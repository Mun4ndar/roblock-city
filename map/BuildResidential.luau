--[[
	ROBLOCK CITY: perluasan kawasan Perumahan (Workspace.Map.Neighborhoods).
	Mengelilingi kota kecil (Map.Residential, pusat (100, 450)) di dalam jalan lingkar, selatan Downtown.
	- Jalan perumahan 2 lajur dengan trotoar: x = -280 dan x = 580 (utara-selatan), z = 120, 780, 960 (timur-barat).
	- Sekolah dengan lapangan bola, taman bermain, lapangan basket.
	- Rumah keluarga (1-2 lantai, sebagian bergarasi) dan 6 rumah mewah berkolam renang.

	Pakai: require(game.ServerStorage.MapBuilders.BuildResidential)()
]]

local Kit = require(script.Parent.MapKit)
local B = require(script.Parent.Buildings)
local H = require(script.Parent.Homes)
local St = require(script.Parent.Streets)

local W = 28 -- lebar jalan perumahan
local WALK = 6
local HOUSE_OFF = W / 2 + WALK + 8 + 8 -- pusat rumah dari garis tengah jalan
local MANSION_OFF = W / 2 + WALK + 4 + 30

local function street(name, axis, at, from, to)
	return {
		name = name,
		axis = axis,
		at = at,
		from = from,
		to = to,
		w = W,
		lanes = 2,
		zebraFrom = true,
		zebraTo = true,
	}
end

local R1a = street("JalanMelati", "z", -280, -224, 426)
local R1b = street("JalanMelatiSelatan", "z", -280, 474, 1056)
local R2a = street("JalanMawar", "z", 580, -224, 426)
local R2b = street("JalanMawarSelatan", "z", 580, 474, 1056)
local R3w = street("JalanKenanga", "x", 120, -456, 68)
local R3e = street("JalanKenangaTimur", "x", 120, 132, 876)
local R4w = street("JalanAnggrek", "x", 780, -456, 76)
local R4e = street("JalanAnggrekTimur", "x", 780, 124, 876)
local R5w = street("JalanTulip", "x", 960, -456, 76)
local R5e = street("JalanTulipTimur", "x", 960, 124, 876)
local STREETS = { R1a, R1b, R2a, R2b, R3w, R3e, R4w, R4e, R5w, R5e }

