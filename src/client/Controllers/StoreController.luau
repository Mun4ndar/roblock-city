--!strict
-- StoreController: panel belanja TOKO (minimarket). Dua mode (event StoreOpen dari server):
--   * "rak"   : pemain memilih barang di rak/kulkas (tekan E di rak) dan memasukkannya ke keranjang.
--   * "kasir" : di meja kasir pemain hanya membayar isi keranjang (NPC kasir menyapa).
-- Semua dicek server (harga, jarak, uang). Barang yang dibayar muncul di hotbar bawah.

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
local cart: { [string]: number } = {}
local mode = "rak"
local shelfItems: { string } = {}
local busy = false

local function cartTotal(): (number, number)
	local total, count = 0, 0
	for id, n in cart do
		local item = StoreConfig.get(id)
		if item then
			total += item.price * n
			count += n
		end
	end
	return total, count
end

local render: () -> ()

local function callCart(action: string, id: string?)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(StoreConfig.CART_FUNC):InvokeServer(action, id)
	end)
	busy = false
	if ok and type(value) == "table" then
		if type(value.cart) == "table" then
			cart = value.cart
		end
		HudController.toast(if type(value.message) == "string" then value.message else "")
	else
		HudController.toast("Gagal terhubung, coba lagi.")
	end
	if panel.Visible then
		render()
	end
end

local function checkout()
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(StoreConfig.BUY_FUNC):InvokeServer()
	end)
	busy = false
	if ok and type(value) == "table" then
		if type(value.bag) == "table" then
			bag = value.bag
		end
		if type(value.cart) == "table" then
			cart = value.cart
		end
		HudController.toast(if type(value.message) == "string" then value.message else "")
	else
		HudController.toast("Gagal terhubung, coba lagi.")
	end
	if panel.Visible then
		render()
	end
end

local function smallButton(row: Frame, text: string, x: number, color: Color3, onClick: () -> ())
	local b = UiKit.button(row, {
		Name = "Kecil",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		Text = text,
		BackgroundColor3 = color,
	})
	b.Activated:Connect(onClick)
end

local function itemRow(index: number, item: StoreConfig.Item, subtitle: string): Frame
	local row = Instance.new("Frame")
	row.Name = "Barang_" .. item.id
	row.Size = UDim2.new(1, -8, 0, 54)
	row.BackgroundColor3 = COLORS.card
	row.LayoutOrder = index
	UiKit.corner(row, 10)
	row.Parent = body
	UiKit.label(row, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -170, 0, 24),
		Text = `{item.icon} {item.name}`,
		TextSize = 15,
	})
	UiKit.label(row, {
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -170, 0, 24),
		Text = subtitle,
		TextSize = 12,
		TextColor3 = COLORS.subtle,
	})
	return row
end

local function renderShelf()
	local total, count = cartTotal()
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 34),
		Text = if count > 0
			then `Keranjang: {count} barang ({Format.money(total)}). Bayar di kasir ya!`
			else "Pilih barangnya, lalu bayar di kasir.",
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		LayoutOrder = 0,
	})
	for index, id in shelfItems do
		local item = StoreConfig.get(id)
		if item == nil then
			continue
		end
		local owned = bag[item.id] or 0
		local inCart = cart[item.id] or 0
		local limit = if item.reusable then 1 else item.maxStack
		local full = owned + inCart >= limit
		local subtitle = if inCart > 0
			then `Di keranjang: {inCart}`
			elseif item.reusable and owned > 0 then "Sudah dimiliki ✔"
			elseif owned > 0 then `Kamu punya {owned}`
			else item.desc
		local row = itemRow(index, item, subtitle)
		local add = UiKit.button(row, {
			Name = "Ambil",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(100, 34),
			Text = if full then "Penuh" else `+ {Format.money(item.price)}`,
			BackgroundColor3 = if full then COLORS.locked else COLORS.go,
		})
		add.Activated:Connect(function()
			callCart("add", item.id)
		end)
		if inCart > 0 then
			smallButton(row, "−", -114, COLORS.locked, function()
				callCart("remove", item.id)
			end)
		end
	end
end

local function renderCashier()
	local total, count = cartTotal()
	if count == 0 then
		UiKit.label(body, {
			Size = UDim2.new(1, -8, 0, 60),
			Text = "Keranjangmu masih kosong. Ambil barang di rak atau kulkas dulu ya, lalu bayar di sini.",
			TextColor3 = COLORS.subtle,
			TextSize = 14,
			LayoutOrder = 0,
		})
		return
	end
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 34),
		Text = "Isi keranjangmu. Bayar sekarang, barangnya masuk ke hotbar.",
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		LayoutOrder = 0,
	})
	for index, item in StoreConfig.ITEMS do
		local n = cart[item.id] or 0
		if n > 0 then
			local row = itemRow(index, item, `{n} x {Format.money(item.price)} = {Format.money(item.price * n)}`)
			smallButton(row, "−", -8, COLORS.locked, function()
				callCart("remove", item.id)
			end)
			smallButton(row, "+", -48, COLORS.go, function()
				callCart("add", item.id)
			end)
		end
	end
	local money = player:GetAttribute("Money")
	local affordable = type(money) == "number" and money >= total
	local pay = UiKit.button(body, {
		Name = "Bayar",
		Size = UDim2.new(1, -8, 0, 44),
		Text = `Bayar {Format.money(total)}`,
		BackgroundColor3 = if affordable then COLORS.go else COLORS.locked,
		LayoutOrder = 1000,
	})
	pay.Activated:Connect(checkout)
	local clear = UiKit.button(body, {
		Name = "Kosongkan",
		Size = UDim2.new(1, -8, 0, 34),
		Text = "Kosongkan keranjang",
		BackgroundColor3 = COLORS.locked,
		LayoutOrder = 1001,
	})
	clear.Activated:Connect(function()
		callCart("clear", nil)
	end)
end

render = function()
	UiKit.clear(body)
	if mode == "kasir" then
		renderCashier()
	else
		renderShelf()
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
	Net.event(StoreConfig.OPEN_EVENT).OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then
			return
		end
		mode = if state.mode == "kasir" then "kasir" else "rak"
		bag = if type(state.bag) == "table" then state.bag else {}
		cart = if type(state.cart) == "table" then state.cart else {}
		shelfItems = if type(state.items) == "table" then state.items else {}
		panel.Visible = true
		render()
	end)
	-- Perbarui tombol (mampu bayar / tidak) saat uang berubah.
	player:GetAttributeChangedSignal("Money"):Connect(function()
		if panel.Visible then
			render()
		end
	end)
	-- Tutup otomatis kalau pemain berjalan menjauh dari kasir / rak.
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				local character = player.Character
				local root = if character then character.PrimaryPart else nil
				local near = false
				local tag = if mode == "kasir" then StoreConfig.TAG_COUNTER else StoreConfig.TAG_SHELF
				local reach = if mode == "kasir" then StoreConfig.BUY_DISTANCE + 6 else StoreConfig.SHELF_DISTANCE + 6
				for _, inst in CollectionService:GetTagged(tag) do
					if root and inst:IsA("BasePart") and (inst.Position - root.Position).Magnitude < reach then
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
