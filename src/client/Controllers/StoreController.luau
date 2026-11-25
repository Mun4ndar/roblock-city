--!strict
-- StoreController: panel belanja TOKO (minimarket). Server membuka panel lewat event StoreOpen
-- (tekan E di kasir); pembelian lewat remote StoreBuy dan semua dicek server (harga, jarak, uang).
-- Barang yang dibeli muncul di hotbar bawah; klik barangnya untuk makan/minum/bermain.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local COLORS = UiKit.COLORS

local StoreController = {}

local panel: Frame
local body: ScrollingFrame
local bag: { [string]: number } = {}
local busy = false

local function render()
	UiKit.clear(body)
	local money = player:GetAttribute("Money")
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 34),
		Text = "Belanjaan masuk ke hotbar di bawah layar. Klik barangnya untuk makan, minum, atau bermain.",
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		LayoutOrder = 0,
	})
	for index, item in StoreConfig.ITEMS do
		local owned = bag[item.id] or 0
		local full = owned >= item.maxStack
		local row = Instance.new("Frame")
		row.Name = "Barang_" .. item.id
		row.Size = UDim2.new(1, -8, 0, 54)
		row.BackgroundColor3 = COLORS.card
		row.LayoutOrder = index
		UiKit.corner(row, 10)
		row.Parent = body
		UiKit.label(row, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -130, 0, 24),
			Text = `{item.icon} {item.name}`,
			TextSize = 15,
		})
		UiKit.label(row, {
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -130, 0, 24),
			Text = if item.reusable
				then (if owned > 0 then "Sudah dimiliki ✔" else item.desc)
				else (if owned > 0 then `Kamu punya {owned}` else item.desc),
			TextSize = 12,
			TextColor3 = COLORS.subtle,
		})
		local affordable = type(money) == "number" and money >= item.price
		local enabled = affordable and not full
		local buy = UiKit.button(row, {
			Name = "Beli",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(100, 34),
			Text = if full then "Penuh" else Format.money(item.price),
			BackgroundColor3 = if enabled then COLORS.go else COLORS.locked,
		})
		buy.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, value = pcall(function(): any
				return Net.func(StoreConfig.BUY_FUNC):InvokeServer(item.id)
			end)
			busy = false
			if ok and type(value) == "table" then
				if type(value.bag) == "table" then
					bag = value.bag
				end
				HudController.toast(if type(value.message) == "string" then value.message else "")
			else
				HudController.toast("Gagal terhubung, coba lagi.")
			end
			if panel.Visible then
				render()
			end
		end)
	end
end

function StoreController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoreGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	panel, body = UiKit.modal(gui, "StorePanel", "🛒 Toko", Vector2.new(380, 460))
	UiScale.attach(panel)
end

function StoreController.start()
	Net.event(StoreConfig.OPEN_EVENT).OnClientEvent:Connect(function(newBag: any)
		bag = if type(newBag) == "table" then newBag else {}
		panel.Visible = true
		render()
	end)
	-- Perbarui tombol (mampu beli / tidak) saat uang berubah.
	player:GetAttributeChangedSignal("Money"):Connect(function()
		if panel.Visible then
			render()
		end
	end)
	-- Tutup otomatis kalau pemain berjalan menjauh dari kasir.
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				local character = player.Character
				local root = if character then character.PrimaryPart else nil
				local near = false
				for _, inst in CollectionService:GetTagged(StoreConfig.TAG_COUNTER) do
					if
						root
						and inst:IsA("BasePart")
						and (inst.Position - root.Position).Magnitude < StoreConfig.BUY_DISTANCE + 6
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

return StoreController
