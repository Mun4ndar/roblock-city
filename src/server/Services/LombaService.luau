--!strict
-- LombaService: lomba 17-an saat event HUT Kemerdekaan RI (Agustus).
--   * Balap karung: tekan E di garis start -> kaki masuk karung; lompat terus (spasi) untuk maju;
--     garis finis menghitung waktu; hadiah menurut waktu (IndonesiaConfig.LOMBA.karung.rewards).
--   * Panjat pinang: tekan E di tiang -> ketuk tombol TAP berulang untuk memanjat, merosot pelan kalau
--     berhenti; yang sampai puncak dapat hadiah, hadiah muncul lagi beberapa detik kemudian.
-- Arena (tag LombaKarungStart/LombaKarungFinish/LombaPinang) hanya ada di dunia selama event berlangsung
-- (map/BuildLomba -> ServerStorage.EventDecor.agustus.Lomba). Semua aturan dicek server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IndonesiaConfig = require(Shared:WaitForChild("IndonesiaConfig"))
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local LombaService = {}

local KARUNG = IndonesiaConfig.LOMBA.karung
local PINANG = IndonesiaConfig.LOMBA.pinang
local BASE_SPEED = 16

type Race = {
	startTime: number,
	startPad: BasePart,
	finishPad: BasePart,
	sack: Model?,
	hopConn: RBXScriptConnection?,
	humanoid: Humanoid,
	hopToken: number,
}
type Climb = {
	pole: BasePart,
	height: number,
	lastTap: number,
	startTime: number,
	axis: Vector3,
	groundY: number,
	sideDir: Vector3,
	track: AnimationTrack?,
	humanoid: Humanoid,
	root: BasePart,
}

local races: { [Player]: Race } = {}
local climbs: { [Player]: Climb } = {}
local cooldowns: { [Player]: number } = {}
local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

local function eventActive(): boolean
	return Workspace:GetAttribute(RetentionConfig.EVENT_ATTR) == "agustus"
end

local function aliveParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function normalSpeed(player: Player): number
	local expires = player:GetAttribute(IndonesiaConfig.BUFF_ATTR)
	if type(expires) == "number" and expires > Workspace:GetServerTimeNow() then
		return BASE_SPEED + IndonesiaConfig.BUFF_SPEED
	end
	return BASE_SPEED
end

-- ---------------------------------------------------------------- balap karung

local function wearSack(player: Player, root: BasePart): Model?
	local source = ServerStorage:FindFirstChild("AsetPasar")
	local tpl = if source then source:FindFirstChild("karung") else nil
	if tpl == nil or not tpl:IsA("Model") then
		return nil
	end
	local sack = tpl:Clone()
	sack.Name = "KarungGoni"
	sack:ScaleTo(0.78)
	sack:PivotTo(root.CFrame * CFrame.new(0, -1.55, 0))
	for _, d in sack:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	sack.Parent = player.Character
	return sack
end

local function endRace(player: Player, message: string?)
	local race = races[player]
	if race == nil then
		return
	end
	races[player] = nil
	if race.hopConn then
		race.hopConn:Disconnect()
	end
	if race.sack then
		race.sack:Destroy()
	end
	if race.humanoid.Parent then
		race.humanoid.WalkSpeed = normalSpeed(player)
		race.humanoid.JumpHeight = 7.2
	end
	player:SetAttribute(IndonesiaConfig.ATTR_RACE_START, nil)
	stateRemote:FireClient(player, "raceEnd")
	if message then
		notify(player, message)
	end
end

local function startRace(player: Player, pad: BasePart)
	if not eventActive() then
		notify(player, "Lomba 17-an hanya ada selama event HUT RI.")
		return
	end
	if races[player] or climbs[player] then
		return
	end
	local humanoid, root = aliveParts(player)
	if humanoid == nil or root == nil or humanoid.SeatPart ~= nil then
		notify(player, "Turun dari kendaraan dulu ya.")
		return
	end
	if (root.Position - pad.Position).Magnitude > 20 then
		return
	end
	local left = (cooldowns[player] or 0) - os.clock()
	if left > 0 then
		notify(player, `Istirahat dulu {math.ceil(left)} detik.`)
		return
	end
	local finishPad: BasePart? = nil
	local best = math.huge
	for _, inst in CollectionService:GetTagged(IndonesiaConfig.TAG_KARUNG_FINISH) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			local d = (inst.Position - pad.Position).Magnitude
			if d < best then
				best, finishPad = d, inst
			end
		end
	end
	if finishPad == nil then
		return
	end
	cooldowns[player] = os.clock() + KARUNG.cooldown
	local race: Race = {
		startTime = os.clock(),
		startPad = pad,
		finishPad = finishPad,
		sack = wearSack(player, root),
		hopConn = nil,
		humanoid = humanoid,
		hopToken = 0,
	}
	races[player] = race
	humanoid.WalkSpeed = KARUNG.baseSpeed
	humanoid.JumpHeight = 3
	race.hopConn = humanoid.Jumping:Connect(function(active: boolean)
		if not active or races[player] ~= race then
			return
		end
		race.hopToken += 1
		local token = race.hopToken
		humanoid.WalkSpeed = KARUNG.hopSpeed
		task.delay(KARUNG.hopSeconds, function()
			if races[player] == race and race.hopToken == token then
				humanoid.WalkSpeed = KARUNG.baseSpeed
			end
		end)
	end)
	player:SetAttribute(IndonesiaConfig.ATTR_RACE_START, Workspace:GetServerTimeNow())
	stateRemote:FireClient(player, "race", Workspace:GetServerTimeNow(), KARUNG.timeLimit)
	notify(player, "Mulai! Lompat terus (spasi) menuju garis finis!")
