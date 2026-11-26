--!strict
--[[
	MasjidConfig: data Masjid Al Munawaroh yang hidup (MasjidService di server, MasjidController di client).
	  * Jadwal sholat lima waktu mengikuti Lighting.ClockTime. Satu acara: adzan -> iqamah -> sholat berjamaah -> tausiah.
	  * Adzan, sholat, dan tausiah memakai TEKS (tidak ada audio): adzan ditulis dengan huruf latin + artinya.
	  * Gerakan sholat disusun dari urutan langkah (sholatSequence) dan dipentaskan client lewat SholatPose.
	  * Semua isi tausiah lembut dan umum, cocok untuk anak-anak. Tambah/ubah waktu sholat = ubah tabel PRAYERS.
	Kiblat: dinding mihrab ada di sisi barat masjid, jadi jamaah menghadap -X.
]]

local MasjidConfig = {}

-- ---------------------------------------------------------------- tempat (koordinat dunia)
MasjidConfig.CENTER = Vector3.new(512, 5.65, -20) -- tengah ruang sholat (permukaan lantai)
MasjidConfig.FLOOR_Y = 5.65
MasjidConfig.QIBLA = Vector3.new(-1, 0, 0)
MasjidConfig.SPAWN_RADIUS = 190 -- NPC dibuat saat ada pemain sedekat ini
MasjidConfig.DESPAWN_RADIUS = 260
MasjidConfig.HALL_MIN = Vector3.new(486, 0, -49) -- sudut ruang sholat (untuk pemeriksaan jarak)
MasjidConfig.HALL_MAX = Vector3.new(544, 0, 9)

-- Posisi NPC (x, z) di lantai. Peran: Imam, Muazin, Marbot, Jamaah.
MasjidConfig.IMAM_SPOT = Vector2.new(488, -20)
MasjidConfig.AZAN_SPOT = Vector2.new(489, -33)

-- Slot sholat untuk pemain (dua saf di belakang saf NPC laki-laki, di depan saf jamaah belakang).
MasjidConfig.PLAYER_SLOTS = {
	Vector2.new(508, -34),
	Vector2.new(508, -28),
	Vector2.new(508, -22),
	Vector2.new(508, -16),
	Vector2.new(508, -10),
	Vector2.new(508, -4),
	Vector2.new(514, -34),
	Vector2.new(514, -28),
	Vector2.new(514, -22),
	Vector2.new(514, -16),
	Vector2.new(514, -10),
	Vector2.new(514, -4),
}

-- Bantal duduk untuk mendengarkan tausiah (menghadap imam di barat).
MasjidConfig.SEATS = {
	Vector2.new(530, -39),
	Vector2.new(530, -32),
	Vector2.new(530, -25),
	Vector2.new(530, -18),
	Vector2.new(530, -11),
	Vector2.new(530, -4),
	Vector2.new(536, -39),
	Vector2.new(536, -32),
	Vector2.new(536, -25),
	Vector2.new(536, -18),
	Vector2.new(536, -11),
	Vector2.new(536, -4),
}

-- Titik sapu marbot (di luar saf jamaah supaya tidak menabrak).
MasjidConfig.SWEEP_SPOTS = {
	Vector2.new(538, -36),
	Vector2.new(520, -36),
	Vector2.new(500, -37),
	Vector2.new(492, -42),
	Vector2.new(510, -43),
	Vector2.new(530, -45),
	Vector2.new(540, -44),
	Vector2.new(540, 2),
	Vector2.new(525, 5),
	Vector2.new(508, 3),
	Vector2.new(494, 5),
	Vector2.new(497, 0),
	Vector2.new(520, 1),
}
MasjidConfig.MARBOT_SLOT = Vector2.new(500, -9) -- tempat marbot ikut sholat di saf kedua

-- ---------------------------------------------------------------- waktu sholat
-- time = jam permainan acara dimulai; endT = batas waktu sholat itu (lewat dari ini = dilewati).
-- Acara berjalan satu per satu: bila dua waktu berimpit, yang kedua menunggu giliran.
export type Prayer = {
	id: string,
	name: string,
	time: number,
	endT: number,
	rakaat: number,
	subuh: boolean,
}

MasjidConfig.PRAYERS = {
	{ id = "subuh", name = "Subuh", time = 4.8, endT = 6.0, rakaat = 2, subuh = true },
	{ id = "dzuhur", name = "Dzuhur", time = 12.0, endT = 15.25, rakaat = 4, subuh = false },
	{ id = "ashar", name = "Ashar", time = 15.25, endT = 18.0, rakaat = 4, subuh = false },
	{ id = "maghrib", name = "Maghrib", time = 18.0, endT = 19.5, rakaat = 3, subuh = false },
	{ id = "isya", name = "Isya", time = 19.5, endT = 28.8, rakaat = 4, subuh = false },
} :: { Prayer }

