local B = {}
local rgb = Color3.fromRGB
local PI = math.pi
local X0, X1, ZF, ZB, CW = -251.5, -114.5, -77.5, -45.0, -71.5
local ROOMS = {
	A = { x0 = -251.5, x1 = -223.25, c = -237.4 },
	B = { x0 = -222.75, x1 = -194.25, c = -208.5 },
	G = { x0 = -171.75, x1 = -143.75, c = -157.75 },
	K = { x0 = -143.25, x1 = -114.5, c = -128.9 },
}
local CREAM = rgb(252, 244, 226)
local MARBLE = Enum.Material.Marble

local CFG = {
	[1] = {
		fy = 1.4, top = 11.4,
		A = { kind = "kelas", label = "KELAS 1A", accent = rgb(255, 236, 170), guru = "Bu Ani", rows = "1A" },
		B = { kind = "kelas", label = "KELAS 1B", accent = rgb(190, 226, 255), guru = "Pak Joko", rows = "1B" },
		G = { kind = "guru", label = "RUANG GURU", accent = rgb(214, 240, 214) },
		K = { kind = "kepsek", label = "KEPALA SEKOLAH", accent = rgb(240, 214, 214) },
	},
	[2] = {
		fy = 12.5, top = 22.0,
		A = { kind = "kelas", label = "KELAS 2A", accent = rgb(255, 210, 225), guru = "Bu Rina", rows = "2A" },
		B = { kind = "kelas", label = "KELAS 2B", accent = rgb(222, 210, 250), guru = "Pak Hendra", rows = "2B" },
		G = { kind = "kelas", label = "KELAS 3A", accent = rgb(255, 222, 190), guru = "Bu Wati", rows = "3A" },
		K = { kind = "kelas", label = "KELAS 3B", accent = rgb(190, 240, 235), guru = "Pak Agus", rows = "3B" },
	},
}

local NAMA_L = { "Budi", "Andi", "Rizky", "Fajar", "Dimas", "Rafi", "Bagas", "Raka", "Dika", "Gilang", "Arif", "Yoga" }
local NAMA_P = { "Siti", "Dewi", "Putri", "Ayu", "Nia", "Sari", "Tika", "Maya", "Lina", "Wulan", "Citra", "Rara" }
local KULIT = { rgb(224, 172, 120), rgb(198, 146, 98), rgb(240, 200, 160), rgb(170, 118, 80), rgb(210, 160, 112) }
local RAMBUT = { rgb(30, 24, 22), rgb(50, 36, 28), rgb(24, 20, 20), rgb(70, 48, 30) }

local function face(cf_pos, dir)
	return CFrame.lookAt(cf_pos, cf_pos + dir)
end

-- CFrame pelat menghadap arah (normal) yang diberikan: bagian depan sign = -Z lokal
local FACE_NEG_Z = CFrame.Angles(0, 0, 0)
local FACE_POS_Z = CFrame.Angles(0, PI, 0)
local FACE_POS_X = CFrame.Angles(0, -PI / 2, 0)
local FACE_NEG_X = CFrame.Angles(0, PI / 2, 0)

