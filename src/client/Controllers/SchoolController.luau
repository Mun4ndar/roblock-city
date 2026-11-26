--!strict
-- SchoolController: saat pemain berada di dalam GedungSekolah, cangkang luar (mesh Visual: dinding berpelangi, atap, kaca)
-- disembunyikan di sisi klien saja. Mesh itu menembus ruang interior (pita oranye setinggi kepala, "atap" rendah di lantai 2),
-- sedangkan dinding, plafon, dan jendela interior sudah dibuat sendiri di Interior.
-- Dari luar gedung tampilannya tidak berubah.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SchoolController = {}

-- kotak ruang dalam gedung (termasuk serambi pintu masuk)
local MIN = Vector3.new(-254, -5, -82.4)
local MAX = Vector3.new(-112, 26, -42)
local MARGIN_EXIT = 2

local hidden = false
local cached: { BasePart } = {}

local function inside(pos: Vector3, margin: number): boolean
	return pos.X > MIN.X - margin
		and pos.X < MAX.X + margin
		and pos.Y > MIN.Y - margin
		and pos.Y < MAX.Y + margin
		and pos.Z > MIN.Z - margin
		and pos.Z < MAX.Z + margin
end

local function findVisual(): Instance?
	local map = Workspace:FindFirstChild("Map")
	local blender = map and map:FindFirstChild("BangunanBlender")
	local school = blender and blender:FindFirstChild("GedungSekolah")
	return school and school:FindFirstChild("Visual")
end

local function collect(): { BasePart }
	local list: { BasePart } = {}
	local visual = findVisual()
	if visual then
		for _, d in visual:GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function apply(on: boolean)
	cached = collect()
	for _, part in cached do
		part.LocalTransparencyModifier = if on then 1 else 0
	end
end

function SchoolController.init() end

function SchoolController.start()
	local lastRefresh = 0
	while true do
		task.wait(0.2)
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local want = inside(root.Position, if hidden then MARGIN_EXIT else 0)
		if want ~= hidden then
			hidden = want
			apply(hidden)
			lastRefresh = os.clock()
		elseif hidden and os.clock() - lastRefresh > 3 then
			-- mesh yang baru ter-stream masuk ikut disembunyikan
			lastRefresh = os.clock()
			apply(true)
		end
	end
end

return SchoolController
