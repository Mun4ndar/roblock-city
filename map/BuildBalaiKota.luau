--!strict
--[[
	ROBLOCK CITY: Balai Kota mewah (dibuat di Blender: tools/blender/balai_kota.py -> assets/blender/balai_kota.fbx).

	Mesh diunggah sebagai asset 87064967622650 (Model, MeshPart per bahan: BkWall, BkStone, BkColumn, BkWhite,
	BkGold, BkRoof, BkDome, BkGlass, BkDark, BkFlag1, BkFlag2, BkHedge) dan dipasang di
	ServerStorage.BalaiKotaMentah. Skrip ini menaruhnya di Blok Layanan (asal Blender di (160, 1, 135), depan
	menghadap -Z ke jalan z=111), mencadangkan model lama ke ServerStorage.CadanganPeta.BalaiKotaLama, dan
	membuat kotak tabrakan tak terlihat (badan, sayap, menara, tangga, tiang) serta papan nama.
	Koordinat Blender -> Roblox lokal: (x, z, -y). Pusat bbox mesh: (0, 4.125, 25.75) dalam Blender.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(160, 1, 135) -- titik (0,0,0) Blender di dunia
local BBOX_CENTER_BL = Vector3.new(0, 4.125, 25.75) -- pusat kotak mesh dalam Blender (x, y, z)

local LOOK = {
	BkWall = { Color3.fromRGB(236, 226, 205), Enum.Material.SmoothPlastic, 0 },
	BkStone = { Color3.fromRGB(205, 196, 180), Enum.Material.Concrete, 0 },
	BkColumn = { Color3.fromRGB(250, 248, 242), Enum.Material.SmoothPlastic, 0 },
	BkWhite = { Color3.fromRGB(250, 248, 242), Enum.Material.SmoothPlastic, 0 },
	BkGold = { Color3.fromRGB(226, 172, 52), Enum.Material.Metal, 0 },
	BkRoof = { Color3.fromRGB(70, 78, 98), Enum.Material.SmoothPlastic, 0 },
	BkDome = { Color3.fromRGB(70, 165, 150), Enum.Material.SmoothPlastic, 0 },
	BkGlass = { Color3.fromRGB(125, 185, 220), Enum.Material.Glass, 0.3 },
	BkDark = { Color3.fromRGB(70, 46, 34), Enum.Material.Wood, 0 },
	BkFlag1 = { Color3.fromRGB(30, 110, 180), Enum.Material.Fabric, 0 },
	BkFlag2 = { Color3.fromRGB(240, 190, 40), Enum.Material.Fabric, 0 },
	BkHedge = { Color3.fromRGB(62, 135, 58), Enum.Material.Grass, 0 },
}

-- kotak tabrakan dalam koordinat Blender (x0, x1, y0, y1, z0, z1)
local COLLIDERS: { { any } } = {
	{ "Alas", -39, 39, -15, 14, 0, 1.0 },
	{ "Anak1", -17, 17, 14.4, 16.4, 0, 1.0 },
	{ "Anak2", -17, 17, 16.4, 18.4, 0, 0.75 },
	{ "Anak3", -17, 17, 18.4, 20.4, 0, 0.5 },
	{ "Anak4", -17, 17, 20.4, 22.4, 0, 0.25 },
	{ "Beranda", -21, 21, 9.3, 14.3, 0, 1.3 },
	{ "Badan", -22, 22, -14, 10, 0, 24.4 },
	{ "SayapKiri", -38, -22, -12, 8, 0, 16.5 },
	{ "SayapKanan", 22, 38, -12, 8, 0, 16.5 },
	{ "MenaraKiri", -41.9, -35.1, 2.6, 9.4, 0, 19 },
	{ "MenaraKanan", 35.1, 41.9, 2.6, 9.4, 0, 19 },
}
for i = 0, 7 do
	local x = -17.5 + i * 5
	table.insert(COLLIDERS, { "Tiang" .. i, x - 1.2, x + 1.2, 11.3, 13.7, 0, 21 })
end

return function(): number
	local raw = ServerStorage:FindFirstChild("BalaiKotaMentah")
	local downtown = Workspace.Map.Residential.Buildings.Downtown
	if raw == nil then
		warn("[BuildBalaiKota] ServerStorage.BalaiKotaMentah tidak ada (insert asset 87064967622650)")
		return 0
	end

	-- pusat kotak mesh mentah (dihitung, jadi tidak bergantung pada letak asal asset)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local half = part.Size / 2
			mn = mn:Min(part.Position - half)
			mx = mx:Max(part.Position + half)
		end
	end
	local rawCenter = (mn + mx) / 2
	local wantCenter = ORIGIN + Vector3.new(BBOX_CENTER_BL.X, BBOX_CENTER_BL.Z, -BBOX_CENTER_BL.Y)

	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	local old = downtown:FindFirstChild("BalaiKota")
	if old then
		local previous = backup:FindFirstChild("BalaiKotaLama")
		if previous then
			previous:Destroy()
		end
		old.Name = "BalaiKotaLama"
		old.Parent = backup
	end

	local model = Instance.new("Model")
	model.Name = "BalaiKota"
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") and LOOK[part.Name] then
			local clone = part:Clone()
			clone:ClearAllChildren()
			-- rotasi bawaan part hasil impor FBX berbeda-beda; susunan mesh berputar (rotasi + 180 derajat) dari susunan ideal
			local r0 = select(2, part.CFrame:ToOrientation())
			local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)
			local center = CFrame.new(wantCenter)
			clone.CFrame = center * CFrame.Angles(0, undo, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
			local look = LOOK[part.Name]
			clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
			clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
			if part.Name == "BkGlass" then
				CollectionService:AddTag(clone, "NightWindow")
			end
			clone.Parent = model
		end
	end

	local colliders = Instance.new("Folder")
	colliders.Name = "Tabrakan"
	colliders.Parent = model
	for _, c in COLLIDERS do
		local part = Instance.new("Part")
		part.Name = c[1]
		part.Anchored = true
		part.Transparency = 1
		part.CastShadow = false
		part.Size = Vector3.new(c[3] - c[2], c[7] - c[6], c[5] - c[4])
		part.Position = ORIGIN + Vector3.new((c[2] + c[3]) / 2, (c[6] + c[7]) / 2, -(c[4] + c[5]) / 2)
		part.Parent = colliders
	end

	local sign = Instance.new("Part")
	sign.Name = "PapanNama"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false
	sign.Transparency = 1
	sign.Size = Vector3.new(30, 1.05, 0.1)
	sign.Position = ORIGIN + Vector3.new(0, 21.8, -15.25) -- muka arsitrave (y Blender 15.2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BALAI KOTA ROBLOCK"
	label.TextColor3 = Color3.fromRGB(35, 55, 100)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
	sign.Parent = model

	model.Parent = downtown
	return #model:GetDescendants()
end
