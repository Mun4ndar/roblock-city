--!strict
-- ROBLOCK CITY: titik masuk server. Bootstrap dua fase:
-- init() semua service (tanpa yield, saling ambil referensi), lalu start().

local Services = script:WaitForChild("Services")

-- Urutan eksplisit: DataService harus siap sebelum service yang bergantung padanya.
local ORDER = {
	"DataService",
	"EconomyService",
	"LanguageService",
	"TimeService",
	"VehicleService",
	"BikeRiderService",
	"FuelService",
	"UniformService",
	"PlaneService",
	"JobService",
	"PortalService",
	"DoorService",
	"BalaiKotaService",
	"ResortService",
	"HotelService",
	"HotelStaffService",
	"ResortHotelService",
	"ClinicService",
	"HouseService",
	"SocialService",
	"FoodService",
	"PasarMalamService",
	"RadioService",
	"LombaService",
	"ProgressService",
	"MissionService",
	"RetentionService",
	"OnboardingService",
	"FarmService",
	"ShopService",
	"GadgetService",
	"StoreService",
	"ShopDoorService",
	"ShopCashierService",
	"PetService",
	"FashionService",
	"BusinessService",
	"JetSkiService",
	"CafePantaiService",
	"FerryService",
	"PelabuhanService",
	"FerrisService",
	"NpcService",
	"SportsService",
	"ConcertService",
	"BeachLifeService",
	"CafeService",
	"CampService",
	"SchoolService",
	"FaceService",
	"DebugService",
}

local loaded: { { name: string, module: any } } = {}
for _, name in ORDER do
	local moduleScript = Services:FindFirstChild(name)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		table.insert(loaded, { name = name, module = require(moduleScript) :: any })
	else
		warn(`[Server] Service tidak ditemukan: {name}`)
	end
end

for _, entry in loaded do
	if typeof(entry.module.init) == "function" then
		entry.module.init()
	end
end

for _, entry in loaded do
	if typeof(entry.module.start) == "function" then
		task.spawn(entry.module.start)
	end
end

print("[ROBLOCK CITY] server siap")
