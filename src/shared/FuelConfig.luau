--!strict
-- FuelConfig: aturan bensin. Tiap mobil milik pemain punya atribut "Fuel" (0..100, persen tangki).
-- Bensin berkurang saat mobil dikemudikan; di SPBU pemain mengisi lewat ProximityPrompt di pompa
-- (part bertag "FuelPump"). Kendaraan dinas (polisi, ambulans, dll.) gratis dan tidak butuh bensin.

local FuelConfig = {}

FuelConfig.ATTR = "Fuel" -- atribut Model kendaraan: angka 0..100 (tidak ada = tidak pakai bensin)
FuelConfig.TAG_PUMP = "FuelPump" -- part titik isi di pompa SPBU
FuelConfig.TANK = 100
FuelConfig.START = 100 -- isi tangki saat mobil pertama kali dikeluarkan di sesi ini
FuelConfig.PRICE_PER_UNIT = 1 -- uang per 1% bensin (tangki kosong ke penuh = 100)
FuelConfig.VEHICLE_RANGE = 26 -- jarak maksimum mobil ke pompa saat mengisi (stud)
FuelConfig.PROMPT_RANGE = 16 -- jarak pemain ke pompa agar tombol muncul
FuelConfig.REFUEL_COOLDOWN = 1.5 -- detik
FuelConfig.DRAIN_IDLE = 0.03 -- persen/detik saat mesin hidup dan diam
FuelConfig.DRAIN_PER_SPEED = 0.0028 -- persen/detik tiap 1 stud/detik; kecepatan penuh sekitar 7 menit
FuelConfig.EMPTY_POWER = 0.28 -- tenaga saat bensin habis (masih bisa merayap ke SPBU)
FuelConfig.LOW = 20 -- di bawah ini peringatan "Bensin menipis"

return FuelConfig
