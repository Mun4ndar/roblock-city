--!strict
--[[
	ROBLOCK CITY: kantor pemadam kebakaran modern (dibuat di Blender: assets/blender/stasiun_damkar.fbx).

	Versi garasi TINGGI (bukaan pintu 12 stud supaya truk tangga 10,6 stud muat): asset 104213637771429
	(assets/blender/stasiun_damkar_tinggi.fbx, semua titik z >= 8,9 naik 3), dipasang di ServerStorage.StasiunDamkarMentah.
	Versi pertama: asset 83253360669850 (Model, 8 MeshPart per bahan: FsWall, FsRed, FsTrim,
	FsGlass, FsDark, FsYellow, FsFloor, FsWhite) dan dipasang di ServerStorage.StasiunDamkarMentah.
	Skrip ini menaruhnya di Blok Layanan (pusat (146, 1, 255), depan menghadap -Z ke jalan z=214),
	mencadangkan model lama ke ServerStorage.CadanganPeta.PemadamLama, dan membuat:
	  Tabrakan (kotak tak terlihat), Pelataran, PapanNama, dan folder Teluk berisi dua part bertag
	  "ServiceBay" (atribut VehicleId = damkar / ambulans). VehicleService memakai teluk itu untuk
	  memarkir kendaraan dinas dan mengeluarkannya dari garasi.
	Koordinat dari Blender: lokal Roblox = (x, z, -y); asal mesh (296.17, 0, 316.03) dalam asset.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(296.17, 0, 316.03)
local CENTER = Vector3.new(146, 1, 255)

local LOOK = {
	FsWall = { Color3.fromRGB(243, 238, 226), Enum.Material.SmoothPlastic, 0 },
	FsRed = { Color3.fromRGB(205, 38, 34), Enum.Material.SmoothPlastic, 0 },
	FsTrim = { Color3.fromRGB(150, 155, 162), Enum.Material.SmoothPlastic, 0 },
	FsGlass = { Color3.fromRGB(135, 195, 230), Enum.Material.Glass, 0.35 },
	FsDark = { Color3.fromRGB(28, 34, 46), Enum.Material.SmoothPlastic, 0 },
	FsYellow = { Color3.fromRGB(250, 200, 40), Enum.Material.SmoothPlastic, 0 },
	FsFloor = { Color3.fromRGB(110, 113, 120), Enum.Material.Concrete, 0 },
	FsWhite = { Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, 0 },
}

-- kotak tabrakan dalam koordinat Blender (x0, x1, y0, y1, z0, z1)
local COLLIDERS: { { any } } = {
	{ "Belakang", -25, 6.5, 13.8, 15, 0, 15.5 },
	{ "Kiri", -25, -23.7, -15, 15, 0, 15.5 },
	{ "Sekat1", -10.5, -9.5, -15, 15, 0, 15.5 },
	{ "Sekat2", 4.6, 6.5, -15, 15, 0, 15.5 },
	{ "Tiang1", -10.8, -8.2, -15.2, -12.5, 0, 15.5 },
	{ "Tiang2", 4.3, 6.5, -15.2, -12.5, 0, 15.5 },
	{ "Balok", -25, 6.5, -15, -13.8, 12, 15.5 },
	{ "Atap", -25.4, 6.9, -15.5, 15.4, 15.5, 16.2 },
	{ "Kantor", 6.5, 25, -15, 15, 0, 21.2 },
	{ "Menara", 16.3, 25.3, -15.6, -6.2, 0, 31.2 },
	{ "Lantai", -23.7, 4.6, -15, 13.8, 0, 0.25 },
}

return function(): number
	local raw = ServerStorage:FindFirstChild("StasiunDamkarMentah")
	local downtown = Workspace.Map.Residential.Buildings.Downtown
	if raw == nil then
		warn("[BuildFireStation] ServerStorage.StasiunDamkarMentah tidak ada (insert asset 83253360669850)")
		return 0
	end
	local world = CFrame.new(CENTER) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-ORIGIN)

	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	local old = downtown:FindFirstChild("PemadamKebakaran")
	if old then
		local previous = backup:FindFirstChild("PemadamRendah")
		if previous then
			previous:Destroy()
		end
		old.Name = "PemadamRendah"
		old.Parent = backup
	end

	local model = Instance.new("Model")
	model.Name = "PemadamKebakaran"
	for _, part in raw:GetChildren() do
		if part:IsA("MeshPart") and LOOK[part.Name] then
			local clone = part:Clone()
			clone:ClearAllChildren()
			clone.CFrame = world * part.CFrame
			local look = LOOK[part.Name]
			clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
			clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
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
		part.CFrame = world
			* CFrame.new(ORIGIN + Vector3.new((c[2] + c[3]) / 2, (c[6] + c[7]) / 2, -(c[4] + c[5]) / 2))
		part.Parent = colliders
	end

	local apron = Instance.new("Part")
	apron.Name = "Pelataran"
	apron.Anchored = true
	apron.Size = Vector3.new(52, 0.3, 9)
	apron.Position = Vector3.new(146, 0.97, 235.5)
	apron.Material = Enum.Material.Concrete
	apron.Color = Color3.fromRGB(165, 168, 172)
	apron.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "PapanNama"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.new(27.3, 2.4, 0.1)
	sign.CFrame = world * CFrame.new(ORIGIN + Vector3.new(-9.35, 13.8, 15.55))
	sign.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- model diputar 180 derajat
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PEMADAM KEBAKARAN"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	local bays = Instance.new("Folder")
	bays.Name = "Teluk"
	bays.Parent = model
	for _, bay in { { "TelukDamkar", "damkar", -17 }, { "TelukTangga", "damkarTangga", -2 } } do
		local part = Instance.new("Part")
		part.Name = bay[1]
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(9, 0.2, 25)
		local at = world * CFrame.new(ORIGIN + Vector3.new(bay[3], 0, 1))
		part.CFrame = CFrame.lookAt(Vector3.new(at.X, 1.3, at.Z), Vector3.new(at.X, 1.3, at.Z - 1))
		part:SetAttribute("VehicleId", bay[2])
		CollectionService:AddTag(part, "ServiceBay")
		part.Parent = bays
	end

	model.Parent = downtown
	return #model:GetDescendants()
end
