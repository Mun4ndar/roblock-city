--!strict
-- ProgressConfig: kemajuan jangka panjang. Koleksi langka (mobil dan hewan) yang jatuh dari tugas kerja,
-- seragam bertingkat menurut level pekerjaan, papan peringkat, bonus anggota grup Roblox, dan kode tukar.
-- Daftar kode tukar sengaja TIDAK di sini (modul bersama terlihat client); ada di ProgressService.

export type Rare = {
	id: string,
	icon: string,
	name: string,
	kind: string,
	rarity: string,
	cash: number,
}
export type Tier = { level: number, name: string, trim: Color3, badge: Color3, tintHat: boolean? }

local ProgressConfig = {}

ProgressConfig.ATTR_COLLECTION = "Koleksi" -- atribut Player: id koleksi dipisah koma
ProgressConfig.ATTR_GROUP_BONUS = "GroupBonus" -- atribut Player: pengali gaji anggota grup (mis. 1.1)

-- ---------------------------------------------------------------- koleksi langka

ProgressConfig.RARITY = {
	langka = { name = "Langka", color = Color3.fromRGB(70, 140, 230), weight = 70 },
	epik = { name = "Epik", color = Color3.fromRGB(170, 90, 220), weight = 25 },
	legenda = { name = "Legenda", color = Color3.fromRGB(255, 170, 30), weight = 5 },
}

ProgressConfig.RARES = {
	{
		id = "klasikBiru",
		icon = "🚙",
		name = "Mobil Klasik Biru",
		kind = "Mobil",
		rarity = "langka",
		cash = 150,
	},
	{
		id = "kucingEmas",
		icon = "🐱",
		name = "Kucing Emas",
		kind = "Hewan",
		rarity = "langka",
		cash = 150,
	},
	{
		id = "rubahSenja",
		icon = "🦊",
		name = "Rubah Senja",
		kind = "Hewan",
		rarity = "langka",
		cash = 150,
	},
	{
		id = "kancilEmas",
		icon = "🚗",
		name = "Mini Car Emas",
		kind = "Mobil",
		rarity = "epik",
		cash = 400,
	},
	{
		id = "motorPelangi",
		icon = "🏍️",
		name = "Motor Pelangi",
		kind = "Mobil",
		rarity = "epik",
		cash = 400,
	},
	{
		id = "pandaKristal",
		icon = "🐼",
		name = "Panda Kristal",
		kind = "Hewan",
		rarity = "epik",
		cash = 400,
	},
	{
		id = "busTingkat",
		icon = "🚌",
		name = "Bus Tingkat Mini",
		kind = "Mobil",
		rarity = "legenda",
		cash = 1000,
	},
	{
		id = "nagaMungil",
		icon = "🐲",
		name = "Naga Mungil",
		kind = "Hewan",
		rarity = "legenda",
		cash = 1000,
	},
} :: { Rare }

ProgressConfig.DROP_BASE = 0.04 -- peluang jatuh per tugas selesai
ProgressConfig.DROP_PER_LEVEL = 0.004 -- tambahan per level pekerjaan
ProgressConfig.PITY = 25 -- pasti jatuh kalau segini tugas berturut-turut tanpa koleksi
ProgressConfig.SET_BONUS = 5000 -- hadiah melengkapi seluruh koleksi

function ProgressConfig.rare(id: any): Rare?
	for _, r in ProgressConfig.RARES do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- ---------------------------------------------------------------- seragam bertingkat

-- Level pekerjaan -> tingkat seragam (garis rompi dan lencana berganti warna). Urut dari yang tertinggi.
ProgressConfig.UNIFORM_TIERS = {
	{
		level = 10,
		name = "Emas Senior",
		trim = Color3.fromRGB(255, 205, 60),
		badge = Color3.fromRGB(255, 205, 60),
		tintHat = true,
	},
	{
		level = 7,
		name = "Emas",
		trim = Color3.fromRGB(255, 205, 60),
		badge = Color3.fromRGB(255, 235, 150),
	},
	{
		level = 4,
		name = "Perak",
		trim = Color3.fromRGB(205, 212, 224),
		badge = Color3.fromRGB(235, 240, 250),
	},
} :: { Tier }

function ProgressConfig.tierFor(level: number): Tier?
	for _, tier in ProgressConfig.UNIFORM_TIERS do
		if level >= tier.level then
			return tier
		end
	end
	return nil
end

-- ---------------------------------------------------------------- papan peringkat

ProgressConfig.BOARD_SIZE = 10
ProgressConfig.PUSH_INTERVAL = 150 -- detik antar pengiriman nilai pemain ke papan

-- ---------------------------------------------------------------- grup Roblox

-- Isi GROUP_ID dengan nomor grup Roblox resmi (0 = fitur grup belum aktif).
ProgressConfig.GROUP_ID = 0
ProgressConfig.GROUP_NAME = "ROBLOCK CITY"
ProgressConfig.GROUP_BONUS = 1.1 -- +10% gaji semua pekerjaan untuk anggota grup
ProgressConfig.GROUP_JOIN_REWARD = 1000 -- hadiah sekali untuk anggota grup

return ProgressConfig
