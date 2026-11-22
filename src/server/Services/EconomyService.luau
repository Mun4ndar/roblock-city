--!strict
-- EconomyService: satu-satunya tempat uang pemain berubah.
--   * server-authoritative: client tidak pernah mengirim jumlah uang
--   * semua jumlah divalidasi (bilangan bulat, positif, terbatas)
--   * saldo direplikasi ke client lewat atribut Player "Money" (read-only bagi client)
--   * remote ClaimDailyReward: rate limit + cooldown dicek di server

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))

type DailyRewardResult = Types.DailyRewardResult

local EconomyService = {}

local MONEY_ATTRIBUTE = "Money"

local lastRemoteCall: { [Player]: number } = {}
local notifyRemote: RemoteEvent

-- ---------------------------------------------------------------- util

local function isValidAmount(amount: any): boolean
	return type(amount) == "number"
		and amount == amount -- bukan NaN
		and amount > 0
		and amount <= Config.MAX_MONEY
		and math.floor(amount) == amount
end

local function publish(player: Player, money: number)
	player:SetAttribute(MONEY_ATTRIBUTE, money)
end

-- Rate limit sederhana per pemain untuk semua remote ekonomi.
local function allowCall(player: Player): boolean
	local now = os.clock()
	local last = lastRemoteCall[player]
	if last and now - last < Config.REMOTE_RATE_LIMIT_SECONDS then
		return false
	end
	lastRemoteCall[player] = now
	return true
end

-- ---------------------------------------------------------------- API server

function EconomyService.getMoney(player: Player): number?
	local data = DataService.getData(player)
	return if data then data.money else nil
end

-- Menambah uang. reason dipakai untuk log/analitik nanti (mis. "job:pizza").
function EconomyService.addMoney(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[Economy] addMoney ditolak: jumlah tidak valid {tostring(amount)} ({reason})`)
		return false
	end
	local data = DataService.getData(player)
	if data == nil then
		return false
	end
	local newMoney = math.min(data.money + amount, Config.MAX_MONEY)
	data.stats.totalEarned += newMoney - data.money
	data.money = newMoney
	publish(player, newMoney)
	return true
end

-- Mengurangi uang hanya jika saldo cukup. Mengembalikan true jika berhasil.
function EconomyService.trySpend(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[Economy] trySpend ditolak: jumlah tidak valid {tostring(amount)} ({reason})`)
		return false
	end
	local data = DataService.getData(player)
	if data == nil or data.money < amount then
		return false
	end
	data.money -= amount
	publish(player, data.money)
	return true
end

function EconomyService.notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

-- ---------------------------------------------------------------- remote handler

local function claimDailyReward(player: Player): DailyRewardResult
	if not allowCall(player) then
		return { ok = false, message = "Pelan-pelan ya, coba lagi sebentar." }
	end
	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, message = "Data kamu masih dimuat..." }
	end
	local elapsed = os.time() - data.lastDailyReward
	if elapsed < Config.DAILY_REWARD_COOLDOWN then
		local left = Config.DAILY_REWARD_COOLDOWN - elapsed
		return {
			ok = false,
			message = "Hadiah harian bisa diambil lagi dalam " .. Format.duration(left),
			secondsLeft = left,
		}
	end
	data.lastDailyReward = os.time()
	-- Pemilik Game Pass VIP (atribut diisi ShopService) mendapat hadiah harian dua kali lipat.
	local amount = Config.DAILY_REWARD_AMOUNT
		* (if player:GetAttribute("VIP") == true then 2 else 1)
	EconomyService.addMoney(player, amount, "daily_reward")
	return {
		ok = true,
		message = "Hore! Kamu dapat " .. Format.money(amount),
		secondsLeft = Config.DAILY_REWARD_COOLDOWN,
	}
end

-- ---------------------------------------------------------------- bootstrap

function EconomyService.init()
	notifyRemote = Net.event(Net.Names.Notify)
	local claimRemote = Net.func(Net.Names.ClaimDailyReward)
	-- Argumen dari client diabaikan sepenuhnya; hanya identitas pemain yang dipakai.
	claimRemote.OnServerInvoke = function(player: Player)
		local ok, result = pcall(claimDailyReward, player)
		if ok then
			return result
		end
		warn("[Economy] ClaimDailyReward error: " .. tostring(result))
		return { ok = false, message = "Terjadi kesalahan, coba lagi nanti." }
	end
end

function EconomyService.start()
	DataService.ProfileLoaded:Connect(function(player: Player, data: Types.PlayerData)
		publish(player, data.money)
	end)
	-- Pemain yang profilnya sudah termuat sebelum listener terpasang.
	for _, player in Players:GetPlayers() do
		local money = EconomyService.getMoney(player)
		if money then
			publish(player, money)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRemoteCall[player] = nil
	end)
end

return EconomyService
