--!strict
-- MapUiController: PETA PENUH. Dibuka dengan mengetuk peta kecil (atau tombol di HP). Isi:
--   * peta besar yang bisa digeser (seret), diperbesar (+/-, roda mouse), semua pin tempat
--   * daftar semua tujuan per zona (Pusat Kota, Perumahan, Pantai, Desa & Kebun, Bandara) + pencarian
--   * kartu tujuan dengan tombol "Mulai GPS" -> NavController mencari rute lewat jalan
-- Gambar petanya (MapCanvas) sama dengan peta kecil; kanvasnya dipindah induknya saat peta dibuka.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))
local MapData = require(Shared:WaitForChild("MapData"))

local Util = script.Parent.Parent:WaitForChild("Util")
local MapCanvas = require(Util:WaitForChild("MapCanvas"))
local NavController = require(script.Parent:WaitForChild("NavController"))
local HouseUiController = require(script.Parent:WaitForChild("HouseUiController"))
local JobController = require(script.Parent:WaitForChild("JobController"))

local player = Players.LocalPlayer

local MapUiController = {}

local rgb = Color3.fromRGB
local C = {
	panel = rgb(24, 32, 60),
	header = rgb(34, 44, 82),
	row = rgb(38, 50, 92),
	rowSelected = rgb(64, 96, 190),
	text = rgb(240, 244, 255),
	subtle = rgb(158, 172, 208),
	accent = rgb(46, 150, 255),
	stop = rgb(235, 80, 90),
	chip = rgb(44, 58, 104),
}
local PANEL = Vector2.new(820, 480)
local MAP_SIZE = Vector2.new(500, 408)
local MIN_SCALE, MAX_SCALE = 0.05, 0.6

local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local mapClip: CanvasGroup
local mapFrame: Frame
local list: ScrollingFrame
local search: TextBox
local chipRow: Frame
local card: Frame
local cardTitle: TextLabel
local cardInfo: TextLabel
local cardButton: TextButton
local playerArrow: Frame
local homeMarker: { frame: Frame, set: (Vector3?) -> () }
local taskMarker: { frame: Frame, set: (Vector3?) -> () }

local isOpen = false
local center = Vector3.new(0, 0, 0)
local scale = 0.13
local filterZone: string? = nil
local selected: DestinationConfig.Destination? = nil
local rows: { [string]: { button: TextButton, distance: TextLabel, position: Vector3 } } = {}
local dragging = false
local dragMoved = 0
local lastPointer = Vector2.new()
local elapsed = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = C.text
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = C.accent
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	for key, value in props do
		(b :: any)[key] = value
	end
	return b
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	return if root then root.Position else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ---------------------------------------------------------------- peta

local function clampCenter()
	local b = MapData.BOUNDS
	center =
		Vector3.new(math.clamp(center.X, b.minX, b.maxX), 0, math.clamp(center.Z, b.minZ, b.maxZ))
end

local function applyView()
	clampCenter()
	local canvas = MapCanvas.getCanvas()
	canvas.Position =
		UDim2.fromOffset(MAP_SIZE.X / 2 - center.X * scale, MAP_SIZE.Y / 2 - center.Z * scale)
end

local function setScale(value: number)
	scale = math.clamp(value, MIN_SCALE, MAX_SCALE)
	MapCanvas.setScale(scale)
	applyView()
end

local function focusOn(position: Vector3?)
	if position == nil then
		return
	end
	center = position
	applyView()
end

-- Tampilkan pemain dan tujuan sekaligus.
local function fitBoth(target: Vector3)
	local here = rootPosition()
	if here == nil then
		focusOn(target)
		return
	end
	local dx = math.abs(target.X - here.X) + 360
	local dz = math.abs(target.Z - here.Z) + 360
	center = Vector3.new((target.X + here.X) / 2, 0, (target.Z + here.Z) / 2)
	setScale(math.min(MAP_SIZE.X / dx, MAP_SIZE.Y / dz, 0.3))
end

-- ---------------------------------------------------------------- daftar tujuan

local function etaText(studs: number): string
	return "±" .. NavController.formatEta(studs * 1.3 / 16) .. " jalan kaki"
end

