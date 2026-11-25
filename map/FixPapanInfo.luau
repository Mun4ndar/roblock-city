--!strict
-- FixPapanInfo: bersihkan pandangan ke Papan Info di taman spawn. Pohon dalam RADIUS dari papan (di sisi jalannya)
-- dan petak bunga kosong berwarna zaitun di dekatnya dipindah ke ServerStorage.CadanganPeta.PapanInfoDibuang
-- (bukan dihapus). Jalankan SETELAH StyleTrees/StyleNature jika peta pernah dibangun ulang.
-- Pakai: require(ServerStorage.MapBuilders.FixPapanInfo)()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TREE_RADIUS = 22 -- pohon dengan batang sedekat ini dari tengah papan dibuang
local BED_NAMES = { FlowerBed3 = true, FlowerBed4 = true } -- petak zaitun polos di baris jalan

local function build()
	local Config = require(ReplicatedStorage.Shared:WaitForChild("InfoBoardConfig"))
	local center = Config.POSITION
	local map = Workspace:WaitForChild("Map")

	local backup = ServerStorage:FindFirstChild("CadanganPeta")
	if backup == nil then
		backup = Instance.new("Folder")
		backup.Name = "CadanganPeta"
		backup.Parent = ServerStorage
	end
	local bin = backup:FindFirstChild("PapanInfoDibuang") or Instance.new("Folder")
	bin.Name = "PapanInfoDibuang"
	bin.Parent = backup

	local moved = 0
	for _, d in map:GetDescendants() do
		if d:IsA("Model") and d.Name == "PohonRindang" then
			local pivot = d:GetPivot().Position
			if Vector3.new(pivot.X - center.X, 0, pivot.Z - center.Z).Magnitude < TREE_RADIUS then
				d.Parent = bin
				moved += 1
			end
		elseif d:IsA("BasePart") and BED_NAMES[d.Name] and d.Parent and d.Parent.Name == "Park" then
			d.Parent = bin
			moved += 1
		end
	end
	return moved
end

return build
