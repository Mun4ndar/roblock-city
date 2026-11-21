--[[
	Homes: rumah keluarga, villa, rumah mewah dengan kolam renang, dan taman bermain.
	Posisi = pusat rumah di tanah (y = 0). Depan rumah = -Z lokal (lihat Streets.sideSpots untuk yaw).
]]

local Kit = require(script.Parent.MapKit)

local H = {}

local WALLS = {
	Color3.fromRGB(250, 215, 120),
	Color3.fromRGB(170, 215, 240),
	Color3.fromRGB(245, 180, 190),
	Color3.fromRGB(190, 230, 170),
	Color3.fromRGB(240, 240, 230),
	Color3.fromRGB(230, 190, 150),
	Color3.fromRGB(205, 190, 240),
	Color3.fromRGB(255, 200, 160),
}
local ROOFS = {
	Color3.fromRGB(170, 70, 55),
	Color3.fromRGB(70, 80, 110),
	Color3.fromRGB(120, 60, 70),
	Color3.fromRGB(90, 110, 70),
	Color3.fromRGB(60, 100, 150),
	Color3.fromRGB(110, 70, 50),
	Color3.fromRGB(80, 80, 90),
}

local function pick(list, seed: number)
	return list[math.floor(Kit.rnd(seed) * #list) + 1]
end

-- Rumah keluarga 1 atau 2 lantai, atap pelana, kadang dengan garasi.
-- drive = jarak dari depan rumah ke tepi trotoar (untuk jalan masuk).
function H.house(
	name: string,
	pos: Vector3,
	yaw: number,
	seed: number,
	parent: Instance,
	drive: number?
)
	local m = Kit.model(name, nil)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local stories = if Kit.rnd(seed + 3) > 0.55 then 2 else 1
	local garage = Kit.rnd(seed + 5) > 0.45
	local w, d = 20, 16
	local h = if stories == 2 then 17 else 10
	local fy = 0.8
	local wall = pick(WALLS, seed)
	local roof = pick(ROOFS, seed + 1)
	local front = -d / 2

	Kit.P({
		Name = "Foundation",
		Size = Vector3.new(w + 2, fy, d + 2),
		CFrame = base * CFrame.new(0, fy / 2, 0),
		Color = Kit.C.walk,
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	local body = Kit.P({
		Name = "Body",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, fy + h / 2, 0),
		Color = wall,
		Parent = m,
	})
	local rh = 6
	local roofY = fy + h + rh / 2
	local half = d / 2 + 1
	Kit.P({
		ClassName = "WedgePart",
		Name = "RoofFront",
		Size = Vector3.new(w + 2, rh, half),
		CFrame = base * CFrame.new(0, roofY, -half / 2),
		Color = roof,
		Parent = m,
	})
	Kit.P({
		ClassName = "WedgePart",
		Name = "RoofBack",
		Size = Vector3.new(w + 2, rh, half),
		CFrame = base * CFrame.new(0, roofY, half / 2) * CFrame.Angles(0, math.pi, 0),
		Color = roof,
		Parent = m,
	})

	Kit.deco({
		Name = "Door",
		Size = Vector3.new(4, 7, 0.3),
		CFrame = base * CFrame.new(-3, fy + 3.5, front - 0.15),
		Color = Kit.C.door,
		Parent = m,
	})
	Kit.deco({
		Name = "Porch",
		Size = Vector3.new(8, 0.4, 3),
		CFrame = base * CFrame.new(-3, fy + 7.6, front - 1.5),
		Color = Color3.new(1, 1, 1),
		Parent = m,
	})
	Kit.deco({
		Name = "Window1",
		Size = Vector3.new(5, 3.5, 0.2),
		CFrame = base * CFrame.new(5, fy + 5, front - 0.1),
		Color = Kit.C.glass,
		Reflectance = 0.2,
		Parent = m,
	})
	if stories == 2 then
		Kit.deco({
			Name = "Window2",
			Size = Vector3.new(w - 6, 3.5, 0.2),
			CFrame = base * CFrame.new(0, fy + 12.5, front - 0.1),
			Color = Kit.C.glass,
			Reflectance = 0.2,
			Parent = m,
		})
	end

	local driveX = -3
	if garage then
		driveX = w / 2 + 6
		Kit.P({
			Name = "Garage",
			Size = Vector3.new(12, 9, d - 2),
			CFrame = base * CFrame.new(w / 2 + 6, fy + 4.5, 1),
			Color = wall:Lerp(Color3.new(1, 1, 1), 0.25),
			Parent = m,
		})
		Kit.P({
			Name = "GarageRoof",
			Size = Vector3.new(13, 0.8, d - 1),
			CFrame = base * CFrame.new(w / 2 + 6, fy + 9.4, 1),
			Color = roof,
			Parent = m,
		})
		Kit.deco({
			Name = "GarageDoor",
			Size = Vector3.new(9, 7, 0.3),
			CFrame = base * CFrame.new(w / 2 + 6, fy + 3.5, front + 0.85),
			Color = Color3.fromRGB(235, 235, 235),
			Parent = m,
		})
	end
	local dl = drive or 8
	Kit.P({
		Name = "Driveway",
		Size = Vector3.new(if garage then 10 else 4, 0.2, dl),
		CFrame = base * CFrame.new(driveX, 0.1, front - dl / 2),
		Color = Kit.C.walk,
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	Kit.deco({
		Name = "Mailbox",
		Size = Vector3.new(1.2, 3.5, 1.2),
		CFrame = base * CFrame.new(driveX - 4, 1.75, front - dl + 1),
		Color = Color3.fromRGB(60, 110, 200),
		Parent = m,
	})
	Kit.deco({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.5,
		CFrame = base * CFrame.new(5, 1.5, front - 2),
		Color = Color3.fromRGB(80, 160, 70),
		Material = Enum.Material.Grass,
		Parent = m,
	})

	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Rumah mewah modern: dua massa bertingkat, kaca besar, atap datar, kolam renang, pagar tanaman.
function H.mansion(
	name: string,
	pos: Vector3,
	yaw: number,
	seed: number,
	parent: Instance,
	drive: number?
)
	local m = Kit.model(name, nil)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local white = Color3.fromRGB(245, 245, 242)
	local accent = pick(
		{ Color3.fromRGB(160, 120, 85), Color3.fromRGB(70, 75, 85), Color3.fromRGB(90, 150, 160) },
		seed
	)
	local glass = Color3.fromRGB(120, 180, 215)
	local W, D = 70, 60 -- ukuran kavling

	-- rumput kavling dan pagar tanaman
	Kit.P({
		Name = "Lawn",
		Size = Vector3.new(W, 0.2, D),
		CFrame = base * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(120, 190, 90),
		Material = Enum.Material.Grass,
		Parent = m,
	})
	for _, sx in { -1, 1 } do
		Kit.P({
			Name = "Hedge",
			Size = Vector3.new(2, 4, D),
			CFrame = base * CFrame.new(sx * (W / 2 - 1), 2, 0),
			Color = Color3.fromRGB(60, 130, 60),
			Material = Enum.Material.Grass,
			Parent = m,
		})
	end
	Kit.P({
		Name = "HedgeBack",
		Size = Vector3.new(W, 4, 2),
		CFrame = base * CFrame.new(0, 2, D / 2 - 1),
		Color = Color3.fromRGB(60, 130, 60),
		Material = Enum.Material.Grass,
		Parent = m,
	})
	for _, sx in { -1, 1 } do
		Kit.P({
			Name = "HedgeFront",
			Size = Vector3.new(W / 2 - 9, 4, 2),
			CFrame = base * CFrame.new(sx * (W / 4 + 4.5), 2, -D / 2 + 1),
			Color = Color3.fromRGB(60, 130, 60),
			Material = Enum.Material.Grass,
			Parent = m,
		})
		Kit.P({
			Name = "GatePost",
			Size = Vector3.new(2, 6, 2),
			CFrame = base * CFrame.new(sx * 8, 3, -D / 2 + 1),
			Color = white,
			Parent = m,
		})
	end

	-- massa bawah (lebar) dan atas (menjorok)
	local body = Kit.P({
		Name = "GroundFloor",
		Size = Vector3.new(40, 10, 22),
		CFrame = base * CFrame.new(-6, 5.5, -2),
		Color = white,
		Parent = m,
	})
	Kit.P({
		Name = "Plinth",
		Size = Vector3.new(44, 1, 26),
		CFrame = base * CFrame.new(-6, 0.5, -2),
		Color = Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	Kit.deco({
		Name = "GlassFront",
		Size = Vector3.new(30, 7, 0.3),
		CFrame = base * CFrame.new(-8, 5.5, -13.2),
		Color = glass,
		Reflectance = 0.3,
		Parent = m,
	})
	Kit.P({
		Name = "UpperFloor",
		Size = Vector3.new(30, 9, 24),
		CFrame = base * CFrame.new(2, 15.5, 0),
		Color = white,
		Parent = m,
	})
	Kit.deco({
		Name = "UpperGlass",
		Size = Vector3.new(24, 5, 0.3),
		CFrame = base * CFrame.new(2, 15.5, -12.2),
		Color = glass,
		Reflectance = 0.3,
		Parent = m,
	})
	Kit.deco({
		Name = "WoodPanel",
		Size = Vector3.new(6, 9, 0.4),
		CFrame = base * CFrame.new(14, 15.5, -12.3),
		Color = accent,
		Material = Enum.Material.Wood,
		Parent = m,
	})
	Kit.P({
		Name = "RoofSlab",
		Size = Vector3.new(34, 1, 28),
		CFrame = base * CFrame.new(2, 20.5, 0),
		Color = Color3.fromRGB(60, 62, 68),
		Parent = m,
	})
	Kit.P({
		Name = "LowerRoof",
		Size = Vector3.new(44, 0.8, 26),
		CFrame = base * CFrame.new(-6, 10.9, -2),
		Color = Color3.fromRGB(60, 62, 68),
		Parent = m,
	})
	Kit.deco({
		Name = "Door",
		Size = Vector3.new(5, 8, 0.3),
		CFrame = base * CFrame.new(10, 5, -13.2),
		Color = accent,
		Material = Enum.Material.Wood,
		Parent = m,
	})

	-- kolam renang di samping
	Kit.P({
		Name = "PoolDeck",
		Size = Vector3.new(22, 0.6, 30),
		CFrame = base * CFrame.new(23, 0.3, 4),
		Color = Color3.fromRGB(225, 215, 195),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	Kit.P({
		Name = "PoolWater",
		Size = Vector3.new(12, 0.3, 20),
		CFrame = base * CFrame.new(23, 0.55, 4),
		Color = Color3.fromRGB(70, 200, 235),
		Transparency = 0.15,
		Reflectance = 0.25,
		CanCollide = false,
		Parent = m,
	})
	for i, cz in { -4, 4 } do
		Kit.deco({
			Name = "Lounger" .. i,
			Size = Vector3.new(2.5, 1, 6),
			CFrame = base * CFrame.new(31, 1.1, cz) * CFrame.Angles(math.rad(8), 0, 0),
			Color = Color3.new(1, 1, 1),
			Parent = m,
		})
	end
	Kit.tree(base.Position + (base.Rotation * Vector3.new(30, 0, 18)), 0.9, m, "palm", seed)
	Kit.tree(base.Position + (base.Rotation * Vector3.new(-30, 0, 20)), 0.8, m, "palm", seed + 1)

	-- jalan masuk ke trotoar
	local dl = drive or 8
	Kit.P({
		Name = "Driveway",
		Size = Vector3.new(12, 0.25, 17 + dl),
		CFrame = base * CFrame.new(0, 0.12, -D / 2 + (17 - dl) / 2 - 0.5 + 0.5),
		Color = Color3.fromRGB(205, 200, 190),
		Material = Enum.Material.Concrete,
		Parent = m,
	})

	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Taman bermain berwarna: perosotan, ayunan (bisa diduduki), jungkat-jungkit, komidi putar, bak pasir.
function H.playground(center: Vector3, parent: Instance)
	local m = Kit.model("TamanBermain", nil)
	local c = CFrame.new(center)
	local red, blue, yellow, green =
		Color3.fromRGB(235, 80, 70),
		Color3.fromRGB(70, 140, 235),
		Color3.fromRGB(250, 205, 60),
		Color3.fromRGB(90, 190, 100)
	local floor = Kit.P({
		Name = "Floor",
		Size = Vector3.new(110, 0.3, 80),
		CFrame = c * CFrame.new(0, 0.15, 0),
		Color = Color3.fromRGB(240, 150, 90),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	Kit.deco({
		Name = "FloorPatch",
		Size = Vector3.new(44, 0.05, 30),
		CFrame = c * CFrame.new(-25, 0.33, -12),
		Color = Color3.fromRGB(110, 170, 230),
		Parent = m,
	})

	-- perosotan
	local s = c * CFrame.new(-30, 0, -14)
	Kit.P({
		Name = "SlideTower",
		Size = Vector3.new(7, 9, 7),
		CFrame = s * CFrame.new(0, 4.5, 0),
		Color = blue,
		Parent = m,
	})
	Kit.P({
		Name = "SlideRoof",
		ClassName = "WedgePart",
		Size = Vector3.new(8, 3, 4),
		CFrame = s * CFrame.new(0, 10.5, -2),
		Color = red,
		Parent = m,
	})
	Kit.P({
		Name = "SlideRoofB",
		ClassName = "WedgePart",
		Size = Vector3.new(8, 3, 4),
		CFrame = s * CFrame.new(0, 10.5, 2) * CFrame.Angles(0, math.pi, 0),
		Color = red,
		Parent = m,
	})
	Kit.P({
		Name = "Slide",
		ClassName = "WedgePart",
		Size = Vector3.new(4, 9, 16),
		CFrame = s * CFrame.new(0, 4.5, 11.5) * CFrame.Angles(0, math.pi, 0),
		Color = yellow,
		Parent = m,
	})
	for i = 0, 3 do
		Kit.P({
			Name = "Step",
			Size = Vector3.new(4, 0.6, 1.6),
			CFrame = s * CFrame.new(0, 1.2 + i * 2.2, -4.5 - i * 0.2),
			Color = green,
			Parent = m,
		})
	end

	-- ayunan
	local sw = c * CFrame.new(20, 0, -18)
	for _, x in { -9, 9 } do
		Kit.P({
			Name = "SwingPost",
			Size = Vector3.new(0.8, 12, 0.8),
			CFrame = sw * CFrame.new(x, 6, 0),
			Color = red,
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	Kit.P({
		Name = "SwingBar",
		Size = Vector3.new(19, 0.8, 0.8),
		CFrame = sw * CFrame.new(0, 12, 0),
		Color = red,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, x in { -4, 4 } do
		for _, rx in { -1, 1 } do
			Kit.deco({
				Name = "Rope",
				Size = Vector3.new(0.2, 9, 0.2),
				CFrame = sw * CFrame.new(x + rx * 1.2, 7.5, 0),
				Color = Color3.fromRGB(80, 80, 80),
				Parent = m,
			})
		end
		local seat = Instance.new("Seat")
		seat.Name = "SwingSeat"
		seat.Anchored = true
		seat.Size = Vector3.new(3, 0.4, 1.6)
		seat.CFrame = sw * CFrame.new(x, 3, 0)
		seat.Color = yellow
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = m
	end

	-- jungkat-jungkit
	local ss = c * CFrame.new(20, 0, 14)
	Kit.P({
		Name = "SeesawBase",
		ClassName = "WedgePart",
		Size = Vector3.new(2, 2, 2),
		CFrame = ss * CFrame.new(0, 1, 0),
		Color = blue,
		Parent = m,
	})
	Kit.P({
		Name = "SeesawPlank",
		Size = Vector3.new(16, 0.5, 1.6),
		CFrame = ss * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(10)),
		Color = green,
		Parent = m,
	})

	-- komidi putar
	local cr = c * CFrame.new(-2, 0, 18)
	Kit.P({
		Name = "Carousel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 12, 12),
		CFrame = cr * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = yellow,
		Parent = m,
	})
	Kit.P({
		Name = "CarouselPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 0.8, 0.8),
		CFrame = cr * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = red,
		Parent = m,
	})
	Kit.P({
		Name = "CarouselTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9, 9),
		CFrame = cr * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = blue,
		Parent = m,
	})

	-- bak pasir
	local sb = c * CFrame.new(-34, 0, 20)
	Kit.P({
		Name = "SandboxRim",
		Size = Vector3.new(16, 1, 16),
		CFrame = sb * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(170, 120, 80),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	Kit.P({
		Name = "Sand",
		Size = Vector3.new(14, 0.2, 14),
		CFrame = sb * CFrame.new(0, 1.05, 0),
		Color = Color3.fromRGB(240, 220, 160),
		Material = Enum.Material.Sand,
		Parent = m,
	})

	-- bangku & papan nama
	for i, x in { -45, 45 } do
		Kit.bench(c * CFrame.new(x, 0, 30) * CFrame.Angles(0, math.pi, 0), m)
		Kit.tree(center + Vector3.new(x, 0, -34), 1.1, m, "round", i + center.X)
	end
	local board = Kit.P({
		Name = "Papan",
		Size = Vector3.new(26, 5, 1),
		CFrame = c * CFrame.new(0, 7, -42),
		Color = Color3.fromRGB(90, 190, 100),
		Parent = m,
	})
	for _, x in { -12, 12 } do
		Kit.P({
			Name = "PapanTiang",
			Size = Vector3.new(1, 7, 1),
			CFrame = c * CFrame.new(x, 3.5, -42),
			Color = Color3.new(1, 1, 1),
			Parent = m,
		})
	end
	Kit.sign(board, "TAMAN BERMAIN", Color3.new(1, 1, 1))

	m.PrimaryPart = floor
	m.Parent = parent
	return m
end

return H
