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
