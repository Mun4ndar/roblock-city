--!strict
-- Daftar pekerjaan. Semuanya berbasis data:
--   * PLACES    : titik di peta (nama + posisi) yang bisa jadi tujuan tugas
--   * POOLS     : kelompok tempat (mis. "alamat" = semua tujuan antar paket)
--   * LIST      : pekerjaan, masing-masing punya beberapa templat tugas
-- Menambah pekerjaan/tugas baru = menambah entri di sini; JobService (server)
-- dan UI (client) mengikuti otomatis.
--
-- Modul ini ikut ter-replikasi ke client. Client hanya memakainya untuk
-- tampilan; gaji dihitung dan divalidasi server.

export type PropKind = "package" | "car" | "fire" | "kios" | "person" | "cat" | "cone"

export type Place = {
	name: string,
	position: Vector3, -- titik di permukaan tanah
	yaw: number?, -- derajat; arah hadap prop mobil di tempat ini
}

export type StepSpec = {
	-- Tempat langkah ini (pilih satu):
	place: string?, -- tempat tetap
	pool: string?, -- dipilih acak dari kelompok tempat
	sameAs: number?, -- tempat yang sama dengan langkah ke-n
	-- Batasan pemilihan dari pool, relatif ke titik sebelumnya:
	nearest: number?, -- acak di antara n tempat terdekat
	minDist: number?,
	maxDist: number?,
	offset: Vector3?, -- geser penanda dari titik tempat (mengikuti yaw tempat)
	action: string, -- teks tombol tahan (ProximityPrompt)
	text: string, -- teks di panel tugas; "{tempat}" diganti nama tempat
	hold: number, -- detik menahan tombol
	prop: PropKind?, -- hiasan yang muncul di langkah ini (hanya di layar pemain itu)
	consume: boolean?, -- prop hilang setelah langkah selesai
	-- Langkah terbang (pekerjaan Pilot): selesai sendiri saat pesawat pemain lewat sedekat ini
	-- (stud, mendatar) dari titiknya; tidak ada tombol. `landed` = pesawat harus sudah di darat.
	fly: number?,
	landed: boolean?,
}

export type TaskTemplate = {
	id: string,
	title: string,
	weight: number, -- peluang terpilih
	basePay: number,
	payPerStud: number, -- tambahan per stud jarak antar langkah
	steps: { StepSpec },
}

export type HatKind = "cap" | "helmet" | "peaked" | "mirror"

-- Seragam yang dipakai selama bekerja (dirakit UniformService di server).
export type Uniform = {
	hat: HatKind, -- topi kurir/mekanik, helm pemadam, topi polisi, cermin dokter
	hatColor: Color3,
	vest: Color3, -- rompi / jas
	trim: Color3, -- garis rompi
	badge: Color3, -- lencana di dada dan topi
}

export type JobDef = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	description: string,
	workplace: string, -- teks lokasi kantor di UI
	uniform: Uniform,
	tasks: { TaskTemplate },
}

-- Payload yang dikirim server ke client (remote JobTask).
export type TaskStepView = {
	position: Vector3,
	origin: Vector3, -- titik tempat (lokasi prop mobil)
	yaw: number,
	placeName: string,
	action: string,
	text: string,
	hold: number,
	prop: PropKind?,
	consume: boolean,
	fly: number?,
	landed: boolean?,
}

