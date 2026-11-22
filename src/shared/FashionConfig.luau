--!strict
-- Toko Baju: setelan (topi + jaket) yang dipakai saat TIDAK sedang bekerja. Saat bekerja,
-- seragam pekerjaan yang tampil. Setelan dirakit UniformService dari part, sama seperti seragam,
-- jadi bentuknya memakai jenis topi yang sama (cap/helmet/peaked).
-- Menambah setelan = menambah entri di OUTFITS.

local JobConfig = require(script.Parent:WaitForChild("JobConfig"))

local FashionConfig = {}

export type Outfit = {
	id: string,
	name: string,
	icon: string,
	price: number,
	look: JobConfig.Uniform,
}

-- Keadaan yang dikirim ke client (atribut Player "Fashion", JSON).
export type FashionView = { owned: { [string]: boolean }, active: string }

FashionConfig.SHOP_POSITION = Vector3.new(540, 1.1, -536) -- depan ROBLOCK Mall, sebelah Toko Hewan
FashionConfig.SHOP_RANGE = 40
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
		id = "santai",
		name = "Santai Biru",
		icon = "🧢",
		price = 200,
		look = look(
			"cap",
			rgb(60, 120, 220),
			rgb(90, 160, 240),
			rgb(250, 250, 250),
			rgb(255, 210, 70)
		),
	},
	{
		id = "ceria",
		name = "Ceria Kuning",
		icon = "🌞",
		price = 250,
		look = look(
			"cap",
			rgb(250, 200, 60),
			rgb(255, 224, 110),
			rgb(240, 130, 50),
			rgb(230, 70, 70)
		),
	},
	{
		id = "pink",
		name = "Manis Pink",
		icon = "🌸",
		price = 300,
		look = look(
			"cap",
			rgb(240, 130, 180),
			rgb(255, 180, 210),
			rgb(250, 250, 250),
			rgb(150, 100, 210)
		),
	},
	{
		id = "hijau",
		name = "Petualang Hijau",
		icon = "🌿",
		price = 350,
		look = look(
			"cap",
			rgb(60, 130, 80),
			rgb(110, 170, 110),
			rgb(230, 210, 150),
			rgb(120, 80, 50)
		),
	},
	{
		id = "sport",
		name = "Sporty Merah",
		icon = "🏃",
		price = 500,
		look = look("cap", rgb(220, 50, 50), rgb(235, 80, 70), rgb(40, 40, 46), rgb(250, 250, 250)),
	},
	{
		id = "keren",
		name = "Keren Hitam",
		icon = "🕶️",
		price = 800,
		look = look(
			"peaked",
			rgb(40, 42, 50),
			rgb(60, 62, 72),
			rgb(200, 204, 212),
			rgb(240, 196, 80)
		),
	},
	{
		id = "kapten",
		name = "Kapten Laut",
		icon = "⚓",
		price = 1200,
		look = look(
			"peaked",
			rgb(250, 250, 250),
			rgb(40, 70, 130),
			rgb(240, 196, 80),
			rgb(240, 196, 80)
		),
	},
	{
		id = "emas",
		name = "Bintang Emas",
		icon = "⭐",
		price = 2500,
		look = look(
			"peaked",
			rgb(240, 196, 80),
			rgb(250, 220, 120),
			rgb(150, 100, 210),
			rgb(250, 250, 250)
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
