--!strict
--[[
	BalaiKotaService: staf berjas di dalam Balai Kota (aula, loket, ruang walikota, sayap pelayanan).
	Tiap staf = avatar R15 yang dibuat dari kode (jas, kemeja, dasi, rambut) dengan animasi kerja dari
	Studio (generate_animation: mengetik, menyapa, mencatat, mencap, menandatangani). Hanya ada saat
	ada pemain dalam SPAWN_RANGE stud (hemat HP) dan dihapus lagi saat semua pemain lebih dari DESPAWN_RANGE.
	Koordinat dalam Blender (x, y, z) -> dunia: ORIGIN + (x, z, -y), sama dengan map/BuildBalaiKotaDalam.
	Satu staf (kurir dokumen) berjalan bolak-balik di aula.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BalaiKotaService = {}

local ORIGIN = Vector3.new(160, 1, 135)
local FLOOR = 1.3 -- tinggi lantai dalam (Blender z)
local CENTER = ORIGIN + Vector3.new(0, 10, 2) -- tengah aula (Blender y -2)
local SPAWN_RANGE = 110
local DESPAWN_RANGE = 160
local CHECK_SECONDS = 3
local GROUP_NPC = "Npc"

local ANIM = {
	ketik = "rbxassetid://75023251394352", -- duduk mengetik
	sapa = "rbxassetid://139976582794074", -- berdiri menyapa, tangan bergerak
	catat = "rbxassetid://120301783800111", -- berdiri mencatat di papan jepit
	cap = "rbxassetid://133709150452002", -- berdiri mencap dokumen
	tanda = "rbxassetid://78524220707329", -- duduk membaca dan menandatangani
	jalan = "rbxassetid://913402848",
	diam = "rbxassetid://507766388",
}

local rgb = Color3.fromRGB

type Staff = {
	name: string,
	title: string,
	at: Vector3, -- (x, y, z) Blender, z = tinggi lantai
	face: Vector2, -- arah hadap (x, y) Blender
	anim: string,
	seated: boolean?,
	skin: Color3,
	suit: Color3,
	pants: Color3,
	hair: Color3,
	hairStyle: string,
	woman: boolean?,
	tie: Color3?,
	glasses: boolean?,
	patrol: { Vector2 }?,
	model: Model?,
}

local STAFF: { Staff } = {
	{
		name = "Bu Sari",
		title = "Resepsionis",
		at = Vector3.new(-3.2, -10.3, FLOOR),
		face = Vector2.new(0, 1),
		anim = "sapa",
		skin = rgb(240, 200, 165),
		suit = rgb(36, 52, 98),
		pants = rgb(36, 52, 98),
		hair = rgb(50, 34, 28),
		hairStyle = "sanggul",
		woman = true,
		tie = rgb(226, 172, 52),
	},
	{
		name = "Pak Dedi",
		title = "Resepsionis",
		at = Vector3.new(3.2, -10.3, FLOOR),
		face = Vector2.new(0, 1),
		anim = "catat",
		skin = rgb(205, 150, 110),
		suit = rgb(40, 44, 56),
		pants = rgb(40, 44, 56),
		hair = rgb(30, 26, 26),
		hairStyle = "rapi",
		tie = rgb(190, 50, 56),
	},
	{
		name = "Pak Rudi",
		title = "Petugas Loket 1",
		at = Vector3.new(-12, 7.5, FLOOR),
		face = Vector2.new(0, -1),
		anim = "ketik",
		seated = true,
		skin = rgb(225, 180, 140),
		suit = rgb(56, 62, 76),
		pants = rgb(40, 44, 56),
		hair = rgb(40, 30, 24),
		hairStyle = "rapi",
		tie = rgb(40, 110, 180),
		glasses = true,
	},
	{
		name = "Bu Maya",
		title = "Petugas Loket 2",
		at = Vector3.new(12, 7.5, FLOOR),
		face = Vector2.new(0, -1),
		anim = "tanda",
		seated = true,
		skin = rgb(235, 190, 150),
		suit = rgb(118, 38, 56),
		pants = rgb(60, 30, 40),
		hair = rgb(30, 24, 22),
		hairStyle = "sanggul",
		woman = true,
		tie = rgb(250, 240, 220),
	},
	{
		name = "Pak Hendra",
		title = "Walikota",
		at = Vector3.new(-32.3, -2, FLOOR),
		face = Vector2.new(1, 0),
		anim = "tanda",
		seated = true,
		skin = rgb(215, 165, 125),
		suit = rgb(24, 34, 70),
		pants = rgb(24, 34, 70),
		hair = rgb(150, 150, 156),
		hairStyle = "rapi",
		tie = rgb(190, 50, 56),
		glasses = true,
	},
	{
		name = "Bu Ratna",
		title = "Sekretaris",
		at = Vector3.new(-26.5, -7.2, FLOOR),
		face = Vector2.new(-1, 0.6),
		anim = "catat",
		skin = rgb(230, 185, 148),
		suit = rgb(70, 78, 98),
		pants = rgb(46, 52, 68),
		hair = rgb(36, 26, 22),
		hairStyle = "sanggul",
		woman = true,
		tie = rgb(70, 165, 150),
	},
	{
		name = "Pak Joko",
		title = "Petugas Pelayanan",
		at = Vector3.new(28.8, -2, FLOOR),
		face = Vector2.new(-1, 0),
		anim = "cap",
		skin = rgb(200, 148, 108),
		suit = rgb(48, 74, 70),
		pants = rgb(40, 56, 54),
		hair = rgb(28, 24, 22),
		hairStyle = "rapi",
		tie = rgb(226, 172, 52),
	},
	{
		name = "Pak Anto",
		title = "Kurir Dokumen",
		at = Vector3.new(-7, 5.6, FLOOR),
		face = Vector2.new(1, 0),
		anim = "diam",
		skin = rgb(215, 165, 125),
		suit = rgb(86, 90, 100),
		pants = rgb(46, 50, 62),
		hair = rgb(30, 26, 26),
		hairStyle = "rapi",
		tie = rgb(40, 110, 180),
		patrol = { Vector2.new(-7, 5.6), Vector2.new(7, 5.6) },
	},
}

local function world(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, z, -y)
end

local function attach(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType,
	material: Enum.Material
)
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
		warn("[BalaiKota] gagal membuat staf: " .. tostring(model))
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
	humanoid.WalkSpeed = 6
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
	-- jas: badan + lengan; celana/rok: kaki; sepatu hitam
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			part.Material = Enum.Material.SmoothPlastic
			if n:match("Hand$") or n == "Head" then
				part.Color = info.skin
			elseif n:match("Foot$") then
				part.Color = rgb(28, 26, 28)
			elseif n:match("Leg$") then
				part.Color = if info.woman and n:match("LowerLeg$") then info.skin else info.pants
			else
				part.Color = info.suit
			end
		end
	end
	-- kemeja putih + dasi/syal + kancing
	attach(
		model,
		torso,
		Vector3.new(0.75, 1.25, 0.06),
		CFrame.new(0, 0.15, -0.51),
		rgb(250, 250, 248),
		Enum.PartType.Block,
		Enum.Material.SmoothPlastic
	)
	local tieColor = info.tie or rgb(190, 50, 56)
	if info.woman then
		attach(
			model,
			torso,
			Vector3.new(0.7, 0.28, 0.1),
			CFrame.new(0, 0.62, -0.53),
			tieColor,
			Enum.PartType.Block,
			Enum.Material.SmoothPlastic
		)
	else
		attach(
			model,
			torso,
			Vector3.new(0.2, 1.0, 0.08),
			CFrame.new(0, 0.08, -0.55),
			tieColor,
			Enum.PartType.Block,
			Enum.Material.SmoothPlastic
		)
		attach(
			model,
			torso,
			Vector3.new(0.3, 0.26, 0.1),
			CFrame.new(0, 0.58, -0.54),
			tieColor,
			Enum.PartType.Block,
			Enum.Material.SmoothPlastic
		)
	end
	attach(
		model,
		torso,
		Vector3.new(0.12, 0.12, 0.08),
		CFrame.new(0.55, -0.4, -0.52),
		rgb(226, 172, 52),
		Enum.PartType.Ball,
		Enum.Material.Metal
	)
	-- rambut
	local smooth, ball, block = Enum.Material.SmoothPlastic, Enum.PartType.Ball, Enum.PartType.Block
	attach(
		model,
		head,
		Vector3.new(1.4, 1.2, 1.4),
		CFrame.new(0, 0.36, 0.08),
		info.hair,
		ball,
		smooth
	)
	if info.hairStyle == "sanggul" then
		attach(
			model,
			head,
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(0, 0.72, 0.58),
			info.hair,
			ball,
			smooth
		)
	else
		attach(
			model,
			head,
			Vector3.new(1.3, 0.35, 0.6),
			CFrame.new(0, 0.62, -0.46),
			info.hair,
			block,
			smooth
		)
	end
	if info.glasses then
		for _, dx in { -0.26, 0.26 } do
			local lens = attach(
				model,
				head,
				Vector3.new(0.34, 0.34, 0.05),
				CFrame.new(dx, 0.08, -0.62),
				rgb(30, 30, 34),
				Enum.PartType.Cylinder,
				smooth
			)
			lens.CFrame = head.CFrame
				* CFrame.new(dx, 0.08, -0.62)
				* CFrame.Angles(0, math.rad(90), 0)
			lens.Transparency = 0.5
		end
	end
	-- papan nama kecil
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(150, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0)
	board.MaxDistance = 28
	board.AlwaysOnTop = false
	board.Parent = head
	local line1 = Instance.new("TextLabel")
	line1.BackgroundTransparency = 1
	line1.Size = UDim2.new(1, 0, 0.55, 0)
	line1.Text = info.name
	line1.Font = Enum.Font.GothamBold
	line1.TextSize = 16
	line1.TextColor3 = rgb(255, 255, 255)
	line1.TextStrokeTransparency = 0.4
	line1.Parent = board
	local line2 = Instance.new("TextLabel")
	line2.BackgroundTransparency = 1
	line2.Position = UDim2.fromScale(0, 0.52)
	line2.Size = UDim2.new(1, 0, 0.45, 0)
	line2.Text = info.title
	line2.Font = Enum.Font.Gotham
	line2.TextSize = 13
	line2.TextColor3 = rgb(255, 232, 160)
	line2.TextStrokeTransparency = 0.4
	line2.Parent = board
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
			goal = Vector3.new(goal.X, model.PrimaryPart.Position.Y, goal.Z)
			idle:Stop(0.2)
			walk:Play(0.2)
			humanoid:MoveTo(goal)
			local waited = 0
			while
				model.Parent
				and (
					model.PrimaryPart.Position * Vector3.new(1, 0, 1)
					- goal * Vector3.new(1, 0, 1)
				).Magnitude > 2
				and waited < 14
			do
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
	-- pusat akar: tinggi lantai + pinggul + setengah akar; duduk = turun sedikit (animasi menurunkan panggul)
	local rootY = floor.Y
		+ humanoid.HipHeight
		+ root.Size.Y / 2
		- (if info.seated then -0.55 else 0)
	local position = Vector3.new(floor.X, rootY, floor.Z)
	local lookAt = position + Vector3.new(info.face.X, 0, -info.face.Y)
	model:PivotTo(CFrame.lookAt(position, lookAt))
	model.Parent = Workspace:FindFirstChild("StafBalaiKota")
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

function BalaiKotaService.init()
	local folder = Workspace:FindFirstChild("StafBalaiKota") or Instance.new("Folder")
	folder.Name = "StafBalaiKota"
	folder.Parent = Workspace
end

function BalaiKotaService.start()
	-- grup tabrakan "Npc" didaftarkan NpcService.init(); kalau belum ada, daftarkan sendiri
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NPC)
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

return BalaiKotaService