local function col(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function buildHouses(zone: Instance)
	local f = Kit.folder("Houses")
	Kit.flush(f, zone)
	local n = 0
	local function row(s, side, from, to, skip)
		for _, spot in St.sideSpots(s, side, HOUSE_OFF, from, to, 55, skip) do
			n += 1
			H.house("Rumah" .. n, spot.pos, spot.yaw, n * 7.13, f, 8)
			if n % 2 == 0 then
				-- pohon di halaman belakang
				local back = -Vector3.new(-math.sin(spot.yaw), 0, -math.cos(spot.yaw))
				Kit.tree(spot.pos + back * 15, 1 + Kit.rnd(n) * 0.3, f, "round", n)
			end
		end
		task.wait()
	end
	local skipR1 = { { -320, -240 } }
	row(R3w, -1, -244, 40)
	row(R3w, 1, -430, -330)
	row(R1a, -1, 190, 390)
	row(R3e, -1, 160, 860, { { 540, 620 } })
	row(R3e, 1, 625, 860)
	row(R4w, -1, -430, 30, skipR1)
	row(R4w, 1, -430, 30, skipR1)
	row(R4e, -1, 160, 530)
	row(R4e, 1, 160, 530)
	row(R4e, 1, 625, 860)
	row(R5w, -1, -430, 30, skipR1)
	row(R5w, 1, -430, 30, skipR1)
	row(R5e, -1, 160, 530)
	row(R5e, 1, 160, 530)

	local lux = Kit.folder("RumahMewah", f)
	local i = 0
	for _, x in { 640, 735, 830 } do
		i += 1
		H.mansion("RumahMewah" .. i, Vector3.new(x, 0, 780 - MANSION_OFF), math.pi, i * 3.7, lux, 4)
		i += 1
		H.mansion("RumahMewah" .. i, Vector3.new(x, 0, 960 + MANSION_OFF), 0, i * 3.7, lux, 4)
		task.wait()
	end
	return n
end

local function buildSchool(zone: Instance)
	local f = Kit.folder("Sekolah")
	B.shop({
		name = "GedungSekolah",
		x = -183,
		z = 175,
		yaw = 0,
		baseY = 0,
		w = 140,
		d = 34,
		h = 22,
		floors = 2,
		color = col(250, 240, 215),
		trim = col(230, 90, 60),
		sign = "SEKOLAH ROBLOCK",
		signColor = col(230, 90, 60),
		doors = { { x = 0, w = 10, h = 7.5, color = Kit.C.glass } },
	}, f)
	B.shop({
		name = "Aula",
		x = -235,
		z = 245,
		yaw = math.pi / 2,
		baseY = 0,
		w = 50,
		d = 40,
		h = 14,
		floors = 1,
		color = col(250, 225, 170),
		trim = col(230, 90, 60),
		sign = "AULA",
		signColor = col(230, 90, 60),
	}, f)

	-- lapangan bola
	local fc = CFrame.new(-165, 0, 330)
	Kit.P({
		Name = "Lapangan",
		Size = Vector3.new(100, 0.2, 64),
		CFrame = fc * CFrame.new(0, 0.1, 0),
		Color = col(95, 175, 75),
		Material = Enum.Material.Grass,
		Parent = f,
	})
	local white = Kit.C.white
	for _, sz in { -1, 1 } do
		Kit.deco({
			Name = "GarisPanjang",
			Size = Vector3.new(96, 0.05, 0.6),
			CFrame = fc * CFrame.new(0, 0.23, sz * 30),
			Color = white,
			Parent = f,
		})
		Kit.deco({
			Name = "GarisGawang",
			Size = Vector3.new(0.6, 0.05, 60),
			CFrame = fc * CFrame.new(sz * 48, 0.23, 0),
			Color = white,
			Parent = f,
		})
		-- gawang
		local g = fc * CFrame.new(sz * 48, 0, 0)
		for _, gz in { -7, 7 } do
			Kit.P({
				Name = "TiangGawang",
				Size = Vector3.new(0.6, 7, 0.6),
				CFrame = g * CFrame.new(0, 3.5, gz),
				Color = white,
				Parent = f,
			})
		end
		Kit.P({
			Name = "MistarGawang",
			Size = Vector3.new(0.6, 0.6, 14.6),
			CFrame = g * CFrame.new(0, 7, 0),
			Color = white,
			Parent = f,
		})
	end
	Kit.deco({
		Name = "GarisTengah",
		Size = Vector3.new(0.6, 0.05, 60),
		CFrame = fc * CFrame.new(0, 0.23, 0),
		Color = white,
		Parent = f,
	})
	Kit.deco({
		Name = "Lingkaran",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 18, 18),
		CFrame = fc * CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = white,
		Parent = f,
	})
	Kit.deco({
		Name = "LingkaranDalam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 16.8, 16.8),
		CFrame = fc * CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(95, 175, 75),
		Parent = f,
	})
	local ball = Kit.P({
		Name = "Bola",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = fc * CFrame.new(0, 1.2, 0),
		Color = white,
		Parent = f,
	})
	ball.Anchored = false -- bola bisa ditendang

	-- tiang bendera merah putih di depan sekolah
	Kit.P({
		Name = "TiangBendera",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(24, 0.6, 0.6),
		CFrame = CFrame.new(-245, 12, 150) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(235, 235, 240),
		Material = Enum.Material.Metal,
		Parent = f,
	})
	Kit.deco({
		Name = "BenderaMerah",
		Size = Vector3.new(0.2, 2, 6),
		CFrame = CFrame.new(-245, 22.5, 153.3),
		Color = col(220, 40, 40),
		Parent = f,
	})
	Kit.deco({
		Name = "BenderaPutih",
		Size = Vector3.new(0.2, 2, 6),
		CFrame = CFrame.new(-245, 20.5, 153.3),
		Color = col(250, 250, 250),
		Parent = f,
	})
	Kit.flush(f, zone)
