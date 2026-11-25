--!strict
-- ProgressService: kemajuan jangka panjang (semua dihitung dan divalidasi server).
--   * koleksi langka: tiap tugas kerja selesai punya peluang menjatuhkan mobil/hewan langka (ada "pity")
--   * seragam bertingkat: tingkat Perak/Emas/Emas Senior di level 4/7/10 (UniformService memakainya)
--   * papan peringkat global (OrderedDataStore): terkaya dan pekerja terbaik
--   * grup Roblox: anggota grup dapat hadiah sekali dan bonus gaji (atribut GroupBonus, dipakai JobService)
--   * kode tukar: daftar kode ada di tabel CODES di bawah (hanya di server)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local ProgressConfig = require(Shared:WaitForChild("ProgressConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local JobService = require(script.Parent:WaitForChild("JobService"))
local UniformService = require(script.Parent:WaitForChild("UniformService"))

type Result = { ok: boolean, message: string }

local ProgressService = {}

-- Kode tukar. expires = os.time() batas akhir (opsional); item = id koleksi langka (opsional).
-- Tambah kode = tambah satu baris di sini.
local CODES: { [string]: { pay: number?, item: string?, expires: number? } } = {
	SELAMATDATANG = { pay = 300 },
	ROBLOCKCITY = { pay = 500 },
	MERDEKA17 = { pay = 1700, expires = os.time({ year = 2027, month = 8, day = 31 }) },
	JALANJALAN = { pay = 400 },
	KANCILEMAS = { item = "kancilEmas" },
}

local CALL_COOLDOWN = 0.5
local CODE_FAIL_LIMIT = 5
local CODE_LOCK_SECONDS = 60

local moneyBoard = DataStoreService:GetOrderedDataStore("RoblockLB_money_v1")
local tasksBoard = DataStoreService:GetOrderedDataStore("RoblockLB_tasks_v1")

local notifyRemote: RemoteEvent
local lastCall: { [Player]: number } = {}
local codeFails: { [Player]: { count: number, since: number, lockedUntil: number } } = {}
local lastTier: { [Player]: string } = {}
local nameCache: { [number]: string } = {}
local boardCache: { at: number, kaya: { any }, pekerja: { any } } =
	{ at = -1e9, kaya = {}, pekerja = {} }

local function notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

local function state(player: Player): any?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	if type(data.progress) ~= "table" then
		data.progress = {}
	end
	local p = data.progress
	if type(p.collection) ~= "table" then
		p.collection = {}
	end
	if type(p.redeemed) ~= "table" then
		p.redeemed = {}
	end
	if type(p.pity) ~= "number" then
		p.pity = 0
	end
	return p
end

local function publishCollection(player: Player)
	local p = state(player)
	if p == nil then
		return
	end
	local ids = {}
	for id in p.collection do
		if ProgressConfig.rare(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	player:SetAttribute(ProgressConfig.ATTR_COLLECTION, table.concat(ids, ","))
end

local function ownedCount(p: any): number
	local n = 0
	for id in p.collection do
		if ProgressConfig.rare(id) then
			n += 1
		end
	end
	return n
end

-- ---------------------------------------------------------------- koleksi

local function award(player: Player, p: any, rare: ProgressConfig.Rare, source: string)
	p.collection[rare.id] = 1
	p.pity = 0
	EconomyService.addMoney(player, rare.cash, "koleksi:" .. rare.id)
	publishCollection(player)
	local rarity = ProgressConfig.RARITY[rare.rarity]
	notify(
		player,
		`✨ Koleksi {rarity.name}! {rare.icon} {rare.name} ({source}). Bonus ${rare.cash}.`
	)
	if ownedCount(p) >= #ProgressConfig.RARES and p.setClaimed ~= true then
		p.setClaimed = true
		EconomyService.addMoney(player, ProgressConfig.SET_BONUS, "koleksi:lengkap")
		notify(player, `🏆 Koleksi lengkap! Hadiah ${ProgressConfig.SET_BONUS}.`)
	end
end

local function rollDrop(player: Player, jobId: string)
	local p = state(player)
	if p == nil then
		return
	end
	p.pity += 1
	local data: any = DataService.getData(player)
	local stat = if data and data.jobs and data.jobs.stats then data.jobs.stats[jobId] else nil
	local level = JobConfig.levelFor(if stat then stat.tasks else 0)
	local chance = ProgressConfig.DROP_BASE + level * ProgressConfig.DROP_PER_LEVEL
	if p.pity < ProgressConfig.PITY and math.random() > chance then
		return
	end
	local unowned = {}
	for _, r in ProgressConfig.RARES do
		if not p.collection[r.id] then
			table.insert(unowned, r)
		end
	end
	if #unowned == 0 then
		return
	end
	-- Pilih item menurut bobot kelangkaan di antara yang belum dimiliki.
	local total = 0
	for _, r in unowned do
		total += ProgressConfig.RARITY[r.rarity].weight
	end
	local roll = math.random() * total
	local pick = unowned[1]
	for _, r in unowned do
		roll -= ProgressConfig.RARITY[r.rarity].weight
		if roll <= 0 then
			pick = r
			break
		end
	end
	award(player, p, pick, "hadiah kerja")
end

-- ---------------------------------------------------------------- seragam bertingkat

local function tierKey(player: Player): string
	local data: any = DataService.getData(player)
	local jobId = if data then data.jobs.current else ""
	local stat = if data and jobId ~= "" then data.jobs.stats[jobId] else nil
	local tier = ProgressConfig.tierFor(JobConfig.levelFor(if stat then stat.tasks else 0))
	return if tier then tier.name else ""
end

local function checkTier(player: Player)
	local key = tierKey(player)
	if lastTier[player] ~= nil and lastTier[player] ~= key and key ~= "" then
		notify(player, `🎖️ Seragam baru: tingkat {key}!`)
		pcall(UniformService.refresh, player)
	end
	lastTier[player] = key
end

-- ---------------------------------------------------------------- papan peringkat

local function taskTotal(data: any): number
	local n = 0
	if data and data.jobs and type(data.jobs.stats) == "table" then
		for _, stat in data.jobs.stats do
			if type(stat) == "table" and type(stat.tasks) == "number" then
				n += stat.tasks
			end
		end
	end
	return n
end

local function pushScores(player: Player)
	local data: any = DataService.getData(player)
	if data == nil then
		return
	end
	local key = tostring(player.UserId)
	local money = math.max(0, math.floor(EconomyService.getMoney(player) or 0))
	local tasks = taskTotal(data)
	pcall(function()
		moneyBoard:SetAsync(key, money)
		tasksBoard:SetAsync(key, tasks)
	end)
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else "Pemain"
	return nameCache[userId]
end

local function fetchTop(store: OrderedDataStore): { any }
	local list = {}
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, ProgressConfig.BOARD_SIZE):GetCurrentPage()
	end)
	if ok then
		for rank, entry in page do
			local userId = tonumber(entry.key) or 0
			table.insert(
				list,
				{ rank = rank, name = nameOf(userId), value = entry.value, userId = userId }
			)
		end
	end
	return list
end

local function board(): { at: number, kaya: { any }, pekerja: { any } }
	if os.clock() - boardCache.at > 60 then
		boardCache =
			{ at = os.clock(), kaya = fetchTop(moneyBoard), pekerja = fetchTop(tasksBoard) }
	end
	return boardCache
end

-- ---------------------------------------------------------------- grup

local function refreshGroup(player: Player)
	if ProgressConfig.GROUP_ID <= 0 then
		return
	end
	local ok, member = pcall(function(): boolean
		return player:IsInGroup(ProgressConfig.GROUP_ID)
	end)
	player:SetAttribute(
		ProgressConfig.ATTR_GROUP_BONUS,
		if ok and member then ProgressConfig.GROUP_BONUS else nil
	)
end

local function claimGroup(player: Player, p: any): Result
	if ProgressConfig.GROUP_ID <= 0 then
		return { ok = false, message = "Grup resmi belum diatur oleh pembuat game." }
	end
	refreshGroup(player)
	if player:GetAttribute(ProgressConfig.ATTR_GROUP_BONUS) == nil then
		return {
			ok = false,
			message = `Gabung grup "{ProgressConfig.GROUP_NAME}" di Roblox dulu, lalu coba lagi.`,
		}
	end
	if p.groupClaimed == true then
		return { ok = true, message = "Hadiah grup sudah kamu ambil. Bonus gaji tetap aktif!" }
	end
	p.groupClaimed = true
	EconomyService.addMoney(player, ProgressConfig.GROUP_JOIN_REWARD, "grup")
	return {
		ok = true,
		message = `Terima kasih sudah bergabung! Hadiah ${ProgressConfig.GROUP_JOIN_REWARD}.`,
	}
end

-- ---------------------------------------------------------------- kode tukar

local function redeem(player: Player, p: any, raw: any): Result
	local now = os.time()
	local fail = codeFails[player]
	if fail and fail.lockedUntil > now then
		return {
			ok = false,
			message = `Terlalu banyak salah. Coba lagi {fail.lockedUntil - now} detik lagi.`,
		}
	end
	local code = if type(raw) == "string" then string.upper((string.gsub(raw, "%s", ""))) else ""
	local def = if #code >= 3
			and #code <= 24
			and not string.find(code, "[^%w]")
		then CODES[code]
		else nil
	if def == nil or (def.expires and now > def.expires) then
		fail = fail or { count = 0, since = now, lockedUntil = 0 }
		if now - fail.since > CODE_LOCK_SECONDS then
			fail.count, fail.since = 0, now
		end
		fail.count += 1
		if fail.count >= CODE_FAIL_LIMIT then
			fail.lockedUntil = now + CODE_LOCK_SECONDS
			fail.count = 0
		end
		codeFails[player] = fail
		return { ok = false, message = "Kode tidak dikenal atau sudah kedaluwarsa." }
	end
	if p.redeemed[code] then
		return { ok = false, message = "Kode itu sudah kamu pakai." }
	end
	local rare = if def.item then ProgressConfig.rare(def.item) else nil
	if rare and p.collection[rare.id] and not def.pay then
		return { ok = false, message = "Kamu sudah punya hadiah kode ini." }
	end
	p.redeemed[code] = true
	if def.pay then
		EconomyService.addMoney(player, def.pay, "kode:" .. code)
	end
	if rare and not p.collection[rare.id] then
		award(player, p, rare, "kode tukar")
	end
	return {
		ok = true,
		message = `🎁 Kode berhasil!{if def.pay then ` Kamu dapat ${def.pay}.` else ""}`,
	}
end

-- ---------------------------------------------------------------- remote

local function handle(player: Player, action: any, arg: any): any
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return { ok = false, message = "Pelan-pelan ya." }
	end
	lastCall[player] = now
	local p = state(player)
	if p == nil then
		return { ok = false, message = "Data belum siap." }
	end
	if action == "board" then
		local b = board()
		local data: any = DataService.getData(player)
		return {
			ok = true,
			message = "",
			kaya = b.kaya,
			pekerja = b.pekerja,
			myMoney = EconomyService.getMoney(player) or 0,
			myTasks = taskTotal(data),
		}
	elseif action == "code" then
		return redeem(player, p, arg)
	elseif action == "group" then
		return claimGroup(player, p)
	elseif action == "state" then
		return {
			ok = true,
			message = "",
			groupId = ProgressConfig.GROUP_ID,
			groupClaimed = p.groupClaimed == true,
			tier = tierKey(player),
		}
	end
	return { ok = false, message = "Aksi tidak dikenal." }
end

function ProgressService.init()
	notifyRemote = Net.event(Net.Names.Notify)
	Net.func("ProgressAction").OnServerInvoke = function(player: Player, action: any, arg: any): any
		local ok, value = pcall(handle, player, action, arg)
		if ok then
			return value
		end
		warn("[Progress] error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi nanti." }
	end
end

function ProgressService.start()
	local function prepare(player: Player)
		publishCollection(player)
		refreshGroup(player)
		lastTier[player] = tierKey(player)
	end
	DataService.ProfileLoaded:Connect(prepare)
	for _, player in Players:GetPlayers() do
		if DataService.getData(player) then
			prepare(player)
		end
	end
	JobService.TaskCompleted:Connect(function(player: Player, jobId: string)
		rollDrop(player, jobId)
		checkTier(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.spawn(pushScores, player)
		lastCall[player] = nil
		codeFails[player] = nil
		lastTier[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ProgressConfig.PUSH_INTERVAL)
			for _, player in Players:GetPlayers() do
				pushScores(player)
				refreshGroup(player)
				task.wait(1)
			end
		end
	end)
end

return ProgressService
