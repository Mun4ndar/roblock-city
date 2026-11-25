--!strict
-- InfoBoardController: panel PAPAN INFO di taman tempat pemain baru muncul. Papan (Part bertag "InfoBoard" dengan
-- ProximityPrompt, dibuat map/BuildPapanInfo) membuka daftar tempat seru lengkap dengan gambar kecil. Mengetuk
-- kartu = memulai GPS yang SAMA dengan Peta/HP (NavController.setTarget dari DestinationConfig).
-- Isi daftar: Shared.InfoBoardConfig. Gambar kecil = satu atlas, dipotong dengan ImageRectOffset.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))
local InfoBoardConfig = require(Shared:WaitForChild("InfoBoardConfig"))

local Util = script.Parent.Parent:WaitForChild("Util")
local UiKit = require(Util:WaitForChild("UiKit"))
local NavController = require(script.Parent:WaitForChild("NavController"))
local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local C = {
	panel = rgb(24, 32, 60),
	header = rgb(34, 44, 82),
	card = rgb(38, 50, 92),
	cardActive = rgb(64, 96, 190),
	text = rgb(240, 244, 255),
	subtle = rgb(158, 172, 208),
	accent = rgb(46, 150, 255),
	chip = rgb(44, 58, 104),
}
local PANEL = Vector2.new(800, 500)
local CLOSE_DISTANCE = 60

local InfoBoardController = {}

type CardRef = {
	button: TextButton,
	distance: TextLabel,
	position: Vector3,
	zone: string,
	openAttr: string?,
	opensAt: string?,
}

local gui: ScreenGui
local panel: Frame
local scroll: ScrollingFrame
local cards: { CardRef } = {}
local chips: { [string]: TextButton } = {}
local activeZone = "all"
local boardPart: BasePart? = nil

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function applyFilter()
	for _, ref in cards do
		ref.button.Visible = activeZone == "all" or ref.zone == activeZone
	end
	for id, chip in chips do
		chip.BackgroundColor3 = if id == activeZone then C.accent else C.chip
	end
	scroll.CanvasPosition = Vector2.zero
end

local function updateDistances()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	for _, ref in cards do
		local text = "📍 " .. NavController.formatDistance(flatDistance(root.Position, ref.position))
		if ref.openAttr then
			if Workspace:GetAttribute(ref.openAttr) == true then
				text ..= " · 🟢 Buka sekarang"
			else
				text ..= " · 🌙 Buka " .. (ref.opensAt or "")
			end
		end
		ref.distance.Text = text
	end
end

local function makeThumb(parent: Instance, entry: InfoBoardConfig.Entry, icon: string, color: Color3)
	local thumb = Instance.new("ImageLabel")
	thumb.Name = "Gambar"
	thumb.Size = UDim2.new(1, -12, 0, 98)
	thumb.Position = UDim2.fromOffset(6, 6)
	thumb.BackgroundColor3 = color
	thumb.ScaleType = Enum.ScaleType.Crop
	UiKit.corner(thumb, 10)
	if entry.cell ~= nil and InfoBoardConfig.ATLAS_ID ~= "" then
		local cell = InfoBoardConfig.CELL
		thumb.Image = InfoBoardConfig.ATLAS_ID
		thumb.ImageRectSize = cell
		thumb.ImageRectOffset = Vector2.new(
			(entry.cell % InfoBoardConfig.COLUMNS) * cell.X,
			math.floor(entry.cell / InfoBoardConfig.COLUMNS) * cell.Y
		)
	else
		local big = Instance.new("TextLabel")
		big.BackgroundTransparency = 1
		big.Size = UDim2.fromScale(1, 1)
		big.Text = icon
		big.TextSize = 46
		big.Font = Enum.Font.GothamBold
		big.Parent = thumb
	end
	thumb.Parent = parent
end

