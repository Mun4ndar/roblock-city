--!strict
-- HudController: menampilkan saldo uang + tombol hadiah harian.
-- Client hanya MEMBACA saldo (atribut "Money" yang diset server) dan MEMINTA
-- hadiah; keputusan & jumlah sepenuhnya di server.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Types"))

local player = Players.LocalPlayer

local HudController = {}

local COLORS = {
	panel = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(40, 48, 60),
	money = Color3.fromRGB(46, 160, 67),
	button = Color3.fromRGB(255, 184, 0),
	toastBg = Color3.fromRGB(40, 48, 60),
}

local gui: ScreenGui
local moneyLabel: TextLabel
local rewardButton: TextButton
local toastLabel: TextLabel

local displayedMoney = 0
local tweenValue: NumberValue
local busy = false

-- ---------------------------------------------------------------- builder UI

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Panel uang di tengah atas (kiri atas dipakai jendela chat Roblox).
	local panel = Instance.new("Frame")
	panel.Name = "MoneyPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(0.5, -6, 0, 8)
	panel.Size = UDim2.fromOffset(200, 48)
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.1
	corner(panel, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLORS.money
	stroke.Parent = panel
	panel.Parent = gui

	moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "Amount"
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Size = UDim2.new(1, -20, 1, 0)
	moneyLabel.Position = UDim2.fromOffset(10, 0)
	moneyLabel.Font = Enum.Font.FredokaOne
	moneyLabel.TextScaled = true
	moneyLabel.TextColor3 = COLORS.money
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "..."
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 30
	textLimit.Parent = moneyLabel
	moneyLabel.Parent = panel

	rewardButton = Instance.new("TextButton")
	rewardButton.Name = "DailyReward"
	rewardButton.Position = UDim2.new(0.5, 6, 0, 12)
	rewardButton.Size = UDim2.fromOffset(190, 40)
	rewardButton.BackgroundColor3 = COLORS.button
	rewardButton.Font = Enum.Font.FredokaOne
	rewardButton.TextSize = 20
	rewardButton.TextColor3 = COLORS.text
	rewardButton.Text = "🎁 Hadiah Harian"
	rewardButton.AutoButtonColor = true
	corner(rewardButton, 12)
	rewardButton.Parent = gui

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.new(0.5, 0, 1, -120)
	toastLabel.Size = UDim2.fromOffset(380, 44)
	toastLabel.BackgroundColor3 = COLORS.toastBg
	toastLabel.BackgroundTransparency = 0.15
	toastLabel.TextColor3 = Color3.new(1, 1, 1)
	toastLabel.Font = Enum.Font.FredokaOne
	toastLabel.TextSize = 20
	toastLabel.TextWrapped = true
	toastLabel.Visible = false
	corner(toastLabel, 12)
	local toastSize = Instance.new("UISizeConstraint")
	toastSize.MaxSize = Vector2.new(380, 60)
	toastSize.Parent = toastLabel
	toastLabel.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- ---------------------------------------------------------------- perilaku

local toastToken = 0
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3, function()
		if token == toastToken then
			toastLabel.Visible = false
		end
	end)
end

-- Dipakai controller lain untuk menampilkan pesan singkat.
function HudController.toast(message: string)
	showToast(message)
end

local function setMoney(target: number, animate: boolean)
	if not animate then
		displayedMoney = target
		tweenValue.Value = target
		moneyLabel.Text = Format.money(target)
		return
	end
	local tween = TweenService:Create(
		tweenValue,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = target }
	)
	tween:Play()
	displayedMoney = target

	-- Efek "pop" kecil saat uang berubah.
	local panel = moneyLabel.Parent :: Frame
	local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = panel
	scale.Scale = 1.12
	TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 1 }):Play()
end

local function onMoneyAttributeChanged()
	local value = player:GetAttribute("Money")
	if type(value) == "number" then
		local firstTime = moneyLabel.Text == "..."
		if value ~= displayedMoney or firstTime then
			setMoney(value, not firstTime)
		end
	end
end

local function onRewardClicked()
	if busy then
		return
	end
	busy = true
	local remote = Net.func(Net.Names.ClaimDailyReward)
	local ok, result = pcall(function(): Types.DailyRewardResult
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" and type(result.message) == "string" then
		showToast(result.message)
	else
		showToast("Gagal terhubung, coba lagi.")
	end
	task.wait(1)
	busy = false
end

-- ---------------------------------------------------------------- bootstrap

function HudController.init()
	tweenValue = Instance.new("NumberValue")
	buildGui()
	tweenValue.Changed:Connect(function(value: number)
		moneyLabel.Text = Format.money(value)
	end)
end

function HudController.start()
	player:GetAttributeChangedSignal("Money"):Connect(onMoneyAttributeChanged)
	onMoneyAttributeChanged()
	rewardButton.Activated:Connect(onRewardClicked)

	local notify = Net.event(Net.Names.Notify)
	notify.OnClientEvent:Connect(function(message: any)
		if type(message) == "string" then
			showToast(message)
		end
	end)
end

return HudController
