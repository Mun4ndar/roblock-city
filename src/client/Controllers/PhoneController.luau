--!strict
-- PhoneController: HP pemain (tombol di tepi kanan).
--   * Peta  : peta skema pulau + daftar tempat; ketuk tempat untuk memasang GPS
--   * Misi  : misi harian, kemajuan, dan tombol ambil hadiah
--   * GPS   : panah arah + jarak + tiang cahaya di tujuan (hanya di layar sendiri)
-- Kemajuan misi dan hadiah dihitung server (MissionService); di sini hanya tampilan.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local HouseUiController = require(script.Parent:WaitForChild("HouseUiController"))

type Destination = { name: string, icon: string, position: Vector3 }

local player = Players.LocalPlayer

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local PhoneController = {}

local rgb = Color3.fromRGB
local COLORS = {
	body = rgb(34, 38, 50),
	screen = rgb(246, 248, 252),
	card = rgb(232, 237, 245),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(90, 120, 235),
	done = rgb(64, 190, 100),
	buy = rgb(255, 184, 0),
	sea = rgb(126, 196, 240),
	land = rgb(140, 206, 128),
	sand = rgb(240, 222, 160),
	gps = rgb(40, 200, 190),
}

-- Daratan di peta skema (stud): pulau utama, bandara, pulau pantai.
local LAND = {
	{ x0 = -620, x1 = 1010, z0 = -1160, z1 = 1120, color = COLORS.land },
	{ x0 = -1120, x1 = -620, z0 = 420, z1 = 800, color = COLORS.land },
	{ x0 = 1690, x1 = 2240, z0 = -660, z1 = 780, color = COLORS.sand },
}
local MAP_WIDTH = 258
local ARRIVE_DISTANCE = 28
local UPDATE_SECONDS = 0.1

local gui: ScreenGui
local phoneButton: TextButton
local badge: Frame
local phone: Frame
local scale: UIScale
local clockLabel: TextLabel
local pages: { [string]: Frame } = {}
local tabs: { [string]: TextButton } = {}
local mapFrame: Frame
local playerDot: Frame
local homeDot: TextLabel
local gpsDot: Frame
local placeList: ScrollingFrame
local missionList: ScrollingFrame
local gpsPill: TextButton
local gpsArrow: Frame
local gpsText: TextLabel

local destination: Destination? = nil
local beam: Part? = nil
local busy = false
local distanceLabels: { [TextLabel]: Vector3 } = {}

-- ---------------------------------------------------------------- util

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = 13
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
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	return b
end

local function rootPart(): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

-- Posisi dunia -> posisi (0..1) di peta.
local function toMap(position: Vector3): UDim2
	local b = MissionConfig.MAP_BOUNDS
	return UDim2.fromScale(
		math.clamp((position.X - b.minX) / (b.maxX - b.minX), 0, 1),
		math.clamp((position.Z - b.minZ) / (b.maxZ - b.minZ), 0, 1)
	)
end

local function distanceText(studs: number): string
	if studs >= 1000 then
		return string.format("%.1f km", studs / 1000)
	end
	return tostring(math.floor(studs)) .. " m"
end

