--!strict
--[[
	ROBLOCK CITY: Balai Kota mewah (dibuat di Blender: tools/blender/balai_kota.py -> assets/blender/balai_kota.fbx).

	Mesh diunggah sebagai asset 87064967622650 (Model, MeshPart per bahan: BkWall, BkStone, BkColumn, BkWhite,
	BkGold, BkRoof, BkDome, BkGlass, BkDark, BkFlag1, BkFlag2, BkHedge) dan dipasang di
	ServerStorage.BalaiKotaMentah. Skrip ini menaruhnya di Blok Layanan (asal Blender di (160, 1, 135), depan
	menghadap -Z ke jalan z=111), mencadangkan model lama ke ServerStorage.CadanganPeta.BalaiKotaV1, dan
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
	-- BkFlag1/BkFlag2 (bendera biru/kuning bawaan mesh) sengaja dibuang: bendera Merah Putih dari map/BenderaBalaiKota
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
	-- dinding berongga (sama dengan COLL di tools/blender/balai_kota.py): aula, bukaan ke sayap, pintu depan
	{ "DindingBelakang", -22, 22, -14, -12.5, 0, 24.4 },
	{ "DindingKiriBelakang", -22, -20.5, -12.5, -7, 0, 24.4 },
	{ "DindingKiriDepan", -22, -20.5, 3, 8.5, 0, 24.4 },
	{ "AmbangKiri", -22, -20.5, -7, 3, 10.0, 24.4 },
	{ "DindingKananBelakang", 20.5, 22, -12.5, -7, 0, 24.4 },
	{ "DindingKananDepan", 20.5, 22, 3, 8.5, 0, 24.4 },
	{ "AmbangKanan", 20.5, 22, -7, 3, 10.0, 24.4 },
	{ "DepanKiri", -22, -3.6, 8.5, 10, 0, 24.4 },
	{ "DepanKanan", 3.6, 22, 8.5, 10, 0, 24.4 },
	{ "AmbangPintu", -3.6, 3.6, 8.5, 10, 10.8, 24.4 },
	{ "AtapAula", -20.5, 20.5, -12.5, 8.5, 21.5, 23.0 },
	{ "SayapKiriBelakang", -38, -22, -12, -10.5, 0, 16 },
	{ "SayapKiriDepan", -38, -22, 6.5, 8, 0, 16 },
	{ "SayapKiriUjung", -38, -36.5, -10.5, 6.5, 0, 16 },
	{ "AtapSayapKiri", -36.5, -22, -10.5, 6.5, 14.0, 15.2 },
	{ "SayapKananBelakang", 22, 38, -12, -10.5, 0, 16 },
	{ "SayapKananDepan", 22, 38, 6.5, 8, 0, 16 },
	{ "SayapKananUjung", 36.5, 38, -10.5, 6.5, 0, 16 },
	{ "AtapSayapKanan", 22, 36.5, -10.5, 6.5, 14.0, 15.2 },
	-- lantai dalam (permukaan z 1.3, sama dengan lantai beranda)
	{ "LantaiAula", -22, 22, -12.5, 8.5, 1.0, 1.3 },
	{ "LantaiAmbang", -3.6, 3.6, 8.5, 10, 1.0, 1.3 },
	{ "LantaiSayapKiri", -36.5, -22, -10.5, 6.5, 1.0, 1.3 },
	{ "LantaiSayapKanan", 22, 36.5, -10.5, 6.5, 1.0, 1.3 },
	{ "MenaraKiri", -41.9, -35.1, 2.6, 9.4, 0, 19 },
	{ "MenaraKanan", 35.1, 41.9, 2.6, 9.4, 0, 19 },
}
for i = 0, 7 do
	local x = -17.5 + i * 5
	table.insert(COLLIDERS, { "Tiang" .. i, x - 1.2, x + 1.2, 11.3, 13.7, 0, 21 })
end

return function(): number
	local raw = ServerStorage:FindFirstChild("BalaiKotaMentah")
	local downtown = Workspace.Map:FindFirstChild("BangunanBlender")
		or Workspace.Map.Residential.Buildings.Downtown
	if raw == nil then
		warn(
			"[BuildBalaiKota] ServerStorage.BalaiKotaMentah tidak ada (insert asset 87064967622650)"
		)
		return 0
	end

	-- pusat kotak mesh mentah (dihitung, jadi tidak bergantung pada letak asal asset)
	local mn, mx =
		Vector3.new(math.huge, math.huge, math.huge),
		Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			-- Size ada di sumbu lokal part (diputar hasil impor FBX): ubah ke setengah-ukuran dalam sumbu dunia
			local r, s = part.CFrame.Rotation, part.Size / 2
			local half = Vector3.new(
				math.abs(r.XVector.X) * s.X
					+ math.abs(r.YVector.X) * s.Y
					+ math.abs(r.ZVector.X) * s.Z,
				math.abs(r.XVector.Y) * s.X
					+ math.abs(r.YVector.Y) * s.Y
					+ math.abs(r.ZVector.Y) * s.Z,
				math.abs(r.XVector.Z) * s.X
					+ math.abs(r.YVector.Z) * s.Y
					+ math.abs(r.ZVector.Z) * s.Z
			)
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
		local previous = backup:FindFirstChild("BalaiKotaV1")
		if previous then
			previous:Destroy()
		end
		old.Name = "BalaiKotaV1"
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
			clone.CFrame = center
				* CFrame.Angles(0, undo, 0)
				* CFrame.new(part.Position - rawCenter)
				* part.CFrame.Rotation
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
		part.Position = ORIGIN
			+ Vector3.new((c[2] + c[3]) / 2, (c[6] + c[7]) / 2, -(c[4] + c[5]) / 2)
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

	-- pintu kaca ganda berengsel di bukaan depan (Blender x +-3.6, tengah dinding y 9.25): DoorService membukanya
	-- otomatis saat pemain mendekat (ayunan keluar, tanpa tabrakan). Lihat src/server/Services/DoorService.luau.
	local function door(doorName: string, side: number)
		local hingeX = ORIGIN.X + side * 3.6
		local wallZ = ORIGIN.Z - 9.25
		local bottom, height, width = ORIGIN.Y + 1.35, 9.4, 3.6
		local doorModel = Instance.new("Model")
		doorModel.Name = doorName
		local cx = hingeX - side * width / 2 -- panel terbentang dari engsel ke arah tengah
		local function piece(
			partName: string,
			size: Vector3,
			offset: Vector3,
			color: Color3,
			material: Enum.Material,
			transparency: number
		)
			local part = Instance.new("Part")
			part.Name = partName
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow =
				true, false, false, false, false
			part.Size = size
			part.Position = Vector3.new(cx, bottom + height / 2, wallZ) + offset
			part.Color, part.Material, part.Transparency = color, material, transparency
			part.Parent = doorModel
			return part
		end
		local gold = Color3.fromRGB(226, 172, 52)
		local glass = piece(
			"Kaca",
			Vector3.new(width - 0.5, height - 0.9, 0.12),
			Vector3.new(0, 0.1, 0),
			Color3.fromRGB(150, 205, 235),
			Enum.Material.Glass,
			0.45
		)
		piece(
			"RelAtas",
			Vector3.new(width, 0.4, 0.28),
			Vector3.new(0, height / 2 - 0.2, 0),
			gold,
			Enum.Material.Metal,
			0
		)
		piece(
			"RelBawah",
			Vector3.new(width, 0.8, 0.28),
			Vector3.new(0, -height / 2 + 0.4, 0),
			gold,
			Enum.Material.Metal,
			0
		)
		piece(
			"TiangEngsel",
			Vector3.new(0.25, height, 0.28),
			Vector3.new(side * -(width / 2 - 0.125), 0, 0),
			gold,
			Enum.Material.Metal,
			0
		)
		piece(
			"TiangTengah",
			Vector3.new(0.25, height, 0.28),
			Vector3.new(side * (width / 2 - 0.125), 0, 0),
			gold,
			Enum.Material.Metal,
			0
		)
		local handle = piece(
			"Gagang",
			Vector3.new(2.6, 0.18, 0.18),
			Vector3.new(side * (width / 2 - 0.55), 0, 0.28),
			gold,
			Enum.Material.Metal,
			0
		)
		handle.CFrame = CFrame.new(handle.Position) * CFrame.Angles(0, 0, math.rad(90))
		doorModel.PrimaryPart = glass
		doorModel:SetAttribute("HingeX", hingeX)
		doorModel:SetAttribute("HingeY", bottom + height / 2)
		doorModel:SetAttribute("HingeZ", wallZ)
		doorModel:SetAttribute("OpenDeg", side < 0 and 100 or -100)
		doorModel:SetAttribute("Radius", 12)
		CollectionService:AddTag(doorModel, "SwingDoor")
		doorModel.Parent = model
	end
	door("PintuKacaKiri", -1)
	door("PintuKacaKanan", 1)

	model.Parent = downtown
	return #model:GetDescendants()
end
