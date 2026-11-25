--!strict
--[[
	ROBLOCK CITY: Perkebunan Besar (pekerjaan Petani) di pedesaan, di barat sungai dan selatan jalan desa.
	Sistem tanam/panen: src/shared/FarmConfig.luau, src/server/Services/FarmService.luau.

	Bahan:
	  ServerStorage.KompleksTaniMentah  = asset 118252158151326 (Blender: assets/blender/kompleks_tani.fbx,
	                                      toko bibit, lumbung, silo, traktor, orang-orangan, jerami)
	  ReplicatedStorage.Assets.Tanaman  = mesh sayur dari "Food Pack Premium" (Creator Store 117840470978877,
	                                      tanpa skrip): kubis, selada, kembangkol, bit, semangka, labu
	Hasil (Workspace.Map.Perkebunan, dibuat ulang tiap dijalankan; Map.Farm.KebunWarga lama dihapus):
	  Kompleks  : mesh Blender + kotak tabrakan + papan nama + dua kios bertag FarmMarket
	              (atribut MarketName: "Toko Bibit" dan "Gudang Hasil")
	  Ladang    : tanah, pagar, 60 petak bertag FarmPlot (atribut PlotIndex 1..60) dengan tombol "Tanam"
	Tanaman digambar di client masing-masing pemain (FarmController).

	Catatan impor FBX: tiap MeshPart membawa rotasi model hasil sisip. Susun ulang lewat CFrame relatif
	terhadap part lantai TaFloor; bingkai asli = (x, z_blender, y_blender) dengan sumbu x terbalik, depan -Z.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CX, CZ = -757, 100 -- tengah kompleks (depan menghadap -Z, ke jalan desa)
local GY = 0.02 -- permukaan tanah
local COLS, ROWS, PITCH = 6, 10, 11
local FIELD_Z0 = 128 -- pusat baris petak pertama

local rgb = Color3.fromRGB
local LOOK = {
	TaFloor = { rgb(168, 160, 145), Enum.Material.Cobblestone },
	TaWall = { rgb(243, 238, 222), Enum.Material.SmoothPlastic },
	TaRed = { rgb(176, 42, 36), Enum.Material.SmoothPlastic },
	TaWhite = { rgb(246, 246, 242), Enum.Material.SmoothPlastic },
	TaGreen = { rgb(70, 140, 70), Enum.Material.SmoothPlastic },
	TaRoof = { rgb(78, 70, 70), Enum.Material.Slate },
	TaGlass = { rgb(140, 200, 230), Enum.Material.Glass },
	TaDark = { rgb(34, 34, 40), Enum.Material.SmoothPlastic },
	TaWood = { rgb(140, 98, 58), Enum.Material.WoodPlanks },
	TaHay = { rgb(232, 192, 80), Enum.Material.Fabric },
	TaYellow = { rgb(242, 160, 36), Enum.Material.SmoothPlastic },
	TaMetal = { rgb(165, 170, 178), Enum.Material.Metal },
	TaTire = { rgb(24, 24, 26), Enum.Material.SmoothPlastic },
	TaCloth = { rgb(130, 90, 150), Enum.Material.Fabric },
}
local GLASS_NAME = "TaGlass"

-- kotak tabrakan dalam koordinat Blender (x0, x1, y0, y1, z0, z1)
local COLLIDERS: { { any } } = {
	{ "Toko", -30, -9, -8, 6, 0, 6.5 },
	{ "Lumbung", 7, 29, -9, 7, 0, 6 },
	{ "Silo", 31.3, 37.7, -3.2, 3.2, 0, 15 },
	{ "Traktor", -3.5, 2.5, -3.3, 0.5, 0, 5 },
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide
	p.CastShadow = collide
	p.Parent = parent
	return p
end

local function sign(parent: Instance, cf: CFrame, size: Vector3, text: string, bg: Color3, fg: Color3)
	local board = part(parent, "PapanNama", size, cf, bg, Enum.Material.SmoothPlastic, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = fg
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
end

local function market(parent: Instance, name: string, position: Vector3)
	local p = part(
		parent,
		"Kios_" .. name,
		Vector3.new(4, 4, 4),
		CFrame.new(position),
		rgb(255, 255, 255),
		Enum.Material.SmoothPlastic,
		false
	)
	p.Transparency = 1
	p.CanQuery = false
	p:SetAttribute("MarketName", name)
	CollectionService:AddTag(p, "FarmMarket")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FarmPrompt"
	prompt.ActionText = "Buka toko"
	prompt.ObjectText = name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
end

local function buildComplex(root: Folder)
	local raw = ServerStorage:FindFirstChild("KompleksTaniMentah")
	if raw == nil then
		warn("[BuildPerkebunan] ServerStorage.KompleksTaniMentah tidak ada (insert asset 118252158151326)")
		return
	end
	local model = Instance.new("Model")
	model.Name = "Kompleks"
	local floorRaw = (raw :: any).TaFloor :: MeshPart
	local base = CFrame.new(CX, GY + 0.125, CZ)
	for _, source in raw:GetChildren() do
		local look = LOOK[source.Name]
		if source:IsA("MeshPart") and look then
			local clone = source:Clone()
			clone:ClearAllChildren()
			clone.CFrame = base * floorRaw.CFrame:ToObjectSpace(source.CFrame)
			clone.Color, clone.Material = look[1], look[2]
			if source.Name == GLASS_NAME then
				clone.Transparency = 0.35
			end
			clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
			clone.Parent = model
		end
	end
	-- bingkai: (x, z_blender, y_blender) dengan x terbalik
	local frame = CFrame.new(CX, GY, CZ)
	for _, c in COLLIDERS do
		local center = frame * Vector3.new(-(c[2] + c[3]) / 2, (c[6] + c[7]) / 2, (c[4] + c[5]) / 2)
		local p = part(
			model,
			c[1],
			Vector3.new(c[3] - c[2], c[7] - c[6], c[5] - c[4]),
			CFrame.new(center),
			rgb(120, 120, 120),
			Enum.Material.Plastic,
			true
		)
		p.Transparency = 1
		p.CastShadow = false
	end
	-- papan nama
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(frame * Vector3.new(-x, z, y))
	end
	sign(model, at(-19.5, -9.7, 8.1), Vector3.new(9, 1.7, 0.2), "TOKO BIBIT", rgb(46, 110, 52), rgb(255, 255, 255))
	sign(model, at(18, -9.7, 7.1), Vector3.new(10, 1.5, 0.2), "GUDANG HASIL", rgb(250, 248, 240), rgb(176, 42, 36))
	-- kios (penanda toko)
	market(model, "Toko Bibit", frame * Vector3.new(11.2, 2.5, -10.5))
	market(model, "Gudang Hasil", frame * Vector3.new(-18, 2.5, -11))
	model.Parent = root
end

local function buildField(root: Folder)
	local field = Instance.new("Folder")
	field.Name = "Ladang"
	local zMid = FIELD_Z0 + (ROWS - 1) * PITCH / 2
	local width, depth = COLS * PITCH + 6, ROWS * PITCH + 10
	part(
		field,
		"Tanah",
		Vector3.new(width, 0.3, depth),
		CFrame.new(CX, GY + 0.15, zMid),
		rgb(112, 80, 54),
		Enum.Material.Ground,
		false
	)
	local index = 0
	for r = 0, ROWS - 1 do
		for c = 0, COLS - 1 do
			index += 1
			local x = CX + (c - (COLS - 1) / 2) * PITCH
			local z = FIELD_Z0 + r * PITCH
			part(
				field,
				"Bingkai" .. index,
				Vector3.new(10.8, 0.4, 10.8),
				CFrame.new(x, GY + 0.4, z),
				rgb(120, 84, 50),
				Enum.Material.WoodPlanks,
				false
			)
			local soil = part(
				field,
				"Petak" .. index,
				Vector3.new(9.8, 0.5, 9.8),
				CFrame.new(x, GY + 0.55, z),
				rgb(86, 58, 40),
				Enum.Material.Mud,
				false
			)
			soil:SetAttribute("PlotIndex", index)
			CollectionService:AddTag(soil, "FarmPlot")
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "FarmPrompt"
			prompt.ActionText = "Tanam"
			prompt.ObjectText = "Petak " .. index
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 11
			prompt.RequiresLineOfSight = false
			prompt.Parent = soil
		end
	end
	-- pagar kayu mengelilingi ladang (celah di tengah sisi utara = gerbang)
	local fence = Instance.new("Folder")
	fence.Name = "Pagar"
	local x0, x1 = CX - width / 2 - 2, CX + width / 2 + 2
	local z0, z1 = zMid - depth / 2 - 2, zMid + depth / 2 + 2
	local wood, dark = rgb(150, 106, 64), rgb(110, 78, 50)
	local function rail(ax: number, az: number, bx: number, bz: number)
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local mid = Vector3.new((ax + bx) / 2, 0, (az + bz) / 2)
		local cf = CFrame.lookAt(mid, mid + Vector3.new(bx - ax, 0, bz - az))
		for _, h in { 1.1, 2.3 } do
			part(
				fence,
				"Palang",
				Vector3.new(0.3, 0.4, length),
				cf * CFrame.new(0, GY + h, 0),
				wood,
				Enum.Material.WoodPlanks,
				false
			)
		end
		part(
			fence,
			"PalangTabrak",
			Vector3.new(0.3, 2.6, length),
			cf * CFrame.new(0, GY + 1.3, 0),
			wood,
			Enum.Material.WoodPlanks,
			true
		).Transparency =
			1
	end
	local function post(x: number, z: number)
		part(fence, "Tiang", Vector3.new(0.7, 3, 0.7), CFrame.new(x, GY + 1.5, z), dark, Enum.Material.WoodPlanks, false)
	end
	local gate = 7
	for x = x0, x1, 6 do
		post(x, z0)
		post(x, z1)
	end
	for z = z0, z1, 6 do
		post(x0, z)
		post(x1, z)
	end
	rail(x0, z0, CX - gate, z0)
	rail(CX + gate, z0, x1, z0)
	rail(x0, z1, x1, z1)
	rail(x0, z0, x0, z1)
	rail(x1, z0, x1, z1)
	fence.Parent = field
	-- jalan kerikil dari kompleks ke gerbang
	part(
		field,
		"JalanKerikil",
		Vector3.new(10, 0.25, z0 - (CZ + 13)),
		CFrame.new(CX, GY + 0.12, (z0 + CZ + 13) / 2),
		rgb(160, 150, 135),
		Enum.Material.Pebble,
		false
	)
	field.Parent = root
end

return function(): number
	local map = Workspace:FindFirstChild("Map")
	if map == nil then
		warn("[BuildPerkebunan] Workspace.Map tidak ada")
		return 0
	end
	local old = map:FindFirstChild("Perkebunan")
	if old then
		old:Destroy()
	end
	local legacy = map:FindFirstChild("Farm")
	local legacyPlots = if legacy then legacy:FindFirstChild("KebunWarga") else nil
	if legacyPlots then
		legacyPlots:Destroy() -- 8 petak lama diganti 60 petak baru (indeks 1..8 berlanjut)
	end
	local root = Instance.new("Folder")
	root.Name = "Perkebunan"
	buildComplex(root)
	buildField(root)
	root.Parent = map
	return #root:GetDescendants()
end
