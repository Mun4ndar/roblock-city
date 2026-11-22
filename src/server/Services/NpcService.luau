--!strict
-- NpcService: warga kota (NPC) yang berjalan-jalan sendiri supaya kota terasa hidup.
--   * tiap kelompok punya daftar tempat (dari JobConfig.PLACES); warga berjalan dari
--     satu tempat ke tempat lain lewat PathfindingService, berhenti sebentar, lalu lanjut
--   * karakter asli buatan sendiri: rig R15 polos dengan warna baju/celana/kulit acak
--     dan rambut dari part (tanpa aset pihak ketiga)
--   * tidak bertabrakan dengan kendaraan, jadi mobil tidak pernah "menabrak" warga
-- Menambah warga = menambah kelompok atau menaikkan `count` di GROUPS.

local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))

local NpcService = {}

local GROUP_NPC = "Npc"
local WALK_ANIMATION = "rbxassetid://913402848" -- animasi jalan R15 bawaan Roblox
local IDLE_ANIMATION = "rbxassetid://507766388" -- animasi diam R15 bawaan Roblox
local STEP_TIMEOUT = 8 -- detik per titik jalur sebelum dianggap tersangkut

local GROUPS = {
	{
		name = "KotaKecil",
		count = 6,
		places = {
			"rumahSakit",
			"toko",
			"kafe",
			"damkar",
			"bengkel",
			"balaiKota",
			"tamanPerumahan",
		},
	},
	{
		name = "PusatKota",
		count = 6,
		places = {
			"kafeKota",
			"pusatBisnis",
			"perpustakaan",
			"tamanKota",
			"mall",
			"kantorPos",
			"bioskop",
		},
	},
	{
		name = "Pantai",
		count = 4,
		places = { "kiosKelapa", "kiosEsKrim", "sewaJetSki", "dermaga" },
	},
}

local rgb = Color3.fromRGB
local SKINS = {
	rgb(255, 214, 170),
	rgb(240, 190, 140),
	rgb(224, 172, 120),
	rgb(168, 116, 76),
	rgb(120, 80, 52),
}
local SHIRTS = {
	rgb(235, 90, 90),
	rgb(90, 150, 235),
	rgb(64, 190, 100),
	rgb(255, 184, 0),
	rgb(170, 110, 220),
	rgb(255, 140, 180),
	rgb(240, 240, 235),
	rgb(40, 170, 170),
}
local PANTS =
	{ rgb(50, 60, 90), rgb(90, 70, 50), rgb(60, 60, 66), rgb(40, 90, 120), rgb(200, 190, 170) }
local HAIRS =
	{ rgb(40, 30, 26), rgb(90, 60, 40), rgb(20, 20, 24), rgb(180, 130, 70), rgb(120, 120, 126) }

local folder: Folder
local random = Random.new()

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

local function placePosition(key: string): Vector3?
	local place = (JobConfig.PLACES :: any)[key]
	return if place then place.position else nil
end

-- Titik acak di sekitar sebuah tempat supaya warga tidak menumpuk di satu titik.
local function near(position: Vector3): Vector3
	return position + Vector3.new(random:NextNumber(-7, 7), 3, random:NextNumber(-7, 7))
end

local function buildNpc(index: number): Model?
	local description = Instance.new("HumanoidDescription")
	local skin, shirt, pants = pick(SKINS), pick(SHIRTS), pick(PANTS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Npc] gagal membuat warga: " .. tostring(model))
		return nil
	end
	model.Name = "Warga" .. tostring(index)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if humanoid == nil or head == nil or not head:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = random:NextNumber(7, 10)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.BreakJointsOnDeath = false
	-- Skrip animasi bawaan hanya berjalan untuk pemain; warga dianimasikan dari server.
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") then
			child:Destroy()
		end
	end
	-- rambut sederhana dari part
	local hair = Instance.new("Part")
	hair.Name = "Rambut"
	hair.Shape = Enum.PartType.Ball
	hair.Size = Vector3.new(1.45, 1.45, 1.45)
	hair.Color = pick(HAIRS)
	hair.Material = Enum.Material.SmoothPlastic
	hair.Massless = true
	hair.CanCollide = false
	hair.CanQuery = false
	hair.CanTouch = false
	hair.CFrame = head.CFrame * CFrame.new(0, 0.32, 0.12)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hair
	weld.Parent = hair
	hair.Parent = model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP_NPC
			d.CanTouch = false
		end
	end
	return model
end

local function animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id: string): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end
	local walk, idle = load(WALK_ANIMATION), load(IDLE_ANIMATION)
	walk.Looped = true
	idle.Looped = true
	idle:Play()
	humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
			end
			walk:AdjustSpeed(speed / 9)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
end

-- Berjalan ke tujuan lewat jalur; kalau tersangkut atau tidak ada jalur, pindah langsung.
local function walkTo(model: Model, humanoid: Humanoid, goal: Vector3)
	local root = humanoid.RootPart
	if root == nil then
		return
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 8,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		model:PivotTo(CFrame.new(goal))
		return
	end
	for _, waypoint in path:GetWaypoints() do
		if model.Parent == nil then
			return
		end
		humanoid:MoveTo(waypoint.Position)
		local reached = false
		local connection = humanoid.MoveToFinished:Connect(function()
			reached = true
		end)
		local waited = 0
		while not reached and waited < STEP_TIMEOUT do
			waited += task.wait(0.2)
		end
		connection:Disconnect()
		if not reached then
			model:PivotTo(CFrame.new(goal))
			return
		end
	end
end

local function live(model: Model, places: { Vector3 })
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	animate(humanoid)
	while model.Parent ~= nil do
		task.wait(random:NextNumber(2, 7)) -- berhenti sebentar, lihat-lihat
		local root = humanoid.RootPart
		if root == nil then
			return
		end
		if root.Position.Y < -30 then
			model:PivotTo(CFrame.new(near(pick(places)))) -- jatuh ke air/lubang: kembali ke darat
		end
		walkTo(model, humanoid, near(pick(places)))
	end
end

function NpcService.init()
	PhysicsService:RegisterCollisionGroup(GROUP_NPC)
	folder = Instance.new("Folder")
	folder.Name = "Warga"
	folder.Parent = Workspace
end

function NpcService.start()
	-- Grup tabrakan kendaraan didaftarkan VehicleService.init(); di sini tinggal dimatikan.
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP_NPC, VehicleBuilder.GROUP_BODY, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_NPC, VehicleBuilder.GROUP_WHEEL, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_NPC, GROUP_NPC, false)
	end)
	local index = 0
	for _, group in GROUPS do
		local places: { Vector3 } = {}
		for _, key in group.places do
			local position = placePosition(key)
			if position then
				table.insert(places, position)
			end
		end
		if #places < 2 then
			continue
		end
		for _ = 1, group.count do
			index += 1
			local model = buildNpc(index)
			if model then
				model:PivotTo(CFrame.new(near(pick(places))))
				model.Parent = folder
				local root = model.PrimaryPart
				if root then
					pcall(function()
						root:SetNetworkOwner(nil)
					end)
				end
				task.spawn(live, model, places)
			end
			task.wait(0.2)
		end
	end
end

return NpcService