local function getMissions(): MissionConfig.MissionView
	local raw = player:GetAttribute(MissionConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" and type(value.day) == "number" then
			value.progress = if type(value.progress) == "table" then value.progress else {}
			value.claimed = if type(value.claimed) == "table" then value.claimed else {}
			return value
		end
	end
	return { day = MissionConfig.dayNumber(os.time()), progress = {}, claimed = {} }
end

-- ---------------------------------------------------------------- GPS

local function clearGps()
	destination = nil
	if beam then
		beam:Destroy()
		beam = nil
	end
	gpsPill.Visible = false
	gpsDot.Visible = false
end

local function setGps(target: Destination)
	clearGps()
	destination = target
	local part = Instance.new("Part")
	part.Name = "GpsBeam"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(400, 3, 3)
	part.CFrame = CFrame.new(target.position + Vector3.new(0, 200, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	part.Material = Enum.Material.Neon
	part.Color = COLORS.gps
	part.Transparency = 0.45
	part.Parent = Workspace
	beam = part
	gpsText.Text = target.icon .. " " .. target.name
	gpsPill.Visible = true
	gpsDot.Position = toMap(target.position)
	gpsDot.Visible = true
	HudController.toast("GPS menuju " .. target.name .. ". Ikuti panah dan tiang cahaya!")
end

local function updateGps(root: BasePart)
	local target = destination
	if target == nil then
		return
	end
	local offset = target.position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude <= ARRIVE_DISTANCE then
		HudController.toast("Kamu sudah sampai di " .. target.name .. "!")
		clearGps()
		return
	end
	gpsText.Text = `{target.icon} {target.name}\n{distanceText(flat.Magnitude)}`
	local camera = Workspace.CurrentCamera
	if camera then
		local relative = camera.CFrame:VectorToObjectSpace(flat)
		gpsArrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
	end
end

-- ---------------------------------------------------------------- halaman Peta

local function destinations(): { Destination }
	local list: { Destination } = {}
	local home = HouseUiController.getHomePosition()
	if home then
		table.insert(list, { name = "Rumahku", icon = "🏠", position = home })
	end
	for _, landmark in MissionConfig.LANDMARKS do
		local position = MissionConfig.placePosition(landmark.place)
		if position then
			table.insert(list, {
				name = MissionConfig.placeName(landmark.place),
				icon = landmark.icon,
				position = position,
			})
		end
	end
	for _, extra in MissionConfig.EXTRA_PLACES do
		table.insert(list, { name = extra.name, icon = extra.icon, position = extra.position })
	end
	return list
end

local function refreshPlaces()
	for _, child in placeList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in mapFrame:GetChildren() do
		if child.Name == "Pin" then
			child:Destroy()
		end
	end
	table.clear(distanceLabels)
	for order, target in destinations() do
		local pin = label({
			Name = "Pin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(target.position),
			Size = UDim2.fromOffset(14, 14),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = target.icon,
			ZIndex = 2,
		})
		pin.Parent = mapFrame

		local rowButton = button({
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 32),
			BackgroundColor3 = COLORS.card,
			Text = "",
		})
		corner(rowButton, 8)
		label({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -78, 1, 0),
			Text = target.icon .. "  " .. target.name,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent =
			rowButton
		local distance = label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0, 64, 1, 0),
			TextColor3 = COLORS.subtle,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "",
		})
		distance.Parent = rowButton
		distanceLabels[distance] = target.position
		rowButton.Parent = placeList
		rowButton.Activated:Connect(function()
			setGps(target)
			phone.Visible = false -- supaya panah GPS dan tiang cahaya langsung terlihat
		end)
	end
	local home = HouseUiController.getHomePosition()
	homeDot.Visible = home ~= nil
	if home then
		homeDot.Position = toMap(home)
	end
end

local function updateMap(root: BasePart)
	playerDot.Position = toMap(root.Position)
	local look = root.CFrame.LookVector
	playerDot.Rotation = math.deg(math.atan2(look.X, -look.Z))
	for distance, position in distanceLabels do
		local offset = position - root.Position
		distance.Text = distanceText(Vector3.new(offset.X, 0, offset.Z).Magnitude)
	end
end

-- ---------------------------------------------------------------- halaman Misi

local function claim(missionId: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.MissionClaim):InvokeServer(missionId)
	end)
	HudController.toast(
		if ok
				and type(value) == "table"
				and type(value.message) == "string"
			then value.message
			else "Gagal terhubung, coba lagi."
	)
	busy = false
end

local function refreshMissions()
	for _, child in missionList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local view = getMissions()
	local claimable = false
	for order, def in MissionConfig.forDay(view.day) do
		local progress = math.min(view.progress[def.id] or 0, def.target)
		local complete = progress >= def.target
		local claimed = view.claimed[def.id] == true
		claimable = claimable or (complete and not claimed)

		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.Size = UDim2.new(1, -6, 0, 74)
		card.BackgroundColor3 = COLORS.card
		corner(card, 10)
		label({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 32),
			Font = Enum.Font.GothamBold,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = def.icon .. " " .. def.title,
		}).Parent =
			card
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(10, 46)
		bar.Size = UDim2.new(1, -110, 0, 10)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		corner(bar, 5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(progress / def.target, 1)
		fill.BackgroundColor3 = if complete then COLORS.done else COLORS.accent
		fill.BorderSizePixel = 0
		corner(fill, 5)
		fill.Parent = bar
		bar.Parent = card
		label({
			Position = UDim2.fromOffset(10, 56),
			Size = UDim2.new(1, -110, 0, 14),
			TextColor3 = COLORS.subtle,
			TextSize = 11,
			Text = if def.kind == "earn"
				then `{Format.money(progress)} / {Format.money(def.target)}`
				else `{progress} / {def.target}`,
		}).Parent =
			card
		local action = button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.fromOffset(84, 30),
			TextSize = 13,
			Text = if claimed
				then "Selesai"
				elseif complete then "Ambil"
				else Format.money(def.reward),
			BackgroundColor3 = if claimed
				then COLORS.done
				elseif complete then COLORS.buy
				else Color3.new(1, 1, 1),
			TextColor3 = if claimed then Color3.new(1, 1, 1) else COLORS.text,
			AutoButtonColor = complete and not claimed,
		})
		corner(action, 8)
		action.Parent = card
		if complete and not claimed then
			action.Activated:Connect(function()
				claim(def.id)
			end)
		end
		card.Parent = missionList
	end
	badge.Visible = claimable
