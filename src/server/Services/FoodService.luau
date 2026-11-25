--!strict
-- FoodService: jajanan Indonesia.
--   * warung dan lapak (part bertag "FoodStall", atribut StallMenu + StallName) menjual makanan
--     di menu IndonesiaConfig.MENUS; beli = uang berkurang, dapat "kenyang semangat" (lari lebih cepat)
--   * pasar malam: lapak di ServerStorage.PasarMalam.Malam dipasang ke Workspace.Map.PasarMalam hanya
--     saat jam dunia 17.30-02.00; festival kuliner (akhir pekan WIB): folder Festival + diskon harga
--   * musik koplo dari speaker pasar (Sound 3D) selama buka

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local FoodService = {}

local TAG = "FoodStall"
local BASE_SPEED = 16
local CALL_COOLDOWN = 0.4

local menuRemote: RemoteEvent
local lastCall: { [Player]: number } = {}
local mounts: { Malam: Folder?, Festival: Folder? } = {}
local forcedFestival: boolean? = nil -- uji (DebugService)
local forcedOpen: boolean? = nil

-- ---------------------------------------------------------------- waktu buka

local function isFestival(): boolean
	if forcedFestival ~= nil then
		return forcedFestival
	end
	local now = os.date("!*t", os.time() + IndonesiaConfig.PASAR_UTC_OFFSET * 3600)
	return now.wday == 1 or now.wday == 7 -- Minggu atau Sabtu
end

local function isPasarOpen(): boolean
	if forcedOpen ~= nil then
		return forcedOpen
	end
	local clock = Lighting.ClockTime
	return clock >= IndonesiaConfig.PASAR_OPEN_FROM or clock < IndonesiaConfig.PASAR_OPEN_TO
end

function FoodService.force(open: boolean?, festival: boolean?)
	forcedOpen = open
	forcedFestival = festival
end

-- ---------------------------------------------------------------- lapak

local function registerStall(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if inst:FindFirstChild("JajanPrompt") then
		return
	end
	local menuId = inst:GetAttribute("StallMenu")
	if type(menuId) ~= "string" or IndonesiaConfig.MENUS[menuId] == nil then
		return
	end
	local name = inst:GetAttribute("StallName")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JajanPrompt"
	prompt.ActionText = "Jajan"
	prompt.ObjectText = if type(name) == "string" then name else "Warung"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		menuRemote:FireClient(player, menuId, prompt.ObjectText)
	end)
	prompt.Parent = inst
end

local function stallNear(player: Player, menuId: string): boolean
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if root == nil then
		return false
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		if
			inst:IsA("BasePart")
			and inst:IsDescendantOf(Workspace)
			and inst:GetAttribute("StallMenu") == menuId
			and (inst.Position - root.Position).Magnitude <= IndonesiaConfig.BUY_DISTANCE
		then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- buff

local function applyBuff(player: Player)
	local expires = player:GetAttribute(IndonesiaConfig.BUFF_ATTR)
	if type(expires) ~= "number" or expires <= Workspace:GetServerTimeNow() then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.WalkSpeed <= BASE_SPEED + 0.5 then
		humanoid.WalkSpeed = BASE_SPEED + IndonesiaConfig.BUFF_SPEED
	end
end

local function endBuff(player: Player, token: number)
	if player:GetAttribute(IndonesiaConfig.BUFF_ATTR) ~= token then
		return
	end
	player:SetAttribute(IndonesiaConfig.BUFF_ATTR, nil)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid
		and math.abs(humanoid.WalkSpeed - (BASE_SPEED + IndonesiaConfig.BUFF_SPEED)) < 0.5
	then
		humanoid.WalkSpeed = BASE_SPEED
	end
end

local function startBuff(player: Player)
	local expires = Workspace:GetServerTimeNow() + IndonesiaConfig.BUFF_SECONDS
	player:SetAttribute(IndonesiaConfig.BUFF_ATTR, expires)
	applyBuff(player)
	task.delay(IndonesiaConfig.BUFF_SECONDS, function()
		endBuff(player, expires)
	end)
end

-- ---------------------------------------------------------------- beli

