--[[
	ROBLOCK CITY — Dealer mobil versi modern ("ROBLOCK AUTO").
	Pakai (Studio, mode Edit): require(game.ServerStorage.MapBuilders.ModernDealer)()
	Mengganti HANYA isi Workspace.Map.Dealer: Showroom, Canopy, tiang papan nama, pagar tanaman,
	dan menambah folder Iklan. Lot, DealerZone, DisplaySlots (tag VehicleDisplaySlot, posisi sama),
	garis Edge/BayLine dan lampu jalan (Yard.Lampu) tidak diganti, jadi VehicleService tetap jalan.
	Koordinat memakai peta yang sudah dipadatkan: lahan x -98..-36, z 238..312.
	Nama dan warna merek hanya karangan sendiri (tidak ada merek asli).
]]

local CollectionService = game:GetService("CollectionService")

local dealer = workspace.Map.Dealer
local T = 0.4 -- permukaan jalan
local ZC = 275

local GRAPHITE = Color3.fromRGB(44, 48, 56)
local WHITE = Color3.fromRGB(244, 246, 250)
local TEAL = Color3.fromRGB(0, 196, 190)
local AMBER = Color3.fromRGB(255, 176, 32)
local NAVY = Color3.fromRGB(14, 22, 38)
local COOL = Color3.fromRGB(190, 235, 255)

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

-- strip neon + PointLight yang menyala malam hari (tag NightLight, sama dengan lampu jalan)
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

local function surfaceGui(part, face, ppS)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS
	g.LightInfluence = 0.15
	g.Parent = part
	return g
end

local function frame(parent, pos, size, color, radius)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
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

-- panel logo: kotak teal berhuruf R + nama
local function logoPanel(gui)
	local bg = frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), NAVY)
	gradient(bg, NAVY, Color3.fromRGB(16, 74, 90), 90)
	local logo = frame(bg, UDim2.fromScale(0.34, 0.1), UDim2.fromScale(0.32, 0.32), TEAL, 0.22)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = logo
	text(logo, "R", UDim2.fromScale(0, 0.05), UDim2.fromScale(1, 0.9), WHITE, Enum.Font.GothamBlack)
	text(bg, "ROBLOCK", UDim2.fromScale(0.05, 0.5), UDim2.fromScale(0.9, 0.14), WHITE, Enum.Font.GothamBlack)
	text(bg, "AUTO", UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.18), TEAL, Enum.Font.GothamBlack)
	frame(bg, UDim2.fromScale(0.3, 0.86), UDim2.fromScale(0.4, 0.012), AMBER)
end

---------------------------------------------------------------- bersihkan bagian lama
for _, name in { "Showroom", "Canopy", "Iklan" } do
	local old = dealer:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local yard = dealer.Yard
for _, c in yard:GetChildren() do
	if c.Name == "PylonPost" or c.Name == "PylonSign" or c.Name == "Hedge" or c.Name == "Planter" or c.Name == "SemakBulat" then
		c:Destroy()
	end
end

local show = Instance.new("Folder")
show.Name = "Showroom"
show.Parent = dealer
local canopy = Instance.new("Folder")
canopy.Name = "Canopy"
canopy.Parent = dealer
local ads = Instance.new("Folder")
ads.Name = "Iklan"
ads.Parent = dealer

---------------------------------------------------------------- gedung showroom
local bx0, bx1 = -97, -80
local bz0, bz1 = 244, 306
local bh = 14
local bl = bz1 - bz0
local FX = bx1 - 0.3 -- bidang kaca depan

P(show, "Floor", (bx0 + bx1) / 2, T + 0.25, ZC, bx1 - bx0, 0.5, bl, Color3.fromRGB(232, 235, 240), Enum.Material.Marble)
P(show, "BackWall", bx0 + 0.5, T + bh / 2, ZC, 1, bh, bl, GRAPHITE, Enum.Material.Concrete)
local northWall = P(show, "SideWall", (bx0 + bx1) / 2, T + bh / 2, bz0 + 0.5, bx1 - bx0, bh, 1, GRAPHITE, Enum.Material.Concrete)
local southWall = P(show, "SideWall", (bx0 + bx1) / 2, T + bh / 2, bz1 - 0.5, bx1 - bx0, bh, 1, GRAPHITE, Enum.Material.Concrete)
for _, w in { { northWall, Enum.NormalId.Back }, { southWall, Enum.NormalId.Front } } do
	logoPanel(surfaceGui(w[1], w[2], 28))
end

