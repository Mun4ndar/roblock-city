--!strict
-- Rumah pemain: tipe & harga, pilihan cat, dan hiasan halaman.
-- Menambah hiasan baru = menambah satu entri di ITEMS (dibangun dari part).
-- Modul ini ikut ter-replikasi ke client; server tetap memvalidasi semuanya.

local HouseConfig = {}

local rgb = Color3.fromRGB

export type Tier = {
	id: string,
	name: string,
	price: number,
	description: string,
}

-- Satu part hiasan. offset relatif terhadap titik slot halaman (y = 0 di tanah).
export type PartSpec = {
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	collide: boolean?, -- default true
	light: boolean?, -- lampu yang menyala saat malam
	bounce: number?, -- kecepatan pantul (trampolin)
}

export type ItemDef = {
	id: string,
	name: string,
	icon: string,
	price: number,
	parts: { PartSpec },
}

export type YardSlot = { name: string, offset: CFrame }

-- Keadaan rumah pemain yang dikirim ke client (atribut Player "House", JSON).
export type HouseView = {
	id: number, -- rumah yang dibeli (0 = belum punya)
	live: number, -- rumah yang ditempati di server ini (bisa rumah pengganti)
	tier: string,
	paint: { [string]: number },
	items: { [string]: string },
	pos: { number }, -- x, y, z depan pintu
}

-- ---------------------------------------------------------------- aturan

HouseConfig.SELL_REFUND = 0.5 -- bagian harga yang kembali saat rumah dijual
HouseConfig.PAINT_PRICE = 25 -- biaya sekali ganti cat (kembali ke warna asli gratis)
HouseConfig.BUY_DISTANCE = 40 -- harus sedekat ini (stud) dengan rumah untuk membeli
HouseConfig.HOME_COOLDOWN = 30 -- jeda tombol Pulang (detik)

HouseConfig.TAG_HOUSE = "House"
HouseConfig.ATTR_PLAYER = "House" -- atribut Player: JSON HouseView
HouseConfig.ATTR_ID = "HouseId" -- atribut Model rumah
HouseConfig.ATTR_TIER = "HouseTier"
HouseConfig.ATTR_OWNER_ID = "HouseOwnerId" -- 0 = kosong
HouseConfig.ATTR_OWNER_NAME = "HouseOwnerName"
HouseConfig.ATTR_PROMPT = "HousePrompt" -- atribut ProximityPrompt di pintu: id rumah
HouseConfig.TAG_BOUNCE = "BouncePad" -- part yang memantulkan pemain (trampolin)
HouseConfig.ATTR_BOUNCE = "Bounce" -- kecepatan pantulnya

HouseConfig.TIERS = {
	{
		id = "kecil",
		name = "Rumah Mungil",
		price = 2500,
		description = "Satu lantai, pas untuk rumah pertamamu.",
	},
	{
		id = "keluarga",
		name = "Rumah Keluarga",
		price = 6000,
		description = "Lebih lega: ada garasi atau lantai dua.",
	},
	{
		id = "besar",
		name = "Rumah Besar",
		price = 12000,
		description = "Dua lantai lengkap dengan garasi.",
	},
} :: { Tier }

-- Bagian rumah yang bisa dicat. Indeks 0 = warna asli rumah.
HouseConfig.PAINT_SLOTS = {
	{ id = "wall", name = "Dinding" },
	{ id = "roof", name = "Atap" },
	{ id = "door", name = "Pintu" },
}

HouseConfig.PAINT = {
	wall = {
		rgb(250, 215, 120),
		rgb(170, 215, 240),
		rgb(245, 180, 190),
		rgb(190, 230, 170),
		rgb(240, 240, 230),
		rgb(205, 190, 240),
		rgb(255, 170, 120),
		rgb(130, 200, 200),
	},
	roof = {
		rgb(170, 70, 55),
		rgb(70, 80, 110),
		rgb(90, 110, 70),
		rgb(60, 100, 150),
		rgb(110, 70, 50),
		rgb(80, 80, 90),
		rgb(150, 60, 110),
		rgb(40, 130, 120),
	},
	door = {
		rgb(120, 80, 50),
		rgb(200, 60, 60),
		rgb(50, 110, 190),
		rgb(60, 150, 90),
		rgb(250, 250, 245),
		rgb(60, 60, 70),
		rgb(240, 190, 60),
		rgb(150, 90, 190),
	},
} :: { [string]: { Color3 } }

