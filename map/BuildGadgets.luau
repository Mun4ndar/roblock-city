--!strict
-- BuildGadgets: model barang ROBLOCK STORE yang dibuat dari part (tanpa aset luar).
--   * Skateboard Rocket dan Pedang Cahaya (model hasil generate lama gagal: tampil kotak merah "OOF!")
--   * Templat tool: ServerStorage.GadgetTemplates.<key> (boombox_neon dan headset_gamer disalin dari
--     ServerStorage.StoreItems), dipakai GadgetService untuk membuat Tool pemain.
--   * Etalase di Workspace.Map.Toko.RoblockStore memakai salinan templat ini.
-- Jalankan: require(MB.BuildGadgets)() di Edit mode (aman dijalankan ulang).

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local KEYS = { "boombox_neon", "skateboard_rocket", "headset_gamer", "pedang_cahaya" }
local STORE_SOURCE = { boombox_neon = "NeonBoombox", headset_gamer = "GamingHeadset" }
local STORE_LENGTH = { boombox_neon = 2.4, headset_gamer = 1.7 }

local function newModel(name: string): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Anchored = true
	core.CFrame = CFrame.new(0, 100, 0)
	core.Parent = model
	model.PrimaryPart = core
	return model, core
end

local function addPart(
	model: Model,
	core: Part,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = core.CFrame * offset
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local rgb = Color3.fromRGB
local BLOCK, CYL, BALL = Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball
local PLASTIC, NEON, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal

-- Papan di sepanjang sumbu X (panjang 3.2), lebar 0.9 di Z.
local function buildSkateboard(): Model
	local m, core = newModel("skateboard_rocket")
	local VERT = CFrame.Angles(0, 0, math.pi / 2) -- silinder tegak
	local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0) -- poros silinder searah Z
	local wood = rgb(238, 190, 130)
	addPart(m, core, "Deck", BLOCK, Vector3.new(2.7, 0.14, 0.9), CFrame.new(0, 0, 0), wood, PLASTIC)
	for _, sx in { -1, 1 } do
		addPart(
			m,
			core,
			"DeckEnd",
			CYL,
			Vector3.new(0.14, 0.9, 0.9),
			CFrame.new(sx * 1.35, 0.06, 0) * VERT,
			wood,
			PLASTIC
		)
		addPart(
			m,
			core,
			"GripEnd",
			CYL,
			Vector3.new(0.02, 0.78, 0.78),
			CFrame.new(sx * 1.35, 0.08, 0) * VERT,
			rgb(35, 38, 48),
			PLASTIC
		)
	end
	addPart(
		m,
		core,
		"GripTape",
		BLOCK,
		Vector3.new(2.7, 0.02, 0.78),
		CFrame.new(0, 0.08, 0),
		rgb(35, 38, 48),
		PLASTIC
	)
	addPart(
		m,
		core,
		"StripeFront",
		BLOCK,
		Vector3.new(2.5, 0.03, 0.06),
		CFrame.new(0, -0.075, 0.38),
		rgb(40, 200, 255),
		NEON
	)
	addPart(
		m,
		core,
		"StripeBack",
		BLOCK,
		Vector3.new(2.5, 0.03, 0.06),
		CFrame.new(0, -0.075, -0.38),
		rgb(40, 200, 255),
		NEON
	)
	for _, sx in { -0.95, 0.95 } do
		addPart(
			m,
			core,
			"Truck",
			BLOCK,
			Vector3.new(0.22, 0.1, 0.62),
			CFrame.new(sx, -0.12, 0),
			rgb(150, 155, 170),
			METAL
		)
		for _, sz in { -0.36, 0.36 } do
			addPart(
				m,
				core,
				"Wheel",
				CYL,
				Vector3.new(0.18, 0.4, 0.4),
				CFrame.new(sx, -0.2, sz) * ALONG_Z,
				rgb(20, 110, 255),
				NEON
			)
		end
	end
	-- roket kecil di belakang (sisi -X)
	addPart(
		m,
		core,
		"Thruster",
		CYL,
		Vector3.new(0.6, 0.3, 0.3),
		CFrame.new(-1.75, 0.02, 0),
		rgb(170, 175, 190),
		METAL
	)
	addPart(
		m,
		core,
		"FlameOuter",
		BALL,
		Vector3.new(0.7, 0.34, 0.34),
		CFrame.new(-2.15, 0.02, 0),
		rgb(255, 120, 30),
		NEON
	)
	addPart(
		m,
		core,
		"FlameInner",
		BALL,
		Vector3.new(0.4, 0.2, 0.2),
		CFrame.new(-2.1, 0.02, 0),
		rgb(255, 225, 90),
		NEON
	)
	return m
end

