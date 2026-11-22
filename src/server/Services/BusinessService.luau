--!strict
-- BusinessService: usaha Kafe milik pemain (buka, naik tingkat, layani pelanggan, ambil hasil).
-- Kafe menghasilkan uang tiap menit selama pemiliknya bermain, ditampung sampai batas laci.
-- Tersimpan di PlayerData.business; dikirim ke client lewat atribut Player "Business".
-- Harga, jarak ke kasir, dan jeda melayani dicek di sini.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local BusinessConfig = require(Shared:WaitForChild("BusinessConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

type Result = { ok: boolean, message: string }

local BusinessService = {}

local lastCall: { [Player]: number } = {}
local lastServe: { [Player]: number } = {}

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function getBusiness(data: Types.PlayerData): Types.BusinessData
	local business: any = data.business
	if type(business) ~= "table" then
		business = { level = 0, stored = 0 }
		data.business = business
	end
	if type(business.level) ~= "number" or business.level ~= business.level then
		business.level = 0
	end
	if type(business.stored) ~= "number" or business.stored ~= business.stored then
		business.stored = 0
	end
	business.level = math.clamp(math.floor(business.level), 0, #BusinessConfig.LEVELS)
	business.stored = math.max(0, math.floor(business.stored))
	return business
end

local function publish(player: Player, business: Types.BusinessData)
	local view: BusinessConfig.BusinessView = { level = business.level, stored = business.stored }
	player:SetAttribute(BusinessConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

local function atCounter(player: Player): boolean
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	return root ~= nil
		and (root.Position - BusinessConfig.POSITION).Magnitude <= BusinessConfig.RANGE
end

-- action: "buy" (buka / naik tingkat) | "collect" | "serve"
local function act(player: Player, action: any): Result
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	if not atCounter(player) then
		return result(false, "Datang dulu ke Kafe Mall di dalam ROBLOCK Mall ya.")
	end
	local business = getBusiness(data)
	if action == "buy" then
		local nextLevel = BusinessConfig.get(business.level + 1)
		if nextLevel == nil then
			return result(false, "Kafemu sudah di tingkat tertinggi.")
		end
		if not EconomyService.trySpend(player, nextLevel.price, "business:kafe") then
			return result(
				false,
				"Uangmu belum cukup. Harganya " .. Format.money(nextLevel.price) .. "."
			)
		end
		business.level += 1
		publish(player, business)
		return result(
			true,
			if business.level == 1
				then "Selamat! Kamu sekarang pemilik " .. nextLevel.name .. "."
				else "Kafemu naik tingkat jadi " .. nextLevel.name .. "!"
		)
	end
	local level = BusinessConfig.get(business.level)
	if level == nil then
		return result(false, "Kamu belum punya kafe.")
	end
	if action == "collect" then
		local amount = business.stored
		if amount <= 0 then
			return result(false, "Laci kasir masih kosong. Tunggu pelanggan dulu ya.")
		end
		if not EconomyService.addMoney(player, amount, "business:kafe") then
			return result(false, "Terjadi kesalahan, coba lagi nanti.")
		end
		business.stored = 0
		publish(player, business)
		return result(true, "Hasil kafe " .. Format.money(amount) .. " masuk ke dompetmu!")
	elseif action == "serve" then
		local now = os.clock()
		local last = lastServe[player]
		if last and now - last < BusinessConfig.SERVE_COOLDOWN then
			local left = math.ceil(BusinessConfig.SERVE_COOLDOWN - (now - last))
			return result(false, "Pelanggan berikutnya datang " .. left .. " detik lagi.")
		end
		if business.stored >= level.capacity then
			return result(false, "Laci kasir penuh. Ambil hasilnya dulu ya.")
		end
		lastServe[player] = now
		business.stored = math.min(level.capacity, business.stored + level.serveBonus)
		publish(player, business)
		return result(
			true,
			"Pelanggan senang! +" .. Format.money(level.serveBonus) .. " di laci kasir."
		)
	end
	return result(false, "Perintah tidak dikenal.")
end

function BusinessService.init()
	Net.func(Net.Names.BusinessAction).OnServerInvoke = function(player: Player, action: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(act, player, action)
		if ok then
			return value
		end
		warn("[Business] BusinessAction error: " .. tostring(value))
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end

	local counter = Instance.new("Part")
	counter.Name = "KafeMall"
	counter.Anchored = true
	counter.CanCollide = false
	counter.CanQuery = false
	counter.Transparency = 1
	counter.Size = Vector3.new(2, 2, 2)
	counter.Position = BusinessConfig.POSITION + Vector3.new(0, 4, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Kelola kafe"
	prompt.ObjectText = "Kafe Mall"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(BusinessConfig.ATTR_PROMPT, true)
	prompt.Parent = counter
	counter.Parent = Workspace
end

function BusinessService.start()
	local function onProfileLoaded(player: Player, data: Types.PlayerData)
		publish(player, getBusiness(data))
	end
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data and player:GetAttribute(BusinessConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
		lastServe[player] = nil
	end)

	-- Pemasukan tiap menit untuk pemilik yang sedang bermain.
	while true do
		task.wait(BusinessConfig.TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			local data = DataService.getData(player)
			if data == nil then
				continue
			end
			local business = getBusiness(data)
			local level = BusinessConfig.get(business.level)
			if level and business.stored < level.capacity then
				business.stored = math.min(level.capacity, business.stored + level.income)
				publish(player, business)
				if business.stored >= level.capacity then
					EconomyService.notify(
						player,
						"Laci kasir kafemu penuh! Ambil hasilnya di Kafe Mall."
					)
				end
			end
		end
	end
end

return BusinessService
