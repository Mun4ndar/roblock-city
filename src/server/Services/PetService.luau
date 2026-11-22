--!strict
-- PetService: hewan peliharaan (beli, pilih, beri makan). Hewan yang dipilih mengikuti
-- pemiliknya: model ringan tanpa tabrakan yang ditarik AlignPosition ke samping pemilik
-- (fisikanya dijalankan client pemilik, jadi gerakannya halus dan murah untuk server).
-- Tersimpan di PlayerData.pets; dikirim ke client lewat atribut Player "Pets".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local PetConfig = require(Shared:WaitForChild("PetConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

type Result = { ok: boolean, message: string }
type PetData = Types.PetData

local PetService = {}

local models: { [Player]: Model } = {}
local lastCall: { [Player]: number } = {}
local folder: Folder

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function getPets(data: Types.PlayerData): PetData
	local pets: any = data.pets
	if type(pets) ~= "table" or type(pets.owned) ~= "table" then
		pets = { owned = {}, active = "", fedAt = 0 }
		data.pets = pets
	end
	if type(pets.active) ~= "string" then
		pets.active = ""
	end
	if type(pets.fedAt) ~= "number" then
		pets.fedAt = 0
	end
	return pets
end

local function publish(player: Player, pets: PetData)
	local view: PetConfig.PetView = { owned = pets.owned, active = pets.active, fedAt = pets.fedAt }
	player:SetAttribute(PetConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

-- ---------------------------------------------------------------- model hewan

local function piece(
	model: Model,
	root: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType
)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
end

local function buildPet(def: PetConfig.PetDef, at: CFrame): (Model, BasePart)
	local k = def.size
	local model = Instance.new("Model")
	model.Name = "Hewan_" .. def.id
	local ball, block = Enum.PartType.Ball, Enum.PartType.Block
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = ball
	root.Size = Vector3.new(1.8, 1.8, 1.8) * k
	root.Color = def.body
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root
	local function add(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType)
		piece(
			model,
			root,
			size * k,
			CFrame.new(offset.Position * k) * offset.Rotation,
			color,
			shape
		)
	end
	add(Vector3.new(1.6, 1.5, 1.2), CFrame.new(0, -0.05, 0.9), def.body, ball) -- badan belakang
	add(Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 0.75, -0.95), def.body, ball) -- kepala
	add(Vector3.new(0.7, 0.55, 0.6), CFrame.new(0, 0.5, -1.65), def.accent, ball) -- moncong
	add(Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.62, -1.95), Color3.fromRGB(40, 36, 40), ball) -- hidung
	for _, sx in { -1, 1 } do
		add(
			Vector3.new(0.2, 0.26, 0.2),
			CFrame.new(sx * 0.36, 0.95, -1.62),
			Color3.fromRGB(30, 30, 36),
			ball
		) -- mata
		if def.ears == "panjang" then
			add(Vector3.new(0.34, 1.5, 0.24), CFrame.new(sx * 0.4, 2, -0.85), def.body, block)
			add(Vector3.new(0.18, 1.1, 0.1), CFrame.new(sx * 0.4, 2, -0.98), def.accent, block)
		elseif def.ears == "runcing" then
			add(
				Vector3.new(0.5, 0.6, 0.3),
				CFrame.new(sx * 0.5, 1.6, -0.9) * CFrame.Angles(0, 0, sx * -0.35),
				def.accent,
				block
			)
		else
			add(Vector3.new(0.6, 0.6, 0.3), CFrame.new(sx * 0.62, 1.45, -0.9), def.accent, ball)
		end
		for _, sz in { -0.5, 1.1 } do
			add(Vector3.new(0.42, 0.9, 0.42), CFrame.new(sx * 0.48, -0.95, sz), def.accent, block) -- kaki
		end
	end
	add(
		Vector3.new(0.4, 0.4, 1.1),
		CFrame.new(0, 0.35, 1.9) * CFrame.Angles(0.6, 0, 0),
		def.accent,
		block
	) -- ekor

	local tag = Instance.new("BillboardGui")
	tag.Name = "Nama"
	tag.Size = UDim2.fromScale(5, 1)
	tag.StudsOffset = Vector3.new(0, 2.4 * k, 0)
	tag.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = def.name
	label.Parent = tag
	tag.Parent = root
	return model, root
end

local function removePet(player: Player)
	local model = models[player]
	if model then
		model:Destroy()
		models[player] = nil
	end
end

local function spawnPet(player: Player)
	removePet(player)
	local data = DataService.getData(player)
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if data == nil or hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	local def = PetConfig.get(getPets(data).active)
	if def == nil then
		return
	end
	local model, root = buildPet(def, hrp.CFrame * CFrame.new(3, -1.4, 2.5))
	-- titik tujuan: di samping belakang pemilik, setinggi tanah
	local target = Instance.new("Attachment")
	target.Name = "PetTarget"
	target.Position = Vector3.new(3, -1.9 + 0.95 * def.size, 2.5)
	target.Parent = hrp
	local anchor = Instance.new("Attachment")
	anchor.Parent = root
	local move = Instance.new("AlignPosition")
	move.Attachment0 = anchor
	move.Attachment1 = target
	move.MaxForce = 1e6
	move.MaxVelocity = 60
	move.Responsiveness = 18
	move.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Attachment0 = anchor
	turn.Attachment1 = target
	turn.MaxTorque = 1e6
	turn.Responsiveness = 14
	turn.Parent = root
	model.Destroying:Connect(function()
		target:Destroy()
	end)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	models[player] = model
end

-- ---------------------------------------------------------------- remote handler

local function nearShop(player: Player): boolean
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	return root ~= nil
		and (root.Position - PetConfig.SHOP_POSITION).Magnitude <= PetConfig.SHOP_RANGE
end

-- action: "buy" | "equip" | "feed"; petId untuk buy/equip ("" pada equip = simpan hewan).
local function act(player: Player, action: any, petId: any): Result
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local pets = getPets(data)
	if action == "buy" then
		local def = PetConfig.get(petId)
		if def == nil then
			return result(false, "Hewan tidak dikenal.")
		end
		if pets.owned[def.id] then
			return result(false, "Kamu sudah punya " .. def.name .. ".")
		end
		if not nearShop(player) then
			return result(false, "Datang dulu ke Toko Hewan di depan ROBLOCK Mall ya.")
		end
		if not EconomyService.trySpend(player, def.price, "pet:" .. def.id) then
			return result(false, "Uangmu belum cukup. Harganya " .. Format.money(def.price) .. ".")
		end
		pets.owned[def.id] = true
		pets.active = def.id
		pets.fedAt = math.floor(Workspace:GetServerTimeNow())
		publish(player, pets)
		spawnPet(player)
		return result(true, def.name .. " sekarang jadi temanmu!")
	elseif action == "equip" then
		if petId == "" then
			pets.active = ""
			publish(player, pets)
			removePet(player)
			return result(true, "Hewanmu beristirahat di rumah.")
		end
		local def = PetConfig.get(petId)
		if def == nil or not pets.owned[def.id] then
			return result(false, "Kamu belum punya hewan itu.")
		end
		pets.active = def.id
		publish(player, pets)
		spawnPet(player)
		return result(true, def.name .. " ikut jalan-jalan!")
	elseif action == "feed" then
		local def = PetConfig.get(pets.active)
		if def == nil then
			return result(false, "Ajak dulu salah satu hewanmu.")
		end
		if not EconomyService.trySpend(player, PetConfig.FEED_PRICE, "pet:feed") then
			return result(
				false,
				"Uangmu belum cukup untuk makanan (" .. Format.money(PetConfig.FEED_PRICE) .. ")."
			)
		end
		pets.fedAt = math.floor(Workspace:GetServerTimeNow())
		publish(player, pets)
		return result(true, def.name .. " kenyang dan senang!")
	end
	return result(false, "Perintah tidak dikenal.")
end

-- ---------------------------------------------------------------- bootstrap

function PetService.init()
	folder = Instance.new("Folder")
	folder.Name = "Hewan"
	folder.Parent = Workspace

	Net.func(Net.Names.PetAction).OnServerInvoke = function(player: Player, action: any, petId: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(act, player, action, petId)
		if ok then
			return value
		end
		warn("[Pet] PetAction error: " .. tostring(value))
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end

	-- Toko Hewan: titik tombol di depan mall
	local shop = Instance.new("Part")
	shop.Name = "TokoHewan"
	shop.Anchored = true
	shop.CanCollide = false
	shop.CanQuery = false
	shop.Transparency = 1
	shop.Size = Vector3.new(2, 2, 2)
	shop.Position = PetConfig.SHOP_POSITION + Vector3.new(0, 4, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lihat hewan"
	prompt.ObjectText = "Toko Hewan"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(PetConfig.ATTR_PROMPT, true)
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
	label.TextColor3 = Color3.fromRGB(255, 170, 200)
	label.TextStrokeTransparency = 0.2
	label.Text = "🐾 Toko Hewan"
	label.Parent = sign
	sign.Parent = shop
	shop.Parent = Workspace
end

function PetService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			spawnPet(player)
		end)
	end
	local function onProfileLoaded(player: Player, data: Types.PlayerData)
		publish(player, getPets(data))
		spawnPet(player)
	end
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		local data = DataService.getData(player)
		if data and player:GetAttribute(PetConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		removePet(player)
		lastCall[player] = nil
	end)
end

return PetService
