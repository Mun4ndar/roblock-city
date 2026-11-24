--!strict
-- JobUiController: menu Pekerjaan + panel tugas aktif.
-- Client hanya MEMINTA ganti pekerjaan / ganti tugas; server yang memutuskan.
-- Daftar pekerjaan dibaca dari JobConfig, jadi pekerjaan baru otomatis muncul.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local JobController = require(script.Parent:WaitForChild("JobController"))

type JobDef = JobConfig.JobDef

type Card = {
	def: JobDef,
	button: TextButton,
	stats: TextLabel,
}

local player = Players.LocalPlayer

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local JobUiController = {}

local COLORS = {
	panel = Color3.fromRGB(255, 255, 255),
	card = Color3.fromRGB(240, 244, 250),
	text = Color3.fromRGB(40, 48, 60),
	subtle = Color3.fromRGB(110, 120, 135),
	start = Color3.fromRGB(64, 190, 100),
	stop = Color3.fromRGB(235, 90, 90),
	accent = Color3.fromRGB(240, 150, 40),
	marker = Color3.fromRGB(255, 204, 0),
	service = Color3.fromRGB(90, 150, 235),
}

local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local openButton: TextButton
local skipButton: TextButton
local serviceButton: TextButton
local serviceButton2: TextButton
local hintLabel: TextLabel
local tracker: TextButton
local trackerScale: UIScale
local trackerTitle: TextLabel
local trackerStep: TextLabel
local trackerDistance: TextLabel
local trackerArrow: Frame
local cards: { Card } = {}
local busy = false

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
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function readStats(): { [string]: JobConfig.JobStats }
	local raw = player:GetAttribute(JobConfig.ATTR_STATS)
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function currentJob(): string
	local value = player:GetAttribute(JobConfig.ATTR_JOB)
	return if type(value) == "string" then value else ""
end

-- ---------------------------------------------------------------- tampilan

local function refreshCards()
	local stats = readStats()
	local current = currentJob()
	for _, card in cards do
		local progress = stats[card.def.id]
		local tasks = if progress and type(progress.tasks) == "number" then progress.tasks else 0
		local earned = if progress and type(progress.earned) == "number" then progress.earned else 0
		local level = JobConfig.levelFor(tasks)
		local nextAt = JobConfig.nextLevelAt(tasks)
		local progressText = if nextAt then `{tasks}/{nextAt} tugas` else `{tasks} tugas`
		card.stats.Text = `Level {level} · {progressText} · {Format.money(earned)}`
		if card.def.id == current then
			card.button.Text = "Berhenti"
			card.button.BackgroundColor3 = COLORS.stop
		else
			card.button.Text = "Mulai"
			card.button.BackgroundColor3 = COLORS.start
		end
	end
	skipButton.Visible = current ~= ""
	-- Pekerjaan dengan kendaraan dinas mendapat tombol untuk mengeluarkannya.
	local service = VehicleConfig.forJob(current)
	serviceButton.Visible = service ~= nil
	hintLabel.Visible = service == nil
	if service then
		serviceButton.Text = "Keluarkan " .. service.name
	end
	local extra = VehicleConfig.extraForJob(current)
	serviceButton2.Visible = extra ~= nil
	if extra then
		serviceButton2.Text = "Keluarkan " .. extra.name
	end
end

local function refreshTracker()
	local task_ = JobController.getTask()
	local def = JobConfig.get(currentJob())
	if def == nil then
		tracker.Visible = false
		return
	end
	tracker.Visible = true
	local step = if task_ then task_.steps[task_.index] else nil
	if task_ == nil or step == nil then
		trackerTitle.Text = `{def.icon} {def.name}`
		trackerStep.Text = "Menyiapkan tugas berikutnya..."
		trackerDistance.Text = ""
		trackerArrow.Visible = false
		return
	end
	trackerTitle.Text = `{def.icon} {task_.title} · {Format.money(task_.pay)}`
	trackerStep.Text = `{task_.index}/{#task_.steps}  {step.text}`
	trackerArrow.Visible = true
end

-- Jarak + panah arah (relatif ke kamera) menuju penanda.
local function updateDirection()
	local target = JobController.getTarget()
	local distance = JobController.getDistance()
	local camera = Workspace.CurrentCamera
	if target == nil or distance == nil or camera == nil or not tracker.Visible then
		return
	end
	trackerDistance.Text = string.format("%d m", math.floor(distance / 3.5 + 0.5))
	local relative = camera.CFrame:PointToObjectSpace(target)
	trackerArrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		refreshCards()
	end
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		panelScale.Scale = math.clamp(math.min(size.X / 500, size.Y / 470), 0.55, 1)
		trackerScale.Scale = math.clamp(math.min(size.X / 760, size.Y / 420), 0.75, 1)
	end