-- Apakah jam permainan `clock` ada di jendela sholat p? (Isya melewati tengah malam.)
function MasjidConfig.inWindow(p: Prayer, clock: number): boolean
	if p.endT > 24 then
		return clock >= p.time or clock < p.endT - 24
	end
	return clock >= p.time and clock < p.endT
end

function MasjidConfig.prayerById(id: string): Prayer?
	for _, p in MasjidConfig.PRAYERS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- ---------------------------------------------------------------- fase acara
MasjidConfig.IQAMAH_SECONDS = 9
MasjidConfig.CLOSING_SECONDS = 15
MasjidConfig.TAUSIAH_LINE_SECONDS = 7.5

-- ---------------------------------------------------------------- adzan (huruf latin + arti)
export type AzanLine = { text: string, meaning: string, seconds: number }

local AZAN_BASE: { AzanLine } = {
	{
		text = "Allahu Akbar, Allahu Akbar",
		meaning = "Allah Maha Besar, Allah Maha Besar",
		seconds = 4.5,
	},
	{
		text = "Asyhadu an laa ilaaha illallah",
		meaning = "Aku bersaksi tiada Tuhan selain Allah",
		seconds = 4,
	},
	{
		text = "Asyhadu anna Muhammadar rasuulullah",
		meaning = "Aku bersaksi Nabi Muhammad adalah utusan Allah",
		seconds = 4,
	},
	{ text = "Hayya 'alash-shalaah", meaning = "Mari menuju sholat", seconds = 4 },
	{ text = "Hayya 'alal-falaah", meaning = "Mari menuju kebahagiaan", seconds = 4 },
	{
		text = "Allahu Akbar, Allahu Akbar",
		meaning = "Allah Maha Besar, Allah Maha Besar",
		seconds = 4.5,
	},
	{ text = "Laa ilaaha illallah", meaning = "Tiada Tuhan selain Allah", seconds = 4 },
}
local AZAN_SUBUH_EXTRA: AzanLine = {
	text = "Ash-shalaatu khairum minan-nauum",
	meaning = "Sholat lebih baik daripada tidur",
	seconds = 4,
}

function MasjidConfig.azanLines(p: Prayer): { AzanLine }
	local lines: { AzanLine } = {}
	for index, line in AZAN_BASE do
		table.insert(lines, line)
		if p.subuh and index == 5 then
			table.insert(lines, AZAN_SUBUH_EXTRA)
		end
	end
	return lines
end

MasjidConfig.IQAMAH_LINE = {
	text = "Qad qaamatish-shalaah",
	meaning = "Sholat akan segera dimulai. Mari luruskan dan rapatkan shaf.",
	seconds = 9,
}

-- ---------------------------------------------------------------- urutan gerakan sholat
export type Step = { pose: string, seconds: number, label: string, say: string?, rakaat: number }

-- Pose = kunci di SholatPose.POSES. label = nama gerakan yang tampil di panel.
local function build(rakaat: number): { Step }
	local steps: { Step } = {}
	local current = 1
	local function add(pose: string, seconds: number, label: string, say: string?)
		table.insert(
			steps,
			{ pose = pose, seconds = seconds, label = label, say = say, rakaat = current }
		)
	end
	add("takbir", 2.8, "Takbiratul ihram", "Allahu Akbar")
	for r = 1, rakaat do
		current = r
		if r == 1 then
			add("qiyam", 3.6, "Berdiri (qiyam)", nil)
		end
		add("ruku", 2.8, "Rukuk", "Allahu Akbar")
		add("berdiri", 2.4, "I'tidal", "Sami'allahu liman hamidah")
		add("sujud", 2.8, "Sujud", "Allahu Akbar")
		add("duduk", 2, "Duduk di antara dua sujud", "Allahu Akbar")
		add("sujud", 2.8, "Sujud", "Allahu Akbar")
		if r == rakaat then
			add("duduk", 4.4, "Tasyahud akhir", "Allahu Akbar")
		elseif r == 2 then
			add("duduk", 3.2, "Tasyahud awal", "Allahu Akbar")
			current = r + 1
			add("qiyam", 3.4, "Berdiri (qiyam)", "Allahu Akbar")
		else
			current = r + 1
			add("qiyam", 3.4, "Berdiri (qiyam)", "Allahu Akbar")
		end
	end
	current = rakaat
	add("salamKanan", 2.4, "Salam ke kanan", "Assalaamu'alaikum warahmatullaah")
	add("salamKiri", 2.4, "Salam ke kiri", "Assalaamu'alaikum warahmatullaah")
	return steps
