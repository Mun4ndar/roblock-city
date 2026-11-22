--!strict
-- JobController: keadaan tugas pekerjaan di client + penanda di dunia.
-- Server mengirim tugas (remote JobTask); controller ini menampilkan penanda
-- kuning, tombol tahan (ProximityPrompt), dan hiasan tugas. Saat tombol selesai
-- ditahan, client hanya MEMINTA server menyelesaikan langkah; server yang
-- memeriksa jarak dan waktu lalu membayar.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local JobProps = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("JobProps"))

type TaskView = JobConfig.TaskView
type TaskStepView = JobConfig.TaskStepView

-- Benda yang ketinggiannya perlu disesuaikan dengan tanah begitu area termuat.
type Grounded = { position: Vector3, apply: (y: number) -> (), done: boolean }

local player = Players.LocalPlayer

local JobController = {}

local MARKER_COLOR = Color3.fromRGB(255, 204, 0)

local changed = Instance.new("BindableEvent")
-- Terpicu setiap kali tugas / langkah aktif berubah.
JobController.Changed = changed.Event

local currentTask: TaskView? = nil
local folder: Folder
local marker: Part
local pillar: Part
local promptAnchor: Part
local prompt: ProximityPrompt
local distanceLabel: TextLabel
local props: { [number]: Model } = {} -- indeks langkah -> prop
local grounded: { Grounded } = {}
local busy = false
local spray: Part? = nil -- semburan air saat menahan tombol di tugas pemadam
local pilotBoarded: number? = nil -- id tugas pilot yang penumpangnya sudah naik
local lastFlyTry = 0
local passengers: { Model } = {} -- penumpang yang terlihat duduk di bus (pekerjaan Sopir Bus)

-- Titik duduk penumpang relatif ke sasis bus (x kiri/kanan, z dari depan ke belakang).
local PASSENGER_SPOTS = {
	Vector3.new(-1.9, 0, -4),
	Vector3.new(1.9, 0, -1),
	Vector3.new(-1.9, 0, 2),
	Vector3.new(1.9, 0, 5),
}

local function clearPassengers()
	for _, model in passengers do
		model:Destroy()
	end
	table.clear(passengers)
end

-- Kendaraan milik pemain yang sedang dikeluarkan.
local function myVehicle(): Model?
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, model in vehicles:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
				return model
			end
		end
	end
	return nil
end

-- Penumpang naik: beberapa warga tampak duduk di dalam bus dan ikut bergerak bersama bus.
-- Hanya tampilan di layar sopirnya (seperti hiasan tugas lain).
local function boardPassengers(seed: number)
	clearPassengers()
	local vehicle = myVehicle()
	local chassis = if vehicle then vehicle:FindFirstChild("Chassis") else nil
	if
		vehicle == nil
		or chassis == nil
		or not chassis:IsA("BasePart")
		or vehicle:GetAttribute("VehicleId") ~= "bus"
	then
		return
	end
	for index, spot in PASSENGER_SPOTS do
		local model = JobProps.build("person", chassis.CFrame * CFrame.new(spot), seed + index * 7)
		model.Name = "Penumpang"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = chassis
				weld.Part1 = d
				weld.Parent = d
			end
		end
		model.Parent = vehicle
		table.insert(passengers, model)
	end
end

-- Penumpang pesawat: satu warga di kursi kopilot (terlihat lewat kaca kokpit).
local function seatInPlane(plane: Instance, hull: BasePart, seed: number)
	clearPassengers()
	for index, spot in { Vector3.new(0.95, -2.3, -8.2) } do
		local model = JobProps.build("person", hull.CFrame * CFrame.new(spot), seed + index * 7)
		model.Name = "Penumpang"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hull
				weld.Part1 = d
				weld.Parent = d
			end
		end
		model.Parent = plane
		table.insert(passengers, model)
	end
end

-- ---------------------------------------------------------------- util

