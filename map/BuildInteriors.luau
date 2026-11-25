--[[
	ROBLOCK CITY: isi bangunan umum (lobi Rumah Sakit, ruang tunggu Bandara, dan ROBLOCK Mega Mall).

	Ruang dalam dibangun tepat DI ATAS bangunannya (y = 2000, tidak terlihat dari tanah), supaya posisi
	mendatar pemain tidak berubah saat masuk: GPS, misi, dan pengawas pekerjaan tetap benar. Jangan taruh di
	bawah tanah: kabut Atmosphere menebal di ketinggian rendah. Pemain berpindah lewat
	portal (part bertag "Portal", lihat src/server/Services/PortalService.luau).

	Pakai (Studio, mode Edit):
	  require(game.ServerStorage.MapBuilders.BuildInteriors)()

	Hasil: Workspace.Map.Interiors (dibuat ulang setiap dijalankan). Menambah ruang baru =
	menambah satu fungsi pembangun + sepasang portal di bawah. Isi rumah pemain TIDAK di sini
	(itu dirakit HouseService dari HouseConfig.INTERIOR).
]]

local CollectionService = game:GetService("CollectionService")

local rgb = Color3.fromRGB
local DEPTH = 2000 -- ketinggian lantai ruang dalam
local WHITE = rgb(246, 248, 250)
local TEAL = rgb(46, 170, 160)
local PINK = rgb(244, 150, 180)
local DARK = rgb(52, 58, 70)
local WOOD = rgb(160, 112, 70)
local LAMP = rgb(255, 246, 224)

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
	p.CastShadow = false -- di dalam ruangan tidak ada matahari
	p.Parent = parent
	return p
end

