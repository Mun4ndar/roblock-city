--!strict
--[[
	ROBLOCK CITY: air mancur bertingkat (taman perumahan, dua di Taman Kota, atrium mall).

	Mengganti air mancur kotak dengan mesh buatan Blender (assets/blender/air_mancur.fbx, templat
	MeshPart di ServerStorage.AsetAlam.AirMancur): kolam bertepi, dua mangkuk bertingkat, air di tiap
	tingkat, pancuran di puncak, air jatuh dari tepi mangkuk, buih di kolam, dan suara air.

	Part air mancur lama tidak dihapus: hanya disembunyikan dan tabrakannya dimatikan. Hasilnya di
	Workspace.Map.Fountains; aman dijalankan ulang. Tanpa templat mesh, skrip ini tidak mengubah apa-apa.

	Suara: "Waterfall Steady Stream 1 (SFX)" dari ProSoundEffects (gratis di Creator Store).
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

-- Titik dasar (tanah) tiap air mancur dan garis tengah kolamnya. Mesh dibuat untuk garis tengah 18.
local SPOTS = {
	{ position = Vector3.new(40, 1.2, 510), diameter = 18 },
	{ position = Vector3.new(-120, 0, -165), diameter = 20 },
	{ position = Vector3.new(330, 0, -165), diameter = 20 },
	{ position = Vector3.new(525, 2000, -597), diameter = 15, indoor = true },
}
local OLD_NAMES = { AirMancur = true, KolamAtrium = true, AirAtrium = true, PancuranAtrium = true }

local STONE = rgb(226, 222, 214)
local WATER = rgb(96, 190, 226)
local MIST = "rbxasset://textures/particles/smoke_main.dds"
local SOUND = "rbxassetid://9120552550"

-- Semua part air mancur lama di peta (dicari sekali, dengan jeda supaya Studio tidak macet).
local function findOld(map: Instance): { BasePart }
	local found: { BasePart } = {}
	for index, d in map:GetDescendants() do
		if index % 5000 == 0 then
			task.wait()
		end
		if
			d:IsA("BasePart")
			and (OLD_NAMES[d.Name] or (d.Parent ~= nil and OLD_NAMES[d.Parent.Name]))
		then
			table.insert(found, d)
		end
	end
	return found
end

local function hideOld(oldParts: { BasePart }, spot: Vector3)
	for _, d in oldParts do
		local flat = Vector3.new(d.Position.X - spot.X, 0, d.Position.Z - spot.Z)
		if flat.Magnitude < 4 and math.abs(d.Position.Y - spot.Y) < 20 then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = MIST
	e.Color = ColorSequence.new(rgb(255, 255, 255))
	e.LightEmission = 0.55
	e.LightInfluence = 1
	e.Rotation = NumberRange.new(0, 360)
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function build(
	template: MeshPart,
	parent: Instance,
	spot: Vector3,
	diameter: number,
	indoor: boolean
)
	local s = diameter / 18
	local base = CFrame.new(spot)
	local model = Instance.new("Model")
	model.Name = "AirMancurBaru"

	local stone = template:Clone()
	stone.Name = "Batu"
	stone.Size = template.Size * s
	stone.CFrame = base * CFrame.new(0, 4.8 * s, 0)
	stone.Anchored = true
	stone.CanCollide = true
	stone.Color = STONE
	stone.Material = Enum.Material.Marble
	stone.Parent = model
	model.PrimaryPart = stone

	local function water(radius: number, y: number)
		local p = Instance.new("Part")
		p.Name = "Air"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, radius * 2 * s, radius * 2 * s)
		p.CFrame = base * CFrame.new(0, y * s, 0) * CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = WATER
		p.Material = Enum.Material.Glass
		p.Transparency = 0.25
		p.Reflectance = 0.2
		p.Parent = model
	end
	water(8.45, 2.05)
	water(3.55, 6.05)
	water(1.78, 8.6)

	-- tirai air yang jatuh dari tepi mangkuk (tabung bening) dan batang pancuran di puncak
	local function curtain(radius: number, top: number, bottom: number, transparency: number)
		local p = Instance.new("Part")
		p.Name = "TiraiAir"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new((top - bottom) * s, radius * 2 * s, radius * 2 * s)
		p.CFrame = base
			* CFrame.new(0, (top + bottom) / 2 * s, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = rgb(200, 236, 255)
		p.Material = Enum.Material.Glass
		p.Transparency = transparency
		p.Parent = model
	end
	curtain(1.96, 8.6, 6.1, 0.72)
	curtain(3.86, 6.1, 2.1, 0.78)
	curtain(0.22, 11.6, 9.4, 0.45)

	-- attachment diberi parent dulu supaya WorldCFrame berlaku
	local function attach(local_: Vector3, outward: Vector3?): Attachment
		local a = Instance.new("Attachment")
		a.Parent = stone
		local world = base * CFrame.new(local_ * s)
		if outward then
			world = CFrame.lookAt(world.Position, world.Position + outward)
		end
		a.WorldCFrame = world
		return a
	end

	-- pancuran di puncak
	emitter(attach(Vector3.new(0, 9.6, 0)), {
		Name = "Pancuran",
		EmissionDirection = Enum.NormalId.Top,
		Rate = 70,
		Lifetime = NumberRange.new(0.85, 1.05),
		Speed = NumberRange.new(13 * math.sqrt(s), 15 * math.sqrt(s)),
		SpreadAngle = Vector2.new(7, 7),
		Acceleration = Vector3.new(0, -30, 0),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * s),
			NumberSequenceKeypoint.new(1, 1.2 * s),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
	})

	-- air jatuh dari tepi mangkuk atas dan tengah
	local function ring(radius: number, y: number, drop: number, count: number)
		local fall = math.sqrt(2 * drop * s / 30)
		for i = 1, count do
			local angle = (i - 0.5) / count * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			emitter(attach(out * radius + Vector3.new(0, y, 0), out), {
				Name = "AirJatuh",
				EmissionDirection = Enum.NormalId.Front,
				Rate = 22,
				Lifetime = NumberRange.new(fall * 0.95, fall * 1.1),
				Speed = NumberRange.new(1.2, 2),
				SpreadAngle = Vector2.new(10, 10),
				Acceleration = Vector3.new(0, -30, 0),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.75 * s),
					NumberSequenceKeypoint.new(1, 0.5 * s),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 0.5),
				}),
			})
		end
	end
	ring(2.0, 8.65, 2.5, 6)
	ring(3.9, 6.15, 4, 10)

	-- buih di kolam bawah tempat air jatuh
	local foam = Instance.new("Part")
	foam.Name = "Buih"
	foam.Size = Vector3.new(9.5 * s, 0.1, 9.5 * s)
	foam.CFrame = base * CFrame.new(0, 2.2 * s, 0)
	foam.Transparency = 1
	foam.Anchored = true
	foam.CanCollide = false
	foam.CanQuery = false
	foam.CanTouch = false
	foam.Parent = model
	emitter(foam, {
		Name = "Buih",
		EmissionDirection = Enum.NormalId.Top,
		Rate = 45,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(40, 40),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3 * s),
			NumberSequenceKeypoint.new(1, 1.1 * s),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local sound = Instance.new("Sound")
	sound.Name = "SuaraAir"
	sound.SoundId = SOUND
	sound.Looped = true
	sound.Playing = true
	sound.Volume = if indoor then 0.25 else 0.4
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = if indoor then 60 else 90
	sound.Parent = stone

	model.Parent = parent
end

return function(): number
	local map = Workspace:FindFirstChild("Map")
	local assets = ServerStorage:FindFirstChild("AsetAlam")
	local template = if assets then assets:FindFirstChild("AirMancur") else nil
	if map == nil or template == nil or not template:IsA("MeshPart") then
		warn("[StyleFountains] Workspace.Map atau ServerStorage.AsetAlam.AirMancur tidak ditemukan")
		return 0
	end
	local old = map:FindFirstChild("Fountains")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Fountains"
	local oldParts = findOld(map)
	for _, spot in SPOTS do
		hideOld(oldParts, spot.position)
		build(template, folder, spot.position, spot.diameter, spot.indoor == true)
	end
	folder.Parent = map
	return #folder:GetChildren()
end
