--!strict
-- VehicleModController: panel Bengkel Modifikasi (cat dan velg mobil).
-- Terbuka dari tombol "Modifikasi mobil" di Halaman Bengkel. Client hanya mengirim pilihan
-- ("paint:3" / "rim:2"); harga, kepemilikan, dan jarak ke bengkel dicek VehicleService.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer

local VehicleModController = {}

local COLORS = {
	panel = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(40, 48, 60),
	subtle = Color3.fromRGB(110, 120, 135),
	accent = Color3.fromRGB(240, 150, 40),
	close = Color3.fromRGB(235, 90, 90),
	card = Color3.fromRGB(240, 244, 250),
}

local gui: ScreenGui
local panel: Frame
local body: Frame
local scale: UIScale
local busy = false

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamMedium
	l.TextColor3 = COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = textSize
	l.TextWrapped = true
	l.Text = text
	l.Position = position
	l.Size = size
	l.Parent = parent
	return l
end

-- Mobil milik pemain yang sedang dikeluarkan (nil jika tidak ada).
local function myVehicle(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	if folder then
		for _, model in folder:GetChildren() do
			if
				model:IsA("Model")
				and model:GetAttribute(VehicleConfig.ATTR_OWNER) == player.UserId
			then
				return model
			end
		end
	end
	return nil
end

local function currentMods(vehicleId: string): (number, number)
	local raw = player:GetAttribute(VehicleConfig.ATTR_MODS)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		local entry = if ok and type(value) == "table" then value[vehicleId] else nil
		if type(entry) == "table" then
			return tonumber(entry.paint) or 0, tonumber(entry.rim) or 0
		end
	end
	return 0, 0
end

local refresh: () -> ()

local function choose(choice: string)
	if busy then
		return
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.VehicleMod):InvokeServer(choice)
	end)
	HudController.toast(
		if ok
				and type(value) == "table"
				and type(value.message) == "string"
			then value.message
			else "Gagal terhubung, coba lagi."
	)
	busy = false
	refresh()
end

local function swatchRow(title: string, y: number, kind: string, list: { Color3 }, current: number)
	label(body, title, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 22), 17, Enum.Font.FredokaOne)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, y + 26)
	row.Size = UDim2.new(1, 0, 0, 84)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(38, 38)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	row.Parent = body
	local function swatch(index: number, color: Color3, text: string)
		local b = Instance.new("TextButton")
		b.Name = kind .. tostring(index)
		b.LayoutOrder = index
		b.BackgroundColor3 = color
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 11
		b.TextColor3 = COLORS.text
		b.Text = text
		corner(b, 10)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = if index == current then 3 else 1
		stroke.Color = if index == current then COLORS.text else Color3.fromRGB(200, 205, 214)
		stroke.Parent = b
		b.Parent = row
		b.Activated:Connect(function()
			choose(kind .. ":" .. tostring(index))
		end)
	end
	swatch(0, COLORS.card, "Asli")
	for index, color in list do
		swatch(index, color, "")
	end
end

function refresh()
	if not panel.Visible then
		return
	end
	body:ClearAllChildren()
	local vehicle = myVehicle()
	local def = if vehicle
		then VehicleConfig.get(vehicle:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
		else nil
	if vehicle == nil or def == nil then
		label(
			body,
			"Keluarkan dulu mobilmu dari menu Kendaraan, lalu parkir di Halaman Bengkel ini.",
			UDim2.new(),
			UDim2.new(1, 0, 0, 60),
			15
		)
		return
	end
	local paint, rim = currentMods(def.id)
	label(body, "Mobil: " .. def.name, UDim2.new(), UDim2.new(1, 0, 0, 22), 15)
	swatchRow(
		"Cat (" .. Format.money(VehicleConfig.PAINT_PRICE) .. ")",
		28,
		"paint",
		VehicleConfig.PAINTS,
		paint
	)
	swatchRow(
		"Velg (" .. Format.money(VehicleConfig.RIM_PRICE) .. ")",
		150,
		"rim",
		VehicleConfig.RIMS,
		rim
	)
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "VehicleModMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -76, 0.5, 0)
	panel.Size = UDim2.fromOffset(330, 320)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.accent
	stroke.Parent = panel
	scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	label(
		panel,
		"Bengkel Modifikasi",
		UDim2.fromOffset(16, 10),
		UDim2.new(1, -70, 0, 32),
		22,
		Enum.Font.FredokaOne
	)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = COLORS.close
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	corner(close, 10)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 50)
	body.Size = UDim2.new(1, -32, 1, -60)
	body.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

function VehicleModController.init()
	buildGui()
end

function VehicleModController.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute(VehicleConfig.ATTR_MOD_PROMPT) then
			panel.Visible = true
			refresh()
		end
	end)
	player:GetAttributeChangedSignal(VehicleConfig.ATTR_MODS):Connect(refresh)
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / 420, 0.6, 1)
		end
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return VehicleModController
