--!strict
--[[
	ConcertService: Panggung Konser Taman Kota. Model panggung = Workspace.Map.Panggung (map/BuildPanggung).
	Konser jalan malam (ConcertConfig.SHOW_FROM..SHOW_TO jam permainan):
	  - musik koplo/dangdut/campursari berlisensi (IndonesiaConfig.STATIONS) jadi Sound 3D di panggung, bergantian;
	  - penampil NPC (R15, animasi emote resmi Roblox) muncul hanya kalau ada pemain dalam NPC_RANGE;
	  - atribut Workspace KonserAktif / KonserKembangApi / KonserLagu dibaca ConcertController (lampu, layar LED,
	    kembang api, confetti). Di luar jam konser: musik berhenti, penampil pulang.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ConcertConfig"))

local ConcertService = {}

local rgb = Color3.fromRGB

local folder: Folder
local performersFolder: Folder
local active = false
local nextFirework = 0
local building = false

-- ---------------------------------------------------------------- musik
-- Lagu dimainkan di tiap client (ConcertController); server hanya memberi benih urutan acak.
local function newSeed()
	Workspace:SetAttribute(Config.ATTR_SEED, Random.new():NextInteger(1, 1000000))
end

-- ---------------------------------------------------------------- penampil NPC
local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function prop(parent: Instance, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function addProp(model: Model, role: string)
	local rightHand = model:FindFirstChild("RightHand") :: BasePart?
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	local lower = model:FindFirstChild("LowerTorso") :: BasePart?
	if role == "vokal" and rightHand then
		-- mikrofon di tangan kanan
		local grip = prop(model, nil, Vector3.new(0.18, 0.9, 0.18), rgb(40, 40, 46), Enum.Material.Metal)
		grip.CFrame = rightHand.CFrame * CFrame.new(0, -0.1, -0.2) * CFrame.Angles(math.rad(70), 0, 0)
		weld(rightHand, grip)
		local head = prop(model, Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.42), rgb(200, 205, 215), Enum.Material.Metal)
		head.CFrame = grip.CFrame * CFrame.new(0, 0.55, 0)
		weld(grip, head)
	elseif role == "gitar" and torso then
		local body = prop(model, nil, Vector3.new(1.5, 1.9, 0.35), rgb(255, 120, 40), Enum.Material.SmoothPlastic)
		body.CFrame = torso.CFrame * CFrame.new(0.2, -0.5, -0.7) * CFrame.Angles(0, 0, math.rad(25))
		weld(torso, body)
		local neck = prop(model, nil, Vector3.new(0.28, 2.6, 0.2), rgb(120, 80, 50), Enum.Material.Wood)
		neck.CFrame = body.CFrame * CFrame.new(0, 2.1, 0)
		weld(body, neck)
	elseif role == "kendang" and lower then
		local drum = prop(model, Enum.PartType.Cylinder, Vector3.new(2.6, 1.3, 1.3), rgb(170, 100, 50), Enum.Material.Wood)
		drum.CFrame = lower.CFrame * CFrame.new(0, 0.2, -1.4) * CFrame.Angles(0, math.rad(90), math.rad(0))
		weld(lower, drum)
		local skin = prop(model, Enum.PartType.Cylinder, Vector3.new(0.1, 1.2, 1.2), rgb(245, 232, 200))
		skin.CFrame = drum.CFrame * CFrame.new(1.32, 0, 0)
		weld(drum, skin)
	end
end

local function floorY(x: number, z: number, fallback: number): number
	local map = Workspace:FindFirstChild("Map")
	local stage = map and map:FindFirstChild("Panggung")
	local fisik = stage and stage:FindFirstChild("Fisik")
	if fisik == nil then
		return fallback
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { fisik }
	local hit = Workspace:Raycast(Vector3.new(x, fallback + 20, z), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function buildPerformer(who: any, phase: number): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = who.skin
	description.LeftArmColor = who.skin
	description.RightArmColor = who.skin
	description.TorsoColor = who.shirt
	description.LeftLegColor = who.pants
	description.RightLegColor = who.pants
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Concert] gagal membuat penampil: " .. tostring(model))
		return nil
	end
	model.Name = "Penampil_" .. who.name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or head == nil or not head:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
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
				d.Color = rgb(245, 245, 240)
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				d.Color = who.shirt
			elseif n == "LowerTorso" or n:match("UpperLeg$") then
				d.Color = if who.dress then who.shirt else who.pants
			elseif n:match("LowerLeg$") then
				d.Color = if who.dress then who.skin else who.pants
			elseif n ~= "HumanoidRootPart" then
				d.Color = who.skin
			end
		end
	end
	local hair = prop(model, Enum.PartType.Ball, Vector3.new(1.42, 1.3, 1.42), who.hair)
	hair.Name = "Rambut"
	hair.CFrame = head.CFrame * CFrame.new(0, 0.36, 0.08)
	weld(head :: BasePart, hair)

	local pos = Config.world(who.at.X, who.at.Y, 3)
	local look = Config.world(who.at.X, who.at.Y + 40, 3) -- menghadap penonton
	local y = floorY(pos.X, pos.Z, 3) + humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(look.X, y, look.Z)))
	root.Anchored = true
	addProp(model, who.role)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	model.Parent = performersFolder
	task.spawn(function()
		task.wait(phase)
		local current: AnimationTrack? = nil
		local index = (math.floor(phase * 10) % #who.anims) + 1
		while model.Parent == performersFolder do
			local animation = Instance.new("Animation")
			animation.AnimationId = who.anims[index]
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play(0.3)
			if current then
				current:Stop(0.3)
			end
			current = track
			task.wait(13 + phase * 2)
			index = (index % #who.anims) + 1
		end
		if current then
			current:Stop(0)
		end
	end)
	return model
end

local function spawnPerformers()
	if building or #performersFolder:GetChildren() > 0 then
		return
	end
	building = true
	for i, who in Config.PERFORMERS do
		if not active then
			break
		end
		buildPerformer(who, i * 0.6)
	end
	building = false
end

local function clearPerformers()
	for _, m in performersFolder:GetChildren() do
		m:Destroy()
	end
end

local function playerNear(range: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - Config.CENTER).Magnitude <= range then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- jadwal
local function startShow()
	active = true
	Workspace:SetAttribute(Config.ATTR_ACTIVE, true)
	nextFirework = os.clock() + 4
	newSeed()
end

local function stopShow()
	active = false
	Workspace:SetAttribute(Config.ATTR_ACTIVE, false)
	clearPerformers()
end

function ConcertService.init()
	folder = Instance.new("Folder")
	folder.Name = "KonserHidup"
	folder.Parent = Workspace
	performersFolder = Instance.new("Folder")
	performersFolder.Name = "Penampil"
	performersFolder.Parent = folder

	local anchor = Instance.new("Part")
	anchor.Name = "TitikMusik"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Config.world(Config.MUSIC_SPOT.X, Config.MUSIC_SPOT.Y, Config.MUSIC_SPOT.Z)
	anchor.Parent = folder

	Workspace:SetAttribute(Config.ATTR_ACTIVE, false)
	Workspace:SetAttribute(Config.ATTR_FIREWORK, 0)
	Workspace:SetAttribute(Config.ATTR_TRACK, 0)
end

function ConcertService.start()
	task.spawn(function()
		local rng = Random.new()
		while true do
			local want = Config.isShowTime(Lighting.ClockTime)
			if want and not active then
				startShow()
			elseif not want and active then
				stopShow()
			end
			if active then
				if #performersFolder:GetChildren() == 0 and not building and playerNear(Config.NPC_RANGE) then
					task.spawn(spawnPerformers)
				elseif #performersFolder:GetChildren() > 0 and not playerNear(Config.NPC_KEEP) then
					clearPerformers()
				end
				if os.clock() >= nextFirework then
					nextFirework = os.clock() + rng:NextNumber(Config.FIREWORK_EVERY[1], Config.FIREWORK_EVERY[2])
					Workspace:SetAttribute(Config.ATTR_FIREWORK, ((Workspace:GetAttribute(Config.ATTR_FIREWORK) or 0) :: number) + 1)
				end
			end
			task.wait(2)
		end
	end)
end

return ConcertService
