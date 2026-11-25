--!strict
-- RetentionConfig: data untuk hadiah login beruntun, misi harian/mingguan, dan event musiman.
-- Semuanya berbasis data: menambah misi = satu baris di DAILY/WEEKLY, menambah event = satu
-- entri di EVENTS (lihat map/BuildEventDecor.luau untuk dekorasinya).
-- Modul ikut ter-replikasi; server yang menghitung kemajuan, hadiah, dan tanggal.

local RetentionConfig = {}

-- Penghitung kemajuan yang dikenal server:
--   "tasks"        tugas pekerjaan apa pun       "task:<idPekerjaan>" tugas satu pekerjaan
--   "earn"         total gaji dari pekerjaan     "refuel" isi bensin    "harvest" panen tanaman
export type MissionDef = {
	id: string,
	icon: string,
	title: string,
	counter: string,
	target: number,
	reward: number,
}

export type EventItem = {
	id: string, -- id setelan di FashionConfig.OUTFITS (bertanda event)
	price: number,
}

export type EventDef = {
	id: string,
	name: string,
	icon: string,
	-- Jendela tanggal (WIB, inklusif). Boleh lintas tahun (start > stop). `years` menimpa
	-- jendela di tahun tertentu (untuk hari raya yang tanggalnya berpindah).
	startMonth: number,
	startDay: number,
	stopMonth: number,
	stopDay: number,
	years: { [number]: { number } }?, -- [tahun] = { bulanMulai, hariMulai, bulanSelesai, hariSelesai }
	missions: { MissionDef },
	items: { EventItem },
}

RetentionConfig.UTC_OFFSET_HOURS = 7 -- hari berganti pukul 00.00 WIB
RetentionConfig.ATTR = "Retention" -- atribut Player (JSON RetentionView)
RetentionConfig.EVENT_ATTR = "ActiveEvent" -- atribut Workspace: id event yang berlaku ("" = tidak ada)
RetentionConfig.DECOR_SOURCE = "EventDecor" -- ServerStorage.EventDecor.<idEvent> (disimpan saat tak aktif)
RetentionConfig.DECOR_FOLDER = "EventDecor" -- Workspace.Map.EventDecor (terpasang saat aktif)
RetentionConfig.VIP_MULTIPLIER = 2 -- pemilik pass VIP: hadiah login dan misi dua kali lipat

-- Hadiah login hari ke-1..7 (uang). Hari ke-7 besar. Lewat satu hari = mulai dari hari ke-1.
RetentionConfig.STREAK = { 120, 160, 200, 250, 300, 400, 1500 }

RetentionConfig.DAILY_COUNT = 3
RetentionConfig.WEEKLY_COUNT = 3

RetentionConfig.DAILY = {
	{
		id = "d_kurir",
		icon = "📦",
		title = "Antar 5 paket sebagai Kurir",
		counter = "task:kurir",
		target = 5,
		reward = 220,
	},
	{
		id = "d_bensin",
		icon = "⛽",
		title = "Isi bensin 3 kali",
		counter = "refuel",
		target = 3,
		reward = 150,
	},
	{
		id = "d_pasien",
		icon = "🩺",
		title = "Rawat 3 pasien sebagai Dokter",
		counter = "task:dokter",
		target = 3,
		reward = 240,
	},
	{
		id = "d_mekanik",
		icon = "🔧",
		title = "Servis 3 mobil sebagai Mekanik",
		counter = "task:mekanik",
		target = 3,
		reward = 220,
	},
	{
		id = "d_api",
		icon = "🚒",
		title = "Selesaikan 2 tugas Pemadam",
		counter = "task:pemadam",
		target = 2,
		reward = 240,
	},
	{
		id = "d_patroli",
		icon = "🚓",
		title = "Selesaikan 3 tugas Polisi",
		counter = "task:polisi",
		target = 3,
		reward = 220,
	},
	{
		id = "d_bus",
		icon = "🚌",
		title = "Selesaikan 3 rute Sopir Bus",
		counter = "task:sopir",
		target = 3,
		reward = 220,
	},
	{
		id = "d_panen",
		icon = "🌾",
		title = "Panen 8 tanaman",
		counter = "harvest",
		target = 8,
		reward = 180,
	},
	{
		id = "d_kerja",
		icon = "💼",
		title = "Selesaikan 4 tugas pekerjaan apa saja",
		counter = "tasks",
		target = 4,
		reward = 170,
	},
} :: { MissionDef }

RetentionConfig.WEEKLY = {
	{
		id = "w_kurir",
		icon = "📦",
		title = "Antar 25 paket sebagai Kurir",
		counter = "task:kurir",
		target = 25,
		reward = 1200,
	},
	{
		id = "w_bensin",
		icon = "⛽",
		title = "Isi bensin 15 kali",
		counter = "refuel",
		target = 15,
		reward = 800,
	},
	{
		id = "w_pasien",
		icon = "🩺",
		title = "Rawat 15 pasien sebagai Dokter",
		counter = "task:dokter",
		target = 15,
		reward = 1200,
	},
	{
		id = "w_panen",
		icon = "🌾",
		title = "Panen 40 tanaman",
		counter = "harvest",
		target = 40,
		reward = 900,
	},
	{
		id = "w_kerja",
		icon = "💪",
		title = "Selesaikan 40 tugas pekerjaan",
		counter = "tasks",
		target = 40,
		reward = 1500,
	},
	{
		id = "w_gaji",
		icon = "💰",
		title = "Kumpulkan gaji $5000",
		counter = "earn",
		target = 5000,
		reward = 1500,
	},
} :: { MissionDef }

