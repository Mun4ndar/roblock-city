--!strict
-- FerryService: kapal feri besar (mesh Meshy + tekstur, Workspace.Map.Beach.Pelabuhan.KapalFeriMeshy)
-- bergoyang pelan di air. Model berlabel atribut "Bob" = true ikut bergoyang.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FerryService = {}

local STEP = 1 / 20

function FerryService.init() end

function FerryService.start()
	local pelabuhan = Workspace:WaitForChild("Map"):WaitForChild("Beach"):WaitForChild("Pelabuhan")
	local ship = pelabuhan:WaitForChild("KapalFeriMeshy", 30)
	if ship == nil or not ship:IsA("Model") then
		return
	end
	CollectionService:AddTag(ship, "Kapal")
	local hull = ship.PrimaryPart
	if hull == nil then
		return
	end
	local base = hull.CFrame
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		local t = Workspace:GetServerTimeNow()
		local lift = math.sin(t * 0.9) * 0.35
		local roll = math.sin(t * 0.7) * math.rad(1.2)
		local pitch = math.sin(t * 0.5 + 1) * math.rad(0.7)
		hull.CFrame = base * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, 0, roll)
	end)
end

return FerryService
