--[[
	ROBLOCK CITY — Pembangun peta "Kota Kecil" (langkah 2)

	Skrip ini membangun ulang seluruh Workspace.Map secara deterministik, jadi
	peta tersimpan di git sebagai kode. Jalankan di Studio (mode Edit):
	  - tempel isi file ini ke Command Bar, atau
	  - jalankan lewat Roblox Studio MCP (execute_luau, datamodel Edit).
	Menjalankan ulang aman: Map lama dihapus dulu.

	Tata letak (stud, sumbu XZ, permukaan tanah y = 0):
	  Jalan timur-barat di z = -120, 0, 120 dan utara-selatan di x = -120, 0, 120.
	  Lebar jalan 32 (2 lajur). Empat blok di tengah:
	    Blok TL (x+, z-) : Toko, Kafe, Balai Kota
	    Blok BD (x-, z-) : Rumah Sakit
	    Blok TG (x+, z+) : Pemadam Kebakaran, Bengkel
	    Blok BL (x-, z+) : Taman + titik spawn
	  Perumahan: deretan rumah di sisi z > 120.
]]

local Lighting = game:GetService("Lighting")

local ROAD_W = 32
local HALF = ROAD_W / 2
local EXTENT = 200 -- ujung jalan
local GRID = { -120, 0, 120 }
local ROAD_TOP = 0.4
local WALK_TOP = 1.0

local C = {
	grass = Color3.fromRGB(106, 170, 76),
	asphalt = Color3.fromRGB(58, 60, 66),
	walk = Color3.fromRGB(196, 196, 190),
	yellow = Color3.fromRGB(245, 200, 40),
	white = Color3.fromRGB(240, 240, 240),
	glass = Color3.fromRGB(150, 205, 235),
	door = Color3.fromRGB(110, 75, 50),
	trunk = Color3.fromRGB(110, 78, 52),
	path = Color3.fromRGB(222, 205, 170),
}

local function P(props: { [string]: any }): BasePart
	local class = props.ClassName or "Part"
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Hiasan kecil: tidak perlu tabrakan/bayangan (hemat untuk mobile)
local function deco(props)
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	props.CastShadow = false
	return P(props)
end

