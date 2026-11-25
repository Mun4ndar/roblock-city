--!strict
-- LocStrings.Sports: mini-game penalti sepak bola dan lempar bebas basket (SportsService / SportsController).

local exact: { [string]: string } = {
	-- papan dan tombol di lapangan
	["⚽ Adu Penalti"] = "⚽ Penalty Shootout",
	["🏀 Lempar Bebas"] = "🏀 Free Throws",
	["Tendang penalti"] = "Take a penalty",
	["Lempar bebas"] = "Shoot free throws",
	["Lapangan Sepak Bola"] = "Football Pitch",
	["Lapangan Basket"] = "Basketball Court",
	["Adu Penalti"] = "Penalty Shootout",
	["Lempar Bebas"] = "Free Throws",
	-- antarmuka mini-game
	["KUNCI ARAH"] = "LOCK AIM",
	["KUNCI TINGGI"] = "LOCK HEIGHT",
	["TENDANG! ⚽"] = "KICK! ⚽",
	["LEMPAR! 🏀"] = "SHOOT! 🏀",
	["Keluar ✖"] = "Exit ✖",
	["TENAGA"] = "POWER",
	-- hasil tendangan
	["GOL! ⚽"] = "GOAL! ⚽",
	["Ditangkap kiper! 🧤"] = "Saved by the keeper! 🧤",
	["Kena tiang gawang!"] = "Hit the post!",
	["Kena mistar!"] = "Hit the crossbar!",
	["Melebar!"] = "Wide!",
	["Terlalu tinggi!"] = "Too high!",
	["Terlalu pelan, kiper menangkapnya"] = "Too weak, the keeper caught it",
	-- hasil lemparan
	["Swish! 🏀"] = "Swish! 🏀",
	["Masuk! 🏀"] = "Scored! 🏀",
	["Menyentuh ring, tapi masuk!"] = "Off the rim, but it goes in!",
	["Kena ring, belum masuk"] = "Hit the rim, no basket",
	["Meleset jauh!"] = "Way off!",
	-- pesan
	["Lapangan sedang dipakai pemain lain. Tunggu sebentar ya!"] = "Another player is using the field. Wait a moment!",
	["Waktu bidik habis, putaran dihentikan."] = "Time ran out, the round was stopped.",
	-- NPC
	["Kiper"] = "Goalkeeper",
	["Penyerang"] = "Striker",
	["Penembak"] = "Shooter",
	["PengambilBola"] = "Ball Boy",
}

local patterns: { { string } } = {
	{ "Hadiah sampai {}", "Prizes up to {}" },
	{ "Tendangan {} dari {} · Gol {}", "Kick {} of {} · Goals {}" },
	{ "Lemparan {} dari {} · Masuk {}", "Shot {} of {} · Scored {}" },
	{ "Selesai! Skor {} dari {} · +{}", "Done! Score {} of {} · +{}" },
	{ "Selesai! Skor {} dari {}", "Done! Score {} of {}" },
	{ "{}: skor {} dari {}. Hadiah {}.", "{}: score {} of {}. Prize {}." },
	{ "{}: skor {} dari {}.", "{}: score {} of {}." },
}

return { exact = exact, patterns = patterns }
