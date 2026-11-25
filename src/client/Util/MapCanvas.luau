--!strict
-- MapCanvas: gambar peta dunia (laut, daratan, jalan, pin tujuan, garis rute GPS) di satu Frame
-- "kanvas" yang dipakai bersama oleh peta kecil dan peta penuh (kanvas dipindah induknya saat peta
-- penuh dibuka). 1 piksel kanvas = 1 stud; perbesaran lewat UIScale, jadi menggeser/zoom murah.
-- Gaya: pastel datar bergaya peta modern (jalan putih berbingkai abu, pantai berpasir, laut biru muda).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapData = require(Shared:WaitForChild("MapData"))
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))

local MapCanvas = {}

local rgb = Color3.fromRGB
MapCanvas.COLORS = {
	sea = rgb(124, 203, 240),
	shore = rgb(170, 226, 247),
	grass = rgb(190, 228, 154),
	sand = rgb(247, 233, 180),
	rock = rgb(190, 192, 198),
	casing = rgb(188, 198, 210),
	road = rgb(255, 255, 255),
	runway = rgb(210, 216, 226),
	route = rgb(36, 124, 255),
	routeCasing = rgb(255, 255, 255),
	player = rgb(40, 110, 255),
	task = rgb(255, 196, 0),
	home = rgb(255, 92, 120),
	ink = rgb(28, 36, 62),
}

local LAND_COLOR = { rgb(190, 228, 154), rgb(247, 233, 180), rgb(190, 192, 198) }

export type Pin = {
	button: TextButton,
	label: TextLabel,
	scale: UIScale,
	dest: DestinationConfig.Destination,
}

local canvas: Frame
local canvasScale: UIScale
local currentScale = 0.2
local pins: { [string]: Pin } = {}
local pinFactor = 0.8
local showMinor = true
local showLabels = false
local interactive = false
local selectedId: string? = nil
local onPin: ((DestinationConfig.Destination) -> ())? = nil

local routeLayer: Frame
local routeFrames: { { frame: Frame, px: number } } = {}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function rect(
	parent: Instance,
	x: number,
	z: number,
	sx: number,
	sz: number,
	rotation: number,
	color: Color3,
	round: boolean?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, z)
	f.Size = UDim2.fromOffset(sx, sz)
	f.Rotation = rotation
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if round then
		corner(f, UDim.new(0.5, 0))
	end
	f.Parent = parent
	return f
end

local function layer(name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(0, 0)
	f.ZIndex = order
	f.Parent = canvas
	return f
end

local function buildTerrainAndRoads()
	local shoreLayer = layer("Pantai", 1)
	local landLayer = layer("Daratan", 2)
	for _, r in MapData.LAND :: { { number } } do
		local w, h = r[2] - r[1], r[4] - r[3]
		local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
		rect(shoreLayer, cx, cz, w + 26, h + 26, 0, MapCanvas.COLORS.shore)
		rect(landLayer, cx, cz, w + 1, h + 1, 0, LAND_COLOR[r[5]] or LAND_COLOR[1])
	end
	local casing = layer("JalanTepi", 3)
	local fill = layer("Jalan", 4)
	for _, r in MapData.ROADS :: { { number } } do
		local x, z, sx, sz, rot, kind = r[1], r[2], r[3], r[4], r[5], r[6]
		if kind == 1 then
			rect(casing, x, z, sx + 10, sz + 10, 0, MapCanvas.COLORS.casing, true)
			rect(fill, x, z, sx, sz, 0, MapCanvas.COLORS.road, true)
		else
			local color = if kind == 2 then MapCanvas.COLORS.runway else MapCanvas.COLORS.road
			rect(casing, x, z, sx + 10, sz + 10, -rot, MapCanvas.COLORS.casing)
			rect(fill, x, z, sx, sz, -rot, color)
		end
	end
end

local function applyPins()
	for id, pin in pins do
		local selected = id == selectedId
		local visible = pin.dest.major or showMinor or selected
		pin.button.Visible = visible
		pin.button.Active = interactive
		pin.button.ZIndex = if selected then 20 else 1
		pin.scale.Scale = pinFactor * (if selected then 1.3 else 1) / currentScale
		pin.label.Visible = visible
			and (
				selected
				or (
					showLabels
					and ((pin.dest.major and currentScale >= 0.17) or currentScale >= 0.32)
				)
			)
	end
end

local function applyRouteWidth()
	for _, entry in routeFrames do
		local studs = entry.px / currentScale
		local f = entry.frame
		if f:GetAttribute("Segmen") then
			f.Size = UDim2.fromOffset(f:GetAttribute("Panjang") :: number, studs)
		else
			f.Size = UDim2.fromOffset(studs, studs)
		end
	end
end

function MapCanvas.build(): Frame
	if canvas then
		return canvas
	end
	canvas = Instance.new("Frame")
	canvas.Name = "Kanvas"
	canvas.Size = UDim2.fromOffset(0, 0)
	canvas.BackgroundTransparency = 1
	canvasScale = Instance.new("UIScale")
	canvasScale.Scale = currentScale
	canvasScale.Parent = canvas

	buildTerrainAndRoads()
	routeLayer = layer("Rute", 5)
	local pinLayer = layer("Pin", 6)

	for _, dest in DestinationConfig.LIST do
		local zone = DestinationConfig.zone(dest.zone)
		local button = Instance.new("TextButton")
		button.Name = dest.id
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromOffset(dest.position.X, dest.position.Z)
		button.Size = UDim2.fromOffset(22, 22)
		button.BackgroundColor3 = dest.color or zone.color
		button.AutoButtonColor = false
		button.Text = dest.icon
		button.TextSize = 13
		button.Font = Enum.Font.GothamMedium
		button.BorderSizePixel = 0
		corner(button, UDim.new(0.5, 0))
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 2
		stroke.Parent = button
		local scale = Instance.new("UIScale")
		scale.Parent = button
		local label = Instance.new("TextLabel")
		label.Name = "Nama"
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 1, 3)
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 0.1
		label.TextColor3 = MapCanvas.COLORS.ink
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.Text = dest.name
		label.Visible = false
		label.ZIndex = 2
		corner(label, UDim.new(0, 6))
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 5)
		pad.PaddingRight = UDim.new(0, 5)
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 2)
		pad.Parent = label
		label.Parent = button
		button.Activated:Connect(function()
			if onPin then
				onPin(dest)
			end
		end)
		button.Parent = pinLayer
		pins[dest.id] = { button = button, label = label, scale = scale, dest = dest }
	end
	applyPins()
	return canvas
