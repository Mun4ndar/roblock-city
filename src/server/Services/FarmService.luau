--!strict
-- FarmService: perkebunan (beli bibit, tanam, panen, jual).
--   * client hanya mengirim id tanaman / nomor petak; harga, stok, jarak ke pasar
--     atau petak, dan kematangan tanaman dicek di sini
--   * waktu tanam memakai jam server (GetServerTimeNow), jadi tanaman tetap tumbuh
--     saat pemain keluar dan tidak bisa dipercepat dari client
--   * tersimpan di PlayerData.farm; dikirim ke client lewat atribut Player "Farm"

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local FarmConfig = require(Shared:WaitForChild("FarmConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

type FarmData = Types.FarmData
type Result = { ok: boolean, message: string }

local FarmService = {}

local CALL_COOLDOWN = 0.25

local lastCall: { [Player]: number } = {}

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

-- Data lama/rusak dirapikan supaya sisa kode boleh percaya pada bentuknya.
local function getFarm(data: Types.PlayerData): FarmData
	local farm: any = data.farm
	if type(farm) ~= "table" then
		farm = {}
		data.farm = farm
	end
	for _, key in { "plots", "seeds", "crops" } do
		if type(farm[key]) ~= "table" then
			farm[key] = {}
		end
	end
	return farm
end

local function publish(player: Player, farm: FarmData)
	local view: FarmConfig.FarmView = { plots = farm.plots, seeds = farm.seeds, crops = farm.crops }
	player:SetAttribute(FarmConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	return if root then root.Position else nil
end

local function nearTagged(
	player: Player,
	tag: string,
	distance: number,
	plotIndex: number?
): boolean
	local position = rootPosition(player)
	if position == nil then
		return false
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if
			inst:IsA("BasePart")
			and (plotIndex == nil or inst:GetAttribute(FarmConfig.ATTR_PLOT_INDEX) == plotIndex)
		then
			if (inst.Position - position).Magnitude <= distance then
				return true
			end
		end
	end
	return false
end

local function isPlotIndex(value: any): boolean
	return type(value) == "number"
		and value == math.floor(value)
		and value >= 1
		and value <= FarmConfig.PLOT_COUNT
end

-- ---------------------------------------------------------------- remote handler

local function buySeed(player: Player, cropId: any): Result
	local data = DataService.getData(player)
	local crop = FarmConfig.crop(cropId)
	if data == nil or crop == nil then
		return result(false, "Bibit tidak dikenal.")
	end
	if not nearTagged(player, FarmConfig.TAG_MARKET, FarmConfig.MARKET_DISTANCE) then
		return result(false, "Datang dulu ke Pasar Tani ya.")
	end
	local farm = getFarm(data)
	local owned = farm.seeds[crop.id] or 0
	if owned >= FarmConfig.MAX_STACK then
		return result(false, "Kantong bibitmu sudah penuh.")
	end
	if not EconomyService.trySpend(player, crop.seedPrice, "farm:seed:" .. crop.id) then
		return result(false, "Uangmu belum cukup untuk bibit " .. crop.name .. ".")
	end
	farm.seeds[crop.id] = owned + 1
	publish(player, farm)
	return result(true, "Bibit " .. crop.name .. " dibeli. Tanam di Kebun Warga!")
end

local function plant(player: Player, plotIndex: any, cropId: any): Result
	local data = DataService.getData(player)
	local crop = FarmConfig.crop(cropId)
	if data == nil or crop == nil or not isPlotIndex(plotIndex) then
		return result(false, "Petak atau bibit tidak dikenal.")
	end
	if not nearTagged(player, FarmConfig.TAG_PLOT, FarmConfig.PLOT_DISTANCE, plotIndex) then
		return result(false, "Dekati dulu petaknya.")
	end
	local farm = getFarm(data)
	local key = tostring(plotIndex)
	if farm.plots[key] ~= nil then
		return result(false, "Petak ini sudah ada tanamannya.")
	end
	local owned = farm.seeds[crop.id] or 0
	if owned < 1 then
		return result(false, "Kamu belum punya bibit " .. crop.name .. ". Beli di Pasar Tani.")
	end
	farm.seeds[crop.id] = if owned > 1 then owned - 1 else nil
	farm.plots[key] = { crop = crop.id, plantedAt = math.floor(Workspace:GetServerTimeNow()) }
	publish(player, farm)
	return result(
		true,
		crop.name .. " ditanam! Siap panen dalam " .. Format.duration(crop.growSeconds) .. "."
	)
end

local function harvest(player: Player, plotIndex: any): Result
	local data = DataService.getData(player)
	if data == nil or not isPlotIndex(plotIndex) then
		return result(false, "Petak tidak dikenal.")
	end
	if not nearTagged(player, FarmConfig.TAG_PLOT, FarmConfig.PLOT_DISTANCE, plotIndex) then
		return result(false, "Dekati dulu petaknya.")
	end
	local farm = getFarm(data)
	local key = tostring(plotIndex)
	local plot = farm.plots[key]
	local crop = if type(plot) == "table" then FarmConfig.crop(plot.crop) else nil
	if plot == nil or crop == nil then
		farm.plots[key] = nil
		publish(player, farm)
		return result(false, "Petak ini masih kosong.")
	end
	local left = crop.growSeconds - (Workspace:GetServerTimeNow() - plot.plantedAt)
	if left > 0 then
		return result(
			false,
			crop.name .. " belum matang. Tunggu " .. Format.duration(math.ceil(left)) .. " lagi."
		)
	end
	local owned = farm.crops[crop.id] or 0
	if owned >= FarmConfig.MAX_STACK then
		return result(false, "Keranjangmu penuh. Jual dulu hasil panen di Pasar Tani.")
	end
	farm.plots[key] = nil
	farm.crops[crop.id] = owned + 1
	publish(player, farm)
	return result(true, "Panen " .. crop.name .. "! Jual di Pasar Tani.")
end

local function sell(player: Player): Result
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	if not nearTagged(player, FarmConfig.TAG_MARKET, FarmConfig.MARKET_DISTANCE) then
		return result(false, "Datang dulu ke Pasar Tani ya.")
	end
	local farm = getFarm(data)
	local total = 0
	for cropId, count in farm.crops do
		local crop = FarmConfig.crop(cropId)
		if crop and type(count) == "number" and count > 0 then
			total += crop.sellPrice * math.min(math.floor(count), FarmConfig.MAX_STACK)
		end
	end
	if total <= 0 then
		return result(false, "Belum ada hasil panen untuk dijual.")
	end
	if not EconomyService.addMoney(player, total, "farm:sell") then
		return result(false, "Belum bisa menjual sekarang, coba lagi.")
	end
	farm.crops = {}
	publish(player, farm)
	return result(true, "Hasil panen terjual " .. Format.money(total) .. "!")
end

-- ---------------------------------------------------------------- bootstrap

local function bind(name: string, handler: (Player, any, any) -> Result)
	Net.func(name).OnServerInvoke = function(player: Player, a: any, b: any)
		local now = os.clock()
		local last = lastCall[player]
		if last and now - last < CALL_COOLDOWN then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(handler, player, a, b)
		if ok then
			return value
		end
		warn(`[Farm] {name} error: {tostring(value)}`)
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

function FarmService.init()
	bind(Net.Names.FarmBuySeed, buySeed)
	bind(Net.Names.FarmPlant, plant)
	bind(Net.Names.FarmHarvest, harvest)
	bind(Net.Names.FarmSell, sell)
end

function FarmService.start()
	local function onProfileLoaded(player: Player, data: Types.PlayerData)
		publish(player, getFarm(data))
	end
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data and player:GetAttribute(FarmConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
end

return FarmService
