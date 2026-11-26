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
-- Perahu nelayan kayu dihapus atas permintaan pemilik (2026-11-26): terlihat tenggelam dan kotak.
local BOATS: { { pos: Vector3, yaw: number, color: Color3 } } = {}

-- Model pilihan pemilik game dari Creator Store (gratis), disimpan di ServerStorage.AsetPengguna
-- dengan nama "A<id aset>". Hanya yang sudah diperiksa (tanpa skrip, ringan) yang dipakai di sini.
-- Skrip apa pun di dalamnya tetap dibuang saat dipasang. pos = titik di pasir, yaw = derajat.
local PROPS = {
	{ id = 156056461, name = "PosPenjagaPantai", pos = Vector3.new(2040, 0, 30), yaw = 90 }, -- "Beach Hut"
	{ id = 19003610982, name = "MenaraPenjaga", pos = Vector3.new(2066, 0, 232), yaw = 0 }, -- "Beach station"
	{ id = 1490839498, name = "LapanganVoli", pos = Vector3.new(1985, 0, -235), yaw = 0 }, -- "Beach VolleyBall Court"
	{ id = 1782903086, name = "KursiPayung", pos = Vector3.new(2052, 0, -70), yaw = 0 }, -- "Beach Seats"
	{ id = 1782903086, name = "KursiPayung", pos = Vector3.new(2044, 0, 310), yaw = 30 },
	{ id = 1782903086, name = "KursiPayung", pos = Vector3.new(2004, 0, 420), yaw = -20 },
	{ id = 400739628, name = "KanopiPantai", pos = Vector3.new(2060, 0, -150), yaw = 90 }, -- "Beach chairs, Umbrella and table"
	{ id = 400739628, name = "KanopiPantai", pos = Vector3.new(2050, 0, 372), yaw = 90 },
	{ id = 170882559, name = "SudutSantai", pos = Vector3.new(2072, 0, 70), yaw = 0 }, -- "Beach Pack"
}

-- Pasang salinan model di atas pasir: hanya digeser dan diputar tegak (orientasi asli dipertahankan).
local function placeProp(parent: Instance, prop, ground: (Vector3) -> number): boolean
	local folder = ServerStorage:FindFirstChild("AsetPengguna")
	local source = folder and folder:FindFirstChild("A" .. tostring(prop.id))
	if not source then
		return false
	end
	local c = source:Clone()
	c.Name = prop.name
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local model = if c:IsA("Model") then c else nil
	if not model then
		return false
	end
	local box = model:GetBoundingBox()
	model:PivotTo(
		CFrame.new(box.Position)
			* CFrame.Angles(0, math.rad(prop.yaw), 0)
			* CFrame.new(-box.Position)
			* model:GetPivot()
	)
	-- dasar model = titik terendah semua part
	local minY = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, half = d.CFrame, d.Size / 2
			local reach = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			minY = math.min(minY, d.Position.Y - reach)
		end
	end
	local center = model:GetBoundingBox().Position
	local y = ground(prop.pos)
	model:PivotTo(
		model:GetPivot() + Vector3.new(prop.pos.X - center.X, y - minY, prop.pos.Z - center.Z)
	)
	model.Parent = parent
	return true
end

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
				-- hanya terrain: tanpa filter, sinarnya mengenai kain payung dan kursi naik ke atas payung
				local onlyTerrain = RaycastParams.new()
				onlyTerrain.FilterType = Enum.RaycastFilterType.Include
				onlyTerrain.FilterDescendantsInstances = { workspace.Terrain }
				local ground = workspace:Raycast(
					base + Vector3.new(0, 30, 0),
					Vector3.new(0, -80, 0),
					onlyTerrain
				)
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

	-- model pilihan pemilik game
	local sand = RaycastParams.new()
	sand.FilterType = Enum.RaycastFilterType.Include
	sand.FilterDescendantsInstances = { workspace.Terrain }
	local function ground(pos: Vector3): number
		local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), sand)
		return if hit then hit.Position.Y else pos.Y
	end
	for _, prop in PROPS do
		if not placeProp(root, prop, ground) then
			warn(
				"[StyleBeach] model A"
					.. tostring(prop.id)
					.. " tidak ada di ServerStorage.AsetPengguna; dilewati"
			)
		end
	end
	local hut = root:FindFirstChild("PosPenjagaPantai")
	if hut and hut:IsA("Model") then
		local box, size = hut:GetBoundingBox()
		local board = P(
			root,
			"PapanPenjaga",
			Vector3.new(0.4, 2.2, 14),
			CFrame.new(box.Position + Vector3.new(0, size.Y / 2 + 1, 0)),
			rgb(230, 70, 60)
		)
		board.CanCollide = false
		-- papan di bubungan atap, tulisannya di dua sisi
		for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "POS PENJAGA PANTAI"
			label.Parent = gui
			gui.Parent = board
		end
	end

	root.Parent = beach
	return #root:GetChildren()
end
