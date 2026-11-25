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
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local UniformService = require(script.Parent:WaitForChild("UniformService"))
local GadgetService = require(script.Parent:WaitForChild("GadgetService"))

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
		-- Sudah diberikan sebelumnya; pastikan tersimpan sebelum Roblox menutup tanda terima.
		if not DataService.saveNow(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = ShopConfig.productById(info.ProductId)
	if product == nil then
		warn("[Shop] produk tidak dikenal: " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.coins then
		if not EconomyService.addMoney(player, product.coins, "shop:" .. product.key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		EconomyService.notify(
			player,
			"Terima kasih! Kamu mendapat " .. Format.money(product.coins) .. "."
		)
	elseif product.costume then
		-- Produk costume (Toko Costume): dicatat ke PlayerData.fashion dan langsung dipakai.
		local outfit = FashionConfig.get(product.costume)
		if outfit == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local fashion: any = data.fashion
		if type(fashion) ~= "table" then
			fashion = {}
			data.fashion = fashion
		end
		if type(fashion.owned) ~= "table" then
			fashion.owned = {}
		end
		fashion.owned[outfit.id] = true
		fashion.active = outfit.id
		player:SetAttribute(
			FashionConfig.ATTR_PLAYER,
			game:GetService("HttpService")
				:JSONEncode({ owned = fashion.owned, active = fashion.active })
		)
		UniformService.refresh(player)
		EconomyService.notify(
			player,
			"Terima kasih! Costume " .. outfit.name .. " sekarang milikmu dan sudah dipakai."
		)
	else
		-- Produk gadget (ROBLOCK STORE): dicatat sebagai milik pemain, bukan koin.
		local gadgets: any = data.gadgets
		if type(gadgets) ~= "table" then
			gadgets = {}
			data.gadgets = gadgets
		end
		if type(gadgets.owned) ~= "table" then
			gadgets.owned = {}
		end
		gadgets.owned[product.key] = true
		GadgetService.refresh(player)
		EconomyService.notify(player, "Terima kasih! " .. product.name .. " sekarang milikmu.")
	end
	table.insert(receipts, purchaseId)
	while #receipts > ShopConfig.MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	-- Simpan ke DataStore SEBELUM tanda terima ditutup. Kalau gagal, Roblox mengulang pemanggilan
	-- ini nanti; PurchaseId sudah tercatat di receipts jadi barang tidak diberikan dua kali.
	if not DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Dipakai alat uji Studio (DebugService) untuk meniru tanda terima tanpa Robux.
function ShopService.processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	return processReceipt(info)
end

-- Papan "VIP" kecil di atas kepala pemilik Game Pass VIP.
local function applyVipTag(player: Player)
	local char = player.Character
	local head = if char then char:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("VipTag")
	if old then
		old:Destroy()
	end
	if player:GetAttribute(ShopConfig.ATTR_VIP) ~= true then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(90, 28)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 80)
	label.Text = "⭐ VIP"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = head
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
	applyVipTag(player)
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

	-- Kios Toko Koin di atrium mall: hanya membuka panel toko di layar pemain (ShopController).
	local base = CFrame.new(ShopConfig.KIOSK_POSITION)
	local kiosk = Instance.new("Folder")
	kiosk.Name = "KiosTokoKoin"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = kiosk
		return p
	end
	local counter = part(
		"Meja",
		Vector3.new(6, 3.4, 3),
		base * CFrame.new(0, 1.7, 0),
		Color3.fromRGB(240, 170, 30)
	)
	part(
		"AtasMeja",
		Vector3.new(6.4, 0.3, 3.4),
		base * CFrame.new(0, 3.55, 0),
		Color3.fromRGB(250, 250, 250)
	)
	for _, sx in { -1, 1 } do
		part(
			"Tiang",
			Vector3.new(0.4, 4.6, 0.4),
			base * CFrame.new(sx * 2.9, 6, 0),
			Color3.fromRGB(90, 96, 110)
		)
	end
	local board = part(
		"Papan",
		Vector3.new(6.6, 1.8, 0.4),
		base * CFrame.new(0, 9, 0),
		Color3.fromRGB(40, 70, 130)
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 214, 80)
		label.Text = "TOKO KOIN"
		label.Parent = gui
		gui.Parent = board
	end
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Lihat"
	shopPrompt.ObjectText = "Toko Koin"
	shopPrompt.HoldDuration = 0.2
	shopPrompt.MaxActivationDistance = 12
	shopPrompt.RequiresLineOfSight = false
	shopPrompt:SetAttribute(ShopConfig.ATTR_PROMPT, true)
	shopPrompt.Parent = counter
	kiosk.Parent = game:GetService("Workspace")
end

function ShopService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(refreshVip, player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			applyVipTag(player)
		end)
		refreshVip(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
	-- Etalase gadget ROBLOCK STORE: ProximityPrompt (atribut ATTR_GADGET = key produk)
	-- ditaruh BuildShops; server yang membuka jendela belinya.
	ProximityPromptService.PromptTriggered:Connect(
		function(proximityPrompt: ProximityPrompt, player: Player)
			local key = proximityPrompt:GetAttribute(ShopConfig.ATTR_GADGET)
			if key == nil then
				return
			end
			local ok, value = pcall(prompt, player, key)
			if ok and value.ok == false and value.message ~= "" then
				EconomyService.notify(player, value.message)
			end
		end
	)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and passId == ShopConfig.PASSES.vip.passId then
				player:SetAttribute(ShopConfig.ATTR_VIP, true)
				applyVipTag(player)
				EconomyService.notify(
					player,
					"Terima kasih! Kamu sekarang VIP: hadiah harian dua kali lipat dan tanda ⭐ VIP."
				)
			end
		end
	)
end

return ShopService
