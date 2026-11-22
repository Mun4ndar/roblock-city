--!strict
-- HouseService: rumah pemain di perumahan (Workspace.Map.Neighborhoods.Houses).
--   * rumah dikenali dari peta saat server mulai (nomor, tipe, titik pusat)
--   * beli/jual/cat/hiasan halaman: semuanya divalidasi di sini, client hanya meminta
--   * kepemilikan tersimpan di PlayerData.house; kalau rumahnya sedang ditempati
--     pemain lain di server ini, pemain mendapat rumah pengganti setipe
--   * tampilan rumah (cat, hiasan, papan nama) hanya dipasang selama pemiliknya ada

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local HouseConfig = require(Shared:WaitForChild("HouseConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))

type HouseData = Types.HouseData
type HouseResult = Types.HouseResult

type House = {
	id: number,
	model: Model,
	base: CFrame, -- pusat rumah di tanah; depan rumah = -Z
	tier: string,
	owner: Player?,
	groups: { [string]: { BasePart } }, -- bagian cat -> part
	original: { [BasePart]: Color3 },
	items: { [number]: Model },
	interior: Model?,
	sign: BillboardGui?,
}

local HouseService = {}

local CALL_COOLDOWN = 0.35
local FOUNDATION_HEIGHT = 0.8
local TWO_STORY_HEIGHT = 12
local DOOR_FRONT = CFrame.new(-3, 4, -13) * CFrame.Angles(0, math.pi, 0)

local houses: { [number]: House } = {}
local byPlayer: { [Player]: House } = {}
local lastCall: { [Player]: number } = {}
local lastHome: { [Player]: number } = {}
local itemFolder: Folder

-- ---------------------------------------------------------------- util

local function result(ok: boolean, message: string): HouseResult
	return { ok = ok, message = message }
end

local function allowCall(player: Player): boolean
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return false
	end
	lastCall[player] = now
	return true
end

local function isInteger(value: any, min: number, max: number): boolean
	return type(value) == "number"
		and value == value
		and math.floor(value) == value
		and value >= min
		and value <= max
end

local function emptyHouse(): HouseData
	return { id = 0, tier = "", boughtAt = 0, paint = {}, items = {} }
end

-- Data lama/rusak dirapikan supaya sisa kode boleh percaya pada bentuknya.
local function sanitize(data: Types.PlayerData): HouseData
	local hd: any = data.house
	if type(hd) ~= "table" or type(hd.id) ~= "number" or HouseConfig.tier(hd.tier) == nil then
		data.house = emptyHouse()
		return data.house
	end
	if type(hd.paint) ~= "table" then
		hd.paint = {}
	end
	if type(hd.items) ~= "table" then
		hd.items = {}
	end
	return hd
end

local function publish(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local hd = data.house
	local house = byPlayer[player]
	local pos = if house then (house.base * DOOR_FRONT).Position else Vector3.zero
	local view: HouseConfig.HouseView = {
		id = hd.id,
		live = if house then house.id else 0,
		tier = hd.tier,
		paint = hd.paint,
		items = hd.items,
		pos = { math.round(pos.X), math.round(pos.Y), math.round(pos.Z) },
	}
	player:SetAttribute(HouseConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

-- ---------------------------------------------------------------- tampilan rumah

-- Rakit daftar part (hiasan halaman atau isi rumah) ke dalam model.
-- alwaysLit = true: lampunya menyala terus (ruang dalam), bukan hanya malam hari.
local function buildParts(
	model: Model,
	origin: CFrame,
	specs: { HouseConfig.PartSpec },
	prefix: string,
	alwaysLit: boolean
)
	for index, spec in specs do
		local part = Instance.new("Part")
		part.Name = prefix .. tostring(index)
		part.Anchored = true
		part.CanCollide = spec.collide ~= false
		part.CastShadow = spec.collide ~= false
		part.Shape = spec.shape or Enum.PartType.Block
		part.Size = spec.size
		part.CFrame = origin * spec.offset
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if spec.light then
			local light = Instance.new("PointLight")
			-- Lampu ruang dalam harus redup (ruang tertutup cepat silau); lampu taman boleh terang.
			light.Range = if alwaysLit then 26 else 18
			light.Brightness = if alwaysLit then 0.3 else 2
			light.Color = spec.color
			light.Shadows = false
			light.Parent = part
			if not alwaysLit then
				CollectionService:AddTag(part, DayNightConfig.TAG_LIGHT)
			end
		end
		if spec.bounce then
			-- Pantulan dihitung di client pemilik karakter (lihat HouseUiController).
			part:SetAttribute(HouseConfig.ATTR_BOUNCE, spec.bounce)
			CollectionService:AddTag(part, HouseConfig.TAG_BOUNCE)
		end
		part.Parent = model
	end
end

local function buildItem(house: House, slotIndex: number, def: HouseConfig.ItemDef)
	local slot = HouseConfig.YARD_SLOTS[slotIndex]
	local model = Instance.new("Model")
	model.Name = `Hiasan_{house.id}_{slotIndex}_{def.id}`
	buildParts(model, house.base * slot.offset, def.parts, def.id, false)
	model.Parent = itemFolder
	house.items[slotIndex] = model
end

-- Warna tiap bahan perabot mesh (nama MeshPart = "Perabot" + bahan).
local FURNITURE = {
	Fabric = { color = Color3.fromRGB(86, 136, 200), material = Enum.Material.Fabric },
	Cushion = { color = Color3.fromRGB(240, 210, 120), material = Enum.Material.Fabric },
	Rug = { color = Color3.fromRGB(236, 186, 120), material = Enum.Material.Fabric },
	Pink = { color = Color3.fromRGB(240, 150, 170), material = Enum.Material.Fabric },
	White = { color = Color3.fromRGB(248, 248, 246), material = Enum.Material.SmoothPlastic },
	Wood = { color = Color3.fromRGB(160, 112, 70), material = Enum.Material.Wood },
	Dark = { color = Color3.fromRGB(70, 60, 56), material = Enum.Material.SmoothPlastic },
	Screen = { color = Color3.fromRGB(24, 26, 34), material = Enum.Material.Glass },
	Lamp = { color = Color3.fromRGB(255, 226, 170), material = Enum.Material.Neon },
	Metal = { color = Color3.fromRGB(206, 212, 220), material = Enum.Material.Metal },
	Accent = { color = Color3.fromRGB(240, 150, 90), material = Enum.Material.SmoothPlastic },
	Red = { color = Color3.fromRGB(210, 70, 70), material = Enum.Material.SmoothPlastic },
	Blue = { color = Color3.fromRGB(70, 120, 200), material = Enum.Material.SmoothPlastic },
	Pot = { color = Color3.fromRGB(190, 110, 70), material = Enum.Material.SmoothPlastic },
	Green = { color = Color3.fromRGB(70, 160, 80), material = Enum.Material.SmoothPlastic },
}

-- Perabot mesh (sudut membulat) dari templat ServerStorage.AsetRumah.perabot. false jika templat tidak ada.
local function addFurniture(model: Model, origin: CFrame): boolean
	local folder = ServerStorage:FindFirstChild("AsetRumah")
	local template = if folder then folder:FindFirstChild("perabot") else nil
	local ref = if template then template:FindFirstChild("PerabotRef") else nil
	if template == nil or ref == nil or not ref:IsA("BasePart") then
		return false
	end
	local base = ref.CFrame * CFrame.new(0, -ref.Size.Y / 2, 0)
	for _, piece in template:GetChildren() do
		local look = FURNITURE[piece.Name:sub(8)]
		if piece:IsA("MeshPart") and piece ~= ref and look then
			local clone = piece:Clone()
			clone.CFrame = origin * base:ToObjectSpace(piece.CFrame)
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.CastShadow = false
			clone.Color = look.color
			clone.Material = look.material
			clone.Parent = model
		end
	end
	return true
end

-- Isi rumah: ruang berperabot tepat di atas rumah (jauh di langit), dimasuki lewat pintu (PortalService).
local function clearInterior(house: House)
	local door = house.model:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		PortalService.removePortal(door)
	end
	local interior = house.interior
	if interior then
		-- Siapa pun yang masih di dalam dikembalikan ke depan rumah supaya tidak jatuh.
		local center = interior:GetPivot().Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character then character.PrimaryPart else nil
			if character and root and (root.Position - center).Magnitude < 40 then
				character:PivotTo(house.base * DOOR_FRONT)
			end
		end
		interior:Destroy()
		house.interior = nil
	end
end

local function buildInterior(house: House)
	clearInterior(house)
	local position = house.base.Position
	local origin = CFrame.new(position.X, HouseConfig.INTERIOR_HEIGHT, position.Z)
	local model = Instance.new("Model")
	model.Name = `IsiRumah_{house.id}`
	buildParts(model, origin, HouseConfig.INTERIOR, "ruang", true)
	if addFurniture(model, origin) then
		-- Perabot mesh terpasang: perabot part cukup jadi tabrakan yang tidak terlihat.
		for _, child in model:GetChildren() do
			local index = tonumber(child.Name:match("^ruang(%d+)$"))
			if index and index > HouseConfig.INTERIOR_SHELL_COUNT and child:IsA("BasePart") then
				child.Transparency = 1
				child.CastShadow = false
			end
		end
	end
	local exit = Instance.new("Part")
	exit.Name = "PintuKeluar"
	exit.Anchored = true
	exit.Size = Vector3.new(4.4, 7.4, 0.4)
	exit.CFrame = origin * HouseConfig.INTERIOR_DOOR
	exit.Color = Color3.fromRGB(120, 80, 50)
	exit.Material = Enum.Material.Wood
	exit.Parent = model
	model.Parent = itemFolder
	house.interior = model

	local door = house.model:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		PortalService.addPortal(door, `rumah{house.id}Luar`, `rumah{house.id}Dalam`, "Masuk")
		PortalService.addPortal(exit, `rumah{house.id}Dalam`, `rumah{house.id}Luar`, "Keluar")
	end
end

local function clearItem(house: House, slotIndex: number)
	local model = house.items[slotIndex]
	if model then
		model:Destroy()
		house.items[slotIndex] = nil
	end
end

local function applyPaint(house: House, hd: HouseData?)
	for slot, parts in house.groups do
		local palette = HouseConfig.PAINT[slot]
		local index = if hd then hd.paint[slot] else nil
		local color: Color3? = if type(index) == "number" then palette[index] else nil
		for _, part in parts do
			if color == nil then
				part.Color = house.original[part]
			elseif part.Name == "Garage" or part.Name == "ShellGarage" then
				part.Color = color:Lerp(Color3.new(1, 1, 1), 0.25)
			else
				part.Color = color
			end
		end
	end
end

local function applyItems(house: House, hd: HouseData?)
	for slotIndex in HouseConfig.YARD_SLOTS do
		clearItem(house, slotIndex)
		local itemId = if hd then hd.items[tostring(slotIndex)] else nil
		local def = if type(itemId) == "string" then HouseConfig.item(itemId) else nil
		if def then
			buildItem(house, slotIndex, def)
		end
	end
end

local function setSign(house: House, owner: Player?)
	if house.sign then
		house.sign:Destroy()
		house.sign = nil
	end
	local door = house.model:FindFirstChild("Door")
	if owner == nil or door == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PapanNama"
	gui.Size = UDim2.fromScale(12, 1.8)
	gui.StudsOffset = Vector3.new(0, 6, 3) -- maju ke arah kamera supaya tidak terpotong dinding
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "Rumah " .. owner.DisplayName
	label.Parent = gui
	gui.Parent = door
	house.sign = gui
end

local function claim(player: Player, house: House, hd: HouseData)
	house.owner = player
	byPlayer[player] = house
	house.model:SetAttribute(HouseConfig.ATTR_OWNER_ID, player.UserId)
	house.model:SetAttribute(HouseConfig.ATTR_OWNER_NAME, player.DisplayName)
	applyPaint(house, hd)
	applyItems(house, hd)
	buildInterior(house)
	setSign(house, player)
end

local function release(player: Player)
	local house = byPlayer[player]
	if house == nil then
		return
	end
	byPlayer[player] = nil
	house.owner = nil
	house.model:SetAttribute(HouseConfig.ATTR_OWNER_ID, 0)
	house.model:SetAttribute(HouseConfig.ATTR_OWNER_NAME, "")
	applyPaint(house, nil)
	applyItems(house, nil)
	clearInterior(house)
	setSign(house, nil)
end

-- Rumah kosong setipe yang paling dekat dengan rumah asli pemain.
local function findSubstitute(tier: string, near: Vector3): House?
	local best: House? = nil
	local bestDistance = math.huge
	for _, house in houses do
		if house.owner == nil and house.tier == tier then
			local distance = (house.base.Position - near).Magnitude
			if distance < bestDistance then
				best, bestDistance = house, distance
			end
		end
	end
	return best
end

local function onProfileLoaded(player: Player, data: Types.PlayerData)
	local hd = sanitize(data)
	if hd.id ~= 0 then
		local house = houses[hd.id]
		if house and house.owner == nil and house.tier == hd.tier then
			claim(player, house, hd)
		else
			local near = if house then house.base.Position else Vector3.zero
			local substitute = findSubstitute(hd.tier, near)
			if substitute then
				claim(player, substitute, hd)
				EconomyService.notify(
					player,
					"Rumahmu sedang ditempati, kamu dapat rumah pengganti dulu ya."
				)
			end
		end
	end
	publish(player)
end

-- ---------------------------------------------------------------- remote handler

local function buy(player: Player, houseId: any): HouseResult
	if not isInteger(houseId, 1, 100000) then
		return result(false, "Rumah tidak dikenal.")
	end
	local house = houses[houseId]
	local data = DataService.getData(player)
	if house == nil or data == nil then
		return result(false, "Rumah tidak dikenal.")
	end
	if data.house.id ~= 0 then
		return result(false, "Kamu sudah punya rumah. Jual dulu rumah lamamu kalau mau pindah.")
	end
	if house.owner ~= nil then
		return result(false, "Rumah ini sudah ada pemiliknya.")
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if
		root == nil
		or (root.Position - house.base.Position).Magnitude > HouseConfig.BUY_DISTANCE
	then
		return result(false, "Datangi dulu rumahnya ya.")
	end
	local tier = HouseConfig.tier(house.tier) :: HouseConfig.Tier
	if not EconomyService.trySpend(player, tier.price, "house:" .. tier.id) then
		return result(false, "Uangmu belum cukup. Harganya " .. Format.money(tier.price) .. ".")
	end
	local hd = emptyHouse()
	hd.id = house.id
	hd.tier = house.tier
	hd.boughtAt = os.time()
	data.house = hd
	claim(player, house, hd)
	publish(player)
	return result(true, "Selamat! " .. HouseConfig.address(house.id) .. " sekarang milikmu.")
end

local function sell(player: Player): HouseResult
	local data = DataService.getData(player)
	if data == nil or data.house.id == 0 then
		return result(false, "Kamu belum punya rumah.")
	end
	local refund = HouseConfig.sellPrice(data.house.tier)
	release(player)
	data.house = emptyHouse()
	if refund > 0 then
		EconomyService.addMoney(player, refund, "house:sell")
	end
	publish(player)
	return result(true, "Rumah terjual. Kamu dapat " .. Format.money(refund) .. ".")
end

local function paint(player: Player, slot: any, index: any): HouseResult
	local data = DataService.getData(player)
	local house = byPlayer[player]
	if data == nil or data.house.id == 0 or house == nil then
		return result(false, "Kamu belum punya rumah.")
	end
	local palette = if type(slot) == "string" then HouseConfig.PAINT[slot] else nil
	if palette == nil or not isInteger(index, 0, #palette) then
		return result(false, "Pilihan cat tidak dikenal.")
	end
	local hd = data.house
	if (hd.paint[slot] or 0) == index then
		return result(true, "Warnanya sudah itu.")
	end
	if
		index ~= 0 and not EconomyService.trySpend(player, HouseConfig.PAINT_PRICE, "house:paint")
	then
		return result(
			false,
			"Uangmu belum cukup untuk cat (" .. Format.money(HouseConfig.PAINT_PRICE) .. ")."
		)
	end
	hd.paint[slot] = index
	applyPaint(house, hd)
	publish(player)
	return result(true, if index == 0 then "Warna asli dikembalikan." else "Cat baru terpasang!")
end

local function setItem(player: Player, slotIndex: any, itemId: any): HouseResult
	local data = DataService.getData(player)
	local house = byPlayer[player]
	if data == nil or data.house.id == 0 or house == nil then
		return result(false, "Kamu belum punya rumah.")
	end
	if not isInteger(slotIndex, 1, #HouseConfig.YARD_SLOTS) or type(itemId) ~= "string" then
		return result(false, "Pilihan hiasan tidak dikenal.")
	end
	local hd = data.house
	local key = tostring(slotIndex)
	if itemId == "" then
		hd.items[key] = nil
		clearItem(house, slotIndex)
		publish(player)
		return result(true, "Hiasan disimpan ke gudang.")
	end
	local def = HouseConfig.item(itemId)
	if def == nil then
		return result(false, "Pilihan hiasan tidak dikenal.")
	end
	if hd.items[key] == itemId then
		return result(true, "Hiasan itu sudah terpasang di sana.")
	end
	if not EconomyService.trySpend(player, def.price, "house:item:" .. def.id) then
		return result(false, "Uangmu belum cukup. Harganya " .. Format.money(def.price) .. ".")
	end
	hd.items[key] = itemId
	clearItem(house, slotIndex)
	buildItem(house, slotIndex, def)
	publish(player)
	return result(true, def.name .. " terpasang di halaman!")
end

local function goHome(player: Player): HouseResult
	local house = byPlayer[player]
	if house == nil then
		return result(false, "Kamu belum punya rumah.")
	end
	local now = os.clock()
	local last = lastHome[player]
	if last and now - last < HouseConfig.HOME_COOLDOWN then
		local left = math.ceil(HouseConfig.HOME_COOLDOWN - (now - last))
		return result(false, `Tunggu {left} detik lagi sebelum pulang.`)
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return result(false, "Belum bisa pulang sekarang.")
	end
	lastHome[player] = now
	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.15)
	end
	character:PivotTo(house.base * DOOR_FRONT)
	return result(true, "Selamat datang di rumah!")
end

-- ---------------------------------------------------------------- API server

-- Rumah yang ditempati pemain di server ini (untuk sistem lain, mis. misi).
function HouseService.getHomePosition(player: Player): Vector3?
	local house = byPlayer[player]
	return if house then (house.base * DOOR_FRONT).Position else nil
end

-- ---------------------------------------------------------------- bootstrap

local function registerHouse(model: Model)
	local id = tonumber(model.Name:match("^Rumah(%d+)$"))
	local body = model:FindFirstChild("Body")
	local door = model:FindFirstChild("Door")
	if id == nil or houses[id] ~= nil or body == nil or door == nil then
		return
	end
	if not body:IsA("BasePart") or not door:IsA("BasePart") then
		return
	end
	local garage = model:FindFirstChild("Garage")
	local stories = if body.Size.Y > TWO_STORY_HEIGHT then 2 else 1
	local house: House = {
		id = id,
		model = model,
		base = body.CFrame * CFrame.new(0, -body.Size.Y / 2 - FOUNDATION_HEIGHT, 0),
		tier = HouseConfig.tierFor(stories, garage ~= nil),
		owner = nil,
		groups = { wall = {}, roof = {}, door = {} },
		original = {},
		items = {},
		interior = nil,
		sign = nil,
	}
	-- Shell* = part rumah modern dari map/StyleHouses.luau (part lama tetap ada tapi disembunyikan).
	local slotByName = {
		Body = "wall",
		Garage = "wall",
		RoofFront = "roof",
		RoofBack = "roof",
		Door = "door",
		ShellWall = "wall",
		ShellGarage = "wall",
		ShellRoof = "roof",
		ShellDoor = "door",
	}
	for _, child in model:GetChildren() do
		local slot = slotByName[child.Name]
		if slot and child:IsA("BasePart") then
			table.insert(house.groups[slot], child)
			house.original[child] = child.Color
		end
	end
	houses[id] = house

	model:SetAttribute(HouseConfig.ATTR_ID, id)
	model:SetAttribute(HouseConfig.ATTR_TIER, house.tier)
	model:SetAttribute(HouseConfig.ATTR_OWNER_ID, 0)
	model:SetAttribute(HouseConfig.ATTR_OWNER_NAME, "")
	CollectionService:AddTag(model, HouseConfig.TAG_HOUSE)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LihatRumah"
	prompt.ActionText = "Lihat rumah"
	prompt.ObjectText = HouseConfig.address(id)
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(HouseConfig.ATTR_PROMPT, id)
	prompt.Parent = door
end

local function bind(name: string, handler: (Player, ...any) -> HouseResult)
	Net.func(name).OnServerInvoke = function(player: Player, ...: any)
		if not allowCall(player) then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		local ok, value = pcall(handler, player, ...)
		if ok then
			return value
		end
		warn(`[House] {name} error: {tostring(value)}`)
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

function HouseService.init()
	itemFolder = Instance.new("Folder")
	itemFolder.Name = "HiasanRumah"
	itemFolder.Parent = Workspace

	local map = Workspace:FindFirstChild("Map")
	local zone = if map then map:FindFirstChild("Neighborhoods") else nil
	local folder = if zone then zone:FindFirstChild("Houses") else nil
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				registerHouse(child)
			end
		end
	else
		warn("[House] Workspace.Map.Neighborhoods.Houses tidak ditemukan")
	end

	bind(Net.Names.HouseBuy, buy)
	bind(Net.Names.HouseSell, sell)
	bind(Net.Names.HousePaint, paint)
	bind(Net.Names.HouseItem, setItem)
	bind(Net.Names.HouseGoHome, goHome)
end

function HouseService.start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if
			data
			and byPlayer[player] == nil
			and player:GetAttribute(HouseConfig.ATTR_PLAYER) == nil
		then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		release(player)
		lastCall[player] = nil
		lastHome[player] = nil
	end)
end

return HouseService
