--[[
	ROBLOCK CITY: Bandara Internasional (Workspace.Map.Airport)
	Barat daya pulau, x -1340..-680, z 470..1180. Dihubungkan jalan dari jalan lingkar di z = 850.
	- Landasan pacu timur-barat (z = 1080) dengan marka & lampu, taxiway, apron.
	- Terminal kaca dengan garbarata, menara kontrol, hangar, parkir mobil, pesawat parkir.

	Pakai: require(game.ServerStorage.MapBuilders.BuildAirport)()
]]

local Kit = require(script.Parent.MapKit)
local B = require(script.Parent.Buildings)

local V2 = Vector2.new
local M = Enum.Material

local function col(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local CONCRETE = col(185, 185, 182)
local RUNWAY_Z = 1080
local RUNWAY_X0, RUNWAY_X1 = -1320, -700
local RUNWAY_W = 50

-- Pesawat penumpang hias. Hidung ke -Z lokal.
local function airplane(name: string, cf: CFrame, livery: Color3, parent: Instance, scale: number?)
	local s = scale or 1
	local m = Kit.model(name, nil)
	local L, D = 64 * s, 8 * s
	local gear = 4 * s
	local c = cf * CFrame.new(0, gear + D / 2, 0)
	local white = Color3.new(1, 1, 1)
	local body = Kit.P({
		Name = "Fuselage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(L, D, D),
		CFrame = c * CFrame.Angles(0, math.pi / 2, 0),
		Color = white,
		Parent = m,
	})
	Kit.P({
		Name = "Nose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * D,
		CFrame = c * CFrame.new(0, 0, -L / 2),
		Color = white,
		Parent = m,
	})
	Kit.P({
		Name = "Tail",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(D * 0.8, D * 0.8, D * 0.8),
		CFrame = c * CFrame.new(0, D * 0.05, L / 2),
		Color = white,
		Parent = m,
	})
	Kit.deco({
		Name = "Cockpit",
		Size = Vector3.new(D * 0.7, D * 0.22, 0.3),
		CFrame = c
			* CFrame.new(0, D * 0.22, -L / 2 - D * 0.35)
			* CFrame.Angles(math.rad(-35), 0, 0),
		Color = col(40, 50, 65),
		Parent = m,
	})
	for _, sx in { -1, 1 } do
		Kit.deco({
			Name = "Windows",
			Size = Vector3.new(0.2, D * 0.12, L * 0.75),
			CFrame = c * CFrame.new(sx * D / 2, D * 0.15, -L * 0.02),
			Color = col(40, 50, 65),
			Parent = m,
		})
		Kit.deco({
			Name = "Livery",
			Size = Vector3.new(0.2, D * 0.16, L * 0.85),
			CFrame = c * CFrame.new(sx * D / 2, -D * 0.12, 0),
			Color = livery,
			Parent = m,
		})
		-- sayap (sedikit menyapu ke belakang)
		Kit.P({
			Name = "Wing",
			Size = Vector3.new(30 * s, 0.8 * s, 10 * s),
			CFrame = c
				* CFrame.new(sx * 17 * s, -D * 0.25, 4 * s)
				* CFrame.Angles(0, -sx * math.rad(18), 0),
			Color = col(225, 228, 232),
			Parent = m,
		})
		Kit.P({
			Name = "Engine",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7 * s, 3.4 * s, 3.4 * s),
			CFrame = c
				* CFrame.new(sx * 12 * s, -D * 0.55, -1 * s)
				* CFrame.Angles(0, math.pi / 2, 0),
			Color = col(200, 205, 210),
			Parent = m,
		})
		Kit.deco({
			Name = "Stabilizer",
			Size = Vector3.new(11 * s, 0.6 * s, 5 * s),
			CFrame = c
				* CFrame.new(sx * 6 * s, D * 0.15, L / 2 - 2 * s)
				* CFrame.Angles(0, -sx * math.rad(20), 0),
			Color = col(225, 228, 232),
			Parent = m,
		})
	end
	Kit.P({
		ClassName = "WedgePart",
		Name = "Fin",
		Size = Vector3.new(0.8 * s, 11 * s, 11 * s),
		CFrame = c * CFrame.new(0, D / 2 + 5.5 * s, L / 2 - 6 * s),
		Color = livery,
		Parent = m,
	})
	for _, gz in { -L * 0.38, 3 * s } do
		Kit.deco({
			Name = "Gear",
			Size = Vector3.new(0.8, gear, 0.8),
			CFrame = cf * CFrame.new(0, gear / 2 + 0.5, gz),
			Color = col(60, 60, 65),
			Parent = m,
		})
		Kit.deco({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 2, 2),
			CFrame = cf * CFrame.new(0, 1, gz),
			Color = col(30, 30, 30),
			Parent = m,
		})
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function buildAirfield(zone: Instance)
	local f = Kit.folder("Landasan")
	local white = Kit.C.white
	local rx = (RUNWAY_X0 + RUNWAY_X1) / 2
	local rl = RUNWAY_X1 - RUNWAY_X0
	Kit.P({
		Name = "Runway",
		Size = Vector3.new(rl, 0.4, RUNWAY_W),
		Position = Vector3.new(rx, 0.2, RUNWAY_Z),
		Color = col(55, 57, 62),
		Material = M.Asphalt,
		Parent = f,
	})
	local my = 0.43
	for _, sz in { -1, 1 } do
		Kit.deco({
			Name = "EdgeLine",
			Size = Vector3.new(rl - 4, 0.05, 0.8),
			Position = Vector3.new(rx, my, RUNWAY_Z + sz * (RUNWAY_W / 2 - 2)),
			Color = white,
			Parent = f,
		})
	end
	local x = RUNWAY_X0 + 60
	while x + 20 <= RUNWAY_X1 - 60 do
		Kit.deco({
			Name = "CenterDash",
			Size = Vector3.new(20, 0.05, 1),
			Position = Vector3.new(x + 10, my, RUNWAY_Z),
			Color = white,
			Parent = f,
		})
		x += 40
	end
	for _, e in { { RUNWAY_X0 + 10, "09" }, { RUNWAY_X1 - 10, "27" } } do
		for k = -4, 4 do
			if k ~= 0 then
				Kit.deco({
					Name = "Threshold",
					Size = Vector3.new(16, 0.05, 2.4),
					Position = Vector3.new(e[1], my, RUNWAY_Z + k * 5),
					Color = white,
					Parent = f,
				})
			end
		end
		local num = Kit.deco({
			Name = "Nomor",
			Size = Vector3.new(14, 0.05, 16),
			Position = Vector3.new(e[1] + (if e[2] == "09" then 26 else -26), my, RUNWAY_Z),
			Transparency = 1,
			Parent = f,
		})
		Kit.sign(num, e[2], white, Enum.NormalId.Top)
	end
	-- lampu tepi landasan
	x = RUNWAY_X0 + 10
	while x <= RUNWAY_X1 - 10 do
		for _, sz in { -1, 1 } do
			Kit.deco({
				Name = "RunwayLight",
				Size = Vector3.new(0.8, 0.6, 0.8),
				Position = Vector3.new(x, 0.3, RUNWAY_Z + sz * (RUNWAY_W / 2 + 2)),
				Color = col(255, 230, 120),
				Material = M.Neon,
				Parent = f,
			})
		end
		x += 40
	end

	-- taxiway & penghubung
	Kit.P({
		Name = "Taxiway",
		Size = Vector3.new(560, 0.4, 24),
		Position = Vector3.new(-1010, 0.2, 990),
		Color = col(65, 67, 72),
		Material = M.Asphalt,
		Parent = f,
	})
	for _, tx in { -1278, -742 } do
		Kit.P({
			Name = "TaxiLink",
			Size = Vector3.new(24, 0.4, 70),
			Position = Vector3.new(tx, 0.21, 1022),
			Color = col(65, 67, 72),
			Material = M.Asphalt,
			Parent = f,
		})
	end
	Kit.deco({
		Name = "TaxiLine",
		Size = Vector3.new(556, 0.05, 0.6),
		Position = Vector3.new(-1010, 0.43, 990),
		Color = Kit.C.yellow,
		Parent = f,
	})
	-- apron
	Kit.P({
		Name = "Apron",
		Size = Vector3.new(500, 0.4, 210),
		Position = Vector3.new(-1000, 0.19, 872),
		Color = CONCRETE,
		Material = M.Concrete,
		Parent = f,
	})
	for _, gx in { -1110, -980, -850 } do
		Kit.deco({
			Name = "GateLine",
			Size = Vector3.new(0.6, 0.05, 110),
			Position = Vector3.new(gx, 0.42, 830),
			Color = Kit.C.yellow,
			Parent = f,
		})
	end

	-- kantong angin
	local ws = Vector3.new(-1250, 0, 1030)
	Kit.P({
		Name = "WindsockPole",
		Size = Vector3.new(0.5, 12, 0.5),
		Position = ws + Vector3.new(0, 6, 0),
		Color = white,
		Parent = f,
	})
	Kit.deco({
		Name = "Windsock",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2, 2),
		CFrame = CFrame.new(ws + Vector3.new(3, 11.5, 0)) * CFrame.Angles(0, 0, math.rad(-10)),
		Color = col(255, 120, 40),
		Parent = f,
	})
	Kit.flush(f, zone)
