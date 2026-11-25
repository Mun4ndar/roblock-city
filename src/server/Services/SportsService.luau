--!strict
-- SportsService: warga NPC bermain di lapangan + mini-game untuk pemain.
--   * Lapangan sepak bola sekolah: penyerang dan kiper NPC berlatih tendangan ke gawang barat.
--     Pemain menekan E di titik penalti -> adu penalti 5 tendangan melawan kiper NPC (bidik + tenaga).
--   * Tiap lapangan basket: penembak dan pengambil bola NPC berlatih di ring pertama.
--     Pemain menekan E di garis lempar bebas ring kedua -> 5 lemparan (arah + tenaga).
-- Semua animasi NPC memakai animasi resmi Roblox lewat Animator (gerak sendi dari skrip tidak tampil pada
-- avatar modern). Semua aturan (hasil, hadiah, jarak, jeda) dihitung server; client hanya mengirim angka
-- bidikan 0..1 dan menampilkan hasilnya. Lapangan dibaca dari dunia; tidak ada bagian peta yang diubah.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local SportsConfig = require(Shared:WaitForChild("SportsConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local SportsService = {}

local FOOT = SportsConfig.FOOTBALL
local BASK = SportsConfig.BASKET
local ANIM = SportsConfig.ANIM
local GROUP_NPC = "Npc"
local SPAWN_RANGE = 140
local DESPAWN_RANGE = 200
local TAG = "SportsSpot"
local rng = Random.new()
local rgb = Color3.fromRGB

-- ---------------------------------------------------------------- tipe

type Tracks = { [string]: AnimationTrack }
type Actor = { model: Model, humanoid: Humanoid, root: BasePart, tracks: Tracks }

type Station = {
	kind: string, -- "football" | "basket"
	center: Vector3,
	groundY: number,
	-- sepak bola
	goalPos: Vector3?, -- tengah garis gawang (tanah)
	inward: Vector3, -- arah dari gawang/ring ke tengah lapangan (datar)
	-- basket
	hoopNpc: Vector3?, -- ring tempat NPC berlatih
	hoopPlayer: Vector3?, -- ring tempat pemain melempar
	inwardNpc: Vector3?,
	-- runtime
	spot: BasePart?, -- cakram titik pemain
	folder: Folder?,
	spawned: boolean,
	token: number,
	actors: { Actor },
	balls: { Model },
	busyPlayer: Player?,
	keeper: Actor?,
	keeperControlled: boolean,
}

type Game = {
	mode: string,
	token: string,
	station: Station,
	shots: number,
	taken: number,
	score: number,
	perfect: number, -- lemparan "swish"
	state: string, -- "aim" | "busy"
	askedAt: number,
	deadline: number,
	ball: Model?,
	root: BasePart,
	humanoid: Humanoid,
	cheer: AnimationTrack?,
	reward: number,
	spotCFrame: CFrame,
	alive: boolean,
}

local stations: { Station } = {}
local games: { [Player]: Game } = {}
local cooldowns: { [Player]: number } = {}
local earned: { [Player]: { window: number, amount: number } } = {}
local stateRemote: RemoteEvent
local actorFolder: Folder

-- ---------------------------------------------------------------- pembantu umum

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.001 then f.Unit else Vector3.new(1, 0, 0)
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

local function playerWithin(position: Vector3, range: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		if root and (root.Position - position).Magnitude <= range then
			return true
		end
	end
	return false
end

local function loadTrack(
	humanoid: Humanoid,
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

-- ---------------------------------------------------------------- bola

local function weldPart(
	parent: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType
): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = parent.CFrame * offset
	p.Parent = parent.Parent
	return p
end

-- Bola buatan sendiri: bola putih dengan bercak hitam (sepak bola) atau bola oranye dengan garis (basket).
-- Semua bagian di-anchor; bola digerakkan dengan PivotTo oleh skrip server.
local function makeBall(kind: string): Model
	local model = Instance.new("Model")
	model.Name = if kind == "bola" then "BolaSepak" else "BolaBasket"
	local radius = if kind == "bola" then 1 else 0.8
	local core = Instance.new("Part")
	core.Name = "Bola"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * radius * 2
	core.Color = if kind == "bola" then rgb(250, 250, 250) else rgb(236, 120, 40)
	core.Material = Enum.Material.SmoothPlastic
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Parent = model
	model.PrimaryPart = core
	if kind == "bola" then
		local dark = rgb(30, 30, 34)
		for _, dir in
			{
				Vector3.xAxis,
				-Vector3.xAxis,
				Vector3.yAxis,
				-Vector3.yAxis,
				Vector3.zAxis,
				-Vector3.zAxis,
			}
		do
			local patch = weldPart(
				core,
				Vector3.one * 0.62 * radius,
				CFrame.new(dir * radius * 0.93),
				dark,
				Enum.PartType.Ball
			)
			patch.Name = "Bercak"
		end
	else
		local line = rgb(40, 28, 24)
		for _, rot in
			{
				CFrame.identity,
				CFrame.Angles(0, 0, math.rad(90)),
				CFrame.Angles(math.rad(90), 0, 0),
			}
		do
			local band = weldPart(
				core,
				Vector3.new(0.06, radius * 2 + 0.03, radius * 2 + 0.03),
				rot * CFrame.Angles(0, 0, math.rad(90)),
				line,
				Enum.PartType.Cylinder
			)
			band.Name = "Garis"
		end
	end
	return model
end

-- Bagian pendamping ikut bergerak: dilas ringan dengan menghitung posisi relatif saat PivotTo.
local function placeBall(ball: Model, cf: CFrame)
	ball:PivotTo(cf)
end

-- Terbang dari p0 ke p1 dalam `seconds`, melengkung setinggi `arc` di tengah. fall = percepatan ke bawah.
local function flyBall(
	ball: Model,
	p0: Vector3,
	p1: Vector3,
	seconds: number,
	arc: number,
	fall: boolean?
)
	local started = os.clock()
	local spinAxis =
		Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	if spinAxis.Magnitude < 0.1 then
		spinAxis = Vector3.xAxis
	end
	spinAxis = spinAxis.Unit
	while ball.Parent do
		local u = math.clamp((os.clock() - started) / seconds, 0, 1)
		local mix = if fall then u * u else u
		local pos = p0:Lerp(p1, mix) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
		placeBall(ball, CFrame.new(pos) * CFrame.fromAxisAngle(spinAxis, u * seconds * 9))
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Jatuh ke tanah lalu memantul dua kali sambil bergeser ke arah roll.
local function dropBall(ball: Model, from: Vector3, floorY: number, radius: number, roll: Vector3)
	local rest = Vector3.new(from.X, floorY + radius, from.Z)
	local fallTime = math.sqrt(2 * math.max(from.Y - rest.Y, 0.2) / 140)
	flyBall(ball, from, rest, fallTime, 0, true)
	local second = rest + roll * 0.55
	flyBall(ball, rest, second, 0.4, math.min(2.4, 0.4 + (from.Y - rest.Y) * 0.2))
	local third = second + roll * 0.25
	flyBall(ball, second, third, 0.25, 0.6)
end

-- ---------------------------------------------------------------- aktor NPC (avatar R15 dengan seragam)

type Look = {
	shirt: Color3,
	shorts: Color3,
	socks: Color3,
	skin: Color3,
	hair: Color3,
	gloves: Color3?,
}

local function buildActor(name: string, look: Look, position: Vector3): Actor?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftLegColor = look.skin
	description.RightLegColor = look.skin
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Sports] gagal membuat NPC: " .. tostring(model))
		return nil
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if
		humanoid == nil
		or head == nil
		or not head:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
	then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 10
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") then
			child:Destroy()
		end
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local n = d.Name
			if n:match("Foot$") then
				d.Color = rgb(30, 30, 34)
			elseif n:match("LowerLeg$") then
				d.Color = look.socks
			elseif n:match("UpperLeg$") or n == "LowerTorso" then
				d.Color = look.shorts
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				d.Color = look.shirt
			elseif n:match("Hand$") and look.gloves then
				d.Color = look.gloves
			elseif n ~= "HumanoidRootPart" then
				d.Color = look.skin
			end
		end
	end
	local hair = Instance.new("Part")
	hair.Name = "Rambut"
	hair.Shape = Enum.PartType.Ball
	hair.Size = Vector3.new(1.42, 1.3, 1.42)
	hair.Color = look.hair
	hair.Material = Enum.Material.SmoothPlastic
	hair.Massless = true
	hair.CanCollide = false
	hair.CanQuery = false
	hair.CanTouch = false
	hair.CFrame = head.CFrame * CFrame.new(0, 0.36, 0.08)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hair
	weld.Parent = hair
	hair.Parent = model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			pcall(function()
				d.CollisionGroup = GROUP_NPC
			end)
			d.CanTouch = false
		end
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = actorFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local tracks: Tracks = {
		idle = loadTrack(humanoid, ANIM.idle, Enum.AnimationPriority.Idle, true),
		walk = loadTrack(humanoid, ANIM.walk, Enum.AnimationPriority.Movement, true),
		run = loadTrack(humanoid, ANIM.run, Enum.AnimationPriority.Movement, true),
		cheer = loadTrack(humanoid, ANIM.cheer, Enum.AnimationPriority.Action, false),
		jump = loadTrack(humanoid, ANIM.jump, Enum.AnimationPriority.Action, false),
	}
	tracks.idle:Play()
	humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			local use = if speed > 10.5 then tracks.run else tracks.walk
			local other = if speed > 10.5 then tracks.walk else tracks.run
			other:Stop(0.15)
			if not use.IsPlaying then
				use:Play(0.15)
			end
			use:AdjustSpeed(if speed > 10.5 then speed / 14 else speed / 9)
		else
			tracks.walk:Stop(0.2)
			tracks.run:Stop(0.2)
		end
	end)
	return { model = model, humanoid = humanoid, root = root, tracks = tracks }
end

local function faceTo(actor: Actor, target: Vector3)
	local here = actor.root.Position
	local flatTarget = Vector3.new(target.X, here.Y, target.Z)
	if (flatTarget - here).Magnitude > 0.1 then
		actor.model:PivotTo(CFrame.lookAt(here, flatTarget))
	end
end

-- Berjalan/berlari ke titik di tanah; selesai kalau dekat atau waktu habis. onStep dipanggil tiap 0.1 detik.
local function walkTo(
	actor: Actor,
	target: Vector3,
	speed: number,
	timeout: number,
	onStep: (() -> ())?
): boolean
	actor.humanoid.WalkSpeed = speed
	actor.humanoid:MoveTo(target)
	local began = os.clock()
	while actor.model.Parent and os.clock() - began < timeout do
		local d =
			Vector3.new(actor.root.Position.X - target.X, 0, actor.root.Position.Z - target.Z).Magnitude
		if d < 2.2 then
			return true
		end
		actor.humanoid:MoveTo(target)
		if onStep then
			onStep()
		end
		task.wait(0.1)
	end
	return false
end

local function stopActor(actor: Actor)
	actor.humanoid:MoveTo(actor.root.Position)
end

-- ---------------------------------------------------------------- sepak bola: hasil tendangan

type Kick = {
	outcome: string, -- goal | save | post | bar | wide | over | weak
	target: Vector3, -- titik bola di garis gawang
	flight: number,
	dive: number, -- -1 kiri / 0 tengah / 1 kanan (dari sudut pandang penendang: +1 = z lebih besar)
	keeperReach: Vector3,
}

local function evaluateKick(
	goal: Vector3,
	aimX: number,
	aimY: number,
	power: number,
	groundY: number
): Kick
	local dz = aimX * FOOT.aimRangeX
	local ty = groundY + FOOT.aimLow + aimY * FOOT.aimSpan
	if power > 0.9 then
		dz += rng:NextNumber(-1.6, 1.6)
		ty += rng:NextNumber(-1, 1.2)
	end
	-- kiper memilih arah sebelum melihat bola; sesekali menebak sisi bidikan
	local dive: number
	local roll = rng:NextNumber()
	if roll < 0.15 and math.abs(aimX) > 0.25 then
		dive = if aimX > 0 then 1 else -1
	elseif roll < 0.55 then
		dive = -1
	elseif roll < 0.75 then
		dive = 0
	else
		dive = 1
	end
	local diveZ = dive * 5.2
	local reach = (3.8 - 1.4 * power) * (if dive == 0 then 0.8 else 1)
	local maxY = groundY + (if dive == 0 then 4.4 else 5.2)
	local onGoal = math.abs(dz) <= FOOT.goalHalf
		and ty <= groundY + FOOT.goalTop
		and ty >= groundY + 0.9
	local outcome: string
	if power < 0.2 then
		outcome = "weak"
	elseif onGoal then
		outcome = if math.abs(dz - diveZ) <= reach and ty <= maxY then "save" else "goal"
	elseif math.abs(dz) <= FOOT.goalHalf + 2 and ty <= groundY + FOOT.goalTop + 1.6 then
		outcome = if ty > groundY + FOOT.goalTop then "bar" else "post"
	elseif math.abs(dz) > FOOT.goalHalf + 2 then
		outcome = "wide"
	else
		outcome = "over"
	end
	local target = Vector3.new(goal.X, ty, goal.Z + dz)
	local flight = 1.15 - 0.65 * power
	local reachY = math.clamp(ty, groundY + 1.5, maxY)
	return {
		outcome = outcome,
		target = target,
		flight = flight,
		dive = dive,
		keeperReach = Vector3.new(
			goal.X,
			reachY,
			goal.Z + (if outcome == "save" or outcome == "weak" then dz else diveZ)
		),
	}
end

local function keeperHome(st: Station): Vector3
	local goal = st.goalPos :: Vector3
	return goal + st.inward * 2.4 + Vector3.new(0, 3.05, 0)
end

local function keeperDive(st: Station, kick: Kick)
	local keeper = st.keeper
	if keeper == nil or keeper.model.Parent == nil then
		return
	end
	keeper.root.Anchored = true
	keeper.tracks.walk:Stop(0.1)
	keeper.tracks.run:Stop(0.1)
	local home = keeperHome(st)
	local forward = st.inward
	local dest = home
	local roll = 0
	if kick.outcome == "weak" or kick.outcome == "save" then
		dest = Vector3.new(home.X, kick.keeperReach.Y - 0.6, kick.keeperReach.Z)
	else
		dest = Vector3.new(
			home.X,
			home.Y + (if kick.dive == 0 then 0.8 else 0.5),
			(st.goalPos :: Vector3).Z + kick.dive * 5.2
		)
	end
	if kick.dive ~= 0 and kick.outcome ~= "weak" then
		roll = -kick.dive * math.rad(75)
	elseif kick.outcome == "save" then
		roll = -math.sign(kick.keeperReach.Z - (st.goalPos :: Vector3).Z) * math.rad(60)
	end
	local base = CFrame.lookAt(dest, dest + forward)
	keeper.tracks.jump:Play(0.05)
	local tween = TweenService:Create(
		keeper.root,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = base * CFrame.Angles(0, 0, roll) }
	)
	tween:Play()
end

local function keeperReset(st: Station)
	local keeper = st.keeper
	if keeper == nil or keeper.model.Parent == nil then
		return
	end
	local home = keeperHome(st)
	keeper.root.Anchored = true
	local tween = TweenService:Create(
		keeper.root,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad),
		{ CFrame = CFrame.lookAt(home, home + st.inward) }
	)
	tween:Play()
	tween.Completed:Wait()
	if not st.keeperControlled then
		keeper.root.Anchored = false
	end
