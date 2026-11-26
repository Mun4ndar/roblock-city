--!strict
-- DestinationConfig: daftar SEMUA tujuan yang bisa dipilih di Peta dan GPS, dikelompokkan per zona.
-- Posisi diukur dari Workspace.Map (titik di depan pintu / halaman bangunan). Menambah tempat baru =
-- menambah satu baris di LIST; tidak ada kode lain yang perlu diubah.
--   major = tampil di peta kecil walau diperkecil dan di peta penuh pada semua perbesaran.
--   arrive = jarak (stud, mendatar) yang dianggap sudah sampai; bawaan 35.

local DestinationConfig = {}

export type Zone = { id: string, name: string, icon: string, color: Color3 }
export type Destination = {
	id: string,
	name: string,
	zone: string,
	icon: string,
	position: Vector3,
	major: boolean,
	arrive: number,
	color: Color3?, -- warna khusus pin (bawaan: warna zona)
}

DestinationConfig.DEFAULT_ARRIVE = 35

-- Urutan = urutan tab zona.
DestinationConfig.ZONES = {
	{ id = "kota", name = "Pusat Kota", icon = "🏙️", color = Color3.fromRGB(122, 92, 255) },
	{
		id = "perumahan",
		name = "Perumahan",
		icon = "🏘️",
		color = Color3.fromRGB(255, 140, 66),
	},
	{ id = "pantai", name = "Pantai", icon = "🏖️", color = Color3.fromRGB(0, 184, 217) },
	{ id = "desa", name = "Desa & Kebun", icon = "🌾", color = Color3.fromRGB(64, 180, 90) },
	{ id = "bandara", name = "Bandara", icon = "✈️", color = Color3.fromRGB(60, 120, 230) },
} :: { Zone }

local LIST: { Destination } = {}

local function add(
	id: string,
	name: string,
	zone: string,
	icon: string,
	x: number,
	z: number,
	major: boolean?,
	arrive: number?
)
	table.insert(LIST, {
		id = id,
		name = name,
		zone = zone,
		icon = icon,
		position = Vector3.new(x, 1, z),
		major = major == true,
		arrive = arrive or DestinationConfig.DEFAULT_ARRIVE,
	})
end

-- ---------------------------------------------------------------- Pusat Kota
add("mall", "ROBLOCK Mall", "kota", "🛍️", 525, -530, true, 60)
add("tokoCostume", "Toko Premium Costume", "kota", "👑", 492, -437, true, 40)
add("bioskop", "Bioskop", "kota", "🎬", -368, -566, true, 45)
add("kantorPos", "Kantor Pos", "kota", "📮", -380, -399, false)
add("perpustakaan", "Perpustakaan", "kota", "📚", 272, -409, false, 45)
add("kafeKota", "Kafe Kota", "kota", "☕", 20, -551, true)
add("pusatBisnis", "Pusat Bisnis", "kota", "💼", 258, -541, false, 50)
add("menara", "Menara ROBLOCK", "kota", "🏙️", 258, -955, true, 45)
add("hotel", "Hotel", "kota", "🏨", 525, -962, false, 45)
add("menaraKembar", "Menara Kembar", "kota", "🏢", 260, -770, false, 45)
add("spbu", "SPBU", "kota", "⛽", 771, -330, false, 50)
add("parkirUmum", "Parkir Umum", "kota", "🅿️", 771, -604, false, 60)
add("aptTaman", "Apartemen Taman", "kota", "🏢", -262, -604, false, 45)
add("aptSelatan", "Apartemen Selatan", "kota", "🏢", -262, -380, false, 45)
add("aptHijau", "Apartemen Hijau", "kota", "🏢", 470, -366, false, 45)
add("aptKrem", "Apartemen Krem", "kota", "🏢", 580, -366, false, 45)
add("aptMint", "Apartemen Mint", "kota", "🏢", -275, -800, false, 45)
add("aptBata", "Apartemen Bata", "kota", "🏢", -390, -800, false, 45)
add("aptKuning", "Apartemen Kuning", "kota", "🏢", 720, -800, false, 45)
add("aptPink", "Apartemen Pink", "kota", "🏢", 820, -800, false, 45)
add("aptLaut", "Apartemen Laut", "kota", "🏢", -268, -996, false, 45)
add("aptUjung", "Apartemen Ujung", "kota", "🏢", 703, -996, false, 45)

