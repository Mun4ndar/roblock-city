--!strict
-- Daftar kendaraan. Menambah kendaraan baru = menambah satu entri di LIST.
-- Modul ini dipakai server (harga, validasi, fisika) dan client (UI, kemudi).
-- Server TIDAK pernah menerima harga/kecepatan dari client; hanya `id`.
--
-- Satuan: panjang dalam stud, kecepatan stud/detik (1 stud/dtk ~ 1 km/j di speedometer).
-- Arah depan model = sumbu -Z, titik asal model = tengah mobil di permukaan tanah.

export type BodyStyle = "hatch" | "sedan" | "suv" | "sport" | "van" | "truck" | "bike"

export type VehicleBody = {
	style: BodyStyle,
	length: number,
	width: number,
	clearance: number, -- jarak bodi ke tanah
	lowerHeight: number, -- tinggi bodi bawah (pintu, kap)
	cabinHeight: number, -- tinggi kaca + atap
	cabinFront: number, -- awal kabin, 0 = moncong depan, 1 = ujung belakang
	cabinBack: number, -- akhir kabin
	rakeFront: number, -- panjang kemiringan kaca depan
	rakeBack: number, -- panjang kemiringan kaca belakang
	wheelRadius: number,
	wheelWidth: number,
	wheelbase: number, -- jarak poros depan ke poros belakang
	spoiler: boolean?,
	roofRack: boolean?,
	-- Perlengkapan kendaraan dinas (semua opsional):
	lightBar: { Color3 }?, -- dua warna lampu atap; berkedip saat ada pengemudi
	band: Color3?, -- pita lebar di sisi bodi
	sideText: string?, -- tulisan di sisi bodi / boks
	box: { height: number, color: Color3 }?, -- boks di belakang kabin (ambulans, truk)
	ladder: boolean?, -- tangga di atas boks
	bigLadder: boolean?, -- tangga panjang bertingkat (truk tangga)
	bike: boolean?, -- motor: jok berurutan di tengah, dua roda tampak (roda fisika tetap empat, tersembunyi)
}

export type VehicleDef = {
	id: string,
	name: string,
	class: string, -- teks jenis yang tampil di UI
	description: string,
	price: number,
	job: string?, -- kendaraan dinas: hanya untuk pemain dengan pekerjaan ini (tidak dijual)
	extra: boolean?, -- kendaraan dinas tambahan: pekerjaan yang sama, tombol kedua di menu pekerjaan
	seats: number, -- termasuk pengemudi (1, 2 atau 4)
	maxSpeed: number,
	reverseSpeed: number,
	acceleration: number, -- stud/detik^2
	brake: number, -- stud/detik^2
	steerAngle: number, -- derajat, saat pelan
	color: Color3,
	accent: Color3, -- warna strip/aksen
	body: VehicleBody,
}

local VehicleConfig = {}

-- Aturan server
VehicleConfig.MAX_SPAWNED_PER_PLAYER = 1
VehicleConfig.SPAWN_COOLDOWN = 4 -- detik antar spawn
VehicleConfig.SPAWN_DISTANCE = 13 -- stud di depan pemain
VehicleConfig.DEALER_RANGE = 75 -- harus sedekat ini dari dealer untuk membeli
VehicleConfig.REMOTE_COOLDOWN = 0.4 -- jeda minimal antar panggilan remote kendaraan
VehicleConfig.SPEED_TOLERANCE = 1.6 -- server menegur jika kecepatan > maxSpeed * ini

-- Nama tag / atribut bersama
VehicleConfig.TAG_VEHICLE = "Vehicle" -- Model kendaraan yang bisa dikendarai
VehicleConfig.TAG_DEALER = "VehicleDealer" -- Part penanda lokasi dealer
VehicleConfig.TAG_DISPLAY_SLOT = "VehicleDisplaySlot" -- Part tempat mobil pajangan
VehicleConfig.TAG_BEACON = "VehicleBeacon" -- Part lampu atap kendaraan dinas
VehicleConfig.ATTR_BEACON_PHASE = "BeaconPhase" -- 0 atau 1: giliran kedip
VehicleConfig.ATTR_VEHICLE_ID = "VehicleId"
VehicleConfig.ATTR_OWNER = "OwnerUserId"
VehicleConfig.ATTR_OWNED = "OwnedVehicles" -- atribut Player: id dipisah koma
VehicleConfig.ATTR_DEALER_PROMPT = "DealerVehicleId" -- atribut ProximityPrompt pajangan
VehicleConfig.ATTR_MODS = "VehicleMods" -- atribut Player: JSON { [id] = { paint, rim } }
VehicleConfig.ATTR_MOD_PROMPT = "VehicleModShop" -- atribut ProximityPrompt di bengkel modifikasi

