--!strict
-- RadioService: radio mobil. Pengemudi memilih stasiun (koplo, dangdut, campursari, gamelan) lewat
-- remote RadioSet; musik jadi Sound 3D di sasis kendaraan supaya orang di sekitar ikut mendengar.
-- Lagu = audio berlisensi gratis dari perpustakaan Roblox (lihat IndonesiaConfig.STATIONS).
-- Radio mati sendiri kalau kursi pengemudi kosong lebih dari 12 detik.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))

local RadioService = {}

local EMPTY_SECONDS = 12
local CALL_COOLDOWN = 0.5
local lastCall: { [Player]: number } = {}

local function vehicleOf(player: Player): (Model?, VehicleSeat?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if seat == nil or not seat:IsA("VehicleSeat") then
		return nil, nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("VehicleId") == nil do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model, seat
end

local function stop(model: Model)
	model:SetAttribute(IndonesiaConfig.ATTR_RADIO, "")
	local chassis = model:FindFirstChild("Chassis")
	local old = if chassis then chassis:FindFirstChild("RadioSound") else nil
	if old then
		old:Destroy()
	end
end

local function play(model: Model, seat: VehicleSeat, station: IndonesiaConfig.Station)
	stop(model)
	local anchor: BasePart = seat
	local chassis = model:FindFirstChild("Chassis")
	if chassis and chassis:IsA("BasePart") then
		anchor = chassis
	end
	local sound = Instance.new("Sound")
	sound.Name = "RadioSound"
	sound.Volume = IndonesiaConfig.RADIO_VOLUME
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = IndonesiaConfig.RADIO_MAX_DISTANCE
	sound.Parent = anchor
	model:SetAttribute(IndonesiaConfig.ATTR_RADIO, station.id)
	task.spawn(function()
		local index = math.random(#station.tracks) - 1
		local emptySince: number? = nil
		while
			sound.Parent ~= nil
			and model.Parent ~= nil
			and model:GetAttribute(IndonesiaConfig.ATTR_RADIO) == station.id
		do
			index = index % #station.tracks + 1
			sound.SoundId = "rbxassetid://" .. station.tracks[index]
			sound:Play()
			local started = os.clock()
			repeat
				task.wait(1)
				if seat.Occupant == nil then
					emptySince = emptySince or os.clock()
				else
					emptySince = nil
				end
				if emptySince and os.clock() - emptySince > EMPTY_SECONDS then
					if model.Parent then
						stop(model)
					end
					return
				end
			until sound.Parent == nil
				or (not sound.IsPlaying and os.clock() - started > 3)
				or model:GetAttribute(IndonesiaConfig.ATTR_RADIO) ~= station.id
		end
	end)
end

local function setStation(player: Player, stationId: any): { ok: boolean, message: string }
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return { ok = false, message = "" }
	end
	lastCall[player] = now
	local model, seat = vehicleOf(player)
	if model == nil or seat == nil then
		return { ok = false, message = "Radio hanya bisa dinyalakan pengemudi." }
	end
	if stationId == "" then
		stop(model)
		return { ok = true, message = "📻 Radio dimatikan." }
	end
	local station = IndonesiaConfig.station(stationId)
	if station == nil then
		return { ok = false, message = "Stasiun tidak dikenal." }
	end
	play(model, seat, station)
	return { ok = true, message = `{station.icon} {station.name}` }
end

function RadioService.init()
	Net.func("RadioSet").OnServerInvoke = function(player: Player, stationId: any): any
		local ok, value = pcall(setStation, player, stationId)
		if ok then
			return value
		end
		warn("[Radio] error: " .. tostring(value))
		return { ok = false, message = "Radio bermasalah." }
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
end

return RadioService
