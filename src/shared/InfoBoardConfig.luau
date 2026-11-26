--!strict
-- InfoBoardConfig: isi Papan Info di taman tempat pemain baru muncul.
-- Tiap entri menunjuk satu tujuan di DestinationConfig (nama, ikon, posisi, jarak sampai dipakai dari sana,
-- jadi GPS-nya sama persis dengan Peta/HP) dan menambah deskripsi singkat + gambar kecil.
-- Gambar kecil semua ada di SATU atlas (1 aset Image) supaya ringan: kolom/baris dihitung dari `cell`.
--   Menambah tempat = satu baris di ENTRIES (dan satu gambar di atlas kalau ada; tanpa gambar dipakai ikon).

local InfoBoardConfig = {}

export type Entry = {
	dest: string, -- id di DestinationConfig
	desc: string, -- satu kalimat pendek
	cell: number?, -- nomor sel di atlas (0 = kiri atas, urut ke kanan lalu ke bawah); kosong = tanpa gambar
	featured: boolean?, -- ikut tampil sebagai gambar kecil di muka papan
	enter: boolean?, -- pemain bisa MASUK ke dalam bangunannya (diberi lencana 🚪 dan chip filter)
	openAttr: string?, -- atribut Workspace true/false = tempat sedang buka/tutup (mis. pasar malam)
	opensAt: string?, -- teks jam buka yang ditampilkan saat tutup
}

-- Atlas gambar kecil: diisi setelah gambar diunggah (tools/buat_atlas_papan.ps1). Kosong = belum ada gambar.
InfoBoardConfig.ATLAS_ID = "rbxassetid://140680131807529"
InfoBoardConfig.ATLAS_SIZE = Vector2.new(1024, 1008)
InfoBoardConfig.CELL = Vector2.new(256, 144)
InfoBoardConfig.COLUMNS = 4

-- Tempat papan berdiri (tengah alas, y = tanah) dan arah hadapnya. Taman spawn kota kecil, di utara air mancur.
InfoBoardConfig.POSITION = Vector3.new(40, 1, 238)
InfoBoardConfig.FACING = Vector3.new(0, 0, 1)

-- Pemain yang muncul sedekat ini dari papan mendapat petunjuk sekali per sesi (stud).
InfoBoardConfig.HINT_RADIUS = 140

InfoBoardConfig.ENTRIES = {
	{
		dest = "balaiKota",
		desc = "Masuk ke lobi mewah dan ruang walikota.",
		cell = 0,
		enter = true,
	},
	{
		dest = "hotel",
		desc = "Hotel modern: lobi, lift, dan kamar untuk tidur.",
		cell = 26,
		enter = true,
	},
	{
		dest = "rumahSakit",
		desc = "Jadi dokter: periksa pasien lalu beri obat.",
		cell = 1,
		enter = true,
		featured = true,
	},
	{
		dest = "sekolah",
		desc = "6 kelas, ruang guru, dan kepala sekolah.",
		cell = 24,
		enter = true,
		featured = true,
	},
	{
		dest = "tokoCostume",
		desc = "Kostum premium: sayap, naga, dan jubah.",
		cell = 2,
		enter = true,
		featured = true,
	},
	{ dest = "toko", desc = "Toko serba ada: masuk dan belanja.", cell = 25, enter = true },
	{
		dest = "startduck",
		desc = "Kafe bebek: pesan kopi dan kue di dalam.",
		cell = 22,
		enter = true,
		featured = true,
	},
	{
		dest = "kafeKota",
		desc = "Kafe kota: barista, menu, dan kursi nyaman.",
		cell = 23,
		enter = true,
	},
	{ dest = "mall", desc = "Toko hewan, toko baju, dan kafe.", cell = 12, enter = true },
	{
		dest = "resort",
		desc = "Hotel resort: check-in, restoran, kolam.",
		cell = 15,
		enter = true,
		featured = true,
	},
	{ dest = "terminalBandara", desc = "Naik pesawat atau jadi pilot.", cell = 21, enter = true },
	{ dest = "bengkel", desc = "Ganti warna dan velg mobilmu di sini.", cell = 3 },
	{ dest = "dealer", desc = "Beli mobil dan motor baru.", cell = 4 },
	{ dest = "spbu", desc = "Isi bensin, lalu belanja di minimarket.", cell = 5 },
	{ dest = "pameranDamkar", desc = "Kenali alat pemadam dan tips selamat.", cell = 6 },
	{ dest = "lapanganSekolah", desc = "Mini-game adu penalti sepak bola.", cell = 7 },
	{ dest = "basketBarat", desc = "Mini-game lempar bebas basket.", cell = 8 },
	{ dest = "tamanBermain", desc = "Ayunan, perosotan, dan teman baru.", cell = 9 },
	{ dest = "tamanKota", desc = "Taman luas untuk santai dan foto.", cell = 10 },
	{
		dest = "pasarMalam",
		desc = "Jajanan dan permainan, buka sore hari.",
		cell = 11,
		openAttr = "PasarMalamBuka",
		opensAt = "17.30",
	},
	{ dest = "bioskop", desc = "Gedung bioskop di pusat kota.", cell = 13 },
	{ dest = "perpustakaan", desc = "Gedung buku yang tenang dan megah.", cell = 14 },
	{
		dest = "kafePantai",
		desc = "Musik, lantai dansa, dan suasana pantai.",
		cell = 16,
		featured = true,
	},
	{
		dest = "sewaJetSki",
		desc = "Sewa Jet Ski dan tantangan 10 cincin.",
		cell = 17,
		featured = true,
	},
	{ dest = "terminalFeri", desc = "Naik feri dan lihat pelabuhan.", cell = 18 },
	{ dest = "pasarTani", desc = "Jual hasil panen dan beli bibit.", cell = 19 },
	{
		dest = "ladang",
		desc = "Perkebunan besar: tanam, rawat, panen.",
		cell = 20,
		featured = true,
	},
	{
		dest = "masjid",
		desc = "Adzan, sholat berjamaah, dan tausiah tiap waktu sholat.",
		featured = true,
	},
} :: { Entry }

return InfoBoardConfig