local function buildCards()
	for _, entry in InfoBoardConfig.ENTRIES do
		local dest = DestinationConfig.get(entry.dest)
		if dest == nil then
			continue
		end
		local zone = DestinationConfig.zone(dest.zone)
		local button = Instance.new("TextButton")
		button.Name = "Kartu_" .. dest.id
		button.AutoButtonColor = true
		button.BackgroundColor3 = C.card
		button.Text = ""
		UiKit.corner(button, 12)
		makeThumb(button, entry, dest.icon, zone.color)

		UiKit.label(button, {
			Name = "Nama",
			Position = UDim2.fromOffset(8, 106),
			Size = UDim2.new(1, -16, 0, 18),
			Text = dest.icon .. " " .. dest.name,
			Font = Enum.Font.FredokaOne,
			TextSize = 14,
			TextColor3 = C.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		UiKit.label(button, {
			Name = "Isi",
			Position = UDim2.fromOffset(8, 124),
			Size = UDim2.new(1, -16, 0, 30),
			Text = entry.desc,
			TextSize = 11,
			TextColor3 = C.subtle,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local distance = UiKit.label(button, {
			Name = "Jarak",
			Position = UDim2.new(0, 8, 1, -22),
			Size = UDim2.new(1, -100, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Text = "",
			TextSize = 11,
			TextColor3 = C.subtle,
		})
		UiKit.label(button, {
			Name = "TombolGps",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 1, -24),
			Size = UDim2.fromOffset(84, 18),
			Text = "🧭 GPS",
			Font = Enum.Font.FredokaOne,
			TextSize = 12,
			TextColor3 = C.accent,
			TextXAlignment = Enum.TextXAlignment.Right,
		})

		button.Activated:Connect(function()
			NavController.setTarget({
				id = dest.id,
				name = dest.name,
				icon = dest.icon,
				position = dest.position,
				arrive = dest.arrive,
			})
			panel.Visible = false
		end)
		button.Parent = scroll
		table.insert(cards, {
			button = button,
			distance = distance,
			position = dest.position,
			zone = dest.zone,
			openAttr = entry.openAttr,
			opensAt = entry.opensAt,
		})
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "InfoBoardGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true

	panel = Instance.new("Frame")
	panel.Name = "PapanInfo"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL.X, PANEL.Y)
	panel.BackgroundColor3 = C.panel
	panel.Visible = false
	UiKit.corner(panel, 16)
	panel.Parent = gui

	-- kecilkan di layar sempit
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = panel
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			uiScale.Scale = math.clamp(math.min(size.X / (PANEL.X + 20), size.Y / (PANEL.Y + 20)), 0.5, 1)
		end
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	UiKit.label(panel, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 28),
		Text = "🗺️ Papan Info ROBLOCK CITY",
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextColor3 = C.text,
	})
	UiKit.label(panel, {
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -70, 0, 18),
		Text = "Ketuk satu tempat, GPS langsung menuntunmu lewat jalan.",
		TextSize = 13,
		TextColor3 = C.subtle,
	})
	local close = UiKit.button(panel, {
		Name = "Tutup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 30),
		Text = "✖",
		BackgroundColor3 = UiKit.COLORS.close,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	-- chip zona
	local chipRow = Instance.new("Frame")
	chipRow.Name = "Zona"
	chipRow.BackgroundTransparency = 1
	chipRow.Position = UDim2.fromOffset(12, 60)
	chipRow.Size = UDim2.new(1, -24, 0, 28)
	chipRow.Parent = panel
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 6)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chipRow
	local chipCount = 0
	local function addChip(id: string, text: string)
		local chip = UiKit.button(chipRow, {
			Name = "Chip_" .. id,
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 13,
			BackgroundColor3 = C.chip,
		})
		chipCount += 1
		chip.LayoutOrder = chipCount
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = chip
		chip.Activated:Connect(function()
			activeZone = id
			applyFilter()
		end)
		chips[id] = chip
	end
	addChip("all", "✨ Semua")
	local used: { [string]: boolean } = {}
	for _, entry in InfoBoardConfig.ENTRIES do
		local dest = DestinationConfig.get(entry.dest)
		if dest then
			used[dest.zone] = true
		end
	end
	for _, zone in DestinationConfig.ZONES do
		if used[zone.id] then
			addChip(zone.id, zone.icon .. " " .. zone.name)
		end
	end

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Daftar"
	scroll.Position = UDim2.fromOffset(12, 96)
	scroll.Size = UDim2.new(1, -24, 1, -108)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(244, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	buildCards()
	applyFilter()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function InfoBoardController.open()
	updateDistances()
	panel.Visible = true
end

function InfoBoardController.init()
	buildGui()
end

function InfoBoardController.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("InfoBoard") then
			boardPart = prompt.Parent :: BasePart?
			InfoBoardController.open()
		end
	end)

	-- menutup sendiri kalau pemain menjauh dari papan
	task.spawn(function()
		while true do
			task.wait(0.5)
			local part = boardPart
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if panel.Visible and part and root and flatDistance(root.Position, part.Position) > CLOSE_DISTANCE then
				panel.Visible = false
			end
		end
	end)

	-- petunjuk sekali per sesi untuk pemain yang muncul di dekat papan
	task.spawn(function()
		local part: Instance? = nil
		for _ = 1, 40 do
			part = CollectionService:GetTagged("InfoBoard")[1]
			if part then
				break
			end
			task.wait(0.5)
		end
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if part and root and flatDistance(root.Position, (part :: BasePart).Position) < InfoBoardConfig.HINT_RADIUS then
			task.wait(6)
			HudController.toast("Baru di sini? Tekan E di Papan Info dekat air mancur untuk lihat semua tempat seru!")
		end
	end)
end

return InfoBoardController
