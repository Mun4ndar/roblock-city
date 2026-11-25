--!strict
--[[
	ROBLOCK CITY: SPBU baru (Blender). Dua model: minimarket yang bisa dimasuki (tools/blender/spbu_minimarket.py,
	asset 119680919516937, templat ServerStorage.SpbuMartMentah) dan kanopi + 4 pompa + selang
	(tools/blender/spbu_pompa.py, asset 131303291531109, templat ServerStorage.SpbuPompaMentah).
	Hasil: Workspace.Map.BangunanBlender.SPBU (Apron + SignPylon lama dipertahankan, sisanya diganti).
	Titik isi bensin = part "TitikPompa" bertag FuelPump (FuelService memasang prompt-nya).
	Penjaga kasir: NpcService grup "PenjagaSPBU" (titik di bawah, belakang meja kasir).

	Catatan impor FBX: tiap MeshPart rotasi 0, Position = pusat kotak mesh, Blender (x, y, z) menjadi
	dunia (-x, z, y). Minimarket diputar 180 derajat (pintu menghadap -Z, ke kanopi), jadi (x, z, -y).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MART_ORIGIN = Vector3.new(771, 1.3, -310) -- tengah denah minimarket, lantai
local PUMP_ORIGIN = Vector3.new(771, 1.3, -386) -- tengah kanopi, tanah

local function c3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- nama -> { warna, bahan, transparansi }
local MART_LOOK: { [string]: { any } } = {
	MtFloor = { c3(214, 216, 220), Enum.Material.SmoothPlastic, 0 },
	MtFloorB = { c3(160, 176, 192), Enum.Material.SmoothPlastic, 0 },
	MtRed = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
	MtWall = { c3(244, 240, 230), Enum.Material.SmoothPlastic, 0 },
	MtGlass = { c3(130, 190, 225), Enum.Material.Glass, 0.45 },
	MtDark = { c3(34, 38, 48), Enum.Material.SmoothPlastic, 0 },
	MtRoofW = { c3(250, 250, 250), Enum.Material.SmoothPlastic, 0 },
	MtCeil = { c3(236, 236, 240), Enum.Material.SmoothPlastic, 0 },
	MtLamp = { c3(255, 248, 225), Enum.Material.Neon, 0 },
	MtWhite = { c3(250, 250, 250), Enum.Material.SmoothPlastic, 0 },
	MtShelfDark = { c3(60, 66, 80), Enum.Material.Metal, 0 },
	MtShelf = { c3(205, 210, 216), Enum.Material.Metal, 0 },
	MtOilY = { c3(248, 204, 30), Enum.Material.SmoothPlastic, 0 },
	MtOilK = { c3(28, 28, 30), Enum.Material.SmoothPlastic, 0 },
	MtSnackR = { c3(228, 56, 56), Enum.Material.SmoothPlastic, 0 },
	MtSnackY = { c3(250, 210, 60), Enum.Material.SmoothPlastic, 0 },
	MtSnackB = { c3(60, 110, 230), Enum.Material.SmoothPlastic, 0 },
	MtSnackG = { c3(70, 180, 90), Enum.Material.SmoothPlastic, 0 },
	MtBottleB = { c3(60, 130, 240), Enum.Material.SmoothPlastic, 0 },
	MtBottleG = { c3(70, 200, 110), Enum.Material.SmoothPlastic, 0 },
	MtBottleO = { c3(248, 150, 40), Enum.Material.SmoothPlastic, 0 },
	MtBottleR = { c3(232, 60, 80), Enum.Material.SmoothPlastic, 0 },
	MtFridge = { c3(224, 232, 240), Enum.Material.SmoothPlastic, 0 },
	MtFridgeLit = { c3(210, 240, 255), Enum.Material.Neon, 0 },
	MtFridgeGlass = { c3(170, 215, 240), Enum.Material.Glass, 0.6 },
	MtFridgeShelf = { c3(180, 184, 190), Enum.Material.Metal, 0 },
	MtCounter = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
	MtScreen = { c3(80, 230, 160), Enum.Material.Neon, 0 },
}

local PUMP_LOOK: { [string]: { any } } = {
	PkRoof = { c3(250, 250, 252), Enum.Material.SmoothPlastic, 0 },
	PkRed = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
	PkUnder = { c3(222, 224, 230), Enum.Material.SmoothPlastic, 0 },
	PkPillar = { c3(236, 238, 242), Enum.Material.SmoothPlastic, 0 },
	PkLamp = { c3(255, 248, 225), Enum.Material.Neon, 0 },
	PmDark = { c3(34, 38, 48), Enum.Material.SmoothPlastic, 0 },
	PmBody = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
	PmWhite = { c3(250, 250, 250), Enum.Material.SmoothPlastic, 0 },
	PmRed = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
	PmScreen = { c3(90, 230, 170), Enum.Material.Neon, 0 },
	PmYellow = { c3(250, 200, 40), Enum.Material.SmoothPlastic, 0 },
	PmMetal = { c3(200, 204, 212), Enum.Material.Metal, 0 },
	PmHose = { c3(20, 20, 22), Enum.Material.SmoothPlastic, 0 },
	PiBase = { c3(150, 152, 160), Enum.Material.Concrete, 0 },
	PiYellow = { c3(250, 200, 40), Enum.Material.SmoothPlastic, 0 },
	PiRed = { c3(214, 40, 48), Enum.Material.SmoothPlastic, 0 },
}

local function place(
	raw: Instance,
	look: { [string]: { any } },
	parent: Instance,
	origin: Vector3,
	rotated: boolean,
	blenderCenter: Vector3
)
	-- pusat gabungan semua MeshPart = pusat kotak Blender, jadi asal Blender = pusat - (-x, z, y)
	local minV, maxV = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, d in raw:GetChildren() do
		if d:IsA("MeshPart") then
			local h = d.Size / 2
			minV = minV:Min(d.Position - h)
			maxV = maxV:Max(d.Position + h)
		end
	end
	local center = (minV + maxV) / 2
	local blOrigin = center - Vector3.new(-blenderCenter.X, blenderCenter.Z, blenderCenter.Y)
	local rot = CFrame.new(origin) * (if rotated then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
	for _, d in raw:GetChildren() do
		local spec = look[d.Name]
		if d:IsA("MeshPart") and spec then
			local part = d:Clone()
			part:ClearAllChildren()
			part.CFrame = rot * CFrame.new(d.Position - blOrigin)
			part.Color, part.Material, part.Transparency = spec[1], spec[2], spec[3]
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.CastShadow = spec[3] == 0
			part.Parent = parent
		end
	end
end

local function collider(parent: Instance, name: string, center: Vector3, size: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Position = center
	p.Parent = parent
end

return function(): number
	local martRaw = ServerStorage:FindFirstChild("SpbuMartMentah")
	local pumpRaw = ServerStorage:FindFirstChild("SpbuPompaMentah")
	local spbu = Workspace.Map.BangunanBlender:FindFirstChild("SPBU")
	if martRaw == nil or pumpRaw == nil or spbu == nil then
		warn("[BuildSpbuBaru] templat atau Workspace.Map.BangunanBlender.SPBU tidak ada")
		return 0
	end
	-- cadangan sekali (jangan timpa kalau sudah ada)
	local backups = ServerStorage:FindFirstChild("CadanganPeta")
	if backups and backups:FindFirstChild("SpbuLama") == nil then
		local old = spbu:Clone()
		old.Name = "SpbuLama"
		old.Parent = backups
	end
	local keep = { Apron = true, SignPylon = true }
	for _, child in spbu:GetChildren() do
		if not keep[child.Name] then
			child:Destroy()
		end
	end

	-- ------------------------------------------------ minimarket
	local mart = Instance.new("Model")
	mart.Name = "Minimarket"
	local function m(x: number, y: number, z: number): Vector3 -- titik Blender -> dunia (diputar 180)
		return MART_ORIGIN + Vector3.new(x, z, -y)
	end
	place(martRaw, MART_LOOK, mart, MART_ORIGIN, true, Vector3.new(0, 1.6, 8.425))
	collider(mart, "Lantai", m(0, 0, 0.15), Vector3.new(40.8, 0.3, 24.8))
	collider(mart, "DindingBelakang", m(0, -11.6, 5.5), Vector3.new(40, 11, 0.8))
	for _, sx in { -1, 1 } do
		collider(mart, "DindingDepan", m(sx * 11.8, 11.6, 5.5), Vector3.new(16.4, 11, 0.8))
		collider(mart, "DindingSamping", m(sx * 19.6, 0, 5.5), Vector3.new(0.8, 11, 24))
	end
	collider(mart, "BalokPintu", m(0, 11.6, 9.2), Vector3.new(7.2, 3.6, 0.8))
	collider(mart, "RakTengah1", m(-10, -1, 2.7), Vector3.new(14, 5.4, 2.2))
	collider(mart, "RakTengah2", m(-10, -6.2, 2.7), Vector3.new(14, 5.4, 2.2))
	collider(mart, "RakDinding", m(-8.8, -10.2, 3.6), Vector3.new(19.6, 7.2, 1.7))
	collider(mart, "Pendingin", m(11.5, -10, 4), Vector3.new(15, 7.2, 2.4))
	collider(mart, "MejaKasir", m(12.1, 6, 1.85), Vector3.new(14.2, 3.1, 2.2))
	collider(mart, "TumpukanOli", m(-14.2, 7.6, 2.4), Vector3.new(7, 4.2, 2))
	-- lampu dalam: dim saja (cahaya terang membuat ruangan putih silau)
	for _, x in { -14, -5, 5, 14 } do
		local lamp = Instance.new("Part")
		lamp.Name = "LampuToko"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.Transparency = 1
		lamp.Size = Vector3.new(1, 0.2, 1)
		lamp.Position = m(x, 0, 9.4)
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 0.28
		light.Color = c3(255, 244, 222)
		light.Parent = lamp
		lamp.Parent = mart
	end
	-- papan nama di depan papan atap (menghadap -Z)
	local sign = Instance.new("Part")
	sign.Name = "PapanNama"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Color = c3(34, 38, 48)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Size = Vector3.new(19, 4.2, 0.1)
	sign.Position = m(0, 11.75, 14.2) - Vector3.new(0, 0, 0.1)
	sign.Parent = mart
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SPBU  •  MINIMARKET"
	label.TextColor3 = c3(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
	mart.Parent = spbu

	-- ------------------------------------------------ kanopi + pompa
	local canopy = Instance.new("Model")
	canopy.Name = "KanopiPompa"
	local function k(x: number, y: number, z: number): Vector3 -- tanpa putaran: (-x, z, y)
		return PUMP_ORIGIN + Vector3.new(-x, z, y)
	end
	place(pumpRaw, PUMP_LOOK, canopy, PUMP_ORIGIN, false, Vector3.new(0, 0, 7.75))
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			collider(canopy, "Tiang", k(sx * 28, sy * 14, 7.2), Vector3.new(1.7, 14.4, 1.7))
		end
	end
	for _, ix in { -14, 14 } do
		collider(canopy, "Pulau", k(ix, 0, 0.45), Vector3.new(5, 0.9, 18))
		for _, iy in { -4.2, 4.2 } do
			collider(canopy, "Pompa", k(ix, iy, 3.9), Vector3.new(3.4, 6.2, 3.4))
			local point = Instance.new("Part")
			point.Name = "TitikPompa"
			point.Anchored = true
			point.CanCollide = false
			point.CanQuery = false
			point.Transparency = 1
			point.Size = Vector3.new(1, 1, 1)
			point.Position = k(ix, iy, 4)
			point.Parent = canopy
			CollectionService:AddTag(point, "FuelPump")
		end
	end
	for _, x in { -24, -8, 8, 24 } do
		local lamp = Instance.new("Part")
		lamp.Name = "LampuKanopiSPBU"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.Transparency = 1
		lamp.Size = Vector3.new(1, 0.2, 1)
		lamp.Position = k(x, 0, 13.5)
		local light = Instance.new("PointLight")
		light.Range = 34
		light.Brightness = 0.6
		light.Color = c3(255, 244, 222)
		light.Enabled = false
		light.Parent = lamp
		CollectionService:AddTag(lamp, "NightLight")
		lamp.Parent = canopy
	end
	canopy.Parent = spbu
	return #mart:GetDescendants() + #canopy:GetDescendants()
end
