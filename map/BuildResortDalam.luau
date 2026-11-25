--!strict
--[[
	ROBLOCK CITY: interior Resort (hotel) + kolam renang air terrain asli.
	Mesh dibuat di Blender: tools/blender/resort.py (luar, lobi berongga; asset 116461016625763 -> ServerStorage.ResortMentah)
	dan tools/blender/resort_dalam.py (interior; asset 137121780971623 -> ServerStorage.ResortDalamMentah).
	Data tabrakan/kursi/lampu otomatis: map/ResortDalamData.luau (modul saudara di ServerStorage.MapBuilders).

	Dipasang di Workspace.Map.BangunanBlender.ROBLOCKResort.Dalam. Koordinat Blender (x, y, z) -> dunia: BASE * (x, z, -y),
	BASE = CFrame(1249, 1, -460) * yaw -pi/2 (depan resort menghadap +X, ke kolam).
	Jalankan: require(MapBuilders.BuildResortDalam)() lalu ("kolam") untuk kolam saja.
	Urutan: BuildBangunanModern("resort") dulu (mesh luar baru), lalu skrip ini.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BASE = CFrame.new(1249, 1, -460) * CFrame.Angles(0, -math.pi / 2, 0)
local BBOX_CENTER_BL = Vector3.new(0.15, -0.025, 5.45)
local F = 1.0
local IX, IY = 67.5, 17.5

local rgb = Color3.fromRGB
local M = Enum.Material
local SP, MET, WOOD, MAR, FAB, GLS, NEON, CON =
	M.SmoothPlastic, M.Metal, M.Wood, M.Marble, M.Fabric, M.Glass, M.Neon, M.Concrete

local LOOK: { [string]: { any } } = {
	RdFloorA = { rgb(240, 234, 220), MAR, 0 },
	RdFloorB = { rgb(70, 92, 100), MAR, 0 },
	RdWood = { rgb(168, 122, 78), M.WoodPlanks, 0 },
	RdWoodD = { rgb(96, 62, 40), WOOD, 0 },
	RdWoodL = { rgb(196, 150, 100), WOOD, 0 },
	RdCarpet = { rgb(30, 110, 120), FAB, 0 },
	RdCarpetB = { rgb(40, 140, 150), FAB, 0 },
	RdGoldT = { rgb(226, 172, 52), MET, 0 },
	RdRug = { rgb(24, 128, 138), FAB, 0 },
	RdRugB = { rgb(246, 232, 200), FAB, 0 },
	RdPanel = { rgb(150, 104, 64), WOOD, 0 },
	RdPanelL = { rgb(190, 140, 90), WOOD, 0 },
	RdTeal = { rgb(30, 160, 170), SP, 0 },
	RdWall = { rgb(244, 240, 232), SP, 0 },
	RdMarble = { rgb(236, 232, 224), MAR, 0 },
	RdNeon = { rgb(255, 232, 180), NEON, 0 },
	RdNeonB = { rgb(120, 230, 240), NEON, 0 },
	RdSteel = { rgb(196, 202, 208), MET, 0 },
	RdSteelD = { rgb(90, 98, 108), MET, 0 },
	RdScreen = { rgb(90, 170, 255), NEON, 0 },
	RdRopeR = { rgb(180, 30, 40), FAB, 0 },
	RdMetalD = { rgb(60, 64, 72), MET, 0 },
	RdPot = { rgb(186, 98, 64), SP, 0 },
	RdSoil = { rgb(70, 50, 36), SP, 0 },
	RdLeaf = { rgb(62, 150, 70), SP, 0 },
	RdFlower = { rgb(250, 120, 150), SP, 0 },
	RdFlowerB = { rgb(255, 214, 80), SP, 0 },
	RdSofa = { rgb(36, 120, 130), FAB, 0 },
	RdSofaB = { rgb(54, 150, 158), FAB, 0 },
	RdGlassT = { rgb(180, 225, 240), GLS, 0.4 },
	RdPaper = { rgb(250, 246, 236), SP, 0 },
	RdLinen = { rgb(252, 250, 244), FAB, 0 },
	RdPlate = { rgb(255, 255, 255), SP, 0 },
	RdTealCush = { rgb(30, 150, 160), FAB, 0 },
	RdFood = { rgb(220, 120, 60), SP, 0 },
	RdFoodB = { rgb(240, 200, 70), SP, 0 },
	RdFoodC = { rgb(110, 170, 80), SP, 0 },
	RdFoodD = { rgb(200, 70, 60), SP, 0 },
	RdDark = { rgb(30, 32, 38), SP, 0 },
	RdMirror = { rgb(196, 220, 230), MET, 0 },
	RdBottleA = { rgb(240, 150, 60), GLS, 0.2 },
	RdBottleB = { rgb(120, 200, 100), GLS, 0.2 },
	RdBottleC = { rgb(240, 90, 120), GLS, 0.2 },
	RdBottleD = { rgb(255, 230, 120), GLS, 0.2 },
	RdBook1 = { rgb(190, 60, 60), SP, 0 },
	RdBook2 = { rgb(60, 110, 180), SP, 0 },
	RdBook3 = { rgb(80, 150, 90), SP, 0 },
	RdBook4 = { rgb(230, 190, 70), SP, 0 },
	RdKidsMat = { rgb(120, 190, 240), FAB, 0 },
	RdKid1 = { rgb(250, 90, 90), SP, 0 },
	RdKid2 = { rgb(250, 210, 70), SP, 0 },
	RdKid3 = { rgb(90, 190, 110), SP, 0 },
	RdKid4 = { rgb(100, 140, 240), SP, 0 },
	RdBulb = { rgb(255, 236, 190), NEON, 0 },
	RdCrystal = { rgb(235, 245, 255), GLS, 0.3 },
}

local function W(x: number, y: number, z: number): CFrame
	return BASE * CFrame.new(x, z, -y)
end

local function newPart(model: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

-- ---------------------------------------------------------------- papan teks (SurfaceGui)
local NAVY, CREAM, GOLD, TEAL = rgb(20, 70, 90), rgb(250, 246, 232), rgb(226, 172, 52), rgb(30, 160, 170)

local function board(model: Instance, name: string, at: Vector3, face: Vector2, w: number, h: number, title: string, lines: { string }?)
	local pos = Vector3.new(at.X, at.Z, -at.Y)
	local part = newPart(model, name, Vector3.new(w, h, 0.15), BASE * CFrame.lookAt(pos, pos + Vector3.new(face.X, 0, -face.Y)))
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Color = NAVY
	part.Material = SP
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(w * 100, h * 100)
	g.LightInfluence = 0.15
	g.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = CREAM
	bg.BorderSizePixel = 0
	bg.Parent = g
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, if lines then 70 else math.floor(h * 100))
	head.BackgroundColor3 = NAVY
	head.BorderSizePixel = 0
	head.Parent = bg
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = title
	t.TextColor3 = rgb(255, 236, 170)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Parent = head
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = if lines then 38 else math.floor(h * 100 * 0.6)
	lim.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = t
	if lines then
		local strip = Instance.new("Frame")
		strip.Position = UDim2.fromOffset(0, 70)
		strip.Size = UDim2.new(1, 0, 0, 6)
		strip.BackgroundColor3 = GOLD
		strip.BorderSizePixel = 0
		strip.Parent = bg
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(22, 90)
		body.Size = UDim2.new(1, -44, 1, -104)
		body.Text = table.concat(lines, "\n")
		body.TextColor3 = rgb(36, 44, 60)
		body.Font = Enum.Font.GothamMedium
		body.TextSize = 24
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.LineHeight = 1.15
		body.Parent = bg
	end
	return part
end

-- ---------------------------------------------------------------- pintu kaca berengsel (DoorService)
local function door(model: Instance, name: string, side: number)
	local hx, hy = side * 4.5, 18.25 -- engsel di tengah dinding depan (y 17.5..19)
	local bottom, height, width = F, 7.5, 4.5
	local zc = bottom + height / 2
	local dm = Instance.new("Model")
	dm.Name = name
	local cxl = hx - side * width / 2 -- panel terbentang dari engsel ke arah tengah
	local function piece(partName: string, sx: number, sy: number, sz: number, ox: number, oy: number, oz: number, color: Color3, mat: Enum.Material, tr: number)
		-- ukuran Blender (x lebar, y tebal, z tinggi); offset dalam Blender
		local p = newPart(dm, partName, Vector3.new(sx, sz, sy), W(cxl + ox, hy + oy, zc + oz))
		p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
		p.Color, p.Material, p.Transparency = color, mat, tr
		return p
	end
	local gold = rgb(226, 172, 52)
	local glass = piece("Kaca", width - 0.5, 0.12, height - 0.9, 0, 0, 0.1, rgb(150, 205, 235), GLS, 0.45)
	piece("RelAtas", width, 0.28, 0.4, 0, 0, height / 2 - 0.2, gold, MET, 0)
	piece("RelBawah", width, 0.28, 0.8, 0, 0, -height / 2 + 0.4, gold, MET, 0)
	piece("TiangEngsel", 0.25, 0.28, height, -side * (width / 2 - 0.125), 0, 0, gold, MET, 0)
	piece("TiangTengah", 0.25, 0.28, height, side * (width / 2 - 0.125), 0, 0, gold, MET, 0)
	piece("Gagang", 0.18, 0.18, 2.6, side * (width / 2 - 0.55), 0.3, 0, gold, MET, 0)
	dm.PrimaryPart = glass
	local hinge = (BASE * CFrame.new(hx, zc, -hy)).Position
	dm:SetAttribute("HingeX", hinge.X)
	dm:SetAttribute("HingeY", hinge.Y)
	dm:SetAttribute("HingeZ", hinge.Z)
	dm:SetAttribute("OpenDeg", if side < 0 then 100 else -100)
	dm:SetAttribute("Radius", 14)
	CollectionService:AddTag(dm, "SwingDoor")
	dm.Parent = model
end

-- ---------------------------------------------------------------- kolam renang (air terrain)
local POOL_C = Vector3.new(1304, 0, -460) -- tengah kolam (X, -, Z)
local POOL_SIZE = Vector2.new(26, 70) -- X, Z
local DECK = Vector2.new(56, 110)

local function pool(): string
	local resort = Workspace.Map.Beach:FindFirstChild("Resort")
	if resort == nil then
		return "Map.Beach.Resort tidak ada"
	end
	local oldWater = resort:FindFirstChild("PoolWater")
	if oldWater then
		oldWater:Destroy()
	end
	local deck = resort:FindFirstChild("PoolDeck") :: BasePart?
	if deck and deck.Size.X > 40 then
		local color, material = deck.Color, deck.Material
		deck:Destroy()
		local function strip(sx: number, sz: number, cx: number, cz: number)
			local p = Instance.new("Part")
			p.Name = "PoolDeck"
			p.Anchored = true
			p.Size = Vector3.new(sx, 0.6, sz)
			p.Position = Vector3.new(cx, 0.3, cz)
			p.Color, p.Material = color, material
			p.Parent = resort
		end
		local sideW = (DECK.X - POOL_SIZE.X) / 2
		local endL = (DECK.Y - POOL_SIZE.Y) / 2
		strip(sideW, DECK.Y, POOL_C.X - POOL_SIZE.X / 2 - sideW / 2, POOL_C.Z)
		strip(sideW, DECK.Y, POOL_C.X + POOL_SIZE.X / 2 + sideW / 2, POOL_C.Z)
		strip(POOL_SIZE.X, endL, POOL_C.X, POOL_C.Z - POOL_SIZE.Y / 2 - endL / 2)
		strip(POOL_SIZE.X, endL, POOL_C.X, POOL_C.Z + POOL_SIZE.Y / 2 + endL / 2)
	end
	local T = Workspace.Terrain
	-- cangkang beton, rongga udara, lalu air; tepi atas kolam di y 0.6 (sama dengan dek)
	T:FillBlock(CFrame.new(POOL_C.X, -3, POOL_C.Z), Vector3.new(POOL_SIZE.X + 6, 10, POOL_SIZE.Y + 6), M.Concrete)
	T:FillBlock(CFrame.new(POOL_C.X, -0.75, POOL_C.Z), Vector3.new(POOL_SIZE.X, 7.5, POOL_SIZE.Y), M.Air)
	T:FillBlock(CFrame.new(POOL_C.X, -2.1, POOL_C.Z), Vector3.new(POOL_SIZE.X, 4.8, POOL_SIZE.Y), M.Water)
	-- tepi kolam (bibir beton) sebagai part supaya rapi
	local rim = resort:FindFirstChild("TepiKolam") or Instance.new("Folder")
	rim.Name = "TepiKolam"
	rim:ClearAllChildren()
	rim.Parent = resort
	local function lip(sx: number, sz: number, cx: number, cz: number)
		local p = Instance.new("Part")
		p.Name = "BibirKolam"
		p.Anchored = true
		p.Size = Vector3.new(sx, 0.25, sz)
		p.Position = Vector3.new(cx, 0.72, cz)
		p.Color, p.Material = rgb(250, 249, 245), CON
		p.Parent = rim
	end
	lip(1.2, POOL_SIZE.Y + 2.4, POOL_C.X - POOL_SIZE.X / 2 - 0.6, POOL_C.Z)
	lip(1.2, POOL_SIZE.Y + 2.4, POOL_C.X + POOL_SIZE.X / 2 + 0.6, POOL_C.Z)
	lip(POOL_SIZE.X, 1.2, POOL_C.X, POOL_C.Z - POOL_SIZE.Y / 2 - 0.6)
	lip(POOL_SIZE.X, 1.2, POOL_C.X, POOL_C.Z + POOL_SIZE.Y / 2 + 0.6)
	return "kolam selesai"
end

-- ---------------------------------------------------------------- interior
local function interior(): string
	local raw = ServerStorage:FindFirstChild("ResortDalamMentah")
	local resortModel = Workspace.Map.BangunanBlender:FindFirstChild("ROBLOCKResort")
	local dataModule = script.Parent:FindFirstChild("ResortDalamData")
	if raw == nil or resortModel == nil or dataModule == nil then
		return "ResortDalamMentah / ROBLOCKResort / ResortDalamData tidak ada"
	end
	local data = require(dataModule :: ModuleScript) :: any

	local old = resortModel:FindFirstChild("Dalam")
	if old then
		old:Destroy()
	end
	local lobbyOld = resortModel:FindFirstChild("Lobby")
	if lobbyOld then
		lobbyOld:Destroy()
	end

	-- pusat kotak mesh mentah (rotasi-aware, lihat BuildBalaiKota)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local r, s = part.CFrame.Rotation, part.Size / 2
			local half = Vector3.new(
				math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z,
				math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z,
				math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z
			)
			mn = mn:Min(part.Position - half)
			mx = mx:Max(part.Position + half)
		end
	end
	local rawCenter = (mn + mx) / 2
	local center = BASE * CFrame.new(BBOX_CENTER_BL.X, BBOX_CENTER_BL.Z, -BBOX_CENTER_BL.Y)

	local model = Instance.new("Model")
	model.Name = "Dalam"
	local count = 0
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local look = key and LOOK[key]
			if look then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Name = key :: string
				local r0 = select(2, part.CFrame:ToOrientation())
				local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)
				clone.CFrame = center * CFrame.Angles(0, undo, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
				clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
				clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CastShadow = true, false, false, false
				clone.CastShadow = key == "RdWall" or key == "RdPanel"
				clone.Parent = model
				count += 1
			end
		end
	end

	local colliders = Instance.new("Folder")
	colliders.Name = "Tabrakan"
	colliders.Parent = model
	local function box(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		local p = newPart(colliders, name, Vector3.new(x1 - x0, z1 - z0, y1 - y0), W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		p.Transparency = 1
		p.CastShadow = false
	end
	-- cangkang lobi: lantai, atap, dinding (dinding depan berbukaan, sama dengan tools/blender/resort.py)
	box("Lantai", -69, 69, -19, 17.6, 0, F)
	box("Ambang1", -4.5, 4.5, 17.5, 19.2, 0, F)
	box("Ambang2", -4.5, 4.5, 19.2, 22, 0, 0.5)
	box("Atap", -70, 70, -20, 20, 10, 11)
	box("DindingBelakang", -69, 69, -19, -17.5, 0, 10)
	box("DindingKiri", -69, -67.5, -19, 19, 0, 10)
	box("DindingKanan", 67.5, 69, -19, 19, 0, 10)
	for _, s in { -1, 1 } do
		local a, b = s * 4.5, s * 17
		box("TiangDepan", math.min(a, b), math.max(a, b), 17.5, 19, 0, 10)
		box("TiangUjung", math.min(s * 67, s * 69), math.max(s * 67, s * 69), 17.5, 19, 0, 10)
		box("AmbangJendela", math.min(s * 17, s * 67), math.max(s * 17, s * 67), 17.5, 19, 8.8, 10)
		box("PagarKaca", math.min(s * 17, s * 67), math.max(s * 17, s * 67), 17.5, 19, 0, 1.4)
	end
	box("AmbangPintu", -4.5, 4.5, 17.5, 19, 8.6, 10)
	for _, s in data.SOLIDS do
		box(s[1], s[2], s[3], s[4], s[5], s[6], s[7])
	end

	-- kursi (Seat tak terlihat, menghadap arah yaw Blender)
	local seats = Instance.new("Folder")
	seats.Name = "Kursi"
	seats.Parent = model
	for _, s in data.SEATS do
		local yaw = math.rad(s[5])
		local lp = Vector3.new(s[2], s[4] - 0.2, -s[3])
		local seat = Instance.new("Seat")
		seat.Name = s[1]
		seat.Anchored = true
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.CFrame = BASE * CFrame.lookAt(lp, lp + Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)))
		seat.Transparency = 1
		seat.CanQuery = false
		seat.CastShadow = false
		seat.Parent = seats
	end

	-- lampu redup (ruang besar: kecerahan rendah)
	local lights = Instance.new("Folder")
	lights.Name = "Lampu"
	lights.Parent = model
	for _, l in data.LAMPS do
		local p = newPart(lights, "Lampu", Vector3.new(0.5, 0.5, 0.5), W(l[1], l[2], l[3]))
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
		local pl = Instance.new("PointLight")
		pl.Brightness = 0.32
		pl.Range = 26
		pl.Color = rgb(255, 232, 196)
		pl.Shadows = false
		pl.Parent = p
	end

	-- pintu kaca masuk
	door(model, "PintuKacaKiri", -1)
	door(model, "PintuKacaKanan", 1)

	-- papan info
	board(model, "PapanFasilitas", Vector3.new(-21.85, -11.5, 6.2), Vector2.new(1, 0), 6.5, 4.4, "FASILITAS", {
		"• Kolam renang di depan resort",
		"• Restoran Samudra (kiri)",
		"• Bar Jus & Kopi (kanan)",
		"• Pojok anak dan perpustakaan",
		"• Lift ke kamar tamu",
	})
	board(model, "PapanLayanan", Vector3.new(21.85, -11.5, 6.2), Vector2.new(-1, 0), 6.5, 4.4, "LAYANAN TAMU", {
		"Check-in: meja Resepsionis",
		"Tanya info: Concierge",
		"Bagasi: dibantu Bellboy",
		"Makan: pesan di Restoran",
		"Buka setiap hari, ramah anak",
	})
	board(model, "PapanPeta", Vector3.new(-21.85, 11.5, 6.2), Vector2.new(1, 0), 6.5, 4.4, "PULAU PANTAI", {
		"Dermaga dan bianglala",
		"Sewa Jet Ski dan tantangan cincin",
		"Kafe Pantai: musik dan penari",
		"Pelabuhan kapal",
		"Pantai berpasir dan payung",
	})
	board(model, "PapanTips", Vector3.new(21.85, 11.5, 6.2), Vector2.new(-1, 0), 6.5, 4.4, "TIPS TAMU", {
		"Berenang di kolam, tapi hati-hati",
		"Duduk di sofa dengan tekan E",
		"Jajan di restoran dan bar",
		"Sapa staf dengan ramah",
		"Jangan berlarian di lobi",
	})
	board(model, "PapanRestoran", Vector3.new(-43, -IY + 0.05, 8.9), Vector2.new(0, 1), 11, 1.5, "RESTORAN SAMUDRA", nil)
	board(model, "PapanBar", Vector3.new(46, -IY + 0.05, 9.25), Vector2.new(0, 1), 11, 1.0, "BAR JUS & KOPI", nil)
	board(model, "PapanResepsionis", Vector3.new(0, -9.45, 5.6), Vector2.new(0, 1), 5, 0.9, "RESEPSIONIS · CHECK-IN", nil)
	board(model, "PapanConcierge", Vector3.new(-15, -4.0, 4.95), Vector2.new(0, 1), 3.4, 0.7, "CONCIERGE", nil)

	-- titik interaksi: check-in, concierge, jajan restoran dan bar (FoodService membuat prompt-nya)
	local function spot(name: string, x: number, y: number, z: number, tag: string, attrs: { [string]: any })
		local p = newPart(model, name, Vector3.new(2, 1, 2), W(x, y, z))
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
		CollectionService:AddTag(p, tag)
	end
	spot("TitikCheckIn", 0, -7.4, F + 4.2, "ResortCheckIn", {})
	spot("TitikConcierge", -15, -2.6, F + 4.0, "ResortConcierge", {})
	for _, x in { -60, -49, -38 } do
		spot("TitikRestoran", x, -10.5, F + 4.0, "FoodStall", { StallMenu = "restoran", StallName = "Restoran Samudra" })
	end
	for _, x in { 34, 46, 58 } do
		spot("TitikBar", x, -10.5, F + 4.0, "FoodStall", { StallMenu = "barJus", StallName = "Bar Jus & Kopi" })
	end

	model.Parent = resortModel
	return `interior: {count} mesh, {#data.SOLIDS} kotak tabrakan, {#data.SEATS} kursi`
end

return function(only: string?): string
	local out = {}
	if only == nil or only == "kolam" then
		table.insert(out, pool())
	end
	if only == nil or only == "dalam" then
		table.insert(out, interior())
	end
	return table.concat(out, "; ")
end