end

-- ---------------------------------------------------------------- aksi

local function onCardClicked(card: Card)
	if busy then
		return
	end
	busy = true
	local stopping = card.def.id == currentJob()
	local res = JobController.selectJob(if stopping then "" else card.def.id)
	HudController.toast(res.message)
	if res.ok and not stopping then
		setOpen(false)
	end
	refreshCards()
	busy = false
end

local function onSkipClicked()
	if busy then
		return
	end
	busy = true
	local res = JobController.skipTask()
	HudController.toast(res.message)
	if res.ok then
		setOpen(false)
	end
	busy = false
end

local function onServiceClicked(extra: boolean?)
	local service = if extra then VehicleConfig.extraForJob(currentJob()) else VehicleConfig.forJob(currentJob())
	if busy or service == nil then
		return
	end
	busy = true
	local ok, res = pcall(function(): any
		return Net.func(Net.Names.VehicleSpawn):InvokeServer(service.id)
	end)
	if ok and type(res) == "table" and type(res.message) == "string" then
		HudController.toast(res.message)
		if res.ok then
			setOpen(false)
		end
	else
		HudController.toast("Gagal terhubung, coba lagi.")
	end
	busy = false
end

-- ---------------------------------------------------------------- builder UI

local function buildCard(def: JobDef, order: number, parent: Instance): Card
	local frame = Instance.new("Frame")
	frame.Name = def.id
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, 96)
	frame.BackgroundColor3 = COLORS.card
	corner(frame, 12)

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Position = UDim2.fromOffset(10, 16)
	swatch.Size = UDim2.fromOffset(64, 64)
	swatch.BackgroundColor3 = def.color
	corner(swatch, 14)
	swatch.Parent = frame
	label({
		Size = UDim2.fromScale(1, 1),
		Text = def.icon,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
	}).Parent =
		swatch

	label({
		Name = "Name",
		Position = UDim2.fromOffset(86, 6),
		Size = UDim2.new(1, -206, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextSize = 21,
		Text = def.name,
	}).Parent =
		frame
	local stats = label({
		Name = "Stats",
		Position = UDim2.fromOffset(86, 30),
		Size = UDim2.new(1, -206, 0, 18),
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		Text = "",
	})
	stats.Parent = frame
	label({
		Name = "Description",
		Position = UDim2.fromOffset(86, 48),
		Size = UDim2.new(1, -206, 0, 44),
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = `{def.description} Mulai di: {def.workplace}.`,
	}).Parent =
		frame

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(100, 44)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "Mulai"
	button.AutoButtonColor = true
	corner(button, 12)
	button.Parent = frame

	frame.Parent = parent
	local card: Card = { def = def, button = button, stats = stats }
	button.Activated:Connect(function()
		onCardClicked(card)
	end)
	return card
end

local function buildTracker()
	-- Panel tugas ringkas di tengah paling atas (uang ada di pojok kanan). Ketuk untuk membuka menu.
	tracker = Instance.new("TextButton")
	tracker.Name = "TaskTracker"
	tracker.AnchorPoint = Vector2.new(0.5, 0)
	tracker.Position = UDim2.new(0.5, 0, 0, 2)
	UiScale.attach(tracker)
	UiScale.onChange(function(value: number)
		tracker.Position = UDim2.new(0.5, 0, 0, 2 + 0 * value)
	end)
	tracker.Size = UDim2.fromOffset(330, 44)
	tracker.BackgroundColor3 = COLORS.panel
	tracker.BackgroundTransparency = 0.3
	tracker.AutoButtonColor = false
	tracker.Text = ""
	tracker.Visible = false
	corner(tracker, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLORS.marker
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = tracker
	trackerScale = Instance.new("UIScale")
	trackerScale.Parent = tracker
	tracker.Parent = gui

	trackerTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -78, 0, 18),
		Font = Enum.Font.FredokaOne,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	trackerTitle.Parent = tracker
	trackerStep = label({
		Name = "Step",
		Position = UDim2.fromOffset(10, 21),
		Size = UDim2.new(1, -78, 0, 20),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	trackerStep.Parent = tracker
	-- Panah arah digambar dari tiga batang supaya bisa diputar dengan rapi.
	trackerArrow = Instance.new("Frame")
	trackerArrow.Name = "Arrow"
	trackerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	trackerArrow.Position = UDim2.new(1, -36, 0, 15)
	trackerArrow.Size = UDim2.fromOffset(28, 28)
	trackerArrow.BackgroundTransparency = 1
	for _, bar in { { 14, 15, 22, 0 }, { 9, 9, 14, 40 }, { 19, 9, 14, -40 } } do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(bar[1], bar[2])
		frame.Size = UDim2.fromOffset(4, bar[3])
		frame.Rotation = bar[4]
		frame.BackgroundColor3 = COLORS.accent
		frame.BorderSizePixel = 0
		corner(frame, 2)
		frame.Parent = trackerArrow
	end
	trackerArrow.Parent = tracker
	trackerDistance = label({
		Name = "Distance",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(1, -36, 0, 27),
		Size = UDim2.fromOffset(70, 15),
		Font = Enum.Font.FredokaOne,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
	})
	trackerDistance.Parent = tracker
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "JobMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4

	-- Tombol pembuka di tepi kiri, di bawah tombol Kendaraan.
	openButton = Instance.new("TextButton")
	openButton.Name = "OpenJobs"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	UiScale.sideButton(openButton, 1)
	openButton.Size = UDim2.fromOffset(132, 42)
	openButton.BackgroundColor3 = COLORS.accent
	openButton.Font = Enum.Font.FredokaOne
	openButton.TextSize = 18
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Text = "💼 Pekerjaan"
	corner(openButton, 12)
	openButton.Parent = gui

	buildTracker()

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(470, 430)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	panel.ZIndex = 5
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.accent
	stroke.Parent = panel
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	panel.Parent = gui

	label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		Text = "Pilih Pekerjaan",
	}).Parent =
		panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundColor3 = COLORS.stop
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 10)
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(14, 56)
	list.Size = UDim2.new(1, -28, 1, -170)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = panel

	for order, def in JobConfig.LIST do
		table.insert(cards, buildCard(def, order, list))
	end

	skipButton = Instance.new("TextButton")
	skipButton.Name = "Skip"
	skipButton.AnchorPoint = Vector2.new(0, 1)
	skipButton.Position = UDim2.new(0, 14, 1, -12)
	skipButton.Size = UDim2.fromOffset(170, 42)
	skipButton.BackgroundColor3 = COLORS.accent
	skipButton.Font = Enum.Font.FredokaOne
	skipButton.TextSize = 17
	skipButton.TextColor3 = Color3.new(1, 1, 1)
	skipButton.Text = "Ganti tugas"
	skipButton.Visible = false
	corner(skipButton, 12)
	skipButton.Parent = panel
	skipButton.Activated:Connect(onSkipClicked)

	serviceButton = Instance.new("TextButton")
	serviceButton.Name = "ServiceVehicle"
	serviceButton.AnchorPoint = Vector2.new(1, 1)
	serviceButton.Position = UDim2.new(1, -14, 1, -12)
	serviceButton.Size = UDim2.fromOffset(250, 42)
	serviceButton.BackgroundColor3 = COLORS.service
	serviceButton.Font = Enum.Font.FredokaOne
	serviceButton.TextSize = 17
	serviceButton.TextColor3 = Color3.new(1, 1, 1)
	serviceButton.Text = ""
	serviceButton.Visible = false
	corner(serviceButton, 12)
	serviceButton.Parent = panel
	serviceButton.Activated:Connect(function()
		onServiceClicked(false)
	end)

	serviceButton2 = Instance.new("TextButton")
	serviceButton2.Name = "ServiceVehicle2"
	serviceButton2.AnchorPoint = Vector2.new(1, 1)
	serviceButton2.Position = UDim2.new(1, -14, 1, -60)
	serviceButton2.Size = UDim2.fromOffset(250, 42)
	serviceButton2.BackgroundColor3 = COLORS.service
	serviceButton2.Font = Enum.Font.FredokaOne
	serviceButton2.TextSize = 17
	serviceButton2.TextColor3 = Color3.new(1, 1, 1)
	serviceButton2.Text = ""
	serviceButton2.Visible = false
	corner(serviceButton2, 12)
	serviceButton2.Parent = panel
	serviceButton2.Activated:Connect(function()
		onServiceClicked(true)
	end)

	hintLabel = label({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(250, 42),
		TextColor3 = COLORS.subtle,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Ikuti penanda kuning, lalu tahan tombolnya. Gaji naik 5% setiap naik level.",
	})
	hintLabel.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- ---------------------------------------------------------------- bootstrap

function JobUiController.init()
	buildGui()
end

function JobUiController.start()
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	tracker.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	player:GetAttributeChangedSignal(JobConfig.ATTR_JOB):Connect(function()
		refreshCards()
		refreshTracker()
	end)
	player:GetAttributeChangedSignal(JobConfig.ATTR_STATS):Connect(refreshCards)
	JobController.Changed:Connect(refreshTracker)

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	refreshCards()
	refreshTracker()

	while true do
		task.wait(0.1)
		updateDirection()
	end
end

return JobUiController
