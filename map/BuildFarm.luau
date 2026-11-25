--[[
	ROBLOCK CITY: Pasar Tani dan Kebun Warga (untuk sistem perkebunan, lihat src/shared/FarmConfig.luau).

	Letaknya di pedesaan, di selatan jalan desa dan di timur lumbung (tanah datar, x -720..-600, z 325..430).
	Pakai (Studio, mode Edit):
	  require(game.ServerStorage.MapBuilders.BuildFarm)()

	Hasil: Workspace.Map.Farm (dibuat ulang setiap dijalankan)
	  - 8 petak tanah bertag "FarmPlot" (atribut PlotIndex 1..8) dengan tombol "Kebun"
	  - kasir pasar bertag "FarmMarket" dengan tombol "Buka pasar"
	Tanaman digambar di client masing-masing pemain (FarmController), bukan di sini.
]]

local CollectionService = game:GetService("CollectionService")

local rgb = Color3.fromRGB
local ORIGIN = CFrame.new(-660, 0.1, 372)
local WOOD = rgb(160, 112, 70)
local DARK_WOOD = rgb(110, 78, 50)
local SOIL = rgb(104, 72, 48)
local PLANKS = Enum.Material.WoodPlanks

local function P(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
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
	p.CanCollide = collide ~= false
	p.CastShadow = collide ~= false
	p.Parent = parent
	return p
end

local function sign(part: BasePart, face: Enum.NormalId, label: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = label
	l.Parent = gui
	gui.Parent = part
end

local function prompt(part: BasePart, action: string, object: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = "FarmPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.2
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = part
end

local function ball(parent: Instance, cf: CFrame, size: number, color: Color3)
	local b = P(parent, "Buah", Vector3.one * size, cf, color, nil, false)
	b.Shape = Enum.PartType.Ball
end

-- Lapak pasar: meja, atap bergaris, dan peti berisi hasil bumi.
local function stall(parent: Instance, cf: CFrame, awning: Color3, produce: Color3)
	P(parent, "MejaLapak", Vector3.new(9, 3, 3.4), cf * CFrame.new(0, 1.5, 0), WOOD, PLANKS)
	for _, x in { -4.2, 4.2 } do
		P(
			parent,
			"TiangLapak",
			Vector3.new(0.5, 8.4, 0.5),
			cf * CFrame.new(x, 4.2, 1.4),
			DARK_WOOD,
			PLANKS,
			false
		)
	end
	for i = 0, 4 do
		P(
			parent,
			"AtapLapak",
			Vector3.new(1.9, 0.3, 6),
			cf * CFrame.new(-3.8 + i * 1.9, 8.5, 0) * CFrame.Angles(math.rad(-10), 0, 0),
			if i % 2 == 0 then awning else rgb(250, 250, 245),
			nil,
			false
		)
	end
	for i = 0, 2 do
		local crate = cf * CFrame.new(-3 + i * 3, 3.5, -0.2)
		P(parent, "Peti", Vector3.new(2.4, 1, 2.4), crate, DARK_WOOD, PLANKS, false)
		for _, off in
			{
				Vector3.new(-0.5, 0.8, -0.4),
				Vector3.new(0.5, 0.8, 0.3),
				Vector3.new(0, 1.2, 0),
				Vector3.new(-0.3, 0.8, 0.6),
			}
		do
			ball(parent, crate * CFrame.new(off), 0.95, produce)
		end
	end
end

return function(): number
	local map = workspace:FindFirstChild("Map")
	if not map then
		warn("[BuildFarm] Workspace.Map tidak ditemukan")
		return 0
	end
	local old = map:FindFirstChild("Farm")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Farm"

	-- ---------------------------------------------------------------- Pasar Tani (sisi utara, dekat jalan)
	local market = Instance.new("Folder")
	market.Name = "PasarTani"
	market.Parent = root
	local m = ORIGIN * CFrame.new(0, 0, -32)
	P(
		market,
		"LantaiPasar",
		Vector3.new(44, 0.4, 16),
		m * CFrame.new(0, 0.2, 0),
		rgb(214, 196, 160),
		Enum.Material.Cobblestone
	)
	stall(market, m * CFrame.new(-14, 0.4, 2), rgb(230, 80, 70), rgb(245, 130, 40))
	stall(market, m * CFrame.new(14, 0.4, 2), rgb(70, 150, 220), rgb(225, 55, 45))
	-- kasir di tengah: tempat beli bibit dan jual hasil panen
	local kasir = P(
		market,
		"Kasir",
		Vector3.new(9, 3.2, 3.4),
		m * CFrame.new(0, 2, 2),
		rgb(90, 160, 90),
		PLANKS
	)
	CollectionService:AddTag(kasir, "FarmMarket")
	prompt(kasir, "Buka pasar", "Pasar Tani")
	for _, x in { -4.2, 4.2 } do
		P(
			market,
			"TiangKasir",
			Vector3.new(0.6, 10, 0.6),
			m * CFrame.new(x, 5.4, 3.4),
			DARK_WOOD,
			PLANKS,
			false
		)
	end
	local board = P(
		market,
		"PapanPasar",
		Vector3.new(14, 3, 0.4),
		m * CFrame.new(0, 11, 3.4),
		rgb(250, 236, 190),
		PLANKS,
		false
	)
	sign(board, Enum.NormalId.Front, "PASAR TANI", rgb(60, 120, 60))
	sign(board, Enum.NormalId.Back, "PASAR TANI", rgb(60, 120, 60))
	for i = 0, 3 do
		local sack = P(
			market,
			"KarungBibit",
			Vector3.new(1.8, 2.2, 1.8),
			m * CFrame.new(-2.7 + i * 1.8, 4.7, 2.4) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(214, 190, 140),
			Enum.Material.Fabric,
			false
		)
		sack.Shape = Enum.PartType.Cylinder
	end

	-- ---------------------------------------------------------------- Kebun Warga (8 petak, 2 baris)
	local garden = Instance.new("Folder")
	garden.Name = "KebunWarga"
	garden.Parent = root
	for index = 1, 8 do
		local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
		local cf = ORIGIN * CFrame.new(-21 + col * 14, 0, 2 + row * 14)
		P(
			garden,
			"BingkaiPetak",
			Vector3.new(11, 0.7, 9),
			cf * CFrame.new(0, 0.35, 0),
			DARK_WOOD,
			PLANKS
		)
		local soil = P(
			garden,
			"Petak" .. index,
			Vector3.new(10, 0.5, 8),
			cf * CFrame.new(0, 0.6, 0),
			SOIL,
			Enum.Material.Ground
		)
		soil:SetAttribute("PlotIndex", index)
		CollectionService:AddTag(soil, "FarmPlot")
		prompt(soil, "Kebun", "Petak " .. index)
	end
	-- pagar keliling dengan gerbang di utara
	local function fence(from: Vector3, to: Vector3)
		local a, b = ORIGIN * from, ORIGIN * to
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		P(
			garden,
			"PagarKebun",
			Vector3.new(0.3, 0.4, length),
			cf * CFrame.new(0, 2.6, 0),
			WOOD,
			PLANKS,
			false
		)
		P(
			garden,
			"PagarKebun",
			Vector3.new(0.3, 0.4, length),
			cf * CFrame.new(0, 1.4, 0),
			WOOD,
			PLANKS,
			false
		)
		for d = 0, length, 6 do
			P(
				garden,
				"TiangPagar",
				Vector3.new(0.5, 3.2, 0.5),
				cf * CFrame.new(0, 1.6, -length / 2 + d),
				DARK_WOOD,
				PLANKS
			)
		end
	end
	fence(Vector3.new(-30, 0, -6), Vector3.new(-6, 0, -6))
	fence(Vector3.new(6, 0, -6), Vector3.new(30, 0, -6))
	fence(Vector3.new(30, 0, -6), Vector3.new(30, 0, 26))
	fence(Vector3.new(30, 0, 26), Vector3.new(-30, 0, 26))
	fence(Vector3.new(-30, 0, 26), Vector3.new(-30, 0, -6))
	local gate = P(
		garden,
		"PapanKebun",
		Vector3.new(12, 2.2, 0.4),
		ORIGIN * CFrame.new(0, 7, -6),
		rgb(250, 236, 190),
		PLANKS,
		false
	)
	sign(gate, Enum.NormalId.Front, "KEBUN WARGA", rgb(110, 78, 50))
	for _, x in { -6, 6 } do
		P(
			garden,
			"TiangGerbang",
			Vector3.new(0.7, 8, 0.7),
			ORIGIN * CFrame.new(x, 4, -6),
			DARK_WOOD,
			PLANKS
		)
	end
	-- orang-orangan sawah dan tong air
	local s = ORIGIN * CFrame.new(26, 0, 22)
	P(
		garden,
		"TiangOrangan",
		Vector3.new(0.4, 7, 0.4),
		s * CFrame.new(0, 3.5, 0),
		DARK_WOOD,
		PLANKS,
		false
	)
	P(
		garden,
		"LenganOrangan",
		Vector3.new(5, 0.4, 0.4),
		s * CFrame.new(0, 5, 0),
		DARK_WOOD,
		PLANKS,
		false
	)
	P(
		garden,
		"BajuOrangan",
		Vector3.new(2.4, 2.6, 1),
		s * CFrame.new(0, 4.4, 0),
		rgb(220, 90, 70),
		Enum.Material.Fabric,
		false
	)
	ball(garden, s * CFrame.new(0, 6.6, 0), 1.8, rgb(236, 210, 150))
	P(
		garden,
		"TopiOrangan",
		Vector3.new(2.8, 0.3, 2.8),
		s * CFrame.new(0, 7.5, 0),
		rgb(200, 160, 80),
		nil,
		false
	)
	local barrel = P(
		garden,
		"TongAir",
		Vector3.new(3, 2.6, 2.6),
		ORIGIN * CFrame.new(-26, 1.5, -2) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(70, 110, 170)
	)
	barrel.Shape = Enum.PartType.Cylinder

	root.Parent = map
	return #root:GetDescendants()
end