-- Titik hiasan di halaman, relatif terhadap pusat rumah (depan rumah = -Z).
HouseConfig.YARD_SLOTS = {
	{ name = "Depan kanan", offset = CFrame.new(5, 0, -11) },
	{ name = "Depan kiri", offset = CFrame.new(-9, 0, -11) },
	{ name = "Samping", offset = CFrame.new(-13.5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) },
	{ name = "Belakang", offset = CFrame.new(0, 0, 12) },
} :: { YardSlot }

-- Silinder tegak: size = (tinggi, diameter, diameter).
local function up(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local WOOD = rgb(150, 100, 60)
local METAL = rgb(120, 126, 136)
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

HouseConfig.ITEMS = {
	{
		id = "pot",
		name = "Pot Bunga",
		icon = "🌷",
		price = 40,
		parts = {
			{
				size = Vector3.new(1.6, 2, 2),
				offset = up(0, 0.8, 0),
				color = rgb(190, 110, 70),
				shape = CYL,
			},
			{
				size = Vector3.new(2.2, 2.2, 2.2),
				offset = CFrame.new(0, 2.4, 0),
				color = rgb(70, 160, 80),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				offset = CFrame.new(0.6, 3.3, 0.2),
				color = rgb(255, 120, 170),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				offset = CFrame.new(-0.5, 3.2, -0.4),
				color = rgb(255, 210, 80),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.8, 0.8, 0.8),
				offset = CFrame.new(-0.1, 3.5, 0.6),
				color = rgb(250, 250, 250),
				shape = BALL,
				collide = false,
			},
		},
	},
	{
		id = "bendera",
		name = "Tiang Bendera",
		icon = "🚩",
		price = 70,
		parts = {
			{
				size = Vector3.new(13, 0.4, 0.4),
				offset = up(0, 6.5, 0),
				color = METAL,
				shape = CYL,
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(1, 1.4, 1.4),
				offset = up(0, 0.5, 0),
				color = rgb(200, 200, 205),
				shape = CYL,
			},
			{
				size = Vector3.new(3.6, 1.1, 0.12),
				offset = CFrame.new(1.95, 12.2, 0),
				color = rgb(220, 40, 40),
				collide = false,
			},
			{
				size = Vector3.new(3.6, 1.1, 0.12),
				offset = CFrame.new(1.95, 11.1, 0),
				color = rgb(250, 250, 250),
				collide = false,
			},
		},
	},
	{
		id = "lampu",
		name = "Lampu Taman",
		icon = "💡",
		price = 90,
		parts = {
			{
				size = Vector3.new(5, 0.5, 0.5),
				offset = up(0, 2.5, 0),
				color = rgb(50, 54, 62),
				shape = CYL,
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.5, 1.4, 1.4),
				offset = up(0, 0.25, 0),
				color = rgb(50, 54, 62),
				shape = CYL,
			},
			{
				size = Vector3.new(1.5, 1.5, 1.5),
				offset = CFrame.new(0, 5.6, 0),
				color = rgb(255, 236, 180),
				shape = BALL,
				material = Enum.Material.Neon,
				collide = false,
				light = true,
			},
		},
	},
	{
		id = "kelinci",
		name = "Patung Kelinci",
		icon = "🐰",
		price = 100,
		parts = {
			{
				size = Vector3.new(2.2, 2.2, 2.2),
				offset = CFrame.new(0, 1.1, 0),
				color = rgb(245, 245, 240),
				shape = BALL,
			},
			{
				size = Vector3.new(1.6, 1.6, 1.6),
				offset = CFrame.new(0, 2.7, -0.2),
				color = rgb(245, 245, 240),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.4, 1.6, 0.3),
				offset = CFrame.new(-0.4, 4, -0.1),
				color = rgb(245, 245, 240),
				collide = false,
			},
			{
				size = Vector3.new(0.4, 1.6, 0.3),
				offset = CFrame.new(0.4, 4, -0.1),
				color = rgb(245, 245, 240),
				collide = false,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				offset = CFrame.new(0, 2.7, -1),
				color = rgb(255, 150, 170),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				offset = CFrame.new(-0.35, 3, -0.85),
				color = rgb(40, 40, 50),
				shape = BALL,
				collide = false,
			},
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				offset = CFrame.new(0.35, 3, -0.85),
				color = rgb(40, 40, 50),
				shape = BALL,
				collide = false,
			},
		},
	},
	{
		id = "bangku",
		name = "Bangku Taman",
		icon = "🪑",
		price = 120,
		parts = {
			{
				size = Vector3.new(5, 0.4, 1.8),
				offset = CFrame.new(0, 1.5, 0),
				color = WOOD,
				material = Enum.Material.WoodPlanks,
			},
			{
				size = Vector3.new(5, 1.6, 0.4),
				offset = CFrame.new(0, 2.6, 0.8),
				color = WOOD,
				material = Enum.Material.WoodPlanks,
			},
			{
				size = Vector3.new(0.4, 1.3, 1.6),
				offset = CFrame.new(-2.1, 0.65, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.4, 1.3, 1.6),
				offset = CFrame.new(2.1, 0.65, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
		},
	},
	{
		id = "kolam",
		name = "Kolam Ikan",
		icon = "🐟",
		price = 250,
		parts = {
			{
				size = Vector3.new(0.8, 6, 6),
				offset = up(0, 0.4, 0),
				color = rgb(150, 150, 158),
				shape = CYL,
				material = Enum.Material.Slate,
			},
			{
				size = Vector3.new(0.2, 5, 5),
				offset = up(0, 0.82, 0),
				color = rgb(70, 170, 230),
				shape = CYL,
				material = Enum.Material.Glass,
				collide = false,
			},
			{
				size = Vector3.new(0.9, 0.3, 0.4),
				offset = CFrame.new(0.8, 0.95, 0.5),
				color = rgb(255, 140, 40),
				collide = false,
			},
			{
				size = Vector3.new(0.9, 0.3, 0.4),
				offset = CFrame.new(-0.9, 0.95, -0.6) * CFrame.Angles(0, 1, 0),
				color = rgb(250, 250, 250),
				collide = false,
			},
			{
				size = Vector3.new(1.2, 0.1, 1.2),
				offset = CFrame.new(-0.6, 0.95, 1.2),
				color = rgb(60, 150, 70),
				shape = CYL,
				collide = false,
			},
		},
	},
	{
		id = "trampolin",
		name = "Trampolin",
		icon = "🤸",
		price = 350,
		parts = {
			{
				size = Vector3.new(0.4, 7, 7),
				offset = up(0, 1.8, 0),
				color = rgb(40, 44, 54),
				shape = CYL,
				bounce = 75,
			},
			{
				size = Vector3.new(0.5, 7.8, 7.8),
				offset = up(0, 1.7, 0),
				color = rgb(60, 140, 235),
				shape = CYL,
			},
			{
				size = Vector3.new(1.6, 0.4, 0.4),
				offset = up(2.6, 0.8, 2.6),
				color = METAL,
				shape = CYL,
			},
			{
				size = Vector3.new(1.6, 0.4, 0.4),
				offset = up(-2.6, 0.8, 2.6),
				color = METAL,
				shape = CYL,
			},
			{
				size = Vector3.new(1.6, 0.4, 0.4),
				offset = up(2.6, 0.8, -2.6),
				color = METAL,
				shape = CYL,
			},
			{
				size = Vector3.new(1.6, 0.4, 0.4),
				offset = up(-2.6, 0.8, -2.6),
				color = METAL,
				shape = CYL,
			},
		},
	},
} :: { ItemDef }

-- ---------------------------------------------------------------- isi rumah

-- Ruang dalam dibangun setinggi ini (stud) tepat di atas rumah; pemain masuk lewat pintu.
-- Jauh di atas supaya tidak terlihat dari tanah. (Di bawah tanah tidak bisa: kabut
-- Atmosphere menebal di ketinggian rendah dan ruangan jadi putih semua.)
HouseConfig.INTERIOR_HEIGHT = 2000
-- Pintu keluar di dalam ruang (relatif ke tengah lantai), menghadap ke dalam.
HouseConfig.INTERIOR_DOOR = CFrame.new(0, 3.7, 10.8)

local WALL = rgb(250, 240, 222)
local SOFA = rgb(86, 136, 200)
local WHITE = rgb(248, 248, 246)
local PLASTER = Enum.Material.Plaster
local PLANKS = Enum.Material.WoodPlanks

-- Ruang 26 x 22 stud, tinggi 11. offset relatif ke tengah lantai (y = 0 di permukaan lantai).
-- Mengubah/menambah perabot = mengubah daftar ini; semua rumah mengikuti.
HouseConfig.INTERIOR = {
	-- lantai, plafon, dinding
	-- (kulit ruangan sengaja tebal 6 stud: dinding tipis ditembus sinar matahari)
	{
		size = Vector3.new(38, 6, 34),
		offset = CFrame.new(0, -3, 0),
		color = rgb(196, 154, 108),
		material = PLANKS,
	},
	{ size = Vector3.new(38, 6, 34), offset = CFrame.new(0, 14, 0), color = WHITE },
	{
		size = Vector3.new(38, 18, 6),
		offset = CFrame.new(0, 5.5, -14),
		color = WALL,
		material = PLASTER,
	},
	{
		size = Vector3.new(38, 18, 6),
		offset = CFrame.new(0, 5.5, 14),
		color = WALL,
		material = PLASTER,
	},
	{
		size = Vector3.new(6, 18, 22),
		offset = CFrame.new(-16, 5.5, 0),
		color = WALL,
		material = PLASTER,
	},
	{
		size = Vector3.new(6, 18, 22),
		offset = CFrame.new(16, 5.5, 0),
		color = WALL,
		material = PLASTER,
	},
	-- lampu plafon dan jendela terang
	{
		size = Vector3.new(3, 0.4, 3),
		offset = CFrame.new(-7, 10.8, -3),
		color = rgb(255, 240, 205),
		material = Enum.Material.Neon,
		collide = false,
		light = true,
	},
	{
		size = Vector3.new(3, 0.4, 3),
		offset = CFrame.new(7, 10.8, -3),
		color = rgb(255, 240, 205),
		material = Enum.Material.Neon,
		collide = false,
		light = true,
	},
	{
		size = Vector3.new(3, 0.4, 3),
		offset = CFrame.new(0, 10.8, 6),
		color = rgb(255, 240, 205),
		material = Enum.Material.Neon,
		collide = false,
		light = true,
	},
	{
		size = Vector3.new(8, 4.5, 0.2),
		offset = CFrame.new(0, 6, -10.9),
		color = rgb(176, 220, 255),
		material = Enum.Material.Neon,
		collide = false,
	},
	{
		size = Vector3.new(8.6, 0.4, 0.5),
		offset = CFrame.new(0, 3.6, -10.8),
		color = WHITE,
		collide = false,
	},
	-- ruang tamu: karpet, sofa, meja, TV
	{
		size = Vector3.new(7, 0.12, 10),
		offset = CFrame.new(-8, 0.06, -4),
		color = rgb(236, 186, 120),
		collide = false,
	},
	{ size = Vector3.new(3, 1.4, 8), offset = CFrame.new(-4, 0.7, -4), color = SOFA },
	{ size = Vector3.new(0.9, 2.4, 8), offset = CFrame.new(-2.9, 2, -4), color = SOFA },
	{ size = Vector3.new(3, 2.2, 0.9), offset = CFrame.new(-4, 1.1, -8.4), color = SOFA },
	{ size = Vector3.new(3, 2.2, 0.9), offset = CFrame.new(-4, 1.1, 0.4), color = SOFA },
	{
		size = Vector3.new(2.4, 0.3, 4),
		offset = CFrame.new(-8, 1.4, -4),
		color = WOOD,
		material = PLANKS,
	},
	{ size = Vector3.new(1.6, 1.2, 3), offset = CFrame.new(-8, 0.6, -4), color = rgb(90, 64, 44) },
	{
		size = Vector3.new(1.6, 1.6, 6),
		offset = CFrame.new(-12.2, 0.8, -4),
		color = WOOD,
		material = PLANKS,
	},
	{
		size = Vector3.new(0.3, 3.2, 5.4),
		offset = CFrame.new(-12.4, 3.4, -4),
		color = rgb(24, 26, 34),
		material = Enum.Material.Glass,
	},
	-- kamar: tempat tidur, meja kecil + lampu, lemari
	{
		size = Vector3.new(6, 1.2, 9),
		offset = CFrame.new(9.5, 0.6, -6),
		color = WOOD,
		material = PLANKS,
	},
	{ size = Vector3.new(5.6, 0.8, 8.6), offset = CFrame.new(9.5, 1.6, -6), color = WHITE },
	{
		size = Vector3.new(5.7, 0.3, 5.5),
		offset = CFrame.new(9.5, 2.1, -4.5),
		color = rgb(240, 150, 170),
	},
	{ size = Vector3.new(4, 0.6, 1.8), offset = CFrame.new(9.5, 2.3, -9.3), color = WHITE },
	{
		size = Vector3.new(2, 1.8, 2),
		offset = CFrame.new(5.2, 0.9, -9.6),
		color = WOOD,
		material = PLANKS,
	},
	{
		size = Vector3.new(1, 1, 1),
		offset = CFrame.new(5.2, 2.4, -9.6),
		color = rgb(255, 226, 170),
		material = Enum.Material.Neon,
		shape = BALL,
		collide = false,
	},
	{
		size = Vector3.new(2, 8, 5),
		offset = CFrame.new(12.4, 4, 2.6),
		color = WOOD,
		material = PLANKS,
	},
	-- dapur dan meja makan
	{ size = Vector3.new(8, 3, 2.2), offset = CFrame.new(8, 1.5, 10.2), color = WHITE },
	{
		size = Vector3.new(8.2, 0.3, 2.4),
		offset = CFrame.new(8, 3.15, 10.2),
		color = rgb(70, 76, 88),
	},
	{
		size = Vector3.new(2.4, 6.5, 2.6),
		offset = CFrame.new(12.1, 3.25, 7.6),
		color = rgb(206, 212, 220),
		material = Enum.Material.Metal,
	},
	{
		size = Vector3.new(5, 0.3, 3.4),
		offset = CFrame.new(6.5, 2.6, 3),
		color = WOOD,
		material = PLANKS,
	},
	{ size = Vector3.new(1, 2.5, 1), offset = CFrame.new(6.5, 1.25, 3), color = rgb(90, 64, 44) },
	{
		size = Vector3.new(1.8, 1.6, 1.8),
		offset = CFrame.new(6.5, 0.8, 0.2),
		color = rgb(240, 150, 90),
	},
	{
		size = Vector3.new(1.8, 1.6, 1.8),
		offset = CFrame.new(6.5, 0.8, 5.8),
		color = rgb(240, 150, 90),
	},
	-- rak buku dan tanaman
	{
		size = Vector3.new(5, 7, 1.4),
		offset = CFrame.new(-8, 3.5, 10.6),
		color = WOOD,
		material = PLANKS,
	},
	{
		size = Vector3.new(4.4, 1, 1),
		offset = CFrame.new(-8, 4.6, 10.2),
		color = rgb(210, 70, 70),
		collide = false,
	},
	{
		size = Vector3.new(4.4, 1, 1),
		offset = CFrame.new(-8, 2.6, 10.2),
		color = rgb(70, 120, 200),
		collide = false,
	},
	{
		size = Vector3.new(1.6, 1.8, 1.8),
		offset = up(-11.6, 0.8, 7.6),
		color = rgb(190, 110, 70),
		shape = CYL,
	},
	{
		size = Vector3.new(2.6, 2.6, 2.6),
		offset = CFrame.new(-11.6, 2.8, 7.6),
		color = rgb(70, 160, 80),
		shape = BALL,
		collide = false,
	},
} :: { PartSpec }

-- ---------------------------------------------------------------- util

local tierById: { [string]: Tier } = {}
for _, tier in HouseConfig.TIERS do
	tierById[tier.id] = tier
end
local itemById: { [string]: ItemDef } = {}
for _, item in HouseConfig.ITEMS do
	itemById[item.id] = item
end

function HouseConfig.tier(id: string): Tier?
	return tierById[id]
end

function HouseConfig.item(id: string): ItemDef?
	return itemById[id]
end

-- Tipe rumah ditentukan dari bentuk bangunannya di peta.
function HouseConfig.tierFor(stories: number, hasGarage: boolean): string
	if stories >= 2 and hasGarage then
		return "besar"
	elseif stories >= 2 or hasGarage then
		return "keluarga"
	end
	return "kecil"
end

function HouseConfig.address(id: number): string
	return "Rumah No. " .. tostring(id)
end

function HouseConfig.sellPrice(tierId: string): number
	local tier = tierById[tierId]
	return if tier then math.floor(tier.price * HouseConfig.SELL_REFUND) else 0
end

return table.freeze(HouseConfig)
