--[[
	ROBLOCK CITY: Downtown City (Workspace.Map.Downtown)
	Area x -456..876, z -1076..-100 (di dalam jalan lingkar, utara Perumahan).
	- Boulevard utara-selatan x = 100 (median berpohon palem) dari jalan lingkar sampai kota kecil.
	- Jalan timur-barat z = -900, -700, -500 (jalan utama 4 lajur), -240 (dengan bundaran di x = 100).
	- Gedung pencakar langit, Menara ROBLOCK, hotel, mal, pusat bisnis, bioskop, SPBU, taman kota.

	Pakai: require(game.ServerStorage.MapBuilders.BuildDowntown)()
]]

local Kit = require(script.Parent.MapKit)
local B = require(script.Parent.Buildings)

local C = Kit.C
local TOP = Kit.ROAD_TOP
local WALK = 1.0
local V2 = Vector2.new

type Street = {
	name: string,
	axis: string,
	at: number,
	from: number,
	to: number,
	w: number,
	lanes: number,
	median: number?,
}

-- axis "x" = membentang timur-barat di z = at; axis "z" = utara-selatan di x = at
local STREETS: { Street } = {
	{ name = "JalanUtara", axis = "x", at = -900, from = -456, to = 876, w = 32, lanes = 2 },
	{ name = "JalanTengah", axis = "x", at = -700, from = -456, to = 876, w = 32, lanes = 2 },
	{ name = "JalanUtama", axis = "x", at = -500, from = -456, to = 876, w = 48, lanes = 4 },
	{ name = "JalanSelatan", axis = "x", at = -240, from = -456, to = 876, w = 32, lanes = 2 },
	{ name = "JalanBarat", axis = "z", at = -200, from = -1076, to = -240, w = 32, lanes = 2 },
	{
		name = "Boulevard",
		axis = "z",
		at = 100,
		from = -1076,
		to = 250,
		w = 64,
		lanes = 4,
		median = 14,
	},
	{ name = "JalanTimur", axis = "z", at = 400, from = -1076, to = -240, w = 32, lanes = 2 },
	{ name = "JalanTimurJauh", axis = "z", at = 650, from = -1076, to = -240, w = 32, lanes = 2 },
}
local RB = V2(100, -240) -- bundaran
local RB_R = 56

-- Pelat trotoar per blok: x0, x1, z0, z1
local BLOCKS = {
	{ -320, -216, -1076, -916 },
	{ -184, 68, -1076, -916 },
	{ 132, 384, -1076, -916 },
	{ 416, 634, -1076, -916 },
	{ 666, 740, -1076, -916 },
	{ -456, -216, -884, -716 },
	{ -184, 68, -884, -716 },
	{ 132, 384, -884, -716 },
	{ 416, 634, -884, -716 },
	{ 666, 876, -884, -716 },
	{ -456, -216, -684, -524 },
	{ -184, 68, -684, -524 },
	{ 132, 384, -684, -524 },
	{ 416, 634, -684, -524 },
	{ 666, 876, -684, -524 },
	{ -456, -216, -476, -256 },
	{ -184, 40, -476, -256 },
	{ 160, 384, -476, -256 },
	{ 416, 634, -476, -256 },
	{ 666, 876, -476, -256 },
}

local S = math.pi -- menghadap selatan (+Z)
local N = 0 -- menghadap utara (-Z)

