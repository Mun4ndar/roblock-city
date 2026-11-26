--!nonstrict
--[[
	ROBLOCK CITY: Hotel Bintang Kota (bisa dimasuki). Gaya: kota modern, granit gelap + emas champagne + kaca biru
	(beda dari Resort yang pantai: teal + kayu). Dibangun dari Part (tanpa aset luar).
	Letak: tengah (270, 0.6, -52), depan menghadap utara ke Jalan Kenanga Timur.
	  - lantai lobi (resepsionis, lounge, bar, lift)
	  - menara 8 lantai (hanya SATU lantai koridor + kamar yang dapat dimasuki: map/BuildHotelLantai;
	    lift hanya mengganti nomor lantai di client, pemain tiba di koridor yang sama)
	Jalankan: require(MapBuilders.BuildHotel)() lalu require(MapBuilders.BuildHotelLantai)().
	HotelService (src/server/Services) menggerakkan lift, tidur, dan check-in.
]]
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local MB = script.Parent
local Kit = require(MB:WaitForChild("HotelKit"))
local Furn = require(MB:WaitForChild("HotelFurn"))
local C, M = Kit.C, Enum.Material
local rgb = Color3.fromRGB

local function sub(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function at(parent, x, y, z, yaw)
	return Kit.ctx(parent, CFrame.new(Kit.ORIGIN) * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0))
end

