--!strict
-- OnboardingService: panduan pemain baru, semuanya dihitung server.
--   * Misi Pemula 3 langkah: pilih pekerjaan -> selesaikan 1 tugas -> belanja / naik kendaraan.
--     Tiap langkah memberi koin; langkah terakhir memberi setelan gratis.
--   * bonus main: bertahan PLAY_BONUS_SECONDS detik -> koin (waktu main tersimpan di data).
--   * teleport cepat dari HP ke tempat-tempat seru (remote OnboardingAction).
-- Tersimpan di PlayerData.onboarding. Client hanya membaca atribut Player "Onboarding" (JSON)
-- dan memanggil remote tanpa pernah mengirim angka.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local OnboardingConfig = require(Shared:WaitForChild("OnboardingConfig"))
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local FashionService = require(script.Parent:WaitForChild("FashionService"))
local JobService = require(script.Parent:WaitForChild("JobService"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))

type Result = { ok: boolean, message: string }

local OnboardingService = {}

local TICK_SECONDS = 1
local CALL_COOLDOWN = 0.5
local STEP_COUNT = #OnboardingConfig.STEPS
local STAND_HEIGHT = 4 -- karakter diletakkan sedikit di atas tanah

local lastCall: { [Player]: number } = {}
local lastTeleport: { [Player]: number } = {}
local lastTick: { [Player]: number } = {}
local jobConnections: { [Player]: RBXScriptConnection } = {}
-- Langkah 3 butuh naik kendaraan SETELAH langkah 2 selesai: pemain harus terlihat tidak
-- mengemudi dulu, baru naik lagi (kalau tidak, kurir yang sedang menyetir langsung lulus).
local seenOffSeat: { [Player]: boolean } = {}

-- ---------------------------------------------------------------- data

local function today(): number
	return RetentionConfig.dayNumber(os.time())
end

-- Pemain lama (sudah pernah menyelesaikan tugas) tidak perlu panduan.
local function isVeteran(data: any): boolean
	local jobs = data.jobs
	if type(jobs) ~= "table" or type(jobs.stats) ~= "table" then
		return false
	end
	for _, progress in jobs.stats do
		if type(progress) == "table" and type(progress.tasks) == "number" and progress.tasks > 0 then
			return true
		end
	end
	return false
end

local function getData(player: Player): any?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	local o: any = data.onboarding
	if type(o) ~= "table" then
		local veteran = isVeteran(data)
		o = { step = if veteran then STEP_COUNT else 0, rewarded = veteran }
		data.onboarding = o
	end
	if type(o.step) ~= "number" then
		o.step = 0
	end
	o.step = math.clamp(math.floor(o.step), 0, STEP_COUNT)
	if type(o.rewarded) ~= "boolean" then
		o.rewarded = false
	end
	for _, key in { "playSeconds", "bonusDay" } do
		if type(o[key]) ~= "number" then
			o[key] = 0
		end
	end
	if type(o.bonusClaimed) ~= "boolean" then
		o.bonusClaimed = false
	end
	return o
end

local function publish(player: Player, o: any)
	local view: OnboardingConfig.View = {
		step = o.step,
		done = o.step >= STEP_COUNT,
		bonusLeft = math.max(0, math.ceil(OnboardingConfig.PLAY_BONUS_SECONDS - o.playSeconds)),
		bonusClaimed = o.bonusClaimed,
	}
	player:SetAttribute(OnboardingConfig.ATTR, HttpService:JSONEncode(view))
end

-- ---------------------------------------------------------------- Misi Pemula

-- Menyelesaikan langkah `step` (1..3) hanya kalau memang langkah berikutnya.
local function complete(player: Player, step: number)
	local o = getData(player)
	if o == nil or o.step ~= step - 1 then
		return
	end
	local def = OnboardingConfig.STEPS[step]
	o.step = step
	EconomyService.addMoney(player, def.reward, "pemula:" .. tostring(step))
	if step < STEP_COUNT then
		EconomyService.notify(player, `Misi Pemula {step}/{STEP_COUNT} selesai! Hadiah {Format.money(def.reward)}.`)
	else
		local outfit = FashionConfig.get(OnboardingConfig.FINAL_OUTFIT)
		if not o.rewarded and outfit and FashionService.grant(player, outfit.id, true) then
			o.rewarded = true
		end
		EconomyService.notify(player, `Misi Pemula selesai! Hadiah {Format.money(def.reward)} dan setelan gratis.`)
	end
	seenOffSeat[player] = nil
	publish(player, o)
end

local function onJobChanged(player: Player)
	local job = player:GetAttribute(JobConfig.ATTR_JOB)
	if type(job) == "string" and job ~= "" then
		complete(player, 1)
	end
end

local function isDriving(player: Player): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	return seat ~= nil and seat:IsA("VehicleSeat")
end

-- ---------------------------------------------------------------- bonus main

