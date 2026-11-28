--!strict
-- RetentionController: panel "Hadiah" (hadiah login 7 hari, misi harian, misi mingguan, event).
-- Dibuka dari HP > Menu > Hadiah, dan muncul sendiri sekali saat masuk kalau hadiah login siap.
-- Semua angka dan hadiah dihitung server (RetentionService); di sini hanya tampilan.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))
local OnboardingConfig = require(Shared:WaitForChild("OnboardingConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local PhoneController = require(script.Parent:WaitForChild("PhoneController"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer

local RetentionController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(246, 248, 252),
	card = rgb(232, 237, 245),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(90, 120, 235),
	done = rgb(64, 190, 100),
	buy = rgb(255, 184, 0),
	big = rgb(255, 150, 60),
}

local TABS = { "Login", "Harian", "Pekan", "Event" }

local panel: Frame
local body: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Login"
local busy = false

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
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 8)
	return b
end

local function getView(): RetentionConfig.RetentionView
	local raw = player:GetAttribute(RetentionConfig.ATTR)
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			return decoded :: any
		end
	end
	return {
		day = 0,
		streak = 0,
		claimedToday = true,
		nextDay = 1,
		daily = {},
		dailyClaimed = {},
		week = 0,
		weekly = {},
		weeklyClaimed = {},
		event = "",
		eventProgress = {},
		eventClaimed = {},
	}
end

local function call(action: string, arg: string?)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.RetentionAction):InvokeServer(action, arg)
	end)
	HudController.toast(
		if ok
				and type(value) == "table"
				and type(value.message) == "string"
			then value.message
			else "Gagal terhubung, coba lagi."
	)
	task.wait(0.3)
	busy = false
end

-- ---------------------------------------------------------------- isi tab

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function header(text: string, order: number)
	label({
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 28),
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextWrapped = true,
		Text = text,
	}).Parent =
		body
end

local function buildStreak(view: RetentionConfig.RetentionView)
	local vip = player:GetAttribute("VIP") == true
	header(`Login beruntun: {view.streak} hari` .. (if vip then "  (VIP: hadiah 2x)" else ""), 0)
	local grid = Instance.new("Frame")
	grid.LayoutOrder = 1
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -6, 0, 150)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -6, 0, 70)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local doneUpTo = if view.claimedToday then (view.streak - 1) % 7 + 1 else view.streak % 7
	for day, reward in RetentionConfig.STREAK do
		local isNext = day == view.nextDay
		local claimed = day <= doneUpTo
		local cell = Instance.new("Frame")
		cell.LayoutOrder = day
		cell.BackgroundColor3 = if claimed
			then COLORS.done
			elseif isNext and not view.claimedToday then COLORS.buy
			else COLORS.card
		corner(cell, 10)
		label({
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 6),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			TextColor3 = if claimed then Color3.new(1, 1, 1) else COLORS.text,
			Text = `Hari {day}`,
		}).Parent =
			cell
		label({
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.FredokaOne,
			TextSize = if day == 7 then 17 else 15,
			TextColor3 = if claimed then Color3.new(1, 1, 1) else COLORS.text,
			Text = if claimed
				then "✔"
				else (if day == 7 then "🎁 " else "") .. Format.money(reward),
		}).Parent =
			cell
		cell.Parent = grid
	end
	grid.Parent = body

	local ready = not view.claimedToday
	local claimButton = button({
		LayoutOrder = 2,
		Name = "ClaimStreak",
		Size = UDim2.new(1, -6, 0, 44),
		BackgroundColor3 = if ready then COLORS.buy else COLORS.card,
		TextColor3 = if ready then COLORS.text else COLORS.subtle,
		TextSize = 17,
		AutoButtonColor = ready,
		Text = if ready then "Ambil hadiah hari ini" else "Sudah diambil. Kembali besok!",
	})
	claimButton.Parent = body
	if ready then
		claimButton.Activated:Connect(function()
			call("streak", nil)
		end)
	end
	label({
		LayoutOrder = 3,
		Size = UDim2.new(1, -6, 0, 34),
		TextWrapped = true,
		TextColor3 = COLORS.subtle,
		Text = "Login tiap hari tanpa putus. Kalau terlewat satu hari, hitungan mulai dari hari ke-1 lagi.",
	}).Parent =
		body
end

local function missionCard(
	def: RetentionConfig.MissionDef,
	progress: { [string]: number },
	claimed: { [string]: boolean },
	order: number
)
	local value = math.min(progress[def.id] or 0, def.target)
	local complete = value >= def.target
	local isClaimed = claimed[def.id] == true
	local mult = if player:GetAttribute("VIP") == true then RetentionConfig.VIP_MULTIPLIER else 1
	local card = Instance.new("Frame")
	card.Name = def.id
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
	fill.Size = UDim2.fromScale(value / def.target, 1)
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
		Text = if def.counter == "earn"
			then `{Format.money(value)} / {Format.money(def.target)}`
			else `{value} / {def.target}`,
	}).Parent =
		card
	local action = button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(84, 30),
		TextSize = 13,
		Text = if isClaimed
			then "Selesai"
			elseif complete then "Ambil"
			else Format.money(def.reward * mult),
		BackgroundColor3 = if isClaimed
			then COLORS.done
			elseif complete then COLORS.buy
			else Color3.new(1, 1, 1),
		TextColor3 = if isClaimed then Color3.new(1, 1, 1) else COLORS.text,
		AutoButtonColor = complete and not isClaimed,
	})
	action.Parent = card
	if complete and not isClaimed then
		action.Activated:Connect(function()
			call("mission", def.id)
		end)
	end
	card.Parent = body
