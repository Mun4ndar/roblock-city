--!strict
--[[
	HotelService: Hotel Bintang Kota.
	  * Lift: dua kabin kembar (lantai lobi dan lantai koridor), pintu geser otomatis saat pemain mendekat.
	    Pemain memilih lantai lewat panel di dalam kabin (prompt -> HotelController); pintu menutup, lampu
	    indikator menyala berurutan per lantai (atribut pemain "HotelLamp"), pemain dipindah ke kabin tujuan
	    dan nomor lantai di koridor ikut ("HotelFloor", dibaca client untuk label bertag HotelLabel).
	  * Tidur: prompt di kasir kamar (tag "HotelBed"): pemain berbaring telentang di kasur (jangkar + PlatformStand).
	  * Resepsionis: prompt "CheckIn" di meja lobi memberi sapaan dan petunjuk.
	Bangunan dibuat oleh map/BuildHotel* (Studio, Workspace.Map.Hotel).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local HotelConfig = require(Shared:WaitForChild("HotelConfig"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local HotelService = {}

type Lift = {
	model: Model,
	level: string,
	zone: BasePart,
	doors: { BasePart },
	busy: boolean,
	isOpen: boolean,
}

type Sleeper = { bed: BasePart, prompt: ProximityPrompt, human: Humanoid? }

local lifts: { Lift } = {}
local byLevel: { [string]: Lift } = {}
local menuRemote: RemoteEvent
local goRemote: RemoteEvent
local wakeRemote: RemoteEvent
local sleepers: { [Player]: Sleeper } = {}
local bedUser: { [BasePart]: Player } = {}
local lastWelcome: { [Player]: number } = {}

local LIFT_NEAR = 7 -- jarak mendatar ke tengah pintu yang membuka pintu lift
local SLEEP_RANGE = 12
local LIE_LIFT = 0.45 -- tinggi pusat badan telentang di atas pelat TempatTidur

local function rootAndHuman(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?,
		character:FindFirstChildOfClass("Humanoid")
end

local function insideZone(zone: BasePart, position: Vector3): boolean
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X + 0.5
		and math.abs(rel.Y) <= half.Y + 3
		and math.abs(rel.Z) <= half.Z + 0.5
end

-- ------------------------------------------------------------------ lift

local function setDoors(lift: Lift, open: boolean)
	if lift.isOpen == open then
		return
	end
	lift.isOpen = open
	for _, door in lift.doors do
		local closed = door:GetAttribute("Closed")
		local slide = door:GetAttribute("Slide")
		if typeof(closed) == "CFrame" and typeof(slide) == "Vector3" then
			local target = if open then closed + slide else closed
			TweenService:Create(
				door,
				TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ CFrame = target }
			):Play()
		end
	end
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local zone = model:FindFirstChild("Dalam")
	local level = model:GetAttribute("Level")
	if
		not (zone and zone:IsA("BasePart") and typeof(level) == "string")
		or byLevel[level] ~= nil
	then
		return
	end
	local doors: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and CollectionService:HasTag(child, "HotelLiftDoor") then
			table.insert(doors, child)
		end
	end
	local lift: Lift =
		{ model = model, level = level, zone = zone, doors = doors, busy = false, isOpen = false }
	table.insert(lifts, lift)
	byLevel[level] = lift
	local plate = model:FindFirstChild("PanelPilih")
	local prompt = if plate then plate:FindFirstChild("PilihLantai") else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			if lift.busy then
				return
			end
			local root = rootAndHuman(player)
			if root == nil or not insideZone(lift.zone, root.Position) then
				return
			end
			local current = player:GetAttribute("HotelLamp")
			menuRemote:FireClient(
				player,
				if typeof(current) == "number" then current else (if level == "lobi" then 1 else 2)
			)
		end)
	end
end

local function currentLamp(player: Player, lift: Lift): number
	local value = player:GetAttribute("HotelLamp")
	if typeof(value) == "number" then
		return value
	end
	return if lift.level == "lobi" then 1 else 2
end

local function ride(player: Player, floor: number)
	local root = rootAndHuman(player)
	if root == nil then
		return
	end
	local src: Lift? = nil
	for _, lift in lifts do
		if insideZone(lift.zone, root.Position) then
			src = lift
			break
		end
	end
	if src == nil or src.busy then
		return
	end
	local from = currentLamp(player, src)
	if floor == from then
		return
	end
	local dest = if floor == 1 then byLevel.lobi else byLevel.lantai
	if dest == nil or (dest ~= src and dest.busy) then
		return
	end
	local riders: { Player } = {}
	for _, other in Players:GetPlayers() do
		local r = rootAndHuman(other)
		if r and insideZone(src.zone, r.Position) then
			table.insert(riders, other)
		end
	end
	src.busy = true
	dest.busy = true
	setDoors(src, false)
	if dest ~= src then
		setDoors(dest, false)
	end
	local saved: { [Player]: { speed: number, jump: number } } = {}
	for _, rider in riders do
		local _, human = rootAndHuman(rider)
		if human then
			saved[rider] = { speed = human.WalkSpeed, jump = human.JumpHeight }
			human.WalkSpeed = 0
			human.JumpHeight = 0
		end
	end
	local ok, err = pcall(function()
		task.wait(HotelConfig.DOOR_CLOSE_SECONDS)
		local step = if floor > from then 1 else -1
		local lamp = from
		while lamp ~= floor do
			lamp += step
			for _, rider in riders do
				rider:SetAttribute("HotelLamp", lamp)
			end
			task.wait(HotelConfig.STEP_SECONDS)
		end
		if dest ~= src then
			local from_: Lift = src :: Lift
			for _, rider in riders do
				local r = rootAndHuman(rider)
				local character = rider.Character
				if r and character then
					local relative = from_.zone.CFrame:ToObjectSpace(r.CFrame)
					character:PivotTo(dest.zone.CFrame * relative)
				end
			end
			task.wait(0.4)
		end
		for _, rider in riders do
			rider:SetAttribute("HotelFloor", if floor > 1 then floor else 0)
			rider:SetAttribute("HotelLamp", floor)
		end
		setDoors(dest, true)
	end)
	if not ok then
		warn("[HotelService] lift:", err)
	end
	for rider, values in saved do
		local _, human = rootAndHuman(rider)
		if human then
			human.WalkSpeed = values.speed
			human.JumpHeight = values.jump
		end
	end
	src.busy = false
	dest.busy = false
end

-- ------------------------------------------------------------------ tidur

local function wake(player: Player, silent: boolean?)
	local state = sleepers[player]
	if state == nil then
		return
	end
	sleepers[player] = nil
	if bedUser[state.bed] == player then
		bedUser[state.bed] = nil
	end
	state.prompt.ActionText = "Tidur"
	player:SetAttribute("HotelTidur", nil)
	local root, human = rootAndHuman(player)
	if root and human and player.Character then
		root.Anchored = false
		human.PlatformStand = false
		local beside = state.bed.CFrame:PointToWorldSpace(Vector3.new(4.2, 1.8, 0))
		player.Character:PivotTo(CFrame.new(beside))
		local head = player.Character:FindFirstChild("Head")
		local tag = if head then head:FindFirstChild("ZzzTidur") else nil
		if tag then
			tag:Destroy()
		end
	end
	if not silent then
		EconomyService.notify(player, "Kamu bangun dengan segar. Selamat beraktivitas!")
	end
end

local function sleep(player: Player, bed: BasePart, prompt: ProximityPrompt)
	if sleepers[player] ~= nil then
		wake(player)
		return
	end
	local owner = bedUser[bed]
	if owner ~= nil and owner ~= player then
		EconomyService.notify(player, "Kasur ini sedang dipakai tamu lain.")
		return
	end
	local root, human = rootAndHuman(player)
	if root == nil or human == nil or human.Health <= 0 or player.Character == nil then
		return
	end
	if (root.Position - bed.Position).Magnitude > SLEEP_RANGE then
		return
	end
	human.Sit = false
	human.PlatformStand = true
	root.Anchored = true
	-- sumbu Z lokal pelat = arah kepala; putar 90 derajat pada X supaya telentang menghadap atas
	player.Character:PivotTo(
		bed.CFrame * CFrame.new(0, LIE_LIFT, 0.4) * CFrame.Angles(math.pi / 2, 0, 0)
	)
	sleepers[player] = { bed = bed, prompt = prompt, human = human }
	bedUser[bed] = player
	prompt.ActionText = "Bangun"
	player:SetAttribute("HotelTidur", true)
	local head = player.Character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "ZzzTidur"
		gui.Size = UDim2.fromOffset(90, 40)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = "Zzz..."
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(190, 220, 255)
		text.TextStrokeTransparency = 0.5
		text.Parent = gui
		gui.Parent = head
	end
	human.Died:Once(function()
		wake(player, true)
	end)
	EconomyService.notify(player, "Selamat tidur! Tekan Bangun kalau sudah cukup istirahat.")
end

local function registerBed(bed: Instance)
	if not bed:IsA("BasePart") then
		return
	end
	local prompt = bed:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		sleep(player, bed, prompt)
	end)
end

-- ------------------------------------------------------------------ resepsionis

local function registerBell(bell: Instance)
	local prompt = bell:FindFirstChild("CheckIn")
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastWelcome[player] or -100) < HotelConfig.WELCOME_COOLDOWN then
			return
		end
		lastWelcome[player] = now
		EconomyService.notify(
			player,
			"Selamat datang di Hotel Bintang Kota! Naik lift di tengah lobi, pilih lantai 2-8, lalu istirahat di kasur kamar."
		)
	end)
