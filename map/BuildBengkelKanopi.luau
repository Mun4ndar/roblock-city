--!strict
--[[
	ROBLOCK CITY: kanopi bengkel di halaman belakang Bengkel (Blender: tools/blender/bengkel_kanopi.py ->
	assets/blender/bengkel_kanopi.fbx, asset 120121254169397, templat ServerStorage.KanopiBengkelMentah).
	Hasil: Workspace.Map.BangunanBlender.KanopiBengkel = kanopi + mobil kecil terangkat di lift dua tiang
	+ penjaga tabrakan tak terlihat. Mekanik R15 dibuat NpcService (grup "Mekanik", spots di bawah).

	Catatan impor FBX: tiap MeshPart punya Position = pusat kotak mesh, rotasi 0; Blender +Y menjadi
	-Z Roblox. Kanopi diputar 180 derajat supaya sisi terbuka (depan Blender) menghadap jalan (+Z) dan
	dinding belakang menempel ke bangunan (-Z). Dunia: x = ORIGIN.x - x_blender, z = ORIGIN.z + y_blender.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(146, 1.0, 296) -- tengah lantai kanopi (atas trotoar)
local LIFT_X = -6.0 -- x_blender pusat lift
local PAD_TOP = 5.25 -- tinggi bantalan lengan lift dari lantai

local function c3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LOOK: { [string]: { any } } = {
	KpFloor = { c3(118, 120, 128), Enum.Material.Concrete },
	KpLine = { c3(250, 200, 40), Enum.Material.SmoothPlastic },
	KpPost = { c3(52, 58, 72), Enum.Material.Metal },
	KpYellow = { c3(250, 195, 40), Enum.Material.SmoothPlastic },
	KpDark = { c3(30, 32, 38), Enum.Material.Metal },
	KpRoof = { c3(28, 48, 98), Enum.Material.Metal },
	KpRib = { c3(52, 84, 152), Enum.Material.Metal },
	KpLamp = { c3(255, 246, 215), Enum.Material.Neon },
	KpWall = { c3(182, 186, 194), Enum.Material.Metal },
	KpBox = { c3(190, 150, 100), Enum.Material.SmoothPlastic },
	KpOilB = { c3(30, 84, 200), Enum.Material.SmoothPlastic },
	KpOilY = { c3(240, 200, 30), Enum.Material.SmoothPlastic },
	KpPeg = { c3(140, 105, 70), Enum.Material.Wood },
	KpTool = { c3(190, 192, 200), Enum.Material.Metal },
	KpRed = { c3(200, 40, 40), Enum.Material.SmoothPlastic },
	KpWood = { c3(160, 120, 75), Enum.Material.WoodPlanks },
	KpLiftBlue = { c3(30, 80, 180), Enum.Material.Metal },
	KpRubber = { c3(20, 20, 22), Enum.Material.SmoothPlastic },
	KpTire = { c3(22, 22, 24), Enum.Material.SmoothPlastic },
	KpRim = { c3(190, 192, 198), Enum.Material.Metal },
}

return function(): number
	local raw = ServerStorage:FindFirstChild("KanopiBengkelMentah")
	if raw == nil then
		warn("[BuildBengkelKanopi] ServerStorage.KanopiBengkelMentah tidak ada")
		return 0
	end
	local parent = Workspace.Map:FindFirstChild("BangunanBlender") or Workspace.Map
	local old = parent:FindFirstChild("KanopiBengkel")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "KanopiBengkel"

	local floorRaw = raw:FindFirstChild("KpFloor") :: MeshPart
	local origin = floorRaw.Position - Vector3.new(0, 0.15, 0) -- asal Blender (lantai tebal 0,3)
	local rot = CFrame.new(ORIGIN) * CFrame.Angles(0, math.pi, 0)
	-- titik Blender (x, y, z_atas) ke dunia
	local function world(x: number, y: number, z: number): Vector3
		return ORIGIN + Vector3.new(-x, z, y)
	end

	for name, look in LOOK do
		local src = raw:FindFirstChild(name) :: MeshPart?
		if src then
			local part = src:Clone()
			part:ClearAllChildren()
			part.CFrame = rot * CFrame.new(src.Position - origin)
			part.Color, part.Material = look[1], look[2]
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.CastShadow = name ~= "KpLine"
			part.Parent = model
		end
	end

	local function collider(name: string, center: Vector3, size: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.Position = center
		p.Parent = model
	end
	collider("Lantai", world(0, 0, 0.15), Vector3.new(44, 0.3, 30))
	for _, x in { -18, 0, 18 } do
		for _, y in { -12, 12 } do
			collider("Tiang", world(x, y, 6.5), Vector3.new(0.9, 12.4, 0.9))
		end
	end
	for _, sy in { -1, 1 } do
		collider("TiangLift", world(LIFT_X, sy * 5.5, 5.8), Vector3.new(1.5, 11, 1.5))
	end
	collider("DindingBelakang", world(0, -14.7, 4.8), Vector3.new(43, 9, 0.5))
	collider("MejaKerja", world(13.5, -12.6, 1.8), Vector3.new(11, 3, 3.2))
	collider("LemariAlat", world(7, -13, 2.4), Vector3.new(4, 4.2, 2.6))
	collider("RakOli", world(-13.5, -13.1, 3.6), Vector3.new(11, 7, 2.2))

	-- lampu malam: PointLight di part kecil bertag NightLight (DayNightController)
	for _, x in { -14, -4, 6, 16 } do
		for _, y in { -5, 5 } do
			local zt = 12.6 + (15.4 - 12.6) * (1 - math.abs(y) / 15) - 1.0
			local lamp = Instance.new("Part")
			lamp.Name = "LampuKanopi"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.CanQuery = false
			lamp.Transparency = 1
			lamp.Size = Vector3.new(1, 0.2, 1)
			lamp.Position = world(x, y, zt - 1.6)
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 0.7
			light.Color = c3(255, 240, 205)
			light.Enabled = false
			light.Parent = lamp
			CollectionService:AddTag(lamp, "NightLight")
			lamp.Parent = model
		end
	end

	-- papan nama di list kuning depan
	local sign = Instance.new("Part")
	sign.Name = "PapanNama"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Color = c3(28, 48, 98)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Size = Vector3.new(24, 1.1, 0.2)
	sign.Position = world(0, 16.3, 12.4) + Vector3.new(0, 0, 0.1)
	sign.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BENGKEL  •  MODIFIKASI MOBIL"
	label.TextColor3 = c3(250, 200, 40)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	-- mobil kecil terangkat di lift (tanpa roda: roda dilepas, ban ada di rak)
	local shells = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("CarShells")
	local template = if shells then shells:FindFirstChild("kancil") else nil
	if template then
		local car = template:Clone()
		car.Name = "MobilDiLift"
		for _, d in car:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
				if d.Name == "ShellBody" then
					d.Color = c3(232, 112, 40)
				elseif d.Name == "ShellGlass" then
					d.Color = c3(120, 170, 200)
				end
			end
		end
		car.Parent = model
		local at = world(LIFT_X, 0, PAD_TOP + 0.1)
		car:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi / 2, 0))
		local box, size = car:GetBoundingBox()
		car:PivotTo(car:GetPivot() + Vector3.new(0, at.Y - (box.Position.Y - size.Y / 2), 0))
	end

	model.Parent = parent
	return #model:GetDescendants()
end
