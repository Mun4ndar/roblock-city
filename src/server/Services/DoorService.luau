--!strict
--[[
	DoorService: pintu kaca berengsel yang terbuka sendiri saat pemain mendekat dan menutup lagi
	setelah pemain menjauh. Server yang menggerakkan (Heartbeat), tidak pernah menghalangi pemain
	(pintu tidak bertabrakan), jadi masuk dan keluar selalu bebas.

	Pintu = Model atau BasePart yang diberi tag "SwingDoor" dan atribut:
	  HingeX, HingeY, HingeZ : titik engsel (dunia) pada posisi tertutup; porosnya sumbu Y
	  OpenDeg                : sudut buka (derajat, boleh negatif)
	  Radius                 : jarak pemain yang membuka pintu (default 9)
	Posisi tertutup dicatat dari pivot pintu saat layanan mulai.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DoorService = {}

local TAG = "SwingDoor"
local SPEED = 260 -- derajat per detik

type Door = {
	instance: Instance,
	closedCFrame: CFrame,
	hinge: Vector3,
	openRad: number,
	radius: number,
	angle: number, -- 0..1
	target: number,
}

local doors: { Door } = {}

local function register(instance: Instance)
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		return
	end
	for _, door in doors do
		if door.instance == instance then
			return
		end
	end
	local hx, hy, hz =
		instance:GetAttribute("HingeX"),
		instance:GetAttribute("HingeY"),
		instance:GetAttribute("HingeZ")
	local open = instance:GetAttribute("OpenDeg")
	if
		type(hx) ~= "number"
		or type(hy) ~= "number"
		or type(hz) ~= "number"
		or type(open) ~= "number"
	then
		return
	end
	local pivot = if instance:IsA("Model")
		then instance:GetPivot()
		else (instance :: BasePart).CFrame
	local radius = instance:GetAttribute("Radius")
	table.insert(doors, {
		instance = instance,
		closedCFrame = pivot,
		hinge = Vector3.new(hx, hy, hz),
		openRad = math.rad(open),
		radius = if type(radius) == "number" then radius else 9,
		angle = 0,
		target = 0,
	})
end

local function apply(door: Door)
	local rotation = CFrame.new(door.hinge)
		* CFrame.Angles(0, door.openRad * door.angle, 0)
		* CFrame.new(-door.hinge)
	local cf = rotation * door.closedCFrame
	if door.instance:IsA("Model") then
		(door.instance :: Model):PivotTo(cf)
	else
		(door.instance :: BasePart).CFrame = cf
	end
end

function DoorService.init() end

function DoorService.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)

	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 0.2 then
			timer = 0
			local positions: { Vector3 } = {}
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					table.insert(positions, root.Position)
				end
			end
			for _, door in doors do
				local near = false
				for _, position in positions do
					if (position - door.hinge).Magnitude <= door.radius then
						near = true
						break
					end
				end
				door.target = if near then 1 else 0
			end
		end
		for _, door in doors do
			if door.instance.Parent ~= nil and door.angle ~= door.target then
				local step = math.rad(SPEED) * dt / math.max(math.abs(door.openRad), 0.01)
				if door.angle < door.target then
					door.angle = math.min(door.target, door.angle + step)
				else
					door.angle = math.max(door.target, door.angle - step)
				end
				apply(door)
			end
		end
	end)
end

return DoorService
