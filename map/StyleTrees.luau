--[[
	ROBLOCK CITY: pohon mesh untuk taman (pelengkap StyleWorld; jalankan setelah StyleWorld).

	Mengganti sebagian pohon bola di taman dengan pohon mesh bercabang supaya taman
	terlihat lebih hidup. Sumber mesh: "Low-Poly Oak Trees Asset Pack" karya Cliosow
	(Creator Store, gratis, aset 8556375773), disimpan di
	ServerStorage.AsetPihakKetiga.CliosowOakTrees. Paket itu hanya berisi MeshPart
	(sudah diperiksa: tanpa skrip). Kalau paketnya tidak ada, modul ini tidak berbuat apa-apa.

	Pakai (Studio, mode Edit):
	  require(game.ServerStorage.MapBuilders.StyleTrees)()

	Aman diulang: pohon bola yang dipertahankan diberi atribut StyleTreesKept dan dilewati.
	Kalau kawasan dibangun ulang (pohon bola kembali), jalankan lagi.
]]

local ServerStorage = game:GetService("ServerStorage")

local TAG = "RoblockStyle"
local KEPT = "StyleTreesKept"
local SEED = 20261122

-- Folder pohon yang diganti (relatif ke Workspace.Map) dan seberapa banyak (1 = semua, 2 = selang-seling).
local TARGETS = {
	{ path = { "Downtown", "Props", "TamanKota" }, every = 2 },
	{ path = { "Neighborhoods", "Taman" }, every = 2 },
	{ path = { "Residential", "Props", "Trees" }, every = 3 },
}

local HEIGHT_FACTOR = 1.25 -- pohon mesh sedikit lebih tinggi daripada pohon bola yang digantikan
local LEAF_TINTS = {
	Color3.fromRGB(104, 176, 78),
	Color3.fromRGB(126, 190, 84),
	Color3.fromRGB(88, 160, 82),
	Color3.fromRGB(150, 200, 90),
}
local TRUNK_COLOR = Color3.fromRGB(122, 88, 62)
local SHADOW_LEAF_SIZE = 8 -- hanya gumpalan daun besar yang berbayang (lebih ringan di HP)

local function sourceTrees(): { Model }
	local folder = ServerStorage:FindFirstChild("AsetPihakKetiga")
	local pack = folder and folder:FindFirstChild("CliosowOakTrees")
	local list: { Model } = {}
	if pack then
		for _, d in pack:GetDescendants() do
			if d:IsA("Model") and d.Name:match("^Tree%d+$") then
				table.insert(list, d)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- Titik pangkal (di tanah) dan tinggi sebuah model, dari kotak pembatas dunia.
local function footprint(model: Model): (Vector3, number)
	local minY, maxY = math.huge, -math.huge
	local sum, count = Vector3.zero, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			local cf = d.CFrame
			local reach = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			minY = math.min(minY, d.Position.Y - reach)
			maxY = math.max(maxY, d.Position.Y + reach)
		end
	end
	local trunk = model:FindFirstChild("Trunk") or model.PrimaryPart
	if trunk and trunk:IsA("BasePart") then
		return Vector3.new(trunk.Position.X, minY, trunk.Position.Z), maxY - minY
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			sum += d.Position
			count += 1
		end
	end
	local center = if count > 0 then sum / count else Vector3.zero
	return Vector3.new(center.X, minY, center.Z), maxY - minY
end

local function plant(source: Model, base: Vector3, height: number, rng: Random, parent: Instance)
	local tree = source:Clone()
	tree.Name = "PohonMesh"
	tree:SetAttribute(TAG, true)
	local _, sourceHeight = footprint(tree)
	tree:ScaleTo(math.clamp(height * HEIGHT_FACTOR / sourceHeight, 0.3, 1.5))
	-- Putar mengelilingi sumbu tegak DUNIA (pivot paket ini tidak tegak, jadi jangan putar di ruang pivot).
	local pivot = tree:GetPivot()
	tree:PivotTo(
		CFrame.new(pivot.Position)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			* pivot.Rotation
	)
	local tint = LEAF_TINTS[rng:NextInteger(1, #LEAF_TINTS)]
	local trunkPosition: Vector3? = nil
	for _, d in tree:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			d.Material = Enum.Material.SmoothPlastic
			if d.Name:match("^Trunk") then
				d.Color = TRUNK_COLOR
				trunkPosition = d.Position
			else
				d.Color = tint
				d.CanCollide = false
				d.CanQuery = false
				d.CastShadow = d.Size.X >= SHADOW_LEAF_SIZE * tree:GetScale()
			end
		end
	end
	-- Geser supaya pangkal batang tepat di titik pohon lama.
	local current, _ = footprint(tree)
	local anchor = if trunkPosition
		then Vector3.new(trunkPosition.X, current.Y, trunkPosition.Z)
		else current
	tree:PivotTo(tree:GetPivot() + (base - anchor))
	tree.Parent = parent
end

-- redo = true: pohon mesh yang sudah ada ikut ditanam ulang (mis. setelah mengubah setelan di atas).
return function(redo: boolean?): number
	local sources = sourceTrees()
	local map = workspace:FindFirstChild("Map")
	if #sources == 0 or not map then
		warn("[StyleTrees] paket pohon atau Workspace.Map tidak ditemukan; dilewati")
		return 0
	end
	local rng = Random.new(SEED)
	local replaced = 0
	for _, target in TARGETS do
		local folder: Instance? = map
		for _, name in target.path do
			folder = folder and folder:FindFirstChild(name)
		end
		if folder then
			local old: { Model } = {}
			for _, child in folder:GetChildren() do
				if
					child:IsA("Model")
					and child.Name:match("^Pohon%d*$")
					and not child:GetAttribute(KEPT)
				then
					table.insert(old, child)
				elseif redo and child.Name == "PohonMesh" then
					local base, height = footprint(child)
					plant(
						sources[rng:NextInteger(1, #sources)],
						base,
						math.clamp(height / HEIGHT_FACTOR, 16, 24),
						rng,
						folder
					)
					child:Destroy()
					replaced += 1
				end
			end
			-- Urutkan menurut posisi supaya hasilnya selalu sama.
			table.sort(old, function(a, b)
				local pa, pb = a:GetPivot().Position, b:GetPivot().Position
				if pa.X ~= pb.X then
					return pa.X < pb.X
				end
				return pa.Z < pb.Z
			end)
			for index, tree in old do
				if index % target.every == 0 then
					local base, height = footprint(tree)
					plant(sources[rng:NextInteger(1, #sources)], base, height, rng, folder)
					tree:Destroy()
					replaced += 1
				else
					tree:SetAttribute(KEPT, true) -- pohon bola yang sengaja dipertahankan
				end
			end
			task.wait()
		end
	end
	return replaced
end
