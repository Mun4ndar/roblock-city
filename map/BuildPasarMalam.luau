--!nocheck
-- BuildPasarMalam: membuat lapak pasar malam di Taman Kota (lahan rumput barat-selatan taman) dan
-- lapak festival kuliner (akhir pekan). Hasil disimpan di ServerStorage.PasarMalam.{Malam,Festival};
-- FoodService memasangnya ke Workspace.Map.PasarMalam hanya saat buka (malam / akhir pekan).
-- Lapak = templat Blender ServerStorage.AsetPasar.lapak (depan = -Z). Aman diulang.
-- Jalankan: require(game.ServerStorage.MapBuilders.BuildPasarMalam)()

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

local AWNINGS = {
	{ rgb(214, 56, 56), rgb(246, 244, 238) },
	{ rgb(50, 110, 210), rgb(246, 244, 238) },
	{ rgb(60, 160, 90), rgb(246, 244, 238) },
	{ rgb(240, 140, 40), rgb(246, 244, 238) },
	{ rgb(150, 70, 190), rgb(250, 220, 80) },
}

-- Skala lapak: templat Blender 5 stud lebar terlalu kecil di samping pemain (tinggi 5,5 stud); x2 = 10 stud lebar, ~8,6 stud tinggi.
local SCALE = 2
-- Tinggi permukaan meja (stud, sudah diskalakan) dan titik berdiri penjual (di belakang meja, lokal lapak).
local TOP = 2.3
local VENDOR_AT = Vector3.new(0, 0.3, 1.7)

-- Deret lapak: x, z, menghadap (0 = ke -Z, 180 = ke +Z), menu (FoodService), nama papan, tampilan dagangan.
local MALAM = {
	{ 636, 108, 180, "bakso", "Bakso Pak Slamet", "bakso" },
	{ 652, 108, 180, "sate", "Sate Madura", "sate" },
	{ 668, 108, 180, "gorengan", "Gorengan Bu Tini", "gorengan" },
	{ 684, 108, 180, "minuman", "Es Cendol Segar", "cendol" },
	{ 700, 108, 180, "martabak", "Martabak Manis", "martabak" },
	{ 636, 136, 0, "jagung", "Jagung Bakar", "jagung" },
	{ 652, 136, 0, "warung", "Nasi Goreng Gerobak", "nasiGoreng" },
	{ 668, 136, 0, "gado", "Gado-gado Bu Sri", "gado" },
	{ 684, 136, 0, "minuman", "Es Campur Segar", "esCampur" },
	{ 700, 136, 0, "martabak", "Kopi & Roti Bakar", "kopi" },
}
local FESTIVAL = {
	{ 735, 138, 0, "sate", "Festival: Sate Lilit", "sate" },
	{ 751, 138, 0, "jagung", "Festival: Kerak Telor", "kerakTelor" },
	{ 767, 138, 0, "bakso", "Festival: Soto & Bakso", "soto" },
	{ 783, 138, 0, "gorengan", "Festival: Jajan Pasar", "jajanPasar" },
	{ 799, 138, 0, "minuman", "Festival: Es Segar", "esKelapa" },
	{ 815, 138, 0, "martabak", "Festival: Martabak", "terangBulan" },
}

-- ---------------------------------------------------------------- dagangan
-- Tiap tampilan = daftar bagian sederhana (balok/silinder/bola) di atas meja, koordinat lokal lapak
-- (x kanan, y dari permukaan meja ke atas, z: depan = -Z). Tanpa tabrakan, tanpa bayangan (hemat HP).
type Add = (
	string,
	number,
	number,
	number,
	number,
	number,
	number,
	Color3,
	Enum.Material?,
	number?
) -> ()

local SP, MT, WD, GL, NE, FB, IC =
	Enum.Material.SmoothPlastic,
	Enum.Material.Metal,
	Enum.Material.Wood,
	Enum.Material.Glass,
	Enum.Material.Neon,
	Enum.Material.Fabric,
	Enum.Material.Ice

local SILVER, WHITE, STEEL = rgb(206, 210, 214), rgb(246, 244, 238), rgb(60, 62, 68)
local CHAR = rgb(40, 38, 40)
local GOLD, BROWN, TAN = rgb(226, 160, 62), rgb(124, 76, 44), rgb(214, 178, 128)

