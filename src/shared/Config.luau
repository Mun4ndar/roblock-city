--!strict
-- Nilai gameplay yang bisa diatur. CATATAN: modul ini ikut ter-replikasi ke
-- client, jadi jangan taruh rahasia di sini. Server tidak pernah mempercayai
-- nilai dari client.

local Config = {
	-- Data pemain
	DATASTORE_NAME = "PlayerData_v1",
	SCHEMA_VERSION = 1,
	AUTOSAVE_INTERVAL = 60, -- detik
	SESSION_LOCK_EXPIRY = 600, -- detik; lock dianggap basi setelah ini (server crash)
	LOAD_RETRIES = 5,
	SAVE_RETRIES = 4,

	-- Ekonomi
	STARTING_MONEY = 500,
	MAX_MONEY = 1_000_000_000,
	CURRENCY_SYMBOL = "$",
	DAILY_REWARD_AMOUNT = 250,
	DAILY_REWARD_COOLDOWN = 20 * 60 * 60, -- 20 jam

	-- Jaringan
	REMOTE_RATE_LIMIT_SECONDS = 1, -- minimal jeda antar panggilan remote per pemain
}

return table.freeze(Config)
