--!strict
--[[
	ROBLOCK CITY: jembatan sungai dari Blender (tools/blender/jembatan.py).

	Mesh: JembatanRaya (asset 115321613615053, jalan raya 48 lebar, panjang 60) dan JembatanDesa
	(asset 122815195636025, jalan desa 28 lebar, panjang 58), dipasang di ServerStorage.JembatanRayaMentah /
	JembatanDesaMentah. Skrip ini menaruh mesh di atas dek lama tanpa mengubah jalan: dek lama dan pagar tipis
	lama disembunyikan (dek tetap jadi lantai tabrakan), lalu ditambah tabrakan trotoar + pagar baru, dan lampu
	jembatan bertag NightLight. Hasil di Workspace.Map.Jembatan.
	Koordinat mesh: X sepanjang jalan, Z atas = permukaan jalan (y=0.4 dunia), pusat bbox Blender z=4.74.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LOOK = {
	BjStone = { Color3.fromRGB(198, 190, 174), Enum.Material.Concrete, 0 },
	BjConcrete = { Color3.fromRGB(140, 142, 146), Enum.Material.Concrete, 0 },
	BjWalk = { Color3.fromRGB(178, 178, 186), Enum.Material.Concrete, 0 },
	BjWhite = { Color3.fromRGB(244, 242, 235), Enum.Material.SmoothPlastic, 0 },
	BjGold = { Color3.fromRGB(226, 172, 52), Enum.Material.Metal, 0 },
	BjDark = { Color3.fromRGB(45, 52, 64), Enum.Material.Metal, 0 },
	BjLamp = { Color3.fromRGB(255, 236, 176), Enum.Material.Glass, 0.15 },
}

local ROAD_TOP = 0.4
local CENTER_Z = 4.74 -- pusat bbox mesh (Blender z)
local EXTRA = 3 -- trotoar tiap sisi (sama dengan E di jembatan.py)

type Spec = { name: string, template: string, length: number, roadWidth: number, base: CFrame, hide: { Instance } }

local function colliderPart(parent: Instance, name: string, size: Vector3, cf: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Transparency = 1
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
end

local function build(spec: Spec, folder: Folder): number
	local raw = ServerStorage:FindFirstChild(spec.template)
	if raw == nil then
		warn("[BuildJembatan] " .. spec.template .. " tidak ada")
		return 0
	end
	for _, d in raw:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
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
	local origin = spec.base * CFrame.new(0, CENTER_Z, 0)

	local model = Instance.new("Model")
	model.Name = spec.name
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local look = key and LOOK[key]
			if look then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Name = key
				clone.CFrame = origin * CFrame.new(part.Position - rawCenter)
				clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
				clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
				clone.Parent = model
			end
		end
	end

	-- tabrakan: trotoar dan pagar (sisi jalan tetap memakai jalan/dek lama)
	local half = spec.roadWidth / 2 + EXTRA
	local colliders = Instance.new("Folder")
	colliders.Name = "Tabrakan"
	colliders.Parent = model
	for _, s in { -1, 1 } do
		colliderPart(
			colliders,
			"Trotoar",
			Vector3.new(spec.length, 2.2, EXTRA),
			spec.base * CFrame.new(0, -1.1, s * (spec.roadWidth / 2 + EXTRA / 2))
		)
		colliderPart(
			colliders,
			"Pagar",
			Vector3.new(spec.length, 2.4, 0.9),
			spec.base * CFrame.new(0, 1.2, s * (half - 0.5))
		)
		-- lampu: part kecil tak terlihat berisi PointLight, menyala malam (tag NightLight)
		for _, i in { 0, 1, 3, 5, 6 } do
			local x = -spec.length / 2 + 1 + i * (spec.length - 2) / 6
			local lamp = Instance.new("Part")
			lamp.Name = "CahayaLampu"
			lamp.Anchored = true
			lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = false, false, false
			lamp.Transparency = 1
			lamp.Size = Vector3.one * 0.5
			lamp.CFrame = spec.base * CFrame.new(x, 8.5, s * (half - 0.5))
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 220, 150)
			light.Brightness = 1.2
			light.Range = 26
			light.Enabled = false
			light.Parent = lamp
			CollectionService:AddTag(lamp, "NightLight")
			lamp.Parent = model
		end
	end

	-- sembunyikan dek dan pagar lama (dek tetap berkolisi)
	for _, inst in spec.hide do
		if inst:IsA("BasePart") then
			inst.Transparency = 1
			if inst.Name ~= "Dek" and inst.Name ~= "DekJembatan" then
				inst.CanCollide = false
			end
		end
	end
	model.Parent = folder
	return #model:GetDescendants()
end

return function(): number
	local map = Workspace.Map
	local folder = map:FindFirstChild("Jembatan") or Instance.new("Folder")
	folder.Name = "Jembatan"
	folder.Parent = map
	for _, c in folder:GetChildren() do
		c:Destroy()
	end

	local specs: { Spec } = {}
	local function collect(parent: Instance, names: { string }, near: Vector3, radius: number): { Instance }
		local out = {}
		for _, c in parent:GetChildren() do
			if table.find(names, c.Name) and c:IsA("BasePart") and (c.Position - near).Magnitude < radius then
				table.insert(out, c)
			end
		end
		return out
	end

	-- dua jembatan jalan raya (dek lama bernama "Dek" di Countryside.Roads)
	for _, dek in map.Countryside.Roads:GetChildren() do
		if dek.Name == "Dek" and dek:IsA("BasePart") then
			local base = CFrame.new(dek.Position.X, ROAD_TOP, dek.Position.Z)
				* CFrame.fromEulerAnglesYXZ(0, select(2, dek.CFrame:ToEulerAnglesYXZ()), 0)
				* CFrame.Angles(0, -math.pi / 2, 0)
			table.insert(specs, {
				name = "JembatanRaya",
				template = "JembatanRayaMentah",
				length = 60,
				roadWidth = 48,
				base = base,
				hide = {
					dek,
					table.unpack(collect(map.Countryside.Roads, { "PagarJembatan" }, dek.Position, 60)),
				},
			})
		end
	end

	-- jembatan jalan desa (RoadFixes)
	local fixes = map.RoadFixes
	local dekDesa = fixes:FindFirstChild("DekJembatan")
	if dekDesa and dekDesa:IsA("BasePart") then
		local hide: { Instance } = { dekDesa }
		for _, c in fixes:GetChildren() do
			if (c.Name == "PagarJembatan" or c.Name == "TiangPagar") and c:IsA("BasePart") then
				if (c.Position - dekDesa.Position).Magnitude < 60 then
					table.insert(hide, c)
				end
			end
		end
		table.insert(specs, {
			name = "JembatanDesa",
			template = "JembatanDesaMentah",
			length = 58,
			roadWidth = 28,
			base = CFrame.new(dekDesa.Position.X + 1, ROAD_TOP, dekDesa.Position.Z),
			hide = hide,
		})
	end

	local total = 0
	for _, spec in specs do
		total += build(spec, folder)
	end
	return total
end
