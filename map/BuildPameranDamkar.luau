--!nocheck
-- Pameran Alat Pemadam Kebakaran: lahan sisi timur halaman belakang Pos Damkar (x 172..204, z 266..318).
-- Model alat: ServerStorage.PameranDamkarMentah (asset 96540725605743, tools/blender/pameran_damkar.py).
-- Hasil: Workspace.Map.PameranDamkar. Tiap dudukan = Part bertag "ExhibitStand" (+ProximityPrompt) yang dibaca
-- client/Controllers/ExhibitController. Aman dijalankan ulang (folder lama dihapus).
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local RAW = ServerStorage:FindFirstChild("PameranDamkarMentah")
local map = workspace:WaitForChild("Map")
local old = map:FindFirstChild("PameranDamkar")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "PameranDamkar"
root.Parent = map

local COLORS = {
	merah = { Color3.fromRGB(214, 36, 36), Enum.Material.SmoothPlastic },
	hitam = { Color3.fromRGB(38, 38, 44), Enum.Material.SmoothPlastic },
	perak = { Color3.fromRGB(196, 202, 212), Enum.Material.Metal },
	putih = { Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic },
	kuning = { Color3.fromRGB(255, 196, 30), Enum.Material.SmoothPlastic },
	biru = { Color3.fromRGB(40, 110, 205), Enum.Material.SmoothPlastic },
	kayu = { Color3.fromRGB(150, 98, 52), Enum.Material.Wood },
	kaca = { Color3.fromRGB(150, 210, 232), Enum.Material.Glass },
}

local ITEMS = {
	{ id = "apar", title = "APAR (Alat Pemadam Api Ringan)", info = "APAR dipakai untuk memadamkan api yang masih kecil, misalnya api di dapur atau di tumpukan kertas. Cara memakainya mudah: Tarik pin, Arahkan selang ke pangkal api, Tekan tuas, lalu Sapu dari sisi ke sisi.", tip = "Jarum di APAR harus berwarna hijau supaya siap dipakai." },
	{ id = "hidran", title = "Hidran", info = "Hidran adalah keran air besar di pinggir jalan. Petugas damkar menyambungkan selang ke hidran untuk mendapat banyak air saat memadamkan kebakaran besar.", tip = "Jangan parkir di depan hidran, supaya petugas bisa memakainya dengan cepat!" },
	{ id = "selang", title = "Selang Pemadam", info = "Selang ini mengalirkan air dari mobil damkar atau hidran sampai ke api. Selangnya kuat menahan tekanan air yang besar. Di ujungnya ada nozel untuk mengatur semburan air.", tip = "Satu gulungan selang bisa sepanjang puluhan meter." },
	{ id = "helm", title = "Helm Pemadam", info = "Helm melindungi kepala petugas dari benda jatuh dan panas. Bagian belakangnya lebar untuk melindungi leher dari percikan air panas dan puing.", tip = "Helm dipakai bersama tali dagu supaya tidak lepas saat bekerja." },
	{ id = "baju", title = "Baju Tahan Api", info = "Baju ini dibuat dari bahan khusus yang tahan panas dan tidak mudah terbakar. Garis perak memantulkan cahaya supaya petugas terlihat jelas di tempat gelap atau berasap.", tip = "Bajunya berlapis-lapis supaya panas sulit menembus." },
	{ id = "kapak", title = "Kapak Damkar", info = "Kapak dipakai untuk membuka pintu atau memotong penghalang saat menolong orang di dalam bangunan. Sisi runcing di belakangnya bisa untuk melubangi dinding.", tip = "Kapak hanya boleh dipakai oleh petugas yang sudah terlatih." },
	{ id = "alarm", title = "Alarm Kebakaran", info = "Alarm berbunyi keras dan lampunya menyala saat ada api atau asap. Dengan begitu semua orang di gedung cepat tahu dan bisa keluar dengan aman. Tuasnya ditarik untuk membunyikan alarm.", tip = "Kalau alarm berbunyi, jalan cepat ke pintu keluar dan jangan naik lift." },
	{ id = "masker", title = "Masker dan Tabung Udara", info = "Asap kebakaran berbahaya jika terhirup. Tabung berisi udara bersih yang dialirkan lewat selang ke masker, sehingga petugas bisa bernapas di dalam ruangan penuh asap.", tip = "Saat ada asap, merunduklah. Udara bersih ada di dekat lantai." },
	{ id = "tangga", title = "Tangga Darurat", info = "Tangga ini dipakai untuk naik ke jendela atau atap gedung, dan untuk menolong orang di lantai atas. Dibuat dari logam yang ringan tapi kuat, dengan kaki karet supaya tidak tergelincir.", tip = "Mobil damkar bertangga bisa memanjang sampai belasan meter." },
}
local TIPS = { id = "tips", title = "Kalau Ada Api", info = "1. Tetap tenang dan beri tahu orang dewasa.\n2. Keluar dari ruangan, jangan bawa barang.\n3. Jangan bersembunyi dan jangan kembali ke dalam.\n4. Telepon pemadam kebakaran di nomor 113.", tip = "Jangan bermain dengan korek api atau kembang api." }