local function col(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local TOWERS: { B.TowerDef } = {
	{
		name = "ApartemenLaut",
		x = -268,
		z = -996,
		w = 44,
		d = 44,
		h = 96,
		yaw = S,
		color = col(245, 200, 170),
		band = col(255, 255, 255),
	},
	{
		name = "MenaraBiru",
		x = -110,
		z = -1000,
		w = 56,
		d = 56,
		h = 170,
		yaw = S,
		color = col(70, 140, 210),
		band = col(220, 235, 250),
		tiers = { { 1, 0.65 }, { 0.78, 0.25 }, { 0.55, 0.1 } },
		crown = "spire",
	},
	{
		name = "KantorPutih",
		x = 10,
		z = -990,
		w = 48,
		d = 60,
		h = 110,
		yaw = S,
		color = col(235, 240, 245),
		band = col(90, 190, 200),
		stripe = col(90, 190, 200),
	},
	{
		name = "MenaraROBLOCK",
		x = 258,
		z = -996,
		w = 64,
		d = 64,
		h = 260,
		yaw = S,
		shape = "cyl",
		color = col(120, 190, 235),
		band = col(245, 250, 255),
		tiers = { { 1, 0.7 }, { 0.8, 0.2 }, { 0.6, 0.1 } },
		crown = "spire",
		sign = "MENARA ROBLOCK",
		signColor = col(40, 70, 140),
	},
	{
		name = "Hotel",
		x = 525,
		z = -996,
		w = 90,
		d = 50,
		h = 130,
		yaw = S,
		color = col(250, 236, 210),
		band = col(235, 120, 100),
		crown = "neon",
		crownColor = col(255, 120, 160),
		sign = "HOTEL",
		signColor = col(235, 90, 110),
	},
	{
		name = "ApartemenUjung",
		x = 703,
		z = -996,
		w = 50,
		d = 56,
		h = 70,
		yaw = S,
		color = col(190, 225, 200),
		band = col(255, 255, 255),
	},

	{
		name = "ApartemenBata",
		x = -390,
		z = -800,
		w = 60,
		d = 60,
		h = 60,
		yaw = S,
		color = col(190, 95, 80),
		band = col(240, 230, 220),
		bandEvery = 10,
	},
	{
		name = "ApartemenMint",
		x = -275,
		z = -800,
		w = 56,
		d = 70,
		h = 85,
		yaw = S,
		color = col(170, 230, 210),
		band = col(255, 255, 255),
	},
	{
		name = "KantorGelap",
		x = -110,
		z = -800,
		w = 70,
		d = 70,
		h = 120,
		yaw = S,
		color = col(55, 75, 100),
		band = col(140, 160, 180),
		tiers = { { 1, 0.75 }, { 0.7, 0.25 } },
		crown = "helipad",
	},
	{
		name = "KantorTerang",
		x = 10,
		z = -800,
		w = 50,
		d = 60,
		h = 80,
		yaw = S,
		color = col(220, 225, 230),
		band = col(250, 170, 60),
	},
	{
		name = "MenaraKembarA",
		x = 200,
		z = -800,
		w = 52,
		d = 52,
		h = 185,
		yaw = S,
		color = col(180, 190, 205),
		band = col(245, 245, 250),
		tiers = { { 1, 0.85 }, { 0.75, 0.15 } },
		crown = "spire",
	},
	{
		name = "MenaraKembarB",
		x = 320,
		z = -800,
		w = 52,
		d = 52,
		h = 185,
		yaw = S,
		color = col(180, 190, 205),
		band = col(245, 245, 250),
		tiers = { { 1, 0.85 }, { 0.75, 0.15 } },
		crown = "spire",
	},
	{
		name = "KantorToska",
		x = 480,
		z = -800,
		w = 64,
		d = 64,
		h = 105,
		yaw = S,
		color = col(70, 190, 190),
		band = col(240, 250, 250),
		crown = "neon",
		crownColor = col(120, 255, 230),
	},
	{
		name = "KantorKecil",
		x = 580,
		z = -800,
		w = 44,
		d = 60,
		h = 60,
		yaw = S,
		color = col(240, 215, 140),
		band = col(255, 255, 255),
	},
	{
		name = "ApartemenKuning",
		x = 720,
		z = -800,
		w = 60,
		d = 70,
		h = 75,
		yaw = S,
		color = col(250, 220, 110),
		band = col(255, 255, 255),
	},
	{
		name = "ApartemenPink",
		x = 820,
		z = -800,
		w = 50,
		d = 70,
		h = 55,
		yaw = S,
		color = col(245, 175, 200),
		band = col(255, 255, 255),
	},

	{
		name = "ApartemenTaman",
		x = -262,
		z = -604,
		w = 50,
		d = 60,
		h = 65,
		yaw = S,
		color = col(200, 180, 240),
		band = col(255, 255, 255),
	},
	{
		name = "MenaraToska",
		x = -100,
		z = -604,
		w = 60,
		d = 60,
		h = 145,
		yaw = S,
		color = col(60, 160, 180),
		band = col(220, 245, 250),
		crown = "helipad",
		stripe = col(250, 250, 255),
	},
	{
		name = "MenaraBisnis",
		x = 258,
		z = -604,
		w = 70,
		d = 70,
		h = 110,
		yaw = S,
		baseY = 20,
		lobby = false,
		color = col(90, 120, 170),
		band = col(230, 240, 250),
		crown = "spire",
	},

	{
		name = "ApartemenSelatan",
		x = -262,
		z = -380,
		w = 56,
		d = 80,
		h = 70,
		yaw = N,
		color = col(240, 190, 150),
		band = col(255, 255, 255),
	},
	{
		name = "KantorPusat",
		x = -72,
		z = -366,
		w = 80,
		d = 80,
		h = 95,
		yaw = N,
		color = col(100, 150, 220),
		band = col(255, 255, 255),
		tiers = { { 1, 0.7 }, { 0.75, 0.3 } },
	},
	{
		name = "ApartemenHijau",
		x = 470,
		z = -366,
		w = 60,
		d = 60,
		h = 80,
		yaw = N,
		color = col(160, 210, 120),
		band = col(255, 255, 255),
	},
	{
		name = "ApartemenKrem",
		x = 580,
		z = -366,
		w = 50,
		d = 60,
		h = 55,
		yaw = N,
		color = col(240, 230, 200),
		band = col(200, 120, 90),
	},
}

local SHOPS: { B.ShopDef } = {
	{
		name = "Bioskop",
		x = -380,
		z = -604,
		yaw = S,
		w = 90,
		d = 60,
		h = 22,
		floors = 1,
		color = col(120, 70, 160),
		trim = col(250, 210, 80),
		sign = "BIOSKOP",
		signColor = col(250, 210, 80),
		signText = col(90, 40, 120),
		doors = {
			{ x = -12, w = 8, h = 7, color = C.glass },
			{ x = 12, w = 8, h = 7, color = C.glass },
		},
	},
	{
		name = "KafeKota",
		x = 20,
		z = -572,
		yaw = S,
		w = 34,
		d = 26,
		h = 12,
		floors = 1,
		color = col(250, 245, 235),
		trim = col(60, 160, 120),
		sign = "KAFE KOTA",
		signColor = col(60, 160, 120),
		storefront = true,
		awning = col(60, 160, 120),
	},
	{
		name = "PusatBisnis",
		x = 258,
		z = -604,
		yaw = S,
		w = 200,
		d = 110,
		h = 18,
		floors = 2,
		color = col(225, 230, 238),
		trim = col(90, 120, 170),
		sign = "PUSAT BISNIS",
		signColor = col(90, 120, 170),
		storefront = true,
		doors = { { x = 0, w = 12, h = 7, color = C.glass } },
	},
	{
		name = "ROBLOCKMall",
		x = 525,
		z = -604,
		yaw = S,
		w = 190,
		d = 120,
		h = 26,
		floors = 2,
		color = col(250, 250, 252),
		trim = col(255, 140, 80),
		sign = "ROBLOCK MALL",
		signColor = col(255, 140, 80),
		storefront = true,
		awning = col(255, 190, 70),
		doors = {
			{ x = -40, w = 10, h = 8, color = C.glass },
			{ x = 0, w = 14, h = 9, color = C.glass },
			{ x = 40, w = 10, h = 8, color = C.glass },
		},
	},
	{
		name = "KantorPos",
		x = -380,
		z = -366,
		yaw = N,
		w = 70,
		d = 50,
		h = 16,
		floors = 2,
		color = col(250, 150, 60),
		trim = col(255, 255, 255),
		sign = "KANTOR POS",
		signColor = col(255, 255, 255),
		signText = col(230, 110, 30),
		storefront = true,
	},
	{
		name = "Perpustakaan",
		x = 272,
		z = -366,
		yaw = N,
		w = 120,
		d = 70,
		h = 18,
		floors = 2,
		color = col(235, 225, 205),
		trim = col(140, 90, 60),
		material = Enum.Material.Brick,
		sign = "PERPUSTAKAAN",
		signColor = col(140, 90, 60),
		doors = { { x = 0, w = 10, h = 7 } },
	},
}

--------------------------------------------------------------------------

local function streetCF(s: Street, along: number): CFrame
	if s.axis == "x" then
		return CFrame.new(along, TOP / 2, s.at) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return CFrame.new(s.at, TOP / 2, along)
end

local function buildSegment(
	s: Street,
	a: number,
	b: number,
	interA: boolean,
	interB: boolean,
	roads: Instance,
	marks: Instance,
	medians: Instance
)
	local len = b - a
	if len <= 1 then
		return
	end
	local cf = streetCF(s, (a + b) / 2)
	local w = s.w
	Kit.P({
		Name = s.name,
		Size = Vector3.new(w, TOP, len),
		CFrame = cf,
		Color = C.asphalt,
		Material = Enum.Material.Asphalt,
		Parent = roads,
	})
	local my = TOP / 2 + 0.025
	local function line(x: number, l: number, zc: number, thick: number, color: Color3)
		Kit.deco({
			Name = "Line",
			Size = Vector3.new(thick, 0.05, l),
			CFrame = cf * CFrame.new(x, my, zc),
			Color = color,
			Parent = marks,
		})
	end
	for _, sd in { -1, 1 } do
		line(sd * (w / 2 - 1.5), len, 0, 0.5, C.white)
	end
	local z0 = -len / 2 + (if interA then 10 else 2)
	local z1 = len / 2 - (if interB then 10 else 2)
	local function dashes(x: number, color: Color3)
		local t = z0
		while t + 8 <= z1 do
			line(x, 8, t + 4, 0.5, color)
			t += 24
		end
	end
	local m = s.median
	if m then
		Kit.P({
			Name = "Median",
			Size = Vector3.new(m, 0.7, len - 2),
			CFrame = cf * CFrame.new(0, TOP / 2 + 0.35, 0),
			Color = C.walk,
			Material = Enum.Material.Concrete,
			Parent = medians,
		})
		Kit.deco({
			Name = "MedianGrass",
			Size = Vector3.new(m - 1.5, 0.1, len - 3.5),
			CFrame = cf * CFrame.new(0, TOP / 2 + 0.75, 0),
			Color = C.grass,
			Material = Enum.Material.Grass,
			Parent = medians,
		})
		local lane = m / 2 + (w / 2 - m / 2) / 2
		dashes(-lane, C.white)
		dashes(lane, C.white)
	elseif s.lanes >= 4 then
		line(-0.5, len, 0, 0.35, C.yellow)
		line(0.5, len, 0, 0.35, C.yellow)
		dashes(-w / 4, C.white)
		dashes(w / 4, C.white)
	else
		dashes(0, C.yellow)
	end
	-- zebra cross
	for _, e in { { interA, -len / 2 + 4 }, { interB, len / 2 - 4 } } do
		if e[1] then
			local x = -w / 2 + 4
			while x <= w / 2 - 4 do
				if not m or math.abs(x) > m / 2 + 1 then
					line(x, 6, e[2], 2.5, C.white)
				end
				x += 5
			end
		end
	end
end

local function buildRoads(zone: Instance)
	local f = Kit.folder("Roads")
	local roads = Kit.folder("Segments", f)
	local marks = Kit.folder("Markings", f)
	local medians = Kit.folder("Medians", f)
	local inters = Kit.folder("Intersections", f)

	-- cari persimpangan
	local cuts: { [Street]: { { number } } } = {}
	for _, s in STREETS do
		cuts[s] = {}
	end
	for _, sx in STREETS do
		if sx.axis == "x" then
			for _, sz in STREETS do
				if
					sz.axis == "z"
					and sz.at >= sx.from
					and sz.at <= sx.to
					and sx.at >= sz.from
					and sx.at <= sz.to
				then
					local p = V2(sz.at, sx.at)
					local isRB = (p - RB).Magnitude < 1
					local hx = if isRB then RB_R - 6 else sz.w / 2
					local hz = if isRB then RB_R - 6 else sx.w / 2
					table.insert(cuts[sx], { sz.at - hx, sz.at + hx, if isRB then 0 else 1 })
					table.insert(cuts[sz], { sx.at - hz, sx.at + hz, if isRB then 0 else 1 })
					if not isRB then
						Kit.P({
							Name = "Simpang",
							Size = Vector3.new(sz.w, TOP, sx.w),
							CFrame = CFrame.new(p.X, TOP / 2, p.Y),
							Color = C.asphalt,
							Material = Enum.Material.Asphalt,
							Parent = inters,
						})
					end
				end
			end
		end
	end

	for _, s in STREETS do
		local list = cuts[s]
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		local pos = s.from
		local prevInter = false
		for _, c in list do
			buildSegment(s, pos, c[1], prevInter, c[3] == 1, roads, marks, medians)
			pos = c[2]
			prevInter = c[3] == 1
		end
		buildSegment(s, pos, s.to, prevInter, false, roads, marks, medians)
	end

	-- Bundaran dengan monumen
	local rb = Kit.folder("Bundaran", f)
	Kit.P({
		Name = "Asphalt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(TOP, RB_R * 2, RB_R * 2),
		CFrame = CFrame.new(RB.X, TOP / 2, RB.Y) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.asphalt,
		Material = Enum.Material.Asphalt,
		Parent = rb,
	})
	Kit.deco({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, RB_R * 2 - 3, RB_R * 2 - 3),
		CFrame = CFrame.new(RB.X, TOP + 0.02, RB.Y) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.white,
		Parent = rb,
	})
	Kit.P({
		Name = "RingFill",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, RB_R * 2 - 4, RB_R * 2 - 4),
		CFrame = CFrame.new(RB.X, TOP + 0.04, RB.Y) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.asphalt,
		Material = Enum.Material.Asphalt,
		CanCollide = false,
		Parent = rb,
	})
	Kit.P({
		Name = "Curb",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 50, 50),
		CFrame = CFrame.new(RB.X, 0.6, RB.Y) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.walk,
		Material = Enum.Material.Concrete,
		Parent = rb,
	})
	Kit.P({
		Name = "Lawn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 47, 47),
		CFrame = CFrame.new(RB.X, 1.25, RB.Y) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.grass,
		Material = Enum.Material.Grass,
		Parent = rb,
	})
	local ped = Kit.P({
		Name = "Pedestal",
		Size = Vector3.new(14, 8, 14),
		Position = Vector3.new(RB.X, 5.2, RB.Y),
		Color = col(235, 235, 240),
		Material = Enum.Material.Marble,
		Parent = rb,
	})
	Kit.sign(ped, "ROBLOCK CITY", col(40, 70, 140), Enum.NormalId.Back)
	Kit.sign(ped, "ROBLOCK CITY", col(40, 70, 140), Enum.NormalId.Front)
	Kit.P({
		Name = "Globe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 12,
		Position = Vector3.new(RB.X, 15.2, RB.Y),
		Color = col(70, 160, 230),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Parent = rb,
	})
	Kit.deco({
		Name = "GlobeRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 16, 16),
		CFrame = CFrame.new(RB.X, 15.2, RB.Y) * CFrame.Angles(0.4, 0, math.pi / 2 + 0.3),
		Color = col(250, 200, 60),
		Material = Enum.Material.Neon,
		Parent = rb,
	})
	for i = 0, 5 do
		local a = i * math.pi / 3
		Kit.deco({
			Name = "Flowers",
			Size = Vector3.new(6, 0.8, 6),
			Position = Vector3.new(RB.X + math.cos(a) * 17, 1.6, RB.Y + math.sin(a) * 17),
			Color = ({ col(240, 90, 120), col(250, 210, 60), col(170, 110, 230) })[i % 3 + 1],
			Material = Enum.Material.Grass,
			Parent = rb,
		})
	end

	Kit.flush(f, zone)
