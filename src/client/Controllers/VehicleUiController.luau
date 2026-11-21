--!strict
-- VehicleUiController: menu Kendaraan (garasi + dealer).
-- Client hanya MEMINTA beli/keluarkan dengan mengirim id kendaraan; server yang
-- memutuskan (harga, saldo, kepemilikan, jarak ke dealer, batas spawn).
-- Daftar kendaraan dibaca dari VehicleConfig, jadi kendaraan baru otomatis muncul.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Types"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

type VehicleDef = VehicleConfig.VehicleDef

type Card = {
	def: VehicleDef,
	frame: Frame,
	button: TextButton,
	confirmUntil: number,
}

local player = Players.LocalPlayer

local VehicleUiController = {}

local COLORS = {
	panel = Color3.fromRGB(255, 255, 255),
	card = Color3.fromRGB(240, 244, 250),
	text = Color3.fromRGB(40, 48, 60),
	subtle = Color3.fromRGB(110, 120, 135),
	buy = Color3.fromRGB(255, 184, 0),
	spawn = Color3.fromRGB(64, 190, 100),
	locked = Color3.fromRGB(200, 205, 214),
	close = Color3.fromRGB(235, 90, 90),
	store = Color3.fromRGB(90, 150, 235),
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local openButton: TextButton
local scale: UIScale
local cards: { Card } = {}
local busy = false

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
	l.TextSize = 14
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function invoke(remoteName: string, arg: any?): Types.VehicleResult
	local ok, value = pcall(function(): any
		return Net.func(remoteName):InvokeServer(arg)
	end)
	if ok and type(value) == "table" and type(value.message) == "string" then
		return value
	end
	return { ok = false, message = "Gagal terhubung, coba lagi." }
end

-- ---------------------------------------------------------------- tampilan

local function refresh()
	local owned = VehicleConfig.parseOwned(player:GetAttribute(VehicleConfig.ATTR_OWNED))
	local money = player:GetAttribute("Money")
	local now = os.clock()
	for _, card in cards do
		local def = card.def
		local button = card.button
		if owned[def.id] then
			button.Text = "Keluarkan"
			button.BackgroundColor3 = COLORS.spawn
			button.TextColor3 = Color3.new(1, 1, 1)
		elseif card.confirmUntil > now then
			button.Text = "Yakin beli?"
			button.BackgroundColor3 = COLORS.buy
			button.TextColor3 = COLORS.text
		else
			button.Text = "Beli " .. Format.money(def.price)
			local affordable = type(money) == "number" and money >= def.price
			button.BackgroundColor3 = if affordable then COLORS.buy else COLORS.locked
			button.TextColor3 = COLORS.text
		end
	end
end

local function setOpen(open: boolean, dealer: boolean?)
	panel.Visible = open
	if open then
		titleLabel.Text = if dealer then "Dealer Mobil ROBLOCK" else "Kendaraanku"
		for _, card in cards do
			card.confirmUntil = 0
		end
		refresh()
	end
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 500, size.Y / 470), 0.55, 1)
	end
end

-- ---------------------------------------------------------------- aksi

local function onCardClicked(card: Card)
	if busy then
		return
	end
	local def = card.def
	local owned = VehicleConfig.parseOwned(player:GetAttribute(VehicleConfig.ATTR_OWNED))
	if owned[def.id] then
		busy = true
		local res = invoke(Net.Names.VehicleSpawn, def.id)
		HudController.toast(res.message)
		if res.ok then
			setOpen(false)
		end
		busy = false
		return
	end
	-- Beli: klik pertama minta konfirmasi, klik kedua baru membeli.
	if card.confirmUntil <= os.clock() then
		card.confirmUntil = os.clock() + 4
		refresh()
		task.delay(4.1, refresh)
		return
	end
	card.confirmUntil = 0
	busy = true
	local res = invoke(Net.Names.VehicleBuy, def.id)
	HudController.toast(res.message)
	refresh()
	busy = false
end

