--!strict
--[[
	ResortService: layanan hotel di dalam Resort ROBLOCK (Pulau Pantai).
	  * Staf berseragam (resepsionis, concierge, bellboy dengan kereta koper, koki, pelayan, bartender):
	    avatar R15 dari kode + animasi resmi/Studio lewat Animator. Hanya ada saat ada pemain dalam
	    SPAWN_RANGE stud dan dihapus lagi saat semua pemain lebih dari DESPAWN_RANGE (hemat HP).
	  * Check-in (prompt di meja resepsionis, tag "ResortCheckIn"): bonus tamu kecil sekali tiap CHECKIN_COOLDOWN detik.
	  * Concierge (tag "ResortConcierge"): memberi saran tempat seru di kota.
	Koordinat Blender (x, y, z) -> dunia: BASE * (x, z, -y), sama dengan map/BuildResortDalam.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ResortService = {}

local BASE = CFrame.new(1249, 1, -460) * CFrame.Angles(0, -math.pi / 2, 0)
local FLOOR = 1.0
local CENTER = (BASE * CFrame.new(0, 6, 0)).Position
local SPAWN_RANGE = 120
local DESPAWN_RANGE = 170
local CHECK_SECONDS = 3
local GROUP_NPC = "Npc"
local CHECKIN_BONUS = 60
local CHECKIN_COOLDOWN = 600

local ANIM = {
	catat = "rbxassetid://120301783800111", -- berdiri mencatat
	sapa = "rbxassetid://139976582794074", -- berdiri menyapa
	ketik = "rbxassetid://75023251394352", -- mengetik
	jalan = "rbxassetid://913402848", -- jalan resmi R15
	diam = "rbxassetid://507766388", -- diam resmi R15
}

local rgb = Color3.fromRGB

type Staff = {
	name: string,
	title: string,
	at: Vector3, -- (x, y, z) Blender
	face: Vector2,
	anim: string,
	skin: Color3,
	vest: Color3,
	pants: Color3,
	hair: Color3,
	hairStyle: string,
	woman: boolean?,
	hat: string?, -- "bellboy" | "chef" | "hijab"
	extra: string?, -- "koper" | "nampan"
	patrol: { Vector2 }?,
	model: Model?,
}

local NAVY, TEAL, WHITE = rgb(24, 52, 78), rgb(30, 160, 170), rgb(250, 250, 248)

local STAFF: { Staff } = {
	{
		name = "Bu Dewi", title = "Resepsionis", at = Vector3.new(0, -11.7, FLOOR), face = Vector2.new(0, 1),
		anim = "catat", skin = rgb(215, 165, 125), vest = NAVY, pants = rgb(40, 44, 58), hair = rgb(30, 26, 26),
		hairStyle = "sanggul", woman = true,
	},
	{
		name = "Pak Rudi", title = "Concierge", at = Vector3.new(-15, -5.4, FLOOR), face = Vector2.new(0, 1),
		anim = "sapa", skin = rgb(190, 140, 100), vest = TEAL, pants = rgb(40, 44, 58), hair = rgb(24, 20, 20),
		hairStyle = "rapi",
	},
	{
		name = "Mas Doni", title = "Bellboy", at = Vector3.new(12, 13.5, FLOOR), face = Vector2.new(0, -1),
		anim = "diam", skin = rgb(205, 155, 115), vest = rgb(150, 30, 36), pants = rgb(40, 44, 58),
		hair = rgb(30, 26, 26), hairStyle = "rapi", hat = "bellboy", extra = "koper",
		patrol = { Vector2.new(12, 13.5), Vector2.new(12, -6), Vector2.new(17.5, -13), Vector2.new(12, -6) },
	},
	{
		name = "Chef Bagas", title = "Koki", at = Vector3.new(-47, -14.6, FLOOR), face = Vector2.new(0, 1),
		anim = "catat", skin = rgb(215, 170, 130), vest = WHITE, pants = rgb(50, 54, 66), hair = rgb(30, 26, 26),
		hairStyle = "rapi", hat = "chef",
	},
	{
		name = "Mbak Ani", title = "Pelayan", at = Vector3.new(-60, 3.4, FLOOR), face = Vector2.new(1, 0),
		anim = "diam", skin = rgb(220, 170, 135), vest = NAVY, pants = rgb(40, 44, 58), hair = rgb(30, 26, 26),
		hairStyle = "sanggul", woman = true, extra = "nampan",
		patrol = { Vector2.new(-60, 3.4), Vector2.new(-30, 3.4), Vector2.new(-30, -8), Vector2.new(-60, -8) },
	},
	{
		name = "Kak Lia", title = "Bartender", at = Vector3.new(46, -14.8, FLOOR), face = Vector2.new(0, 1),
		anim = "sapa", skin = rgb(225, 175, 140), vest = TEAL, pants = rgb(40, 44, 58), hair = rgb(60, 36, 24),
		hairStyle = "sanggul", woman = true,
	},
}

local function world(x: number, y: number, z: number): Vector3
	return (BASE * CFrame.new(x, z, -y)).Position
end

local function attach(model: Model, to: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = "Hiasan"
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless = false, false, false, false, true
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local SP, METAL, BLOCK, BALL, CYL = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

local function build(info: Staff): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = if info.woman then 0.97 else 1.03
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Resort] gagal membuat staf: " .. tostring(model))
		return nil
	end
	model.Name = info.name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if humanoid == nil or head == nil or torso == nil or not head:IsA("BasePart") or not torso:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 7
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.BreakJointsOnDeath = false
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") or child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("Pants") then
			child:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			part.Material = SP
			if n:match("Hand$") or n == "Head" then
				part.Color = info.skin
			elseif n:match("Foot$") then
				part.Color = rgb(28, 26, 28)
			elseif n:match("Leg$") then
				part.Color = if info.woman and n:match("LowerLeg$") then info.skin else info.pants
			else
				part.Color = WHITE -- kemeja putih (badan + lengan), rompi di dada
			end
		end
	end
	-- rompi berwarna di dada + dasi kupu-kupu/dasi + lencana emas
	attach(model, torso, Vector3.new(1.0, 1.35, 0.1), CFrame.new(0, 0.1, -0.52), info.vest, BLOCK, SP)
	attach(model, torso, Vector3.new(0.18, 0.9, 0.08), CFrame.new(0, 0.1, -0.58), WHITE, BLOCK, SP)
	attach(model, torso, Vector3.new(0.3, 0.2, 0.1), CFrame.new(0, 0.6, -0.58), rgb(190, 50, 56), BLOCK, SP)
	attach(model, torso, Vector3.new(0.3, 0.16, 0.06), CFrame.new(0.4, 0.3, -0.58), rgb(226, 172, 52), BLOCK, METAL)
	-- rambut
	attach(model, head, Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 0.36, 0.08), info.hair, BALL, SP)
	if info.hairStyle == "sanggul" then
		attach(model, head, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.72, 0.58), info.hair, BALL, SP)
	else
		attach(model, head, Vector3.new(1.3, 0.35, 0.6), CFrame.new(0, 0.62, -0.46), info.hair, BLOCK, SP)
	end
	-- topi
	if info.hat == "bellboy" then
		local cap = attach(model, head, Vector3.new(0.5, 1.15, 1.15), CFrame.new(0, 0.78, 0), rgb(150, 30, 36), CYL, SP)
		cap.CFrame = head.CFrame * CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90))
		attach(model, head, Vector3.new(1.0, 0.1, 0.12), CFrame.new(0, 0.55, -0.55), rgb(226, 172, 52), BLOCK, METAL)
	elseif info.hat == "chef" then
		local base = attach(model, head, Vector3.new(0.5, 1.2, 1.2), CFrame.new(0, 0.7, 0), WHITE, CYL, SP)
		base.CFrame = head.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
		attach(model, head, Vector3.new(1.5, 0.9, 1.5), CFrame.new(0, 1.2, 0), WHITE, BALL, SP)
	end
	-- kereta koper (bellboy) di depan badan: rangka, dua koper, roda
	if info.extra == "koper" then
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local cart = attach(model, root, Vector3.new(2.4, 0.2, 3.0), CFrame.new(0, -2.2, -3.2), rgb(226, 172, 52), BLOCK, METAL)
		attach(model, cart, Vector3.new(0.18, 3.4, 0.18), CFrame.new(-1.1, 1.7, 1.4), rgb(226, 172, 52), BLOCK, METAL)
		attach(model, cart, Vector3.new(0.18, 3.4, 0.18), CFrame.new(1.1, 1.7, 1.4), rgb(226, 172, 52), BLOCK, METAL)
		attach(model, cart, Vector3.new(2.4, 0.18, 0.18), CFrame.new(0, 3.4, 1.4), rgb(226, 172, 52), BLOCK, METAL)
		attach(model, cart, Vector3.new(1.9, 1.3, 1.0), CFrame.new(-0.2, 0.75, -0.3), rgb(200, 60, 60), BLOCK, SP)
		attach(model, cart, Vector3.new(1.5, 1.0, 0.9), CFrame.new(0.2, 2.0, -0.3), rgb(40, 110, 180), BLOCK, SP)
		attach(model, cart, Vector3.new(1.3, 0.8, 0.8), CFrame.new(-0.3, 0.55, 0.9), rgb(60, 150, 100), BLOCK, SP)
		for _, dx in { -1, 1 } do
			for _, dz in { -1.2, 1.2 } do
				local w = attach(model, cart, Vector3.new(0.3, 0.5, 0.5), CFrame.new(dx * 1.1, -0.3, dz), rgb(30, 30, 34), CYL, SP)
				w.CFrame = cart.CFrame * CFrame.new(dx * 1.1, -0.3, dz)
			end
		end
	elseif info.extra == "nampan" then
		local tray = attach(model, torso, Vector3.new(1.6, 0.1, 1.2), CFrame.new(0, -0.1, -1.4), rgb(196, 202, 208), BLOCK, METAL)
		attach(model, tray, Vector3.new(0.35, 0.7, 0.7), CFrame.new(-0.3, 0.2, 0), WHITE, CYL, SP)
		attach(model, tray, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0.4, 0.4, 0.1), rgb(250, 120, 60), CYL, SP)
	end
	-- papan nama
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(150, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
	board.MaxDistance = 28
	board.AlwaysOnTop = false
	board.Parent = head
	local function line(text: string, y: number, h: number, size: number, color: Color3, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.new(1, 0, h, 0)
		l.Text = text
		l.Font = font
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.4
		l.Parent = board
	end
	line(info.name, 0, 0.55, 16, rgb(255, 255, 255), Enum.Font.GothamBold)
	line(info.title, 0.52, 0.45, 13, rgb(255, 232, 160), Enum.Font.Gotham)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP_NPC
			d.CanTouch = false
		end
	end
	return model
end

local function play(humanoid: Humanoid, id: string): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.3)
	return track
end

local function patrol(model: Model, humanoid: Humanoid, points: { Vector2 })
	local walk, idle = play(humanoid, ANIM.jalan), play(humanoid, ANIM.diam)
	walk:Stop(0)
	task.spawn(function()
		local index = 1
		while model.Parent do
			index = index % #points + 1
			local target = points[index]
			local goal = world(target.X, target.Y, FLOOR)
			local root = model.PrimaryPart
			if root == nil then
				return
			end
			goal = Vector3.new(goal.X, root.Position.Y, goal.Z)
			idle:Stop(0.2)
			walk:Play(0.2)
			humanoid:MoveTo(goal)
			local waited = 0
			while model.Parent and (root.Position * Vector3.new(1, 0, 1) - goal * Vector3.new(1, 0, 1)).Magnitude > 2 and waited < 16 do
				waited += task.wait(0.25)
			end
			walk:Stop(0.2)
			idle:Play(0.2)
			task.wait(2 + math.random() * 3)
		end
	end)
end

local function spawnStaff(info: Staff)
	local model = build(info)
	if model == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart
	local floor = world(info.at.X, info.at.Y, info.at.Z)
	local position = Vector3.new(floor.X, floor.Y + humanoid.HipHeight + root.Size.Y / 2, floor.Z)
	local look = (BASE * CFrame.new(info.face.X, 0, -info.face.Y)).Position - BASE.Position
	model:PivotTo(CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z)))
	model.Parent = Workspace:FindFirstChild("StafResort")
	if info.patrol then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		patrol(model, humanoid, info.patrol)
	else
		root.Anchored = true
		play(humanoid, ANIM[info.anim])
	end
	info.model = model
