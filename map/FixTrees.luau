--!strict
--[[
	ROBLOCK CITY: menyingkirkan pohon yang berdiri di atas jalan atau di pembatas tengah jalan raya.

	Beberapa pembangun dan perias peta menaruh pohon tanpa tahu letak jalan, jadi ada pohon yang jatuh
	di aspal. Skrip ini memeriksa tiap pohon (model bernama Pohon, PohonRindang, PohonMesh) dengan
	sinar ke bawah di pangkalnya dan di sekelilingnya; kalau mengenai aspal, pohon itu dipindah ke
	ServerStorage.CadanganPeta.PohonDiJalan (tidak dihapus). Jalankan setelah semua perias peta.
	Aman dijalankan ulang. Mengembalikan jumlah pohon yang dipindah.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TREE_NAMES = { Pohon = true, PohonRindang = true, PohonMesh = true }
local RING = 3.5 -- stud; jarak titik periksa di sekeliling pangkal pohon

-- Aspal (jalan, tempat parkir) dan pembatas tengah jalan raya: pohon di sana menghalangi pengemudi.
local function isRoad(hit: RaycastResult): boolean
	return hit.Material == Enum.Material.Asphalt or hit.Instance.Name == "Median"
end

local function onRoad(tree: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { tree }
	local base = tree:GetPivot().Position
	local hits = 0
	local offsets = {
		Vector3.zero,
		Vector3.new(RING, 0, 0),
		Vector3.new(-RING, 0, 0),
		Vector3.new(0, 0, RING),
		Vector3.new(0, 0, -RING),
	}
	for index, offset in offsets do
		local hit =
			Workspace:Raycast(base + offset + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
		if hit and hit.Instance:IsA("BasePart") and isRoad(hit) then
			if index == 1 then
				return true -- pangkalnya sendiri di aspal
			end
			hits += 1
		end
	end
	return hits >= 2 -- menjorok ke jalan dari tepi
end

return function(): number
	local map = Workspace:FindFirstChild("Map")
	if map == nil then
		warn("[FixTrees] Workspace.Map tidak ditemukan")
		return 0
	end
	local backup = ServerStorage:FindFirstChild("CadanganPeta")
	if backup == nil then
		backup = Instance.new("Folder")
		backup.Name = "CadanganPeta"
		backup.Parent = ServerStorage
	end
	local bin = backup:FindFirstChild("PohonDiJalan")
	if bin == nil then
		bin = Instance.new("Folder")
		bin.Name = "PohonDiJalan"
		bin.Parent = backup
	end
	local trees: { Model } = {}
	for index, d in map:GetDescendants() do
		if index % 5000 == 0 then
			task.wait()
		end
		if d:IsA("Model") and TREE_NAMES[d.Name] then
			table.insert(trees, d)
		end
	end
	local moved = 0
	for index, tree in trees do
		if index % 100 == 0 then
			task.wait()
		end
		if onRoad(tree) then
			tree.Parent = bin
			moved += 1
		end
	end
	return moved
end
