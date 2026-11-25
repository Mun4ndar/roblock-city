--!strict
-- Perkebunan: beli bibit di Pasar Tani, tanam di petak Kebun Warga, tunggu tumbuh,
-- panen, lalu jual hasilnya di pasar. Menambah tanaman = menambah entri di CROPS.
-- Petak kebun bersifat pribadi: setiap pemain punya 8 petak sendiri di tempat yang
-- sama (tanaman pemain lain tidak terlihat), jadi tidak ada rebutan lahan.
-- Modul ini ikut ter-replikasi; harga, waktu tumbuh, dan jarak dicek server.

local FarmConfig = {}

export type CropDef = {
	id: string,
	name: string,
	icon: string,
	seedPrice: number,
	sellPrice: number,
	growSeconds: number,
	color: Color3, -- warna buahnya saat siap panen
	model: string?, -- templat mesh di ReplicatedStorage.Assets.Tanaman (tanpa ini: gambar bola sederhana)
	scale: number?, -- skala mesh saat matang
	yield: number?, -- hasil panen per petak (bawaan 1)
	grid: number?, -- rumpun per sisi di tiap petak (bawaan 3, jagung 2 karena modelnya berat)
}

export type PlotState = { crop: string, plantedAt: number } -- plantedAt: waktu server (detik unix)

-- Keadaan kebun pemain yang dikirim ke client (atribut Player "Farm", JSON).
export type FarmView = {
	plots: { [string]: PlotState },
	seeds: { [string]: number },
	crops: { [string]: number },
}

FarmConfig.PLOT_COUNT = 60 -- petak di Perkebunan Besar (map/BuildPerkebunan)
FarmConfig.MAX_STACK = 99 -- batas bibit / hasil panen per jenis
FarmConfig.MARKET_DISTANCE = 30 -- harus sedekat ini dari kasir pasar untuk beli/jual
FarmConfig.PLOT_DISTANCE = 22 -- harus sedekat ini dari petak untuk tanam/panen

FarmConfig.TAG_PLOT = "FarmPlot" -- part petak kebun (atribut PlotIndex)
FarmConfig.TAG_MARKET = "FarmMarket" -- part kasir pasar
FarmConfig.ATTR_PLOT_INDEX = "PlotIndex"
FarmConfig.ATTR_PLAYER = "Farm"

-- Pekerjaan Petani (JobConfig id) menjual hasil panen sedikit lebih mahal.
FarmConfig.JOB = "petani"
FarmConfig.JOB_SELL_BONUS = 1.25

local rgb = Color3.fromRGB

FarmConfig.CROPS = {
	-- Padi, gandum, dan jagung memakai mesh Creator Store (tanpa skrip); sayur lain dari Food Pack Premium.
	-- Tiap petak menghasilkan `yield` buah.
	{
		id = "padi",
		name = "Padi",
		icon = "🌾",
		seedPrice = 20,
		sellPrice = 30,
		growSeconds = 150,
		color = rgb(230, 200, 90),
		model = "padi",
		scale = 1.7,
		yield = 4,
	},
	{
		id = "gandum",
		name = "Gandum",
		icon = "🌾",
		seedPrice = 25,
		sellPrice = 34,
		growSeconds = 180,
		color = rgb(225, 190, 100),
		model = "gandum",
		scale = 1.1,
		yield = 4,
	},
	{
		id = "jagung",
		name = "Jagung",
		icon = "🌽",
		seedPrice = 35,
		sellPrice = 55,
		growSeconds = 200,
		color = rgb(250, 210, 70),
		model = "jagung",
		scale = 0.55,
		grid = 2,
		yield = 3,
	},
	{
		id = "selada",
		name = "Selada",
		icon = "🥬",
		seedPrice = 15,
		sellPrice = 22,
		growSeconds = 120,
		color = rgb(130, 200, 90),
		model = "selada",
		scale = 4.6,
		yield = 4,
	},
	{
		id = "kubis",
		name = "Kubis (Kol)",
		icon = "🥦",
		seedPrice = 30,
		sellPrice = 40,
		growSeconds = 240,
		color = rgb(120, 190, 100),
		model = "kubis",
		scale = 3.8,
		yield = 4,
	},
	{
		id = "bit",
		name = "Bit Merah",
		icon = "🫒",
		seedPrice = 25,
		sellPrice = 36,
		growSeconds = 200,
		color = rgb(150, 40, 80),
		model = "bit",
		scale = 3.2,
		yield = 4,
	},
	{
		id = "kembangkol",
		name = "Kembang Kol",
		icon = "🥦",
		seedPrice = 50,
		sellPrice = 62,
		growSeconds = 360,
		color = rgb(240, 238, 225),
		model = "kembangkol",
		scale = 3.8,
		yield = 4,
	},
	{
		id = "semangka",
		name = "Semangka",
		icon = "🍉",
		seedPrice = 60,
		sellPrice = 190,
		growSeconds = 320,
		color = rgb(60, 150, 70),
		model = "semangka",
		scale = 3.4,
	},
	{
		id = "labu",
		name = "Labu",
		icon = "🎃",
		seedPrice = 100,
		sellPrice = 330,
		growSeconds = 480,
		color = rgb(240, 150, 40),
		model = "labu",
		scale = 3.4,
	},
} :: { CropDef }

local byId: { [string]: CropDef } = {}
for _, crop in FarmConfig.CROPS do
	byId[crop.id] = crop
end

function FarmConfig.crop(id: any): CropDef?
	return if type(id) == "string" then byId[id] else nil
end

-- 0..1: seberapa matang tanaman di sebuah petak pada waktu `now`.
function FarmConfig.growth(plot: PlotState, now: number): number
	local crop = byId[plot.crop]
	if crop == nil then
		return 0
	end
	return math.clamp((now - plot.plantedAt) / crop.growSeconds, 0, 1)
end

return table.freeze(FarmConfig)
