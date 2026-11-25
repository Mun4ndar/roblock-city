--!strict
-- LocStrings.Resort: interior Resort ROBLOCK (ResortService, map/BuildResortDalam), wajah NPC tidak punya teks.

local exact: { [string]: string } = {
	-- staf
	["Bu Dewi"] = "Ms. Dewi",
	["Pak Rudi"] = "Mr. Rudi",
	["Mas Doni"] = "Doni",
	["Chef Bagas"] = "Chef Bagas",
	["Mbak Ani"] = "Ani",
	["Kak Lia"] = "Lia",
	["Resepsionis"] = "Receptionist",
	["Concierge"] = "Concierge",
	["Bellboy"] = "Bellboy",
	["Koki"] = "Chef",
	["Pelayan"] = "Waiter",
	["Bartender"] = "Bartender",
	-- prompt
	["Check-in"] = "Check in",
	["Resepsionis Resort"] = "Resort Reception",
	["Tanya Concierge"] = "Ask the Concierge",
	["Restoran Samudra"] = "Samudra Restaurant",
	["Bar Jus & Kopi"] = "Juice & Coffee Bar",
	-- papan
	["RESTORAN SAMUDRA"] = "SAMUDRA RESTAURANT",
	["BAR JUS & KOPI"] = "JUICE & COFFEE BAR",
	["RESEPSIONIS · CHECK-IN"] = "RECEPTION · CHECK-IN",
	["CONCIERGE"] = "CONCIERGE",
	["FASILITAS"] = "FACILITIES",
	["LAYANAN TAMU"] = "GUEST SERVICES",
	["PULAU PANTAI"] = "BEACH ISLAND",
	["TIPS TAMU"] = "GUEST TIPS",
	[table.concat({
		"• Kolam renang di depan resort",
		"• Restoran Samudra (kiri)",
		"• Bar Jus & Kopi (kanan)",
		"• Pojok anak dan perpustakaan",
		"• Lift ke kamar tamu",
	}, "\n")] = table.concat({
		"• Swimming pool in front of the resort",
		"• Samudra Restaurant (left)",
		"• Juice & Coffee Bar (right)",
		"• Kids' corner and library",
		"• Lift to guest rooms",
	}, "\n"),
	[table.concat({
		"Check-in: meja Resepsionis",
		"Tanya info: Concierge",
		"Bagasi: dibantu Bellboy",
		"Makan: pesan di Restoran",
		"Buka setiap hari, ramah anak",
	}, "\n")] = table.concat({
		"Check-in: Reception desk",
		"Ask for info: Concierge",
		"Luggage: helped by the Bellboy",
		"Dining: order at the Restaurant",
		"Open every day, kid friendly",
	}, "\n"),
	[table.concat({
		"Dermaga dan bianglala",
		"Sewa Jet Ski dan tantangan cincin",
		"Kafe Pantai: musik dan penari",
		"Pelabuhan kapal",
		"Pantai berpasir dan payung",
	}, "\n")] = table.concat({
		"Pier and Ferris wheel",
		"Jet Ski rental and ring challenge",
		"Beach Cafe: music and dancers",
		"Harbor with boats",
		"Sandy beach and umbrellas",
	}, "\n"),
	[table.concat({
		"Berenang di kolam, tapi hati-hati",
		"Duduk di sofa dengan tekan E",
		"Jajan di restoran dan bar",
		"Sapa staf dengan ramah",
		"Jangan berlarian di lobi",
	}, "\n")] = table.concat({
		"Swim in the pool, but be careful",
		"Sit on a sofa by pressing E",
		"Grab a bite at the restaurant and bar",
		"Greet the staff politely",
		"Don't run in the lobby",
	}, "\n"),
	-- pesan
	["Kamu sudah check-in. Selamat menikmati Resort!"] = "You have already checked in. Enjoy the Resort!",
	["Coba Jet Ski di pantai: ada tantangan 10 cincin!"] = "Try the Jet Ski at the beach: there's a 10-ring challenge!",
	["Bianglala di dermaga punya pemandangan indah."] = "The Ferris wheel on the pier has a beautiful view.",
	["Kafe Pantai buka jam 8 pagi sampai 9 malam, ada penari."] = "The Beach Cafe is open 8 AM to 9 PM, with dancers.",
	["Jajan di Restoran Samudra untuk tenaga ekstra sebentar."] = "Grab food at Samudra Restaurant for a short energy boost.",
	["Berenanglah di kolam depan resort, airnya sejuk!"] = "Take a swim in the pool in front of the resort, the water is cool!",
	["Pulau Pantai punya pelabuhan dengan kapal-kapal cantik."] = "Beach Island has a harbor full of lovely boats.",
}

local patterns: { { string } } = {
	{ "Selamat datang di ROBLOCK Resort! Bonus tamu ${}", "Welcome to ROBLOCK Resort! Guest bonus ${}" },
}

return { exact = exact, patterns = patterns }
