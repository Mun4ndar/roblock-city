--[[
	ROBLOCK CITY: rias dunia (tampilan), terpisah dari skrip pembangun bentuk.
	Jalankan PALING AKHIR, dan ulangi setiap kali ada kawasan yang dibangun ulang. Aman diulang.

	Yang dikerjakan:
	  "lighting"  : langit, awan, matahari, kabut, dan efek visual (pengganti plugin Atmos / Celestial Body Dragger).
	  "materials" : material tiap part menurut namanya + MaterialVariant paving (pengganti material pack).
	  "lights"    : semua lampu disetel serentak dari tabel LIGHTS (pengganti Light Editor).
	  "scenery"   : semak, batu, dan bunga disebar acak di rumput kosong -> Workspace.Map.Scenery
	                (pengganti Brush Tool). Hasilnya selalu sama karena memakai SEED.

	Pakai (Studio, mode Edit):
	  require(game.ServerStorage.MapBuilders.StyleWorld)()            -- semua
	  require(game.ServerStorage.MapBuilders.StyleWorld)("lighting")  -- satu bagian saja

	Semua hiasan tanpa tabrakan dan tanpa bayangan supaya tetap ringan di HP.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")
local Kit = require(script.Parent.MapKit)

local M = Enum.Material
local rgb = Color3.fromRGB

--------------------------------------------------------------------------
-- Pencahayaan
--------------------------------------------------------------------------

local LOOK = {
	clockTime = 14.6, -- sore awal: bayangan agak panjang tapi tetap terang
	latitude = 28, -- memiringkan matahari supaya bayangan jatuh serong
	brightness = 3,
	exposure = 0.05,
	ambient = rgb(60, 66, 80),
	outdoorAmbient = rgb(138, 150, 172), -- bayangan kebiruan, tidak gelap
	sunTint = rgb(255, 244, 224),
	shadowSoftness = 0.3,
	atmosphere = {
		Density = 0.24,
		Offset = 0.3,
		Color = rgb(214, 230, 248),
		Decay = rgb(128, 168, 226),
		Glare = 0.15,
		Haze = 0.4,
	},
	clouds = { Cover = 0.55, Density = 0.45, Color = rgb(255, 255, 255) },
	bloom = { Intensity = 0.35, Size = 26, Threshold = 1.5 },
	color = { Brightness = 0.02, Contrast = 0.07, Saturation = 0.1 },
	sunRays = { Intensity = 0.05, Spread = 0.65 },
}

local TAG = "RoblockStyle"

-- Ambil objek rias milik kita (bertanda atribut), atau buat baru.
local function ours(className: string, parent: Instance): Instance
	for _, c in parent:GetChildren() do
		if c.ClassName == className and c:GetAttribute(TAG) then
			return c
		end
	end
	local inst = Instance.new(className)
	inst.Name = className
	inst:SetAttribute(TAG, true)
	inst.Parent = parent
	return inst
end

local function apply(inst: Instance, props: { [string]: any })
	for k, v in props do
		(inst :: any)[k] = v
	end
end

-- Langit/kabut/efek lain yang bukan milik kita (mis. dari Toolbox) dipindahkan, tidak dihapus,
-- supaya hasilnya pasti dan tidak ada dua Sky yang berebut.
local function parkForeign()
	local parked = ServerStorage:FindFirstChild("LightingLama")
	for _, c in Lighting:GetChildren() do
		local styled = c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect")
		if styled and not c:GetAttribute(TAG) then
			if not parked then
				parked = Kit.folder("LightingLama", ServerStorage)
			end
			c.Parent = parked
		end
	end
end

local function lighting()
	parkForeign()

	Lighting.ClockTime = LOOK.clockTime
	Lighting.GeographicLatitude = LOOK.latitude
	Lighting.Brightness = LOOK.brightness
	Lighting.ExposureCompensation = LOOK.exposure
	Lighting.Ambient = LOOK.ambient
	Lighting.OutdoorAmbient = LOOK.outdoorAmbient
	Lighting.ColorShift_Top = LOOK.sunTint
	Lighting.ColorShift_Bottom = rgb(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = LOOK.shadowSoftness
	Lighting.FogEnd = 100000

	-- Langit bawaan Roblox (tanpa tekstur pihak ketiga) + awan dinamis.
	local sky = ours("Sky", Lighting) :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 10
	sky.StarCount = 2500
	sky.CelestialBodiesShown = true

	apply(ours("Atmosphere", Lighting), LOOK.atmosphere)
	apply(ours("Clouds", workspace.Terrain), LOOK.clouds)
	apply(ours("BloomEffect", Lighting), LOOK.bloom)
	apply(ours("ColorCorrectionEffect", Lighting), LOOK.color)
	apply(ours("SunRaysEffect", Lighting), LOOK.sunRays)

	-- Air sedikit lebih jernih dan memantulkan langit.
	local T = workspace.Terrain
	T.WaterColor = rgb(36, 178, 208)
	T.WaterTransparency = 0.5
	T.WaterReflectance = 0.45
	T.WaterWaveSize = 0.1
	T.WaterWaveSpeed = 7
	T:SetMaterialColor(M.Grass, rgb(104, 176, 74))
	T:SetMaterialColor(M.Sand, rgb(242, 226, 176))
end

--------------------------------------------------------------------------
-- Material
--------------------------------------------------------------------------

-- MaterialVariant buatan sendiri (tekstur dibuat dengan generator material Roblox Studio).
-- Kalau belum ada di MaterialService, dibuat ulang dari ID ini.
local VARIANTS = {
	{
		name = "PavingKota",
		base = M.Pavement,
		studsPerTile = 8,
		color = "rbxassetid://71797495294786",
		normal = "rbxassetid://97900043009283",
		roughness = "rbxassetid://115353513203858",
		metalness = "rbxassetid://111426034867901",
	},
}

local function ensureVariants()
	for _, v in VARIANTS do
		local mv = MaterialService:FindFirstChild(v.name, true)
		if not (mv and mv:IsA("MaterialVariant")) then
			mv = Instance.new("MaterialVariant")
			mv.Name = v.name
			mv.Parent = MaterialService
		end
		local variant = mv :: MaterialVariant
		variant.BaseMaterial = v.base
		variant.ColorMap = v.color
		variant.NormalMap = v.normal
		variant.RoughnessMap = v.roughness
		variant.MetalnessMap = v.metalness
		variant.StudsPerTile = v.studsPerTile
	end
end

type Rule = {
	names: { string }, -- pola Lua untuk nama part
	from: { Enum.Material }?, -- hanya part dengan material ini (default: semua)
	sibling: string?, -- hanya jika ada saudara dengan nama ini (membedakan rumah dari gedung)
	material: Enum.Material?,
	variant: string?,
	color: Color3?,
	reflectance: number?,
}

-- Aturan pertama yang cocok dipakai. Menambah gaya baru = menambah satu aturan.
local RULES: { Rule } = {
	-- Trotoar, lantai blok kota, jalan masuk rumah: paving block
	{
		names = {
			"^Trotoar$",
			"^Blok%d+$",
			"Block$",
			"^Driveway$",
			"^Median$",
			"^PoolDeck$",
			"^Plinth$",
		},
		from = { M.Concrete, M.Pavement, M.SmoothPlastic },
		material = M.Pavement,
		variant = "PavingKota",
		color = rgb(236, 231, 222),
	},
	-- Dinding rumah: plester halus
	{
		names = { "^Body$", "^Garage$" },
		from = { M.SmoothPlastic },
		sibling = "RoofFront",
		material = M.Plaster,
	},
	{
		names = { "^GroundFloor$", "^UpperFloor$" },
		from = { M.SmoothPlastic },
		material = M.Plaster,
	},
	-- Atap rumah: genteng
	{
		names = { "^RoofFront$", "^RoofBack$", "^GarageRoof$", "^SlideRoofB?$" },
		from = { M.SmoothPlastic },
		material = M.RoofShingles,
	},
	-- Kaca: memantulkan langit
	{
		names = {
			"^Window%d*$",
			"^Windows%d+$",
			"^GlassFront$",
			"^UpperGlass$",
			"^Storefront$",
			"^GlassWall$",
		},
		reflectance = 0.28,
	},
	-- Menara kaca Downtown
	{ names = { "^Body%d$" }, from = { M.SmoothPlastic }, reflectance = 0.12 },
	-- Semak dan pagar tanaman: daun
	{ names = { "^Bush$", "^Hedge", "^Tanaman$" }, from = { M.Grass }, material = M.LeafyGrass },
}

local function matches(part: BasePart, rule: Rule): boolean
	local hit = false
	for _, pattern in rule.names do
		if string.find(part.Name, pattern) then
			hit = true
			break
		end
	end
	if not hit then
		return false
	end
	if rule.from and not table.find(rule.from, part.Material) then
		return false
	end
	if rule.sibling and not (part.Parent and part.Parent:FindFirstChild(rule.sibling)) then
		return false
	end
	return true
end

local function materials(): number
	ensureVariants()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return 0
	end
	local changed = 0
	for i, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			for _, rule in RULES do
				if matches(d, rule) then
					if rule.material then
						d.Material = rule.material
					end
					if rule.variant then
						d.MaterialVariant = rule.variant
					end
					if rule.color then
						d.Color = rule.color
					end
					if rule.reflectance then
						d.Reflectance = rule.reflectance
					end
					changed += 1
					break
				end
			end
		end
		if i % 2000 == 0 then
			task.wait()
		end
	end
	return changed
end

--------------------------------------------------------------------------
-- Lampu
--------------------------------------------------------------------------

-- Setelan per nama part induk lampu. Tanpa bayangan: ratusan lampu berbayang terlalu berat.
local LIGHTS: { [string]: { Range: number, Brightness: number, Color: Color3 } } = {
	Lamp = { Range = 40, Brightness = 3, Color = rgb(255, 222, 168) }, -- lampu jalan
}

-- Tag untuk siklus siang/malam (lihat src/shared/DayNightConfig.luau): client
-- menyalakan part bertag NightLight dan sebagian jendela bertag NightWindow saat malam.
local TAG_NIGHT_LIGHT = "NightLight"
local TAG_NIGHT_WINDOW = "NightWindow"
local NIGHT_WINDOW_NAMES = { "^Window%d*$", "^Windows%d*$", "^Storefront$", "^TowerWindows%d*$" }

local function lights(): number
	local map = workspace:FindFirstChild("Map")
	if not map then
		return 0
	end
	local n = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			for _, pattern in NIGHT_WINDOW_NAMES do
				if d.Name:match(pattern) then
					CollectionService:AddTag(d, TAG_NIGHT_WINDOW)
					break
				end
			end
		elseif d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") then
			CollectionService:AddTag(d.Parent, TAG_NIGHT_LIGHT)
		end
		if d:IsA("Light") then
			d.Shadows = false
			local cfg = d.Parent and LIGHTS[d.Parent.Name]
			if cfg then
				d.Brightness = cfg.Brightness
				d.Color = cfg.Color
				if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
					d.Range = cfg.Range
				end
				n += 1
			end
		end
	end
	return n
end

--------------------------------------------------------------------------
-- Hiasan alam (semak, batu, bunga)
--------------------------------------------------------------------------

local SEED = 20261122
local MAX_TRIES = 600 -- percobaan gerombol per kawasan

-- box = x0, z0, x1, z1; parts = batas jumlah part hiasan di kawasan itu;
-- weights = bobot { semak, batu, bunga }
local REGIONS = {
	{ name = "Countryside", box = { -1450, -1150, -550, 350 }, parts = 450, weights = { 4, 4, 3 } },
	{ name = "Downtown", box = { -400, -1000, 800, -200 }, parts = 550, weights = { 5, 1, 4 } },
	{ name = "Perumahan", box = { -400, -100, 800, 1000 }, parts = 650, weights = { 5, 1, 4 } },
	{ name = "Bandara", box = { -1450, 450, -600, 1150 }, parts = 100, weights = { 4, 3, 1 } },
	{ name = "Beach", box = { 1380, -560, 2160, 760 }, parts = 250, weights = { 3, 5, 2 } },
	{ name = "Pesisir", box = { -1500, -1300, 1150, 1300 }, parts = 250, weights = { 4, 4, 2 } },
}

local BUSH_COLORS = { rgb(74, 150, 62), rgb(92, 166, 70), rgb(62, 138, 78), rgb(112, 176, 64) }
local ROCK_COLORS =
	{ rgb(150, 148, 156), rgb(134, 132, 140), rgb(168, 164, 166), rgb(122, 124, 134) }
local FLOWER_COLORS = {
	rgb(255, 214, 64),
	rgb(255, 128, 160),
	rgb(240, 96, 88),
	rgb(250, 250, 250),
	rgb(176, 132, 240),
	rgb(255, 160, 72),
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function bush(rng: Random, pos: Vector3, parent: Instance): number
	local s = rng:NextNumber(0.7, 1.7)
	local color = pick(rng, BUSH_COLORS)
	local blobs = rng:NextInteger(2, 3)
	for i = 1, blobs do
		local d = rng:NextNumber(2.6, 4.2) * s
		local off = if i == 1
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * s
		Kit.deco({
			Name = "Semak",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d * rng:NextNumber(0.7, 0.9), d),
			CFrame = CFrame.new(pos + off + Vector3.new(0, d * 0.22, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Color = color:Lerp(Color3.new(1, 1, 0.6), rng:NextNumber(0, 0.12)),
			Material = M.LeafyGrass,
			Parent = parent,
		})
	end
	return blobs
end

local function rock(rng: Random, pos: Vector3, parent: Instance): number
	local s = rng:NextNumber(0.6, 2.2)
	local color = pick(rng, ROCK_COLORS)
	local count = rng:NextInteger(1, 2)
	for i = 1, count do
		local k = if i == 1 then s else s * rng:NextNumber(0.35, 0.6)
		local size = Vector3.new(
			rng:NextNumber(2, 3.4),
			rng:NextNumber(1.6, 2.6),
			rng:NextNumber(2, 3.4)
		) * k
		local off = if i == 1
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-2.4, 2.4)) * s
		-- balok miring yang separuh terbenam terlihat seperti batu low-poly
		Kit.deco({
			Name = "Batu",
			Size = size,
			CFrame = CFrame.new(pos + off + Vector3.new(0, size.Y * 0.18, 0)) * CFrame.Angles(
				rng:NextNumber(-0.45, 0.45),
				rng:NextNumber(0, math.pi * 2),
				rng:NextNumber(-0.45, 0.45)
			),
			Color = color,
			Material = M.Slate,
			Parent = parent,
		})
	end
	return count
end

local function flowers(rng: Random, pos: Vector3, parent: Instance): number
	local color = pick(rng, FLOWER_COLORS)
	local s = rng:NextNumber(0.8, 1.3)
	Kit.deco({
		Name = "Rumpun",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 1.3, 2.6) * s,
		Position = pos + Vector3.new(0, 0.2 * s, 0),
		Color = pick(rng, BUSH_COLORS),
		Material = M.LeafyGrass,
		Parent = parent,
	})
	local blooms = rng:NextInteger(2, 3)
	for _ = 1, blooms do
		local d = rng:NextNumber(0.55, 0.85) * s
		local off = Vector3.new(
			rng:NextNumber(-0.8, 0.8),
			rng:NextNumber(0.7, 0.95),
			rng:NextNumber(-0.8, 0.8)
		)
		Kit.deco({
			Name = "Bunga",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d,
			Position = pos + off * s,
			Color = color,
			Parent = parent,
		})
	end
	return blooms + 1
end

local YARD_PATTERNS = { "^Halaman%d+$", "^Lawn$" }

local function scenery(): number
	local zone = Kit.zone("Scenery")
	local rng = Random.new(SEED)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { zone }
	rayParams.IgnoreWater = false

	local function overlapParams(ignore: { Instance }): OverlapParams
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.MaxParts = 1
		return params
	end

	-- Cari tempat kosong: harus rumput (atau pasir untuk batu), datar, dan jauh dari part lain.
	local function spot(x: number, z: number, kind: number, clearance: number): Vector3?
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), rayParams)
		if not hit or hit.Normal.Y < 0.9 or hit.Position.Y > 70 then
			return nil
		end
		local inst = hit.Instance
		if inst:IsA("Terrain") then
			local okSand = kind == 2 and hit.Material == M.Sand
			if hit.Material ~= M.Grass and not okSand then
				return nil
			end
		else
			-- halaman (part rumput): hanya semak dan bunga
			if kind == 2 or inst.Material ~= M.Grass then
				return nil
			end
			local yard = false
			for _, pattern in YARD_PATTERNS do
				if string.find(inst.Name, pattern) then
					yard = true
				end
			end
			if not yard then
				return nil
			end
		end
		-- kotak mulai sedikit di atas permukaan, supaya alas di bawah rumput tidak ikut terhitung
		local box = Vector3.new(clearance * 2, 10, clearance * 2)
		local center = CFrame.new(hit.Position + Vector3.new(0, 5.3, 0))
		local ignore = overlapParams({ zone, workspace.Terrain, inst })
		if #workspace:GetPartBoundsInBox(center, box, ignore) > 0 then
			return nil
		end
		return hit.Position
	end

	-- Hiasan lebih banyak di dekat jalan dan bangunan (tempat pemain lewat) daripada di padang kosong.
	local function nearSomething(x: number, z: number): boolean
		local ignore = overlapParams({ zone, workspace.Terrain })
		return #workspace:GetPartBoundsInBox(
				CFrame.new(x, 10, z),
				Vector3.new(90, 60, 90),
				ignore
			) > 0
	end

	local total = 0
	for _, region in REGIONS do
		local folder = Kit.folder(region.name)
		local b = region.box
		local w = region.weights
		local sum = w[1] + w[2] + w[3]
		local placed = 0
		for c = 1, MAX_TRIES do
			if placed >= region.parts then
				break
			end
			if c % 25 == 0 then
				task.wait()
			end
			local cx, cz = rng:NextNumber(b[1], b[3]), rng:NextNumber(b[2], b[4])
			if not nearSomething(cx, cz) and rng:NextNumber() > 0.15 then
				continue
			end
			-- satu gerombol = 2 sampai 5 hiasan berdekatan, jenis utamanya sama
			local roll = rng:NextNumber(0, sum)
			local main = if roll < w[1] then 1 elseif roll < w[1] + w[2] then 2 else 3
			local items = rng:NextInteger(2, 5)
			local spread = rng:NextNumber(5, 12)
			for _ = 1, items do
				local kind = if rng:NextNumber() < 0.75 then main else rng:NextInteger(1, 3)
				local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
				local pos = spot(cx + math.cos(a) * r, cz + math.sin(a) * r, kind, 6)
				if pos then
					if kind == 1 then
						placed += bush(rng, pos, folder)
					elseif kind == 2 then
						placed += rock(rng, pos, folder)
					else
						placed += flowers(rng, pos, folder)
					end
				end
			end
		end
		total += placed
		Kit.flush(folder, zone)
	end
	return total
end

--------------------------------------------------------------------------

local STEPS: { [string]: () -> any } = {
	lighting = lighting,
	materials = materials,
	lights = lights,
	scenery = scenery,
}

return function(only: string?)
	if only then
		local step = STEPS[only]
		assert(step, "Bagian tidak dikenal: " .. only)
		return step()
	end
	lighting()
	local m = materials()
	local l = lights()
	local s = scenery()
	print(("[StyleWorld] material %d part, lampu %d, hiasan alam %d part"):format(m, l, s))
	return s
end
