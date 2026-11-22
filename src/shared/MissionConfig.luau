--!strict
-- Misi harian dan data peta HP. Semuanya berbasis data:
--   * LIST      : semua misi; tiap hari dipilih beberapa (forDay)
--   * LANDMARKS : tempat yang tampil di peta HP dan bisa dijadikan tujuan GPS
-- Posisi tempat diambil dari JobConfig.PLACES supaya hanya ada satu sumber.
-- Modul ini ikut ter-replikasi; server yang menghitung kemajuan dan hadiah.

local JobConfig = require(script.Parent:WaitForChild("JobConfig"))

local MissionConfig = {}

export type MissionKind = "tasks" | "earn" | "visit"

export type MissionDef = {
	id: string,
	icon: string,
	title: string,
	kind: MissionKind,
	target: number, -- jumlah tugas / jumlah gaji / 1 untuk kunjungan
	place: string?, -- kunci JobConfig.PLACES (misi kunjungan)
	reward: number,
}

export type Landmark = { place: string, icon: string }

-- Keadaan misi yang dikirim ke client (atribut Player "Missions", JSON).
export type MissionView = {
	day: number,
	progress: { [string]: number },
	claimed: { [string]: boolean },
}

MissionConfig.ATTR_PLAYER = "Missions"
MissionConfig.VISIT_RADIUS = 45 -- stud (mendatar) dari titik tempat
MissionConfig.WORK_PER_DAY = 2 -- misi kerja per hari
MissionConfig.VISIT_PER_DAY = 2 -- misi kunjungan per hari
MissionConfig.DAY_OFFSET_HOURS = 7 -- pergantian hari pukul 00.00 WIB

MissionConfig.LIST = {
	{
		id = "kerja3",
		icon = "💼",
		title = "Selesaikan 3 tugas pekerjaan",
		kind = "tasks",
		target = 3,
		reward = 150,
	},
	{
		id = "kerja6",
		icon = "💪",
		title = "Selesaikan 6 tugas pekerjaan",
		kind = "tasks",
		target = 6,
		reward = 320,
	},
	{
		id = "gaji400",
		icon = "💰",
		title = "Kumpulkan gaji $400",
		kind = "earn",
		target = 400,
		reward = 180,
	},
	{
		id = "gaji900",
		icon = "🏆",
		title = "Kumpulkan gaji $900",
		kind = "earn",
		target = 900,
		reward = 400,
	},
	{
		id = "dermaga",
		icon = "🏖️",
		title = "Jalan-jalan ke Dermaga",
		kind = "visit",
		target = 1,
		place = "dermaga",
		reward = 140,
	},
	{
		id = "mercusuar",
		icon = "🚨",
		title = "Lihat Mercusuar dari dekat",
		kind = "visit",
		target = 1,
		place = "mercusuar",
		reward = 140,
	},
	{
		id = "bandara",
		icon = "✈️",
		title = "Kunjungi Terminal Bandara",
		kind = "visit",
		target = 1,
		place = "bandara",
		reward = 120,
	},
	{
		id = "menara",
		icon = "🏙️",
		title = "Kunjungi Menara ROBLOCK",
		kind = "visit",
		target = 1,
		place = "menara",
		reward = 100,
	},
	{
		id = "mall",
		icon = "🛍️",
		title = "Mampir ke ROBLOCK Mall",
		kind = "visit",
		target = 1,
		place = "mall",
		reward = 100,
	},
	{
		id = "tamanKota",
		icon = "🌳",
		title = "Bersantai di Taman Kota",
		kind = "visit",
		target = 1,
		place = "tamanKota",
		reward = 80,
	},
	{
		id = "sekolah",
		icon = "🏫",
		title = "Mampir ke Sekolah",
		kind = "visit",
		target = 1,
		place = "sekolah",
		reward = 80,
	},
	{
		id = "tamanBermain",
		icon = "🎠",
		title = "Main ke Taman Bermain",
		kind = "visit",
		target = 1,
		place = "tamanBermain",
		reward = 80,
	},
} :: { MissionDef }

-- Tempat di peta HP. Urutan = urutan di daftar tujuan GPS.
MissionConfig.LANDMARKS = {
	{ place = "tamanPerumahan", icon = "⛲" },
	{ place = "rumahSakit", icon = "🏥" },
	{ place = "balaiKota", icon = "🏛️" },
	{ place = "toko", icon = "🏪" },
	{ place = "bengkel", icon = "🔧" },
	{ place = "damkar", icon = "🚒" },
	{ place = "sekolah", icon = "🏫" },
	{ place = "tamanBermain", icon = "🎠" },
	{ place = "tamanKota", icon = "🌳" },
	{ place = "kantorPos", icon = "📮" },
	{ place = "bioskop", icon = "🎬" },
	{ place = "perpustakaan", icon = "📚" },
	{ place = "mall", icon = "🛍️" },
	{ place = "menara", icon = "🏙️" },
	{ place = "hotel", icon = "🏨" },
	{ place = "spbu", icon = "⛽" },
	{ place = "bandara", icon = "✈️" },
	{ place = "terminalFeri", icon = "⛴️" },
	{ place = "dermaga", icon = "🏖️" },
	{ place = "mercusuar", icon = "🚨" },
} :: { Landmark }

-- Batas dunia yang digambar di peta HP (stud).
MissionConfig.MAP_BOUNDS = { minX = -1150, maxX = 2300, minZ = -1200, maxZ = 1150 }

-- Tempat dealer mobil tidak ada di JobConfig.PLACES, jadi dicatat di sini.
MissionConfig.EXTRA_PLACES = {
	dealer = { name = "Dealer Mobil", position = Vector3.new(-67, 1, 511), icon = "🚗" },
	kasirKafe = {
		name = "Kasir Kafe Kota (usahamu)",
		position = Vector3.new(28, 1, -553),
		icon = "☕",
	},
	pasarTani = { name = "Pasar Tani & Kebun", position = Vector3.new(-660, 1, 334), icon = "🌽" },
}

-- ---------------------------------------------------------------- util

local byId: { [string]: MissionDef } = {}
local work: { MissionDef } = {}
local visit: { MissionDef } = {}
for _, def in MissionConfig.LIST do
	byId[def.id] = def
	table.insert(if def.kind == "visit" then visit else work, def)
end

function MissionConfig.get(id: string): MissionDef?
	return byId[id]
end

-- Nomor hari (berganti tengah malam WIB).
function MissionConfig.dayNumber(unixTime: number): number
	return math.floor((unixTime + MissionConfig.DAY_OFFSET_HOURS * 3600) / 86400)
end

local function pickFrom(list: { MissionDef }, count: number, day: number, into: { MissionDef })
	for i = 0, math.min(count, #list) - 1 do
		table.insert(into, list[(day * count + i) % #list + 1])
	end
end

-- Misi yang berlaku pada hari tertentu (sama untuk semua pemain dan server).
function MissionConfig.forDay(day: number): { MissionDef }
	local result: { MissionDef } = {}
	pickFrom(work, MissionConfig.WORK_PER_DAY, day, result)
	pickFrom(visit, MissionConfig.VISIT_PER_DAY, day, result)
	return result
end

function MissionConfig.isActive(id: string, day: number): boolean
	for _, def in MissionConfig.forDay(day) do
		if def.id == id then
			return true
		end
	end
	return false
end

function MissionConfig.placePosition(key: string): Vector3?
	local place = JobConfig.PLACES[key]
	return if place then place.position else nil
end

function MissionConfig.placeName(key: string): string
	local place = JobConfig.PLACES[key]
	return if place then place.name else key
end

return table.freeze(MissionConfig)
