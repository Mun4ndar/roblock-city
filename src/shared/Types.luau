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

export type DailyRewardResult = {
	ok: boolean,
	message: string,
	secondsLeft: number?,
}

return nil
