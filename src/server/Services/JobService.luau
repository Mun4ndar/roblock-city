--!strict
-- JobService: pekerjaan pemain (pilih pekerjaan, tugas, gaji).
--   * server-authoritative: server yang menyusun tugas dan menghitung gaji;
--     client hanya mengirim "langkah ke-n tugas x selesai"
--   * setiap langkah divalidasi: pemain harus berada di dekat penanda, dan waktu
--     tempuhnya harus masuk akal untuk kendaraan yang ia miliki
--   * pengawas posisi membatalkan tugas jika pemain berpindah tidak wajar
--   * pengaman tambahan: rate limit remote + batas gaji per jendela waktu
--   * kemajuan (jumlah tugas, total gaji, pekerjaan aktif) tersimpan di data pemain
--     dan dikirim ke client lewat atribut Player "Job" dan "JobStats"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local UniformService = require(script.Parent:WaitForChild("UniformService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local PlaneService = require(script.Parent:WaitForChild("PlaneService"))
local PlaneConfig = require(Shared:WaitForChild("PlaneConfig"))

type JobResult = Types.JobResult
type JobDef = JobConfig.JobDef
type TaskTemplate = JobConfig.TaskTemplate
type TaskView = JobConfig.TaskView
type TaskStepView = JobConfig.TaskStepView

type ActiveTask = {
	view: TaskView,
	stepStartedAt: number, -- os.clock() saat langkah aktif dimulai
	stepOrigin: Vector3, -- titik awal perjalanan menuju langkah aktif
}

type Earning = { time: number, amount: number }

type Track = { character: Model, position: Vector3, time: number }

local JobService = {}

local completedEvent = Instance.new("BindableEvent")
-- Terpicu (player, jobId, gaji) setiap satu tugas selesai dan dibayar (dipakai misi).
JobService.TaskCompleted = completedEvent.Event

local FALLBACK_ORIGIN = Vector3.new(40, 1, 274) -- taman kota kecil (titik spawn)
local HORIZONTAL = Vector3.new(1, 0, 1)

local taskRemote: RemoteEvent
local active: { [Player]: ActiveTask } = {}
local earnings: { [Player]: { Earning } } = {}
local tracks: { [Player]: Track } = {}
local lastCall: { [Player]: number } = {}
local lastSelect: { [Player]: number } = {}
local lastSkip: { [Player]: number } = {}
local lastSync: { [Player]: number } = {}
local assignToken: { [Player]: number } = {}
local nextTaskId = 0
local random = Random.new()

-- ---------------------------------------------------------------- util

local function result(ok: boolean, message: string): JobResult
	return { ok = ok, message = message }
end

local function flatDistance(a: Vector3, b: Vector3): number
	return ((a - b) * HORIZONTAL).Magnitude
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function allowCall(player: Player): boolean
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < JobConfig.REMOTE_COOLDOWN then
		return false
	end
	lastCall[player] = now
	return true
end

-- Kecepatan tempuh tercepat yang wajar untuk pemain ini (stud/detik).
local function allowedSpeed(player: Player): number
	local speed = JobConfig.WALK_SPEED
	local data = DataService.getData(player)
	if data then
		for id in data.vehicles do
			local def = VehicleConfig.get(id)
			if def and def.maxSpeed > speed then
				speed = def.maxSpeed
			end
		end
		local service = VehicleConfig.forJob(data.jobs.current)
		if service and service.maxSpeed > speed then
			speed = service.maxSpeed
		end
		if data.jobs.current == PlaneConfig.JOB then
			speed = math.max(speed, PlaneConfig.MAX_SPEED)
		end
	end
	return speed * JobConfig.SPEED_SLACK
end

local function getProgress(data: Types.PlayerData, jobId: string): Types.JobProgress
	local progress = data.jobs.stats[jobId]
	if
		type(progress) ~= "table"
		or type(progress.tasks) ~= "number"
		or type(progress.earned) ~= "number"
	then
		progress = { tasks = 0, earned = 0 }
		data.jobs.stats[jobId] = progress
	end
	return progress
end

local function publish(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local stats: { [string]: Types.JobProgress } = {}
	for _, def in JobConfig.LIST do
		local progress = data.jobs.stats[def.id]
		if type(progress) == "table" then
			stats[def.id] = getProgress(data, def.id)
		end
	end
	local current = if JobConfig.get(data.jobs.current) then data.jobs.current else ""
	player:SetAttribute(JobConfig.ATTR_JOB, current)
	player:SetAttribute(JobConfig.ATTR_STATS, HttpService:JSONEncode(stats))
end

local function sendTask(player: Player)
	local task_ = active[player]
	taskRemote:FireClient(player, if task_ then task_.view else nil)
end

-- ---------------------------------------------------------------- menyusun tugas

local function pickTemplate(def: JobDef): TaskTemplate
	local total = 0
	for _, template in def.tasks do
		total += template.weight
	end
	local roll = random:NextNumber() * total
	for _, template in def.tasks do
		roll -= template.weight
		if roll <= 0 then
			return template
		end
	end
	return def.tasks[#def.tasks]
end

-- Memilih tempat dari pool yang memenuhi batasan jarak dari `ref`.
-- Jika tidak ada yang memenuhi, ambil yang paling mendekati batasan.
local function pickFromPool(
	spec: JobConfig.StepSpec,
	ref: Vector3,
	used: { [string]: boolean }
): string?
	local pool = JobConfig.POOLS[spec.pool :: string]
	if pool == nil then
		return nil
	end
	local minDist = spec.minDist or 0
	local maxDist = spec.maxDist or math.huge
	local inRange: { { id: string, distance: number } } = {}
	local fallbackId: string? = nil
	local fallbackMiss = math.huge
	for _, id in pool do
		local place = JobConfig.PLACES[id]
		if place == nil or used[id] then
			continue
		end
		local distance = flatDistance(place.position, ref)
		if distance >= minDist and distance <= maxDist then
			table.insert(inRange, { id = id, distance = distance })
		else
			local miss = if distance < minDist then minDist - distance else distance - maxDist
			if miss < fallbackMiss then
				fallbackMiss = miss
				fallbackId = id
			end
		end
	end
	if #inRange == 0 then
		return fallbackId
	end
	local count = #inRange
	if spec.nearest then
		table.sort(inRange, function(a, b)
			return a.distance < b.distance
		end)
		count = math.min(count, spec.nearest)
	end
	return inRange[random:NextInteger(1, count)].id
end

local function buildTask(player: Player, def: JobDef, origin: Vector3): ActiveTask?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	local template = pickTemplate(def)
	local steps: { TaskStepView } = {}
	local placeIds: { string } = {}
	local used: { [string]: boolean } = {}
	local ref = origin
	local travel = 0

	for index, spec in template.steps do
		local placeId: string? = nil
		if spec.place then
			placeId = spec.place
		elseif spec.sameAs then
			placeId = placeIds[spec.sameAs]
		elseif spec.pool then
			placeId = pickFromPool(spec, ref, used)
		end
		local place = if placeId then JobConfig.PLACES[placeId] else nil
		if placeId == nil or place == nil then
			warn(`[Job] Templat {def.id}/{template.id} langkah {index}: tempat tidak ditemukan`)
			return nil
		end
		used[placeId] = true
		placeIds[index] = placeId

		local yaw = place.yaw or 0
		local position = place.position
		if spec.offset then
			position += CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(spec.offset)
		end
		if index > 1 then
			travel += flatDistance(position, ref)
		end
		ref = position

		table.insert(steps, {
			position = position,
			origin = place.position,
			yaw = yaw,
			placeName = place.name,
			action = spec.action,
			text = (spec.text:gsub("{tempat}", place.name)),
			hold = spec.hold,
			prop = spec.prop,
			consume = spec.consume == true,
			fly = spec.fly,
			landed = spec.landed,
		})
	end

	local level = JobConfig.levelFor(getProgress(data, def.id).tasks)
	local pay = (template.basePay + template.payPerStud * travel) * JobConfig.payMultiplier(level)
	nextTaskId += 1
	return {
		view = {
			id = nextTaskId,
			jobId = def.id,
			title = template.title,
			pay = math.max(1, math.floor(pay + 0.5)),
			index = 1,
			steps = steps,
		},
		stepStartedAt = os.clock(),
		stepOrigin = origin,
	}
end

-- Memberi tugas baru sesuai pekerjaan aktif pemain (atau menghapus tugas jika
-- pemain tidak bekerja).
local function assignTask(player: Player)
	assignToken[player] = (assignToken[player] or 0) + 1
	active[player] = nil
	local data = DataService.getData(player)
	local def = if data then JobConfig.get(data.jobs.current) else nil
	if def then
		local root = getRoot(player)
		local origin = if root then root.Position else FALLBACK_ORIGIN
		active[player] = buildTask(player, def, origin)
	end
	sendTask(player)
end

local function assignTaskLater(player: Player, delaySeconds: number)
	local token = (assignToken[player] or 0) + 1
	assignToken[player] = token
	task.delay(delaySeconds, function()
		if assignToken[player] == token and player.Parent ~= nil then
			assignTask(player)
		end
	end)
end

-- ---------------------------------------------------------------- gaji

-- Total gaji pemain dalam jendela waktu terakhir (sekaligus membuang catatan lama).
local function recentEarnings(player: Player): number
	local list = earnings[player]
	if list == nil then
		return 0
	end
	local cutoff = os.clock() - JobConfig.EARN_WINDOW
	local kept: { Earning } = {}
	local total = 0
	for _, entry in list do
		if entry.time >= cutoff then
			table.insert(kept, entry)
			total += entry.amount
		end
	end
	earnings[player] = kept
	return total
end

local function payTask(player: Player, task_: ActiveTask): JobResult
	local data = DataService.getData(player)
	local def = JobConfig.get(task_.view.jobId)
	if data == nil or def == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local pay = task_.view.pay
	if recentEarnings(player) + pay > JobConfig.MAX_EARN_PER_WINDOW then
		warn(`[Job] {player.Name} melewati batas gaji per jendela waktu`)
		return result(false, "Kamu sudah bekerja keras! Istirahat sebentar, lalu coba lagi ya.")
	end
	if not EconomyService.addMoney(player, pay, "job:" .. def.id) then
		return result(false, "Gaji belum bisa dibayar, coba lagi.")
	end
	local list = earnings[player] or {}
	table.insert(list, { time = os.clock(), amount = pay })
	earnings[player] = list

	local progress = getProgress(data, def.id)
	local levelBefore = JobConfig.levelFor(progress.tasks)
	progress.tasks += 1
	progress.earned += pay
	completedEvent:Fire(player, def.id, pay)
	local levelAfter = JobConfig.levelFor(progress.tasks)
	publish(player)

	active[player] = nil
	sendTask(player)
	assignTaskLater(player, JobConfig.NEXT_TASK_DELAY)

	if levelAfter > levelBefore then
		return result(
			true,
			`Naik ke level {levelAfter}! Gaji {def.name} kamu bertambah. +{Format.money(pay)}`
		)
	end
	return result(true, `Tugas selesai! Kamu dapat {Format.money(pay)}`)
end

-- ---------------------------------------------------------------- remote handler

local function completeStep(player: Player, taskId: any, stepIndex: any): JobResult
	if type(taskId) ~= "number" or type(stepIndex) ~= "number" then
		return result(false, "Permintaan tidak valid.")
	end
	local task_ = active[player]
	if task_ == nil or task_.view.id ~= taskId or task_.view.index ~= stepIndex then
		sendTask(player) -- client tertinggal; kirim keadaan terbaru
		return result(false, "Tugasnya sudah berganti.")
	end
	local step = task_.view.steps[task_.view.index]
	local root = getRoot(player)
	if root == nil then
		return result(false, "Tunggu sampai karaktermu muncul ya.")
	end
	if step.fly then
		-- Langkah terbang: pemain harus menerbangkan pesawatnya sendiri dan lewat di dekat titiknya
		-- (tinggi bebas). Untuk mendarat, pesawat harus sudah di darat dan pelan.
		if not PlaneService.isFlying(player) then
			return result(false, "Terbangkan pesawatmu dulu ya.")
		end
		if flatDistance(root.Position, step.position) > step.fly then
			return result(false, "Pesawatmu masih terlalu jauh.")
		end
		if step.landed then
			local speed, onGround = PlaneService.getState(player)
			if not onGround or speed > PlaneConfig.TAKEOFF_SPEED * 0.8 then
				return result(false, "Pelankan pesawat sampai mendarat dulu ya.")
			end
		end
	elseif
		flatDistance(root.Position, step.position) > JobConfig.STEP_RADIUS
		or math.abs(root.Position.Y - step.position.Y) > 60
	then
		return result(false, "Kamu terlalu jauh. Dekati penandanya ya!")
	end

	local now = os.clock()
	local travel = flatDistance(step.position, task_.stepOrigin)
	local needed = travel / allowedSpeed(player) + step.hold * JobConfig.HOLD_SLACK
	local elapsed = now - task_.stepStartedAt
	if elapsed < needed then
		local wait = math.ceil(needed - elapsed)
		return result(false, `Wah, cepat sekali! Tunggu {wait} detik lagi ya.`)
	end

	if task_.view.index >= #task_.view.steps then
		return payTask(player, task_)
	end
	task_.view.index += 1
	task_.stepStartedAt = now
	task_.stepOrigin = step.position
	sendTask(player)
	return result(true, "")
end

local function selectJob(player: Player, jobId: any): JobResult
	if type(jobId) ~= "string" or #jobId > 32 then
		return result(false, "Pekerjaan tidak dikenal.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local def = JobConfig.get(jobId)
	if jobId ~= "" and def == nil then
		return result(false, "Pekerjaan tidak dikenal.")
	end
	if data.jobs.current == jobId then
		return result(
			false,
			if def then `Kamu sudah bekerja sebagai {def.name}.` else "Kamu sedang tidak bekerja."
		)
	end
	local now = os.clock()
	local last = lastSelect[player]
	if last and now - last < JobConfig.SELECT_COOLDOWN then
		return result(false, "Sebentar ya, baru saja ganti pekerjaan.")
	end
	lastSelect[player] = now

	data.jobs.current = jobId
	publish(player)
	VehicleService.onJobChanged(player, jobId)
	UniformService.refresh(player)
	assignTask(player)
	if def then
		-- Kendaraan dinas langsung dikeluarkan di dekat pemain; kalau tempatnya sempit, pemain
		-- diarahkan ke tombol di menu Pekerjaan.
		local spawnedOk, vehicleName = VehicleService.spawnForJob(player, def.id)
		if vehicleName then
			if spawnedOk then
				return result(
					true,
					`Kamu sekarang {def.name}! {vehicleName} sudah menunggu di dekatmu.`
				)
			end
			return result(
				true,
				`Kamu sekarang {def.name}! Cari tempat lapang, lalu tekan "Keluarkan {vehicleName}" di menu Pekerjaan.`
			)
		end
		if def.id == PlaneConfig.JOB then
			return result(
				true,
				`Kamu sekarang {def.name}! Ambil pesawat di papan Pilot di landasan bandara.`
			)
		end
		return result(true, `Kamu sekarang {def.name}! Ikuti penanda kuning.`)
	end
	return result(true, "Kamu berhenti bekerja. Terima kasih sudah membantu kota!")
end

local function skipTask(player: Player): JobResult
	if active[player] == nil then
		return result(false, "Belum ada tugas. Pilih pekerjaan dulu ya!")
	end
	local now = os.clock()
	local last = lastSkip[player]
	if last and now - last < JobConfig.SKIP_COOLDOWN then
		local wait = math.ceil(JobConfig.SKIP_COOLDOWN - (now - last))
		return result(false, `Tugas bisa diganti lagi dalam {wait} detik.`)
	end
	lastSkip[player] = now
	assignTask(player)
	return result(true, "Ini tugas baru untukmu!")
end

-- ---------------------------------------------------------------- pengawas posisi

-- Posisi karakter dikendalikan client, jadi server mengawasinya: pemain yang
-- berpindah jauh lebih cepat dari kendaraan mana pun kehilangan tugasnya
-- (tanpa hukuman lain) dan mendapat tugas baru dari posisi barunya.
local function watchPositions()
	while true do
		task.wait(1)
		local now = os.clock()
		for player in active do
			local root = getRoot(player)
			local character = player.Character
			if root == nil or character == nil then
				tracks[player] = nil
				continue
			end
			local track = tracks[player]
			tracks[player] = { character = character, position = root.Position, time = now }
			if track == nil or track.character ~= character then
				continue -- baru muncul / respawn
			end
			local limit = JobConfig.TELEPORT_SPEED * (now - track.time) + JobConfig.TELEPORT_SLACK
			if flatDistance(root.Position, track.position) > limit then
				warn(`[Job] {player.Name} berpindah tidak wajar; tugas diulang`)
				assignTask(player)
				EconomyService.notify(
					player,
					"Posisimu berubah mendadak, jadi tugasnya diganti ya."
				)
			end
		end
	end
end

-- ---------------------------------------------------------------- bootstrap

local function wrap(label: string, handler: (Player, any, any) -> JobResult)
	return function(player: Player, a: any, b: any): JobResult
		if not allowCall(player) then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		local ok, value = pcall(handler, player, a, b)
		if ok then
			return value
		end
		warn(`[Job] {label} error: {tostring(value)}`)
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

local function onProfileLoaded(player: Player)
	publish(player)
	local data = DataService.getData(player)
	if data == nil or JobConfig.get(data.jobs.current) == nil then
		return
	end
	-- Lanjutkan pekerjaan terakhir setelah karakter muncul.
	task.spawn(function()
		local deadline = os.clock() + 15
		while getRoot(player) == nil and os.clock() < deadline and player.Parent ~= nil do
			task.wait(0.5)
		end
		if player.Parent ~= nil and active[player] == nil then
			assignTask(player)
		end
	end)
end

function JobService.getJob(player: Player): string
	local data = DataService.getData(player)
	return if data then data.jobs.current else ""
end

function JobService.init()
	taskRemote = Net.event(Net.Names.JobTask)
	Net.func(Net.Names.JobSelect).OnServerInvoke = wrap("Select", selectJob)
	Net.func(Net.Names.JobStep).OnServerInvoke = wrap("Step", completeStep)
	Net.func(Net.Names.JobSkip).OnServerInvoke = wrap("Skip", skipTask)
	Net.event(Net.Names.JobSync).OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		local last = lastSync[player]
		if last and now - last < 1 then
			return
		end
		lastSync[player] = now
		sendTask(player)
	end)
end

function JobService.start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			onProfileLoaded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		active[player] = nil
		earnings[player] = nil
		tracks[player] = nil
		lastCall[player] = nil
		lastSelect[player] = nil
		lastSkip[player] = nil
		lastSync[player] = nil
		assignToken[player] = nil
	end)
	task.spawn(watchPositions)
end

return JobService
