--!strict
-- ROBLOCK CITY: titik masuk client. Bootstrap dua fase: init() lalu start().

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"LocalizeController", -- harus pertama: pengamat teks sudah terpasang saat controller lain membuat UI
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
	"NavController",
	"PhoneController",
	"RetentionController",
	"FarmController",
	"PetController",
	"SocialController",
	"FoodController",
	"RadioController",
	"LombaController",
	"ProgressController",
	"PetAnimController",
	"FashionController",
	"BusinessController",
	"ShopController",
	"PlaneController",
	"JetSkiController",
	"MinimapController",
	"MapUiController",
	"WindmillController",
	"ExhibitController",
	"UiStyleController",
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
