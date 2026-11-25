--!strict
-- RetentionService: alasan untuk kembali bermain setiap hari.
--   * hadiah login beruntun 7 hari (hari ke-7 besar), pemilik VIP dua kali lipat
--   * misi harian dan mingguan yang terkait pekerjaan (kurir, dokter, bensin, panen, ...)
--   * kerangka event musiman: tanggal, dekorasi, misi, dan setelan terbatas
-- Semua dihitung server dan disimpan di PlayerData.retention. Client hanya membaca atribut
-- Player "Retention" (JSON) dan memanggil remote RetentionAction (remote tidak mengirim angka).
--   Debug (Studio): ServerStorage.Debug:Invoke("event", "natal") memaksa event, "" = normal.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local FashionService = require(script.Parent:WaitForChild("FashionService"))
local FuelService = require(script.Parent:WaitForChild("FuelService"))
local FarmService = require(script.Parent:WaitForChild("FarmService"))
local ClinicService = require(script.Parent:WaitForChild("ClinicService"))
local JobService = require(script.Parent:WaitForChild("JobService"))

type Result = { ok: boolean, message: string }

local RetentionService = {}

local CALL_COOLDOWN = 0.4
local EVENT_CHECK_SECONDS = 60
local MAX_KEY = 40

local lastCall: { [Player]: number } = {}
local forcedEvent: string? = nil
local currentEvent = ""

-- ---------------------------------------------------------------- data

local function toTable(value: any): { [string]: any }
	return if type(value) == "table" then value else {}
end

-- Memastikan bentuk data benar (aman untuk data lama yang belum punya field ini).
local function getData(player: Player): any?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	local r: any = data.retention
	if type(r) ~= "table" then
		r = {}
		data.retention = r
	end
	for _, key in { "streak", "lastClaimDay", "day", "week" } do
		if type(r[key]) ~= "number" then
			r[key] = 0
		end
	end
	for _, key in
		{ "daily", "dailyClaimed", "weekly", "weeklyClaimed", "eventProgress", "eventClaimed" }
	do
		r[key] = toTable(r[key])
	end
	if type(r.eventKey) ~= "string" then
		r.eventKey = ""
	end
	return r
end

local function eventNow(): RetentionConfig.EventDef?
	if forcedEvent ~= nil then
		return if forcedEvent == "" then nil else RetentionConfig.event(forcedEvent)
	end
	return RetentionConfig.activeEvent(os.time())
end

local function eventKey(event: RetentionConfig.EventDef): string
	local year = os.date("!*t", os.time() + RetentionConfig.UTC_OFFSET_HOURS * 3600).year
	return `{event.id}_{year}`
end

-- Mengulang kemajuan yang sudah kedaluwarsa (hari/pekan/event berganti).
local function rollover(r: any)
	local day = RetentionConfig.dayNumber(os.time())
	if r.day ~= day then
		r.day = day
		r.daily = {}
		r.dailyClaimed = {}
	end
	local week = RetentionConfig.weekNumber(day)
	if r.week ~= week then
		r.week = week
		r.weekly = {}
		r.weeklyClaimed = {}
	end
	local event = eventNow()
	local key = if event then eventKey(event) else ""
	if r.eventKey ~= key then
		r.eventKey = key
		r.eventProgress = {}
		r.eventClaimed = {}
	end
end

-- Hari login yang akan diambil: lanjut kalau kemarin klaim, kalau lewat mulai lagi.
local function streakState(r: any): (number, boolean, number)
	local day = RetentionConfig.dayNumber(os.time())
	local claimedToday = r.lastClaimDay == day
	local alive = claimedToday or r.lastClaimDay == day - 1
	local streak = if alive then r.streak else 0
	return streak, claimedToday, (streak % 7) + 1
end

local function multiplier(player: Player): number
	return if player:GetAttribute("VIP") == true then RetentionConfig.VIP_MULTIPLIER else 1
end

local function publish(player: Player, r: any)
	local streak, claimedToday, nextDay = streakState(r)
	local view: RetentionConfig.RetentionView = {
		day = r.day,
		streak = streak,
		claimedToday = claimedToday,
		nextDay = nextDay,
		daily = r.daily,
		dailyClaimed = r.dailyClaimed,
		week = r.week,
		weekly = r.weekly,
		weeklyClaimed = r.weeklyClaimed,
		event = if r.eventKey ~= "" then string.match(r.eventKey, "^(%a+)_") or "" else "",
		eventProgress = r.eventProgress,
		eventClaimed = r.eventClaimed,
	}
	player:SetAttribute(RetentionConfig.ATTR, HttpService:JSONEncode(view))