end

-- Animasi satu tendangan: bola terbang, kiper menyelam, bola berakhir sesuai hasil. Menunggu sampai selesai.
local function playKick(st: Station, ball: Model, from: Vector3, kick: Kick)
	local goal = st.goalPos :: Vector3
	local floorY = st.groundY
	local side = Vector3.new(0, 0, if kick.target.Z >= goal.Z then 1 else -1)
	task.spawn(function()
		task.wait(kick.flight * 0.25)
		keeperDive(st, kick)
	end)
	if kick.outcome == "weak" then
		local stop = from + (kick.target - from) * 0.8
		flyBall(ball, from, Vector3.new(stop.X, floorY + 1, stop.Z), 1.6, 0.5)
		return
	end
	local straight = (kick.target - from).Magnitude
	flyBall(ball, from, kick.target, kick.flight, 0.5 + straight * 0.015)
	local out = -st.inward
	if kick.outcome == "goal" then
		local into = kick.target + out * 3
		flyBall(ball, kick.target, Vector3.new(into.X, kick.target.Y - 2, into.Z), 0.3, 0)
		dropBall(ball, Vector3.new(into.X, kick.target.Y - 2, into.Z), floorY, 1, out * 1.4)
	elseif kick.outcome == "save" then
		local deflect = kick.target + side * 3.5 + st.inward * 2
		flyBall(ball, kick.target, Vector3.new(deflect.X, deflect.Y - 1.5, deflect.Z), 0.35, 0.8)
		dropBall(
			ball,
			Vector3.new(deflect.X, deflect.Y - 1.5, deflect.Z),
			floorY,
			1,
			st.inward * 1.5
		)
	elseif kick.outcome == "post" or kick.outcome == "bar" then
		local back = kick.target + st.inward * 7 + side * (if kick.outcome == "post" then 3 else 0)
		flyBall(ball, kick.target, Vector3.new(back.X, floorY + 1, back.Z), 0.7, 3)
		dropBall(ball, Vector3.new(back.X, floorY + 1, back.Z), floorY, 1, st.inward * 1.2)
	else
		local beyond = kick.target + out * 8 + side * 1.5
		flyBall(ball, kick.target, Vector3.new(beyond.X, floorY + 1, beyond.Z), 0.7, 1.5)
		dropBall(ball, Vector3.new(beyond.X, floorY + 1, beyond.Z), floorY, 1, out * 1.2)
	end
