--!strict
-- BeaconController: lampu atap kendaraan dinas (ambulans, pemadam, patroli).
-- Lampu berkedip bergantian selama kursi pengemudi terisi. Hanya tampilan,
-- jadi dijalankan di client supaya tidak membebani server.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local BeaconController = {}

local BLINK_SECONDS = 0.35

local function isDriven(lamp: Instance): boolean
	local model = lamp:FindFirstAncestorOfClass("Model")
	local seat = if model then model:FindFirstChild("DriveSeat") else nil
	return seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
end

function BeaconController.start()
	local phase = 0
	while true do
		task.wait(BLINK_SECONDS)
		phase = 1 - phase
		for _, lamp in CollectionService:GetTagged(VehicleConfig.TAG_BEACON) do
			if lamp:IsA("BasePart") then
				local lit = isDriven(lamp)
					and lamp:GetAttribute(VehicleConfig.ATTR_BEACON_PHASE) == phase
				lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end
end

return BeaconController