end

local function buildParks(zone: Instance)
	local f = Kit.folder("Taman")
	H.playground(Vector3.new(440, 0, 290), f)
	for i, p in
		{
			Vector3.new(360, 0, 190),
			Vector3.new(520, 0, 190),
			Vector3.new(350, 0, 390),
			Vector3.new(530, 0, 395),
			Vector3.new(440, 0, 400),
		}
	do
		Kit.tree(p, 1.2, f, "round", i * 11)
	end

	-- lapangan basket
	local bc = CFrame.new(-376, 0, -40)
	Kit.P({
		Name = "LapanganBasket",
		Size = Vector3.new(60, 0.3, 34),
		CFrame = bc * CFrame.new(0, 0.15, 0),
		Color = col(70, 120, 200),
		Parent = f,
	})
	Kit.deco({
		Name = "Area",
		Size = Vector3.new(56, 0.05, 30),
		CFrame = bc * CFrame.new(0, 0.32, 0),
		Color = col(235, 140, 70),
		Parent = f,
	})
	for _, sx in { -1, 1 } do
		local hb = bc * CFrame.new(sx * 29, 0, 0)
		Kit.P({
			Name = "TiangRing",
			Size = Vector3.new(0.6, 11, 0.6),
			CFrame = hb * CFrame.new(sx * 1, 5.5, 0),
			Color = col(60, 60, 65),
			Material = Enum.Material.Metal,
			Parent = f,
		})
		Kit.P({
			Name = "Papan",
			Size = Vector3.new(0.4, 4, 6),
			CFrame = hb * CFrame.new(0, 10.5, 0),
			Color = Kit.C.white,
			Parent = f,
		})
		Kit.deco({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2.4, 2.4),
			CFrame = hb * CFrame.new(-sx * 1.6, 9.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = col(240, 100, 40),
			Parent = f,
		})
	end
	local bola = Kit.P({
		Name = "BolaBasket",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = bc * CFrame.new(0, 1.3, 0),
		Color = col(235, 120, 40),
		Parent = f,
	})
	bola.Anchored = false

	-- taman kecil di selatan kota kecil
	for i = 0, 7 do
		local x = -80 + i * 50
		if math.abs(x - 100) > 30 then
			Kit.tree(
				Vector3.new(x, 0, 680 + (i % 2) * 25),
				1 + Kit.rnd(i) * 0.3,
				f,
				if i % 3 == 0 then "pine" else "round",
				i * 5
			)
		end
	end
	for i, x in { -40, 40, 160, 240 } do
		Kit.bench(CFrame.new(x, 0, 700) * CFrame.Angles(0, if i % 2 == 0 then math.pi else 0, 0), f)
	end
	Kit.flush(f, zone)
end

local function buildStreetProps(zone: Instance)
	local f = Kit.folder("Props")
	local lights = Kit.folder("StreetLights", f)
	Kit.flush(f, zone)
	local crossX = { { -310, -250 }, { 550, 610 } }
	local crossZ = { { 90, 150 }, { 750, 810 }, { 930, 990 } }
	for _, s in STREETS do
		local skip = if s.axis == "x" then crossX else crossZ
		for _, spot in St.sideSpots(s, 1, W / 2 + WALK - 1, s.from + 25, s.to - 25, 75, skip) do
			Kit.streetLight(spot.pos + Vector3.new(0, 0.6, 0), spot.yaw, lights)
		end
		task.wait()
	end
end

return function()
	local zone = Kit.zone("Neighborhoods")
	zone:SetAttribute("Zone", "Residential")
	St.buildGrid(STREETS, zone, { walkWidth = WALK, walkTop = 0.6 })
	buildSchool(zone)
	buildParks(zone)
	local houses = buildHouses(zone)
	buildStreetProps(zone)
	local n = Kit.countParts(zone)
	print(("[BuildResidential] selesai: %d rumah, %d part"):format(houses, n))
	return n
end
