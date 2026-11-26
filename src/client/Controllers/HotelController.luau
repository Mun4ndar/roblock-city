--!strict
--[[
	HotelController: sisi client Hotel Bintang Kota.
	  * Pemilih lantai lift (panel kecil, tombol L dan 2..8) saat prompt panel kabin ditekan (HotelLiftMenu).
	  * Lampu indikator lift (part bertag HotelLamp, atribut Idx dan Level) menyala menurut atribut pemain
	    "HotelLamp"; tiap pemain melihat lantainya sendiri (ilusi: koridor sama untuk semua lantai).
	  * Label bertag HotelLabel (atribut Pattern, "{N}" = nomor lantai pemain "HotelFloor") ikut berganti.
	  * Tombol Bangun saat pemain sedang tidur di kasur kamar (atribut "HotelTidur").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local HotelConfig = require(Shared:WaitForChild("HotelConfig"))
local DayNightController = require(script.Parent:WaitForChild("DayNightController"))
local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))

local HotelController = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB

local LAMP_ON = rgb(255, 214, 90)
local LAMP_OFF = rgb(110, 116, 124)

-- ------------------------------------------------------------------ lampu dan label

local function activeLamp(level: string?): number
	local value = player:GetAttribute("HotelLamp")
	if typeof(value) == "number" then
		return value
	end
	return if level == "lobi" then 1 else 0
end

local function paintLamp(lamp: Instance)
	if not lamp:IsA("BasePart") then
		return
	end
	local idx = lamp:GetAttribute("Idx")
	local level = lamp:GetAttribute("Level")
	local on = idx == activeLamp(if typeof(level) == "string" then level else nil)
	lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	lamp.Color = if on then LAMP_ON else LAMP_OFF
	for _, gui in lamp:GetChildren() do
		local label = if gui:IsA("SurfaceGui") then gui:FindFirstChildOfClass("TextLabel") else nil
		if label then
			label.TextColor3 = if on then rgb(40, 30, 10) else Color3.new(1, 1, 1)
		end
	end
end

local function floorText(): string
	local value = player:GetAttribute("HotelFloor")
	if typeof(value) == "number" and value > 1 then
		return tostring(math.floor(value))
	end
	return "2"
end

local function paintLabel(inst: Instance)
	if not inst:IsA("TextLabel") then
		return
	end
	local pattern = inst:GetAttribute("Pattern")
	if typeof(pattern) == "string" then
		inst.Text = (string.gsub(pattern, "{N}", floorText()))
	end
end

local function repaintAll()
	for _, lamp in CollectionService:GetTagged("HotelLamp") do
		paintLamp(lamp)
	end
	for _, label in CollectionService:GetTagged("HotelLabel") do
		paintLabel(label)
	end
end

-- ------------------------------------------------------------------ UI

local gui: ScreenGui
local panel: Frame
local buttons: { TextButton } = {}
local wakeButton: TextButton
local dim: Frame
local current = 1

local function refreshButtons()
	for index, button in buttons do
		local here = index == current
		button.BackgroundColor3 = if here then UiKit.COLORS.go else rgb(52, 56, 64)
		button.Text = HotelConfig.LABELS[index]
	end
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "HotelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "PemilihLantai"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 214)
	panel.BackgroundColor3 = rgb(30, 34, 42)
	panel.Visible = false
	UiKit.corner(panel, 16)
	panel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(208, 168, 86)
	stroke.Thickness = 2
	stroke.Parent = panel
	UiKit.label(panel, {
		Name = "Judul",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 30),
		Text = "Pilih Lantai",
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextColor3 = rgb(255, 226, 150),
	})
	local close = UiKit.button(panel, {
		Name = "Tutup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(34, 30),
		Text = "✖",
		BackgroundColor3 = UiKit.COLORS.close,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local grid = Instance.new("Frame")
	grid.Name = "Tombol"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(16, 52)
	grid.Size = UDim2.new(1, -32, 1, -68)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(56, 56)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	-- lantai teratas di baris atas, seperti panel lift sungguhan (4 kolom: 5 6 7 8 / L 2 3 4 -> dibalik)
	local order = { 5, 6, 7, 8, 1, 2, 3, 4 }
	for position, index in order do
		local button = UiKit.button(grid, {
			Name = "Lantai" .. HotelConfig.LABELS[index],
			Text = HotelConfig.LABELS[index],
			TextSize = 26,
			LayoutOrder = position,
		})
		button.Activated:Connect(function()
			panel.Visible = false
			Net.event(Net.Names.HotelLiftGo):FireServer(index)
		end)
		buttons[index] = button
	end

	dim = Instance.new("Frame")
	dim.Name = "Tidur"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(8, 12, 30)
	dim.BackgroundTransparency = 0.55
	dim.BorderSizePixel = 0
	dim.Visible = false
	dim.Active = false
	dim.Parent = gui
	wakeButton = UiKit.button(dim, {
		Name = "Bangun",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(190, 52),
		Text = "☀️ Bangun",
		TextSize = 22,
		BackgroundColor3 = UiKit.COLORS.warn,
	})
	wakeButton.Activated:Connect(function()
		Net.event(Net.Names.HotelWake):FireServer()
	end)
	UiKit.label(dim, {
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(300, 60),
		Text = "Zzz...",
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.FredokaOne,
		TextSize = 44,
		TextColor3 = rgb(190, 220, 255),
	})
end

local function updateSleep()
	dim.Visible = player:GetAttribute("HotelTidur") == true
end

-- ------------------------------------------------------------------ di dalam hotel

-- Kotak bangunan hotel (dunia). Di dalamnya cahaya diredupkan. (Mode kamera Zoom diatur HotelService
-- di server, karena client tidak boleh mengubah DevCameraOcclusionMode.)
local INSIDE_MIN = Vector3.new(219, -4, -81)
local INSIDE_MAX = Vector3.new(321, 95, -23)

local function isInside(): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = root.Position
	return p.X >= INSIDE_MIN.X
		and p.X <= INSIDE_MAX.X
		and p.Y >= INSIDE_MIN.Y
		and p.Y <= INSIDE_MAX.Y
		and p.Z >= INSIDE_MIN.Z
		and p.Z <= INSIDE_MAX.Z
end

local function watchInside()
	local insideNow = false
	local timer = 0
	RunService.Heartbeat:Connect(function(dt: number)
		timer += dt
		if timer >= 0.2 then
			timer = 0
			local now = isInside()
			if now ~= insideNow then
				insideNow = now
			end
		end
		local target = if insideNow then 1 else 0
		local current = DayNightController.interior
		if current ~= target then
			DayNightController.interior = current + (target - current) * math.min(1, dt * 3)
			if math.abs(DayNightController.interior - target) < 0.01 then
				DayNightController.interior = target
			end
		end
	end)
end

function HotelController.init() end

function HotelController.start()
	buildUi()
	Net.event(Net.Names.HotelLiftMenu).OnClientEvent:Connect(function(lamp: unknown)
		current = if typeof(lamp) == "number" then lamp else 1
		refreshButtons()
		panel.Visible = true
	end)
	player:GetAttributeChangedSignal("HotelLamp"):Connect(repaintAll)
	player:GetAttributeChangedSignal("HotelFloor"):Connect(repaintAll)
	player:GetAttributeChangedSignal("HotelTidur"):Connect(updateSleep)
	CollectionService:GetInstanceAddedSignal("HotelLamp"):Connect(paintLamp)
	CollectionService:GetInstanceAddedSignal("HotelLabel"):Connect(paintLabel)
	repaintAll()
	updateSleep()
	watchInside()
end

return HotelController
