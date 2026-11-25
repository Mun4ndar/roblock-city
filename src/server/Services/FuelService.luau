--!strict
-- FuelService: bensin mobil. Berkurang saat dikemudikan (ditentukan server dari kecepatan),
-- diisi di pompa SPBU lewat ProximityPrompt dengan uang. Semua dicek di server: jarak mobil ke pompa,
-- kepemilikan mobil, uang, dan jeda. Kendaraan dinas tidak memakai bensin (tanpa atribut Fuel).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local FuelConfig = require(Shared:WaitForChild("FuelConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local FuelService = {}

-- sisa bensin tiap mobil selama server hidup, supaya keluar-masuk garasi tidak mengisi ulang gratis
local saved: { [number]: { [string]: number } } = {}
local lastUse: { [Player]: number } = {}

local function ownerId(model: Instance): number?
	local value = model:GetAttribute(VehicleConfig.ATTR_OWNER)
	if type(value) == "number" then
		return value
	end
	return nil
end

local function setupVehicle(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local def = VehicleConfig.get(model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
	local uid = ownerId(model)
	if def == nil or def.job or uid == nil then
		return
	end
	local memory = saved[uid]
	local fuel = if memory and memory[def.id] then memory[def.id] else FuelConfig.START
	model:SetAttribute(FuelConfig.ATTR, fuel)
end

local function ownVehicle(player: Player): Model?
	for _, model in CollectionService:GetTagged(VehicleConfig.TAG_VEHICLE) do
		if
			model:IsA("Model")
			and ownerId(model) == player.UserId
			and type(model:GetAttribute(FuelConfig.ATTR)) == "number"
		then
			return model
		end
	end
	return nil
end

local function drainLoop()
	while true do
		task.wait(1)
		for _, model in CollectionService:GetTagged(VehicleConfig.TAG_VEHICLE) do
			local fuel = model:GetAttribute(FuelConfig.ATTR)
			if type(fuel) ~= "number" or not model:IsA("Model") then
				continue
			end
			local seat = model:FindFirstChild("DriveSeat")
			local chassis = model.PrimaryPart
			if seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil and chassis then
				local velocity = chassis.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				local rate = FuelConfig.DRAIN_IDLE + velocity.Magnitude * FuelConfig.DRAIN_PER_SPEED
				fuel = math.max(0, fuel - rate)
				model:SetAttribute(FuelConfig.ATTR, fuel)
			end
			local uid = ownerId(model)
			local id = model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID)
			if uid and type(id) == "string" then
				local memory = saved[uid]
				if memory == nil then
					memory = {}
					saved[uid] = memory
				end
				memory[id] = fuel
			end
		end
	end
end

local function refuel(player: Player, pump: BasePart)
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < FuelConfig.REFUEL_COOLDOWN then
		return
	end
	lastUse[player] = now
	local vehicle = ownVehicle(player)
	if vehicle == nil or vehicle.PrimaryPart == nil then
		EconomyService.notify(player, "Keluarkan mobilmu dulu dari menu Kendaraan, lalu parkir di dekat pompa.")
		return
	end
	if (vehicle.PrimaryPart.Position - pump.Position).Magnitude > FuelConfig.VEHICLE_RANGE then
		EconomyService.notify(player, "Parkir mobilmu lebih dekat ke pompa ya.")
		return
	end
	local fuel = vehicle:GetAttribute(FuelConfig.ATTR) :: number
	local need = FuelConfig.TANK - fuel
	if need < 1 then
		EconomyService.notify(player, "Tangki mobilmu sudah penuh!")
		return
	end
	local money = EconomyService.getMoney(player) or 0
	local units = math.min(need, math.floor(money / FuelConfig.PRICE_PER_UNIT))
	if units < 1 then
		EconomyService.notify(player, "Uangmu belum cukup untuk membeli bensin.")
		return
	end
	local cost = math.ceil(units * FuelConfig.PRICE_PER_UNIT)
	if not EconomyService.trySpend(player, cost, "Bensin") then
		EconomyService.notify(player, "Uangmu belum cukup untuk membeli bensin.")
		return
	end
	vehicle:SetAttribute(FuelConfig.ATTR, math.min(FuelConfig.TANK, fuel + units))
	if units >= need then
		EconomyService.notify(player, `Tangki penuh! Bayar ${cost}.`)
	else
		EconomyService.notify(player, `Bensin terisi sebagian (${cost}). Uangmu habis.`)
	end
end

local function setupPump(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Isi bensin"
	prompt.ObjectText = `Pompa bensin (${FuelConfig.PRICE_PER_UNIT} per 1%)`
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = FuelConfig.PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		refuel(player, part)
	end)
	prompt.Parent = part
end

function FuelService.init() end

function FuelService.start()
	for _, model in CollectionService:GetTagged(VehicleConfig.TAG_VEHICLE) do
		setupVehicle(model)
	end
	CollectionService:GetInstanceAddedSignal(VehicleConfig.TAG_VEHICLE):Connect(setupVehicle)
	for _, part in CollectionService:GetTagged(FuelConfig.TAG_PUMP) do
		setupPump(part)
	end
	CollectionService:GetInstanceAddedSignal(FuelConfig.TAG_PUMP):Connect(setupPump)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
		saved[player.UserId] = nil
	end)
	task.spawn(drainLoop)
end

return FuelService
