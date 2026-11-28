--!strict
-- OnboardingConfig: panduan pemain baru.
--   * Misi Pemula 3 langkah (pilih pekerjaan -> selesaikan 1 tugas -> belanja / naik kendaraan)
--   * bonus main 10 menit (penghitung waktu di layar)
--   * teleport cepat dari HP ke beberapa tempat seru
-- Modul ikut ter-replikasi; server (OnboardingService) yang menghitung langkah, waktu, dan hadiah.
-- Mengubah hadiah / tempat = ubah angka di sini saja.

local HttpService = game:GetService("HttpService")

local OnboardingConfig = {}

export type StepDef = {
	icon: string,
	title: string,
	hint: string,
	reward: number, -- koin saat langkah selesai
}

export type Spot = {
	id: string,
	icon: string,
	name: string,
	note: string,
	position: Vector3, -- titik berdiri (permukaan tanah)
}

-- Keadaan yang dikirim ke client (atribut Player "Onboarding", JSON).
export type View = {
	step: number, -- jumlah langkah Misi Pemula yang sudah selesai (0..3)
	done: boolean,
	bonusLeft: number, -- sisa detik menuju bonus main (saat atribut dikirim)
	bonusClaimed: boolean,
}

OnboardingConfig.ATTR = "Onboarding"

OnboardingConfig.STEPS = {
	{
		icon = "💼",
		title = "Ambil pekerjaan pertamamu",
		hint = "Tekan tombol Pekerjaan di kiri, lalu tekan Mulai.",
		reward = 100,
	},
	{
		icon = "⭐",
		title = "Selesaikan 1 tugas",
		hint = "Ikuti panah biru di jalan sampai penanda kuning.",
		reward = 150,
	},
	{
		icon = "🛒",
		title = "Belanja atau naik kendaraan",
		hint = "Beli sesuatu di toko, atau naik kendaraan mana saja.",
		reward = 250,
	},
} :: { StepDef }

-- Hadiah akhir Misi Pemula: setelan gratis (lihat FashionConfig.OUTFITS).
OnboardingConfig.FINAL_OUTFIT = "jaket_warga_baru"

-- Tujuan GPS langkah 3 (id di DestinationConfig); yang terdekat dari pemain yang dipakai.
OnboardingConfig.SHOP_TARGETS = { "toko", "indomart", "dealer" }

-- Bonus main: pemain yang bertahan sekian detik mendapat koin. Dihitung server, tersimpan,
-- jadi keluar-masuk tidak mengulang hitungan. DAILY = true: bisa didapat lagi setiap hari.
OnboardingConfig.PLAY_BONUS_SECONDS = 600
OnboardingConfig.PLAY_BONUS_AMOUNT = 500
OnboardingConfig.PLAY_BONUS_DAILY = true

OnboardingConfig.TELEPORT_COOLDOWN = 20 -- detik antar teleport cepat

OnboardingConfig.SPOTS = {
	{ id = "pasarMalam", icon = "🏮", name = "Pasar Malam", note = "Jajan dan wahana, ramai saat sore", position = Vector3.new(668, 0, 122) },
	{ id = "pantai", icon = "🏖️", name = "Pantai", note = "Jet ski, voli, dan kafe pantai", position = Vector3.new(1580, 0, -170) },
	{ id = "bandara", icon = "✈️", name = "Bandara", note = "Lihat pesawat lepas landas", position = Vector3.new(-975, 0, 400) },
	{ id = "mall", icon = "🛍️", name = "ROBLOCK Mall", note = "Pusat kota dan toko costume", position = Vector3.new(525, 1, -470) },
	{ id = "perkemahan", icon = "⛺", name = "Perkemahan", note = "Api unggun dan air terjun", position = Vector3.new(-865, 18, -420) },
} :: { Spot }

function OnboardingConfig.spot(id: any): Spot?
	if type(id) ~= "string" then
		return nil
	end
	for _, spot in OnboardingConfig.SPOTS do
		if spot.id == id then
			return spot
		end
	end
	return nil
end

-- Membaca keadaan dari atribut Player. nil = server belum mengirimnya.
function OnboardingConfig.read(player: Player): View?
	local raw = player:GetAttribute(OnboardingConfig.ATTR)
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(decoded) == "table" and type(decoded.step) == "number" then
		return decoded :: any
	end
	return nil
end

return OnboardingConfig