-- add(bentuk, x, y, z, sx, sy, sz, warna, bahan, transparansi)
--   "b" balok (sx,sy,sz) | "o" bola (sx = garis tengah) | "c" silinder berdiri (sx garis tengah, sy tinggi)
--   "cz" silinder rebah searah Z (sx garis tengah, sz panjang) | "cx" silinder rebah searah X (sx, sz panjang)
local LOOKS: { [string]: (Add) -> () } = {}

LOOKS.bakso = function(add)
	add("c", -2.4, 0.9, -1.7, 2.6, 1.8, 2.6, SILVER, MT)
	add("c", -2.4, 1.78, -1.7, 2.3, 0.12, 2.3, rgb(228, 186, 98), SP)
	for i = 1, 7 do
		local a = i * 2.4
		add(
			"o",
			-2.4 + math.cos(a) * 0.7,
			1.9,
			-1.7 + math.sin(a) * 0.7,
			0.55,
			0.55,
			0.55,
			rgb(206, 172, 132),
			SP
		)
	end
	for i = 0, 3 do
		add("c", 0.6, 0.12 + i * 0.26, -2.2, 1.5, 0.24, 1.5, WHITE, SP)
	end
	add("c", 2.2, 0.35, -1.6, 1.7, 0.7, 1.7, rgb(240, 212, 96), SP) -- mi kuning
	add("c", 3.6, 0.55, -1.2, 0.4, 1.1, 0.4, rgb(200, 50, 40), SP) -- saus
	add("c", 4.1, 0.55, -1.2, 0.4, 1.1, 0.4, rgb(90, 150, 60), SP) -- sambal hijau
	add("c", 3.85, 0.45, -2.2, 0.55, 0.9, 0.55, rgb(80, 52, 36), SP) -- kecap
	add("b", 2.4, 0.5, 0.2, 2.2, 0.9, 1.2, SILVER, MT) -- kukusan di rak
end

LOOKS.sate = function(add)
	add("b", -0.8, 0.45, -1.7, 5.2, 0.9, 1.7, CHAR, MT)
	add("b", -0.8, 0.93, -1.7, 4.8, 0.1, 1.3, rgb(255, 104, 38), NE)
	for i = 0, 5 do
		local x = -3 + i * 0.85
		add("cz", x, 1.1, -1.7, 0.1, 0.1, 2.9, TAN, WD)
		add("b", x, 1.15, -2.2, 0.4, 0.4, 0.7, BROWN, SP)
		add("b", x, 1.15, -1.5, 0.4, 0.4, 0.7, rgb(150, 92, 52), SP)
	end
	add("c", 3.2, 0.2, -1.2, 1.4, 0.4, 1.4, WHITE, SP) -- piring sate mentah
	add("b", 3.2, 0.5, -1.2, 1.0, 0.25, 0.8, rgb(232, 170, 160), SP)
	add("c", 3.3, 0.4, -2.5, 1.0, 0.8, 1.0, rgb(150, 100, 60), SP) -- bumbu kacang
	for i = 0, 2 do
		add("cx", 1.6 + i * 0.5, 0.35, 0.3, 0.45, 0.45, 1.3, rgb(210, 220, 180), SP) -- lontong
	end
end

LOOKS.gorengan = function(add)
	add("b", -2.6, 0.35, -1.7, 2.8, 0.7, 2.2, STEEL, MT)
	add("c", -2.6, 0.8, -1.7, 2.6, 0.5, 2.6, CHAR, MT)
	add("c", -2.6, 1.05, -1.7, 2.2, 0.06, 2.2, rgb(240, 190, 70), NE)
	add("b", 1.2, 0.12, -1.8, 3.0, 0.24, 2.0, SILVER, MT)
	local layers = { 4, 3, 2, 1 }
	local k = 0
	for layer, count in layers do
		for i = 1, count do
			k += 1
			add(
				"o",
				1.2 + (i - (count + 1) / 2) * 0.8,
				0.5 + (layer - 1) * 0.5,
				-1.8,
				0.85,
				0.85,
				0.85,
				if k % 2 == 0 then GOLD else rgb(214, 134, 48),
				SP
			)
		end
	end
	for i = 0, 2 do
		add("b", 3.5 + i * 0.12, 0.35, -1.0 - i * 0.3, 0.1, 0.1, 0.7, rgb(200, 40, 36), SP) -- cabai
	end
	add("b", 3.6, 0.4, -2.4, 0.9, 0.8, 0.5, rgb(176, 130, 84), SP) -- bungkus kertas
