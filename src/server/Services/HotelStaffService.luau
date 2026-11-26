--!strict
--[[
	HotelStaffService: staf Hotel Bintang Kota (meniru pola ResortService): avatar R15 dari kode, seragam
	arang + emas, animasi resmi/Studio lewat Animator. Hanya ada saat ada pemain dalam SPAWN_RANGE stud,
	dihapus lagi saat semua pemain lebih dari DESPAWN_RANGE (hemat HP).
	  * Resepsionis (di belakang meja lobi), Concierge (dekat pintu masuk, prompt "Tanya Concierge"),
	    Bellboy (patroli dengan kereta koper), Pelayan lounge (patroli dengan nampan), Bartender,
	    Housekeeping (patroli di koridor lantai kamar dengan kereta handuk).
	  * Menyapa pemain yang mendekat: berbalik, melambai, dan muncul gelembung ucapan.
	Koordinat staf = titik lokal hotel (x timur, z selatan) + Kit.ORIGIN; y = tinggi lantai.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local HotelStaffService = {}

local ORIGIN = Vector3.new(270, 0.6, -52)
local LOBBY_Y = 0.6
local UPPER_Y = 16.6
local SPAWN_RANGE = 110
local DESPAWN_RANGE = 160
local CHECK_SECONDS = 3
local GROUP_NPC = "Npc"
local GREET_RANGE = 13
local GREET_COOLDOWN = 25

local ANIM = {
	catat = "rbxassetid://120301783800111",
	sapa = "rbxassetid://139976582794074",
	ketik = "rbxassetid://75023251394352",
	jalan = "rbxassetid://913402848",
	diam = "rbxassetid://507766388",
}

local rgb = Color3.fromRGB
local CHARCOAL, GOLD, WHITE = rgb(48, 52, 60), rgb(208, 168, 86), rgb(250, 250, 248)

type Staff = {
	name: string,
	title: string,
	at: Vector2, -- (x, z) lokal hotel
	floorY: number,
	face: Vector2,
	anim: string,
	skin: Color3,
	vest: Color3,
	pants: Color3,
	hair: Color3,
	hairStyle: string,
	woman: boolean?,
	hat: string?, -- "bellboy" | "hijab"
	extra: string?, -- "koper" | "nampan" | "handuk"
	patrol: { Vector2 }?,
	concierge: boolean?,
	greet: { string },
	model: Model?,
	lastGreet: number?, -- indeks tips terakhir (concierge)
	lastGreetAt: number?, -- waktu sapaan terakhir
}

local STAFF: { Staff } = {
	{
		name = "Bu Sari",
		title = "Resepsionis",
		at = Vector2.new(-31, 10.8),
		floorY = LOBBY_Y,
		face = Vector2.new(0, -1),
		anim = "ketik",
		skin = rgb(215, 165, 125),
		vest = CHARCOAL,
		pants = rgb(40, 44, 58),
		hair = rgb(30, 26, 26),
		hairStyle = "sanggul",
		woman = true,
		greet = {
			"Selamat datang di Hotel Bintang Kota!",
			"Mau check-in, Kak? Silakan ke sini.",
			"Kamar tamu ada di lantai 2 sampai 8.",
		},
	},
	{
		name = "Pak Anton",
		title = "Concierge",
		at = Vector2.new(-9, -17),
		floorY = LOBBY_Y,
		face = Vector2.new(0, -1),
		anim = "sapa",
		skin = rgb(190, 140, 100),
		vest = rgb(30, 70, 100),
		pants = rgb(40, 44, 58),
		hair = rgb(24, 20, 20),
		hairStyle = "rapi",
		concierge = true,
		greet = {
			"Selamat datang! Ada yang bisa saya bantu?",
			"Tekan tombol untuk bertanya pada saya, ya.",
			"Lift ada di tengah lobi.",
		},
	},
	{
		name = "Mas Rio",
		title = "Bellboy",
		at = Vector2.new(-8, -22),
		floorY = LOBBY_Y,
		face = Vector2.new(0, 1),
		anim = "diam",
		skin = rgb(205, 155, 115),
		vest = rgb(150, 30, 36),
		pants = rgb(40, 44, 58),
		hair = rgb(30, 26, 26),
		hairStyle = "rapi",
		hat = "bellboy",
		extra = "koper",
		patrol = { Vector2.new(-8, -22), Vector2.new(-8, -3), Vector2.new(-22, -12) },
		greet = { "Halo, Kak! Butuh bantuan bawa koper?", "Selamat datang di hotel kami!" },
	},
	{
		name = "Mbak Dina",
		title = "Pelayan",
		at = Vector2.new(16, -21),
		floorY = LOBBY_Y,
		face = Vector2.new(1, 0),
		anim = "diam",
		skin = rgb(220, 170, 135),
		vest = CHARCOAL,
		pants = rgb(40, 44, 58),
		hair = rgb(30, 26, 26),
		hairStyle = "sanggul",
		woman = true,
		extra = "nampan",
		patrol = {
			Vector2.new(16, -21),
			Vector2.new(38, -21),
			Vector2.new(38, 3),
			Vector2.new(16, 3),
		},
		greet = { "Silakan duduk di lounge, Kak!", "Mau minum sesuatu?" },
	},
	{
		name = "Kak Rina",
		title = "Bartender",
		at = Vector2.new(31, 22),
		floorY = LOBBY_Y,
		face = Vector2.new(0, -1),
		anim = "sapa",
		skin = rgb(225, 175, 140),
		vest = CHARCOAL,
		pants = rgb(40, 44, 58),
		hair = rgb(60, 36, 24),
		hairStyle = "sanggul",
		woman = true,
		greet = { "Selamat datang di Bar & Lounge!", "Jus segar atau kopi, Kak?" },
	},
	{
		name = "Bu Tini",
		title = "Housekeeping",
		at = Vector2.new(-40, 0),
		floorY = UPPER_Y,
		face = Vector2.new(1, 0),
		anim = "diam",
		skin = rgb(210, 160, 120),
		vest = rgb(46, 124, 130),
		pants = rgb(40, 44, 58),
		hair = rgb(30, 26, 26),
		hairStyle = "sanggul",
		woman = true,
		extra = "handuk",
		patrol = {
			Vector2.new(-40, 0),
			Vector2.new(-14, 0),
			Vector2.new(-40, 0),
			Vector2.new(-22, 0),
		},
		greet = { "Selamat istirahat, Kak!", "Handuk bersih ada di kamar, ya." },
	},
}

local TIPS = {
	"Naik lift di tengah lobi, lalu pilih lantai 2 sampai 8.",
	"Di setiap kamar ada kasur: tekan E untuk tidur, lalu Bangun.",
	"Bar & Lounge ada di sisi timur lobi. Silakan bersantai!",
	"Resepsionis siap membantu di sebelah barat lobi.",
	"Hotel kami buka 24 jam. Selamat menginap!",
}

local function world(x: number, y: number, z: number): Vector3
	return Vector3.new(ORIGIN.X + x, y, ORIGIN.Z + z)
end

local SP, METAL, BLOCK, BALL, CYL =
	Enum.Material.SmoothPlastic,
	Enum.Material.Metal,
	Enum.PartType.Block,
	Enum.PartType.Ball,
	Enum.PartType.Cylinder

local function attach(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = "Hiasan"
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless =
		false, false, false, false, true
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function build(info: Staff): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = if info.woman then 0.97 else 1.03
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Hotel] gagal membuat staf: " .. tostring(model))
		return nil
	end
	model.Name = info.name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if
		humanoid == nil
		or head == nil
		or torso == nil
		or not head:IsA("BasePart")
		or not torso:IsA("BasePart")
	then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 7
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.BreakJointsOnDeath = false
	for _, child in model:GetChildren() do
		if
			child:IsA("LuaSourceContainer")
			or child:IsA("BodyColors")
			or child:IsA("Shirt")
			or child:IsA("Pants")
		then
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
				part.Color = WHITE
			end
		end
	end
	-- rompi seragam + dasi + lencana emas
	attach(
		model,
		torso,
		Vector3.new(1.0, 1.35, 0.1),
		CFrame.new(0, 0.1, -0.52),
		info.vest,
		BLOCK,
		SP
	)
	attach(model, torso, Vector3.new(0.18, 0.9, 0.08), CFrame.new(0, 0.1, -0.58), WHITE, BLOCK, SP)
	attach(model, torso, Vector3.new(0.3, 0.2, 0.1), CFrame.new(0, 0.6, -0.58), GOLD, BLOCK, METAL)
	attach(
		model,
		torso,
		Vector3.new(0.3, 0.16, 0.06),
		CFrame.new(0.4, 0.3, -0.58),
		GOLD,
		BLOCK,
		METAL
	)
	-- rambut
	attach(model, head, Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 0.36, 0.08), info.hair, BALL, SP)
	if info.hairStyle == "sanggul" then
		attach(
			model,
			head,
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(0, 0.72, 0.58),
			info.hair,
			BALL,
			SP
		)
	else
		attach(
			model,
			head,
			Vector3.new(1.3, 0.35, 0.6),
			CFrame.new(0, 0.62, -0.46),
			info.hair,
			BLOCK,
			SP
		)
	end
	if info.hat == "bellboy" then
		local cap = attach(
			model,
			head,
			Vector3.new(0.5, 1.15, 1.15),
			CFrame.new(0, 0.78, 0),
			rgb(150, 30, 36),
			CYL,
			SP
		)
		cap.CFrame = head.CFrame * CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90))
		attach(
			model,
			head,
			Vector3.new(1.0, 0.1, 0.12),
			CFrame.new(0, 0.55, -0.55),
			GOLD,
			BLOCK,
			METAL
		)
	end
	if info.extra == "koper" or info.extra == "handuk" then
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local cart = attach(
			model,
			root,
			Vector3.new(2.4, 0.2, 3.0),
			CFrame.new(0, -2.2, -3.2),
			GOLD,
			BLOCK,
			METAL
		)
		attach(
			model,
			cart,
			Vector3.new(0.18, 3.4, 0.18),
			CFrame.new(-1.1, 1.7, 1.4),
			GOLD,
			BLOCK,
			METAL
		)
		attach(
			model,
			cart,
			Vector3.new(0.18, 3.4, 0.18),
			CFrame.new(1.1, 1.7, 1.4),
			GOLD,
			BLOCK,
			METAL
		)
		attach(
			model,
			cart,
			Vector3.new(2.4, 0.18, 0.18),
			CFrame.new(0, 3.4, 1.4),
			GOLD,
			BLOCK,
			METAL
		)
		if info.extra == "koper" then
			attach(
				model,
				cart,
				Vector3.new(1.9, 1.3, 1.0),
				CFrame.new(-0.2, 0.75, -0.3),
				rgb(112, 34, 46),
				BLOCK,
				SP
			)
			attach(
				model,
				cart,
				Vector3.new(1.5, 1.0, 0.9),
				CFrame.new(0.2, 2.0, -0.3),
				rgb(40, 60, 100),
				BLOCK,
				SP
			)
			attach(
				model,
				cart,
				Vector3.new(1.3, 0.8, 0.8),
				CFrame.new(-0.3, 0.55, 0.9),
				GOLD,
				BLOCK,
				SP
			)
		else
			attach(
				model,
				cart,
				Vector3.new(2.0, 0.5, 1.2),
				CFrame.new(0, 0.35, -0.3),
				WHITE,
				BLOCK,
				SP
			)
			attach(
				model,
				cart,
				Vector3.new(2.0, 0.5, 1.2),
				CFrame.new(0, 0.9, -0.3),
				rgb(180, 210, 220),
				BLOCK,
				SP
			)
			attach(
				model,
				cart,
				Vector3.new(2.0, 0.5, 1.2),
				CFrame.new(0, 1.45, -0.3),
				WHITE,
				BLOCK,
				SP
			)
			attach(
				model,
				cart,
				Vector3.new(0.5, 0.9, 0.5),
				CFrame.new(0.7, 2.1, 0.8),
				rgb(120, 200, 220),
				CYL,
				SP
			)
		end
		for _, dx in { -1, 1 } do
			for _, dz in { -1.2, 1.2 } do
				local w = attach(
					model,
					cart,
					Vector3.new(0.3, 0.5, 0.5),
					CFrame.new(dx * 1.1, -0.3, dz),
					rgb(30, 30, 34),
					CYL,
					SP
				)
				w.CFrame = cart.CFrame * CFrame.new(dx * 1.1, -0.3, dz)
			end
		end
	elseif info.extra == "nampan" then
		local tray = attach(
			model,
			torso,
			Vector3.new(1.6, 0.1, 1.2),
			CFrame.new(0, -0.1, -1.4),
			rgb(196, 202, 208),
			BLOCK,
			METAL
		)
		attach(model, tray, Vector3.new(0.35, 0.7, 0.7), CFrame.new(-0.3, 0.2, 0), WHITE, CYL, SP)
		attach(
			model,
			tray,
			Vector3.new(0.7, 0.4, 0.4),
			CFrame.new(0.4, 0.4, 0.1),
			rgb(250, 120, 60),
			CYL,
			SP
		)
	end
	-- papan nama
	local board = Instance.new("BillboardGui")
	board.Name = "PapanNama"
	board.Size = UDim2.fromOffset(150, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
	board.MaxDistance = 28
	board.AlwaysOnTop = false
	board.Parent = head
	local function line(
		text: string,
		y: number,
		h: number,
		size: number,
		color: Color3,
		font: Enum.Font
	)
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

local function track(
	humanoid: Humanoid,
	id: string,
	looped: boolean,
	priority: Enum.AnimationPriority
): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local t = animator:LoadAnimation(animation)
	t.Looped = looped
	t.Priority = priority
	return t
end

local function play(humanoid: Humanoid, id: string): AnimationTrack
	local t = track(humanoid, id, true, Enum.AnimationPriority.Action)
	t:Play(0.3)
	return t
end

local function patrol(info: Staff, model: Model, humanoid: Humanoid, points: { Vector2 })
	local walk, idle = play(humanoid, ANIM.jalan), play(humanoid, ANIM.diam)
	walk:Stop(0)
	task.spawn(function()
		local index = 1
		while model.Parent do
			index = index % #points + 1
			local target = points[index]
			local goal = world(target.X, info.floorY, target.Y)
			local root = model.PrimaryPart
			if root == nil then
				return
			end
			goal = Vector3.new(goal.X, root.Position.Y, goal.Z)
			idle:Stop(0.2)
			walk:Play(0.2)
			humanoid:MoveTo(goal)
			local waited = 0
			while
				model.Parent
				and (root.Position * Vector3.new(1, 0, 1) - goal * Vector3.new(1, 0, 1)).Magnitude > 2
				and waited < 18
			do
				waited += task.wait(0.25)
			end
			walk:Stop(0.2)
			idle:Play(0.2)
			task.wait(2 + math.random() * 3)
		end
	end)
end

local function bubble(model: Model, text: string)
	local head = model:FindFirstChild("Head")
	if head == nil then
		return
	end
	local old = head:FindFirstChild("Ucapan")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Ucapan"
	gui.Size = UDim2.fromOffset(210, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 36
	gui.Parent = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BackgroundTransparency = 0.05
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = back
	back.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -12, 1, -6)
	label.Position = UDim2.fromOffset(6, 3)
	label.Text = text
	label.TextWrapped = true
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextColor3 = rgb(40, 44, 54)
	label.Parent = back
	task.delay(4.5, function()
		if gui.Parent then
			gui:Destroy()
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
	local floor = world(info.at.X, info.floorY, info.at.Y)
	local position = Vector3.new(floor.X, floor.Y + humanoid.HipHeight + root.Size.Y / 2, floor.Z)
	model:PivotTo(CFrame.lookAt(position, position + Vector3.new(info.face.X, 0, info.face.Y)))
	model.Parent = Workspace:FindFirstChild("StafHotel")
	if info.patrol then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		patrol(info, model, humanoid, info.patrol)
	else
		root.Anchored = true
		play(humanoid, ANIM[info.anim])
	end
	if info.concierge then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TanyaConcierge"
		prompt.ActionText = "Tanya Concierge"
		prompt.ObjectText = "Concierge Hotel"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player: Player)
			local index = (info.lastGreet or 0) % #TIPS + 1
			info.lastGreet = index
			Net.event(Net.Names.Notify):FireClient(player, TIPS[index])
			bubble(model, TIPS[index])
		end)
	end
	info.model = model
