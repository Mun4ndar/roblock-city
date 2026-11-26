--!strict
-- StoreConfig: isi TOKO (minimarket). Barang dibeli dengan uang dalam game, masuk ke hotbar (Backpack)
-- sebagai Tool. Makanan/minuman habis setelah dipakai (ada jumlahnya); mainan dan payung dibeli sekali
-- dan dipakai berulang kali. Semua harga dan efek diatur di sini.
--
-- MODEL 3D: letakkan hasil FBX (lihat assets/meshy/Toko) di ServerStorage.StoreTemplates dengan nama
-- sama dengan id barang (Model dengan PrimaryPart, atau satu MeshPart bernama Handle). Selama modelnya
-- belum ada, StoreService membuat bentuk sementara dari part sederhana.

export type Kind = "drink" | "eat" | "toy" | "umbrella"

export type Item = {
	id: string,
	name: string,
	icon: string,
	price: number,
	kind: Kind,
	desc: string,
	maxStack: number, -- jumlah maksimal yang boleh dibawa (barang habis pakai)
	buffSeconds: number?, -- "kenyang semangat" (lari lebih cepat) setelah dipakai
	reusable: boolean, -- true = tidak habis, hanya boleh dimiliki satu
}

local StoreConfig = {}

StoreConfig.ATTR_COUNTER = "StoreCounter" -- tag CollectionService pada meja kasir / penjaga toko
StoreConfig.TAG_COUNTER = "StoreCounter"
StoreConfig.BUY_DISTANCE = 22
StoreConfig.OPEN_EVENT = "StoreOpen" -- RemoteEvent server -> client
StoreConfig.BUY_FUNC = "StoreBuy" -- RemoteFunction client -> server (itemId) -> { ok, message }
StoreConfig.USE_SECONDS = 2.6 -- lama animasi makan/minum

StoreConfig.ITEMS = {
	{
		id = "air_mineral",
		name = "Air Mineral",
		icon = "💧",
		price = 4,
		kind = "drink",
		maxStack = 10,
		reusable = false,
		buffSeconds = 30,
		desc = "Segar dan menyehatkan.",
	},
	{
		id = "es_teh",
		name = "Teh Botol",
		icon = "🥤",
		price = 6,
		kind = "drink",
		maxStack = 10,
		reusable = false,
		buffSeconds = 45,
		desc = "Dingin, manis, bikin semangat.",
	},
	{
		id = "kopi_susu",
		name = "Kopi Susu",
		icon = "☕",
		price = 12,
		kind = "drink",
		maxStack = 10,
		reusable = false,
		buffSeconds = 60,
		desc = "Kopi susu dingin kekinian.",
	},
	{
		id = "susu_kotak",
		name = "Susu Kotak",
		icon = "🥛",
		price = 7,
		kind = "drink",
		maxStack = 10,
		reusable = false,
		buffSeconds = 45,
		desc = "Susu kotak dengan sedotan.",
	},
	{
		id = "roti",
		name = "Roti Manis",
		icon = "🍞",
		price = 8,
		kind = "eat",
		maxStack = 10,
		reusable = false,
		buffSeconds = 45,
		desc = "Roti empuk bertabur wijen.",
	},
	{
		id = "onigiri",
		name = "Nasi Kepal",
		icon = "🍙",
		price = 10,
		kind = "eat",
		maxStack = 10,
		reusable = false,
		buffSeconds = 60,
		desc = "Nasi kepal segitiga dibalut nori.",
	},
	{
		id = "keripik",
		name = "Keripik Renyah",
		icon = "🥔",
		price = 6,
		kind = "eat",
		maxStack = 10,
		reusable = false,
		buffSeconds = 30,
		desc = "Kriuk-kriuk gurih.",
	},
	{
		id = "es_krim",
		name = "Es Krim",
		icon = "🍦",
		price = 9,
		kind = "eat",
		maxStack = 10,
		reusable = false,
		buffSeconds = 45,
		desc = "Dua scoop, dingin dan manis.",
	},
	{
		id = "cilok",
		name = "Cilok",
		icon = "🍡",
		price = 8,
		kind = "eat",
		maxStack = 10,
		reusable = false,
		buffSeconds = 45,
		desc = "Bola-bola kenyal dengan saus.",
	},
	{
		id = "permen",
		name = "Permen Lolipop",
		icon = "🍭",
		price = 3,
		kind = "eat",
		maxStack = 20,
		reusable = false,
		buffSeconds = 20,
		desc = "Manis berwarna-warni.",
	},
	{
		id = "payung",
		name = "Payung",
		icon = "☂️",
		price = 40,
		kind = "umbrella",
		maxStack = 1,
		reusable = true,
		desc = "Klik untuk membuka dan menutup payung.",
	},
	{
		id = "bola_mainan",
		name = "Bola Karet",
		icon = "⚽",
		price = 25,
		kind = "toy",
		maxStack = 1,
		reusable = true,
		desc = "Klik untuk memantulkan bola.",
	},
	{
		id = "mobil_mainan",
		name = "Mobil Mainan",
		icon = "🚗",
		price = 35,
		kind = "toy",
		maxStack = 1,
		reusable = true,
		desc = "Klik untuk membunyikan klakson mainan.",
	},
	{
		id = "boneka_beruang",
		name = "Boneka Beruang",
		icon = "🧸",
		price = 50,
		kind = "toy",
		maxStack = 1,
		reusable = true,
		desc = "Klik untuk memeluk dan menebar hati.",
	},
} :: { Item }

function StoreConfig.get(id: any): Item?
	for _, item in StoreConfig.ITEMS do
		if item.id == id then
			return item
		end
	end
	return nil
end

return table.freeze(StoreConfig)
