--!strict
-- PlaneController: panel kecil saat pemain duduk di kursi pilot (kecepatan, tinggi, petunjuk).
-- Hanya tampilan; gerak pesawat sepenuhnya diatur PlaneService di server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlaneConfig = require(Shared:WaitForChild("PlaneConfig"))

local player = Players.LocalPlayer

local PlaneController = {}

local gui: ScreenGui
local panel: Frame
local speedLabel: TextLabel
local hintLabel: TextLabel

local function myPlane(): (Model?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local model = if seat and seat.Name == "DriveSeat" then seat.Parent else nil
	if model and model:IsA("Model") and model.Name:sub(1, 6) == "Plane_" then
		local hull = model:FindFirstChild("Hull")
		if hull and hull:IsA("BasePart") then
			return model, hull
		end
	end
	return nil, nil
end

function PlaneController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "PlaneHud"
	gui.ResetOnSpawn = false
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.fromOffset(300, 64)
	panel.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "Speed"
	speedLabel.Size = UDim2.new(1, 0, 0, 36)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Font = Enum.Font.FredokaOne
	speedLabel.TextSize = 22
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.Parent = panel
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Position = UDim2.fromOffset(0, 34)
	hintLabel.Size = UDim2.new(1, 0, 0, 24)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(200, 215, 240)
	hintLabel.Parent = panel
	panel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Baling-baling semua pesawat di sekitar diputar di layar tiap pemain (hanya tampilan): makin kencang
-- pesawatnya makin cepat putarannya; pesawat kosong yang diam tidak berputar.
local baseC0: { [Weld]: CFrame } = {}
local angle = 0

local function spinPropellers(dt: number)
	for _, plane in CollectionService:GetTagged(PlaneConfig.TAG_PLANE) do
		local propeller = plane:FindFirstChild(PlaneConfig.PROPELLER_NAME)
		local weld = if propeller then propeller:FindFirstChild("Putar") else nil
		if weld == nil or not weld:IsA("Weld") then
			continue
		end
		local base = baseC0[weld]
		if base == nil then
			base = weld.C0
			baseC0[weld] = base
			weld.Destroying:Once(function()
				baseC0[weld] = nil
			end)
		end
		local speed = plane:GetAttribute(PlaneConfig.ATTR_SPEED)
		local seat = plane:FindFirstChild("DriveSeat")
		local occupied = seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
		local moving = type(speed) == "number" and math.abs(speed) > 1
		if occupied or moving then
			weld.C0 = base * CFrame.Angles(0, 0, angle)
		end
	end
	angle = (angle + dt * 34) % (math.pi * 2)
end

function PlaneController.start()
	RunService.RenderStepped:Connect(spinPropellers)
	while true do
		task.wait(0.15)
		local model, hull = myPlane()
		if model == nil or hull == nil then
			panel.Visible = false
			continue
		end
		local speed = model:GetAttribute(PlaneConfig.ATTR_SPEED)
		local shown = if type(speed) == "number" then speed else 0
		local height =
			math.max(0, math.floor((hull.Position.Y - 3.7 - PlaneConfig.GROUND_Y) / 3.5 + 0.5))
		speedLabel.Text = string.format("✈️ %d km/j   ⬆ %d m", shown, height)
		hintLabel.Text = if shown < PlaneConfig.TAKEOFF_SPEED
			then "Tahan W untuk menambah kecepatan dan lepas landas"
			else "W naik lebih tinggi · S pelan dan turun · A/D belok"
		panel.Visible = true
		local camera = Workspace.CurrentCamera
		if camera then
			panel.Position = UDim2.new(0.5, 0, 1, if camera.ViewportSize.Y < 500 then -8 else -16)
		end
	end
end

return PlaneController