-- atap datar menjorok ke depan + garis LED di bawah tepinya
P(show, "Roof", -87, T + bh + 0.45, ZC, 22, 0.9, bl + 2, WHITE)
P(show, "RoofTrim", -76.2, T + bh + 0.45, ZC, 0.5, 1.1, bl + 2, GRAPHITE)
for i, z in { 252, 275, 298 } do
	glow(show, "LedAtap" .. i, -76.6, T + bh - 0.15, z, 0.3, 0.25, 19, COOL, 16, 1)
end

-- fasad kaca dari lantai ke langit-langit, 6 petak, dua petak tengah jadi pintu masuk
local bays = 6
local bayL = bl / bays
local glassTop = 11
for i = 0, bays do
	if i == 3 then
		continue -- tengah = pintu masuk
	end
	P(show, "Mullion", FX, T + glassTop / 2, bz0 + i * bayL, 0.5, glassTop, 0.5, GRAPHITE, Enum.Material.Metal)
end
for i = 0, bays - 1 do
	local isDoor = i == 2 or i == 3
	local h = if isDoor then glassTop - 9.5 else glassTop - 0.5
	P(show, if isDoor then "DoorTop" else "Glass", FX, T + glassTop - h / 2, bz0 + (i + 0.5) * bayL, 0.25, h, bayL - 0.5, Color3.fromRGB(150, 205, 235), Enum.Material.Glass, { Transparency = 0.42, Reflectance = 0.12 })
end
P(show, "DoorHeader", FX, T + 9.25, bz0 + 3 * bayL, 0.6, 0.5, 2 * bayL, GRAPHITE, Enum.Material.Metal)
deco(show, "DoorMat", bx1 + 2, T + 0.05, bz0 + 3 * bayL, 3.5, 0.1, 2 * bayL - 2, Color3.fromRGB(30, 34, 40), Enum.Material.Fabric)
-- pita fasad tempat nama toko
local fascia = P(show, "Sign", bx1 - 0.5, T + 12.5, ZC, 1, 3, bl, GRAPHITE, Enum.Material.Metal)
local fg = surfaceGui(fascia, Enum.NormalId.Right, 30)
text(fg, "ROBLOCK AUTO", UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.34, 0.8), WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
frame(fg, UDim2.fromScale(0.385, 0.2), UDim2.fromScale(0.004, 0.6), TEAL)
text(fg, "Dealer Mobil  ·  Pilih, bayar, tancap gas", UDim2.fromScale(0.4, 0.22), UDim2.fromScale(0.57, 0.56), COOL, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
glow(show, "SignStripe", bx1 + 0.05, T + 10.95, ZC, 0.15, 0.2, bl, TEAL)

-- interior: logo di dinding belakang, meja resepsionis, ruang tunggu, tanaman, lampu langit-langit
local back = P(show, "LogoWall", bx0 + 1.2, T + 8, ZC, 0.4, 7, 26, NAVY)
local bg = frame(surfaceGui(back, Enum.NormalId.Right, 30), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), NAVY)
gradient(bg, NAVY, Color3.fromRGB(16, 74, 90), 0)
text(bg, "ROBLOCK AUTO", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.5), WHITE, Enum.Font.GothamBlack)
text(bg, "Mobil impianmu menunggu", UDim2.fromScale(0.05, 0.64), UDim2.fromScale(0.9, 0.2), TEAL, Enum.Font.GothamMedium)
glow(show, "LogoGlow", bx0 + 1.45, T + 4.3, ZC, 0.1, 0.2, 26, TEAL)

P(show, "Counter", bx0 + 5.5, T + 0.5 + 1.7, ZC, 3, 3.4, 14, WHITE)
deco(show, "CounterTop", bx0 + 5.5, T + 0.5 + 3.55, ZC, 3.8, 0.3, 14.8, Color3.fromRGB(196, 146, 96), Enum.Material.Wood)
glow(show, "CounterGlow", bx0 + 3.95, T + 1.4, ZC, 0.12, 0.3, 13, TEAL)

for _, z in { 253, 297 } do
	P(show, "SofaSeat", bx0 + 3.5, T + 1.1, z, 3.4, 1.2, 9, Color3.fromRGB(38, 110, 122), Enum.Material.Fabric)
	P(show, "SofaBack", bx0 + 2.3, T + 2.4, z, 1, 2.6, 9, Color3.fromRGB(30, 92, 104), Enum.Material.Fabric)
	P(show, "CoffeeTable", bx0 + 7.2, T + 0.95, z, 2.2, 0.9, 4, WHITE, Enum.Material.Glass, { Transparency = 0.3 })