local function addSign(part: BasePart, text: string, textColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or C.white
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

--------------------------------------------------------------------------
-- Bangunan
--------------------------------------------------------------------------

type BuildingDef = {
	name: string,
	x: number,
	z: number,
	yaw: number, -- arah depan: 0 = -Z, math.pi = +Z, -pi/2 = +X, pi/2 = -X
	w: number,
	d: number,
	h: number,
	floors: number,
	color: Color3,
	trim: Color3,
	material: Enum.Material?,
	sign: string,
	signColor: Color3,
	signText: Color3?,
	doors: { { x: number, w: number, h: number, color: Color3? } },
	storefront: boolean?,
}

local function building(def: BuildingDef, parent: Instance, baseY: number)
	local m = Instance.new("Model")
	m.Name = def.name
	local base = CFrame.new(def.x, baseY, def.z) * CFrame.Angles(0, def.yaw, 0)
	local w, d, h = def.w, def.d, def.h
	local front = -d / 2

	local body = P({
		Name = "Body",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = def.color,
		Material = def.material or Enum.Material.SmoothPlastic,
		Parent = m,
	})
	P({ Name = "Roof", Size = Vector3.new(w + 2, 1, d + 2), CFrame = base * CFrame.new(0, h + 0.5, 0), Color = def.trim, Parent = m })

	local floorH = h / def.floors
	for f = 1, def.floors do
		local y = (f - 0.5) * floorH
		if f == 1 and def.storefront then
			deco({
				Name = "Storefront",
				Size = Vector3.new(w - 4, floorH * 0.55, 0.2),
				CFrame = base * CFrame.new(0, floorH * 0.45, front - 0.1),
				Color = C.glass,
				Reflectance = 0.2,
				Parent = m,
			})
		elseif f > 1 then
			deco({
				Name = "Windows" .. f,
				Size = Vector3.new(w - 4, floorH * 0.45, 0.2),
				CFrame = base * CFrame.new(0, y, front - 0.1),
				Color = C.glass,
				Reflectance = 0.2,
				Parent = m,
			})
		end
	end

	for i, door in def.doors do
		deco({
			Name = "Door" .. i,
			Size = Vector3.new(door.w, door.h, 0.3),
			CFrame = base * CFrame.new(door.x, door.h / 2, front - 0.2),
			Color = door.color or C.door,
			Parent = m,
		})
	end

	-- papan nama di batas lantai 1-2 (atau di atas pintu bila hanya 1 lantai)
	local signH = 3
	local signY = if def.floors > 1 then floorH else h - signH / 2 - 0.5
	local sign = deco({
		Name = "Sign",
		Size = Vector3.new(math.min(w - 2, #def.sign * 2.2 + 4), signH, 0.4),
		CFrame = base * CFrame.new(0, signY, front - 0.45),
		Color = def.signColor,
		Parent = m,
	})
	addSign(sign, def.sign, def.signText)

	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function house(name: string, x: number, z: number, yaw: number, color: Color3, roofColor: Color3, parent: Instance)
	local m = Instance.new("Model")
	m.Name = name
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local w, d, h = 20, 16, 10
	local fy = WALK_TOP -- fondasi setinggi trotoar

	P({ Name = "Foundation", Size = Vector3.new(w + 2, fy, d + 2), CFrame = base * CFrame.new(0, fy / 2, 0), Color = C.walk, Material = Enum.Material.Concrete, Parent = m })
	local body = P({ Name = "Body", Size = Vector3.new(w, h, d), CFrame = base * CFrame.new(0, fy + h / 2, 0), Color = color, Parent = m })

	-- Atap pelana: dua WedgePart (lereng menghadap -Z lokal)
	local rh = 6
	local roofY = fy + h + rh / 2
	P({ ClassName = "WedgePart", Name = "RoofFront", Size = Vector3.new(w + 2, rh, d / 2 + 1), CFrame = base * CFrame.new(0, roofY, -(d / 2 + 1) / 2), Color = roofColor, Parent = m })
	P({
		ClassName = "WedgePart",
		Name = "RoofBack",
		Size = Vector3.new(w + 2, rh, d / 2 + 1),
		CFrame = base * CFrame.new(0, roofY, (d / 2 + 1) / 2) * CFrame.Angles(0, math.pi, 0),
		Color = roofColor,
		Parent = m,
	})
	deco({ Name = "Chimney", Size = Vector3.new(2, 5, 2), CFrame = base * CFrame.new(w / 4, fy + h + 4, 3), Color = Color3.fromRGB(150, 80, 60), Material = Enum.Material.Brick, Parent = m })

	local front = -d / 2
	deco({ Name = "Door", Size = Vector3.new(4, 7, 0.3), CFrame = base * CFrame.new(0, fy + 3.5, front - 0.15), Color = C.door, Parent = m })
	for i, wx in { -6, 6 } do
		deco({ Name = "Window" .. i, Size = Vector3.new(4, 3.5, 0.2), CFrame = base * CFrame.new(wx, fy + 5.5, front - 0.1), Color = C.glass, Reflectance = 0.2, Parent = m })
	end
	-- Jalan setapak dari trotoar ke pintu, dan kotak surat
	P({ Name = "Driveway", Size = Vector3.new(4, 0.2, 7), CFrame = base * CFrame.new(0, 0.1, front - 4.5), Color = C.walk, Material = Enum.Material.Concrete, Parent = m })
	deco({ Name = "Mailbox", Size = Vector3.new(1.2, 3.5, 1.2), CFrame = base * CFrame.new(4, 1.75, front - 7), Color = Color3.fromRGB(60, 110, 200), Parent = m })

	m.PrimaryPart = body
	m.Parent = parent
	return m
end

--------------------------------------------------------------------------
-- Properti
--------------------------------------------------------------------------

local function tree(name: string, pos: Vector3, scale: number, leafColor: Color3, parent: Instance)
	local m = Instance.new("Model")
	m.Name = name
	local th = 7 * scale
	local trunk = P({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(th, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, th / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.trunk,
		Material = Enum.Material.Wood,
		Parent = m,
	})
	P({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * 8 * scale, Position = pos + Vector3.new(0, th + 2.5 * scale, 0), Color = leafColor, Material = Enum.Material.Grass, CanCollide = false, Parent = m })
	P({ Name = "LeavesTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 5.5 * scale, Position = pos + Vector3.new(0.6 * scale, th + 6 * scale, 0.4 * scale), Color = leafColor:Lerp(Color3.new(1, 1, 0.6), 0.12), Material = Enum.Material.Grass, CanCollide = false, Parent = m })
	m.PrimaryPart = trunk
	m.Parent = parent
end

local function streetLight(name: string, pos: Vector3, yaw: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = name
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local pole = P({ Name = "Pole", Size = Vector3.new(0.6, 14, 0.6), CFrame = base * CFrame.new(0, 7, 0), Color = Color3.fromRGB(70, 75, 85), Material = Enum.Material.Metal, Parent = m })
	deco({ Name = "Arm", Size = Vector3.new(0.4, 0.4, 4), CFrame = base * CFrame.new(0, 13.8, -2), Color = Color3.fromRGB(70, 75, 85), Material = Enum.Material.Metal, Parent = m })
	local head = deco({ Name = "Lamp", Size = Vector3.new(1.6, 0.6, 2), CFrame = base * CFrame.new(0, 13.4, -3.6), Color = Color3.fromRGB(255, 236, 180), Material = Enum.Material.Neon, Parent = m })
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Shadows = false
	light.Parent = head
	m.PrimaryPart = pole
	m.Parent = parent
end

local function bench(name: string, cf: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = name
	local wood = Color3.fromRGB(150, 100, 60)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(6, 0.5, 2)
	seat.CFrame = cf * CFrame.new(0, 1.8, 0)
	seat.Color = wood
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = m
	deco({ Name = "Back", Size = Vector3.new(6, 2, 0.4), CFrame = cf * CFrame.new(0, 3, 0.9), Color = wood, Material = Enum.Material.Wood, Parent = m })
	for i, lx in { -2.5, 2.5 } do
		deco({ Name = "Leg" .. i, Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cf * CFrame.new(lx, 0.8, 0), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal, Parent = m })
	end
	m.PrimaryPart = seat
	m.Parent = parent
end

--------------------------------------------------------------------------
-- Bangun
--------------------------------------------------------------------------

-- Bersihkan peta lama dan baseplate/spawn bawaan template
for _, name in { "Map", "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local map = folder("Map")
map:SetAttribute("Zone", "KotaKecil")
map.Parent = workspace

local function flush(f: Instance)
	f.Parent = map
	task.wait()
end

-- 1. Tanah
do
	local f = folder("Ground")
	P({ Name = "Grass", Size = Vector3.new(560, 2, 560), Position = Vector3.new(0, -1, 0), Color = C.grass, Material = Enum.Material.Grass, Parent = f })
	flush(f)
end

-- 2. Jalan: segmen, persimpangan, marka
do
	local roads = folder("Roads")
	local segs = folder("Segments", roads)
	local inters = folder("Intersections", roads)
	local marks = folder("Markings", roads)

	-- titik potong sepanjang satu jalan
	local cuts = { -EXTENT }
	for _, g in GRID do
		table.insert(cuts, g - HALF)
		table.insert(cuts, g + HALF)
	end
	table.insert(cuts, EXTENT)

	local function mark(name: string, cx: number, cz: number, sx: number, sz: number, color: Color3)
		deco({ Name = name, Size = Vector3.new(sx, 0.05, sz), Position = Vector3.new(cx, ROAD_TOP + 0.025, cz), Color = color, Parent = marks })
	end

	for _, dir in { "EW", "NS" } do
		for ri, g in GRID do
			for i = 1, #cuts - 1, 2 do
				local a, b = cuts[i], cuts[i + 1]
				local len = b - a
				local mid = (a + b) / 2
				local segName = string.format("%s%d_%d", dir, ri, (i + 1) / 2)
				-- posisi: (sepanjang, melintang) -> (x, z)
				local function at(along: number, across: number): (number, number)
					if dir == "EW" then
						return along, g + across
					end
					return g + across, along
				end
				local function sz(along: number, across: number): (number, number)
					if dir == "EW" then
						return along, across
					end
					return across, along
				end

				local sx, sz2 = sz(len, ROAD_W)
				local px, pz = at(mid, 0)
				P({ Name = segName, Size = Vector3.new(sx, ROAD_TOP, sz2), Position = Vector3.new(px, ROAD_TOP / 2, pz), Color = C.asphalt, Material = Enum.Material.Asphalt, Parent = segs })

				-- garis tepi putih
				for _, side in { -HALF + 1.5, HALF - 1.5 } do
					local ex, ez = at(mid, side)
					local lx, lz = sz(len, 0.5)
					mark(segName .. "_Edge", ex, ez, lx, lz, C.white)
				end

				-- zebra cross di ujung yang menempel persimpangan
				local ends = {}
				if a > -EXTENT then
					table.insert(ends, a + 4)
				end
				if b < EXTENT then
					table.insert(ends, b - 4)
				end
				for _, e in ends do
					for s = -2, 2 do
						local cx, cz = at(e, s * 5.5)
						local lx, lz = sz(6, 2.5)
						mark(segName .. "_Zebra", cx, cz, lx, lz, C.white)
					end
				end

				-- garis tengah kuning putus-putus
				local startA = a + (a > -EXTENT and 10 or 2)
				local endB = b - (b < EXTENT and 10 or 2)
				local t = startA
				while t + 6 <= endB do
					local cx, cz = at(t + 3, 0)
					local lx, lz = sz(6, 0.6)
					mark(segName .. "_Dash", cx, cz, lx, lz, C.yellow)
					t += 12
				end
			end
		end
	end

	for _, gx in GRID do
		for _, gz in GRID do
			P({ Name = string.format("X_%d_%d", gx, gz), Size = Vector3.new(ROAD_W, ROAD_TOP, ROAD_W), Position = Vector3.new(gx, ROAD_TOP / 2, gz), Color = C.asphalt, Material = Enum.Material.Asphalt, Parent = inters })
		end
	end
	flush(roads)
end

-- 3. Trotoar / pelat blok
local BLOCKS = {
	Downtown = Vector3.new(60, 0, -60),
	Hospital = Vector3.new(-60, 0, -60),
	Services = Vector3.new(60, 0, 60),
	Park = Vector3.new(-60, 0, 60),
}
local BLOCK_SIZE = 120 - ROAD_W -- 88
do
	local f = folder("Sidewalks")
	for name, c in BLOCKS do
		P({ Name = name .. "Block", Size = Vector3.new(BLOCK_SIZE, WALK_TOP, BLOCK_SIZE), Position = Vector3.new(c.X, WALK_TOP / 2, c.Z), Color = C.walk, Material = Enum.Material.Concrete, Parent = f })
	end
	-- trotoar sisi perumahan (utara jalan z = 120)
	local z0 = 120 + HALF + 3
	for _, span in { { -EXTENT, -136 }, { -104, -16 }, { 16, 104 }, { 136, EXTENT } } do
		local a, b = span[1], span[2]
		P({ Name = "ResidentialWalk", Size = Vector3.new(b - a, WALK_TOP, 6), Position = Vector3.new((a + b) / 2, WALK_TOP / 2, z0), Color = C.walk, Material = Enum.Material.Concrete, Parent = f })
	end
	flush(f)
end

-- 4. Bangunan pusat kota
do
	local buildings = folder("Buildings")
	local downtown = folder("Downtown", buildings)
	local houses = folder("Houses", buildings)
	local Y = WALK_TOP
	local edge = 16 + 6 -- tepi blok + lebar trotoar

	building({
		name = "Toko",
		x = 38, z = -(edge + 12), yaw = math.pi,
		w = 28, d = 24, h = 16, floors = 2,
		color = Color3.fromRGB(80, 160, 220), trim = Color3.fromRGB(240, 240, 240),
		sign = "TOKO", signColor = Color3.fromRGB(240, 120, 40),
		doors = { { x = 0, w = 6, h = 6 } }, storefront = true,
	}, downtown, Y)

	building({
		name = "Kafe",
		x = 84, z = -(edge + 10), yaw = math.pi,
		w = 22, d = 20, h = 16, floors = 2,
		color = Color3.fromRGB(240, 205, 150), trim = Color3.fromRGB(150, 90, 60),
		material = Enum.Material.Brick,
		sign = "KAFE", signColor = Color3.fromRGB(120, 70, 45),
		doors = { { x = 0, w = 5, h = 6 } }, storefront = true,
	}, downtown, Y)

	building({
		name = "BalaiKota",
		x = 60, z = -(120 - edge - 14), yaw = 0, -- menghadap jalan z = -120
		w = 48, d = 28, h = 27, floors = 3,
		color = Color3.fromRGB(235, 230, 215), trim = Color3.fromRGB(120, 130, 150),
		sign = "BALAI KOTA", signColor = Color3.fromRGB(40, 70, 140),
		doors = { { x = 0, w = 8, h = 7 } },
	}, downtown, Y)

	building({
		name = "RumahSakit",
		x = -60, z = -(edge + 16), yaw = math.pi,
		w = 52, d = 32, h = 32, floors = 4,
		color = Color3.fromRGB(245, 245, 248), trim = Color3.fromRGB(210, 60, 60),
		sign = "RUMAH SAKIT", signColor = Color3.fromRGB(210, 50, 50),
		doors = { { x = 0, w = 10, h = 6.5, color = C.glass } },
	}, downtown, Y)

	building({
		name = "PemadamKebakaran",
		x = 40, z = edge + 15, yaw = 0,
		w = 34, d = 30, h = 20, floors = 2,
		color = Color3.fromRGB(200, 45, 40), trim = Color3.fromRGB(240, 240, 240),
		material = Enum.Material.Brick,
		sign = "PEMADAM KEBAKARAN", signColor = Color3.fromRGB(240, 240, 240), signText = Color3.fromRGB(200, 40, 40),
		doors = { { x = -8, w = 12, h = 7.5, color = Color3.fromRGB(230, 230, 230) }, { x = 8, w = 12, h = 7.5, color = Color3.fromRGB(230, 230, 230) } },
	}, downtown, Y)

	building({
		name = "Bengkel",
		x = 86, z = edge + 13, yaw = 0,
		w = 22, d = 26, h = 12, floors = 1,
		color = Color3.fromRGB(150, 155, 165), trim = Color3.fromRGB(245, 190, 40),
		material = Enum.Material.DiamondPlate,
		sign = "BENGKEL", signColor = Color3.fromRGB(245, 190, 40), signText = Color3.fromRGB(40, 40, 40),
		doors = { { x = 0, w = 14, h = 8, color = Color3.fromRGB(100, 105, 115) } },
	}, downtown, Y)

	-- Rumah di sisi utara jalan z = 120, menghadap jalan (-Z)
	local houseColors = {
		{ Color3.fromRGB(250, 215, 120), Color3.fromRGB(170, 70, 55) },
		{ Color3.fromRGB(170, 215, 240), Color3.fromRGB(70, 80, 110) },
		{ Color3.fromRGB(245, 180, 190), Color3.fromRGB(120, 60, 70) },
		{ Color3.fromRGB(190, 230, 170), Color3.fromRGB(90, 110, 70) },
		{ Color3.fromRGB(240, 240, 230), Color3.fromRGB(60, 100, 150) },
		{ Color3.fromRGB(230, 190, 150), Color3.fromRGB(110, 70, 50) },
	}
	local houseZ = 120 + HALF + 6 + 16
	for i, hx in { -168, -84, -36, 36, 84, 168 } do
		local col = houseColors[i]
		house("Rumah" .. i, hx, houseZ, 0, col[1], col[2], houses)
	end
	flush(buildings)
end

-- 5. Taman
do
	local park = folder("Park")
	local c = BLOCKS.Park
	local top = WALK_TOP + 0.2
	P({ Name = "Lawn", Size = Vector3.new(BLOCK_SIZE - 8, 0.2, BLOCK_SIZE - 8), Position = Vector3.new(c.X, WALK_TOP + 0.1, c.Z), Color = C.grass, Material = Enum.Material.Grass, Parent = park })
	P({ Name = "PathEW", Size = Vector3.new(BLOCK_SIZE - 8, 0.06, 6), Position = Vector3.new(c.X, top + 0.03, c.Z), Color = C.path, Material = Enum.Material.Sand, Parent = park })
	P({ Name = "PathNS", Size = Vector3.new(6, 0.06, BLOCK_SIZE - 8), Position = Vector3.new(c.X, top + 0.03, c.Z), Color = C.path, Material = Enum.Material.Sand, Parent = park })

	-- Air mancur
	local ftn = Instance.new("Model")
	ftn.Name = "AirMancur"
	local rim = P({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 18, 18), CFrame = CFrame.new(c.X, top + 1, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Marble, Parent = ftn })
	deco({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 16, 16), CFrame = CFrame.new(c.X, top + 2.05, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(80, 170, 230), Transparency = 0.25, Reflectance = 0.15, Parent = ftn })
	P({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 2.5, 2.5), CFrame = CFrame.new(c.X, top + 5, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Marble, Parent = ftn })
	deco({ Name = "Spray", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = Vector3.new(c.X, top + 8.5, c.Z), Color = Color3.fromRGB(150, 210, 245), Transparency = 0.4, Parent = ftn })
	ftn.PrimaryPart = rim
	ftn.Parent = park

	-- Bangku menghadap air mancur
	local benches = folder("Benches", park)
	local n = 0
	for _, off in { Vector3.new(16, 0, 7), Vector3.new(-16, 0, 7), Vector3.new(16, 0, -7), Vector3.new(-16, 0, -7) } do
		n += 1
		local pos = c + off + Vector3.new(0, top, 0)
		local face = Vector3.new(pos.X, pos.Y, c.Z)
		bench("Bangku" .. n, CFrame.lookAt(pos, face), benches)
	end

	-- Petak bunga di empat sudut
	local flowers = { Color3.fromRGB(240, 90, 120), Color3.fromRGB(250, 210, 60), Color3.fromRGB(170, 110, 230), Color3.fromRGB(250, 140, 60) }
	for i, off in { Vector3.new(28, 0, 28), Vector3.new(-28, 0, 28), Vector3.new(28, 0, -28), Vector3.new(-28, 0, -28) } do
		deco({ Name = "FlowerBed" .. i, Size = Vector3.new(10, 0.8, 10), Position = c + off + Vector3.new(0, top + 0.4, 0), Color = flowers[i], Material = Enum.Material.Grass, Parent = park })
	end
	flush(park)
end

-- 6. Properti: pohon, lampu jalan, tempat sampah, hidran
do
	local props = folder("Props")
	local trees = folder("Trees", props)
	local lights = folder("StreetLights", props)
	local misc = folder("Furniture", props)
	local leafs = { Color3.fromRGB(70, 150, 60), Color3.fromRGB(90, 165, 70), Color3.fromRGB(60, 135, 75) }

	local function rnd(i: number): number
		-- pseudo-acak deterministik supaya peta selalu sama
		return (math.sin(i * 12.9898) * 43758.5453) % 1
	end

	local n = 0
	local function addTree(pos: Vector3)
		n += 1
		tree("Pohon" .. n, pos, 0.9 + rnd(n) * 0.4, leafs[n % #leafs + 1], trees)
	end

	-- pohon di taman
	local pc = BLOCKS.Park
	for _, off in { { -30, -14 }, { -14, -30 }, { 30, -14 }, { 14, -30 }, { -30, 14 }, { -14, 30 }, { 30, 14 }, { 14, 30 }, { -38, -38 }, { 38, 38 } } do
		addTree(Vector3.new(pc.X + off[1], WALK_TOP + 0.2, pc.Z + off[2]))
	end
	-- pohon di trotoar jalan utama (z = 0) dan halaman belakang rumah sakit
	addTree(Vector3.new(62, WALK_TOP, -32))
	addTree(Vector3.new(62, WALK_TOP, -58))
	for _, x in { -28, -48, -76, -92 } do
		addTree(Vector3.new(x, WALK_TOP + 0.2, 25))
	end
	for _, x in { -90, -75, -45, -30 } do
		addTree(Vector3.new(x, WALK_TOP, -96))
	end
	-- pohon di halaman rumah
	for _, x in { -184, -152, -100, -68, -52, -20, 20, 52, 68, 100, 152, 184 } do
		addTree(Vector3.new(x, 0, 182))
	end
	-- pohon pinggir kota
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local r = 225 + rnd(i + 50) * 25
		addTree(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end

	-- lampu jalan di kedua sisi jalan utama dan jalan tengah
	local li = 0
	-- lengan lampu (lokal -Z) selalu menjorok ke arah jalan
	for _, x in { -160, -46, 64, 160 } do
		li += 1
		streetLight("Lampu" .. li, Vector3.new(x, WALK_TOP, -(HALF + 2)), math.pi, lights)
	end
	for _, x in { -170, -80, 62, 170 } do
		li += 1
		streetLight("Lampu" .. li, Vector3.new(x, WALK_TOP, HALF + 2), 0, lights)
	end
	for _, z in { -60, 60 } do
		li += 1
		streetLight("Lampu" .. li, Vector3.new(HALF + 2, WALK_TOP, z), math.pi / 2, lights)
		li += 1
		streetLight("Lampu" .. li, Vector3.new(-(HALF + 2), WALK_TOP, z + 20), -math.pi / 2, lights)
	end
	-- (lampu di sisi tanah berumput diturunkan ke y = 0)
	for _, l in lights:GetChildren() do
		local pole = (l :: Model).PrimaryPart :: BasePart
		local x, z = pole.Position.X, pole.Position.Z
		local onBlock = math.abs(x) < 104 and math.abs(z) < 104
		if not onBlock then
			(l :: Model):PivotTo((l :: Model):GetPivot() - Vector3.new(0, WALK_TOP, 0))
		end
	end

	-- tempat sampah & hidran
	for i, pos in { Vector3.new(24, 0, -20), Vector3.new(70, 0, -20), Vector3.new(-40, 0, -20), Vector3.new(-40, 0, 52) } do
		P({ Name = "TempatSampah" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2, 2), CFrame = CFrame.new(pos + Vector3.new(0, WALK_TOP + 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 140, 80), Parent = misc })
	end
	P({ Name = "Hidran", Size = Vector3.new(1.2, 2.5, 1.2), Position = Vector3.new(68, WALK_TOP + 1.25, 20), Color = Color3.fromRGB(220, 50, 40), Material = Enum.Material.Metal, Parent = misc })
	flush(props)
end

-- 7. Titik spawn (di jalan setapak taman, mengelilingi air mancur)
do
	local spawns = folder("Spawns")
	local c = BLOCKS.Park
	local top = WALK_TOP + 0.26
	for i, off in { Vector3.new(0, 0, 18), Vector3.new(0, 0, -18), Vector3.new(26, 0, 0), Vector3.new(-26, 0, 0) } do
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn" .. i
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0 -- tanpa force field, ini game ramah anak tanpa pertarungan
		s.Size = Vector3.new(6, 0.2, 6)
		s.Position = c + off + Vector3.new(0, top + 0.1, 0)
		s.Color = Color3.fromRGB(120, 200, 255)
		s.Material = Enum.Material.SmoothPlastic
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = spawns
	end
	flush(spawns)
end

-- 8. Pencahayaan siang cerah
do
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = 0.28
		atm.Haze = 1
		atm.Color = Color3.fromRGB(200, 220, 240)
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false -- terlalu berat & buram untuk mobile
	end
end

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(("[BuildTown] Kota kecil selesai: %d part"):format(count))
return count