end

function MapCanvas.getCanvas(): Frame
	return MapCanvas.build()
end

function MapCanvas.getScale(): number
	return currentScale
end

function MapCanvas.setScale(scale: number)
	MapCanvas.build()
	currentScale = scale
	canvasScale.Scale = scale
	applyPins()
	applyRouteWidth()
end

-- Cara tampil pin. minor = pin kecil ikut tampil; labels = nama tampil; interactive = pin bisa diketuk.
function MapCanvas.setPinMode(factor: number, minor: boolean, labels: boolean, canTap: boolean)
	MapCanvas.build()
	pinFactor, showMinor, showLabels, interactive = factor, minor, labels, canTap
	applyPins()
end

function MapCanvas.setPinCallback(callback: ((DestinationConfig.Destination) -> ())?)
	onPin = callback
end

function MapCanvas.setSelected(id: string?)
	selectedId = id
	if canvas then
		applyPins()
	end
end

-- Gambar rute GPS (nil = hapus). Lebar garis dijaga tetap dalam piksel layar walau diperbesar.
function MapCanvas.showRoute(points: { Vector3 }?)
	MapCanvas.build()
	for _, entry in routeFrames do
		entry.frame:Destroy()
	end
	table.clear(routeFrames)
	if points == nil or #points < 2 then
		return
	end
	local pass = {
		{ px = 11, color = MapCanvas.COLORS.routeCasing },
		{ px = 7, color = MapCanvas.COLORS.route },
	}
	for _, p in pass do
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local d = b - a
			local length = Vector3.new(d.X, 0, d.Z).Magnitude
			if length > 0.5 then
				local f = rect(
					routeLayer,
					(a.X + b.X) / 2,
					(a.Z + b.Z) / 2,
					length,
					1,
					math.deg(math.atan2(d.Z, d.X)),
					p.color
				)
				f.ZIndex = if p.px == 11 then 1 else 3
				f:SetAttribute("Segmen", true)
				f:SetAttribute("Panjang", length)
				table.insert(routeFrames, { frame = f, px = p.px })
			end
		end
		-- sambungan membulat di tiap titik belok
		for i = 1, #points do
			local f = rect(routeLayer, points[i].X, points[i].Z, 1, 1, 0, p.color, true)
			f.ZIndex = if p.px == 11 then 2 else 4
			table.insert(routeFrames, { frame = f, px = p.px })
		end
	end
	applyRouteWidth()
end

-- Penanda dinamis (rumah, tugas, pemain di peta penuh). Diletakkan di lapisan atas kanvas.
local dynamicLayer: Frame? = nil
function MapCanvas.addMarker(
	color: Color3,
	px: number,
	icon: string?
): { frame: Frame, set: (Vector3?) -> () }
	MapCanvas.build()
	if dynamicLayer == nil then
		dynamicLayer = layer("Penanda", 8)
	end
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Visible = false
	corner(f, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = f
	local scale = Instance.new("UIScale")
	scale.Name = "Skala"
	scale.Parent = f
	if icon then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = icon
		l.TextSize = math.floor(px * 0.62)
		l.Font = Enum.Font.GothamMedium
		l.Parent = f
	end
	f.Parent = dynamicLayer
	return {
		frame = f,
		set = function(position: Vector3?)
			if position == nil then
				f.Visible = false
				return
			end
			f.Position = UDim2.fromOffset(position.X, position.Z)
			scale.Scale = pinFactor / currentScale
			f.Visible = true
		end,
	}
end

-- Panah pemain (lingkaran biru + tanda panah putih) sebagai Frame; putar lewat .Rotation.
function MapCanvas.makeArrow(parent: Instance, size: number): Frame
	local root = Instance.new("Frame")
	root.Name = "Pemain"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	-- sorot arah (cahaya di depan)
	local cone = Instance.new("Frame")
	cone.AnchorPoint = Vector2.new(0.5, 1)
	cone.Position = UDim2.fromScale(0.5, 0.5)
	cone.Size = UDim2.fromScale(0.62, 0.78)
	cone.BackgroundColor3 = MapCanvas.COLORS.player
	cone.BackgroundTransparency = 0.7
	cone.BorderSizePixel = 0
	corner(cone, UDim.new(0.5, 0))
	cone.Parent = root
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.5, 0.5)
	dot.BackgroundColor3 = MapCanvas.COLORS.player
	dot.BorderSizePixel = 0
	corner(dot, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2.5
	stroke.Parent = dot
	dot.Parent = root
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromScale(0.5, 0.2)
	tip.Size = UDim2.fromScale(0.2, 0.2)
	tip.Rotation = 45
	tip.BackgroundColor3 = MapCanvas.COLORS.player
	tip.BorderSizePixel = 0
	tip.Parent = root
	root.Parent = parent
	return root
end

return MapCanvas
