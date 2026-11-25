--!strict
-- JetSkiController: tampilan tantangan cincin Jet Ski (waktu, cincin ke berapa, rekor) dan sorotan
-- cincin berikutnya. Hanya tampilan: semua keputusan (cincin lolos, waktu, hadiah) dari JetSkiService.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JetSkiConfig = require(Shared:WaitForChild("JetSkiConfig"))
local Net = require(Shared:WaitForChild("Net"))

local JetSkiController = {}

local COLOR_IDLE = Color3.fromRGB(80, 220, 255)
local COLOR_FINISH = Color3.fromRGB(255, 205, 40)
local COLOR_NEXT = Color3.fromRGB(90, 255, 120)
local COLOR_DONE = Color3.fromRGB(150, 160, 175)

local gui: ScreenGui
local panel: Frame
local timeLabel: TextLabel
local ringLabel: TextLabel
local bestLabel: TextLabel
local toast: TextLabel

local running = false
local startedAt = 0
local total = 0
local limit = JetSkiConfig.TIME_LIMIT
local nextRing = 1
local bestTime = 0
local timerConnection: RBXScriptConnection? = nil

local function label(name: string, size: number, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = UDim2.new(1, 0, 0, height)
	l.Position = UDim2.fromOffset(0, y)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = panel
	return l
end

local function ringsFolder(): Instance?
	local map = Workspace:FindFirstChild("Map")
	return (if map then map:FindFirstChild("TantanganJetSki") else nil)
		or Workspace:FindFirstChild("TantanganJetSki")
end

-- state: pewarnaan tiap cincin menurut kemajuan (0 = tidak ada tantangan)
local function paintRings()
	local folder = ringsFolder()
	if folder == nil then
		return
	end
	for _, model in folder:GetChildren() do
		local index = model:GetAttribute("Index")
		if type(index) == "number" then
			local color: Color3
			local transparency: number
			if not running then
				color = if index == total or index == #JetSkiConfig.COURSE
					then COLOR_FINISH
					else COLOR_IDLE
				transparency = 0.35
			elseif index < nextRing then
				color, transparency = COLOR_DONE, 0.8
			elseif index == nextRing then
				color, transparency = COLOR_NEXT, 0
			else
				color = if index == #JetSkiConfig.COURSE then COLOR_FINISH else COLOR_IDLE
				transparency = 0.55
			end
			for _, seg in model:GetChildren() do
				if seg:IsA("BasePart") then
					seg.Color = color
					seg.Transparency = transparency
				end
			end
		end
	end
end

local function showToast(text: string, color: Color3)
	toast.Text = text
	toast.TextColor3 = color
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	toast.Visible = true
	local token = os.clock()
	toast:SetAttribute("Token", token)
	task.delay(3.5, function()
		if toast:GetAttribute("Token") == token then
			TweenService
				:Create(
					toast,
					TweenInfo.new(0.5),
					{ TextTransparency = 1, TextStrokeTransparency = 1 }
				)
				:Play()
		end
	end)
end

local function updateRingText()
	ringLabel.Text = string.format("Cincin %d / %d", math.min(nextRing, total), total)
end

local function stopTimer()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
end

local function endRunUi()
	running = false
	stopTimer()
	panel.Visible = false
	paintRings()
end

local function handle(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "start" then
		running = true
		startedAt = os.clock()
		total = if type(payload.total) == "number" then payload.total else 0
		limit = if type(payload.limit) == "number" then payload.limit else JetSkiConfig.TIME_LIMIT
		bestTime = if type(payload.best) == "number" then payload.best else 0
		nextRing = 1
		bestLabel.Text = if bestTime > 0
			then string.format("Rekormu: %.1f dtk", bestTime)
			else "Belum ada rekor"
		updateRingText()
		panel.Visible = true
		stopTimer()
		timerConnection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - startedAt
			timeLabel.Text = string.format("%.1f", elapsed)
			timeLabel.TextColor3 = if elapsed > limit - 15
				then Color3.fromRGB(255, 120, 110)
				else Color3.new(1, 1, 1)
		end)
		paintRings()
		showToast("Mulai! Lewati cincin hijau!", COLOR_NEXT)
	elseif kind == "ring" then
		nextRing = (if type(payload.index) == "number" then payload.index else nextRing) + 1
		updateRingText()
		paintRings()
		showToast(string.format("Bagus! +%d", payload.reward or 0), COLOR_NEXT)
	elseif kind == "finish" then
		local time = if type(payload.time) == "number" then payload.time else 0
		local text = string.format("SELESAI! %.1f dtk  +%d koin", time, payload.total or 0)
		if payload.newBest == true then
			text ..= "\nREKOR BARU!"
		end
		endRunUi()
		showToast(text, COLOR_FINISH)
	elseif kind == "fail" then
		endRunUi()
		showToast(
			if type(payload.reason) == "string" then payload.reason else "Tantangan berhenti.",
			Color3.fromRGB(255, 150, 140)
		)
	end
end

function JetSkiController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "JetSkiHud"
	gui.ResetOnSpawn = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 70)
	panel.Size = UDim2.fromOffset(230, 112)
	panel.BackgroundColor3 = Color3.fromRGB(20, 50, 90)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	timeLabel = label("Waktu", 40, 2, 50)
	timeLabel.Text = "0.0"
	ringLabel = label("Cincin", 20, 52, 28)
	bestLabel = label("Rekor", 16, 80, 26)
	bestLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	panel.Parent = gui

	toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.3, 0)
	toast.Size = UDim2.fromOffset(420, 70)
	toast.BackgroundTransparency = 1
	toast.Font = Enum.Font.FredokaOne
	toast.TextSize = 30
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function JetSkiController.start()
	Net.event(JetSkiConfig.REMOTE_RUN).OnClientEvent:Connect(handle)
	-- cincin tampil ketika area sudah termuat (StreamingEnabled): beri warna saat muncul
	task.spawn(function()
		while true do
			if not running then
				paintRings()
			end
			task.wait(5)
		end
	end)
end

return JetSkiController
