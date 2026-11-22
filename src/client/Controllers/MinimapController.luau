--!strict
-- MinimapController: peta kecil di kanan bawah. Utara selalu di atas; pemain di tengah (panah merah
-- menunjukkan arah hadap). Menampilkan daratan, jalan, tempat penting, rumah pemain, tujuan tugas
-- (kuning), dan tujuan GPS (biru). Penanda yang di luar jangkauan menempel di tepi peta sebagai arah.
-- Ketuk peta untuk memperbesar/memperkecil jangkauan. Data jalan dan daratan dari Shared.MapData.
-- Di HP, peta digeser ke kiri tombol lompat supaya tidak tertutup jari.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapData = require(Shared:WaitForChild("MapData"))
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))

local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))
local JobController = require(script.Parent:WaitForChild("JobController"))
local HouseUiController = require(script.Parent:WaitForChild("HouseUiController"))

local player = Players.LocalPlayer

local MinimapController = {}

local rgb = Color3.fromRGB
local SIZE = 150 -- piksel pada ukuran penuh
local SCALES = { 0.2, 0.09 } -- piksel per stud: dekat, jauh
local UPDATE_SECONDS = 0.05
local COLORS = {
	sea = rgb(112, 196, 236),
	land = rgb(150, 208, 132),
	road = rgb(250, 250, 246),
	border = rgb(34, 46, 80),
	player = rgb(230, 60, 60),
	task = rgb(255, 204, 0),
	gps = rgb(60, 130, 255),
	home = rgb(40, 170, 140),
}

type Marker = { dot: GuiObject, position: () -> Vector3? }

local gui: ScreenGui
local frame: TextButton
local canvas: Frame
local arrow: Frame
local markers: { Marker } = {}
local scaleIndex = 1
local elapsed = 0

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Kanvas digambar pada 1 piksel = 1 stud lalu dikecilkan dengan UIScale, jadi ganti jangkauan
-- cukup mengubah satu angka.
local canvasScale: UIScale

local function rect(
	x: number,
	z: number,
	sx: number,
	sz: number,
	rotation: number,
	color: Color3,
	z_: number
)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, z)
	f.Size = UDim2.fromOffset(sx, sz)
	f.Rotation = rotation
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z_
	f.Parent = canvas
end

local function buildCanvas()
	local step = MapData.STEP
	for _, run in MapData.LAND :: { { number } } do
		local x0, x1, z = run[1], run[2], run[3]
		rect((x0 + x1) / 2, z, x1 - x0 + step, step + 1, 0, COLORS.land, 1)
	end
	for _, road in MapData.ROADS :: { { number } } do
		rect(road[1], road[2], road[3], road[4], -road[5], COLORS.road, 2)
	end
	-- tempat penting (ikon tetap terbaca karena ukurannya dilawan skala kanvas, lihat applyScale)
	local function icon(position: Vector3, text: string)
		local l = Instance.new("TextLabel")
		l.Name = "Ikon"
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromOffset(position.X, position.Z)
		l.Size = UDim2.fromOffset(16, 16)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 13
		l.Text = text
		l.ZIndex = 3
		local s = Instance.new("UIScale")
		s.Parent = l
		l.Parent = canvas
	end
	for _, landmark in MissionConfig.LANDMARKS do
		local position = MissionConfig.placePosition(landmark.place)
		if position then
			icon(position, landmark.icon)
		end
	end
	for _, extra in MissionConfig.EXTRA_PLACES do
		icon(extra.position, extra.icon)
	end
end

local function applyScale()
	local scale = SCALES[scaleIndex]
	canvasScale.Scale = scale
	for _, child in canvas:GetChildren() do
		if child.Name == "Ikon" then
			local s = child:FindFirstChildOfClass("UIScale")
			if s then
				s.Scale = 1 / scale
			end
		end
	end
end

