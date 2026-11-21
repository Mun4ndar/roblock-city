--!strict
-- HouseUiController: menu Rumah (lihat & beli rumah, cat, hiasan halaman, pulang).
-- Client hanya MEMINTA lewat remote; harga, kepemilikan, dan jarak dicek server.
-- Keadaan rumah dibaca dari atribut Player "House" (JSON, diisi HouseService).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Types"))
local HouseConfig = require(Shared:WaitForChild("HouseConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

type HouseView = HouseConfig.HouseView

local player = Players.LocalPlayer

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local HouseUiController = {}

local COLORS = {
	panel = Color3.fromRGB(255, 255, 255),
	card = Color3.fromRGB(240, 244, 250),
	text = Color3.fromRGB(40, 48, 60),
	subtle = Color3.fromRGB(110, 120, 135),
	accent = Color3.fromRGB(46, 170, 150),
	buy = Color3.fromRGB(255, 184, 0),
	locked = Color3.fromRGB(200, 205, 214),
	close = Color3.fromRGB(235, 90, 90),
	selected = Color3.fromRGB(40, 48, 60),
}

local EMPTY_VIEW: HouseView =
	{ id = 0, live = 0, tier = "", paint = {}, items = {}, pos = { 0, 0, 0 } }

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local body: ScrollingFrame
local openButton: TextButton
local scale: UIScale

local busy = false
local viewing: Model? = nil -- rumah yang sedang dilihat lewat pintunya
local selectedSlot = 1
local confirmUntil = 0 -- konfirmasi beli/jual (klik dua kali)
local refresh: () -> ()

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
	l.TextWrapped = true
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 17
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	return b
end

local function row(height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -8, 0, height)
	f.LayoutOrder = order
	f.Parent = body
	return f
end

local function getView(): HouseView
	local raw = player:GetAttribute(HouseConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" and type(value.id) == "number" then
			value.paint = if type(value.paint) == "table" then value.paint else {}
			value.items = if type(value.items) == "table" then value.items else {}
			return value
		end
	end
	return EMPTY_VIEW
end

local function call(remoteName: string, ...: any): Types.HouseResult?
	if busy then
		return nil
	end
	busy = true
	local args = table.pack(...)
	local ok, value = pcall(function(): any
		return Net.func(remoteName):InvokeServer(table.unpack(args, 1, args.n))
	end)
	local res: Types.HouseResult = if ok
			and type(value) == "table"
			and type(value.message) == "string"
		then value
		else { ok = false, message = "Gagal terhubung, coba lagi." }
	HudController.toast(res.message)
	busy = false
	refresh()
	return res
end

-- Tombol yang harus diklik dua kali (beli/jual).
local function confirmClick(action: () -> ())
	if confirmUntil > os.clock() then
		confirmUntil = 0
		action()
	else
		confirmUntil = os.clock() + 4
		refresh()
		task.delay(4.1, function()
			if panel.Visible then
				refresh()
			end
		end)
	end
end

-- ---------------------------------------------------------------- isi panel

local function buildInfo(text: string, order: number, height: number?)
	label({ Size = UDim2.fromScale(1, 1), Text = text, TextYAlignment = Enum.TextYAlignment.Top }).Parent =
		row(height or 40, order)
end

local function buildTierList(order: number)
	for index, tier in HouseConfig.TIERS do
		local r = row(54, order + index)
		r.BackgroundTransparency = 0
		r.BackgroundColor3 = COLORS.card
		corner(r, 10)
		label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -130, 0, 22),
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
			Text = "🏠 " .. tier.name,
		}).Parent =
			r
		label({
			Position = UDim2.fromOffset(12, 27),
			Size = UDim2.new(1, -130, 0, 22),
			TextColor3 = COLORS.subtle,
			TextSize = 12,
			Text = tier.description,
		}).Parent =
			r
		label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 24),
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Format.money(tier.price),
		}).Parent =
			r
	end
end

