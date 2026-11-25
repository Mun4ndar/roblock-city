--!nocheck
-- BuildLomba: arena lomba 17-an (balap karung + panjat pinang) di lahan timur Taman Kota.
-- Hasil: ServerStorage.EventDecor.agustus.Lomba (RetentionService memasangnya hanya selama event
-- HUT RI). Tag: LombaKarungStart / LombaKarungFinish / LombaPinang (dipakai LombaService).
-- Tiang pinang = templat Blender ServerStorage.AsetPasar.pinang. Aman diulang.
-- Jalankan: require(game.ServerStorage.MapBuilders.BuildLomba)()

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

local TRACK_X0, TRACK_X1 = 772, 832 -- start dan finis (panjang 60 = IndonesiaConfig.LOMBA.karung.length)
local TRACK_Z_CANDIDATES = { 90, 80, 100, 70 }
local POLE_SPOTS = { { 790, 128 }, { 806, 128 }, { 822, 128 }, { 790, 112 }, { 822, 112 } }

local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local r = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0), params)
	return if r then r.Position.Y else 0
end

local function blocked(center: Vector3, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ServerStorage }
	for _, p in Workspace:GetPartBoundsInBox(CFrame.new(center), size, params) do
		if not p:IsA("Terrain") and p.CanCollide then
			return true
		end
	end
	return false
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function banner(parent: Instance, name: string, cf: CFrame, width: number, text: string)
	local board = part(parent, name, Vector3.new(width, 2, 0.4), cf, rgb(200, 30, 40))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
	end
	return board
end

local function arch(parent: Instance, x: number, z: number, y: number, text: string)
	for _, dz in { -5.2, 5.2 } do
		local pole = part(parent, "TiangGapura", Vector3.new(0.9, 9, 0.9), CFrame.new(x, y + 4.5, z + dz), rgb(245, 245, 245), Enum.Material.Wood)
		pole.CanCollide = true
		part(parent, "BenderaMerah", Vector3.new(0.2, 0.9, 1.4), CFrame.new(x, y + 9.4, z + dz + 0.7 * math.sign(dz)), rgb(220, 30, 40), Enum.Material.Fabric)
	end
	banner(parent, "SpandukGapura", CFrame.new(x, y + 8.4, z) * CFrame.Angles(0, math.rad(90), 0), 11.4, text)
end

return function()
	local decor = ServerStorage:FindFirstChild("EventDecor") and ServerStorage.EventDecor:FindFirstChild("agustus")
	assert(decor, "ServerStorage.EventDecor.agustus belum ada (jalankan BuildEventDecor)")
	local old = decor:FindFirstChild("Lomba")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Lomba"
	local log = {}

	local tz
	for _, z in TRACK_Z_CANDIDATES do
		local clear = true
		for x = TRACK_X0, TRACK_X1, 6 do
			if blocked(Vector3.new(x, groundY(x, z) + 3, z), Vector3.new(6, 5, 9)) then
				clear = false
				break
			end
		end
		if clear then
			tz = z
			break
		end
	end
	if tz == nil then
		tz = TRACK_Z_CANDIDATES[1]
		table.insert(log, "jalur balap karung terhalang pohon, dipakai z=" .. tz)
	end
	local y0 = groundY((TRACK_X0 + TRACK_X1) / 2, tz)
	local mid = (TRACK_X0 + TRACK_X1) / 2
	part(root, "JalurLomba", Vector3.new(TRACK_X1 - TRACK_X0 + 4, 0.12, 9), CFrame.new(mid, y0 + 0.07, tz), rgb(228, 200, 150), Enum.Material.Sand)
	for _, dz in { -4.6, 4.6 } do
		part(root, "GarisJalur", Vector3.new(TRACK_X1 - TRACK_X0 + 4, 0.14, 0.4), CFrame.new(mid, y0 + 0.09, tz + dz), rgb(250, 250, 250))
	end
	for x = TRACK_X0, TRACK_X1, 6 do
		for _, dz in { -5.4, 5.4 } do
			local c = if (x - TRACK_X0) / 6 % 2 == 0 then rgb(220, 30, 40) else rgb(250, 250, 250)
			part(root, "Penanda", Vector3.new(0.9, 1.2, 0.9), CFrame.new(x, groundY(x, tz + dz) + 0.6, tz + dz), c)
		end
	end
	arch(root, TRACK_X0, tz, y0, "START 🏁")
	arch(root, TRACK_X1, tz, y0, "FINISH 🏁")
	local startPad = part(root, "KarungStart", Vector3.new(5, 1, 9), CFrame.new(TRACK_X0 + 2, y0 + 0.5, tz), rgb(255, 255, 255))
	startPad.Transparency = 1
	CollectionService:AddTag(startPad, "LombaKarungStart")
	local finishPad = part(root, "KarungFinish", Vector3.new(4, 6, 10), CFrame.new(TRACK_X1, y0 + 3, tz), rgb(255, 255, 255))
	finishPad.Transparency = 1
	CollectionService:AddTag(finishPad, "LombaKarungFinish")
	banner(root, "PapanKarung", CFrame.new(TRACK_X0 - 3, y0 + 3.2, tz - 8) * CFrame.Angles(0, math.rad(180), 0), 7, "BALAP KARUNG")

	local tpl = ServerStorage.AsetPasar.pinang
	local count = 0
	for _, spot in POLE_SPOTS do
		if count >= 3 then
			break
		end
		local x, z = spot[1], spot[2]
		local y = groundY(x, z)
		if not blocked(Vector3.new(x, y + 3, z), Vector3.new(8, 5, 8)) then
			count += 1
			local pole = tpl:Clone()
			pole.Name = "Pinang" .. count
			pole:PivotTo(CFrame.new(x, y, z))
			local main = pole.Kayu
			main:SetAttribute("PinangId", count)
			CollectionService:AddTag(main, "LombaPinang")
			for _, d in pole:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			pole.Parent = root
		else
			table.insert(log, `tiang pinang ({x},{z}) terhalang`)
		end
	end
	banner(root, "PapanPinang", CFrame.new(798, groundY(798, 120) + 3.2, 120), 7, "PANJAT PINANG")
	table.insert(log, `tiang pinang terpasang: {count}`)
	root.Parent = decor
	return log
end
