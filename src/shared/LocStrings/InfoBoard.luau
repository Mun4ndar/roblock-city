--!strict
-- LocStrings.InfoBoard: Papan Info di taman spawn (InfoBoardController, map/BuildPapanInfo, InfoBoardConfig).

local exact: { [string]: string } = {
	["Adzan, sholat berjamaah, dan tausiah tiap waktu sholat."] = "Adhan, congregational prayer, and a sermon at every prayer time.",
	["🗺️ Papan Info ROBLOCK CITY"] = "🗺️ ROBLOCK CITY Info Board",
	["Ketuk satu tempat, GPS langsung menuntunmu lewat jalan."] = "Tap a place and the GPS guides you along the roads.",
	["Ketuk satu tempat, GPS menuntunmu lewat jalan"] = "Tap a place and the GPS guides you along the roads",
	["✨ Semua"] = "✨ All",
	["SELAMAT DATANG DI ROBLOCK CITY!"] = "WELCOME TO ROBLOCK CITY!",
	["Tekan  E  untuk daftar lengkap semua tempat"] = "Press  E  for the full list of places",
	["Lihat Papan Info"] = "View Info Board",
	["Peta Petualangan"] = "Adventure Map",
	["Baru di sini? Tekan E di Papan Info dekat air mancur untuk lihat semua tempat seru!"] = "New here? Press E at the Info Board near the fountain to see all the fun places!",
	["🧭 GPS"] = "🧭 GPS",
	-- tujuan baru
	["Pameran Alat Pemadam"] = "Firefighting Equipment Exhibition",
	-- deskripsi tempat
	["Masuk ke lobi mewah dan ruang walikota."] = "Step into the grand lobby and the mayor's office.",
	["Jadi dokter: periksa pasien lalu beri obat."] = "Be a doctor: examine patients, then give medicine.",
	["Kostum premium: sayap, naga, dan jubah."] = "Premium costumes: wings, dragons and capes.",
	["Ganti warna dan velg mobilmu di sini."] = "Change your car's colour and rims here.",
	["Beli mobil dan motor baru."] = "Buy new cars and scooters.",
	["Isi bensin, lalu belanja di minimarket."] = "Fill up, then shop at the minimart.",
	["Kenali alat pemadam dan tips selamat."] = "Learn about firefighting gear and safety tips.",
	["Mini-game adu penalti sepak bola."] = "Football penalty shootout mini-game.",
	["Mini-game lempar bebas basket."] = "Basketball free-throw mini-game.",
	["Ayunan, perosotan, dan teman baru."] = "Swings, slides and new friends.",
	["Taman luas untuk santai dan foto."] = "A big park to relax and take photos.",
	["Jajanan dan permainan, buka sore hari."] = "Snacks and games, open in the evening.",
	["Toko hewan, toko baju, dan kafe."] = "Pet shop, clothes shop and cafe.",
	["Gedung bioskop di pusat kota."] = "The cinema in the city centre.",
	["Gedung buku yang tenang dan megah."] = "A quiet and grand house of books.",
	["Hotel resort: check-in, restoran, kolam."] = "Resort hotel: check-in, restaurant, pool.",
	["Musik, lantai dansa, dan suasana pantai."] = "Music, a dance floor and beach vibes.",
	["Sewa Jet Ski dan tantangan 10 cincin."] = "Rent a Jet Ski and try the 10-ring challenge.",
	["Naik feri dan lihat pelabuhan."] = "Ride the ferry and see the harbour.",
	["Jual hasil panen dan beli bibit."] = "Sell your harvest and buy seeds.",
	["Perkebunan besar: tanam, rawat, panen."] = "Big plantation: plant, tend, harvest.",
	["Naik pesawat atau jadi pilot."] = "Take a flight or become a pilot.",
	["🚪 Bisa Dimasuki"] = "🚪 Enterable",
	[" 🚪 Bisa masuk "] = " 🚪 Enterable ",
	["6 kelas, ruang guru, dan kepala sekolah."] = "6 classrooms, the staff room and the principal's office.",
	["Toko serba ada: masuk dan belanja."] = "General store: walk in and shop.",
	["Kafe bebek: pesan kopi dan kue di dalam."] = "Duck cafe: order coffee and cake inside.",
	["Hotel modern: lobi, lift, dan kamar untuk tidur."] = "Modern hotel: a lobby, a lift and rooms to sleep in.",
	["Kafe kota: barista, menu, dan kursi nyaman."] = "City cafe: baristas, a menu and comfy seats.",
}

local patterns: { { string } } = {
	{ "{} · 🟢 Buka sekarang", "{} · 🟢 Open now" },
	{ "{} · 🌙 Buka {}", "{} · 🌙 Opens at {}" },
}

exact["PASAR MALAM"] = "NIGHT MARKET"
exact["Jajanan, permainan, dan lampu-lampu cantik"] = "Street snacks, games and pretty lights"
exact["Buka jam 17.30 – 02.00 (waktu dalam game)"] = "Open 5:30 PM – 2:00 AM (game time)"
exact["Akhir pekan: Festival Kuliner, jajanan diskon!"] =
	"Weekends: Food Festival with discounted snacks!"

return { exact = exact, patterns = patterns }
