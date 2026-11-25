--!strict
-- ConcertConfig: Panggung Konser di Taman Kota (ConcertService di server, ConcertController di client,
-- model dari tools/blender/panggung.py + map/BuildPanggung.luau). Semua angka yang bisa diatur ada di sini.
-- Musik hanya dari perpustakaan audio resmi Roblox (lagu koplo/dangdut/campursari berlisensi di IndonesiaConfig).

export type Performer = {
	name: string,
	role: string, -- "vokal" | "kendang" | "gitar" | "penari"
	at: Vector2, -- posisi di dek (x, y Blender: y positif = ke arah penonton)
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hair: Color3,
	dress: boolean?,
	anims: { string },
}

local rgb = Color3.fromRGB

local ConcertConfig = {}

-- ---------------------------------------------------------------- lokasi
-- Titik asal panggung di dunia (timur plaza Taman Kota, menghadap barat ke plaza) dan putaran Y.
-- Koordinat Blender (x, y, z) -> dunia: frame() * Vector3.new(x, z, -y).
ConcertConfig.ORIGIN = Vector3.new(842, 0, 55)
ConcertConfig.YAW = math.pi / 2

function ConcertConfig.frame(): CFrame
	return CFrame.new(ConcertConfig.ORIGIN) * CFrame.Angles(0, ConcertConfig.YAW, 0)
end

-- Titik di dunia dari koordinat Blender.
function ConcertConfig.world(x: number, y: number, z: number): Vector3
	return ConcertConfig.frame() * Vector3.new(x, z, -y)
end

ConcertConfig.CENTER = Vector3.new(842 - 10, 0, 55) -- pusat area panggung + penonton (untuk jarak)

-- ---------------------------------------------------------------- jadwal
-- Konser jalan malam hari (jam permainan, Lighting.ClockTime) dari SHOW_FROM sampai SHOW_TO (lewat tengah malam).
ConcertConfig.SHOW_FROM = 17
ConcertConfig.SHOW_TO = 5

function ConcertConfig.isShowTime(clock: number): boolean
	local from, to = ConcertConfig.SHOW_FROM, ConcertConfig.SHOW_TO
	if from <= to then
		return clock >= from and clock < to
	end
	return clock >= from or clock < to
end

-- Atribut Workspace yang diisi server dan dibaca client.
ConcertConfig.ATTR_ACTIVE = "KonserAktif" -- boolean: konser sedang berlangsung
ConcertConfig.ATTR_FIREWORK = "KonserKembangApi" -- angka naik tiap ada kembang api
ConcertConfig.ATTR_TRACK = "KonserLagu" -- angka naik tiap ganti lagu (confetti)

-- Tag CollectionService (dipasang BuildPanggung).
ConcertConfig.TAG_LAMP = "KonserLampu"
ConcertConfig.TAG_SCREEN = "KonserLayar"
ConcertConfig.TAG_SIGN = "KonserPapan"
ConcertConfig.TAG_PAD = "KonserJogetPad"

-- ---------------------------------------------------------------- musik
-- Lagu panggung = DistroKid resmi (berlisensi) yang TIDAK dipakai radio mobil (IndonesiaConfig.STATIONS). Tambah id baru di sini.
ConcertConfig.PLAYLIST = table.freeze({
	{ id = 79791127438214, name = "Malaikat Cinta" },
	{ id = 95373906477475, name = "Janda Muda" },
	{ id = 97948069367953, name = "Stucy | Mix Dangdut pt4" },
	{ id = 96082404733673, name = "Stucy | Mix Dangdut pt3" },
	{ id = 107302164689882, name = "Janji Koplo" },
	{ id = 108733665602479, name = "Joged Bareng Sayang" },
	{ id = 115933072822345, name = "Memendam Rasa" },
})
ConcertConfig.VOLUME = 1.0
ConcertConfig.HEAR_MIN = 55 -- stud dari panggung: suara penuh
ConcertConfig.HEAR_MAX = 340 -- stud dari panggung: suara habis
ConcertConfig.MUSIC_SPOT = Vector3.new(0, 14, 8) -- posisi speaker (koordinat Blender)

