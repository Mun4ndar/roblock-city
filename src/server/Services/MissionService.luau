--!strict
-- MissionService: misi harian.
--   * misi hari ini ditentukan MissionConfig.forDay (sama untuk semua pemain)
--   * kemajuan dihitung server: tugas pekerjaan (JobService.TaskCompleted) dan
--     kunjungan tempat (posisi karakter dicek berkala di server)
--   * hadiah hanya lewat remote MissionClaim, dicek ulang di sini
-- Kemajuan tersimpan di PlayerData.missions dan diulang saat hari berganti.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local JobService = require(script.Parent:WaitForChild("JobService"))

type MissionData = Types.MissionData
type Result = { ok: boolean, message: string }

local MissionService = {}

local VISIT_CHECK_SECONDS = 2
local CALL_COOLDOWN = 0.5

local lastCall: { [Player]: number } = {}

-- ---------------------------------------------------------------- util

local function today(): number
	return MissionConfig.dayNumber(os.time())
end

-- Data misi pemain untuk hari ini (diulang dari nol kalau hari sudah berganti).
local function getMissions(data: Types.PlayerData): MissionData
	local md: any = data.missions
	local day = today()
	if
		type(md) ~= "table"
		or md.day ~= day
		or type(md.progress) ~= "table"
		or type(md.claimed) ~= "table"
	then
		md = { day = day, progress = {}, claimed = {} }
		data.missions = md
	end
	return md
end

local function publish(player: Player, md: MissionData)
	local view: MissionConfig.MissionView =
		{ day = md.day, progress = md.progress, claimed = md.claimed }
	player:SetAttribute(MissionConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

-- Tambah kemajuan semua misi aktif sejenis; beri tahu pemain saat ada yang selesai.
local function addProgress(
	player: Player,
	kind: MissionConfig.MissionKind,
	amount: number,
	place: string?
)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local md = getMissions(data)
	local changed = false
	for _, def in MissionConfig.forDay(md.day) do
		local current = md.progress[def.id] or 0
		if def.kind == kind and current < def.target and (place == nil or def.place == place) then
			local value = math.min(current + amount, def.target)
			md.progress[def.id] = value
			changed = true
			if value >= def.target then
				EconomyService.notify(player, `Misi selesai: {def.title}. Ambil hadiahnya di HP!`)
			end
		end
	end
	if changed then
		publish(player, md)
	end
end

local function checkVisits()
	local defs = MissionConfig.forDay(today())
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		if data and root then
			local md = getMissions(data)
			for _, def in defs do
				if
					def.kind == "visit"
					and def.place
					and (md.progress[def.id] or 0) < def.target
				then
					local position = MissionConfig.placePosition(def.place)
					if position then
						local offset = root.Position - position
						if
							Vector3.new(offset.X, 0, offset.Z).Magnitude
							<= MissionConfig.VISIT_RADIUS
						then
							addProgress(player, "visit", 1, def.place)
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- remote handler

local function claim(player: Player, missionId: any): Result
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return { ok = false, message = "Pelan-pelan ya, coba lagi sebentar." }
	end
	lastCall[player] = now

	local data = DataService.getData(player)
	local def = if type(missionId) == "string" then MissionConfig.get(missionId) else nil
	if data == nil or def == nil then
		return { ok = false, message = "Misi tidak dikenal." }
	end
	local md = getMissions(data)
	if not MissionConfig.isActive(def.id, md.day) then
		return { ok = false, message = "Misi ini bukan misi hari ini." }
	end
	if md.claimed[def.id] then
		return { ok = false, message = "Hadiah misi ini sudah diambil." }
	end
	if (md.progress[def.id] or 0) < def.target then
		return { ok = false, message = "Misinya belum selesai." }
	end
	if not EconomyService.addMoney(player, def.reward, "mission:" .. def.id) then
		return { ok = false, message = "Hadiah belum bisa diberikan, coba lagi." }
	end
	md.claimed[def.id] = true
	publish(player, md)
	return { ok = true, message = "Hadiah misi: " .. Format.money(def.reward) .. "!" }
end

-- ---------------------------------------------------------------- bootstrap

local function onProfileLoaded(player: Player, data: Types.PlayerData)
	publish(player, getMissions(data))
end

function MissionService.init()
	Net.func(Net.Names.MissionClaim).OnServerInvoke = function(player: Player, missionId: any)
		local ok, value = pcall(claim, player, missionId)
		if ok then
			return value
		end
		warn("[Mission] MissionClaim error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi nanti." }
	end
end

function MissionService.start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data and player:GetAttribute(MissionConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)

	JobService.TaskCompleted:Connect(function(player: Player, _jobId: string, pay: number)
		addProgress(player, "tasks", 1)
		addProgress(player, "earn", pay)
	end)

	while true do
		task.wait(VISIT_CHECK_SECONDS)
		checkVisits()
	end
end

return MissionService
