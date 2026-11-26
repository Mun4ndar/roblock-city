--!strict
-- LocStrings.Hotel: Hotel Bintang Kota (HotelService, HotelController, map/BuildHotel, map/BuildHotelLantai).

local exact: { [string]: string } = {
	-- prompt
	["Pilih lantai"] = "Choose a floor",
	["Lift"] = "Lift",
	["Tidur"] = "Sleep",
	["Bangun"] = "Wake up",
	["Sapa resepsionis"] = "Greet the receptionist",
	["Resepsionis Hotel"] = "Hotel Reception",
	-- panel
	["Pilih Lantai"] = "Choose a Floor",
	["☀️ Bangun"] = "☀️ Wake up",
	-- pesan
	["Kasur ini sedang dipakai tamu lain."] = "This bed is being used by another guest.",
	["Kamu bangun dengan segar. Selamat beraktivitas!"] = "You wake up refreshed. Have a great day!",
	["Selamat tidur! Tekan Bangun kalau sudah cukup istirahat."] = "Sleep well! Press Wake up when you have rested enough.",
	["Selamat datang di Hotel Bintang Kota! Naik lift di tengah lobi, pilih lantai 2-8, lalu istirahat di kasur kamar."] = "Welcome to Hotel Bintang Kota! Take the lift in the middle of the lobby, pick floor 2-8, then rest on a bed in your room.",
	-- papan
	["RESEPSIONIS"] = "RECEPTION",
	["BAR & LOUNGE"] = "BAR & LOUNGE",
	["← RESEPSIONIS"] = "← RECEPTION",
	["BAR & LOUNGE →"] = "BAR & LOUNGE →",
	["KELUAR"] = "EXIT",
	["LIFT"] = "LIFT",
}

local patterns: { { string } } = {
	{ "LANTAI {}", "FLOOR {}" },
	{ "Kasur kamar {}", "Bed of room {}" },
}

return { exact = exact, patterns = patterns }
