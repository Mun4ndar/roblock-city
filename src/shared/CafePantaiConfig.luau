--!strict
-- Kafe Pantai (lihat CafePantaiService): jam buka, daftar musik, dan lantai dansa. Semua angka di sini.
-- Musik hanya dari perpustakaan audio resmi Roblox (APM Music, gratis dipakai di game Roblox).

local CafePantaiConfig = {}

-- Pusat lantai dansa (dunia). Diisi sesuai letak model kafe di pantai.
CafePantaiConfig.DANCE_CENTER = Vector3.new(1660, 0.6, -300)
CafePantaiConfig.DANCE_RADIUS = 5
CafePantaiConfig.DANCERS = 4

-- Kafe buka pada jam permainan (Lighting.ClockTime) dari OPEN_FROM sampai OPEN_TO.
CafePantaiConfig.OPEN_FROM = 8
CafePantaiConfig.OPEN_TO = 21

-- Musik kafe (EDM/house instrumental, APM Music): diputar bergantian dan berulang selama kafe buka,
-- terdengar hanya di sekitar kafe.
CafePantaiConfig.PLAYLIST = table.freeze({
	{ id = 1840081722, name = "Dance Baby Dance" }, -- funky electro house, 6 menit
	{ id = 1840082532, name = "Glamour" }, -- stylish dance groove, 6 menit
	{ id = 1835751459, name = "Casino Luck" }, -- energetic house groove
	{ id = 1841590283, name = "Friday Night Fever" },
})
CafePantaiConfig.VOLUME = 0.55
CafePantaiConfig.HEAR_MIN = 25 -- studs dari pusat: suara penuh
CafePantaiConfig.HEAR_MAX = 110 -- studs dari pusat: suara habis

-- Animasi dansa resmi Roblox (emote bawaan R15).
CafePantaiConfig.DANCE_ANIMATIONS = table.freeze({
	"rbxassetid://507771019",
	"rbxassetid://507776043",
	"rbxassetid://507777268",
})

return table.freeze(CafePantaiConfig)