end

local KICK_TEXT: { [string]: string } = {
	goal = "GOL! ⚽",
	save = "Ditangkap kiper! 🧤",
	post = "Kena tiang gawang!",
	bar = "Kena mistar!",
	wide = "Melebar!",
	over = "Terlalu tinggi!",
	weak = "Terlalu pelan, kiper menangkapnya",
}

-- ---------------------------------------------------------------- basket: hasil lemparan

type Throw = {
	outcome: string, -- swish | made | rimin | rim | air
	landing: Vector3, -- titik bola di bidang ring
	flight: number,
}

local function evaluateThrow(hoop: Vector3, inward: Vector3, aimX: number, power: number): Throw
	local perp = Vector3.new(-inward.Z, 0, inward.X)
	local lat = aimX * BASK.aimRange
	local depth = (power - BASK.sweetPower) * BASK.depthRange
	local d = math.sqrt(lat * lat + depth * depth)
	local outcome: string
	if d <= BASK.swishRadius then
		outcome = "swish"
	elseif d <= BASK.madeRadius then
		outcome = "made"
	elseif d <= BASK.rimInRadius and rng:NextNumber() < 0.4 then
		outcome = "rimin"
	elseif d <= BASK.rimMissRadius then
		outcome = "rim"
	else
		outcome = "air"
	end
	-- depth > 0 = melambung jauh (menuju papan), < 0 = pendek (ke arah penembak)
	local landing = hoop - inward * depth + perp * lat
	return { outcome = outcome, landing = landing, flight = 1.0 }
