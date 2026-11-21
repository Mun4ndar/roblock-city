--!strict
-- VehicleEffectsController: efek tampilan mobil, dibuat di client untuk setiap
-- kendaraan yang terlihat (tidak membebani server):
--   * asap knalpot: makin tebal saat melaju dan saat tancap gas
--   * bekas ban + debu: saat mobil tergelincir ke samping, mengerem keras, atau
--     tancap gas dari diam
-- Angka-angkanya ada di tabel TUNING supaya mudah disetel.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local VehicleEffectsController = {}

local TUNING = {
	updateSeconds = 0.08,
	exhaustIdle = 5, -- partikel/detik saat diam dengan pengemudi
	exhaustPerSpeed = 0.3, -- tambahan per stud/detik
	exhaustBoost = 30, -- tambahan saat tancap gas
	boostAcceleration = 14, -- stud/detik^2: di atas ini dianggap tancap gas
	slideSpeed = 9, -- kecepatan menyamping (stud/detik) yang meninggalkan bekas ban
	brakeDeceleration = 40, -- perlambatan yang meninggalkan bekas ban
	brakeMinSpeed = 12,
	launchAcceleration = 24, -- tancap gas dari pelan juga meninggalkan bekas
	launchMaxSpeed = 20,
	markSeconds = 5, -- lama bekas ban terlihat
	dustRate = 22,
}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type Fx = {
	chassis: BasePart,
	seat: VehicleSeat?,
	exhaust: ParticleEmitter,
	dust: ParticleEmitter,
	trails: { Trail },
	lastSpeed: number,
}

local effects: { [Model]: Fx } = {}
local elapsed = 0

local function attachment(parent: BasePart, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "FxAttachment"
	a.Position = position
	a.Parent = parent
	return a
end

local function smokeEmitter(parent: Attachment, color: Color3, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.35),
		NumberSequenceKeypoint.new(1, size),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.EmissionDirection = Enum.NormalId.Back
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 0
	e.Parent = parent
	return e
end

local function setup(model: Instance)
	if not model:IsA("Model") or effects[model] then
		return
	end
	local chassis = model:WaitForChild("Chassis", 10)
	local def = VehicleConfig.get(model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
	if chassis == nil or not chassis:IsA("BasePart") or def == nil or effects[model] then
		return
	end
	local b = def.body
	local groundY = -(b.clearance + 0.3) + 0.1 -- permukaan jalan relatif ke tengah sasis
	local rearZ = b.wheelbase / 2
	local wheelX = b.width / 2 - b.wheelWidth / 2

	local exhaust = smokeEmitter(
		attachment(chassis, Vector3.new(b.width / 2 - 1.5, -0.1, b.length / 2 - 0.2)),
		Color3.fromRGB(150, 150, 156),
		1.8
	)
	local dust = smokeEmitter(
		attachment(chassis, Vector3.new(0, groundY + 0.4, rearZ + 1)),
		Color3.fromRGB(196, 190, 176),
		3.2
	)
	dust.SpreadAngle = Vector2.new(50, 20)

	local trails: { Trail } = {}
	for _, side in { -1, 1 } do
		local half = b.wheelWidth * 0.42
		local trail = Instance.new("Trail")
		trail.Name = "BekasBan"
		trail.Attachment0 = attachment(chassis, Vector3.new(side * wheelX - half, groundY, rearZ))
		trail.Attachment1 = attachment(chassis, Vector3.new(side * wheelX + half, groundY, rearZ))
		trail.Color = ColorSequence.new(Color3.fromRGB(26, 26, 30))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Lifetime = TUNING.markSeconds
		trail.MinLength = 0.3
		trail.FaceCamera = false
		trail.LightEmission = 0
		trail.LightInfluence = 1
		trail.Enabled = false
		trail.Parent = chassis
		table.insert(trails, trail)
	end

	local seat = model:FindFirstChild("DriveSeat")
	effects[model] = {
		chassis = chassis,
		seat = if seat and seat:IsA("VehicleSeat") then seat else nil,
		exhaust = exhaust,
		dust = dust,
		trails = trails,
		lastSpeed = 0,
	}
end

local function update(dt: number)
	for model, fx in effects do
		local chassis = fx.chassis
		if model.Parent == nil or chassis.Parent == nil then
			effects[model] = nil
			continue
		end
		local velocity = chassis.AssemblyLinearVelocity
		local speed = velocity.Magnitude
		local sideways = math.abs(velocity:Dot(chassis.CFrame.RightVector))
		local acceleration = (speed - fx.lastSpeed) / dt
		fx.lastSpeed = speed
		local driven = fx.seat ~= nil and fx.seat.Occupant ~= nil

		local rate = 0
		if driven then
			rate = TUNING.exhaustIdle + math.min(speed, 90) * TUNING.exhaustPerSpeed
			if acceleration > TUNING.boostAcceleration then
				rate += TUNING.exhaustBoost
			end
		end
		fx.exhaust.Rate = rate

		local skidding = sideways > TUNING.slideSpeed
			or (acceleration < -TUNING.brakeDeceleration and speed > TUNING.brakeMinSpeed)
			or (
				driven
				and acceleration > TUNING.launchAcceleration
				and speed < TUNING.launchMaxSpeed
			)
		for _, trail in fx.trails do
			trail.Enabled = skidding
		end
		fx.dust.Rate = if skidding then TUNING.dustRate else 0
	end
end

function VehicleEffectsController.start()
	for _, model in CollectionService:GetTagged(VehicleConfig.TAG_VEHICLE) do
		task.spawn(setup, model)
	end
	CollectionService:GetInstanceAddedSignal(VehicleConfig.TAG_VEHICLE)
		:Connect(function(model: Instance)
			task.spawn(setup, model)
		end)
	CollectionService:GetInstanceRemovedSignal(VehicleConfig.TAG_VEHICLE)
		:Connect(function(model: Instance)
			effects[model :: Model] = nil
		end)
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TUNING.updateSeconds then
			update(elapsed)
			elapsed = 0
		end
	end)
end

return VehicleEffectsController