local function onStoreClicked()
	if busy then
		return
	end
	busy = true
	local res = invoke(Net.Names.VehicleDespawn)
	HudController.toast(res.message)
	busy = false
end

-- ---------------------------------------------------------------- builder UI

local function buildCard(def: VehicleDef, order: number, parent: Instance): Card
	local frame = Instance.new("Frame")
	frame.Name = def.id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, 92)
	frame.BackgroundColor3 = COLORS.card
	corner(frame, 12)

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Position = UDim2.fromOffset(10, 14)
	swatch.Size = UDim2.fromOffset(64, 64)
	swatch.BackgroundColor3 = def.color
	corner(swatch, 14)
	swatch.Parent = frame
	local icon = label({
		Size = UDim2.fromScale(1, 1),
		Text = "🚗",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	icon.Parent = swatch

	label({
		Name = "Name",
		Position = UDim2.fromOffset(86, 8),
		Size = UDim2.new(1, -230, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		Text = def.name,
	}).Parent =
		frame
	label({
		Name = "Stats",
		Position = UDim2.fromOffset(86, 32),
		Size = UDim2.new(1, -230, 0, 18),
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		Text = `{def.class} · {def.maxSpeed} km/j · {def.seats} kursi`,
	}).Parent =
		frame
	label({
		Name = "Description",
		Position = UDim2.fromOffset(86, 50),
		Size = UDim2.new(1, -230, 0, 36),
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = def.description,
	}).Parent =
		frame

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(126, 44)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 18
	button.Text = ""
	button.AutoButtonColor = true
	corner(button, 12)
	button.Parent = frame

	frame.Parent = parent
	local card: Card = { def = def, frame = frame, button = button, confirmUntil = 0 }
	button.Activated:Connect(function()
		onCardClicked(card)
	end)
	return card
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "VehicleMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	-- Tombol pembuka di tepi kiri (kiri atas = chat, kiri bawah = thumbstick HP).
	openButton = Instance.new("TextButton")
	openButton.Name = "OpenVehicles"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 10, 0.42, 0)
	openButton.Size = UDim2.fromOffset(132, 42)
	openButton.BackgroundColor3 = COLORS.store
	openButton.Font = Enum.Font.FredokaOne
	openButton.TextSize = 18
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Text = "🚗 Kendaraan"
	corner(openButton, 12)
	openButton.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(470, 430)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.store
	stroke.Parent = panel
	scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	titleLabel = label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		Text = "Kendaraanku",
	})
	titleLabel.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundColor3 = COLORS.close
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 10)
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(14, 56)
	list.Size = UDim2.new(1, -28, 1, -122)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = panel

	for order, def in VehicleConfig.LIST do
		table.insert(cards, buildCard(def, order, list))
	end

	local store = Instance.new("TextButton")
	store.Name = "Store"
	store.AnchorPoint = Vector2.new(0, 1)
	store.Position = UDim2.new(0, 14, 1, -12)
	store.Size = UDim2.fromOffset(210, 42)
	store.BackgroundColor3 = COLORS.store
	store.Font = Enum.Font.FredokaOne
	store.TextSize = 17
	store.TextColor3 = Color3.new(1, 1, 1)
	store.Text = "Simpan mobil ke garasi"
	corner(store, 12)
	store.Parent = panel
	store.Activated:Connect(onStoreClicked)

	label({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(210, 42),
		TextColor3 = COLORS.subtle,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Mobil baru dibeli di Dealer Mobil, di seberang taman kota.",
	}).Parent =
		panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- ---------------------------------------------------------------- bootstrap

function VehicleUiController.init()
	buildGui()
end

function VehicleUiController.start()
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible, false)
	end)
	player:GetAttributeChangedSignal(VehicleConfig.ATTR_OWNED):Connect(refresh)
	player:GetAttributeChangedSignal("Money"):Connect(refresh)

	-- Mobil pajangan di dealer membuka menu ini.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(VehicleConfig.ATTR_DEALER_PROMPT) ~= nil then
			setOpen(true, true)
		end
	end)

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	refresh()
end

return VehicleUiController
