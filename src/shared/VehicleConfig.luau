--!strict
-- Daftar kendaraan. Menambah kendaraan baru = menambah satu entri di LIST.
-- Modul ini dipakai server (harga, validasi, fisika) dan client (UI, kemudi).
-- Server TIDAK pernah menerima harga/kecepatan dari client; hanya `id`.
--
-- Satuan: panjang dalam stud, kecepatan stud/detik (1 stud/dtk ~ 1 km/j di speedometer).
-- Arah depan model = sumbu -Z, titik asal model = tengah mobil di permukaan tanah.

export type BodyStyle = "hatch" | "sedan" | "suv" | "sport"

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
}

export type VehicleDef = {
	id: string,
	name: string,
	class: string, -- teks jenis yang tampil di UI
	description: string,
	price: number,
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
VehicleConfig.ATTR_VEHICLE_ID = "VehicleId"
VehicleConfig.ATTR_OWNER = "OwnerUserId"
VehicleConfig.ATTR_OWNED = "OwnedVehicles" -- atribut Player: id dipisah koma
VehicleConfig.ATTR_DEALER_PROMPT = "DealerVehicleId" -- atribut ProximityPrompt pajangan

VehicleConfig.LIST = {
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
} :: { VehicleDef }

local byId: { [string]: VehicleDef } = {}
for _, def in VehicleConfig.LIST do
	assert(byId[def.id] == nil, "id kendaraan ganda: " .. def.id)
	byId[def.id] = def
end

-- Mengembalikan definisi kendaraan, atau nil jika id tidak dikenal.
-- Aman dipanggil dengan nilai apa pun dari client.
function VehicleConfig.get(id: any): VehicleDef?
	if type(id) ~= "string" or #id > 32 then
		return nil
	end
	return byId[id]
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