-- Pedang cahaya mainan (tanpa damage). Bilah menunjuk ke -Z, gagang ke +Z.
local function buildSaber(): Model
	local m, core = newModel("pedang_cahaya")
	local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
	local gold = rgb(255, 196, 60)
	addPart(
		m,
		core,
		"Grip",
		CYL,
		Vector3.new(1.3, 0.3, 0.3),
		CFrame.new(0, 0, 0.65) * ALONG_Z,
		rgb(40, 44, 58),
		PLASTIC
	)
	for i, z in { 0.2, 0.65, 1.1 } do
		addPart(
			m,
			core,
			"GripRing" .. i,
			CYL,
			Vector3.new(0.1, 0.36, 0.36),
			CFrame.new(0, 0, z) * ALONG_Z,
			gold,
			METAL
		)
	end
	addPart(
		m,
		core,
		"Pommel",
		BALL,
		Vector3.new(0.42, 0.42, 0.42),
		CFrame.new(0, 0, 1.38),
		gold,
		METAL
	)
	addPart(
		m,
		core,
		"Guard",
		BLOCK,
		Vector3.new(1.1, 0.16, 0.24),
		CFrame.new(0, 0, -0.05),
		gold,
		METAL
	)
	for _, sx in { -1, 1 } do
		addPart(
			m,
			core,
			"GuardCap",
			BALL,
			Vector3.new(0.26, 0.26, 0.26),
			CFrame.new(sx * 0.55, 0, -0.05),
			rgb(60, 220, 255),
			NEON
		)
	end
	local blade = addPart(
		m,
		core,
		"Blade",
		CYL,
		Vector3.new(2.6, 0.24, 0.24),
		CFrame.new(0, 0, -1.45) * ALONG_Z,
		rgb(60, 220, 255),
		NEON
	)
	addPart(
		m,
		core,
		"BladeTip",
		BALL,
		Vector3.new(0.24, 0.24, 0.24),
		CFrame.new(0, 0, -2.75),
		rgb(60, 220, 255),
		NEON
	)
	addPart(
		m,
		core,
		"BladeCore",
		CYL,
		Vector3.new(2.62, 0.12, 0.12),
		CFrame.new(0, 0, -1.45) * ALONG_Z,
		rgb(235, 255, 255),
		NEON
	)
	local light = Instance.new("PointLight")
	light.Color = rgb(60, 220, 255)
	light.Brightness = 0.8
	light.Range = 8
	light.Parent = blade
	return m
end

local function copyFromStoreItems(key: string, folder: Folder): Model?
	local items = ServerStorage:FindFirstChild("StoreItems")
	local source = items and items:FindFirstChild(STORE_SOURCE[key])
	local generated = source and source:FindFirstChild("Generated")
	if generated == nil then
		return nil
	end
	local parts = {}
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in generated:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = (d.CFrame * CFrame.new(
							sx * d.Size.X / 2,
							sy * d.Size.Y / 2,
							sz * d.Size.Z / 2
						)).Position
						mn = mn:Min(p)
						mx = mx:Max(p)
					end
				end
			end
		end
	end
	local size = mx - mn
	local center = (mx + mn) / 2
	local scale = STORE_LENGTH[key] / math.max(size.X, size.Y, size.Z)
	local model, core = newModel(key)
	for _, d in parts do
		local c = d:Clone()
		for _, k in c:GetDescendants() do
			if k:IsA("LuaSourceContainer") then
				k:Destroy()
			end
		end
		c.Size = d.Size * scale
		c.CFrame = CFrame.new(core.Position + (d.CFrame.Position - center) * scale)
			* (d.CFrame - d.CFrame.Position)
		c.Anchored = true
		c.CanCollide = false
		c.CanTouch = false
		c.CanQuery = false
		c.Massless = true
		c.Parent = model
	end
	model.Parent = folder
	return model
end

return function()
	local folder = ServerStorage:FindFirstChild("GadgetTemplates") :: Folder?
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "GadgetTemplates"
		folder.Parent = ServerStorage
	end
	local templates = folder :: Folder
	-- boombox + headset: salin dari StoreItems hanya bila belum ada
	for key in STORE_SOURCE do
		if templates:FindFirstChild(key) == nil then
			copyFromStoreItems(key, templates)
		end
	end
	for _, old in { "skateboard_rocket", "pedang_cahaya" } do
		local existing = templates:FindFirstChild(old)
		if existing then
			existing:Destroy()
		end
	end
	local skate = buildSkateboard()
	skate.Parent = templates
	local saber = buildSaber()
	saber.Parent = templates

	-- etalase: ganti model placeholder dengan salinan templat (berdiri tegak, menghadap -X)
	local store = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Toko")
	local roblock = store and store:FindFirstChild("RoblockStore")
	if roblock then
		for _, key in KEYS do
			if key == "skateboard_rocket" or key == "pedang_cahaya" then
				local pedestal: BasePart? = nil
				for _, c in roblock:GetChildren() do
					if c.Name == "Etalase_" .. key and c:IsA("BasePart") then
						pedestal = c
					elseif c.Name == "Etalase_" .. key and c:IsA("ProceduralModel") then
						c:Destroy()
					end
				end
				local old = roblock:FindFirstChild("Display_" .. key)
				if old then
					old:Destroy()
				end
				if pedestal then
					local display = (templates:FindFirstChild(key) :: Model):Clone()
					display.Name = "Display_" .. key
					local sizeBoost = if key == "pedang_cahaya" then 0.85 else 0.9
					local lookIn = CFrame.Angles(0, -math.pi / 2, 0) -- depan (-Z model) menghadap -X
					local upright = if key == "pedang_cahaya"
						then CFrame.Angles(math.pi / 2, 0, 0)
						else CFrame.Angles(0, 0, math.pi / 2)
					display:PivotTo(
						CFrame.new(pedestal.Position + Vector3.new(0, 1.95, 0)) * lookIn * upright
					)
					display:ScaleTo(sizeBoost)
					for _, d in display:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
						end
					end
					display.Parent = roblock
				end
			end
		end
	end
end
