--!strict
--[[
	ROBLOCK CITY: teras dua kafe.

	1. Kafe Kota (pusat kota), tempat usaha kafe pemain (lihat BusinessService): teras kayu di depan
	   gedung dengan empat meja berpayung, kursi berlengan, cangkir kopi, konter kasir (titiknya harus
	   sama dengan BusinessConfig.POSITION), papan menu, dan pot tanaman. Hasil: Workspace.Map.KafeKota.
	2. Cafe Startduck (kota kecil): papan nama gedung kafe diganti, patung bebek kuning di atap,
	   lambang bebek, tenda bergaris, dan teras tiga meja di sisi timur gedung (trotoar depannya
	   sempit). Hasil: Workspace.Map.Startduck. Nama dan lambangnya buatan sendiri.

	Kursinya berisi Seat, jadi pemain bisa duduk dan warga (NpcService, grup "KafeKota" dan
	"Startduck") duduk memegang cangkir di sana.

	Kursi berlengan memakai mesh dari model gratis Creator Store "Coffee Shop Cafe Store Building"
	(em0lii0); hanya mesh kursinya yang diambil, semua skripnya dibuang. Templatnya di
	ServerStorage.AsetPihakKetiga.KursiKafe; tanpa templat, kursi dibuat dari part biasa.

	Aman dijalankan ulang.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

local ORIGIN = CFrame.new(20, 1.1, -559)
local DECK_DEPTH = 17
local DECK_WIDTH = 36
local COUNTER = Vector3.new(8, 0, 3.6)
local CHAIR_YAW = math.rad(180)

local WOOD = rgb(150, 104, 66)
local DARK = rgb(60, 46, 38)
local CREAM = rgb(250, 242, 226)
local UMBRELLAS = { rgb(214, 84, 70), rgb(240, 180, 60), rgb(70, 150, 120), rgb(84, 130, 200) }

local function part(
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

local function cylinder(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function text(target: BasePart, face: Enum.NormalId, value: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = value
	label.Parent = gui
	gui.Parent = target
end

local function chair(parent: Instance, cf: CFrame, template: Instance?)
	local model = Instance.new("Model")
	model.Name = "KursiKafe"
	local mesh = if template then template:FindFirstChildWhichIsA("MeshPart") else nil
	if mesh then
		local clone = mesh:Clone()
		clone.Anchored = true
		clone.CanCollide = true
		clone.CFrame = cf * CFrame.new(0, clone.Size.Y / 2, 0) * CFrame.Angles(0, CHAIR_YAW, 0)
		clone.Parent = model
	else
		part(
			model,
			"Dudukan",
			Vector3.new(3, 1.2, 3),
			cf * CFrame.new(0, 0.6, 0),
			CREAM,
			Enum.Material.Fabric
		)
		part(
			model,
			"Sandaran",
			Vector3.new(3, 2.4, 0.6),
			cf * CFrame.new(0, 1.8, 1.2),
			CREAM,
			Enum.Material.Fabric
		)
	end
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.3, 1.8)
	seat.CFrame = cf * CFrame.new(0, 1.25, -0.1)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = model
	model.Parent = parent
end

local function cup(parent: Instance, cf: CFrame)
	cylinder(parent, "Tatakan", 0.42, 0.06, cf * CFrame.new(0, 0.03, 0), CREAM)
	cylinder(parent, "Cangkir", 0.26, 0.36, cf * CFrame.new(0, 0.24, 0), CREAM)
	local coffee =
		cylinder(parent, "Kopi", 0.21, 0.04, cf * CFrame.new(0, 0.41, 0), rgb(86, 54, 34))
	coffee.CanCollide = false
end

local function tableSet(parent: Instance, cf: CFrame, color: Color3, template: Instance?)
	local set = Instance.new("Model")
	set.Name = "MejaKafe"
	cylinder(set, "KakiMeja", 0.7, 0.2, cf * CFrame.new(0, 0.1, 0), DARK, Enum.Material.Metal)
	cylinder(set, "TiangMeja", 0.16, 2.3, cf * CFrame.new(0, 1.35, 0), DARK, Enum.Material.Metal)
	cylinder(set, "DaunMeja", 1.7, 0.22, cf * CFrame.new(0, 2.6, 0), WOOD, Enum.Material.Wood)
	cylinder(
		set,
		"TiangPayung",
		0.1,
		6.4,
		cf * CFrame.new(0, 5.9, 0),
		rgb(236, 236, 232),
		Enum.Material.Metal
	).CanCollide =
		false
	local canopy =
		cylinder(set, "Payung", 4.1, 0.25, cf * CFrame.new(0, 8.9, 0), color, Enum.Material.Fabric)
	canopy.CanCollide = false
	cylinder(
		set,
		"PuncakPayung",
		2.2,
		0.5,
		cf * CFrame.new(0, 9.25, 0),
		color,
		Enum.Material.Fabric
	).CanCollide =
		false
	cylinder(set, "KancingPayung", 0.3, 0.3, cf * CFrame.new(0, 9.65, 0), CREAM).CanCollide = false
	cup(set, cf * CFrame.new(-0.8, 2.71, 0.1))
	cup(set, cf * CFrame.new(0.8, 2.71, -0.1))
	chair(set, cf * CFrame.new(-3.3, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), template)
	chair(set, cf * CFrame.new(3.3, 0, 0) * CFrame.Angles(0, math.rad(90), 0), template)
	set.Parent = parent
end

local function planter(parent: Instance, cf: CFrame)
	part(
		parent,
		"Pot",
		Vector3.new(2.6, 2, 2.6),
		cf * CFrame.new(0, 1, 0),
		rgb(214, 206, 192),
		Enum.Material.Concrete
	)
	local leaves = part(
		parent,
		"Daun",
		Vector3.new(3.4, 3.4, 3.4),
		cf * CFrame.new(0, 3.3, 0),
		rgb(70, 150, 84),
		Enum.Material.Grass
	)
	leaves.Shape = Enum.PartType.Ball
	leaves.CanCollide = false
end

-- ---------------------------------------------------------------- Cafe Startduck (kota kecil)

-- Bola lonjong (untuk patung bebek): Part dengan SpecialMesh bulat.
local function blob(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, name, size, cf, color)
	p.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Patung bebek kuning memegang cangkir; `cf` = titik di atap, bebek menghadap -Z lokal.
local function duck(parent: Instance, cf: CFrame)
	local yellow, orange = rgb(255, 208, 60), rgb(245, 140, 40)
	local model = Instance.new("Model")
	model.Name = "PatungBebek"
	cylinder(model, "Alas", 3.4, 0.8, cf * CFrame.new(0, 0.4, 0), CREAM, Enum.Material.Marble)
	blob(model, "Badan", Vector3.new(5.2, 4.4, 6.4), cf * CFrame.new(0, 3.0, 0.4), yellow)
	blob(
		model,
		"Ekor",
		Vector3.new(2.2, 2, 2.6),
		cf * CFrame.new(0, 4.2, 3.2) * CFrame.Angles(math.rad(35), 0, 0),
		yellow
	)
	blob(model, "Kepala", Vector3.new(3.6, 3.6, 3.6), cf * CFrame.new(0, 6.3, -1.6), yellow)
	blob(model, "Paruh", Vector3.new(2, 0.8, 1.8), cf * CFrame.new(0, 5.9, -3.5), orange)
	for _, sx in { -1, 1 } do
		blob(
			model,
			"Mata",
			Vector3.new(0.6, 0.7, 0.4),
			cf * CFrame.new(sx * 0.85, 6.9, -3.15),
			rgb(30, 28, 34)
		)
		blob(
			model,
			"Sayap",
			Vector3.new(0.9, 2.6, 3.6),
			cf * CFrame.new(sx * 2.5, 3.2, 0.6) * CFrame.Angles(0, 0, math.rad(sx * -12)),
			rgb(250, 190, 50)
		)
		blob(model, "Kaki", Vector3.new(1.4, 0.5, 2), cf * CFrame.new(sx * 1.1, 1.0, -1.6), orange)
	end
	-- cangkir kopi besar di depan bebek
	cylinder(model, "CangkirBesar", 1.0, 1.5, cf * CFrame.new(2.6, 1.55, -2.6), CREAM).CanCollide =
		false
	cylinder(model, "KopiBesar", 0.85, 0.1, cf * CFrame.new(2.6, 2.32, -2.6), rgb(86, 54, 34)).CanCollide =
		false
	model.Parent = parent
end

-- Gedung kafe kota kecil: depan di z = 428,5 menghadap +Z, atap y = 18, trotoar y = 1.
-- Trotoar depan sempit, jadi teras ada di sisi timur gedung (trotoar lebar di pojok simpang).
local function startduck(map: Instance, template: Instance?)
	local old = map:FindFirstChild("Startduck")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Startduck"
	local brown, yellow = rgb(96, 62, 40), rgb(255, 214, 90)

	-- papan nama gedung lama: ganti tulisannya
	local residential = map:FindFirstChild("Residential")
	local buildings = residential and residential:FindFirstChild("Buildings")
	local downtown = buildings and buildings:FindFirstChild("Downtown")
	local kafe = downtown and downtown:FindFirstChild("Kafe")
	local sign = kafe and kafe:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		sign.Size = Vector3.new(19, 3, 0.4)
		sign.Color = brown
		local label = sign:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = "CAFE STARTDUCK"
			label.TextColor3 = yellow
		end
	end

	-- bebek di atap, menghadap jalan (+Z)
	duck(f, CFrame.new(184, 18, 423) * CFrame.Angles(0, math.pi, 0))

	-- lambang bundar di dinding depan (bebek, bukan lambang merek mana pun)
	local logo = cylinder(
		f,
		"Lambang",
		2.1,
		0.3,
		CFrame.new(175.6, 13.2, 428.4) * CFrame.Angles(math.rad(90), 0, 0),
		yellow
	)
	logo.CanCollide = false
	local plate =
		part(f, "LambangTeks", Vector3.new(3, 3, 0.1), CFrame.new(175.6, 13.2, 428.62), yellow)
	plate.Transparency = 1
	plate.CanCollide = false
	text(plate, Enum.NormalId.Back, "\u{1F986}", brown)

	-- tenda bergaris di atas etalase
	for i = 0, 8 do
		local stripe = part(
			f,
			"Tenda",
			Vector3.new(2.2, 0.25, 3.4),
			CFrame.new(175.2 + i * 2.2, 7.4, 430) * CFrame.Angles(math.rad(14), 0, 0),
			if i % 2 == 0 then brown else CREAM,
			Enum.Material.Fabric
		)
		stripe.CanCollide = false
	end
	planter(f, CFrame.new(173, 1, 430.4))
	planter(f, CFrame.new(195, 1, 430.4))
	local menu = part(
		f,
		"PapanMenu",
		Vector3.new(3, 4.4, 0.3),
		CFrame.new(190.4, 3.2, 431.6) * CFrame.Angles(math.rad(-12), math.rad(-15), 0),
		DARK
	)
	text(menu, Enum.NormalId.Back, "KOPI\nCOKELAT\nKUE", CREAM)

	-- teras di sisi timur: lantai kayu, tiga meja berpayung, pagar ke arah jalan
	local floor = CFrame.new(201, 1.2, 418)
	part(
		f,
		"Teras",
		Vector3.new(11.6, 0.2, 21),
		CFrame.new(201, 1.1, 418),
		WOOD,
		Enum.Material.WoodPlanks
	)
	local colors = { yellow, rgb(214, 120, 60), rgb(250, 242, 226) }
	for index, z in { -6.6, 0, 6.6 } do
		tableSet(f, floor * CFrame.new(0, 0, z), colors[index], template)
	end
	part(f, "Pagar", Vector3.new(0.3, 0.3, 21), floor * CFrame.new(5.6, 2.2, 0), CREAM)
	for i = 0, 4 do
		part(
			f,
			"TiangPagar",
			Vector3.new(0.3, 2.2, 0.3),
			floor * CFrame.new(5.6, 1.1, -10.3 + i * 5.15),
			CREAM
		)
	end

	f.Parent = map
end

return function(): number
	local map = Workspace:FindFirstChild("Map")
	if map == nil then
		warn("[BuildCafe] Workspace.Map tidak ditemukan")
		return 0
	end
	local old = map:FindFirstChild("KafeKota")
	if old then
		old:Destroy()
	end
	local third = ServerStorage:FindFirstChild("AsetPihakKetiga")
	local template = if third then third:FindFirstChild("KursiKafe") else nil

	local f = Instance.new("Folder")
	f.Name = "KafeKota"
	local o = ORIGIN
	local half = DECK_DEPTH / 2
	part(
		f,
		"Teras",
		Vector3.new(DECK_WIDTH, 0.3, DECK_DEPTH),
		o * CFrame.new(0, 0.15, half),
		WOOD,
		Enum.Material.WoodPlanks
	)
	local floor = o * CFrame.new(0, 0.3, 0)
	for _, sx in { -1, 1 } do
		local length = DECK_WIDTH / 2 - 4
		part(
			f,
			"Pagar",
			Vector3.new(length, 0.3, 0.3),
			floor * CFrame.new(sx * (4 + length / 2), 2.2, DECK_DEPTH - 0.3),
			CREAM
		)
		for i = 0, 3 do
			part(
				f,
				"TiangPagar",
				Vector3.new(0.3, 2.2, 0.3),
				floor * CFrame.new(sx * (4.2 + i * (length - 0.4) / 3), 1.1, DECK_DEPTH - 0.3),
				CREAM
			)
		end
		planter(f, floor * CFrame.new(sx * (DECK_WIDTH / 2 - 1.6), 0, DECK_DEPTH - 1.8))
		planter(f, floor * CFrame.new(sx * 5.4, 0, DECK_DEPTH - 1.8))
	end
	local spots = {
		Vector3.new(-11, 0, 5),
		Vector3.new(-11, 0, 12),
		Vector3.new(11, 0, 12),
		Vector3.new(-2.5, 0, 12.5),
	}
	for index, spot in spots do
		tableSet(f, floor * CFrame.new(spot), UMBRELLAS[index], template)
	end
	local c = floor * CFrame.new(COUNTER.X, 0, COUNTER.Z - 1.4)
	part(
		f,
		"Konter",
		Vector3.new(8, 3.4, 2.2),
		c * CFrame.new(0, 1.7, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	part(f, "AtasKonter", Vector3.new(8.4, 0.3, 2.6), c * CFrame.new(0, 3.55, 0), DARK)
	part(
		f,
		"MesinKopi",
		Vector3.new(2.2, 1.8, 1.4),
		c * CFrame.new(-2.2, 4.6, -0.2),
		rgb(196, 200, 208),
		Enum.Material.Metal
	)
	part(f, "KepalaMesin", Vector3.new(1.6, 0.5, 0.5), c * CFrame.new(-2.2, 4.3, 0.7), DARK)
	cup(f, c * CFrame.new(0.2, 3.7, 0.2))
	cup(f, c * CFrame.new(1.4, 3.7, -0.2))
	part(
		f,
		"Toples",
		Vector3.new(1, 1.4, 1),
		c * CFrame.new(3, 4.4, 0),
		rgb(200, 230, 240),
		Enum.Material.Glass
	).Transparency =
		0.4
	for _, sx in { -1, 1 } do
		part(
			f,
			"TiangKonter",
			Vector3.new(0.3, 5, 0.3),
			c * CFrame.new(sx * 3.9, 6.2, -0.8),
			DARK,
			Enum.Material.Metal
		)
	end
	local board =
		part(f, "PapanKasir", Vector3.new(8.4, 1.8, 0.3), c * CFrame.new(0, 8.6, -0.8), DARK)
	text(board, Enum.NormalId.Back, "KASIR KAFE", rgb(255, 214, 120))
	local menu = part(
		f,
		"PapanMenu",
		Vector3.new(3, 4.4, 0.3),
		floor
			* CFrame.new(-5.6, 2.2, DECK_DEPTH - 4.4)
			* CFrame.Angles(math.rad(-12), math.rad(20), 0),
		DARK
	)
	text(menu, Enum.NormalId.Back, "KOPI\nTEH\nDONAT", CREAM)
	f.Parent = map
	startduck(map, template)
	local made = map:FindFirstChild("Startduck")
	return #f:GetDescendants() + (if made then #made:GetDescendants() else 0)
end
