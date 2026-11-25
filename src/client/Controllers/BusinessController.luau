--!strict
-- BusinessController: panel Kafe milik pemain (buka, naik tingkat, layani pelanggan, ambil hasil).
-- Terbuka dari tombol di kasir Kafe Kota atau dari HP. Semua aksi lewat remote BusinessAction;
-- harga, jarak, dan jeda dicek BusinessService.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local BusinessConfig = require(Shared:WaitForChild("BusinessConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer

local BusinessController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(250, 242, 230),
	text = rgb(60, 44, 32),
	soft = rgb(130, 112, 96),
	accent = rgb(150, 100, 70),
	buy = rgb(255, 184, 0),
	locked = rgb(200, 205, 214),
	go = rgb(64, 190, 100),
	close = rgb(235, 90, 90),
}

local gui: ScreenGui
local panel: Frame
local scale: UIScale
local title: TextLabel
local info: TextLabel
local drawer: TextLabel
local fill: Frame
local buyButton: TextButton
local collectButton: TextButton
local serveButton: TextButton
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
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	b.Parent = parent
	return b
end

local function getView(): BusinessConfig.BusinessView
	local raw = player:GetAttribute(BusinessConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" then
			return {
				level = if type(value.level) == "number" then value.level else 0,
				stored = if type(value.stored) == "number" then value.stored else 0,
			}
		end
	end
	return { level = 0, stored = 0 }
end

local function call(action: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.BusinessAction):InvokeServer(action)
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
	if not panel.Visible then
		return
	end
	local view = getView()
	local level = BusinessConfig.get(view.level)
	local nextLevel = BusinessConfig.get(view.level + 1)
	local money = player:GetAttribute("Money")
	if level then
		title.Text = "☕ " .. level.name .. " (tingkat " .. view.level .. ")"
		info.Text = "Pemasukan "
			.. Format.money(level.income)
			.. " per menit selama kamu bermain. Layani pelanggan untuk bonus "
			.. Format.money(level.serveBonus)
			.. "."
		drawer.Text = "Laci kasir: "
			.. Format.money(view.stored)
			.. " / "
			.. Format.money(level.capacity)
		fill.Size = UDim2.fromScale(math.clamp(view.stored / level.capacity, 0, 1), 1)
	else
		title.Text = "☕ Kafe Kota"
		info.Text = "Buka kafemu sendiri! Kafe menghasilkan uang tiap menit selama kamu bermain, "
			.. "dan kamu bisa melayani pelanggan untuk bonus."
		drawer.Text = "Kamu belum punya kafe."
		fill.Size = UDim2.fromScale(0, 1)
	end
	collectButton.Visible = level ~= nil
	serveButton.Visible = level ~= nil
	collectButton.BackgroundColor3 = if view.stored > 0 then COLORS.go else COLORS.locked
	if nextLevel then
		local canPay = type(money) == "number" and money >= nextLevel.price
		buyButton.Visible = true
		buyButton.BackgroundColor3 = if canPay then COLORS.buy else COLORS.locked
		buyButton.Text = (if level then "Naik ke " else "Buka ")
			.. nextLevel.name
			.. "  "
			.. Format.money(nextLevel.price)
	else
		buyButton.Visible = false
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "BusinessMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 330)
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
	title = label(panel, {
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 24,
		Text = "☕ Kafe Kota",
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
	info = label(panel, {
		Name = "Info",
		Position = UDim2.fromOffset(18, 52),
		Size = UDim2.new(1, -36, 0, 54),
		TextSize = 14,
		TextColor3 = COLORS.soft,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local card = Instance.new("Frame")
	card.Name = "Drawer"
	card.Position = UDim2.fromOffset(16, 112)
	card.Size = UDim2.new(1, -32, 0, 62)
	card.BackgroundColor3 = COLORS.card
	corner(card, 12)
	card.Parent = panel
	drawer = label(card, {
		Name = "Text",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
	})
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(12, 38)
	bar.Size = UDim2.new(1, -24, 0, 14)
	bar.BackgroundColor3 = rgb(226, 214, 198)
	corner(bar, 7)
	bar.Parent = card
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.buy
	corner(fill, 7)
	fill.Parent = bar
	collectButton = button(panel, {
		Name = "Collect",
		Position = UDim2.fromOffset(16, 186),
		Size = UDim2.new(0.5, -22, 0, 52),
		BackgroundColor3 = COLORS.go,
		Text = "💰 Ambil hasil",
	})
	collectButton.Activated:Connect(function()
		call("collect")
	end)
	serveButton = button(panel, {
		Name = "Serve",
		Position = UDim2.new(0.5, 6, 0, 186),
		Size = UDim2.new(0.5, -22, 0, 52),
		Text = "🧁 Layani pelanggan",
	})
	serveButton.Activated:Connect(function()
		call("serve")
	end)
	buyButton = button(panel, {
		Name = "Buy",
		Position = UDim2.fromOffset(16, 250),
		Size = UDim2.new(1, -32, 0, 52),
		BackgroundColor3 = COLORS.buy,
		TextColor3 = COLORS.text,
	})
	buyButton.Activated:Connect(function()
		call("buy")
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function BusinessController.init()
	buildGui()
end

function BusinessController.start()
	local PhoneController = require(script.Parent:WaitForChild("PhoneController")) :: any
	PhoneController.addApp("☕", "Kafeku", function()
		panel.Visible = true
		refresh()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(BusinessConfig.ATTR_PROMPT) then
			panel.Visible = true
			refresh()
		end
	end)
	player:GetAttributeChangedSignal(BusinessConfig.ATTR_PLAYER):Connect(refresh)
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 460, size.Y / 370), 0.55, 1)
		end
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return BusinessController
