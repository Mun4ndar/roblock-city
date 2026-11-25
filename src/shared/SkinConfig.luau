--!strict
-- Toko Skin: tema warna + bahan untuk penampilan karakter. Ada yang gratis (diambil
-- langsung di konter Toko Skin dalam ROBLOCK STORE) dan ada yang dibeli dengan Robux
-- (produknya terdaftar di ShopConfig.PRODUCTS dengan field `skin`; ID-nya diisi setelah
-- produk dibuat di Creator Dashboard). Skin dipasang SkinService ke bagian tubuh avatar;
-- avatar asli pemain tidak diubah permanen dan bisa kembali kapan saja.

local SkinConfig = {}

export type SkinLook = {
	material: Enum.Material,
	head: Color3,
	torso: Color3,
	arms: Color3,
	legs: Color3,
}

export type Skin = {
	id: string,
	name: string,
	icon: string,
	desc: string,
	free: boolean, -- true = gratis, diambil di Toko Skin
	robux: number, -- saran harga Robux untuk skin berbayar (tidak dipakai kode)
	look: SkinLook,
}

-- Keadaan yang dikirim ke client (atribut Player "Skin", JSON).
export type SkinView = { owned: { [string]: boolean }, active: string }

SkinConfig.ATTR_PLAYER = "Skin"
SkinConfig.ATTR_PROMPT = "SkinShop"
-- Konter Toko Skin di dalam ROBLOCK STORE (bangunannya dari MapBuilders/BuildShops.luau).
SkinConfig.SHOP_POSITION = Vector3.new(150.5, 0.4, -25)
SkinConfig.SHOP_RANGE = 36

local rgb = Color3.fromRGB
local function look(
	material: Enum.Material,
	head: Color3,
	torso: Color3,
	arms: Color3,
	legs: Color3
): SkinLook
	return { material = material, head = head, torso = torso, arms = arms, legs = legs }
end

SkinConfig.SKINS = {
	-- gratis
	{
		id = "hijau_lumut",
		name = "Hijau Lumut",
		icon = "🌿",
		desc = "Segar seperti taman kota.",
		free = true,
		robux = 0,
		look = look(
			Enum.Material.SmoothPlastic,
			rgb(150, 200, 120),
			rgb(90, 160, 70),
			rgb(120, 180, 90),
			rgb(70, 130, 60)
		),
	},
	{
		id = "biru_langit",
		name = "Biru Langit",
		icon = "☁️",
		desc = "Tenang seperti langit sore.",
		free = true,
		robux = 0,
		look = look(
			Enum.Material.SmoothPlastic,
			rgb(150, 205, 255),
			rgb(80, 160, 240),
			rgb(120, 190, 250),
			rgb(60, 120, 200)
		),
	},
	{
		id = "merah_ceri",
		name = "Merah Ceri",
		icon = "🍒",
		desc = "Berani dan ceria.",
		free = true,
		robux = 0,
		look = look(
			Enum.Material.SmoothPlastic,
			rgb(255, 150, 140),
			rgb(230, 60, 60),
			rgb(250, 110, 100),
			rgb(180, 40, 50)
		),
	},
	-- Robux (produk di ShopConfig.PRODUCTS, field skin = true)
	{
		id = "perak",
		name = "Perak Chrome",
		icon = "🥈",
		desc = "Kilau logam chrome.",
		free = false,
		robux = 75,
		look = look(
			Enum.Material.Metal,
			rgb(225, 232, 240),
			rgb(190, 200, 212),
			rgb(205, 215, 226),
			rgb(172, 182, 194)
		),
	},
	{
		id = "emas",
		name = "Bintang Emas",
		icon = "⭐",
		desc = "Bermandi cahaya emas.",
		free = false,
		robux = 99,
		look = look(
			Enum.Material.Metal,
			rgb(255, 216, 90),
			rgb(240, 196, 60),
			rgb(250, 222, 115),
			rgb(222, 170, 52)
		),
	},
	{
		id = "robot",
		name = "Robot Kota",
		icon = "🤖",
		desc = "Baja kota masa depan.",
		free = false,
		robux = 129,
		look = look(
			Enum.Material.Metal,
			rgb(152, 162, 175),
			rgb(64, 74, 90),
			rgb(118, 128, 143),
			rgb(52, 60, 72)
		),
	},
	{
		id = "neon_biru",
		name = "Neon Biru",
		icon = "💠",
		desc = "Menyala di kegelapan.",
		free = false,
		robux = 149,
		look = look(
			Enum.Material.Neon,
			rgb(85, 238, 255),
			rgb(60, 220, 255),
			rgb(105, 242, 255),
			rgb(50, 200, 240)
		),
	},
	{
		id = "kristal_es",
		name = "Kristal Es",
		icon = "❄️",
		desc = "Dingin dan berkilau.",
		free = false,
		robux = 149,
		look = look(
			Enum.Material.Ice,
			rgb(195, 236, 255),
			rgb(150, 220, 250),
			rgb(172, 230, 255),
			rgb(130, 205, 245)
		),
	},
	{
		id = "lava",
		name = "Kulit Lava",
		icon = "🌋",
		desc = "Panas membara!",
		free = false,
		robux = 199,
		look = look(
			Enum.Material.Neon,
			rgb(255, 125, 45),
			rgb(255, 82, 30),
			rgb(255, 152, 62),
			rgb(232, 62, 22)
		),
	},
} :: { Skin }

local byId: { [string]: Skin } = {}
for _, skin in SkinConfig.SKINS do
	byId[skin.id] = skin
end

function SkinConfig.get(id: any): Skin?
	return if type(id) == "string" then byId[id] else nil
end

return table.freeze(SkinConfig)