-- ---------------------------------------------------------------- Perumahan (kota kecil)
add("balaiKota", "Balai Kota", "perumahan", "🏛️", 160, 108, true, 45)
add("rumahSakit", "Rumah Sakit", "perumahan", "🏥", 40, 200, true, 45)
add("damkar", "Pemadam Kebakaran", "perumahan", "🚒", 146, 236, true)
add("ambulans", "Garasi Ambulans", "perumahan", "🚑", 78, 160, false)
add("toko", "Toko Modern", "perumahan", "🏪", 138, 200, false)
add("startduck", "Kafe Startduck", "perumahan", "🦆", 184, 200, false)
add("bengkel", "Bengkel", "perumahan", "🔧", 186, 232, true)
add("dealer", "Dealer Mobil", "perumahan", "🚗", -67, 275, true, 50)
add("tamanPerumahan", "Taman Perumahan", "perumahan", "⛲", 40, 274, false, 45)
add("indomart", "Indomart", "perumahan", "🛒", 140, 45, false)
add("roblockStore", "Roblock Store", "perumahan", "📱", 140, -35, false)
add("warung", "Warung Kelontong", "perumahan", "🥫", 140, -78, false)
add("masjid", "Masjid", "perumahan", "🕌", 562, -20, true, 45)
add("sekolah", "Sekolah", "perumahan", "🏫", -183, -90, true, 50)
add("aula", "Aula Sekolah", "perumahan", "🎭", -263, 9, false, 40)
add("lapanganSekolah", "Lapangan Sekolah", "perumahan", "⚽", -165, 94, false, 45)
add("basketBarat", "Lapangan Basket Barat", "perumahan", "🏀", -390, -18, false, 45)
add("basketTimur", "Lapangan Basket Timur", "perumahan", "🏀", 712, 300, false, 45)
add("tamanBermain", "Taman Bermain", "perumahan", "🎠", 440, 104, true, 50)
add("tamanKota", "Taman Kota", "perumahan", "🌳", 716, 55, true, 60)
add("pasarMalam", "Pasar Malam (buka sore)", "perumahan", "🏮", 668, 122, true, 45)
add("panggungKonser", "Panggung Konser (malam)", "perumahan", "🎤", 812, 55, true, 45)
add("arenaLomba", "Arena Lomba 17-an (Agustus)", "perumahan", "🇮🇩", 802, 100, false, 45)
add("pameranDamkar", "Pameran Alat Pemadam", "perumahan", "🧯", 138, 293, false, 45)
add("tamanBunga", "Taman Bunga", "perumahan", "🌸", -375, 277, false, 45)
add("tamanBermainBarat", "Taman Bermain Barat", "perumahan", "🛝", -160, 330, false, 45)
add("gazebo", "Gazebo & Kolam", "perumahan", "🛖", 466, 330, false, 45)
add("kiosTaman", "Kios Taman", "perumahan", "🍦", 740, 430, false)
add("perumahan", "Kompleks Perumahan", "perumahan", "🏘️", 180, 620, true, 120)

-- ---------------------------------------------------------------- Pantai
add("kafePantai", "Kafe Pantai", "pantai", "🎶", 1620, -300, true, 45)
add("sewaJetSki", "Sewa Jet Ski", "pantai", "🛥️", 1608, -380, true)
add("resort", "Resort ROBLOCK", "pantai", "🌴", 1249, -440, true, 60)
add("kiosEsKrim", "Kios Es Krim", "pantai", "🍨", 1415, -300, false)
add("kiosKelapa", "Kios Kelapa", "pantai", "🥥", 1415, 10, false)
add("dermaga", "Dermaga", "pantai", "⚓", 1694, -120, true, 50)
add("menaraPantai", "Menara Penjaga Pantai", "pantai", "🛟", 1614, -170, false)
add("voli", "Lapangan Voli Pantai", "pantai", "🏐", 1534, 95, false, 45)
add("mercusuar", "Mercusuar", "pantai", "🗼", 1344, -800, true)
add("terminalFeri", "Terminal Feri", "pantai", "⛴️", 1314, 450, true, 45)
add("pelabuhan", "Pelabuhan Kapal", "pantai", "🚢", 1304, 560, false, 50)

-- ---------------------------------------------------------------- Desa & Kebun
add("pasarTani", "Pasar Tani", "desa", "🌽", -660, 105, true)
add("tokoBibit", "Toko Bibit", "desa", "🌱", -746, 88, true)
add("gudangTani", "Gudang Hasil", "desa", "📦", -775, 89, false)
add("ladang", "Perkebunan Besar (Ladang)", "desa", "🥬", -757, 178, true, 70)
add("kincirPompa", "Kincir Pompa Air", "desa", "🚰", -808, 236, false)
add("lumbung", "Lumbung", "desa", "🌾", -830, 176, false, 45)
add("rumahPetani", "Rumah Petani", "desa", "🏡", -900, 109, false)
add("kincirAngin", "Kincir Angin", "desa", "🌬️", -956, 183, false)
add("perkemahan", "Perkemahan", "desa", "⛺", -865, -420, true, 50)
add("airTerjun", "Air Terjun", "desa", "💧", -960, -516, false)

-- ---------------------------------------------------------------- Bandara
add("terminalBandara", "Terminal Bandara", "bandara", "🛫", -975, 400, true, 50)
add("gerbang", "Gerbang Keberangkatan", "bandara", "🚪", -981, 520, false, 50)
add("menaraKontrol", "Menara Kontrol", "bandara", "📡", -745, 470, false)
add("parkirBandara", "Parkir Bandara", "bandara", "🅿️", -990, 299, false, 60)
add("hangar", "Hangar Pesawat", "bandara", "🛩️", -1282, 644, false, 50)
add("landasan", "Landasan Pacu", "bandara", "✈️", -1010, 844, true, 80)

DestinationConfig.LIST = LIST

-- Pin emas khusus untuk toko premium supaya mudah dicari di peta.
for _, d in LIST do
	if d.id == "tokoCostume" then
		d.color = Color3.fromRGB(255, 184, 0)
	end
end

-- ---------------------------------------------------------------- util

local byId: { [string]: Destination } = {}
for _, d in LIST do
	byId[d.id] = d
end
local zoneById: { [string]: Zone } = {}
for _, z in DestinationConfig.ZONES do
	zoneById[z.id] = z
end

function DestinationConfig.get(id: string): Destination?
	return byId[id]
end

function DestinationConfig.zone(id: string): Zone
	return zoneById[id]
end

return DestinationConfig
