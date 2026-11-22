--!strict
-- DataService: menyimpan & memuat data pemain dengan aman.
--   * retry + exponential backoff untuk setiap panggilan DataStore
--   * session locking via UpdateAsync (mencegah duplikasi data antar server)
--   * autosave berkala + simpan saat keluar + BindToClose
--   * versi skema + migrasi
-- Service lain TIDAK boleh menyentuh DataStore langsung; pakai API modul ini.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type PlayerData = Types.PlayerData

type Lock = { jobId: string, time: number }
type Record = { data: PlayerData?, lock: Lock? }

type Profile = {
	data: PlayerData,
	persistent: boolean, -- false = mode offline (Studio tanpa API access), tidak disimpan
	released: boolean,
}

local DataService = {}

local JOB_ID = if game.JobId ~= "" then game.JobId else "studio"
local KEY_PREFIX = "Player_"
local LOCK_WAIT_ATTEMPTS = 6
local LOCK_WAIT_SECONDS = 5

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local pendingSaves = 0
local shuttingDown = false

local loadedEvent = Instance.new("BindableEvent")
-- Terpicu (player, data) setelah profil pemain siap.
DataService.ProfileLoaded = loadedEvent.Event

-- ---------------------------------------------------------------- skema

local function defaultData(): PlayerData
	return {
		version = Config.SCHEMA_VERSION,
		money = Config.STARTING_MONEY,
		lastDailyReward = 0,
		stats = { totalEarned = 0, joins = 0 },
		vehicles = {},
		jobs = { current = "", stats = {} },
		house = { id = 0, tier = "", boughtAt = 0, paint = {}, items = {} },
		missions = { day = 0, progress = {}, claimed = {} },
		farm = { plots = {}, seeds = {}, crops = {} },
		receipts = {},
		pets = { owned = {}, active = "", fedAt = 0 },
		fashion = { owned = {}, active = "" },
		business = { level = 0, stored = 0 },
	}
end

-- MIGRATIONS[n] mengubah data versi n menjadi versi n+1.
-- Saat skema berubah: naikkan Config.SCHEMA_VERSION dan tambah fungsi di sini.
local MIGRATIONS: { [number]: (any) -> any } = {}

local function migrate(raw: any): PlayerData
	if type(raw) ~= "table" then
		return defaultData()
	end
	local version = if type(raw.version) == "number" then raw.version else 0
	while version < Config.SCHEMA_VERSION do
		local step = MIGRATIONS[version]
		if step then
			raw = step(raw)
		end
		version += 1
		raw.version = version
	end
	-- Isi field yang hilang dengan default (aman untuk penambahan field).
	local defaults: any = defaultData()
	for key, value in defaults do
		if raw[key] == nil then
			raw[key] = value
		end
	end
	if type(raw.stats) ~= "table" then
		raw.stats = {}
	end
	for key, value in defaults.stats do
		if raw.stats[key] == nil then
			raw.stats[key] = value
		end
	end
	if type(raw.vehicles) ~= "table" then
		raw.vehicles = {}
	end
	if type(raw.jobs) ~= "table" then
		raw.jobs = {}
	end
	if type(raw.jobs.current) ~= "string" then
		raw.jobs.current = ""
	end
	if type(raw.jobs.stats) ~= "table" then
		raw.jobs.stats = {}
	end
	return raw :: PlayerData
end

-- ---------------------------------------------------------------- util

local function retry(label: string, attempts: number, fn: () -> any): (boolean, any)
	local lastError = ""
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		warn(`[DataService] {label} gagal (percobaan {attempt}/{attempts}): {lastError}`)
		if attempt < attempts then
			task.wait(math.min(2 ^ attempt, 16))
		end
	end
	return false, lastError
end

