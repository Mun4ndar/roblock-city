--[[
	ROBLOCK CITY: tampilan alam bergaya templat desa resmi Roblox Studio (rumput, pohon, kayu).
	Jalankan PALING AKHIR (setelah StyleWorld, StyleTrees, dan lainnya); aman diulang.

	"materials" : MaterialVariant bertekstur dari templat resmi Roblox (rumput lumut, papan kayu) dijadikan
	              tampilan bawaan Grass dan WoodPlanks (rumput 3D di terrain tersedia tapi dimatikan, lihat DECORATION).
	"bushes"    : semak bola di Map.Scenery diganti semak berdaun (jalankan setelah StyleWorld "scenery").
	"trees"     : pohon bola dan pohon mesh lama di kota/taman/perumahan diganti pohon rindang bertekstur.
	              Templat pohon ada di ServerStorage.AsetAlam (Pohon1, Pohon2), dirakit dari mesh dan
	              tekstur templat resmi Roblox itu. Pohon kelapa pantai dan cemara hutan tidak diganti.

	Pakai: require(game.ServerStorage.MapBuilders.StyleNature)()  atau ("materials") / ("trees")
]]

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local TAG = "RoblockStyle"
local SEED = 2211
local DECORATION = false
local GRASS_LENGTH = 0.12 -- pendek, supaya helai rumput tidak menembus jalan (tebal jalan 0,4)

local CLIFF_NORMAL = "rbxassetid://15634141840"
local CLIFF_ROUGHNESS = "rbxassetid://14899560341"

local VARIANTS = {
	{
		name = "RumputLumut",
		base = Enum.Material.Grass,
		color = "rbxassetid://16102976891",
		normal = "rbxassetid://16102976952",
		roughness = "rbxassetid://16102977058",
		metalness = "rbxassetid://13280829022",
		studs = 10,
	},
	{
		name = "PapanKayu",
		base = Enum.Material.WoodPlanks,
		color = "rbxassetid://15238305245",
		normal = "rbxassetid://15238305551",
		roughness = "rbxassetid://15238279404",
		metalness = "",
		studs = 10,
	},
	{ -- tebing batu: dipakai gunung dan batu terrain
		name = "TebingBatu",
		base = Enum.Material.Rock,
		color = "rbxassetid://14900084267",
		normal = CLIFF_NORMAL,
		roughness = CLIFF_ROUGHNESS,
		metalness = "",
		studs = 15,
	},
	{ -- jalan batu bulat: lantai Pasar Tani dan semua part Cobblestone
		name = "JalanBatu",
		base = Enum.Material.Cobblestone,
		color = "rbxassetid://15940445564",
		normal = "rbxassetid://15940436103",
		roughness = "rbxassetid://15633798696",
		metalness = "",
		studs = 15,
	},
}

-- Folder pohon yang diganti (relatif ke Workspace.Map). every = 1 semua, 2 selang-seling.
local TARGETS = {
	{ path = { "Downtown", "Props", "TamanKota" }, every = 1 },
	{ path = { "Downtown", "Props", "Trees" }, every = 1 },
	{ path = { "Downtown", "Sidewalks" }, every = 1 },
	{ path = { "Residential", "Props", "Trees" }, every = 1 },
	{ path = { "Neighborhoods", "Taman" }, every = 1 },
	{ path = { "Neighborhoods", "Houses" }, every = 1 },
	{ path = { "Airport", "Landside" }, every = 1 },
	{ path = { "Countryside", "Pertanian" }, every = 1 },
}
local HEIGHT_FACTOR = 1.45 -- pohon baru lebih tinggi daripada yang digantikan
local MIN_HEIGHT, MAX_HEIGHT = 20, 34

local function materials(): number
	local n = 0
	for _, v in VARIANTS do
		local variant = MaterialService:FindFirstChild(v.name)
		if not (variant and variant:IsA("MaterialVariant")) then
			local created = Instance.new("MaterialVariant")
			created.Name = v.name
			created.Parent = MaterialService
			variant = created
		end
		local mv = variant :: MaterialVariant
		mv.BaseMaterial = v.base
		mv.ColorMap = v.color
		mv.NormalMap = v.normal
		mv.RoughnessMap = v.roughness
		mv.MetalnessMap = v.metalness
		mv.StudsPerTile = v.studs
		mv:SetAttribute(TAG, true)
		MaterialService:SetBaseMaterialOverride(v.base, v.name)
		n += 1
	end
	local terrain = workspace.Terrain
	-- Rumput 3D (Decoration) SENGAJA mati: diukur di playtest, menyalakannya menjatuhkan kelancaran dari
	-- sekitar 45-55 fps menjadi 7-14 fps. Ubah DECORATION ke true hanya untuk PC kencang.
	terrain.Decoration = DECORATION
	terrain.GrassLength = GRASS_LENGTH
	-- warna rumput terrain putih: warnanya datang dari tekstur RumputLumut (seperti di templat resmi)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(255, 255, 255))
	return n
