--!strict
-- FoodController: menu jajanan. Server membuka panel lewat event FoodMenu (tekan E di warung/lapak);
-- pembelian lewat remote FoodBuy dan semua dicek server (harga, jarak, uang).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local COLORS = UiKit.COLORS

local FoodController = {}

local panel: Frame
local body: ScrollingFrame
local currentMenu = ""
local busy = false

local function render(stallName: string)
	local title = panel:FindFirstChild("Judul") :: TextLabel
	title.Text = "🍽️ " .. stallName
	UiKit.clear(body)
	local festival = Workspace:GetAttribute(IndonesiaConfig.ATTR_FESTIVAL) == true
	local money = player:GetAttribute("Money")
	local menu = IndonesiaConfig.MENUS[currentMenu] or {}
	if festival then
		UiKit.label(body, {
			Size = UDim2.new(1, -8, 0, 22),
			Text = "🎉 Festival Kuliner! Semua harga diskon 20%.",
			TextColor3 = COLORS.warn,
			LayoutOrder = 0,
		})
	end
	for index, foodId in menu do
		local food = IndonesiaConfig.FOODS[foodId]
		local price = if festival
			then math.ceil(food.price * IndonesiaConfig.FESTIVAL_DISCOUNT)
			else food.price
		local row = Instance.new("Frame")
		row.Name = "Menu_" .. foodId
		row.Size = UDim2.new(1, -8, 0, 46)
		row.BackgroundColor3 = COLORS.card
		row.LayoutOrder = index
		UiKit.corner(row, 10)
		row.Parent = body
		UiKit.label(row, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Text = `{food.icon} {food.name}`,
			TextSize = 15,
		})
		local affordable = type(money) == "number" and money >= price
		local buy = UiKit.button(row, {
			Name = "Beli",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(96, 32),
			Text = Format.money(price),
			BackgroundColor3 = if affordable then COLORS.go else COLORS.locked,
		})
		buy.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, value = pcall(function(): any
				return Net.func("FoodBuy"):InvokeServer(currentMenu, foodId)
			end)
			busy = false
			HudController.toast(
				if ok
						and type(value) == "table"
						and type(value.message) == "string"
					then value.message
					else "Gagal terhubung, coba lagi."
			)
			if panel.Visible then
				render(stallName)
			end
		end)
	end
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 36),
		Text = `Jajan bikin kenyang semangat: lari lebih cepat {IndonesiaConfig.BUFF_SECONDS} detik.`,
		TextColor3 = COLORS.subtle,
		LayoutOrder = 100,
	})
end

function FoodController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FoodGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	panel, body = UiKit.modal(gui, "FoodPanel", "🍽️ Warung", Vector2.new(360, 380))
	UiScale.attach(panel)
end

function FoodController.start()
	Net.event("FoodMenu").OnClientEvent:Connect(function(menuId: any, stallName: any)
		if type(menuId) ~= "string" or IndonesiaConfig.MENUS[menuId] == nil then
			return
		end
		currentMenu = menuId
		panel.Visible = true
		render(if type(stallName) == "string" then stallName else "Warung")
	end)
	-- Tutup otomatis kalau pemain berjalan menjauh dari lapak.
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				local character = player.Character
				local root = if character then character.PrimaryPart else nil
				local near = false
				for _, inst in game:GetService("CollectionService"):GetTagged("FoodStall") do
					if
						root
						and inst:IsA("BasePart")
						and inst:GetAttribute("StallMenu") == currentMenu
						and (inst.Position - root.Position).Magnitude
							< IndonesiaConfig.BUY_DISTANCE + 6
					then
						near = true
						break
					end
				end
				if not near then
					panel.Visible = false
				end
			end
		end
	end)
end

return FoodController
