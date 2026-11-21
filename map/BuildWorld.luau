--[[
	ROBLOCK CITY: pembangun dunia dasar.
	- Terrain: laut, pulau utama (~2600 x 2500 stud), pegunungan barat laut, bukit Countryside,
	  dan Beach Island di timur.
	- Workspace.Map.Highway: jalan lingkar 4 lajur, jalan penghubung ke tiap kawasan, jembatan.
	- Pencahayaan.

	Peta kawasan (utara = -Z):
	  Downtown     x -400..800,  z -1000..-200
	  Perumahan    x -400..800,  z -100..1000 (kota kecil di tengahnya, pusat (100, 450))
	  Countryside  x -1450..-550, z -1150..350 (gunung di barat laut)
	  Bandara      x -1450..-600, z 450..1150
	  Beach Island pusat (1750, 100), dihubungkan jembatan di z = 0

	Pakai (Studio, mode Edit): require(game.ServerStorage.MapBuilders.BuildWorld)()
	Peringatan: Terrain dihapus dan dibangun ulang.
]]

local Kit = require(script.Parent.MapKit)
local StyleWorld = require(script.Parent.StyleWorld)

local M = Enum.Material

-- Bentuk pulau: persegi (x0, z0, x1, z1) dan piringan (x, z, r)
local MAIN_RECTS = {
	{ -1350, -1250, 950, 1250 },
	{ -1500, -1100, 1100, 1100 },
}
local MAIN_DISCS = {
	{ -1350, -1100, 150 },
	{ 950, -1100, 150 },
	{ 950, 1100, 150 },
	{ -1350, 1100, 150 },
	{ -1500, 250, 200 },
	{ -250, 1250, 170 },
	{ 650, -1250, 150 },
	{ 1100, 650, 170 },
	{ -1100, 1250, 160 },
	{ 300, 1260, 140 },
	{ -700, -1250, 150 },
}
local BEACH_SAND = { { 1760, 100, 420 }, { 1800, -260, 330 }, { 1740, 450, 320 } }
local BEACH_GRASS = { { 1680, 90, 250 }, { 1700, -230, 180 }, { 1660, 420, 170 } }

-- Gunung bertingkat (gaya low-poly): x, z, jari-jari, tinggi
local MOUNTAINS = {
	{ -1150, -950, 330, 300 },
	{ -850, -1080, 230, 210 },
	{ -1380, -640, 210, 170 },
	{ -1330, -1150, 200, 190 },
	{ -950, -700, 170, 110 },
}
-- Bukit landai Countryside: x, z, jari-jari, tinggi puncak
local HILLS = {
	{ -1200, -300, 160, 40 },
	{ -1000, 120, 130, 30 },
	{ -1380, 20, 170, 45 },
	{ -800, -470, 110, 28 },
}

-- Catatan: permukaan terrain tampil sekitar 2 stud di atas batas isinya, jadi rumput diisi
-- sampai y = -2 supaya permukaannya pas di y = 0 (sejajar jalan dan trotoar part).
local function fillShapes(T: Terrain, rects, discs, grow: number, yTop: number, mat: Enum.Material)
	local yBot = -18
	local h = yTop - yBot
	local cy = (yTop + yBot) / 2
	for _, r in rects do
		local x0, z0, x1, z1 = r[1] - grow, r[2] - grow, r[3] + grow, r[4] + grow
		T:FillBlock(
			CFrame.new((x0 + x1) / 2, cy, (z0 + z1) / 2),
			Vector3.new(x1 - x0, h, z1 - z0),
			mat
		)
		task.wait()
	end
	-- piringan digambar sebagai jalur-jalur blok 8 stud (FillCylinder membulatkan tinggi ke grid 4 stud)
	for _, d in discs do
		local x, z, r = d[1], d[2], d[3] + grow
		for dz = -r + 4, r - 4, 8 do
			local half = math.sqrt(r * r - dz * dz)
			T:FillBlock(CFrame.new(x, cy, z + dz), Vector3.new(half * 2, h, 8), mat)
		end
	end
	task.wait()
end