end

-- ---------------------------------------------------------------- kemajuan

local function matches(counter: string, kind: string, jobId: string?): boolean
	if counter == kind then
		return true
	end
	return jobId ~= nil and kind == "tasks" and counter == "task:" .. jobId
end

local function bump(
	player: Player,
	r: any,
	list: { RetentionConfig.MissionDef },
	store: any,
	kind: string,
	amount: number,
	jobId: string?
): boolean
	local changed = false
	for _, def in list do
		if matches(def.counter, kind, jobId) then
			local current = store[def.id] or 0
			if current < def.target then
				local value = math.min(current + amount, def.target)
				store[def.id] = value
				changed = true
				if value >= def.target then
					EconomyService.notify(
						player,
						`Misi selesai: {def.title}. Ambil hadiahnya di HP!`
					)
				end
			end
		end
	end
	return changed
end

-- kind: "tasks" (jobId diisi), "earn", "refuel", "harvest".
local function addProgress(player: Player, kind: string, amount: number, jobId: string?)
	local r = getData(player)
	if r == nil or amount <= 0 then
		return
	end
	rollover(r)
	local event = eventNow()
	local changed = bump(player, r, RetentionConfig.dailyFor(r.day), r.daily, kind, amount, jobId)
	changed = bump(player, r, RetentionConfig.weeklyFor(r.week), r.weekly, kind, amount, jobId)
		or changed
	if event then
		changed = bump(player, r, event.missions, r.eventProgress, kind, amount, jobId) or changed
	end
	-- "task:<id>" butuh kind "tasks"; kejadian yang sama juga dihitung sebagai "task:<id>" lewat matches().
	if changed then
		publish(player, r)
	end
end

-- ---------------------------------------------------------------- remote

