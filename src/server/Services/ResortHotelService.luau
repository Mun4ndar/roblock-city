--!strict
--[[
	ResortHotelService: menginap di Resort ROBLOCK (lantai kamar di y +2000, dibangun map/BuildResortLantai).
	  * Tamu: setelah check-in di resepsionis (ResortService) pemain mendapat atribut "ResortGuestUntil"
	    (waktu server). Hanya tamu yang boleh naik lift dan tidur; turun ke lobi selalu boleh.
	  * Lift: dua kabin (tag "ResortLift", atribut Level "lobi"/"lantai") dengan pintu geser (tag "ResortLiftDoor",
	    atribut Slide). Pemain memilih lantai lewat pemilih lantai yang sama dengan Hotel Bintang Kota
	    (HotelController: remote HotelLiftMenu/HotelLiftGo). Lantai 2-8 = ilusi, tiba di koridor yang sama.
	  * Tidur: pelat tak terlihat bertag "ResortBed" (+Z lokal = arah kepala): prompt Tidur/Bangun,
	    pemain telentang (jangkar + PlatformStand), atribut "HotelTidur" memunculkan tombol Bangun (HotelWake).
	  * Kamera Zoom di dalam resor dan di lantai kamar: dinding menahan kamera, tidak jadi transparan.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local ResortHotelService = {}

local BASE = CFrame.new(1249, 1, -460) * CFrame.Angles(0, -math.pi / 2, 0)
local GUEST_SECONDS = 1800
local LIFT_NEAR = 7
local DOOR_CLOSE_SECONDS = 0.9
local STEP_SECONDS = 0.8
local SLEEP_RANGE = 12
local LIE_LIFT = 0.45
local FLOORS = 8

type Lift = {
	model: Model,
	level: string,
	zone: BasePart,
	doors: { BasePart },
	closed: { [BasePart]: CFrame },
	busy: boolean,
	isOpen: boolean,
}

local lifts: { Lift } = {}
local byLevel: { [string]: Lift } = {}
local menuRemote: RemoteEvent
local goRemote: RemoteEvent
local wakeRemote: RemoteEvent
local sleepers: { [Player]: { bed: BasePart, prompt: ProximityPrompt } } = {}
local bedUser: { [BasePart]: Player } = {}
local savedOcclusion: { [Player]: Enum.DevCameraOcclusionMode } = {}
local shownFloor: { [Player]: number } = {}

local function rootAndHuman(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

function ResortHotelService.isGuest(player: Player): boolean
	local untilTime = player:GetAttribute("ResortGuestUntil")
	return typeof(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow()
end

-- dipanggil ResortService saat check-in
function ResortHotelService.grantGuest(player: Player)
	player:SetAttribute("ResortGuestUntil", Workspace:GetServerTimeNow() + GUEST_SECONDS)
end

local function insideZone(zone: BasePart, position: Vector3): boolean
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Y) <= half.Y + 3 and math.abs(rel.Z) <= half.Z + 0.5
end

-- bagian dalam resor (lobi) atau lantai kamar: kamera Zoom
local function isInsideResort(position: Vector3): boolean
	local p = BASE:PointToObjectSpace(position) -- (x, z_blender, -y_blender)
	local bx, by, bz = p.X, -p.Z, p.Y
	if bz > 1500 then
		return bx > -40 and bx < 33 and by > -21 and by < 21
	end
	return math.abs(bx) < 71 and math.abs(by) < 21 and bz > -2 and bz < 12
end

-- ------------------------------------------------------------------ lift
local function setDoors(lift: Lift, open: boolean)
	if lift.isOpen == open then
		return
	end
	lift.isOpen = open
	for _, door in lift.doors do
		local closed = lift.closed[door]
		local slide = door:GetAttribute("Slide")
		if closed and typeof(slide) == "Vector3" then
			local target = if open then closed + slide else closed
			TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target }):Play()
		end
	end
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local zone = model:FindFirstChild("Dalam")
	local level = model:GetAttribute("Level")
	if not (zone and zone:IsA("BasePart") and typeof(level) == "string") or byLevel[level] ~= nil then
		return
	end
	local doors: { BasePart } = {}
	local closed: { [BasePart]: CFrame } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and CollectionService:HasTag(child, "ResortLiftDoor") then
			table.insert(doors, child)
			closed[child] = child.CFrame.Rotation + child.Position
		end
	end
	local lift: Lift = { model = model, level = level, zone = zone, doors = doors, closed = closed, busy = false, isOpen = false }
	table.insert(lifts, lift)
	byLevel[level] = lift
	local plate = model:FindFirstChild("PanelPilih")
	if plate and plate:IsA("BasePart") and plate:FindFirstChild("PilihLantai") == nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PilihLantai"
		prompt.ActionText = "Pilih lantai"
		prompt.ObjectText = "Lift Resort"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player: Player)
			if lift.busy then
				return
			end
			local root = rootAndHuman(player)
			if root == nil or not insideZone(lift.zone, root.Position) then
				return
			end
			local current = if level == "lobi" then 1 else (shownFloor[player] or 2)
			menuRemote:FireClient(player, current)
		end)
		prompt.Parent = plate
	end
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
	local dest = if floor == 1 then byLevel.lobi else byLevel.lantai
	if dest == nil or (dest ~= src and dest.busy) then
		return
	end
	if dest.level == "lantai" and not ResortHotelService.isGuest(player) then
		EconomyService.notify(player, "Check-in dulu di meja resepsionis untuk naik ke kamar.")
		return
	end
	if dest == src then
		shownFloor[player] = floor
		EconomyService.notify(player, `Lantai {floor}`)
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
	setDoors(dest, false)
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
		task.wait(DOOR_CLOSE_SECONDS)
		task.wait(STEP_SECONDS * math.min(3, math.abs(floor - 1)))
		local out = dest.zone:GetAttribute("Out")
		local outDir = if typeof(out) == "Vector3" then out else Vector3.new(1, 0, 0)
		local spot = Vector3.new(dest.zone.Position.X, dest.zone.Position.Y - dest.zone.Size.Y / 2 + 3.2, dest.zone.Position.Z)
		for _, rider in riders do
			local character = rider.Character
			if character then
				character:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(outDir.X, 0, outDir.Z)))
			end
			shownFloor[rider] = floor
		end
		task.wait(0.4)
		setDoors(dest, true)
		for _, rider in riders do
			EconomyService.notify(rider, if floor == 1 then "Lantai L (lobi)" else `Lantai {floor}`)
		end
	end)
	if not ok then
		warn("[ResortHotelService] lift:", err)
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
		player.Character:PivotTo(CFrame.new(state.bed.CFrame:PointToWorldSpace(Vector3.new(3.6, 1.8, 0))))
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
	if not ResortHotelService.isGuest(player) then
		EconomyService.notify(player, "Check-in dulu di meja resepsionis untuk menginap.")
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
	player.Character:PivotTo(bed.CFrame * CFrame.new(0, LIE_LIFT, 0.4) * CFrame.Angles(math.pi / 2, 0, 0))
	sleepers[player] = { bed = bed, prompt = prompt }
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
	if not bed:IsA("BasePart") or bed:FindFirstChild("TidurPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TidurPrompt"
	prompt.ActionText = "Tidur"
	prompt.ObjectText = "Kasur kamar"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		sleep(player, bed, prompt)
	end)
	prompt.Parent = bed
