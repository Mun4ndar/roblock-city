--!nocheck
-- BuildPasarMalam: membuat lapak pasar malam di Taman Kota (lahan rumput barat-selatan taman) dan
-- lapak festival kuliner (akhir pekan). Hasil disimpan di ServerStorage.PasarMalam.{Malam,Festival};
-- FoodService memasangnya ke Workspace.Map.PasarMalam hanya saat buka (malam / akhir pekan).
-- Lapak = templat Blender ServerStorage.AsetPasar.lapak (depan = -Z). Aman diulang.
-- Jalankan: require(game.ServerStorage.MapBuilders.BuildPasarMalam)()

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

local AWNINGS = {
	{ rgb(214, 56, 56), rgb(246, 244, 238) },
	{ rgb(50, 110, 210), rgb(246, 244, 238) },
	{ rgb(60, 160, 90), rgb(246, 244, 238) },
	{ rgb(240, 140, 40), rgb(246, 244, 238) },
	{ rgb(150, 70, 190), rgb(250, 220, 80) },
}

-- Deret lapak: x, z, menghadap (0 = ke -Z, 180 = ke +Z), menu, nama papan.
local MALAM = {
	{ 636, 108, 180, "bakso", "Bakso Pak Slamet" },
	{ 652, 108, 180, "sate", "Sate Madura" },
	{ 668, 108, 180, "gorengan", "Gorengan Bu Tini" },
	{ 684, 108, 180, "minuman", "Es Cendol Segar" },
	{ 700, 108, 180, "martabak", "Martabak Manis" },
	{ 636, 136, 0, "jagung", "Jagung Bakar" },
	{ 652, 136, 0, "warung", "Nasi Goreng Gerobak" },
	{ 668, 136, 0, "gado", "Gado-gado Bu Sri" },
	{ 684, 136, 0, "minuman", "Es Campur Segar" },
	{ 700, 136, 0, "martabak", "Kopi & Roti Bakar" },
}
local FESTIVAL = {
	{ 735, 140, 0, "sate", "Festival: Sate Lilit" },
	{ 751, 140, 0, "jagung", "Festival: Kerak Telor" },
	{ 767, 140, 0, "bakso", "Festival: Soto & Bakso" },
	{ 783, 140, 0, "gorengan", "Festival: Jajan Pasar" },
	{ 799, 140, 0, "minuman", "Festival: Es Segar" },
	{ 815, 140, 0, "martabak", "Festival: Martabak" },
}

local function groundY(x: number, z: number): number
	local r = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0))
	return if r then r.Position.Y else 0
end

-- Ada pohon/benda lain di tempat lapak? (Terrain diabaikan.)
local function blocked(cf: CFrame): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ServerStorage }
	local parts = Workspace:GetPartBoundsInBox(cf * CFrame.new(0, 3, 0), Vector3.new(6.5, 6, 5), params)
	for _, p in parts do
		if not p:IsA("Terrain") and p.CanCollide and p.Name ~= "Baseplate" then
			return true
		end
	end
	return false
end

local function faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -2
	for _, face in Enum.NormalId:GetEnumItems() do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
		local dot = normal:Dot(direction)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

local function sign(papan: BasePart, text: string, front: Vector3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = faceToward(papan, front)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = papan
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = rgb(255, 245, 210)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
end

local function place(parent: Instance, tpl: Model, spec: { any }, index: number): (Model?, string?)
	local x, z, face, menu, name = spec[1], spec[2], spec[3], spec[4], spec[5]
	local y = groundY(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(face), 0)
	if blocked(cf) then
		return nil, `{name} ({x},{z}) terhalang`
	end
	local model = tpl:Clone()
	model.Name = "Lapak" .. index
	model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(face), 0))
	local pair = AWNINGS[(index - 1) % #AWNINGS + 1]
	model.TendaA.Color = pair[1]
	model.TendaB.Color = pair[2]
	sign(model.Papan, name, model:GetPivot().LookVector)
	local main = model.Kayu
	main:SetAttribute("StallMenu", menu)
	main:SetAttribute("StallName", name)
	CollectionService:AddTag(main, "FoodStall")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = parent
	return model, nil
end

local function bulbPole(parent: Instance, x: number, z: number)
	local y = groundY(x, z)
	local pole = Instance.new("Part")
	pole.Name = "TiangLampu"
	pole.Anchored = true
	pole.Size = Vector3.new(0.5, 11, 0.5)
	pole.Position = Vector3.new(x, y + 5.5, z)
	pole.Color = rgb(70, 60, 55)
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CastShadow = false
	pole.Parent = parent
	local light = Instance.new("PointLight")
	light.Brightness = 0.7
	light.Range = 34
	light.Color = rgb(255, 214, 150)
	light.Parent = pole
	return pole
end

return function()
	local tpl = ServerStorage.AsetPasar.lapak
	local root = ServerStorage:FindFirstChild("PasarMalam")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "PasarMalam"
	local malam = Instance.new("Folder")
	malam.Name = "Malam"
	malam.Parent = root
	local festival = Instance.new("Folder")
	festival.Name = "Festival"
	festival.Parent = root
	local log = {}
	for i, spec in MALAM do
		local m, why = place(malam, tpl, spec, i)
		if not m then
			table.insert(log, why)
		end
	end
	for i, spec in FESTIVAL do
		local m, why = place(festival, tpl, spec, 100 + i)
		if not m then
			table.insert(log, why)
		end
	end
	-- Tiang lampu di tengah lorong + speaker musik (Sound dipasang FoodService).
	for _, x in { 628, 668, 708 } do
		bulbPole(malam, x, 122)
	end
	-- Untai bohlam antar tiang (Neon, tanpa tabrakan).
	for index = 1, 2 do
		local xa, xb = 628 + (index - 1) * 40, 668 + (index - 1) * 40
		local y = groundY(xa, 122) + 10.5
		for k = 0, 10 do
			local t = k / 10
			local sag = math.sin(t * math.pi) * 1.4
			local bulb = Instance.new("Part")
			bulb.Name = "Bohlam"
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.new(0.7, 0.7, 0.7)
			bulb.Position = Vector3.new(xa + (xb - xa) * t, y - sag, 122)
			bulb.Anchored = true
			bulb.CanCollide = false
			bulb.CastShadow = false
			bulb.Material = Enum.Material.Neon
			bulb.Color = ({ rgb(255, 226, 140), rgb(255, 120, 120), rgb(140, 220, 255), rgb(170, 255, 170) })[k % 4 + 1]
			bulb.Parent = malam
		end
	end
	local speaker = Instance.new("Part")
	speaker.Name = "SpeakerPasar"
	speaker.Anchored = true
	speaker.Size = Vector3.new(1.4, 2.2, 1.2)
	speaker.Position = Vector3.new(668, groundY(668, 122) + 1.1, 122)
	speaker.Color = rgb(35, 35, 40)
	speaker.Material = Enum.Material.SmoothPlastic
	speaker.Parent = malam
	root.Parent = ServerStorage
	return log
end
