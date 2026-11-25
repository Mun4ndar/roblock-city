--!strict
-- PhoneController: HP pemain (tombol di tepi kanan).
--   * Peta  : tombol Peta Penuh + daftar semua tujuan (ketuk = GPS lewat jalan), lihat NavController
--   * Misi  : misi harian, kemajuan, dan tombol ambil hadiah
--   * Menu  : pintasan aplikasi (Garasi, Rumahku, Hewan, ...)
-- Kartu GPS di bawah tombol HP menunjukkan arah belok berikutnya, sisa jarak, dan perkiraan waktu.
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
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local HouseUiController = require(script.Parent:WaitForChild("HouseUiController"))
local NavController = require(script.Parent:WaitForChild("NavController"))

local player = Players.LocalPlayer

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local PhoneController = {}

local rgb = Color3.fromRGB
local COLORS = {
	body = rgb(24, 30, 54),
	screen = rgb(246, 248, 252),
	card = rgb(232, 237, 245),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(90, 120, 235),
	done = rgb(64, 190, 100),
	buy = rgb(255, 184, 0),
	gps = rgb(46, 150, 255),
	stop = rgb(235, 80, 90),
}
local UPDATE_SECONDS = 0.1

local gui: ScreenGui
local phoneButton: TextButton
local badge: Frame
local phone: Frame
local scale: UIScale
local clockLabel: TextLabel
local pages: { [string]: Frame } = {}
local tabs: { [string]: TextButton } = {}
local placeList: ScrollingFrame
local searchBox: TextBox
local missionList: ScrollingFrame
local gpsCard: TextButton
local gpsArrow: Frame
local gpsName: TextLabel
local gpsInfo: TextLabel

local busy = false
local distanceLabels: { [TextLabel]: Vector3 } = {}

-- ---------------------------------------------------------------- util

local function corner(parent: Instance, radius: number)
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

local function openMap(focusId: string?)
	phone.Visible = false
	local MapUi = require(script.Parent:WaitForChild("MapUiController")) :: any
	MapUi.open(focusId)
end

-- ---------------------------------------------------------------- kartu GPS

local function refreshGpsCard()
	local target = NavController.getTarget()
	gpsCard.Visible = target ~= nil
	if target == nil then
		return
	end
	gpsName.Text = target.icon .. " " .. target.name
	local remaining = NavController.getRemaining()
	gpsInfo.Text = NavController.formatDistance(remaining)
		.. "  ·  "
		.. NavController.formatEta(NavController.getEta())
	local heading = NavController.getHeading()
	local camera = Workspace.CurrentCamera
	if heading and camera then
		local relative = camera.CFrame:VectorToObjectSpace(heading)
		gpsArrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
	end
end

-- ---------------------------------------------------------------- halaman Peta

local function allDestinations(): { DestinationConfig.Destination }
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
	local root = rootPart()
	if root then
		table.sort(result, function(a, b)
			local da = (a.position - root.Position) * Vector3.new(1, 0, 1)
			local db = (b.position - root.Position) * Vector3.new(1, 0, 1)
			return da.Magnitude < db.Magnitude
		end)
	end
	return result
end

local function refreshPlaces()
	for _, child in placeList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(distanceLabels)
	local query = string.lower(searchBox.Text)
	local order = 0
	for _, dest in allDestinations() do
		if query == "" or string.find(string.lower(dest.name), query, 1, true) then
			order += 1
			local zone = DestinationConfig.zone(dest.zone)
			local row = button({
				Name = "Tujuan_" .. dest.id,
				LayoutOrder = order,
				Size = UDim2.new(1, -6, 0, 40),
				BackgroundColor3 = COLORS.card,
				Text = "",
			})
			corner(row, 10)
			local badgeLabel = label({
				Position = UDim2.fromOffset(5, 5),
				Size = UDim2.fromOffset(30, 30),
				BackgroundTransparency = 0,
				BackgroundColor3 = zone.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 16,
				Text = dest.icon,
			})
			corner(badgeLabel, 15)
			badgeLabel.Parent = row
			label({
				Position = UDim2.fromOffset(42, 0),
				Size = UDim2.new(1, -108, 1, 0),
				Font = Enum.Font.GothamBold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = dest.name,
			}).Parent =
				row
			local distance = label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.new(0, 60, 1, 0),
				TextColor3 = COLORS.subtle,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "",
			})
			distance.Parent = row
			distanceLabels[distance] = dest.position
			row.Parent = placeList
			row.Activated:Connect(function()
				phone.Visible = false -- supaya panah dan jalur GPS langsung terlihat
				NavController.setTarget({
					id = dest.id,
					name = dest.name,
					icon = dest.icon,
					position = dest.position,
					arrive = dest.arrive,
				})
			end)
		end
	end
end

local function updateDistances(root: BasePart)
	for distance, position in distanceLabels do
		local offset = position - root.Position
		distance.Text = NavController.formatDistance(Vector3.new(offset.X, 0, offset.Z).Magnitude)
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