end

local function buildTerminal(zone: Instance)
	local f = Kit.folder("Terminal")
	-- gedung terminal: depan (sisi jalan) menghadap utara
	local tz = 700
	local term = Kit.model("Terminal", f)
	local body = Kit.P({
		Name = "Body",
		Size = Vector3.new(280, 26, 80),
		Position = Vector3.new(-990, 13, tz),
		Color = col(235, 240, 245),
		Parent = term,
	})
	Kit.P({
		Name = "Roof",
		Size = Vector3.new(296, 2, 96),
		Position = Vector3.new(-990, 27, tz),
		Color = col(80, 150, 210),
		Parent = term,
	})
	for _, sz in { -1, 1 } do
		Kit.deco({
			Name = "GlassWall",
			Size = Vector3.new(270, 18, 0.4),
			Position = Vector3.new(-990, 12, tz + sz * 40.1),
			Color = col(120, 185, 225),
			Reflectance = 0.3,
			Parent = term,
		})
	end
	for k = -6, 6 do
		Kit.deco({
			Name = "Mullion",
			Size = Vector3.new(1, 22, 1.2),
			Position = Vector3.new(-990 + k * 21, 13, tz - 40.4),
			Color = Color3.new(1, 1, 1),
			Parent = term,
		})
	end
	Kit.P({
		Name = "Canopy",
		Size = Vector3.new(200, 1, 18),
		Position = Vector3.new(-990, 11, tz - 49),
		Color = Color3.new(1, 1, 1),
		Parent = term,
	})
	for k = -4, 4 do
		Kit.P({
			Name = "CanopyPost",
			Size = Vector3.new(1, 10, 1),
			Position = Vector3.new(-990 + k * 24, 5.5, tz - 56),
			Color = col(200, 205, 210),
			Parent = term,
		})
	end
	local sign = Kit.deco({
		Name = "Sign",
		Size = Vector3.new(170, 7, 1),
		Position = Vector3.new(-990, 33, tz - 30),
		Color = col(40, 90, 160),
		Parent = term,
	})
	Kit.sign(sign, "BANDARA INTERNASIONAL ROBLOCK", Color3.new(1, 1, 1))
	term.PrimaryPart = body

	-- garbarata ke pesawat (sisi selatan)
	for _, gx in { -1110, -980, -850 } do
		Kit.P({
			Name = "Garbarata",
			Size = Vector3.new(7, 7, 34),
			Position = Vector3.new(gx + 14, 10, tz + 57),
			Color = col(225, 228, 232),
			Parent = f,
		})
		Kit.P({
			Name = "TiangGarbarata",
			Size = Vector3.new(1.5, 7, 1.5),
			Position = Vector3.new(gx + 14, 3.5, tz + 68),
			Color = col(120, 125, 130),
			Parent = f,
		})
	end

	-- menara kontrol
	local tc = Vector3.new(-770, 0, 700)
	Kit.P({
		Name = "MenaraKontrol",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 10, 10),
		CFrame = CFrame.new(tc + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(240, 240, 245),
		Parent = f,
	})
	Kit.P({
		Name = "Kabin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 20, 20),
		CFrame = CFrame.new(tc + Vector3.new(0, 64, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(70, 130, 180),
		Reflectance = 0.35,
		Parent = f,
	})
	Kit.P({
		Name = "AtapKabin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 23, 23),
		CFrame = CFrame.new(tc + Vector3.new(0, 68.75, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = col(240, 240, 245),
		Parent = f,
	})
	Kit.deco({
		Name = "Antena",
		Size = Vector3.new(0.6, 12, 0.6),
		Position = tc + Vector3.new(0, 75, 0),
		Color = col(200, 60, 60),
		Parent = f,
	})

	-- hangar
	B.shop({
		name = "Hangar",
		x = -1290,
		z = 880,
		yaw = -math.pi / 2,
		baseY = 0,
		w = 90,
		d = 60,
		h = 26,
		floors = 1,
		color = col(200, 205, 210),
		trim = col(80, 150, 210),
		material = M.DiamondPlate,
		sign = "HANGAR",
		signColor = col(80, 150, 210),
		doors = { { x = 0, w = 60, h = 20, color = col(150, 155, 160) } },
	}, f)
	Kit.flush(f, zone)
end

local function buildLandside(zone: Instance)
	local f = Kit.folder("Landside")
	-- jalan dari jalan Bandara (ujung x -700, z 850) ke depan terminal
	Kit.road(
		{ V2(-712, 862), V2(-712, 620), V2(-1150, 620) },
		{ width = 28, lanes = 2, parent = f, name = "JalanTerminal" }
	)
	B.parkingLot("ParkirBandara", CFrame.new(-990, 0, 535), 300, 110, f)
	for k = -2, 2 do
		Kit.tree(Vector3.new(-990 + k * 70, 0, 482), 1.1, f, "round", k + 900)
	end
	for _, x in { -1100, -1000, -900, -800 } do
		Kit.streetLight(Vector3.new(x, 0, 638), 0, f)
	end
	Kit.flush(f, zone)
end

local function buildPlanes(zone: Instance)
	local f = Kit.folder("Pesawat")
	airplane("PesawatROBLOCKAir1", CFrame.new(-1096, 0.4, 812), col(230, 70, 70), f)
	airplane("PesawatROBLOCKAir2", CFrame.new(-966, 0.4, 812), col(60, 130, 220), f)
	airplane(
		"PesawatTaxi",
		CFrame.new(-1180, 0.4, 990) * CFrame.Angles(0, -math.pi / 2, 0),
		col(250, 180, 50),
		f
	)
	airplane(
		"PesawatKecil",
		CFrame.new(-1240, 0.4, 900) * CFrame.Angles(0, math.pi / 2, 0),
		col(90, 190, 110),
		f,
		0.45
	)
	Kit.flush(f, zone)
end

return function()
	local zone = Kit.zone("Airport")
	zone:SetAttribute("Zone", "Airport")
	buildAirfield(zone)
	buildTerminal(zone)
	buildLandside(zone)
	buildPlanes(zone)
	local n = Kit.countParts(zone)
	print(("[BuildAirport] selesai: %d part"):format(n))
	return n
end
