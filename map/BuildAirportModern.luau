--!strict
--[[
	ROBLOCK CITY: bandara besar modern (dibuat di Blender: tools/bangun_pesawat.py, tools/bangun_terminal.py).

	Aset yang diunggah (Model, satu MeshPart per bahan) dipasang di ServerStorage.AsetBandara:
	  TerminalMentah 124361055586138 (TmFloor, TmGlass, TmWhite, TmFrame, TmCounter, TmDark, TmLight, TmRoof)
	  PesawatPenumpangMentah 97741812415503 (PlWhite, PlLivery, PlDark, PlGray, PlTire)
	  GarbarataMentah 88066069925230 (BrWhite, BrGlass, BrGray, BrYellow, BrDark)
	  MenaraMentah 140239327509449 (TwWhite, TwRed, TwGlass, TwDark)
	Koordinat Blender -> Roblox lokal = (x, z, -y); asal mesh dihitung dari kotak pembatas model
	(tengah kotak di Blender diketahui, lihat BBOX di bawah). Semua aset simetris kiri-kanan.

	Isi: terminal besar (depan menghadap -Z ke jalan terminal, tengah (-975, 464)), 4 pesawat
	penumpang di gerbang 1-4 (hidung ke terminal, warna maskapai karangan sendiri, statis), 4 garbarata
	dari terminal ke pintu kiri pesawat, menara kontrol, marka gerbang, kendaraan darat hias.
	Bandara lama dicadangkan utuh di ServerStorage.CadanganPeta.BandaraLama. Landasan, taxiway,
	jalan terminal, parkir, hangar, PesawatKecil dan gerbang interior (portal) tidak diubah.
	Aman dijalankan ulang.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local V3 = Vector3.new
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- tengah kotak pembatas di Blender (x, y, z) per aset
local BBOX = {
	TerminalMentah = V3(0, 6, 14.492),
	PesawatPenumpangMentah = V3(0, -0.75, 13.5),
	GarbarataMentah = V3(0, 23.025, 6.375),
	MenaraMentah = V3(0, 0, 44.25),
}

-- nama bahan -> { warna, material, transparansi, pantulan }
local LOOK: { [string]: { any } } = {
	TmFloor = { rgb(196, 198, 204), Enum.Material.Concrete, 0, 0 },
	TmGlass = { rgb(130, 195, 232), Enum.Material.Glass, 0.4, 0.1 },
	TmWhite = { rgb(246, 247, 250), Enum.Material.SmoothPlastic, 0, 0 },
	TmFrame = { rgb(36, 92, 168), Enum.Material.SmoothPlastic, 0, 0 },
	TmCounter = { rgb(236, 176, 80), Enum.Material.SmoothPlastic, 0, 0 },
	TmDark = { rgb(46, 52, 64), Enum.Material.SmoothPlastic, 0, 0 },
	TmLight = { rgb(255, 244, 205), Enum.Material.Neon, 0, 0 },
	TmRoof = { rgb(248, 250, 252), Enum.Material.SmoothPlastic, 0, 0 },
	TwWhite = { rgb(242, 243, 247), Enum.Material.SmoothPlastic, 0, 0 },
	TwRed = { rgb(222, 62, 56), Enum.Material.SmoothPlastic, 0, 0 },
	TwGlass = { rgb(110, 182, 222), Enum.Material.Glass, 0.3, 0.1 },
	TwDark = { rgb(46, 52, 64), Enum.Material.SmoothPlastic, 0, 0 },
	BrWhite = { rgb(238, 240, 245), Enum.Material.SmoothPlastic, 0, 0 },
	BrGlass = { rgb(120, 190, 228), Enum.Material.Glass, 0.35, 0.1 },
	BrGray = { rgb(150, 155, 162), Enum.Material.SmoothPlastic, 0, 0 },
	BrYellow = { rgb(250, 200, 42), Enum.Material.SmoothPlastic, 0, 0 },
	BrDark = { rgb(55, 60, 70), Enum.Material.SmoothPlastic, 0, 0 },
	PlWhite = { rgb(250, 250, 252), Enum.Material.SmoothPlastic, 0, 0 },
	PlDark = { rgb(30, 42, 58), Enum.Material.SmoothPlastic, 0, 0 },
	PlGray = { rgb(208, 213, 220), Enum.Material.SmoothPlastic, 0, 0 },
	PlTire = { rgb(26, 26, 30), Enum.Material.SmoothPlastic, 0, 0 },
}

local TERMINAL_X, TERMINAL_Z = -975, 464
local BASE_Y = 0.4 -- permukaan apron/landasan
local GATES = {
	{ x = -1110, name = "ZAMRUD AIR", color = rgb(60, 180, 120) },
	{ x = -1020, name = "AWAN AIR", color = rgb(62, 150, 232) },
	{ x = -930, name = "PELANGI AIR", color = rgb(240, 96, 96) },
	{ x = -840, name = "MENTARI AIR", color = rgb(250, 170, 40) },
}
local PLANE_NOSE_Z = 543
local PLANE_CENTER_Z = PLANE_NOSE_Z + 38.5

-- Menaruh salinan aset mentah: Blender (0,0,0) = titik `origin`, hadap ikut `frame`.
local function place(
	raw: Instance,
	frame: CFrame,
	parent: Instance,
	name: string,
	livery: Color3?
): Model
	local parts: { MeshPart } = {}
	local mn, mx = V3(1e9, 1e9, 1e9), V3(-1e9, -1e9, -1e9)
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
			local h = d.Size / 2
			mn, mx = mn:Min(d.Position - h), mx:Max(d.Position + h)
		end
	end
	local c = BBOX[raw.Name]
	local origin = (mn + mx) / 2 - V3(c.X, c.Z, -c.Y)
	local model = Instance.new("Model")
	model.Name = name
	for _, part in parts do
		local look = LOOK[part.Name]
		if look then
			local clone = part:Clone()
			clone:ClearAllChildren()
			clone.CFrame = frame * CFrame.new(part.Position - origin)
			clone.Color, clone.Material, clone.Transparency, clone.Reflectance =
				look[1], look[2], look[3], look[4]
			if part.Name == "PlLivery" and livery then
				clone.Color = livery
			end
			clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery = true, false, false, false
			clone.CastShadow = part.Name ~= "TmLight" and part.Name ~= "TmGlass"
			clone.Parent = model
		end
	end
	model.Parent = parent
	return model
end

local function box(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	collide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.CanCollide = collide
	part.CanTouch = false
	part.Transparency = if color then 0 else 1
	part.CastShadow = color ~= nil
	if color then
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
	end
	part.Parent = parent
	return part
end

local function label(part: BasePart, text: string, face: Enum.NormalId, color: Color3, ppsFactor: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsFactor or 24
	gui.Parent = part
	local text_label = Instance.new("TextLabel")
	text_label.Size = UDim2.fromScale(1, 1)
	text_label.BackgroundTransparency = 1
	text_label.Text = text
	text_label.TextColor3 = color
	text_label.Font = Enum.Font.GothamBlack
	text_label.TextScaled = true
	text_label.Parent = gui
end

return function(): number
	local map = Workspace.Map
	local zone = map:FindFirstChild("Airport")
	local assets = ServerStorage:FindFirstChild("AsetBandara")
	if zone == nil or assets == nil then
		warn("[BuildAirportModern] Map.Airport atau ServerStorage.AsetBandara tidak ada")
		return 0
	end

	-- cadangan bandara lama (sekali, sebelum perubahan pertama)
	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	local old = zone:FindFirstChild("BandaraBaru")
	if old == nil and backup:FindFirstChild("BandaraLama") == nil then
		local copy = zone:Clone()
		copy.Name = "BandaraLama"
		copy.Parent = backup
	end
	if old then
		old:Destroy()
	end

	-- singkirkan bagian lama yang digantikan (terminal, garbarata, menara, pesawat besar, marka gerbang lama)
	local removeNames = { Terminal = true, Garbarata = true, TiangGarbarata = true, MenaraKontrol = true, Kabin = true, AtapKabin = true, Antena = true }
	for _, child in zone.Terminal:GetChildren() do
		if removeNames[child.Name] then
			child:Destroy()
		end
	end
	for _, name in { "PesawatROBLOCKAir1", "PesawatROBLOCKAir2", "PesawatTaxi" } do
		local plane = zone.Pesawat:FindFirstChild(name)
		if plane then
			plane:Destroy()
		end
	end
	for _, d in zone.Landasan:GetChildren() do
		if d.Name == "GateLine" then
			d:Destroy()
		end
	end

	local root = Instance.new("Folder")
	root.Name = "BandaraBaru"
	local frameTerminal = CFrame.new(TERMINAL_X, BASE_Y, TERMINAL_Z)

	-- terminal
	local terminal = place(assets.TerminalMentah, frameTerminal, root, "TerminalModern")
	local solid = Instance.new("Folder")
	solid.Name = "Tabrakan"
	solid.Parent = terminal
	box(solid, "Badan", CFrame.new(TERMINAL_X, BASE_Y + 12, TERMINAL_Z), V3(364, 24, 78), nil, nil, true)
	box(solid, "Teras", CFrame.new(TERMINAL_X, BASE_Y + 0.7, TERMINAL_Z - 6), V3(376, 1.4, 112), nil, nil, true)
	local sign = box(terminal, "PapanNama", CFrame.new(TERMINAL_X, BASE_Y + 20.5, TERMINAL_Z - 59.4), V3(200, 4, 0.2), rgb(36, 92, 168), nil, false)
	label(sign, "BANDARA INTERNASIONAL ROBLOCK", Enum.NormalId.Front, Color3.new(1, 1, 1), 24)
	local pillars: { { number } } = { { -150, 30 }, { 150, 30 } }
	for _, p in pillars do
		local panel = box(terminal, "PapanSisi", CFrame.new(TERMINAL_X + p[1], BASE_Y + 21, TERMINAL_Z - 58.8), V3(p[2] * 2, 3, 0.2), rgb(36, 92, 168), nil, false)
		label(panel, if p[1] < 0 then "KEBERANGKATAN" else "KEDATANGAN", Enum.NormalId.Front, rgb(255, 214, 80), 24)
	end

	-- pesawat + garbarata + penanda gerbang
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Gerbang"
	gateFolder.Parent = root
	for index, gate in GATES do
		local frame = CFrame.new(gate.x, BASE_Y, PLANE_CENTER_Z)
		local plane = place(assets.PesawatPenumpangMentah, frame, gateFolder, "Pesawat" .. gate.name:gsub(" ", ""), gate.color)
		local colliders = Instance.new("Folder")
		colliders.Name = "Tabrakan"
		colliders.Parent = plane
		box(colliders, "Badan", frame * CFrame.new(0, 7.6, 0), V3(8, 8, 76), nil, nil, true)
		box(colliders, "Sayap", frame * CFrame.new(0, 6.4, -0.5), V3(66, 1.6, 14), nil, nil, true)
		-- nama maskapai di sisi badan (dua sisi)
		for side = -1, 1, 2 do
			local text = box(plane, "NamaMaskapai", frame * CFrame.new(side * 4.12, 9.7, -2) * CFrame.Angles(0, -side * math.pi / 2, 0), V3(30, 1.5, 0.1), nil, nil, false)
			text.Transparency = 1
			text.CastShadow = false
			label(text, gate.name, Enum.NormalId.Front, gate.color, 40)
		end

		-- garbarata dari terminal ke pintu kiri pesawat
		local from = V3(gate.x - 18, BASE_Y, 504.5)
		local to = V3(gate.x - 5.5, BASE_Y, PLANE_CENTER_Z - 27)
		local bridgeFrame = CFrame.lookAt(from, to)
		local bridge = place(assets.GarbarataMentah, bridgeFrame, gateFolder, "Garbarata" .. index)
		local length = (to - from).Magnitude
		box(bridge, "Tabrakan", bridgeFrame * CFrame.new(0, 8.5, -length / 2 + 1) * CFrame.new(0, 0, 0), V3(6.4, 7, length - 4), nil, nil, true)

		-- marka tengah gerbang + tanda nomor di dinding terminal
		local line = box(root, "GarisGerbang", CFrame.new(gate.x, BASE_Y + 0.05, (PLANE_NOSE_Z + 520) / 2 + 40), V3(0.7, 0.1, 140), rgb(250, 205, 60), Enum.Material.SmoothPlastic, false)
		line.CanQuery = false
		local num = box(gateFolder, "NomorGerbang", CFrame.new(gate.x - 18, BASE_Y + 19.2, 502.3), V3(12, 3.4, 0.2), rgb(36, 92, 168), nil, false)
		label(num, "GATE " .. index, Enum.NormalId.Back, Color3.new(1, 1, 1), 30)
	end

	-- menara kontrol
	local tower = place(assets.MenaraMentah, CFrame.new(-745, BASE_Y, 470), root, "MenaraKontrol")
	box(tower, "Tabrakan", CFrame.new(-745, BASE_Y + 40, 470), V3(14, 80, 14), nil, nil, true)

	-- kendaraan darat hias di apron (kereta bagasi + bus penumpang)
	local ground = Instance.new("Folder")
	ground.Name = "KendaraanDarat"
	ground.Parent = root
	for index, gx in { -1110, -1020, -930, -840 } do
		local base = V3(gx - 30, BASE_Y, 536 + (index % 2) * 6)
		local tug = box(ground, "Penarik", CFrame.new(base + V3(0, 1.6, 0)), V3(3, 2.4, 5), rgb(250, 205, 60), nil, false)
		box(ground, "AtapPenarik", CFrame.new(base + V3(0, 3.4, 0.4)), V3(2.8, 0.4, 3), rgb(60, 66, 80), nil, false)
		for k = 1, 3 do
			box(ground, "Kereta", CFrame.new(base + V3(0, 1.3, 5.5 + k * 5)), V3(3.6, 2, 4.2), rgb(90, 150, 220), nil, false)
			box(ground, "Bagasi", CFrame.new(base + V3(0, 2.8, 5.5 + k * 5)), V3(3, 1.1, 3.4), rgb(235, 130, 90), nil, false)
		end
		tug.Name = "Penarik"
		box(ground, "Tabrakan", CFrame.new(base + V3(0, 2, 12)), V3(4, 4, 28), nil, nil, true)
	end

	-- cahaya malam untuk lampu langit-langit terminal
	for _, d in terminal:GetChildren() do
		if d:IsA("MeshPart") and d.Name == "TmLight" then
			CollectionService:AddTag(d, "NightLight")
		end
	end

	root.Parent = zone
	return #root:GetDescendants()
end
