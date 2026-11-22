--!strict
-- ShopService: pembelian Robux (Developer Product + Game Pass). Lihat ShopConfig untuk cara
-- mengaktifkannya; selama semua ID masih 0, service ini tidak menjual apa-apa.
--   * ProcessReceipt: koin hanya diberikan sekali per pembelian. ID pembelian dicatat di
--     PlayerData.receipts; pembelian yang sudah tercatat langsung dianggap selesai.
--   * Kalau data pemain belum termuat, pembelian DITUNDA (NotProcessedYet) dan Roblox
--     mengulanginya nanti, jadi pemain tidak kehilangan Robux.
--   * Client hanya meminta jendela beli (remote ShopPrompt); Roblox yang menampilkan harga
--     dan konfirmasi. Tidak ada harga atau jumlah koin yang dikirim client.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local ShopService = {}

local lastCall: { [Player]: number } = {}

local function getReceipts(data: Types.PlayerData): { string }
	local receipts: any = data.receipts
	if type(receipts) ~= "table" then
		receipts = {}
		data.receipts = receipts
	end
	return receipts
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = if player then DataService.getData(player) else nil
	if player == nil or data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = getReceipts(data)
	local purchaseId = tostring(info.PurchaseId)
	if table.find(receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- sudah diberikan sebelumnya
	end
	local product = ShopConfig.productById(info.ProductId)
	if product == nil then
		warn("[Shop] produk tidak dikenal: " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not EconomyService.addMoney(player, product.coins, "shop:" .. product.key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(receipts, purchaseId)
	while #receipts > ShopConfig.MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	EconomyService.notify(
		player,
		"Terima kasih! Kamu mendapat " .. Format.money(product.coins) .. "."
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function refreshVip(player: Player)
	local pass = ShopConfig.PASSES.vip
	local owns = false
	if pass.passId ~= 0 then
		local ok, value = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.passId)
		end)
		owns = ok and value == true
	end
	player:SetAttribute(ShopConfig.ATTR_VIP, owns)
end

function ShopService.isVip(player: Player): boolean
	return player:GetAttribute(ShopConfig.ATTR_VIP) == true
end

-- Client minta jendela beli. key = kunci produk di ShopConfig.PRODUCTS atau "vip".
local function prompt(player: Player, key: any): { ok: boolean, message: string }
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 1 then
		return { ok = false, message = "Pelan-pelan ya, coba lagi sebentar." }
	end
	lastCall[player] = now
	if key == "vip" then
		local pass = ShopConfig.PASSES.vip
		if pass.passId == 0 then
			return { ok = false, message = "Toko belum dibuka." }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.passId)
		return { ok = true, message = "" }
	end
	local product = ShopConfig.productByKey(key)
	if product == nil or product.productId == 0 then
		return { ok = false, message = "Toko belum dibuka." }
	end
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return { ok = true, message = "" }
end

function ShopService.init()
	MarketplaceService.ProcessReceipt = function(info: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(processReceipt, info)
		if ok then
			return decision
		end
		warn("[Shop] ProcessReceipt error: " .. tostring(decision))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Net.func(Net.Names.ShopPrompt).OnServerInvoke = function(player: Player, key: any)
		local ok, value = pcall(prompt, player, key)
		if ok then
			return value
		end
		warn("[Shop] ShopPrompt error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi nanti." }
	end
end

function ShopService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(refreshVip, player)
	end
	Players.PlayerAdded:Connect(refreshVip)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and passId == ShopConfig.PASSES.vip.passId then
				player:SetAttribute(ShopConfig.ATTR_VIP, true)
			end
		end
	)
end

return ShopService
