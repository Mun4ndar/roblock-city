--!strict
-- LombaController: tampilan lomba 17-an. Balap karung: penghitung waktu di atas layar.
-- Panjat pinang: tombol TAP besar + batang kemajuan. Semua aturan ada di LombaService (server).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))

local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local COLORS = UiKit.COLORS
local LombaController = {}

local gui: ScreenGui
local timerLabel: TextLabel
local tapFrame: Frame
local barFill: Frame
local raceStart = 0
local raceLimit = 0
local climbHeight = 1
local renderConnection: RBXScriptConnection? = nil

local function stopTimer()
	timerLabel.Visible = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function startTimer(start: number, limit: number)
	raceStart = start
	raceLimit = limit
	timerLabel.Visible = true
	if renderConnection == nil then
		renderConnection = RunService.Heartbeat:Connect(function()
			local elapsed = math.max(0, Workspace:GetServerTimeNow() - raceStart)
			timerLabel.Text =
				`🏃 Balap Karung  {string.format("%.1f", elapsed)} / {raceLimit} dtk`
		end)
	end
end

local function updateBar()
	local height = player:GetAttribute(IndonesiaConfig.ATTR_CLIMB)
	local fraction = if type(height) == "number" then math.clamp(height / climbHeight, 0, 1) else 0
	barFill.Size = UDim2.new(1, 0, fraction, 0)
	barFill.Position = UDim2.new(0, 0, 1 - fraction, 0)
end

function LombaController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "LombaGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 14
	gui.Parent = player:WaitForChild("PlayerGui")

	timerLabel = UiKit.label(gui, {
		Name = "Penghitung",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(300, 36),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(200, 30, 40),
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Visible = false,
	})
	UiKit.corner(timerLabel, 12)
	UiScale.attach(timerLabel)

	tapFrame = Instance.new("Frame")
	tapFrame.Name = "PanjatPinang"
	tapFrame.AnchorPoint = Vector2.new(0.5, 1)
	tapFrame.Position = UDim2.new(0.5, 0, 1, -24)
	tapFrame.Size = UDim2.fromOffset(300, 120)
	tapFrame.BackgroundTransparency = 1
	tapFrame.Visible = false
	tapFrame.Parent = gui
	UiScale.attach(tapFrame)

	local tap = UiKit.button(tapFrame, {
		Name = "Tap",
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.fromOffset(180, 90),
		Text = "TAP! 👆",
		TextSize = 30,
		BackgroundColor3 = Color3.fromRGB(220, 50, 60),
	})
	tap.Activated:Connect(function()
		Net.event("LombaTap"):FireServer()
	end)
	local leave = UiKit.button(tapFrame, {
		Name = "Turun",
		Position = UDim2.fromOffset(100, 94),
		Size = UDim2.fromOffset(100, 26),
		Text = "Turun",
		TextSize = 13,
		BackgroundColor3 = COLORS.locked,
	})
	leave.Activated:Connect(function()
		Net.event("LombaLeave"):FireServer()
	end)
	local bar = Instance.new("Frame")
	bar.Name = "Batang"
	bar.Position = UDim2.fromOffset(250, 0)
	bar.Size = UDim2.fromOffset(18, 90)
	bar.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	UiKit.corner(bar, 9)
	bar.Parent = tapFrame
	barFill = Instance.new("Frame")
	barFill.Name = "Isi"
	barFill.BackgroundColor3 = COLORS.go
	UiKit.corner(barFill, 9)
	barFill.Parent = bar
end

function LombaController.start()
	Net.event("LombaState").OnClientEvent:Connect(function(kind: any, a: any, b: any)
		if kind == "race" and type(a) == "number" and type(b) == "number" then
			startTimer(a, b)
		elseif kind == "raceEnd" then
			stopTimer()
		elseif kind == "climb" and type(a) == "number" then
			climbHeight = a
			tapFrame.Visible = true
			updateBar()
		elseif kind == "climbEnd" then
			tapFrame.Visible = false
		end
	end)
	player:GetAttributeChangedSignal(IndonesiaConfig.ATTR_CLIMB):Connect(updateBar)
end

return LombaController