end

local function finishRace(player: Player, race: Race)
	local elapsed = os.clock() - race.startTime
	if elapsed < KARUNG.minTime then
		endRace(player, "Wah, terlalu cepat. Coba lagi dengan jujur ya!")
		return
	end
	local reward = KARUNG.rewards[#KARUNG.rewards]
	for _, tier in KARUNG.rewards do
		if elapsed <= tier.maxTime then
			reward = tier
			break
		end
	end
	local paid = EconomyService.addMoney(player, reward.pay, "lomba:karung")
	endRace(
		player,
		`🏁 {reward.title}! Waktumu {string.format("%.1f", elapsed)} detik.{if paid
			then ` Hadiah ${reward.pay}.`
			else ""}`
	)
end

local function raceTick()
	for player, race in races do
		local humanoid, root = aliveParts(player)
		if
			humanoid == nil
			or root == nil
			or race.startPad.Parent == nil
			or race.finishPad.Parent == nil
		then
			endRace(player, nil)
			continue
		end
		local elapsed = os.clock() - race.startTime
		if elapsed > KARUNG.timeLimit then
			endRace(player, "⏱️ Waktu habis. Coba lagi nanti ya!")
			continue
		end
		if humanoid.SeatPart ~= nil then
			endRace(player, "Lomba dibatalkan.")
			continue
		end
		local axis = race.finishPad.Position - race.startPad.Position
		local flat = Vector3.new(axis.X, 0, axis.Z)
		local length = flat.Magnitude
		local dir = flat.Unit
		local rel = root.Position - race.startPad.Position
		local along = rel.X * dir.X + rel.Z * dir.Z
		local side = math.abs(rel.X * dir.Z - rel.Z * dir.X)
		if side > 14 then
			endRace(player, "Kamu keluar jalur lomba.")
		elseif along >= length - 1.5 then
			finishRace(player, race)
		end
	end
end

-- ---------------------------------------------------------------- panjat pinang

local PRIZE_NAMES = { "Hadiah", "Tali", "Pita" }

local function setPrizeVisible(pole: Instance, visible: boolean)
	for _, d in pole:GetDescendants() do
		if d:IsA("BasePart") then
			for _, key in PRIZE_NAMES do
				if d.Name:sub(1, #key) == key then
					d.Transparency = if visible then 0 else 1
				end
			end
		end
	end
end

local function climbPosition(c: Climb): CFrame
	local pos = Vector3.new(c.axis.X, c.groundY + 3.2 + c.height, c.axis.Z)
		+ c.sideDir * PINANG.radius
	return CFrame.lookAt(pos, Vector3.new(c.axis.X, pos.Y, c.axis.Z))
end

local function endClimb(player: Player, message: string?)
	local c = climbs[player]
	if c == nil then
		return
	end
	climbs[player] = nil
	if c.track then
		c.track:Stop(0.1)
	end
	player:SetAttribute(IndonesiaConfig.ATTR_CLIMB, nil)
	if c.root.Parent then
		c.root.Anchored = false
		c.root.CFrame = CFrame.new(Vector3.new(c.axis.X, c.groundY + 3.5, c.axis.Z) + c.sideDir * 5)
	end
	stateRemote:FireClient(player, "climbEnd")
	if message then
		notify(player, message)
	end
end

local function reachTop(player: Player, c: Climb)
	local pole = c.pole
	local model = pole.Parent
	if pole:GetAttribute("Claimed") == true then
		endClimb(player, "Hadiahnya sudah diambil orang lain. Tunggu sebentar ya!")
		return
	end
	pole:SetAttribute("Claimed", true)
	local prompt = pole:FindFirstChild("PinangPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
	local paid = EconomyService.addMoney(player, PINANG.pay, "lomba:pinang")
	endClimb(
		player,
		`🎉 Hadiah panjat pinang diraih!{if paid then ` Kamu dapat ${PINANG.pay}.` else ""}`
	)
	if model then
		setPrizeVisible(model, false)
		task.delay(PINANG.resetSeconds, function()
			if pole.Parent then
				pole:SetAttribute("Claimed", nil)
				setPrizeVisible(model, true)
				local p = pole:FindFirstChild("PinangPrompt")
				if p and p:IsA("ProximityPrompt") then
					p.Enabled = true
				end
			end
		end)
	end
end

local function startClimb(player: Player, pole: BasePart)
	if not eventActive() then
		notify(player, "Lomba 17-an hanya ada selama event HUT RI.")
		return
	end
	if races[player] or climbs[player] or pole:GetAttribute("Claimed") == true then
		return
	end
	local humanoid, root = aliveParts(player)
	if humanoid == nil or root == nil or humanoid.SeatPart ~= nil then
		return
	end
	if (root.Position - pole.Position).Magnitude > 40 then
		return
	end
	local axis = Vector3.new(pole.Position.X, 0, pole.Position.Z)
	local away = Vector3.new(root.Position.X - axis.X, 0, root.Position.Z - axis.Z)
	local sideDir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local c: Climb = {
		pole = pole,
		height = 0,
		lastTap = 0,
		startTime = os.clock(),
		axis = axis,
		groundY = pole.Position.Y - pole.Size.Y / 2,
		sideDir = sideDir,
		track = nil,
		humanoid = humanoid,
		root = root,
	}
	climbs[player] = c
	root.Anchored = true
	root.CFrame = climbPosition(c)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://507765644" -- animasi memanjat bawaan Roblox
		local ok, track = pcall(function(): AnimationTrack
			return animator:LoadAnimation(animation)
		end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.1)
			track:AdjustSpeed(0)
			c.track = track
		end
	end
	player:SetAttribute(IndonesiaConfig.ATTR_CLIMB, 0)
	stateRemote:FireClient(player, "climb", PINANG.height)
	notify(player, "Ketuk TAP berulang-ulang untuk memanjat!")
end

local function tap(player: Player)
	local c = climbs[player]
	if c == nil then
		return
	end
	local now = os.clock()
	if now - c.lastTap < PINANG.minTapInterval then
		return
	end
	c.lastTap = now
	c.height = math.min(PINANG.height, c.height + PINANG.tapGain)
	if c.track then
		c.track:AdjustSpeed(1)
	end
	if c.root.Parent then
		c.root.CFrame = climbPosition(c)
	end
	player:SetAttribute(IndonesiaConfig.ATTR_CLIMB, math.floor(c.height * 10) / 10)
	if c.height >= PINANG.height then
		reachTop(player, c)
	end
end

local function climbTick(dt: number)
	for player, c in climbs do
		if c.humanoid.Parent == nil or c.humanoid.Health <= 0 or c.root.Parent == nil then
			climbs[player] = nil
			player:SetAttribute(IndonesiaConfig.ATTR_CLIMB, nil)
			continue
		end
		if os.clock() - c.startTime > PINANG.timeLimit then
			endClimb(player, "⏱️ Waktu habis, kamu turun. Coba lagi ya!")
			continue
		end
		if os.clock() - c.lastTap > 0.35 then
			c.height = math.max(0, c.height - PINANG.decay * dt)
			c.root.CFrame = climbPosition(c)
			if c.track then
				c.track:AdjustSpeed(0)
			end
			player:SetAttribute(IndonesiaConfig.ATTR_CLIMB, math.floor(c.height * 10) / 10)
		end
	end
end

-- ---------------------------------------------------------------- pendaftaran tag

local function registerKarungStart(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("KarungPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KarungPrompt"
	prompt.ActionText = "Ikut balap karung"
	prompt.ObjectText = "Lomba 17-an"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		startRace(player, inst)
	end)
	prompt.Parent = inst
end

local function registerPinang(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("PinangPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PinangPrompt"
	prompt.ActionText = "Panjat pinang"
	prompt.ObjectText = "Lomba 17-an"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		startClimb(player, inst)
	end)
	prompt.Parent = inst
end

local function bind(tag: string, handler: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(handler)
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(Workspace) then
			handler(inst)
		end
	end
end

function LombaService.init()
	stateRemote = Net.event("LombaState")
	notifyRemote = Net.event(Net.Names.Notify)
	Net.event("LombaTap").OnServerEvent:Connect(function(player: Player)
		tap(player)
	end)
	Net.event("LombaLeave").OnServerEvent:Connect(function(player: Player)
		endClimb(player, nil)
		endRace(player, "Lomba dibatalkan.")
	end)
	bind(IndonesiaConfig.TAG_KARUNG_START, registerKarungStart)
	bind(IndonesiaConfig.TAG_PINANG, registerPinang)
end

function LombaService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		if next(races) then
			raceTick()
		end
		if next(climbs) then
			climbTick(step)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		endRace(player, nil)
		climbs[player] = nil
		cooldowns[player] = nil
	end)
end

return LombaService
