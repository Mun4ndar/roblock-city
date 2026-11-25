--!strict
-- ProgressController: panel "Koleksi & Peringkat" di HP > Menu: koleksi langka, papan peringkat
-- (terkaya, pekerja terbaik), dan kode tukar + grup Roblox. Semua data dari server (ProgressAction).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local ProgressConfig = require(Shared:WaitForChild("ProgressConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local PhoneController = require(script.Parent:WaitForChild("PhoneController"))
local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local COLORS = UiKit.COLORS

local ProgressController = {}

local TABS = { "Koleksi", "Peringkat", "Kode" }

local panel: Frame
local body: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Koleksi"
local busy = false
local refresh: () -> ()

local function call(action: string, arg: any?): any
	if busy then
		return nil
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func("ProgressAction"):InvokeServer(action, arg)
	end)
	busy = false
	if ok and type(value) == "table" then
		return value
	end
	HudController.toast("Gagal terhubung, coba lagi.")
	return nil
end

local function owned(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local raw = player:GetAttribute(ProgressConfig.ATTR_COLLECTION)
	if type(raw) == "string" then
		for id in raw:gmatch("[^,]+") do
			set[id] = true
		end
	end
	return set
end

-- ---------------------------------------------------------------- tab

local function tabCollection()
	local have = owned()
	local count = 0
	for _ in have do
		count += 1
	end
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 40),
		Text = `Koleksi langka: {count}/{#ProgressConfig.RARES}. Dapatkan dari tugas pekerjaan (makin tinggi level, makin sering) atau kode tukar. Lengkap = hadiah {Format.money(
			ProgressConfig.SET_BONUS
		)}!`,
		TextSize = 12,
		TextColor3 = COLORS.subtle,
		LayoutOrder = 0,
	})
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 1
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -4, 0, 78)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index, rare in ProgressConfig.RARES do
		local rarity = ProgressConfig.RARITY[rare.rarity]
		local card = Instance.new("Frame")
		card.Name = "Kartu_" .. rare.id
		card.LayoutOrder = index
		card.BackgroundColor3 = if have[rare.id] then COLORS.card else Color3.fromRGB(226, 229, 236)
		UiKit.corner(card, 10)
		card.Parent = grid
		local stroke = Instance.new("UIStroke")
		stroke.Color = if have[rare.id] then rarity.color else COLORS.locked
		stroke.Thickness = 2
		stroke.Parent = card
		UiKit.label(card, {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 34),
			Text = if have[rare.id] then rare.icon else "❓",
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		UiKit.label(card, {
			Position = UDim2.fromOffset(6, 38),
			Size = UDim2.new(1, -12, 0, 34),
			Text = if have[rare.id]
				then `{rare.name}\n{rarity.name} · {rare.kind}`
				else `???\n{rarity.name} · {rare.kind}`,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if have[rare.id] then COLORS.text else COLORS.subtle,
		})
	end
end

local function addBoard(title: string, list: any, unit: string, order: number, myValue: number)
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 24),
		Text = title,
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = COLORS.accent,
		LayoutOrder = order,
	})
	if #list == 0 then
		UiKit.label(body, {
			Size = UDim2.new(1, -8, 0, 22),
			Text = "Belum ada data peringkat.",
			TextColor3 = COLORS.subtle,
			LayoutOrder = order + 1,
		})
	end
	for index, entry in list do
		local mine = entry.userId == player.UserId
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 30)
		row.BackgroundColor3 = if mine then Color3.fromRGB(255, 244, 205) else COLORS.card
		row.LayoutOrder = order + index
		UiKit.corner(row, 8)
		row.Parent = body
		local medal = ({ "🥇", "🥈", "🥉" })[entry.rank] or `{entry.rank}.`
		UiKit.label(row, {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Text = `{medal} {entry.name}`,
			TextSize = 13,
		})
		UiKit.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(104, 30),
			Text = if unit == "uang" then Format.money(entry.value) else `{entry.value} tugas`,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 20),
		Text = `Kamu: {if unit == "uang" then Format.money(myValue) else `{myValue} tugas`}`,
		TextSize = 12,
		TextColor3 = COLORS.subtle,
		LayoutOrder = order + 50,
	})
end

local function tabBoard()
	local data = call("board")
	if data == nil or type(data.kaya) ~= "table" then
		return
	end
	addBoard("💰 Terkaya", data.kaya, "uang", 0, data.myMoney or 0)
	addBoard("🛠️ Pekerja Terbaik", data.pekerja, "tugas", 100, data.myTasks or 0)
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 30),
		Text = "Peringkat diperbarui beberapa menit sekali.",
		TextSize = 11,
		TextColor3 = COLORS.subtle,
		LayoutOrder = 300,
	})