-- Modifikasi di Bengkel (Halaman Bengkel, kota kecil). Indeks 0 = warna asli pabrik.
-- Menambah pilihan = menambah warna di daftar ini.
VehicleConfig.MOD_POSITION = Vector3.new(195, 1, 303)
VehicleConfig.MOD_RANGE = 60 -- mobil harus sedekat ini dari bengkel
VehicleConfig.PAINT_PRICE = 150
VehicleConfig.RIM_PRICE = 100
VehicleConfig.PAINTS = {
	Color3.fromRGB(226, 54, 54),
	Color3.fromRGB(245, 140, 40),
	Color3.fromRGB(250, 208, 60),
	Color3.fromRGB(70, 180, 100),
	Color3.fromRGB(40, 170, 170),
	Color3.fromRGB(52, 120, 220),
	Color3.fromRGB(130, 90, 200),
	Color3.fromRGB(240, 120, 170),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(40, 42, 50),
}
VehicleConfig.RIMS = {
	Color3.fromRGB(200, 204, 212),
	Color3.fromRGB(40, 42, 50),
	Color3.fromRGB(240, 196, 80),
	Color3.fromRGB(226, 54, 54),
	Color3.fromRGB(52, 120, 220),
}

VehicleConfig.LIST = {
	{
		-- Tampilan dari templat mesh ReplicatedStorage.Assets.CarShells.lincah (buatan Blender,
		-- assets/blender/motor_shell.fbx). Ukuran di bawah mengikuti mesh itu.
		id = "lincah",
		name = "Lincah",
		class = "Motor Skuter",
		description = "Motor skuter mungil untuk berdua. Murah dan gesit di jalan kota!",
		price = 250,
		seats = 2,
		maxSpeed = 58,
		reverseSpeed = 12,
		acceleration = 28,
		brake = 70,
		steerAngle = 30,
		color = Color3.fromRGB(64, 190, 170),
		accent = Color3.fromRGB(250, 250, 250),
		body = {
			style = "bike",
			bike = true,
			length = 9.2,
			width = 4.4,
			clearance = 0.8,
			lowerHeight = 1.5,
			cabinHeight = 0.6,
			cabinFront = 0.5,
			cabinBack = 0.92,
			rakeFront = 0.5,
			rakeBack = 0.5,
			wheelRadius = 1.2,
			wheelWidth = 0.7,
			wheelbase = 6,
		},
	},
	{
		id = "kancil",
		name = "Kancil",
		class = "Mobil Kota",
		description = "Mungil, irit, dan lincah. Cocok untuk mobil pertama!",
		price = 400,
		seats = 4,
		maxSpeed = 62,
		reverseSpeed = 22,
		acceleration = 26,
		brake = 70,
		steerAngle = 34,
		color = Color3.fromRGB(255, 196, 46),
		accent = Color3.fromRGB(255, 255, 255),
		body = {
			style = "hatch",
			length = 12.5,
			width = 6.6,
			clearance = 0.9,
			lowerHeight = 2.3,
			cabinHeight = 2.9,
			cabinFront = 0.26,
			cabinBack = 0.97,
			rakeFront = 1.6,
			rakeBack = 0.7,
			wheelRadius = 1.25,
			wheelWidth = 1.0,
			wheelbase = 7.6,
		},
	},
	{
		id = "serasi",
		name = "Serasi",
		class = "Sedan",
		description = "Sedan keluarga yang nyaman untuk jalan-jalan keliling kota.",
		price = 2500,
		seats = 4,
		maxSpeed = 78,
		reverseSpeed = 24,
		acceleration = 30,
		brake = 80,
		steerAngle = 32,
		color = Color3.fromRGB(52, 120, 220),
		accent = Color3.fromRGB(225, 230, 240),
		body = {
			style = "sedan",
			length = 15.5,
			width = 7,
			clearance = 0.9,
			lowerHeight = 2.2,
			cabinHeight = 2.8,
			cabinFront = 0.3,
			cabinBack = 0.8,
			rakeFront = 1.9,
			rakeBack = 1.7,
			wheelRadius = 1.3,
			wheelWidth = 1.1,
			wheelbase = 9.4,
		},
	},
	{
		id = "jelajah",
		name = "Jelajah",
		class = "SUV",
		description = "Tinggi dan tangguh. Siap diajak ke pedesaan dan pantai.",
		price = 6000,
		seats = 4,
		maxSpeed = 72,
		reverseSpeed = 24,
		acceleration = 28,
		brake = 80,
		steerAngle = 32,
		color = Color3.fromRGB(46, 150, 96),
		accent = Color3.fromRGB(60, 64, 72),
		body = {
			style = "suv",
			length = 15,
			width = 7.4,
			clearance = 1.5,
			lowerHeight = 2.6,
			cabinHeight = 3.1,
			cabinFront = 0.27,
			cabinBack = 0.98,
			rakeFront = 1.4,
			rakeBack = 0.6,
			wheelRadius = 1.75,
			wheelWidth = 1.4,
			wheelbase = 9,
			roofRack = true,
		},
	},
	{
		id = "kilat",
		name = "Kilat",
		class = "Mobil Sport",
		description = "Rendah, ramping, dan paling kencang di Kota ROBLOCK.",
		price = 15000,
		seats = 2,
		maxSpeed = 112,
		reverseSpeed = 26,
		acceleration = 44,
		brake = 110,
		steerAngle = 30,
		color = Color3.fromRGB(226, 54, 54),
		accent = Color3.fromRGB(30, 32, 38),
		body = {
			style = "sport",
			length = 15.5,
			width = 7.4,
			clearance = 0.7,
			lowerHeight = 1.9,
			cabinHeight = 2.5,
			cabinFront = 0.36,
			cabinBack = 0.76,
			rakeFront = 2.6,
			rakeBack = 2.4,
			wheelRadius = 1.35,
			wheelWidth = 1.5,
			wheelbase = 9.6,
			spoiler = true,
		},
	},
	{
		-- Tampilan dari templat mesh ReplicatedStorage.Assets.CarShells.elegan (mobil resmi Roblox
		-- "Car", gratis di Creator Store). Ukuran di bawah mengikuti mesh itu (skala 0,75).
		id = "elegan",
		name = "Elegan",
		class = "Sedan Mewah",
		description = "Sedan mewah yang mengilap dengan lampu dan velg asli. Nyaman dan cepat.",
		price = 9000,
		seats = 4,
		maxSpeed = 96,
		reverseSpeed = 25,
		acceleration = 36,
		brake = 95,
		steerAngle = 31,
		color = Color3.fromRGB(235, 70, 70),
		accent = Color3.fromRGB(30, 32, 38),
		body = {
			style = "sedan",
			length = 15.4,
			width = 6.44,
			clearance = 0.73,
			lowerHeight = 1.1, -- rendah supaya kursi turun dan kepala tidak menembus atap mesh
			cabinHeight = 2.8,
			cabinFront = 0.33,
			cabinBack = 0.8,
			rakeFront = 2,
			rakeBack = 2,
			wheelRadius = 1.13,
			wheelWidth = 0.93,
			wheelbase = 9.28,
		},
	},
} :: { VehicleDef }