local function addMarker(color: Color3, size: number, position: () -> Vector3?)
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Visible = false
	corner(dot, size)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = dot
	dot.Parent = frame
	table.insert(markers, { dot = dot, position = position })
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
	frame.Position = UDim2.new(1, -10, 1, -10)
	frame.Size = UDim2.fromOffset(SIZE, SIZE)
	frame.BackgroundColor3 = COLORS.sea
	frame.AutoButtonColor = false
	frame.Text = ""
	corner(frame, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.border
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	UiScale.attach(frame)
	frame.Parent = gui

	-- CanvasGroup memotong isi (termasuk jalan yang diputar) mengikuti sudut bulat peta.
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Isi"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ZIndex = 1
	corner(clip, 16)
	clip.Parent = frame

	canvas = Instance.new("Frame")
	canvas.Name = "Kanvas"
	canvas.Size = UDim2.fromOffset(0, 0)
	canvas.BackgroundTransparency = 1
	canvasScale = Instance.new("UIScale")
	canvasScale.Parent = canvas
	canvas.Parent = clip

	local north = Instance.new("TextLabel")
	north.Name = "Utara"
	north.AnchorPoint = Vector2.new(0.5, 0)
	north.Position = UDim2.new(0.5, 0, 0, 2)
	north.Size = UDim2.fromOffset(16, 14)
	north.BackgroundTransparency = 1
	north.Font = Enum.Font.FredokaOne
	north.TextSize = 12
	north.TextColor3 = COLORS.border
	north.Text = "U"
	north.ZIndex = 6
	north.Parent = frame

	-- panah pemain di tengah
	arrow = Instance.new("Frame")
	arrow.Name = "Pemain"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(18, 18)
	arrow.BackgroundTransparency = 1
	arrow.ZIndex = 7
	for _, bar in { { 9, 9, 14, 0 }, { 5.5, 6, 10, 38 }, { 12.5, 6, 10, -38 } } do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(bar[1], bar[2])
		f.Size = UDim2.fromOffset(4, bar[3])
		f.Rotation = bar[4]
		f.BackgroundColor3 = COLORS.player
		f.BorderSizePixel = 0
		f.ZIndex = 7
		corner(f, 2)
		f.Parent = arrow
	end
	arrow.Parent = frame

	buildCanvas()
	applyScale()
	frame.Activated:Connect(function()
		scaleIndex = scaleIndex % #SCALES + 1
		applyScale()
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
		local right = screen.X - jump.AbsolutePosition.X + 10
		frame.Position = UDim2.new(1, -math.max(10, right), 1, -10)
	else
		frame.Position = UDim2.new(1, -10, 1, -10)
	end
end

local function update()
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if root == nil then
		return
	end
	local scale = SCALES[scaleIndex]
	local here = root.Position
	local half = frame.AbsoluteSize.X / 2 / math.max(UiScale.factor(), 0.01)
	canvas.Position = UDim2.fromOffset(half - here.X * scale, half - here.Z * scale)
	local look = root.CFrame.LookVector
	arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
	local limit = half - 9
	for _, marker in markers do
		local position = marker.position()
		if position == nil then
			marker.dot.Visible = false
			continue
		end
		local dx, dz = (position.X - here.X) * scale, (position.Z - here.Z) * scale
		local over = math.max(math.abs(dx), math.abs(dz)) / limit
		if over > 1 then
			dx, dz = dx / over, dz / over -- di luar jangkauan: tempel di tepi sebagai arah
		end
		marker.dot.Position = UDim2.fromOffset(half + dx, half + dz)
		marker.dot.Visible = true
	end
end

function MinimapController.init()
	buildGui()
end

function MinimapController.start()
	local PhoneController = require(script.Parent:WaitForChild("PhoneController")) :: any
	addMarker(COLORS.home, 9, function(): Vector3?
		return HouseUiController.getHomePosition()
	end)
	addMarker(COLORS.gps, 10, function(): Vector3?
		return PhoneController.getGpsTarget()
	end)
	addMarker(COLORS.task, 11, function(): Vector3?
		return JobController.getTarget()
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
