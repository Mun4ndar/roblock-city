--!strict
-- VehicleController: mengemudikan mobil yang sedang diduduki pemain.
-- Input dibaca dari VehicleSeat.ThrottleFloat / SteerFloat, yang diisi skrip
-- kontrol bawaan Roblox untuk keyboard (WASD/panah), gamepad, DAN thumbstick
-- sentuh di HP, jadi satu kode jalan di semua perangkat.
-- Client pengemudi memegang network ownership mobilnya, sehingga mengubah
-- engsel roda di sini langsung terasa tanpa jeda. Server tetap memutuskan
-- siapa yang boleh duduk dan mengawasi kecepatan.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

type VehicleDef = VehicleConfig.VehicleDef

type Driving = {
	def: VehicleDef,
	seat: VehicleSeat,
	chassis: BasePart,
	motors: { HingeConstraint },
	steers: { Attachment }, -- attachment poros roda depan di chassis
	steerAngle: number, -- sudut belok saat ini (derajat)
	upsideDownFor: number,
}

local player = Players.LocalPlayer

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local VehicleController = {}

-- Arah putar engsel/attachment terhadap arah maju mobil (ditentukan oleh orientasi attachment di VehicleBuilder).
local DRIVE_SIGN = -1
local STEER_SIGN = -1
local COAST_DECEL = 14 -- stud/dtk^2 saat gas dilepas
local MAX_LATERAL_ACCEL = 70 -- batas belok: makin kencang makin kecil sudut setirnya
local STEER_RATE = 85 -- derajat/detik, kecepatan setir berputar saat pelan
local STEER_RETURN = 2.2 -- setir kembali lurus lebih cepat daripada berbelok
local STEER_CURVE = 1.6 -- > 1: gerakan kecil thumbstick/tombol berbelok lebih halus
local FLIP_AFTER = 1.5 -- detik terbalik sebelum minta dibalikkan

local driving: Driving? = nil
local stepConnection: RBXScriptConnection? = nil

local gui: ScreenGui
local speedLabel: TextLabel
local flipEvent: RemoteEvent

-- ---------------------------------------------------------------- UI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "VehicleHud"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Speedometer"
	UiScale.attach(panel)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.fromOffset(170, 64)
	panel.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
	panel.BackgroundTransparency = 0.2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	panel.Parent = gui

	speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "Speed"
	speedLabel.BackgroundTransparency = 1
	speedLabel.Size = UDim2.new(1, 0, 0, 40)
	speedLabel.Font = Enum.Font.FredokaOne
	speedLabel.TextSize = 30
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.Text = "0 km/j"
	speedLabel.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(0, 38)
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(220, 226, 235)
	hint.Text = "Lompat untuk turun"
	hint.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- ---------------------------------------------------------------- kemudi

local function step(dt: number)
	local d = driving
	if d == nil then
		return
	end
	local chassis = d.chassis
	if chassis.Parent == nil then
		return
	end
	local def = d.def
	-- Gas + belok bersamaan (W+D atau thumbstick miring) memberi 0,7 pada tiap sumbu
	-- karena vektor gerak dinormalkan; kalikan supaya tetap bisa gas/belok penuh.
	local throttle = math.clamp(d.seat.ThrottleFloat * 1.42, -1, 1)
	local steerRaw = math.clamp(d.seat.SteerFloat * 1.42, -1, 1)
	local steer = math.sign(steerRaw) * math.abs(steerRaw) ^ STEER_CURVE
	local speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
	local radius = def.body.wheelRadius

	local target = 0
	local accel = COAST_DECEL
	if throttle > 0.05 then
		if speed < -3 then
			accel = def.brake -- sedang mundur: rem dulu
		else
			target = def.maxSpeed * throttle
			accel = def.acceleration
		end
	elseif throttle < -0.05 then
		if speed > 3 then
			accel = def.brake
		else
			target = def.reverseSpeed * throttle
			accel = def.acceleration
		end
	end
	for _, motor in d.motors do
		motor.AngularVelocity = DRIVE_SIGN * target / radius
		motor.MotorMaxAcceleration = accel / radius
	end

	-- Makin kencang makin kecil sudut belok (radius belok dibatasi percepatan samping).
	local limit =
		math.deg(math.atan(def.body.wheelbase * MAX_LATERAL_ACCEL / math.max(speed * speed, 1)))
	local wanted = STEER_SIGN * steer * math.min(def.steerAngle, limit)
	-- Setir berputar lebih pelan saat kencang supaya mobil tidak mudah oleng di HP.
	local rate = STEER_RATE * math.clamp(1 - math.abs(speed) / 140, 0.4, 1)
	if math.abs(wanted) < math.abs(d.steerAngle) then
		rate *= STEER_RETURN
	end
	local maxStep = rate * dt
	d.steerAngle += math.clamp(wanted - d.steerAngle, -maxStep, maxStep)
	for _, att in d.steers do
		att.Orientation = Vector3.new(0, d.steerAngle, 0)
	end

	speedLabel.Text = string.format("%d km/j", math.floor(math.abs(speed) + 0.5))

	-- Mobil terbalik: minta server membalikkannya.
	if chassis.CFrame.UpVector.Y < 0.3 and math.abs(speed) < 10 then
		d.upsideDownFor += dt
		if d.upsideDownFor > FLIP_AFTER then
			d.upsideDownFor = 0
			flipEvent:FireServer()
		end
	else
		d.upsideDownFor = 0
	end