end
for _, pos in { { bx0 + 2, 248 }, { bx0 + 2, 302 }, { bx1 - 2, 261 }, { bx1 - 2, 289 } } do
	P(show, "PlantPot", pos[1], T + 1.3, pos[2], 2, 1.6, 2, WHITE, Enum.Material.Concrete, { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
	P(show, "PlantLeaves", pos[1], T + 3.4, pos[2], 3.4, 3.4, 3.4, Color3.fromRGB(70, 160, 80), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
end
for i, z in { 258, 275, 292 } do
	glow(show, "LampuLangit" .. i, -89, T + bh - 0.1, z, 6, 0.15, 1.2, Color3.fromRGB(255, 248, 235), 14, 0.28)
end

---------------------------------------------------------------- kanopi + alas pajangan
local cx0, cx1 = -77, -55
local ch = 13
P(canopy, "CanopyRoof", (cx0 + cx1) / 2, T + ch, ZC, cx1 - cx0, 0.7, 70, WHITE)
P(canopy, "CanopyTrim", (cx0 + cx1) / 2, T + ch - 0.45, ZC, cx1 - cx0 + 0.4, 0.3, 70.4, GRAPHITE)
for _, z in { 241, 264, 286, 309 } do
	P(canopy, "Post", cx1 - 1, T + ch / 2, z, 0.9, ch, 0.9, GRAPHITE, Enum.Material.Metal)
end
for i, z in { 252, 275, 298 } do
	glow(canopy, "LedKanopi" .. i, cx1 - 0.05, T + ch - 0.75, z, 0.3, 0.25, 19, COOL, 14, 1)
end
local banner = P(canopy, "Banner", cx1 + 0.45, T + ch - 1.2, ZC, 0.5, 2.2, 70, GRAPHITE, Enum.Material.Metal)
local bgui = surfaceGui(banner, Enum.NormalId.Right, 28)
text(bgui, "MINI CAR  ·  SEDAN  ·  SUV  ·  SPORT  ·  SEDAN MEWAH  ·  MIO KARBU", UDim2.fromScale(0.02, 0.12), UDim2.fromScale(0.96, 0.76), WHITE, Enum.Font.GothamBold)

-- spotlight pajangan di atas tiap alas mobil
local firstZ = ZC - 5 * 11 / 2
for i = 1, 6 do
	local z = firstZ + (i - 1) * 11
	local fx = P(canopy, "Spot" .. i, -66, T + ch - 0.8, z, 0.9, 0.5, 0.9, GRAPHITE, Enum.Material.Metal)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 75
	l.Range = 26
	l.Brightness = 2.5
	l.Color = Color3.fromRGB(255, 244, 225)
	l.Parent = fx
	CollectionService:AddTag(fx, "NightLight")
end

-- alas pajangan: gelap dengan bingkai neon (posisi dan tag tidak diubah)
for _, slot in dealer.DisplaySlots:GetChildren() do
	slot.Color = Color3.fromRGB(34, 38, 46)
	slot.Material = Enum.Material.Slate
	local p = slot.Position
	for _, old in slot:GetChildren() do
		if old.Name == "Rim" then
			old:Destroy()
		end
	end
	for _, dz in { -4.4, 4.4 } do
		deco(slot, "Rim", p.X, p.Y + 0.17, p.Z + dz, 18, 0.06, 0.22, TEAL, Enum.Material.Neon)
	end
	for _, dx in { -8.9, 8.9 } do
		deco(slot, "Rim", p.X + dx, p.Y + 0.17, p.Z, 0.22, 0.06, 9, TEAL, Enum.Material.Neon)
	end
end

---------------------------------------------------------------- papan iklan
-- 1) baliho besar di atap, menghadap jalan (timur)
local bb = P(ads, "Baliho", -88.5, T + 24, ZC, 0.8, 10, 38, NAVY, Enum.Material.Metal)
for _, z in { 262, 288 } do
	P(ads, "BalihoTiang", -88.5, T + 19, z, 0.8, 8.2, 0.8, GRAPHITE, Enum.Material.Metal)
end
local g = surfaceGui(bb, Enum.NormalId.Right, 24)
local bback = frame(g, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), NAVY)
gradient(bback, NAVY, Color3.fromRGB(18, 78, 96), 0)
frame(bback, UDim2.fromScale(0.035, 0.14), UDim2.fromScale(0.012, 0.72), AMBER)
text(bback, "ROBLOCK AUTO", UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.62, 0.5), WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
text(bback, "Mobil impianmu, siap meluncur.", UDim2.fromScale(0.06, 0.62), UDim2.fromScale(0.62, 0.2), Color3.fromRGB(150, 230, 235), Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
local chip = frame(bback, UDim2.fromScale(0.72, 0.18), UDim2.fromScale(0.24, 0.64), AMBER, 0.12)
text(chip, "MULAI DARI", UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.84, 0.2), NAVY, Enum.Font.GothamBold)
text(chip, "$250", UDim2.fromScale(0.05, 0.32), UDim2.fromScale(0.9, 0.5), NAVY, Enum.Font.GothamBlack)
text(chip, "Skuter Mio Karbu", UDim2.fromScale(0.08, 0.8), UDim2.fromScale(0.84, 0.14), NAVY, Enum.Font.GothamMedium)
for _, y in { 19, 29 } do
	glow(ads, "BalihoBingkai", -88.05, T + y, ZC, 0.15, 0.25, 38.6, TEAL)
end
for _, z in { ZC - 19.1, ZC + 19.1 } do
	glow(ads, "BalihoBingkai", -88.05, T + 24, z, 0.15, 10.3, 0.25, TEAL)
end
for i, z in { 262, 275, 288 } do
	local fl = P(ads, "BalihoLampu" .. i, -87.2, T + 29.5, z, 1.2, 0.4, 1.2, GRAPHITE, Enum.Material.Metal)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Right
	l.Angle = 90
	l.Range = 18
	l.Brightness = 1.2
	l.Parent = fl
	CollectionService:AddTag(fl, "NightLight")
end

-- 2) dua tiang papan nama (totem) di tepi jalan, tampil dari kedua arah
for _, z in { 241, 309 } do
	P(ads, "TotemDasar", -39, T + 0.5, z, 4, 1, 3, GRAPHITE, Enum.Material.Concrete)
	local tot = P(ads, "Totem", -39, T + 9.5, z, 1.2, 17, 5, NAVY, Enum.Material.Metal)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local tg = surfaceGui(tot, face, 40)
		local tb = frame(tg, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), NAVY)
		gradient(tb, NAVY, Color3.fromRGB(16, 74, 90), 90)
		local logo = frame(tb, UDim2.fromOffset(40, 28), UDim2.fromOffset(120, 120), TEAL, 0.22)
		text(logo, "R", UDim2.fromScale(0, 0.05), UDim2.fromScale(1, 0.9), WHITE, Enum.Font.GothamBlack)
		text(tb, "ROBLOCK", UDim2.fromOffset(8, 160), UDim2.fromOffset(184, 38), WHITE, Enum.Font.GothamBlack)
		text(tb, "AUTO", UDim2.fromOffset(8, 198), UDim2.fromOffset(184, 54), TEAL, Enum.Font.GothamBlack)
		frame(tb, UDim2.fromOffset(60, 262), UDim2.fromOffset(80, 4), AMBER)
		text(tb, "DEALER MOBIL", UDim2.fromOffset(8, 276), UDim2.fromOffset(184, 26), COOL, Enum.Font.GothamBold)
		for k, n in { "Mio Karbu", "Mini Car", "Sedan", "SUV", "Sedan Mewah", "Sport" } do
			text(tb, n, UDim2.fromOffset(8, 316 + (k - 1) * 30), UDim2.fromOffset(184, 24), Color3.fromRGB(200, 212, 225), Enum.Font.GothamMedium)
		end
		local go = frame(tb, UDim2.fromOffset(20, 540), UDim2.fromOffset(160, 50), AMBER, 0.2)
		text(go, "MASUK  >>", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.76), NAVY, Enum.Font.GothamBlack)
	end
	glow(ads, "TotemTopi", -39, T + 18.1, z, 1.5, 0.3, 5.4, TEAL, 12, 0.8)
end

-- 3) tanaman rapi di sisi utara dan selatan lahan
for _, z in { 236.5, 313.5 } do
	P(yard, "Planter", -71, 0.9, z, 54, 1, 2.8, GRAPHITE, Enum.Material.Concrete)
	-- deretan semak mesh (template ServerStorage.AsetPihakKetiga.SemakBulat); cadangan: pagar balok
	local bush = game:GetService("ServerStorage"):FindFirstChild("AsetPihakKetiga")
		and game.ServerStorage.AsetPihakKetiga:FindFirstChild("SemakBulat")
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

return #dealer:GetDescendants()
