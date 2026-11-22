--[[
	ROBLOCK CITY: hiasan pantai (jalankan setelah BuildBeach dan StyleWorld; aman diulang).

	- Kursi pantai yang bisa diduduki di bawah setiap payung pantai. Modelnya dari
	  "Tidewalk Sampler: Voxel Beach Boardwalk Kit" karya stayrot (Creator Store, gratis, aset
	  134898338402000; MeshPart + Seat, tanpa skrip), disimpan di ServerStorage.AsetPihakKetiga.
	  Kalau paketnya tidak ada, bagian ini dilewati.
	- Perahu nelayan kecil dari part di tepi laut dekat dermaga (buatan sendiri).

	Pakai: require(game.ServerStorage.MapBuilders.StyleBeach)()
	Hasil: Workspace.Map.Beach.Hiasan (dibuat ulang setiap dijalankan).
]]

local ServerStorage = game:GetService("ServerStorage")

local rgb = Color3.fromRGB
local LOUNGER_SCALE = 1.6
local BOATS = {
	{ pos = Vector3.new(2168, 0.6, 60), yaw = 20, color = rgb(230, 80, 70) },
	{ pos = Vector3.new(2176, 0.6, 96), yaw = -15, color = rgb(70, 150, 220) },
	{ pos = Vector3.new(2170, 0.6, 176), yaw = 160, color = rgb(250, 200, 70) },
	{ pos = Vector3.new(2182, 0.6, 214), yaw = 200, color = rgb(90, 180, 110) },
}

local function P(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function boat(parent: Instance, cf: CFrame, color: Color3)
	local m = Instance.new("Model")
	m.Name = "PerahuNelayan"
	local wood = Enum.Material.WoodPlanks
	P(m, "Lambung", Vector3.new(5, 1.6, 11), cf * CFrame.new(0, 0, 0), color, wood)
	local bow = Instance.new("WedgePart")
	bow.Name = "Haluan"
	bow.Anchored = true
	bow.Size = Vector3.new(5, 1.6, 4)
	bow.CFrame = cf * CFrame.new(0, 0, -7.5) * CFrame.Angles(0, math.pi, math.pi)
	bow.Color = color
	bow.Material = wood
	bow.Parent = m
	P(m, "Dek", Vector3.new(4.2, 0.3, 10), cf * CFrame.new(0, 0.7, 0), rgb(214, 180, 130), wood)
	for _, x in { -2.4, 2.4 } do
		P(
			m,
			"Tepi",
			Vector3.new(0.4, 0.9, 11),
			cf * CFrame.new(x, 1.2, 0),
			rgb(250, 250, 245),
			wood
		)
	end
	P(
		m,
		"Bangku",
		Vector3.new(4.4, 0.4, 1.2),
		cf * CFrame.new(0, 1.3, 1.5),
		rgb(160, 112, 70),
		wood
	)
	P(m, "Bangku", Vector3.new(4.4, 0.4, 1.2), cf * CFrame.new(0, 1.3, -2), rgb(160, 112, 70), wood)
	P(m, "Tiang", Vector3.new(0.3, 7, 0.3), cf * CFrame.new(0, 4.2, 4), rgb(110, 78, 50), wood)
	P(m, "Bendera", Vector3.new(0.1, 1.2, 2), cf * CFrame.new(0, 7, 3), color)
	m.Parent = parent
end

return function(): number
	local map = workspace:FindFirstChild("Map")
	local beach = map and map:FindFirstChild("Beach")
	if not beach then
		warn("[StyleBeach] Workspace.Map.Beach tidak ditemukan")
		return 0
	end
	local old = beach:FindFirstChild("Hiasan")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Hiasan"

	-- kursi pantai di bawah payung
	local pack = ServerStorage:FindFirstChild("AsetPihakKetiga")
	local sampler = pack and pack:FindFirstChild("TidewalkSampler")
	local lounger = sampler and sampler:FindFirstChild("Beach lounger", true)
	if lounger and lounger:IsA("Model") then
		for _, d in beach:GetDescendants() do
			if d:IsA("Model") and d.Name == "Payung" then
				local base = d:GetPivot().Position
				local ground =
					workspace:Raycast(base + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0))
				local y = if ground then ground.Position.Y else base.Y
				for _, side in { -1, 1 } do
					local c = lounger:Clone()
					c.Name = "KursiPantai"
					c:ScaleTo(LOUNGER_SCALE)
					for _, part in c:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = true
						end
					end
					local _, size = c:GetBoundingBox()
					-- menghadap laut (timur)
					c:PivotTo(
						CFrame.new(base.X, y, base.Z + side * 3.4)
							* CFrame.Angles(0, math.rad(-90), 0)
							* CFrame.new(0, size.Y * 0, 0)
					)
					c.Parent = root
				end
			end
		end
	else
		warn("[StyleBeach] paket TidewalkSampler tidak ditemukan; kursi pantai dilewati")
	end

	-- Perahu mengapung di permukaan air (dicari dengan raycast yang tidak mengabaikan air).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	for _, b in BOATS do
		local hit =
			workspace:Raycast(b.pos + Vector3.new(0, 40, 0), Vector3.new(0, -100, 0), params)
		local y = if hit then hit.Position.Y + 0.2 else b.pos.Y
		boat(root, CFrame.new(b.pos.X, y, b.pos.Z) * CFrame.Angles(0, math.rad(b.yaw), 0), b.color)
	end

	root.Parent = beach
	return #root:GetChildren()
end
