--!strict
-- Toko Costume: skin baju/costume yang dipakai saat TIDAK sedang bekerja. Saat bekerja,
-- seragam pekerjaan yang tampil. Costume dirakit UniformService dari part (topi, jaket,
-- aksesoris dada/lengan/punggung) supaya tidak bergantung asset luar.
-- Menambah costume = menambah entri di OUTFITS.

local JobConfig = require(script.Parent:WaitForChild("JobConfig"))

local FashionConfig = {}

export type Outfit = {
	id: string,
	name: string,
	icon: string,
	price: number, -- harga uang game; 0 jika Robux
	robux: number?, -- harga saran Robux untuk Developer Product
	productKey: string?, -- key produk Robux di ShopConfig
	look: JobConfig.Uniform,
}

-- Keadaan yang dikirim ke client (atribut Player "Fashion", JSON).
export type FashionView = { owned: { [string]: boolean }, active: string }

-- Toko Costume kaca di downtown/perkotaan.
FashionConfig.SHOP_POSITION = Vector3.new(492, 1.1, -432)
FashionConfig.SHOP_RANGE = 42
FashionConfig.ATTR_PLAYER = "Fashion"
FashionConfig.ATTR_PROMPT = "FashionShop"

local rgb = Color3.fromRGB
local function look(
	hat: JobConfig.HatKind,
	hatColor: Color3,
	vest: Color3,
	trim: Color3,
	badge: Color3
): JobConfig.Uniform
	return { hat = hat, hatColor = hatColor, vest = vest, trim = trim, badge = badge }
end

FashionConfig.OUTFITS = {
	{
		id = "sayap_malaikat",
		name = "Sayap Malaikat",
		icon = "🪽",
		price = 0,
		robux = 99,
		productKey = "costume_sayap_malaikat",
		look = look(
			"peaked",
			rgb(245, 248, 255),
			rgb(245, 248, 255),
			rgb(255, 224, 110),
			rgb(120, 235, 255)
		),
	},
	{
		id = "naga_api",
		name = "Naga Api",
		icon = "🐉",
		price = 0,
		robux = 129,
		productKey = "costume_naga_api",
		look = look(
			"helmet",
			rgb(225, 55, 55),
			rgb(55, 22, 18),
			rgb(255, 90, 40),
			rgb(255, 184, 0)
		),
	},
	{
		id = "mecha_wing",
		name = "Mecha Wing",
		icon = "🤖",
		price = 0,
		robux = 149,
		productKey = "costume_mecha_wing",
		look = look(
			"helmet",
			rgb(160, 180, 205),
			rgb(45, 55, 70),
			rgb(80, 240, 255),
			rgb(255, 184, 0)
		),
	},
	{
		id = "penyihir_galaksi",
		name = "Penyihir Galaksi",
		icon = "🧙",
		price = 0,
		robux = 119,
		productKey = "costume_penyihir_galaksi",
		look = look(
			"peaked",
			rgb(90, 45, 150),
			rgb(45, 25, 80),
			rgb(170, 100, 255),
			rgb(255, 255, 255)
		),
	},
	{
		id = "raja_petir",
		name = "Raja Petir",
		icon = "⚡",
		price = 0,
		robux = 159,
		productKey = "costume_raja_petir",
		look = look(
			"peaked",
			rgb(240, 196, 80),
			rgb(38, 40, 55),
			rgb(255, 224, 80),
			rgb(120, 235, 255)
		),
	},
} :: { Outfit }

local byId: { [string]: Outfit } = {}
for _, outfit in FashionConfig.OUTFITS do
	byId[outfit.id] = outfit
end

function FashionConfig.get(id: any): Outfit?
	return if type(id) == "string" then byId[id] else nil
end

return table.freeze(FashionConfig)
