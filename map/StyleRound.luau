--[[
	ROBLOCK CITY: gedung bersudut bulat (mengurangi kesan kotak-kotak). Jalankan setelah BuildDowntown
	dan StyleWorld; aman diulang.

	Bagian bangunan di pusat kota, kota kecil, pantai, dan bandara (badan, pita lantai, topi, lobi) diberi kulit
	mesh bersudut bulat buatan sendiri (Blender, assets/blender/bentuk_bulat.fbx; templat
	ServerStorage.AsetRumah.bulat berisi MeshPart "Bulat" 1x1x1 dan "Sirip"). Part kotak aslinya tidak
	dihapus, hanya disembunyikan dan tetap menjadi tabrakan. Badan gedung dibuat seperti kaca yang
	memantulkan langit dan diberi sirip tegak.

	Pakai: require(game.ServerStorage.MapBuilders.StyleRound)()
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ATTR = "RoundShell"
local MIN_HEIGHT = 9 -- hanya bangunan yang punya badan setinggi ini
local MAX_ASPECT = 4 -- part yang terlalu pipih memanjang dibiarkan kotak (sudutnya jadi lonjong)
local FIN_HEIGHT = 40 -- sirip tegak hanya untuk gedung tinggi
-- Kawasan yang dirias. Rumah perumahan punya gayanya sendiri (StyleHouses), jadi tidak ikut.
local ZONES = { "Downtown", "Residential", "Beach", "Airport", "Countryside" }
-- Pelat blok kota (trotoar + halaman rumput di atasnya) diberi sudut bulat kecil; sudut yang terpotong
-- ditambal aspal supaya menyatu dengan persimpangan. Templat: ServerStorage.AsetRumah.bulatKecil.
local SLABS = { "^Blok%d+$", "Block$", "^Halaman%d+$" }
local SLAB_RADIUS = 0.06 -- bagian sisi yang membulat (sama dengan mesh BulatKecil)
local ASPHALT = Color3.fromRGB(86, 90, 100)
local NAMES = {
	"^Body%d*$",
	"^Band$",
	"^Cap%d*$",
	"^Lobby$",
	"^NeonCrown$",
	"^Roof$",
	"^Lumbung$",
	"^Rumah$",
}

local function matches(name: string): boolean
	for _, pattern in NAMES do
		if name:match(pattern) then
			return true
		end
	end
	return false
end

return function(): number
	local folder = ServerStorage:FindFirstChild("AsetRumah")
	local template = folder and folder:FindFirstChild("bulat")
	local round = template and template:FindFirstChild("Bulat")
	local fins = template and template:FindFirstChild("Sirip")
	local map = workspace:FindFirstChild("Map")
	if not (round and round:IsA("MeshPart") and map) then
		warn(
			"[StyleRound] templat ServerStorage.AsetRumah.bulat atau Workspace.Map tidak ditemukan; dilewati"
		)
		return 0
	end
	local models: { Instance } = {}
	for _, zoneName in ZONES do
		local zone = map:FindFirstChild(zoneName)
		if zone then
			for _, d in zone:GetDescendants() do
				if d:IsA("Model") then
					table.insert(models, d)
				end
			end
		end
	end
	local count = 0
	for _, model in models do
		local tall = false
		for _, child in model:GetChildren() do
			if child:GetAttribute(ATTR) then
				child:Destroy()
			elseif
				child:IsA("Part")
				and child.Shape == Enum.PartType.Block
				and child.Size.Y >= MIN_HEIGHT
			then
				tall = true
			end
		end
		if not tall then
			continue
		end
		for _, part in model:GetChildren() do
			if
				not (part:IsA("Part") and part.Shape == Enum.PartType.Block and matches(part.Name))
			then
				continue
			end
			local size = part.Size
			if math.max(size.X, size.Z) / math.min(size.X, size.Z) > MAX_ASPECT then
				continue
			end
			local isBody = part.Name:match("^Body") ~= nil
			local shell = round:Clone()
			shell.Name = part.Name .. "Bulat"
			shell.Size = size
			shell.CFrame = part.CFrame
			shell.Color = part.Color
			shell.Material = if part.Material == Enum.Material.Neon
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
			shell.Reflectance = if isBody then 0.32 else 0.05
			shell.Anchored = true
			shell.CanCollide = false
			shell.CanTouch = false
			shell.CanQuery = false
			shell.CastShadow = isBody
			shell:SetAttribute(ATTR, true)
			shell.Parent = model
			if isBody and size.Y >= FIN_HEIGHT and fins and fins:IsA("MeshPart") then
				local f = fins:Clone()
				f.Name = "Sirip"
				f.Size = Vector3.new(size.X * fins.Size.X, size.Y, size.Z * fins.Size.Z)
				f.CFrame = part.CFrame
				f.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.7)
				f.Material = Enum.Material.SmoothPlastic
				f.Anchored = true
				f.CanCollide = false
				f.CanTouch = false
				f.CanQuery = false
				f.CastShadow = false
				f:SetAttribute(ATTR, true)
				f.Parent = model
			end
			shell.Reflectance = if isBody and size.Y >= FIN_HEIGHT then 0.32 else 0.05
			part.Transparency = 1
			part.CastShadow = false
			CollectionService:RemoveTag(part, "NightWindow")
			count += 1
		end
	end

	-- pelat blok kota
	local small = template and template.Parent:FindFirstChild("bulatKecil")
	local slabMesh = small and small:FindFirstChild("BulatKecil")
	if slabMesh and slabMesh:IsA("MeshPart") then
		local sample = map:FindFirstChild("Simpang", true)
		local roadColor = if sample and sample:IsA("BasePart") then sample.Color else ASPHALT
		local roadTop = if sample and sample:IsA("BasePart")
			then sample.Position.Y + sample.Size.Y / 2
			else 0.4
		for _, zoneName in { "Downtown", "Residential" } do
			local zone = map:FindFirstChild(zoneName)
			local walks = zone and zone:FindFirstChild("Sidewalks")
			if not walks then
				continue
			end
			for _, part in walks:GetChildren() do
				if part:GetAttribute(ATTR) then
					part:Destroy()
				end
			end
			for _, part in walks:GetChildren() do
				local isSlab = false
				for _, pattern in SLABS do
					if part.Name:match(pattern) then
						isSlab = true
					end
				end
				if not (isSlab and part:IsA("Part") and part.Shape == Enum.PartType.Block) then
					continue
				end
				local shell = slabMesh:Clone()
				shell.Name = part.Name .. "Bulat"
				shell.Size = part.Size
				shell.CFrame = part.CFrame
				shell.Color = part.Color
				shell.Material = part.Material
				shell.MaterialVariant = part.MaterialVariant
				shell.Anchored = true
				shell.CanCollide = false
				shell.CanTouch = false
				shell.CanQuery = false
				shell.CastShadow = false
				shell:SetAttribute(ATTR, true)
				shell.Parent = walks
				part.Transparency = 1
				part.CastShadow = false
				count += 1
				-- tambal aspal di keempat sudut trotoar (bukan halaman rumput di atasnya)
				if not part.Name:match("^Halaman") then
					local rx, rz = part.Size.X * SLAB_RADIUS, part.Size.Z * SLAB_RADIUS
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local patch = Instance.new("Part")
							patch.Name = "TambalSudut"
							patch.Anchored = true
							patch.Size = Vector3.new(rx, 0.4, rz)
							patch.CFrame = CFrame.new(
								part.Position.X + sx * (part.Size.X / 2 - rx / 2),
								roadTop - 0.2,
								part.Position.Z + sz * (part.Size.Z / 2 - rz / 2)
							)
							patch.Color = roadColor
							patch.Material = Enum.Material.Asphalt
							patch.TopSurface = Enum.SurfaceType.Smooth
							patch.CastShadow = false
							patch:SetAttribute(ATTR, true)
							patch.Parent = walks
						end
					end
				end
			end
		end
	end
	return count
end