end

local function buildSidewalks(zone: Instance)
	local f = Kit.folder("Sidewalks")
	for i, b in BLOCKS do
		Kit.P({
			Name = "Blok" .. i,
			Size = Vector3.new(b[2] - b[1], WALK, b[4] - b[3]),
			Position = Vector3.new((b[1] + b[2]) / 2, WALK / 2, (b[3] + b[4]) / 2),
			Color = C.walk,
			Material = Enum.Material.Concrete,
			Parent = f,
		})
	end
	Kit.flush(f, zone)
end

local function buildBuildings(zone: Instance)
	local f = Kit.folder("Buildings")
	Kit.flush(f, zone)
	for i, def in SHOPS do
		B.shop(def, f)
		if i % 3 == 0 then
			task.wait()
		end
	end
	for i, def in TOWERS do
		B.tower(def, f)
		if i % 3 == 0 then
			task.wait()
		end
	end
	-- jembatan langit antar menara kembar
	Kit.P({
		Name = "JembatanLangit",
		Size = Vector3.new(70, 6, 12),
		Position = Vector3.new(260, 121, -800),
		Color = col(200, 225, 245),
		Reflectance = 0.25,
		Parent = f,
	})
	-- atap mal: papan nama besar & taman atap
	Kit.deco({
		Name = "MallRoofGarden",
		Size = Vector3.new(120, 0.4, 60),
		Position = Vector3.new(525, 28.2, -615),
		Color = C.grass,
		Material = Enum.Material.Grass,
		Parent = f,
	})

	-- Parkir umum & SPBU
	B.parkingLot("ParkirUmum", CFrame.new(771, WALK, -604), 190, 140, f)
	local spbu = Kit.model("SPBU", f)
	local sc = CFrame.new(771, WALK, -366)
	Kit.P({
		Name = "Apron",
		Size = Vector3.new(190, 0.3, 200),
		CFrame = sc * CFrame.new(0, 0.15, 0),
		Color = col(90, 92, 98),
		Material = Enum.Material.Concrete,
		Parent = spbu,
	})
	Kit.P({
		Name = "Canopy",
		Size = Vector3.new(70, 2, 40),
		CFrame = sc * CFrame.new(0, 14, -20),
		Color = col(240, 240, 245),
		Parent = spbu,
	})
	Kit.deco({
		Name = "CanopyStripe",
		Size = Vector3.new(70.4, 1, 40.4),
		CFrame = sc * CFrame.new(0, 13.5, -20),
		Color = col(220, 50, 50),
		Parent = spbu,
	})
	for _, px in { -28, 28 } do
		for _, pz in { -34, -6 } do
			Kit.P({
				Name = "Pillar",
				Size = Vector3.new(1.5, 13, 1.5),
				CFrame = sc * CFrame.new(px, 6.5, pz),
				Color = col(220, 220, 225),
				Parent = spbu,
			})
		end
	end
	for _, px in { -14, 14 } do
		Kit.P({
			Name = "PumpIsland",
			Size = Vector3.new(4, 0.8, 16),
			CFrame = sc * CFrame.new(px, 0.7, -20),
			Color = C.walk,
			Material = Enum.Material.Concrete,
			Parent = spbu,
		})
		Kit.P({
			Name = "Pump",
			Size = Vector3.new(2.4, 5, 3),
			CFrame = sc * CFrame.new(px, 3.6, -20),
			Color = col(220, 50, 50),
			Parent = spbu,
		})
	end
	B.shop(
		{
			name = "TokoSPBU",
			x = 771,
			z = -310,
			yaw = N,
			w = 40,
			d = 24,
			h = 12,
			floors = 1,
			color = col(250, 250, 250),
			trim = col(220, 50, 50),
			sign = "SPBU",
			signColor = col(220, 50, 50),
			storefront = true,
		},
		spbu
	)
	local pylon = Kit.P({
		Name = "SignPylon",
		Size = Vector3.new(8, 20, 1.5),
		CFrame = sc * CFrame.new(-80, 10, -90),
		Color = col(220, 50, 50),
		Parent = spbu,
	})
	Kit.sign(pylon, "SPBU", col(255, 255, 255))