end

local function playThrow(
	st: Station,
	ball: Model,
	hoop: Vector3,
	inward: Vector3,
	from: Vector3,
	throw: Throw
)
	local floorY = st.groundY
	local landing = Vector3.new(throw.landing.X, hoop.Y, throw.landing.Z)
	local arcHeight = 4.5 + (from - landing).Magnitude * 0.12
	if throw.outcome == "swish" or throw.outcome == "made" or throw.outcome == "rimin" then
		local target = if throw.outcome == "rimin"
			then hoop + (landing - hoop) * 0.3
			else (if throw.outcome == "swish" then hoop else hoop + (landing - hoop) * 0.5)
		flyBall(ball, from, Vector3.new(target.X, hoop.Y + 0.4, target.Z), throw.flight, arcHeight)
		local down = Vector3.new(hoop.X, floorY + 0.8, hoop.Z)
		flyBall(
			ball,
			Vector3.new(target.X, hoop.Y + 0.4, target.Z),
			Vector3.new(down.X, hoop.Y - 3.2, down.Z),
			0.28,
			0,
			true
		)
		dropBall(ball, Vector3.new(down.X, hoop.Y - 3.2, down.Z), floorY, 0.8, inward * 1.2)
	elseif throw.outcome == "rim" then
		flyBall(
			ball,
			from,
			Vector3.new(landing.X, hoop.Y + 0.3, landing.Z),
			throw.flight,
			arcHeight
		)
		local away = flat(landing - hoop) * 3.5 + inward * 2.2
		local drop = Vector3.new(landing.X + away.X, hoop.Y - 1.5, landing.Z + away.Z)
		flyBall(ball, Vector3.new(landing.X, hoop.Y + 0.3, landing.Z), drop, 0.45, 2.2)
		dropBall(ball, drop, floorY, 0.8, inward * 1.4)
	else
		local finish = landing
			+ (if (landing - hoop):Dot(inward) < 0 then inward * 3 else -inward * 4)
		flyBall(
			ball,
			from,
			Vector3.new(finish.X, floorY + 0.8, finish.Z),
			throw.flight + 0.2,
			arcHeight * 0.7
		)
		dropBall(ball, Vector3.new(finish.X, floorY + 2.4, finish.Z), floorY, 0.8, inward * 1.2)
	end
end

local THROW_TEXT: { [string]: string } = {
	swish = "Swish! 🏀",
	made = "Masuk! 🏀",
	rimin = "Menyentuh ring, tapi masuk!",
	rim = "Kena ring, belum masuk",
	air = "Meleset jauh!",
}

-- ---------------------------------------------------------------- NPC sepak bola

local function footballLoop(st: Station, token: number)
	local goal = st.goalPos :: Vector3
	local ball = makeBall("bola")
	ball.Parent = st.folder
	table.insert(st.balls, ball)
	local striker: Actor? = nil
	for _, a in st.actors do
		if a.model.Name == "Penyerang" then
			striker = a
		end
	end
	if striker == nil then
		return
	end
	local ballPos = function(a: Actor): Vector3
		return a.root.Position
			+ a.root.CFrame.LookVector * 2.8
			+ Vector3.new(0, st.groundY + 1 - a.root.Position.Y, 0)
	end
	local function ballFollow()
		local s = striker :: Actor
		local t = os.clock()
		placeBall(ball, CFrame.new(ballPos(s)) * CFrame.Angles(t * 6, 0, 0))
	end
	while st.token == token and ball.Parent do
		if st.keeperControlled then
			-- pemain sedang adu penalti: penyerang menepi di tengah lapangan
			stopActor(striker)
			placeBall(
				ball,
				CFrame.new(
					striker.root.Position
						+ striker.root.CFrame.LookVector * 2.8
						+ Vector3.new(0, st.groundY + 1 - striker.root.Position.Y, 0)
				)
			)
			task.wait(0.5)
			continue
		end
		-- ambil bola di tengah lapangan, lalu giring ke posisi tembak
		local spotTarget = goal
			+ st.inward * rng:NextNumber(20, 28)
			+ Vector3.new(0, 0, rng:NextNumber(-9, 9))
		local s = striker
		local startAt = st.center + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		walkTo(s, startAt, 12, 8, nil)
		if st.token ~= token then
			break
		end
		faceTo(s, spotTarget)
		walkTo(s, spotTarget, 11, 9, ballFollow)
		if st.token ~= token or st.keeperControlled then
			continue
		end
		stopActor(s)
		faceTo(s, goal)
		ballFollow()
		task.wait(0.5)
		-- tembak
		local from = ballPos(s)
		local kick = evaluateKick(
			goal,
			rng:NextNumber(-0.9, 0.9),
			rng:NextNumber(0.05, 0.9),
			rng:NextNumber(0.45, 0.85),
			st.groundY
		)
		playKick(st, ball, from, kick)
		if kick.outcome == "goal" then
			s.tracks.cheer:Play(0.1)
		elseif st.keeper then
			st.keeper.tracks.cheer:Play(0.1)
		end
		task.wait(1.3)
		if not st.keeperControlled then
			keeperReset(st)
		end
		-- bola kembali ke kaki penyerang di tengah lapangan
		if st.token ~= token then
			break
		end
		placeBall(ball, CFrame.new(Vector3.new(startAt.X, st.groundY + 1, startAt.Z)))
		task.wait(rng:NextNumber(0.6, 1.6))
	end
	ball:Destroy()
