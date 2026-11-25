--!strict
-- CafeConfig: dua kafe dalam ruangan (Cafe Startduck dan Kafe Kota): menu, harga, dan sapaan pelayan.
-- Pesanan memakai StoreService.serve (animasi makan/minum sama seperti toko), jadi tiap menu menunjuk
-- ke id barang di StoreConfig untuk bentuk dan animasinya; nama dan harga kafe ditentukan di sini.
-- Dipakai server (CafeService) dan client (CafeController); papan menu di dinding dibuat dari data ini.

local CafeConfig = {}

CafeConfig.OPEN_EVENT = "KafeMenuOpen" -- RemoteEvent server -> client: (venueKey)
CafeConfig.ORDER_FUNC = "KafeOrder" -- RemoteFunction client -> server: (venueKey, index) -> { ok, message }
CafeConfig.ORDER_DISTANCE = 30 -- jarak maksimal pemain ke pelayan saat memesan
CafeConfig.FOLDER = "KafeHidup" -- Workspace: pelayan kedua kafe

export type Entry = { id: string, name: string, price: number, desc: string, icon: string? }
export type Venue = {
	key: string,
	title: string,
	icon: string,
	accent: Color3,
	menu: { Entry },
}

CafeConfig.VENUES = {
	startduck = {
		key = "startduck",
		title = "Cafe Startduck",
		icon = "🦆",
		accent = Color3.fromRGB(255, 196, 40),
		menu = {
			{ id = "kopi_susu", name = "Duck Latte", price = 18, desc = "Kopi susu dingin dengan busa lembut." },
			{ id = "es_teh", name = "Teh Madu Dingin", price = 10, desc = "Teh segar dengan madu.", icon = "🥤" },
			{ id = "susu_kotak", name = "Susu Cokelat", price = 12, desc = "Susu cokelat manis, favorit anak." },
			{ id = "air_mineral", name = "Air Mineral", price = 6, desc = "Segar dan menyehatkan." },
			{ id = "roti", name = "Croissant Mentega", price = 14, desc = "Renyah di luar, lembut di dalam." },
			{ id = "es_krim", name = "Es Krim Vanila", price = 13, desc = "Dua scoop dingin dan manis." },
			{ id = "onigiri", name = "Nasi Kepal Mini", price = 12, desc = "Nasi kepal isi ayam suwir." },
		},
	},
	kafekota = {
		key = "kafekota",
		title = "Kafe Kota",
		icon = "☕",
		accent = Color3.fromRGB(255, 160, 60),
		menu = {
			{ id = "kopi_susu", name = "Kopi Susu Gula Aren", price = 16, desc = "Kopi susu khas kota, manis gula aren." },
			{ id = "es_teh", name = "Es Teh Tarik", price = 9, desc = "Teh tarik dingin yang menyegarkan.", icon = "🥤" },
			{ id = "susu_kotak", name = "Susu Segar", price = 10, desc = "Susu segar dingin." },
			{ id = "air_mineral", name = "Air Mineral", price = 5, desc = "Segar dan menyehatkan." },
			{ id = "roti", name = "Roti Bakar Cokelat", price = 12, desc = "Roti bakar hangat, cokelat meleleh." },
			{ id = "keripik", name = "Keripik Kentang", price = 8, desc = "Kriuk-kriuk gurih." },
			{ id = "cilok", name = "Cilok Kafe", price = 10, desc = "Cilok kenyal dengan saus pedas manis." },
		},
	},
} :: { [string]: Venue }

function CafeConfig.entry(venueKey: any, index: any): Entry?
	local venue = if type(venueKey) == "string" then CafeConfig.VENUES[venueKey] else nil
	if venue == nil or type(index) ~= "number" then
		return nil
	end
	return venue.menu[math.floor(index)]
end

return table.freeze(CafeConfig)