end

-- ------------------------------------------------------------------ mulai
function ResortHotelService.init()
	menuRemote = Net.event(Net.Names.HotelLiftMenu)
	goRemote = Net.event(Net.Names.HotelLiftGo)
	wakeRemote = Net.event(Net.Names.HotelWake)
end

function ResortHotelService.start()
	for _, model in CollectionService:GetTagged("ResortLift") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("ResortLift"):Connect(register)
	for _, bed in CollectionService:GetTagged("ResortBed") do
		registerBed(bed)
	end
	CollectionService:GetInstanceAddedSignal("ResortBed"):Connect(registerBed)

	goRemote.OnServerEvent:Connect(function(player: Player, floor: unknown)
		if typeof(floor) ~= "number" or floor % 1 ~= 0 or floor < 1 or floor > FLOORS then
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
			shownFloor[player] = nil
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		wake(player, true)
		savedOcclusion[player] = nil
		shownFloor[player] = nil
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
				local inside = isInsideResort(root.Position)
				local saved = savedOcclusion[player]
				if inside and saved == nil then
					savedOcclusion[player] = player.DevCameraOcclusionMode
					player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
				elseif not inside and saved ~= nil then
					player.DevCameraOcclusionMode = saved
					savedOcclusion[player] = nil
				end
			end
		end
		for _, lift in lifts do
			if not lift.busy then
				local door = lift.zone:GetAttribute("DoorPos")
				local doorPosition = if typeof(door) == "Vector3" then door else lift.zone.Position
				local near = false
				for _, position in positions do
					if math.abs(position.Y - lift.zone.Position.Y) <= 6.5 then
						local dx, dz = position.X - doorPosition.X, position.Z - doorPosition.Z
						if dx * dx + dz * dz <= LIFT_NEAR * LIFT_NEAR or insideZone(lift.zone, position) then
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

return ResortHotelService