-- Kendaraan dinas: gratis, tidak dijual di dealer, dan hanya bisa dikeluarkan
-- pemain yang sedang menjalani pekerjaan `job` (lihat JobConfig). Menambah
-- kendaraan dinas untuk pekerjaan lain = menambah satu entri di sini.
VehicleConfig.SERVICE = {
	{
		id = "ambulans",
		name = "Ambulans",
		class = "Kendaraan Dinas",
		description = "Mengantar dokter ke pasien dengan cepat dan aman.",
		price = 0,
		job = "dokter",
		seats = 2,
		maxSpeed = 70,
		reverseSpeed = 22,
		acceleration = 28,
		brake = 80,
		steerAngle = 31,
		color = Color3.fromRGB(245, 247, 250),
		accent = Color3.fromRGB(40, 180, 160),
		body = {
			style = "van",
			length = 17,
			width = 7.6,
			clearance = 1.3,
			lowerHeight = 2.6,
			cabinHeight = 3,
			cabinFront = 0.12,
			cabinBack = 0.42,
			rakeFront = 1.5,
			rakeBack = 0.3,
			wheelRadius = 1.5,
			wheelWidth = 1.3,
			wheelbase = 10.5,
			lightBar = { Color3.fromRGB(40, 200, 180), Color3.fromRGB(255, 255, 255) },
			band = Color3.fromRGB(40, 180, 160),
			sideText = "AMBULANS",
			box = { height = 4.2, color = Color3.fromRGB(245, 247, 250) },
		},
	},
	{
		id = "bus",
		name = "Bus Kota",
		class = "Kendaraan Dinas",
		description = "Bus kuning untuk mengantar penumpang keliling kota.",
		price = 0,
		job = "sopir",
		seats = 4,
		maxSpeed = 66,
		reverseSpeed = 20,
		acceleration = 22,
		brake = 80,
		steerAngle = 30,
		color = Color3.fromRGB(250, 196, 50),
		accent = Color3.fromRGB(40, 60, 110),
		body = {
			style = "truck",
			length = 24,
			width = 8,
			clearance = 1.4,
			lowerHeight = 2.8,
			cabinHeight = 3.6,
			cabinFront = 0.04,
			cabinBack = 0.96,
			rakeFront = 0.8,
			rakeBack = 0.4,
			wheelRadius = 1.6,
			wheelWidth = 1.4,
			wheelbase = 14,
			band = Color3.fromRGB(40, 60, 110),
			sideText = "BUS KOTA",
		},
	},
	{
		id = "damkar",
		name = "Mobil Pemadam",
		class = "Kendaraan Dinas",
		description = "Truk merah besar dengan tangga, siap memadamkan api.",
		price = 0,
		job = "pemadam",
		seats = 2,
		maxSpeed = 62,
		reverseSpeed = 20,
		acceleration = 24,
		brake = 80,
		steerAngle = 30,
		color = Color3.fromRGB(215, 50, 45),
		accent = Color3.fromRGB(250, 250, 250),
		body = {
			style = "truck",
			length = 20,
			width = 8,
			clearance = 1.5,
			lowerHeight = 2.8,
			cabinHeight = 3.2,
			cabinFront = 0.06,
			cabinBack = 0.32,
			rakeFront = 1,
			rakeBack = 0.3,
			wheelRadius = 1.7,
			wheelWidth = 1.5,
			wheelbase = 12,
			lightBar = { Color3.fromRGB(255, 70, 50), Color3.fromRGB(255, 190, 40) },
			band = Color3.fromRGB(250, 250, 250),
			sideText = "PEMADAM",
			box = { height = 3.4, color = Color3.fromRGB(215, 50, 45) },
			ladder = true,
		},
	},
	{
		id = "damkarTangga",
		name = "Truk Tangga",
		class = "Kendaraan Dinas",
		description = "Truk pemadam besar dengan tangga panjang untuk gedung tinggi.",
		price = 0,
		job = "pemadam",
		extra = true,
		seats = 2,
		maxSpeed = 56,
		reverseSpeed = 18,
		acceleration = 20,
		brake = 80,
		steerAngle = 28,
		color = Color3.fromRGB(205, 40, 36),
		accent = Color3.fromRGB(250, 250, 250),
		body = {
			style = "truck",
			length = 24,
			width = 8.4,
			clearance = 1.6,
			lowerHeight = 3.2,
			cabinHeight = 3.3,
			cabinFront = 0.05,
			cabinBack = 0.27,
			rakeFront = 1,
			rakeBack = 0.3,
			wheelRadius = 1.9,
			wheelWidth = 1.6,
			wheelbase = 14.5,
			lightBar = { Color3.fromRGB(255, 70, 50), Color3.fromRGB(255, 190, 40) },
			band = Color3.fromRGB(250, 250, 250),
			sideText = "TRUK TANGGA",
			box = { height = 3.6, color = Color3.fromRGB(205, 40, 36) },
			ladder = true,
			bigLadder = true,
		},
	},
	{
		id = "patroli",
		name = "Mobil Patroli",
		class = "Kendaraan Dinas",
		description = "Mobil polisi untuk berpatroli menjaga kota.",
		price = 0,
		job = "polisi",
		seats = 4,
		maxSpeed = 76,
		reverseSpeed = 24,
		acceleration = 30,
		brake = 85,
		steerAngle = 32,
		color = Color3.fromRGB(245, 247, 250),
		accent = Color3.fromRGB(40, 80, 190),
		body = {
			style = "sedan",
			length = 15.5,
			width = 7,
			clearance = 0.9,
			lowerHeight = 2.2,
			cabinHeight = 2.8,
			cabinFront = 0.3,
			cabinBack = 0.8,
			rakeFront = 1.9,
			rakeBack = 1.7,
			wheelRadius = 1.3,
			wheelWidth = 1.1,
			wheelbase = 9.4,
			lightBar = { Color3.fromRGB(60, 110, 255), Color3.fromRGB(255, 70, 60) },
			band = Color3.fromRGB(40, 80, 190),
			sideText = "POLISI",
		},
	},
	{
		-- Mesh bodi: ReplicatedStorage.Assets.CarShells.ojek (salinan templat motor "lincah" buatan Blender).
		id = "ojek",
		name = "Motor Ojek",
		class = "Kendaraan Dinas",
		description = "Motor skuter oranye untuk mengantar penumpang dan pesanan.",
		price = 0,
		job = "ojol",
		seats = 2,
		maxSpeed = 62,
		reverseSpeed = 12,
		acceleration = 30,
		brake = 70,
		steerAngle = 30,
		color = Color3.fromRGB(255, 150, 40),
		accent = Color3.fromRGB(40, 50, 70),
		body = {
			style = "bike",
			bike = true,
			length = 9.2,
			width = 4.4,
			clearance = 0.8,
			lowerHeight = 1.5,
			cabinHeight = 0.6,
			cabinFront = 0.5,
			cabinBack = 0.92,
			rakeFront = 0.5,
			rakeBack = 0.5,
			wheelRadius = 1.2,
			wheelWidth = 0.7,
			wheelbase = 6,
		},
	},
	{
		-- Mesh bodi: CarShells.angkot (salinan templat van "ambulans" buatan Blender, dicat hijau).
		id = "angkot",
		name = "Angkot",
		class = "Kendaraan Dinas",
		description = "Angkot hijau untuk mengangkut banyak penumpang keliling kota.",
		price = 0,
		job = "angkot",
		seats = 4,
		maxSpeed = 64,
		reverseSpeed = 20,
		acceleration = 24,
		brake = 80,
		steerAngle = 31,
		color = Color3.fromRGB(70, 170, 120),
		accent = Color3.fromRGB(250, 220, 90),
		body = {
			style = "van",
			length = 17,
			width = 7.6,
			clearance = 1.3,
			lowerHeight = 2.6,
			cabinHeight = 3,
			cabinFront = 0.12,
			cabinBack = 0.42,
			rakeFront = 1.5,
			rakeBack = 0.3,
			wheelRadius = 1.5,
			wheelWidth = 1.3,
			wheelbase = 10.5,
			band = Color3.fromRGB(250, 220, 90),
			sideText = "ANGKOT 07",
			box = { height = 4.2, color = Color3.fromRGB(70, 170, 120) },
		},
	},
} :: { VehicleDef }

