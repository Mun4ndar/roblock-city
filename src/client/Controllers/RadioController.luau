--!strict
-- RadioController: tombol 📻 kecil di tepi kanan, muncul hanya saat pemain duduk di kursi pengemudi.
-- Tiap ketukan memilih stasiun berikutnya (koplo -> dangdut -> campursari -> gamelan -> mati).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local UiKit = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiKit"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer
local RadioController = {}

local button: TextButton
local busy = false

local function currentVehicle(): Model?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if seat == nil or not seat:IsA("VehicleSeat") then
		return nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("VehicleId") == nil do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

local function refreshLabel()
	local model = currentVehicle()
	local id = if model then model:GetAttribute(IndonesiaConfig.ATTR_RADIO) else nil
	local station = IndonesiaConfig.station(id)
	button.Text = if station then station.icon else "📻"
	button.BackgroundColor3 = if station then UiKit.COLORS.go else Color3.fromRGB(70, 78, 96)
end

local function onActivated()
	if busy then
		return
	end
	local model = currentVehicle()
	if model == nil then
		return
	end
	local id = model:GetAttribute(IndonesiaConfig.ATTR_RADIO)
	local nextId = ""
	if type(id) ~= "string" or id == "" then
		nextId = IndonesiaConfig.STATIONS[1].id
	else
		for index, station in IndonesiaConfig.STATIONS do
			if station.id == id then
				local following = IndonesiaConfig.STATIONS[index + 1]
				nextId = if following then following.id else ""
			end
		end
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func("RadioSet"):InvokeServer(nextId)
	end)
	busy = false
	if
		ok
		and type(value) == "table"
		and type(value.message) == "string"
		and value.message ~= ""
	then
		HudController.toast(value.message)
	end
	task.wait(0.2)
	refreshLabel()
end

function RadioController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	button = UiKit.button(gui, {
		Name = "TombolRadio",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.64, 0),
		Size = UDim2.fromOffset(46, 46),
		Text = "📻",
		TextSize = 22,
		BackgroundColor3 = Color3.fromRGB(70, 78, 96),
		Visible = false,
	})
	UiScale.attach(button)
	button.Activated:Connect(onActivated)
end

function RadioController.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local model = currentVehicle()
			button.Visible = model ~= nil
			if model then
				refreshLabel()
			end
		end
	end)
end

return RadioController