end

local function stopDriving()
	local d = driving
	driving = nil
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	gui.Enabled = false
	if d then
		-- kembalikan engsel ke keadaan diam (rem parkir)
		for _, motor in d.motors do
			motor.AngularVelocity = 0
			motor.MotorMaxAcceleration = 60
		end
		for _, att in d.steers do
			att.Orientation = Vector3.zero
		end
	end
end

local function startDriving(seat: VehicleSeat)
	local model = seat.Parent
	if model == nil or not model:IsA("Model") then
		return
	end
	local def = VehicleConfig.get(model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
	local chassis = model.PrimaryPart
	if def == nil or chassis == nil then
		return
	end
	local motors: { HingeConstraint } = {}
	local steers: { Attachment } = {}
	for _, key in { "FL", "FR", "RL", "RR" } do
		local motor = chassis:WaitForChild("Motor" .. key, 5)
		if motor and motor:IsA("HingeConstraint") then
			table.insert(motors, motor)
		end
	end
	for _, key in { "FL", "FR" } do
		local att = chassis:WaitForChild("Steer" .. key, 5)
		if att and att:IsA("Attachment") then
			table.insert(steers, att)
		end
	end
	if #motors == 0 then
		warn("[Vehicle] engsel roda tidak ditemukan")
		return
	end

	stopDriving()
	driving = {
		def = def,
		seat = seat,
		chassis = chassis,
		motors = motors,
		steers = steers,
		steerAngle = 0,
		upsideDownFor = 0,
	}
	gui.Enabled = true
	stepConnection = RunService.PreSimulation:Connect(step)
end

-- Selama duduk di kendaraan (mobil, perahu, pesawat), tombol "Naik/Kemudikan" kendaraan itu
-- disembunyikan di layar pemain ini supaya tidak mengganggu. Dikembalikan saat turun.
local hiddenPrompts: { ProximityPrompt } = {}
local lastSeat: BasePart? = nil

local function showPrompts()
	for _, prompt in hiddenPrompts do
		if prompt.Parent then
			prompt.Enabled = true
		end
	end
	table.clear(hiddenPrompts)
end

local function hidePrompts(model: Instance)
	showPrompts()
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "EnterPrompt" and d.Enabled then
			d.Enabled = false
			table.insert(hiddenPrompts, d)
		end
	end
end

-- Turun dari kendaraan: karakter dipindah berdiri tegak di samping kendaraan, tidak terjatuh.
local function standBeside(humanoid: Humanoid, seat: BasePart)
	local character = humanoid.Parent
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local model = seat.Parent
	if root == nil or not root:IsA("BasePart") or model == nil or not model:IsA("Model") then
		return
	end
	local pivot = model:GetPivot()
	local half = model:GetExtentsSize().X / 2
	local localSeat = pivot:PointToObjectSpace(seat.Position)
	local side = if localSeat.X < 0 then -1 else 1
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, character :: Instance }
	local target: Vector3? = nil
	for _, trySide in { side, -side } do
		local out = pivot.RightVector * trySide * (half - math.abs(localSeat.X) + 3)
		local from = seat.Position + Vector3.new(0, 2.5, 0)
		if Workspace:Raycast(from, out, params) == nil then
			target = from + out
			break
		end
	end
	local position = target or (seat.Position + Vector3.new(0, 6, 0)) -- kedua sisi terhalang: naik ke atas
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(position, position + look.Unit)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function onSeatChanged(humanoid: Humanoid)
	local seat = humanoid.SeatPart
	if seat and seat.Parent then
		lastSeat = seat
		hidePrompts(seat.Parent)
	else
		showPrompts()
		local previous = lastSeat
		lastSeat = nil
		if previous and previous.Parent and humanoid.Health > 0 then
			task.defer(standBeside, humanoid, previous)
		end
	end
	if
		seat
		and seat:IsA("VehicleSeat")
		and seat.Parent
		and seat.Parent:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID)
	then
		task.spawn(startDriving, seat)
	else
		stopDriving()
	end
end

local function onCharacter(character: Model)
	stopDriving()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		-- karakter tidak perlu tersandung/terguling di game ini
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			onSeatChanged(humanoid)
		end)
		humanoid.Died:Connect(stopDriving)
		onSeatChanged(humanoid)
	end
end

-- ---------------------------------------------------------------- bootstrap

function VehicleController.isDriving(): boolean
	return driving ~= nil
end

function VehicleController.init()
	buildGui()
end

function VehicleController.start()
	flipEvent = Net.event(Net.Names.VehicleFlip)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return VehicleController
