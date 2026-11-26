--!strict
--[[
	BuildKemah: merapikan dan melengkapi Perkemahan tepi danau (Workspace.Map.Countryside.Perkemahan), lokasi lama
	tidak berubah (api unggun di sekitar (-864, y, -428), lereng barat bukit, danau di baratnya).
	Idempotent: tiap langkah menghapus hasil lamanya dulu. Jalankan dengan execute_luau di Edit:
	    require(MB.BuildKemah)()                 -- semua langkah
	    require(MB.BuildKemah)("tenda")          -- satu langkah: "teras" | "api" | "tenda" | "warung" | "dermaga"
	Langkah:
	  teras  : meratakan teras tanah 44x48 stud di lereng (terrain) + tanah gelap di sekitar api.
	  api    : api unggun (Fire + lampu), tumpukan kayu bakar, panggangan BBQ, bangku kayu bulat, titik NPC gitaris.
	  tenda  : dua tenda realistis dari ServerStorage.AsetKemah.TendaStilasi (Creator Store gratis, script dibuang).
	  warung : lapak Kak Sari (kanopi, meja, dagangan pancing/mie/tenda mini/ember ikan) + titik penjual.
	  dermaga: dermaga kayu ke danau dengan tiga titik memancing (tag KemahPancing).
	Tag/atribut dibaca CampService: KemahPusat, KemahApi (Kind), KemahPenjual, KemahPancing (LookX/LookZ/WaterY).
	Semua Part anchored, CanQuery=false untuk dekor (ringan di HP).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB
local SP, WOOD, FAB, MET, ROCK, NEON =
	Enum.Material.SmoothPlastic,
	Enum.Material.Wood,
	Enum.Material.Fabric,
	Enum.Material.Metal,
	Enum.Material.Slate,
	Enum.Material.Neon
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

local CENTER_X, CENTER_Z = -862, -428
local HALF_X, HALF_Z = 22, 24
local FIRE = Vector3.new(-864, 0, -428)
local TARGET_Y = 16

local function folderOf(): Folder
	local map = Workspace:WaitForChild("Map")
	local zone = map:WaitForChild("Countryside")
	local f = zone:FindFirstChild("Perkemahan")
	if f == nil then
		f = Instance.new("Folder")
		f.Name = "Perkemahan"
		f.Parent = zone
	end
	return f :: Folder
end

local function groundY(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position.Y else nil
end

local function padY(): number
	local sum, n = 0, 0
	for dx = -10, 10, 5 do
		for dz = -10, 10, 5 do
			local y = groundY(CENTER_X + dx, CENTER_Z + dz)
			if y then
				sum += y
				n += 1
			end
		end
	end
	return if n > 0 then sum / n else TARGET_Y
end

local function newModel(parent: Instance, name: string): Model
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = SP
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------- teras

local function stepTeras()
	local terrain = Workspace.Terrain
	local y = TARGET_Y
	local size = Vector3.new(HALF_X * 2, 0, HALF_Z * 2)
	-- isi di bawah y dengan rumput, buang tanah di atas y
	terrain:FillBlock(
		CFrame.new(CENTER_X, y - 10, CENTER_Z),
		Vector3.new(size.X, 20, size.Z),
		Enum.Material.Grass
	)
	terrain:FillBlock(
		CFrame.new(CENTER_X, y + 20, CENTER_Z),
		Vector3.new(size.X, 40, size.Z),
		Enum.Material.Air
	)
	-- tanah gelap di sekitar api unggun
	terrain:FillCylinder(CFrame.new(FIRE.X, y - 1.5, FIRE.Z), 3, 9, Enum.Material.Ground)
	return padY()
end

-- ---------------------------------------------------------------- api, kayu, panggangan, bangku

local function stepApi(f: Folder, y: number)
	local center = f:FindFirstChild("PusatKemah")
	if center then
		center:Destroy()
	end
	local c = part(f, {
		Name = "PusatKemah",
		Size = Vector3.new(2, 2, 2),
		Position = Vector3.new(FIRE.X, y + 1, FIRE.Z),
		Transparency = 1,
	})
	CollectionService:AddTag(c, "KemahPusat")

	-- api unggun
	local m = newModel(f, "Unggun")
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = 2.5
		part(m, {
			Name = "Batu",
			Shape = BALL,
			Size = Vector3.new(1.5 + (i % 3) * 0.25, 1.0, 1.4),
			CFrame = CFrame.new(FIRE.X + math.cos(a) * r, y + 0.35, FIRE.Z + math.sin(a) * r)
				* CFrame.Angles(0, a, 0),
			Color = rgb(120 + (i % 3) * 14, 118 + (i % 2) * 10, 114),
			Material = ROCK,
			CanCollide = true,
		})
	end
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		part(m, {
			Name = "Kayu",
			Shape = CYL,
			Size = Vector3.new(3.4, 0.55, 0.55),
			CFrame = CFrame.new(FIRE.X + math.cos(a) * 0.7, y + 0.9, FIRE.Z + math.sin(a) * 0.7)
				* CFrame.Angles(0, -a, math.rad(38)),
			Color = rgb(96 + i * 6, 64 + i * 3, 42),
			Material = WOOD,
		})
	end
	local flame = part(m, {
		Name = "ApiUnggun",
		Size = Vector3.new(3, 1, 3),
		Position = Vector3.new(FIRE.X, y + 1.2, FIRE.Z),
		Transparency = 1,
	})
	CollectionService:AddTag(flame, "KemahApi")
	flame:SetAttribute("Kind", "unggun")
	local fire = Instance.new("Fire")
	fire.Size = 3.5
	fire.Heat = 5
	fire.Color = rgb(255, 150, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 160, 80)
	light.Range = 24
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = flame
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Asap"
	smoke.Enabled = false
	smoke.Rate = 10
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(3, 4)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	smoke.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(rgb(190, 190, 190))
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = flame
	-- percikan
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Percikan"
	sparks.Rate = 3
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Speed = NumberRange.new(4, 7)
	sparks.Size = NumberSequence.new(0.15, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(rgb(255, 190, 80))
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Parent = flame

	-- bangku kayu bulat melingkari api
	local seats = newModel(f, "BangkuLog")
	local function log(x: number, z: number, along: string)
		local rot = if along == "x" then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
		part(seats, {
			Name = "Log",
			Shape = CYL,
			Size = Vector3.new(6.5, 1.7, 1.7),
			CFrame = CFrame.new(x, y + 0.85, z) * rot,
			Color = rgb(122, 86, 56),
			Material = WOOD,
			CanCollide = true,
		})
	end
	log(FIRE.X + 2, FIRE.Z + 6.5, "x") -- selatan: tempat gitaris
	log(FIRE.X, FIRE.Z - 6.5, "x")
	log(FIRE.X - 6.5, FIRE.Z, "z")
	-- titik duduk gitaris (tinggi = pusat badan saat duduk di atas log)
	local old = f:FindFirstChild("TitikGitaris")
	if old then
		old:Destroy()
	end
	local gx, gz = FIRE.X + 2, FIRE.Z + 6.5
	local seat = part(f, {
		Name = "TitikGitaris",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(
			Vector3.new(gx, y + 1.7 + 0.6, gz),
			Vector3.new(FIRE.X, y + 2.3, FIRE.Z)
		),
		Transparency = 1,
	})
	seat:SetAttribute("Kegunaan", "Titik duduk Kak Bagas")

	-- tumpukan kayu bakar + kapak di tunggul
	local wood = newModel(f, "KayuBakar")
	local px, pz = -877, -415
	for layer = 0, 2 do
		local count = 4 - layer
		for i = 1, count do
			part(wood, {
				Name = "Gelondong",
				Shape = CYL,
				Size = Vector3.new(5, 0.95, 0.95),
				CFrame = CFrame.new(px, y + 0.5 + layer * 0.85, pz + (i - (count + 1) / 2) * 1.02),
				Color = rgb(108 + (i * 7 + layer * 5) % 24, 72 + (i * 5) % 14, 46),
				Material = WOOD,
				CanCollide = layer == 0,
			})
		end
	end
	for i = 1, 3 do -- kayu terbelah berserakan
		part(wood, {
			Name = "Belahan",
			Size = Vector3.new(1.6, 0.35, 0.5),
			CFrame = CFrame.new(px + 3.8 + i * 0.6, y + 0.2, pz + 2 - i * 1.1)
				* CFrame.Angles(0, i * 0.9, 0),
			Color = rgb(190, 150, 100),
			Material = WOOD,
		})
	end
	local stump = part(wood, {
		Name = "Tunggul",
		Shape = CYL,
		Size = Vector3.new(1.5, 2.4, 2.4),
		CFrame = CFrame.new(px + 4.5, y + 0.75, pz - 3.2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(138, 98, 62),
		Material = WOOD,
		CanCollide = true,
	})
	part(wood, {
		Name = "GagangKapak",
		Size = Vector3.new(0.28, 2.0, 0.28),
		Position = stump.Position + Vector3.new(-0.2, 2.0, 0),
		Color = rgb(150, 105, 62),
		Material = WOOD,
	})
	part(wood, {
		Name = "MataKapak",
		Size = Vector3.new(0.7, 0.55, 0.14),
		Position = stump.Position + Vector3.new(-0.2, 2.2, 0.15),
		Color = rgb(150, 156, 164),
		Material = MET,
	})

	-- panggangan BBQ
	local bbq = newModel(f, "Panggangan")
	local bx, bz = FIRE.X + 11, FIRE.Z + 9
	local top = y + 2.8
	for _, off in
		{
			Vector3.new(-1.7, 0, -0.8),
			Vector3.new(1.7, 0, -0.8),
			Vector3.new(-1.7, 0, 0.8),
			Vector3.new(1.7, 0, 0.8),
		}
	do
		part(bbq, {
			Name = "Kaki",
			Shape = CYL,
			Size = Vector3.new(2.6, 0.28, 0.28),
			CFrame = CFrame.new(bx + off.X, y + 1.3, bz + off.Z)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(40, 40, 44),
			Material = MET,
		})
	end
	part(bbq, {
		Name = "Badan",
		Size = Vector3.new(4.4, 0.9, 2.2),
		Position = Vector3.new(bx, top - 0.45, bz),
		Color = rgb(52, 54, 60),
		Material = MET,
		CanCollide = true,
	})
	part(bbq, {
		Name = "Bara",
		Size = Vector3.new(3.9, 0.15, 1.7),
		Position = Vector3.new(bx, top + 0.02, bz),
		Color = rgb(255, 110, 30),
		Material = NEON,
	})
	for i = -3, 3 do
		part(bbq, {
			Name = "Jeruji",
			Shape = CYL,
			Size = Vector3.new(2.0, 0.08, 0.08),
			CFrame = CFrame.new(bx + i * 0.6, top + 0.35, bz)
				* CFrame.Angles(math.rad(90), 0, 0)
				* CFrame.Angles(0, 0, 0),
			Color = rgb(150, 150, 156),
			Material = MET,
		})
	end
	for i = -1, 1 do -- sate/sosis di atas jeruji
		part(bbq, {
			Name = "Sate",
			Shape = CYL,
			Size = Vector3.new(1.4, 0.32, 0.32),
			CFrame = CFrame.new(bx + i * 1.2, top + 0.5, bz)
				* CFrame.Angles(math.rad(90), 0, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(190, 90, 60),
			Material = SP,
		})
	end
	part(bbq, {
		Name = "Rak",
		Size = Vector3.new(4.4, 0.25, 1.1),
		Position = Vector3.new(bx, y + 1.5, bz),
		Color = rgb(150, 110, 70),
		Material = WOOD,
	})
	part(bbq, {
		Name = "MejaSamping",
		Size = Vector3.new(2.4, 0.25, 2.2),
		Position = Vector3.new(bx + 3.6, y + 2.6, bz),
		Color = rgb(150, 110, 70),
		Material = WOOD,
		CanCollide = true,
	})
	part(bbq, {
		Name = "KakiMeja",
		Size = Vector3.new(0.3, 2.5, 0.3),
		Position = Vector3.new(bx + 4.5, y + 1.3, bz),
		Color = rgb(110, 80, 50),
		Material = WOOD,
	})
	local grill = part(bbq, {
		Name = "ApiPanggang",
		Size = Vector3.new(4.6, 1.5, 2.4),
		Position = Vector3.new(bx, top + 0.3, bz),
		Transparency = 1,
	})
	CollectionService:AddTag(grill, "KemahApi")
	grill:SetAttribute("Kind", "panggangan")
	local bl = Instance.new("PointLight")
	bl.Color = rgb(255, 130, 60)
	bl.Range = 9
	bl.Brightness = 0.9
	bl.Shadows = false
	bl.Parent = grill
	local bs = Instance.new("ParticleEmitter")
	bs.Name = "Asap"
	bs.Rate = 6
	bs.Lifetime = NumberRange.new(1.2, 2)
	bs.Speed = NumberRange.new(2.5, 3.5)
	bs.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	bs.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	bs.Color = ColorSequence.new(rgb(210, 210, 210))
	bs.EmissionDirection = Enum.NormalId.Top
	bs.Enabled = true
	bs.Parent = grill
end

-- ---------------------------------------------------------------- tenda

local function stepTenda(f: Folder, y: number)
	local assets = ServerStorage:FindFirstChild("AsetKemah")
	local template = if assets then assets:FindFirstChild("TendaStilasi") else nil
	if template == nil then
		warn("[BuildKemah] ServerStorage.AsetKemah.TendaStilasi tidak ada")
		return
	end
	local spots = {
		{ name = "Tenda1", pos = Vector3.new(-849, y, -443), yaw = 90 },
		{ name = "Tenda2", pos = Vector3.new(-849, y, -428), yaw = 90 },
	}
	for _, s in spots do
		local old = f:FindFirstChild(s.name)
		if old then
			old:Destroy()
		end
		local tent = (template :: Model):Clone()
		tent.Name = s.name
		for _, d in tent:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- jangan pernah membawa script aset pihak ketiga
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		tent:PivotTo(
			CFrame.new(s.pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.rad(s.yaw), 0)
		)
		local box, size = tent:GetBoundingBox()
		tent:PivotTo(tent:GetPivot() + Vector3.new(0, y - (box.Position.Y - size.Y / 2) - 0.05, 0))
		tent.Parent = f
	end
end

-- ---------------------------------------------------------------- warung Kak Sari

local function stepWarung(f: Folder, y: number)
	local m = newModel(f, "WarungKemah")
	local cx, cz = -868, -445
	local W = 10
	local wood, wood2 = rgb(150, 104, 62), rgb(196, 150, 100)
	-- tiang
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, {
				Name = "Tiang",
				Shape = CYL,
				Size = Vector3.new(8, 0.5, 0.5),
				CFrame = CFrame.new(cx + sx * (W / 2 - 0.3), y + 4, cz + sz * 2.4)
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = wood,
				Material = WOOD,
				CanCollide = sz == 1,
			})
		end
	end
	-- kanopi belang merah-putih (miring ke depan/selatan)
	for i = 0, 9 do
		part(m, {
			Name = "Kanopi",
			Size = Vector3.new(W / 10 + 0.02, 0.25, 7.4),
			CFrame = CFrame.new(cx - W / 2 + (i + 0.5) * (W / 10), y + 8.3, cz)
				* CFrame.Angles(math.rad(-9), 0, 0),
			Color = if i % 2 == 0 then rgb(214, 62, 54) else rgb(250, 244, 232),
			Material = FAB,
		})
	end
	part(m, {
		Name = "Rumbai",
		Size = Vector3.new(W, 0.9, 0.12),
		Position = Vector3.new(cx, y + 7.6, cz + 3.55),
		Color = rgb(250, 244, 232),
		Material = FAB,
	})
	-- dinding belakang dari kain
	part(m, {
		Name = "Belakang",
		Size = Vector3.new(W - 0.4, 6.5, 0.2),
		Position = Vector3.new(cx, y + 3.9, cz - 2.4),
		Color = rgb(232, 214, 176),
		Material = FAB,
	})
	-- meja jual
	part(m, {
		Name = "MejaJual",
		Size = Vector3.new(W - 1, 3.1, 1.8),
		Position = Vector3.new(cx, y + 1.55, cz + 1.8),
		Color = wood,
		Material = WOOD,
		CanCollide = true,
	})
	part(m, {
		Name = "PapanMeja",
		Size = Vector3.new(W - 0.6, 0.3, 2.6),
		Position = Vector3.new(cx, y + 3.25, cz + 1.8),
		Color = wood2,
		Material = WOOD,
	})
	-- papan nama
	local sign = part(m, {
		Name = "Papan",
		Size = Vector3.new(7, 1.6, 0.25),
		Position = Vector3.new(cx, y + 6.7, cz + 3.45),
		Color = rgb(96, 64, 40),
		Material = WOOD,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = rgb(255, 232, 160)
	lbl.Text = "WARUNG KEMAH"
	lbl.Parent = gui
	-- dagangan: joran bersandar, mie cup, tenda mini, ember ikan
	for i = 1, 3 do
		part(m, {
			Name = "Joran",
			Shape = CYL,
			Size = Vector3.new(7, 0.16, 0.16),
			CFrame = CFrame.new(cx - 3.8 + i * 0.55, y + 3.9, cz - 2.1)
				* CFrame.Angles(0, 0, math.rad(90 - 8 + i * 3)),
			Color = rgb(120 + i * 18, 82, 50),
			Material = WOOD,
		})
	end
	local cupColors = { rgb(235, 80, 60), rgb(250, 190, 40), rgb(70, 160, 90) }
	for i = 1, 3 do
		local cx2 = cx + 0.5 + i * 0.95
		part(m, {
			Name = "MieCup",
			Shape = CYL,
			Size = Vector3.new(0.9, 0.85, 0.85),
			CFrame = CFrame.new(cx2, y + 3.85, cz + 1.9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = cupColors[i],
			Material = SP,
		})
		part(m, {
			Name = "TutupMie",
			Shape = CYL,
			Size = Vector3.new(0.12, 0.95, 0.95),
			CFrame = CFrame.new(cx2, y + 4.3, cz + 1.9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(245, 245, 245),
			Material = SP,
		})
	end
	local tentMini = part(m, {
		Name = "TendaMini",
		Size = Vector3.new(2, 1.3, 1.6),
		Position = Vector3.new(cx - 2.6, y + 3.95, cz + 1.9),
		Color = rgb(240, 120, 60),
		Material = FAB,
	})
	tentMini.Shape = BLOCK
	local wedge = Instance.new("WedgePart")
	wedge.Name = "AtapTendaMini"
	wedge.Anchored = true
	wedge.CanCollide, wedge.CanQuery, wedge.CanTouch = false, false, false
	wedge.Size = Vector3.new(1.6, 1.1, 2)
	wedge.CFrame = CFrame.new(cx - 2.6, y + 5.2, cz + 1.9) * CFrame.Angles(0, math.rad(90), 0)
	wedge.Color = rgb(240, 120, 60)
	wedge.Material = FAB
	wedge.Parent = m
	part(m, {
		Name = "Ember",
		Shape = CYL,
		Size = Vector3.new(1.5, 1.6, 1.6),
		CFrame = CFrame.new(cx + 4.2, y + 1.2, cz + 4.3) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(70, 140, 215),
		Material = SP,
		CanCollide = true,
	})
	for i = 1, 3 do
		part(m, {
			Name = "IkanEmber",
			Shape = BALL,
			Size = Vector3.new(1.3, 0.5, 0.5),
			CFrame = CFrame.new(cx + 3.9 + i * 0.3, y + 2.1, cz + 4.1 + i * 0.2)
				* CFrame.Angles(0, i, math.rad(20)),
			Color = rgb(150 + i * 25, 170, 190),
			Material = SP,
		})
	end
	-- titik penjual (di belakang meja) + zona belanja
	local old = f:FindFirstChild("TitikPenjual")
	if old then
		old:Destroy()
	end
	part(f, {
		Name = "TitikPenjual",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(Vector3.new(cx, y + 1, cz - 0.6), Vector3.new(cx, y + 1, cz + 10)),
		Transparency = 1,
	})
	local zone = part(m, {
		Name = "ZonaBelanja",
		Size = Vector3.new(W, 3, 4),
		Position = Vector3.new(cx, y + 3.5, cz + 3.4),
		Transparency = 1,
	})
	CollectionService:AddTag(zone, "KemahPenjual")
end

-- ---------------------------------------------------------------- dermaga

local function stepDermaga(f: Folder)
	local m = newModel(f, "Dermaga")
	local z0 = -445
	local topY = 1.3
	local plank = rgb(168, 122, 78)
	local function board(x0: number, x1: number, zc: number, depth: number, tone: number)
		part(m, {
			Name = "Papan",
			Size = Vector3.new(x0 - x1, 0.35, depth),
			Position = Vector3.new((x0 + x1) / 2, topY, zc),
			Color = Color3.new(plank.R * tone, plank.G * tone, plank.B * tone),
			Material = WOOD,
			CanCollide = true,
			CanQuery = true,
		})
	end
	-- jalur utama dari darat (x -904) ke ujung (x -932)
	local step = 2.2
	local x = -904
	local k = 0
	while x - step >= -932 do
		board(x, x - step + 0.1, z0, 5.2, 0.92 + (k % 3) * 0.04)
		x -= step
		k += 1
	end
	-- kepala dermaga (T)
	local tx = -934
	for i = 0, 5 do
		board(tx + 2.2, tx, z0 - 7 + i * 2.8 + 1.4 - 1.4, 2.7, 0.9 + (i % 3) * 0.05)
	end
	-- tiang penyangga
	for _, px in { -906, -912, -918, -924, -930 } do
		for _, sz in { -2.4, 2.4 } do
			part(m, {
				Name = "Tiang",
				Shape = CYL,
				Size = Vector3.new(6, 0.6, 0.6),
				CFrame = CFrame.new(px, topY - 2.6, z0 + sz) * CFrame.Angles(0, 0, math.rad(90)),
				Color = rgb(96, 66, 42),
				Material = WOOD,
				CanCollide = false,
			})
		end
	end
	for _, pz in { -7.5, -2.5, 2.5, 7.5 } do
		part(m, {
			Name = "TiangUjung",
			Shape = CYL,
			Size = Vector3.new(6, 0.6, 0.6),
			CFrame = CFrame.new(tx - 0.6, topY - 2.6, z0 + pz) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(96, 66, 42),
			Material = WOOD,
		})
	end
	-- pagar rendah di sisi jalur + lentera di ujung
	for _, sz in { -2.7, 2.7 } do
		part(m, {
			Name = "Pagar",
			Size = Vector3.new(26, 0.2, 0.2),
			Position = Vector3.new(-917, topY + 1.4, z0 + sz),
			Color = rgb(120, 84, 52),
			Material = WOOD,
		})
	end
	local lampPost = part(m, {
		Name = "TiangLentera",
		Size = Vector3.new(0.3, 4.2, 0.3),
		Position = Vector3.new(-934.2, topY + 2.4, z0 + 7),
		Color = rgb(96, 66, 42),
		Material = WOOD,
	})
	local lamp = part(m, {
		Name = "Lentera",
		Shape = BALL,
		Size = Vector3.one * 1.0,
		Position = lampPost.Position + Vector3.new(0, 2.3, 0),
		Color = rgb(255, 200, 110),
		Material = NEON,
	})
	local pl = Instance.new("PointLight")
	pl.Color = rgb(255, 200, 120)
	pl.Range = 16
	pl.Brightness = 1
	pl.Shadows = false
	pl.Parent = lamp
	-- titik memancing (tiga, menghadap barat ke air)
	for i = -1, 1 do
		local spot = part(m, {
			Name = "TitikPancing",
			Size = Vector3.new(3, 1, 3),
			Position = Vector3.new(tx - 0.3, topY + 0.8, z0 + i * 5),
			Transparency = 1,
		})
		CollectionService:AddTag(spot, "KemahPancing")
		spot:SetAttribute("LookX", -1)
		spot:SetAttribute("LookZ", 0)
		spot:SetAttribute("WaterY", -1)
	end
	-- papan petunjuk di pangkal dermaga
	local post = part(m, {
		Name = "PapanTiang",
		Size = Vector3.new(0.4, 4, 0.4),
		Position = Vector3.new(-902, 2.2, z0 - 4.6),
		Color = rgb(96, 66, 42),
		Material = WOOD,
	})
	local board2 = part(m, {
		Name = "PapanPetunjuk",
		Size = Vector3.new(0.25, 1.8, 4.6),
		Position = post.Position + Vector3.new(0, 1.6, 0),
		Color = rgb(112, 78, 48),
		Material = WOOD,
	})
	local g2 = Instance.new("SurfaceGui")
	g2.Face = Enum.NormalId.Right
	g2.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g2.PixelsPerStud = 40
	g2.Parent = board2
	local l2 = Instance.new("TextLabel")
	l2.Size = UDim2.fromScale(1, 1)
	l2.BackgroundTransparency = 1
	l2.Font = Enum.Font.FredokaOne
	l2.TextScaled = true
	l2.TextColor3 = rgb(255, 232, 160)
	l2.Text = "🎣 Dermaga Memancing"
	l2.Parent = g2
end

-- ---------------------------------------------------------------- utama

return function(only: string?)
	local f = folderOf()
	-- bersihkan sisa kemah lama (balok tenda, api bola neon, meja piknik)
	if only == nil or only == "teras" then
		for _, child in f:GetChildren() do
			if
				child:IsA("BasePart")
				and (
					child.Name == "Tenda"
					or child.Name == "KayuBakar"
					or child.Name == "ApiUnggun"
					or child.Name == "MejaPiknik"
					or child.Name == "BangkuPiknik"
				)
			then
				child:Destroy()
			end
		end
	end
	local y = padY()
	if only == nil or only == "teras" then
		y = stepTeras()
		task.wait(1)
		y = padY()
	end
	if only == nil or only == "api" then
		stepApi(f, y)
	end
	if only == nil or only == "tenda" then
		stepTenda(f, y)
	end
	if only == nil or only == "warung" then
		stepWarung(f, y)
	end
	if only == nil or only == "dermaga" then
		stepDermaga(f)
	end
	return y
end
