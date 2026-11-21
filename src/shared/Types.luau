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
	-- modifikasi (cat, velg, dll.) ditambahkan di sini nanti
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
