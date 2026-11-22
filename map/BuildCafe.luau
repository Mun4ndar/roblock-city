--!strict
--[[
	ROBLOCK CITY: teras Kafe Kota (pusat kota), tempat usaha kafe pemain (lihat BusinessService).

	Membangun teras kayu di depan gedung Kafe Kota: empat meja berpayung dengan kursi berlengan dan
	cangkir kopi, konter kasir (titiknya harus sama dengan BusinessConfig.POSITION), papan menu, dan
	pot tanaman. Kursinya berisi Seat, jadi pemain bisa duduk dan warga (NpcService, grup "KafeKota")
	duduk minum kopi di sana.

	Kursi berlengan memakai mesh dari model gratis Creator Store "Coffee Shop Cafe Store Building"
	(em0lii0); hanya mesh kursinya yang diambil, semua skripnya dibuang. Templatnya di
	ServerStorage.AsetPihakKetiga.KursiKafe; tanpa templat, kursi dibuat dari part biasa.

	Hasil di Workspace.Map.KafeKota; aman dijalankan ulang.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

-- Depan gedung Kafe Kota: dinding depan di z = -559 menghadap +Z, pintu di x = 20, tanah y = 1,1.
local ORIGIN = CFrame.new(20, 1.1, -559)
local DECK_DEPTH = 17
local DECK_WIDTH = 36
local COUNTER = Vector3.new(8, 0, 3.6) -- relatif ke ORIGIN; = BusinessConfig.POSITION (28, 1.1, -555.4)
local CHAIR_YAW = math.rad(180) -- putaran mesh kursi supaya bagian depannya menghadap -Z lokal

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

-- Silinder tegak (sumbu Y): Roblox membuat silinder sepanjang sumbu X, jadi diputar.
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

-- Kursi menghadap -Z lokal `cf` (titik di lantai teras).
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
	-- payung
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
	-- dua kursi berhadapan di kiri dan kanan meja
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

	-- lantai teras dan pagar rendah di tepi depan
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
		-- pagar di depan, menyisakan jalan masuk selebar 8 di tengah
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

	-- empat meja: dua di kiri pintu, dua di kanan (jalan ke pintu di tengah tetap lapang)
	local spots = {
		Vector3.new(-11, 0, 5),
		Vector3.new(-11, 0, 12),
		Vector3.new(11, 0, 12),
		Vector3.new(-2.5, 0, 12.5),
	}
	for index, spot in spots do
		tableSet(f, floor * CFrame.new(spot), UMBRELLAS[index], template)
	end

	-- konter kasir di kanan pintu, menghadap teras
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

	-- papan menu berdiri di dekat jalan masuk
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
	return #f:GetDescendants()
end
