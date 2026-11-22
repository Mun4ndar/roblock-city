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
local SHOES =
	{ rgb(40, 40, 46), rgb(245, 245, 240), rgb(120, 80, 50), rgb(220, 70, 70), rgb(60, 110, 200) }
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

-- Part hiasan yang menempel di bagian tubuh (rambut, topi, ransel, ...).
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
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

local function buildNpc(index: number): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = random:NextNumber(0.88, 1.06)
	description.WidthScale = random:NextNumber(0.9, 1.05)
	description.HeadScale = random:NextNumber(0.98, 1.08)
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
	-- Pakaian: lengan pendek, celana, sepatu (warna per bagian tubuh, bukan satu warna polos).
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	local shoes = pick(SHOES)
	local dress = random:NextNumber() < 0.3 -- sebagian warga memakai terusan
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local n = d.Name
			if n:match("Foot$") then
				d.Color = shoes
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				d.Color = shirt
			elseif n == "LowerTorso" or n:match("UpperLeg$") then
				d.Color = if dress then shirt else pants
			elseif n:match("LowerLeg$") then
				d.Color = if dress then skin else pants
			elseif n ~= "HumanoidRootPart" then
				d.Color = skin
			end
		end
	end
	local torso = model:FindFirstChild("UpperTorso")
	local hairColor = pick(HAIRS)
	local smooth = Enum.Material.SmoothPlastic
	local ball, block, cylinder = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
	-- Rambut/topi: empat gaya dari part.
	local style = random:NextInteger(1, 4)
	if style == 1 then -- rambut pendek
		attach(
			model,
			head,
			Vector3.new(1.42, 1.3, 1.42),
			CFrame.new(0, 0.36, 0.08),
			hairColor,
			ball,
			smooth
		)
	elseif style == 2 then -- rambut panjang
		attach(
			model,
			head,
			Vector3.new(1.46, 1.36, 1.46),
			CFrame.new(0, 0.34, 0.1),
			hairColor,
			ball,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(1.3, 1.5, 0.45),
			CFrame.new(0, -0.35, 0.58),
			hairColor,
			block,
			smooth
		)
	elseif style == 3 then -- sanggul / kuncir
		attach(
			model,
			head,
			Vector3.new(1.42, 1.3, 1.42),
			CFrame.new(0, 0.36, 0.08),
			hairColor,
			ball,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(0, 0.95, 0.45),
			hairColor,
			ball,
			smooth
		)
	else -- topi bertepi
		local hat = pick(SHIRTS)
		attach(
			model,
			head,
			Vector3.new(0.55, 1.4, 1.4),
			CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, math.pi / 2),
			hat,
			cylinder,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(0.12, 1.9, 1.9),
			CFrame.new(0, 0.5, -0.25) * CFrame.Angles(0, 0, math.pi / 2),
			hat,
			cylinder,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(1.3, 0.5, 0.3),
			CFrame.new(0, 0.1, 0.55),
			hairColor,
			block,
			smooth
		)
	end
	if torso and torso:IsA("BasePart") then
		local extra = random:NextNumber()
		if extra < 0.3 then -- ransel
			attach(
				model,
				torso,
				Vector3.new(1.5, 1.6, 0.7),
				CFrame.new(0, 0.05, 0.85),
				pick(SHIRTS),
				block,
				Enum.Material.Fabric
			)
			attach(
				model,
				torso,
				Vector3.new(1.1, 0.5, 0.3),
				CFrame.new(0, -0.3, 1.25),
				pick(PANTS),
				block,
				Enum.Material.Fabric
			)
		elseif extra < 0.55 then -- jaket terbuka: garis tengah berwarna lain
			attach(
				model,
				torso,
				Vector3.new(0.5, 1.5, 0.08),
				CFrame.new(0, 0, -0.52),
				rgb(245, 245, 240),
				block,
				smooth
			)
		elseif extra < 0.75 then -- saku / lencana kecil
			attach(
				model,
				torso,
				Vector3.new(0.5, 0.45, 0.08),
				CFrame.new(0.5, 0.35, -0.52),
				pick(PANTS),
				block,
				smooth
			)
		end
	end
	if random:NextNumber() < 0.2 then -- kacamata
		attach(
			model,
			head,
			Vector3.new(1.1, 0.26, 0.1),
			CFrame.new(0, 0.12, -0.62),
			rgb(30, 30, 36),
			block,
			smooth
		)
	end
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
