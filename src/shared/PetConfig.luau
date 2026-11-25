--!strict
-- Hewan peliharaan. Beli di Toko Hewan (di dalam ROBLOCK Mega Mall), pilih satu untuk diajak jalan,
-- beri makan supaya senang. Menambah hewan = menambah entri di PETS (dirakit dari part).
-- Modul ini ikut ter-replikasi; harga, kepemilikan, dan jarak ke toko dicek server.

local PetConfig = {}

export type PetDef = {
	id: string,
	name: string,
	icon: string,
	price: number,
	body: Color3,
	accent: Color3, -- telinga, ekor, belang
	ears: "runcing" | "panjang" | "bulat",
	size: number, -- skala (1 = seukuran kucing)
}

-- Keadaan yang dikirim ke client (atribut Player "Pets", JSON).
export type PetView = {
	owned: { [string]: boolean },
	active: string, -- "" = tidak ada yang diajak
	fedAt: number, -- waktu server terakhir diberi makan
}

-- Kasir Toko Hewan di dalam ROBLOCK Mega Mall (ruang dalam di y = 2000, lihat map/BuildInteriors.luau)
PetConfig.SHOP_POSITION = Vector3.new(486, 2000, -623)
PetConfig.SHOP_RANGE = 34
PetConfig.FEED_PRICE = 15
PetConfig.HAPPY_SECONDS = 600 -- lama hewan "senang" setelah diberi makan
PetConfig.ATTR_PLAYER = "Pets"
PetConfig.ATTR_PROMPT = "PetShop"

local rgb = Color3.fromRGB

PetConfig.PETS = {
	{
		id = "kucing",
		name = "Kucing Oren",
		icon = "🐱",
		price = 400,
		body = rgb(240, 160, 70),
		accent = rgb(250, 240, 225),
		ears = "runcing",
		size = 1,
	},
	{
		id = "anjing",
		name = "Anjing Cokelat",
		icon = "🐶",
		price = 600,
		body = rgb(160, 110, 70),
		accent = rgb(90, 60, 40),
		ears = "bulat",
		size = 1.2,
	},
	{
		id = "kelinci",
		name = "Kelinci Putih",
		icon = "🐰",
		price = 800,
		body = rgb(248, 246, 240),
		accent = rgb(255, 170, 190),
		ears = "panjang",
		size = 0.9,
	},
	{
		id = "rubah",
		name = "Rubah Merah",
		icon = "🦊",
		price = 1500,
		body = rgb(226, 100, 50),
		accent = rgb(250, 245, 235),
		ears = "runcing",
		size = 1.15,
	},
	{
		id = "panda",
		name = "Panda Kecil",
		icon = "🐼",
		price = 3000,
		body = rgb(248, 248, 246),
		accent = rgb(40, 40, 46),
		ears = "bulat",
		size = 1.35,
	},
} :: { PetDef }

local byId: { [string]: PetDef } = {}
for _, pet in PetConfig.PETS do
	byId[pet.id] = pet
end

function PetConfig.get(id: any): PetDef?
	return if type(id) == "string" then byId[id] else nil
end

-- ---------------------------------------------------------------- kepribadian
-- Tiap hewan punya sifat sendiri. Server (PetService) memilih suasana hati (mood) dan tempat berdiri
-- hewan; client (PetAnimController) memainkan gerakan sendi sesuai mood. Mood = nama pose.

export type MoodDef = {
	place: "follow" | "near" | "orbit8" | "circle", -- di mana hewan berdiri terhadap pemilik
	emote: string, -- teks melayang ("" = tidak ada)
	seconds: number, -- lama mood sebelum ganti
}

export type Personality = {
	gait: "trot" | "hop" | "waddle" | "sneak", -- cara jalan
	follow: Vector3, -- x = samping kanan pemilik, z = di belakang pemilik (stud)
	idle: { string }, -- mood bermanja saat pemilik diam
	petMood: string, -- reaksi saat dielus
}

PetConfig.MOODS = {
	walk = { place = "follow", emote = "", seconds = 0 },
	idle = { place = "follow", emote = "", seconds = 0 },
	sit = { place = "near", emote = "", seconds = 7 },
	rub = { place = "orbit8", emote = "Purrr~ ♥", seconds = 9 },
	beg = { place = "near", emote = "Guk guk! ♥", seconds = 7 },
	nuzzle = { place = "near", emote = "♥", seconds = 7 },
	binky = { place = "circle", emote = "Yeay!", seconds = 6 },
	pounce = { place = "near", emote = "Yip!", seconds = 7 },
	curl = { place = "near", emote = "Zzz ♥", seconds = 9 },
	hug = { place = "near", emote = "Peluk aku! ♥", seconds = 7 },
	roll = { place = "circle", emote = "Hehe!", seconds = 6 },
	-- reaksi dielus
	purr = { place = "near", emote = "Purrr~ ♥", seconds = 4 },
	wag = { place = "near", emote = "Guk guk! ♥", seconds = 4 },
	melt = { place = "near", emote = "♥ ♥", seconds = 4 },
	wiggle = { place = "near", emote = "Yip yip! ♥", seconds = 4 },
	sway = { place = "near", emote = "Hehe ♥", seconds = 4 },
} :: { [string]: MoodDef }

PetConfig.PERSONALITY = {
	kucing = {
		gait = "trot",
		follow = Vector3.new(1.7, 0, 1.6),
		idle = { "rub", "sit", "rub" },
		petMood = "purr",
	},
	anjing = {
		gait = "trot",
		follow = Vector3.new(1.5, 0, 1.2),
		idle = { "sit", "beg", "beg" },
		petMood = "wag",
	},
	kelinci = {
		gait = "hop",
		follow = Vector3.new(1.4, 0, 1.4),
		idle = { "nuzzle", "binky", "sit" },
		petMood = "melt",
	},
	rubah = {
		gait = "sneak",
		follow = Vector3.new(1.3, 0, 1.0),
		idle = { "pounce", "curl", "sit" },
		petMood = "wiggle",
	},
	panda = {
		gait = "waddle",
		follow = Vector3.new(1.8, 0, 1.5),
		idle = { "hug", "roll", "sit" },
		petMood = "sway",
	},
} :: { [string]: Personality }

PetConfig.PET_RANGE = 12 -- jarak maksimal untuk mengelus hewan
PetConfig.PET_COOLDOWN = 1.2

function PetConfig.personality(id: string): Personality
	return PetConfig.PERSONALITY[id] or PetConfig.PERSONALITY.kucing
end

return table.freeze(PetConfig)