end

local function keeperPatrol(st: Station, token: number)
	while st.token == token do
		task.wait(rng:NextNumber(2.5, 5))
		local keeper = st.keeper
		if keeper == nil or keeper.model.Parent == nil or st.token ~= token then
			return
		end
		if st.keeperControlled or keeper.root.Anchored then
			continue
		end
		local home = keeperHome(st)
		local goalZ = (st.goalPos :: Vector3).Z
		local target = Vector3.new(home.X, home.Y, goalZ + rng:NextNumber(-3.5, 3.5))
		walkTo(keeper, target, 6, 5, nil)
		stopActor(keeper)
		faceTo(keeper, keeper.root.Position + st.inward * 5)
	end
end

local function spawnFootball(st: Station, token: number)
	local home = keeperHome(st)
	local keeper = buildActor("Kiper", {
		shirt = rgb(250, 190, 40),
		shorts = rgb(40, 40, 48),
		socks = rgb(250, 190, 40),
		skin = rgb(224, 172, 120),
		hair = rgb(30, 26, 26),
		gloves = rgb(235, 90, 90),
	}, home)
	if keeper == nil or st.token ~= token then
		if keeper then
			keeper.model:Destroy()
		end
		return
	end
	keeper.model:PivotTo(CFrame.lookAt(home, home + st.inward))
	st.keeper = keeper
	table.insert(st.actors, keeper)
	local striker = buildActor("Penyerang", {
		shirt = rgb(220, 60, 60),
		shorts = rgb(245, 245, 240),
		socks = rgb(220, 60, 60),
		skin = rgb(168, 116, 76),
		hair = rgb(30, 26, 26),
	}, st.center + Vector3.new(0, 3, 0))
	if striker == nil or st.token ~= token then
		if striker then
			striker.model:Destroy()
		end
		return
	end
	table.insert(st.actors, striker)
	task.spawn(footballLoop, st, token)
	task.spawn(keeperPatrol, st, token)
end

-- ---------------------------------------------------------------- NPC basket

local function basketLoop(st: Station, token: number)
	local hoop = st.hoopNpc :: Vector3
	local inward = st.inwardNpc :: Vector3
	local perp = Vector3.new(-inward.Z, 0, inward.X)
	local shooter: Actor? = nil
	local rebounder: Actor? = nil
	for _, a in st.actors do
		if a.model.Name == "Penembak" then
			shooter = a
		elseif a.model.Name == "PengambilBola" then
			rebounder = a
		end
	end
	if shooter == nil or rebounder == nil then
		return
	end
	local ball = makeBall("basket")
	ball.Parent = st.folder
	table.insert(st.balls, ball)
	local floorY = st.groundY
	local shootSpot = hoop + inward * 6.5 + perp * rng:NextNumber(-3, 3)
	local reboundHome = hoop + inward * 2.5 + perp * 3.5
	local s, r = shooter, rebounder
	local function handPos(a: Actor, lift: number): Vector3
		return a.root.Position
			+ a.root.CFrame.LookVector * 1.2
			+ a.root.CFrame.RightVector * 0.8
			+ Vector3.new(0, lift, 0)
	end
	local function chestPos(a: Actor): Vector3
		return a.root.Position + a.root.CFrame.LookVector * 1.1 + Vector3.new(0, 0.6, 0)
	end
	walkTo(s, shootSpot, 10, 10, nil)
	walkTo(r, reboundHome, 10, 10, nil)
	while st.token == token and ball.Parent do
		-- penembak menggiring (bola memantul di samping) lalu membidik ring
		shootSpot = hoop + inward * rng:NextNumber(5.5, 8) + perp * rng:NextNumber(-3.5, 3.5)
		walkTo(s, shootSpot, 8, 6, nil)
		stopActor(s)
		faceTo(s, hoop)
		faceTo(r, hoop)
		local began = os.clock()
		while os.clock() - began < 2.2 and st.token == token do
			local bounce = math.abs(math.sin((os.clock() - began) * 6.5))
			local p = handPos(s, -2.2 + bounce * 2.8)
			placeBall(ball, CFrame.new(Vector3.new(p.X, math.max(p.Y, floorY + 0.8), p.Z)))
			RunService.Heartbeat:Wait()
		end
		if st.token ~= token then
			break
		end
		-- lempar: tangan terangkat (animasi sorak resmi) lalu bola melengkung ke ring
		s.tracks.cheer:Play(0.1)
		task.wait(0.35)
		local from = s.root.Position + Vector3.new(0, 3, 0) + s.root.CFrame.LookVector
		local luck = rng:NextNumber()
		local aim, power
		if luck < 0.55 then
			aim, power = rng:NextNumber(-0.15, 0.15), BASK.sweetPower + rng:NextNumber(-0.05, 0.05)
		elseif luck < 0.8 then
			aim, power = rng:NextNumber(-0.5, 0.5), BASK.sweetPower + rng:NextNumber(-0.18, 0.18)
		else
			aim, power = rng:NextNumber(-0.9, 0.9), BASK.sweetPower + rng:NextNumber(-0.3, 0.3)
		end
		local throw = evaluateThrow(hoop, inward, aim, power)
		task.spawn(function()
			task.wait(1.2)
			s.tracks.cheer:Stop(0.3)
		end)
		task.spawn(function()
			-- pengambil bola bergerak ke bawah ring saat bola jatuh
			task.wait(0.9)
			walkTo(r, hoop + inward * 1.5 + perp * rng:NextNumber(-1.5, 1.5), 11, 3, nil)
		end)
		playThrow(st, ball, hoop, inward, from, throw)
		if st.token ~= token then
			break
		end
		-- pengambil bola mengambil bola lalu mengoper ke penembak
		local ballAt = ball.PrimaryPart and ball.PrimaryPart.Position or hoop
		walkTo(r, Vector3.new(ballAt.X, r.root.Position.Y, ballAt.Z), 12, 5, nil)
		stopActor(r)
		faceTo(r, s.root.Position)
		placeBall(ball, CFrame.new(chestPos(r)))
		task.wait(0.4)
		local passTo = chestPos(s)
		flyBall(ball, chestPos(r), passTo, 0.6, 1.2)
		task.wait(0.3)
		placeBall(ball, CFrame.new(handPos(s, 0.6)))
		walkTo(r, reboundHome, 9, 6, nil)
		stopActor(r)
		faceTo(r, hoop)
		task.wait(rng:NextNumber(0.4, 1.2))
	end
	ball:Destroy()