end

local sequenceCache: { [number]: { Step } } = {}

function MasjidConfig.sholatSequence(rakaat: number): { Step }
	local cached = sequenceCache[rakaat]
	if cached then
		return cached
	end
	local steps = build(rakaat)
	sequenceCache[rakaat] = steps
	return steps
end

function MasjidConfig.sholatSeconds(rakaat: number): number
	local total = 0
	for _, step in MasjidConfig.sholatSequence(rakaat) do
		total += step.seconds
	end
	return total
end

-- Langkah pada detik t sejak sholat dimulai: (indeks langkah, detik di dalam langkah, rakaat ke-berapa).
function MasjidConfig.stepAt(rakaat: number, t: number): (number, number, number)
	local steps = MasjidConfig.sholatSequence(rakaat)
	local acc = 0
	for index, step in steps do
		if acc + step.seconds > t then
			return index, t - acc, step.rakaat
		end
		acc += step.seconds
	end
	local last = steps[#steps]
	return #steps, last.seconds, last.rakaat
end

-- ---------------------------------------------------------------- tausiah
export type TausiahLine = { text: string, replyBy: string?, reply: string? }
export type Tausiah = { title: string, lines: { TausiahLine } }

MasjidConfig.TAUSIAH = {
	subuh = {
		title = "Bersyukur di Pagi Hari",
		lines = {
			{
				text = "Assalamu'alaikum, Bapak, Ibu, dan adik-adik sekalian. Pagi ini kita belajar tentang bersyukur.",
			},
			{
				text = "Pagi hari adalah hadiah. Kita masih bisa bangun, melihat matahari terbit, dan bertemu keluarga.",
				replyBy = "PakBudi",
				reply = "Alhamdulillah. 🤲",
			},
			{
				text = "Bersyukur itu sederhana. Ucapkan 'Alhamdulillah' setiap menerima kebaikan, sekecil apa pun.",
			},
			{
				text = "Orang yang pandai bersyukur hatinya tenang dan wajahnya mudah tersenyum. 😊",
				replyBy = "Dimas",
				reply = "Aku mau banyak senyum, Ustadz!",
			},
			{
				text = "Bangun pagi juga melatih disiplin. Rapikan tempat tidur, bantu ibu, lalu berangkat sekolah dengan semangat.",
			},
			{
				text = "Sebelum makan, berdoa dulu. Habiskan makanan, karena banyak orang yang sulit mendapatkannya.",
				replyBy = "PakSiswo",
				reply = "Betul sekali, Ustadz.",
			},
			{
				text = "Syukur bukan hanya di lisan, tapi juga dengan berbuat baik: menolong teman, berbagi, dan menjaga lingkungan.",
			},
			{
				text = "Semoga hari ini kita menjadi orang yang rajin dan pandai bersyukur. Aamiin.",
				replyBy = "Semua",
				reply = "Aamiin. 🤲",
			},
		},
	},
	dzuhur = {
		title = "Jujur Itu Indah",
		lines = {
			{
				text = "Assalamu'alaikum, saudara-saudaraku. Siang ini kita berbincang tentang kejujuran.",
			},
			{
				text = "Jujur artinya berkata dan bertindak sesuai kenyataan, walaupun tidak ada yang melihat.",
				replyBy = "Dimas",
				reply = "Tapi kadang takut dimarahi, Ustadz...",
			},
			{
				text = "Tidak apa-apa, Nak. Tetapi berkata jujur selalu lebih baik. Orang tua lebih menghargai anak yang berani jujur.",
			},
			{
				text = "Kalau menemukan barang milik orang lain, kembalikan kepada pemiliknya atau serahkan kepada petugas.",
				replyBy = "PakJoko",
				reply = "Seperti dompet yang tertinggal itu, ya, Ustadz.",
			},
			{
				text = "Jujur saat berdagang, jujur saat ujian, dan jujur saat bermain. Kejujuran membuat kita dipercaya.",
			},
			{
				text = "Orang yang jujur hatinya ringan, tidurnya nyenyak, dan temannya banyak.",
				replyBy = "PakAgus",
				reply = "MasyaAllah.",
			},
			{
				text = "Kejujuran dilatih sedikit demi sedikit sejak kecil, mulai dari hal-hal sederhana.",
			},
			{
				text = "Semoga kita semua dimudahkan untuk selalu jujur. Aamiin.",
				replyBy = "Semua",
				reply = "Aamiin. 🤲",
			},
		},
	},
	ashar = {
		title = "Senang Berbagi",
		lines = {
			{ text = "Assalamu'alaikum. Sore ini kita belajar tentang berbagi dengan sesama." },
			{
				text = "Berbagi tidak harus menunggu kaya. Senyuman, bantuan tenaga, dan makanan kecil pun sangat berarti.",
				replyBy = "Nurul",
				reply = "Aku sering membagi bekal ke teman!",
			},
			{
				text = "Wah, itu bagus sekali. Berbagi membuat teman senang dan hati kita ikut bahagia. 😊",
			},
			{
				text = "Berbagi tidak membuat harta kita berkurang. Justru hati kita menjadi lapang.",
			},
			{
				text = "Lihatlah sekitar kita. Mungkin ada tetangga yang butuh bantuan atau orang tua yang butuh dibantu membawa belanjaan.",
				replyBy = "PakHaji",
				reply = "Betul, Ustadz. Kita harus saling peduli.",
			},
			{
				text = "Berbagi juga bisa dengan ilmu. Ajari temanmu yang belum bisa, jangan malu dan jangan pelit.",
				replyBy = "Dimas",
				reply = "Siap, Ustadz!",
			},
			{ text = "Lakukan dengan ikhlas, tanpa ingin dipuji. Cukup Allah yang tahu." },
			{
				text = "Semoga kita menjadi pribadi yang dermawan. Aamiin.",
				replyBy = "Semua",
				reply = "Aamiin. 🤲",
			},
		},
	},
	maghrib = {
		title = "Berbakti kepada Orang Tua",
		lines = {
			{ text = "Assalamu'alaikum. Menjelang malam ini kita bicara tentang orang tua kita." },
			{
				text = "Ayah dan ibu merawat kita sejak kecil. Mereka begadang saat kita sakit dan bekerja keras untuk kita.",
				replyBy = "PakSiswo",
				reply = "Betul, Ustadz. Orang tua itu sayang sekali.",
			},
			{
				text = "Cara berbakti sangat sederhana: berkata lembut, tidak membentak, dan mau mendengarkan nasihat mereka.",
			},
			{
				text = "Bantu pekerjaan di rumah: menyapu, merapikan mainan, atau mencuci piring. Itu sudah membuat mereka bahagia.",
				replyBy = "Dimas",
				reply = "Aku tiap hari bantu ibu menyiram bunga!",
			},
			{ text = "MasyaAllah, anak yang baik. Pertahankan, ya, Nak. 😊" },
			{
				text = "Doakan mereka setiap selesai sholat. Doa seorang anak untuk orang tuanya sangat berharga.",
			},
			{
				text = "Kalau orang tua sudah lanjut usia, kita yang gantian merawat dengan sabar dan penuh kasih sayang.",
				replyBy = "PakBudi",
				reply = "Kita harus sabar dan telaten.",
			},
			{
				text = "Semoga kita semua menjadi anak yang berbakti dan disayang keluarga. Aamiin.",
				replyBy = "Semua",
				reply = "Aamiin. 🤲",
			},
		},
	},
	isya = {
		title = "Menjaga Persahabatan",
		lines = {
			{ text = "Assalamu'alaikum. Malam ini kita belajar tentang persahabatan." },
			{
				text = "Teman yang baik mengingatkan kita pada kebaikan dan menemani saat susah maupun senang.",
				replyBy = "Nurul",
				reply = "Aku punya teman baik di sekolah!",
			},
			{
				text = "Alhamdulillah. Jagalah mereka dengan saling menghormati dan tidak saling mengejek.",
			},
			{
				text = "Kalau ada teman yang bertengkar, bantu mendamaikan. Meminta maaf dan memaafkan adalah sikap yang mulia.",
				replyBy = "PakJoko",
				reply = "Memaafkan memang bikin hati lega.",
			},
			{
				text = "Jangan memilih teman hanya karena punya mainan bagus. Berteman dengan semua orang dengan tulus.",
			},
			{
				text = "Kalau ada yang sendirian, ajaklah bermain. Kita tidak tahu betapa berharganya ajakan itu.",
				replyBy = "Dimas",
				reply = "Nanti aku ajak yang duduk sendirian, Ustadz.",
			},
			{
				text = "Terakhir, sebelum tidur, berdoalah dan ucapkan terima kasih untuk hari ini.",
			},
			{
				text = "Semoga kita punya banyak sahabat yang baik dan menjadi sahabat yang baik pula. Aamiin.",
				replyBy = "Semua",
				reply = "Aamiin. 🤲",
			},
		},
	},
} :: { [string]: Tausiah }

-- Kata-kata penutup imam.
MasjidConfig.CLOSING_SAY = "Barakallahu fiikum. Hati-hati di jalan, ya! 😊"

return MasjidConfig