-- kolom kiri (muka ke timur), kolom kanan (muka ke barat)
local TOP = 1.15
local ROWS = { 278, 287, 296, 305, 314 }
local SLOTS = {
	{ 178, ROWS[1], 1 }, { 178, ROWS[2], 1 }, { 178, ROWS[3], 1 }, { 178, ROWS[4], 1 }, { 178, ROWS[5], 1 },
	{ 198, ROWS[1], -1 }, { 198, ROWS[2], -1 }, { 198, ROWS[3], -1 }, { 198, ROWS[4], -1 }, { 198, ROWS[5], -1 },
}

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function sign(partOwner, face, text, size, textColor, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Parent = partOwner
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	if bg then
		l.BackgroundColor3 = bg
	end
	l.Text = text
	l.TextColor3 = textColor
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Parent = g
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
end

-- lantai plaza + jalur
part(root, "Plaza", Vector3.new(32, 0.15, 51), CFrame.new(188, 1.075, 292.5), Color3.fromRGB(176, 170, 160), Enum.Material.Pavement)
part(root, "Jalur", Vector3.new(8, 0.18, 48), CFrame.new(188, 1.09, 293), Color3.fromRGB(196, 60, 56), Enum.Material.Pavement)

-- gerbang
local gate = Instance.new("Model")
gate.Name = "Gerbang"
gate.Parent = root
for _, x in ipairs({ 179, 197 }) do
	part(gate, "Tiang", Vector3.new(1.6, 10, 1.6), CFrame.new(x, 6.15, 269), Color3.fromRGB(214, 36, 36))
end
local beam = part(gate, "Papan", Vector3.new(20, 3.4, 1.2), CFrame.new(188, 9.8, 269), Color3.fromRGB(255, 196, 30))
sign(beam, Enum.NormalId.Back, "PAMERAN ALAT PEMADAM", 80, Color3.fromRGB(150, 20, 20))
sign(beam, Enum.NormalId.Front, "PAMERAN ALAT PEMADAM", 80, Color3.fromRGB(150, 20, 20))

-- salin bagian mesh dari model mentah (posisi relatif terhadap titik asal tiap alat)
local function itemParts(index)
	local O = CFrame.new(128.87, 0, 402.79 - 10 * (index - 1))
	local out = {}
	if not RAW then
		return out
	end
	for _, d in ipairs(RAW:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name:match("^(%a+)_") then
			local prefix = d.Name:match("^(%a+)_")
			if prefix == ITEMS[index].id then
				table.insert(out, { part = d, rel = O:ToObjectSpace(d.CFrame) })
			end
		end
	end
	return out
end

local function makeStand(slot, data, index)
	local x, z, dir = slot[1], slot[2], slot[3]
	local m = Instance.new("Model")
	m.Name = "Dudukan_" .. data.id
	m.Parent = root
	local front = Vector3.new(dir, 0, 0)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + front)
	-- pedestal bulat
	local ped = part(m, "Dudukan", Vector3.new(1.2, 6, 6), CFrame.new(x, 1.15 + 0.6, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(235, 228, 215), Enum.Material.Concrete)
	ped.Shape = Enum.PartType.Cylinder
	local ring = part(m, "Cincin", Vector3.new(0.25, 6.4, 6.4), CFrame.new(x, 1.15 + 0.12, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(214, 36, 36))
	ring.Shape = Enum.PartType.Cylinder
	-- papan nama di depan dudukan
	local plateCF = CFrame.new(x + dir * 3.9, 1.15 + 0.65, z) * CFrame.Angles(0, dir == 1 and math.pi / 2 or -math.pi / 2, 0) * CFrame.Angles(math.rad(-25), 0, 0)
	local plate = part(m, "Papan", Vector3.new(4.6, 1.3, 0.2), plateCF, Color3.fromRGB(255, 250, 240))
	sign(plate, Enum.NormalId.Front, data.title, 36, Color3.fromRGB(150, 20, 20))
	ped:SetAttribute("Title", data.title)
	ped:SetAttribute("Info", data.info)
	ped:SetAttribute("Tip", data.tip)
	CollectionService:AddTag(ped, "ExhibitStand")
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "InfoPrompt"
	pp.ActionText = "Lihat Info"
	pp.ObjectText = data.title
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 9
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = ped
	-- alat
	local itemFrame = base * CFrame.new(0, TOP + 0.05, 0) * CFrame.Angles(0, -math.pi / 2, 0) -- depan Blender (-X impor) -> arah depan dudukan
	if index <= #ITEMS then
		for _, e in ipairs(itemParts(index)) do
			local c = e.part:Clone()
			c.Anchored = true
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = false
			c.CastShadow = false
			local suffix = c.Name:match("_(%a+)$")
			local sp = COLORS[suffix]
			if sp then
				c.Color = sp[1]
				c.Material = sp[2]
			end
			if suffix == "kaca" then
				c.Transparency = 0.45
			elseif c.Name == "alarm_kuning" then
				c.Material = Enum.Material.Neon
			end
			c.CFrame = CFrame.new(Vector3.new(x, TOP + 0.05, z)) * (itemFrame - itemFrame.Position) * e.rel
			c.Parent = m
		end
	else
		-- papan tips: papan besar berdiri
		local board = part(m, "PapanTips", Vector3.new(5, 3.6, 0.3), CFrame.new(x, TOP + 3.4, z) * (base - base.Position) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 250, 240))
		sign(board, Enum.NormalId.Front, "Kalau ada api: TENANG, KELUAR, TELEPON 113", 40, Color3.fromRGB(150, 20, 20))
		part(m, "Kaki", Vector3.new(0.5, 2.6, 0.5), CFrame.new(x, TOP + 1.3, z), Color3.fromRGB(60, 60, 66))
	end
end

for i, slot in ipairs(SLOTS) do
	local data = ITEMS[i] or TIPS
	makeStand(slot, data, i)
end
return root
