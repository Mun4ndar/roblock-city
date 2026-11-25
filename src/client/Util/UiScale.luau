--!strict
-- UiScale: mengecilkan HUD di layar kecil (HP) supaya tidak saling menutupi.
-- Satu faktor untuk semua elemen HUD, dihitung dari ukuran layar.
--   UiScale.attach(elemen)            -- elemen mengecil ke arah AnchorPoint-nya
--   UiScale.sideButton(tombol, urutan) -- tumpukan tombol menu di tepi kiri
--   UiScale.onChange(fn)               -- dipanggil sekarang dan tiap layar berubah

local Workspace = game:GetService("Workspace")

local UiScale = {}

local BASE_SIZE = Vector2.new(1100, 620) -- layar seukuran ini ke atas: ukuran penuh
local MIN_FACTOR = 0.7
local SIDE_BUTTON_STEP = 50 -- jarak antar tombol menu kiri pada ukuran penuh

local factor = 1
local listeners: { (number) -> () } = {}
local cameraConnection: RBXScriptConnection? = nil

local function recompute()
	local camera = Workspace.CurrentCamera
	local value = 1
	if camera then
		local size = camera.ViewportSize
		value = math.clamp(math.min(size.X / BASE_SIZE.X, size.Y / BASE_SIZE.Y), MIN_FACTOR, 1)
	end
	if value ~= factor then
		factor = value
		for _, listener in listeners do
			listener(factor)
		end
	end
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
	end
	recompute()
end

function UiScale.factor(): number
	return factor
end

function UiScale.onChange(listener: (number) -> ())
	table.insert(listeners, listener)
	listener(factor)
end

function UiScale.attach(element: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Name = "HudScale"
	scale.Parent = element
	UiScale.onChange(function(value: number)
		scale.Scale = value
	end)
end

-- Tombol menu di tepi kiri layar; index 0 = paling atas.
function UiScale.sideButton(button: GuiObject, index: number)
	button.AnchorPoint = Vector2.new(0, 0.5)
	UiScale.attach(button)
	UiScale.onChange(function(value: number)
		button.Position = UDim2.new(0, 10, 0.42, index * SIDE_BUTTON_STEP * value)
	end)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

return UiScale