-- Rumah yang dilihat lewat pintunya: info + tombol beli.
local function buildOffer(model: Model, view: HouseView)
	local id = model:GetAttribute(HouseConfig.ATTR_ID)
	local tier = HouseConfig.tier(model:GetAttribute(HouseConfig.ATTR_TIER) :: any)
	local ownerId = model:GetAttribute(HouseConfig.ATTR_OWNER_ID)
	if type(id) ~= "number" or tier == nil then
		buildInfo("Rumah ini belum bisa dibeli.", 1)
		return
	end
	titleLabel.Text = HouseConfig.address(id)
	buildInfo(`{tier.name}\n{tier.description}`, 1, 44)
	if type(ownerId) == "number" and ownerId ~= 0 then
		local ownerName = model:GetAttribute(HouseConfig.ATTR_OWNER_NAME)
		buildInfo("Rumah ini milik " .. tostring(ownerName) .. ".", 2)
		return
	end
	if view.id ~= 0 then
		buildInfo("Kamu sudah punya rumah. Jual dulu rumah lamamu kalau mau pindah ke sini.", 2)
		return
	end
	local money = player:GetAttribute("Money")
	local affordable = type(money) == "number" and money >= tier.price
	local confirming = confirmUntil > os.clock()
	local buy = button({
		Size = UDim2.fromOffset(240, 48),
		TextSize = 20,
		Text = if confirming then "Yakin beli?" else "Beli " .. Format.money(tier.price),
		TextColor3 = COLORS.text,
		BackgroundColor3 = if affordable or confirming then COLORS.buy else COLORS.locked,
	})
	buy.Parent = row(52, 2)
	buy.Activated:Connect(function()
		confirmClick(function()
			local res = call(Net.Names.HouseBuy, id)
			if res and res.ok then
				viewing = nil
				refresh()
			end
		end)
	end)
	if not affordable then
		buildInfo("Uangmu belum cukup. Ayo bekerja dulu di menu Pekerjaan!", 3)
	end
end

local function buildSwatch(
	parent: Instance,
	color: Color3,
	text: string,
	selected: boolean,
	onClick: () -> ()
)
	local b = button({
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 11,
	})
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = if selected then 3 else 1
	stroke.Color = if selected then COLORS.selected else COLORS.locked
	stroke.Parent = b
	b.Parent = parent
	b.Activated:Connect(onClick)
end

-- Rumah sendiri: cat, hiasan halaman, pulang, jual.
local function buildManage(view: HouseView)
	local tier = HouseConfig.tier(view.tier)
	titleLabel.Text = "Rumahku"
	local info = `{HouseConfig.address(view.live)} · {if tier then tier.name else ""}`
	if view.live ~= view.id then
		info ..= " (rumah pengganti)"
	end
	buildInfo(info, 0, 20)

	label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Text = `Cat rumah ({Format.money(HouseConfig.PAINT_PRICE)} sekali ganti)`,
	}).Parent =
		row(24, 2)
	for index, slot in HouseConfig.PAINT_SLOTS do
		local r = row(38, 2 + index)
		label({ Size = UDim2.new(0, 64, 1, 0), Text = slot.name }).Parent = r
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromOffset(66, 2)
		strip.Size = UDim2.new(1, -66, 1, -4)
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = strip
		strip.Parent = r
		local current = view.paint[slot.id] or 0
		buildSwatch(strip, COLORS.card, "Asli", current == 0, function()
			call(Net.Names.HousePaint, slot.id, 0)
		end)
		for colorIndex, color in HouseConfig.PAINT[slot.id] do
			buildSwatch(strip, color, "", current == colorIndex, function()
				call(Net.Names.HousePaint, slot.id, colorIndex)
			end)
		end
	end

	label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Text = "Hiasan halaman: pilih tempat, lalu pilih hiasan",
	}).Parent =
		row(24, 10)
	local slotRow = row(40, 11)
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.Padding = UDim.new(0, 6)
	slotLayout.Parent = slotRow
	for slotIndex, slot in HouseConfig.YARD_SLOTS do
		local item = HouseConfig.item(view.items[tostring(slotIndex)] or "")
		local b = button({
			Size = UDim2.fromOffset(100, 36),
			TextSize = 13,
			Text = (if item then item.icon .. " " else "") .. slot.name,
			BackgroundColor3 = if slotIndex == selectedSlot then COLORS.accent else COLORS.card,
			TextColor3 = if slotIndex == selectedSlot then Color3.new(1, 1, 1) else COLORS.text,
		})
		b.Parent = slotRow
		b.Activated:Connect(function()
			selectedSlot = slotIndex
			refresh()
		end)
	end

	local installed = view.items[tostring(selectedSlot)] or ""
	local gridRow = row(140, 12)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(100, 64)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridRow
	local function itemButton(order: number, text: string, isCurrent: boolean, itemId: string)
		local b = button({
			LayoutOrder = order,
			TextSize = 13,
			Text = text,
			TextWrapped = true,
			BackgroundColor3 = if isCurrent then COLORS.accent else COLORS.card,
			TextColor3 = if isCurrent then Color3.new(1, 1, 1) else COLORS.text,
		})
		b.Parent = gridRow
		b.Activated:Connect(function()
			call(Net.Names.HouseItem, selectedSlot, itemId)
		end)
	end
	for order, item in HouseConfig.ITEMS do
		itemButton(
			order,
			`{item.icon} {item.name}\n{Format.money(item.price)}`,
			installed == item.id,
			item.id
		)
	end
	itemButton(#HouseConfig.ITEMS + 1, "Kosongkan", installed == "", "")

	local footer = row(46, 1)
	local home = button({ Size = UDim2.fromOffset(200, 42), Text = "🏠 Pulang ke rumah" })
	home.Parent = footer
	home.Activated:Connect(function()
		local res = call(Net.Names.HouseGoHome)
		if res and res.ok then
			panel.Visible = false
		end
	end)
	local confirming = confirmUntil > os.clock()
	local sell = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(200, 42),
		TextSize = 15,
		BackgroundColor3 = if confirming then COLORS.close else COLORS.locked,
		TextColor3 = if confirming then Color3.new(1, 1, 1) else COLORS.text,
		Text = if confirming
			then "Yakin jual?"
			else "Jual rumah (" .. Format.money(HouseConfig.sellPrice(view.tier)) .. ")",
	})
	sell.Parent = footer
	sell.Activated:Connect(function()
		confirmClick(function()
			call(Net.Names.HouseSell)
		end)
	end)
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
	local model = viewing
	if model and model.Parent and model:GetAttribute(HouseConfig.ATTR_ID) ~= view.live then
		buildOffer(model, view)
	elseif view.id ~= 0 and view.live ~= 0 then
		buildManage(view)
	elseif view.id ~= 0 then
		titleLabel.Text = "Rumahku"
		buildInfo(
			"Semua rumah setipe sedang penuh di server ini. Rumahmu tetap aman, coba lagi nanti ya.",
			1
		)
	else
		titleLabel.Text = "Rumah"
		buildInfo(
			"Kamu belum punya rumah. Datangi rumah di perumahan, lalu tekan tombol di pintunya untuk melihat dan membelinya.",
			1,
			50
		)
		buildTierList(1)
	end
