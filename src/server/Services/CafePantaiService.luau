--!strict
-- CafePantaiService: Kafe Pantai punya jam buka (jam permainan), musik khusus yang hanya terdengar
-- di sekitar kafe saat buka, dan beberapa penari (NPC) di lantai dansa. Saat tutup: musik berhenti,
-- penari pulang (dipindah dari dunia), papan berubah jadi "TUTUP". Model bangunan kafe sendiri
-- diletakkan di Studio (Workspace.Map.Beach.KafePantai); layanan ini hanya mengurus kehidupannya.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CafePantaiConfig"))

local CafePantaiService = {}

local rgb = Color3.fromRGB

type Dancer = {
	name: string,
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hair: Color3,
	dress: boolean?,
}

local DANCERS: { Dancer } = {
	{
		name = "Dewi",
		skin = rgb(240, 190, 140),
		shirt = rgb(255, 120, 160),
		pants = rgb(255, 120, 160),
		hair = rgb(30, 26, 26),
		dress = true,
	},
	{
		name = "Raka",
		skin = rgb(224, 172, 120),
		shirt = rgb(60, 180, 220),
		pants = rgb(245, 245, 240),
		hair = rgb(70, 45, 30),
	},
	{
		name = "Mira",
		skin = rgb(214, 160, 116),
		shirt = rgb(255, 200, 40),
		pants = rgb(60, 90, 160),
		hair = rgb(30, 26, 26),
	},
	{
		name = "Bayu",
		skin = rgb(224, 172, 120),
		shirt = rgb(120, 210, 120),
		pants = rgb(40, 52, 78),
		hair = rgb(30, 26, 26),
	},
	{
		name = "Tika",
		skin = rgb(240, 190, 140),
		shirt = rgb(170, 120, 220),
		pants = rgb(170, 120, 220),
		hair = rgb(96, 62, 40),
		dress = true,
	},
	{
		name = "Joni",
		skin = rgb(214, 160, 116),
		shirt = rgb(255, 150, 60),
		pants = rgb(60, 70, 90),
		hair = rgb(30, 26, 26),
	},
}

local folder: Folder
local dancers: { Model } = {}
local music: Sound
local signLabel: TextLabel
local isOpen = false
local trackIndex = 0

local function floorY(x: number, z: number, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(Vector3.new(x, fallback + 30, z), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function buildDancer(who: Dancer, position: Vector3, lookAt: Vector3, phase: number): Model?
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
		warn("[CafePantai] gagal membuat penari: " .. tostring(model))
		return nil
	end
	model.Name = "Penari_" .. who.name
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
	-- rambut: bola kecil di kepala
	local hair = Instance.new("Part")
	hair.Name = "Rambut"
	hair.Shape = Enum.PartType.Ball
	hair.Size = Vector3.new(1.42, 1.3, 1.42)
	hair.Color = who.hair
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

	local y = floorY(position.X, position.Z, position.Y) + humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(
		CFrame.lookAt(Vector3.new(position.X, y, position.Z), Vector3.new(lookAt.X, y, lookAt.Z))
	)
	root.Anchored = true

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	model.Parent = folder
	-- tiap penari memulai dansa dengan jeda berbeda dan ganti gaya berkala
	task.spawn(function()
		task.wait(phase)
		local current: AnimationTrack? = nil
		local index = (math.floor(phase * 10) % #Config.DANCE_ANIMATIONS) + 1
		while model.Parent == folder do
			local animation = Instance.new("Animation")
			animation.AnimationId = Config.DANCE_ANIMATIONS[index]
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play(0.3)
			if current then
				current:Stop(0.3)
			end
			current = track
			task.wait(18 + phase * 3)
			index = (index % #Config.DANCE_ANIMATIONS) + 1
		end
		if current then
			current:Stop(0)
		end
	end)
	return model
end

local function setSign(open: boolean)
	if open then
		signLabel.Text = "KAFE PANTAI  •  BUKA"
		signLabel.TextColor3 = rgb(120, 255, 150)
	else
		signLabel.Text = "KAFE PANTAI  •  TUTUP\nbuka jam "
			.. string.format("%02d.00", Config.OPEN_FROM)
		signLabel.TextColor3 = rgb(255, 150, 140)
	end
end

local function nextTrack()
	trackIndex = (trackIndex % #Config.PLAYLIST) + 1
	music.SoundId = "rbxassetid://" .. tostring(Config.PLAYLIST[trackIndex].id)
	music:Play()
end

local function openCafe()
	isOpen = true
	setSign(true)
	-- penari muncul
	local center = Config.DANCE_CENTER
	for i = 1, math.min(Config.DANCERS, #DANCERS) do
		local angle = (i - 1) / Config.DANCERS * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.DANCE_RADIUS
		local model = buildDancer(DANCERS[i], pos, center, i * 0.7)
		if model then
			table.insert(dancers, model)
		end
	end
	nextTrack()
end

local function closeCafe()
	isOpen = false
	setSign(false)
	music:Stop()
	for _, model in dancers do
		model:Destroy()
	end
	table.clear(dancers)
end

local function shouldBeOpen(): boolean
	local clock = Lighting.ClockTime
	return clock >= Config.OPEN_FROM and clock < Config.OPEN_TO
end

function CafePantaiService.init()
	folder = Instance.new("Folder")
	folder.Name = "KafePantaiHidup"
	folder.Parent = Workspace

	local anchor = Instance.new("Part")
	anchor.Name = "TitikMusik"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Config.DANCE_CENTER + Vector3.new(0, 6, 0)
	anchor.Parent = folder

	-- musik 3D: penuh dekat kafe, hilang makin jauh (hanya terdengar di sekitar kafe)
	music = Instance.new("Sound")
	music.Name = "MusikKafe"
	music.Volume = Config.VOLUME
	music.RollOffMode = Enum.RollOffMode.Linear
	music.RollOffMinDistance = Config.HEAR_MIN
	music.RollOffMaxDistance = Config.HEAR_MAX
	music.Looped = false
	music.Parent = anchor
	music.Ended:Connect(function()
		if isOpen then
			nextTrack()
		end
	end)

	local gui = Instance.new("BillboardGui")
	gui.Name = "PapanKafe"
	gui.Size = UDim2.fromOffset(300, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = gui
	gui.Parent = anchor
	setSign(false)
end

function CafePantaiService.start()
	task.spawn(function()
		while true do
			local want = shouldBeOpen()
			if want and not isOpen then
				openCafe()
			elseif not want and isOpen then
				closeCafe()
			end
			task.wait(2)
		end
	end)
	-- Sound.Looped=false di server: pemain yang baru masuk ikut mendengar dari posisi lagu sekarang.
	RunService.Heartbeat:Wait()
end

return CafePantaiService
