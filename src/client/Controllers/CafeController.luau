--!strict
-- CafeController: menu kafe di sisi pemain (Cafe Startduck dan Kafe Kota). Dibuka saat pemain menekan
-- "Lihat Menu" pada barista, pelayan, atau konter (server mengirim CafeConfig.OPEN_EVENT dengan kunci kafe).
-- Pesanan dikirim ke server (CafeConfig.ORDER_FUNC); server memotong uang dan memutar animasi makan/minum.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CafeConfig = require(Shared:WaitForChild("CafeConfig"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local player = Players.LocalPlayer

local CafeController = {}

local rgb = Color3.fromRGB

local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local pending = false
local current = ""

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

local function buildShell(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "KafeMenu2"
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
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.62, 0.8)
	panel.BackgroundColor3 = rgb(255, 248, 232)
	panel.BorderSizePixel = 0
	addCorner(panel, 22)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 260)
	limit.MaxSize = Vector2.new(640, 560)
	limit.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Garis"
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
	title.Parent = panel
	titleLabel = title

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
	listFrame = list

	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

local function fillMenu(venueKey: string)
	local venue = CafeConfig.VENUES[venueKey]
	local list = listFrame
	if venue == nil or list == nil then
		return
	end
	current = venueKey
	if titleLabel then
		titleLabel.Text = `{venue.icon} Menu {venue.title}`
		titleLabel.TextColor3 = venue.accent
	end
	if gui then
		local panel = gui:FindFirstChild("Panel")
		local garis = if panel then panel:FindFirstChild("Garis") else nil
		if garis and garis:IsA("UIStroke") then
			garis.Color = venue.accent
		end
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, entry in venue.menu do
		local item = StoreConfig.get(entry.id)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 66)
		card.BackgroundColor3 = rgb(255, 255, 255)
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		addCorner(card, 14)
		card.Parent = list

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(50, 50)
		icon.Position = UDim2.fromOffset(8, 8)
		icon.BackgroundTransparency = 1
		icon.TextScaled = true
		icon.Text = if entry and entry.icon then entry.icon elseif item then item.icon else "☕"
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -190, 0, 28)
		name.Position = UDim2.fromOffset(66, 6)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = rgb(50, 60, 80)
		name.Text = entry.name
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -190, 0, 22)
		desc.Position = UDim2.fromOffset(66, 36)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextScaled = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextColor3 = rgb(120, 120, 130)
		desc.Text = entry.desc
		desc.Parent = card

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(110, 46)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.BackgroundColor3 = rgb(70, 190, 110)
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextColor3 = rgb(255, 255, 255)
		buy.Text = `Pesan {Format.money(entry.price)}`
		addCorner(buy, 14)
		buy.Parent = card
		buy.Activated:Connect(function()
			if pending then
				return
			end
			pending = true
			setStatus("Memesan...", true)
			local ok, result = pcall(function(): any
				return Net.func(CafeConfig.ORDER_FUNC):InvokeServer(current, index)
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
end

local function openMenu(venueKey: any)
	if type(venueKey) ~= "string" or CafeConfig.VENUES[venueKey] == nil then
		return
	end
	if gui == nil then
		gui = buildShell()
	end
	fillMenu(venueKey)
	setStatus("Pilih menu lalu tekan Pesan.", true)
	if gui then
		gui.Enabled = true
	end
end

function CafeController.init() end

-- Tombol "Lihat Menu" (barista, pelayan, konter) disembunyikan di client ini selama pemain duduk,
-- supaya tidak menutupi pandangan saat menunggu pesanan. Muncul lagi begitu pemain berdiri.
local function isSeated(): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

local function watchMenuPrompts()
	local shown: { [ProximityPrompt]: boolean } = {}
	local hidden: { [ProximityPrompt]: boolean } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.ActionText ~= "Lihat Menu" then
			return
		end
		if isSeated() then
			hidden[prompt] = true
			prompt.Enabled = false
		else
			shown[prompt] = true
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		shown[prompt] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if isSeated() then
				for prompt in shown do
					shown[prompt] = nil
					hidden[prompt] = true
					prompt.Enabled = false
				end
			else
				for prompt in hidden do
					hidden[prompt] = nil
					if prompt.Parent then
						prompt.Enabled = true
					end
				end
			end
		end
	end)
end

function CafeController.start()
	Net.event(CafeConfig.OPEN_EVENT).OnClientEvent:Connect(openMenu)
	watchMenuPrompts()
end

return CafeController