end

LOOKS.cendol = function(add)
	local fills = { rgb(116, 190, 96), rgb(112, 62, 38), rgb(246, 242, 232) }
	for i = 1, 3 do
		local x = -3.2 + (i - 1) * 2.0
		add("c", x, 1.2, -1.8, 1.7, 2.4, 1.7, rgb(206, 232, 232), GL, 0.5)
		add("c", x, 0.8, -1.8, 1.5, 1.6, 1.5, fills[i], SP)
	end
	for i = 0, 3 do
		add("c", 2.4, 0.1 + i * 0.16, -2.4, 0.9, 0.16, 0.9, rgb(236, 244, 244), GL, 0.35)
	end
	add("c", 3.6, 0.6, -1.0, 0.45, 1.2, 0.45, rgb(210, 50, 70), SP)
	add("c", 4.1, 0.6, -1.0, 0.45, 1.2, 0.45, rgb(90, 170, 80), SP)
	add("b", 2.9, 0.5, -1.3, 1.1, 1.0, 1.1, rgb(220, 240, 252), IC, 0.3)
	add("o", 4.0, 0.55, -2.4, 1.1, 1.1, 1.1, rgb(120, 82, 52), SP) -- kelapa
end

LOOKS.esCampur = function(add)
	add("c", -1.6, 0.5, -1.8, 3.4, 1.0, 3.4, WHITE, SP)
	add("c", -1.6, 1.02, -1.8, 3.0, 0.06, 3.0, rgb(255, 150, 176), SP)
	local fruit = {
		rgb(255, 72, 84),
		rgb(255, 176, 48),
		rgb(122, 202, 84),
		rgb(255, 230, 90),
		rgb(250, 250, 250),
		rgb(180, 90, 200),
	}
	for i = 1, 9 do
		local a = i * 0.7
		local r = 0.95 * (i % 2 + 0.7)
		add(
			"o",
			-1.6 + math.cos(a) * r,
			1.2,
			-1.8 + math.sin(a) * r,
			0.6,
			0.6,
			0.6,
			fruit[(i - 1) % #fruit + 1],
			SP
		)
	end
	for i = 0, 3 do
		add("c", 1.6 + i * 0.85, 0.85, -2.2, 0.8, 1.7, 0.8, rgb(230, 244, 248), GL, 0.5)
		add(
			"c",
			1.6 + i * 0.85,
			0.5,
			-2.2,
			0.7,
			1.0,
			0.7,
			if i % 2 == 0 then rgb(255, 120, 150) else rgb(255, 190, 70),
			SP
		)
	end
	add("b", 3.4, 0.6, -0.8, 1.2, 1.2, 1.2, rgb(216, 238, 252), IC, 0.3)
	add("c", 2.0, 0.55, -0.7, 0.45, 1.1, 0.45, rgb(220, 40, 70), SP)
end

local function martabak(add: Add, batter: Color3, box: Color3)
	add("b", -2.2, 0.35, -1.7, 3.2, 0.7, 3.2, STEEL, MT)
	add("c", -2.2, 0.85, -1.7, 3.5, 0.3, 3.5, CHAR, MT)
	add("c", -2.2, 1.05, -1.7, 3.0, 0.12, 3.0, batter, SP)
	add("c", -2.2, 1.14, -1.7, 1.6, 0.05, 1.6, rgb(120, 70, 40), SP)
	for i = 0, 3 do
		add("b", 2.2, 0.25 + i * 0.5, -1.9, 1.8, 0.5, 1.8, box, SP)
	end
	for i = 0, 2 do
		add("b", 3.6, 0.2, -1.0 - i * 0.7, 0.9, 0.4, 0.6, rgb(196, 128, 62), SP)
	end
	add("c", 0.5, 0.45, -0.7, 0.7, 0.9, 0.7, rgb(60, 110, 200), SP)
end
LOOKS.martabak = function(add)
	martabak(add, rgb(246, 206, 96), rgb(206, 164, 104))
end
LOOKS.terangBulan = function(add)
	martabak(add, rgb(222, 146, 60), rgb(238, 224, 196))
	add("c", 0.6, 0.2, -2.8, 1.0, 0.4, 1.0, rgb(250, 230, 140), SP)
end

LOOKS.jagung = function(add)
	add("b", -1.6, 0.4, -1.7, 4.4, 0.8, 1.6, CHAR, MT)
	add("b", -1.6, 0.85, -1.7, 4.0, 0.1, 1.2, rgb(255, 90, 30), NE)
	for i = 0, 4 do
		add("cz", -3.1 + i * 0.75, 1.15, -1.7, 0.6, 0.6, 2.0, rgb(250, 208, 52), SP)
		add("b", -3.1 + i * 0.75, 1.15, -0.65, 0.5, 0.15, 0.5, rgb(90, 150, 70), FB)
	end
	add("c", 2.8, 0.5, -1.7, 2.2, 1.0, 2.2, rgb(168, 126, 80), WD)
	for i = 0, 3 do
		add(
			"c",
			2.5 + (i % 2) * 0.6,
			1.6,
			-1.8 + (i // 2) * 0.5,
			0.45,
			1.3,
			0.45,
			rgb(100, 160, 70),
			FB
		)
	end
	add("c", 4.1, 0.25, -2.5, 0.8, 0.5, 0.8, rgb(250, 232, 110), SP) -- mentega
end

LOOKS.nasiGoreng = function(add)
	add("b", -2.2, 0.3, -1.6, 3.0, 0.6, 2.6, STEEL, MT)
	add("c", -2.2, 0.8, -1.6, 3.0, 0.45, 3.0, CHAR, MT)
	add("o", -2.2, 1.15, -1.6, 2.2, 0.9, 2.2, rgb(206, 148, 76), SP)
	for i = 0, 2 do
		add("c", 1.4, 0.06 + i * 0.1, -2.2, 1.6, 0.1, 1.6, WHITE, SP)
	end
	add("o", 1.4, 0.55, -2.2, 1.0, 0.6, 1.0, rgb(206, 148, 76), SP)
	add("c", 1.4, 0.78, -2.2, 0.55, 0.06, 0.55, WHITE, SP)
	add("o", 1.4, 0.86, -2.2, 0.22, 0.2, 0.22, rgb(255, 196, 40), SP)
	add("c", 3.0, 0.4, -1.0, 0.5, 0.8, 0.5, rgb(190, 40, 36), SP)
	add("c", 3.6, 0.4, -1.0, 0.5, 0.8, 0.5, rgb(76, 48, 34), SP)
	add("c", 4.2, 0.4, -1.0, 0.5, 0.8, 0.5, rgb(246, 236, 210), SP)
	add("b", 3.4, 0.2, -2.4, 1.6, 0.4, 1.0, rgb(236, 220, 180), SP)
	for i = 0, 3 do
		add("o", 2.9 + i * 0.35, 0.5, -2.4, 0.3, 0.3, 0.3, rgb(250, 240, 210), SP)
	end
end

LOOKS.gado = function(add)
	add("c", -1.8, 0.08, -1.8, 4.2, 0.16, 4.2, rgb(88, 156, 72), FB)
	for i = 1, 5 do
		add("o", -3.0 + i * 0.5, 0.45, -2.6, 0.7, 0.55, 0.7, rgb(112, 178, 80), SP) -- sayur
	end
	for i = 1, 4 do
		add("b", -2.8 + i * 0.5, 0.35, -1.3, 0.55, 0.45, 0.55, rgb(232, 176, 72), SP) -- tahu
	end
	for i = 1, 3 do
		add("o", -2.6 + i * 0.6, 0.35, -0.5, 0.6, 0.6, 0.6, rgb(250, 248, 240), SP) -- telur
		add("o", -2.6 + i * 0.6, 0.5, -0.5, 0.25, 0.2, 0.25, rgb(255, 196, 40), SP)
	end
	add("c", 2.3, 0.45, -1.8, 2.4, 0.9, 2.4, rgb(120, 70, 40), SP) -- bumbu kacang
	add("c", 2.3, 0.92, -1.8, 2.0, 0.08, 2.0, rgb(150, 96, 56), SP)
	for i = 0, 3 do
		add("c", 3.9, 0.05 + i * 0.1, -0.6, 1.5, 0.1, 1.5, rgb(250, 190, 170), SP) -- kerupuk
	end
	add("b", 3.8, 0.5, -2.8, 1.3, 1.0, 0.5, rgb(236, 226, 190), SP)
end

LOOKS.kopi = function(add)
	add("c", -3.2, 1.0, -1.6, 1.4, 2.0, 1.4, SILVER, MT)
	add("b", -2.4, 1.5, -1.6, 0.7, 0.2, 0.2, SILVER, MT)
	for i = 0, 3 do
		add("c", -1.2 + i * 0.8, 0.28, -2.4, 0.65, 0.55, 0.65, WHITE, SP)
		add("c", -1.2 + i * 0.8, 0.56, -2.4, 0.55, 0.04, 0.55, rgb(100, 60, 36), SP)
	end
	for i = 0, 2 do
		add("b", 1.6, 0.3 + i * 0.6, -1.6, 1.8, 0.6, 1.2, rgb(238, 212, 160), SP)
	end
	add("b", 3.4, 0.25, -1.6, 1.6, 0.5, 1.4, STEEL, MT)
	for i = 0, 2 do
		add("b", 3.4 + (i - 1) * 0.4, 0.75, -1.6, 0.3, 0.5, 1.0, rgb(196, 130, 60), SP)
	end
	add("c", 0.4, 0.5, -1.0, 0.7, 1.0, 0.7, rgb(60, 110, 200), SP)
	add("c", 4.2, 0.4, -2.6, 0.7, 0.8, 0.7, rgb(206, 232, 232), GL, 0.45)
end

LOOKS.kerakTelor = function(add)
	add("c", -2.4, 0.45, -1.7, 1.8, 0.9, 1.8, rgb(170, 90, 56), SP)
	add("c", -2.4, 0.92, -1.7, 1.5, 0.08, 1.5, rgb(255, 100, 40), NE)
	add("c", -2.4, 1.1, -1.7, 2.0, 0.14, 2.0, CHAR, MT)
	add("c", -2.4, 1.2, -1.7, 1.7, 0.08, 1.7, rgb(236, 196, 86), SP)
	for i = 0, 3 do
		add("o", 0.0 + i * 0.5, 0.25, -2.3 + (i % 2) * 0.4, 0.5, 0.5, 0.5, rgb(190, 214, 200), SP)
	end
	add("c", 2.6, 0.4, -1.5, 1.8, 0.8, 1.8, rgb(190, 150, 94), WD)
	add("c", 2.6, 0.84, -1.5, 1.4, 0.1, 1.4, WHITE, SP)
	add("c", 4.0, 0.3, -2.4, 0.9, 0.6, 0.9, rgb(222, 112, 60), SP)
	add("c", 1.0, 0.1, -0.7, 1.4, 0.2, 1.4, WHITE, SP)
	add("c", 1.0, 0.24, -0.7, 1.2, 0.1, 1.2, rgb(218, 168, 70), SP)
end

LOOKS.soto = function(add)
	add("c", -2.0, 1.1, -1.7, 3.0, 2.2, 3.0, rgb(244, 242, 236), SP)
	add("c", -2.0, 2.25, -1.7, 3.1, 0.15, 3.1, rgb(60, 110, 190), SP)
	add("c", -2.0, 2.15, -1.7, 2.7, 0.06, 2.7, rgb(236, 200, 72), SP)
	for i = 0, 3 do
		add("c", 1.6, 0.12 + i * 0.26, -2.2, 1.4, 0.24, 1.4, WHITE, SP)
	end
	for i = 0, 4 do
		add(
			"o",
			3.0 + (i % 3) * 0.5,
			0.25,
			-1.0 - (i // 3) * 0.5,
			0.5,
			0.5,
			0.5,
			rgb(130, 200, 70),
			SP
		)
	end
	add("c", 3.4, 0.55, -2.4, 1.2, 1.1, 1.2, rgb(240, 226, 190), SP)
	add("c", 0.4, 0.4, -0.6, 0.6, 0.8, 0.6, rgb(200, 50, 40), SP)
	add("b", 4.0, 0.5, -0.3, 0.9, 1.0, 0.3, rgb(236, 180, 190), SP)
end

LOOKS.jajanPasar = function(add)
	for t = 1, 3 do
		add(
			"c",
			-3.0 + (t - 1) * 3.0,
			0.08 + (t % 2) * 0.12,
			-1.8,
			2.6,
			0.16,
			2.6,
			rgb(204, 168, 104),
			WD
		)
	end
	local colors = {
		rgb(120, 200, 90),
		rgb(255, 130, 170),
		rgb(250, 240, 220),
		rgb(160, 90, 50),
		rgb(255, 200, 60),
		rgb(240, 90, 80),
	}
	local k = 0
	for t = 1, 3 do
		for i = 0, 3 do
			k += 1
			local a = i * 1.57 + t
			add(
				"o",
				-3.0 + (t - 1) * 3.0 + math.cos(a) * 0.6,
				0.4 + (t % 2) * 0.12,
				-1.8 + math.sin(a) * 0.6,
				0.55,
				0.45,
				0.55,
				colors[k % #colors + 1],
				SP
			)
		end
	end
	add("b", 3.9, 0.3, -0.5, 1.0, 0.6, 1.0, rgb(250, 226, 180), SP)
end

LOOKS.esKelapa = function(add)
	for i = 0, 5 do
		add(
			"o",
			-3.6 + (i % 3) * 1.1,
			0.55 + (i // 3) * 0.9,
			-1.8,
			1.1,
			1.1,
			1.1,
			rgb(168, 202, 118),
			SP
		)
	end
	add("cz", -3.0, 2.2, -1.9, 0.07, 0.07, 1.4, rgb(230, 60, 70), SP) -- sedotan
	add("b", 0.8, 0.8, -1.7, 3.0, 1.6, 1.8, rgb(66, 140, 206), SP)
	add("b", 0.8, 1.62, -1.7, 2.6, 0.08, 1.4, rgb(230, 244, 252), IC, 0.2)
	add("b", 3.4, 0.6, -2.2, 0.5, 0.15, 1.4, SILVER, MT)
	add("c", 3.9, 0.4, -1.0, 0.8, 0.8, 0.8, rgb(250, 250, 244), SP)
	add("c", 3.4, 0.5, -0.8, 0.5, 1.0, 0.5, rgb(255, 200, 40), SP)
end

local function addGoods(model: Model, look: string)
	local build = LOOKS[look]
	if build == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Dagangan"
	folder.Parent = model
	local base = model:GetPivot()
	local add: Add = function(shape, x, y, z, sx, sy, sz, color, material, transparency)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Color = color
		part.Material = material or SP
		part.Transparency = transparency or 0
		local pos = base * CFrame.new(x, TOP + y, z)
		if shape == "o" then
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(sx, sy, sz)
			part.CFrame = pos
		elseif shape == "b" then
			part.Size = Vector3.new(sx, sy, sz)
			part.CFrame = pos
		else
			part.Shape = Enum.PartType.Cylinder
			if shape == "c" then
				part.Size = Vector3.new(sy, sx, sx)
				part.CFrame = pos * CFrame.Angles(0, 0, math.rad(90))
			elseif shape == "cz" then
				part.Size = Vector3.new(sz, sx, sx)
				part.CFrame = pos * CFrame.Angles(0, math.rad(90), 0)
			else -- "cx"
				part.Size = Vector3.new(sz, sx, sx)
				part.CFrame = pos
			end
		end
		part.Parent = folder
	end
	build(add)
end

local function groundY(x: number, z: number): number
	local r = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0))
	return if r then r.Position.Y else 0
end

-- Ada pohon/benda lain di tempat lapak? (Terrain diabaikan.)
local function blocked(cf: CFrame): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ServerStorage }
	local parts = Workspace:GetPartBoundsInBox(
		cf * CFrame.new(0, 6, 0),
		Vector3.new(6.5 * SCALE, 12, 5 * SCALE),
		params
	)
	for _, p in parts do
		if not p:IsA("Terrain") and p.CanCollide and p.Name ~= "Baseplate" and p.Size.Y >= 0.6 then
			return true
		end
	end
	return false
end

local function faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -2
	for _, face in Enum.NormalId:GetEnumItems() do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
		local dot = normal:Dot(direction)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

local function sign(papan: BasePart, text: string, front: Vector3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = faceToward(papan, front)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = papan
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = rgb(255, 245, 210)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
end

local function place(parent: Instance, tpl: Model, spec: { any }, index: number): (Model?, string?)
	local x, z, face, menu, name, look = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
	local y = groundY(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(face), 0)
	if blocked(cf) then
		return nil, `{name} ({x},{z}) terhalang`
	end
	local model = tpl:Clone()
	model.Name = "Lapak" .. index
	model:ScaleTo(SCALE)
	model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(face), 0))
	local pair = AWNINGS[(index - 1) % #AWNINGS + 1]
	model.TendaA.Color = pair[1]
	model.TendaB.Color = pair[2]
	sign(model.Papan, name, model:GetPivot().LookVector)
	-- Panci bawaan templat sama di semua lapak: disembunyikan, diganti dagangan khas tiap lapak.
	model.Besi.Transparency = 1
	model.Besi.CanCollide = false
	model:SetAttribute("Look", look)
	model:SetAttribute("Menu", menu)
	model:SetAttribute("StallName", name)
	addGoods(model, look)
	local spot = Instance.new("Part")
	spot.Name = "TitikPenjual"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = model:GetPivot() * CFrame.new(VENDOR_AT)
	spot.Parent = model
	local main = model.Kayu
	main:SetAttribute("StallMenu", menu)
	main:SetAttribute("StallName", name)
	CollectionService:AddTag(main, "FoodStall")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = parent
	return model, nil
end

local function bulbPole(parent: Instance, x: number, z: number)
	local y = groundY(x, z)
	local pole = Instance.new("Part")
	pole.Name = "TiangLampu"
	pole.Anchored = true
	pole.Size = Vector3.new(0.5, 11, 0.5)
	pole.Position = Vector3.new(x, y + 5.5, z)
	pole.Color = rgb(70, 60, 55)
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CastShadow = false
	pole.Parent = parent
	local light = Instance.new("PointLight")
	light.Brightness = 0.7
	light.Range = 34
	light.Color = rgb(255, 214, 150)
	light.Parent = pole
	return pole
end

return function()
	local tpl = ServerStorage.AsetPasar.lapak
	local root = ServerStorage:FindFirstChild("PasarMalam")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "PasarMalam"
	local malam = Instance.new("Folder")
	malam.Name = "Malam"
	malam.Parent = root
	local festival = Instance.new("Folder")
	festival.Name = "Festival"
	festival.Parent = root
	local log = {}
	for i, spec in MALAM do
		local m, why = place(malam, tpl, spec, i)
		if not m then
			table.insert(log, why)
		end
	end
	for i, spec in FESTIVAL do
		local m, why = place(festival, tpl, spec, 100 + i)
		if not m then
			table.insert(log, why)
		end
	end
	-- Tiang lampu di tengah lorong + speaker musik (Sound dipasang FoodService).
	for _, x in { 628, 668, 708 } do
		bulbPole(malam, x, 122)
	end
	-- Untai bohlam antar tiang (Neon, tanpa tabrakan).
	for index = 1, 2 do
		local xa, xb = 628 + (index - 1) * 40, 668 + (index - 1) * 40
		local y = groundY(xa, 122) + 10.5
		for k = 0, 10 do
			local t = k / 10
			local sag = math.sin(t * math.pi) * 1.4
			local bulb = Instance.new("Part")
			bulb.Name = "Bohlam"
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.new(0.7, 0.7, 0.7)
			bulb.Position = Vector3.new(xa + (xb - xa) * t, y - sag, 122)
			bulb.Anchored = true
			bulb.CanCollide = false
			bulb.CastShadow = false
			bulb.Material = Enum.Material.Neon
			bulb.Color = ({
				rgb(255, 226, 140),
				rgb(255, 120, 120),
				rgb(140, 220, 255),
				rgb(170, 255, 170),
			})[k % 4 + 1]
			bulb.Parent = malam
		end
	end
	local speaker = Instance.new("Part")
	speaker.Name = "SpeakerPasar"
	speaker.Anchored = true
	speaker.Size = Vector3.new(1.4, 2.2, 1.2)
	speaker.Position = Vector3.new(668, groundY(668, 122) + 1.1, 122)
	speaker.Color = rgb(35, 35, 40)
	speaker.Material = Enum.Material.SmoothPlastic
	speaker.Parent = malam
	root.Parent = ServerStorage
	return log
end
