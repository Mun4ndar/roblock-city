--[[
	ROBLOCK CITY: Countryside / Pedesaan (Workspace.Map.Countryside + sungai di Terrain)
	Barat pulau, x -1450..-560. Jalankan SETELAH BuildWorld (BuildWorld menghapus Terrain).
	- Sungai dari danau di kaki gunung (dengan air terjun) mengalir ke laut selatan,
	  melewati bawah jalan Countryside dan jalan Bandara (ada jembatan).
	- Hutan cemara di perbukitan, perkemahan di tepi danau.
	- Jalan desa, ladang, lumbung, silo, kincir angin, rumah petani, padang rumput dengan sapi & domba.

	Pakai: require(game.ServerStorage.MapBuilders.BuildCountryside)()
]]

local Kit = require(script.Parent.MapKit)

local V2 = Vector2.new
local M = Enum.Material

local function col(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local RIVER = {
	V2(-960, -470),
	V2(-935, -385),
	V2(-900, -330),
	V2(-760, -180),
	V2(-690, 0),
	V2(-640, 200),
	V2(-610, 420),
	V2(-600, 700),
	V2(-575, 950),
	V2(-560, 1320),
}
local RIVER_W = 36
local LAKE = V2(-960, -472) -- di luar kaki gunung supaya tidak jadi gua
local LAKE_R = 48
-- Titik belok dibulatkan (radius 60) supaya jalan desa melengkung mulus, tidak patah-patah.
local COUNTRY_ROAD = Kit.smooth(
	{ V2(-950, -262), V2(-1060, -160), V2(-1110, 0), V2(-1150, 150), V2(-1100, 300), V2(-740, 300) },
	60,
	8
)

local WOOD = col(150, 105, 70)

local function groundY(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local r = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
	if r and r.Material ~= M.Water then
		return r.Position.Y
	end
	return nil
end

local function distToPolyline(p: Vector2, pts: { Vector2 }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end

local function segIntersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2): Vector2?
	local r, s = b - a, d - c
	local den = r.X * s.Y - r.Y * s.X
	if math.abs(den) < 1e-6 then
		return nil
	end
	local t = ((c.X - a.X) * s.Y - (c.Y - a.Y) * s.X) / den
	local u = ((c.X - a.X) * r.Y - (c.Y - a.Y) * r.X) / den
	if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
		return a + r * t
	end
	return nil
end

--------------------------------------------------------------------------
-- Sungai, danau & air terjun (Terrain)
--------------------------------------------------------------------------

local function carveStrip(T: Terrain, a: Vector2, b: Vector2, w: number)
	local A, Bv = Vector3.new(a.X, 0, a.Y), Vector3.new(b.X, 0, b.Y)
	local mid = (A + Bv) / 2
	local len = (Bv - A).Magnitude + w * 0.6
	local rot = CFrame.lookAt(mid, Bv).Rotation
	T:FillBlock(CFrame.new(mid + Vector3.new(0, 8, 0)) * rot, Vector3.new(w, 24, len), M.Air)
	T:FillBlock(CFrame.new(mid + Vector3.new(0, -6, 0)) * rot, Vector3.new(w + 6, 4, len), M.Sand)
	T:FillBlock(CFrame.new(mid + Vector3.new(0, -2.5, 0)) * rot, Vector3.new(w, 3, len), M.Water)
end

local function buildRiver()
	local T = workspace.Terrain
	for i = 1, #RIVER - 1 do
		carveStrip(T, RIVER[i], RIVER[i + 1], RIVER_W)
		task.wait()
	end
	-- danau
	for dz = -LAKE_R + 4, LAKE_R - 4, 8 do
		local half = math.sqrt(LAKE_R * LAKE_R - dz * dz)
		local cf = CFrame.new(LAKE.X, 0, LAKE.Y + dz)
		T:FillBlock(cf * CFrame.new(0, 8, 0), Vector3.new(half * 2, 24, 8), M.Air)
		T:FillBlock(cf * CFrame.new(0, -6, 0), Vector3.new(half * 2 + 6, 4, 8), M.Sand)
		T:FillBlock(cf * CFrame.new(0, -2.5, 0), Vector3.new(half * 2, 3, 8), M.Water)
	end
	-- tebing batu untuk air terjun di utara danau
	T:FillBlock(CFrame.new(LAKE.X, 22, LAKE.Y - 70), Vector3.new(110, 48, 44), M.Rock)
	T:FillBlock(CFrame.new(LAKE.X, 46, LAKE.Y - 80), Vector3.new(26, 4, 30), M.Water)
	task.wait()
end

local function buildWaterfall(zone: Instance)
	local f = Kit.folder("AirTerjun")
	-- air jatuh sedikit miring mengikuti muka tebing
	local x, zf = LAKE.X, LAKE.Y - 43
	local top = Vector3.new(x, 47, LAKE.Y - 61)
	local bot = Vector3.new(x, -1, zf)
	local fall = Kit.deco({
		Name = "Air",
		Size = Vector3.new(22, (top - bot).Magnitude, 2),
		CFrame = CFrame.lookAt((top + bot) / 2, top) * CFrame.Angles(math.pi / 2, 0, 0),
		Color = col(150, 210, 245),
		Transparency = 0.3,
		Reflectance = 0.2,
		Parent = f,
	})
	for i = 0, 4 do
		Kit.deco({
			Name = "Busa",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (6 + (i % 2) * 3),
			Position = Vector3.new(x - 10 + i * 5, -1, zf + 3),
			Color = Color3.new(1, 1, 1),
			Transparency = 0.2,
			Parent = f,
		})
	end
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(8, 14)
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Rate = 6
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = fall
	Kit.flush(f, zone)
end

--------------------------------------------------------------------------
-- Model kecil
--------------------------------------------------------------------------

local function cow(cf: CFrame, parent: Instance)
	local m = Kit.model("Sapi", nil)
	local body = Kit.P({
		Name = "Body",
		Size = Vector3.new(3, 3, 6),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.deco({
		Name = "Spot",
		Size = Vector3.new(3.1, 1.6, 2.2),
		CFrame = cf * CFrame.new(0, 4, 1),
		Color = col(40, 40, 40),
		Parent = m,
	})
	Kit.P({
		Name = "Head",
		Size = Vector3.new(2.2, 2.2, 2.4),
		CFrame = cf * CFrame.new(0, 4.6, -3.8),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.deco({
		Name = "Nose",
		Size = Vector3.new(1.8, 1, 0.6),
		CFrame = cf * CFrame.new(0, 4, -5.1),
		Color = col(240, 170, 170),
		Parent = m,
	})
	for _, lx in { -1, 1 } do
		for _, lz in { -2.2, 2.2 } do
			Kit.deco({
				Name = "Leg",
				Size = Vector3.new(0.7, 2, 0.7),
				CFrame = cf * CFrame.new(lx, 1, lz),
				Color = Color3.new(1, 1, 1),
				Parent = m,
			})
		end
	end
	m.PrimaryPart = body
	m.Parent = parent
end

local function sheep(cf: CFrame, parent: Instance)
	local m = Kit.model("Domba", nil)
	local body = Kit.P({
		Name = "Wool",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.6,
		CFrame = cf * CFrame.new(0, 2.8, 0),
		Color = col(245, 245, 240),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	Kit.P({
		Name = "Head",
		Size = Vector3.new(1.4, 1.6, 1.6),
		CFrame = cf * CFrame.new(0, 3.2, -2.1),
		Color = col(50, 45, 45),
		Parent = m,
	})
	for _, lx in { -0.8, 0.8 } do
		for _, lz in { -0.9, 0.9 } do
			Kit.deco({
				Name = "Leg",
				Size = Vector3.new(0.5, 1.4, 0.5),
				CFrame = cf * CFrame.new(lx, 0.7, lz),
				Color = col(50, 45, 45),
				Parent = m,
			})
		end
	end
	m.PrimaryPart = body
	m.Parent = parent
end

local function gable(
	name: string,
	base: CFrame,
	w: number,
	h: number,
	d: number,
	wall: Color3,
	roof: Color3,
	parent: Instance
): BasePart
	local body = Kit.P({
		Name = name,
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = wall,
		Parent = parent,
	})
	local rh = w * 0.35
	local half = d / 2 + 1
	Kit.P({
		ClassName = "WedgePart",
		Name = "RoofA",
		Size = Vector3.new(w + 2, rh, half),
		CFrame = base * CFrame.new(0, h + rh / 2, -half / 2),
		Color = roof,
		Parent = parent,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "RoofB",
		Size = Vector3.new(w + 2, rh, half),
		CFrame = base * CFrame.new(0, h + rh / 2, half / 2) * CFrame.Angles(0, math.pi, 0),
		Color = roof,
		Parent = parent,
	})
	return body
end

local function fence(a: Vector3, b: Vector3, parent: Instance)
	local d = b - a
	local len = d.Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	for _, y in { 1.6, 3 } do
		Kit.P({
			Name = "Rail",
			Size = Vector3.new(0.4, 0.4, len),
			CFrame = cf + Vector3.new(0, y, 0),
			Color = WOOD,
			Material = M.Wood,
			Parent = parent,
		})
	end
	local n = math.max(1, math.floor(len / 12))
	for i = 0, n do
		Kit.deco({
			Name = "Post",
			Size = Vector3.new(0.7, 3.8, 0.7),
			CFrame = CFrame.new(a + d * (i / n) + Vector3.new(0, 1.9, 0)),
			Color = WOOD,
			Material = M.Wood,
			Parent = parent,
		})
	end
end

--------------------------------------------------------------------------
-- Kawasan
--------------------------------------------------------------------------

local function buildRoads(zone: Instance)
	local f = Kit.folder("Roads")
	local countryRoad =
		Kit.road(COUNTRY_ROAD, { width = 28, lanes = 2, parent = f, name = "JalanDesa" })
	-- Potong tanah bukit di atas badan jalan (plus bahu lebar): tepi potongan terrain dirender
	-- melandai, jadi tanpa bahu lebar rumput tampak menutupi aspal.
	for _, seg in countryRoad:GetDescendants() do
		if
			seg:IsA("BasePart")
			and seg.Size.X > 20
			and seg.Size.Z > 4
			and seg.CFrame.UpVector.Y > 0.99
		then
			workspace.Terrain:FillBlock(
				seg.CFrame * CFrame.new(0, 13 - seg.Position.Y, 0),
				Vector3.new(seg.Size.X + 28, 30, seg.Size.Z + 6),
				Enum.Material.Air
			)
		end
	end
	-- jembatan: pagar di tempat jalan menyeberangi sungai
	local crossings = {
		{ COUNTRY_ROAD, 28 },
		{ { V2(-504, -250), V2(-650, -262), V2(-800, -300), V2(-950, -262) }, 48 },
		{ { V2(-504, 850), V2(-700, 850) }, 48 },
	}
	for _, c in crossings do
		local pts, w = c[1], c[2]
		for i = 1, #pts - 1 do
			for j = 1, #RIVER - 1 do
				local p = segIntersect(pts[i], pts[i + 1], RIVER[j], RIVER[j + 1])
				if p then
					local dir = (pts[i + 1] - pts[i]).Unit
					local side = Vector2.new(-dir.Y, dir.X)
					for _, s in { -1, 1 } do
						local q = p + side * s * (w / 2 + 0.6)
						local cf = CFrame.lookAt(
							Vector3.new(q.X, 0, q.Y),
							Vector3.new(q.X + dir.X, 0, q.Y + dir.Y)
						)
						Kit.P({
							Name = "PagarJembatan",
							Size = Vector3.new(1.2, 3, RIVER_W + 24),
							CFrame = cf + Vector3.new(0, 1.5, 0),
							Color = col(235, 235, 240),
							Material = M.Concrete,
							Parent = f,
						})
					end
					Kit.P({
						Name = "Dek",
						Size = Vector3.new(w + 3, 2, RIVER_W + 24),
						CFrame = CFrame.lookAt(
							Vector3.new(p.X, -0.8, p.Y),
							Vector3.new(p.X + dir.X, -0.8, p.Y + dir.Y)
						),
						Color = col(190, 190, 195),
						Material = M.Concrete,
						Parent = f,
					})
				end
			end
		end
	end
	-- papan selamat datang
	local board = Kit.P({
		Name = "PapanPedesaan",
		Size = Vector3.new(30, 7, 1),
		CFrame = CFrame.lookAt(Vector3.new(-560, 10, -310), Vector3.new(-500, 10, -310)),
		Color = col(90, 150, 70),
		Parent = f,
	})
	Kit.sign(board, "PEDESAAN", Color3.new(1, 1, 1))
	for _, dz in { -12, 12 } do
		Kit.P({
			Name = "Tiang",
			Size = Vector3.new(1, 10, 1),
			Position = Vector3.new(-560, 5, -310 + dz),
			Color = WOOD,
			Material = M.Wood,
			Parent = f,
		})
	end
	Kit.flush(f, zone)
end

local function buildFarm(zone: Instance)
	local f = Kit.folder("Pertanian")
	Kit.flush(f, zone)
	-- ladang di selatan jalan desa (z 320..440)
	local crops = { col(120, 170, 60), col(230, 200, 80), col(90, 150, 50), col(240, 170, 60) }
	local i = 0
	for x = -1300, -1030, 90 do
		i += 1
		local fc = CFrame.new(x, 0, 380)
		Kit.P({
			Name = "Tanah",
			Size = Vector3.new(80, 0.3, 100),
			CFrame = fc * CFrame.new(0, 0.15, 0),
			Color = col(125, 90, 60),
			Material = M.Ground,
			Parent = f,
		})
		for r = -4, 4 do
			Kit.deco({
				Name = "Tanaman",
				Size = Vector3.new(4, 1.4, 92),
				CFrame = fc * CFrame.new(r * 8.5, 1, 0),
				Color = crops[i % #crops + 1],
				Material = M.Grass,
				Parent = f,
			})
		end
		task.wait()
	end

	-- rumah petani, lumbung, silo, kincir angin (z 320..440, x -940..-760)
	local farm = Kit.model("RumahPetani", f)
	gable("Rumah", CFrame.new(-900, 0, 345), 24, 12, 18, col(250, 240, 220), col(150, 70, 55), farm)
	Kit.deco({
		Name = "Pintu",
		Size = Vector3.new(4, 7, 0.3),
		CFrame = CFrame.new(-900, 3.5, 335.9),
		Color = Kit.C.door,
		Parent = farm,
	})
	local barn = Kit.model("Lumbung", f)
	gable(
		"Lumbung",
		CFrame.new(-840, 0, 395) * CFrame.Angles(0, math.pi / 2, 0),
		30,
		16,
		40,
		col(190, 50, 45),
		col(80, 70, 70),
		barn
	)
	Kit.deco({
		Name = "PintuLumbung",
		Size = Vector3.new(0.3, 12, 14),
		CFrame = CFrame.new(-859.9, 6, 395),
		Color = Color3.new(1, 1, 1),
		Parent = barn,
	})
	Kit.P({
		Name = "Silo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 12, 12),
		CFrame = CFrame.new(-805, 15, 430) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(200, 205, 210),
		Material = M.Metal,
		Parent = barn,
	})
	Kit.P({
		Name = "SiloTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 12,
		Position = Vector3.new(-805, 30, 430),
		Color = col(200, 205, 210),
		Material = M.Metal,
		Parent = barn,
	})
	local mill = Kit.model("KincirAngin", f)
	local mx, mz = -960, 420
	Kit.P({
		Name = "Menara",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 10, 10),
		CFrame = CFrame.new(mx, 13, mz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(245, 240, 230),
		Parent = mill,
	})
	Kit.P({
		Name = "Atap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 10,
		Position = Vector3.new(mx, 26, mz),
		Color = col(150, 70, 55),
		Parent = mill,
	})
	for k = 0, 3 do
		Kit.deco({
			Name = "Baling",
			Size = Vector3.new(2.6, 18, 0.3),
			CFrame = CFrame.new(mx, 24, mz - 5.6)
				* CFrame.Angles(0, 0, k * math.pi / 2 + 0.3)
				* CFrame.new(0, 9, 0),
			Color = Color3.new(1, 1, 1),
			Parent = mill,
		})
	end
	-- padang rumput berpagar dengan sapi & domba di ujung barat ladang
	local pasture = Kit.folder("PadangRumput", f)
	local px0, px1, pz0, pz1 = -1440, -1355, 322, 440
	fence(Vector3.new(px0, 0, pz0), Vector3.new(px1, 0, pz0), pasture)
	fence(Vector3.new(px1, 0, pz0), Vector3.new(px1, 0, pz1), pasture)
	fence(Vector3.new(px1, 0, pz1), Vector3.new(px0, 0, pz1), pasture)
	fence(Vector3.new(px0, 0, pz1), Vector3.new(px0, 0, pz0), pasture)
	for k = 0, 2 do
		cow(CFrame.new(-1425 + k * 12, 0, 345 + k * 30) * CFrame.Angles(0, k * 1.3, 0), pasture)
		sheep(CFrame.new(-1395 + k * 6, 0, 370 + k * 22) * CFrame.Angles(0, k * 2.1, 0), pasture)
	end
	-- pagar sepanjang jalan desa sisi ladang
	fence(Vector3.new(-1440, 0, 318), Vector3.new(-1000, 0, 318), f)
	-- pohon buah
	for k = 0, 5 do
		Kit.tree(
			Vector3.new(-930 + (k % 3) * 22, 0, 380 + math.floor(k / 3) * 26),
			0.9,
			f,
			"round",
			k + 300
		)
	end
end

local function buildCamp(zone: Instance)
	local f = Kit.folder("Perkemahan")
	local base = Vector3.new(LAKE.X + 80, 0, LAKE.Y + 20)
	local colors = { col(240, 120, 60), col(70, 160, 235), col(90, 190, 100) }
	for k = 0, 2 do
		local p = base + Vector3.new(k * 16, 0, (k % 2) * 12)
		local y = groundY(p.X, p.Z) or 0
		local cf = CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, k * 0.5, 0)
		Kit.P({
			ClassName = "WedgePart",
			Name = "Tenda",
			Size = Vector3.new(8, 6, 4),
			CFrame = cf * CFrame.new(0, 3, -2),
			Color = colors[k + 1],
			Material = M.Fabric,
			Parent = f,
		})
		Kit.P({
			ClassName = "WedgePart",
			Name = "Tenda",
			Size = Vector3.new(8, 6, 4),
			CFrame = cf * CFrame.new(0, 3, 2) * CFrame.Angles(0, math.pi, 0),
			Color = colors[k + 1],
			Material = M.Fabric,
			Parent = f,
		})
	end
	local fp = base + Vector3.new(16, 0, 26)
	local fy = groundY(fp.X, fp.Z) or 0
	for k = 0, 2 do
		Kit.P({
			Name = "KayuBakar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 1, 1),
			CFrame = CFrame.new(fp.X, fy + 0.5, fp.Z) * CFrame.Angles(0, k * math.pi / 3, 0),
			Color = col(110, 75, 50),
			Material = M.Wood,
			Parent = f,
		})
	end
	local fire = Kit.deco({
		Name = "ApiUnggun",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		Position = Vector3.new(fp.X, fy + 1.4, fp.Z),
		Color = col(255, 150, 40),
		Material = M.Neon,
		Parent = f,
	})
	local light = Instance.new("PointLight")
	light.Color = col(255, 160, 80)
	light.Range = 18
	light.Parent = fire
	for k = 0, 1 do
		local tp = base + Vector3.new(-10 + k * 50, 0, 40)
		local ty = groundY(tp.X, tp.Z) or 0
		local cf = CFrame.new(tp.X, ty, tp.Z)
		Kit.P({
			Name = "MejaPiknik",
			Size = Vector3.new(8, 0.5, 4),
			CFrame = cf * CFrame.new(0, 3, 0),
			Color = WOOD,
			Material = M.Wood,
			Parent = f,
		})
		for _, s in { -1, 1 } do
			Kit.P({
				Name = "BangkuPiknik",
				Size = Vector3.new(8, 0.4, 1.4),
				CFrame = cf * CFrame.new(0, 1.8, s * 3),
				Color = WOOD,
				Material = M.Wood,
				Parent = f,
			})
		end
	end
	Kit.flush(f, zone)
end

local function buildForest(zone: Instance)
	local f = Kit.folder("Hutan")
	Kit.flush(f, zone)
	local n = 0
	local function ok(x: number, z: number): boolean
		local p = V2(x, z)
		if distToPolyline(p, RIVER) < RIVER_W / 2 + 10 then
			return false
		end
		if (p - LAKE).Magnitude < LAKE_R + 40 then
			return false
		end
		if distToPolyline(p, COUNTRY_ROAD) < 26 then
			return false
		end
		if
			distToPolyline(p, { V2(-504, -250), V2(-650, -262), V2(-800, -300), V2(-950, -262) })
			< 34
		then
			return false
		end
		return true
	end
	local regions = {
		{ -1460, -1020, -660, -160, 40, "pine" }, -- hutan di kaki gunung & bukit
		{ -1460, -1180, -140, 250, 46, "mix" }, -- bukit barat
		{ -900, -560, -1000, -620, 48, "pine" }, -- lereng utara-timur
		{ -860, -620, -150, 250, 55, "mix" }, -- tepi sungai
	}
	for _, r in regions do
		local x = r[1]
		while x <= r[2] do
			local z = r[3]
			while z <= r[4] do
				n += 1
				local jx = x + (Kit.rnd(n * 1.31) - 0.5) * r[5] * 0.8
				local jz = z + (Kit.rnd(n * 2.17) - 0.5) * r[5] * 0.8
				if ok(jx, jz) then
					local y = groundY(jx, jz)
					if y and y < 120 then
						local kind = if r[6] == "pine" or Kit.rnd(n) > 0.5 then "pine" else "round"
						Kit.tree(
							Vector3.new(jx, y - 0.3, jz),
							1.1 + Kit.rnd(n * 3.1) * 0.6,
							f,
							kind,
							n
						)
					end
				end
				z += r[5]
			end
			x += r[5]
		end
		task.wait()
	end
end

return function()
	buildRiver()
	local zone = Kit.zone("Countryside")
	zone:SetAttribute("Zone", "Countryside")
	buildWaterfall(zone)
	buildRoads(zone)
	buildFarm(zone)
	buildCamp(zone)
	buildForest(zone)
	local n = Kit.countParts(zone)
	print(("[BuildCountryside] selesai: %d part"):format(n))
	return n
end