local function eventMissions(prefix: string, icon: string, theme: string): { MissionDef }
	return {
		{
			id = prefix .. "_kerja",
			icon = icon,
			title = `{theme}: selesaikan 8 tugas pekerjaan`,
			counter = "tasks",
			target = 8,
			reward = 700,
		},
		{
			id = prefix .. "_bensin",
			icon = icon,
			title = `{theme}: isi bensin 4 kali`,
			counter = "refuel",
			target = 4,
			reward = 400,
		},
		{
			id = prefix .. "_gaji",
			icon = icon,
			title = `{theme}: kumpulkan gaji $1500`,
			counter = "earn",
			target = 1500,
			reward = 900,
		},
	}
end

-- Tanggal hari raya bergerak (Lebaran) adalah perkiraan; periksa kalender tiap tahun.
RetentionConfig.EVENTS = {
	{
		id = "agustus",
		name = "HUT Kemerdekaan RI",
		icon = "🇮🇩",
		startMonth = 8,
		startDay = 10,
		stopMonth = 8,
		stopDay = 24,
		missions = eventMissions("e_agt", "🇮🇩", "Merdeka"),
		items = { { id = "baju_merdeka", price = 900 } },
	},
	{
		id = "lebaran",
		name = "Hari Raya Lebaran",
		icon = "🌙",
		startMonth = 3,
		startDay = 6,
		stopMonth = 3,
		stopDay = 16,
		years = { [2027] = { 3, 6, 3, 16 }, [2028] = { 2, 22, 3, 3 }, [2029] = { 2, 10, 2, 21 } },
		missions = eventMissions("e_leb", "🌙", "Lebaran"),
		items = { { id = "baju_lebaran", price = 900 } },
	},
	{
		id = "natal",
		name = "Natal",
		icon = "🎄",
		startMonth = 12,
		startDay = 15,
		stopMonth = 12,
		stopDay = 27,
		missions = eventMissions("e_ntl", "🎄", "Natal"),
		items = { { id = "baju_natal", price = 900 } },
	},
	{
		id = "tahunbaru",
		name = "Tahun Baru",
		icon = "🎆",
		startMonth = 12,
		startDay = 28,
		stopMonth = 1,
		stopDay = 3,
		missions = eventMissions("e_thb", "🎆", "Tahun Baru"),
		items = { { id = "baju_pesta", price = 900 } },
	},
} :: { EventDef }

-- ---------------------------------------------------------------- util

local byId: { [string]: MissionDef } = {}
for _, list in { RetentionConfig.DAILY, RetentionConfig.WEEKLY } do
	for _, def in list do
		byId[def.id] = def
	end
end
for _, event in RetentionConfig.EVENTS do
	for _, def in event.missions do
		byId[def.id] = def
	end
end

function RetentionConfig.mission(id: string): MissionDef?
	return byId[id]
end

function RetentionConfig.event(id: string): EventDef?
	for _, event in RetentionConfig.EVENTS do
		if event.id == id then
			return event
		end
	end
	return nil
end

-- Nomor hari (berganti tengah malam WIB).
function RetentionConfig.dayNumber(unixTime: number): number
	return math.floor((unixTime + RetentionConfig.UTC_OFFSET_HOURS * 3600) / 86400)
end

-- Nomor pekan (berganti Senin 00.00 WIB; hari 0 = Kamis 1 Jan 1970).
function RetentionConfig.weekNumber(day: number): number
	return math.floor((day + 3) / 7)
end

local function pick(list: { MissionDef }, count: number, seed: number): { MissionDef }
	local result = {}
	for i = 0, math.min(count, #list) - 1 do
		table.insert(result, list[(seed * count + i) % #list + 1])
	end
	return result
end

function RetentionConfig.dailyFor(day: number): { MissionDef }
	return pick(RetentionConfig.DAILY, RetentionConfig.DAILY_COUNT, day)
end

function RetentionConfig.weeklyFor(week: number): { MissionDef }
	return pick(RetentionConfig.WEEKLY, RetentionConfig.WEEKLY_COUNT, week)
end

-- Event yang berlaku pada waktu tertentu, atau nil. Jendela = bulan*100+hari (WIB).
function RetentionConfig.activeEvent(unixTime: number): EventDef?
	local t = os.date("!*t", unixTime + RetentionConfig.UTC_OFFSET_HOURS * 3600)
	local today = t.month * 100 + t.day
	for _, event in RetentionConfig.EVENTS do
		local w = if event.years then event.years[t.year] else nil
		local a = if w then w[1] * 100 + w[2] else event.startMonth * 100 + event.startDay
		local b = if w then w[3] * 100 + w[4] else event.stopMonth * 100 + event.stopDay
		local inside = if a <= b then (today >= a and today <= b) else (today >= a or today <= b)
		-- Event tanpa tabel `years` hanya dipakai bila tahunnya tidak tercantum untuk event ber-years.
		if inside and (event.years == nil or w ~= nil) then
			return event
		end
	end
	return nil
end

-- Keadaan yang dikirim ke client.
export type RetentionView = {
	day: number,
	streak: number, -- hari beruntun sampai klaim terakhir
	claimedToday: boolean,
	nextDay: number, -- hari ke-berapa (1..7) yang akan diambil berikutnya
	daily: { [string]: number },
	dailyClaimed: { [string]: boolean },
	week: number,
	weekly: { [string]: number },
	weeklyClaimed: { [string]: boolean },
	event: string, -- id event aktif, "" = tidak ada
	eventProgress: { [string]: number },
	eventClaimed: { [string]: boolean },
}

return RetentionConfig
