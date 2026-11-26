--!strict
-- HotelConfig: Hotel Bintang Kota (bangunan map/BuildHotel + map/BuildHotelLantai).
-- Satu koridor saja; lift hanya mengganti NOMOR lantai yang tampil (ilusi), pemain tiba di koridor yang sama.

local HotelConfig = {}

HotelConfig.NAME = "Hotel Bintang Kota"
HotelConfig.FLOORS = 8 -- indeks 1 = L (lobi), 2..8 = lantai tamu
HotelConfig.LABELS = { "L", "2", "3", "4", "5", "6", "7", "8" }
HotelConfig.STEP_SECONDS = 0.8 -- jeda lampu indikator berpindah satu lantai
HotelConfig.DOOR_CLOSE_SECONDS = 0.9 -- pintu lift menutup dulu sebelum jalan
HotelConfig.WELCOME_COOLDOWN = 8 -- detik antar sapaan resepsionis per pemain

return HotelConfig