local function refreshCard()
	local target = NavController.getTarget()
	if selected == nil then
		card.Visible = false
		return
	end
	card.Visible = true
	local here = rootPosition()
	local dist = if here then flatDistance(here, selected.position) else 0
	local zone = DestinationConfig.zone(selected.zone)
	cardTitle.Text = selected.icon .. "  " .. selected.name
	cardInfo.Text = `{zone.name}  ·  {NavController.formatDistance(dist)}  ·  {etaText(dist)}`
	local active = target ~= nil and target.id == selected.id
	cardButton.Text = if active then "⏹ Hentikan GPS" else "🧭 Mulai GPS"
	cardButton.BackgroundColor3 = if active then C.stop else C.accent
end

local function selectDest(dest: DestinationConfig.Destination?, move: boolean)
	selected = dest
	MapCanvas.setSelected(if dest then dest.id else nil)
	for id, row in rows do
		row.button.BackgroundColor3 = if dest and dest.id == id then C.rowSelected else C.row
	end
	refreshCard()
	if dest and move then
		fitBoth(dest.position)
	end
end

local function destinations(): { DestinationConfig.Destination }
	local result: { DestinationConfig.Destination } = {}
	local home = HouseUiController.getHomePosition()
	if home then
		table.insert(result, {
			id = "rumahku",
			name = "Rumahku",
			zone = "perumahan",
			icon = "🏠",
			position = home,
			major = true,
			arrive = 30,
		})
	end
	for _, d in DestinationConfig.LIST do
		table.insert(result, d)
	end
	local here = rootPosition()
	if here then
		table.sort(result, function(a, b)
			return flatDistance(here, a.position) < flatDistance(here, b.position)
		end)
	end
	return result
end