end

-- ---------------------------------------------------------------- builder UI

local function showPage(name: string)
	for pageName, page in pages do
		page.Visible = pageName == name
		tabs[pageName].BackgroundColor3 = if pageName == name then COLORS.accent else COLORS.card
		tabs[pageName].TextColor3 = if pageName == name then Color3.new(1, 1, 1) else COLORS.text
	end
	if name == "Peta" then
		refreshPlaces()
	else
		refreshMissions()
	end
end

local function buildArrow(parent: Instance, color: Color3, size: number): Frame
	local arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(size, size)
	arrow.BackgroundTransparency = 1
	local k = size / 28
	for _, bar in { { 14, 15, 22, 0 }, { 9, 9, 14, 40 }, { 19, 9, 14, -40 } } do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(bar[1] * k, bar[2] * k)
		frame.Size = UDim2.fromOffset(math.max(3, 4 * k), bar[3] * k)
		frame.Rotation = bar[4]
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		corner(frame, 2)
		frame.Parent = arrow
	end
	arrow.Parent = parent
	return arrow
end

local function buildList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = parent
	return list
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6

	-- Tombol HP di tepi kanan (kanan bawah = tombol lompat di HP sungguhan).
	phoneButton = button({
		Name = "OpenPhone",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = COLORS.body,
		TextSize = 26,
		Text = "📱",
	})
	corner(phoneButton, 16)
	UiScale.attach(phoneButton)
	phoneButton.Parent = gui
	badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -4)
	badge.Size = UDim2.fromOffset(16, 16)
	badge.BackgroundColor3 = rgb(235, 70, 70)
	badge.Visible = false
	corner(badge, 8)
	badge.Parent = phoneButton

	gpsPill = button({
		Name = "Gps",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 58),
		Size = UDim2.fromOffset(176, 44),
		BackgroundColor3 = COLORS.body,
		Text = "",
		Visible = false,
	})
	corner(gpsPill, 12)
	UiScale.attach(gpsPill)
	UiScale.onChange(function(value: number)
		gpsPill.Position = UDim2.new(1, -10, 0.42, 58 * value)
	end)
	gpsPill.Parent = gui
	gpsArrow = buildArrow(gpsPill, COLORS.gps, 28)
	gpsArrow.Position = UDim2.new(0, 22, 0.5, 0)
	gpsText = label({
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	gpsText.Parent = gpsPill

	phone = Instance.new("Frame")
	phone.Name = "Phone"
	phone.AnchorPoint = Vector2.new(1, 0.5)
	phone.Position = UDim2.new(1, -72, 0.5, 0)
	phone.Size = UDim2.fromOffset(290, 500)
	phone.BackgroundColor3 = COLORS.body
	phone.Visible = false
	corner(phone, 28)
	scale = Instance.new("UIScale")
	scale.Parent = phone
	phone.Parent = gui

	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.Position = UDim2.fromOffset(8, 8)
	screen.Size = UDim2.new(1, -16, 1, -16)
	screen.BackgroundColor3 = COLORS.screen
	corner(screen, 22)
	screen.Parent = phone

	clockLabel = label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(120, 22),
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Text = "08:00",
	})
	clockLabel.Parent = screen
	local close = button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = rgb(235, 90, 90),
		Text = "X",
	})
	corner(close, 8)
	close.Parent = screen
	close.Activated:Connect(function()
		phone.Visible = false
	end)

	for index, name in { "Peta", "Misi" } do
		local page = Instance.new("Frame")
		page.Name = name
		page.Position = UDim2.fromOffset(8, 40)
		page.Size = UDim2.new(1, -16, 1, -92)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = screen
		pages[name] = page

		local tab = button({
			Name = "Tab" .. name,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((index - 1) * 0.5, if index == 1 then 8 else 4, 1, -8),
			Size = UDim2.new(0.5, -12, 0, 36),
			Text = if name == "Peta" then "🗺️ Peta" else "🎯 Misi",
		})
		corner(tab, 10)
		tab.Parent = screen
		tabs[name] = tab
		tab.Activated:Connect(function()
			showPage(name)
		end)
	end

	-- Peta skema
	local b = MissionConfig.MAP_BOUNDS
	local mapHeight = math.floor(MAP_WIDTH * (b.maxZ - b.minZ) / (b.maxX - b.minX))
	mapFrame = Instance.new("Frame")
	mapFrame.Name = "Map"
	mapFrame.Size = UDim2.fromOffset(MAP_WIDTH, mapHeight)
	mapFrame.BackgroundColor3 = COLORS.sea
	mapFrame.ClipsDescendants = true
	corner(mapFrame, 10)
	mapFrame.Parent = pages.Peta
	for _, land in LAND do
		local from = toMap(Vector3.new(land.x0, 0, land.z0))
		local to = toMap(Vector3.new(land.x1, 0, land.z1))
		local frame = Instance.new("Frame")
		frame.Name = "Land"
		frame.Position = from
		frame.Size = UDim2.fromScale(to.X.Scale - from.X.Scale, to.Y.Scale - from.Y.Scale)
		frame.BackgroundColor3 = land.color
		frame.BorderSizePixel = 0
		corner(frame, 8)
		frame.Parent = mapFrame
	end
	gpsDot = Instance.new("Frame")
	gpsDot.Name = "GpsDot"
	gpsDot.AnchorPoint = Vector2.new(0.5, 0.5)
	gpsDot.Size = UDim2.fromOffset(18, 18)
	gpsDot.BackgroundColor3 = COLORS.gps
	gpsDot.BackgroundTransparency = 0.35
	gpsDot.Visible = false
	corner(gpsDot, 9)
	gpsDot.Parent = mapFrame
	homeDot = label({
		Name = "Home",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🏠",
		Visible = false,
		ZIndex = 3,
	})
	homeDot.Parent = mapFrame
	playerDot = buildArrow(mapFrame, rgb(230, 60, 60), 18)
	playerDot.Name = "Player"
	playerDot.ZIndex = 4

	placeList = buildList(
		pages.Peta,
		UDim2.fromOffset(0, mapHeight + 8),
		UDim2.new(1, 0, 1, -mapHeight - 8)
	)
	placeList.Name = "Places"

	label({
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = COLORS.subtle,
		TextSize = 12,
		TextWrapped = true,
		Text = "Misi berganti setiap hari. Selesaikan, lalu ambil hadiahnya di sini.",
	}).Parent =
		pages.Misi
	missionList = buildList(pages.Misi, UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36))
	missionList.Name = "Missions"

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.Y / 540, 0.55, 1)
	end
end

-- ---------------------------------------------------------------- bootstrap

-- Dipakai sistem lain untuk mengarahkan pemain (mis. tombol "Tunjukkan jalan").
function PhoneController.setDestination(name: string, icon: string, position: Vector3)
	setGps({ name = name, icon = icon, position = position })
end

function PhoneController.init()
	buildGui()
end

function PhoneController.start()
	phoneButton.Activated:Connect(function()
		phone.Visible = not phone.Visible
		if phone.Visible then
			showPage(if badge.Visible then "Misi" else "Peta")
		end
	end)
	gpsPill.Activated:Connect(function()
		clearGps()
		HudController.toast("GPS dimatikan.")
	end)
	player:GetAttributeChangedSignal(MissionConfig.ATTR_PLAYER):Connect(refreshMissions)
	refreshMissions()

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	while true do
		task.wait(UPDATE_SECONDS)
		local root = rootPart()
		if root then
			updateGps(root)
			if phone.Visible then
				clockLabel.Text = DayNightConfig.formatClock(Lighting.ClockTime)
				if pages.Peta.Visible then
					updateMap(root)
				end
			end
		end
	end
end

return PhoneController
