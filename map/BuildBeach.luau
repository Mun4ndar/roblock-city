--[[
	ROBLOCK CITY: Beach Island (Workspace.Map.Beach)
	Pulau di timur (pusat ~ (1750, 100)), tersambung jembatan di z = 0.
	- Jalan pantai x = 1820 (utara-selatan) + promenade kayu berpalem.
	- Resor dengan kolam renang, dermaga dengan bianglala, payung pantai, menara penjaga pantai,
	  sewa jet ski, kios es krim & kelapa muda, lapangan voli pantai.
	- Pelabuhan di ujung selatan dengan kapal, mercusuar di ujung utara.

	Pakai: require(game.ServerStorage.MapBuilders.BuildBeach)()
]]

local Kit = require(script.Parent.MapKit)
local B = require(script.Parent.Buildings)

local V2 = Vector2.new
local WATER_Y = -2

local function col(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WOOD = col(170, 125, 85)
local COLORS = {
	col(240, 80, 90),
	col(250, 200, 60),
	col(70, 160, 235),
	col(90, 200, 120),
	col(240, 130, 200),
	col(255, 150, 60),
}

local function boat(name: string, cf: CFrame, hull: Color3, parent: Instance, len: number?)
	local m = Kit.model(name, nil)
	local L = len or 26
	local body = Kit.P({
		Name = "Hull",
		Size = Vector3.new(9, 4, L * 0.7),
		CFrame = cf * CFrame.new(0, 0.5, L * 0.15),
		Color = hull,
		Parent = m,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "Bow",
		Size = Vector3.new(9, 4, L * 0.3),
		CFrame = cf * CFrame.new(0, 0.5, -L * 0.35) * CFrame.Angles(0, 0, math.pi),
		Color = hull,
		Parent = m,
	})
	Kit.deco({
		Name = "Stripe",
		Size = Vector3.new(9.2, 0.6, L * 0.7),
		CFrame = cf * CFrame.new(0, 1.8, L * 0.15),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.P({
		Name = "Cabin",
		Size = Vector3.new(6, 4, L * 0.3),
		CFrame = cf * CFrame.new(0, 4.5, L * 0.2),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.deco({
		Name = "CabinGlass",
		Size = Vector3.new(6.2, 1.5, L * 0.3 - 1),
		CFrame = cf * CFrame.new(0, 5, L * 0.2),
		Color = Kit.C.glass,
		Reflectance = 0.3,
		Parent = m,
	})
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function jetSki(cf: CFrame, color: Color3, parent: Instance)
	local m = Kit.model("JetSki", nil)
	local hull = Kit.P({
		Name = "Hull",
		Size = Vector3.new(3, 1.2, 6),
		CFrame = cf * CFrame.new(0, 0, 1),
		Color = color,
		Parent = m,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "Nose",
		Size = Vector3.new(3, 1.2, 3),
		CFrame = cf * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, 0, math.pi),
		Color = color,
		Parent = m,
	})
	Kit.deco({
		Name = "Seat",
		Size = Vector3.new(1.4, 0.8, 3),
		CFrame = cf * CFrame.new(0, 1, 1.5),
		Color = col(40, 40, 45),
		Parent = m,
	})
	Kit.deco({
		Name = "Handle",
		Size = Vector3.new(2.4, 0.4, 0.4),
		CFrame = cf * CFrame.new(0, 1.6, -0.6),
		Color = col(40, 40, 45),
		Parent = m,
	})
	m.PrimaryPart = hull
	m.Parent = parent
	return m
end

local function umbrella(pos: Vector3, color: Color3, parent: Instance, seed: number)
	local m = Kit.model("Payung", nil)
	local pole = Kit.P({
		Name = "Pole",
		Size = Vector3.new(0.4, 8, 0.4),
		Position = pos + Vector3.new(0, 4, 0),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.deco({
		Name = "Canopy",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 9, 9),
		CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Parent = m,
	})
	Kit.deco({
		Name = "Top",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Position = pos + Vector3.new(0, 8.6, 0),
		Color = color,
		Parent = m,
	})
	local towel = COLORS[math.floor(Kit.rnd(seed) * #COLORS) + 1]
	Kit.deco({
		Name = "Towel",
		Size = Vector3.new(3, 0.1, 6),
		CFrame = CFrame.new(pos + Vector3.new(3, 0.05, 1))
			* CFrame.Angles(0, Kit.rnd(seed + 1) * 0.6, 0),
		Color = towel,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	m.PrimaryPart = pole
	m.Parent = parent
end

local function ferrisWheel(center: Vector3, r: number, parent: Instance)
	local m = Kit.model("Bianglala", nil)
	-- roda menghadap sumbu X (terlihat penuh dari pantai di barat)
	local hub = Kit.P({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 4, 4),
		CFrame = CFrame.new(center),
		Color = col(240, 240, 245),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, sx in { -3, 3 } do
		for _, sz in { -1, 1 } do
			local foot = center + Vector3.new(sx, -center.Y + 3, sz * r * 0.55)
			local top = center + Vector3.new(sx, 0, 0)
			local mid = (foot + top) / 2
			Kit.P({
				Name = "Leg",
				Size = Vector3.new(1.2, (top - foot).Magnitude, 1.2),
				CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.pi / 2, 0, 0),
				Color = col(240, 240, 245),
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end
	local n = 16
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = center + Vector3.new(0, math.sin(a) * r, math.cos(a) * r)
		local seg = 2 * math.pi * r / n + 0.6
		Kit.deco({
			Name = "Rim",
			Size = Vector3.new(1, 1, seg),
			CFrame = CFrame.new(p) * CFrame.Angles(-a + math.pi / 2, 0, 0),
			Color = col(250, 90, 140),
			Material = Enum.Material.Neon,
			Parent = m,
		})
		if i % 2 == 0 then
			local sp = center + Vector3.new(0, math.sin(a) * r / 2, math.cos(a) * r / 2)
			Kit.deco({
				Name = "Spoke",
				Size = Vector3.new(0.5, 0.5, r),
				CFrame = CFrame.lookAt(sp, p),
				Color = Color3.new(1, 1, 1),
				Parent = m,
			})
			Kit.P({
				Name = "Cabin",
				Size = Vector3.new(4, 4, 4),
				CFrame = CFrame.new(p - Vector3.new(0, 3, 0)),
				Color = COLORS[(i / 2) % #COLORS + 1],
				Parent = m,
			})
		end
	end
	m.PrimaryPart = hub
	m.Parent = parent
	return m
end

local function lighthouse(pos: Vector3, parent: Instance)
	local m = Kit.model("Mercusuar", nil)
	local base = Kit.P({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 18, 18),
		CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(200, 200, 205),
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	for i = 0, 5 do
		local d = 12 - i * 1.1
		Kit.P({
			Name = "Section" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(8, d, d),
			CFrame = CFrame.new(pos + Vector3.new(0, 8 + i * 8, 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = if i % 2 == 0 then col(230, 50, 50) else Color3.new(1, 1, 1),
			Parent = m,
		})
	end
	local top = pos + Vector3.new(0, 52, 0)
	Kit.P({
		Name = "Gallery",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 11, 11),
		CFrame = CFrame.new(top) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(50, 55, 60),
		Parent = m,
	})
	local lamp = Kit.deco({
		Name = "Lamp",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(top + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(255, 240, 150),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	Kit.P({
		Name = "Roof",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7,
		Position = top + Vector3.new(0, 6.5, 0),
		Color = col(230, 50, 50),
		Parent = m,
	})
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = col(255, 235, 170)
	light.Parent = lamp
	m.PrimaryPart = base
	m.Parent = parent
	return m
end

local function kiosk(
	name: string,
	sign: string,
	pos: Vector3,
	yaw: number,
	color: Color3,
	parent: Instance
)
	B.shop(
		{
			name = name,
			x = pos.X,
			z = pos.Z,
			yaw = yaw,
			baseY = pos.Y,
			w = 16,
			d = 12,
			h = 9,
			floors = 1,
			color = Color3.new(1, 1, 1),
			trim = color,
			sign = sign,
			signColor = color,
			storefront = true,
			awning = color,
		},
		parent
	)
end

local function buildRoads(zone: Instance)
	local f = Kit.folder("Roads")
	Kit.road(
		{ V2(1560, 0), V2(1796, 0) },
		{ width = 48, lanes = 4, parent = f, name = "JalanMasukPulau" }
	)
	Kit.road(
		{ V2(1820, -380), V2(1820, 560), V2(1780, 690) },
		{ width = 32, lanes = 2, parent = f, name = "JalanPantai" }
	)
	-- promenade kayu di sisi pantai
	Kit.P({
		Name = "Promenade",
		Size = Vector3.new(14, 0.6, 840),
		Position = Vector3.new(1852, 0.3, 90),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = f,
	})
	local p = 0
	for z = -320, 500, 40 do
		p += 1
		Kit.tree(Vector3.new(1843, 0.6, z), 1 + Kit.rnd(z) * 0.25, f, "palm", z)
		if p % 2 == 0 then
			Kit.streetLight(Vector3.new(1838, 0.6, z + 20), -math.pi / 2, f)
		end
	end
	Kit.flush(f, zone)
end

local function buildResort(zone: Instance)
	local f = Kit.folder("Resort")
	B.tower(
		{
			name = "ROBLOCKResort",
			x = 1705,
			z = -220,
			w = 140,
			d = 40,
			h = 42,
			yaw = -math.pi / 2,
			color = col(250, 248, 240),
			band = col(90, 190, 200),
			bandEvery = 8,
			crown = "ac",
			sign = "ROBLOCK RESORT",
			signColor = col(60, 170, 190),
		},
		f
	)
	-- kolam renang di depan resor
	Kit.P({
		Name = "PoolDeck",
		Size = Vector3.new(56, 0.6, 110),
		Position = Vector3.new(1760, 0.3, -220),
		Color = col(235, 225, 205),
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	Kit.P({
		Name = "PoolWater",
		Size = Vector3.new(26, 0.3, 70),
		Position = Vector3.new(1760, 0.55, -220),
		Color = col(70, 205, 235),
		Transparency = 0.15,
		Reflectance = 0.25,
		CanCollide = false,
		Parent = f,
	})
	for i = 0, 5 do
		local z = -260 + i * 16
		Kit.deco({
			Name = "Lounger",
			Size = Vector3.new(6, 1, 2.5),
			CFrame = CFrame.new(1780, 1.1, z) * CFrame.Angles(0, 0, math.rad(8)),
			Color = Color3.new(1, 1, 1),
			Parent = f,
		})
		umbrella(Vector3.new(1783, 0.6, z + 6), COLORS[i % #COLORS + 1], f, i)
	end
	for _, z in { -280, -160 } do
		Kit.tree(Vector3.new(1740, 0.6, z), 1.2, f, "palm", z)
		Kit.tree(Vector3.new(1785, 0.6, z + 10), 1.1, f, "palm", z + 3)
	end
	Kit.flush(f, zone)
end

local function buildBeachLife(zone: Instance)
	local f = Kit.folder("Pantai")
	Kit.flush(f, zone)
	-- payung & handuk di pasir
	local function blocked(x: number, z: number): boolean
		return (x > 2020 and z < -100)
			or (math.abs(x - 2070) < 18 and math.abs(z - 60) < 18)
			or math.abs(z - 120) < 18
			or (math.abs(x - 1990) < 25 and math.abs(z - 330) < 20)
	end
	local n = 0
	for z = -220, 440, 55 do
		for _, x in { 1930, 1990, 2050 } do
			n += 1
			if Kit.rnd(n * 3.3) > 0.25 and not blocked(x, z) then
				umbrella(
					Vector3.new(x + (Kit.rnd(n) - 0.5) * 16, 0, z + (Kit.rnd(n + 7) - 0.5) * 16),
					COLORS[n % #COLORS + 1],
					f,
					n
				)
			end
		end
	end
	task.wait()

	-- menara penjaga pantai
	local lg = CFrame.new(2070, 0, 60)
	local tower = Kit.model("MenaraPenjagaPantai", f)
	for _, sx in { -3, 3 } do
		for _, sz in { -3, 3 } do
			Kit.P({
				Name = "Leg",
				Size = Vector3.new(0.8, 9, 0.8),
				CFrame = lg * CFrame.new(sx, 4.5, sz),
				Color = Color3.new(1, 1, 1),
				Parent = tower,
			})
		end
	end
	Kit.P({
		Name = "Platform",
		Size = Vector3.new(8, 0.8, 8),
		CFrame = lg * CFrame.new(0, 9.4, 0),
		Color = col(240, 70, 60),
		Parent = tower,
	})
	Kit.P({
		Name = "Hut",
		Size = Vector3.new(6, 5, 6),
		CFrame = lg * CFrame.new(0, 12.3, 0),
		Color = col(250, 200, 60),
		Parent = tower,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "Ramp",
		Size = Vector3.new(3, 9, 8),
		CFrame = lg * CFrame.new(0, 4.5, -8) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.new(1, 1, 1),
		Parent = tower,
	})

	-- voli pantai
	local vc = CFrame.new(1990, 0, 330)
	for _, sz in { -10, 10 } do
		Kit.P({
			Name = "TiangNet",
			Size = Vector3.new(0.5, 9, 0.5),
			CFrame = vc * CFrame.new(0, 4.5, sz),
			Color = Color3.new(1, 1, 1),
			Parent = f,
		})
	end
	Kit.deco({
		Name = "Net",
		Size = Vector3.new(0.2, 3, 20),
		CFrame = vc * CFrame.new(0, 7, 0),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.4,
		Parent = f,
	})
	local vb = Kit.P({
		Name = "BolaVoli",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = vc * CFrame.new(6, 1, 0),
		Color = col(250, 220, 80),
		Parent = f,
	})
	vb.Anchored = false

	-- kios
	kiosk("KiosEsKrim", "ES KRIM", Vector3.new(1885, 0.6, -60), math.pi / 2, col(240, 120, 170), f)
	kiosk(
		"KiosKelapa",
		"KELAPA MUDA",
		Vector3.new(1885, 0.6, 250),
		math.pi / 2,
		col(90, 180, 90),
		f
	)

	-- sewa jet ski
	B.shop(
		{
			name = "SewaJetSki",
			x = 2060,
			z = -150,
			yaw = -math.pi / 2,
			baseY = 0,
			w = 22,
			d = 14,
			h = 10,
			floors = 1,
			color = col(70, 160, 235),
			trim = Color3.new(1, 1, 1),
			sign = "SEWA JET SKI",
			signColor = Color3.new(1, 1, 1),
			signText = col(40, 110, 200),
			storefront = true,
			awning = col(250, 200, 60),
		},
		f
	)
	for i = 0, 3 do
		jetSki(
			CFrame.new(2135, WATER_Y + 0.4, -175 + i * 16) * CFrame.Angles(0, -math.pi / 2, 0),
			COLORS[i + 1],
			f
		)
	end
end

local function buildPier(zone: Instance)
	local f = Kit.folder("Dermaga")
	local z = 120
	local x0, x1 = 1990, 2360
	Kit.P({
		Name = "Deck",
		Size = Vector3.new(x1 - x0, 1, 18),
		Position = Vector3.new((x0 + x1) / 2, 2.5, z),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = f,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "Ramp",
		Size = Vector3.new(18, 3, 14),
		CFrame = CFrame.new(x0 - 7, 1.5, z) * CFrame.Angles(0, math.pi / 2, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = f,
	})
	for x = x0 + 20, x1 - 10, 30 do
		for _, s in { -1, 1 } do
			Kit.P({
				Name = "Post",
				Size = Vector3.new(1.2, 20, 1.2),
				Position = Vector3.new(x, -7, z + s * 8),
				Color = col(120, 85, 55),
				Material = Enum.Material.Wood,
				Parent = f,
			})
			Kit.deco({
				Name = "Rail",
				Size = Vector3.new(30, 0.4, 0.4),
				Position = Vector3.new(x + 15, 5.5, z + s * 8.6),
				Color = Color3.new(1, 1, 1),
				Parent = f,
			})
		end
	end
	-- platform lebar di ujung untuk bianglala
	Kit.P({
		Name = "Platform",
		Size = Vector3.new(60, 1, 70),
		Position = Vector3.new(x1 + 20, 2.5, z),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = f,
	})
	for _, px in { x1, x1 + 40 } do
		for _, pz in { z - 30, z + 30 } do
			Kit.P({
				Name = "Post",
				Size = Vector3.new(2, 20, 2),
				Position = Vector3.new(px, -7, pz),
				Color = col(120, 85, 55),
				Material = Enum.Material.Wood,
				Parent = f,
			})
		end
	end
	ferrisWheel(Vector3.new(x1 + 20, 48, z), 40, f)
	Kit.flush(f, zone)
end

local function buildHarbor(zone: Instance)
	local f = Kit.folder("Pelabuhan")
	-- dermaga beton & terminal feri
	Kit.P({
		Name = "Quay",
		Size = Vector3.new(220, 3, 50),
		Position = Vector3.new(1760, -0.5, 765),
		Color = col(185, 185, 190),
		Material = Enum.Material.Concrete,
		Parent = f,
	})
	Kit.P({
		Name = "QuayEdge",
		Size = Vector3.new(220, 1, 1.5),
		Position = Vector3.new(1760, 1.5, 789),
		Color = col(250, 200, 60),
		Parent = f,
	})
	B.shop(
		{
			name = "TerminalFeri",
			x = 1770,
			z = 720,
			yaw = 0,
			baseY = 0,
			w = 70,
			d = 30,
			h = 16,
			floors = 2,
			color = col(240, 245, 250),
			trim = col(40, 110, 200),
			sign = "PELABUHAN",
			signColor = col(40, 110, 200),
			storefront = true,
		},
		f
	)
	-- jetty kayu & kapal
	for i, x in { 1680, 1760, 1840 } do
		Kit.P({
			Name = "Jetty",
			Size = Vector3.new(8, 1, 90),
			Position = Vector3.new(x, 0.5, 835),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
		for zz = 800, 870, 35 do
			Kit.P({
				Name = "Post",
				Size = Vector3.new(1, 14, 1),
				Position = Vector3.new(x + 4.5, -5, zz),
				Color = col(120, 85, 55),
				Material = Enum.Material.Wood,
				Parent = f,
			})
		end
		boat(
			"Kapal" .. i,
			CFrame.new(x + 12, WATER_Y, 850) * CFrame.Angles(0, if i == 2 then math.pi else 0, 0),
			COLORS[i + 2],
			f,
			26 + i * 4
		)
	end
	-- kapal feri besar
	boat("KapalFeri", CFrame.new(1600, WATER_Y, 820), col(240, 240, 245), f, 60)
	for _, x in { 1660, 1860 } do
		Kit.streetLight(Vector3.new(x, 1, 760), math.pi, f)
	end
	Kit.flush(f, zone)
end

return function()
	local zone = Kit.zone("Beach")
	zone:SetAttribute("Zone", "BeachIsland")
	buildRoads(zone)
	buildResort(zone)
	buildBeachLife(zone)
	buildPier(zone)
	buildHarbor(zone)
	local lh = Kit.folder("Mercusuar")
	lighthouse(Vector3.new(1800, 0, -560), lh)
	Kit.flush(lh, zone)
	-- palem tersebar di bagian rumput pulau
	local pf = Kit.folder("Palms")
	for i = 1, 26 do
		local a = Kit.rnd(i * 1.7) * math.pi * 2
		local r = 40 + Kit.rnd(i * 2.9) * 190
		local p = Vector3.new(1660 + math.cos(a) * r * 0.8, 0, 100 + math.sin(a) * r * 1.6)
		if math.abs(p.Z) > 30 and p.X < 1790 and not (p.X > 1670 and p.Z < -130) then
			Kit.tree(p, 0.9 + Kit.rnd(i) * 0.4, pf, "palm", i)
		end
	end
	Kit.flush(pf, zone)
	local n = Kit.countParts(zone)
	print(("[BuildBeach] selesai: %d part"):format(n))
	return n
end
