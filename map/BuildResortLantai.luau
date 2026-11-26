--!strict
--[[
	ROBLOCK CITY: lantai kamar Resort + dua kabin lift (lobi dan lantai kamar).
	Mesh dari Blender: tools/blender/resort_lantai.py (-> ServerStorage.ResortLantaiMentah), data tabrakan/tempat tidur/lampu/label:
	ResortLantaiData (modul saudara di ServerStorage.MapBuilders, dibuat otomatis oleh skrip Blender).
	Lantai kamar dibangun di y +2000 tepat di atas resor (X/Z sama, jadi GPS dan misi tetap valid); pemain tiba lewat lift.
	Koordinat Blender (x, y, z) -> dunia: BASE * (x, z, -y); BASE = CFrame(1249, 1, -460) * yaw -pi/2 (depan resort = +X).
	Jalankan: require(MapBuilders.BuildResortLantai)()  (hasil di Workspace.Map.BangunanBlender.ROBLOCKResort.Lantai dan .LiftLobi)
	Runtime: src/server/Services/ResortService.luau (lift, tidur, tamu).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BASE = CFrame.new(1249, 1, -460) * CFrame.Angles(0, -math.pi / 2, 0)
local BASE_UP = BASE * CFrame.new(0, 2000, 0)
local BBOX_CENTER_BL = Vector3.new(0, 0, 4.25)

local rgb = Color3.fromRGB
local M = Enum.Material
local SP, MET, WOOD, FAB, GLS, NEON, MAR = M.SmoothPlastic, M.Metal, M.Wood, M.Fabric, M.Glass, M.Neon, M.Marble

local LOOK: { [string]: { any } } = {
	RlParq = { rgb(176, 130, 84), M.WoodPlanks, 0 },
	RlCeil = { rgb(204, 196, 184), SP, 0 },
	RlFloor = { rgb(40, 104, 112), FAB, 0 },
	RlGoldT = { rgb(226, 172, 52), MET, 0 },
	RlWall = { rgb(188, 168, 140), SP, 0 },
	RlArtA = { rgb(70, 150, 190), SP, 0 },
	RlArtB = { rgb(236, 170, 80), SP, 0 },
	RlArtC = { rgb(120, 180, 120), SP, 0 },
	RlArtD = { rgb(220, 110, 120), SP, 0 },
	RlArtE = { rgb(90, 170, 210), SP, 0 },
	RlNeon = { rgb(255, 228, 180), NEON, 0 },
	RlPot = { rgb(186, 98, 64), SP, 0 },
	RlLeaf = { rgb(62, 150, 70), SP, 0 },
	RlRug = { rgb(206, 190, 160), FAB, 0 },
	RlWoodD = { rgb(96, 62, 40), WOOD, 0 },
	RlWood = { rgb(180, 134, 90), WOOD, 0 },
	RlLinen = { rgb(250, 248, 242), FAB, 0 },
	RlBlanket = { rgb(40, 150, 160), FAB, 0 },
	RlDark = { rgb(28, 30, 36), SP, 0 },
	RlScreen = { rgb(40, 60, 90), SP, 0 },
	RlTealCush = { rgb(40, 130, 140), FAB, 0 },
	RlTile = { rgb(226, 236, 240), MAR, 0 },
	RlPorcelain = { rgb(252, 252, 250), SP, 0 },
	RlGlass = { rgb(190, 225, 240), GLS, 0.5 },
	RlSteel = { rgb(196, 202, 208), MET, 0 },
}

local function W(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, z, -y)
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------- kabin lift (dari Part)
type Booth = {
	name: string,
	level: string,
	base: CFrame,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	door: string, -- "+y" atau "+x": sisi pintu (tepi atas sumbu itu), arah keluar searah sumbu positif
	floorPlate: boolean,
}

local function booth(parent: Instance, b: Booth): Model
	local model = Instance.new("Model")
	model.Name = b.name
	model:SetAttribute("Level", b.level)
	local steel, gold = rgb(196, 202, 208), rgb(226, 172, 52)
	local t = 0.3
	local function slab(partName: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, mat: Enum.Material): Part
		local p = newPart(model, partName, Vector3.new(x1 - x0, z1 - z0, y1 - y0), W(b.base, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		p.Color, p.Material = color, mat
		return p
	end
	local alongY = b.door == "+y"
	local outBL = if alongY then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local outWorld = (b.base * CFrame.new(outBL.X, 0, -outBL.Y)).Position - b.base.Position
	-- dinding samping dan belakang
	if alongY then
		slab("DindingKiri", b.x0 - t, b.x0, b.y0, b.y1 + t, b.z0, b.z1, steel, MET)
		slab("DindingKanan", b.x1, b.x1 + t, b.y0, b.y1 + t, b.z0, b.z1, steel, MET)
		if b.floorPlate then
			slab("DindingBelakang", b.x0, b.x1, b.y0 - t, b.y0, b.z0, b.z1, steel, MET)
		end
	else
		slab("DindingKiri", b.x0 - t, b.x1 + t, b.y0 - t, b.y0, b.z0, b.z1, steel, MET)
		slab("DindingKanan", b.x0 - t, b.x1 + t, b.y1, b.y1 + t, b.z0, b.z1, steel, MET)
		slab("DindingBelakang", b.x0 - t, b.x0, b.y0, b.y1, b.z0, b.z1, steel, MET)
	end
	slab("Atap", b.x0 - t, b.x1 + t, b.y0 - t, b.y1 + t, b.z1, b.z1 + t, steel, MET)
	-- garis emas di sepanjang dinding (hiasan)
	if alongY then
		slab("HiasanKiri", b.x0 + 0.0, b.x0 + 0.08, b.y0, b.y1, b.z0 + 3.6, b.z0 + 3.8, gold, MET).CanCollide = false
		slab("HiasanKanan", b.x1 - 0.08, b.x1, b.y0, b.y1, b.z0 + 3.6, b.z0 + 3.8, gold, MET).CanCollide = false
	else
		slab("HiasanKiri", b.x0, b.x1, b.y0, b.y0 + 0.08, b.z0 + 3.6, b.z0 + 3.8, gold, MET).CanCollide = false
		slab("HiasanKanan", b.x0, b.x1, b.y1 - 0.08, b.y1, b.z0 + 3.6, b.z0 + 3.8, gold, MET).CanCollide = false
	end
	if b.floorPlate then
		slab("Lantai", b.x0 - t, b.x1 + t, b.y0 - t, b.y1 + t, b.z0 - 0.4, b.z0, rgb(70, 74, 82), MET)
	end
	-- dua daun pintu geser di tepi pintu (menutup ruang antara dinding samping)
	local slide = if alongY then Vector3.new(1, 0, 0) else Vector3.new(0, 0, -1) -- sumbu geser (lokal Roblox; Blender y -> -z)
	local half = ((if alongY then b.x1 - b.x0 else b.y1 - b.y0)) / 2
	for index, side in { -1, 1 } do
		local cx, cy
		local panel: Part
		if alongY then
			cx = (b.x0 + b.x1) / 2 + side * half / 2
			panel = slab("Pintu" .. index, cx - half / 2, cx + half / 2, b.y1 - 0.4, b.y1 - 0.1, b.z0, b.z1, rgb(214, 218, 224), MET)
		else
			cy = (b.y0 + b.y1) / 2 + side * half / 2
			panel = slab("Pintu" .. index, b.x1 - 0.4, b.x1 - 0.1, cy - half / 2, cy + half / 2, b.z0, b.z1, rgb(214, 218, 224), MET)
		end
		local worldSlide = (b.base * CFrame.new(
			if alongY then side * half else 0,
			0,
			if alongY then 0 else -side * half
		)).Position - b.base.Position
		panel:SetAttribute("Slide", worldSlide)
		CollectionService:AddTag(panel, "ResortLiftDoor")
		local strip = newPart(model, "Garis" .. index, Vector3.new(
			if alongY then 0.14 else panel.Size.X + 0.05,
			panel.Size.Y - 1.0,
			if alongY then panel.Size.Z + 0.05 else 0.14
		), panel.CFrame)
		strip.Color, strip.Material, strip.CanCollide = gold, MET, false
		strip.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = panel, strip
		weld.Parent = strip
		strip.Anchored = false
	end
	-- zona dalam kabin (tak terlihat), arah keluar dan titik pintu
	local cxm, cym = (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2
	local zone = newPart(model, "Dalam", Vector3.new(b.x1 - b.x0, b.z1 - b.z0, b.y1 - b.y0), W(b.base, cxm, cym, (b.z0 + b.z1) / 2))
	zone.Transparency, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false, false
	zone:SetAttribute("Out", outWorld)
	local doorBL = if alongY then Vector3.new(cxm, b.y1, b.z0) else Vector3.new(b.x1, cym, b.z0)
	zone:SetAttribute("DoorPos", (b.base * CFrame.new(doorBL.X, doorBL.Z, -doorBL.Y)).Position)
	-- panel tombol (dinding belakang)
	local plateBL = if alongY then Vector3.new(cxm, b.y0 + 0.4, b.z0 + 4.2) else Vector3.new(b.x0 + 0.4, cym, b.z0 + 4.2)
	local plateOut = if alongY then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local pos = Vector3.new(plateBL.X, plateBL.Z, -plateBL.Y)
	local plate = newPart(model, "PanelPilih", Vector3.new(1.6, 2.4, 0.2), b.base * CFrame.lookAt(pos, pos + Vector3.new(plateOut.X, 0, -plateOut.Y)))
	plate.Color, plate.Material, plate.CanCollide = rgb(40, 44, 52), SP, false
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(160, 240)
	g.Parent = plate
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Text = "▲\nLIFT\n▼"
	lbl.TextColor3 = rgb(255, 214, 90)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = g
	-- lampu kabin redup
	local lamp = newPart(model, "Lampu", Vector3.new(1, 0.2, 1), W(b.base, cxm, cym, b.z1 - 0.1))
	lamp.Color, lamp.Material, lamp.CanCollide, lamp.CanQuery = rgb(255, 232, 190), NEON, false, false
	local light = Instance.new("PointLight")
	light.Brightness, light.Range, light.Shadows = 0.25, 10, false
	light.Color = rgb(255, 232, 196)
	light.Parent = lamp
	CollectionService:AddTag(model, "ResortLift")
	model.Parent = parent
	return model
end

-- ---------------------------------------------------------------- lantai kamar
local function lantai(): string
	local raw = ServerStorage:FindFirstChild("ResortLantaiMentah")
	local resortModel = Workspace.Map.BangunanBlender:FindFirstChild("ROBLOCKResort")
	local dataModule = script.Parent:FindFirstChild("ResortLantaiData")
	if raw == nil or resortModel == nil or dataModule == nil then
		return "ResortLantaiMentah / ROBLOCKResort / ResortLantaiData tidak ada"
	end
	local data = require(dataModule :: ModuleScript) :: any
	for _, n in { "Lantai", "LiftLobi" } do
		local old = resortModel:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end

	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local r, s = part.CFrame.Rotation, part.Size / 2
			local half = Vector3.new(
				math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z,
				math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z,
				math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z
			)
			mn = mn:Min(part.Position - half)
			mx = mx:Max(part.Position + half)
		end
	end
	local rawCenter = (mn + mx) / 2
	local center = BASE_UP * CFrame.new(BBOX_CENTER_BL.X, BBOX_CENTER_BL.Z, -BBOX_CENTER_BL.Y)

	local model = Instance.new("Model")
	model.Name = "Lantai"
	local count = 0
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local look = key and LOOK[key]
			if look then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Name = key :: string
				local r0 = select(2, part.CFrame:ToOrientation())
				local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)
				clone.CFrame = center * CFrame.Angles(0, undo, 0) * CFrame.new(part.Position - rawCenter) * part.CFrame.Rotation
				clone.Color, clone.Material, clone.Transparency = look[1], look[2], look[3]
				clone.Anchored, clone.CanCollide, clone.CanTouch = true, false, false
				clone.CastShadow = key == "RlWall" or key == "RlCeil"
				clone.Parent = model
				count += 1
			end
		end
	end

	local colliders = Instance.new("Folder")
	colliders.Name = "Tabrakan"
	colliders.Parent = model
	local function box(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		local p = newPart(colliders, name, Vector3.new(x1 - x0, z1 - z0, y1 - y0), W(BASE_UP, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		p.CastShadow = false
		if p.Name:match("^Dinding") or p.Name:match("^Ujung") or p.Name:match("^Sekat") then
			-- dinding: tabrakan terlihat tapi tersembunyi di dalam mesh dinding (kamera Zoom tertahan, tidak tembus)
			p.Size = p.Size - Vector3.new(0.06, 0.06, 0.06)
			p.Color = rgb(188, 168, 140)
			p.Material = SP
		else
			p.Transparency = 1
		end
	end
	for _, s in data.SOLIDS do
		box(s[1], s[2], s[3], s[4], s[5], s[6], s[7])
	end

	-- lampu redup (kamar dan koridor)
	local lights = Instance.new("Folder")
	lights.Name = "Lampu"
	lights.Parent = model
	for _, l in data.LAMPS do
		local p = newPart(lights, "Lampu", Vector3.new(0.5, 0.5, 0.5), W(BASE_UP, l[1], l[2], l[3]))
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
		local pl = Instance.new("PointLight")
		pl.Brightness = l[4] * 0.4 -- kamar redup, tidak menyilaukan
		pl.Range = l[5]
		pl.Color = rgb(255, 232, 196)
		pl.Shadows = false
		pl.Parent = p
	end

	-- tempat tidur: pelat tak terlihat; +Z lokal pelat = arah kepala (ResortService memasang prompt)
	local beds = Instance.new("Folder")
	beds.Name = "Kasur"
	beds.Parent = model
	for _, b in data.BEDS do
		local yaw = math.rad(b[5])
		local pos = Vector3.new(b[2], b[4], -b[3])
		local head = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) -- arah kepala (lokal Roblox)
		local plate = newPart(beds, "TempatTidur", Vector3.new(4.4, 0.2, 6.0), BASE_UP * CFrame.lookAt(pos, pos - head))
		plate.Transparency, plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.CastShadow = 1, false, true, false, false
		plate:SetAttribute("Kamar", b[1])
		CollectionService:AddTag(plate, "ResortBed")
	end

	-- nomor kamar di dinding koridor
	for _, l in data.LABELS do
		local pos = Vector3.new(l[2], 5.2 + data.FLOOR, -l[3])
		local part = newPart(model, "Nomor" .. l[1], Vector3.new(2.4, 0.9, 0.1), BASE_UP * CFrame.lookAt(pos, pos + Vector3.new(0, 0, -l[4])))
		part.Color, part.Material = rgb(20, 70, 90), SP
		part.CanCollide, part.CanQuery, part.CastShadow = false, false, false
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.CanvasSize = Vector2.new(240, 90)
		g.Parent = part
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1
		lb.Size = UDim2.fromScale(1, 1)
		lb.Text = "Kamar " .. l[1]
		lb.TextColor3 = rgb(255, 226, 150)
		lb.Font = Enum.Font.GothamBlack
		lb.TextScaled = true
		lb.Parent = g
	end

	-- kabin lift lantai kamar (ujung barat koridor, pintu menghadap +x)
	booth(model, {
		name = "LiftLantai", level = "lantai", base = BASE_UP,
		x0 = -37.0, x1 = -30.0, y0 = -3.0, y1 = 3.0, z0 = data.FLOOR, z1 = 8.4,
		door = "+x", floorPlate = true,
	})
	model.Parent = resortModel

	-- kabin lift lobi (belakang lobi, kanan; pintu menghadap +y, belakangnya dinding lobi + pintu lift hiasan)
	booth(resortModel, {
		name = "LiftLobi", level = "lobi", base = BASE,
		x0 = 12.6, x1 = 19.2, y0 = -17.5, y1 = -13.4, z0 = 1.0, z1 = 8.6,
		door = "+y", floorPlate = false,
	})
	return `lantai: {count} mesh, {#data.SOLIDS} kotak tabrakan, {#data.BEDS} kasur`
end

return function(): string
	return lantai()
end