export type TaskView = {
	id: number,
	jobId: string,
	title: string,
	pay: number,
	index: number, -- langkah yang sedang aktif (1..#steps)
	steps: { TaskStepView },
}

export type JobStats = { tasks: number, earned: number }

local JobConfig = {}

-- ---------------------------------------------------------------- aturan server

JobConfig.STEP_RADIUS = 16 -- pemain harus sedekat ini (mendatar) dari penanda
JobConfig.PROMPT_DISTANCE = 12
JobConfig.REMOTE_COOLDOWN = 0.3 -- jeda minimal antar panggilan remote pekerjaan
JobConfig.SELECT_COOLDOWN = 3 -- jeda ganti pekerjaan
JobConfig.SKIP_COOLDOWN = 20 -- jeda tombol "Ganti tugas"
JobConfig.WALK_SPEED = 24 -- stud/dtk; batas wajar tanpa kendaraan (sedikit di atas lari)
JobConfig.SPEED_SLACK = 1.25 -- kelonggaran di atas kecepatan kendaraan tercepat milik pemain
JobConfig.HOLD_SLACK = 0.8 -- bagian dari waktu tahan yang wajib berlalu
JobConfig.TELEPORT_SPEED = 200 -- stud/dtk; lebih dari ini dianggap berpindah tidak wajar
JobConfig.TELEPORT_SLACK = 40 -- stud
JobConfig.EARN_WINDOW = 300 -- detik
JobConfig.MAX_EARN_PER_WINDOW = 3000 -- batas gaji per jendela waktu (pengaman)
JobConfig.NEXT_TASK_DELAY = 1.5 -- detik sebelum tugas berikutnya muncul

-- Naik level berdasarkan jumlah tugas selesai di pekerjaan itu.
-- LEVELS[n] = jumlah tugas minimal untuk level n.
JobConfig.LEVELS = { 0, 5, 15, 30, 50, 80, 120, 170, 230, 300 }
JobConfig.LEVEL_BONUS = 0.05 -- +5% gaji per level di atas 1

-- Atribut Player (diset server, dibaca client)
JobConfig.ATTR_JOB = "Job" -- id pekerjaan aktif, "" = tidak bekerja
JobConfig.ATTR_STATS = "JobStats" -- JSON { [jobId] = { tasks, earned } }

-- ---------------------------------------------------------------- tempat

local function place(name: string, x: number, y: number, z: number, yaw: number?): Place
	return { name = name, position = Vector3.new(x, y, z), yaw = yaw }
end

JobConfig.PLACES = {
	-- Kota kecil (Perumahan)
	rumahSakit = place("Rumah Sakit", 40, 1, 197),
	toko = place("Toko", 138, 1, 197),
	kafe = place("Cafe Startduck", 184, 1, 197),
	damkar = place("Pemadam Kebakaran", 132, 1, 231),
	bengkel = place("Bengkel", 186, 1, 231),
	bengkelServis = place("Halaman Bengkel", 186, 1, 282, 90),
	balaiKota = place("Balai Kota", 160, 1, 111),
	tamanPerumahan = place("Taman Perumahan", 24, 1, 302),
	sekolah = place("Sekolah", -183, 0, -90, 90),
	aula = place("Aula Sekolah", -263, 0.6, 9),
	tamanBermain = place("Taman Bermain", 440, 0, 104, 90),
	rumah18 = place("Rumah No. 18", 438, 0.6, -136),
	rumah20 = place("Rumah No. 20", 658, 0.6, -136),
	rumah27 = place("Rumah No. 27", 787, 0.6, -96),
	rumah29 = place("Rumah No. 29", -427, 0.6, 524),
	rumah34 = place("Rumah No. 34", -42, 0.6, 524),
	rumah49 = place("Rumah No. 49", 493, 0.6, 524),
	rumah62 = place("Rumah No. 62", -427, 0.6, 704),
	rumah65 = place("Rumah No. 65", -152, 0.6, 704),
	rumah74 = place("Rumah No. 74", -48, 0.6, 744),
	rumah76 = place("Rumah No. 76", 163, 0.6, 704),
	rumah78 = place("Rumah No. 78", 273, 0.6, 704),
	rumah85 = place("Rumah No. 85", 267, 0.6, 744),
	rumah88 = place("Rumah No. 88", 432, 0.6, 744),
	-- Downtown
	kantorPos = place("Kantor Pos", -380, 1.1, -399),
	mall = place("ROBLOCK Mall", 565, 1.1, -536),
	kafeKota = place("Kafe Kota", 20, 1.1, -551),
	pusatBisnis = place("Pusat Bisnis", 258, 1.1, -541),
	perpustakaan = place("Perpustakaan", 272, 1.1, -409),
	bioskop = place("Bioskop", -368, 1.1, -566),
	hotel = place("Hotel", 525, 1.1, -962),
	menara = place("Menara ROBLOCK", 258, 1.1, -955),
	spbu = place("Toko SPBU", 771, 1.3, -330),
	spbuParkir = place("Halaman SPBU", 700, 1.3, -330, 90),
	parkirUmum = place("Parkir Umum", 771, 1.3, -604),
	parkirUmumBarat = place("Parkir Umum Barat", 720, 1.3, -570, 90),
	tamanKota = place("Taman Kota", 716, 0.4, 55),
	-- Beach Island
	sewaJetSki = place("Sewa Jet Ski", 1619, 0, -390),
	kiosKelapa = place("Kios Kelapa", 1415, 0, 10),
	kiosEsKrim = place("Kios Es Krim", 1415, 0, -300),
	terminalFeri = place("Terminal Feri", 1314, 0, 457),
	dermaga = place("Dermaga", 1694, 3, -120),
	mercusuar = place("Mercusuar", 1324, 0, -800),
	-- Bandara
	bandara = place("Terminal Bandara", -975, 0.4, 392),
	parkirBandara = place("Parkir Bandara", -990, 0.3, 299, 90),
	parkirBandaraTimur = place("Parkir Bandara Timur", -900, 0.3, 284),
	papanPilot = place("Landasan Bandara", -1262, 0.4, 811),
	landasan = place("Landasan Bandara", -1010, 0.4, 844),
	-- Countryside
	lumbung = place("Lumbung", -830, 0, 129),
	kincirAngin = place("Kincir Angin", -960, 0, 164),
	perkemahan = place("Perkemahan", -865, 3, -400),
	-- Perkebunan Besar (map/BuildPerkebunan): toko bibit, gudang hasil, dan titik-titik di ladang
	tokoBibit = place("Toko Bibit", -746, 0.3, 88),
	gudangTani = place("Gudang Hasil", -775, 0.3, 89),
	ladangUtara = place("Ladang Utara", -757, 0.6, 134),
	ladangTengah = place("Ladang Tengah", -757, 0.6, 178),
	ladangSelatan = place("Ladang Selatan", -757, 0.6, 224),
	ladangBarat = place("Ladang Barat", -784, 0.6, 156),
	ladangTimur = place("Ladang Timur", -730, 0.6, 200),
} :: { [string]: Place }

local RUMAH = {
	"rumah18",
	"rumah20",
	"rumah27",
	"rumah29",
	"rumah34",
	"rumah49",
	"rumah62",
	"rumah65",
	"rumah74",
	"rumah76",
	"rumah78",
	"rumah85",
	"rumah88",
}

JobConfig.POOLS = {
	-- petak-petak di Perkebunan Besar (pekerjaan Petani)
	ladang = { "ladangUtara", "ladangTengah", "ladangSelatan", "ladangBarat", "ladangTimur" },
	-- pemandangan yang dilewati penerbangan wisata (pekerjaan Pilot)
	wisataUdara = {
		"mercusuar",
		"dermaga",
		"terminalFeri",
		"menara",
		"mall",
		"tamanKota",
		"balaiKota",
		"kincirAngin",
		"perkemahan",
	},
	-- halte bus (pekerjaan Sopir Bus)
	halte = {
		"tamanPerumahan",
		"rumahSakit",
		"balaiKota",
		"sekolah",
		"tamanKota",
		"mall",
		"perpustakaan",
		"hotel",
		"bandara",
	},
	-- tempat mengambil paket
	depot = { "kantorPos", "toko", "mall", "terminalFeri", "bandara", "lumbung" },
	-- tujuan antar (rumah + tempat umum)
	alamat = {
		"kafe",
		"balaiKota",
		"rumahSakit",
		"sekolah",
		"kafeKota",
		"pusatBisnis",
		"perpustakaan",
		"bioskop",
		"hotel",
		"menara",
		"spbu",
		"sewaJetSki",
		"kiosKelapa",
		"kiosEsKrim",
		"lumbung",
		"perkemahan",
		table.unpack(RUMAH),
	},
	rumah = RUMAH,
	-- tempat lapang untuk mobil mogok
	mogok = {
		"sekolah",
		"tamanBermain",
		"spbuParkir",
		"parkirUmum",
		"parkirUmumBarat",
		"parkirBandara",
		"parkirBandaraTimur",
	},
	patroli = {
		"tamanPerumahan",
		"toko",
		"sekolah",
		"tamanBermain",
		"tamanKota",
		"mall",
		"kantorPos",
		"perpustakaan",
		"bioskop",
		"menara",
		"spbu",
		"dermaga",
		"terminalFeri",
		"kiosEsKrim",
		"bandara",
	},
	-- tempat warga menunggu bantuan
	warga = {
		"tamanPerumahan",
		"tamanBermain",
		"tamanKota",
		"mall",
		"perpustakaan",
		"bioskop",
		"dermaga",
	},
	penyeberangan = { "sekolah", "aula", "tamanBermain", "mall" },
	-- lokasi api kecil (tempat sampah berasap)
	kebakaran = {
		"kafe",
		"toko",
		"sekolah",
		"kafeKota",
		"bioskop",
		"lumbung",
		"kiosKelapa",
		"rumah18",
		"rumah34",
		"rumah76",
	},
	pohon = { "tamanPerumahan", "tamanBermain", "tamanKota", "aula", "kincirAngin" },
} :: { [string]: { string } }

-- ---------------------------------------------------------------- pekerjaan

JobConfig.LIST = {
	{
		id = "kurir",
		name = "Kurir",
		icon = "📦",
		color = Color3.fromRGB(240, 150, 40),
		description = "Ambil paket lalu antar ke alamat tujuan. Makin jauh, makin besar upahnya!",
		workplace = "Kantor Pos, Toko, dan Mall",
		uniform = {
			hat = "cap",
			hatColor = Color3.fromRGB(240, 150, 40),
			vest = Color3.fromRGB(240, 150, 40),
			trim = Color3.fromRGB(250, 250, 250),
			badge = Color3.fromRGB(120, 80, 50),
		},
		tasks = {
			{
				id = "dekat",
				title = "Antar paket",
				weight = 3,
				basePay = 30,
				payPerStud = 0.08,
				steps = {
					{
						pool = "depot",
						nearest = 1,
						action = "Ambil paket",
						text = "Ambil paket di {tempat}",
						hold = 1,
						prop = "package",
						consume = true,
					},
					{
						pool = "alamat",
						minDist = 150,
						maxDist = 900,
						action = "Serahkan paket",
						text = "Antar paket ke {tempat}",
						hold = 1,
					},
				},
			},
			{
				id = "jauh",
				title = "Kiriman kilat antar kawasan",
				weight = 1,
				basePay = 40,
				payPerStud = 0.09,
				steps = {
					{
						pool = "depot",
						nearest = 1,
						action = "Ambil paket",
						text = "Ambil paket kilat di {tempat}",
						hold = 1,
						prop = "package",
						consume = true,
					},
					{
						pool = "alamat",
						minDist = 900,
						maxDist = 3200,
						action = "Serahkan paket",
						text = "Antar paket kilat ke {tempat}",
						hold = 1,
					},
				},
			},
		},
	},
	{
		id = "mekanik",
		name = "Mekanik",
		icon = "🔧",
		color = Color3.fromRGB(90, 150, 235),
		description = "Servis mobil pelanggan di Bengkel dan tolong mobil yang mogok di jalan.",
		workplace = "Bengkel (kota kecil)",
		uniform = {
			hat = "cap",
			hatColor = Color3.fromRGB(50, 90, 160),
			vest = Color3.fromRGB(60, 100, 170),
			trim = Color3.fromRGB(255, 200, 40),
			badge = Color3.fromRGB(200, 205, 212),
		},
		tasks = {
			{
				id = "servis",
				title = "Servis mobil pelanggan",
				weight = 3,
				basePay = 45,
				payPerStud = 0,
				steps = {
					{
						place = "bengkelServis",
						offset = Vector3.new(0, 0, -11),
						action = "Periksa mesin",
						text = "Periksa mesin mobil di {tempat}",
						hold = 3,
						prop = "car",
					},
					{
						sameAs = 1,
						offset = Vector3.new(-7, 0, 3),
						action = "Ganti oli",
						text = "Ganti oli mobil",
						hold = 3,
					},
					{
						sameAs = 1,
						offset = Vector3.new(7, 0, -3),
						action = "Pompa ban",
						text = "Pompa ban mobil",
						hold = 3,
					},
					{
						sameAs = 1,
						offset = Vector3.new(0, 0, 11),
						action = "Cuci mobil",
						text = "Cuci mobil sampai kinclong",
						hold = 3,
					},
				},
			},
			{
				id = "mogok",
				title = "Panggilan mobil mogok",
				weight = 2,
				basePay = 40,
				payPerStud = 0.08,
				steps = {
					{
						place = "bengkel",
						action = "Ambil peralatan",
						text = "Ambil kotak peralatan di {tempat}",
						hold = 1,
					},
					{
						pool = "mogok",
						minDist = 200,
						offset = Vector3.new(0, 0, -11),
						action = "Perbaiki mesin",
						text = "Perbaiki mobil mogok di {tempat}",
						hold = 4,
						prop = "car",
					},
					{
						sameAs = 2,
						offset = Vector3.new(7, 0, 3),
						action = "Ganti ban",
						text = "Ganti ban yang kempes",
						hold = 3,
					},
				},
			},
		},
	},
	{
		id = "sopir",
		name = "Sopir Bus",
		icon = "🚌",
		color = Color3.fromRGB(250, 190, 40),
		description = "Jemput penumpang di halte dan antar keliling kota dengan Bus Kota.",
		workplace = "Halte di seluruh kota",
		uniform = {
			hat = "peaked",
			hatColor = Color3.fromRGB(40, 60, 110),
			vest = Color3.fromRGB(60, 90, 150),
			trim = Color3.fromRGB(250, 200, 60),
			badge = Color3.fromRGB(250, 200, 60),
		},
		tasks = {
			{
				id = "rute",
				title = "Rute bus kota",
				weight = 3,
				basePay = 45,
				payPerStud = 0.08,
				steps = {
					{
						pool = "halte",
						nearest = 2,
						action = "Naikkan penumpang",
						text = "Jemput penumpang di halte {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						pool = "halte",
						minDist = 200,
						maxDist = 1200,
						action = "Turunkan penumpang",
						text = "Antar penumpang ke {tempat}",
						hold = 2,
					},
					{
						pool = "halte",
						minDist = 200,
						maxDist = 1200,
						action = "Turunkan penumpang",
						text = "Lanjut ke halte {tempat}",
						hold = 2,
					},
				},
			},
			{
				id = "sekolah",
				title = "Bus antar-jemput sekolah",
				weight = 1,
				basePay = 50,
				payPerStud = 0.08,
				steps = {
					{
						place = "sekolah",
						action = "Naikkan murid",
						text = "Jemput murid di {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						pool = "halte",
						minDist = 250,
						maxDist = 1500,
						action = "Turunkan murid",
						text = "Antar murid ke {tempat}",
						hold = 2,
					},
				},
			},
		},
	},
	{
		id = "pilot",
		name = "Pilot",
		icon = "✈️",
		color = Color3.fromRGB(70, 150, 230),
		description = "Terbangkan pesawat wisata keliling Kota ROBLOCK. Ambil pesawat di papan Pilot di tepi landasan bandara.",
		workplace = "Landasan Bandara",
		uniform = {
			hat = "peaked",
			hatColor = Color3.fromRGB(250, 250, 250),
			vest = Color3.fromRGB(30, 50, 100),
			trim = Color3.fromRGB(240, 196, 80),
			badge = Color3.fromRGB(240, 196, 80),
		},
		tasks = {
			{
				id = "wisata",
				title = "Penerbangan wisata",
				weight = 3,
				basePay = 80,
				payPerStud = 0.02,
				steps = {
					{
						place = "papanPilot",
						action = "Naikkan penumpang",
						text = "Jemput penumpang di tepi {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						pool = "wisataUdara",
						minDist = 500,
						action = "Terbang",
						text = "Terbang melewati {tempat}",
						hold = 0,
						fly = 110,
					},
					{
						pool = "wisataUdara",
						minDist = 500,
						action = "Terbang",
						text = "Lanjut terbang melewati {tempat}",
						hold = 0,
						fly = 110,
					},
					{
						place = "landasan",
						action = "Mendarat",
						text = "Pelankan pesawat dan mendarat di {tempat}",
						hold = 0,
						fly = 300,
						landed = true,
					},
				},
			},
			{
				id = "antar",
				title = "Antar penumpang keliling pulau",
				weight = 1,
				basePay = 70,
				payPerStud = 0.02,
				steps = {
					{
						place = "papanPilot",
						action = "Naikkan penumpang",
						text = "Jemput penumpang di tepi {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						place = "mercusuar",
						action = "Terbang",
						text = "Terbang ke Pulau Pantai, lewati {tempat}",
						hold = 0,
						fly = 110,
					},
					{
						place = "landasan",
						action = "Mendarat",
						text = "Kembali dan mendarat di {tempat}",
						hold = 0,
						fly = 300,
						landed = true,
					},
				},
			},
		},
	},
	{
		id = "polisi",
		name = "Polisi",
		icon = "👮",
		color = Color3.fromRGB(60, 90, 190),
		description = "Jaga kota tetap aman dan tertib: patroli, bantu warga, dan seberangkan anak-anak.",
		workplace = "Pos Polisi di Balai Kota",
		uniform = {
			hat = "peaked",
			hatColor = Color3.fromRGB(35, 50, 110),
			vest = Color3.fromRGB(45, 65, 140),
			trim = Color3.fromRGB(255, 210, 60),
			badge = Color3.fromRGB(255, 210, 60),
		},
		tasks = {
			{
				id = "patroli",
				title = "Patroli kota",
				weight = 3,
				basePay = 30,
				payPerStud = 0.08,
				steps = {
					{
						pool = "patroli",
						nearest = 3,
						action = "Periksa keadaan",
						text = "Patroli ke {tempat}",
						hold = 2,
					},
					{
						pool = "patroli",
						minDist = 120,
						maxDist = 900,
						action = "Periksa keadaan",
						text = "Lanjut patroli ke {tempat}",
						hold = 2,
					},
					{
						pool = "patroli",
						minDist = 120,
						maxDist = 900,
						action = "Periksa keadaan",
						text = "Patroli terakhir di {tempat}",
						hold = 2,
					},
				},
			},
			{
				id = "tersesat",
				title = "Antar anak tersesat pulang",
				weight = 2,
				basePay = 35,
				payPerStud = 0.08,
				steps = {
					{
						pool = "warga",
						nearest = 3,
						action = "Tenangkan anak",
						text = "Temui anak yang tersesat di {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						pool = "rumah",
						minDist = 150,
						maxDist = 1400,
						action = "Antar sampai rumah",
						text = "Antar anak itu pulang ke {tempat}",
						hold = 1,
					},
				},
			},
			{
				id = "seberang",
				title = "Bantu menyeberang jalan",
				weight = 2,
				basePay = 45,
				payPerStud = 0.08,
				steps = {
					{
						place = "balaiKota",
						action = "Ambil rompi dan peluit",
						text = "Ambil rompi dan peluit di {tempat}",
						hold = 1,
					},
					{
						pool = "penyeberangan",
						minDist = 100,
						action = "Seberangkan warga",
						text = "Bantu warga menyeberang di {tempat}",
						hold = 5,
						prop = "cone",
						consume = true,
					},
				},
			},
		},
	},
	{
		id = "pemadam",
		name = "Pemadam Kebakaran",
		icon = "🚒",
		color = Color3.fromRGB(225, 70, 60),
		description = "Padamkan api kecil sebelum membesar dan selamatkan kucing yang terjebak di pohon.",
		workplace = "Kantor Pemadam Kebakaran",
		uniform = {
			hat = "helmet",
			hatColor = Color3.fromRGB(215, 50, 45),
			vest = Color3.fromRGB(240, 190, 50),
			trim = Color3.fromRGB(230, 232, 236),
			badge = Color3.fromRGB(255, 210, 60),
		},
		tasks = {
			{
				id = "api",
				title = "Padamkan api",
				weight = 3,
				basePay = 40,
				payPerStud = 0.08,
				steps = {
					{
						place = "damkar",
						action = "Siapkan selang",
						text = "Siapkan selang di {tempat}",
						hold = 1,
					},
					{
						pool = "kebakaran",
						minDist = 80,
						action = "Semprot air",
						text = "Padamkan kios yang terbakar di {tempat}",
						hold = 4,
						prop = "kios", -- kios kayu terbakar (api besar + asap)
						consume = true,
					},
					{
						sameAs = 2,
						offset = Vector3.new(9, 0, 0),
						action = "Semprot air",
						text = "Padamkan sisa api",
						hold = 3,
						prop = "fire",
						consume = true,
					},
				},
			},
			{
				id = "kucing",
				title = "Selamatkan kucing",
				weight = 2,
				basePay = 45,
				payPerStud = 0.08,
				steps = {
					{
						place = "damkar",
						action = "Ambil tangga",
						text = "Ambil tangga di {tempat}",
						hold = 1,
					},
					{
						pool = "pohon",
						minDist = 80,
						action = "Turunkan kucing",
						text = "Selamatkan kucing di {tempat}",
						hold = 4,
						prop = "cat",
						consume = true,
					},
				},
			},
		},
	},
	{
		id = "petani",
		name = "Petani",
		icon = "🧑‍🌾",
		color = Color3.fromRGB(86, 160, 80),
		description = "Ambil bibit di Toko Bibit, tanam dan rawat sayur di Perkebunan Besar, lalu antar hasil panen ke Gudang Hasil. Hasil panen dijual 25% lebih mahal.",
		workplace = "Toko Bibit Perkebunan",
		uniform = {
			hat = "cap",
			hatColor = Color3.fromRGB(236, 204, 110),
			vest = Color3.fromRGB(70, 120, 190),
			trim = Color3.fromRGB(250, 250, 245),
			badge = Color3.fromRGB(120, 200, 90),
		},
		tasks = {
			{
				id = "tanam",
				title = "Tanam bibit",
				weight = 3,
				basePay = 35,
				payPerStud = 0.06,
				steps = {
					{
						place = "tokoBibit",
						action = "Ambil bibit",
						text = "Ambil bibit di {tempat}",
						hold = 1,
					},
					{
						pool = "ladang",
						minDist = 30,
						action = "Tanam bibit",
						text = "Tanam bibit di {tempat}",
						hold = 3,
					},
				},
			},
			{
				id = "siram",
				title = "Siram tanaman",
				weight = 2,
				basePay = 32,
				payPerStud = 0.06,
				steps = {
					{
						place = "tokoBibit",
						action = "Ambil ember",
						text = "Ambil ember air di {tempat}",
						hold = 1,
					},
					{
						pool = "ladang",
						minDist = 30,
						action = "Siram tanaman",
						text = "Siram tanaman di {tempat}",
						hold = 3,
					},
				},
			},
			{
				id = "panen",
				title = "Panen dan antar ke gudang",
				weight = 3,
				basePay = 45,
				payPerStud = 0.06,
				steps = {
					{
						pool = "ladang",
						action = "Panen sayur",
						text = "Panen sayur di {tempat}",
						hold = 3,
					},
					{
						place = "gudangTani",
						action = "Antar hasil",
						text = "Antar hasil panen ke {tempat}",
						hold = 1,
					},
				},
			},
		},
	},
	{
		id = "dokter",
		name = "Dokter",
		icon = "🩺",
		color = Color3.fromRGB(40, 180, 160),
		description = "Periksa pasien di Rumah Sakit, kunjungi pasien di rumah, dan jemput yang butuh bantuan.",
		workplace = "Rumah Sakit",
		uniform = {
			hat = "mirror",
			hatColor = Color3.fromRGB(220, 225, 230),
			vest = Color3.fromRGB(248, 248, 250),
			trim = Color3.fromRGB(40, 180, 160),
			badge = Color3.fromRGB(235, 90, 110),
		},
		tasks = {
			{
				id = "kunjungan",
				title = "Kunjungan ke rumah pasien",
				weight = 3,
				basePay = 40,
				payPerStud = 0.08,
				steps = {
					{
						place = "rumahSakit",
						action = "Ambil tas dokter",
						text = "Ambil tas dokter di {tempat}",
						hold = 1,
					},
					{
						pool = "rumah",
						minDist = 150,
						action = "Periksa pasien",
						text = "Periksa pasien di {tempat}",
						hold = 4,
						prop = "person",
					},
				},
			},
			{
				id = "jemput",
				title = "Jemput pasien",
				weight = 2,
				basePay = 40,
				payPerStud = 0.08,
				steps = {
					{
						pool = "warga",
						nearest = 4,
						action = "Bantu pasien",
						text = "Jemput pasien di {tempat}",
						hold = 2,
						prop = "person",
						consume = true,
					},
					{
						place = "rumahSakit",
						action = "Antar ke dokter jaga",
						text = "Antar pasien ke {tempat}",
						hold = 2,
					},
				},
			},
			{
				id = "periksa",
				title = "Periksa pasien di Rumah Sakit",
				weight = 2,
				basePay = 40,
				payPerStud = 0,
				steps = {
					{
						place = "rumahSakit",
						offset = Vector3.new(-14, 0, 0),
						action = "Periksa pasien",
						text = "Periksa pasien pertama di {tempat}",
						hold = 3,
						prop = "person",
						consume = true,
					},
					{
						sameAs = 1,
						offset = Vector3.new(0, 0, 0),
						action = "Beri obat",
						text = "Beri obat ke pasien kedua",
						hold = 3,
						prop = "person",
						consume = true,
					},
					{
						sameAs = 1,
						offset = Vector3.new(14, 0, 0),
						action = "Balut luka",
						text = "Balut luka pasien ketiga",
						hold = 3,
						prop = "person",
						consume = true,
					},
				},
			},
		},
	},
} :: { JobDef }

local byId: { [string]: JobDef } = {}
for _, def in JobConfig.LIST do
	assert(byId[def.id] == nil, "id pekerjaan ganda: " .. def.id)
	byId[def.id] = def
end

-- Mengembalikan definisi pekerjaan, atau nil jika id tidak dikenal.
-- Aman dipanggil dengan nilai apa pun dari client.
function JobConfig.get(id: any): JobDef?
	if type(id) ~= "string" or #id > 32 then
		return nil
	end
	return byId[id]
end

function JobConfig.levelFor(tasks: number): number
	local level = 1
	for index, needed in JobConfig.LEVELS do
		if tasks >= needed then
			level = index
		end
	end
	return level
end

-- Jumlah tugas untuk naik ke level berikutnya, nil jika sudah level tertinggi.
function JobConfig.nextLevelAt(tasks: number): number?
	return JobConfig.LEVELS[JobConfig.levelFor(tasks) + 1]
end

function JobConfig.payMultiplier(level: number): number
	return 1 + JobConfig.LEVEL_BONUS * (level - 1)
end

return JobConfig
