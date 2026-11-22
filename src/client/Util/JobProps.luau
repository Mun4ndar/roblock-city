--!strict
-- JobProps: hiasan tugas pekerjaan (paket, mobil pelanggan, api kecil, warga,
-- kucing di pohon, kerucut lalu lintas). Dibuat di client pemain yang sedang
-- bertugas saja, jadi tidak membebani server atau pemain lain.
-- Titik asal setiap prop = permukaan tanah.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local JobProps = {}

local SHIRTS = {
	Color3.fromRGB(235, 90, 90),
	Color3.fromRGB(90, 150, 235),
	Color3.fromRGB(64, 190, 100),
	Color3.fromRGB(255, 184, 0),
	Color3.fromRGB(170, 110, 220),
	Color3.fromRGB(255, 140, 180),
}
local SKINS = {
	Color3.fromRGB(255, 214, 170),
	Color3.fromRGB(224, 172, 120),
	Color3.fromRGB(168, 116, 76),
}
local CAR_COLORS = {
	Color3.fromRGB(235, 90, 90),
	Color3.fromRGB(90, 150, 235),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(64, 190, 100),
	Color3.fromRGB(150, 155, 165),
}

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function package(model: Model)
	part(model, {
		Name = "Box",
		Size = Vector3.new(2.6, 2.2, 2.6),
		CFrame = CFrame.new(0, 1.1, 0),
		Color = Color3.fromRGB(196, 150, 96),
	})
	part(model, {
		Name = "Tape",
		Size = Vector3.new(2.7, 2.3, 0.5),
		CFrame = CFrame.new(0, 1.1, 0),
		Color = Color3.fromRGB(240, 226, 190),
	})
end

-- Api + asap di sebuah part (dipakai kios terbakar).
local function burn(host: BasePart, flameSize: number, smokeSize: number)
	local flames = Instance.new("Fire")
	flames.Size = flameSize
	flames.Heat = flameSize + 4
	flames.Parent = host
	local smoke = Instance.new("Smoke")
	smoke.Size = smokeSize
	smoke.RiseVelocity = 9
	smoke.Opacity = 0.45
	smoke.Color = Color3.fromRGB(70, 70, 76)
	smoke.Parent = host
end