local function buildExterior(root, F0)
	local ext = sub(root, "Eksterior")
	local e = Kit.ctx(ext, F0)
	e.box("Fondasi", -49, 49, -3, -0.1, -27, 27, C.charcoalD, M.Concrete)
	e.box("Plaza", -58, 58, -1, 0, -44, -26.9, C.stone, M.Pavement)
	e.box("PlazaGaris", -58, 58, -0.02, 0.01, -44, -43.4, C.stoneD, M.Pavement)
	e.box("JalurAntar", -24, 24, -0.9, 0.02, -43.4, -26.9, C.charcoal, M.Slate)
	e.box("Karpet", -4.5, 4.5, 0, 0.06, -44, -26, C.burgundy, M.Fabric)
	e.box("KarpetTepiKiri", -4.8, -4.5, 0, 0.07, -44, -26, C.gold, M.Metal)
	e.box("KarpetTepiKanan", 4.5, 4.8, 0, 0.07, -44, -26, C.gold, M.Metal)
	-- tembok podium: utara kaca, timur/barat batu berjendela, selatan batu
	local N = -26
	for _, x in { -46.8, -40, -32, -24, -16, -8, -5.4, 5.4, 8, 16, 24, 32, 40, 46.8 } do
		e.box("TiangKaca", x - 0.25, x + 0.25, 0, 14.8, N - 0.15, N + 0.5, C.gold, M.Metal)
	end
	e.box("KacaLobiKiri", -46.8, -5.4, 0, 14.8, N, N + 0.25, C.glass, M.Glass, 0.45)
	e.box("KacaLobiKanan", 5.4, 46.8, 0, 14.8, N, N + 0.25, C.glass, M.Glass, 0.45)
	e.box("KacaLobiAtas", -5.4, 5.4, 9.6, 14.8, N, N + 0.25, C.glass, M.Glass, 0.45)
	e.box("RelPintu", -46.8, 46.8, 9.4, 9.9, N - 0.15, N + 0.5, C.gold, M.Metal)
	e.box("TepiBawahKaca", -46.8, 46.8, 0, 0.6, N - 0.2, N + 0.6, C.charcoal, M.Granite)
	-- pintu utama: dua daun kaca berengsel, membuka ke luar (utara)
	e.door("PintuUtamaKiri", -5.4, N + 0.1, 0, 9.4, 1, 0, 5.4, 0, -1, { radius = 9 })
	e.door("PintuUtamaKanan", 5.4, N + 0.1, 0, 9.4, -1, 0, 5.4, 0, -1, { radius = 9 })
	-- timur & barat
	for _, side in { -1, 1 } do
		local x0, x1 = if side > 0 then 46.8 else -48, if side > 0 then 48 else -46.8
		local nm = if side > 0 then "T" else "B"
		-- lobi: tiga jendela besar
		local zs = { -26, -20, -12, -4, 4, 12, 20, 26 }
		for i = 1, #zs - 1, 2 do
			e.box("PilarLobi" .. nm .. i, x0, x1, 0, 14.8, zs[i], zs[i + 1], C.cream, M.Limestone)
		end
		for i = 2, #zs - 1, 2 do
			e.box("AmbangJendela" .. nm .. i, x0, x1, 0, 1.2, zs[i], zs[i + 1], C.cream, M.Limestone)
			e.box("KepalaJendela" .. nm .. i, x0, x1, 12.4, 14.8, zs[i], zs[i + 1], C.cream, M.Limestone)
			e.box("KacaSamping" .. nm .. i, x0 + 0.4, x1 - 0.4, 1.2, 12.4, zs[i], zs[i + 1], C.glass, M.Glass, 0.45)
			e.box("KusenSamping" .. nm .. i, x0 + 0.3, x1 - 0.3, 1.1, 1.4, zs[i], zs[i + 1], C.gold, M.Metal)
		end
		-- lantai koridor: dinding batu dengan jendela ujung koridor
		e.box("TembokKoridor" .. nm .. "U", x0, x1, 14.8, 26, -26, -3.2, C.cream, M.Limestone)
		e.box("TembokKoridor" .. nm .. "S", x0, x1, 14.8, 26, 3.2, 26, C.cream, M.Limestone)
		e.box("TembokKoridor" .. nm .. "Bwh", x0, x1, 14.8, 17.4, -3.2, 3.2, C.cream, M.Limestone)
		e.box("TembokKoridor" .. nm .. "Ats", x0, x1, 25.2, 26, -3.2, 3.2, C.cream, M.Limestone)
		e.box("KacaUjungKoridor" .. nm, x0 + 0.4, x1 - 0.4, 17.4, 25.2, -3.2, 3.2, C.glass, M.Glass, 0.4)
	end
	-- selatan lobi + inti belakang
	e.box("TembokSelatanLobi", -48, 48, 0, 14.8, 24.8, 26, C.cream, M.Limestone)
	e.box("TembokSelatanInti", -6, 6, 14.8, 26, 24.8, 26, C.cream, M.Limestone)
	-- pita lantai (pelat) di sekeliling
	for _, z in { -26.4, 25.4 } do
		e.box("PitaLantai", -48.4, 48.4, 14.8, 16.0, z, z + 1.0, C.charcoal, M.Granite)
	end
	for _, x in { -48.6, 47.6 } do
		e.box("PitaLantaiSamping", x, x + 1.0, 14.8, 16.0, -26.4, 26.4, C.charcoal, M.Granite)
	end
	-- fasad koridor (kamar utara/selatan): kaca dari lantai ke langit-langit, sirip di sekat kamar
	local function facade(zc, dir, fins)
		local z0, z1 = if dir < 0 then zc - 0.3 else zc, if dir < 0 then zc else zc + 0.3
		if dir > 0 then
			e.box("KacaKamarSelatanKiri", -46.8, -6, 16, 26, z0, z1, C.glass, M.Glass, 0.45)
			e.box("KacaKamarSelatanKanan", 6, 46.8, 16, 26, z0, z1, C.glass, M.Glass, 0.45)
		else
			e.box("KacaKamarUtara", -46.8, 46.8, 16, 26, z0, z1, C.glass, M.Glass, 0.45)
		end
		for _, x in fins do
			e.box("SirippKamar", x - 0.5, x + 0.5, 14.8, 27.2, if dir < 0 then zc - 1.2 else zc - 0.2, if dir < 0 then zc + 0.2 else zc + 1.2, C.stone, M.Limestone)
		end
		e.box("TiangUjungKiri", -48, -46.8, 14.8, 27.2, if dir < 0 then zc - 1.2 else zc - 0.4, if dir < 0 then zc + 0.4 else zc + 1.2, C.stone, M.Limestone)
		e.box("TiangUjungKanan", 46.8, 48, 14.8, 27.2, if dir < 0 then zc - 1.2 else zc - 0.4, if dir < 0 then zc + 0.4 else zc + 1.2, C.stone, M.Limestone)
	end
	facade(-26, -1, { -24, 0, 24 })
	facade(26, 1, { -26, -6, 6, 26 })
	-- pelat atap lantai koridor
	e.box("PelatAtasKoridor", -48, 48, 26, 27.2, -26, 26, C.charcoal, M.Concrete)
	-- menara atas: inti gelap + kulit kaca bertingkat
	e.box("IntiMenara", -46.8, 46.8, 27.2, 81.2, -25, 25, C.charcoalD, M.Concrete)
	for k = 0, 5 do
		local b = 27.2 + 9 * k
		for _, dir in { -1, 1 } do
			local z = 26 * dir
			local z0, z1 = if dir < 0 then z - 0.3 else z - 0.3, if dir < 0 then z + 0.3 else z + 0.3
			e.box("SpandrelUtaraSelatan", -48, 48, b, b + 1.6, z - 1.0 * math.abs(dir) * 0.5 - 0.3, z + 0.5 * math.abs(dir) + 0.3, C.stone, M.Limestone)
			local g = e.box("KacaMenara", -46.8, 46.8, b + 1.6, b + 9, z - 0.15, z + 0.15, C.glassD, M.Glass, 0.3)
			CollectionService:AddTag(g, "NightWindow")
			for x = -40, 40, 8 do
				e.box("SirippMenara", x - 0.4, x + 0.4, b + 1.6, b + 9, if dir < 0 then z - 1.3 else z - 0.2, if dir < 0 then z + 0.2 else z + 1.3, C.creamD, M.Limestone)
			end
		end
		for _, side in { -1, 1 } do
			local x = 47.4 * side
			e.box("SpandrelSamping", x - 0.7, x + 0.7, b, b + 1.6, -26, 26, C.stone, M.Limestone)
			for _, zc in { -15, 15 } do
				local g = e.box("KacaMenaraSamping", x - 0.2, x + 0.2, b + 2.2, b + 8.4, zc - 7, zc + 7, C.glassD, M.Glass, 0.3)
				CollectionService:AddTag(g, "NightWindow")
			end
		end
	end
	-- atap + tiang pagar + perlengkapan
	e.box("PelatAtap", -48.4, 48.4, 81.2, 82.4, -26.4, 26.4, C.charcoal, M.Concrete)
	e.box("PagarAtapU", -48.4, 48.4, 82.4, 84.2, -26.4, -25.6, C.stone, M.Limestone)
	e.box("PagarAtapS", -48.4, 48.4, 82.4, 84.2, 25.6, 26.4, C.stone, M.Limestone)
	e.box("PagarAtapB", -48.4, -47.6, 82.4, 84.2, -26.4, 26.4, C.stone, M.Limestone)
	e.box("PagarAtapT", 47.6, 48.4, 82.4, 84.2, -26.4, 26.4, C.stone, M.Limestone)
	for _, p in { { -30, 0 }, { -18, 0 }, { 30, 6 } } do
		e.box("UnitAC", p[1] - 3, p[1] + 3, 82.4, 86, p[2] - 3, p[2] + 3, C.steel, M.Metal)
		e.cyl("KipasAC", p[1], 86, p[2], 4.6, 0.3, C.charcoalD, M.Metal)
	end
	e.cyl("TangkiAir", 20, 82.4, 8, 8, 7, C.steelD, M.Metal)
	e.cyl("AtapTangki", 20, 89.4, 8, 8.6, 0.5, C.charcoal, M.Metal)
	e.cyl("Antena", 38, 82.4, -10, 0.5, 16, C.steelD, M.Metal)
	e.ball("LampuAntena", 38, 98.6, -10, 1.2, rgb(255, 60, 60), M.Neon)
	-- papan nama di atap (menghadap utara)
	local board = e.sign("PapanNamaAtap", -26, 26, 85, 92, -24.6, -24.0, Enum.NormalId.Front, "HOTEL BINTANG KOTA",
		{ bg = C.charcoalD, color = C.gold, pps = 40, font = Enum.Font.GothamBlack, mat = M.Metal })
	e.box("PapanTiangKiri", -20, -19, 82.4, 85, -24.6, -24.0, C.charcoal, M.Metal)
	e.box("PapanTiangKanan", 19, 20, 82.4, 85, -24.6, -24.0, C.charcoal, M.Metal)
	e.box("PapanBingkaiAtas", -26.4, 26.4, 92, 92.5, -24.9, -23.8, C.gold, M.Metal)
	e.box("PapanBingkaiBawah", -26.4, 26.4, 84.5, 85, -24.9, -23.8, C.gold, M.Metal)
	-- kanopi pintu masuk
	e.box("Kanopi", -22, 22, 11.4, 12.6, -38, -26, C.charcoal, M.Metal)
	e.box("KanopiTepi", -22.4, 22.4, 11.2, 12.8, -38.4, -37.6, C.gold, M.Metal)
	e.sign("PapanKanopi", -16, 16, 11.4, 12.6, -38.6, -38.4, Enum.NormalId.Front, "HOTEL BINTANG KOTA",
		{ bg = C.charcoalD, color = C.gold, pps = 40, font = Enum.Font.GothamBold })
	for _, x in { -20, -8, 8, 20 } do
		e.cyl("TiangKanopi", x, 0, -37, 1.4, 11.4, C.stone, M.Marble)
		e.cyl("CincinTiang", x, 0.4, -37, 1.8, 0.4, C.gold, M.Metal)
		e.cyl("CincinTiangAtas", x, 10.8, -37, 1.8, 0.4, C.gold, M.Metal)
	end
	for _, x in { -15, -5, 5, 15 } do
		for _, z in { -30, -35 } do
			local lt = e.box("LampuKanopi", x - 0.8, x + 0.8, 11.3, 11.4, z - 0.8, z + 0.8, C.warm, M.Neon)
			CollectionService:AddTag(lt, "NightLight")
			e.light(lt, 14, 0.3)
		end
	end
	-- penghias plaza: tiang batas, pot tanaman, bangku
	for x = -56, 56, 8 do
		if math.abs(x) > 26 then
			e.cyl("TiangBatas", x, 0, -43, 0.9, 2.4, C.stone, M.Granite)
			e.cyl("TiangBatasEmas", x, 2.4, -43, 1.0, 0.25, C.gold, M.Metal)
		end
	end
	for _, x in { -34, 34, -46, 46 } do
		local c = at(ext, x, 0, -34)
		Furn.plant(c, 1.5)
	end
	for _, x in { -36, 36 } do
		local c = at(ext, x, 0, -38, math.pi)
		c.box("BangkuPlaza", -3, 3, 1.3, 1.7, -0.8, 0.8, C.walnutL, M.Wood)
		c.box("SandaranPlaza", -3, 3, 1.7, 3.2, -0.8, -0.5, C.walnutL, M.Wood)
		for _, sx in { -2.6, 2.6 } do
			c.box("KakiBangku", sx - 0.2, sx + 0.2, 0, 1.3, -0.7, 0.7, C.charcoal, M.Metal)
		end
		local s = Furn.seatBox(c, "DudukBangku", -3, 3, 1.3, 1.5, -0.8, 0.8, C.walnutL, M.Wood)
		s.Transparency = 1
	end
	-- lampu dinding emas di tiang depan
	for _, x in { -46.8, -24, 24, 46.8 } do
		local l = e.box("LampuSorot", x - 0.4, x + 0.4, 0.2, 0.6, -28, -27, C.warm, M.Neon)
		CollectionService:AddTag(l, "NightLight")
	end