end

local function spawnBasket(st: Station, token: number)
	local hoop = st.hoopNpc :: Vector3
	local inward = st.inwardNpc :: Vector3
	local shooter = buildActor("Penembak", {
		shirt = rgb(255, 150, 40),
		shorts = rgb(255, 150, 40),
		socks = rgb(245, 245, 240),
		skin = rgb(224, 172, 120),
		hair = rgb(30, 26, 26),
	}, hoop + inward * 6.5 + Vector3.new(0, st.groundY + 3, 0))
	if shooter == nil or st.token ~= token then
		if shooter then
			shooter.model:Destroy()
		end
		return
	end
	table.insert(st.actors, shooter)
	local rebounder = buildActor("PengambilBola", {
		shirt = rgb(120, 80, 200),
		shorts = rgb(120, 80, 200),
		socks = rgb(245, 245, 240),
		skin = rgb(120, 80, 52),
		hair = rgb(30, 26, 26),
	}, hoop + inward * 2.5 + Vector3.new(3, st.groundY + 3, 0))
	if rebounder == nil or st.token ~= token then
		if rebounder then
			rebounder.model:Destroy()
		end
		return
	end
	table.insert(st.actors, rebounder)
	task.spawn(basketLoop, st, token)
end

-- ---------------------------------------------------------------- LOD NPC

local function spawnStation(st: Station)
	if st.spawned then
		return
	end
	st.spawned = true
	st.token += 1
	local token = st.token
	local folder = Instance.new("Folder")
	folder.Name = if st.kind == "football" then "SepakBola" else "Basket"
	folder.Parent = actorFolder
	st.folder = folder
	st.actors = {}
	st.balls = {}
	task.spawn(function()
		if st.kind == "football" then
			spawnFootball(st, token)
		else
			spawnBasket(st, token)
		end
	end)
end

local function despawnStation(st: Station)
	if not st.spawned then
		return
	end
	st.spawned = false
	st.token += 1
	for _, a in st.actors do
		a.model:Destroy()
	end
	for _, b in st.balls do
		b:Destroy()
	end
	if st.folder then
		st.folder:Destroy()
	end
	st.actors = {}
	st.balls = {}
	st.keeper = nil
	st.folder = nil
end

-- ---------------------------------------------------------------- mini-game pemain

local function sendState(player: Player, kind: string, ...: any)
	stateRemote:FireClient(player, kind, ...)
end

local function earnable(player: Player, amount: number): number
	local now = os.clock()
	local record = earned[player]
	if record == nil or now - record.window > SportsConfig.EARN_WINDOW then
		record = { window = now, amount = 0 }
		earned[player] = record
	end
	local room = math.max(0, SportsConfig.EARN_CAP - record.amount)
	local pay = math.min(amount, room)
	record.amount += pay
	return pay
end

local function endGame(player: Player, message: string?)
	local game = games[player]
	if game == nil then
		return
	end
	games[player] = nil
	game.alive = false
	local st = game.station
	st.busyPlayer = nil
	if st.kind == "football" then
		st.keeperControlled = false
		if st.keeper and st.keeper.model.Parent then
			st.keeper.root.Anchored = false
		end
	end
	if game.cheer then
		game.cheer:Stop(0.2)
	end
	if game.ball then
		game.ball:Destroy()
	end
	if game.root.Parent then
		game.root.Anchored = false
	end
	cooldowns[player] = os.clock() + SportsConfig.COOLDOWN
	local pay = 0
	if game.reward > 0 then
		pay = earnable(player, game.reward)
		if pay > 0 then
			EconomyService.addMoney(player, pay, "olahraga:" .. game.mode)
		end
	end
	sendState(player, "end", game.score, game.taken, pay)
	if message then
		EconomyService.notify(player, message)
	elseif game.taken >= game.shots then
		local title = if game.mode == "football" then FOOT.title else BASK.title
		EconomyService.notify(
			player,
			`{title}: skor {game.score} dari {game.shots}.{if pay > 0
				then ` Hadiah {Format.money(pay)}.`
				else ""}`
		)
	end
end