-- ---------------------------------------------------------------- halaman Menu (aplikasi)

-- Pintasan ke menu lain (termasuk Toko Koin, lihat ShopController). Aplikasi didaftarkan controller lain lewat
-- PhoneController.addApp, jadi HP tidak perlu mengenal mereka satu per satu.
local apps: { { icon: string, name: string, open: () -> () } } = {}

local function refreshMenu()
	local page = pages.Menu
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local grid = page:FindFirstChildOfClass("UIGridLayout")
	if grid == nil then
		local created = Instance.new("UIGridLayout")
		created.CellSize = UDim2.new(0.5, -4, 0, 58)
		created.CellPadding = UDim2.fromOffset(8, 8)
		created.SortOrder = Enum.SortOrder.LayoutOrder
		created.Parent = page
	end
	for order, app in apps do
		local b = button({
			Name = "App" .. order,
			LayoutOrder = order,
			BackgroundColor3 = COLORS.card,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Text = app.icon .. "\n" .. app.name,
		})
		corner(b, 12)
		b.Parent = page
		b.Activated:Connect(function()
			phone.Visible = false
			app.open()
		end)
	end
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
	elseif name == "Misi" then
		refreshMissions()
	else
		refreshMenu()
	end
end

-- Panah arah: dua batang membentuk kepala panah + batang tengah (dipakai di kartu GPS).
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

