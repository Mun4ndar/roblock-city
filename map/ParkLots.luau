--!strict
--[[
	ROBLOCK CITY: empat lahan kosong besar diubah menjadi taman berbeda-beda + halaman mewah (2026-11-25).
	Pakai (mode Edit): require(game.ServerStorage.MapBuilders.ParkLots)()  -- sekali; hasil di Workspace.Map.TamanLahan

	  A  (737, 356)  Pusat Olahraga dan Kuliner : lapangan basket, deretan kios, meja payung, area bermain
	  B  (466, 356)  Taman Kota Kecil           : kolam, jalan melingkar, gazebo, bedeng bunga
	  C  (-186, 359) Taman Bermain Keluarga     : ayunan, jungkat-jungkit, bak pasir, meja piknik, gawang
	  D  (-375, 355) Kebun Bunga dan Piknik     : baris bunga, pergola, saung piknik, jalan kayu

	Aset gratis tanpa skrip di ServerStorage.AsetPihakKetiga: SemakBulat, BungaToko, BangkuTaman, CemaraSpruce,
	CliosowPalmTrees; pohon berdaun dari Workspace.Map.Neighborhoods.Houses.PohonRindang.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ParkLots = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local STONE = rgb(214, 208, 196)
local GRASS_A, GRASS_B = rgb(96, 168, 78), rgb(110, 182, 86)
local WOOD = rgb(150, 104, 66)
local DARK = rgb(60, 62, 68)
local WHITE = rgb(245, 245, 245)

type Ctx = {
	root: Folder,
	rnd: Random,
	assets: Instance,
	treeT: Model?,
	box: (name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?) -> Part,
}

local function newCtx(root: Folder, seed: number): Ctx
	local assets = ServerStorage:WaitForChild("AsetPihakKetiga")
	local map = workspace:WaitForChild("Map")
	local houses = map:WaitForChild("Neighborhoods"):WaitForChild("Houses")
	local ctx: any = { root = root, rnd = Random.new(seed), assets = assets, treeT = houses:FindFirstChild("PohonRindang") }
	function ctx.box(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = solid ~= false
		p.CanQuery = solid ~= false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = root
		return p
	end
	return ctx :: Ctx
end

local function at(x: number, y: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
end

local function clone(ctx: Ctx, tpl: Instance?, x: number, z: number, scale: number?, yaw: number?, name: string?): Model?
	if not tpl then
		return nil
	end
	local c = tpl:Clone() :: Model
	c.Name = name or tpl.Name
	if scale then
		c:ScaleTo(scale)
	end
	local bb, sz = c:GetBoundingBox()
	local off = c:GetPivot().Position.Y - (bb.Position.Y - sz.Y / 2)
	c:PivotTo(CFrame.new(x, off - 0.05, z) * CFrame.Angles(0, yaw or ctx.rnd:NextNumber(0, math.pi * 2), 0))
	c.Parent = ctx.root
	return c
end

local function tree(ctx: Ctx, x: number, z: number, height: number)
	if ctx.treeT then
		local _, sz = ctx.treeT:GetBoundingBox()
		clone(ctx, ctx.treeT, x, z, height / sz.Y, nil, "Pohon")
	end
end

local function bush(ctx: Ctx, x: number, z: number, s: number)
	clone(ctx, ctx.assets:FindFirstChild("SemakBulat"), x, z, s * ctx.rnd:NextNumber(0.9, 1.15), nil, "Semak")
end

local function flowers(ctx: Ctx, x: number, z: number, radius: number, n: number)
	local folder = ctx.assets:FindFirstChild("BungaToko")
	if not folder then
		return
	end
	local names = { "Bunga1", "Bunga2", "Bunga3", "Bunga4", "BungaDaisy" }
	for _ = 1, n do
		local a, r = ctx.rnd:NextNumber(0, math.pi * 2), ctx.rnd:NextNumber(0, radius)
		local name = names[ctx.rnd:NextInteger(1, #names)]
		clone(ctx, folder:FindFirstChild(name), x + math.cos(a) * r, z + math.sin(a) * r, if name == "BungaDaisy" then 0.5 else ctx.rnd:NextNumber(1.1, 1.5), nil, "Bunga")
	end
end

local function tuft(ctx: Ctx, x: number, z: number)
	local f = ctx.assets:FindFirstChild("BungaToko")
	clone(ctx, if f then f:FindFirstChild("RumputTuft") else nil, x, z, ctx.rnd:NextNumber(0.6, 0.85), nil, "Rumput")
end

local function bench(ctx: Ctx, x: number, z: number, yaw: number)
	clone(ctx, ctx.assets:FindFirstChild("BangkuTaman"), x, z, nil, yaw, "Bangku")
end

local function lamp(ctx: Ctx, x: number, z: number)
	ctx.box("TiangLampu", Vector3.new(0.5, 9, 0.5), at(x, 4.5, z), DARK, Enum.Material.Metal)
	local head = ctx.box("Lamp", Vector3.new(1.6, 1.6, 1.6), at(x, 9.4, z), rgb(255, 232, 180), Enum.Material.Neon, false)
	head.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 3
	light.Color = rgb(255, 222, 168)
	light.Shadows = false
	light.Parent = head
	CollectionService:AddTag(head, "NightLight")
end

-- lembar datar (rumput, paving) di atas tanah: atas = 0,12
local function slab(ctx: Ctx, name: string, cx: number, cz: number, w: number, d: number, color: Color3, material: Enum.Material?, yaw: number?, top: number?): Part
	local t = top or 0.12
	return ctx.box(name, Vector3.new(w, 0.2, d), at(cx, t - 0.1, cz, yaw), color, material or Enum.Material.Concrete, false)
end

local function pathLine(ctx: Ctx, a: Vector2, b: Vector2, width: number)
	local d = b - a
	local mid = (a + b) / 2
	local p = ctx.box("Jalan", Vector3.new(width, 0.2, d.Magnitude + 0.2), CFrame.lookAt(Vector3.new(mid.X, 0.14, mid.Y), Vector3.new(b.X, 0.14, b.Y)), STONE, Enum.Material.Pavement, false)
	p.CanQuery = false
end

local function ring(ctx: Ctx, cx: number, cz: number, r: number, width: number, steps: number)
	for i = 0, steps - 1 do
		local a1, a2 = i / steps * math.pi * 2, (i + 1) / steps * math.pi * 2
		pathLine(ctx, Vector2.new(cx + math.cos(a1) * r, cz + math.sin(a1) * r), Vector2.new(cx + math.cos(a2) * r, cz + math.sin(a2) * r), width)
	end
end

local function pond(ctx: Ctx, cx: number, cz: number, r: number)
	local rim = ctx.box("TepiKolam", Vector3.new(0.9, r * 2 + 3, r * 2 + 3), at(cx, 0.4, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(150, 150, 156), Enum.Material.Concrete)
	rim.Shape = Enum.PartType.Cylinder
	local water = ctx.box("Air", Vector3.new(0.6, r * 2, r * 2), at(cx, 0.62, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(70, 170, 215), Enum.Material.Glass, false)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.35
end

local function picnicTable(ctx: Ctx, x: number, z: number, yaw: number)
	local base = at(x, 0, z, yaw)
	ctx.box("MejaTop", Vector3.new(6, 0.4, 3), base * CFrame.new(0, 2.6, 0), WOOD, Enum.Material.Wood)
	for _, sz in { -1, 1 } do
		ctx.box("Bangku", Vector3.new(6, 0.4, 1.2), base * CFrame.new(0, 1.6, sz * 2.4), WOOD, Enum.Material.Wood)
		ctx.box("Kaki", Vector3.new(0.4, 2.6, 0.4), base * CFrame.new(-2.2, 1.3, sz * 1.0), WOOD, Enum.Material.Wood, false)
		ctx.box("Kaki", Vector3.new(0.4, 2.6, 0.4), base * CFrame.new(2.2, 1.3, sz * 1.0), WOOD, Enum.Material.Wood, false)
	end
end

local function umbrellaTable(ctx: Ctx, x: number, z: number, color: Color3)
	ctx.box("TiangPayung", Vector3.new(0.3, 7, 0.3), at(x, 3.5, z), WHITE, Enum.Material.Metal, false)
	local cone = ctx.box("Payung", Vector3.new(0.5, 8, 8), at(x, 7.1, z) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Fabric, false)
	cone.Shape = Enum.PartType.Cylinder
	local top = ctx.box("MejaBulat", Vector3.new(0.4, 4, 4), at(x, 2.6, z) * CFrame.Angles(0, 0, math.pi / 2), WHITE)
	top.Shape = Enum.PartType.Cylinder
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.7
		local seat = ctx.box("Kursi", Vector3.new(0.4, 1.6, 1.6), at(x + math.cos(a) * 3.4, 1.4, z + math.sin(a) * 3.4) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.SmoothPlastic)
		seat.Shape = Enum.PartType.Cylinder
	end
end

local function stall(ctx: Ctx, x: number, z: number, yaw: number, color: Color3, label: string)
	local base = at(x, 0, z, yaw)
	ctx.box("KiosDasar", Vector3.new(8, 3.2, 4.4), base * CFrame.new(0, 1.6, 0), rgb(236, 226, 205), Enum.Material.SmoothPlastic)
	ctx.box("KiosMeja", Vector3.new(8.6, 0.4, 2.4), base * CFrame.new(0, 3.4, -2.8), WOOD, Enum.Material.Wood)
	for _, sx in { -3.9, 3.9 } do
		ctx.box("KiosTiang", Vector3.new(0.4, 6.6, 0.4), base * CFrame.new(sx, 3.3, -3.8), WOOD, Enum.Material.Wood, false)
		ctx.box("KiosTiang", Vector3.new(0.4, 6.6, 0.4), base * CFrame.new(sx, 3.3, 2.0), WOOD, Enum.Material.Wood, false)
	end
	ctx.box("KiosAtap", Vector3.new(9.6, 0.5, 7), base * CFrame.new(0, 6.9, -0.9) * CFrame.Angles(math.rad(-8), 0, 0), color, Enum.Material.Fabric, false)
	for i = -3, 3 do
		if i % 2 == 0 then
			ctx.box("KiosLis", Vector3.new(1.2, 0.55, 7), base * CFrame.new(i * 1.3, 6.95, -0.9) * CFrame.Angles(math.rad(-8), 0, 0), WHITE, Enum.Material.Fabric, false)
		end
	end
	local sign = ctx.box("KiosPapan", Vector3.new(6, 1.4, 0.3), base * CFrame.new(0, 5.6, -3.9), rgb(60, 40, 30), Enum.Material.Wood, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = rgb(255, 228, 160)
	text.Parent = gui
end

local function swingSet(ctx: Ctx, x: number, z: number, yaw: number)
	local base = at(x, 0, z, yaw)
	local red = rgb(210, 70, 60)
	for _, sx in { -6, 6 } do
		ctx.box("AyunanKaki", Vector3.new(0.6, 9, 0.6), base * CFrame.new(sx, 4.5, -2) * CFrame.Angles(math.rad(12), 0, 0), red, Enum.Material.Metal, false)
		ctx.box("AyunanKaki", Vector3.new(0.6, 9, 0.6), base * CFrame.new(sx, 4.5, 2) * CFrame.Angles(math.rad(-12), 0, 0), red, Enum.Material.Metal, false)
	end
	ctx.box("AyunanPalang", Vector3.new(13, 0.7, 0.7), base * CFrame.new(0, 8.9, 0), red, Enum.Material.Metal, false)
	for _, sx in { -2.5, 2.5 } do
		for _, rx in { -0.6, 0.6 } do
			ctx.box("AyunanTali", Vector3.new(0.12, 6, 0.12), base * CFrame.new(sx + rx, 5.9, 0), DARK, Enum.Material.Metal, false)
		end
		ctx.box("AyunanDudukan", Vector3.new(1.8, 0.3, 1), base * CFrame.new(sx, 2.7, 0), rgb(240, 200, 60), Enum.Material.SmoothPlastic, false)
	end
end

local function seesaw(ctx: Ctx, x: number, z: number, yaw: number)
	local base = at(x, 0, z, yaw)
	ctx.box("JungkatPapan", Vector3.new(9, 0.4, 1.4), base * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(8)), rgb(60, 150, 210), Enum.Material.SmoothPlastic, false)
	ctx.box("JungkatTumpu", Vector3.new(1, 1.7, 1.6), base * CFrame.new(0, 0.85, 0), rgb(230, 80, 70), Enum.Material.SmoothPlastic)
end

local function sandbox(ctx: Ctx, x: number, z: number, w: number, d: number)
	ctx.box("BakPasirTepi", Vector3.new(w, 0.9, d), at(x, 0.45, z), WOOD, Enum.Material.Wood, false)
	ctx.box("Pasir", Vector3.new(w - 1.2, 0.3, d - 1.2), at(x, 0.85, z), rgb(238, 214, 150), Enum.Material.Sand, false)
end

local function gazebo(ctx: Ctx, x: number, z: number, r: number)
	local floor = ctx.box("GazeboLantai", Vector3.new(0.6, r * 2, r * 2), at(x, 0.45, z) * CFrame.Angles(0, 0, math.pi / 2), rgb(200, 190, 170), Enum.Material.Concrete)
	floor.Shape = Enum.PartType.Cylinder
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		ctx.box("GazeboTiang", Vector3.new(0.6, 8, 0.6), at(x + math.cos(a) * (r - 0.8), 4.4, z + math.sin(a) * (r - 0.8)), WHITE, Enum.Material.Wood, false)
	end
	local roof = ctx.box("GazeboAtap", Vector3.new(1.2, r * 2 + 3, r * 2 + 3), at(x, 8.9, z) * CFrame.Angles(0, 0, math.pi / 2), rgb(190, 70, 60), Enum.Material.SmoothPlastic, false)
	roof.Shape = Enum.PartType.Cylinder
	ctx.box("GazeboPuncak", Vector3.new(1, 1.6, 1), at(x, 9.9, z), rgb(190, 70, 60), Enum.Material.SmoothPlastic, false)
end

local function pavilion(ctx: Ctx, x: number, z: number, w: number, d: number, yaw: number)
	local base = at(x, 0, z, yaw)
	ctx.box("SaungLantai", Vector3.new(w, 0.6, d), base * CFrame.new(0, 0.3, 0), rgb(176, 150, 112), Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ctx.box("SaungTiang", Vector3.new(0.7, 7.4, 0.7), base * CFrame.new(sx * (w / 2 - 0.7), 4.2, sz * (d / 2 - 0.7)), WOOD, Enum.Material.Wood, false)
		end
	end
	ctx.box("SaungAtap", Vector3.new(w + 2.4, 0.7, d + 2.4), base * CFrame.new(0, 8.1, 0), rgb(120, 86, 58), Enum.Material.Wood, false)
	ctx.box("SaungAtapPuncak", Vector3.new(w + 0.6, 1.2, d * 0.5), base * CFrame.new(0, 8.9, 0), rgb(150, 104, 66), Enum.Material.Wood, false)
	picnicTable(ctx, x, z, yaw)
end

local function pergola(ctx: Ctx, x: number, z: number, length: number, yaw: number)
	local base = at(x, 0, z, yaw)
	local n = math.floor(length / 6)
	for i = 0, n do
		local px = -length / 2 + i * (length / n)
		for _, sz in { -2.6, 2.6 } do
			ctx.box("PergolaTiang", Vector3.new(0.6, 7.6, 0.6), base * CFrame.new(px, 3.8, sz), WHITE, Enum.Material.Wood, false)
		end
		ctx.box("PergolaBalok", Vector3.new(0.5, 0.5, 6.4), base * CFrame.new(px, 7.7, 0), WHITE, Enum.Material.Wood, false)
	end
	ctx.box("PergolaRel", Vector3.new(length, 0.4, 0.4), base * CFrame.new(0, 7.4, -2.6), WHITE, Enum.Material.Wood, false)
	ctx.box("PergolaRel", Vector3.new(length, 0.4, 0.4), base * CFrame.new(0, 7.4, 2.6), WHITE, Enum.Material.Wood, false)
end

local function goal(ctx: Ctx, x: number, z: number, yaw: number)
	local base = at(x, 0, z, yaw)
	for _, sx in { -7, 7 } do
		ctx.box("GawangTiang", Vector3.new(0.6, 7, 0.6), base * CFrame.new(sx, 3.5, 0), WHITE, Enum.Material.Metal, false)
	end
	ctx.box("GawangMistar", Vector3.new(14.6, 0.6, 0.6), base * CFrame.new(0, 7, 0), WHITE, Enum.Material.Metal, false)
	local net = ctx.box("GawangJaring", Vector3.new(14, 6.6, 0.1), base * CFrame.new(0, 3.5, 3), WHITE, Enum.Material.SmoothPlastic, false)
	net.Transparency = 0.7
end

local function hedgeRow(ctx: Ctx, x1: number, z1: number, x2: number, z2: number, spacing: number, scale: number)
	local d = Vector2.new(x2 - x1, z2 - z1)
	local n = math.max(1, math.floor(d.Magnitude / spacing))
	for i = 0, n do
		local t = i / n
		bush(ctx, x1 + d.X * t, z1 + d.Y * t, scale)
	end
end

----------------------------------------------------------------------
-- A. Pusat Olahraga dan Kuliner  (x 612..862, z 244..468)
----------------------------------------------------------------------
local function lotA(parent: Folder)
	local root = Instance.new("Folder")
	root.Name = "A_OlahragaKuliner"
	root.Parent = parent
	local ctx = newCtx(root, 11)
	slab(ctx, "Lahan", 737, 356, 250, 224, GRASS_A, Enum.Material.Grass)
	-- lapangan basket
	local ok, BasketCourt = pcall(function()
		return require(ServerStorage.MapBuilders.BasketCourt)
	end)
	if ok then
		local court = (BasketCourt :: any).build(CFrame.new(712, 0, 300), root)
		court.Name = "LapanganBasketTimur"
	end
	-- plaza kuliner
	slab(ctx, "Plaza", 737, 424, 230, 40, STONE, Enum.Material.Pavement, nil, 0.14)
	local colors = { rgb(214, 70, 60), rgb(240, 170, 50), rgb(70, 150, 210), rgb(90, 170, 100), rgb(180, 100, 190) }
	local names = { "BAKSO", "KOPI", "SATE", "ES TEH", "MARTABAK" }
	for i = 1, 5 do
		stall(ctx, 650 + (i - 1) * 45, 440, math.pi, colors[i], names[i])
		umbrellaTable(ctx, 650 + (i - 1) * 45 - 8, 418, colors[i])
		umbrellaTable(ctx, 650 + (i - 1) * 45 + 8, 412, colors[(i % 5) + 1])
	end
	-- area bermain kecil dan bangku sekeliling lapangan
	swingSet(ctx, 810, 268, 0)
	seesaw(ctx, 790, 300, 0)
	sandbox(ctx, 832, 306, 12, 10)
	for _, p in ipairs({ { 668, 258 }, { 756, 258 }, { 668, 340 }, { 756, 340 } }) do
		bench(ctx, p[1], p[2], if p[2] < 300 then math.pi else 0)
	end
	-- pohon, semak, lampu
	for k = 0, 8 do
		tree(ctx, 628 + k * 28, 252, ctx.rnd:NextNumber(10, 14))
		if k % 2 == 0 then
			lamp(ctx, 640 + k * 28, 392)
		end
	end
	for _ = 1, 9 do
		tree(ctx, ctx.rnd:NextNumber(840, 856), ctx.rnd:NextNumber(280, 400), ctx.rnd:NextNumber(10, 14))
	end
	hedgeRow(ctx, 622, 392, 852, 392, 7, 0.4)
	for _ = 1, 20 do
		tuft(ctx, ctx.rnd:NextNumber(620, 850), ctx.rnd:NextNumber(250, 385))
	end
	flowers(ctx, 760, 372, 8, 12)
end

----------------------------------------------------------------------
-- B. Taman Kota Kecil  (x 366..566, z 244..466)
----------------------------------------------------------------------
local function lotB(parent: Folder)
	local root = Instance.new("Folder")
	root.Name = "B_TamanKota"
	root.Parent = parent
	local ctx = newCtx(root, 22)
	slab(ctx, "Lahan", 466, 356, 200, 222, GRASS_B, Enum.Material.Grass)
	pond(ctx, 466, 356, 22)
	ring(ctx, 466, 356, 32, 5, 40)
	ring(ctx, 466, 356, 62, 5, 56)
	-- jalan silang ke empat arah
	for _, a in ipairs({ 0, math.pi / 2, math.pi, math.pi * 1.5 }) do
		pathLine(ctx, Vector2.new(466 + math.cos(a) * 32, 356 + math.sin(a) * 32), Vector2.new(466 + math.cos(a) * 98, 356 + math.sin(a) * 98), 5)
	end
	gazebo(ctx, 466, 296, 6.5)
	pathLine(ctx, Vector2.new(466, 303), Vector2.new(466, 330), 4)
	-- bedeng bunga dan bangku mengelilingi jalan luar
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.26
		flowers(ctx, 466 + math.cos(a) * 47, 356 + math.sin(a) * 47, 4, 8)
		bench(ctx, 466 + math.cos(a) * 66, 356 + math.sin(a) * 66, a + math.pi / 2 + math.pi)
		if k % 2 == 0 then
			lamp(ctx, 466 + math.cos(a) * 60, 356 + math.sin(a) * 60)
		end
	end
	-- pohon di sudut dan tepi
	for _, p in ipairs({ { 392, 270 }, { 540, 270 }, { 392, 442 }, { 540, 442 }, { 466, 262 }, { 466, 452 }, { 382, 356 }, { 550, 356 } }) do
		tree(ctx, p[1], p[2], ctx.rnd:NextNumber(12, 17))
	end
	for _ = 1, 24 do
		bush(ctx, ctx.rnd:NextNumber(372, 560), ctx.rnd:NextNumber(250, 462), 0.34)
		tuft(ctx, ctx.rnd:NextNumber(372, 560), ctx.rnd:NextNumber(250, 462))
	end
end

----------------------------------------------------------------------
-- C. Taman Bermain Keluarga  (x -248..-124, z 252..466)
----------------------------------------------------------------------
local function lotC(parent: Folder)
	local root = Instance.new("Folder")
	root.Name = "C_TamanBermain"
	root.Parent = parent
	local ctx = newCtx(root, 33)
	slab(ctx, "Lahan", -186, 359, 124, 214, GRASS_A, Enum.Material.Grass)
	-- alas karet bermain
	local mat = slab(ctx, "AlasBermain", -186, 318, 90, 70, rgb(228, 150, 90), Enum.Material.Plastic, nil, 0.16)
	mat.Material = Enum.Material.SmoothPlastic
	swingSet(ctx, -208, 300, 0)
	swingSet(ctx, -168, 300, 0)
	seesaw(ctx, -222, 336, 0)
	seesaw(ctx, -196, 336, math.pi / 2)
	sandbox(ctx, -160, 336, 18, 14)
	-- perosotan sederhana
	ctx.box("PerosotanMenara", Vector3.new(5, 7, 5), at(-142, 3.5, 318), rgb(70, 140, 210), Enum.Material.SmoothPlastic)
	ctx.box("PerosotanAtap", Vector3.new(6, 0.6, 6), at(-142, 7.3, 318), rgb(230, 80, 70), Enum.Material.SmoothPlastic, false)
	local slide = Instance.new("WedgePart")
	slide.Name = "Perosotan"
	slide.Size = Vector3.new(3.4, 7, 10)
	slide.CFrame = CFrame.new(-142, 3.5, 326) * CFrame.Angles(0, math.pi, 0)
	slide.Color = rgb(245, 205, 60)
	slide.Material = Enum.Material.SmoothPlastic
	slide.Anchored = true
	slide.Parent = root
	-- piknik dan gawang
	for k = 0, 2 do
		picnicTable(ctx, -226 + k * 34, 398, if k % 2 == 0 then 0 else math.pi / 2)
	end
	goal(ctx, -186, 452, 0)
	slab(ctx, "JalanBangku", -186, 270, 80, 5, STONE, Enum.Material.Pavement, nil, 0.14)
	for _, x in ipairs({ -226, -146 }) do
		bench(ctx, x, 280, 0)
		lamp(ctx, x, 262)
	end
	for _, p in ipairs({ { -236, 262 }, { -136, 262 }, { -236, 380 }, { -136, 380 }, { -236, 440 }, { -136, 440 } }) do
		tree(ctx, p[1], p[2], ctx.rnd:NextNumber(11, 15))
	end
	hedgeRow(ctx, -240, 366, -132, 366, 7, 0.38)
	for _ = 1, 16 do
		tuft(ctx, ctx.rnd:NextNumber(-240, -134), ctx.rnd:NextNumber(262, 450))
	end
	flowers(ctx, -210, 372, 6, 10)
end

----------------------------------------------------------------------
-- D. Kebun Bunga dan Piknik  (x -428..-322, z 244..466)
----------------------------------------------------------------------
local function lotD(parent: Folder)
	local root = Instance.new("Folder")
	root.Name = "D_KebunBunga"
	root.Parent = parent
	local ctx = newCtx(root, 44)
	slab(ctx, "Lahan", -375, 355, 106, 222, GRASS_B, Enum.Material.Grass)
	-- jalan kayu memanjang utara-selatan
	for z = 256, 456, 8 do
		ctx.box("PapanJalan", Vector3.new(5, 0.3, 7.4), at(-375, 0.22, z), WOOD, Enum.Material.WoodPlanks, false)
	end
	pergola(ctx, -375, 280, 30, math.pi / 2)
	-- baris bunga kiri-kanan jalan kayu
	for z = 300, 440, 20 do
		for _, sx in { -1, 1 } do
			flowers(ctx, -375 + sx * 13, z, 5, 14)
			hedgeRow(ctx, -375 + sx * 20, z - 7, -375 + sx * 20, z + 7, 5, 0.3)
		end
	end
	pavilion(ctx, -405, 262, 14, 10, 0)
	pavilion(ctx, -345, 262, 14, 10, 0)
	for _, z in ipairs({ 330, 395 }) do
		bench(ctx, -400, z, math.pi / 2)
		bench(ctx, -350, z, -math.pi / 2)
		lamp(ctx, -375, z)
	end
	for _, p in ipairs({ { -415, 300 }, { -335, 300 }, { -418, 372 }, { -332, 372 }, { -415, 440 }, { -335, 440 } }) do
		tree(ctx, p[1], p[2], ctx.rnd:NextNumber(12, 16))
	end
	for _ = 1, 14 do
		tuft(ctx, ctx.rnd:NextNumber(-425, -325), ctx.rnd:NextNumber(250, 462))
	end
end

----------------------------------------------------------------------
-- Halaman mewah: pagar semak, lampu taman, patio, bunga, pohon palem/rindang
----------------------------------------------------------------------
local function luxuryYards(parent: Folder)
	local map = workspace:WaitForChild("Map")
	local lux = map:WaitForChild("Neighborhoods"):WaitForChild("Houses"):FindFirstChild("RumahMewah")
	if not lux then
		return
	end
	local palms = (ServerStorage:WaitForChild("AsetPihakKetiga")):FindFirstChild("CliosowPalmTrees")
	local palm: Instance? = nil
	if palms then
		for _, c in palms:GetChildren() do
			if c:IsA("Model") then
				palm = c
				break
			end
		end
	end
	for i, h in lux:GetChildren() do
		if not h:IsA("Model") then
			continue
		end
		local root = Instance.new("Folder")
		root.Name = "HalamanMewah" .. i
		root.Parent = parent
		local ctx = newCtx(root, 100 + i)
		local pv = h:GetPivot()
		local rot = pv - pv.Position
		local function w(x: number, z: number): Vector3
			return pv.Position + rot:VectorToWorldSpace(Vector3.new(x, 0, z))
		end
		-- lokal: depan = -Z, halaman belakang = +Z; kolam di (35, 8)
		-- pagar balok bawaan rumah diganti deretan semak mesh
		for _, c in h:GetChildren() do
			if c:IsA("BasePart") and (c.Name == "Hedge" or c.Name == "HedgeBack" or c.Name == "HedgeFront") then
				c:Destroy()
			end
		end
		for x = -28, 40, 5 do -- belakang
			local p = w(x, 31)
			bush(ctx, p.X, p.Z, 0.42)
		end
		for z = -27, 31, 5 do -- samping kiri dan kanan
			local l, r = w(-28, z), w(40, z)
			bush(ctx, l.X, l.Z, 0.42)
			bush(ctx, r.X, r.Z, 0.42)
		end
		for x = -28, -5, 5 do -- depan, celah gerbang di x -3..15
			local p = w(x, -27)
			bush(ctx, p.X, p.Z, 0.42)
		end
		for x = 17, 40, 5 do
			local p = w(x, -27)
			bush(ctx, p.X, p.Z, 0.42)
		end
		for _, x in ipairs({ -2, 14 }) do -- lampu taman jalan masuk
			local p = w(x + 0.5, -22)
			lamp(ctx, p.X, p.Z)
		end
		for _, z in ipairs({ -12, 2 }) do
			local p = w(-22, z)
			lamp(ctx, p.X, p.Z)
		end
		-- patio di sisi kolam
		local pc = w(14, 22)
		local patio = ctx.box("Patio", Vector3.new(16, 0.3, 10), CFrame.new(pc.X, 0.2, pc.Z) * rot, rgb(210, 196, 172), Enum.Material.Pavement, false)
		patio.Name = "Patio"
		umbrellaTable(ctx, pc.X, pc.Z, rgb(240, 240, 235))
		-- pohon palem di sudut belakang + pohon rindang
		for _, x in ipairs({ -22, 38 }) do
			local p = w(x, 26)
			if palm then
				clone(ctx, palm, p.X, p.Z, nil, nil, "Palem")
			else
				tree(ctx, p.X, p.Z, 13)
			end
		end
		local tp = w(-20, 10)
		tree(ctx, tp.X, tp.Z, 11)
		local fp = w(-12, -16)
		flowers(ctx, fp.X, fp.Z, 4, 10)
		local fp2 = w(18, -18)
		flowers(ctx, fp2.X, fp2.Z, 4, 10)
	end
end

function ParkLots.build(): Folder
	local map = workspace:WaitForChild("Map")
	local old = map:FindFirstChild("TamanLahan")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "TamanLahan"
	root.Parent = map
	lotA(root)
	task.wait()
	lotB(root)
	task.wait()
	lotC(root)
	task.wait()
	lotD(root)
	task.wait()
	luxuryYards(root)
	return root
end

return function()
	return ParkLots.build()
end
