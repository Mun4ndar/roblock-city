--!strict
--[[
	BikeRiderService: pengendara motor duduk dengan benar. Saat pemain (karakter R15) duduk di kursi pengemudi
	motor (model kendaraan punya bagian GripL/GripR/PegL/PegR dari VehicleBuilder), dua tangan dipasang ke
	stang (IKControl, target GripL/GripR) dan dua kaki ke pijakan (PegL/PegR). IKControl dibuat di Humanoid
	sehingga ikut terreplikasi dan tampil sama di semua pemain; dihapus saat turun.
	Penumpang boncengan memakai pose duduk bawaan.
]]

local Players = game:GetService("Players")

local BikeRiderService = {}

local TAG = "BikeIK"

local function clear(hum: Humanoid)
	for _, child in hum:GetChildren() do
		if child:GetAttribute(TAG) then
			child:Destroy()
		end
	end
end

local function addIK(hum: Humanoid, char: Model, rootName: string, endName: string, target: BasePart, weight: number)
	local root = char:FindFirstChild(rootName)
	local effector = char:FindFirstChild(endName)
	if not (root and effector and root:IsA("BasePart") and effector:IsA("BasePart")) then
		return
	end
	local ik = Instance.new("IKControl")
	ik.Name = "Pose" .. endName
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = root
	ik.EndEffector = effector
	ik.Target = target
	ik.Weight = weight
	ik.SmoothTime = 0.08
	ik:SetAttribute(TAG, true)
	ik.Parent = hum
end

local function mount(hum: Humanoid, seat: Seat | VehicleSeat)
	local model = seat.Parent
	local char = hum.Parent
	if model == nil or char == nil or not char:IsA("Model") then
		return
	end
	if hum.RigType ~= Enum.HumanoidRigType.R15 or seat.Name ~= "DriveSeat" then
		return
	end
	local gl, gr = model:FindFirstChild("GripL", true), model:FindFirstChild("GripR", true)
	local pl, pr = model:FindFirstChild("PegL", true), model:FindFirstChild("PegR", true)
	if not (gl and gr and gl:IsA("BasePart") and gr:IsA("BasePart")) then
		return
	end
	addIK(hum, char, "LeftUpperArm", "LeftHand", gl, 1)
	addIK(hum, char, "RightUpperArm", "RightHand", gr, 1)
	if pl and pr and pl:IsA("BasePart") and pr:IsA("BasePart") then
		addIK(hum, char, "LeftUpperLeg", "LeftFoot", pl, 1)
		addIK(hum, char, "RightUpperLeg", "RightFoot", pr, 1)
	end
end

local function watch(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum == nil or not hum:IsA("Humanoid") then
		return
	end
	hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
		clear(hum)
		local seat = hum.SeatPart
		if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
			mount(hum, seat)
		end
	end)
end

function BikeRiderService.init() end

function BikeRiderService.start()
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(watch, player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return BikeRiderService
