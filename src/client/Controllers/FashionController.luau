--!strict
-- FashionController: panel Toko Costume (beli dan pakai skin baju/costume). Terbuka dari tombol di Toko Costume.
-- Semua aksi lewat remote FashionAction; harga dan kepemilikan dicek FashionService.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer

local FashionController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(238, 245, 252),
	text = rgb(40, 48, 60),
	accent = rgb(80, 150, 235),
	buy = rgb(255, 184, 0),
	locked = rgb(200, 205, 214),
	go = rgb(64, 190, 100),
	close = rgb(235, 90, 90),
}

local gui: ScreenGui
local panel: Frame
local body: ScrollingFrame
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

local function getView(): FashionConfig.FashionView
	local raw = player:GetAttribute(FashionConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" then
			return {
				owned = if type(value.owned) == "table" then value.owned else {},
				active = if type(value.active) == "string" then value.active else "",
			}
		end
	end
	return { owned = {}, active = "" }
end

local function call(action: string, id: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.FashionAction):InvokeServer(action, id)
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

local function buyRobux(productKey: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.ShopPrompt):InvokeServer(productKey)
	end)
	if
		ok
		and type(value) == "table"
		and value.ok == false
		and type(value.message) == "string"
		and value.message ~= ""
	then
		HudController.toast(value.message)
	elseif not ok then
		HudController.toast("Gagal membuka pembelian Roblox.")
	end
	busy = false
end

function refresh()
	if not panel.Visible then
		return
	end
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local view = getView()
	for order, outfit in FashionConfig.OUTFITS do
		local owned = view.owned[outfit.id] == true
		if outfit.event and not owned then
			continue -- setelan event dibeli di panel Hadiah HP
		end
		local wearing = view.active == outfit.id
		local row = Instance.new("Frame")
		row.Name = outfit.id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = COLORS.card
		corner(row, 10)
		row.Parent = body
		-- contoh warna: jaket + topi
		local jacket = Instance.new("Frame")
		jacket.Position = UDim2.fromOffset(8, 8)
		jacket.Size = UDim2.fromOffset(40, 40)
		jacket.BackgroundColor3 = outfit.look.vest
		corner(jacket, 12)
		jacket.Parent = row
		local hat = Instance.new("Frame")
		hat.Size = UDim2.new(1, 0, 0, 12)
		hat.BackgroundColor3 = outfit.look.hatColor
		corner(hat, 6)
		hat.Parent = jacket
		label(jacket, {
			Size = UDim2.fromScale(1, 1),
			Text = outfit.icon,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		label(row, {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -200, 1, 0),
			Font = Enum.Font.FredokaOne,
			TextSize = 17,
			Text = outfit.name,
		})
		local text, color, textColor =
			if outfit.productKey
				then "R$ " .. tostring(outfit.robux or "?")
				else "Beli " .. Format.money(outfit.price),
			COLORS.buy,
			COLORS.text
		if wearing then
			text, color = "Lepas", COLORS.locked
		elseif owned then
			text, color, textColor = "Pakai", COLORS.go, Color3.new(1, 1, 1)
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
			if wearing then
				call("wear", "")
			elseif owned then
				call("wear", outfit.id)
			elseif outfit.productKey then
				buyRobux(outfit.productKey)
			else
				call("buy", outfit.id)
			end
		end)
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "FashionMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 440)
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
		Text = "🧥 Toko Costume",
	})
	label(panel, {
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 0, 18),
		TextSize = 12,
		TextColor3 = rgb(110, 120, 135),
		Text = "Skin baju/costume terlihat saat kamu tidak sedang bekerja.",
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
	body.Position = UDim2.fromOffset(16, 68)
	body.Size = UDim2.new(1, -28, 1, -80)
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

function FashionController.init()
	buildGui()
end

function FashionController.start()
	local PhoneController = require(script.Parent:WaitForChild("PhoneController")) :: any
	PhoneController.addApp("👑", "Toko Premium", function()
		local Nav = require(script.Parent:WaitForChild("NavController")) :: any
		local shop = require(
			game:GetService("ReplicatedStorage")
				:WaitForChild("Shared")
				:WaitForChild("DestinationConfig")
		).get("tokoCostume")
		Nav.setTarget({
			id = shop.id,
			name = shop.name,
			icon = shop.icon,
			position = shop.position,
			arrive = shop.arrive,
		})
	end)
	PhoneController.addApp("🧥", "Costume", function()
		panel.Visible = true
		refresh()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(FashionConfig.ATTR_PROMPT) then
			panel.Visible = true
			refresh()
		end
	end)
	player:GetAttributeChangedSignal(FashionConfig.ATTR_PLAYER):Connect(refresh)
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 480, size.Y / 480), 0.55, 1)
		end
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return FashionController
