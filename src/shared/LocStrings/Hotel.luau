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
	-- staf
	["Bu Sari"] = "Ms. Sari",
	["Pak Anton"] = "Mr. Anton",
	["Mas Rio"] = "Rio",
	["Mbak Dina"] = "Dina",
	["Kak Rina"] = "Rina",
	["Bu Tini"] = "Ms. Tini",
	["Concierge Hotel"] = "Hotel Concierge",
	["Tanya Concierge"] = "Ask the Concierge",
	["Housekeeping"] = "Housekeeping",
	["Selamat datang di Hotel Bintang Kota!"] = "Welcome to Hotel Bintang Kota!",
	["Mau check-in, Kak? Silakan ke sini."] = "Would you like to check in? Please come over.",
	["Kamar tamu ada di lantai 2 sampai 8."] = "Guest rooms are on floors 2 to 8.",
	["Selamat datang! Ada yang bisa saya bantu?"] = "Welcome! How can I help you?",
	["Tekan tombol untuk bertanya pada saya, ya."] = "Press the button to ask me anything.",
	["Lift ada di tengah lobi."] = "The lift is in the middle of the lobby.",
	["Halo, Kak! Butuh bantuan bawa koper?"] = "Hello! Need help with your luggage?",
	["Selamat datang di hotel kami!"] = "Welcome to our hotel!",
	["Silakan duduk di lounge, Kak!"] = "Please have a seat in the lounge!",
	["Mau minum sesuatu?"] = "Would you like something to drink?",
	["Selamat datang di Bar & Lounge!"] = "Welcome to the Bar & Lounge!",
	["Jus segar atau kopi, Kak?"] = "Fresh juice or coffee?",
	["Selamat istirahat, Kak!"] = "Have a good rest!",
	["Handuk bersih ada di kamar, ya."] = "Clean towels are in your room.",
	["Naik lift di tengah lobi, lalu pilih lantai 2 sampai 8."] = "Take the lift in the middle of the lobby, then pick floor 2 to 8.",
	["Di setiap kamar ada kasur: tekan E untuk tidur, lalu Bangun."] = "Every room has a bed: press E to sleep, then Wake up.",
	["Bar & Lounge ada di sisi timur lobi. Silakan bersantai!"] = "The Bar & Lounge is on the east side of the lobby. Relax!",
	["Resepsionis siap membantu di sebelah barat lobi."] = "Reception is ready to help on the west side of the lobby.",
	["Hotel kami buka 24 jam. Selamat menginap!"] = "Our hotel is open 24 hours. Enjoy your stay!",
	-- papan
	["RESEPSIONIS"] = "RECEPTION",
	["BAR & LOUNGE"] = "BAR & LOUNGE",
	["← RESEPSIONIS"] = "← RECEPTION",
	["BAR & LOUNGE →"] = "BAR & LOUNGE →",
	["KELUAR"] = "EXIT",
	["KAMAR MANDI"] = "BATHROOM",
	["Mandi"] = "Shower",
	["Kamu mandi dengan air hangat. Ahh, segar!"] = "You take a warm shower. Ahh, refreshing!",
	["LIFT"] = "LIFT",
}

local patterns: { { string } } = {
	{ "LANTAI {}", "FLOOR {}" },
	{ "Kasur kamar {}", "Bed of room {}" },
	{ "Shower kamar {}", "Shower of room {}" },
}

return { exact = exact, patterns = patterns }
