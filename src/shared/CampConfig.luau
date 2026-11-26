--!strict
-- CampConfig: Perkemahan di tepi danau (CampService / CampController / map/BuildKemah).
-- Memancing penuh di server: beli pancing -> lempar di dermaga -> ikan menggigit -> tarik tepat waktu ->
-- bakar di api unggun / panggangan atau jual ke Kak Sari dengan sistem uang yang ada.

local CampConfig = {}

CampConfig.TAG_VENDOR = "KemahPenjual" -- bagian lapak (ProximityPrompt "Belanja")
CampConfig.TAG_FIRE = "KemahApi" -- api unggun / panggangan, atribut Kind = "unggun" | "panggangan"
CampConfig.TAG_SPOT = "KemahPancing" -- titik memancing di dermaga (+ atribut LookX/LookZ = arah air)
CampConfig.TAG_CENTER = "KemahPusat" -- pusat perkemahan (batas memasang tenda)
CampConfig.TAG_GUITAR = "KemahGitaris" -- model NPC gitaris (client menggerakkan lengannya)
CampConfig.ATTR_PLAYER = "Kemah" -- atribut Player: JSON CampView

CampConfig.TALK_DISTANCE = 16 -- jarak maksimal ke lapak / api saat transaksi
CampConfig.SPOT_DISTANCE = 14
CampConfig.PLACE_RADIUS = 90 -- tenda hanya boleh dipasang sedekat ini dari pusat
CampConfig.MAX_TENTS = 8 -- tenda pemain di seluruh server (yang tertua dibongkar)
CampConfig.STACK_MAX = 99
CampConfig.GRILL_SECONDS = 5
CampConfig.EAT_BUFF_SECONDS = 120
CampConfig.GRILLED_MULTIPLIER = 1.8
CampConfig.GRILL_CAPACITY = { unggun = 2, panggangan = 4 }
CampConfig.BITE_WINDOW = 2.0 -- detik untuk menarik setelah ikan menggigit
CampConfig.BITE_GRACE = 0.5 -- toleransi lag
CampConfig.CAST_COOLDOWN = 1.0
CampConfig.CALL_COOLDOWN = 0.25
CampConfig.SPAWN_RANGE = 130 -- NPC kemah hanya ada bila ada pemain sedekat ini
CampConfig.DESPAWN_RANGE = 190

export type Item = {
	id: string,
	name: string,
	icon: string,
	price: number,
	desc: string,
}

CampConfig.ITEMS = {
	{
		id = "pancing_kayu",
		name = "Pancing Kayu",
		icon = "🎣",
		price = 120,
		desc = "Pancing sederhana untuk mulai memancing.",
	},
	{
		id = "pancing_fiber",
		name = "Pancing Fiber",
		icon = "🎣",
		price = 500,
		desc = "Ikan lebih cepat menggigit dan lebih sering dapat ikan besar.",
	},
	{
		id = "tenda",
		name = "Tenda Kemah",
		icon = "⛺",
		price = 300,
		desc = "Pasang tendamu sendiri di perkemahan.",
	},
	{
		id = "mie",
		name = "Mie Cup",
		icon = "🍜",
		price = 20,
		desc = "Masak di api unggun lalu makan: lari lebih cepat.",
	},
} :: { Item }

function CampConfig.item(id: any): Item?
	for _, item in CampConfig.ITEMS do
		if item.id == id then
			return item
		end
	end
	return nil
end

export type Fish = {
	id: string,
	name: string,
	icon: string,
	weight: number, -- peluang relatif
	price: number, -- harga jual ikan mentah
}

CampConfig.FISH = {
	{ id = "mujair", name = "Ikan Mujair", icon = "🐟", weight = 50, price = 20 },
	{ id = "nila", name = "Ikan Nila", icon = "🐟", weight = 30, price = 32 },
	{ id = "lele", name = "Ikan Lele", icon = "🐟", weight = 22, price = 45 },
	{ id = "gurame", name = "Ikan Gurame", icon = "🐠", weight = 10, price = 95 },
	{ id = "kakap", name = "Ikan Kakap", icon = "🐠", weight = 4, price = 170 },
	{ id = "koi", name = "Ikan Koi Emas", icon = "✨", weight = 1, price = 420 },
} :: { Fish }

function CampConfig.fish(id: any): Fish?
	for _, fish in CampConfig.FISH do
		if fish.id == id then
			return fish
		end
	end
	return nil
end

-- Panggangan hanya lebih banyak muat (4 ikan sekali bakar vs 2 di api unggun); harga bakar sama.
function CampConfig.grilledPrice(fish: Fish, _kind: string?): number
	return math.floor(fish.price * CampConfig.GRILLED_MULTIPLIER + 0.5)
end

-- Bobot ikan untuk pancing tertentu: pancing fiber melipatgandakan peluang ikan mahal.
function CampConfig.weightFor(fish: Fish, rod: string): number
	if rod == "fiber" and fish.price >= 90 then
		return fish.weight * 2.5
	end
	return fish.weight
end

function CampConfig.biteDelay(rod: string): (number, number)
	if rod == "fiber" then
		return 2, 5
	end
	return 3.5, 7.5
end

export type CampView = {
	rod: string, -- "" | "kayu" | "fiber"
	tent: boolean,
	mie: number,
	mieMasak: number,
	fish: { [string]: number },
	grilled: { [string]: number },
}

-- Lagu ceria untuk anak-anak (lirik asli): dinyanyikan gelembung gitaris dan "Ikut Nyanyi".
CampConfig.SONG = {
	"♪ Api unggun menyala, hangat kita bersama ~ ♪",
	"♪ Ikan kecil berenang, ayo kita pancing ~ ♪",
	"♪ La la la, bintang bersinar di atas tenda ~ ♪",
	"♪ Kawan baik berkumpul, tertawa riang gembira ~ ♪",
	"♪ Ikan bakar harum sekali, nyam nyam nyam ~ ♪",
	"♪ Gitar berbunyi merdu, ayo ikut bernyanyi ~ ♪",
}

CampConfig.GUITAR_TRACKS = { 9045573146, 9042550155, 9046533474 } -- APM Music (berlisensi Roblox), tanpa vokal

CampConfig.SING_REPLIES = {
	"Suaranya merdu sekali, Kak! 🎶",
	"Wah kompak, Kak! Ayo lagi!",
	"Mantap, Kak! Ikut terus ya!",
}

CampConfig.GREETINGS = {
	"Halo Kak! Selamat datang di perkemahan ⛺",
	"Kak, duduk sini, hangat di dekat api!",
	"Ayo Kak, ikut nyanyi bareng! 🎸",
}

CampConfig.VENDOR_LINES = {
	"Halo Kak! Pancing, tenda, dan mie ada di sini!",
	"Kak, ikan hasil pancingan bisa dijual ke aku lho!",
	"Mau mancing, Kak? Beli pancing dulu ya 🎣",
}

CampConfig.THANKS = {
	"Terima kasih, Kak! Selamat memancing!",
	"Makasih ya Kak, ikannya segar sekali!",
	"Sip, Kak! Datang lagi ya!",
}

return CampConfig
