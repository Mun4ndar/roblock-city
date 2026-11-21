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
}

export type DailyRewardResult = {
	ok: boolean,
	message: string,
	secondsLeft: number?,
}

return nil
