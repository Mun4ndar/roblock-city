--!nonstrict
--[[
	ROBLOCK CITY: lantai koridor Hotel Bintang Kota (satu lantai saja; lift hanya mengganti nomor lantai di client).
	8 kamar (4 utara + 4 selatan) mengapit koridor 7 stud; inti lift di tengah selatan.
	Tiap kamar: pintu kaca buram berengsel, kamar mandi (toilet, wastafel+cermin, shower kaca), kasur
	(prompt Tidur -> HotelService), TV, meja kerja, kursi, lemari, tirai, jendela lantai ke langit-langit.
	Teks yang berubah menurut lantai memakai tag "HotelLabel" + atribut Pattern ("{N}" = nomor lantai pemain).
	Jalankan setelah BuildHotel: require(MapBuilders.BuildHotelLantai)().
]]
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local MB = script.Parent
local Kit = require(MB:WaitForChild("HotelKit"))
local Furn = require(MB:WaitForChild("HotelFurn"))
local C, M = Kit.C, Enum.Material
local rgb = Color3.fromRGB

local RD = 21.7 -- kedalaman kamar (dari dinding koridor ke kaca)
local DOOR_H, DOOR_W = 8.4, 4.4

local function sub(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function at(c, u, y, v, yaw)
	return Kit.ctx(c.parent, c.frame * CFrame.new(u, y, v) * CFrame.Angles(0, yaw or 0, 0))
end

local function buildRoom(parent, frame, RW, no, doorsFolder)
	local folder = sub(parent, "Kamar" .. no)
	folder:SetAttribute("Nomor", no)
	local c = Kit.ctx(folder, frame)
	local a = -RW / 2
	local d = a + 10.8 -- pusat pintu kamar
	local label = "{N}0" .. no
	-- lantai
	c.box("LantaiKamar", a, RW / 2, 0, 0.12, 0, RD, rgb(230, 200, 160), M.Wood)
	c.box("PlafonKamar", a, RW / 2, 9.7, 10, 0, RD, C.cream, M.SmoothPlastic)
	-- dinding koridor dengan lubang pintu
	c.box("DindingKoridorKiri", a - 0.4, d - DOOR_W / 2, 0, 10, -0.8, 0, C.cream, M.SmoothPlastic)
	c.box(
		"DindingKoridorKanan",
		d + DOOR_W / 2,
		RW / 2 + 0.4,
		0,
		10,
		-0.8,
		0,
		C.cream,
		M.SmoothPlastic
	)
	c.box(
		"DindingKoridorAtas",
		d - DOOR_W / 2,
		d + DOOR_W / 2,
		DOOR_H,
		10,
		-0.8,
		0,
		C.cream,
		M.SmoothPlastic
	)
	c.box(
		"KusenPintuKiri",
		d - DOOR_W / 2 - 0.25,
		d - DOOR_W / 2,
		0,
		DOOR_H,
		-1.0,
		0.1,
		C.gold,
		M.Metal
	)
	c.box(
		"KusenPintuKanan",
		d + DOOR_W / 2,
		d + DOOR_W / 2 + 0.25,
		0,
		DOOR_H,
		-1.0,
		0.1,
		C.gold,
		M.Metal
	)
	c.box(
		"KusenPintuAtas",
		d - DOOR_W / 2 - 0.25,
		d + DOOR_W / 2 + 0.25,
		DOOR_H,
		DOOR_H + 0.3,
		-1.0,
		0.1,
		C.gold,
		M.Metal
	)
	c.box("AmbangPintu", d - DOOR_W / 2, d + DOOR_W / 2, 0, 0.14, -0.8, 0, C.steelD, M.Metal)
	Kit.ctx(c.parent, frame).door(
		"PintuKamar" .. no,
		d - DOOR_W / 2,
		-0.4,
		0,
		DOOR_H,
		1,
		0,
		DOOR_W,
		0,
		1,
		{ frost = true, radius = 4.6, parent = doorsFolder }
	)
	-- pelat nomor kamar (sisi koridor)
	c.sign(
		"NomorKamar",
		d + DOOR_W / 2 + 0.5,
		d + DOOR_W / 2 + 3.1,
		4.8,
		5.9,
		-1.05,
		-0.8,
		Enum.NormalId.Front,
		label,
		{ bg = C.charcoalD, color = C.gold, pps = 50, tag = "HotelLabel" }
	)
	-- lampu dinding sisi koridor
	local sc = c.box(
		"LampuLorong",
		d - DOOR_W / 2 - 2.0,
		d - DOOR_W / 2 - 1.2,
		5.6,
		7.0,
		-1.1,
		-0.8,
		C.warm,
		M.Neon
	)
	-- kamar mandi
	do
		local bx = a + 8
		c.box("DindingMandiSekat1", bx, bx + 0.4, 0, 10, 0, 3.6, C.cream, M.SmoothPlastic)
		c.box("DindingMandiSekat2", bx, bx + 0.4, 0, 10, 7.0, 9.8, C.cream, M.SmoothPlastic)
		c.box("DindingMandiLintel", bx, bx + 0.4, DOOR_H, 10, 3.6, 7.0, C.cream, M.SmoothPlastic)
		c.box("DindingMandiDepan", a, bx + 0.4, 0, 10, 9.8, 10.2, C.cream, M.SmoothPlastic)
		c.box("LantaiMandi", a, bx, 0.12, 0.2, 0, 9.8, rgb(232, 236, 238), M.Marble)
		c.box("UbinDinding1", a, a + 0.12, 0.2, 7.6, 0, 9.8, rgb(228, 234, 238), M.Marble)
		c.box("UbinDinding2", a, bx, 0.2, 7.6, 0.0, 0.12, rgb(228, 234, 238), M.Marble)
		c.box("UbinDinding3", a, bx, 0.2, 7.6, 9.68, 9.8, rgb(228, 234, 238), M.Marble)
		c.box("UbinGarisEmas", a, bx, 4.4, 4.55, 0.0, 0.14, C.gold, M.Metal)
		Kit.ctx(c.parent, frame).door(
			"PintuMandi" .. no,
			bx + 0.2,
			3.6,
			0,
			DOOR_H,
			0,
			1,
			3.4,
			-1,
			0,
			{ frost = true, radius = 3.4, parent = doorsFolder }
		)
		-- toilet di dinding koridor
		local t = at(c, a + 2.4, 0.2, 0.1)
		t.box("ToiletTangki", -0.9, 0.9, 1.4, 3.4, 0.0, 1.0, C.white, M.SmoothPlastic)
		t.box("ToiletAlas", -0.6, 0.6, 0, 1.2, 0.8, 2.4, C.white, M.SmoothPlastic)
		t.box("ToiletMangkuk", -0.95, 0.95, 1.2, 1.9, 0.8, 3.1, C.white, M.SmoothPlastic)
		t.box("ToiletDudukan", -0.85, 0.85, 1.9, 2.0, 1.0, 3.0, C.cream, M.SmoothPlastic)
		t.box("ToiletTombol", -0.3, 0.3, 3.4, 3.55, 0.3, 0.7, C.gold, M.Metal)
		-- wastafel + cermin
		local s = at(c, a + 5.8, 0.2, 0.1)
		s.box("WastafelLemari", -1.7, 1.7, 0, 2.9, 0.0, 1.9, C.walnut, M.Wood)
		s.box("WastafelMeja", -1.8, 1.8, 2.9, 3.2, 0.0, 2.0, C.cream, M.Marble)
		s.box("WastafelCekung", -0.8, 0.8, 3.2, 3.35, 0.4, 1.5, C.white, M.SmoothPlastic)
		s.box("KranTiang", -0.1, 0.1, 3.2, 3.9, 0.3, 0.5, C.gold, M.Metal)
		s.box("KranMulut", -0.1, 0.1, 3.8, 3.95, 0.3, 1.0, C.gold, M.Metal)
		s.box("CerminBingkai", -1.6, 1.6, 4.0, 7.2, 0.0, 0.15, C.gold, M.Metal)
		local mir = s.box("Cermin", -1.45, 1.45, 4.15, 7.05, 0.15, 0.2, C.mirror, M.Metal)
		mir.Reflectance = 0.5
		local lamp = s.box("LampuCermin", -1.4, 1.4, 7.4, 7.6, 0.1, 0.5, C.warm, M.Neon)
		s.light(lamp, 12, 0.35)
		-- shower di pojok barat belakang
		c.box("ShowerBak", a + 0.1, a + 3.8, 0.2, 0.5, 6.0, 9.7, C.stone, M.Granite)
		local g1 =
			c.box("ShowerKacaTimur", a + 3.8, a + 3.95, 0.5, 8.0, 5.9, 9.7, C.glass, M.Glass, 0.55)
		local g2 =
			c.box("ShowerKacaDepan", a + 0.1, a + 2.4, 0.5, 8.0, 5.85, 6.0, C.glass, M.Glass, 0.55)
		c.box("ShowerKusen", a + 3.8, a + 3.95, 8.0, 8.15, 5.9, 9.7, C.steel, M.Metal)
		c.box("ShowerLengan", a + 0.1, a + 1.8, 7.4, 7.55, 8.3, 8.45, C.steel, M.Metal)
		c.cyl("ShowerKepala", a + 1.8, 7.2, 8.4, 1.4, 0.25, C.steel, M.Metal)
		-- handuk
		c.box("HandukBatang", bx - 0.5, bx - 0.3, 4.6, 4.8, 7.6, 9.2, C.gold, M.Metal)
		c.box("Handuk1", bx - 0.6, bx - 0.3, 3.3, 4.7, 7.8, 8.6, C.white, M.Fabric)
		c.box("Handuk2", bx - 0.7, bx - 0.3, 3.5, 4.7, 8.7, 9.1, rgb(180, 210, 220), M.Fabric)
		local cl = c.box("LampuMandi", a + 3, a + 5, 9.6, 9.7, 3, 5, C.warm, M.Neon)
		c.light(cl, 12, 0.35)
	end
	-- lemari di dinding koridor, timur pintu
	do
		local w = math.min(7, RW / 2 - 0.2 - (d + DOOR_W / 2 + 0.4))
		local u0 = d + DOOR_W / 2 + 0.4
		c.box("LemariBadan", u0, u0 + w, 0.2, 8.2, 0.0, 2.0, C.walnut, M.Wood)
		c.box("LemariPintu1", u0 + 0.1, u0 + w / 2 - 0.05, 0.4, 8.0, 2.0, 2.1, C.walnutL, M.Wood)
		c.box(
			"LemariPintu2",
			u0 + w / 2 + 0.05,
			u0 + w - 0.1,
			0.4,
			8.0,
			2.0,
			2.1,
			C.walnutL,
			M.Wood
		)
		c.box(
			"LemariGagang1",
			u0 + w / 2 - 0.4,
			u0 + w / 2 - 0.3,
			3.5,
			4.8,
			2.1,
			2.25,
			C.gold,
			M.Metal
		)
		c.box(
			"LemariGagang2",
			u0 + w / 2 + 0.3,
			u0 + w / 2 + 0.4,
			3.5,
			4.8,
			2.1,
			2.25,
			C.gold,
			M.Metal
		)
	end
	-- tempat tidur: kepala di dinding timur (u = RW/2)
	local vb = 13.6
	local ue = RW / 2
	do
		c.box("KarpetKamar", ue - 13, ue - 2, 0.12, 0.17, vb - 4.8, vb + 4.8, C.teal, M.Fabric)
		c.box(
			"KarpetKamarTepi",
			ue - 12.4,
			ue - 2.6,
			0.17,
			0.2,
			vb - 4.2,
			vb + 4.2,
			C.creamD,
			M.Fabric
		)
		c.box("KepalaRanjang", ue - 0.9, ue, 0.4, 5.6, vb - 3.7, vb + 3.7, C.charcoal, M.Fabric)
		c.box(
			"KepalaRanjangEmas",
			ue - 1.0,
			ue - 0.9,
			0.4,
			5.8,
			vb - 3.8,
			vb - 3.6,
			C.gold,
			M.Metal
		)
		c.box(
			"KepalaRanjangEmas2",
			ue - 1.0,
			ue - 0.9,
			0.4,
			5.8,
			vb + 3.6,
			vb + 3.8,
			C.gold,
			M.Metal
		)
		c.box("RangkaRanjang", ue - 10.0, ue - 0.9, 0.4, 1.5, vb - 3.4, vb + 3.4, C.walnut, M.Wood)
		c.box("Kasur", ue - 9.8, ue - 0.9, 1.5, 2.5, vb - 3.2, vb + 3.2, C.linen, M.Fabric)
		c.box("Selimut", ue - 9.9, ue - 6.3, 2.5, 2.9, vb - 3.3, vb + 3.3, C.burgundy, M.Fabric)
		c.box("SelimutLipat", ue - 6.4, ue - 5.5, 2.5, 2.95, vb - 3.3, vb + 3.3, C.gold, M.Fabric)
		c.box("Bantal1", ue - 3.0, ue - 1.1, 2.5, 3.4, vb - 3.0, vb - 0.5, C.white, M.Fabric)
		c.box("Bantal2", ue - 3.0, ue - 1.1, 2.5, 3.4, vb + 0.5, vb + 3.0, C.white, M.Fabric)
		c.box("BantalHias", ue - 4.6, ue - 3.4, 2.5, 3.3, vb - 0.7, vb + 0.7, C.teal, M.Fabric)
		c.box(
			"BangkuKaki",
			ue - 11.4,
			ue - 10.2,
			0.5,
			1.9,
			vb - 2.6,
			vb + 2.6,
			C.charcoal,
			M.Fabric
		)
		-- meja samping + lampu tidur (dua sisi)
		for _, sv in { vb - 3.4 - 1.0 - 0.2, vb + 3.4 + 1.0 + 0.2 } do
			c.box("MejaTidur", ue - 2.6, ue - 0.9, 0, 2.2, sv - 1.0, sv + 1.0, C.walnutL, M.Wood)
			c.box(
				"MejaTidurLaci",
				ue - 2.65,
				ue - 2.6,
				0.6,
				1.8,
				sv - 0.8,
				sv + 0.8,
				C.walnut,
				M.Wood
			)
			c.cyl("LampuTidurDasar", ue - 1.7, 2.2, sv, 0.9, 0.2, C.gold, M.Metal)
			c.cyl("LampuTidurTiang", ue - 1.7, 2.4, sv, 0.15, 1.0, C.gold, M.Metal)
			local sh = c.cyl("LampuTidurKap", ue - 1.7, 3.2, sv, 1.5, 1.0, C.cream, M.Neon)
			sh.Transparency = 0.2
			c.light(sh, 14, 0.4)
		end
		-- lukisan di atas kepala ranjang
		Furn.painting(
			at(c, ue - 0.2, 5.5, vb, -math.pi / 2),
			6,
			3,
			{ rgb(30, 90, 110), rgb(230, 200, 140), rgb(120, 50, 70) },
			"LukisanKamar"
		)
		-- titik tidur (lihat HotelService)
		local pos = Vector3.new(ue - 4.9, 2.6, vb)
		local bed = Instance.new("Part")
		bed.Name = "TempatTidur"
		bed.Anchored = true
		bed.CanCollide = false
		bed.CanQuery = true
		bed.Transparency = 1
		bed.Size = Vector3.new(5.6, 0.2, 7.6) -- X = lebar kasur, Z = panjang (arah kepala)
		-- sumbu Z lokal = arah kepala (+u), Y = atas
		bed.CFrame = frame
			* CFrame.fromMatrix(pos, Vector3.new(0, 0, -1), Vector3.yAxis, Vector3.xAxis)
		bed.Parent = folder
		bed:SetAttribute("Nomor", no)
		CollectionService:AddTag(bed, "HotelBed")
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "Tidur"
		pr.ActionText = "Tidur"
		pr.ObjectText = "Kasur kamar " .. no
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.HoldDuration = 0.4
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr.Parent = bed
	end
	-- TV + konsol di dinding barat
	do
		c.box("KonsolTv", a, a + 1.8, 0.12, 2.6, 12.4, 18.8, C.walnut, M.Wood)
		c.box("KonsolTvAtas", a, a + 2.0, 2.6, 2.75, 12.3, 18.9, C.cream, M.Marble)
		local tv = Furn.tv(at(c, a + 0.15, 3.4, vb, math.pi / 2))
	end
	-- meja kerja + kursi di dekat jendela
	do
		local du = -0.5
		c.box("MejaKerjaAtas", du - 3.2, du + 3.2, 2.9, 3.15, 19.2, 21.4, C.walnutL, M.Wood)
		for _, su in { du - 2.9, du + 2.9 } do
			c.box("MejaKerjaKaki", su - 0.15, su + 0.15, 0.12, 2.9, 19.4, 21.2, C.gold, M.Metal)
		end
		c.box("LaptopAlas", du - 1.0, du + 1.0, 3.15, 3.25, 19.8, 20.8, C.steel, M.Metal)
		local lscr =
			c.box("LaptopLayar", du - 1.0, du + 1.0, 3.25, 4.5, 20.7, 20.8, rgb(40, 52, 80), M.Neon)
		lscr.CanCollide = false
		Furn.chair(at(c, du, 0.12, 17.6, math.pi))
		Furn.armchair(at(c, ue - 3.8, 0.12, 20.0, -math.pi / 2 - 0.3), C.teal)
		Furn.sideTable(at(c, ue - 7.4, 0.12, 20.4))
		Furn.plant(at(c, a + 1.6, 0.12, 20.2), 0.9)
	end
	-- jendela: bingkai dalam + tirai tipis
	do
		c.box("BingkaiJendelaBawah", a, RW / 2, 0.12, 0.5, RD - 0.4, RD, C.charcoal, M.Metal)
		c.box("BingkaiJendelaAtas", a, RW / 2, 9.4, 9.7, RD - 0.3, RD, C.charcoal, M.Metal)
		for _, u in { a, 0, RW / 2 } do
			c.box("TiangJendela", u - 0.2, u + 0.2, 0.12, 9.7, RD - 0.3, RD, C.charcoal, M.Metal)
		end
		c.box("BatangTirai", a, RW / 2, 9.2, 9.35, RD - 1.0, RD - 0.85, C.gold, M.Metal)
		c.box("TiraiKiri", a + 0.2, a + 3.4, 0.2, 9.1, RD - 1.0, RD - 0.7, C.creamD, M.Fabric, 0.3)
		c.box(
			"TiraiKanan",
			RW / 2 - 3.4,
			RW / 2 - 0.2,
			0.2,
			9.1,
			RD - 1.0,
			RD - 0.7,
			C.creamD,
			M.Fabric,
			0.3
		)
	end
	-- lampu langit-langit
	do
		local l1 = c.box("LampuLangit1", -1.4, 1.4, 9.6, 9.7, 8.0, 10.6, C.warm, M.Neon)
		c.light(l1, 18, 0.8)
		local l2 = c.box("LampuLangit2", d - 1, d + 1, 9.6, 9.7, 3.0, 5.0, C.warm, M.Neon)
		c.light(l2, 10, 0.5)
		local l3 =
			c.box("LampuLangit3", ue - 5.5, ue - 3.5, 9.6, 9.7, vb - 1, vb + 1, C.warm, M.Neon)
		c.light(l3, 16, 0.6)
		local l4 = c.box("LampuLangit4", -3, -1, 9.6, 9.7, 17, 19, C.warm, M.Neon)
		c.light(l4, 14, 0.5)
	end
	return folder
end

return function()
	local root = Workspace.Map:WaitForChild("Hotel")
	local old = root:FindFirstChild("Lantai")
	if old then
		old:Destroy()
	end
	local lantai = sub(root, "Lantai")
	local doors = sub(lantai, "Pintu")
	local rooms = sub(lantai, "Kamar")
	local F2 = CFrame.new(Kit.ORIGIN + Vector3.new(0, Kit.H1, 0))
	local c = Kit.ctx(lantai, F2)
	-- lantai + plafon koridor
	c.box("PelatLantai", -48, 48, -1.2, 0, -26, 26, C.charcoalD, M.Concrete)
	c.box("LantaiKoridor", -46.8, 46.8, 0, 0.06, -3.5, 3.5, rgb(150, 50, 62), M.Fabric)
	c.box("LariKoridor", -46.8, 46.8, 0.06, 0.1, -1.4, 1.4, C.charcoal, M.Fabric)
	c.box("LariKoridorEmasU", -46.8, 46.8, 0.1, 0.12, -1.55, -1.4, C.gold, M.Metal)
	c.box("LariKoridorEmasS", -46.8, 46.8, 0.1, 0.12, 1.4, 1.55, C.gold, M.Metal)
	c.box("PlafonKoridor", -46.8, 46.8, 9.7, 10, -3.5, 3.5, C.cream, M.SmoothPlastic)
	c.box("PlintKoridorU", -46.8, 46.8, 0, 0.5, -3.5, -3.4, C.charcoal, M.Wood)
	for x = -40, 40, 8 do
		local s = c.box("LampuKoridor", x - 1, x + 1, 9.6, 9.7, -0.6, 0.6, C.warm, M.Neon)
		c.light(s, 14, 0.5)
	end
	-- sekat kamar (dunia): utara x -24,0,24; selatan x -26 dan dinding inti +-6.2
	for _, x in { -24, 0, 24 } do
		c.box("SekatUtara", x - 0.4, x + 0.4, 0, 10, -26, -3.5, C.cream, M.SmoothPlastic)
	end
	c.box("SekatSelatan", -26.4, -25.6, 0, 10, 3.5, 26, C.cream, M.SmoothPlastic)
	c.box("SekatSelatan2", 25.6, 26.4, 0, 10, 3.5, 26, C.cream, M.SmoothPlastic)
	c.box("SekatInti", -6.4, -6.0, 0, 10, 4.3, 26, C.cream, M.SmoothPlastic)
	c.box("SekatInti2", 6.0, 6.4, 0, 10, 4.3, 26, C.cream, M.SmoothPlastic)
	c.box("RuangServis", -6, 6, 0, 10, 13.8, 24.8, C.charcoalD, M.Concrete)
	-- 8 kamar
	local north = { { -46.8, -24.4 }, { -23.6, -0.4 }, { 0.4, 23.6 }, { 24.4, 46.8 } }
	local south = { { -46.8, -26.4 }, { -25.6, -6.4 }, { 6.4, 25.6 }, { 26.4, 46.8 } }
	for i, b in north do
		local cx = (b[1] + b[2]) / 2
		buildRoom(
			rooms,
			F2 * CFrame.new(cx, 0, -4.3) * CFrame.Angles(0, math.pi, 0),
			b[2] - b[1],
			i,
			doors
		)
	end
	for i, b in south do
		local cx = (b[1] + b[2]) / 2
		buildRoom(rooms, F2 * CFrame.new(cx, 0, 4.3), b[2] - b[1], 4 + i, doors)
	end
	-- lift lantai
	Kit.lift(c, "lantai", Kit.ROOM_H, lantai)
	-- papan lantai dan petunjuk
	c.sign(
		"PapanLantai",
		-4,
		4,
		4.8,
		7.0,
		-3.5,
		-3.3,
		Enum.NormalId.Back,
		"LANTAI {N}",
		{
			bg = C.charcoalD,
			color = C.gold,
			pps = 50,
			font = Enum.Font.GothamBlack,
			tag = "HotelLabel",
		}
	)
	for _, p in
		{
			{ -14, "← {N}01 · {N}02 · {N}05 · {N}06" },
			{ 14, "{N}03 · {N}04 · {N}07 · {N}08 →" },
		}
	do
		for _, f in { { Enum.NormalId.Front, -0.2, 0.0 }, { Enum.NormalId.Back, 0.0, 0.2 } } do
			c.sign(
				"PetunjukKamar",
				p[1] - 5,
				p[1] + 5,
				7.4,
				8.9,
				f[2] - 0.1,
				f[3] + 0.0,
				f[1],
				p[2],
				{ bg = C.charcoalD, color = C.gold, pps = 32, tag = "HotelLabel" }
			)
		end
		c.cyl("TaliPetunjukKiri", p[1] - 4, 8.9, -0.1, 0.1, 0.8, C.gold, M.Metal)
		c.cyl("TaliPetunjukKanan", p[1] + 4, 8.9, -0.1, 0.1, 0.8, C.gold, M.Metal)
	end
	-- ujung koridor: bangku menghadap jendela, tanaman, tanda keluar
	for _, side in { -1, 1 } do
		local x = 44.2 * side
		local b =
			Kit.ctx(lantai, F2 * CFrame.new(x, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0))
		b.box("BangkuUjungDasar", -2.6, 2.6, 0.12, 1.5, -0.9, 0.9, C.charcoal, M.Fabric)
		Furn.seatBox(b, "BangkuUjung", -2.6, 2.6, 1.5, 1.9, -0.9, 0.9, C.sofa, M.Fabric)
		b.box("SandaranUjung", -2.6, 2.6, 1.9, 3.6, -0.9, -0.5, C.sofa, M.Fabric)
		local ex = c.sign(
			"TandaKeluar",
			side * 45.6 - 0.1,
			side * 45.6 + 0.1,
			8.2,
			9.2,
			-1.5,
			1.5,
			if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
			"KELUAR",
			{ bg = rgb(30, 130, 70), color = C.white, pps = 40 }
		)
		ex.Material = M.Neon
		Furn.plant(Kit.ctx(lantai, F2 * CFrame.new(side * 43.6, 0.12, -2.4)), 0.8)
	end
	return lantai
end