-- ---------------------------------------------------------------- jarak dan kualitas
ConcertConfig.NPC_RANGE = 260 -- penampil muncul kalau ada pemain sedekat ini
ConcertConfig.NPC_KEEP = 340 -- penampil dihapus kalau semua pemain lebih jauh dari ini
ConcertConfig.VISUAL_RANGE = 300 -- lampu, layar LED, dan sorotan hanya bergerak sedekat ini
ConcertConfig.FIREWORK_RANGE = 520 -- kembang api terlihat sejauh ini
ConcertConfig.FIREWORK_EVERY = { 35, 60 } -- detik antar pertunjukan kembang api

-- Jumlah elemen per kualitas (HP memakai LOW).
ConcertConfig.QUALITY = {
	HIGH = { beams = 22, realLights = 6, ledCols = 24, ledRows = 10, ledHz = 10, sideCols = 4, sideRows = 8, bursts = 5, confetti = 90 },
	LOW = { beams = 8, realLights = 3, ledCols = 12, ledRows = 5, ledHz = 5, sideCols = 2, sideRows = 4, bursts = 3, confetti = 40 },
}

-- ---------------------------------------------------------------- lantai joget
ConcertConfig.DANCE_ANIMATIONS = table.freeze({
	"rbxassetid://507771019",
	"rbxassetid://507776043",
	"rbxassetid://507777268",
	"rbxassetid://507770677",
})
ConcertConfig.DANCE_SWITCH_SECONDS = 14
ConcertConfig.PAD_PROMPT = { action = "Joget!", object = "Lantai Dansa" }

-- ---------------------------------------------------------------- penampil (pemain band + penari)
local DANCE = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" }

ConcertConfig.PERFORMERS = table.freeze({
	{
		name = "Sari Koplo",
		role = "vokal",
		at = Vector2.new(0, 6.5),
		skin = rgb(240, 190, 140),
		shirt = rgb(255, 80, 150),
		pants = rgb(255, 214, 40),
		hair = rgb(30, 26, 26),
		dress = true,
		anims = { "rbxassetid://507770677", "rbxassetid://507771019", "rbxassetid://507776043" },
	},
	{
		name = "Mas Kendang",
		role = "kendang",
		at = Vector2.new(-8, -2.5),
		skin = rgb(214, 160, 116),
		shirt = rgb(250, 120, 40),
		pants = rgb(40, 52, 78),
		hair = rgb(30, 26, 26),
		anims = { "rbxassetid://507776043", "rbxassetid://507771019" },
	},
	{
		name = "Bang Gitar",
		role = "gitar",
		at = Vector2.new(8, -1.5),
		skin = rgb(224, 172, 120),
		shirt = rgb(60, 190, 230),
		pants = rgb(245, 245, 240),
		hair = rgb(70, 45, 30),
		anims = { "rbxassetid://507777268", "rbxassetid://507776043" },
	},
	{
		name = "Dewi",
		role = "penari",
		at = Vector2.new(-6, 9.5),
		skin = rgb(224, 172, 120),
		shirt = rgb(255, 120, 190),
		pants = rgb(255, 120, 190),
		hair = rgb(30, 26, 26),
		dress = true,
		anims = DANCE,
	},
	{
		name = "Raka",
		role = "penari",
		at = Vector2.new(6, 9.5),
		skin = rgb(214, 160, 116),
		shirt = rgb(255, 220, 40),
		pants = rgb(60, 90, 160),
		hair = rgb(30, 26, 26),
		anims = DANCE,
	},
	{
		name = "Tika",
		role = "penari",
		at = Vector2.new(-13, 6),
		skin = rgb(240, 190, 140),
		shirt = rgb(170, 120, 240),
		pants = rgb(170, 120, 240),
		hair = rgb(96, 62, 40),
		dress = true,
		anims = DANCE,
	},
	{
		name = "Joni",
		role = "penari",
		at = Vector2.new(13, 6),
		skin = rgb(224, 172, 120),
		shirt = rgb(120, 220, 120),
		pants = rgb(40, 52, 78),
		hair = rgb(30, 26, 26),
		anims = DANCE,
	},
	{
		name = "Mira",
		role = "penari",
		at = Vector2.new(0, 2.5),
		skin = rgb(214, 160, 116),
		shirt = rgb(60, 200, 255),
		pants = rgb(255, 150, 60),
		hair = rgb(30, 26, 26),
		dress = true,
		anims = DANCE,
	},
} :: { Performer })

return table.freeze(ConcertConfig)
