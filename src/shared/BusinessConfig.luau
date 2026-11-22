--!strict
-- Usaha pemain: Kafe di dalam ROBLOCK Mega Mall. Pemain membuka kafe, lalu kafe menghasilkan
-- uang tiap menit selama pemiliknya sedang bermain (ditampung di laci kasir sampai penuh).
-- Pemilik mengambil hasilnya di kasir, bisa melayani pelanggan untuk bonus, dan menaikkan
-- tingkat kafe. Semua angka diatur di sini.

local BusinessConfig = {}

export type Level = {
	name: string,
	price: number, -- harga membuka (tingkat 1) atau naik ke tingkat ini
	income: number, -- uang per menit
	capacity: number, -- isi laci kasir paling banyak
	serveBonus: number, -- bonus tiap melayani pelanggan
}

-- Keadaan yang dikirim ke client (atribut Player "Business", JSON). level 0 = belum punya.
export type BusinessView = { level: number, stored: number }

-- Kasir Kafe Mall (ruang dalam di y = 2000, lihat map/BuildInteriors.luau)
BusinessConfig.POSITION = Vector3.new(564, 2000, -623)
BusinessConfig.RANGE = 34
BusinessConfig.ATTR_PLAYER = "Business"
BusinessConfig.ATTR_PROMPT = "BusinessCafe"
BusinessConfig.TICK_SECONDS = 60
BusinessConfig.SERVE_COOLDOWN = 25 -- detik antar melayani pelanggan

BusinessConfig.LEVELS = {
	{ name = "Kedai Kopi", price = 3000, income = 15, capacity = 300, serveBonus = 10 },
	{ name = "Kafe Ramai", price = 8000, income = 35, capacity = 800, serveBonus = 20 },
	{ name = "Kafe Bintang", price = 20000, income = 70, capacity = 2000, serveBonus = 35 },
} :: { Level }

function BusinessConfig.get(level: number): Level?
	return BusinessConfig.LEVELS[level]
end

return table.freeze(BusinessConfig)
