--!strict
-- FashionService: Toko Costume (beli dan pakai skin baju/costume). Costume tampil saat pemain
-- tidak sedang bekerja (dirakit UniformService). Tersimpan di PlayerData.fashion; dikirim ke
-- client lewat atribut Player "Fashion". Harga, kepemilikan, dan jarak ke toko dicek di sini.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local UniformService = require(script.Parent:WaitForChild("UniformService"))

type Result = { ok: boolean, message: string }

local FashionService = {}

local lastCall: { [Player]: number } = {}

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function getFashion(data: Types.PlayerData): Types.FashionData
	local fashion: any = data.fashion
	if type(fashion) ~= "table" or type(fashion.owned) ~= "table" then
		fashion = { owned = {}, active = "" }
		data.fashion = fashion
	end
	if type(fashion.active) ~= "string" then
		fashion.active = ""
	end
	return fashion
end

local function publish(player: Player, fashion: Types.FashionData)
	local view: FashionConfig.FashionView = { owned = fashion.owned, active = fashion.active }
	player:SetAttribute(FashionConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

-- Dipakai RetentionService: setelan event terbatas dibeli di panel event, bukan di toko.
function FashionService.owns(player: Player, id: string): boolean
	local data = DataService.getData(player)
	return data ~= nil and getFashion(data).owned[id] == true
end

-- wear = true: langsung dipakai kalau pemain belum memakai setelan lain (hadiah Misi Pemula).
function FashionService.grant(player: Player, id: string, wear: boolean?): boolean
	local data = DataService.getData(player)
	if data == nil or FashionConfig.get(id) == nil then
		return false
	end
	local fashion = getFashion(data)
	fashion.owned[id] = true
	local wearNow = wear == true and fashion.active == ""
	if wearNow then
		fashion.active = id
	end
	publish(player, fashion)
	if wearNow then
		UniformService.refresh(player)
	end
	return true
end

-- action: "buy" | "wear"; pada "wear", id "" = lepas setelan.
local function act(player: Player, action: any, id: any): Result
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local fashion = getFashion(data)
	if action == "wear" and id == "" then
		fashion.active = ""
		publish(player, fashion)
		UniformService.refresh(player)
		return result(true, "Setelan dilepas.")
	end
	local outfit = FashionConfig.get(id)
	if outfit == nil then
		return result(false, "Setelan tidak dikenal.")
	end
	if action == "buy" then
		if fashion.owned[outfit.id] then
			return result(false, "Kamu sudah punya setelan itu.")
		end
		if outfit.event then
			return result(false, "Setelan ini hanya dijual saat event, lewat menu Hadiah di HP.")
		end
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		if
			root == nil
			or (root.Position - FashionConfig.SHOP_POSITION).Magnitude
				> FashionConfig.SHOP_RANGE
		then
			return result(false, "Datang dulu ke Toko Costume kaca di downtown ya.")
		end
		if outfit.productKey then
			local product = ShopConfig.productByKey(outfit.productKey)
			if product == nil or product.productId == 0 then
				return result(
					false,
					"Developer Product untuk " .. outfit.name .. " belum diisi ID-nya."
				)
			end
			return result(false, "Tekan tombol R$ di menu untuk membuka pembelian Roblox.")
		end
		if not EconomyService.trySpend(player, outfit.price, "fashion:" .. outfit.id) then
			return result(
				false,
				"Uangmu belum cukup. Harganya " .. Format.money(outfit.price) .. "."
			)
		end
		fashion.owned[outfit.id] = true
		fashion.active = outfit.id
	elseif action == "wear" then
		if not fashion.owned[outfit.id] then
			return result(false, "Kamu belum punya setelan itu.")
		end
		fashion.active = outfit.id
	else
		return result(false, "Perintah tidak dikenal.")
	end
	publish(player, fashion)
	UniformService.refresh(player)
	local working = data.jobs.current ~= ""
	return result(
		true,
		outfit.name
			.. (
				if working
					then " tersimpan. Terlihat saat kamu tidak sedang bekerja."
					else " terpasang!"
			)
	)
end

function FashionService.init()
	Net.func(Net.Names.FashionAction).OnServerInvoke = function(
		player: Player,
		action: any,
		id: any
	)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(act, player, action, id)
		if ok then
			return value
		end
		warn("[Fashion] FashionAction error: " .. tostring(value))
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end

	local shop = Instance.new("Part")
	shop.Name = "TokoCostume"
	shop.Anchored = true
	shop.CanCollide = false
	shop.CanQuery = false
	shop.Transparency = 1
	shop.Size = Vector3.new(2, 2, 2)
	shop.Position = FashionConfig.SHOP_POSITION + Vector3.new(0, 4, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lihat costume"
	prompt.ObjectText = "Toko Costume"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(FashionConfig.ATTR_PROMPT, true)
	prompt.Parent = shop
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(12, 2.4)
	sign.StudsOffset = Vector3.new(0, 6, 0)
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 200, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = "🧥 Toko Costume"
	label.Parent = sign
	sign.Enabled = false -- papan nama toko sudah ada di dalam mall
	sign.Parent = shop
	shop.Parent = Workspace
end

function FashionService.start()
	local function onProfileLoaded(player: Player, data: Types.PlayerData)
		publish(player, getFashion(data))
	end
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data and player:GetAttribute(FashionConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
end

return FashionService
