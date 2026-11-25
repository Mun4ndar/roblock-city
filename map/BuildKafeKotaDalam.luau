--!nonstrict
--[[
	ROBLOCK CITY: interior Kafe Kota (Workspace.Map.Downtown.Buildings.KafeKota, depan menghadap +Z ke teras).
	Gaya industrial urban: bata merah, beton, baja hitam, lampu Edison. Cangkang mesh padat diganti dinding part
	bersudut bulat + kaca kerangka baja; pintu kaca ganda berengsel (AutoDoor). Konter kasir usaha pemain
	(BusinessConfig.POSITION) ada di dalam, di dinding belakang. Titik pelayan: Workspace.Map.KafeTitik.
	Aman dijalankan ulang.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent:WaitForChild("KafeKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CafeConfig = require(Shared:WaitForChild("CafeConfig"))
local Format = require(Shared:WaitForChild("Format"))

local rgb, M, V, PI = Color3.fromRGB, Enum.Material, Vector3.new, math.pi

local HX, HZ, R, T = 17, 13, 4.8, 0.7
local TOP, CEIL = 11.8, 11.3
local WALL = rgb(250, 245, 235)
local BRICK, CONC = rgb(158, 86, 66), rgb(112, 114, 120)
local STEEL, STEEL_L = rgb(34, 36, 40), rgb(70, 74, 80)
local WOOD, WOOD_D = rgb(176, 124, 76), rgb(108, 72, 46)
local LEATHER = rgb(120, 70, 46)
local ORANGE, WARM = rgb(255, 160, 60), rgb(255, 196, 132)

local function holes(ops)
	local r = {}
	for _, op in ipairs(ops) do
		local c = table.clone(op)
		c.hole = not op.door
		table.insert(r, c)
	end
	return r
end

-- bangku panjang bersandaran-tanpa, tempat duduk terbagi per orang. Menghadap arah yaw.
local function bench(k, pos, length, yaw, wood, steel)
	local rot = CFrame.Angles(0, yaw, 0)
	local n = math.max(1, math.floor(length / 2.1))
	local w = length / n
	for i = 1, n do
		local off = V(-length / 2 + w * (i - 0.5), 0, 0)
		k:box("DudukBangku", V(w - 0.05, 0.3, 1.3), pos + rot:VectorToWorldSpace(off + V(0, 1.7, 0)), wood, M.Wood,
			{ class = "Seat", rot = rot })
	end
	for _, sx in { -length / 2 + 0.3, length / 2 - 0.3 } do
		k:box("KakiBangku", V(0.2, 1.6, 1.1), pos + rot:VectorToWorldSpace(V(sx, 0.8, 0)), steel, M.Metal, { rot = rot })
	end
end

local function pipeShelf(k, pos, length, alongZ, rnd)
	-- rak pipa baja + papan kayu menempel dinding; pos = ujung awal, tinggi 6
	local function at(a, y, th, d)
		if alongZ then return V(pos.X, y, pos.Z + a), V(d, th, length) end
		return V(pos.X + a, y, pos.Z), V(length, th, d)
	end
	for i, y in { 1.6, 3.4, 5.2 } do
		local p, s = at(length / 2, y, 0.2, 0.9)
		k:box("PapanRak", s, p, WOOD, M.WoodPlanks)
		local cols = { rgb(190, 70, 60), rgb(70, 110, 170), rgb(90, 150, 100), rgb(230, 190, 70), rgb(240, 236, 226) }
		local x = 0.3
		while x < length - 0.5 do
			local w = 0.25 + rnd:NextNumber() * 0.2
			local h = 0.7 + rnd:NextNumber() * 0.4
			local ps = if alongZ then V(0.6, h, w) else V(w, h, 0.6)
			local pp = if alongZ then V(pos.X, y + 0.1 + h / 2, pos.Z + x + w / 2) else V(pos.X + x + w / 2, y + 0.1 + h / 2, pos.Z)
			if i == 3 and rnd:NextNumber() < 0.25 then
				k:cyl("Pot", 0.7, 0.6, pp, rgb(210, 110, 70), M.Concrete, { solid = false })
				k:ball("Daun", V(0.8, 0.8, 0.8), pp + V(0, 0.6, 0), rgb(70, 150, 80), M.Grass, { solid = false })
			else
				k:box("Buku", ps, pp, cols[rnd:NextInteger(1, #cols)], M.SmoothPlastic, { solid = false })
			end
			x += w + 0.04
		end
	end
	for _, e in { 0.15, length - 0.15 } do
		local p = if alongZ then V(pos.X, 3.1, pos.Z + e) else V(pos.X + e, 3.1, pos.Z)
		k:cyl("TiangRak", 0.18, 6.4, p, STEEL, M.Metal)
	end
end

return function()
	local building = Workspace.Map.Downtown.Buildings.KafeKota
	for _, n in { "BodyBulat", "Body", "Storefront", "Door1", "Dalam" } do
		local x = building:FindFirstChild(n)
		if x then x:Destroy() end
	end
	local root = Instance.new("Folder")
	root.Name = "Dalam"
	root.Parent = building
	local venue = CafeConfig.VENUES.kafekota
	local k = Kit.new(root, V(20, 1.2, -572))
	k.lightScale = 2.6
	local rnd = Random.new(23)

	-- ============================================================ cangkang
	k:group("Cangkang")
	local function buildWall(axis, c, a0, a1, inward, ops, brick)
		k:wall("Dinding", axis, c, T, a0, a1, 0, TOP, WALL, M.SmoothPlastic, table.clone(ops))
		local ci = c + inward * (T / 2 + 0.06)
		k:wall(if brick then "Bata" else "Beton", axis, ci, 0.12, a0, a1, 0, TOP - 0.5,
			if brick then BRICK else CONC, if brick then M.Brick else M.Concrete, holes(ops))
	end
	local frame = STEEL
	buildWall("x", HZ - T / 2, -(HX - R), HX - R, -1, {
		{ a = -12.0, b = -3.5, y0 = 0.5, y1 = 7.0, frame = frame, cols = 4, rows = 2 },
		{ door = true, a = -3.2, b = 3.2, y1 = 6.4 },
		{ a = 3.5, b = 12.0, y0 = 0.5, y1 = 7.0, frame = frame, cols = 4, rows = 2 },
	}, false)
	buildWall("x", -(HZ - T / 2), -(HX - R), HX - R, 1, {
		{ a = -11, b = -4.5, y0 = 4.4, y1 = 9.6, frame = frame, cols = 3, rows = 2 },
	}, true)
	local sideOps = {
		{ a = -7, b = -2.4, y0 = 3.4, y1 = 9.2, frame = frame, cols = 3, rows = 3 },
		{ a = 2.4, b = 7, y0 = 3.4, y1 = 9.2, frame = frame, cols = 3, rows = 3 },
	}
	buildWall("z", HX - T / 2, -(HZ - R), HZ - R, -1, sideOps, true)
	buildWall("z", -(HX - T / 2), -(HZ - R), HZ - R, 1, sideOps, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cx, cz = sx * (HX - R), sz * (HZ - R)
			local a0 = if sx > 0 and sz > 0 then 0 elseif sx < 0 and sz > 0 then 90 elseif sx < 0 then 180 else 270
			k:arc("Sudut", cx, cz, R, T, a0, a0 + 90, 0, TOP, WALL, M.SmoothPlastic, 10)
			local brick = not (sz > 0)
			k:arc("BataSudut", cx, cz, R - T, 0.12, a0, a0 + 90, 0, TOP - 0.5, if brick then BRICK else CONC,
				if brick then M.Brick else M.Concrete, 8)
		end
	end
	-- lantai beton poles + langit-langit beton gelap + balok baja, pipa, saluran udara
	k:roundSlab("Lantai", HX - 0.05, HZ - 0.05, R, -0.3, 0, rgb(126, 128, 134), M.Concrete)
	k:roundSlab("Langit", HX - 0.05, HZ - 0.05, R, CEIL, TOP, rgb(52, 54, 60), M.Concrete)
	for _, x in { -12, -4, 4, 12 } do
		k:box("BalokBaja", V(0.5, 0.8, 24.2), V(x, 10.9, 0), STEEL, M.Metal)
	end
	for _, z in { -8, -2.5, 3, 8.5 } do
		k:hcyl("PipaLangit", 0.45, 32, V(0, 10.1, z), STEEL_L, M.Metal, { solid = false })
	end
	k:box("SaluranUdara", V(24, 1.1, 1.3), V(4, 10.3, -6.5), rgb(150, 154, 160), M.Metal, { solid = false })
	-- keset karet dan karpet area
	k:box("KesetMasuk", V(6.4, 0.05, 2.6), V(0, 0.03, 10.4), rgb(40, 42, 46), M.Fabric, { solid = false })
	k:box("KarpetLounge", V(9.6, 0.05, 9), V(-11.2, 0.03, -7.2), rgb(140, 48, 48), M.Fabric, { solid = false })
	k:box("KarpetLoungeTepi", V(9.0, 0.06, 8.4), V(-11.2, 0.04, -7.2), rgb(176, 90, 70), M.Fabric, { solid = false })

	-- pintu kaca ganda berengsel baja hitam
	k:group("Pintu")
	k:doors("PintuKaca", 0, HZ - T / 2, 6.4, 6.3, STEEL, 0.5, 13)
	k:box("AmbangPintu", V(6.4, 0.1, 0.9), V(0, 0.05, HZ - T / 2), STEEL_L, M.Metal, { solid = false })
	local tb = k:box("TandaBuka", V(2.0, 1.0, 0.1), V(5.2, 5.2, HZ + 0.1), STEEL, M.Metal, { solid = false })
	k:label(tb, Enum.NormalId.Back, "BUKA", ORANGE, Enum.Font.Oswald, 60)

	-- ============================================================ konter + bar belakang
	k:group("Konter")
	local top = 3.65
	k:box("BadanKonter", V(14, 3.4, 1.9), V(5.5, 1.7, -8.4), STEEL, M.Metal)
	for i = 0, 14 do
		k:box("PapanKonter", V(0.5, 3.0, 0.06), V(-1.2 + i * 0.95, 1.7, -7.42), WOOD_D, M.WoodPlanks, { solid = false })
	end
	k:box("MejaKonter", V(14.4, 0.28, 2.3), V(5.5, 3.52, -8.4), rgb(150, 152, 158), M.Concrete)
	k:box("LisOranye", V(14, 0.12, 0.06), V(5.5, 3.3, -7.4), ORANGE, M.Neon, { solid = false })
	-- mesin espresso besar
	k:box("MesinEspresso", V(3.6, 2.0, 1.6), V(8.8, top + 1.0, -8.7), rgb(190, 196, 204), M.Metal, { solid = false })
	k:box("AtapMesin", V(3.7, 0.25, 1.7), V(8.8, top + 2.1, -8.7), STEEL, M.Metal, { solid = false })
	for _, dx in { -1.0, 0, 1.0 } do
		k:cyl("KepalaGrup", 0.5, 0.5, V(8.8 + dx, top + 1.2, -7.85), STEEL, M.Metal, { solid = false })
		k:cup(V(8.8 + dx, top + 0.2, -7.9), rgb(236, 236, 232), rgb(80, 50, 32))
	end
	k:hcyl("Uap", 0.12, 1.0, V(10.8, top + 1.4, -7.9), STEEL_L, M.Metal, { solid = false })
	k:box("LampuMesin", V(0.5, 0.2, 0.05), V(8.8, top + 1.7, -7.88), ORANGE, M.Neon, { solid = false })
	k:box("Penggiling", V(1.0, 1.6, 1.0), V(6.6, top + 0.8, -8.8), STEEL, M.Metal, { solid = false })
	k:cyl("Corong", 0.9, 0.9, V(6.6, top + 2.05, -8.8), rgb(210, 222, 228), M.Glass, { solid = false, t = 0.4 })
	-- kasir usaha pemain (titik BusinessConfig.POSITION): mesin kasir + papan
	k:box("Kasir", V(1.4, 0.55, 1.0), V(1.0, top + 0.28, -8.2), STEEL, M.Metal, { solid = false })
	k:box("LayarKasir", V(1.2, 0.8, 0.08), V(1.0, top + 0.95, -8.4), rgb(90, 170, 255), M.Neon, { solid = false, rot = CFrame.Angles(math.rad(-15), 0, 0) })
	k:box("LaciKasir", V(1.4, 0.25, 1.0), V(1.0, top + 0.12, -7.7), rgb(60, 62, 68), M.Metal, { solid = false })
	local sign = k:box("PapanKasir", V(4.4, 1.0, 0.12), V(-2.4, 7.4, -11.3), STEEL, M.Metal, { solid = false })
	k:label(sign, Enum.NormalId.Back, "KASIR • KELOLA KAFE", ORANGE, Enum.Font.Oswald, 60)
	-- display roti dan toples
	k:glass("KubahRoti", V(2.4, 1.2, 1.4), V(3.6, top + 0.7, -8.4), { t = 0.6, solid = false })
	k:box("AlasKubah", V(2.4, 0.15, 1.4), V(3.6, top + 0.08, -8.4), WOOD, M.Wood, { solid = false })
	for i = 1, 4 do
		k:ball("Donat", V(0.6, 0.25, 0.6), V(2.6 + i * 0.45, top + 0.3, -8.4), if i % 2 == 0 then rgb(240, 150, 170) else rgb(120, 76, 50), M.SmoothPlastic, { solid = false })
	end
	k:cup(V(-0.6, top, -7.9), rgb(236, 236, 232), rgb(86, 54, 34))
	k:cup(V(5.2, top, -7.9), rgb(236, 236, 232), rgb(86, 54, 34))
	k:box("Lonceng", V(0.35, 0.3, 0.35), V(-1.5, top + 0.15, -7.8), rgb(226, 172, 52), M.Metal, { solid = false })

	k:group("BarBelakang")
	k:box("LemariBelakang", V(14.2, 3.2, 0.8), V(5.5, 1.6, -11.9), STEEL, M.Metal)
	k:box("MejaLemari", V(14.4, 0.2, 1.0), V(5.5, 3.3, -11.85), CONC, M.Concrete)
	local theme = { bg = rgb(28, 30, 34), title = ORANGE, text = rgb(240, 238, 232), price = ORANGE, font = Enum.Font.Oswald, px = 70 }
	local function board(x, from, to, title)
		local rows = {}
		for i = from, to do
			local e = venue.menu[i]
			table.insert(rows, { e.name, Format.money(e.price) })
		end
		k:box("BingkaiPapan", V(4.5, 2.9, 0.14), V(x, 6.3, -12.1), STEEL, M.Metal, { solid = false })
		local pb = k:box("PapanMenu", V(4.2, 2.6, 0.1), V(x, 6.3, -12.0), rgb(28, 30, 34), M.SmoothPlastic, { solid = false })
		k:menuBoard(pb, Enum.NormalId.Back, title, rows, theme)
	end
	board(2.6, 1, 4, "KAFE KOTA ☕")
	board(7.4, 5, 7, "MENU ☕ 2")
	-- rak pipa dengan cangkir/toples di sisi kanan
	for _, y in { 4.4, 5.6, 6.8 } do
		k:box("PapanRak", V(2.4, 0.18, 0.8), V(11.4, y, -11.9), WOOD, M.WoodPlanks, { solid = false })
		for i = 1, 3 do
			k:cyl("Mug", 0.55, 0.55, V(10.6 + (i - 1) * 0.8, y + 0.36, -11.9), if (i + math.floor(y)) % 2 == 0 then ORANGE else rgb(236, 236, 232), M.SmoothPlastic, { solid = false })
		end
	end
	for _, x in { 10.2, 12.6 } do
		k:cyl("TiangRakDinding", 0.14, 3.2, V(x, 5.6, -11.9), STEEL, M.Metal, { solid = false })
	end
	for _, x in { 0, 5, 10 } do
		k:pendant(V(x + 0.5, 6.8, -8.4), CEIL - 0.1, STEEL, WARM, 1.1, 16, 1.1)
	end
	-- neon di dinding barat
	local neon = k:box("PapanNeon", V(5.2, 1.6, 0.12), V(-15.95, 6.8, -6.5), STEEL, M.Metal, { solid = false, rot = CFrame.Angles(0, PI / 2, 0) })
	k:label(neon, Enum.NormalId.Back, "KAFE KOTA", rgb(255, 120, 60), Enum.Font.Oswald, 70)
	local nl = k:box("CahayaNeon", V(0.2, 0.2, 0.2), V(-15.0, 6.8, -6.5), ORANGE, M.SmoothPlastic, { t = 1, solid = false, shadow = false })
	k:light(nl, rgb(255, 130, 70), 1.2, 18)

	-- ============================================================ perabot
	k:group("Perabot")
	-- meja komunal panjang + bangku, lampu gantung Edison
	local communal = V(-7.2, 0, 0)
	k:box("DauMejaKomunal", V(9.2, 0.35, 2.3), communal + V(0, 2.55, 0), WOOD, M.WoodPlanks)
	for _, sx in { -4, 4 } do
		k:box("KakiMejaKomunal", V(0.3, 2.4, 2.0), communal + V(sx, 1.2, 0), STEEL, M.Metal)
	end
	k:box("RelMeja", V(8, 0.2, 0.2), communal + V(0, 0.8, 0), STEEL, M.Metal, { solid = false })
	bench(k, communal + V(0, 0, 2.3), 8.4, PI, WOOD_D, STEEL)
	bench(k, communal + V(0, 0, -2.3), 8.4, 0, WOOD_D, STEEL)
	for _, x in { -3, 0, 3 } do
		k:pendant(communal + V(x, 7.0, 0), CEIL - 0.1, STEEL, WARM, 1.2, 18, 1.4)
		k:cup(communal + V(x - 0.7, 2.73, 0.3), rgb(236, 236, 232), rgb(86, 54, 34))
	end
	k:ball("PotKecil", V(1.2, 1.2, 1.2), communal + V(1.3, 3.3, -0.3), rgb(70, 150, 80), M.Grass, { solid = false })
	-- bar jendela depan (dua sisi) + bangku tinggi menghadap kaca
	for _, side in { -1, 1 } do
		k:box("MejaBar", V(7.4, 0.3, 1.2), V(side * 7.6, 3.4, 11.3), WOOD, M.WoodPlanks)
		for _, dx in { -3.2, 3.2 } do
			k:box("KakiBar", V(0.25, 3.3, 0.9), V(side * 7.6 + dx, 1.65, 11.3), STEEL, M.Metal)
		end
		for i = 0, 3 do
			k:stool(V(side * 7.6 - 2.8 + i * 1.9, 0, 9.7), STEEL, LEATHER, PI)
		end
		k:cup(V(side * 7.6 + 1, 3.55, 11.3), rgb(236, 236, 232), rgb(86, 54, 34))
		k:pendant(V(side * 7.6, 6.6, 10.6), CEIL - 0.1, STEEL, WARM, 1.0, 16, 1.2)
	end
	-- bilik sofa kulit di dinding timur
	for _, z in { 7.6, 2.8, -2.0 } do
		k:sofa(V(15.0, 0, z), PI / 2, 4.2, LEATHER, STEEL, M.Leather)
		k:rectTable(V(12.7, 0, z), 2.0, 3.0, 2.4, WOOD, M.WoodPlanks, STEEL)
		k:cup(V(12.5, 2.4, z - 0.5), rgb(236, 236, 232), rgb(86, 54, 34))
		k:chair(V(10.9, 0, z - 0.95), -PI / 2, STEEL, WOOD)
		k:chair(V(10.9, 0, z + 0.95), -PI / 2, STEEL, WOOD)
		k:pendant(V(12.8, 6.6, z), CEIL - 0.1, STEEL, WARM, 1.0, 16, 1.2)
	end
	-- lounge barat belakang: sofa, kursi berlengan, meja kopi, lampu lantai, rak pipa
	k:sofa(V(-15.0, 0, -5.6), -PI / 2, 5.4, rgb(66, 70, 78), STEEL, M.Fabric)
	k:sofa(V(-9.2, 0, -11.0), PI, 5.4, rgb(66, 70, 78), STEEL, M.Fabric)
	k:sofa(V(-7.2, 0, -6.2), PI / 2, 2.6, LEATHER, STEEL, M.Leather)
	k:rectTable(V(-11.4, 0, -6.8), 3.0, 2.0, 1.6, WOOD, M.WoodPlanks, STEEL)
	k:cup(V(-11.4, 1.6, -6.8), rgb(236, 236, 232), rgb(86, 54, 34))
	k:cyl("TiangLampuLantai", 0.15, 6.0, V(-15.6, 3.0, -9.6), STEEL, M.Metal, { solid = false })
	local lamp = k:ball("KapLampu", V(1.4, 1.1, 1.4), V(-15.6, 6.3, -9.6), WARM, M.Neon, { solid = false })
	k:light(lamp, WARM, 1.0, 16)
	pipeShelf(k, V(-15.85, 0, 0.8), 6.4, true, rnd)
	-- tanaman besar di baja hitam sisi pintu
	for _, sx in { -1, 1 } do
		k:plant(V(sx * 4.8, 0, 11.0), 1.3, rgb(44, 46, 52), rgb(60, 140, 70))
	end
	k:plant(V(15.2, 0, 11.0), 1.1, rgb(44, 46, 52), rgb(80, 150, 70))
	k:cyl("TongSampah", 1.1, 1.8, V(4.2, 0.9, 5.6), STEEL_L, M.Metal)
	-- lemari pendingin
	k:box("LemariPendingin", V(2.8, 5.2, 1.8), V(-1.8, 2.6, -11.4), rgb(40, 42, 46), M.Metal)
	k:glass("PintuKulkas", V(2.4, 4.4, 0.1), V(-1.8, 2.6, -10.45), { t = 0.6, solid = false })
	for i = 1, 4 do
		k:cyl("Botol", 0.5, 1.0, V(-2.5 + (i % 2) * 1.4, 0.8 + (i - 1) * 1.0, -11.4), if i % 2 == 0 then rgb(250, 190, 60) else rgb(200, 60, 60), M.SmoothPlastic, { solid = false })
	end
	-- cahaya pengisi
	k:group("Cahaya")
	for _, p in { V(0, 9, 6), V(0, 9, -4), V(-10, 9, 4), V(12, 9, 4), V(-10, 8, -8) } do
		local l = k:box("TitikCahaya", V(0.2, 0.2, 0.2), p, WARM, M.SmoothPlastic, { t = 1, solid = false, shadow = false })
		k:light(l, WARM, 0.75, 30)
	end

	-- ============================================================ titik pelayan
	local titik = Workspace.Map:FindFirstChild("KafeTitik")
	if titik == nil then
		titik = Instance.new("Folder")
		titik.Name = "KafeTitik"
		titik.Parent = Workspace.Map
	end
	for _, c in titik:GetChildren() do
		if c:GetAttribute("Venue") == "kafekota" then c:Destroy() end
	end
	local function marker(role, idx, pos, facing)
		local p = Instance.new("Part")
		p.Name = "kafekota_" .. role .. (if idx then tostring(idx) else "")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = V(1, 1, 1)
		p.Position = V(20, 1.2, -572) + pos
		p:SetAttribute("Venue", "kafekota")
		p:SetAttribute("Role", role)
		if idx then p:SetAttribute("Index", idx) end
		if facing then p:SetAttribute("Facing", facing) end
		p.Parent = titik
	end
	marker("Barista", nil, V(5.0, 0, -10.0), V(0, 0, 1))
	marker("Meja", nil, V(3.5, 3.9, -8.4))
	marker("Kasir", nil, V(1.0, 3.9, -8.2))
	for i, p in ipairs({ V(4.5, 0, -5.5), V(4.5, 0, 3), V(3.0, 0, 8), V(4.5, 0, 3) }) do
		marker("Jalur", i, p)
	end
	return #root:GetDescendants()
end
