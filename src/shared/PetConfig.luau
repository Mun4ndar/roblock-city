--!strict
-- Hewan peliharaan. Beli di Toko Hewan (depan ROBLOCK Mall), pilih satu untuk diajak jalan,
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

PetConfig.SHOP_POSITION = Vector3.new(590, 1.1, -536) -- depan ROBLOCK Mall
PetConfig.SHOP_RANGE = 40
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

return table.freeze(PetConfig)