end

local function buildLobby(root, F0)
	local lob = sub(root, "Lobi")
	local c = Kit.ctx(lob, F0)
	-- lantai marmer dengan bingkai gelap
	c.box("LantaiLobi", -46.8, 46.8, -0.1, 0.0, -25.7, 24.8, C.cream, M.Marble)
	c.box("BingkaiLantaiU", -46.8, 46.8, 0, 0.03, -25.7, -23.7, C.charcoal, M.Marble)
	c.box("BingkaiLantaiS", -46.8, 46.8, 0, 0.03, 22.8, 24.8, C.charcoal, M.Marble)
	c.box("BingkaiLantaiB", -46.8, -44.8, 0, 0.03, -23.7, 22.8, C.charcoal, M.Marble)
	c.box("BingkaiLantaiT", 44.8, 46.8, 0, 0.03, -23.7, 22.8, C.charcoal, M.Marble)
	c.box("CincinLantai", -13, 13, 0, 0.03, -26, -1, C.creamD, M.Marble)
	c.box("KarpetLobi", -4.5, 4.5, 0, 0.06, -25.7, 3.5, C.burgundy, M.Fabric)
	c.box("KarpetLobiKiri", -4.8, -4.5, 0, 0.07, -25.7, 3.5, C.gold, M.Metal)
	c.box("KarpetLobiKanan", 4.5, 4.8, 0, 0.07, -25.7, 3.5, C.gold, M.Metal)
	-- plafon + lampu sorot
	c.box("PlafonLobi", -46.8, 46.8, 14.5, 14.8, -25.7, 24.8, C.cream, M.SmoothPlastic)
	for _, x in { -36, -18, 18, 36 } do
		local s = c.box("LampuPlafon", x - 0.4, x + 0.4, 14.4, 14.5, -22, 21, C.warm, M.SmoothPlastic)
		CollectionService:AddTag(s, "NightLight")
	end
	for _, x in { -36, -18, 18, 36 } do
		for _, z in { -14, 10 } do
			local p = c.box("TitikCahaya", x - 0.3, x + 0.3, 14.3, 14.4, z - 0.3, z + 0.3, C.warm, M.SmoothPlastic)
			c.light(p, 22, 0.22)
		end
	end
	-- dinding selatan: panel kayu + garis emas
	c.box("PanelKayuSelatan", -46.8, 46.8, 0, 13.4, 24.2, 24.8, C.walnut, M.Wood)
	for x = -42, 42, 6 do
		c.box("GarisEmasSelatan", x - 0.1, x + 0.1, 0.4, 13.0, 24.0, 24.2, C.gold, M.Metal)
	end
	c.box("PapanKayuAtasSelatan", -46.8, 46.8, 13.4, 14.5, 24.0, 24.8, C.charcoal, M.Wood)
	-- lift lobi
	Kit.lift(Kit.ctx(lob, F0), "lobi", Kit.LOBBY_H, lob)
	-- lantai inti: ambang marmer sekitar inti
	c.box("AlasInti", -7, 7, 0, 0.05, 3.5, 5.6, C.charcoal, M.Marble)
	-- pilar marmer
	for _, p in { { -15, -20 }, { 15, -20 }, { -15, 17 }, { 15, 17 } } do
		c.cyl("PilarLobi", p[1], 0, p[2], 2.4, 14.5, C.stone, M.Marble)
		c.cyl("PilarCincinBawah", p[1], 0, p[2], 3.0, 0.5, C.gold, M.Metal)
		c.cyl("PilarCincinAtas", p[1], 14.0, p[2], 3.0, 0.5, C.gold, M.Metal)
	end
	-- lampu gantung besar (chandelier) di atas karpet
	do
		local k = at(lob, 0, 0, -12)
		k.cyl("RantaiLampu", 0, 10.5, 0, 0.3, 4.1, C.gold, M.Metal)
		k.cyl("CincinLampu", 0, 10.2, 0, 7.0, 0.3, C.gold, M.Metal)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local b = k.ball("BohlamLampu", math.cos(a) * 3.2, 9.7, math.sin(a) * 3.2, 0.9, C.warm, M.Neon)
			if i % 4 == 0 then
				k.light(b, 26, 0.3)
			end
			k.ball("KristalLampu", math.cos(a) * 2.2, 8.9, math.sin(a) * 2.2, 0.6, C.white, M.Glass).Transparency = 0.3
		end
		local mid = k.ball("BolaTengah", 0, 9.4, 0, 2.0, C.warm, M.Neon)
		CollectionService:AddTag(mid, "NightLight")
	end
	-- resepsionis (barat)
	do
		local r = at(lob, -31, 0, 8.2)
		r.box("MejaResepsionisAlas", -11, 11, 0, 3.6, -1.2, 1.2, C.walnut, M.Wood)
		r.box("MejaResepsionisPanelEmas", -11, 11, 0.5, 0.8, -1.3, -1.2, C.gold, M.Metal)
		r.box("MejaResepsionisAtas", -11.4, 11.4, 3.6, 4.0, -1.6, 1.4, C.cream, M.Marble)
		for _, x in { -6, 0, 6 } do
			r.box("MonitorTiang", x - 0.15, x + 0.15, 4.0, 4.9, 0.6, 0.9, C.black, M.Metal)
			local mon = r.box("Monitor", x - 1.3, x + 1.3, 4.7, 6.3, 0.5, 0.7, C.black, M.SmoothPlastic)
			local scr = r.box("MonitorLayar", x - 1.15, x + 1.15, 4.85, 6.15, 0.45, 0.5, rgb(64, 120, 190), M.Neon)
			scr.CanCollide = false
		end
		local bell = r.cyl("LoncengMeja", -9, 4.0, -0.2, 0.9, 0.25, C.gold, M.Metal)
		bell.Name = "LoncengCheckIn"
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "CheckIn"
		pr.ActionText = "Sapa resepsionis"
		pr.ObjectText = "Resepsionis Hotel"
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = bell
		local wall = r.box("LatarResepsionis", -12, 12, 0, 12, 5.4, 6.2, C.charcoal, M.Wood)
		for x = -11, 11, 1.4 do
			r.box("LamelKayu", x - 0.25, x + 0.25, 0.3, 11.7, 5.1, 5.4, C.walnutL, M.Wood)
		end
		r.box("RakKunci", -9, 9, 5.4, 9.4, 4.8, 5.1, C.walnut, M.Wood)
		for i = 0, 8 do
			for j = 0, 3 do
				r.box("KunciKamar", -8.3 + i * 2.05, -7.1 + i * 2.05, 5.8 + j * 0.9, 6.4 + j * 0.9, 4.6, 4.8, C.gold, M.Metal)
			end
		end
		r.sign("LogoResepsionis", -9, 9, 9.8, 11.4, 4.7, 4.8, Enum.NormalId.Back, "RESEPSIONIS", { bg = C.charcoalD, color = C.gold, pps = 40 })
		-- tiang tali antrean
		for _, x in { -6, 6 } do
			r.cyl("TiangAntre", x, 0, -5, 0.5, 3, C.gold, M.Metal)
			r.cyl("AlasAntre", x, 0, -5, 1.4, 0.15, C.gold, M.Metal)
		end
		r.box("TaliAntre", -6, 6, 2.4, 2.55, -5.1, -4.9, C.burgundy, M.Fabric)
	end
	-- lounge (timur): karpet, sofa, meja, kursi, lampu
	do
		c.box("KarpetLounge", 15, 43, 0, 0.05, -19, 3, C.navy, M.Fabric)
		c.box("KarpetLoungeEmas", 16, 42, 0.05, 0.08, -18, 2, C.gold, M.Fabric, 0.4)
		c.box("KarpetLoungeDalam", 17, 41, 0.08, 0.1, -17, 1, C.navy, M.Fabric)
		Furn.sofa(at(lob, 29, 0, -14.2, 0), 9, C.sofa, rgb(110, 130, 150))
		Furn.sofa(at(lob, 29, 0, -2.8, math.pi), 9, C.sofa, rgb(110, 130, 150))
		Furn.armchair(at(lob, 20.5, 0, -8.5, math.pi / 2), C.burgundy)
		Furn.armchair(at(lob, 37.5, 0, -8.5, -math.pi / 2), C.burgundy)
		Furn.coffeeTable(at(lob, 29, 0, -8.5), 6, 3.6)
		Furn.floorLamp(at(lob, 42, 0, -18))
		Furn.floorLamp(at(lob, 42, 0, 2))
		Furn.plant(at(lob, 44, 0, -22), 1.3)
		Furn.plant(at(lob, 17, 0, -22), 1.1)
		Furn.sideTable(at(lob, 20.5, 0, -13.5))
		Furn.sideTable(at(lob, 37.5, 0, -3.5))
	end
	-- bar lobi (timur belakang)
	do
		local b = at(lob, 31, 0, 19.2)
		b.box("BarAlas", -13, 13, 0, 3.6, -1.2, 1.2, C.charcoalD, M.Wood)
		b.box("BarPanelEmas", -13, 13, 0.6, 0.9, -1.3, -1.2, C.gold, M.Metal)
		b.box("BarAtas", -13.4, 13.4, 3.6, 4.0, -1.6, 1.4, C.stone, M.Marble)
		for i = 0, 4 do
			local s = Furn.stool(at(lob, 20.5 + i * 5, 0, 16.2))
		end
		local shelf = at(lob, 31, 0, 23.6)
		shelf.box("RakBar", -12, 12, 3.6, 9.6, -0.5, 0.2, C.walnut, M.Wood)
		for r = 0, 2 do
			shelf.box("RakBarPapan", -12, 12, 4.2 + r * 2.2, 4.4 + r * 2.2, -1.0, 0.2, C.walnutL, M.Wood)
			for i = 0, 15 do
				local colorList = { rgb(240, 150, 60), rgb(120, 200, 100), rgb(240, 90, 120), rgb(255, 230, 120), rgb(100, 160, 240) }
				shelf.cyl("Botol", -11 + i * 1.45, 4.4 + r * 2.2, -0.4, 0.7, 1.6, colorList[(i + r) % 5 + 1], M.Glass)
			end
		end
		for _, x in { -8, 0, 8 } do
			local lampBulb = b.ball("LampuBar", x, 8.2, 0, 1.1, C.warm, M.Neon)
			b.cyl("KabelLampuBar", x, 8.5, 0, 0.1, 6.0, C.charcoalD, M.Metal)
			b.light(lampBulb, 14, 0.25)
		end
		b.sign("PapanBar", -6, 6, 11.5, 13.0, -0.7, -0.5, Enum.NormalId.Front, "BAR & LOUNGE", { bg = C.charcoalD, color = C.gold, pps = 40 })
		b.box("TiangPapanBarKiri", -6.2, -5.8, 9.6, 13.0, -0.7, -0.5, C.gold, M.Metal)
		-- mesin kopi sederhana
		b.box("MesinKopi", -10, -7, 4.0, 6.0, -0.2, 1.0, C.steel, M.Metal)
		b.box("MesinKopiAtas", -10.2, -6.8, 6.0, 6.4, -0.4, 1.2, C.charcoal, M.Metal)
	end
	-- taman dalam di belakang inti
	do
		local z = 19.4
		c.box("BakTamanDalam", -14, 14, 0, 1.4, z - 2.6, z + 2.6, C.stone, M.Granite)
		c.box("TanahTamanDalam", -13.4, 13.4, 1.4, 1.6, z - 2.0, z + 2.0, rgb(70, 52, 38), M.Ground)
		for i, x in { -10, -5, 0, 5, 10 } do
			Furn.plant(at(lob, x, 1.4, z), 0.9)
		end
	end
	-- bagasi: troli bellboy, koper
	do
		local k = at(lob, -14, 0, -6, 0.5)
		k.box("TroliAlas", -2, 2, 0.7, 0.9, -1.2, 1.2, C.gold, M.Metal)
		for _, sx in { -1.9, 1.9 } do
			for _, sz in { -1.1, 1.1 } do
				k.cyl("RodaTroli", sx, 0, sz, 0.7, 0.2, C.charcoalD, M.Metal)
				k.box("KakiTroli", sx - 0.08, sx + 0.08, 0.2, 5.4, sz - 0.08, sz + 0.08, C.gold, M.Metal)
			end
		end
		k.box("PalangTroli", -1.95, 1.95, 5.3, 5.5, -1.2, 1.2, C.gold, M.Metal)
		k.box("Koper1", -1.6, 0.2, 0.9, 3.0, -0.9, 0.9, rgb(110, 34, 46), M.Fabric)
		k.box("Koper2", 0.4, 1.8, 0.9, 2.5, -0.8, 0.8, rgb(40, 60, 100), M.Fabric)
		k.box("Koper3", -1.2, 0.0, 3.0, 4.4, -0.7, 0.7, rgb(208, 168, 86), M.Fabric)
	end
	-- papan petunjuk gantung
	for _, d in { { -22, "← RESEPSIONIS" }, { 22, "BAR & LOUNGE →" } } do
		local p = c.sign("PetunjukGantung", d[1] - 5, d[1] + 5, 10.2, 12, -3.2, -2.8, Enum.NormalId.Front, d[2], { bg = C.charcoalD, color = C.gold, pps = 40 })
		local back = c.sign("PetunjukGantungBelakang", d[1] - 5, d[1] + 5, 10.2, 12, -2.8, -2.7, Enum.NormalId.Back, d[2], { bg = C.charcoalD, color = C.gold, pps = 40 })
		c.cyl("TaliPetunjukKiri", d[1] - 4, 12, -3.0, 0.1, 2.5, C.gold, M.Metal)
		c.cyl("TaliPetunjukKanan", d[1] + 4, 12, -3.0, 0.1, 2.5, C.gold, M.Metal)
	end
	-- lukisan di dinding barat dan timur
	Furn.painting(at(lob, -46.6, 4.2, -14, math.pi / 2), 8, 5, { rgb(40, 70, 110), rgb(208, 168, 86), rgb(140, 40, 60) }, "LukisanLobiBarat")
	Furn.painting(at(lob, 46.6, 4.2, -14, -math.pi / 2), 8, 5, { rgb(30, 90, 100), rgb(240, 220, 170), rgb(60, 60, 90) }, "LukisanLobiTimur")
end

return function()
	local map = Workspace:WaitForChild("Map")
	local old = map:FindFirstChild("Hotel")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "Hotel"
	root.Parent = map
	local F0 = CFrame.new(Kit.ORIGIN)
	buildExterior(root, F0)
	buildLobby(root, F0)
	return root
end
