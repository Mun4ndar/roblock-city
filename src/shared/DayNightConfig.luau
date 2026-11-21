--!strict
-- Siklus siang/malam. Server memajukan jam (Lighting.ClockTime); client
-- mengurus tampilan (warna langit malam, lampu jalan, jendela menyala).
-- Semua angka yang bisa diatur ada di sini.

local DayNightConfig = {}

DayNightConfig.START_CLOCK = 8 -- jam saat server mulai
DayNightConfig.SUNRISE = 6
DayNightConfig.SUNSET = 18
DayNightConfig.DAY_MINUTES = 16 -- lama siang (06-18) dalam menit nyata
DayNightConfig.NIGHT_MINUTES = 6 -- lama malam (18-06) dalam menit nyata

-- Peralihan: malam penuh di luar rentang ini, siang penuh di antaranya.
DayNightConfig.DAWN = { from = 5, to = 6.75 }
DayNightConfig.DUSK = { from = 17.5, to = 19 }

-- Lampu menyala saat faktor malam melewati ambang ini.
DayNightConfig.LIGHTS_ON_AT = 0.4

-- Tag CollectionService, dipasang oleh map/StyleWorld.luau ("lights").
DayNightConfig.TAG_LIGHT = "NightLight" -- part berisi Light: menyala saat malam
DayNightConfig.TAG_WINDOW = "NightWindow" -- jendela: sebagian menyala saat malam
DayNightConfig.WINDOW_LIT_PERCENT = 65

-- Atribut Workspace yang diisi server, untuk sistem lain (mis. misi malam).
DayNightConfig.ATTR_NIGHT = "IsNight"

-- 0 = siang penuh, 1 = malam penuh.
function DayNightConfig.nightFactor(clock: number): number
	local dawn, dusk = DayNightConfig.DAWN, DayNightConfig.DUSK
	if clock >= dawn.to and clock <= dusk.from then
		return 0
	elseif clock < dawn.from or clock > dusk.to then
		return 1
	elseif clock < dawn.to then
		return 1 - (clock - dawn.from) / (dawn.to - dawn.from)
	end
	return (clock - dusk.from) / (dusk.to - dusk.from)
end

-- Kecepatan jam (jam permainan per detik nyata) pada jam tertentu.
function DayNightConfig.hoursPerSecond(clock: number): number
	local isDay = clock >= DayNightConfig.SUNRISE and clock < DayNightConfig.SUNSET
	local minutes = if isDay then DayNightConfig.DAY_MINUTES else DayNightConfig.NIGHT_MINUTES
	return 12 / (minutes * 60)
end

function DayNightConfig.formatClock(clock: number): string
	local hours = math.floor(clock) % 24
	local minutes = math.floor((clock - math.floor(clock)) * 60)
	return string.format("%02d:%02d", hours, minutes)
end

return table.freeze(DayNightConfig)
