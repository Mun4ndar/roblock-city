--!strict
-- BeachLifeController: sisi pemain untuk pantai yang hidup.
--   * bola voli: digambar lokal dari waktu server (Config.ballAt) saat kamera dekat lapangan, bergerak
--     mulus antara dua pemain voli NPC tanpa lalu lintas jaringan.
--   * menu Kafe Pantai: dibuka saat pemain menekan "Lihat Menu" pada pelayan. Pesanan dikirim ke server
--     (CafeOrder); server yang memotong uang dan memutar animasi makan/minum.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("BeachLifeConfig"))
local Net = require(Shared:WaitForChild("Net"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local player = Players.LocalPlayer

local BeachLifeController = {}

local rgb = Color3.fromRGB

-- ---------------------------------------------------------------- bola voli

local function makeBall(): Part
	local ball = Instance.new("Part")
	ball.Name = "BolaVoliPantai"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(Config.BALL_SIZE, Config.BALL_SIZE, Config.BALL_SIZE)
	ball.Color = rgb(252, 248, 236)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = true
	-- dua pita warna di bola, seperti bola voli pantai
	for index, color in { rgb(255, 196, 40), rgb(60, 140, 235) } do
		local band = Instance.new("Part")
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(0.12, Config.BALL_SIZE * 0.92, Config.BALL_SIZE * 0.92)
		band.Color = color
		band.Material = Enum.Material.SmoothPlastic
		band.Massless = true
		band.CanCollide = false
		band.CanQuery = false
		band.CanTouch = false
		band.CFrame = ball.CFrame * CFrame.Angles(0, 0, 0) * CFrame.new(if index == 1 then -0.35 else 0.35, 0, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ball
		weld.Part1 = band
		weld.Parent = band
		band.Parent = ball
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(rgb(255, 255, 255))
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Parent = ball
	return ball
end

local function startBall()
	local folder = Workspace:WaitForChild(Config.FOLDER, 60)
	if folder == nil then
		return
	end
	local ball = makeBall()
	local shown = false
	RunService.RenderStepped:Connect(function()
		local epoch = folder:GetAttribute("Epoch")
		local camera = Workspace.CurrentCamera
		if type(epoch) ~= "number" or camera == nil then
			return
		end
		local near = (camera.CFrame.Position - Config.COURT_CENTER).Magnitude < Config.RENDER_RANGE
		local t = Workspace:GetServerTimeNow() - epoch
		if not near or t < 0 then
			if shown then
				shown = false
				ball.Parent = nil
			end
			return
		end
		local position = Config.ballAt(t)
		ball.CFrame = CFrame.new(position) * CFrame.Angles(t * 6, t * 3, 0)
		if not shown then
			shown = true
			ball.Parent = Workspace
		end
	end)
end

-- ---------------------------------------------------------------- menu kafe

local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local pending = false

local function setStatus(text: string, good: boolean)
	if statusLabel then
		statusLabel.Text = text
		statusLabel.TextColor3 = if good then rgb(30, 140, 70) else rgb(200, 70, 60)
	end
end

local function closeMenu()
	if gui then
		gui.Enabled = false
	end
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function buildMenu(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "KafeMenu"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 30
	screen.Enabled = false

	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.BorderSizePixel = 0
	dim.Activated:Connect(closeMenu)
	dim.Parent = screen

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.62, 0.8)
	panel.BackgroundColor3 = rgb(255, 248, 232)
	panel.BorderSizePixel = 0
	addCorner(panel, 22)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 260)
	limit.MaxSize = Vector2.new(640, 520)
	limit.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(255, 176, 64)
	stroke.Thickness = 4
	stroke.Parent = panel
	panel.Parent = screen

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 0, 54)
	title.Position = UDim2.fromOffset(20, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = rgb(230, 110, 40)
	title.Text = "🍹 Menu Kafe Pantai"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(46, 46)
	close.Position = UDim2.new(1, -58, 0, 12)
	close.BackgroundColor3 = rgb(255, 110, 100)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = rgb(255, 255, 255)
	close.Text = "X"
	addCorner(close, 23)
	close.Activated:Connect(closeMenu)
	close.Parent = panel

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -40, 0, 28)
	status.Position = UDim2.new(0, 20, 1, -36)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = rgb(90, 90, 90)
	status.Text = "Pilih menu lalu tekan Pesan."
	status.Parent = panel
	statusLabel = status

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -112)
	list.Position = UDim2.fromOffset(16, 68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	for _, id in Config.MENU do
		local item = StoreConfig.get(id)
		if item == nil then
			continue
		end
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 66)
		card.BackgroundColor3 = rgb(255, 255, 255)
		card.BorderSizePixel = 0
		addCorner(card, 14)
		card.Parent = list

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(50, 50)
		icon.Position = UDim2.fromOffset(8, 8)
		icon.BackgroundTransparency = 1
		icon.TextScaled = true
		icon.Text = item.icon
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -190, 0, 28)
		name.Position = UDim2.fromOffset(66, 6)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = rgb(50, 60, 80)
		name.Text = item.name
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -190, 0, 22)
		desc.Position = UDim2.fromOffset(66, 36)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextScaled = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextColor3 = rgb(120, 120, 130)
		desc.Text = item.desc
		desc.Parent = card

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(110, 46)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.BackgroundColor3 = rgb(70, 190, 110)
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextColor3 = rgb(255, 255, 255)
		buy.Text = `Pesan ${Config.price(id)}`
		addCorner(buy, 14)
		buy.Parent = card
		buy.Activated:Connect(function()
			if pending then
				return
			end
			pending = true
			setStatus("Memesan...", true)
			local ok, result = pcall(function(): any
				return Net.func(Config.ORDER_FUNC):InvokeServer(id)
			end)
			pending = false
			if ok and type(result) == "table" then
				setStatus(tostring(result.message), result.ok == true)
				if result.ok == true then
					task.delay(0.7, closeMenu) -- tutup supaya animasi makan/minum terlihat
				end
			else
				setStatus("Gagal memesan, coba lagi.", false)
			end
		end)
	end

	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

local function openMenu()
	if gui == nil then
		gui = buildMenu()
	end
	setStatus("Pilih menu lalu tekan Pesan.", true)
	if gui then
		gui.Enabled = true
	end
end

function BeachLifeController.init() end

function BeachLifeController.start()
	task.spawn(startBall)
	Net.event(Config.OPEN_EVENT).OnClientEvent:Connect(openMenu)
end

return BeachLifeController
