--!strict
--[[
	ROBLOCK CITY: bangunan modern dari Blender (tools/blender/<nama>.py -> assets/blender/*.fbx).

	Tiap bangunan: mesh diunggah sebagai asset Model (MeshPart per bahan) lalu dipasang di
	ServerStorage.<Nama>Mentah. Skrip ini:
	  * mencadangkan model lama utuh ke ServerStorage.CadanganPeta.<Nama>Lama,
	  * di model hidup menyimpan hanya part tabrakan lama (Body, Roof; dibuat tak terlihat) dan
	    menghapus bagian visual lama (pintu, jendela, papan, BodyBulat/RoofBulat),
	  * menambah MeshPart baru (warna/bahan dari LOOK), kotak tabrakan tambahan, dan papan nama SurfaceGui.
	Koordinat Blender -> Roblox lokal: (x, z, -y). Asal Blender di (cx, 1, cz) dunia, yaw 0 = depan menghadap -Z,
	yaw pi = depan menghadap +Z. Pusat bbox mesh (dalam Blender) dipakai untuk meluruskan mesh mentah.
	Jalankan: require(MapBuilders.BuildBangunanModern)() atau ("mall"|"bioskop"|"pos"|"perpus").
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

type Look = { Color3 | Enum.Material | number }
type Sign = { text: string, size: Vector2, at: Vector3, color: Color3 }
type Spec = {
	key: string,
	model: string, -- nama model lama (dan baru) di Downtown.Buildings
	template: string,
	origin: Vector3,
	yaw: number,
	bboxCenter: Vector3, -- pusat bbox dalam koordinat Blender
	keep: { string }, -- part tabrakan lama yang dijadikan tak terlihat
	keepVisible: { string }?, -- part lama yang dibiarkan apa adanya (mis. Apron)
	look: { [string]: Look },
	colliders: { { any } }, -- { nama, x0, x1, y0, y1, z0, z1 } dalam koordinat Blender
	signs: { Sign },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local SP, CON, MET, GLS, WOOD, BRICK, GRASS =
	Enum.Material.SmoothPlastic,
	Enum.Material.Concrete,
	Enum.Material.Metal,
	Enum.Material.Glass,
	Enum.Material.Wood,
	Enum.Material.Brick,
	Enum.Material.Grass

local SPECS: { Spec } = {
	{
		key = "mall",
		model = "ROBLOCKMall",
		template = "MallMentah",
		origin = Vector3.new(525, 1, -604),
		yaw = math.pi,
		bboxCenter = Vector3.new(0, 8.4, 23.65),
		keep = { "Body", "Roof" },
		look = {
			MlWall = { rgb(240, 236, 228), SP, 0 },
			MlStone = { rgb(200, 194, 184), CON, 0 },
			MlRoof = { rgb(84, 90, 102), SP, 0 },
			MlWhite = { rgb(250, 250, 248), SP, 0 },
			MlGlass = { rgb(110, 170, 205), GLS, 0.3 },
			MlDark = { rgb(40, 46, 60), SP, 0 },
			MlCoral = { rgb(240, 110, 95), SP, 0 },
			MlTeal = { rgb(50, 180, 170), SP, 0 },
			MlYellow = { rgb(250, 200, 60), SP, 0 },
		},
		colliders = {
			{ "MenaraKiri", -101.5, -82.5, 44.5, 63.5, 0, 36 },
			{ "MenaraKanan", 82.5, 101.5, 44.5, 63.5, 0, 36 },
		},
		signs = {
			{ text = "ROBLOCK MALL", size = Vector2.new(46, 4.2), at = Vector3.new(0, 74.3, 18.9), color = rgb(255, 214, 90) },
		},
	},
	{
		key = "bioskop",
		model = "Bioskop",
		template = "BioskopMentah",
		origin = Vector3.new(-380, 1, -604),
		yaw = math.pi,
		bboxCenter = Vector3.new(0, 4.75, 16.75),
		keep = { "Body", "Roof" },
		look = {
			BsWall = { rgb(42, 46, 78), SP, 0 },
			BsStone = { rgb(170, 165, 160), CON, 0 },
			BsRoof = { rgb(30, 32, 50), SP, 0 },
			BsGold = { rgb(235, 185, 60), MET, 0 },
			BsGlass = { rgb(100, 150, 200), GLS, 0.3 },
			BsDark = { rgb(24, 26, 38), SP, 0 },
			BsPoster1 = { rgb(230, 80, 80), SP, 0 },
			BsPoster2 = { rgb(80, 170, 230), SP, 0 },
			BsPoster3 = { rgb(250, 200, 60), SP, 0 },
			BsBulb = { rgb(255, 236, 170), Enum.Material.Neon, 0 },
			BsRed = { rgb(190, 30, 40), Enum.Material.Fabric, 0 },
		},
		colliders = {},
		signs = {
			{ text = "BIOSKOP", size = Vector2.new(44, 5.2), at = Vector3.new(0, 38.85, 16.0), color = rgb(255, 214, 90) },
		},
	},
	{
		key = "pos",
		model = "KantorPos",
		template = "KantorPosMentah",
		origin = Vector3.new(-380, 1, -366),
		yaw = 0,
		bboxCenter = Vector3.new(0, 3.175, 19.35),
		keep = { "Body", "Roof" },
		look = {
			PsBrick = { rgb(178, 86, 66), BRICK, 0 },
			PsStone = { rgb(170, 165, 158), CON, 0 },
			PsCream = { rgb(240, 230, 205), SP, 0 },
			PsRoof = { rgb(60, 100, 92), SP, 0 },
			PsGlass = { rgb(120, 175, 210), GLS, 0.3 },
			PsGold = { rgb(226, 172, 52), MET, 0 },
			PsDark = { rgb(50, 36, 30), WOOD, 0 },
			PsClock = { rgb(255, 252, 240), SP, 0 },
			PsRed = { rgb(205, 40, 40), SP, 0 },
		},
		colliders = {},
		signs = {
			{ text = "KANTOR POS", size = Vector2.new(15, 1.0), at = Vector3.new(0, 27.95, 14.6), color = rgb(240, 230, 205) },
		},
	},
	{
		key = "perpus",
		model = "Perpustakaan",
		template = "PerpustakaanMentah",
		origin = Vector3.new(272, 1, -366),
		yaw = 0,
		bboxCenter = Vector3.new(0, 8.05, 12.85),
		keep = { "Body", "Roof" },
		look = {
			PlWall = { rgb(236, 228, 210), SP, 0 },
			PlStone = { rgb(200, 192, 178), CON, 0 },
			PlRoof = { rgb(80, 86, 96), SP, 0 },
			PlWhite = { rgb(248, 246, 240), SP, 0 },
			PlGreen = { rgb(96, 168, 84), GRASS, 0 },
			PlWood = { rgb(170, 118, 70), WOOD, 0 },
			PlGlass = { rgb(120, 185, 215), GLS, 0.3 },
			PlDark = { rgb(48, 52, 60), SP, 0 },
			PlBook1 = { rgb(210, 70, 70), SP, 0 },
			PlBook2 = { rgb(70, 120, 200), SP, 0 },
			PlBook3 = { rgb(240, 190, 60), SP, 0 },
		},
		colliders = {
			{ "Atrium", -15.5, 15.5, 34, 46.5, 0, 19 },
		},
		signs = {
			{ text = "PERPUSTAKAAN", size = Vector2.new(22, 3.6), at = Vector3.new(0, 46.85, 23.3), color = rgb(245, 235, 215) },
		},
	},
	{
		key = "bengkel",
		model = "Bengkel",
		template = "BengkelMentah",
		origin = Vector3.new(186, 1, 249),
		yaw = 0,
		bboxCenter = Vector3.new(0, 2.6, 10.206),
		keep = { "Body", "Roof" },
		look = {
			BgWall = { rgb(70, 82, 104), SP, 0 },
			BgStone = { rgb(170, 168, 164), CON, 0 },
			BgOrange = { rgb(250, 150, 40), SP, 0 },
			BgRoof = { rgb(60, 66, 80), SP, 0 },
			BgDark = { rgb(34, 38, 48), SP, 0 },
			BgGlass = { rgb(130, 190, 225), GLS, 0.3 },
			BgDoor = { rgb(190, 196, 204), MET, 0 },
			BgTire = { rgb(30, 30, 34), SP, 0 },
			BgRim = { rgb(200, 205, 212), MET, 0 },
		},
		colliders = {},
		signs = {
			{ text = "BENGKEL", size = Vector2.new(18, 1.3), at = Vector3.new(0, 13.2, 11.2), color = rgb(255, 255, 255) },
		},
	},
	{
		key = "spbu",
		model = "SPBU",
		template = "SpbuMentah",
		origin = Vector3.new(771, 1, -310),
		yaw = 0,
		bboxCenter = Vector3.new(-24.4, 66.75, 10.0),
		keep = { "Body", "Roof", "Pillar", "Pump", "PumpIsland", "Canopy", "CanopyStripe", "SignPylon" },
		keepVisible = { "Apron" },
		look = {
			BpWall = { rgb(244, 240, 230), SP, 0 },
			BpStone = { rgb(170, 168, 164), CON, 0 },
			BpRed = { rgb(220, 50, 52), SP, 0 },
			BpWhite = { rgb(250, 250, 250), SP, 0 },
			BpGlass = { rgb(130, 190, 225), GLS, 0.3 },
			BpDark = { rgb(34, 38, 48), SP, 0 },
			BpGold = { rgb(250, 200, 60), SP, 0 },
		},
		colliders = {},
		signs = {
			{ text = "SPBU", size = Vector2.new(17, 3.6), at = Vector3.new(0, 2.6, 14.5), color = rgb(255, 255, 255) },
		},
	},
	{
		key = "resort",
		model = "ROBLOCKResort",
		template = "ResortMentah",
		origin = Vector3.new(1249, 1, -460),
		yaw = -math.pi / 2, -- depan menghadap +X (ke kolam)
		bboxCenter = Vector3.new(0, 5.775, 27.5),
		keep = { "Body1", "Lobby" },
		look = {
			RsWall = { rgb(244, 240, 232), SP, 0 },
			RsSand = { rgb(224, 208, 170), CON, 0 },
			RsWhite = { rgb(250, 249, 245), SP, 0 },
			RsGlass = { rgb(110, 195, 215), GLS, 0.3 },
			RsDark = { rgb(34, 50, 62), SP, 0 },
			RsWood = { rgb(176, 128, 80), WOOD, 0 },
			RsPlanter = { rgb(150, 110, 80), CON, 0 },
			RsLeaf = { rgb(70, 160, 80), GRASS, 0 },
			RsTeal = { rgb(30, 170, 180), SP, 0 },
			RsGold = { rgb(226, 172, 52), MET, 0 },
		},
		colliders = {},
		signs = {
			{ text = "ROBLOCK RESORT", size = Vector2.new(22, 3.0), at = Vector3.new(0, 19.05, 13.4), color = rgb(255, 255, 255) },
		},
	},
	{
		key = "sekolah",
		model = "GedungSekolah",
		template = "SekolahMentah",
		origin = Vector3.new(-183, 0, -61),
		yaw = 0,
		bboxCenter = Vector3.new(0, 4.8, 23.25),
		keep = { "Body", "Roof" },
		look = {
			ScWall = { rgb(250, 232, 160), SP, 0 },
			ScStone = { rgb(190, 184, 172), CON, 0 },
			ScRed = { rgb(210, 70, 62), SP, 0 },
			ScOrange = { rgb(250, 150, 40), SP, 0 },
			ScYellow = { rgb(252, 214, 60), SP, 0 },
			ScGreen = { rgb(90, 190, 90), SP, 0 },
			ScBlue = { rgb(70, 140, 230), SP, 0 },
			ScPurple = { rgb(160, 100, 220), SP, 0 },
			ScRoof = { rgb(196, 78, 66), SP, 0 },
			ScWhite = { rgb(250, 249, 245), SP, 0 },
			ScGlass = { rgb(130, 195, 225), GLS, 0.3 },
			ScDark = { rgb(60, 44, 38), WOOD, 0 },
			ScGold = { rgb(226, 172, 52), MET, 0 },
			ScClock = { rgb(255, 252, 240), SP, 0 },
			ScWhiteFlag = { rgb(250, 249, 245), Enum.Material.Fabric, 0 },
			ScWood = { rgb(176, 128, 80), WOOD, 0 },
		},
		colliders = {},
		signs = {
			{ text = "SEKOLAH", size = Vector2.new(14, 1.6), at = Vector3.new(0, 21.9, 20.6), color = rgb(190, 50, 50) },
		},
	},
}

local function build(spec: Spec): number
	local raw = ServerStorage:FindFirstChild(spec.template)
	local buildings = Workspace.Map.Downtown.Buildings
	local blender = Workspace.Map:FindFirstChild("BangunanBlender")
	local old = (blender and blender:FindFirstChild(spec.model))
		or buildings:FindFirstChild(spec.model)
		or Workspace.Map.Residential.Buildings.Downtown:FindFirstChild(spec.model)
		or Workspace.Map.Beach.Resort:FindFirstChild(spec.model)
		or Workspace.Map.Neighborhoods.Sekolah:FindFirstChild(spec.model)
	if raw == nil or old == nil then
		warn("[BuildBangunanModern] " .. spec.key .. ": template atau model lama tidak ada")
		return 0
	end
	for _, d in raw:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		end
	end

	-- cadangkan model lama utuh (sekali saja)
	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	local backupName = spec.model .. "Lama"
	if backup:FindFirstChild(backupName) == nil then
		local copy = old:Clone()
		copy.Name = backupName
		copy.Parent = backup
	end

	-- buang visual lama, simpan part tabrakan
	for _, c in old:GetChildren() do
		if spec.keepVisible and table.find(spec.keepVisible, c.Name) then
			continue
		elseif table.find(spec.keep, c.Name) and c:IsA("BasePart") then
			c.Transparency = 1
			for _, tag in CollectionService:GetTags(c) do
				CollectionService:RemoveTag(c, tag)
			end
		else
			c:Destroy()
		end
	end
	local oldMesh = old:FindFirstChild("Visual")
	if oldMesh then
		oldMesh:Destroy()
	end

	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local half = part.Size / 2
			mn = mn:Min(part.Position - half)
			mx = mx:Max(part.Position + half)
		end
	end
	local rawCenter = (mn + mx) / 2
	local base = CFrame.new(spec.origin) * CFrame.Angles(0, spec.yaw, 0)
	local center = base * CFrame.new(spec.bboxCenter.X, spec.bboxCenter.Z, -spec.bboxCenter.Y)

	local visual = Instance.new("Model")
	visual.Name = "Visual"
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local look = key and spec.look[key]
			if look then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Name = key :: string
				-- rotasi bawaan part hasil impor FBX harus dipertahankan (bukan hanya yaw bangunan)
				-- FBX diimpor dengan rotasi bawaan yang berbeda-beda (0 atau ~180 derajat): jika 0, depan mesh ada di +Z
				-- lokal, jadi putar 180 derajat di sekitar pusat agar depan = -Z seperti yang lain.
				local flip = if math.abs(select(2, part.CFrame:ToOrientation())) < 1.5 then math.pi else 0
				clone.CFrame = center * CFrame.Angles(0, flip, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
				clone.Color, clone.Material, clone.Transparency = look[1] :: Color3, look[2] :: Enum.Material, look[3] :: number
				clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
				if string.sub(key :: string, -5) == "Glass" then
					CollectionService:AddTag(clone, "NightWindow")
				end
				clone.Parent = visual
			end
		end
	end

	for _, c in spec.colliders do
		local part = Instance.new("Part")
		part.Name = c[1]
		part.Anchored = true
		part.Transparency = 1
		part.CastShadow = false
		part.Size = Vector3.new(c[3] - c[2], c[7] - c[6], c[5] - c[4])
		part.CFrame = base * CFrame.new((c[2] + c[3]) / 2, (c[6] + c[7]) / 2, -(c[4] + c[5]) / 2)
		part.Parent = visual
	end

	for _, s in spec.signs do
		local sign = Instance.new("Part")
		sign.Name = "PapanNama"
		sign.Anchored = true
		sign.CanCollide, sign.CanQuery, sign.CanTouch = false, false, false
		sign.Transparency = 1
		sign.Size = Vector3.new(s.size.X, s.size.Y, 0.1)
		sign.CFrame = base * CFrame.new(s.at.X, s.at.Z, -s.at.Y) * CFrame.new(0, 0, -0.6) -- sedikit di depan permukaan
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.9) -- sisakan tepi agar huruf pertama tidak terpotong
		label.Position = UDim2.fromScale(0.04, 0.05)
		label.BackgroundTransparency = 1
		label.Text = s.text
		label.TextColor3 = s.color
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Parent = gui
		-- batas ukuran huruf: tanpa ini TextScaled melebar dan huruf pertama terpotong
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(s.size.Y * gui.PixelsPerStud * 0.6)
		limit.Parent = label
		sign.Parent = visual
	end
	visual.Parent = old
	if blender then
		old.Parent = blender -- semua bangunan Blender dikumpulkan di Map.BangunanBlender
	end
	return #visual:GetDescendants()
end

return function(only: string?): number
	local total = 0
	for _, spec in SPECS do
		if only == nil or only == spec.key then
			total += build(spec)
		end
	end
	return total
end
