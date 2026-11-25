--!strict
-- KlinikController: mini-game ketuk singkat untuk langkah periksa dokter di rumah sakit.
-- Server (ClinicService) mengirim KlinikMulai; setelah selesai/waktu habis client mengirim
-- KlinikSelesai(token, jumlahKetuk). Server yang menilai (jumlah, waktu, jarak), bukan client.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local KlinikController = {}

local rgb = Color3.fromRGB
local rng = Random.new()

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local countLabel: TextLabel
local timerFill: Frame
local arena: Frame
local target: TextButton
local session = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "KlinikMinigame"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.48)
	panel.Size = UDim2.fromOffset(340, 300)
	panel.BackgroundColor3 = rgb(255, 255, 255)
	panel.Parent = gui
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(40, 180, 160)
	stroke.Thickness = 3
	stroke.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 36)
	titleLabel.Position = UDim2.fromOffset(10, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = rgb(30, 110, 100)
	titleLabel.Parent = panel

	countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, -20, 0, 24)
	countLabel.Position = UDim2.fromOffset(10, 46)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextScaled = true
	countLabel.TextColor3 = rgb(80, 90, 105)
	countLabel.Parent = panel

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -28, 0, 10)
	track.Position = UDim2.fromOffset(14, 76)
	track.BackgroundColor3 = rgb(225, 232, 240)
	track.Parent = panel
	corner(track, 5)
	timerFill = Instance.new("Frame")
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = rgb(64, 190, 100)
	timerFill.Parent = track
	corner(timerFill, 5)

	arena = Instance.new("Frame")
	arena.Name = "Arena"
	arena.Position = UDim2.fromOffset(14, 96)
	arena.Size = UDim2.new(1, -28, 1, -110)
	arena.BackgroundColor3 = rgb(228, 246, 242)
	arena.ClipsDescendants = true
	arena.Parent = panel
	corner(arena, 14)

	target = Instance.new("TextButton")
	target.Name = "SasaranKetuk"
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.Size = UDim2.fromOffset(70, 70)
	target.BackgroundColor3 = rgb(255, 255, 255)
	target.Font = Enum.Font.GothamBold
	target.TextScaled = true
	target.AutoButtonColor = true
	target.Text = ""
	target.Parent = arena
	corner(target, 35)
	local ts = Instance.new("UIStroke")
	ts.Color = rgb(40, 180, 160)
	ts.Thickness = 3
	ts.Parent = target

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function randomSpot(): UDim2
	return UDim2.fromScale(rng:NextNumber(0.15, 0.85), rng:NextNumber(0.2, 0.8))
end

local function start(token: string, icon: string, title: string, taps: number, seconds: number)
	session += 1
	local mine = session
	local count = 0
	local finished = false
	titleLabel.Text = title
	countLabel.Text = `0 / {taps}`
	target.Text = icon
	target.Position = randomSpot()
	target.Visible = true
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = rgb(64, 190, 100)
	gui.Enabled = true
	TweenService:Create(
		timerFill,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	):Play()

	local remote = Net.event(Net.Names.KlinikSelesai)
	local function finish(message: string, ok: boolean)
		if finished or session ~= mine then
			return
		end
		finished = true
		remote:FireServer(token, count)
		target.Visible = false
		titleLabel.Text = message
		countLabel.Text = if ok then "Hebat!" else "Coba lagi ya"
		task.delay(1.1, function()
			if session == mine then
				gui.Enabled = false
			end
		end)
	end

	local connection
	connection = target.Activated:Connect(function()
		if finished or session ~= mine then
			connection:Disconnect()
			return
		end
		count += 1
		countLabel.Text = `{count} / {taps}`
		if count >= taps then
			connection:Disconnect()
			finish("Berhasil! ✅", true)
		else
			target.Position = randomSpot()
		end
	end)

	task.spawn(function()
		local startedAt = os.clock()
		while not finished and session == mine and os.clock() - startedAt < seconds do
			task.wait(1.3)
			if not finished and session == mine then
				target.Position = randomSpot()
			end
		end
		if not finished and session == mine then
			connection:Disconnect()
			finish("Waktu habis", false)
		end
	end)
end

function KlinikController.init()
	build()
end

function KlinikController.start()
	Net.event(Net.Names.KlinikMulai).OnClientEvent
		:Connect(function(token: any, icon: any, title: any, taps: any, seconds: any)
			if
				type(token) == "string"
				and type(icon) == "string"
				and type(title) == "string"
				and type(taps) == "number"
				and type(seconds) == "number"
			then
				start(token, icon, title, math.clamp(taps, 1, 12), math.clamp(seconds, 3, 20))
			end
		end)
end

return KlinikController
