--!strict
-- Toko Robux (opsional). Semua isi game tetap bisa didapat dengan bermain; toko ini hanya
-- jalan pintas dan kosmetik. TIDAK ada kotak acak / undian.
--
-- CARA MENGAKTIFKAN (dilakukan pemilik game di Creator Dashboard, create.roblox.com):
--   1. Buka experience Kota ROBLOCK > Monetization > Developer Products, buat produk untuk
--      tiap entri PRODUCTS (nama dan harga Robux bebas; angka `robux` di sini hanya saran).
--   2. Salin Product ID tiap produk ke `productId` di bawah.
--   3. Monetization > Passes, buat Game Pass VIP, salin ID-nya ke PASSES.vip.passId.
--   4. Selama ID masih 0, tombol belinya tidak aktif dan tidak ada yang bisa dibeli.
-- Harga Robux yang sebenarnya selalu yang tertulis di Roblox, dan Roblox sendiri yang
-- menampilkan jendela konfirmasi pembelian.

local ShopConfig = {}

export type Product = {
	key: string,
	name: string,
	coins: number?, -- uang dalam game yang diberikan (produk koin)
	costume: string?, -- id costume (lihat FashionConfig) yang diberikan
	robux: number, -- saran harga (tidak dipakai kode)
	productId: number, -- 0 = belum dibuat
}

-- Produk gadget ROBLOCK STORE: tidak punya `coins`, jadi pembelian dicatat di
-- PlayerData.gadgets.owned (key produk) bukan menambah uang.

export type Pass = {
	key: string,
	name: string,
	description: string,
	robux: number,
	passId: number, -- 0 = belum dibuat
}

ShopConfig.PRODUCTS = {
	{ key = "koin_kecil", name = "Kantong Koin", coins = 1000, robux = 25, productId = 3734530264 },
	{ key = "koin_sedang", name = "Peti Koin", coins = 5000, robux = 99, productId = 3734530503 },
	{
		key = "koin_besar",
		name = "Brankas Koin",
		coins = 15000,
		robux = 249,
		productId = 3734530604,
	},
	-- Gadget ROBLOCK STORE (lihat MapBuilders/BuildShops.luau untuk etalasenya).
	{ key = "boombox_neon", name = "Boombox Neon", robux = 75, productId = 3735942279 },
	{ key = "skateboard_rocket", name = "Skateboard Rocket", robux = 99, productId = 3735942374 },
	{ key = "headset_gamer", name = "Headset Gamer", robux = 49, productId = 3735942455 },
	{ key = "pedang_cahaya", name = "Pedang Cahaya", robux = 149, productId = 3735942541 },
	-- Costume premium Toko Costume (isi productId setelah Developer Product dibuat).
	{
		key = "costume_sayap_malaikat",
		name = "Sayap Malaikat",
		costume = "sayap_malaikat",
		robux = 99,
		productId = 0,
	},
	{
		key = "costume_naga_api",
		name = "Naga Api",
		costume = "naga_api",
		robux = 129,
		productId = 0,
	},
	{
		key = "costume_mecha_wing",
		name = "Mecha Wing",
		costume = "mecha_wing",
		robux = 149,
		productId = 0,
	},
	{
		key = "costume_penyihir_galaksi",
		name = "Penyihir Galaksi",
		costume = "penyihir_galaksi",
		robux = 119,
		productId = 0,
	},
	{
		key = "costume_raja_petir",
		name = "Raja Petir",
		costume = "raja_petir",
		robux = 159,
		productId = 0,
	},
} :: { Product }

ShopConfig.PASSES = {
	vip = {
		key = "vip",
		name = "VIP ROBLOCK",
		description = "Tanda VIP di papan nama rumah dan hadiah harian dua kali lipat.",
		robux = 199,
		passId = 2096409895,
	},
} :: { [string]: Pass }

ShopConfig.ATTR_VIP = "VIP" -- atribut Player (boolean), diisi server
ShopConfig.ATTR_PROMPT = "CoinShop" -- atribut ProximityPrompt kios Toko Koin
ShopConfig.ATTR_GADGET = "GadgetShop" -- atribut ProximityPrompt etalase gadget (nilai = key produk)
-- Kios Toko Koin di atrium ROBLOCK Mega Mall (ruang dalam di y = 2000, lihat map/BuildInteriors.luau)
ShopConfig.KIOSK_POSITION = Vector3.new(499, 2000, -585)
ShopConfig.MAX_RECEIPTS = 60 -- jumlah tanda terima terakhir yang diingat per pemain

function ShopConfig.productById(productId: number): Product?
	for _, product in ShopConfig.PRODUCTS do
		if product.productId ~= 0 and product.productId == productId then
			return product
		end
	end
	return nil
end

function ShopConfig.productByKey(key: any): Product?
	for _, product in ShopConfig.PRODUCTS do
		if product.key == key then
			return product
		end
	end
	return nil
end

return table.freeze(ShopConfig)
