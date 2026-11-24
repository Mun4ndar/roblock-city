--!strict
--[[
	ROBLOCK CITY: 10 apartemen berbalkon dari Blender (tools/blender/apartemen.py, satu FBX per gedung).

	Mesh diunggah sebagai asset Model (lihat tabel APT) dan dipasang di ServerStorage.Apt<Nama>Mentah.
	Pemasangan sama dengan BuildBangunanModern: model lama dicadangkan ke ServerStorage.CadanganPeta.<Nama>Lama,
	part tabrakan (Body1, Lobby, Cap1) dibiarkan tak terlihat, visual lama dihapus, mesh baru ditaruh di
	Model "Visual" lalu model dipindah ke Workspace.Map.BangunanBlender. Warna dinding = warna gedung lama.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

type Apt = { name: string, asset: number, x: number, z: number, yaw: number, cz: number, color: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- yaw pi = depan menghadap +Z, 0 = depan menghadap -Z; cz = pusat bbox mesh (Blender z)
local APT: { Apt } = {
	{ name = "ApartemenMint", asset = 100881298602925, x = -275, z = -800, yaw = math.pi, cz = 50.85, color = rgb(170, 230, 210) },
	{ name = "ApartemenSelatan", asset = 97943613863985, x = -262, z = -380, yaw = 0, cz = 43.35, color = rgb(240, 190, 150) },
	{ name = "ApartemenKrem", asset = 92556653058843, x = 580, z = -366, yaw = 0, cz = 35.85, color = rgb(240, 230, 200) },
	{ name = "ApartemenKuning", asset = 126414501398724, x = 720, z = -800, yaw = math.pi, cz = 45.85, color = rgb(250, 220, 110) },
	{ name = "ApartemenPink", asset = 91600610892759, x = 820, z = -800, yaw = math.pi, cz = 35.85, color = rgb(245, 175, 200) },
	{ name = "ApartemenTaman", asset = 126193157784095, x = -262, z = -604, yaw = math.pi, cz = 40.85, color = rgb(200, 180, 240) },
	{ name = "ApartemenHijau", asset = 139309685351898, x = 470, z = -366, yaw = 0, cz = 48.35, color = rgb(160, 210, 120) },
	{ name = "ApartemenLaut", asset = 124803483096375, x = -268, z = -996, yaw = math.pi, cz = 56.35, color = rgb(245, 200, 170) },
	{ name = "ApartemenUjung", asset = 140179409375169, x = 703, z = -996, yaw = math.pi, cz = 43.35, color = rgb(190, 225, 200) },
	{ name = "ApartemenBata", asset = 83263598534439, x = -390, z = -800, yaw = math.pi, cz = 38.35, color = rgb(190, 95, 80) },
}
local BBOX_Y = 1.825 -- pusat bbox mesh dalam Blender (y)

local function look(color: Color3): { [string]: { any } }
	local SP = Enum.Material.SmoothPlastic
	return {
		AtWall = { color, SP, 0 },
		AtAccent = { color:Lerp(Color3.new(0, 0, 0), 0.38), SP, 0 },
		AtSlab = { rgb(245, 243, 238), SP, 0 },
		AtWhite = { rgb(250, 249, 245), SP, 0 },
		AtTrim = { rgb(235, 235, 235), SP, 0 },
		AtGlass = { rgb(130, 190, 215), Enum.Material.Glass, 0.3 },
		AtDark = { rgb(40, 46, 58), SP, 0 },
		AtStone = { rgb(190, 184, 172), Enum.Material.Concrete, 0 },
		AtRoof = { rgb(84, 90, 100), SP, 0 },
	}
end

local KEEP = { "Body1", "Lobby", "Cap1" }

local function build(apt: Apt): string
	local raw = ServerStorage:FindFirstChild("Apt" .. string.sub(apt.name, 10) .. "Mentah")
	local map = Workspace.Map
	local blender = map:FindFirstChild("BangunanBlender")
	local old = (blender and blender:FindFirstChild(apt.name)) or map.Downtown.Buildings:FindFirstChild(apt.name)
	if raw == nil or old == nil then
		return apt.name .. ": template atau model lama tidak ada"
	end
	for _, d in raw:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	if backup:FindFirstChild(apt.name .. "Lama") == nil then
		local copy = old:Clone()
		copy.Name = apt.name .. "Lama"
		copy.Parent = backup
	end
	for _, c in old:GetChildren() do
		if table.find(KEEP, c.Name) and c:IsA("BasePart") then
			c.Transparency = 1
			for _, tag in CollectionService:GetTags(c) do
				CollectionService:RemoveTag(c, tag)
			end
		else
			c:Destroy()
		end
	end

	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local half = part.Size / 2
			mn = mn:Min(part.Position - half)
			mx = mx:Max(part.Position + half)
		end
	end
	local rawCenter = (mn + mx) / 2
	local base = CFrame.new(apt.x, 1, apt.z) * CFrame.Angles(0, apt.yaw, 0)
	local center = base * CFrame.new(0, apt.cz, -BBOX_Y)
	local looks = look(apt.color)
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local l = key and looks[key]
			if l then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Name = key :: string
				local r0 = select(2, part.CFrame:ToOrientation())
				local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)
				clone.CFrame = center * CFrame.Angles(0, undo, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
				clone.Color, clone.Material, clone.Transparency = l[1] :: Color3, l[2] :: Enum.Material, l[3] :: number
				clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
				if key == "AtGlass" then
					CollectionService:AddTag(clone, "NightWindow")
				end
				clone.Parent = visual
			end
		end
	end
	visual.Parent = old
	if blender then
		old.Parent = blender
	end
	return apt.name .. " " .. #visual:GetChildren()
end

return function(only: string?): number
	local n = 0
	for _, apt in APT do
		if only == nil or only == apt.name then
			print(build(apt))
			n += 1
		end
	end
	return n
end