end

local function tabCode()
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 22),
		Text = "🎁 Kode Tukar",
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = COLORS.accent,
		LayoutOrder = 0,
	})
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 48)
	row.BackgroundColor3 = COLORS.card
	row.LayoutOrder = 1
	UiKit.corner(row, 10)
	row.Parent = body
	local box = Instance.new("TextBox")
	box.Name = "KolomKode"
	box.Position = UDim2.fromOffset(8, 7)
	box.Size = UDim2.new(1, -108, 0, 34)
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = "Masukkan kode"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamMedium
	box.TextSize = 14
	box.TextColor3 = COLORS.text
	UiKit.corner(box, 8)
	box.Parent = row
	local go = UiKit.button(row, {
		Name = "TukarKode",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(86, 34),
		Text = "Tukar",
		BackgroundColor3 = COLORS.go,
	})
	go.Activated:Connect(function()
		local value = call("code", box.Text)
		if value and type(value.message) == "string" then
			HudController.toast(value.message)
			if value.ok then
				box.Text = ""
			end
		end
	end)
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 36),
		Text = "Kode dibagikan lewat acara dan media sosial resmi ROBLOCK CITY. Tiap kode hanya sekali pakai per pemain.",
		TextSize = 12,
		TextColor3 = COLORS.subtle,
		LayoutOrder = 2,
	})
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 22),
		Text = "👥 Grup Roblox",
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = COLORS.accent,
		LayoutOrder = 3,
	})
	local bonus = player:GetAttribute(ProgressConfig.ATTR_GROUP_BONUS)
	local info = if type(bonus) == "number"
		then `Kamu anggota grup! Bonus gaji +{math.round((bonus - 1) * 100)}% aktif.`
		else `Gabung grup "{ProgressConfig.GROUP_NAME}" di Roblox: hadiah {Format.money(
			ProgressConfig.GROUP_JOIN_REWARD
		)} sekali dan bonus gaji +{math.round((ProgressConfig.GROUP_BONUS - 1) * 100)}% semua pekerjaan.`
	UiKit.label(body, {
		Size = UDim2.new(1, -8, 0, 52),
		Text = if ProgressConfig.GROUP_ID <= 0
			then "Grup resmi akan segera dibuka. Nantikan ya!"
			else info,
		TextSize = 12,
		LayoutOrder = 4,
	})
	if ProgressConfig.GROUP_ID > 0 then
		local claim = UiKit.button(body, {
			Name = "KlaimGrup",
			Size = UDim2.new(1, -8, 0, 38),
			Text = "Klaim hadiah grup",
			BackgroundColor3 = COLORS.warn,
			LayoutOrder = 5,
		})
		claim.Activated:Connect(function()
			local value = call("group")
			if value and type(value.message) == "string" then
				HudController.toast(value.message)
				refresh()
			end
		end)
	end
end

local TAB_FUNCS: { [string]: () -> () } = {
	Koleksi = tabCollection,
	Peringkat = tabBoard,
	Kode = tabCode,
}

function refresh()
	if not panel.Visible then
		return
	end
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then COLORS.accent else COLORS.locked
	end
	UiKit.clear(body)
	TAB_FUNCS[currentTab]()
end

function ProgressController.open(tab: string?)
	if tab and TAB_FUNCS[tab] then
		currentTab = tab
	end
	panel.Visible = true
	refresh()
end

function ProgressController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ProgressGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	panel, body =
		UiKit.modal(gui, "ProgressPanel", "🏆 Koleksi & Peringkat", Vector2.new(400, 450))
	UiScale.attach(panel)

	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.fromOffset(12, 44)
	tabs.Size = UDim2.new(1, -24, 0, 32)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tabs
	for index, name in TABS do
		local b = UiKit.button(tabs, {
			Name = "Tab" .. name,
			LayoutOrder = index,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			Text = name,
			BackgroundColor3 = COLORS.locked,
		})
		b.Activated:Connect(function()
			currentTab = name
			refresh()
		end)
		tabButtons[name] = b
	end
	body.Position = UDim2.fromOffset(12, 84)
	body.Size = UDim2.new(1, -24, 1, -96)
end

function ProgressController.start()
	PhoneController.addApp("🏆", "Koleksi", function()
		ProgressController.open("Koleksi")
	end)
	PhoneController.addApp("📊", "Peringkat", function()
		ProgressController.open("Peringkat")
	end)
	PhoneController.addApp("🔑", "Kode Tukar", function()
		ProgressController.open("Kode")
	end)
	player:GetAttributeChangedSignal(ProgressConfig.ATTR_COLLECTION):Connect(refresh)
end

return ProgressController