local function text(
	part: BasePart,
	face: Enum.NormalId,
	label: string,
	color: Color3,
	background: Color3?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = if background then 0 else 1
	l.BackgroundColor3 = background or Color3.new()
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = label
	l.Parent = gui
	gui.Parent = part
end

-- Kotak ruangan: lantai, plafon, empat dinding, dan lampu plafon. origin = tengah lantai.
local function room(
	parent: Instance,
	origin: CFrame,
	w: number,
	d: number,
	h: number,
	floor: Color3,
	wall: Color3,
	lampsX: number,
	lampsZ: number
)
	local shell = {
		P(parent, "Lantai", Vector3.new(w + 12, 6, d + 12), origin * CFrame.new(0, -3, 0), floor),
		P(
			parent,
			"Plafon",
			Vector3.new(w + 12, 6, d + 12),
			origin * CFrame.new(0, h + 3, 0),
			WHITE
		),
		P(
			parent,
			"DindingUtara",
			Vector3.new(w + 12, h + 12, 6),
			origin * CFrame.new(0, h / 2, -d / 2 - 3),
			wall
		),
		P(
			parent,
			"DindingSelatan",
			Vector3.new(w + 12, h + 12, 6),
			origin * CFrame.new(0, h / 2, d / 2 + 3),
			wall
		),
		P(
			parent,
			"DindingBarat",
			Vector3.new(6, h + 12, d),
			origin * CFrame.new(-w / 2 - 3, h / 2, 0),
			wall
		),
		P(
			parent,
			"DindingTimur",
			Vector3.new(6, h + 12, d),
			origin * CFrame.new(w / 2 + 3, h / 2, 0),
			wall
		),
	}
	-- Kulit ruangan tebal (6 stud) dan berbayang supaya sinar matahari tidak menembus ke dalam.
	for _, part in shell do
		part.CastShadow = true
	end
	for ix = 1, lampsX do
		for iz = 1, lampsZ do
			local x = -w / 2 + (ix - 0.5) * w / lampsX
			local z = -d / 2 + (iz - 0.5) * d / lampsZ
			local lamp = P(
				parent,
				"LampuPlafon",
				Vector3.new(5, 0.4, 5),
				origin * CFrame.new(x, h - 0.2, z),
				LAMP,
				Enum.Material.Neon,
				false
			)
			local light = Instance.new("PointLight")
			-- Redup saja: di ruang tertutup, lampu yang terang membuat semuanya putih silau.
			light.Range = 32
			light.Brightness = 0.25
			light.Color = LAMP
			light.Shadows = false
			light.Parent = lamp
		end
	end
end

local function portal(part: BasePart, id: string, target: string, label: string)
	part:SetAttribute("PortalId", id)
	part:SetAttribute("PortalTarget", target)
	part:SetAttribute("PortalText", label)
	CollectionService:AddTag(part, "Portal")
end

-- Pintu keluar di dinding selatan ruangan (menghadap ke dalam) + portal luar di depan bangunan.
local function doors(
	parent: Instance,
	origin: CFrame,
	d: number,
	id: string,
	outside: CFrame,
	outsideSize: Vector3
)
	local exit = P(
		parent,
		"PintuKeluar",
		Vector3.new(8, 8, 0.4),
		origin * CFrame.new(0, 4, d / 2 - 0.2),
		rgb(120, 190, 230),
		Enum.Material.Glass
	)
	text(exit, Enum.NormalId.Front, "KELUAR", WHITE)
	portal(exit, id .. "Dalam", id .. "Luar", "Keluar")
	local entry = P(parent, "PintuMasuk", outsideSize, outside, WHITE, nil, false)
	entry.Transparency = 1
	portal(entry, id .. "Luar", id .. "Dalam", "Masuk")
end

local function chair(parent: Instance, cf: CFrame, color: Color3)
	P(parent, "Kursi", Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(0, 1.5, 0), color)
	P(parent, "SandaranKursi", Vector3.new(2.2, 2.2, 0.4), cf * CFrame.new(0, 2.6, 0.9), color)
	P(parent, "KakiKursi", Vector3.new(1.6, 1.3, 1.6), cf * CFrame.new(0, 0.65, 0), DARK)
end

local function plant(parent: Instance, cf: CFrame)
	local pot = P(
		parent,
		"Pot",
		Vector3.new(2, 2, 2),
		cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(190, 110, 70)
	)
	pot.Shape = Enum.PartType.Cylinder
	local leaves = P(
		parent,
		"Daun",
		Vector3.new(3.4, 3.4, 3.4),
		cf * CFrame.new(0, 3.4, 0),
		rgb(70, 160, 80),
		nil,
		false
	)
	leaves.Shape = Enum.PartType.Ball
end

--------------------------------------------------------------------------
-- Lobi Rumah Sakit (di atas Rumah Sakit kota kecil)
--------------------------------------------------------------------------

local function hospital(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "RumahSakit"
	local o = CFrame.new(40, DEPTH, 412)
	local w, d, h = 52, 34, 13
	room(f, o, w, d, h, rgb(196, 208, 214), rgb(226, 238, 234), 3, 2)
	P(
		f,
		"GarisDinding",
		Vector3.new(w, 1, 0.2),
		o * CFrame.new(0, 4, -d / 2 + 0.1),
		TEAL,
		nil,
		false
	)
	-- pintu keluar; portal luar di pintu depan Rumah Sakit (menghadap selatan)
	doors(
		f,
		o,
		d,
		"rumahSakit",
		CFrame.new(40, 4.25, 429.2) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(10, 6.5, 1)
	)

	-- meja pendaftaran + papan nama
	P(f, "MejaPendaftaran", Vector3.new(14, 3.6, 3), o * CFrame.new(0, 1.8, -7), WHITE)
	P(f, "AtasMeja", Vector3.new(14.4, 0.3, 3.4), o * CFrame.new(0, 3.75, -7), TEAL)
	P(f, "Komputer", Vector3.new(2, 1.5, 0.3), o * CFrame.new(-3, 4.7, -7.4), DARK, nil, false)
	chair(f, o * CFrame.new(0, 0, -10.5) * CFrame.Angles(0, math.pi, 0), TEAL)
	local board = P(
		f,
		"PapanPendaftaran",
		Vector3.new(16, 2.6, 0.3),
		o * CFrame.new(0, 8.6, -d / 2 + 0.2),
		TEAL,
		nil,
		false
	)
	text(board, Enum.NormalId.Back, "PENDAFTARAN", WHITE)
	local badge = P(
		f,
		"Lencana",
		Vector3.new(0.3, 3, 3),
		o * CFrame.new(11, 8.6, -d / 2 + 0.25) * CFrame.Angles(0, math.pi / 2, 0),
		PINK,
		nil,
		false
	)
	badge.Shape = Enum.PartType.Cylinder

	-- ruang tunggu: dua baris kursi menghadap meja
	for row = 0, 1 do
		for i = 0, 4 do
			chair(
				f,
				o * CFrame.new(-22 + i * 2.8, 0, 3 + row * 5),
				if (i + row) % 2 == 0 then TEAL else PINK
			)
		end
	end
	P(
		f,
		"MejaMajalah",
		Vector3.new(4, 1.4, 2.4),
		o * CFrame.new(-6, 0.7, 5.5),
		WOOD,
		Enum.Material.WoodPlanks
	)
	plant(f, o * CFrame.new(-24, 0, -14))
	plant(f, o * CFrame.new(-24, 0, 14))

	-- ruang periksa: dua ranjang dengan tirai
	for i = 0, 1 do
		local bed = o * CFrame.new(13 + i * 9, 0, -9)
		P(
			f,
			"Ranjang",
			Vector3.new(4.4, 2, 8.4),
			bed * CFrame.new(0, 1, 0),
			rgb(214, 220, 228),
			Enum.Material.Metal
		)
		P(f, "Kasur", Vector3.new(4, 0.7, 8), bed * CFrame.new(0, 2.35, 0), WHITE)
		P(
			f,
			"Selimut",
			Vector3.new(4.1, 0.25, 4.6),
			bed * CFrame.new(0, 2.8, 1.4),
			if i == 0 then TEAL else PINK
		)
		P(f, "Bantal", Vector3.new(3, 0.5, 1.6), bed * CFrame.new(0, 2.95, -3), WHITE)
		P(
			f,
			"Tirai",
			Vector3.new(0.2, 9, 9.5),
			bed * CFrame.new(-4.4, 4.5, 0),
			rgb(196, 232, 232),
			nil,
			false
		)
		local pole = P(
			f,
			"TiangInfus",
			Vector3.new(6.5, 0.3, 0.3),
			bed * CFrame.new(2.9, 3.25, -3) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(190, 196, 204),
			Enum.Material.Metal,
			false
		)
		pole.Shape = Enum.PartType.Cylinder
		P(
			f,
			"KantongInfus",
			Vector3.new(0.9, 1.3, 0.4),
			bed * CFrame.new(2.9, 6, -3),
			rgb(200, 236, 250),
			Enum.Material.Glass,
			false
		)
	end
	local sign = P(
		f,
		"PapanPeriksa",
		Vector3.new(12, 2, 0.3),
		o * CFrame.new(17, 10, -d / 2 + 0.2),
		PINK,
		nil,
		false
	)
	text(sign, Enum.NormalId.Back, "RUANG PERIKSA", WHITE)

	-- mesin minuman dan apotek
	local vending = P(
		f,
		"MesinMinuman",
		Vector3.new(2.6, 7, 3.4),
		o * CFrame.new(w / 2 - 1.4, 3.5, 6),
		rgb(70, 120, 210)
	)
	P(
		f,
		"KacaMesin",
		Vector3.new(0.2, 4, 2.6),
		vending.CFrame * CFrame.new(-1.3, 0.8, 0),
		rgb(200, 236, 250),
		Enum.Material.Neon,
		false
	)
	P(f, "MejaApotek", Vector3.new(3, 3.6, 10), o * CFrame.new(w / 2 - 6, 1.8, 13 - 2), WHITE)
	local apotek = P(
		f,
		"PapanApotek",
		Vector3.new(0.3, 2, 9),
		o * CFrame.new(w / 2 - 0.2, 8.6, 11),
		TEAL,
		nil,
		false
	)
	text(apotek, Enum.NormalId.Left, "APOTEK", WHITE)
	f.Parent = parent
end

--------------------------------------------------------------------------
-- Ruang tunggu Bandara (di atas terminal)
--------------------------------------------------------------------------

local function airport(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Bandara"
	local o = CFrame.new(-990, DEPTH, 695)
	local w, d, h = 84, 40, 16
	room(f, o, w, d, h, rgb(178, 186, 198), rgb(238, 236, 228), 4, 2)
	-- dinding kaca terang di sisi utara (seolah menghadap landasan)
	P(
		f,
		"JendelaBesar",
		Vector3.new(w - 8, 9, 0.2),
		o * CFrame.new(0, 8, -d / 2 + 0.1),
		rgb(170, 216, 255),
		Enum.Material.Neon,
		false
	)
	for i = 0, 6 do
		P(
			f,
			"KusenJendela",
			Vector3.new(0.6, 9, 0.5),
			o * CFrame.new(-36 + i * 12, 8, -d / 2 + 0.3),
			WHITE,
			nil,
			false
		)
	end
	-- portal luar di depan terminal (menghadap utara, ke arah jalan)
	doors(f, o, d, "bandara", CFrame.new(-975, 4, 641), Vector3.new(14, 7, 1))

	-- konter check-in
	for i = 1, 5 do
		local c = o * CFrame.new(-36 + i * 10, 0, -6)
		P(f, "KonterCheckIn", Vector3.new(6, 3.6, 2.6), c * CFrame.new(0, 1.8, 0), WHITE)
		P(
			f,
			"AtasKonter",
			Vector3.new(6.3, 0.3, 2.9),
			c * CFrame.new(0, 3.75, 0),
			rgb(60, 120, 210)
		)
		P(f, "Timbangan", Vector3.new(3, 0.6, 3), c * CFrame.new(4.4, 0.3, 0), DARK)
		local board = P(
			f,
			"PapanCheckIn",
			Vector3.new(6, 1.6, 0.3),
			c * CFrame.new(0, 8, -1),
			rgb(60, 120, 210),
			nil,
			false
		)
		text(board, Enum.NormalId.Back, "CHECK-IN " .. i, WHITE)
		P(f, "TiangPapan", Vector3.new(0.3, 4, 0.3), c * CFrame.new(0, 5.4, -1), DARK, nil, false)
	end

	-- papan keberangkatan
	local departures = P(
		f,
		"PapanKeberangkatan",
		Vector3.new(0.4, 8, 20),
		o * CFrame.new(w / 2 - 0.3, 9, -4),
		rgb(20, 24, 32),
		nil,
		false
	)
	text(
		departures,
		Enum.NormalId.Left,
		"KEBERANGKATAN\nPulau Pantai   09.30\nKota Awan      10.15\nPulau Hijau    11.00\nTeluk Biru     12.45",
		rgb(255, 214, 80)
	)

	-- kursi tunggu: tiga baris
	for row = 0, 2 do
		for i = 0, 7 do
			chair(
				f,
				o * CFrame.new(-38 + i * 2.8, 0, 5 + row * 5),
				if row % 2 == 0 then rgb(60, 120, 210) else rgb(250, 190, 70)
			)
		end
	end
	-- koper dan troli
	local cases = { rgb(230, 80, 80), rgb(70, 170, 110), rgb(250, 190, 70), rgb(150, 100, 200) }
	for i, color in cases do
		P(
			f,
			"Koper",
			Vector3.new(1.6, 2.6, 1),
			o * CFrame.new(-12 + i * 2.4, 1.3, 9 + (i % 2) * 2),
			color
		)
	end
	P(
		f,
		"Troli",
		Vector3.new(3, 0.5, 5),
		o * CFrame.new(4, 1, 12),
		rgb(190, 196, 204),
		Enum.Material.Metal
	)
	P(
		f,
		"PeganganTroli",
		Vector3.new(3, 3, 0.3),
		o * CFrame.new(4, 2.5, 14.4),
		rgb(190, 196, 204),
		Enum.Material.Metal
	)

	-- kafe bandara
	local cafe = o * CFrame.new(28, 0, 10)
	P(
		f,
		"KonterKafe",
		Vector3.new(12, 3.6, 3),
		cafe * CFrame.new(0, 1.8, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	P(f, "AtasKafe", Vector3.new(12.4, 0.3, 3.4), cafe * CFrame.new(0, 3.75, 0), rgb(90, 64, 44))
	local cafeSign = P(
		f,
		"PapanKafe",
		Vector3.new(12, 2.2, 0.3),
		cafe * CFrame.new(0, 9, 3),
		rgb(250, 190, 70),
		nil,
		false
	)
	text(cafeSign, Enum.NormalId.Front, "KAFE BANDARA", rgb(90, 64, 44))
	P(f, "TiangKafe", Vector3.new(0.4, 5.4, 0.4), cafe * CFrame.new(-5.6, 6.3, 3), DARK, nil, false)
	P(f, "TiangKafe", Vector3.new(0.4, 5.4, 0.4), cafe * CFrame.new(5.6, 6.3, 3), DARK, nil, false)
	for i = 0, 2 do
		local cup = P(
			f,
			"Gelas",
			Vector3.new(0.8, 0.6, 0.6),
			cafe * CFrame.new(-3 + i * 3, 4.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WHITE,
			nil,
			false
		)
		cup.Shape = Enum.PartType.Cylinder
	end
	plant(f, o * CFrame.new(-40, 0, -17))
	plant(f, o * CFrame.new(40, 0, 17))
	f.Parent = parent
end

--------------------------------------------------------------------------
-- ROBLOCK Mega Mall (di atas gedung mall pusat kota)
--------------------------------------------------------------------------

-- Toko di dalam mall. Titik kasir Toko Hewan dan Toko Baju harus sama dengan SHOP_POSITION di
-- PetConfig / FashionConfig (tombolnya dipasang PetService / FashionService di titik itu).
local function shop(
	parent: Instance,
	origin: CFrame,
	x: number,
	title: string,
	color: Color3,
	counter: Color3
)
	local c = origin * CFrame.new(x, 0, -22)
	P(parent, "DindingToko", Vector3.new(22, 12, 1), c * CFrame.new(0, 6, -5.4), color)
	for _, sx in { -1, 1 } do
		P(parent, "SekatToko", Vector3.new(1, 12, 10), c * CFrame.new(sx * 11, 6, -0.5), color)
	end
	P(parent, "Kasir", Vector3.new(10, 3.4, 2.6), c * CFrame.new(0, 1.7, 2), rgb(210, 214, 222))
	P(parent, "AtasKasir", Vector3.new(10.4, 0.3, 3), c * CFrame.new(0, 3.55, 2), counter)
	for i = -1, 1 do
		P(
			parent,
			"Rak",
			Vector3.new(5, 0.4, 2),
			c * CFrame.new(i * 6.4, 4, -4.2),
			WOOD,
			Enum.Material.WoodPlanks
		)
		P(
			parent,
			"Rak",
			Vector3.new(5, 0.4, 2),
			c * CFrame.new(i * 6.4, 7, -4.2),
			WOOD,
			Enum.Material.WoodPlanks
		)
		P(
			parent,
			"Barang",
			Vector3.new(1.6, 1.6, 1.6),
			c * CFrame.new(i * 6.4 - 1.2, 5, -4.2),
			counter,
			nil,
			false
		)
		P(
			parent,
			"Barang",
			Vector3.new(1.4, 2, 1.4),
			c * CFrame.new(i * 6.4 + 1.2, 5.2, -4.2),
			color:Lerp(Color3.new(1, 1, 1), 0.4),
			nil,
			false
		)
		P(
			parent,
			"Barang",
			Vector3.new(2.4, 1.4, 1.4),
			c * CFrame.new(i * 6.4, 7.9, -4.2),
			counter,
			nil,
			false
		)
	end
	local board = P(
		parent,
		"PapanToko",
		Vector3.new(20, 2.6, 0.4),
		c * CFrame.new(0, 13.4, 5),
		counter,
		nil,
		false
	)
	text(board, Enum.NormalId.Back, title, WHITE)
end

local function mall(parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Mall"
	local o = CFrame.new(525, DEPTH, -603)
	local w, d, h = 110, 62, 18
	-- lantai gelap dan sedikit lampu: ruang besar berdinding terang cepat jadi putih silau
	room(f, o, w, d, h, rgb(120, 126, 140), rgb(214, 206, 192), 3, 1)
	-- pintu utama mall menghadap selatan
	doors(
		f,
		o,
		d,
		"mall",
		CFrame.new(525, 4.5, -542.6) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(14, 9, 1)
	)

	-- empat toko di sisi utara
	shop(f, o, -39, "TOKO HEWAN", rgb(250, 214, 226), rgb(236, 110, 160))
	shop(f, o, -13, "TOKO BAJU", rgb(214, 232, 250), rgb(80, 150, 235))
	shop(f, o, 13, "TOKO MAINAN", rgb(250, 240, 200), rgb(240, 170, 50))
	shop(f, o, 39, "KAFE MALL", rgb(236, 222, 204), rgb(150, 100, 70))

	-- atrium: air mancur, bangku, tanaman
	local basin = P(
		f,
		"KolamAtrium",
		Vector3.new(1.4, 16, 16),
		o * CFrame.new(0, 0.7, 6) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(214, 218, 226)
	)
	basin.Shape = Enum.PartType.Cylinder
	local water = P(
		f,
		"AirAtrium",
		Vector3.new(0.3, 14, 14),
		o * CFrame.new(0, 1.35, 6) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(110, 196, 240),
		Enum.Material.Glass,
		false
	)
	water.Shape = Enum.PartType.Cylinder
	local jet = P(
		f,
		"PancuranAtrium",
		Vector3.new(5, 1.2, 1.2),
		o * CFrame.new(0, 3.6, 6) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(180, 224, 250),
		Enum.Material.Glass,
		false
	)
	jet.Shape = Enum.PartType.Cylinder
	for _, sx in { -1, 1 } do
		P(
			f,
			"BangkuMall",
			Vector3.new(8, 1.4, 2.6),
			o * CFrame.new(sx * 16, 0.7, 6),
			WOOD,
			Enum.Material.WoodPlanks
		)
		plant(f, o * CFrame.new(sx * 24, 0, 6))
		plant(f, o * CFrame.new(sx * 50, 0, 26))
	end
	-- karpet jalur dan papan selamat datang
	P(
		f,
		"KarpetMall",
		Vector3.new(14, 0.1, 22),
		o * CFrame.new(0, 0.05, 20),
		rgb(200, 70, 80),
		Enum.Material.Fabric,
		false
	)
	local welcome = P(
		f,
		"PapanMall",
		Vector3.new(34, 3.4, 0.4),
		o * CFrame.new(0, 15, d / 2 - 0.4),
		rgb(60, 90, 160),
		nil,
		false
	)
	text(welcome, Enum.NormalId.Front, "ROBLOCK MEGA MALL", rgb(255, 214, 80))
	f.Parent = parent
end

return function(): number
	local map = workspace:FindFirstChild("Map")
	if not map then
		warn("[BuildInteriors] Workspace.Map tidak ditemukan")
		return 0
	end
	local old = map:FindFirstChild("Interiors")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Interiors"
	hospital(root)
	airport(root)
	mall(root)
	root.Parent = map
	return #root:GetDescendants()
end