end

local function setOpen(open: boolean, model: Model?)
	viewing = model
	confirmUntil = 0
	panel.Visible = open
	refresh()
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 500, size.Y / 500), 0.55, 1)
	end
end

-- ---------------------------------------------------------------- builder UI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "HouseMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	openButton = button({
		Name = "OpenHouse",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.42, 100),
		Size = UDim2.fromOffset(132, 42),
		TextSize = 18,
		Text = "🏠 Rumah",
	})
	corner(openButton, 12)
	UiScale.sideButton(openButton, 2)
	openButton.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(470, 460)
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

	titleLabel = label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		Text = "Rumah",
	})
	titleLabel.Parent = panel

	local close = button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = COLORS.close,
		TextSize = 20,
		Text = "X",
	})
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
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

-- Trampolin: pantulan dihitung di client pemilik karakter (fisika karakter milik client).
local function hookBouncePad(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	inst.Touched:Connect(function(hit: BasePart)
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		local power = inst:GetAttribute(HouseConfig.ATTR_BOUNCE)
		if character and root and type(power) == "number" and hit:IsDescendantOf(character) then
			local velocity = root.AssemblyLinearVelocity
			if velocity.Y < power * 0.5 then
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
			end
		end
	end)
end

-- ---------------------------------------------------------------- bootstrap

-- Posisi depan rumah pemain di server ini (untuk peta/GPS), nil jika belum punya.
function HouseUiController.getHomePosition(): Vector3?
	local view = getView()
	if view.live == 0 then
		return nil
	end
	return Vector3.new(view.pos[1] or 0, view.pos[2] or 0, view.pos[3] or 0)
end

function HouseUiController.init()
	buildGui()
end

function HouseUiController.start()
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	player:GetAttributeChangedSignal(HouseConfig.ATTR_PLAYER):Connect(refresh)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(HouseConfig.ATTR_PROMPT) ~= nil then
			setOpen(true, prompt:FindFirstAncestorOfClass("Model"))
		end
	end)

	for _, pad in CollectionService:GetTagged(HouseConfig.TAG_BOUNCE) do
		hookBouncePad(pad)
	end
	CollectionService:GetInstanceAddedSignal(HouseConfig.TAG_BOUNCE):Connect(hookBouncePad)

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return HouseUiController