-- Kios kayu yang terbakar: api di atap dan di dalam, asap tebal, cahaya jingga.
-- Berdiri sedikit di belakang titik prop supaya tidak menutupi penanda tugas.
local function kiosk(model: Model)
	local z = -4
	local wood = Color3.fromRGB(150, 104, 66)
	local burnt = Color3.fromRGB(62, 48, 42)
	local planks = Enum.Material.WoodPlanks
	part(model, {
		Name = "Lantai",
		Size = Vector3.new(9, 0.5, 6),
		CFrame = CFrame.new(0, 0.25, z),
		Color = burnt,
	})
	part(model, {
		Name = "DindingBelakang",
		Size = Vector3.new(9, 6, 0.5),
		CFrame = CFrame.new(0, 3.5, z - 2.75),
		Color = wood,
		Material = planks,
	})
	part(model, {
		Name = "DindingKiri",
		Size = Vector3.new(0.5, 6, 6),
		CFrame = CFrame.new(-4.25, 3.5, z),
		Color = burnt,
		Material = planks,
	})
	part(model, {
		Name = "DindingKanan",
		Size = Vector3.new(0.5, 6, 6),
		CFrame = CFrame.new(4.25, 3.5, z),
		Color = wood,
		Material = planks,
	})
	part(model, {
		Name = "Meja",
		Size = Vector3.new(9, 2.6, 0.6),
		CFrame = CFrame.new(0, 1.8, z + 2.7),
		Color = wood,
		Material = planks,
	})
	part(model, {
		Name = "Atap",
		Size = Vector3.new(10.5, 0.5, 7.6),
		CFrame = CFrame.new(0, 7, z) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = Color3.fromRGB(196, 72, 60),
	})
	part(model, {
		Name = "BalokJatuh",
		Size = Vector3.new(0.6, 0.6, 6),
		CFrame = CFrame.new(2.4, 0.5, z + 4.6) * CFrame.Angles(0, math.rad(35), math.rad(8)),
		Color = burnt,
	})
	local glow = part(model, {
		Name = "Bara",
		Size = Vector3.new(7.6, 3.2, 4.4),
		CFrame = CFrame.new(0, 3.2, z - 0.2),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 30
	light.Brightness = 2
	light.Parent = glow
	for _, spot in { { 0, 7.6, 0, 16, 9 }, { -3, 4, 1.2, 10, 5 }, { 3, 3, -1, 9, 5 } } do
		local host = part(model, {
			Name = "TitikApi",
			Size = Vector3.new(2, 0.4, 2),
			CFrame = CFrame.new(spot[1], spot[2], z + spot[3]),
			Transparency = 1,
		})
		burn(host, spot[4], spot[5])
	end
end

-- Api padam: nyala mati, asap berubah jadi uap putih, lalu prop hilang.
function JobProps.extinguish(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Fire") or d:IsA("PointLight") then
			d.Enabled = false
		elseif d:IsA("Smoke") then
			d.Color = Color3.fromRGB(236, 238, 240)
			d.Opacity = 0.25
			d.RiseVelocity = 5
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Material = Enum.Material.SmoothPlastic
			d.Color = Color3.fromRGB(58, 50, 46)
		end
	end
	task.delay(2, function()
		for _, d in model:GetDescendants() do
			if d:IsA("Smoke") then
				d.Enabled = false
			end
		end
	end)
	task.delay(5, function()
		model:Destroy()
	end)
end

-- Semburan air dari `from` ke arah `target` (selang pemadam). Kembalikan part-nya;
-- hancurkan untuk menghentikan semburan.
function JobProps.waterSpray(from: Vector3, target: Vector3): Part
	local nozzle = Instance.new("Part")
	nozzle.Name = "SemburanAir"
	nozzle.Anchored = true
	nozzle.CanCollide = false
	nozzle.CanQuery = false
	nozzle.CanTouch = false
	nozzle.Transparency = 1
	nozzle.Size = Vector3.new(0.4, 0.4, 0.4)
	nozzle.CFrame = CFrame.lookAt(from, target + Vector3.new(0, 2.5, 0))
	local distance = (target - from).Magnitude
	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxasset://textures/particles/smoke_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	water.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	water.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	water.Speed = NumberRange.new(38, 44)
	water.Lifetime = NumberRange.new(math.clamp(distance / 40, 0.25, 0.9))
	water.Acceleration = Vector3.new(0, -14, 0)
	water.SpreadAngle = Vector2.new(5, 5)
	water.Rate = 70
	water.LightEmission = 0.3
	water.EmissionDirection = Enum.NormalId.Front
	water.Parent = nozzle
	return nozzle
end

local function fire(model: Model)
	part(model, {
		Name = "Bin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 2.4, 2.4),
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 110, 80),
	})
	local ember = part(model, {
		Name = "Ember",
		Size = Vector3.new(1.6, 0.4, 1.6),
		CFrame = CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
	})
	local flames = Instance.new("Fire")
	flames.Size = 7
	flames.Heat = 9
	flames.Parent = ember
	local smoke = Instance.new("Smoke")
	smoke.Size = 2
	smoke.RiseVelocity = 6
	smoke.Opacity = 0.25
	smoke.Parent = ember
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 14
	light.Parent = ember
end

local function person(model: Model, random: Random)
	local shirt = SHIRTS[random:NextInteger(1, #SHIRTS)]
	local skin = SKINS[random:NextInteger(1, #SKINS)]
	local pants = Color3.fromRGB(60, 70, 100)
	for _, x in { -0.5, 0.5 } do
		part(model, {
			Name = "Leg",
			Size = Vector3.new(0.9, 2, 0.9),
			CFrame = CFrame.new(x, 1, 0),
			Color = pants,
		})
		part(model, {
			Name = "Arm",
			Size = Vector3.new(0.8, 1.9, 0.8),
			CFrame = CFrame.new(x * 2.9, 3, 0),
			Color = skin,
		})
	end
	part(model, {
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(0, 3, 0),
		Color = shirt,
	})
	part(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.5, 1.5),
		CFrame = CFrame.new(0, 4.75, 0),
		Color = skin,
	})
end

local function cat(model: Model)
	part(model, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 1.6, 1.6),
		CFrame = CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 78, 52),
	})
	part(model, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(0, 11, 0),
		Color = Color3.fromRGB(76, 150, 70),
		Transparency = 0.15,
	})
	local fur = Color3.fromRGB(245, 160, 70)
	local base = CFrame.new(0, 7.2, -3.6)
	part(model, {
		Name = "Branch",
		Size = Vector3.new(0.7, 0.7, 5),
		CFrame = base,
		Color = Color3.fromRGB(110, 78, 52),
	})
	part(model, {
		Name = "CatBody",
		Size = Vector3.new(0.9, 0.9, 1.6),
		CFrame = base * CFrame.new(0, 0.8, -1),
		Color = fur,
	})
	part(model, {
		Name = "CatHead",
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = base * CFrame.new(0, 1.3, -2),
		Color = fur,
	})
	for _, x in { -0.3, 0.3 } do
		part(model, {
			Name = "CatEar",
			Size = Vector3.new(0.25, 0.35, 0.25),
			CFrame = base * CFrame.new(x, 1.9, -2),
			Color = fur,
		})
	end
	part(model, {
		Name = "CatTail",
		Size = Vector3.new(0.25, 1.1, 0.25),
		CFrame = base * CFrame.new(0, 1.5, -0.2),
		Color = fur,
	})