local function tickPlayer(player: Player, now: number)
	local o = getData(player)
	if o == nil then
		return
	end
	local last = lastTick[player] or now
	lastTick[player] = now
	local changed = false

	if OnboardingConfig.PLAY_BONUS_DAILY then
		local day = today()
		if o.bonusDay ~= day then
			o.bonusDay = day
			o.playSeconds = 0
			o.bonusClaimed = false
			changed = true
		end
	end

	if not o.bonusClaimed then
		o.playSeconds += math.clamp(now - last, 0, TICK_SECONDS * 3)
		if o.playSeconds >= OnboardingConfig.PLAY_BONUS_SECONDS then
			if EconomyService.addMoney(player, OnboardingConfig.PLAY_BONUS_AMOUNT, "pemula:bonus_main") then
				o.bonusClaimed = true
				changed = true
				local minutes = OnboardingConfig.PLAY_BONUS_SECONDS // 60
				local again = if OnboardingConfig.PLAY_BONUS_DAILY then " Besok ada lagi!" else ""
				EconomyService.notify(
					player,
					`Bonus main {minutes} menit: {Format.money(OnboardingConfig.PLAY_BONUS_AMOUNT)}!{again}`
				)
			end
		end
	end

	if o.step == STEP_COUNT - 1 then
		if isDriving(player) then
			if seenOffSeat[player] then
				complete(player, STEP_COUNT)
				return
			end
		else
			seenOffSeat[player] = true
		end
	end

	if changed then
		publish(player, o)
	end
end

-- ---------------------------------------------------------------- remote

local function reply(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function teleport(player: Player, spotId: any): Result
	local spot = OnboardingConfig.spot(spotId)
	if spot == nil then
		return reply(false, "Tempat itu tidak dikenal.")
	end
	local now = os.clock()
	local last = lastTeleport[player]
	if last and now - last < OnboardingConfig.TELEPORT_COOLDOWN then
		local left = math.ceil(OnboardingConfig.TELEPORT_COOLDOWN - (now - last))
		return reply(false, `Tunggu {left} detik lagi sebelum teleport.`)
	end
	local destination = CFrame.new(spot.position + Vector3.new(0, STAND_HEIGHT, 0))
	if not PortalService.teleport(player, destination) then
		return reply(false, "Belum bisa teleport sekarang, coba lagi sebentar.")
	end
	lastTeleport[player] = now
	return reply(true, `Selamat datang di {spot.name}!`)
end

local function handle(player: Player, action: any, arg: any): Result
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return reply(false, "Pelan-pelan ya, coba lagi sebentar.")
	end
	lastCall[player] = now
	if not DataService.isLoaded(player) then
		return reply(false, "Data kamu masih dimuat...")
	end
	if action == "teleport" then
		return teleport(player, arg)
	end
	return reply(false, "Perintah tidak dikenal.")
end

-- Dipakai DebugService (hanya Studio): ulangi panduan dari awal dan setel waktu main (detik).
function OnboardingService.debugReset(player: Player, playSeconds: number?): boolean
	local o = getData(player)
	if o == nil then
		return false
	end
	o.step = 0
	o.rewarded = false
	o.playSeconds = playSeconds or 0
	o.bonusClaimed = false
	seenOffSeat[player] = nil
	publish(player, o)
	return true
end

-- ---------------------------------------------------------------- bootstrap

function OnboardingService.init()
	Net.func(Net.Names.OnboardingAction).OnServerInvoke = function(player: Player, action: any, arg: any)
		local ok, value = pcall(handle, player, action, arg)
		if ok then
			return value
		end
		warn("[Onboarding] OnboardingAction error: " .. tostring(value))
		return reply(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

local function onProfileLoaded(player: Player)
	local o = getData(player)
	if o == nil then
		return
	end
	lastTick[player] = os.clock()
	publish(player, o)
	if jobConnections[player] == nil then
		jobConnections[player] = player:GetAttributeChangedSignal(JobConfig.ATTR_JOB):Connect(function()
			onJobChanged(player)
		end)
	end
	-- Pekerjaan yang tersimpan dari sesi lalu langsung dihitung.
	if JobService.getJob(player) ~= "" then
		complete(player, 1)
	else
		onJobChanged(player)
	end
end

function OnboardingService.start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) and player:GetAttribute(OnboardingConfig.ATTR) == nil then
			onProfileLoaded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local connection = jobConnections[player]
		if connection then
			connection:Disconnect()
		end
		jobConnections[player] = nil
		lastCall[player] = nil
		lastTeleport[player] = nil
		lastTick[player] = nil
		seenOffSeat[player] = nil
	end)

	JobService.TaskCompleted:Connect(function(player: Player)
		complete(player, 1) -- jaga-jaga: tugas selesai berarti pekerjaan sudah dipilih
		complete(player, 2)
	end)
	EconomyService.Spent:Connect(function(player: Player, _amount: number, reason: string)
		if reason ~= "debug" then
			complete(player, STEP_COUNT)
		end
	end)

	while true do
		task.wait(TICK_SECONDS)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			if DataService.isLoaded(player) then
				local ok, err = pcall(tickPlayer, player, now)
				if not ok then
					warn("[Onboarding] tick error: " .. tostring(err))
				end
			end
		end
	end
end

return OnboardingService
