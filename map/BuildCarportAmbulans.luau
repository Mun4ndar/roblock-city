--!strict
--[[
	ROBLOCK CITY: carport ambulans di sisi timur rumah sakit (Blender: assets/blender/carport_ambulans.fbx,
	asset 121291151959060, templat ServerStorage.CarportAmbulansMentah). Tengah (78.2, 1, 160), terbuka
	di kedua ujung, papan "PARKIR AMBULANS" menghadap jalan (+Z). Part TelukAmbulans bertag "ServiceBay"
	(VehicleId = ambulans): VehicleService memarkir ambulans di sini dan mengeluarkannya dari sini.

	Catatan impor FBX: tiap MeshPart membawa rotasi model hasil sisip. Susun ulang lewat CFrame relatif
	terhadap part lantai (AmFloor), lalu putar 180 derajat supaya depan mesh (-Z asli) menghadap +Z.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LOOK = {
	AmTeal = { Color3.fromRGB(24, 160, 145), Enum.Material.SmoothPlastic },
	AmWhite = { Color3.fromRGB(245, 246, 248), Enum.Material.SmoothPlastic },
	AmFloor = { Color3.fromRGB(110, 113, 120), Enum.Material.Concrete },
	AmYellow = { Color3.fromRGB(250, 200, 40), Enum.Material.SmoothPlastic },
}

return function(): number
	local raw = ServerStorage:FindFirstChild("CarportAmbulansMentah")
	if raw == nil then
		warn("[BuildCarportAmbulans] ServerStorage.CarportAmbulansMentah tidak ada")
		return 0
	end
	local old = Workspace.Map.Toko:FindFirstChild("CarportAmbulans")
	if old then
		old:Destroy()
	end
	local floorRaw = raw.AmFloor :: MeshPart
	local base = CFrame.new(78.2, 1.1, 160) * CFrame.Angles(0, math.pi, 0)
	local model = Instance.new("Model")
	model.Name = "CarportAmbulans"
	for name, look in LOOK do
		local part = (raw :: any)[name]:Clone() :: MeshPart
		part:ClearAllChildren()
		part.CFrame = base * floorRaw.CFrame:ToObjectSpace((raw :: any)[name].CFrame)
		part.Color, part.Material = look[1], look[2]
		part.Anchored, part.CanCollide, part.CanTouch = true, false, false
		part.Parent = model
	end
	local ground = Instance.new("Part")
	ground.Name = "Lantai"
	ground.Anchored = true
	ground.Transparency = 1
	ground.Size = Vector3.new(11, 0.2, 24)
	ground.Position = Vector3.new(78.2, 1.1, 160)
	ground.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "PapanNama"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Color = Color3.fromRGB(250, 185, 205)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Size = Vector3.new(10.4, 1.9, 0.2)
	sign.Position = Vector3.new(78.2, 8.85, 172.99)
	sign.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PARKIR AMBULANS"
	label.TextColor3 = Color3.fromRGB(10, 110, 100)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	local bay = Instance.new("Part")
	bay.Name = "TelukAmbulans"
	bay.Anchored = true
	bay.CanCollide = false
	bay.CanQuery = false
	bay.Transparency = 1
	bay.Size = Vector3.new(8, 0.2, 18)
	bay.CFrame = CFrame.lookAt(Vector3.new(78.2, 1.3, 160), Vector3.new(78.2, 1.3, 161))
	bay:SetAttribute("VehicleId", "ambulans")
	CollectionService:AddTag(bay, "ServiceBay")
	bay.Parent = model

	model.Parent = Workspace.Map.Toko
	return #model:GetDescendants()
end