local byId: { [string]: VehicleDef } = {}
local byJob: { [string]: VehicleDef } = {}
for _, def in VehicleConfig.LIST do
	assert(byId[def.id] == nil, "id kendaraan ganda: " .. def.id)
	byId[def.id] = def
end
for _, def in VehicleConfig.SERVICE do
	assert(byId[def.id] == nil, "id kendaraan ganda: " .. def.id)
	assert(def.job ~= nil, "kendaraan dinas tanpa pekerjaan: " .. def.id)
	byId[def.id] = def
	if not def.extra then
		byJob[def.job :: string] = def
	end
end

-- Mengembalikan definisi kendaraan, atau nil jika id tidak dikenal.
-- Aman dipanggil dengan nilai apa pun dari client.
function VehicleConfig.get(id: any): VehicleDef?
	if type(id) ~= "string" or #id > 32 then
		return nil
	end
	return byId[id]
end

-- Kendaraan dinas untuk pekerjaan `jobId`, atau nil jika pekerjaan itu tidak punya.
function VehicleConfig.forJob(jobId: any): VehicleDef?
	if type(jobId) ~= "string" then
		return nil
	end
	return byJob[jobId]
end

-- Kendaraan dinas tambahan (tombol kedua di menu pekerjaan) untuk `jobId`, atau nil.
function VehicleConfig.extraForJob(jobId: any): VehicleDef?
	if type(jobId) ~= "string" then
		return nil
	end
	for _, def in VehicleConfig.SERVICE do
		if def.job == jobId and def.extra then
			return def
		end
	end
	return nil
end

-- "kancil,serasi" -> { kancil = true, serasi = true }
function VehicleConfig.parseOwned(value: any): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	if type(value) == "string" then
		for id in value:gmatch("[^,]+") do
			owned[id] = true
		end
	end
	return owned
end

return VehicleConfig
