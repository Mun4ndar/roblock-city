--[[
	ROBLOCK CITY — Dealer mobil "ROBLOCK AUTO", versi 2 (showroom kaca dua lantai tinggi).
	Pakai (Studio, mode Edit): require(game.ServerStorage.MapBuilders.ModernDealer)()

	Mengganti HANYA isi Workspace.Map.Dealer: folder Showroom, Halaman, Iklan (dan membuang
	Canopy + baliho atap versi lama). Lot, DealerZone, garis Edge/BayLine dan lampu jalan
	(Yard.Lampu) tidak diganti. DisplaySlots tetap bertag VehicleDisplaySlot dengan atribut
	Order yang sama; hanya posisinya diatur ulang: slot 1-4 di halaman depan, slot 5-6 di
	dalam showroom di atas panggung bundar (VehicleService menaruh mobil sesuai urutan
	VehicleConfig.LIST, jadi dua mobil terakhir tampil di dalam).

	Papan iklan:
	  * Videotron dua sisi di tiang tunggal, sudut utara tepi jalan. Tiap sisi punya Frame
	    Slide1..SlideN; client AdScreenController (tag "AdScreen") menggantinya bergiliran.
	  * Totem ramping di sudut selatan, poster lampu di dinding samping, huruf nama di fasad.
	Nama dan harga di iklan dibaca dari VehicleConfig.LIST, jadi ikut berubah kalau data berubah.

	Koordinat memakai peta yang sudah dipadatkan: lahan x -98..-36, z 238..312, jalan di timur.
	Nama dan warna merek karangan sendiri (tidak ada merek asli).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local Format = require(Shared:WaitForChild("Format"))

local dealer = workspace.Map.Dealer
local T = 0.4 -- permukaan jalan / lahan
local ZC = 275

local GRAPHITE = Color3.fromRGB(40, 44, 52)
local WHITE = Color3.fromRGB(246, 247, 250)
local TEAL = Color3.fromRGB(0, 196, 190)
local AMBER = Color3.fromRGB(255, 176, 32)
local NAVY = Color3.fromRGB(12, 20, 36)
local DEEP = Color3.fromRGB(14, 70, 88)
local COOL = Color3.fromRGB(196, 236, 255)
local WARM = Color3.fromRGB(255, 244, 226)
local WOOD = Color3.fromRGB(186, 140, 96)
local GLASS = Color3.fromRGB(176, 214, 232)
local SOFT = Color3.fromRGB(200, 212, 225)

---------------------------------------------------------------- pembantu part
local function P(parent, name, x, y, z, sx, sy, sz, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(sx, sy, sz)
	p.Position = Vector3.new(x, y, z)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function deco(parent, name, x, y, z, sx, sy, sz, color, material, props)
	local p = P(parent, name, x, y, z, sx, sy, sz, color, material, props)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- silinder tegak (sumbu Y)
local function cyl(parent, name, x, y, z, diameter, height, color, material, collide)
	local p = P(parent, name, x, y, z, height, diameter, diameter, color, material, {
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})
	if not collide then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	return p
end

local function glass(parent, name, x, y, z, sx, sy, sz)
	-- SmoothPlastic, bukan Glass: material Glass menyembunyikan benda tembus pandang di baliknya
	return P(parent, name, x, y, z, sx, sy, sz, GLASS, Enum.Material.SmoothPlastic, {
		Transparency = 0.62,
		Reflectance = 0.16,
		CastShadow = false,
	})
end

-- strip neon; dengan range ikut menyala sebagai lampu malam (tag NightLight)
local function glow(parent, name, x, y, z, sx, sy, sz, color, range, brightness)
	local p = deco(parent, name, x, y, z, sx, sy, sz, color, Enum.Material.Neon)
	if range then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Parent = p
		CollectionService:AddTag(p, "NightLight")
	end
	return p
end

local function spot(part, face, range, brightness, angle)
	local l = Instance.new("SpotLight")
	l.Face = face
	l.Angle = angle or 80
	l.Range = range
	l.Brightness = brightness
	l.Color = WARM
	l.Parent = part
	CollectionService:AddTag(part, "NightLight")
end

---------------------------------------------------------------- pembantu papan (SurfaceGui)
local function surfaceGui(part, face, pps, lightInfluence)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = lightInfluence or 0.15
	g.Parent = part
	return g
end

local function frame(parent, pos, size, color, radius)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or WHITE
	if color == nil then
		f.BackgroundTransparency = 1
	end
	f.Position = pos
	f.Size = size
	f.Parent = parent
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(radius, 0)
		c.Parent = f
	end
	return f
end

local function text(parent, str, pos, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = str
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

local function gradient(f, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot
	g.Parent = f
end

local S = UDim2.fromScale
local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right

-- kotak logo teal berhuruf R (selalu persegi)
local function logoChip(parent, pos, size)
	local chip = frame(parent, pos, size, TEAL, 0.24)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = chip
	text(chip, "R", S(0, 0.06), S(1, 0.88), WHITE, Enum.Font.GothamBlack)
	return chip
end

-- gambar mobil sederhana dari Frame (badan, kabin, kaca, dua roda)
local function carIcon(parent, pos, size, color)
	local box = frame(parent, pos, size, nil)
	frame(box, S(0.2, 0.08), S(0.5, 0.5), color, 0.32)
	frame(box, S(0.27, 0.17), S(0.17, 0.24), COOL, 0.2)
	frame(box, S(0.47, 0.17), S(0.17, 0.24), COOL, 0.2)
	frame(box, S(0, 0.4), S(1, 0.36), color, 0.4)
	frame(box, S(0.9, 0.48), S(0.07, 0.1), AMBER, 0.5)
	for _, x in { 0.13, 0.67 } do
		local wheel = frame(box, S(x, 0.56), S(0.2, 0.4), NAVY, 0.5)
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.Parent = wheel
		local hub = frame(wheel, S(0.3, 0.3), S(0.4, 0.4), SOFT, 0.5)
		hub.ZIndex = 2
	end
	return box
end

local function priceChip(parent, pos, size, top, price, bottom)
	local chip = frame(parent, pos, size, AMBER, 0.12)
	text(chip, top, S(0.08, 0.08), S(0.84, 0.2), NAVY, Enum.Font.GothamBold)
	text(chip, price, S(0.05, 0.3), S(0.9, 0.46), NAVY, Enum.Font.GothamBlack)
	text(chip, bottom, S(0.08, 0.78), S(0.84, 0.16), NAVY, Enum.Font.GothamMedium)
	return chip
end

---------------------------------------------------------------- data kendaraan untuk iklan
local list = VehicleConfig.LIST
local cheapest, priciest = list[1], list[1]
for _, def in list do
	if def.price < cheapest.price then
		cheapest = def
	end
	if def.price > priciest.price then
		priciest = def
	end
end

---------------------------------------------------------------- bersihkan bagian lama
for _, name in { "Showroom", "Canopy", "Halaman", "Iklan" } do
	local old = dealer:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local yard = dealer.Yard
local OLD_YARD = { PylonPost = true, PylonSign = true, Hedge = true, Planter = true, SemakBulat = true }
for _, c in yard:GetChildren() do
	if OLD_YARD[c.Name] then
		c:Destroy()
	end
end

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = dealer
	return f
end
local show = folder("Showroom")
local court = folder("Halaman")
local ads = folder("Iklan")

---------------------------------------------------------------- gedung showroom
local bx0, bx1 = -97, -75 -- dalam 22 stud
local bz0, bz1 = 244, 306
local bl = bz1 - bz0
local xc = (bx0 + bx1) / 2
local FLOOR = T + 0.5 -- muka lantai
local GH = 15 -- tinggi kaca
local BH = 19 -- tinggi dinding (kaca + pita nama)
local FX = bx1 - 0.2 -- bidang kaca depan
local DOOR = 7 -- setengah lebar pintu masuk

P(show, "Floor", xc, T + 0.25, ZC, bx1 - bx0, 0.5, bl, Color3.fromRGB(236, 238, 242), Enum.Material.Marble)
deco(show, "FloorBand", bx1 - 2.2, FLOOR + 0.02, ZC, 0.5, 0.04, bl - 2, GRAPHITE)

-- dinding belakang dan sudut belakang: panel putih bersih dengan nat tipis
P(show, "BackWall", bx0 + 0.5, T + BH / 2, ZC, 1, BH, bl, WHITE)
for _, z in { bz0 + 0.5, bz1 - 0.5 } do
	P(show, "SideWall", bx0 + 5, T + BH / 2, z, 10, BH, 1, WHITE)
end
for z = bz0 + 7.75, bz1 - 1, 7.75 do
	deco(show, "Nat", bx0 + 1.02, T + BH / 2, z, 0.05, BH, 0.12, SOFT)
end

-- kaca membungkus sudut depan (sisi utara dan selatan)
for _, z in { bz0 + 0.2, bz1 - 0.2 } do
	glass(show, "Glass", (bx0 + 10 + bx1) / 2, T + GH / 2, z, bx1 - bx0 - 10, GH, 0.25)
	P(show, "PitaSamping", (bx0 + 10 + bx1) / 2, T + (GH + BH) / 2, z, bx1 - bx0 - 10, BH - GH, 0.6, WHITE)
end

-- fasad kaca tanpa bingkai: panel 8 stud dengan sirip kaca tipis, pintu masuk di tengah
for _, side in { -1, 1 } do
	local z0 = if side < 0 then bz0 + 0.4 else ZC + DOOR
	local z1 = if side < 0 then ZC - DOOR else bz1 - 0.4
	local n = 3
	local w = (z1 - z0) / n
	for i = 0, n - 1 do
		glass(show, "Glass", FX, T + GH / 2, z0 + (i + 0.5) * w, 0.25, GH, w - 0.12)
	end
	for i = 1, n - 1 do
		deco(show, "SiripKaca", FX - 0.5, T + GH / 2, z0 + i * w, 1, GH, 0.14, GLASS, Enum.Material.SmoothPlastic, { Transparency = 0.35 })
	end
end
P(show, "RelBawah", FX, T + 0.3, ZC - DOOR - (bl / 2 - DOOR) / 2, 0.4, 0.6, bl / 2 - DOOR, GRAPHITE, Enum.Material.Metal)
P(show, "RelBawah", FX, T + 0.3, ZC + DOOR + (bl / 2 - DOOR) / 2, 0.4, 0.6, bl / 2 - DOOR, GRAPHITE, Enum.Material.Metal)

-- gerbang masuk: bingkai grafit menjorok dengan garis LED, daun pintu kaca terbuka
local PH = 11 -- tinggi bukaan
for _, z in { ZC - DOOR - 0.6, ZC + DOOR + 0.6 } do
	P(show, "GerbangTiang", bx1 + 0.6, T + (PH + 1.2) / 2, z, 3.6, PH + 1.2, 1.2, GRAPHITE, Enum.Material.Metal)
end
P(show, "GerbangAtas", bx1 + 0.6, T + PH + 0.6, ZC, 3.6, 1.2, 2 * DOOR + 2.4, GRAPHITE, Enum.Material.Metal)
glow(show, "GerbangLed", bx1 + 2.42, T + PH - 0.05, ZC, 0.08, 0.14, 2 * DOOR, TEAL, 14, 0.8)
for _, z in { ZC - DOOR + 0.02, ZC + DOOR - 0.02 } do
	glow(show, "GerbangLed", bx1 + 2.42, T + PH / 2, z, 0.08, PH, 0.14, TEAL)
end
glass(show, "DoorTop", FX, T + (PH + 1.2 + GH) / 2, ZC, 0.25, GH - PH - 1.2, 2 * DOOR)
for _, z in { ZC - DOOR - 2.3, ZC + DOOR + 2.3 } do
	local leaf = glass(show, "DaunPintu", FX - 0.5, T + PH / 2, z, 0.2, PH, 4.4)
	leaf.CanCollide = false
end
deco(show, "DoorMat", bx1 + 1.2, T + 0.05, ZC, 5, 0.1, 2 * DOOR - 1, Color3.fromRGB(30, 34, 40), Enum.Material.Fabric)

-- pita nama di atas kaca: huruf gelap di panel putih, diterangi garis LED
local fascia = P(show, "Sign", bx1 - 0.3, T + (GH + BH) / 2, ZC, 0.8, BH - GH, bl, WHITE)
local fg = surfaceGui(fascia, Enum.NormalId.Right, 30, 0.35)
local mid = frame(fg, S(0.3, 0), S(0.4, 1), nil)
logoChip(mid, S(0.02, 0.14), S(0.12, 0.72))
text(mid, "ROBLOCK AUTO", S(0.17, 0.12), S(0.81, 0.76), NAVY, Enum.Font.GothamBlack, LEFT)
text(fg, "DEALER MOBIL", S(0.03, 0.3), S(0.2, 0.4), GRAPHITE, Enum.Font.GothamBold, LEFT)
text(fg, "SHOWROOM", S(0.77, 0.3), S(0.2, 0.4), GRAPHITE, Enum.Font.GothamBold, RIGHT)
glow(show, "SignStripe", bx1 + 0.14, T + GH + 0.1, ZC, 0.1, 0.16, bl, COOL)
for i, z in { 252, 298 } do
	glow(show, "LedPita" .. i, bx1 + 0.3, T + GH - 0.2, z, 0.2, 0.15, 14, COOL, 16, 0.9)
end

-- atap tipis melayang, menjorok 5 stud ke depan, plafon kayu di bagian yang menjorok
P(show, "Roof", (bx0 - 1 + bx1 + 5) / 2, T + BH + 0.35, ZC, bx1 - bx0 + 6, 0.7, bl + 2, WHITE)
deco(show, "RoofTrim", bx1 + 5.1, T + BH + 0.35, ZC, 0.3, 0.9, bl + 2.2, GRAPHITE, Enum.Material.Metal)
deco(show, "Plafon", bx1 + 2.6, T + BH - 0.03, ZC, 4.8, 0.08, bl + 1.6, WOOD, Enum.Material.WoodPlanks)
for i, z in { 250, 262.5, 287.5, 300 } do
	local d = deco(show, "LampuPlafon" .. i, bx1 + 2.6, T + BH - 0.12, z, 0.9, 0.12, 0.9, WARM, Enum.Material.Neon)
	spot(d, Enum.NormalId.Bottom, 24, 1.4, 70)
end

-- interior: dinding kayu berlogo, meja resepsionis, meja konsultasi, tanaman
local back = P(show, "LogoWall", bx0 + 1.25, FLOOR + 6.5, ZC, 0.5, 11, 15, WOOD, Enum.Material.WoodPlanks)
local bgui = surfaceGui(back, Enum.NormalId.Right, 30)
logoChip(bgui, S(0.42, 0.1), S(0.16, 0.3))
text(bgui, "ROBLOCK AUTO", S(0.06, 0.44), S(0.88, 0.26), WHITE, Enum.Font.GothamBlack)
text(bgui, "Mobil impianmu menunggu", S(0.1, 0.74), S(0.8, 0.12), WARM, Enum.Font.GothamMedium)
glow(show, "LogoGlow", bx0 + 1.55, FLOOR + 0.9, ZC, 0.1, 0.18, 15, WARM)

P(show, "Counter", bx0 + 6, FLOOR + 1.7, ZC, 2.6, 3.4, 11, WHITE)
deco(show, "CounterTop", bx0 + 6, FLOOR + 3.52, ZC, 3.2, 0.24, 11.6, GRAPHITE, Enum.Material.Marble)
glow(show, "CounterGlow", bx0 + 7.36, FLOOR + 0.5, ZC, 0.1, 0.22, 10.4, TEAL)
for _, z in { ZC - 3, ZC + 3 } do
	deco(show, "Layar", bx0 + 5.6, FLOOR + 4.5, z, 0.2, 1.5, 2.2, NAVY)
	deco(show, "LayarKaki", bx0 + 5.6, FLOOR + 3.75, z, 0.3, 0.3, 0.5, GRAPHITE, Enum.Material.Metal)
end

for _, z in { ZC - 5.5, ZC + 5.5 } do
	cyl(show, "MejaKaki", bx1 - 5, FLOOR + 1.1, z, 0.5, 2.2, GRAPHITE, Enum.Material.Metal, true)
	cyl(show, "MejaKonsultasi", bx1 - 5, FLOOR + 2.3, z, 4, 0.25, WHITE, nil, true)
	for _, dz in { -2.9, 2.9 } do
		cyl(show, "Bangku", bx1 - 5, FLOOR + 0.8, z + dz, 1.5, 1.6, TEAL, Enum.Material.Fabric, true)
	end
end

for _, pos in { { bx0 + 2.4, bz0 + 2.6 }, { bx0 + 2.4, bz1 - 2.6 }, { bx0 + 2.4, ZC - 10 }, { bx0 + 2.4, ZC + 10 } } do
	cyl(show, "PlantPot", pos[1], FLOOR + 0.9, pos[2], 2, 1.8, GRAPHITE, Enum.Material.Concrete, true)
	P(show, "PlantLeaves", pos[1], FLOOR + 3.2, pos[2], 3.2, 3.2, 3.2, Color3.fromRGB(70, 160, 80), Enum.Material.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
end

-- garis lampu langit-langit (redup: ruangan terang membuat layar putih)
for i, z in { 252, 267, 283, 298 } do
	glow(show, "LampuLangit" .. i, xc, T + BH - 0.1, z, 14, 0.12, 0.5, WARM, 16, 0.28)
end

-- dua panggung bundar untuk mobil unggulan (slot 5 dan 6)
local STAGE = { { z = 257, aim = 268 }, { z = 293, aim = 282 } }
local SX = -86
for i, st in STAGE do
	cyl(show, "Panggung" .. i, SX, FLOOR + 0.25, st.z, 19, 0.5, Color3.fromRGB(28, 31, 38), Enum.Material.Marble, true)
	cyl(show, "PanggungLed" .. i, SX, FLOOR + 0.1, st.z, 19.5, 0.14, TEAL, Enum.Material.Neon).CastShadow = false
	local lamp = cyl(show, "SorotPanggung" .. i, SX, T + BH - 0.3, st.z, 1.6, 0.4, GRAPHITE, Enum.Material.Metal)
	spot(lamp, Enum.NormalId.Left, 26, 1.6, 70) -- sumbu silinder = X lokal, setelah diputar Left menghadap bawah
end

-- poster lampu di dinding samping bagian belakang (terlihat dari luar)
local function poster(wallZ, face, title, tagline, def, color)
	local p = P(ads, "Poster", bx0 + 5, T + 9, wallZ, 8, 11, 0.3, NAVY)
	local g = surfaceGui(p, face, 30, 0)
	local bg = frame(g, S(0, 0), S(1, 1), NAVY)
	gradient(bg, NAVY, DEEP, 90)
	text(bg, title, S(0.08, 0.06), S(0.84, 0.13), TEAL, Enum.Font.GothamBlack, LEFT)
	text(bg, def.name, S(0.08, 0.19), S(0.84, 0.15), WHITE, Enum.Font.GothamBlack, LEFT)
	carIcon(bg, S(0.1, 0.38), S(0.8, 0.24), color)
	text(bg, tagline, S(0.08, 0.64), S(0.84, 0.08), COOL, Enum.Font.GothamMedium, LEFT)
	local chip = frame(bg, S(0.08, 0.76), S(0.84, 0.17), AMBER, 0.2)
	text(chip, Format.money(def.price), S(0.06, 0.12), S(0.88, 0.76), NAVY, Enum.Font.GothamBlack)
	for _, y in { 3.4, 14.6 } do
		glow(ads, "PosterLed", bx0 + 5, T + y, wallZ, 8.3, 0.14, 0.34, TEAL)
	end
end
poster(bz0 - 0.12, Enum.NormalId.Front, "PALING NGEBUT", "Ngebut dengan gaya!", priciest, Color3.fromRGB(235, 70, 70))
poster(bz1 + 0.12, Enum.NormalId.Back, "PALING HEMAT", "Irit, lincah, siap jalan!", cheapest, TEAL)

---------------------------------------------------------------- halaman depan
-- teras di depan kaca dan plaza masuk dari tepi jalan
deco(court, "Teras", bx1 + 2.5, T + 0.04, ZC, 5, 0.08, bl + 2, Color3.fromRGB(206, 209, 215), Enum.Material.Concrete)
deco(court, "Plaza", -55, T + 0.04, ZC, 35, 0.08, 18, Color3.fromRGB(206, 209, 215), Enum.Material.Concrete)
for _, z in { ZC - 9, ZC + 9 } do
	deco(court, "PlazaGaris", -55, T + 0.09, z, 35, 0.03, 0.3, TEAL)
end
for x = -68, -42, 6.5 do
	glow(court, "PlazaLampu", x, T + 0.1, ZC, 0.8, 0.05, 0.8, COOL)
end

-- alas pajangan: 4 di halaman, 2 di panggung dalam
local SLOT_X = -61
local OUT_Z = { 249, 260, 290, 301 }
local slots = dealer.DisplaySlots:GetChildren()
table.sort(slots, function(a, b)
	return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
end)
for i, slot in slots do
	for _, old in slot:GetChildren() do
		if old.Name == "Rim" then
			old:Destroy()
		end
	end
	if i <= #OUT_Z then
		local pos = Vector3.new(SLOT_X, T + 0.15, OUT_Z[i])
		slot.CFrame = CFrame.lookAt(pos, pos + Vector3.xAxis) -- depan mobil menghadap jalan
		slot.Color = Color3.fromRGB(30, 33, 40)
		slot.Material = Enum.Material.Slate
		slot.Transparency = 0
		slot.CanCollide = true
		for _, lx in { -4.4, 4.4 } do
			local r = deco(slot, "Rim", 0, 0, 0, 0.2, 0.06, 18, COOL, Enum.Material.Neon)
			r.CFrame = slot.CFrame * CFrame.new(lx, 0.17, 0)
		end
		for _, lz in { -8.9, 8.9 } do
			local r = deco(slot, "Rim", 0, 0, 0, 9, 0.06, 0.2, COOL, Enum.Material.Neon)
			r.CFrame = slot.CFrame * CFrame.new(0, 0.17, lz)
		end
	else
		local st = STAGE[i - #OUT_Z]
		if st then
			local pos = Vector3.new(SX, FLOOR + 0.5 - 0.13, st.z)
			slot.CFrame = CFrame.lookAt(pos, Vector3.new(-69, pos.Y, st.aim))
			slot.Transparency = 1
			slot.CanCollide = false
		end
	end
end

-- tiang lampu ramping di antara mobil pajangan
for i, z in { 243.6, 254.5, 265.4, 284.6, 295.5, 306.4 } do
	P(court, "TiangLampu", -51, T + 6.5, z, 0.45, 13, 0.45, GRAPHITE, Enum.Material.Metal)
	local arm = P(court, "LenganLampu" .. i, -53.2, T + 12.9, z, 5, 0.3, 0.6, GRAPHITE, Enum.Material.Metal, { CanCollide = false })
	local led = deco(court, "LedLampu" .. i, -53.6, T + 12.72, z, 3.6, 0.08, 0.4, WARM, Enum.Material.Neon)
	spot(led, Enum.NormalId.Bottom, 24, 2, 85)
	arm.CastShadow = false
end

-- bendera bilah di tepi jalan
for i, z in { 250, 261, 289, 300 } do
	local color = if i % 2 == 1 then TEAL else WHITE
	P(court, "TiangBendera", -38.5, T + 7, z, 0.3, 14, 0.3, GRAPHITE, Enum.Material.Metal)
	local flag = deco(court, "Bendera", -38.5, T + 8.6, z + 1.35, 0.12, 10, 2.4, color)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local g = surfaceGui(flag, face, 30)
		logoChip(g, S(0.14, 0.05), S(0.72, 0.2))
		frame(g, S(0.2, 0.3), S(0.6, 0.012), if color == TEAL then WHITE else TEAL)
		for k, ch in { "A", "U", "T", "O" } do
			text(g, ch, S(0.1, 0.34 + (k - 1) * 0.155), S(0.8, 0.14), if color == TEAL then WHITE else NAVY, Enum.Font.GothamBlack)
		end
	end
end

-- tanaman rapi di sisi utara dan selatan lahan
for _, z in { 236.5, 313.5 } do
	P(yard, "Planter", -71, 0.9, z, 54, 1, 2.8, GRAPHITE, Enum.Material.Concrete)
	local third = ServerStorage:FindFirstChild("AsetPihakKetiga")
	local bush = third and third:FindFirstChild("SemakBulat")
	if bush then
		local rng = Random.new(z)
		for x = -94.85, -47.15, 5.3 do
			local c = bush:Clone()
			c.Name = "SemakBulat"
			c:PivotTo(CFrame.new(x, 3.3 + rng:NextNumber(-0.1, 0.2), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			c.Parent = yard
		end
	else
		P(yard, "Hedge", -71, 2.3, z, 53, 2.2, 2.2, Color3.fromRGB(70, 150, 60), Enum.Material.Grass)
	end
end

---------------------------------------------------------------- videotron (papan iklan digital)
local VZ = 241.2
local VX = -53 -- tengah layar
local VW, VH = 30, 12
local VY = T + 24

cyl(ads, "VideotronTiang", -41, T + 9.2, VZ, 2.2, 18.4, GRAPHITE, Enum.Material.Metal, true)
P(ads, "VideotronDasar", -41, T + 0.4, VZ, 4.4, 0.8, 4.4, Color3.fromRGB(120, 124, 132), Enum.Material.Concrete)
P(ads, "VideotronBalok", VX + 4, T + 17.7, VZ, VW - 6, 1.2, 1.2, GRAPHITE, Enum.Material.Metal)
P(ads, "VideotronRumah", VX, VY, VZ, VW + 1.2, VH + 1.2, 1.5, Color3.fromRGB(20, 22, 27), Enum.Material.Metal)
for _, y in { VY - VH / 2 - 0.3, VY + VH / 2 + 0.3 } do
	for _, dz in { -0.78, 0.78 } do
		glow(ads, "VideotronLed", VX, y, VZ + dz, VW + 0.6, 0.12, 0.06, TEAL)
	end
end

local function slide(gui, index)
	local f = frame(gui, S(0, 0), S(1, 1), NAVY)
	f.Name = "Slide" .. index
	f.Visible = index == 1
	f.ClipsDescendants = true
	return f
end

local function screen(dz, face)
	local p = deco(ads, "VideotronLayar", VX, VY, VZ + dz, VW, VH, 0.1, Color3.fromRGB(8, 10, 14))
	CollectionService:AddTag(p, "AdScreen")
	p:SetAttribute("SlideSeconds", 6)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Range = 22
	light.Brightness = 0.7
	light.Angle = 120
	light.Color = COOL
	light.Parent = p
	CollectionService:AddTag(p, "NightLight")
	local g = surfaceGui(p, face, 28, 0)

	-- 1: merek + harga termurah
	local s1 = slide(g, 1)
	gradient(s1, NAVY, DEEP, 20)
	frame(s1, S(0.035, 0.14), S(0.008, 0.72), AMBER)
	logoChip(s1, S(0.06, 0.12), S(0.1, 0.24))
	text(s1, "ROBLOCK AUTO", S(0.06, 0.4), S(0.6, 0.3), WHITE, Enum.Font.GothamBlack, LEFT)
	text(s1, "Mobil impianmu, siap meluncur.", S(0.06, 0.72), S(0.6, 0.13), COOL, Enum.Font.GothamMedium, LEFT)
	priceChip(s1, S(0.71, 0.16), S(0.25, 0.68), "MULAI DARI", Format.money(cheapest.price), cheapest.name)

	-- 2: mobil unggulan
	local s2 = slide(g, 2)
	gradient(s2, Color3.fromRGB(34, 12, 40), Color3.fromRGB(150, 36, 60), 20)
	text(s2, "PALING NGEBUT", S(0.05, 0.1), S(0.5, 0.14), AMBER, Enum.Font.GothamBold, LEFT)
	text(s2, priciest.name, S(0.05, 0.26), S(0.5, 0.34), WHITE, Enum.Font.GothamBlack, LEFT)
	text(s2, "Ngebut dengan gaya!", S(0.05, 0.62), S(0.5, 0.13), WARM, Enum.Font.GothamMedium, LEFT)
	local c2 = frame(s2, S(0.05, 0.78), S(0.26, 0.15), AMBER, 0.3)
	text(c2, Format.money(priciest.price), S(0.06, 0.1), S(0.88, 0.8), NAVY, Enum.Font.GothamBlack)
	carIcon(s2, S(0.56, 0.2), S(0.4, 0.62), Color3.fromRGB(245, 245, 248))

	-- 3: daftar semua kendaraan
	local s3 = slide(g, 3)
	gradient(s3, DEEP, NAVY, 20)
	text(s3, "PILIHAN KENDARAAN", S(0.05, 0.07), S(0.6, 0.15), WHITE, Enum.Font.GothamBlack, LEFT)
	frame(s3, S(0.05, 0.24), S(0.9, 0.008), TEAL)
	local rows = math.ceil(#list / 2)
	for k, def in list do
		local col = (k - 1) // rows
		local row = (k - 1) % rows
		local y = 0.29 + row * (0.46 / rows)
		local h = 0.4 / rows
		text(s3, def.name, S(0.05 + col * 0.47, y), S(0.26, h), WHITE, Enum.Font.GothamBold, LEFT)
		text(s3, Format.money(def.price), S(0.31 + col * 0.47, y), S(0.15, h), AMBER, Enum.Font.GothamBlack, RIGHT)
	end
	local go = frame(s3, S(0.05, 0.8), S(0.9, 0.14), TEAL, 0.3)
	text(go, "Masuk dan pilih sendiri!", S(0.05, 0.14), S(0.9, 0.72), NAVY, Enum.Font.GothamBlack)
end
screen(-0.81, Enum.NormalId.Front)
screen(0.81, Enum.NormalId.Back)

---------------------------------------------------------------- totem di sudut selatan
local TZ = 309
P(ads, "TotemDasar", -39.5, T + 0.4, TZ, 3.4, 0.8, 5.4, GRAPHITE, Enum.Material.Concrete)
local tot = P(ads, "Totem", -39.5, T + 8.3, TZ, 1, 15, 4.4, WHITE)
P(ads, "TotemSisi", -39.5, T + 8.3, TZ - 2.35, 1.3, 15, 0.3, GRAPHITE, Enum.Material.Metal)
for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
	local g = surfaceGui(tot, face, 40, 0.3)
	local head = frame(g, S(0, 0), S(1, 0.36), NAVY)
	gradient(head, NAVY, DEEP, 90)
	logoChip(head, S(0.3, 0.1), S(0.4, 0.42))
	text(head, "ROBLOCK", S(0.06, 0.56), S(0.88, 0.17), WHITE, Enum.Font.GothamBlack)
	text(head, "AUTO", S(0.06, 0.74), S(0.88, 0.2), TEAL, Enum.Font.GothamBlack)
	text(g, "DEALER MOBIL", S(0.08, 0.39), S(0.84, 0.05), NAVY, Enum.Font.GothamBlack)
	frame(g, S(0.3, 0.455), S(0.4, 0.006), AMBER)
	for k, def in list do
		if k > 6 then
			break
		end
		text(g, def.name, S(0.08, 0.475 + (k - 1) * 0.062), S(0.84, 0.045), GRAPHITE, Enum.Font.GothamMedium)
	end
	local go = frame(g, S(0.1, 0.87), S(0.8, 0.09), TEAL, 0.25)
	text(go, "MASUK", S(0.1, 0.14), S(0.8, 0.72), WHITE, Enum.Font.GothamBlack)
end
glow(ads, "TotemTopi", -39.5, T + 15.95, TZ, 1.3, 0.25, 4.8, TEAL, 12, 0.8)

return #dealer:GetDescendants()