local function buy(player: Player, menuId: any, foodId: any): { ok: boolean, message: string }
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < CALL_COOLDOWN then
		return { ok = false, message = "Pelan-pelan ya." }
	end
	lastCall[player] = now
	if type(menuId) ~= "string" or type(foodId) ~= "string" then
		return { ok = false, message = "Pesanan tidak valid." }
	end
	local menu = IndonesiaConfig.MENUS[menuId]
	local food = IndonesiaConfig.FOODS[foodId]
	if menu == nil or food == nil or table.find(menu, foodId) == nil then
		return { ok = false, message = "Menu itu tidak dijual di sini." }
	end
	if not stallNear(player, menuId) then
		return { ok = false, message = "Dekati lapaknya dulu ya." }
	end
	local price = food.price
	if Workspace:GetAttribute(IndonesiaConfig.ATTR_FESTIVAL) == true then
		price = math.ceil(price * IndonesiaConfig.FESTIVAL_DISCOUNT)
	end
	if not EconomyService.trySpend(player, price, "jajan:" .. foodId) then
		return { ok = false, message = "Uangmu belum cukup." }
	end
	startBuff(player)
	return {
		ok = true,
		message = `{food.icon} {food.name} enak! Kenyang semangat {IndonesiaConfig.BUFF_SECONDS} detik: lari lebih cepat.`,
	}
end

-- ---------------------------------------------------------------- pasar malam

local function playlist(speaker: BasePart, tracks: { number })
	local sound = Instance.new("Sound")
	sound.Name = "MusikPasar"
	sound.Volume = 0.7
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 14
	sound.RollOffMaxDistance = 110
	sound.Parent = speaker
	task.spawn(function()
		local index = 0
		while speaker.Parent ~= nil and sound.Parent ~= nil do
			index = index % #tracks + 1
			sound.SoundId = "rbxassetid://" .. tracks[index]
			sound:Play()
			local started = os.clock()
			repeat
				task.wait(1)
			until not sound.IsPlaying and os.clock() - started > 3 or speaker.Parent == nil
		end
	end)
end

local function mount(name: "Malam" | "Festival", on: boolean, mountRoot: Folder)
	local current = mounts[name]
	if on == (current ~= nil) then
		return
	end
	if not on then
		if current then
			current:Destroy()
		end
		mounts[name] = nil
		return
	end
	local source = ServerStorage:FindFirstChild("PasarMalam")
	local group = if source then source:FindFirstChild(name) else nil
	if group == nil then
		return
	end
	local copy = group:Clone()
	copy.Name = name
	copy.Parent = mountRoot
	mounts[name] = copy
	if name == "Malam" then
		local speaker = copy:FindFirstChild("SpeakerPasar")
		local station = IndonesiaConfig.station("koplo")
		if speaker and speaker:IsA("BasePart") and station then
			playlist(speaker, station.tracks)
		end
	end
end

local function update(mountRoot: Folder)
	local open = isPasarOpen()
	local festival = isFestival()
	Workspace:SetAttribute(IndonesiaConfig.ATTR_PASAR, open)
	Workspace:SetAttribute(IndonesiaConfig.ATTR_FESTIVAL, festival)
	mount("Malam", open, mountRoot)
	mount("Festival", festival, mountRoot)
end

-- ---------------------------------------------------------------- bootstrap

function FoodService.init()
	menuRemote = Net.event("FoodMenu")
	Net.func("FoodBuy").OnServerInvoke = function(player: Player, menuId: any, foodId: any): any
		local ok, value = pcall(buy, player, menuId, foodId)
		if ok then
			return value
		end
		warn("[Food] buy error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi." }
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(registerStall)
	for _, inst in CollectionService:GetTagged(TAG) do
		registerStall(inst)
	end
end

function FoodService.start()
	local map = Workspace:FindFirstChild("Map")
	-- Warung Creator Store yang sudah ada di peta ikut berjualan.
	local toko = if map then map:FindFirstChild("Toko") else nil
	local warung = if toko then toko:FindFirstChild("Warung") else nil
	if warung and warung:IsA("Model") then
		local main = warung.PrimaryPart
		if main == nil then
			for _, d in warung:GetDescendants() do
				if
					d:IsA("BasePart") and (main == nil or d.Size.Magnitude > main.Size.Magnitude)
				then
					main = d
				end
			end
		end
		if main then
			main:SetAttribute("StallMenu", "warung")
			main:SetAttribute("StallName", "Warung")
			CollectionService:AddTag(main, TAG)
		end
	end

	local mountRoot = Instance.new("Folder")
	mountRoot.Name = "PasarMalam"
	mountRoot.Parent = map or Workspace
	update(mountRoot)
	task.spawn(function()
		while true do
			task.wait(4)
			update(mountRoot)
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyBuff(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
end

return FoodService