end

-- ------------------------------------------------------------------ mulai

function HotelService.init()
	menuRemote = Net.event(Net.Names.HotelLiftMenu)
	goRemote = Net.event(Net.Names.HotelLiftGo)
	wakeRemote = Net.event(Net.Names.HotelWake)
end

function HotelService.start()
	for _, model in CollectionService:GetTagged("HotelLift") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("HotelLift"):Connect(register)
	for _, bed in CollectionService:GetTagged("HotelBed") do
		registerBed(bed)
	end
	CollectionService:GetInstanceAddedSignal("HotelBed"):Connect(registerBed)
	local map = Workspace:FindFirstChild("Map")
	local hotel = if map then map:FindFirstChild("Hotel") else nil
	local bell = if hotel then hotel:FindFirstChild("LoncengCheckIn", true) else nil
	if bell then
		registerBell(bell)
	end

	goRemote.OnServerEvent:Connect(function(player: Player, floor: unknown)
		if
			typeof(floor) ~= "number"
			or floor % 1 ~= 0
			or floor < 1
			or floor > HotelConfig.FLOORS
		then
			return
		end
		task.spawn(ride, player, floor)
	end)
	wakeRemote.OnServerEvent:Connect(function(player: Player)
		wake(player)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			wake(player, true)
			player:SetAttribute("HotelLamp", nil)
			player:SetAttribute("HotelFloor", 0)
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		wake(player, true)
		lastWelcome[player] = nil
	end)

	local timer = 0
	RunService.Heartbeat:Connect(function(dt: number)
		timer += dt
		if timer < 0.25 then
			return
		end
		timer = 0
		local positions: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local root = rootAndHuman(player)
			if root then
				table.insert(positions, root.Position)
			end
		end
		for _, lift in lifts do
			if not lift.busy then
				local zonePosition = lift.zone.Position
				local doorPosition = zonePosition + Vector3.new(0, 0, -4.5)
				local near = false
				for _, position in positions do
					if math.abs(position.Y - zonePosition.Y) <= 6.5 then
						local dx, dz = position.X - doorPosition.X, position.Z - doorPosition.Z
						if
							dx * dx + dz * dz <= LIFT_NEAR * LIFT_NEAR
							or insideZone(lift.zone, position)
						then
							near = true
							break
						end
					end
				end
				setDoors(lift, near)
			end
		end
	end)
end

return HotelService
