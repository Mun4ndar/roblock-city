--!strict
-- ShopController: panel Toko Koin (pembelian Robux, opsional). Terbuka dari HP (menu "Toko Koin")
-- atau dari kios Toko Koin di dalam ROBLOCK Mega Mall. Tombol hanya meminta server membuka jendela
-- beli; jendela konfirmasi, harga, dan pembayarannya sepenuhnya milik Roblox (lihat ShopService).
-- Produk yang ID-nya masih 0 di ShopConfig tidak ditampilkan.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer

local ShopController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(255, 246, 222),
	text = rgb(40, 48, 60),
	soft = rgb(110, 120, 135),
	accent = rgb(240, 170, 30),
	buy = rgb(64, 190, 100),
	owned = rgb(200, 205, 214),
	close = rgb(235, 90, 90),
}

local gui: ScreenGui
local panel: Frame
local body: Frame
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
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.buy
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	b.Parent = parent
	return b
end

-- Harga yang tampil diambil dari Roblox (harga di sana yang berlaku); selama belum didapat,
-- tombolnya bertuliskan "Beli".
local prices: { [string]: number } = {}

local function priceText(key: string): string
	local price = prices[key]
	return if price then "R$ " .. price else "Beli"
end

local function loadPrices()
	local function fetch(key: string, id: number, infoType: Enum.InfoType)
		if id == 0 then
			return
		end
		local ok, info = pcall(function(): any
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			prices[key] = info.PriceInRobux
		end
	end
	for _, product in ShopConfig.PRODUCTS do
		fetch(product.key, product.productId, Enum.InfoType.Product)
	end
	fetch("vip", ShopConfig.PASSES.vip.passId, Enum.InfoType.GamePass)
	refresh()
end

local function ask(key: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.ShopPrompt):InvokeServer(key)
	end)
	if not ok then
		HudController.toast("Gagal terhubung, coba lagi.")
	elseif type(value) == "table" and type(value.message) == "string" and value.message ~= "" then
		HudController.toast(value.message)
	end
	busy = false
end

local function row(order: number, icon: string, title: string, detail: string): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 62)
	frame.BackgroundColor3 = COLORS.card
	corner(frame, 12)
	frame.Parent = body
	label(frame, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0, 44, 1, 0),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = icon,
	})
	label(frame, {
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(1, -200, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Text = title,
	})
	label(frame, {
		Position = UDim2.fromOffset(60, 32),
		Size = UDim2.new(1, -200, 0, 24),
		TextSize = 12,
		TextColor3 = COLORS.soft,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = detail,
	})
	return frame
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
	local order = 0
	for _, product in ShopConfig.PRODUCTS do
		if product.productId ~= 0 then
			order += 1
			local frame =
				row(order, "💰", product.name, "+" .. Format.money(product.coins) .. " uang kota")
			button(frame, {
				Name = "Buy",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 42),
				Text = priceText(product.key),
			}).Activated:Connect(function()
				ask(product.key)
			end)
		end
	end
	local pass = ShopConfig.PASSES.vip
	if pass.passId ~= 0 then
		order += 1
		local owned = player:GetAttribute(ShopConfig.ATTR_VIP) == true
		local frame = row(order, "⭐", pass.name, pass.description)
		local b = button(frame, {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(120, 42),
			BackgroundColor3 = if owned then COLORS.owned else COLORS.buy,
			Text = if owned then "Sudah punya" else priceText("vip"),
		})
		if not owned then
			b.Activated:Connect(function()
				ask("vip")
			end)
		end
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 400)
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
		Text = "💰 Toko Koin",
	})
	label(panel, {
		Position = UDim2.fromOffset(18, 46),
		Size = UDim2.new(1, -36, 0, 34),
		TextSize = 12,
		TextColor3 = COLORS.soft,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Semua isi kota bisa didapat dengan bermain. Toko ini hanya jalan pintas. "
			.. "Minta izin orang tua dulu sebelum membeli ya!",
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
	body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(16, 88)
	body.Size = UDim2.new(1, -32, 1, -100)
	body.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	body.Parent = panel
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function isOpenForBusiness(): boolean
	if ShopConfig.PASSES.vip.passId ~= 0 then
		return true
	end
	for _, product in ShopConfig.PRODUCTS do
		if product.productId ~= 0 then
			return true
		end
	end
	return false
end

function ShopController.open()
	panel.Visible = true
	refresh()
end

function ShopController.init()
	buildGui()
end

function ShopController.start()
	if isOpenForBusiness() then
		local PhoneController = require(script.Parent:WaitForChild("PhoneController")) :: any
		PhoneController.addApp("💰", "Toko Koin", ShopController.open)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(ShopConfig.ATTR_PROMPT) then
			ShopController.open()
		end
	end)
	player:GetAttributeChangedSignal(ShopConfig.ATTR_VIP):Connect(refresh)
	task.spawn(loadPrices)
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 480, size.Y / 440), 0.55, 1)
		end
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return ShopController