local function reply(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function claimStreak(player: Player, r: any): Result
	local streak, claimedToday, dayIndex = streakState(r)
	if claimedToday then
		return reply(false, "Hadiah login hari ini sudah diambil. Sampai besok ya!")
	end
	local amount = RetentionConfig.STREAK[dayIndex] * multiplier(player)
	if not EconomyService.addMoney(player, amount, "streak") then
		return reply(false, "Hadiah belum bisa diberikan, coba lagi.")
	end
	r.streak = streak + 1
	r.lastClaimDay = RetentionConfig.dayNumber(os.time())
	publish(player, r)
	local extra = if dayIndex == 7 then " Hari ke-7, hadiah besar!" else ""
	return reply(true, `Login hari ke-{dayIndex}: {Format.money(amount)}!{extra}`)
end

local function claimMission(player: Player, r: any, id: any): Result
	local def = if type(id) == "string" and #id <= MAX_KEY then RetentionConfig.mission(id) else nil
	if def == nil then
		return reply(false, "Misi tidak dikenal.")
	end
	local store, claimed
	local active = false
	for _, d in RetentionConfig.dailyFor(r.day) do
		if d.id == def.id then
			store, claimed, active = r.daily, r.dailyClaimed, true
		end
	end
	for _, d in RetentionConfig.weeklyFor(r.week) do
		if d.id == def.id then
			store, claimed, active = r.weekly, r.weeklyClaimed, true
		end
	end
	local event = eventNow()
	if event then
		for _, d in event.missions do
			if d.id == def.id then
				store, claimed, active = r.eventProgress, r.eventClaimed, true
			end
		end
	end
	if not active then
		return reply(false, "Misi ini sedang tidak berlaku.")
	end
	if claimed[def.id] then
		return reply(false, "Hadiah misi ini sudah diambil.")
	end
	if (store[def.id] or 0) < def.target then
		return reply(false, "Misinya belum selesai.")
	end
	local amount = def.reward * multiplier(player)
	if not EconomyService.addMoney(player, amount, "retention:" .. def.id) then
		return reply(false, "Hadiah belum bisa diberikan, coba lagi.")
	end
	claimed[def.id] = true
	publish(player, r)
	return reply(true, `Hadiah misi: {Format.money(amount)}!`)
end

local function buyEventItem(player: Player, itemId: any): Result
	local event = eventNow()
	if event == nil then
		return reply(false, "Tidak ada event yang sedang berlangsung.")
	end
	local item
	for _, candidate in event.items do
		if candidate.id == itemId then
			item = candidate
		end
	end
	local outfit = if item then FashionConfig.get(item.id) else nil
	if item == nil or outfit == nil then
		return reply(false, "Barang event tidak dikenal.")
	end
	if FashionService.owns(player, outfit.id) then
		return reply(false, "Kamu sudah punya barang ini.")
	end
	if not EconomyService.trySpend(player, item.price, "event:" .. outfit.id) then
		return reply(false, `Uangmu belum cukup. Harganya {Format.money(item.price)}.`)
	end
	if not FashionService.grant(player, outfit.id) then
		EconomyService.addMoney(player, item.price, "event_refund")
		return reply(false, "Barang belum bisa diberikan, uangmu dikembalikan.")
	end
	return reply(true, `{outfit.name} jadi milikmu! Pakai di Toko Costume.`)
end

local function handle(player: Player, action: any, arg: any): Result
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return reply(false, "Pelan-pelan ya, coba lagi sebentar.")
	end
	lastCall[player] = now
	local r = getData(player)
	if r == nil then
		return reply(false, "Data kamu masih dimuat...")
	end
	rollover(r)
	if action == "streak" then
		return claimStreak(player, r)
	elseif action == "mission" then
		return claimMission(player, r, arg)
	elseif action == "buy" then
		return buyEventItem(player, arg)
	end
	return reply(false, "Perintah tidak dikenal.")
end

-- ---------------------------------------------------------------- dekorasi event

-- Dekorasi disimpan di ServerStorage.EventDecor.<id> dan dipasang ke Workspace.Map.EventDecor
-- hanya selama event berlangsung (tidak aktif = tidak ada di dunia, tidak memakan memori).
local function applyEvent(eventId: string)
	if eventId == currentEvent then
		return
	end
	currentEvent = eventId
	Workspace:SetAttribute(RetentionConfig.EVENT_ATTR, eventId)
	local map = Workspace:FindFirstChild("Map")
	local mount = if map then map:FindFirstChild(RetentionConfig.DECOR_FOLDER) else nil
	if mount then
		mount:Destroy()
	end
	local source = ServerStorage:FindFirstChild(RetentionConfig.DECOR_SOURCE)
	local decor = if source and eventId ~= "" then source:FindFirstChild(eventId) else nil
	if decor and map then
		local copy = decor:Clone()
		copy.Name = RetentionConfig.DECOR_FOLDER
		copy.Parent = map
	end
	for _, player in Players:GetPlayers() do
		local r = getData(player)
		if r then
			rollover(r)
			publish(player, r)
		end
	end
end

local function checkEvent()
	local event = eventNow()
	applyEvent(if event then event.id else "")
end

-- Dipakai DebugService (hanya Studio).
function RetentionService.forceEvent(eventId: string?)
	forcedEvent = eventId
	checkEvent()
end

-- ---------------------------------------------------------------- bootstrap

function RetentionService.init()
	Net.func(Net.Names.RetentionAction).OnServerInvoke = function(
		player: Player,
		action: any,
		arg: any
	)
		local ok, value = pcall(handle, player, action, arg)
		if ok then
			return value
		end
		warn("[Retention] RetentionAction error: " .. tostring(value))
		return reply(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

local function onProfileLoaded(player: Player)
	local r = getData(player)
	if r then
		rollover(r)
		publish(player, r)
	end
end

function RetentionService.start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.getData(player) and player:GetAttribute(RetentionConfig.ATTR) == nil then
			onProfileLoaded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)

	JobService.TaskCompleted:Connect(function(player: Player, jobId: string, pay: number)
		addProgress(player, "tasks", 1, jobId)
		addProgress(player, "earn", pay)
	end)
	FuelService.Refueled:Connect(function(player: Player)
		addProgress(player, "refuel", 1)
	end)
	ClinicService.PatientCured:Connect(function(doctor: Player)
		addProgress(doctor, "patient", 1)
	end)
	FarmService.Harvested:Connect(function(player: Player, amount: number)
		addProgress(player, "harvest", amount)
	end)

	while true do
		checkEvent()
		task.wait(EVENT_CHECK_SECONDS)
	end
end

return RetentionService