end

local function playerNear(range: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - CENTER).Magnitude <= range then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- interaksi tamu
local TIPS = {
	"Coba Jet Ski di pantai: ada tantangan 10 cincin!",
	"Bianglala di dermaga punya pemandangan indah.",
	"Kafe Pantai buka jam 8 pagi sampai 9 malam, ada penari.",
	"Jajan di Restoran Samudra untuk tenaga ekstra sebentar.",
	"Berenanglah di kolam depan resort, airnya sejuk!",
	"Pulau Pantai punya pelabuhan dengan kapal-kapal cantik.",
}

local notifyRemote: RemoteEvent
local lastCheckIn: { [Player]: number } = {}
local tipIndex = 0

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function addPrompt(part: BasePart, action: string, object: string, handler: (Player) -> ())
	if part:FindFirstChild("ResortPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ResortPrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(handler)
	prompt.Parent = part
end

local function registerCheckIn(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	addPrompt(inst, "Check-in", "Resepsionis Resort", function(player)
		local now = os.clock()
		local last = lastCheckIn[player]
		if last and now - last < CHECKIN_COOLDOWN then
			notify(player, "Kamu sudah check-in. Selamat menikmati Resort!")
			return
		end
		local character = player.Character
		local root = if character then character.PrimaryPart else nil
		if root == nil or (root.Position - inst.Position).Magnitude > 20 then
			return
		end
		lastCheckIn[player] = now
		local ok, Economy = pcall(function()
			return require(script.Parent:WaitForChild("EconomyService")) :: any
		end)
		if ok and Economy and typeof(Economy.addMoney) == "function" then
			Economy.addMoney(player, CHECKIN_BONUS, "resort")
		end
		notify(player, `Selamat datang di ROBLOCK Resort! Bonus tamu ${CHECKIN_BONUS}`)
	end)
end

local function registerConcierge(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	addPrompt(inst, "Tanya Concierge", "Concierge", function(player)
		tipIndex = tipIndex % #TIPS + 1
		notify(player, TIPS[tipIndex])
	end)
end

function ResortService.init()
	local folder = Workspace:FindFirstChild("StafResort") or Instance.new("Folder")
	folder.Name = "StafResort"
	folder.Parent = Workspace
	notifyRemote = Net.event(Net.Names.Notify)
end

function ResortService.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NPC)
	end)
	for _, inst in CollectionService:GetTagged("ResortCheckIn") do
		registerCheckIn(inst)
	end
	CollectionService:GetInstanceAddedSignal("ResortCheckIn"):Connect(registerCheckIn)
	for _, inst in CollectionService:GetTagged("ResortConcierge") do
		registerConcierge(inst)
	end
	CollectionService:GetInstanceAddedSignal("ResortConcierge"):Connect(registerConcierge)
	Players.PlayerRemoving:Connect(function(player)
		lastCheckIn[player] = nil
	end)

	task.spawn(function()
		while true do
			local near = playerNear(SPAWN_RANGE)
			local far = not playerNear(DESPAWN_RANGE)
			for _, info in STAFF do
				local model = info.model
				if model and model.Parent == nil then
					info.model = nil
					model = nil
				end
				if model == nil and near then
					spawnStaff(info)
				elseif model and far then
					model:Destroy()
					info.model = nil
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return ResortService