local function startGame(player: Player, st: Station)
	if games[player] or st.busyPlayer then
		if st.busyPlayer and st.busyPlayer ~= player then
			EconomyService.notify(
				player,
				"Lapangan sedang dipakai pemain lain. Tunggu sebentar ya!"
			)
		end
		return
	end
	local humanoid, root = aliveParts(player)
	if humanoid == nil or root == nil or humanoid.SeatPart ~= nil then
		EconomyService.notify(player, "Turun dari kendaraan dulu ya.")
		return
	end
	local spot = st.spot
	if spot == nil or (root.Position - spot.Position).Magnitude > 16 then
		return
	end
	local left = (cooldowns[player] or 0) - os.clock()
	if left > 0 then
		EconomyService.notify(player, `Istirahat dulu {math.ceil(left)} detik.`)
		return
	end
	local mode = st.kind
	local lookAt: Vector3
	local camPos: Vector3
	local standCFrame: CFrame
	local ballStart: Vector3
	if mode == "football" then
		local goal = st.goalPos :: Vector3
		local stand = Vector3.new(spot.Position.X, st.groundY + 3.05, spot.Position.Z)
		standCFrame = CFrame.lookAt(stand, Vector3.new(goal.X, stand.Y, goal.Z))
		lookAt = goal + Vector3.new(0, 1, 0)
		camPos = stand + st.inward * 9 + Vector3.new(0, 6.5, 4)
		ballStart = stand + -st.inward * 2.4 + Vector3.new(0, 1 - 3.05, 0)
		ballStart = Vector3.new(ballStart.X, st.groundY + 1, ballStart.Z)
	else
		local hoop = st.hoopPlayer :: Vector3
		local inward = flat(spot.Position - hoop)
		local stand = Vector3.new(spot.Position.X, st.groundY + 3.05, spot.Position.Z)
		standCFrame = CFrame.lookAt(stand, Vector3.new(hoop.X, stand.Y, hoop.Z))
		lookAt = hoop + Vector3.new(0, -4, 0)
		camPos = stand + inward * 9 + Vector3.new(0, 6.5, 2)
		ballStart = stand + -inward * 1.1 + Vector3.new(0, 0.5, 0)
	end
	local token = tostring(rng:NextInteger(100000, 999999))
	local game: Game = {
		mode = mode,
		token = token,
		station = st,
		shots = SportsConfig.SHOTS,
		taken = 0,
		score = 0,
		perfect = 0,
		state = "aim",
		askedAt = os.clock(),
		deadline = os.clock() + SportsConfig.SHOT_TIMEOUT,
		ball = nil,
		root = root,
		humanoid = humanoid,
		cheer = nil,
		reward = 0,
		spotCFrame = standCFrame,
		alive = true,
	}
	games[player] = game
	st.busyPlayer = player
	if mode == "football" then
		st.keeperControlled = true
		if st.keeper and st.keeper.model.Parent then
			local home = keeperHome(st)
			st.keeper.root.Anchored = true
			st.keeper.model:PivotTo(CFrame.lookAt(home, home + st.inward))
			st.keeper.tracks.idle:Play()
		end
	end
	root.Anchored = true
	player.Character:PivotTo(standCFrame)
	if mode == "basket" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = ANIM.cheer
			local ok, track = pcall(function(): AnimationTrack
				return animator:LoadAnimation(animation)
			end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = false
				game.cheer = track
			end
		end
	end
	local ball = makeBall(if mode == "football" then "bola" else "basket")
	ball.Parent = Workspace
	placeBall(ball, CFrame.new(ballStart))
	game.ball = ball
	sendState(player, "start", mode, token, game.shots, camPos, lookAt)
end

local function resolveShot(player: Player, game: Game, a: number, b: number, c: number)
	local st = game.station
	local ball = game.ball
	if ball == nil then
		return
	end
	local text: string
	local good = false
	if game.mode == "football" then
		local kick = evaluateKick(st.goalPos :: Vector3, a, b, c, st.groundY)
		local from = ball.PrimaryPart and ball.PrimaryPart.Position or st.center
		playKick(st, ball, from, kick)
		text = KICK_TEXT[kick.outcome] or ""
		good = kick.outcome == "goal"
		if good then
			game.reward += FOOT.goalPay
		end
	else
		local hoop = st.hoopPlayer :: Vector3
		local inward = flat((st.spot :: BasePart).Position - hoop)
		local throw = evaluateThrow(hoop, inward, a, b)
		local from = game.root.Position + Vector3.new(0, 2.4, 0) + game.root.CFrame.LookVector * 0.6
		if game.cheer then
			game.cheer:Play(0.1)
		end
		task.wait(0.3)
		playThrow(st, ball, hoop, inward, from, throw)
		text = THROW_TEXT[throw.outcome] or ""
		good = throw.outcome ~= "rim" and throw.outcome ~= "air"
		if good then
			game.reward += BASK.madePay
			if throw.outcome == "swish" then
				game.reward += BASK.swishBonus
				game.perfect += 1
			end
		end
	end
	if not game.alive then
		return
	end
	game.taken += 1
	if good then
		game.score += 1
	end
	sendState(player, "result", text, good, game.score, game.taken, game.shots)
	task.wait(1.4)
	if not game.alive then
		return
	end
	if game.mode == "football" and st.keeper then
		keeperReset(st)
	end
	if game.taken >= game.shots then
		if game.score >= game.shots then
			game.reward += if game.mode == "football" then FOOT.sweepBonus else BASK.sweepBonus
		end
		endGame(player, nil)
		return
	end
	-- bola baru
	if game.ball then
		game.ball:Destroy()
	end
	local newBall = makeBall(if game.mode == "football" then "bola" else "basket")
	newBall.Parent = Workspace
	local stand = game.spotCFrame.Position
	local inwardDir = if game.mode == "football"
		then st.inward
		else flat(stand - (st.hoopPlayer :: Vector3))
	local pos = if game.mode == "football"
		then Vector3.new(stand.X - st.inward.X * 2.4, st.groundY + 1, stand.Z - st.inward.Z * 2.4)
		else stand - inwardDir * 1.1 + Vector3.new(0, 0.5, 0)
	placeBall(newBall, CFrame.new(pos))
	game.ball = newBall
	game.state = "aim"
	game.askedAt = os.clock()
	game.deadline = os.clock() + SportsConfig.SHOT_TIMEOUT
	sendState(player, "ready", game.taken + 1)
end

local function onShoot(player: Player, token: any, a: any, b: any, c: any)
	local game = games[player]
	if game == nil or token ~= game.token or game.state ~= "aim" then
		return
	end
	if type(a) ~= "number" or type(b) ~= "number" or type(c) ~= "number" then
		return
	end
	if a ~= a or b ~= b or c ~= c then
		return
	end
	if os.clock() - game.askedAt < SportsConfig.MIN_SHOT_SECONDS then
		return
	end
	local humanoid, root = aliveParts(player)
	if humanoid == nil or root == nil then
		endGame(player, nil)
		return
	end
	game.state = "busy"
	task.spawn(
		resolveShot,
		player,
		game,
		math.clamp(a, -1, 1),
		math.clamp(b, 0, 1),
		math.clamp(c, 0, 1)
	)
end

-- ---------------------------------------------------------------- bangun stasiun dari dunia

local function makeSpot(
	position: Vector3,
	color: Color3,
	label: string,
	hint: string,
	actionText: string,
	objectText: string
): BasePart
	local spot = Instance.new("Part")
	spot.Name = "TitikOlahraga"
	spot.Shape = Enum.PartType.Cylinder
	spot.Size = Vector3.new(0.18, 3.8, 3.8)
	spot.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	spot.Color = color
	spot.Material = Enum.Material.Neon
	spot.Transparency = 0.35
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanTouch = false
	spot.CastShadow = false
	spot.Parent = Workspace
	CollectionService:AddTag(spot, TAG)
	local board = Instance.new("BillboardGui")
	board.Name = "Papan"
	board.Size = UDim2.fromOffset(190, 52)
	board.StudsOffset = Vector3.new(0, 5, 0)
	board.MaxDistance = 60
	board.AlwaysOnTop = false
	board.Parent = spot
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.Text = label
	title.Parent = board
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = rgb(255, 235, 150)
	sub.TextStrokeTransparency = 0.3
	sub.Text = hint
	sub.Parent = board
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OlahragaPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
	return spot
end

local function newStation(kind: string, center: Vector3, groundY: number, inward: Vector3): Station
	return {
		kind = kind,
		center = center,
		groundY = groundY,
		goalPos = nil,
		inward = inward,
		hoopNpc = nil,
		hoopPlayer = nil,
		inwardNpc = nil,
		spot = nil,
		folder = nil,
		spawned = false,
		token = 0,
		actors = {},
		balls = {},
		busyPlayer = nil,
		keeper = nil,
		keeperControlled = false,
	}
end

local function buildFootball()
	local map = Workspace:FindFirstChild("Map")
	local neighborhoods = if map then map:FindFirstChild("Neighborhoods") else nil
	local school = if neighborhoods then neighborhoods:FindFirstChild("Sekolah") else nil
	local pitch = if school then school:FindFirstChild("Lapangan") else nil
	if pitch == nil or not pitch:IsA("BasePart") then
		warn("[Sports] lapangan sepak bola tidak ditemukan")
		return
	end
	local groundY = pitch.Position.Y + pitch.Size.Y / 2
	local center = Vector3.new(pitch.Position.X, groundY, pitch.Position.Z)
	local westX = center.X - pitch.Size.X / 2 + 2
	local lines: { number } = {}
	for _, d in (school :: Instance):GetChildren() do
		if d.Name == "GarisGawang" and d:IsA("BasePart") then
			table.insert(lines, d.Position.X)
		end
	end
	if #lines >= 2 then
		table.sort(lines)
		westX = lines[1]
	end
	local goal = Vector3.new(westX, groundY, center.Z)
	local st = newStation("football", center, groundY, Vector3.new(1, 0, 0))
	st.goalPos = goal
	local spotPos = Vector3.new(westX + FOOT.spotDistance, groundY + 0.12, center.Z)
	local spot = makeSpot(
		spotPos,
		rgb(255, 235, 90),
		"⚽ Adu Penalti",
		`Hadiah sampai {Format.money(FOOT.goalPay * SportsConfig.SHOTS + FOOT.sweepBonus)}`,
		"Tendang penalti",
		"Lapangan Sepak Bola"
	)
	st.spot = spot
	local prompt = spot:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(player: Player)
		startGame(player, st)
	end)
	table.insert(stations, st)
