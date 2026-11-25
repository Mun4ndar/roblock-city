--!strict
-- SportsConfig: mini-game lapangan olahraga (penalti sepak bola + lempar bebas basket).
-- Dipakai server (SportsService, semua aturan dihitung di server) dan client (SportsController, tampilan).
-- Posisi lapangan dibaca dari dunia saat game berjalan; angka di sini hanya cadangan dan aturan main.

local SportsConfig = {}

SportsConfig.SHOTS = 5 -- tendangan / lemparan per putaran
SportsConfig.COOLDOWN = 40 -- detik istirahat setelah putaran selesai
SportsConfig.SHOT_TIMEOUT = 45 -- detik menunggu bidikan pemain sebelum putaran dibatalkan
SportsConfig.MIN_SHOT_SECONDS = 0.7 -- tercepat yang wajar untuk mengetuk beberapa kali
SportsConfig.EARN_WINDOW = 600 -- detik
SportsConfig.EARN_CAP = 300 -- batas hadiah mini-game per jendela waktu

SportsConfig.FOOTBALL = {
	title = "Adu Penalti",
	icon = "⚽",
	spotDistance = 20, -- jarak titik penalti dari garis gawang (stud)
	goalHalf = 5.7, -- setengah lebar gawang yang bisa dimasuki bola (tiang 6,7 dikurangi jari-jari bola)
	goalTop = 5.9, -- tinggi tengah bola maksimal agar masuk di bawah mistar
	aimRangeX = 8, -- aimX -1..1 -> -8..8 stud dari tengah gawang
	aimLow = 1.2,
	aimSpan = 6, -- aimY 0..1 -> 1,2..7,2 stud di atas tanah
	powerHint = { 0.5, 0.85 }, -- area hijau di pengukur tenaga (hanya petunjuk)
	goalPay = 6,
	sweepBonus = 15, -- 5 dari 5 gol
}

SportsConfig.BASKET = {
	title = "Lempar Bebas",
	icon = "🏀",
	spotDistance = 8.3, -- jarak titik lempar dari pusat ring (stud)
	aimRange = 3.6, -- aimX -1..1 -> -3,6..3,6 stud ke samping di ring
	sweetPower = 0.7, -- tenaga ideal
	depthRange = 9, -- selisih tenaga 1.0 = 9 stud terlalu jauh/dekat
	madeRadius = 0.9,
	swishRadius = 0.35,
	rimInRadius = 1.3, -- menyentuh ring tetapi masih bisa masuk
	rimMissRadius = 2.3,
	aimBand = 0.24, -- lebar area hijau pengukur arah (hanya petunjuk)
	powerBand = 0.1,
	madePay = 5,
	swishBonus = 2,
	sweepBonus = 15,
}

SportsConfig.ANIM = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://507767714",
	cheer = "rbxassetid://507770677",
	jump = "rbxassetid://507765000",
	wave = "rbxassetid://507770239",
}

return SportsConfig