function B.build(L, root, fl, ctx)
	local cfg = CFG[fl]
	local fy, top = cfg.fy, cfg.top
	local rng = Random.new(1000 + fl)
	local usedNames = {}
	local function pickName(g)
		local list = if g == "L" then NAMA_L else NAMA_P
		for _ = 1, 20 do
			local n = list[rng:NextInteger(1, #list)]
			if not usedNames[n] then
				usedNames[n] = true
				return n
			end
		end
		return list[rng:NextInteger(1, #list)]
	end

	local shell = Instance.new("Model")
	shell.Name = "Bangunan"
	local furn = Instance.new("Model")
	furn.Name = "Perabot"
	local markers = Instance.new("Folder")
	markers.Name = "TitikNPC"

	-- ===== lantai =====
	local floorMat = { kelas = Enum.Material.WoodPlanks, guru = Enum.Material.SmoothPlastic, kepsek = Enum.Material.WoodPlanks }
	local floorCol = { kelas = rgb(205, 160, 108), guru = rgb(150, 176, 208), kepsek = rgb(140, 92, 64) }
	local function tile(x0, z0, x1, z1, color, mat)
		if fl == 1 then
			L.box(shell, "Lantai", x0, fy - 0.5, z0, x1, fy, z1, color, mat)
		else
			L.box(shell, "Lantai", x0, fy - 0.1, z0, x1, fy, z1, color, mat, { CanCollide = false })
		end
	end
	for _, id in ipairs({ "A", "B", "G", "K" }) do
		local r, c = ROOMS[id], cfg[id]
		tile(r.x0 - 0.25, CW, r.x1 + 0.25, ZB, floorCol[c.kind], floorMat[c.kind])
	end
	tile(X0, ZF, ROOMS.B.x1 + 0.25, CW, rgb(236, 232, 222), MARBLE)
	tile(ROOMS.G.x0 - 0.25, ZF, X1, CW, rgb(236, 232, 222), MARBLE)
	tile(-194.25, ZF, -171.75, ZB, rgb(236, 232, 222), MARBLE)
	if fl == 1 then
		-- ceiling / lantai atas (slab) dengan lubang tangga
		local function slab(x0, z0, x1, z1)
			L.box(shell, "LantaiAtas", x0, 11.4, z0, x1, 12.4, z1, CREAM, Enum.Material.SmoothPlastic)
		end
		slab(-252, -78, -194, -44.5)
		slab(-172, -78, -114, -44.5)
		slab(-194, -78, -191, -44.5)
		slab(-175, -78, -172, -44.5)
		slab(-191, -78, -175, -66)
	else
		L.box(shell, "Plafon", -252, 21.8, -78, -114, 22.0, -44.5, CREAM, Enum.Material.SmoothPlastic, { CanCollide = false })
	end

	-- ===== dinding luar =====
	local wallMat = Enum.Material.SmoothPlastic
	local function winX(centers, width)
		local o = {}
		for _, c in ipairs(centers) do
			table.insert(o, { a0 = c - width / 2, a1 = c + width / 2, y0 = fy + 3.0, y1 = fy + 7.6, glass = true })
		end
		return o
	end
	local frontO = winX({ -244, -230, -216, -202, -164, -150, -136, -122 }, 6)
	if fl == 1 then
		table.insert(frontO, { a0 = -188, a1 = -178, y0 = fy, y1 = fy + 8.4 })
	else
		table.insert(frontO, { a0 = -187, a1 = -179, y0 = fy + 3.0, y1 = fy + 7.6, glass = true })
	end
	L.wall(shell, "DindingDepan", "x", -77.75, -252, -114, fy, top, 0.5, CREAM, wallMat, frontO)
	L.wall(shell, "DindingKiri", "z", -251.75, -78, -44.5, fy, top, 0.5, CREAM, wallMat, { { a0 = -61, a1 = -55, y0 = fy + 3.0, y1 = fy + 7.6, glass = true } })
	L.wall(shell, "DindingKanan", "z", -114.25, -78, -44.5, fy, top, 0.5, CREAM, wallMat, { { a0 = -61, a1 = -55, y0 = fy + 3.0, y1 = fy + 7.6, glass = true } })
	-- dinding belakang per ruang (warna aksen) + jendela di kiri-kanan papan
	for _, id in ipairs({ "A", "B", "G", "K" }) do
		local r, c = ROOMS[id], cfg[id]
		L.wall(shell, "DindingBelakang", "x", -44.75, r.x0 - 0.25, r.x1 + 0.25, fy, top, 0.5, c.accent, wallMat, winX({ r.c - 10, r.c + 10 }, 5))
	end
	L.wall(shell, "DindingBelakang", "x", -44.75, -194.25, -171.75, fy, top, 0.5, CREAM, wallMat, {})
	-- sekat ruang
	for _, x in ipairs({ -223, -194, -172, -143.5 }) do
		L.wall(shell, "Sekat", "z", x, CW, ZB, fy, top, 0.5, CREAM, wallMat, {})
	end
	-- dinding koridor dengan pintu ruang
	local doorW, doorH = 4.4, 7.6
	local function doorOpen(c)
		return { a0 = c - doorW / 2, a1 = c + doorW / 2, y0 = fy, y1 = fy + doorH }
	end
	L.wall(shell, "DindingKoridor", "x", CW, -252, -194, fy, top, 0.5, CREAM, wallMat, { doorOpen(ROOMS.A.c), doorOpen(ROOMS.B.c) })
	L.wall(shell, "DindingKoridor", "x", CW, -172, -114, fy, top, 0.5, CREAM, wallMat, { doorOpen(ROOMS.G.c), doorOpen(ROOMS.K.c) })
	for _, id in ipairs({ "A", "B", "G", "K" }) do
		local r, c = ROOMS[id], cfg[id]
		L.door(shell, "Pintu " .. c.label, r.c - doorW / 2, fy, CW, doorW, doorH, 1, -1, "wood", 8)
		L.sign(shell, "Papan " .. c.label, CFrame.new(r.c, fy + 9.0, CW - 0.32) * FACE_NEG_Z, Vector3.new(5.6, 1.3, 0.12), c.label, rgb(250, 250, 245), rgb(40, 70, 130), Enum.Font.FredokaOne)
		L.box(shell, "BingkaiPapan", r.c - 2.9, fy + 8.3, CW - 0.28, r.c + 2.9, fy + 9.7, CW - 0.2, rgb(120, 78, 46), Enum.Material.Wood)
	end

	-- ===== loker koridor =====
	local lockerCols = { rgb(220, 70, 70), rgb(70, 130, 220), rgb(80, 180, 100), rgb(240, 190, 60), rgb(170, 100, 200) }
	local function lockersBetween(a, b)
		local n = math.min(6, math.floor((b - a) / 1.5))
		local start = (a + b) / 2 - (n * 1.5) / 2 + 0.75
		for i = 0, n - 1 do
			L.locker(furn, CFrame.new(start + i * 1.5, fy, CW - 0.25 - 0.6) * FACE_POS_Z, lockerCols[(i % #lockerCols) + 1])
		end
	end
	lockersBetween(-251, ROOMS.A.c - doorW / 2 - 0.6)
	lockersBetween(ROOMS.A.c + doorW / 2 + 0.6, ROOMS.B.c - doorW / 2 - 0.6)
	lockersBetween(ROOMS.B.c + doorW / 2 + 0.6, -195)
	lockersBetween(-171, ROOMS.G.c - doorW / 2 - 0.6)
	lockersBetween(ROOMS.G.c + doorW / 2 + 0.6, ROOMS.K.c - doorW / 2 - 0.6)
	lockersBetween(ROOMS.K.c + doorW / 2 + 0.6, -115)

	-- lampu koridor
	for _, x in ipairs({ -244, -228, -212, -154, -140, -126 }) do
		L.lamp(furn, x, top - 0.2, -74.6, 3.6, 1.4, 0.5)
	end
	L.lamp(furn, -183, top - 0.2, -74.6, 3.6, 1.4, 0.5)

	-- ===== isi ruangan =====
	local function marker(pos, dir, attrs)
		attrs.Lantai = fl
		return L.marker(markers, face(pos, dir), attrs)
	end
	local function student(x, z, seatTopY, g)
		local nm = pickName(g)
		return {
			Nama = nm, Peran = "Murid", Pose = "Duduk", Kelamin = g,
			Kulit = KULIT[rng:NextInteger(1, #KULIT)], Rambut = RAMBUT[rng:NextInteger(1, #RAMBUT)],
			Skala = 0.78, Gaya = if g == "L" then "pendek" else (if rng:NextInteger(1, 2) == 1 then "kucir" else "panjang"),
		}
	end

	local function classroom(id)
		local r, c = ROOMS[id], cfg[id]
		local cx = r.c
		-- papan tulis hijau
		L.box(furn, "BingkaiPapanTulis", cx - 6.4, fy + 3.1, -45.2, cx + 6.4, fy + 7.9, -45.0, rgb(140, 92, 56), Enum.Material.Wood)
		L.sign(furn, "PapanTulis", CFrame.new(cx, fy + 5.5, -45.28) * FACE_NEG_Z, Vector3.new(12, 4.2, 0.12), "Selamat Pagi Anak-anak! 📚\n2 + 3 = 5   ·   A B C D\n" .. c.label, rgb(38, 86, 64), rgb(245, 245, 235), Enum.Font.PatrickHand)
		L.box(furn, "RakKapur", cx - 6, fy + 2.9, -45.7, cx + 6, fy + 3.1, -45.2, rgb(140, 92, 56), Enum.Material.Wood, { CanCollide = false })
		L.box(furn, "Kapur", cx - 2, fy + 3.1, -45.6, cx - 1.4, fy + 3.25, -45.4, rgb(250, 250, 250), Enum.Material.SmoothPlastic, { CanCollide = false })
		-- bendera merah putih di atas papan
		L.box(furn, "BenderaMerah", cx - 2, fy + 8.9, -45.2, cx + 2, fy + 9.6, -45.05, rgb(220, 40, 40), Enum.Material.Fabric, { CanCollide = false })
		L.box(furn, "BenderaPutih", cx - 2, fy + 8.2, -45.2, cx + 2, fy + 8.9, -45.05, rgb(252, 252, 252), Enum.Material.Fabric, { CanCollide = false })
		-- poster di dinding sisi
		local posters = {
			{ "A B C D E\nF G H I J", rgb(255, 230, 120), rgb(180, 60, 60) },
			{ "1 2 3 4 5\n6 7 8 9 10", rgb(170, 220, 255), rgb(40, 70, 130) },
		}
		for i, p in ipairs(posters) do
			local z = ({ -62, -52 })[i]
			L.sign(furn, "Poster", CFrame.new(r.x1 - 0.1, fy + 5.6, z) * FACE_NEG_X, Vector3.new(4.4, 3.2, 0.1), p[1], p[2], p[3], Enum.Font.FredokaOne)
		end
		L.sign(furn, "PosterKiri", CFrame.new(r.x0 + 0.1, fy + 5.6, -57) * FACE_POS_X, Vector3.new(5.6, 3.2, 0.1), "RAJIN BELAJAR\nPANGKAL PANDAI", rgb(255, 205, 220), rgb(150, 50, 90), Enum.Font.FredokaOne)
		-- bangku siswa 4 x 3
		local seatsAll = {}
		for _, rowZ in ipairs({ -63.5, -58.5, -53.5 }) do
			for _, dx in ipairs({ -9.6, -3.2, 3.2, 9.6 }) do
				local x = cx + dx
				L.studentSet(furn, CFrame.new(x, fy, rowZ), rng)
				table.insert(seatsAll, { x = x, z = rowZ - 2.1 })
			end
		end
		-- pilih 8 dari 12 kursi untuk murid
		for i = #seatsAll, 2, -1 do
			local j = rng:NextInteger(1, i)
			seatsAll[i], seatsAll[j] = seatsAll[j], seatsAll[i]
		end
		for i = 1, 8 do
			local s = seatsAll[i]
			local g = if rng:NextInteger(1, 2) == 1 then "L" else "P"
			local a = student(s.x, s.z, fy + 1.66, g)
			a.Ruang = c.label
			marker(Vector3.new(s.x, fy + 1.2, s.z), Vector3.new(0, 0, 1), a)
		end
		-- meja guru + barang
		local dbase = CFrame.new(cx - 8, fy, -49.4) * CFrame.Angles(0, PI, 0)
		L.deskSet(furn, dbase, 5.2, true)
		L.ball(furn, dbase, "Globe", 1.2, Vector3.new(1.6, 3.65, 0.3), rgb(70, 140, 210), Enum.Material.SmoothPlastic)
		L.lp(furn, dbase, "KakiGlobe", Vector3.new(0.2, 0.4, 0.2), Vector3.new(1.6, 3.05, 0.3), rgb(60, 60, 60), Enum.Material.Metal)
		L.ball(furn, dbase, "Apel", 0.45, Vector3.new(-1.2, 3.2, 0.2), rgb(220, 40, 40), Enum.Material.SmoothPlastic)
		L.lp(furn, dbase, "TumpukBuku", Vector3.new(1.4, 0.4, 1.0), CFrame.new(-0.2, 3.2, -0.2) * CFrame.Angles(0, 0.3, 0), rgb(70, 130, 210), Enum.Material.SmoothPlastic)
		-- guru berdiri dekat papan
		marker(Vector3.new(cx + 4, fy, -47.0), Vector3.new(0, 0, -1), {
			Nama = c.guru, Peran = "Guru", Pose = "Berdiri", Kelamin = if c.guru:sub(1, 2) == "Bu" then "P" else "L",
			Kulit = KULIT[rng:NextInteger(1, #KULIT)], Rambut = RAMBUT[rng:NextInteger(1, #RAMBUT)], Skala = 1,
			Gaya = if c.guru:sub(1, 2) == "Bu" then "sanggul" else "pendek", Ruang = c.label,
			Baju = if c.guru:sub(1, 2) == "Bu" then rgb(176, 96, 64) else rgb(60, 110, 170),
		})
		L.bookshelf(furn, CFrame.new(r.x1 - 0.9, fy, -66.5) * FACE_POS_X, 5.5, 6.2, rng)
		L.plant(furn, r.x0 + 1.4, fy, -46.4, 1.0)
		L.lamp(furn, cx - 7, top - 0.2, -58, 3.6, 1.5, 0.5)
		L.lamp(furn, cx + 7, top - 0.2, -58, 3.6, 1.5, 0.5)
	end

	local function staffRoom(id)
		local r, c = ROOMS[id], cfg[id]
		local cx = r.c
		-- 4 meja kerja guru, 3 guru duduk
		local spots = { { cx - 7, -62 }, { cx + 7, -62 }, { cx - 7, -54 }, { cx + 7, -54 } }
		local gurus = { { "Bu Dian", "P", "sanggul", rgb(150, 90, 170) }, { "Pak Slamet", "L", "pendek", rgb(70, 120, 90) }, { "Bu Tuti", "P", "kucir", rgb(210, 120, 60) } }
		for i, s in ipairs(spots) do
			local base = CFrame.new(s[1], fy, s[2])
			L.deskSet(furn, base, 4.8, true, rgb(176, 130, 86))
			L.lp(furn, base, "Laptop", Vector3.new(1.4, 0.1, 1.0), Vector3.new(0, 3.0, 0.1), rgb(60, 64, 70), Enum.Material.Metal, { CanCollide = false })
			L.lp(furn, base, "LayarLaptop", Vector3.new(1.4, 0.9, 0.08), CFrame.new(0, 3.5, 0.55) * CFrame.Angles(-0.25, 0, 0), rgb(90, 160, 220), Enum.Material.Neon, { CanCollide = false })
			L.ball(furn, base, "Cangkir", 0.35, Vector3.new(1.6, 3.15, 0.3), rgb(250, 250, 245), Enum.Material.SmoothPlastic)
			local g = gurus[i]
			if g then
				marker(Vector3.new(s[1], fy + 1.55, s[2] - 2.5), Vector3.new(0, 0, 1), {
					Nama = g[1], Peran = "Guru", Pose = "Duduk", Kelamin = g[2], Kulit = KULIT[rng:NextInteger(1, #KULIT)],
					Rambut = RAMBUT[rng:NextInteger(1, #RAMBUT)], Skala = 1, Gaya = g[3], Baju = g[4], Ruang = c.label,
				})
			end
		end
		-- papan jadwal di dinding belakang
		L.sign(furn, "PapanJadwal", CFrame.new(cx, fy + 5.6, -45.2) * FACE_NEG_Z, Vector3.new(9, 4.2, 0.12), "JADWAL PIKET GURU\nSenin Bu Ani · Selasa Pak Joko\nRabu Bu Dian · Kamis Pak Slamet\nJumat Bu Tuti", rgb(252, 252, 250), rgb(40, 70, 130), Enum.Font.PatrickHand)
		L.box(furn, "BingkaiJadwal", cx - 4.7, fy + 3.3, -45.2, cx + 4.7, fy + 7.9, -45.05, rgb(160, 160, 165), Enum.Material.Metal, { CanCollide = false })
		-- sofa + meja kopi di sisi kanan
		L.sofa(furn, CFrame.new(r.x1 - 1.8, fy, -57) * FACE_POS_X, 6, rgb(90, 130, 170))
		L.box(furn, "MejaKopi", r.x1 - 6.2, fy + 1.2, -58.6, r.x1 - 4.4, fy + 1.45, -55.4, rgb(150, 100, 62), Enum.Material.Wood)
		L.box(furn, "KakiMejaKopi", r.x1 - 5.6, fy, -58.0, r.x1 - 5.0, fy + 1.2, -56.0, rgb(110, 70, 44), Enum.Material.Wood)
		-- lemari arsip di sisi kiri
		for i, z in ipairs({ -66, -62.6, -59.2 }) do
			L.box(furn, "Lemari", r.x0 + 0.3, fy, z - 1.5, r.x0 + 2.1, fy + 5.2, z + 1.5, rgb(150, 160, 170), Enum.Material.Metal)
			L.box(furn, "LemariLaci", r.x0 + 2.1, fy + 1.0, z - 1.3, r.x0 + 2.16, fy + 1.5, z + 1.3, rgb(100, 110, 120), Enum.Material.Metal, { CanCollide = false })
			L.box(furn, "LemariLaci", r.x0 + 2.1, fy + 2.6, z - 1.3, r.x0 + 2.16, fy + 3.1, z + 1.3, rgb(100, 110, 120), Enum.Material.Metal, { CanCollide = false })
		end
		-- dispenser air
		L.box(furn, "Dispenser", r.x0 + 0.5, fy, -47.6, r.x0 + 2.1, fy + 3.6, -46.0, rgb(245, 245, 248), Enum.Material.SmoothPlastic)
		L.box(furn, "GalonAir", r.x0 + 0.7, fy + 3.6, -47.4, r.x0 + 1.9, fy + 5.2, -46.2, rgb(120, 190, 240), Enum.Material.Glass, { Transparency = 0.4, CanCollide = false })
		L.plant(furn, r.x1 - 1.5, fy, -47, 1.1)
		L.lamp(furn, cx - 7, top - 0.2, -58, 3.6, 1.5, 0.5)
		L.lamp(furn, cx + 7, top - 0.2, -58, 3.6, 1.5, 0.5)
	end

	local function principalRoom(id)
		local r, c = ROOMS[id], cfg[id]
		local cx = r.c
		L.box(furn, "Karpet", cx - 5, fy, -60, cx + 5, fy + 0.06, -52, rgb(150, 44, 58), Enum.Material.Fabric, { CanCollide = false })
		local dbase = CFrame.new(cx, fy, -50.3) * CFrame.Angles(0, PI, 0)
		L.deskSet(furn, dbase, 7.2, true, rgb(110, 70, 44))
		L.lp(furn, dbase, "PlakatNama", Vector3.new(2.2, 0.5, 0.15), CFrame.new(0, 3.2, 0.7) * CFrame.Angles(0.3, 0, 0), rgb(220, 190, 90), Enum.Material.Metal, { CanCollide = false })
		L.lp(furn, dbase, "Laptop", Vector3.new(1.4, 0.1, 1.0), Vector3.new(-1.8, 3.0, -0.1), rgb(60, 64, 70), Enum.Material.Metal, { CanCollide = false })
		L.lp(furn, dbase, "LayarLaptop", Vector3.new(1.4, 0.9, 0.08), CFrame.new(-1.8, 3.5, 0.35) * CFrame.Angles(-0.25, 0, 0), rgb(90, 160, 220), Enum.Material.Neon, { CanCollide = false })
		L.lp(furn, dbase, "LampuMeja", Vector3.new(0.5, 1.0, 0.5), Vector3.new(2.6, 3.5, 0.2), rgb(40, 120, 70), Enum.Material.SmoothPlastic, { CanCollide = false })
		-- kepala sekolah duduk menghadap pintu
		marker(Vector3.new(cx, fy + 1.55, -47.8), Vector3.new(0, 0, -1), {
			Nama = "Pak Bambang", Peran = "Kepala Sekolah", Pose = "Duduk", Kelamin = "L", Kulit = KULIT[2], Rambut = rgb(40, 40, 44),
			Skala = 1, Gaya = "pendek", Baju = rgb(196, 170, 120), Ruang = c.label,
		})
		-- kursi tamu
		for _, dx in ipairs({ -2.2, 2.2 }) do
			local kb = CFrame.new(cx + dx, fy, -57) * CFrame.Angles(0, PI, 0)
			L.lp(furn, kb, "DudukanTamu", Vector3.new(2.0, 0.3, 2.0), Vector3.new(0, 1.7, 0), rgb(160, 50, 60), Enum.Material.Fabric)
			L.lp(furn, kb, "SandaranTamu", Vector3.new(2.0, 2.0, 0.25), Vector3.new(0, 2.8, -0.95), rgb(160, 50, 60), Enum.Material.Fabric)
			L.lp(furn, kb, "KakiTamu", Vector3.new(0.3, 1.6, 0.3), Vector3.new(0, 0.8, 0), rgb(60, 60, 64), Enum.Material.Metal, { CanCollide = false })
		end
		-- rak buku di sisi kiri
		L.bookshelf(furn, CFrame.new(r.x0 + 0.9, fy, -64) * FACE_NEG_X, 6, 7, rng)
		L.bookshelf(furn, CFrame.new(r.x0 + 0.9, fy, -57) * FACE_NEG_X, 6, 7, rng)
		-- hiasan dinding belakang: bendera, foto presiden/wapres diganti pigura umum + piagam
		L.box(furn, "BenderaMerah", cx - 3, fy + 8.4, -45.15, cx - 0.5, fy + 9.4, -45.05, rgb(220, 40, 40), Enum.Material.Fabric, { CanCollide = false })
		L.box(furn, "BenderaPutih", cx - 3, fy + 7.4, -45.15, cx - 0.5, fy + 8.4, -45.05, rgb(252, 252, 252), Enum.Material.Fabric, { CanCollide = false })
		L.sign(furn, "Piagam", CFrame.new(cx + 2.5, fy + 8.0, -45.12) * FACE_NEG_Z, Vector3.new(3.6, 2.4, 0.1), "PIAGAM\nSEKOLAH SEHAT\n⭐⭐⭐", rgb(250, 240, 200), rgb(140, 90, 30), Enum.Font.FredokaOne)
		L.sign(furn, "Pigura", CFrame.new(cx + 6.5, fy + 8.0, -45.12) * FACE_NEG_Z, Vector3.new(2.6, 2.4, 0.1), "🏆", rgb(250, 250, 250), rgb(160, 120, 20), Enum.Font.FredokaOne)
		-- sofa + meja kecil
		L.sofa(furn, CFrame.new(r.x1 - 1.6, fy, -64) * FACE_POS_X, 5.5, rgb(70, 90, 120))
		L.plant(furn, r.x1 - 1.4, fy, -47, 1.2)
		L.plant(furn, r.x0 + 1.4, fy, -47, 1.0)
		L.lamp(furn, cx - 5, top - 0.2, -58, 3.6, 1.5, 0.5)
		L.lamp(furn, cx + 5, top - 0.2, -58, 3.6, 1.5, 0.5)
	end

	for _, id in ipairs({ "A", "B", "G", "K" }) do
		local k = cfg[id].kind
		if k == "kelas" then
			classroom(id)
		elseif k == "guru" then
			staffRoom(id)
		else
			principalRoom(id)
		end
	end

	-- ===== lobi =====
	L.lamp(furn, -187, top - 0.2, -66, 3.6, 1.4, 0.5)
	if fl == 1 then
		-- vestibule di bawah serambi
		local vm = Instance.new("Model")
		vm.Name = "Serambi"
		L.box(vm, "LantaiSerambi", -197.6, 0.9, -82.6, -167.4, 1.4, -77.5, rgb(236, 232, 222), MARBLE)
		L.box(vm, "PlafonSerambi", -197.6, 10.0, -82.6, -167.4, 10.3, -77.5, CREAM, Enum.Material.SmoothPlastic, { CanCollide = false })
		L.wall(vm, "DindingSerambiKiri", "z", -197.45, -82.6, -77.5, 1.4, 10.0, 0.3, CREAM, wallMat, {})
		L.wall(vm, "DindingSerambiKanan", "z", -167.55, -82.6, -77.5, 1.4, 10.0, 0.3, CREAM, wallMat, {})
		L.wall(vm, "DindingSerambiDepan", "x", -82.45, -197.6, -167.4, 1.4, 10.0, 0.3, CREAM, wallMat, { { a0 = -187.5, a1 = -178.5, y0 = 1.4, y1 = 9.0 } })
		L.door(vm, "PintuKacaSekolahKiri", -187.5, 1.4, -82.45, 4.5, 7.6, 1, -1, "glass", 11)
		L.door(vm, "PintuKacaSekolahKanan", -178.5, 1.4, -82.45, 4.5, 7.6, -1, -1, "glass", 11)
		L.lamp(vm, -183, 9.9, -80, 3.6, 1.4, 0.5)
		vm.Parent = root
		-- tangga bolak-balik di lobi
		local steps = Instance.new("Model")
		steps.Name = "Tangga"
		local stepCol = rgb(190, 140, 96)
		local rise = 5.55 / 10
		for i = 1, 10 do
			L.box(steps, "Anak Tangga", -191, 0.9, -66 + (i - 1) * 1.4, -187, fy + rise * i, -66 + i * 1.4, stepCol, Enum.Material.WoodPlanks)
		end
		L.box(steps, "Bordes", -191, 0.9, -52, -175, fy + 5.55, -45, stepCol, Enum.Material.WoodPlanks)
		for j = 1, 10 do
			L.box(steps, "Anak Tangga", -179, 0.9, -52 - 1.4 * j, -175, fy + 5.55 + rise * j, -52 - 1.4 * (j - 1), stepCol, Enum.Material.WoodPlanks)
		end
		steps.Parent = root
		-- pagar tangga di lantai atas (lubang x -191..-175, z -66..-45)
		local railCol = rgb(150, 100, 62)
		local function rail(x0, z0, x1, z1)
			L.box(steps, "Pagar", x0, 12.5, z0, x1, 13.7, z1, railCol, Enum.Material.Wood)
			L.box(steps, "PagarAtas", x0 - 0.05, 13.7, z0 - 0.05, x1 + 0.05, 13.85, z1 + 0.05, rgb(100, 64, 38), Enum.Material.Wood)
		end
		rail(-191.2, -66, -190.9, -45)
		rail(-175.1, -66, -174.8, -45)
		rail(-191, -66.2, -179, -65.9)
		-- tanda selamat datang besar di dinding belakang lobi
		L.sign(furn, "TandaLobi", CFrame.new(-183, 17.5, -45.2) * FACE_NEG_Z, Vector3.new(16, 3.6, 0.2), "SELAMAT DATANG\nSEKOLAH ROBLOCK CITY", rgb(40, 100, 180), rgb(255, 255, 255), Enum.Font.FredokaOne)
		L.box(furn, "BingkaiTanda", -191.4, 15.5, -45.1, -174.6, 19.5, -45.0, rgb(255, 205, 60), Enum.Material.SmoothPlastic, { CanCollide = false })
		-- lemari piala di sisi kiri lobi
		L.box(furn, "LemariPiala", -193.6, fy, -70, -191.6, fy + 5.4, -64, rgb(120, 78, 46), Enum.Material.Wood)
		L.box(furn, "KacaPiala", -191.6, fy + 0.8, -69.7, -191.5, fy + 5.0, -64.3, rgb(190, 228, 245), Enum.Material.Glass, { Transparency = 0.55, CanCollide = false })
		for k = 0, 2 do
			L.ball(furn, CFrame.new(-192.6, fy + 1.0 + k * 1.4, -67), "Piala", 0.8, Vector3.new(0, 0.5, 0), rgb(235, 190, 50), Enum.Material.Metal)
		end
		-- papan pengumuman sisi kanan lobi
		L.sign(furn, "Pengumuman", CFrame.new(-172.1, fy + 5.2, -62) * FACE_NEG_X, Vector3.new(6, 3.6, 0.15), "PENGUMUMAN\nPR hari ini dikumpulkan\nbesok ya! ✏️", rgb(255, 245, 180), rgb(120, 60, 30), Enum.Font.PatrickHand)
		-- bangku tunggu + tanaman
		L.sofa(furn, CFrame.new(-173.9, fy, -52) * FACE_POS_X, 5, rgb(220, 120, 60))
		L.plant(furn, -192.6, fy, -47.5, 1.3)
		L.plant(furn, -173.2, fy, -69, 1.3)
		L.plant(furn, -192.6, fy, -73, 1.0)
		-- satpam dan murid di lobi
		marker(Vector3.new(-186.5, fy, -75.5), Vector3.new(0, 0, -1), {
			Nama = "Pak Satpam", Peran = "Satpam", Pose = "Berdiri", Kelamin = "L", Kulit = KULIT[4], Rambut = rgb(24, 20, 20),
			Skala = 1, Gaya = "topi", Baju = rgb(70, 90, 120), Ruang = "Lobi",
		})
		marker(Vector3.new(-176, fy, -74), Vector3.new(-1, 0, 0), {
			Nama = "Rizky", Peran = "Murid", Pose = "Berdiri", Kelamin = "L", Kulit = KULIT[1], Rambut = RAMBUT[1], Skala = 0.78, Gaya = "pendek", Ruang = "Lobi",
		})
		marker(Vector3.new(-178, fy, -74.6), Vector3.new(1, 0, 0), {
			Nama = "Putri", Peran = "Murid", Pose = "Berdiri", Kelamin = "P", Kulit = KULIT[3], Rambut = RAMBUT[2], Skala = 0.78, Gaya = "kucir", Ruang = "Lobi",
		})
		-- pagar halaman: tidak ada; penyekat tabrakan gang samping serambi
	else
		L.sign(furn, "TandaLantai2", CFrame.new(-183, fy + 5.5, -45.2) * FACE_NEG_Z, Vector3.new(10, 2.4, 0.2), "LANTAI 2 · KELAS 2 & 3", rgb(40, 100, 180), rgb(255, 255, 255), Enum.Font.FredokaOne)
		L.plant(furn, -192.6, fy, -47.5, 1.3)
		L.plant(furn, -173.2, fy, -47.5, 1.3)
	end

	shell.Parent = root
	furn.Parent = root
	markers.Parent = root
	return markers
end

return B
