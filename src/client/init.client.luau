--!strict
-- ROBLOCK CITY: titik masuk client. Bootstrap dua fase: init() lalu start().

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"HudController",
	"DayNightController",
	"VehicleController",
	"VehicleUiController",
	"VehicleModController",
	"BeaconController",
	"VehicleEffectsController",
	"JobController",
	"JobUiController",
	"HouseUiController",
	"PhoneController",
	"FarmController",
	"PetController",
	"FashionController",
}

local loaded: { any } = {}
for _, name in ORDER do
	local moduleScript = Controllers:WaitForChild(name)
	if moduleScript:IsA("ModuleScript") then
		table.insert(loaded, require(moduleScript) :: any)
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[ROBLOCK CITY] client siap")