end

local function buildBasketCourts()
	local map = Workspace:FindFirstChild("Map")
	if map == nil then
		return
	end
	for _, model in map:GetDescendants() do
		if not (model:IsA("Model") and model.Name:match("^LapanganBasket")) then
			continue
		end
		local supports: { BasePart } = {}
		local rings: { BasePart } = {}
		local floorY = 0.47
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") then
				if d.Name == "PenyanggaRing" then
					table.insert(supports, d)
				elseif d.Name == "Ring" then
					table.insert(rings, d)
				elseif d.Name == "Lantai" then
					floorY = d.Position.Y + d.Size.Y / 2
				end
			end
		end
		if #supports < 2 then
			continue
		end
		table.sort(supports, function(x: BasePart, y: BasePart)
			if math.abs(x.Position.X - y.Position.X) > 0.5 then
				return x.Position.X < y.Position.X
			end
			return x.Position.Z < y.Position.Z
		end)
		local hoops: { Vector3 } = {}
		for _, support in supports do
			local sum, count = Vector3.zero, 0
			for _, ring in rings do
				if (ring.Position - support.Position).Magnitude < 3.6 then
					sum += ring.Position
					count += 1
				end
			end
			table.insert(hoops, if count > 0 then sum / count else support.Position)
		end
		local center = (hoops[1] + hoops[2]) / 2
		local centerGround = Vector3.new(center.X, floorY, center.Z)
		local st = newStation("basket", centerGround, floorY, Vector3.new(1, 0, 0))
		st.hoopNpc = hoops[1]
		st.hoopPlayer = hoops[2]
		st.inwardNpc = flat(center - hoops[1])
		local inwardPlayer = flat(center - hoops[2])
		local spotPos = Vector3.new(hoops[2].X, floorY + 0.12, hoops[2].Z)
			+ inwardPlayer * BASK.spotDistance
		local spot = makeSpot(
			spotPos,
			rgb(255, 150, 60),
			"🏀 Lempar Bebas",
			`Hadiah sampai {Format.money(
				(BASK.madePay + BASK.swishBonus) * SportsConfig.SHOTS + BASK.sweepBonus
			)}`,
			"Lempar bebas",
			"Lapangan Basket"
		)
		st.spot = spot
		local prompt = spot:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(player: Player)
			startGame(player, st)
		end)
		table.insert(stations, st)
	end
end

-- ---------------------------------------------------------------- siklus hidup

function SportsService.init()
	stateRemote = Net.event("SportsState")
	Net.event("SportsShoot").OnServerEvent:Connect(onShoot)
	Net.event("SportsLeave").OnServerEvent:Connect(function(player: Player, token: any)
		local game = games[player]
		if game and token == game.token then
			endGame(player, nil)
		end
	end)
end

function SportsService.start()
	actorFolder = Instance.new("Folder")
	actorFolder.Name = "NpcOlahraga"
	actorFolder.Parent = Workspace
	buildFootball()
	buildBasketCourts()
	Players.PlayerRemoving:Connect(function(player: Player)
		endGame(player, nil)
		cooldowns[player] = nil
		earned[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			for _, st in stations do
				if st.spawned then
					if st.busyPlayer == nil and not playerWithin(st.center, DESPAWN_RANGE) then
						despawnStation(st)
					end
				elseif playerWithin(st.center, SPAWN_RANGE) then
					spawnStation(st)
				end
			end
			-- pengawas putaran: pemain mati/menjauh/lambat membidik
			for player, game in games do
				local humanoid, root = aliveParts(player)
				if
					humanoid == nil
					or root == nil
					or (root.Position - game.spotCFrame.Position).Magnitude > 12
				then
					endGame(player, nil)
				elseif game.state == "aim" and os.clock() > game.deadline then
					endGame(player, "Waktu bidik habis, putaran dihentikan.")
				end
			end
		end
	end)
end

return SportsService
