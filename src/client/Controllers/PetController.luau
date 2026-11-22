--!strict
-- PetController: panel Toko Hewan (beli, ajak, beri makan). Terbuka dari tombol di Toko Hewan
-- atau dari tombol kecil di tepi kanan layar kalau sudah punya hewan.
-- Semua aksi lewat remote PetAction; harga dan kepemilikan dicek PetService.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local PetConfig = require(Shared:WaitForChild("PetConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer

local PetController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(250, 240, 246),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(236, 110, 160),
	buy = rgb(255, 184, 0),
	locked = rgb(200, 205, 214),
	go = rgb(64, 190, 100),
	close = rgb(235, 90, 90),
}

local gui: ScreenGui
local panel: Frame
local body: ScrollingFrame
local openButton: TextButton
local scale: UIScale
local busy = false
local refresh: () -> ()

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = 14
	l.TextWrapped = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	b.Parent = parent
	return b
end

local function getView(): PetConfig.PetView
	local raw = player:GetAttribute(PetConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" then
			return {
				owned = if type(value.owned) == "table" then value.owned else {},
				active = if type(value.active) == "string" then value.active else "",
				fedAt = tonumber(value.fedAt) or 0,
			}
		end
	end
	return { owned = {}, active = "", fedAt = 0 }
end

local function call(action: string, petId: string?)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.PetAction):InvokeServer(action, petId)
	end)
	HudController.toast(
		if ok
				and type(value) == "table"
				and type(value.message) == "string"
			then value.message
			else "Gagal terhubung, coba lagi."
	)
	busy = false
	refresh()
end

function refresh()
	local view = getView()
	openButton.Visible = next(view.owned) ~= nil
	if not panel.Visible then
		return
	end
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local money = player:GetAttribute("Money")
	local active = PetConfig.get(view.active)
	if active then
		local happy = Workspace:GetServerTimeNow() - view.fedAt < PetConfig.HAPPY_SECONDS
		local row = Instance.new("Frame")
		row.LayoutOrder = 0
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundTransparency = 1
		row.Parent = body
		label(row, {
			Size = UDim2.new(1, -150, 1, 0),
			Text = `{active.icon} {active.name} sedang ikut kamu.\n{if happy
				then "Dia kenyang dan senang 😊"
				else "Dia lapar, beri makan yuk!"}`,
		})
		button(row, {
			Name = "Feed",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = COLORS.go,
			Text = "Beri makan " .. Format.money(PetConfig.FEED_PRICE),
		}).Activated:Connect(function()
			call("feed")
		end)
	end
	for order, pet in PetConfig.PETS do
		local owned = view.owned[pet.id] == true
		local row = Instance.new("Frame")
		row.Name = pet.id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = COLORS.card
		corner(row, 10)
		row.Parent = body
		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.fromOffset(8, 8)
		swatch.Size = UDim2.fromOffset(40, 40)
		swatch.BackgroundColor3 = pet.body
		corner(swatch, 12)
		swatch.Parent = row
		label(swatch, {
			Size = UDim2.fromScale(1, 1),
			Text = pet.icon,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		label(row, {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -200, 1, 0),
			Font = Enum.Font.FredokaOne,
			TextSize = 17,
			Text = pet.name,
		})
		local text, color, textColor = "", COLORS.buy, COLORS.text
		if owned and view.active == pet.id then
			text, color, textColor = "Istirahatkan", COLORS.locked, COLORS.text
		elseif owned then
			text, color, textColor = "Ajak jalan", COLORS.go, Color3.new(1, 1, 1)
		else
			text = "Beli " .. Format.money(pet.price)
			if not (type(money) == "number" and money >= pet.price) then
				color = COLORS.locked
			end
		end
		button(row, {
			Name = "Action",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(128, 40),
			BackgroundColor3 = color,
			TextColor3 = textColor,
			Text = text,
		}).Activated:Connect(function()
			if owned and view.active == pet.id then
				call("equip", "")
			elseif owned then
				call("equip", pet.id)
			else
				call("buy", pet.id)
			end
		end)
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PetMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	openButton = button(gui, {
		Name = "OpenPets",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, -58),
		Size = UDim2.fromOffset(52, 52),
		TextSize = 26,
		Text = "🐾",
		Visible = false,
	})
	corner(openButton, 16)
	UiScale.attach(openButton)
	UiScale.onChange(function(value: number)
		openButton.Position = UDim2.new(1, -10, 0.42, -58 * value)
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 420)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.accent
	stroke.Parent = panel
	scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	label(panel, {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		Text = "🐾 Hewan Peliharaan",
	})
	button(panel, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = COLORS.close,
		TextSize = 20,
		Text = "X",
	}).Activated:Connect(function()
		panel.Visible = false
	end)
	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(16, 54)
	body.Size = UDim2.new(1, -28, 1, -66)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	body.Parent = panel
	gui.Parent = player:WaitForChild("PlayerGui")
end

function PetController.init()
	buildGui()
end

function PetController.start()
	local PhoneController = require(script.Parent:WaitForChild("PhoneController")) :: any
	PhoneController.addApp("🐾", "Hewan", function()
		panel.Visible = true
		refresh()
	end)
	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(PetConfig.ATTR_PROMPT) then
			panel.Visible = true
			refresh()
		end
	end)
	player:GetAttributeChangedSignal(PetConfig.ATTR_PLAYER):Connect(refresh)
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 480, size.Y / 460), 0.55, 1)
		end
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	refresh()
end

return PetController