local function buildTerrain()
	local T = workspace.Terrain
	T:Clear()
	T:SetMaterialColor(M.Grass, Color3.fromRGB(112, 178, 78))
	T:SetMaterialColor(M.Sand, Color3.fromRGB(240, 222, 170))
	T:SetMaterialColor(M.Rock, Color3.fromRGB(150, 140, 160))
	T:SetMaterialColor(M.Ground, Color3.fromRGB(140, 110, 80))
	T:SetMaterialColor(M.Snow, Color3.fromRGB(245, 248, 255))
	T.WaterColor = Color3.fromRGB(40, 175, 205)
	T.WaterTransparency = 0.45
	T.WaterReflectance = 0.35
	T.WaterWaveSize = 0.08
	T.WaterWaveSpeed = 6
	-- rumput 3D terrain menembus jalan/parkir yang tipis, dan berat untuk HP
	T.Decoration = false

	-- Laut + dasar pasir, dibagi per lajur supaya Studio tidak macet
	local W, D = 5600, 4800
	for i = 0, 3 do
		local x = -W / 2 + W / 8 + i * W / 4
		T:FillBlock(CFrame.new(x, -20, 0), Vector3.new(W / 4, 4, D), M.Sand)
		T:FillBlock(CFrame.new(x, -10, 0), Vector3.new(W / 4, 16, D), M.Water)
		task.wait()
	end

	-- Pulau utama: pantai pasir dulu (lebih lebar, sedikit lebih rendah), lalu rumput
	fillShapes(T, MAIN_RECTS, MAIN_DISCS, 60, -2, M.Sand)
	fillShapes(T, MAIN_RECTS, MAIN_DISCS, 0, -2, M.Grass)
	-- Beach Island
	fillShapes(T, {}, BEACH_SAND, 0, -2, M.Sand)
	fillShapes(T, {}, BEACH_GRASS, 0, -2, M.Grass)

	-- Pegunungan bertingkat
	for _, g in MOUNTAINS do
		local x, z, r, h = g[1], g[2], g[3], g[4]
		local layers = math.floor(h / 16)
		for i = 0, layers - 1 do
			local t = i / layers
			local rad = r * (1 - t) ^ 0.85
			local jitter = Vector3.new((Kit.rnd(x + i) - 0.5) * 24, 0, (Kit.rnd(z + i) - 0.5) * 24)
			local mat = if t < 0.3 then M.Grass elseif h >= 250 and t > 0.8 then M.Snow else M.Rock
			T:FillCylinder(
				CFrame.new(Vector3.new(x, i * 16 + 8, z) + jitter),
				16,
				math.max(rad, 12),
				mat
			)
		end
		task.wait()
	end

	-- Bukit landai
	for _, hl in HILLS do
		local x, z, r, top = hl[1], hl[2], hl[3], hl[4]
		-- bola besar yang sebagian besar terbenam: tinggi tutup = top
		local R = (r * r + top * top) / (2 * top)
		T:FillBall(Vector3.new(x, top - 2 - R, z), R, M.Grass)
		task.wait()
	end
end

local function buildHighway()
	local zone = Kit.zone("Highway")

	-- 16 ruas per tikungan supaya lengkungnya mulus (6 ruas terlihat patah-patah).
	local ring = Kit.roundedRect(-480, -1100, 900, 1080, 160, 16)
	local f = Kit.folder("RingRoad")
	Kit.road(ring, { width = 48, lanes = 4, closed = true, parent = f, name = "JalanLingkar" })
	Kit.flush(f, zone)

	local spokes = Kit.folder("Connectors")
	local V = Vector2.new
	local routes = {
		{ "KeSelatan", { V(100, 650), V(100, 1056) } },
		{ "KeBarat", { V(-100, 450), V(-456, 450) } },
		{ "KeTimur", { V(300, 450), V(876, 450) } },
		{ "KeBeachIsland", { V(924, 0), V(1560, 0) } },
		{ "KeBandara", { V(-504, 850), V(-700, 850) } },
		{ "KeCountryside", { V(-504, -250), V(-650, -262), V(-800, -300), V(-950, -262) } },
	}
	for _, r in routes do
		Kit.road(r[2], { width = 48, lanes = 4, parent = spokes, name = r[1] })
	end
	Kit.flush(spokes, zone)

	-- Jembatan ke Beach Island: pagar dan tiang di atas air
	local bridge = Kit.folder("Bridge")
	local x0, x1 = 1110, 1380
	for _, s in { -1, 1 } do
		Kit.P({
			Name = "Railing",
			Size = Vector3.new(x1 - x0, 1, 1),
			Position = Vector3.new((x0 + x1) / 2, 3.4, s * 24.5),
			Color = Color3.fromRGB(235, 235, 240),
			Parent = bridge,
		})
		Kit.P({
			Name = "RailingBase",
			Size = Vector3.new(x1 - x0, 1.5, 1.5),
			Position = Vector3.new((x0 + x1) / 2, 1.15, s * 24.5),
			Color = Color3.fromRGB(200, 200, 205),
			Material = Enum.Material.Concrete,
			Parent = bridge,
		})
	end
	for x = x0 + 20, x1 - 20, 50 do
		for _, s in { -1, 1 } do
			Kit.P({
				Name = "Pillar",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(18, 4, 4),
				CFrame = CFrame.new(x, -9, s * 16) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(190, 190, 195),
				Material = Enum.Material.Concrete,
				Parent = bridge,
			})
		end
		Kit.streetLight(Vector3.new(x, 0.4, 22.5), 0, bridge)
	end
	Kit.flush(bridge, zone)

	-- Lampu di sisi luar jalan lingkar, kecuali di persimpangan
	local lights = Kit.folder("StreetLights")
	local junctions = {
		V(100, -1100),
		V(100, 1080),
		V(-480, 450),
		V(900, 450),
		V(900, 0),
		V(-480, 850),
		V(-480, -250),
	}
	for _, p in Kit.along(ring, true, 150, -30) do
		local ok = true
		for _, j in junctions do
			if (V(p.pos.X, p.pos.Z) - j).Magnitude < 45 then
				ok = false
				break
			end
		end
		if ok then
			Kit.streetLight(p.pos, p.yaw, lights)
		end
	end
	Kit.flush(lights, zone)
	return zone
end

-- Pencahayaan, langit, dan warna terrain diatur di satu tempat: StyleWorld.
local function buildLighting()
	StyleWorld("lighting")
end

return function()
	buildTerrain()
	local zone = buildHighway()
	buildLighting()
	local n = Kit.countParts(zone)
	print(("[BuildWorld] Terrain + jalan selesai: %d part"):format(n))
	return n
end