local function invoke(remoteName: string, a: any?, b: any?): Types.JobResult
	local ok, value = pcall(function(): any
		return Net.func(remoteName):InvokeServer(a, b)
	end)
	if ok and type(value) == "table" and type(value.message) == "string" then
		return value
	end
	return { ok = false, message = "Gagal terhubung, coba lagi." }
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Mencari tinggi tanah di bawah `position`; nil jika area itu belum termuat.
local function groundHeight(position: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		table.insert(ignore, vehicles)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

local function tryGround(entry: Grounded)
	local y = groundHeight(entry.position)
	if y == nil then
		return
	end
	entry.done = true
	-- Selisih besar berarti sinarnya mengenai atap/pohon; pakai tinggi dari JobConfig.
	if math.abs(y - entry.position.Y) <= 8 then
		entry.apply(y)
	end
end

local function addGrounded(position: Vector3, apply: (y: number) -> ())
	local entry: Grounded = { position = position, apply = apply, done = false }
	table.insert(grounded, entry)
	tryGround(entry)
end

-- ---------------------------------------------------------------- penanda & prop

local function clearProps()
	for _, model in props do
		model:Destroy()
	end
	table.clear(props)
	table.clear(grounded)
end

local function buildProps(task_: TaskView)
	for index, step in task_.steps do
		local kind = step.prop
		if kind == nil or index < task_.index then
			continue
		end
		local facing = CFrame.Angles(0, math.rad(step.yaw), 0)
		-- Mobil berdiri di titik tempat; prop lain sedikit di belakang penanda.
		local position = if kind == "car"
			then step.origin
			else step.position + facing:VectorToWorldSpace(Vector3.new(0, 0, -3))
		local model = JobProps.build(kind, CFrame.new(position) * facing, task_.id * 31 + index)
		model.Parent = folder
		props[index] = model
		addGrounded(position, function(y: number)
			model:PivotTo(CFrame.new(position.X, y, position.Z) * facing)
		end)
	end
end

local function placeMarker(step: TaskStepView)
	local function apply(y: number)
		marker.CFrame = CFrame.new(step.position.X, y + 0.3, step.position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		pillar.CFrame = CFrame.new(step.position.X, y + 35, step.position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		promptAnchor.CFrame = CFrame.new(step.position.X, y + 3, step.position.Z)
	end
	local fly = step.fly
	prompt.Enabled = fly == nil
	if fly then
		-- Langkah terbang: lingkaran besar di tanah + tiang cahaya tinggi, tanpa tombol.
		local ringSize = if step.landed then 60 else math.min(fly * 1.6, 160)
		marker.Size = Vector3.new(0.4, ringSize, ringSize)
		pillar.Size = Vector3.new(520, 5, 5)
		marker.CFrame = CFrame.new(step.position.X, step.position.Y + 0.6, step.position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		pillar.CFrame = CFrame.new(step.position.X, step.position.Y + 260, step.position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		promptAnchor.CFrame = CFrame.new(
			step.position.X,
			step.position.Y + (if step.landed then 12 else 150),
			step.position.Z
		)
	else
		marker.Size = Vector3.new(0.4, 10, 10)
		pillar.Size = Vector3.new(70, 1.2, 1.2)
		apply(step.position.Y)
		addGrounded(step.position, apply)
	end
	prompt.ActionText = step.action
	prompt.ObjectText = step.placeName
	prompt.HoldDuration = step.hold
	marker.Parent = folder
	promptAnchor.Parent = folder
end

local function hideMarker()
	marker.Parent = nil
	promptAnchor.Parent = nil
end

local function onTask(task_: TaskView?)
	local previous = currentTask
	currentTask = task_
	if task_ == nil or (previous ~= nil and previous.id ~= task_.id) then
		clearPassengers()
	end
	if task_ == nil then
		clearProps()
		hideMarker()
		changed:Fire()
		return
	end
	if previous == nil or previous.id ~= task_.id then
		clearProps()
		buildProps(task_)
	else
		-- Langkah maju: buang prop langkah yang sudah selesai jika sekali pakai.
		for index, model in props do
			if index < task_.index and task_.steps[index].consume then
				model:Destroy()
				props[index] = nil
			end
		end
	end
	local step = task_.steps[task_.index]
	if step then
		placeMarker(step)
	else
		hideMarker()
	end
	changed:Fire()
end

local function isFireProp(kind: string?): boolean
	return kind == "fire" or kind == "kios"
end

local function stopSpray()
	if spray then
		spray:Destroy()
		spray = nil
	end
end

-- Menahan tombol di tugas pemadam: semprotkan air dari pemain ke arah api.
local function startSpray()
	stopSpray()
	local task_ = currentTask
	local step = if task_ then task_.steps[task_.index] else nil
	local model = if task_ then props[task_.index] else nil
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if step == nil or model == nil or root == nil or not isFireProp(step.prop) then
		return
	end
	local from = (root.CFrame * CFrame.new(0.8, 0.4, -1.2)).Position
	local nozzle = JobProps.waterSpray(from, model:GetPivot().Position)
	nozzle.Parent = folder
	spray = nozzle
end

local function onPromptTriggered()
	local task_ = currentTask
	if busy or task_ == nil then
		return
	end
	busy = true
	local stepIndex = task_.index
	local res = invoke(Net.Names.JobStep, task_.id, task_.index)
	stopSpray()
	-- Api yang berhasil dipadamkan mengepulkan uap dulu sebelum hilang.
	local burning = props[stepIndex]
	local finished = task_.steps[stepIndex]
	if res.ok and burning and finished and finished.consume and isFireProp(finished.prop) then
		props[stepIndex] = nil
		JobProps.extinguish(burning)
	end
	-- Sopir bus: penumpang naik saat dijemput, turun sebagian di tiap halte berikutnya.
	-- Pilot: seorang penumpang tampak duduk di kokpit sampai pesawat mendarat lagi.
	if res.ok and task_.jobId == "pilot" and finished then
		if finished.prop == "person" then
			pilotBoarded = task_.id
		elseif stepIndex >= #task_.steps then
			pilotBoarded = nil
			clearPassengers()
		end
	end
	if res.ok and task_.jobId == "sopir" and finished then
		if finished.prop == "person" then
			boardPassengers(task_.id)
		elseif stepIndex >= #task_.steps then
			clearPassengers()
		else
			for _ = 1, math.ceil(#passengers / 2) do
				local leaving = table.remove(passengers)
				if leaving then
					leaving:Destroy()
				end
			end
		end
	end
	-- Langkah terbang dicoba otomatis berulang; penolakannya tidak perlu ditampilkan.
	if res.message ~= "" and (res.ok or finished == nil or finished.fly == nil) then
		HudController.toast(res.message)
	end
	busy = false
end

local function buildMarker()
	folder = Instance.new("Folder")
	folder.Name = "JobLocal"
	folder.Parent = Workspace

	marker = Instance.new("Part")
	marker.Name = "JobMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.4, 10, 10)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = MARKER_COLOR
	marker.Transparency = 0.45

	-- Tiang cahaya supaya penanda terlihat dari jauh.
	pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(70, 1.2, 1.2)
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanTouch = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = MARKER_COLOR
	pillar.Transparency = 0.6
	pillar.Parent = marker

	promptAnchor = Instance.new("Part")
	promptAnchor.Name = "JobPrompt"
	promptAnchor.Size = Vector3.new(1, 1, 1)
	promptAnchor.Transparency = 1
	promptAnchor.Anchored = true
	promptAnchor.CanCollide = false
	promptAnchor.CanTouch = false
	promptAnchor.CanQuery = false

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JobStepPrompt"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = JobConfig.PROMPT_DISTANCE
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = promptAnchor
	prompt.Triggered:Connect(onPromptTriggered)
	prompt.PromptButtonHoldBegan:Connect(startSpray)
	prompt.PromptButtonHoldEnded:Connect(function()
		-- Kalau tombol dilepas sebelum selesai, air berhenti (kalau selesai, onPromptTriggered yang menghentikan).
		if not busy then
			stopSpray()
		end
	end)

	-- Papan jarak yang terlihat dari jauh (menembus bangunan).
	local board = Instance.new("BillboardGui")
	board.Name = "Waypoint"
	board.AlwaysOnTop = true
	board.Size = UDim2.fromOffset(110, 46)
	board.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	distanceLabel = Instance.new("TextLabel")
	distanceLabel.Size = UDim2.fromScale(1, 1)
	distanceLabel.BackgroundColor3 = MARKER_COLOR
	distanceLabel.BackgroundTransparency = 0.1
	distanceLabel.Font = Enum.Font.FredokaOne
	distanceLabel.TextSize = 20
	distanceLabel.TextColor3 = Color3.fromRGB(40, 48, 60)
	distanceLabel.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = distanceLabel
	distanceLabel.Parent = board
	board.Parent = promptAnchor
end

-- ---------------------------------------------------------------- API client

function JobController.getTask(): TaskView?
	return currentTask
end

-- Posisi penanda langkah aktif, atau nil jika tidak ada tugas.
function JobController.getTarget(): Vector3?
	local task_ = currentTask
	local step = if task_ then task_.steps[task_.index] else nil
	return if step then promptAnchor.Position else nil
end

-- Jarak mendatar (stud) dari pemain ke penanda.
function JobController.getDistance(): number?
	local target = JobController.getTarget()
	local position = rootPosition()
	if target == nil or position == nil then
		return nil
	end
	return ((target - position) * Vector3.new(1, 0, 1)).Magnitude
end

function JobController.selectJob(jobId: string): Types.JobResult
	return invoke(Net.Names.JobSelect, jobId)
end

function JobController.skipTask(): Types.JobResult
	return invoke(Net.Names.JobSkip)
end

-- ---------------------------------------------------------------- bootstrap

function JobController.init()
	buildMarker()
end

function JobController.start()
	Net.event(Net.Names.JobTask).OnClientEvent:Connect(function(task_: any)
		if task_ == nil or (type(task_) == "table" and type(task_.steps) == "table") then
			onTask(task_)
		end
	end)
	-- Tugas mungkin sudah dikirim sebelum listener terpasang.
	Net.event(Net.Names.JobSync):FireServer()

	while true do
		task.wait(0.25)
		local distance = JobController.getDistance()
		local task_ = currentTask
		local step = if task_ then task_.steps[task_.index] else nil
		-- Pilot: penumpang tampak di kokpit selama penerbangan (hanya di layar pilotnya).
		if task_ == nil or task_.jobId ~= "pilot" then
			pilotBoarded = nil
		else
			local plane = Workspace:FindFirstChild("Plane_" .. player.UserId)
			local hull = if plane then plane:FindFirstChild("Hull") else nil
			if pilotBoarded == task_.id and hull and hull:IsA("BasePart") then
				if #passengers == 0 then
					seatInPlane(plane :: Instance, hull, task_.id)
				end
			elseif #passengers > 0 then
				clearPassengers()
			end
		end
		-- Langkah terbang selesai sendiri begitu pesawat cukup dekat (server yang memeriksa).
		if
			step
			and step.fly
			and distance
			and not busy
			and distance <= step.fly * 0.95
			and os.clock() - lastFlyTry > 1
		then
			lastFlyTry = os.clock()
			task.spawn(onPromptTriggered)
		end
		if distance then
			distanceLabel.Text = string.format("%d m", math.floor(distance / 3.5 + 0.5))
		end
		-- Sesuaikan tinggi penanda/prop begitu tanah di sekitarnya termuat.
		for _, entry in grounded do
			if not entry.done then
				tryGround(entry)
			end
		end
	end
end

return JobController
