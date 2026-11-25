--!nonstrict
--[[
	ROBLOCK CITY: interior Cafe Startduck (Workspace.Map.Residential.Buildings.Downtown.Kafe, depan menghadap +Z).
	Cangkang lama (mesh padat BodyBulat) diganti dinding part bersudut bulat + kaca; pintu kaca ganda berengsel
	(ShopDoorService, tag AutoDoor). Gaya: hangat, krem-kuning-kayu oak. Lantai bawah: konter barista, papan
	menu kapur, meja, bangku jendela, ruang baca; lantai atas (mezanin) lewat tangga: sofa panjang + meja.
	Titik pelayan ditaruh di Workspace.Map.KafeTitik (dibaca CafeService). Aman dijalankan ulang.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent:WaitForChild("KafeKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CafeConfig = require(Shared:WaitForChild("CafeConfig"))
local Format = require(Shared:WaitForChild("Format"))

local rgb, M, V, PI = Color3.fromRGB, Enum.Material, Vector3.new, math.pi

local HX, HZ, R, T = 11, 10, 3.4, 0.7
local TOP, CEIL, MEZZ = 15.8, 15.3, 6.8
local WALL, PAINT = rgb(240, 205, 150), rgb(252, 240, 216)
local OAK, OAK_D, ESP = rgb(196, 148, 96), rgb(150, 100, 60), rgb(96, 62, 40)
local YELLOW, CREAM, MUSTARD = rgb(255, 200, 50), rgb(252, 244, 228), rgb(238, 178, 48)
local MINT, SLATE = rgb(150, 205, 184), rgb(38, 44, 42)
local WARM = rgb(255, 226, 170)

local function holes(ops)
	local r = {}
	for _, op in ipairs(ops) do
		local c = table.clone(op)
		c.hole = not op.door
		table.insert(r, c)
	end
	return r
end

local function duck(k, pos, s, yaw)
	local rot = CFrame.Angles(0, yaw or 0, 0)
	local function p(n, size, off, col, ball)
		local part = k:box(n, size * s, pos + rot:VectorToWorldSpace(off * s), col, M.SmoothPlastic, { rot = rot, solid = false })
		if ball then part.Shape = Enum.PartType.Ball end
		return part
	end
	local y, o = rgb(255, 214, 70), rgb(245, 140, 40)
	p("Badan", V(2.6, 2.2, 3.2), V(0, 1.1, 0), y, true)
	p("Ekor", V(1.1, 1.0, 1.3), V(0, 1.9, 1.5), y, true)
	p("Kepala", V(1.9, 1.9, 1.9), V(0, 2.9, -0.9), y, true)
	p("Paruh", V(1.1, 0.4, 0.9), V(0, 2.7, -1.9), o, false)
	for _, sx in { -1, 1 } do
		p("Mata", V(0.3, 0.38, 0.2), V(sx * 0.45, 3.2, -1.7), rgb(30, 28, 34), true)
		p("Sayap", V(0.5, 1.3, 1.9), V(sx * 1.3, 1.3, 0.2), rgb(250, 190, 50), true)
	end
end

local function books(k, rnd, base, axis, length, y, depth)
	local x = 0
	local cols = { rgb(190, 70, 60), rgb(70, 110, 170), rgb(90, 150, 100), rgb(230, 190, 70), rgb(150, 100, 60), rgb(240, 236, 226) }
	while x < length - 0.3 do
		local w = 0.22 + rnd:NextNumber() * 0.2
		local h = 0.8 + rnd:NextNumber() * 0.45
		if x + w > length - 0.15 then break end
		local size, off
		if axis == "z" then
			size = V(depth, h, w)
			off = V(0, h / 2, x + w / 2)
		else
			size = V(w, h, depth)
			off = V(x + w / 2, h / 2, 0)
		end
		k:box("Buku", size, base + off + V(0, y, 0), cols[rnd:NextInteger(1, #cols)], M.SmoothPlastic, { solid = false })
		x += w + 0.03
	end
end

local function bookcase(k, rnd, pos, axis, length, height, depth)
	-- pos = ujung awal (sumbu panjang), y = dasar; tinggi `height`
	local n = math.floor(height / 1.5)
	local function at(a, y, thick)
		if axis == "z" then
			return V(pos.X, y, pos.Z + a), V(depth, thick, length)
		end
		return V(pos.X + a, y, pos.Z), V(length, thick, depth)
	end
	local mid, sz = at(length / 2, pos.Y + height + 0.1, 0.25)
	k:box("AtapRak", sz, mid, ESP, M.Wood)
	for i = 0, n do
		local m2, s2 = at(length / 2, pos.Y + i * (height / n) + 0.12, 0.24)
		k:box("PapanRak", s2, m2, OAK_D, M.Wood)
		if i < n then
			books(k, rnd, (if axis == "z" then V(pos.X, pos.Y, pos.Z) else V(pos.X, pos.Y, pos.Z)), axis, length, pos.Y + i * (height / n) + 0.24 - pos.Y, depth * 0.7)
		end
	end
	for _, e in { 0.1, length - 0.1 } do
		local m3 = if axis == "z" then V(pos.X, pos.Y + height / 2, pos.Z + e) else V(pos.X + e, pos.Y + height / 2, pos.Z)
		local s3 = if axis == "z" then V(depth, height + 0.3, 0.2) else V(0.2, height + 0.3, depth)
		k:box("TiangRak", s3, m3, ESP, M.Wood)
	end
end

return function()
	local building = Workspace.Map.Residential.Buildings.Downtown.Kafe
	for _, n in { "BodyBulat", "Body", "Storefront", "Windows2", "Door1", "Dalam" } do
		local x = building:FindFirstChild(n)
		if x then x:Destroy() end
	end
	local root = Instance.new("Folder")
	root.Name = "Dalam"
	root.Parent = building
	local venue = CafeConfig.VENUES.startduck
	local k = Kit.new(root, V(184, 1.2, 182))
	k.lightScale = 0.14
	k.tone = 0.84
	local rnd = Random.new(11)

	-- ============================================================ cangkang
	k:group("Cangkang")
	local function buildWall(axis, c, a0, a1, inward, lower, upper)
		k:wall("Dinding", axis, c, T, a0, a1, 0, 7.2, WALL, M.SmoothPlastic, table.clone(lower))
		k:wall("Dinding", axis, c, T, a0, a1, 7.2, TOP, WALL, M.SmoothPlastic, table.clone(upper))
		local ci = c + inward * (T / 2 + 0.05)
		k:wall("Cat", axis, ci, 0.1, a0, a1, 3.2, 7.2, PAINT, M.SmoothPlastic, holes(lower))
		k:wall("Cat", axis, ci, 0.1, a0, a1, 7.2, TOP - 0.5, PAINT, M.SmoothPlastic, holes(upper))
		local cw = c + inward * (T / 2 + 0.07)
		k:wall("Lis", axis, cw, 0.14, a0, a1, 0, 3.2, OAK, M.WoodPlanks, holes(lower))
		k:wall("LisAtas", axis, c + inward * (T / 2 + 0.1), 0.2, a0, a1, 3.1, 3.3, ESP, M.Wood, holes(lower))
	end
	local frontLower = {
		{ a = -7.2, b = -3.4, y0 = 0.8, y1 = 6.0, frame = ESP, cols = 2 },
		{ door = true, a = -3, b = 3, y1 = 6.0 },
		{ a = 3.4, b = 7.2, y0 = 0.8, y1 = 6.0, frame = ESP, cols = 2 },
	}
	local frontUpper = { { a = -6.5, b = 6.5, y0 = 11.2, y1 = 14.8, frame = ESP, cols = 5 } }
	local backUpper = { { a = -6, b = 6, y0 = 10.0, y1 = 14.2, frame = ESP, cols = 4 } }
	local eastLower = {
		{ a = -5.2, b = -1.2, y0 = 1.6, y1 = 5.6, frame = ESP, cols = 2 },
		{ a = 0.4, b = 4.4, y0 = 1.6, y1 = 5.6, frame = ESP, cols = 2 },
	}
	local sideUpper = {
		{ a = -5.5, b = -0.5, y0 = 8.4, y1 = 13.2, frame = ESP, cols = 3 },
		{ a = 0.5, b = 5.5, y0 = 8.4, y1 = 13.2, frame = ESP, cols = 3 },
	}
	buildWall("x", HZ - T / 2, -(HX - R), HX - R, -1, frontLower, frontUpper)
	buildWall("x", -(HZ - T / 2), -(HX - R), HX - R, 1, {}, backUpper)
	buildWall("z", HX - T / 2, -(HZ - R), HZ - R, -1, eastLower, sideUpper)
	buildWall("z", -(HX - T / 2), -(HZ - R), HZ - R, 1, {}, sideUpper)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cx, cz = sx * (HX - R), sz * (HZ - R)
			local a0 = if sx > 0 and sz > 0 then 0 elseif sx < 0 and sz > 0 then 90 elseif sx < 0 then 180 else 270
			k:arc("Sudut", cx, cz, R, T, a0, a0 + 90, 0, TOP, WALL, M.SmoothPlastic, 8)
			k:arc("CatSudut", cx, cz, R - T, 0.1, a0, a0 + 90, 3.2, TOP - 0.5, PAINT, M.SmoothPlastic, 6)
			k:arc("LisSudut", cx, cz, R - T, 0.14, a0, a0 + 90, 0, 3.2, OAK, M.WoodPlanks, 6)
		end
	end
	-- lantai, langit-langit, balok kayu
	k:roundSlab("Lantai", HX - 0.05, HZ - 0.05, R, -0.3, 0, OAK, M.WoodPlanks)
	k:roundSlab("Langit", HX - 0.05, HZ - 0.05, R, CEIL, TOP, PAINT, M.SmoothPlastic)
	for _, z in { -7.2, -3.6, 0, 3.6, 7.2 } do
		k:box("Balok", V(20.2, 0.6, 0.5), V(0, 15.0, z), ESP, M.Wood)
	end
	-- ubin papan catur area barista
	for ix = 0, 6 do
		for iz = 0, 2 do
			k:box("Ubin", V(2, 0.04, 2), V(-5 + 2 * ix, 0.02, -8.2 + 2 * iz),
				if (ix + iz) % 2 == 0 then rgb(250, 246, 238) else rgb(64, 50, 44), M.Marble, { solid = false })
		end
	end
	k:box("Keset", V(5, 0.05, 2.4), V(0, 0.03, 7.9), ESP, M.Fabric, { solid = false })

	-- pintu kaca ganda berengsel + ambang
	k:group("Pintu")
	k:doors("PintuKaca", 0, HZ - T / 2, 6, 5.9, ESP, 0.5, 12)
	k:box("AmbangPintu", V(6, 0.1, 0.9), V(0, 0.05, HZ - T / 2), rgb(214, 170, 70), M.Metal, { solid = false })
	k:box("TandaBuka", V(1.7, 0.8, 0.1), V(5.2, 4.8, HZ + 0.12), SLATE, M.SmoothPlastic, { solid = false })
	k:label(k.cur:FindFirstChild("TandaBuka"), Enum.NormalId.Back, "BUKA • OPEN", YELLOW, Enum.Font.FredokaOne, 60)

	-- ============================================================ lantai atas (mezanin) + tangga
	k:group("LantaiAtas")
	local mz = MEZZ
	k:box("Mezanin", V(20.6, 0.4, 3.6), V(0, mz - 0.2, -4.8), OAK, M.WoodPlanks)
	k:box("Mezanin", V(15.2, 0.38, 2.7), V(0, mz - 0.2, -7.95), OAK, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		k:cyl("Mezanin", 5.4, 0.36, V(sx * 7.6, mz - 0.2, -6.6), OAK, M.WoodPlanks)
	end
	local fascia = k:box("Fasia", V(20.6, 0.9, 0.14), V(0, mz - 0.45, -2.95), ESP, M.Wood, { solid = false })
	k:label(fascia, Enum.NormalId.Back, "CAFE STARTDUCK  •  KOPI  •  COKELAT  •  KUE", YELLOW, Enum.Font.FredokaOne, 60)
	for _, x in { -3, 3.6, 10 } do
		k:cyl("TiangMezanin", 0.5, mz - 0.4, V(x, (mz - 0.4) / 2, -3.2), ESP, M.Wood)
	end
	for i = 1, 8 do
		local h = 0.85 * i
		local zc = 4.2 - 0.9 * (i - 0.5)
		k:box("Anak Tangga", V(2.9, h, 0.9), V(-8.85, h / 2, zc), OAK, M.WoodPlanks)
		k:box("PanelTangga", V(0.1, 3.0, 0.9), V(-7.35, h + 1.5, zc), rgb(190, 225, 235), M.Glass, { t = 0.55, shadow = false })
	end
	k:box("PegangTangga", V(0.2, 0.2, 9.9), V(-7.35, 6.6, 0.6), ESP, M.Wood,
		{ rot = CFrame.lookAt(V(0, 0, 0), V(0, 6.8, -7.2)), solid = false })
	k:cyl("TiangTangga", 0.3, 3.4, V(-7.35, 1.7, 4.4), ESP, M.Wood)
	k:glass("PagarMezanin", V(17.3, 3.0, 0.1), V(1.65, mz + 1.5, -3.1))
	k:box("PegangMezanin", V(17.3, 0.2, 0.3), V(1.65, mz + 3.05, -3.1), ESP, M.Wood, { solid = false })
	for _, x in { -6.9, -2.6, 1.7, 6, 10.2 } do
		k:cyl("TiangPagar", 0.25, 3.1, V(x, mz + 1.55, -3.1), ESP, M.Wood)
	end
	-- mezanin: sofa panjang di dinding belakang, tiga meja, rak buku, tanaman
	k:group("IsiLantaiAtas")
	k:sofa(V(0, mz, -8.1), PI, 14.8, MUSTARD, ESP, M.Fabric)
	for _, x in { -4.5, 0, 4.5 } do
		k:roundTable(V(x, mz, -5.7), 2.6, 2.5, CREAM, M.Marble, ESP)
		k:cup(V(x - 0.5, mz + 2.5, -5.7), CREAM, rgb(86, 54, 34))
		k:chair(V(x, mz, -4.0), 0, OAK_D, if x == 0 then MINT else CREAM)
	end
	bookcase(k, rnd, V(10.0, mz, -8.6), "z", 5.2, 5.4, 0.7)
	k:plant(V(8.9, mz, -3.9), 1.0, CREAM, rgb(60, 140, 70))
	k:plant(V(-8.4, mz, -4.2), 0.9, CREAM, rgb(80, 150, 70))
	duck(k, V(-9.2, mz, -7.6), 0.45, PI * 0.85)
	for _, x in { -4.5, 0, 4.5 } do
		k:pendant(V(x, mz + 4.5, -5.7), CEIL - 0.1, YELLOW, WARM, 1.1, 20, 1.5)
	end
	k:picture(V(-9.95, mz + 5.2, -6.2), V(3.4, 2.6, 0), PI / 2 * -1, ESP, "☕", CREAM, ESP)

	-- ============================================================ lantai bawah
	k:group("Konter")
	local cx0 = 1.0
	k:box("BadanKonter", V(11, 3.4, 1.8), V(cx0, 1.7, -5.4), ESP, M.Wood)
	k:box("StripKuning", V(11, 0.45, 0.06), V(cx0, 2.5, -4.47), YELLOW, M.SmoothPlastic, { solid = false })
	for i = 0, 10 do
		k:box("LisKonter", V(0.12, 2.3, 0.06), V(cx0 - 5 + i, 1.15, -4.47), OAK_D, M.Wood, { solid = false })
	end
	k:box("MejaKonter", V(11.4, 0.25, 2.2), V(cx0, 3.52, -5.4), CREAM, M.Marble)
	local top = 3.65
	-- mesin espresso
	local mesin = k:box("MesinEspresso", V(2.6, 1.9, 1.4), V(-2.5, top + 0.95, -5.7), rgb(200, 204, 212), M.Metal, { solid = false })
	k:box("AtapMesin", V(2.7, 0.2, 1.5), V(-2.5, top + 1.95, -5.7), rgb(176, 112, 72), M.Metal, { solid = false })
	for _, dx in { -0.6, 0.6 } do
		k:cyl("KepalaGrup", 0.5, 0.5, V(-2.5 + dx, top + 1.1, -4.95), rgb(34, 34, 38), M.Metal, { solid = false })
		k:cup(V(-2.5 + dx, top + 0.15, -5.0), CREAM, rgb(80, 50, 32))
	end
	k:hcyl("Uap", 0.12, 0.9, V(-3.6, top + 1.3, -5.0), rgb(180, 184, 190), M.Metal, { solid = false })
	k:box("LampuMesin", V(0.4, 0.2, 0.05), V(-2.5, top + 1.6, -4.98), rgb(255, 120, 60), M.Neon, { solid = false })
	_ = mesin
	-- penggiling kopi, kasir, etalase kue
	k:box("Penggiling", V(0.9, 1.5, 0.9), V(-0.3, top + 0.75, -5.8), rgb(40, 40, 46), M.Metal, { solid = false })
	k:cyl("Corong", 0.9, 0.9, V(-0.3, top + 1.95, -5.8), rgb(210, 220, 225), M.Glass, { solid = false, t = 0.4 })
	k:box("Kasir", V(1.2, 0.5, 0.9), V(1.4, top + 0.25, -5.6), rgb(50, 50, 56), M.SmoothPlastic, { solid = false })
	k:box("LayarKasir", V(1.0, 0.7, 0.08), V(1.4, top + 0.85, -5.7), rgb(90, 170, 255), M.Neon, { solid = false, rot = CFrame.Angles(math.rad(-15), 0, 0) })
	k:box("DasarEtalase", V(3.8, 0.2, 1.6), V(4.6, top + 0.1, -5.3), CREAM, M.Marble, { solid = false })
	k:glass("KacaEtalase", V(3.8, 1.5, 1.6), V(4.6, top + 1.0, -5.3), { t = 0.7, solid = false })
	k:box("RakEtalase", V(3.6, 0.1, 1.4), V(4.6, top + 0.65, -5.3), CREAM, M.Marble, { solid = false })
	for i = 1, 5 do
		k:ball("Croissant", V(0.6, 0.35, 0.8), V(3.2 + i * 0.55, top + 0.35, -5.1), rgb(222, 160, 80), M.SmoothPlastic, { solid = false })
	end
	for i = 1, 3 do
		k:cyl("Kue", 0.9, 0.35, V(3.2 + i * 1.0, top + 0.85, -5.4), if i == 2 then rgb(240, 150, 170) else rgb(120, 76, 50), M.SmoothPlastic, { solid = false })
		k:ball("Ceri", V(0.2, 0.2, 0.2), V(3.2 + i * 1.0, top + 1.1, -5.4), rgb(200, 40, 50), M.SmoothPlastic, { solid = false })
	end
	duck(k, V(6.0, top, -5.0), 0.18, PI)
	k:cup(V(0.4, top, -4.9), CREAM, rgb(86, 54, 34))
	k:cup(V(2.4, top, -4.8), CREAM, rgb(86, 54, 34))
	k:box("Lonceng", V(0.35, 0.3, 0.35), V(2.0, top + 0.15, -4.6), rgb(226, 172, 52), M.Metal, { solid = false })

	-- bar belakang + papan menu kapur
	k:group("BarBelakang")
	k:box("LemariBelakang", V(12.5, 3.2, 0.8), V(0, 1.6, -8.9), ESP, M.Wood)
	k:box("MejaLemari", V(12.8, 0.2, 1.0), V(0, 3.3, -8.85), CREAM, M.Marble)
	local theme = { bg = SLATE, title = YELLOW, text = CREAM, price = YELLOW, font = Enum.Font.FredokaOne, px = 70 }
	local function board(x, from, to, title)
		local rows = {}
		for i = from, to do
			local e = venue.menu[i]
			table.insert(rows, { e.name, Format.money(e.price) })
		end
		k:box("BingkaiPapan", V(4.4, 2.8, 0.14), V(x, 5.0, -9.15), OAK_D, M.Wood, { solid = false })
		local pb = k:box("PapanMenu", V(4.1, 2.5, 0.1), V(x, 5.0, -9.07), SLATE, M.SmoothPlastic, { solid = false })
		k:menuBoard(pb, Enum.NormalId.Back, title, rows, theme)
	end
	board(-2.5, 1, 4, "MENU 🦆")
	board(2.5, 5, 7, "MENU 🦆 2")
	for _, x in { -6.8, 6.8 } do
		for _, y in { 4.3, 5.4 } do
			k:box("RakDinding", V(2.6, 0.18, 0.7), V(x, y, -8.95), OAK, M.Wood, { solid = false })
			for i = 1, 3 do
				k:cyl("Mug", 0.55, 0.55, V(x - 0.9 + (i - 1) * 0.9, y + 0.36, -8.95), if (i + math.floor(y)) % 2 == 0 then YELLOW else CREAM, M.SmoothPlastic, { solid = false })
			end
		end
		k:cyl("ToplesKopi", 0.9, 1.2, V(x, 3.9, -8.85), rgb(210, 222, 228), M.Glass, { solid = false, t = 0.4 })
		k:cyl("BijiKopi", 0.8, 0.9, V(x, 3.75, -8.85), rgb(70, 46, 30), M.SmoothPlastic, { solid = false })
	end
	-- lampu gantung di atas konter + lampu bawah mezanin
	for _, x in { -3, 1, 5 } do
		k:pendant(V(x, 5.0, -5.4), mz - 0.4, YELLOW, WARM, 1.0, 14, 1.4)
	end

	-- bangku, meja, kursi lantai bawah
	k:group("Perabot")
	for _, z in { 1.4, 5.6 } do
		k:roundTable(V(-4.0, 0, z), 2.8, 2.5, CREAM, M.Marble, ESP)
		k:cup(V(-4.4, 2.5, z), CREAM, rgb(86, 54, 34))
		k:chair(V(-6.0, 0, z), -PI / 2, OAK_D, if z > 3 then MINT else MUSTARD)
		k:chair(V(-2.0, 0, z), PI / 2, OAK_D, if z > 3 then MUSTARD else MINT)
		k:pendant(V(-4.0, 8.6, z), CEIL - 0.1, rgb(250, 244, 230), WARM, 1.0, 18, 1.6)
	end
	for _, z in { 1.2, 5.4 } do
		k:sofa(V(9.1, 0, z), PI / 2, 3.8, MUSTARD, ESP, M.Fabric)
		k:rectTable(V(6.9, 0, z), 1.9, 2.6, 2.4, OAK, M.WoodPlanks, ESP)
		k:cup(V(6.7, 2.4, z - 0.4), CREAM, rgb(86, 54, 34))
		k:chair(V(5.0, 0, z), -PI / 2, OAK_D, CREAM)
		k:pendant(V(7.0, 8.6, z), CEIL - 0.1, rgb(250, 244, 230), WARM, 1.0, 18, 1.5)
	end
	-- jendela depan: bak tanaman + patung bebek + tanaman besar di samping pintu
	for _, sx in { -1, 1 } do
		k:box("BakTanaman", V(3.8, 1.2, 0.9), V(sx * 5.4, 0.6, 8.7), OAK_D, M.Wood)
		k:plant(V(sx * 4.6, 1.2, 8.7), 0.6, CREAM, rgb(70, 150, 80))
		k:plant(V(sx * 6.3, 1.2, 8.7), 0.5, CREAM, rgb(90, 160, 70))
	end
	k:plant(V(-3.5, 0, 8.4), 1.1, CREAM, rgb(60, 140, 70))
	k:box("AlasBebek", V(2.4, 0.3, 2.4), V(8.4, 0.15, 7.6), CREAM, M.Marble)
	duck(k, V(8.4, 0.3, 7.6), 0.9, PI + 0.5)
	-- sudut baca di bawah mezanin (barat): rak buku, kursi berlengan, meja kecil
	bookcase(k, rnd, V(-10.0, 0, -8.8), "z", 5.2, 5.6, 0.7)
	k:sofa(V(-8.4, 0, -5.6), -PI / 2, 2.6, rgb(236, 120, 80), ESP, M.Fabric)
	k:roundTable(V(-6.6, 0, -5.6), 1.6, 1.8, OAK, M.WoodPlanks, ESP)
	k:cup(V(-6.6, 1.8, -5.6), CREAM, rgb(86, 54, 34))
	k:cyl("TiangLampu", 0.15, 5.0, V(-9.1, 2.5, -8.2), ESP, M.Metal, { solid = false })
	local fl = k:ball("KapLampu", V(1.2, 1.0, 1.2), V(-9.1, 5.3, -8.2), WARM, M.Neon, { solid = false })
	k:light(fl, WARM, 1.0, 14)
	-- lemari minuman (timur belakang) dan tempat sampah
	k:box("Lemari Pendingin", V(1.8, 5.2, 2.8), V(9.4, 2.6, -6.6), rgb(240, 242, 245), M.Metal)
	k:glass("PintuKulkas", V(0.1, 4.4, 2.4), V(8.46, 2.6, -6.6), { t = 0.6, solid = false })
	for i = 1, 4 do
		k:cyl("Botol", 0.5, 1.0, V(8.9, 0.8 + (i - 1) * 1.0, -6.6 + (i % 2) * 0.7 - 0.4), if i % 2 == 0 then rgb(250, 190, 60) else rgb(200, 60, 60), M.SmoothPlastic, { solid = false })
	end
	k:cyl("TongSampah", 1.1, 1.8, V(2.6, 0.9, 8.6), rgb(150, 156, 160), M.Metal)
	-- gambar dinding
	k:picture(V(10.25, 8.4, 1.2), V(3.6, 2.6, 0), PI / 2 * -1 + PI, ESP, "🦆", rgb(255, 234, 150), ESP)
	k:picture(V(-10.25, 8.4, 5.8), V(3.0, 2.2, 0), -PI / 2, ESP, "☕", rgb(252, 244, 228), ESP)
	-- cahaya pengisi ruangan
	k:group("Cahaya")
	for _, p in { V(0, 13, 4), V(0, 13, -3), V(-6, 9, 3), V(6, 9, 3), V(0, 5.2, -7) } do
		local l = k:box("TitikCahaya", V(0.2, 0.2, 0.2), p, WARM, M.SmoothPlastic, { t = 1, solid = false, shadow = false })
		k:light(l, WARM, 0.7, 18)
	end

	-- ============================================================ titik pelayan
	local map = Workspace.Map
	local titik = map:FindFirstChild("KafeTitik")
	if titik == nil then
		titik = Instance.new("Folder")
		titik.Name = "KafeTitik"
		titik.Parent = map
	end
	for _, c in titik:GetChildren() do
		if c:GetAttribute("Venue") == "startduck" then c:Destroy() end
	end
	local function marker(role, idx, pos, facing)
		local p = Instance.new("Part")
		p.Name = "startduck_" .. role .. (if idx then tostring(idx) else "")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = V(1, 1, 1)
		p.Position = V(184, 1.2, 182) + pos
		p:SetAttribute("Venue", "startduck")
		p:SetAttribute("Role", role)
		if idx then p:SetAttribute("Index", idx) end
		if facing then p:SetAttribute("Facing", facing) end
		p.Parent = titik
	end
	marker("Barista", nil, V(-1.4, 0, -7.2), V(0, 0, 1))
	marker("Meja", nil, V(1, 3.9, -5.4))
	for i, p in ipairs({ V(1.2, 0, -2.6), V(1.2, 0, 4.4), V(2.0, 0, 7.4), V(1.2, 0, 4.4) }) do
		marker("Jalur", i, p)
	end
	return #root:GetDescendants()
end
