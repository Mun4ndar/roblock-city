--!strict
-- ShopDoorService: pintu kaca berengsel otomatis. Model bertag "AutoDoor" berisi bagian "Engsel*" (Part tak
-- terlihat, di sumbu engsel, atribut OpenAngle dalam derajat) yang di-weld ke daun pintu. Pintu membuka sendiri
-- (berayun) saat ada pemain dalam jarak Radius (atribut model) dan menutup lagi sesudah mereka menjauh.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ShopDoorService = {}

local TAG = "AutoDoor"
local DEFAULT_RADIUS = 11
local CLOSE_DELAY = 1.2
local SWING = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Hinge = { part: BasePart, closed: CFrame, angle: number }
type Door = {
	model: Model,
	hinges: { Hinge },
	center: Vector3,
	radius: number,
	open: boolean,
	lastNear: number,
}

local doors: { [Model]: Door } = {}

local function setup(model: Model)
	if doors[model] then
		return
	end
	local hinges: { Hinge } = {}
	local sum = Vector3.zero
	for _, child in model:GetChildren() do
		local angle = child:GetAttribute("OpenAngle")
		if child:IsA("BasePart") and type(angle) == "number" then
			table.insert(hinges, { part = child, closed = child.CFrame, angle = math.rad(angle) })
			sum += child.Position
		end
	end
	if #hinges == 0 then
		return
	end
	local radius = model:GetAttribute("Radius")
	doors[model] = {
		model = model,
		hinges = hinges,
		center = sum / #hinges,
		radius = if type(radius) == "number" then radius else DEFAULT_RADIUS,
		open = false,
		lastNear = 0,
	}
end

local function swing(door: Door, open: boolean)
	door.open = open
	for _, hinge in door.hinges do
		local goal = if open then hinge.closed * CFrame.Angles(0, hinge.angle, 0) else hinge.closed
		TweenService:Create(hinge.part, SWING, { CFrame = goal }):Play()
	end
end

local function someoneNear(door: Door): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root
			and root:IsA("BasePart")
			and (root.Position - door.center).Magnitude <= door.radius
		then
			return true
		end
	end
	return false
end

function ShopDoorService.init() end

function ShopDoorService.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") then
			setup(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			setup(instance)
		end
	end)
	task.spawn(function()
		while true do
			local now = os.clock()
			for model, door in doors do
				if not model:IsDescendantOf(game) then
					doors[model] = nil
					continue
				end
				if someoneNear(door) then
					door.lastNear = now
					if not door.open then
						swing(door, true)
					end
				elseif door.open and now - door.lastNear > CLOSE_DELAY then
					swing(door, false)
				end
			end
			task.wait(0.2)
		end
	end)
end

return ShopDoorService
