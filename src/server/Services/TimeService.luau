--!strict
-- TimeService: jam dunia. Server satu-satunya yang menentukan jam; client
-- hanya menghaluskan gerak matahari di antara pembaruan server.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))

local TimeService = {}

local TICK_SECONDS = 2

local clock = DayNightConfig.START_CLOCK

function TimeService.getClock(): number
	return clock
end

function TimeService.isNight(): boolean
	return DayNightConfig.nightFactor(clock) >= DayNightConfig.LIGHTS_ON_AT
end

-- Untuk pengujian di Studio (tidak ada remote yang memanggil ini).
function TimeService.setClock(value: number)
	clock = value % 24
	Lighting.ClockTime = clock
	Workspace:SetAttribute(DayNightConfig.ATTR_NIGHT, TimeService.isNight())
end

function TimeService.init()
	TimeService.setClock(DayNightConfig.START_CLOCK)
end

function TimeService.start()
	while true do
		local dt = task.wait(TICK_SECONDS)
		-- Jam bisa diubah dari luar (uji coba di Studio): ikuti nilai Lighting.
		if math.abs(Lighting.ClockTime - clock) > 0.25 then
			clock = Lighting.ClockTime
		end
		TimeService.setClock(clock + DayNightConfig.hoursPerSecond(clock) * dt)
	end
end

return TimeService