end

-- Titik pangkal (di tanah) dan tinggi sebuah pohon, dari kotak pembatas dunia.
local function footprint(model: Model): (Vector3, number)
	local minY, maxY = math.huge, -math.huge
	local trunk: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local half, cf = d.Size / 2, d.CFrame
			local reach = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			minY = math.min(minY, d.Position.Y - reach)
			maxY = math.max(maxY, d.Position.Y + reach)
			if d.Name:lower():match("^trunk") then
				trunk = d
			end
		end
	end
	local at = if trunk then trunk.Position else model:GetPivot().Position
	return Vector3.new(at.X, minY, at.Z), maxY - minY
end

local function trees(): number
	local folder = ServerStorage:FindFirstChild("AsetAlam")
	local sources: { Model } = {}
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.Name:match("^Pohon%d+$") then
				table.insert(sources, m)
			end
		end
	end
	local map = workspace:FindFirstChild("Map")
	if #sources == 0 or not map then
		warn(
			"[StyleNature] ServerStorage.AsetAlam atau Workspace.Map tidak ditemukan; pohon dilewati"
		)
		return 0
	end
	table.sort(sources, function(a, b)
		return a.Name < b.Name
	end)
	local rng = Random.new(SEED)
	local count = 0
	for _, target in TARGETS do
		local parent: Instance? = map
		for _, name in target.path do
			parent = parent and parent:FindFirstChild(name)
		end
		if not parent then
			continue
		end
		local old: { Model } = {}
		for _, child in parent:GetChildren() do
			if
				child:IsA("Model") and (child.Name:match("^Pohon%d*$") or child.Name == "PohonMesh")
			then
				table.insert(old, child)
			end
		end
		table.sort(old, function(a, b)
			local pa, pb = a:GetPivot().Position, b:GetPivot().Position
			if pa.X ~= pb.X then
				return pa.X < pb.X
			end
			return pa.Z < pb.Z
		end)
		for index, tree in old do
			if index % target.every ~= 0 then
				continue
			end
			local base, height = footprint(tree)
			local clone = sources[rng:NextInteger(1, #sources)]:Clone()
			clone.Name = "PohonRindang"
			clone:SetAttribute(TAG, true)
			local _, sourceHeight = footprint(clone)
			local wanted = math.clamp(height * HEIGHT_FACTOR, MIN_HEIGHT, MAX_HEIGHT)
				* rng:NextNumber(0.9, 1.1)
			clone:ScaleTo(wanted / sourceHeight)
			local pivot = clone:GetPivot()
			clone:PivotTo(
				CFrame.new(pivot.Position)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					* pivot.Rotation
			)
			local at, _ = footprint(clone)
			clone:PivotTo(clone:GetPivot() + (base - at))
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanTouch = false
					if d.Name == "leaves" then
						d.CanCollide = false
						d.CanQuery = false
					end
				end
			end
			clone.Parent = parent
			tree:Destroy()
			count += 1
		end
		task.wait()
	end
	return count
end

-- Semak bola di Map.Scenery diganti semak berdaun (mesh + tekstur daun templat resmi Roblox).
local function bushes(): number
	local folder = ServerStorage:FindFirstChild("AsetAlam")
	local source = folder and folder:FindFirstChild("Semak")
	local leaf = source and source:FindFirstChild("leaves")
	local map = workspace:FindFirstChild("Map")
	local scenery = map and map:FindFirstChild("Scenery")
	if not (leaf and leaf:IsA("MeshPart") and scenery) then
		return 0
	end
	local rng = Random.new(SEED)
	local count = 0
	for _, old in scenery:GetDescendants() do
		if old:IsA("Part") and old.Name == "Semak" then
			local bush = leaf:Clone()
			bush.Name = "Semak"
			local s = old.Size.Y * 1.5
			bush.Size = Vector3.new(s * 0.95, s, s)
			bush.CFrame = CFrame.new(old.Position + Vector3.new(0, s * 0.12, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			bush.Anchored = true
			bush.CanCollide = false
			bush.CanTouch = false
			bush.CanQuery = false
			bush.CastShadow = false
			bush.Parent = old.Parent
			old:Destroy()
			count += 1
			if count % 150 == 0 then
				task.wait()
			end
		end
	end
	return count
end

return function(section: string?): number
	local n = 0
	if section == nil or section == "bushes" then
		n += bushes()
	end
	if section == nil or section == "materials" then
		n += materials()
	end
	if section == nil or section == "trees" then
		n += trees()
	end
	return n
end