local function rebuildList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(rows)
	local query = string.lower(search.Text)
	local order = 0
	for _, dest in destinations() do
		local zone = DestinationConfig.zone(dest.zone)
		if
			(filterZone == nil or dest.zone == filterZone)
			and (query == "" or string.find(string.lower(dest.name), query, 1, true))
		then
			order += 1
			local row = button({
				Name = "Baris_" .. dest.id,
				LayoutOrder = order,
				Size = UDim2.new(1, -6, 0, 44),
				BackgroundColor3 = if selected and selected.id == dest.id
					then C.rowSelected
					else C.row,
				Text = "",
			})
			corner(row, 12)
			local badge = label({
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 0,
				BackgroundColor3 = dest.color or zone.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 17,
				Text = dest.icon,
			})
			corner(badge, 16)
			badge.Parent = row
			label({
				Position = UDim2.fromOffset(46, 4),
				Size = UDim2.new(1, -110, 0, 20),
				Font = Enum.Font.GothamBold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = dest.name,
			}).Parent =
				row
			label({
				Position = UDim2.fromOffset(46, 23),
				Size = UDim2.new(1, -110, 0, 16),
				TextSize = 11,
				TextColor3 = C.subtle,
				Text = zone.name,
			}).Parent =
				row
			local distance = label({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(60, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = C.subtle,
				Font = Enum.Font.GothamBold,
				Text = "",
			})
			distance.Parent = row
			row.Parent = list
			rows[dest.id] = { button = row, distance = distance, position = dest.position }
			row.Activated:Connect(function()
				selectDest(dest, true)
			end)
		end
	end
end

local function updateDistances()
	local here = rootPosition()
	if here == nil then
		return
	end
	for _, row in rows do
		row.distance.Text = NavController.formatDistance(flatDistance(here, row.position))
	end
end

local function buildChips()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = chipRow
	local function addChip(id: string?, text: string, order: number)
		local chip = button({
			Name = "Zona_" .. (id or "semua"),
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			BackgroundColor3 = C.chip,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = text,
		})
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = chip
		corner(chip, 14)
		chip.Parent = chipRow
		chip.Activated:Connect(function()
			filterZone = id
			for _, other in chipRow:GetChildren() do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = if other == chip then C.accent else C.chip
				end
			end
			rebuildList()
			updateDistances()
		end)
		if id == nil then
			chip.BackgroundColor3 = C.accent
		end
	end
	addChip(nil, "Semua", 0)
	for index, zone in DestinationConfig.ZONES do
		addChip(zone.id, zone.icon .. " " .. zone.name, index)
	end
end

-- ---------------------------------------------------------------- bangun UI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PetaPenuh"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Latar"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		MapUiController.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL.X, PANEL.Y)
	panel.BackgroundColor3 = C.panel
	corner(panel, 24)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.new(1, 1, 1)
	panelStroke.Transparency = 0.8
	panelStroke.Thickness = 2
	panelStroke.Parent = panel
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	panel.Parent = gui
	-- panel menyerap ketukan supaya tidak menutup lewat latar
	local sink = Instance.new("TextButton")
	sink.Name = "Penyerap"
	sink.Size = UDim2.fromScale(1, 1)
	sink.BackgroundTransparency = 1
	sink.Text = ""
	sink.AutoButtonColor = false
	sink.ZIndex = 0
	sink.Parent = panel

	label({
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(400, 34),
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		Text = "🗺️ Peta ROBLOCK CITY",
	}).Parent =
		panel
	local close = button({
		Name = "Tutup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.stop,
		Text = "X",
	})
	corner(close, 17)
	close.Parent = panel
	close.Activated:Connect(function()
		MapUiController.close()
	end)

	-- peta
	mapFrame = Instance.new("Frame")
	mapFrame.Name = "Peta"
	mapFrame.Position = UDim2.fromOffset(14, 58)
	mapFrame.Size = UDim2.fromOffset(MAP_SIZE.X, MAP_SIZE.Y)
	mapFrame.BackgroundColor3 = MapCanvas.COLORS.sea
	mapFrame.Active = true
	corner(mapFrame, 18)
	mapFrame.Parent = panel
	mapClip = Instance.new("CanvasGroup")
	mapClip.Name = "Isi"
	mapClip.Size = UDim2.fromScale(1, 1)
	mapClip.BackgroundTransparency = 1
	corner(mapClip, 18)
	mapClip.Parent = mapFrame
	local mapStroke = Instance.new("UIStroke")
	mapStroke.Color = C.header
	mapStroke.Thickness = 3
	mapStroke.Parent = mapFrame

	local function mapButton(
		text: string,
		anchor: Vector2,
		position: UDim2,
		onClick: () -> ()
	): TextButton
		local b = button({
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = Color3.new(1, 1, 1),
			TextColor3 = MapCanvas.COLORS.ink,
			TextSize = 22,
			Text = text,
			ZIndex = 30,
		})
		corner(b, 19)
		b.Parent = mapFrame
		b.Activated:Connect(onClick)
		return b
	end
	mapButton("+", Vector2.new(1, 1), UDim2.new(1, -10, 1, -54), function()
		setScale(scale * 1.4)
	end).Name =
		"Perbesar"
	mapButton("-", Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), function()
		setScale(scale / 1.4)
	end).Name =
		"Perkecil"
	mapButton("◎", Vector2.new(0, 1), UDim2.new(0, 10, 1, -10), function()
		focusOn(rootPosition())
	end).Name =
		"KeAku"

	-- seret untuk menggeser, roda mouse untuk zoom
	mapFrame.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragMoved = 0
			lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	mapFrame.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			setScale(scale * (if input.Position.Z > 0 then 1.2 else 1 / 1.2))
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local pointer = Vector2.new(input.Position.X, input.Position.Y)
			local delta = (pointer - lastPointer) / panelScale.Scale
			lastPointer = pointer
			dragMoved += delta.Magnitude
			center = center - Vector3.new(delta.X / scale, 0, delta.Y / scale)
			applyView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	-- panel samping
	local side = Instance.new("Frame")
	side.Name = "Samping"
	side.Position = UDim2.fromOffset(528, 58)
	side.Size = UDim2.fromOffset(278, 408)
	side.BackgroundTransparency = 1
	side.Parent = panel

	search = Instance.new("TextBox")
	search.Name = "Cari"
	search.Size = UDim2.new(1, 0, 0, 34)
	search.BackgroundColor3 = C.header
	search.PlaceholderText = "🔍  Cari tempat..."
	search.PlaceholderColor3 = C.subtle
	search.Text = ""
	search.TextColor3 = C.text
	search.Font = Enum.Font.GothamMedium
	search.TextSize = 14
	search.ClearTextOnFocus = false
	search.TextXAlignment = Enum.TextXAlignment.Left
	corner(search, 17)
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 14)
	searchPad.Parent = search
	search.Parent = side

	local chipScroll = Instance.new("ScrollingFrame")
	chipScroll.Name = "Zona"
	chipScroll.Position = UDim2.fromOffset(0, 40)
	chipScroll.Size = UDim2.new(1, 0, 0, 34)
	chipScroll.BackgroundTransparency = 1
	chipScroll.BorderSizePixel = 0
	chipScroll.ScrollBarThickness = 0
	chipScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	chipScroll.CanvasSize = UDim2.new()
	chipScroll.ScrollingDirection = Enum.ScrollingDirection.X
	chipScroll.Parent = side
	chipRow = chipScroll :: any
	buildChips()

	list = Instance.new("ScrollingFrame")
	list.Name = "Daftar"
	list.Position = UDim2.fromOffset(0, 80)
	list.Size = UDim2.new(1, 0, 1, -170)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = side

	card = Instance.new("Frame")
	card.Name = "Kartu"
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.fromScale(0, 1)
	card.Size = UDim2.new(1, 0, 0, 82)
	card.BackgroundColor3 = C.header
	card.Visible = false
	corner(card, 16)
	card.Parent = side
	cardTitle = label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	cardTitle.Parent = card
	cardInfo = label({
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = 11,
		TextColor3 = C.subtle,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	cardInfo.Parent = card
	cardButton = button({
		Name = "MulaiGps",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 32),
		TextSize = 15,
		Text = "🧭 Mulai GPS",
	})
	corner(cardButton, 16)
	cardButton.Parent = card
	cardButton.Activated:Connect(function()
		local dest = selected
		if dest == nil then
			return
		end
		local target = NavController.getTarget()
		if target and target.id == dest.id then
			NavController.clear()
			refreshCard()
			return
		end
		NavController.setTarget({
			id = dest.id,
			name = dest.name,
			icon = dest.icon,
			position = dest.position,
			arrive = dest.arrive,
		})
		MapUiController.close()
	end)

	search:GetPropertyChangedSignal("Text"):Connect(function()
		rebuildList()
		updateDistances()
	end)

	-- penanda dinamis di kanvas
	local canvas = MapCanvas.getCanvas()
	playerArrow = MapCanvas.makeArrow(canvas, 34)
	playerArrow.ZIndex = 40
	playerArrow.Visible = false
	for _, child in playerArrow:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 40
		end
	end
	homeMarker = MapCanvas.addMarker(MapCanvas.COLORS.home, 22, "🏠")
	taskMarker = MapCanvas.addMarker(MapCanvas.COLORS.task, 20, "★")

	MapCanvas.setPinCallback(function(dest: DestinationConfig.Destination)
		if dragMoved < 8 then
			selectDest(dest, false)
			local row = rows[dest.id]
			if row then
				local y = row.button.AbsolutePosition.Y
					- list.AbsolutePosition.Y
					+ list.CanvasPosition.Y
				list.CanvasPosition = Vector2.new(0, math.max(0, y - 80))
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		panelScale.Scale =
			math.clamp(math.min(size.X / (PANEL.X + 30), size.Y / (PANEL.Y + 30)), 0.45, 1.25)
	end
end

local function update()
	if not isOpen then
		return
	end
	local here = rootPosition()
	if here then
		playerArrow.Position = UDim2.fromOffset(here.X, here.Z)
		local size = 34 / scale
		playerArrow.Size = UDim2.fromOffset(size, size)
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		if root then
			local look = root.CFrame.LookVector
			playerArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end
	homeMarker.set(HouseUiController.getHomePosition())
	taskMarker.set(JobController.getTarget())
	updateDistances()
	refreshCard()
end

function MapUiController.isOpen(): boolean
	return isOpen
end

function MapUiController.open(focusId: string?)
	if isOpen then
		return
	end
	isOpen = true
	updateScale()
	local MinimapController = require(script.Parent:WaitForChild("MinimapController")) :: any
	MinimapController.setVisible(false)
	local canvas = MapCanvas.getCanvas()
	canvas.Parent = mapClip
	MapCanvas.setPinMode(0.85, true, true, true)
	gui.Enabled = true
	playerArrow.Visible = true
	rebuildList()
	local target = NavController.getTarget()
	local here = rootPosition()
	if target and target.id then
		selectDest(DestinationConfig.get(target.id), false)
		fitBoth(target.position)
	else
		selectDest(nil, false)
		center = here or Vector3.new(100, 0, 200)
		setScale(0.2)
	end
	if focusId then
		selectDest(DestinationConfig.get(focusId), true)
	end
	update()
end

function MapUiController.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	dragging = false
	playerArrow.Visible = false
	homeMarker.set(nil)
	taskMarker.set(nil)
	local MinimapController = require(script.Parent:WaitForChild("MinimapController")) :: any
	MinimapController.setVisible(true)
	MinimapController.reclaim()
end

function MapUiController.init()
	buildGui()
end

function MapUiController.start()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	NavController.onChanged(function()
		if isOpen then
			refreshCard()
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			update()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			if isOpen then
				MapUiController.close()
			else
				MapUiController.open()
			end
		end
	end)
end

return MapUiController
