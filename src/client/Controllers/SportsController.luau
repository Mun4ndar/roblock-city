--!strict
-- SportsController: tampilan mini-game lapangan (adu penalti sepak bola dan lempar bebas basket).
-- Pemain mengetuk tombol besar beberapa kali: mengunci arah, (tinggi), lalu tenaga. Angka 0..1 dikirim ke
-- SportsService yang menghitung hasil, gerak bola, kiper, dan hadiah. Sentuhan dan klik memakai satu tombol;
-- tombol spasi juga bisa dipakai di komputer.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SportsConfig = require(Shared:WaitForChild("SportsConfig"))
local Format = require(Shared:WaitForChild("Format"))

local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local COLORS = UiKit.COLORS
local FOOT = SportsConfig.FOOTBALL
local BASK = SportsConfig.BASKET
local rgb = Color3.fromRGB

local SportsController = {}

type Session = {
	token: string,
	mode: string,
	shots: number,
	shot: number,
	stage: number,
	values: { number },
	stageStart: number,
	phase: number,
	waiting: boolean,
	score: number,
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local scoreLabel: TextLabel
local actionButton: TextButton
local aimView: Frame
local goalRect: Frame
local crosshair: Frame
local aimBar: Frame
local aimBand: Frame
local aimMarker: Frame
local powerBar: Frame
local powerBand: Frame
local powerMarker: Frame
local resultLabel: TextLabel
local exitButton: TextButton
local session: Session? = nil

-- Periode satu sapuan (detik) per tahap.
local FOOT_PERIODS = { 4.8, 4.2, 3.8 }
local BASK_PERIODS = { 4.8, 4.2 }

local function periods(mode: string): { number }
	return if mode == "football" then FOOT_PERIODS else BASK_PERIODS
end

local function stageNames(mode: string): { string }
	if mode == "football" then
		return { "KUNCI ARAH", "KUNCI TINGGI", "TENDANG! ⚽" }
	end
	return { "KUNCI ARAH", "LEMPAR! 🏀" }
end

-- Gelombang segitiga 0..1..0 dengan fase awal acak supaya tidak bisa dihafal.
local function sweep(elapsed: number, period: number, phase: number): number
	local x = (elapsed / period + phase) % 1
	return math.abs(x * 2 - 1)
end

local function currentValue(s: Session): number
	local list = periods(s.mode)
	return sweep(os.clock() - s.stageStart, list[s.stage], s.phase)
end

local function showMarkers(s: Session)
	local football = s.mode == "football"
	aimView.Visible = football
	aimBar.Visible = not football
	powerBar.Visible = true
	exitButton.Visible = true
	panel.Visible = true
	if football then
		powerBar.Position = UDim2.fromOffset(214, 30)
		powerBar.Size = UDim2.fromOffset(194, 20)
		actionButton.Position = UDim2.fromOffset(214, 56)
		actionButton.Size = UDim2.fromOffset(194, 46)
	else
		aimBar.Position = UDim2.fromOffset(12, 30)
		powerBar.Position = UDim2.fromOffset(12, 66)
		powerBar.Size = UDim2.fromOffset(190, 24)
		actionButton.Position = UDim2.fromOffset(214, 30)
		actionButton.Size = UDim2.fromOffset(194, 72)
	end
end

local function updateLabels(s: Session)
	local football = s.mode == "football"
	titleLabel.Text = if football then `{FOOT.icon} {FOOT.title}` else `{BASK.icon} {BASK.title}`
	scoreLabel.Text = if football
		then `Tendangan {s.shot} dari {s.shots} · Gol {s.score}`
		else `Lemparan {s.shot} dari {s.shots} · Masuk {s.score}`
	local names = stageNames(s.mode)
	actionButton.Text = names[s.stage] or names[#names]
end

local function startStage(s: Session, stage: number)
	s.stage = stage
	s.stageStart = os.clock()
	s.phase = math.random()
	updateLabels(s)
end

local function resetShot(s: Session)
	s.values = {}
	s.waiting = false
	actionButton.Visible = true
	actionButton.Active = true
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Visible = s.mode == "football"
	aimMarker.Position = UDim2.fromScale(0.5, 0.5)
	powerMarker.Position = UDim2.fromScale(0, 0.5)
	startStage(s, 1)
end

local function render()
	local s = session
	if s == nil or s.waiting then
		return
	end
	local v = currentValue(s)
	if s.mode == "football" then
		if s.stage == 1 then
			crosshair.Position = UDim2.fromScale(v, 0.5)
		elseif s.stage == 2 then
			local x = (s.values[1] + 1) / 2
			crosshair.Position = UDim2.fromScale(x, 1 - v)
		else
			local x = (s.values[1] + 1) / 2
			crosshair.Position = UDim2.fromScale(x, 1 - s.values[2])
			powerMarker.Position = UDim2.fromScale(v, 0.5)
		end
	else
		if s.stage == 1 then
			aimMarker.Position = UDim2.fromScale(v, 0.5)
		else
			aimMarker.Position = UDim2.fromScale((s.values[1] + 1) / 2, 0.5)
			powerMarker.Position = UDim2.fromScale(v, 0.5)
		end
	end
end

local function say(text: string, color: Color3, seconds: number)
	resultLabel.Text = text
	resultLabel.TextColor3 = color
	resultLabel.Visible = true
	resultLabel.TextTransparency = 0
	resultLabel.Size = UDim2.fromOffset(120, 24)
	TweenService:Create(
		resultLabel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(420, 64) }
	):Play()
	local mine = text
	task.delay(seconds, function()
		if resultLabel.Text == mine then
			resultLabel.Visible = false
		end
	end)
end

local function pressAction()
	local s = session
	if s == nil or s.waiting then
		return
	end
	local v = currentValue(s)
	local list = stageNames(s.mode)
	if s.stage == 1 then
		table.insert(s.values, v * 2 - 1) -- aimX -1..1
	else
		table.insert(s.values, v)
	end
	if s.stage < #list then
		startStage(s, s.stage + 1)
		return
	end
	-- semua tahap terkunci: kirim bidikan
	s.waiting = true
	actionButton.Visible = false
	local a, b, c = s.values[1], s.values[2], s.values[3]
	if s.mode == "basket" then
		a, b, c = s.values[1], s.values[2], 0
	end
	Net.event("SportsShoot"):FireServer(s.token, a, b, c)
end

local hiddenTags: { BillboardGui } = {}

-- Papan nama/VIP di atas kepala pemain disembunyikan selama mini-game supaya tidak menutupi gawang/ring.
local function hideOwnTags(hide: boolean)
	if hide then
		local character = player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BillboardGui") and d.Enabled then
					d.Enabled = false
					table.insert(hiddenTags, d)
				end
			end
		end
		for _, spot in CollectionService:GetTagged("SportsSpot") do
			for _, d in spot:GetChildren() do
				if d:IsA("BillboardGui") and d.Enabled then
					d.Enabled = false
					table.insert(hiddenTags, d)
				end
			end
		end
	else
		for _, tag in hiddenTags do
			if tag.Parent then
				tag.Enabled = true
			end
		end
		table.clear(hiddenTags)
	end
end

local function restoreCamera()
	hideOwnTags(false)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function closeGui()
	session = nil
	gui.Enabled = false
	resultLabel.Visible = false
	restoreCamera()
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SportsGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 26
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -8)
	panel.Size = UDim2.fromOffset(420, 112)
	panel.BackgroundColor3 = rgb(25, 35, 55)
	panel.BackgroundTransparency = 0.5
	panel.Parent = gui
	UiKit.corner(panel, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.accent
	stroke.Thickness = 3
	stroke.Transparency = 0.5
	stroke.Parent = panel
	UiScale.attach(panel)

	titleLabel = UiKit.label(panel, {
		Name = "Judul",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.fromOffset(150, 20),
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextWrapped = false,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
	})
	scoreLabel = UiKit.label(panel, {
		Name = "Skor",
		Position = UDim2.fromOffset(150, 6),
		Size = UDim2.fromOffset(190, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
	})

	-- pandangan gawang (sepak bola): kotak luar = area bidik, kotak putih = gawang
	aimView = Instance.new("Frame")
	aimView.Name = "PandanganGawang"
	aimView.Position = UDim2.fromOffset(12, 26)
	aimView.Size = UDim2.fromOffset(190, 76)
	aimView.BackgroundColor3 = rgb(120, 190, 110)
	aimView.BackgroundTransparency = 0.6
	aimView.ClipsDescendants = true
	aimView.Parent = panel
	UiKit.corner(aimView, 10)
	local halfW = FOOT.goalHalf / FOOT.aimRangeX
	local topFrac = (FOOT.goalTop - FOOT.aimLow) / FOOT.aimSpan
	goalRect = Instance.new("Frame")
	goalRect.Name = "Gawang"
	goalRect.AnchorPoint = Vector2.new(0.5, 0)
	goalRect.Position = UDim2.fromScale(0.5, 1 - topFrac)
	goalRect.Size = UDim2.fromScale(halfW, topFrac)
	goalRect.BackgroundColor3 = rgb(255, 255, 255)
	goalRect.BackgroundTransparency = 0.75
	goalRect.Parent = aimView
	local goalStroke = Instance.new("UIStroke")
	goalStroke.Color = Color3.new(1, 1, 1)
	goalStroke.Thickness = 3
	goalStroke.Parent = goalRect
	crosshair = Instance.new("Frame")
	crosshair.Name = "Bidikan"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(18, 18)
	crosshair.BackgroundColor3 = rgb(235, 60, 60)
	crosshair.BackgroundTransparency = 0.25
	crosshair.ZIndex = 3
	crosshair.Parent = aimView
	UiKit.corner(crosshair, 9)
	local crossStroke = Instance.new("UIStroke")
	crossStroke.Color = Color3.new(1, 1, 1)
	crossStroke.Thickness = 3
	crossStroke.Parent = crosshair

	-- batang arah (basket): tengah hijau = tepat ke ring
	aimBar = Instance.new("Frame")
	aimBar.Name = "BatangArah"
	aimBar.Position = UDim2.fromOffset(12, 30)
	aimBar.Size = UDim2.fromOffset(190, 24)
	aimBar.BackgroundColor3 = rgb(225, 232, 240)
	aimBar.BackgroundTransparency = 0.4
	aimBar.Parent = panel
	UiKit.corner(aimBar, 13)
	aimBand = Instance.new("Frame")
	aimBand.AnchorPoint = Vector2.new(0.5, 0.5)
	aimBand.Position = UDim2.fromScale(0.5, 0.5)
	aimBand.Size = UDim2.fromScale(BASK.aimBand, 1)
	aimBand.BackgroundColor3 = COLORS.go
	aimBand.BackgroundTransparency = 0.3
	aimBand.Parent = aimBar
	aimMarker = Instance.new("Frame")
	aimMarker.Name = "Penanda"
	aimMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	aimMarker.Position = UDim2.fromScale(0.5, 0.5)
	aimMarker.Size = UDim2.new(0, 8, 1, 8)
	aimMarker.BackgroundColor3 = rgb(235, 60, 60)
	aimMarker.ZIndex = 3
	aimMarker.Parent = aimBar
	UiKit.corner(aimMarker, 4)

	-- batang tenaga: area hijau = tenaga yang baik
	powerBar = Instance.new("Frame")
	powerBar.Name = "BatangTenaga"
	powerBar.Position = UDim2.fromOffset(214, 30)
	powerBar.Size = UDim2.fromOffset(194, 20)
	powerBar.BackgroundColor3 = rgb(225, 232, 240)
	powerBar.BackgroundTransparency = 0.4
	powerBar.Parent = panel
	UiKit.corner(powerBar, 13)
	powerBand = Instance.new("Frame")
	powerBand.AnchorPoint = Vector2.new(0, 0.5)
	powerBand.BackgroundColor3 = COLORS.go
	powerBand.BackgroundTransparency = 0.3
	powerBand.Parent = powerBar
	powerMarker = Instance.new("Frame")
	powerMarker.Name = "Penanda"
	powerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	powerMarker.Position = UDim2.fromScale(0, 0.5)
	powerMarker.Size = UDim2.new(0, 8, 1, 8)
	powerMarker.BackgroundColor3 = rgb(235, 60, 60)
	powerMarker.ZIndex = 3
	powerMarker.Parent = powerBar
	UiKit.corner(powerMarker, 4)
	UiKit.label(powerBar, {
		Name = "Tulisan",
		Size = UDim2.fromScale(1, 1),
		Text = "TENAGA",
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})

	actionButton = UiKit.button(panel, {
		Name = "TombolBidik",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(214, 56),
		Size = UDim2.fromOffset(194, 46),
		Text = "KUNCI ARAH",
		TextSize = 20,
		BackgroundColor3 = COLORS.go,
	})
	actionButton.Activated:Connect(pressAction)

	exitButton = UiKit.button(panel, {
		Name = "Keluar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 5),
		Size = UDim2.fromOffset(66, 18),
		Text = "Keluar ✖",
		TextSize = 11,
		BackgroundColor3 = COLORS.close,
	})
	exitButton.Activated:Connect(function()
		local s = session
		if s then
			Net.event("SportsLeave"):FireServer(s.token)
		end
		closeGui()
	end)

	resultLabel = UiKit.label(gui, {
		Name = "Hasil",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(420, 64),
		Font = Enum.Font.FredokaOne,
		TextSize = 38,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	UiScale.attach(resultLabel)
end

local function placeBands(mode: string)
	if mode == "football" then
		local lo, hi = FOOT.powerHint[1], FOOT.powerHint[2]
		powerBand.Position = UDim2.fromScale(lo, 0.5)
		powerBand.Size = UDim2.fromScale(hi - lo, 1)
	else
		powerBand.Position = UDim2.fromScale(BASK.sweetPower - BASK.powerBand, 0.5)
		powerBand.Size = UDim2.fromScale(BASK.powerBand * 2, 1)
	end
end

local function onStart(mode: string, token: string, shots: number, camPos: Vector3, lookAt: Vector3)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(
			camera,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(camPos, lookAt) }
		):Play()
	end
	hideOwnTags(true)
	local s: Session = {
		token = token,
		mode = mode,
		shots = shots,
		shot = 1,
		stage = 1,
		values = {},
		stageStart = os.clock(),
		phase = 0,
		waiting = false,
		score = 0,
	}
	session = s
	placeBands(mode)
	showMarkers(s)
	gui.Enabled = true
	resetShot(s)
end

function SportsController.init()
	build()
end

function SportsController.start()
	local remote = Net.event("SportsState")
	remote.OnClientEvent:Connect(function(kind: any, a: any, b: any, c: any, d: any, e: any)
		if kind == "start" then
			if
				type(a) == "string"
				and type(b) == "string"
				and type(c) == "number"
				and typeof(d) == "Vector3"
				and typeof(e) == "Vector3"
			then
				onStart(a, b, c, d, e)
			end
		elseif kind == "result" then
			local s = session
			if s and type(a) == "string" and type(b) == "boolean" and type(c) == "number" then
				s.score = c
				say(a, if b then rgb(255, 255, 255) else rgb(255, 200, 120), 1.4)
				scoreLabel.Text = if s.mode == "football"
					then `Tendangan {s.shot} dari {s.shots} · Gol {s.score}`
					else `Lemparan {s.shot} dari {s.shots} · Masuk {s.score}`
			end
		elseif kind == "ready" then
			local s = session
			if s and type(a) == "number" then
				s.shot = a
				resetShot(s)
			end
		elseif kind == "end" then
			local s = session
			if
				s
				and type(a) == "number"
				and type(b) == "number"
				and type(c) == "number"
				and b >= s.shots
			then
				local text = `Selesai! Skor {a} dari {s.shots}`
				if c > 0 then
					text ..= ` · +{Format.money(c)}`
				end
				session = nil
				restoreCamera()
				panel.Visible = false
				exitButton.Visible = false
				say(text, rgb(255, 235, 120), 3)
				task.delay(3.1, function()
					if session == nil then
						gui.Enabled = false
					end
				end)
			else
				closeGui()
			end
		end
	end)
	RunService.RenderStepped:Connect(render)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space and session and gui.Enabled then
			pressAction()
		end
	end)
end

return SportsController
