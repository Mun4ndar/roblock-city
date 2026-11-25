--!strict
-- ExhibitController: panel info untuk Pameran Alat Pemadam (belakang Pos Damkar).
-- Tiap dudukan pameran adalah Part bertag "ExhibitStand" dengan atribut Title, Info, Tip dan sebuah
-- ProximityPrompt (dibuat di peta). Menekan tombolnya membuka panel; panel menutup sendiri bila pemain menjauh.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local ExhibitController = {}

local TAG = "ExhibitStand"
local CLOSE_DISTANCE = 20

local frame: Frame? = nil
local titleLabel: TextLabel? = nil
local infoLabel: TextLabel? = nil
local tipLabel: TextLabel? = nil
local current: BasePart? = nil

local function label(parent: Instance, name: string, size: UDim2, pos: UDim2, textSize: number, color: Color3, font: Enum.Font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.TextSize = textSize
	l.TextColor3 = color
	l.Font = font
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = ""
	l.Parent = parent
	return l
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExhibitGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local f = Instance.new("Frame")
	f.Name = "ExhibitPanel"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.55)
	f.Size = UDim2.fromOffset(420, 300)
	f.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	f.Visible = false
	f.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(210, 40, 40)
	stroke.Thickness = 4
	stroke.Parent = f

	local head = Instance.new("Frame")
	head.Name = "Header"
	head.Size = UDim2.new(1, 0, 0, 44)
	head.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
	head.Parent = f
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 12)
	hc.Parent = head

	titleLabel = label(head, "Judul", UDim2.new(1, -60, 1, 0), UDim2.fromOffset(14, 0), 22, Color3.new(1, 1, 1), Enum.Font.FredokaOne)
	;(titleLabel :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center
	infoLabel = label(f, "Fungsi", UDim2.new(1, -28, 0, 140), UDim2.fromOffset(14, 54), 18, Color3.fromRGB(40, 40, 50), Enum.Font.GothamMedium)
	tipLabel = label(f, "Tahukah", UDim2.new(1, -28, 0, 70), UDim2.fromOffset(14, 202), 16, Color3.fromRGB(150, 90, 0), Enum.Font.GothamMedium)

	local close = Instance.new("TextButton")
	close.Name = "TutupPameran"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -6, 0.5, 0)
	close.Size = UDim2.fromOffset(36, 32)
	close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.TextSize = 20
	close.Font = Enum.Font.GothamBold
	close.TextColor3 = Color3.fromRGB(210, 40, 40)
	close.Parent = head
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.Activated:Connect(function()
		f.Visible = false
		current = nil
	end)

	UiScale.attach(f)
	frame = f
end

local function show(stand: BasePart)
	if not frame then
		return
	end
	current = stand
	;(titleLabel :: TextLabel).Text = tostring(stand:GetAttribute("Title") or stand.Name)
	;(infoLabel :: TextLabel).Text = tostring(stand:GetAttribute("Info") or "")
	local tip = stand:GetAttribute("Tip")
	;(tipLabel :: TextLabel).Text = if tip then "Tahukah kamu? " .. tostring(tip) else ""
	frame.Visible = true
end

function ExhibitController.start()
	build()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local stand = prompt.Parent
		if stand and stand:IsA("BasePart") and CollectionService:HasTag(stand, TAG) then
			show(stand)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local stand = current
			if stand and frame and frame.Visible then
				local char = Players.LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not stand.Parent or (root and root:IsA("BasePart") and (root.Position - stand.Position).Magnitude > CLOSE_DISTANCE) then
					frame.Visible = false
					current = nil
				end
			end
		end
	end)
end

return ExhibitController