local function keyFor(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

local function isLockedByOther(lock: Lock?): boolean
	if lock == nil or lock.jobId == JOB_ID then
		return false
	end
	return os.time() - lock.time < Config.SESSION_LOCK_EXPIRY
end

-- ---------------------------------------------------------------- load / save

-- Mengembalikan (data, persistent). data nil = gagal total.
local function loadAsync(player: Player): (PlayerData?, boolean)
	local ds = store
	if ds == nil then
		return defaultData(), false
	end

	local key = keyFor(player)
	for attempt = 1, LOCK_WAIT_ATTEMPTS do
		local blocked = false
		local ok, result = retry("Load " .. key, Config.LOAD_RETRIES, function()
			return ds:UpdateAsync(key, function(old: any): any
				local record: Record = if type(old) == "table" then old else {}
				if isLockedByOther(record.lock) then
					blocked = true
					return nil -- batalkan penulisan
				end
				blocked = false
				record.lock = { jobId = JOB_ID, time = os.time() }
				return record
			end)
		end)

		if not ok then
			return nil, false
		end
		if not blocked then
			local record = result :: Record?
			return migrate(if record then record.data else nil), true
		end
		-- Data masih dipakai server lain (mis. baru pindah server). Tunggu lalu coba lagi.
		warn(`[DataService] {key} terkunci server lain, menunggu (percobaan {attempt})`)
		task.wait(LOCK_WAIT_SECONDS)
		if player.Parent == nil then
			return nil, false
		end
	end
	return nil, false
end

local function saveAsync(player: Player, profile: Profile, release: boolean): boolean
	local ds = store
	if ds == nil or not profile.persistent then
		return true
	end
	local key = keyFor(player)
	local stolen = false
	pendingSaves += 1
	local ok = retry("Save " .. key, Config.SAVE_RETRIES, function()
		return ds:UpdateAsync(key, function(old: any): any
			local record: Record = if type(old) == "table" then old else {}
			if isLockedByOther(record.lock) then
				stolen = true
				return nil -- server lain sudah mengambil alih; jangan timpa
			end
			stolen = false
			record.data = profile.data
			record.lock = if release then nil else { jobId = JOB_ID, time = os.time() }
			return record
		end)
	end)
	pendingSaves -= 1
	if stolen then
		warn(`[DataService] lock {key} diambil server lain; simpan dibatalkan`)
		return false
	end
	return ok
end

-- ---------------------------------------------------------------- lifecycle

local function onPlayerAdded(player: Player)
	local data, persistent = loadAsync(player)
	if data == nil then
		if RunService:IsStudio() then
			warn("[DataService] Gagal memuat data, memakai data sementara (Studio).")
			data, persistent = defaultData(), false
		else
			player:Kick("Data kamu belum bisa dimuat. Coba masuk lagi sebentar lagi ya!")
			return
		end
	end
	local loadedData = data :: PlayerData

	if player.Parent == nil then
		-- Pemain keluar saat loading: lepaskan lock yang barusan diambil.
		saveAsync(player, { data = loadedData, persistent = persistent, released = true }, true)
		return
	end

	loadedData.stats.joins += 1
	profiles[player] = { data = loadedData, persistent = persistent, released = false }
	loadedEvent:Fire(player, loadedData)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil or profile.released then
		return
	end
	profile.released = true
	saveAsync(player, profile, true)
	profiles[player] = nil
end

-- ---------------------------------------------------------------- API publik

-- Data hidup pemain. Hanya service pemilik field yang boleh mengubahnya
-- (mis. money hanya lewat EconomyService).
function DataService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- true jika data pemain benar-benar disimpan ke DataStore (bukan mode offline).
function DataService.isPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.persistent
end

-- ---------------------------------------------------------------- bootstrap

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore tidak tersedia, data tidak disimpan: " .. tostring(result))
	end
end

function DataService.start()
	-- Studio tanpa "Enable Studio Access to API Services": pakai mode offline.
	if store and RunService:IsStudio() then
		local probeOk, probeErr = pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			warn(
				"[DataService] Akses API DataStore mati di Studio -> mode offline (tidak disimpan). "
					.. "Aktifkan di Game Settings > Security. ("
					.. tostring(probeErr)
					.. ")"
			)
			store = nil
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		shuttingDown = true
		for player, profile in profiles do
			if not profile.released then
				profile.released = true
				task.spawn(saveAsync, player, profile, true)
			end
		end
		-- Tunggu semua penyimpanan selesai (batas BindToClose ~30 detik).
		local deadline = os.clock() + 25
		task.wait()
		while pendingSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while not shuttingDown do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if not profile.released and not shuttingDown then
					task.spawn(saveAsync, player, profile, false)
				end
			end
		end
	end)
end

return DataService
