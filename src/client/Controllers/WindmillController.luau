--!strict
-- WindmillController: memutar baling-baling kincir angin (hanya tampilan, di client).
-- Part/Model baling bertag "WindmillBlades" dengan atribut:
--   SpinAxis  : "X" | "Y" | "Z" (sumbu putar di ruang lokal baling, bawaan "Z")
--   SpinSpeed : radian per detik (bawaan 0.6; negatif = arah sebaliknya)
-- Baling hanya diputar saat kamera berada dalam VIEW_RANGE stud, supaya tidak membebani.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WindmillController = {}

local TAG = "WindmillBlades"
local VIEW_RANGE = 450
local DEFAULT_SPEED = 0.6

local blades: { [Instance]: { base: CFrame, angle: number } } = {}

local function pivotOf(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function register(instance: Instance)
	local pivot = pivotOf(instance)
	if pivot and blades[instance] == nil then
		blades[instance] = { base = pivot, angle = 0 }
	end
end

local function axisRotation(axis: string, angle: number): CFrame
	if axis == "X" then
		return CFrame.Angles(angle, 0, 0)
	elseif axis == "Y" then
		return CFrame.Angles(0, angle, 0)
	end
	return CFrame.Angles(0, 0, angle)
end

function WindmillController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		blades[instance] = nil
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local eye = camera.CFrame.Position
		for instance, state in blades do
			if instance.Parent == nil then
				blades[instance] = nil
				continue
			end
			if (state.base.Position - eye).Magnitude > VIEW_RANGE then
				continue
			end
			local speed = instance:GetAttribute("SpinSpeed")
			state.angle += dt * (if type(speed) == "number" then speed else DEFAULT_SPEED)
			local axis = instance:GetAttribute("SpinAxis")
			local cf = state.base * axisRotation(if type(axis) == "string" then axis else "Z", state.angle)
			if instance:IsA("Model") then
				instance:PivotTo(cf)
			elseif instance:IsA("BasePart") then
				instance.CFrame = cf
			end
		end
	end)
end

return WindmillController
