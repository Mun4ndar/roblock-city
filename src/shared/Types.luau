--!strict
-- Definisi tipe bersama. Tipe yang melewati batas client/server
-- (payload remote, skema profil) ada di sini supaya kedua sisi sepakat.

export type PlayerData = {
	version: number,
	money: number,
	lastDailyReward: number, -- os.time() saat terakhir klaim, 0 = belum pernah
	stats: {
		totalEarned: number,
		joins: number,
	},
	-- Kendaraan yang dimiliki: id (lihat VehicleConfig) -> catatan kepemilikan.
	vehicles: { [string]: OwnedVehicle },
	-- Pekerjaan: yang sedang dijalani + kemajuan tiap pekerjaan (lihat JobConfig).
	jobs: JobData,
	-- Rumah yang dimiliki (lihat HouseConfig). id 0 = belum punya.
	house: HouseData,
	-- Misi harian (lihat MissionConfig).
	missions: MissionData,
	-- Kebun pemain (lihat FarmConfig).
	farm: FarmData,
	-- ID pembelian Robux yang sudah diberikan (lihat ShopService), supaya tidak dobel.
	receipts: { string },
	-- Hewan peliharaan (lihat PetConfig).
	pets: PetData,
	-- Setelan dari Toko Baju (lihat FashionConfig).
	fashion: FashionData,
	-- Usaha Kafe (lihat BusinessConfig).
	business: BusinessData,
}

export type BusinessData = {
	level: number, -- 0 = belum punya kafe
	stored: number, -- uang di laci kasir yang belum diambil
}

export type FashionData = {
	owned: { [string]: boolean },
	active: string, -- id setelan yang dipakai, "" = tidak ada
}

export type PetData = {
	owned: { [string]: boolean },
	active: string, -- id hewan yang diajak, "" = tidak ada
	fedAt: number, -- waktu server terakhir diberi makan
}

export type FarmData = {
	plots: { [string]: { crop: string, plantedAt: number } }, -- nomor petak (teks) -> tanaman
	seeds: { [string]: number }, -- id tanaman -> jumlah bibit
	crops: { [string]: number }, -- id tanaman -> jumlah hasil panen
}

export type MissionData = {
	day: number, -- nomor hari saat kemajuan ini dicatat; hari berganti = mulai dari nol
	progress: { [string]: number },
	claimed: { [string]: boolean },
}

export type HouseData = {
	id: number, -- nomor rumah di peta, 0 = belum punya
	tier: string,
	boughtAt: number,
	paint: { [string]: number }, -- bagian (wall/roof/door) -> indeks warna, 0/nil = asli
	items: { [string]: string }, -- nomor slot halaman (teks) -> id hiasan
}

export type JobData = {
	current: string, -- id pekerjaan aktif, "" = tidak bekerja
	stats: { [string]: JobProgress },
}

export type JobProgress = {
	tasks: number, -- jumlah tugas selesai
	earned: number, -- total gaji dari pekerjaan ini
}

export type OwnedVehicle = {
	boughtAt: number, -- os.time() saat dibeli
	paint: number?, -- indeks VehicleConfig.PAINTS; nil/0 = warna asli
	rim: number?, -- indeks VehicleConfig.RIMS; nil/0 = velg asli
}

-- Balasan semua remote kendaraan.
export type VehicleResult = {
	ok: boolean,
	message: string,
}

-- Balasan semua remote rumah.
export type HouseResult = {
	ok: boolean,
	message: string,
}

-- Balasan semua remote pekerjaan.
export type JobResult = {
	ok: boolean,
	message: string,
}

export type DailyRewardResult = {
	ok: boolean,
	message: string,
	secondsLeft: number?,
}

return nil
