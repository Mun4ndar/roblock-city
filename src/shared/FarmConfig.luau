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
}

export type PlotState = { crop: string, plantedAt: number } -- plantedAt: waktu server (detik unix)

-- Keadaan kebun pemain yang dikirim ke client (atribut Player "Farm", JSON).
export type FarmView = {
	plots: { [string]: PlotState },
	seeds: { [string]: number },
	crops: { [string]: number },
}

FarmConfig.PLOT_COUNT = 8
FarmConfig.MAX_STACK = 99 -- batas bibit / hasil panen per jenis
FarmConfig.MARKET_DISTANCE = 30 -- harus sedekat ini dari kasir pasar untuk beli/jual
FarmConfig.PLOT_DISTANCE = 22 -- harus sedekat ini dari petak untuk tanam/panen

FarmConfig.TAG_PLOT = "FarmPlot" -- part petak kebun (atribut PlotIndex)
FarmConfig.TAG_MARKET = "FarmMarket" -- part kasir pasar
FarmConfig.ATTR_PLOT_INDEX = "PlotIndex"
FarmConfig.ATTR_PLAYER = "Farm"

local rgb = Color3.fromRGB

FarmConfig.CROPS = {
	{
		id = "wortel",
		name = "Wortel",
		icon = "🥕",
		seedPrice = 10,
		sellPrice = 28,
		growSeconds = 60,
		color = rgb(245, 130, 40),
	},
	{
		id = "tomat",
		name = "Tomat",
		icon = "🍅",
		seedPrice = 20,
		sellPrice = 58,
		growSeconds = 120,
		color = rgb(225, 55, 45),
	},
	{
		id = "jagung",
		name = "Jagung",
		icon = "🌽",
		seedPrice = 35,
		sellPrice = 105,
		growSeconds = 200,
		color = rgb(250, 210, 70),
	},
	{
		id = "semangka",
		name = "Semangka",
		icon = "🍉",
		seedPrice = 60,
		sellPrice = 190,
		growSeconds = 320,
		color = rgb(60, 150, 70),
	},
	{
		id = "labu",
		name = "Labu",
		icon = "🎃",
		seedPrice = 100,
		sellPrice = 330,
		growSeconds = 480,
		color = rgb(240, 150, 40),
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
