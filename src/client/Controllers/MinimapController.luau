--!strict
-- MinimapController: peta kecil bundar di kanan bawah. Utara selalu di atas, pemain di tengah (titik
-- biru dengan sorot arah). Menampilkan laut, daratan, jalan, pin tempat penting, rute GPS (garis biru
-- lewat jalan), rumah (merah muda), dan tujuan tugas (kuning). Penanda di luar jangkauan menempel di
-- tepi lingkaran sebagai arah. Ketuk peta = buka peta penuh; tombol +/- = perbesar/perkecil.
-- Gambar peta dipakai bersama dengan peta penuh lewat Util/MapCanvas.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = script.Parent.Parent:WaitForChild("Util")
local UiScale = require(Util:WaitForChild("UiScale"))
local MapCanvas = require(Util:WaitForChild("MapCanvas"))
local JobController = require(script.Parent:WaitForChild("JobController"))
local HouseUiController = require(script.Parent:WaitForChild("HouseUiController"))
local NavController = require(script.Parent:WaitForChild("NavController"))

local player = Players.LocalPlayer

local MinimapController = {}

local rgb = Color3.fromRGB
local SIZE = 172 -- piksel pada ukuran penuh
local HALF = SIZE / 2
local SCALES = { 0.32, 0.2, 0.11, 0.06 } -- piksel per stud, dari dekat ke jauh
local UPDATE_SECONDS = 0.05

type Marker = { dot: GuiObject, position: () -> Vector3? }

local gui: ScreenGui
local frame: TextButton
local clip: CanvasGroup
local markers: { Marker } = {}
local scaleIndex = 2
local elapsed = 0
local drawnVersion = -1
local drawnIndex = -1

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function applyScale()
	MapCanvas.setScale(SCALES[scaleIndex])
	MapCanvas.setPinMode(0.65, SCALES[scaleIndex] >= 0.25, false, false)
end

-- Ambil kembali kanvas (setelah peta penuh ditutup).
function MinimapController.reclaim()
	local canvas = MapCanvas.getCanvas()
	canvas.Parent = clip
	applyScale()
	drawnVersion = -1
end