end

local function cone(model: Model)
	for _, x in { -3, 0, 3 } do
		part(model, {
			Name = "ConeBase",
			Size = Vector3.new(1.6, 0.25, 1.6),
			CFrame = CFrame.new(x, 0.125, 2.5),
			Color = Color3.fromRGB(240, 110, 40),
		})
		part(model, {
			Name = "Cone",
			Size = Vector3.new(0.9, 2, 0.9),
			CFrame = CFrame.new(x, 1.25, 2.5),
			Color = Color3.fromRGB(240, 110, 40),
		})
		part(model, {
			Name = "ConeStripe",
			Size = Vector3.new(0.95, 0.45, 0.95),
			CFrame = CFrame.new(x, 1.5, 2.5),
			Color = Color3.fromRGB(245, 245, 245),
		})
	end
end

-- Membuat prop di `ground` (titik tanah + arah). Model belum diberi Parent.
function JobProps.build(kind: JobConfig.PropKind, ground: CFrame, seed: number): Model
	local random = Random.new(seed)
	if kind == "car" then
		local def = VehicleConfig.LIST[random:NextInteger(1, #VehicleConfig.LIST)]
		local model = VehicleBuilder.build(def, {
			static = true,
			color = CAR_COLORS[random:NextInteger(1, #CAR_COLORS)],
		})
		model.Name = "JobCar"
		model:PivotTo(ground)
		return model
	end

	local model = Instance.new("Model")
	model.Name = "JobProp_" .. kind
	if kind == "package" then
		package(model)
	elseif kind == "fire" then
		fire(model)
	elseif kind == "kios" then
		kiosk(model)
	elseif kind == "person" then
		person(model, random)
	elseif kind == "cat" then
		cat(model)
	else
		cone(model)
	end
	-- Part dibuat di sekitar titik asal dunia; pindahkan ke tempatnya.
	model.WorldPivot = CFrame.new()
	model:PivotTo(ground)
	return model
end

return JobProps
