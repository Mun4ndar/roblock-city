--!strict
--[[
	ROBLOCK CITY: interior Balai Kota (dibuat di Blender: tools/blender/balai_kota_dalam.py -> balai_kota_dalam.fbx,
	asset 110634041164361, dipasang di ServerStorage.BalaiKotaDalamMentah). Lukisan dirender di Blender
	(tools/blender/lukisan_balai_kota.py) dan diunggah sebagai Image.
	Dipasang di Workspace.Map.BangunanBlender.BalaiKota.Dalam (ikut Balai Kota; cangkangnya berongga, lihat BuildBalaiKota).
	Isi: lantai marmer, air mancur tengah, meja resepsionis, loket, ruang walikota, sayap pelayanan, bingkai lukisan
	dan papan info (SurfaceGui), lampu gantung (PointLight redup), percikan air mancur, kotak tabrakan perabot.
	Koordinat Blender -> dunia: ORIGIN + (x, z, -y).
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(160, 1, 135)
local BBOX_CENTER_BL = Vector3.new(0, -1.6, 11.25) -- pusat kotak mesh interior di Blender

local function W(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, z, -y)
end

type Look = { Color3, Enum.Material, number }
local rgb = Color3.fromRGB
local M = Enum.Material
local LOOK: { [string]: Look } = {
	IFloorA = { rgb(238, 234, 224), M.Marble, 0 },
	IFloorB = { rgb(92, 102, 118), M.Marble, 0 },
	IParquet = { rgb(176, 124, 72), M.WoodPlanks, 0 },
	IGold = { rgb(226, 172, 52), M.Metal, 0 },
	IRug = { rgb(150, 28, 36), M.Fabric, 0 },
	IRugB = { rgb(40, 70, 130), M.Fabric, 0 },
	IStone = { rgb(226, 220, 208), M.Marble, 0 },
	IWater = { rgb(110, 200, 235), M.SmoothPlastic, 0.35 },
	IPanel = { rgb(122, 80, 50), M.Wood, 0 },
	INeon = { rgb(255, 240, 200), M.Neon, 0 },
	IWood = { rgb(150, 100, 60), M.Wood, 0 },
	IWoodD = { rgb(96, 62, 40), M.Wood, 0 },
	IWoodL = { rgb(190, 140, 90), M.Wood, 0 },
	IDark = { rgb(40, 44, 52), M.SmoothPlastic, 0 },
	IScreen = { rgb(90, 170, 255), M.Neon, 0 },
	IPaper = { rgb(245, 245, 240), M.SmoothPlastic, 0 },
	IBlue = { rgb(46, 80, 140), M.Fabric, 0 },
	IPot = { rgb(186, 98, 64), M.SmoothPlastic, 0 },
	ILeaf = { rgb(62, 140, 62), M.SmoothPlastic, 0 },
	IRed = { rgb(150, 30, 36), M.Fabric, 0 },
	IFlag1 = { rgb(30, 110, 180), M.Fabric, 0 },
	IFlag2 = { rgb(240, 190, 40), M.Fabric, 0 },
	IBook1 = { rgb(190, 60, 60), M.SmoothPlastic, 0 },
	IBook2 = { rgb(60, 110, 180), M.SmoothPlastic, 0 },
	IBook3 = { rgb(80, 150, 90), M.SmoothPlastic, 0 },
	IMetal = { rgb(150, 160, 170), M.Metal, 0 },
	IFrameBack = { rgb(50, 40, 34), M.SmoothPlastic, 0 },
}

-- kotak tabrakan perabot (Blender: nama, x0, x1, y0, y1, z0, z1)
local SOLIDS: { { any } } = {
	{ "Air mancur", -5.5, 5.5, -6.5, 4.5, 1.3, 2.5, "cyl" },
	{ "MejaResepsionis", -6.8, 6.8, -9.2, -7.0, 1.3, 4.5 },
	{ "MejaLoketKiri", -14.5, -9.5, 5.2, 6.8, 1.3, 4.2 },
	{ "MejaLoketKanan", 9.5, 14.5, 5.2, 6.8, 1.3, 4.2 },
	{ "MejaWalikota", -30.9, -28.1, -5.6, 1.6, 1.3, 4.4 },
	{ "KonterPelayanan", 25.2, 27.4, -8.5, 4.5, 1.3, 4.3 },
	{ "RakBuku1", -35.9, -32.1, -10.4, -9.4, 1.3, 9.3 },
	{ "RakBuku2", -31.4, -27.6, -10.4, -9.4, 1.3, 9.3 },
	{ "RakBuku3", -26.9, -23.1, -10.4, -9.4, 1.3, 9.3 },
	{ "LemariArsip", 35.2, 36.4, -9.6, 5.1, 1.3, 5.9 },
	{ "BangkuKiri", -16.6, -12.4, -12.1, -10.7, 1.3, 2.9 },
	{ "BangkuKanan", 12.4, 16.6, -12.1, -10.7, 1.3, 2.9 },
}

-- bingkai (dari FRAMES di balai_kota_dalam.py): dinding, u, z tengah, lebar kanvas, tinggi kanvas
local CANVAS: { [string]: { any } } = {
	info1 = { "L", -9.75, 6.1, 4.24, 3.24 },
	info2 = { "L", 5.75, 6.1, 4.24, 3.24 },
	info3 = { "R", -9.75, 6.1, 4.24, 3.24 },
	info4 = { "R", 5.75, 6.1, 4.24, 3.24 },
	lukDowntown = { "L", -9.75, 14.8, 6.44, 4.44 },
	lukPantai = { "L", 5.75, 14.8, 6.44, 4.44 },
	lukRumah = { "R", -9.75, 14.8, 6.44, 4.44 },
	lukDesa = { "R", 5.75, 14.8, 6.44, 4.44 },
	lukBandara = { "B", -12.0, 14.0, 6.44, 4.44 },
	potretWalikota = { "B", 12.0, 13.5, 3.64, 5.04 },
	lambang = { "B", 0.0, 15.2, 6.44, 5.44 },
	aturan = { "F", -12.0, 12.8, 5.44, 3.44 },
	selamat = { "F", 12.0, 12.8, 5.44, 3.44 },
	visi = { "LW", -2.0, 8.4, 5.44, 3.64 },
	lukWaterfront = { "LF", -29.0, 8.2, 5.94, 3.04 },
	layanan = { "RW", -2.0, 8.4, 10.44, 4.64 },
}

local IMAGES: { [string]: { string } } = {
	lukDowntown = { "83471857800187", "PUSAT KOTA" },
	lukPantai = { "136699009153366", "PANTAI" },
	lukRumah = { "123735429806810", "PERUMAHAN" },
	lukDesa = { "129470372350330", "DESA & KEBUN" },
	lukBandara = { "117268548104485", "BANDARA" },
	potretWalikota = { "128305061669627", "WALIKOTA ROBLOCK" },
	lambang = { "71582928206205", "" },
	lukWaterfront = { "136699009153366", "PULAU PANTAI" },
}

local NAVY, CREAM, GOLD = rgb(28, 52, 98), rgb(248, 243, 228), rgb(226, 172, 52)

-- Papan teks: {judul, {baris...}}
local BOARDS: { [string]: { any } } = {
	info1 = {
		"SELAMAT DATANG",
		{
			"ROBLOCK CITY adalah kota terbuka yang ramah anak.",
			"",
			"Jelajahi kota, cari pekerjaan, beli kendaraan, dan berteman!",
			"",
			"• Tanpa senjata dan kekerasan",
			"• Semua bisa bermain bersama",
		},
	},
	info2 = {
		"5 ZONA KOTA",
		{
			"Pusat Kota: gedung, mall, bioskop",
			"Perumahan: rumah, sekolah, taman",
			"Pantai: dermaga, jet ski, kafe",
			"Desa & Kebun: ladang, kincir angin",
			"Bandara: terbang naik pesawat",
		},
	},
	info3 = {
		"PEKERJAAN",
		{
			"Kurir: antar paket keliling kota",
			"Mekanik: perbaiki mobil di Bengkel",
			"Sopir Bus: jemput penumpang",
			"Pilot: terbangkan pesawat",
			"Polisi: patroli dan bantu warga",
			"Pemadam: padamkan api",
			"Petani: tanam dan panen",
			"Dokter: obati pasien",
		},
	},
	info4 = {
		"TIPS BERMAIN",
		{
			"Buka HP untuk Peta dan GPS",
			"Tekan M untuk peta kota",
			"Ambil hadiah harian dan misi",
			"Beli kendaraan di Dealer",
			"Isi bensin di SPBU",
			"Beli rumah dan hewan peliharaan",
		},
	},
	aturan = {
		"ATURAN KOTA",
		{
			"Bersikap ramah pada semua warga",
			"Hormati rumah dan taman",
			"Berkendara dengan hati-hati",
			"Jaga kebersihan kota",
		},
	},
	selamat = {
		"AYO JELAJAHI!",
		{
			"Naik kendaraan, bekerja, dan temukan tempat baru di 5 zona ROBLOCK CITY.",
			"",
			"Salam dari Walikota!",
		},
	},
	visi = {
		"VISI KOTA",
		{
			"Menjadikan ROBLOCK CITY kota yang ramah, aman, dan seru untuk semua warga.",
		},
	},
}

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font, alignX: Enum.TextXAlignment?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.Text = text
	l.TextColor3 = color
	l.Font = font
	l.TextSize = textSize
	l.TextWrapped = true
	l.TextXAlignment = alignX or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = parent
	return l
end

local function gui(part: BasePart, w: number, h: number, face: Enum.NormalId): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(w * 100, h * 100)
	g.LightInfluence = 0.15
	g.Parent = part
	return g
end

local function textBoard(g: SurfaceGui, title: string, lines: { string })
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = CREAM
	bg.BorderSizePixel = 0
	bg.Parent = g
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 62)
	head.BackgroundColor3 = NAVY
	head.BorderSizePixel = 0
	head.Parent = bg
	local strip = Instance.new("Frame")
	strip.Position = UDim2.new(0, 0, 0, 62)
	strip.Size = UDim2.new(1, 0, 0, 6)
	strip.BackgroundColor3 = GOLD
	strip.BorderSizePixel = 0
	strip.Parent = bg
	local t = label(head, title, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 36, rgb(255, 236, 170), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	t.TextYAlignment = Enum.TextYAlignment.Center
	local body = label(bg, table.concat(lines, "\n"), UDim2.fromOffset(22, 84), UDim2.new(1, -44, 1, -100), 23, rgb(40, 44, 60), Enum.Font.GothamMedium)
	body.LineHeight = 1.15
end

local function layananBoard(g: SurfaceGui)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = CREAM
	bg.BorderSizePixel = 0
	bg.Parent = g
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 90)
	head.BackgroundColor3 = NAVY
	head.BorderSizePixel = 0
	head.Parent = bg
	local t = label(head, "LOKET PELAYANAN WARGA", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 52, rgb(255, 236, 170), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	t.TextYAlignment = Enum.TextYAlignment.Center
	local cols = {
		{ "LOKET 1", "Informasi Kota", "Tanya arah, peta, dan tujuan di kota" },
		{ "LOKET 2", "Lowongan Kerja", "Lihat daftar pekerjaan yang tersedia" },
		{ "LOKET 3", "Saran & Bantuan", "Ceritakan idemu untuk ROBLOCK CITY" },
	}
	for i, c in cols do
		local card = Instance.new("Frame")
		card.Position = UDim2.new((i - 1) / 3, 14, 0, 110)
		card.Size = UDim2.new(1 / 3, -28, 0, 280)
		card.BackgroundColor3 = rgb(255, 255, 255)
		card.BorderSizePixel = 0
		card.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 3
		stroke.Parent = card
		label(card, c[1], UDim2.fromOffset(16, 14), UDim2.new(1, -32, 0, 44), 38, rgb(190, 60, 60), Enum.Font.GothamBlack)
		label(card, c[2], UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 44), 32, NAVY, Enum.Font.GothamBold)
		label(card, c[3], UDim2.fromOffset(16, 130), UDim2.new(1, -32, 0, 130), 26, rgb(70, 74, 90), Enum.Font.Gotham)
	end
	label(bg, "Buka setiap hari  •  Ramah anak  •  Antre dengan tertib", UDim2.fromOffset(0, 410), UDim2.new(1, 0, 0, 40), 26, rgb(70, 74, 90), Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
end

local function imageBoard(g: SurfaceGui, image: string, caption: string)
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundColor3 = NAVY
	img.Image = "rbxassetid://" .. image
	img.ScaleType = Enum.ScaleType.Crop
	img.Parent = g
	if caption ~= "" then
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0, 1)
		band.Position = UDim2.fromScale(0, 1)
		band.Size = UDim2.new(1, 0, 0, 54)
		band.BackgroundColor3 = NAVY
		band.BackgroundTransparency = 0.25
		band.BorderSizePixel = 0
		band.Parent = img
		local t = label(band, caption, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 32, rgb(255, 236, 170), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		t.TextYAlignment = Enum.TextYAlignment.Center
	end
end

-- dinding -> (titik dinding Blender, arah ke dalam ruangan dalam Blender)
local function wallPlace(wall: string, u: number, z: number, off: number): (Vector3, Vector3)
	if wall == "L" then
		return W(-20.5 + off, u, z), Vector3.new(1, 0, 0)
	elseif wall == "R" then
		return W(20.5 - off, u, z), Vector3.new(-1, 0, 0)
	elseif wall == "B" then
		return W(u, -12.5 + off, z), Vector3.new(0, 0, -1) -- ruangan di +y Blender = -z dunia
	elseif wall == "F" then
		return W(u, 8.5 - off, z), Vector3.new(0, 0, 1)
	elseif wall == "LW" then
		return W(-36.5 + off, u, z), Vector3.new(1, 0, 0)
	elseif wall == "RW" then
		return W(36.5 - off, u, z), Vector3.new(-1, 0, 0)
	end
	-- "LF": dinding depan sayap kiri (y 6.5), menghadap -y Blender = +z dunia
	return W(u, 6.5 - off, z), Vector3.new(0, 0, 1)
end

local function plaque(parent: Instance, name: string, text: string, pos: Vector3, normal: Vector3, w: number, h: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(w, h, 0.05)
	part.CFrame = CFrame.lookAt(pos, pos + normal)
	local g = gui(part, w, h, Enum.NormalId.Front)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = NAVY
	bg.BorderSizePixel = 0
	bg.Parent = g
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 5
	stroke.Parent = bg
	local t = label(bg, text, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), math.floor(h * 100 * 0.5), rgb(255, 236, 170), Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	t.TextYAlignment = Enum.TextYAlignment.Center
	part.Parent = parent
end

local function light(parent: Instance, name: string, pos: Vector3, brightness: number, range: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Position = pos
	local l = Instance.new("PointLight")
	l.Brightness, l.Range, l.Shadows = brightness, range, false
	l.Color = rgb(255, 238, 205)
	l.Parent = part
	part.Parent = parent
end

return function(): number
	local raw = ServerStorage:FindFirstChild("BalaiKotaDalamMentah")
	local hall = Workspace.Map:FindFirstChild("BangunanBlender") and Workspace.Map.BangunanBlender:FindFirstChild("BalaiKota")
	if raw == nil or hall == nil then
		warn("[BuildBalaiKotaDalam] butuh ServerStorage.BalaiKotaDalamMentah dan Map.BangunanBlender.BalaiKota")
		return 0
	end
	local old = hall:FindFirstChild("Dalam")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "Dalam"

	-- pusat kotak mesh mentah -> penempatan (rotasi bawaan part hasil impor FBX berbeda-beda, lihat BuildBalaiKota)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			-- Size ada di sumbu lokal part (diputar hasil impor FBX): ubah ke setengah-ukuran dalam sumbu dunia
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
	local wantCenter = W(BBOX_CENTER_BL.X, BBOX_CENTER_BL.Y, BBOX_CENTER_BL.Z)
	for _, part in raw:GetDescendants() do
		local look = if part:IsA("MeshPart") then LOOK[part.Name] else nil
		if look then
			local clone = part:Clone()
			clone:ClearAllChildren()
			local r0 = select(2, part.CFrame:ToOrientation())
			local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)
			clone.CFrame = CFrame.new(wantCenter) * CFrame.Angles(0, undo, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
			clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
			clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery = true, false, false, false
			clone.CastShadow = false
			clone.Parent = root
		end
	end

	-- tabrakan perabot
	local solids = Instance.new("Folder")
	solids.Name = "Tabrakan"
	solids.Parent = root
	for _, c in SOLIDS do
		local part = Instance.new("Part")
		part.Name = c[1]
		part.Anchored = true
		part.Transparency = 1
		part.CastShadow = false
		part.Size = Vector3.new(c[3] - c[2], c[7] - c[6], c[5] - c[4])
		part.Position = W((c[2] + c[3]) / 2, (c[4] + c[5]) / 2, (c[6] + c[7]) / 2)
		if c[8] == "cyl" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(c[7] - c[6], c[3] - c[2], c[5] - c[4])
			part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, 0, math.rad(90))
		end
		part.Parent = solids
	end

	-- kanvas lukisan dan papan info
	local boards = Instance.new("Folder")
	boards.Name = "Papan"
	boards.Parent = root
	for name, c in CANVAS do
		local pos, normal = wallPlace(c[1], c[2], c[3], 0.14)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(c[4], c[5], 0.02)
		part.CFrame = CFrame.lookAt(pos, pos + normal)
		local g = gui(part, c[4], c[5], Enum.NormalId.Front)
		local board = BOARDS[name]
		if name == "layanan" then
			layananBoard(g)
		elseif board then
			textBoard(g, board[1], board[2])
		else
			local image = IMAGES[name]
			imageBoard(g, image[1], image[2])
		end
		part.Parent = boards
	end
	plaque(boards, "PlakatResepsionis", "INFORMASI & PENGADUAN", W(0, -7.12, 3.4), Vector3.new(0, 0, -1), 6.4, 0.9)
	plaque(boards, "PlakatLoket1", "LOKET 1", W(-12, 5.17, 3.0), Vector3.new(0, 0, 1), 3.2, 0.7)
	plaque(boards, "PlakatLoket2", "LOKET 2", W(12, 5.17, 3.0), Vector3.new(0, 0, 1), 3.2, 0.7)
	plaque(boards, "PlakatWalikota", "RUANG WALIKOTA", W(-20.35, -2, 11.0), Vector3.new(1, 0, 0), 7.5, 1.3)
	plaque(boards, "PlakatPelayanan", "LOKET PELAYANAN", W(20.35, -2, 11.0), Vector3.new(-1, 0, 0), 7.5, 1.3)

	-- lampu (redup: ruang besar dan lantai marmer mudah silau)
	local lights = Instance.new("Folder")
	lights.Name = "Lampu"
	lights.Parent = root
	light(lights, "LampuTengah", W(0, -1, 16.5), 0.3, 40)
	light(lights, "LampuKiri", W(-12, -1, 16.5), 0.2, 28)
	light(lights, "LampuKanan", W(12, -1, 16.5), 0.2, 28)
	light(lights, "LampuDepan", W(0, 5, 14), 0.15, 24)
	light(lights, "LampuSayapKiri", W(-29, -2, 10.5), 0.3, 24)
	light(lights, "LampuSayapKanan", W(29, -2, 10.5), 0.3, 24)

	-- percikan air mancur: semburan puncak + dua mangkuk (ringan)
	local fx = Instance.new("Folder")
	fx.Name = "Percikan"
	fx.Parent = root
	local function emitter(name: string, at: Vector3, rate: number, speed: number, spread: number, size: number)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(0.4, 0.4, 0.4)
		part.Position = at
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = rate
		e.Lifetime = NumberRange.new(0.9, 1.4)
		e.Speed = NumberRange.new(speed * 0.8, speed)
		e.SpreadAngle = Vector2.new(spread, spread)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -22, 0)
		e.Color = ColorSequence.new(rgb(200, 235, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 0.4
		e.Parent = part
		part.Parent = fx
	end
	emitter("SemburTengah", W(0, -1, 1.3 + 9.8), 22, 11, 8, 0.5)
	emitter("SemburMangkukAtas", W(0, -1, 1.3 + 6.3), 12, 5, 55, 0.35)
	emitter("SemburMangkukBawah", W(0, -1, 1.3 + 4.0), 16, 4, 75, 0.35)

	root.Parent = hall
	return #root:GetDescendants()
end
