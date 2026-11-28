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
	event: string?, -- id event (RetentionConfig): hanya dijual saat event, lewat panel Hadiah
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
		robux = 149,
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
		robux = 199,
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
		robux = 249,
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
		robux = 299,
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
		robux = 399,
		productKey = "costume_raja_petir",
		look = look(
			"peaked",
			rgb(240, 196, 80),
			rgb(38, 40, 55),
			rgb(255, 224, 80),
			rgb(120, 235, 255)
		),
	},
	-- Hadiah gratis Misi Pemula (OnboardingConfig.FINAL_OUTFIT). Bertanda event supaya tidak dijual di toko.
	{
		id = "jaket_warga_baru",
		name = "Jaket Warga Baru",
		icon = "🧥",
		price = 0,
		event = "pemula",
		look = look("cap", rgb(40, 170, 160), rgb(40, 170, 160), rgb(255, 255, 255), rgb(255, 184, 0)),
	},
	-- Setelan terbatas event (dibeli di panel Hadiah HP saat event berlangsung; lihat RetentionConfig).
	{
		id = "baju_merdeka",
		name = "Seragam Merdeka",
		icon = "🇮🇩",
		price = 0,
		event = "agustus",
		look = look(
			"cap",
			rgb(220, 40, 45),
			rgb(245, 245, 245),
			rgb(220, 40, 45),
			rgb(255, 255, 255)
		),
	},
	{
		id = "baju_lebaran",
		name = "Baju Lebaran",
		icon = "🌙",
		price = 0,
		event = "lebaran",
		look = look(
			"cap",
			rgb(30, 30, 35),
			rgb(60, 150, 120),
			rgb(255, 215, 110),
			rgb(255, 215, 110)
		),
	},
	{
		id = "baju_natal",
		name = "Kostum Natal",
		icon = "🎄",
		price = 0,
		event = "natal",
		look = look(
			"peaked",
			rgb(215, 40, 45),
			rgb(215, 40, 45),
			rgb(250, 250, 250),
			rgb(60, 170, 90)
		),
	},
	{
		id = "baju_pesta",
		name = "Kostum Pesta Tahun Baru",
		icon = "🎆",
		price = 0,
		event = "tahunbaru",
		look = look(
			"peaked",
			rgb(255, 205, 60),
			rgb(40, 40, 70),
			rgb(255, 205, 60),
			rgb(120, 220, 255)
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
