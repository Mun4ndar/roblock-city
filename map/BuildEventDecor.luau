--!nocheck
-- BuildEventDecor: membuat dekorasi event musiman di ServerStorage.EventDecor.<idEvent>.
-- RetentionService memasang folder itu ke Workspace.Map.EventDecor hanya selama event berlangsung,
-- jadi dekorasi tidak memakan part saat event tidak aktif. Jalankan di Studio (mode Edit);
-- aman diulang (folder lama diganti). Tambah event = tambah fungsi di MAKERS dan baris di ANCHORS.
-- Semua part Anchored, tanpa tabrakan, tanpa bayangan (ringan untuk HP).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local JobConfig = require(ReplicatedStorage.Shared.JobConfig)
local RetentionConfig = require(ReplicatedStorage.Shared.RetentionConfig)

local rgb = Color3.fromRGB

-- Tempat (kunci JobConfig.PLACES) tempat dekorasi dipasang beserta jumlah dan radius lingkaran.
local ANCHORS = {
	{ place = "balaiKota", count = 8, radius = 30 },
	{ place = "tamanKota", count = 6, radius = 26 },
	{ place = "mall", count = 6, radius = 34 },
	{ place = "tamanPerumahan", count = 5, radius = 20 },
	{ place = "dermaga", count = 4, radius = 18 },
}

local function part(
	model: Model,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	neon: boolean?
)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local MAKERS = {}

-- Tiang bendera merah putih.
function MAKERS.agustus(model: Model, at: CFrame)
	part(model, Vector3.new(0.5, 20, 0.5), at * CFrame.new(0, 10, 0), rgb(235, 235, 235))
	part(
		model,
		Vector3.new(0.6, 0.6, 0.6),
		at * CFrame.new(0, 20.2, 0),
		rgb(255, 205, 60),
		Enum.PartType.Ball
	)
	part(model, Vector3.new(0.2, 2, 7), at * CFrame.new(0, 18.5, 3.7), rgb(220, 40, 45))
	part(model, Vector3.new(0.2, 2, 7), at * CFrame.new(0, 16.5, 3.7), rgb(250, 250, 250))
end

-- Pohon Natal sederhana dengan bintang dan lampu.
function MAKERS.natal(model: Model, at: CFrame)
	part(model, Vector3.new(2, 3, 2), at * CFrame.new(0, 1.5, 0), rgb(120, 80, 50))
	local tiers = { { 11, 3, 7 }, { 8, 6, 9 }, { 5, 9, 11 } } -- lebar, tinggi tengah, ...
	for i, t in tiers do
		part(
			model,
			Vector3.new(3.4, t[1], t[1]),
			at * CFrame.new(0, 4 + (i - 1) * 3, 0),
			rgb(40, 150, 70),
			Enum.PartType.Cylinder
		).CFrame = at
			* CFrame.new(0, 4 + (i - 1) * 3, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
	end
	part(
		model,
		Vector3.new(1.6, 1.6, 1.6),
		at * CFrame.new(0, 14, 0),
		rgb(255, 225, 90),
		Enum.PartType.Ball,
		true
	)
	local colors = { rgb(255, 80, 80), rgb(90, 170, 255), rgb(255, 225, 90), rgb(255, 130, 220) }
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local h = 4 + (i % 3) * 3
		local r = 4.6 - (i % 3) * 1.5
		part(
			model,
			Vector3.one * 0.9,
			at * CFrame.new(math.cos(a) * r, h, math.sin(a) * r),
			colors[i % 4 + 1],
			Enum.PartType.Ball,
			true
		)
	end
end

-- Kumpulan balon pesta di tiang.
function MAKERS.tahunbaru(model: Model, at: CFrame)
	part(model, Vector3.new(0.4, 9, 0.4), at * CFrame.new(0, 4.5, 0), rgb(230, 230, 235))
	local colors = {
		rgb(255, 205, 60),
		rgb(255, 90, 140),
		rgb(90, 200, 255),
		rgb(150, 110, 255),
		rgb(90, 220, 140),
	}
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(
			model,
			Vector3.new(3, 3.6, 3),
			at * CFrame.new(math.cos(a) * 2, 10.5 + (i % 2) * 1.5, math.sin(a) * 2),
			colors[i],
			Enum.PartType.Ball,
			true
		)
	end
end

-- Lentera dan ketupat gantung.
function MAKERS.lebaran(model: Model, at: CFrame)
	part(model, Vector3.new(0.5, 12, 0.5), at * CFrame.new(0, 6, 0), rgb(90, 70, 50))
	part(
		model,
		Vector3.new(4, 3, 3),
		at * CFrame.new(0, 11, 0),
		rgb(255, 190, 90),
		Enum.PartType.Cylinder,
		true
	).CFrame = at
		* CFrame.new(0, 11, 0)
		* CFrame.Angles(0, 0, math.pi / 2)
	for i, dx in { -2.2, 2.2 } do
		part(
			model,
			Vector3.new(1.6, 1.6, 1.6),
			at * CFrame.new(dx, 8 - i, 0) * CFrame.Angles(0, 0, math.pi / 4),
			rgb(70, 170, 90)
		)
	end
end

local ROOT = ServerStorage:FindFirstChild(RetentionConfig.DECOR_SOURCE)
if ROOT then
	ROOT:Destroy()
end
ROOT = Instance.new("Folder")
ROOT.Name = RetentionConfig.DECOR_SOURCE
ROOT.Parent = ServerStorage

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Exclude
ground.FilterDescendantsInstances = { ROOT }

local total = 0
for eventId, make in MAKERS do
	local folder = Instance.new("Folder")
	folder.Name = eventId
	folder.Parent = ROOT
	for _, anchor in ANCHORS do
		local place = JobConfig.PLACES[anchor.place]
		if place then
			for i = 1, anchor.count do
				local a = i / anchor.count * math.pi * 2 + 0.3
				local origin = place.position
					+ Vector3.new(math.cos(a) * anchor.radius, 80, math.sin(a) * anchor.radius)
				local hit = Workspace:Raycast(origin, Vector3.new(0, -160, 0), ground)
				local dy = if hit then hit.Position.Y - place.position.Y else 0
				if hit and hit.Material ~= Enum.Material.Water and math.abs(dy) < 6 then
					local model = Instance.new("Model")
					model.Name = eventId .. i
					make(model, CFrame.new(hit.Position) * CFrame.Angles(0, a + math.pi, 0))
					model.Parent = folder
					total += #model:GetChildren()
				end
			end
		end
	end
end
return `Dekorasi event dibuat: {total} part di {#ROOT:GetChildren()} event`
