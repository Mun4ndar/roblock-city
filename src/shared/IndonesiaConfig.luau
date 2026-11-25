--!strict
-- IndonesiaConfig: nuansa Indonesia. Jajanan (warung, pasar malam, festival kuliner),
-- radio mobil (musik berlisensi gratis dari kanal DistroKid/APM di perpustakaan audio Roblox),
-- dan lomba 17-an (balap karung, panjat pinang). Semua angka bisa diatur di sini.

export type Food = { id: string, name: string, icon: string, price: number }
export type Station = { id: string, name: string, icon: string, tracks: { number } }

local IndonesiaConfig = {}

-- ---------------------------------------------------------------- jajanan

IndonesiaConfig.FOODS = {
	nasiGoreng = { id = "nasiGoreng", name = "Nasi Goreng", icon = "🍛", price = 25 },
	mieAyam = { id = "mieAyam", name = "Mie Ayam", icon = "🍜", price = 22 },
	bakso = { id = "bakso", name = "Bakso", icon = "🥣", price = 20 },
	sate = { id = "sate", name = "Sate Ayam", icon = "🍢", price = 28 },
	gado = { id = "gado", name = "Gado-gado", icon = "🥗", price = 18 },
	gorengan = { id = "gorengan", name = "Gorengan", icon = "🍤", price = 8 },
	pisangGoreng = { id = "pisangGoreng", name = "Pisang Goreng", icon = "🍌", price = 8 },
	esTeh = { id = "esTeh", name = "Es Teh Manis", icon = "🍹", price = 6 },
	esCampur = { id = "esCampur", name = "Es Campur", icon = "🍧", price = 12 },
	cendol = { id = "cendol", name = "Es Cendol", icon = "🥤", price = 10 },
	martabak = { id = "martabak", name = "Martabak Manis", icon = "🥞", price = 30 },
	jagungBakar = { id = "jagungBakar", name = "Jagung Bakar", icon = "🌽", price = 10 },
	kerakTelor = { id = "kerakTelor", name = "Kerak Telor", icon = "🍳", price = 18 },
	klepon = { id = "klepon", name = "Klepon", icon = "🟢", price = 8 },
	rotiBakar = { id = "rotiBakar", name = "Roti Bakar", icon = "🍞", price = 14 },
	kopi = { id = "kopi", name = "Kopi Susu", icon = "☕", price = 12 },
} :: { [string]: Food }

-- id menu -> daftar id makanan. Lapak/warung menunjuk menu lewat atribut StallMenu.
IndonesiaConfig.MENUS = {
	warung = { "nasiGoreng", "mieAyam", "gorengan", "esTeh", "kopi" },
	bakso = { "bakso", "mieAyam", "esTeh" },
	sate = { "sate", "nasiGoreng", "esTeh" },
	gorengan = { "gorengan", "pisangGoreng", "klepon", "esTeh" },
	minuman = { "esTeh", "esCampur", "cendol", "kopi" },
	martabak = { "martabak", "rotiBakar", "kopi" },
	jagung = { "jagungBakar", "kerakTelor", "klepon" },
	gado = { "gado", "kerakTelor", "esCampur" },
} :: { [string]: { string } }

IndonesiaConfig.BUFF_SECONDS = 90 -- lama "kenyang semangat" setelah jajan
IndonesiaConfig.BUFF_SPEED = 4 -- tambahan WalkSpeed
IndonesiaConfig.BUFF_ATTR = "SnackBuffUntil" -- atribut Player: GetServerTimeNow() saat buff habis
IndonesiaConfig.BUY_DISTANCE = 20
IndonesiaConfig.FESTIVAL_DISCOUNT = 0.8 -- harga x0.8 selama festival kuliner

-- Pasar malam buka dari jam dunia ini (lewat tengah malam sampai OPEN_TO_NEXT).
IndonesiaConfig.PASAR_OPEN_FROM = 17.5
IndonesiaConfig.PASAR_OPEN_TO = 2
IndonesiaConfig.PASAR_UTC_OFFSET = 7 -- WIB; festival kuliner = Sabtu dan Minggu WIB
IndonesiaConfig.ATTR_PASAR = "PasarMalamBuka" -- atribut Workspace: true saat buka
IndonesiaConfig.ATTR_FESTIVAL = "FestivalKuliner" -- atribut Workspace: true saat akhir pekan

-- ---------------------------------------------------------------- radio mobil

IndonesiaConfig.STATIONS = {
	{
		id = "koplo",
		name = "Radio Koplo",
		icon = "🪘",
		tracks = { 107302164689882, 108733665602479, 90047526532000 },
	},
	{
		id = "dangdut",
		name = "Dangdut Santai",
		icon = "🎤",
		tracks = { 96755117635802, 120786497356440 },
	},
	{
		id = "campursari",
		name = "Campursari",
		icon = "🎶",
		tracks = { 127072831280609, 134961421543388, 85537520513989 },
	},
	{
		id = "gamelan",
		name = "Gamelan Santai",
		icon = "🥁",
		tracks = { 1840472303, 83077123902599, 1840694476 },
	},
} :: { Station }

IndonesiaConfig.RADIO_VOLUME = 0.55
IndonesiaConfig.RADIO_MAX_DISTANCE = 70 -- stud; orang di dekat mobil ikut mendengar
IndonesiaConfig.ATTR_RADIO = "RadioStation" -- atribut model kendaraan: id stasiun, "" = mati

function IndonesiaConfig.station(id: any): Station?
	for _, s in IndonesiaConfig.STATIONS do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- ---------------------------------------------------------------- lomba 17-an

IndonesiaConfig.LOMBA = {
	karung = {
		length = 60, -- stud dari garis start ke garis finis (arah lintasan)
		timeLimit = 45, -- detik
		minTime = 7, -- finis lebih cepat dari ini dianggap curang
		baseSpeed = 2,
		hopSpeed = 11,
		hopSeconds = 0.38,
		cooldown = 40,
		rewards = {
			{ maxTime = 14, pay = 400, title = "Juara 1" },
			{ maxTime = 20, pay = 260, title = "Juara 2" },
			{ maxTime = 30, pay = 160, title = "Juara 3" },
			{ maxTime = 999, pay = 60, title = "Peserta" },
		},
	},
	pinang = {
		height = 22, -- tinggi puncak dari alas (stud)
		tapGain = 1.25,
		decay = 1.1, -- stud per detik merosot
		minTapInterval = 0.1,
		timeLimit = 70,
		pay = 350,
		resetSeconds = 30, -- hadiah muncul lagi setelah direbut
		radius = 1.9, -- jarak pemain dari sumbu tiang
	},
}

IndonesiaConfig.TAG_KARUNG_START = "LombaKarungStart"
IndonesiaConfig.TAG_KARUNG_FINISH = "LombaKarungFinish"
IndonesiaConfig.TAG_PINANG = "LombaPinang"
IndonesiaConfig.ATTR_RACE_START = "LombaStart" -- atribut Player: GetServerTimeNow() saat balap karung mulai
IndonesiaConfig.ATTR_CLIMB = "LombaPinangTinggi" -- atribut Player: tinggi sekarang, nil bila tidak memanjat

return IndonesiaConfig