local function addMarker(color: Color3, icon: string, position: () -> Vector3?)
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(20, 20)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Visible = false
	corner(dot, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = dot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = icon
	label.TextSize = 12
	label.Font = Enum.Font.GothamMedium
	label.Parent = dot
	dot.Parent = frame
	table.insert(markers, { dot = dot, position = position })
end

local function roundButton(text: string, offsetY: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(0, -6, 0.5, offsetY)
	b.Size = UDim2.fromOffset(28, 28)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.TextColor3 = MapCanvas.COLORS.ink
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 20
	b.AutoButtonColor = true
	corner(b, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = MapCanvas.COLORS.ink
	stroke.Thickness = 2
	stroke.Transparency = 0.6
	stroke.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = frame
	return b
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Minimap"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1

	frame = Instance.new("TextButton")
	frame.Name = "Peta"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -44, 1, -14)
	frame.Size = UDim2.fromOffset(SIZE, SIZE)
	frame.BackgroundColor3 = MapCanvas.COLORS.sea
	frame.AutoButtonColor = false
	frame.Text = ""
	corner(frame, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = MapCanvas.COLORS.ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	UiScale.attach(frame)
	frame.Parent = gui

	-- bayangan lembut
	local shadow = Instance.new("Frame")
	shadow.Name = "Bayangan"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 5)
	shadow.Size = UDim2.new(1, 10, 1, 10)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.78
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	corner(shadow, UDim.new(0.5, 0))
	shadow.Parent = frame

	clip = Instance.new("CanvasGroup")
	clip.Name = "Isi"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ZIndex = 1
	corner(clip, UDim.new(0.5, 0))
	clip.Parent = frame

	-- cincin putih tipis di dalam bingkai gelap
	local ring = Instance.new("Frame")
	ring.Name = "Cincin"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -2, 1, -2)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 8
	corner(ring, UDim.new(0.5, 0))
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.new(1, 1, 1)
	ringStroke.Thickness = 2.5
	ringStroke.Parent = ring
	ring.Parent = frame

	-- lencana utara
	local north = Instance.new("TextLabel")
	north.Name = "Utara"
	north.AnchorPoint = Vector2.new(0.5, 0.5)
	north.Position = UDim2.fromScale(0.5, 0.02)
	north.Size = UDim2.fromOffset(22, 22)
	north.BackgroundColor3 = MapCanvas.COLORS.ink
	north.TextColor3 = Color3.new(1, 1, 1)
	north.Font = Enum.Font.FredokaOne
	north.TextSize = 13
	north.Text = "U"
	north.ZIndex = 9
	corner(north, UDim.new(0.5, 0))
	north.Parent = frame

	local canvas = MapCanvas.getCanvas()
	canvas.Parent = clip
	applyScale()

	local arrow = MapCanvas.makeArrow(frame, 34)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.ZIndex = 7
	for _, child in arrow:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 7
		end
	end
	arrow.Name = "Pemain"

	roundButton("+", -18, function()
		scaleIndex = math.max(1, scaleIndex - 1)
		applyScale()
	end)
	roundButton("-", 18, function()
		scaleIndex = math.min(#SCALES, scaleIndex + 1)
		applyScale()
	end)

	frame.Activated:Connect(function()
		local MapUi = require(script.Parent:WaitForChild("MapUiController")) :: any
		MapUi.open()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Di layar sentuh, tombol lompat Roblox ada di kanan bawah: taruh peta di sebelah kirinya.
local function place()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touch = if playerGui then playerGui:FindFirstChild("TouchGui") else nil
	local jump = if touch then touch:FindFirstChild("JumpButton", true) else nil
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0 then
		local screen = gui.AbsoluteSize
		local right = screen.X - jump.AbsolutePosition.X + 44
		frame.Position = UDim2.new(1, -math.max(44, right), 1, -14)
	else
		frame.Position = UDim2.new(1, -44, 1, -14)
	end
end

local function redrawRoute()
	local route = NavController.getRoute()
	local index = NavController.getRouteIndex()
	local version = NavController.getVersion()
	if version == drawnVersion and index == drawnIndex then
		return
	end
	drawnVersion, drawnIndex = version, index
	if route == nil then
		MapCanvas.showRoute(nil)
		return
	end
	local points: { Vector3 } = {}
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if root then
		table.insert(points, Vector3.new(root.Position.X, 0, root.Position.Z))
	end
	for i = index + 1, #route.points do
		table.insert(points, route.points[i])
	end
	MapCanvas.showRoute(points)
end

local function update()
	if not frame.Visible then
		return
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if root == nil then
		return
	end
	local canvas = MapCanvas.getCanvas()
	if canvas.Parent ~= clip then
		return -- peta penuh sedang memakai kanvas
	end
	local scale = SCALES[scaleIndex]
	local here = root.Position
	canvas.Position = UDim2.fromOffset(HALF - here.X * scale, HALF - here.Z * scale)
	local look = root.CFrame.LookVector
	local arrow = frame:FindFirstChild("Pemain") :: Frame
	arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
	redrawRoute()
	local limit = HALF - 12
	for _, marker in markers do
		local position = marker.position()
		if position == nil then
			marker.dot.Visible = false
			continue
		end
		local dx, dz = (position.X - here.X) * scale, (position.Z - here.Z) * scale
		local length = math.sqrt(dx * dx + dz * dz)
		if length > limit then
			dx, dz = dx / length * limit, dz / length * limit -- di luar jangkauan: tempel di tepi
		end
		marker.dot.Position = UDim2.fromOffset(HALF + dx, HALF + dz)
		marker.dot.Visible = true
	end
end

function MinimapController.setVisible(visible: boolean)
	frame.Visible = visible
end

function MinimapController.init()
	buildGui()
end

function MinimapController.start()
	addMarker(rgb(255, 92, 120), "🏠", function(): Vector3?
		return HouseUiController.getHomePosition()
	end)
	addMarker(rgb(255, 196, 0), "★", function(): Vector3?
		return JobController.getTarget()
	end)
	addMarker(MapCanvas.COLORS.route, "📍", function(): Vector3?
		return NavController.getTargetPosition()
	end)
	NavController.onChanged(function()
		local target = NavController.getTarget()
		MapCanvas.setSelected(if target then target.id else nil)
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= UPDATE_SECONDS then
			elapsed = 0
			update()
		end
	end)
	while true do
		place()
		task.wait(1)
	end
end

return MinimapController