-- Ikon tombol HP: ponsel putih mungil dengan layar gelap dan empat ikon aplikasi warna-warni.
local function buildPhoneIcon(parent: GuiObject)
	local body = Instance.new("Frame")
	body.Name = "Ponsel"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(24, 38)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.Rotation = 8
	body.ZIndex = 3
	corner(body, 7)
	body.Parent = parent
	local screen = Instance.new("Frame")
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.52)
	screen.Size = UDim2.new(1, -6, 1, -12)
	screen.BackgroundColor3 = rgb(30, 36, 74)
	screen.BorderSizePixel = 0
	screen.ZIndex = 4
	corner(screen, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(70, 86, 170), rgb(28, 34, 70))
	gradient.Rotation = 90
	gradient.Parent = screen
	screen.Parent = body
	local notch = Instance.new("Frame")
	notch.AnchorPoint = Vector2.new(0.5, 0)
	notch.Position = UDim2.new(0.5, 0, 0, 2)
	notch.Size = UDim2.fromOffset(8, 2)
	notch.BackgroundColor3 = rgb(190, 196, 215)
	notch.BorderSizePixel = 0
	notch.ZIndex = 4
	corner(notch, 1)
	notch.Parent = body
	local colors = { rgb(255, 99, 132), rgb(255, 205, 86), rgb(80, 220, 150), rgb(70, 190, 255) }
	for i, color in colors do
		local app = Instance.new("Frame")
		app.Position = UDim2.fromOffset(2 + ((i - 1) % 2) * 9, 3 + ((i - 1) // 2) * 9)
		app.Size = UDim2.fromOffset(7, 7)
		app.BackgroundColor3 = color
		app.BorderSizePixel = 0
		app.ZIndex = 5
		corner(app, 2)
		app.Parent = screen
	end
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
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
	})
	corner(phoneButton, 20)
	local buttonGradient = Instance.new("UIGradient")
	buttonGradient.Color = ColorSequence.new(rgb(86, 132, 255), rgb(150, 90, 255))
	buttonGradient.Rotation = 55
	buttonGradient.Parent = phoneButton
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.new(1, 1, 1)
	buttonStroke.Thickness = 2.5
	buttonStroke.Transparency = 0.25
	buttonStroke.Parent = phoneButton
	local shadow = Instance.new("Frame")
	shadow.Name = "Bayangan"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	corner(shadow, 20)
	shadow.Parent = phoneButton
	buildPhoneIcon(phoneButton)
	UiScale.attach(phoneButton)
	phoneButton.Parent = gui
	badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 5, 0, -5)
	badge.Size = UDim2.fromOffset(18, 18)
	badge.BackgroundColor3 = rgb(255, 64, 90)
	badge.Visible = false
	badge.ZIndex = 10
	corner(badge, 9)
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.new(1, 1, 1)
	badgeStroke.Thickness = 2
	badgeStroke.Parent = badge
	badge.Parent = phoneButton

	-- Kartu GPS: panah arah belok, nama tujuan, sisa jarak dan waktu. Ketuk = peta penuh.
	gpsCard = button({
		Name = "Gps",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 66),
		Size = UDim2.fromOffset(204, 56),
		BackgroundColor3 = COLORS.body,
		Text = "",
		Visible = false,
	})
	corner(gpsCard, 18)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.gps
	cardStroke.Thickness = 2
	cardStroke.Parent = gpsCard
	UiScale.attach(gpsCard)
	UiScale.onChange(function(value: number)
		gpsCard.Position = UDim2.new(1, -10, 0.42, 66 * value)
	end)
	gpsCard.Parent = gui
	local arrowBadge = Instance.new("Frame")
	arrowBadge.Position = UDim2.fromOffset(8, 8)
	arrowBadge.Size = UDim2.fromOffset(40, 40)
	arrowBadge.BackgroundColor3 = COLORS.gps
	arrowBadge.BorderSizePixel = 0
	corner(arrowBadge, 20)
	arrowBadge.Parent = gpsCard
	gpsArrow = buildArrow(arrowBadge, Color3.new(1, 1, 1), 26)
	gpsArrow.Position = UDim2.fromScale(0.5, 0.5)
	gpsName = label({
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -92, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	gpsName.Parent = gpsCard
	gpsInfo = label({
		Position = UDim2.fromOffset(56, 29),
		Size = UDim2.new(1, -92, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = rgb(150, 205, 255),
		Text = "",
	})
	gpsInfo.Parent = gpsCard
	local stop = button({
		Name = "HentikanGps",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = COLORS.stop,
		TextSize = 14,
		Text = "X",
	})
	corner(stop, 14)
	stop.Parent = gpsCard
	stop.Activated:Connect(function()
		NavController.clear()
		HudController.toast("GPS dimatikan.")
	end)
	gpsCard.Activated:Connect(function()
		openMap(nil)
	end)

	phone = Instance.new("Frame")
	phone.Name = "Phone"
	phone.AnchorPoint = Vector2.new(1, 0.5)
	phone.Position = UDim2.new(1, -78, 0.5, 0)
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

	for index, name in { "Peta", "Misi", "Menu" } do
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
			Position = UDim2.new((index - 1) / 3, 6, 1, -8),
			Size = UDim2.new(1 / 3, -10, 0, 36),
			TextSize = 13,
			Text = if name == "Peta"
				then "🗺️ Peta"
				elseif name == "Misi" then "🎯 Misi"
				else "📲 Menu",
		})
		corner(tab, 10)
		tab.Parent = screen
		tabs[name] = tab
		tab.Activated:Connect(function()
			showPage(name)
		end)
	end

	-- Halaman Peta: tombol peta penuh, kotak cari, daftar tujuan
	local open = button({
		Name = "BukaPetaPenuh",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		Text = "🗺️ Buka Peta Penuh",
	})
	corner(open, 12)
	open.Parent = pages.Peta
	open.Activated:Connect(function()
		openMap(nil)
	end)
	searchBox = Instance.new("TextBox")
	searchBox.Name = "Cari"
	searchBox.Position = UDim2.fromOffset(0, 46)
	searchBox.Size = UDim2.new(1, 0, 0, 32)
	searchBox.BackgroundColor3 = COLORS.card
	searchBox.PlaceholderText = "🔍  Cari tempat..."
	searchBox.PlaceholderColor3 = COLORS.subtle
	searchBox.Text = ""
	searchBox.TextColor3 = COLORS.text
	searchBox.Font = Enum.Font.GothamMedium
	searchBox.TextSize = 13
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	corner(searchBox, 16)
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 12)
	searchPad.Parent = searchBox
	searchBox.Parent = pages.Peta
	searchBox:GetPropertyChangedSignal("Text"):Connect(refreshPlaces)
	placeList = buildList(pages.Peta, UDim2.fromOffset(0, 84), UDim2.new(1, 0, 1, -84))
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
	NavController.setDestination(name, icon, position)
end

-- Tujuan GPS yang sedang aktif (untuk peta kecil lama), atau nil.
function PhoneController.getGpsTarget(): Vector3?
	return NavController.getTargetPosition()
end

-- Daftarkan pintasan di halaman Menu HP (dipanggil controller lain saat start()).
function PhoneController.addApp(icon: string, name: string, open: () -> ())
	table.insert(apps, { icon = icon, name = name, open = open })
end

function PhoneController.init()
	buildGui()
end

function PhoneController.start()
	PhoneController.addApp("🏠", "Rumahku", HouseUiController.open)
	PhoneController.addApp("🗺️", "Peta", function()
		openMap(nil)
	end)
	phoneButton.Activated:Connect(function()
		phone.Visible = not phone.Visible
		if phone.Visible then
			showPage(if badge.Visible then "Misi" else "Peta")
		end
	end)
	player:GetAttributeChangedSignal(MissionConfig.ATTR_PLAYER):Connect(refreshMissions)
	refreshMissions()
	NavController.onChanged(refreshGpsCard)

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	while true do
		task.wait(UPDATE_SECONDS)
		local root = rootPart()
		if root then
			refreshGpsCard()
			if phone.Visible then
				clockLabel.Text = DayNightConfig.formatClock(Lighting.ClockTime)
				if pages.Peta.Visible then
					updateDistances(root)
				end
			end
		end
	end
end

return PhoneController