end

local function buildProps(zone: Instance)
	local f = Kit.folder("Props")
	local trees = Kit.folder("Trees", f)
	local lights = Kit.folder("StreetLights", f)
	local signals = Kit.folder("TrafficLights", f)
	local park = Kit.folder("TamanKota", f)
	Kit.flush(f, zone)

	local crossZ = { -900, -700, -500, -240 }
	local function nearCross(z: number, pad: number): boolean
		for _, c in crossZ do
			if math.abs(z - c) < pad then
				return true
			end
		end
		return false
	end

	-- palem di median boulevard + lampu di kedua sisinya
	local z = -1056
	while z <= 240 do
		if not nearCross(z, 40) and math.abs(z - RB.Y) > RB_R + 10 then
			Kit.tree(Vector3.new(100, TOP + 0.8, z), 1.1, trees, "palm", z)
		end
		z += 40
	end
	z = -1050
	while z <= 240 do
		if not nearCross(z, 30) and math.abs(z - RB.Y) > RB_R + 6 then
			local y = if z < -256 then WALK else 0
			Kit.streetLight(Vector3.new(100 - 36, y, z), -math.pi / 2, lights)
			Kit.streetLight(Vector3.new(100 + 36, y, z + 30), math.pi / 2, lights)
		end
		z += 60
	end
	task.wait()

	-- pohon di trotoar jalan utama
	local x = -440
	while x <= 860 do
		local nearNS = false
		for _, nx in { -200, 100, 400, 650 } do
			if math.abs(x - nx) < 45 then
				nearNS = true
			end
		end
		if not nearNS then
			Kit.tree(Vector3.new(x, WALK, -500 - 27), 0.9, trees, "round", x)
			Kit.tree(Vector3.new(x + 25, WALK, -500 + 27), 0.9, trees, "round", x + 1)
		end
		x += 55
	end
	task.wait()

	-- lampu lalu lintas di persimpangan boulevard
	for _, cz in { -900, -700, -500 } do
		local hz = if cz == -500 then 24 else 16
		B.trafficLight(Vector3.new(100 - 35, WALK, cz - hz - 3), -math.pi / 2, signals, 20)
		B.trafficLight(Vector3.new(100 + 35, WALK, cz + hz + 3), math.pi / 2, signals, 20)
	end

	-- Taman Kota: jalur rumput antara Downtown dan Perumahan (z -224..-100)
	for i = 0, 25 do
		local px = -430 + i * 50
		if math.abs(px - 100) > 50 then
			Kit.tree(
				Vector3.new(px, 0, -200 + Kit.rnd(i) * 20),
				1 + Kit.rnd(i + 9) * 0.3,
				park,
				if i % 3 == 0 then "pine" else "round",
				i
			)
			Kit.tree(
				Vector3.new(px + 20, 0, -130 + Kit.rnd(i + 4) * 20),
				1 + Kit.rnd(i + 3) * 0.3,
				park,
				"round",
				i + 40
			)
		end
	end
	for i, bx in { -300, -150, 260, 400, 560, 720 } do
		Kit.bench(
			CFrame.new(bx, 0, -165) * CFrame.Angles(0, if i % 2 == 0 then 0 else math.pi, 0),
			park
		)
	end
	B.fountain(Vector3.new(-120, 0, -165), 10, park)
	B.fountain(Vector3.new(330, 0, -165), 10, park)
	-- papan selamat datang menghadap selatan (ke Perumahan)
	local welcome = Kit.model("PapanSelamatDatang", park)
	for _, px in { -14, 14 } do
		Kit.P({
			Name = "Post",
			Size = Vector3.new(1.5, 10, 1.5),
			Position = Vector3.new(20 + px, 5, -150),
			Color = col(235, 235, 240),
			Parent = welcome,
		})
	end
	local board = Kit.P({
		Name = "Board",
		Size = Vector3.new(34, 8, 1),
		Position = Vector3.new(20, 12, -150),
		Color = col(40, 70, 140),
		Parent = welcome,
	})
	Kit.sign(board, "Selamat Datang di DOWNTOWN", col(255, 255, 255), Enum.NormalId.Back)
end

return function()
	local zone = Kit.zone("Downtown")
	zone:SetAttribute("Zone", "Downtown")
	buildRoads(zone)
	buildSidewalks(zone)
	buildBuildings(zone)
	buildProps(zone)
	local n = Kit.countParts(zone)
	print(("[BuildDowntown] selesai: %d part"):format(n))
	return n
end