end

local function buildDaily(view: RetentionConfig.RetentionView)
	header("Misi harian (ganti tiap pukul 00.00 WIB)", 0)
	for order, def in RetentionConfig.dailyFor(view.day) do
		missionCard(def, view.daily, view.dailyClaimed, order)
	end
end

local function buildWeekly(view: RetentionConfig.RetentionView)
	header("Misi mingguan (ganti tiap Senin)", 0)
	for order, def in RetentionConfig.weeklyFor(view.week) do
		missionCard(def, view.weekly, view.weeklyClaimed, order)
	end
end

local function buildEvent(view: RetentionConfig.RetentionView)
	local event = if view.event ~= "" then RetentionConfig.event(view.event) else nil
	if event == nil then
		header("Belum ada event. Event berikutnya muncul di hari-hari besar!", 0)
		for order, e in RetentionConfig.EVENTS do
			label({
				LayoutOrder = order,
				Size = UDim2.new(1, -6, 0, 22),
				Text = `{e.icon} {e.name}`,
			}).Parent =
				body
		end
		return
	end
	header(`{event.icon} {event.name}`, 0)
	for order, def in event.missions do
		missionCard(def, view.eventProgress, view.eventClaimed, order)
	end
	local base = #event.missions
	local owned = {}
	local raw = player:GetAttribute(FashionConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" and type(decoded.owned) == "table" then
			owned = decoded.owned
		end
	end
	header("Barang terbatas", base + 1)
	for index, item in event.items do
		local outfit = FashionConfig.get(item.id)
		if outfit then
			local has = owned[outfit.id] == true
			local row = Instance.new("Frame")
			row.LayoutOrder = base + 1 + index
			row.Size = UDim2.new(1, -6, 0, 56)
			row.BackgroundColor3 = COLORS.card
			corner(row, 10)
			label({
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -150, 1, 0),
				Font = Enum.Font.FredokaOne,
				TextSize = 16,
				Text = `{outfit.icon} {outfit.name}`,
			}).Parent =
				row
			local buy = button({
				Name = "BuyEvent",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 38),
				BackgroundColor3 = if has then COLORS.done else COLORS.buy,
				TextColor3 = if has then Color3.new(1, 1, 1) else COLORS.text,
				AutoButtonColor = not has,
				Text = if has then "Dimiliki" else "Beli " .. Format.money(item.price),
			})
			buy.Parent = row
			if not has then
				buy.Activated:Connect(function()
					call("buy", item.id)
				end)
			end
			row.Parent = body
		end
	end
end

local BUILDERS = {
	Login = buildStreak,
	Harian = buildDaily,
	Pekan = buildWeekly,
	Event = buildEvent,
}

local function refresh()
	if not panel.Visible then
		return
	end
	for name, tab in tabButtons do
		tab.BackgroundColor3 = if name == currentTab then COLORS.accent else COLORS.card
		tab.TextColor3 = if name == currentTab then Color3.new(1, 1, 1) else COLORS.text
	end
	clear()
	BUILDERS[currentTab](getView())
end

-- ---------------------------------------------------------------- UI

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RetentionGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(400, 420)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 16)
	UiScale.attach(panel)
	panel.Parent = gui

	label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 28),
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		Text = "🎁 Hadiah",
	}).Parent =
		panel
	local close = button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(32, 28),
		BackgroundColor3 = rgb(235, 80, 90),
		Text = "X",
	})
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	for index, name in TABS do
		local tab = button({
			Name = "Tab" .. name,
			Position = UDim2.new((index - 1) / #TABS, 8, 0, 42),
			Size = UDim2.new(1 / #TABS, -6, 0, 28),
			TextSize = 13,
			Text = name,
		})
		tab.Parent = panel
		tabButtons[name] = tab
		tab.Activated:Connect(function()
			currentTab = name
			refresh()
		end)
	end

	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(10, 78)
	body.Size = UDim2.new(1, -20, 1, -88)
	body.ScrollBarThickness = 4
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	body.Parent = panel
end

function RetentionController.open(tab: string?)
	if tab and BUILDERS[tab] then
		currentTab = tab
	end
	panel.Visible = true
	refresh()
end

function RetentionController.init()
	buildGui()
end

function RetentionController.start()
	PhoneController.addApp("🎁", "Hadiah", function()
		RetentionController.open()
	end)
	player:GetAttributeChangedSignal(RetentionConfig.ATTR):Connect(refresh)
	Workspace:GetAttributeChangedSignal(RetentionConfig.EVENT_ATTR):Connect(function()
		local id = Workspace:GetAttribute(RetentionConfig.EVENT_ATTR)
		local event = if type(id) == "string" then RetentionConfig.event(id) else nil
		if event then
			HudController.toast(`Event {event.name} dimulai! Cek menu Hadiah di HP.`)
		end
	end)

	-- Sekali saat masuk: tampilkan panel kalau hadiah login siap diambil.
	task.spawn(function()
		local waited = 0
		while player:GetAttribute(RetentionConfig.ATTR) == nil and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		task.wait(3)
		-- Pemain baru: tunggu sampai langkah 1 Misi Pemula selesai supaya tidak langsung disambut menu.
		local held = false
		while true do
			local onboarding = OnboardingConfig.read(player)
			if onboarding == nil or onboarding.done or onboarding.step >= 1 then
				break
			end
			held = true
			task.wait(1)
		end
		if held then
			task.wait(6)
		end
		if player:GetAttribute(RetentionConfig.ATTR) ~= nil and not getView().claimedToday and not panel.Visible then
			RetentionController.open("Login")
		end
	end)
end

return RetentionController