end

local function nearestPlayer(position: Vector3): (Player?, number)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local r = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if r and r:IsA("BasePart") then
			local d = (r.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

local function anyNear(range: number): boolean
	local _, d = nearestPlayer(ORIGIN + Vector3.new(0, 8, 0))
	return d <= range
end

-- sapa pemain yang mendekat: berbalik (staf diam), melambai, gelembung ucapan
local waveTracks: { [Model]: AnimationTrack } = {}

local function greetLoop()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, info in STAFF do
			local model = info.model
			local root = if model then model.PrimaryPart else nil
			local last = info.lastGreetAt
			if model and root and (last == nil or now - last > GREET_COOLDOWN) then
				local player, distance = nearestPlayer(root.Position)
				if player and distance <= GREET_RANGE then
					info.lastGreetAt = now
					local character = player.Character
					local theirRoot = if character
						then character:FindFirstChild("HumanoidRootPart")
						else nil
					if info.patrol == nil and theirRoot and theirRoot:IsA("BasePart") then
						local here = root.Position
						model:PivotTo(
							CFrame.lookAt(
								here,
								Vector3.new(theirRoot.Position.X, here.Y, theirRoot.Position.Z)
							)
						)
					end
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local wave = waveTracks[model]
						if wave == nil then
							wave = track(humanoid, ANIM.sapa, false, Enum.AnimationPriority.Action2)
							waveTracks[model] = wave
						end
						wave:Play(0.2)
					end
					bubble(model, info.greet[math.random(1, #info.greet)])
				end
			end
		end
	end
end

function HotelStaffService.init()
	local folder = Workspace:FindFirstChild("StafHotel") or Instance.new("Folder")
	folder.Name = "StafHotel"
	folder.Parent = Workspace
end

function HotelStaffService.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NPC)
	end)
	task.spawn(greetLoop)
	task.spawn(function()
		while true do
			local near = anyNear(SPAWN_RANGE)
			local far = not anyNear(DESPAWN_RANGE)
			for _, info in STAFF do
				local model = info.model
				if model and model.Parent == nil then
					info.model = nil
					model = nil
				end
				if model == nil and near then
					spawnStaff(info)
				elseif model and far then
					waveTracks[model] = nil
					model:Destroy()
					info.model = nil
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return HotelStaffService
