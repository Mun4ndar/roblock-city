--!strict
-- Utilitas format murni (tanpa side effect), aman dipakai client & server.

local Config = require(script.Parent.Config)

local Format = {}

-- 1234567 -> "$1.234.567"
function Format.money(amount: number): string
	local whole = tostring(math.floor(math.abs(amount)))
	local withDots = whole:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if withDots:sub(1, 1) == "." then
		withDots = withDots:sub(2)
	end
	local sign = if amount < 0 then "-" else ""
	return sign .. Config.CURRENCY_SYMBOL .. withDots
end

-- 3725 -> "1j 2m"
function Format.duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	if h > 0 then
		return string.format("%dj %dm", h, m)
	end
	return string.format("%dm %dd", m, s % 60)
end

return Format
