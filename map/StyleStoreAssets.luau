--!strict
--[[
	ROBLOCK CITY: air mancur dan gunung realistis dari Creator Store (gratis, sudah dibersihkan dari skrip).

	Templat (di Studio, sekali pasang lewat insert_asset lalu semua skrip dihapus):
	  ServerStorage.AsetAlam.AirMancurRealistis  = aset 9286173464 (batu bertingkat 3, 1 MeshPart + 3 Part air)
	  ServerStorage.AsetAlam.GunungFoto          = aset 82500806779615 (MeshPart foto-realistis dengan SurfaceAppearance)

	Hasil: Workspace.Map.AirMancurStore (2 air mancur: Taman Kota dan taman kota kecil) dan
	Workspace.Map.Gunung (5 gunung, mesh sama dengan skala/putaran beda). Yang lama dipindah ke
	ServerStorage.CadanganPeta (AirMancurLama, GunungLama). Jangan jalankan StyleFountains lagi:
	skrip itu membuat air mancur lama kembali.

	Pembaruan (dikerjakan langsung di Studio, bukan lewat skrip ini): semua gunung diturunkan 6 stud, Gunung5
	digeser ke z -800, blok terrain Rock air terjun lama dihapus, air terjun lama dipindah ke
	CadanganPeta.AirTerjunLama. Air terjun baru = Workspace.Map.Countryside.AirTerjunBaru: pita Part kaca
	mengikuti jalur turun terjal dari (-990,107,-782) ke (-957,-2,-658) di lereng Gunung1, dengan semprotan,
	kabut, buih, dan suara. Pohon cemara yang melayang/tertanam akibat gunung baru dipindah atau dihapus.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local FOUNTAINS = { Vector3.new(740, 0.36, 55), Vector3.new(40, 1.2, 274) }
local FOUNTAIN_SCALE = 0.85
local SOUND = "rbxassetid://9120552550"

-- pos.y diabaikan; dasar mesh ditanam 12 stud di bawah permukaan
local MOUNTAINS = {
	{ pos = Vector3.new(-1150, 0, -950), s = 0.62, yaw = 40 },
	{ pos = Vector3.new(-860, 0, -1090), s = 0.42, yaw = -20 },
	{ pos = Vector3.new(-1400, 0, -660), s = 0.42, yaw = 75 },
	{ pos = Vector3.new(-1340, 0, -1170), s = 0.45, yaw = 10 },
	{ pos = Vector3.new(-960, 0, -730), s = 0.3, yaw = -60 },
}

local function fountains(template: Model, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "AirMancurStore"
	for _, spot in FOUNTAINS do
		local m = template:Clone()
		m.Name = "AirMancurRealistis"
		m.Parent = folder
		m:ScaleTo(FOUNTAIN_SCALE)
		local cf, size = m:GetBoundingBox()
		local mesh = m:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
		mesh.CollisionFidelity = Enum.CollisionFidelity.Box
		m:PivotTo(
			m:GetPivot()
				+ Vector3.new(spot.X - cf.Position.X, spot.Y - (cf.Position.Y - size.Y / 2), spot.Z - cf.Position.Z)
		)
		local waters: { BasePart } = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				if d.Name == "Water" then
					d.CanCollide = false
					d.CanQuery = false
					d.CastShadow = false
					d.Material = Enum.Material.Glass
					d.Transparency = 0.2
					table.insert(waters, d)
				end
			end
		end
		table.sort(waters, function(a, b)
			return a.Position.Y > b.Position.Y
		end)
		local att = Instance.new("Attachment")
		att.Name = "Pancuran"
		att.Parent = mesh
		att.WorldPosition = Vector3.new(mesh.Position.X, waters[1].Position.Y + 0.2, mesh.Position.Z)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Pancuran"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightEmission = 0.5
		e.Rate = 45
		e.Lifetime = NumberRange.new(0.8, 1)
		e.Speed = NumberRange.new(10, 12)
		e.SpreadAngle = Vector2.new(6, 6)
		e.Acceleration = Vector3.new(0, -26, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.7) })
		e.Parent = att
		local s = Instance.new("Sound")
		s.Name = "SuaraAir"
		s.SoundId = SOUND
		s.Looped = true
		s.Playing = true
		s.Volume = 0.4
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 80
		s.Parent = mesh
	end
	folder.Parent = map
end

local function mountains(template: MeshPart, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Gunung"
	for i, sp in MOUNTAINS do
		local m = template:Clone()
		m.Name = "Gunung" .. i
		m.Size = template.Size * sp.s
		m.Anchored = true
		m.CanCollide = true
		m.CanTouch = false
		m.CollisionFidelity = Enum.CollisionFidelity.Box
		m.CFrame = CFrame.new(sp.pos.X, -12 + m.Size.Y / 2, sp.pos.Z) * CFrame.Angles(0, math.rad(sp.yaw), 0)
		m.Parent = folder
	end
	folder.Parent = map
end

return function()
	local map = Workspace:FindFirstChild("Map")
	local assets = ServerStorage:FindFirstChild("AsetAlam")
	local fountain = if assets then assets:FindFirstChild("AirMancurRealistis") else nil
	local mountain = if assets then assets:FindFirstChild("GunungFoto") else nil
	if map == nil or fountain == nil or mountain == nil then
		warn("[StyleStoreAssets] templat AsetAlam.AirMancurRealistis / GunungFoto tidak ada")
		return
	end
	for _, name in { "AirMancurStore", "Gunung" } do
		local old = map:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	fountains(fountain :: Model, map)
	mountains(mountain :: MeshPart, map)
end
