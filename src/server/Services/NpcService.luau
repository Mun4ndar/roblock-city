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
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local Format = require(Shared:WaitForChild("Format"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
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
		seatsIn = "Beach", -- warga di sini juga duduk santai di kursi (Seat) dalam Workspace.Map.Beach
	},
	{
		-- Petani di Perkebunan Besar: avatar modern (bukan blok klasik) dari ServerStorage.AsetPetani,
		-- dibuat dengan generate_avatar; kalau templatnya belum ada, kelompok ini dilewati.
		name = "Petani",
		count = 4,
		places = {
			"ladangUtara",
			"ladangTengah",
			"ladangSelatan",
			"ladangBarat",
			"ladangTimur",
			"tokoBibit",
			"gudangTani",
		},
		template = "AsetPetani",
	},
	{
		-- Penjaga Pasar Tani: satu avatar modern yang mondar-mandir di depan lapak.
		name = "PenjagaPasar",
		count = 1,
		places = { "pasarTaniKiri", "pasarTaniKanan" },
		template = "AsetPetani",
	},
	{
		-- Pengunjung Kafe Kota: hampir selalu duduk di teras sambil memegang cangkir kopi.
		name = "KafeKota",
		count = 4,
		places = { "kafeKota", "pusatBisnis" },
		seatsIn = "KafeKota",
		relaxChance = 0.85,
		sitSeconds = { 30, 70 },
		cup = true,
	},
	{
		-- Pengunjung Cafe Startduck di kota kecil (teras di sisi timur gedung).
		name = "Startduck",
		count = 3,
		places = { "kafe", "toko" },
		seatsIn = "Startduck",
		relaxChance = 0.85,
		sitSeconds = { 30, 70 },
		cup = true,
	},
}

local rgb = Color3.fromRGB
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

-- Enam belas warga, masing-masing karakter sendiri (bukan warna acak). Menambah warga baru =
-- menambah entri. style: pendek/panjang/sanggul/kribo/hijab/peci/caping/botak/topi.
-- extra: ransel/jaket/dasi/celemek/syal/saku.
type Character = {
	name: string,
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	shoes: Color3,
	hair: Color3,
	accent: Color3,
	style: string,
	extra: string?,
	height: number,
	width: number,
	dress: boolean?,
	glasses: boolean?,
	beard: boolean?,
}
local BLACK, BROWN, GREY = rgb(30, 26, 26), rgb(96, 62, 40), rgb(170, 170, 176)
local CHARACTERS: { Character } = {
	{
		name = "PakBudi",
		skin = rgb(224, 172, 120),
		shirt = rgb(245, 245, 240),
		pants = rgb(44, 52, 78),
		shoes = BLACK,
		hair = BLACK,
		accent = rgb(200, 50, 50),
		style = "pendek",
		extra = "dasi",
		height = 1.04,
		width = 1,
		glasses = true,
	},
	{
		name = "BuSari",
		skin = rgb(240, 190, 140),
		shirt = rgb(150, 100, 200),
		pants = rgb(150, 100, 200),
		shoes = rgb(245, 245, 240),
		hair = BLACK,
		accent = rgb(40, 170, 170),
		style = "hijab",
		height = 0.97,
		width = 0.95,
		dress = true,
	},
	{
		name = "Dimas",
		skin = rgb(224, 172, 120),
		shirt = rgb(255, 200, 40),
		pants = rgb(40, 90, 150),
		shoes = rgb(220, 70, 70),
		hair = BLACK,
		accent = rgb(220, 60, 60),
		style = "topi",
		extra = "ransel",
		height = 0.84,
		width = 0.92,
	},
	{
		name = "NenekIjah",
		skin = rgb(214, 160, 116),
		shirt = rgb(140, 84, 60),
		pants = rgb(140, 84, 60),
		shoes = BROWN,
		hair = GREY,
		accent = rgb(230, 200, 120),
		style = "sanggul",
		extra = "syal",
		height = 0.9,
		width = 0.98,
		dress = true,
		glasses = true,
	},
	{
		name = "MasJoko",
		skin = rgb(168, 116, 76),
		shirt = rgb(70, 140, 80),
		pants = rgb(110, 84, 56),
		shoes = BROWN,
		hair = BLACK,
		accent = rgb(226, 196, 120),
		style = "caping",
		height = 1.02,
		width = 1.04,
		beard = true,
	},
	{
		name = "KakRina",
		skin = rgb(255, 214, 170),
		shirt = rgb(255, 140, 180),
		pants = rgb(60, 90, 150),
		shoes = rgb(245, 245, 240),
		hair = BROWN,
		accent = rgb(245, 245, 240),
		style = "panjang",
		extra = "jaket",
		height = 0.98,
		width = 0.93,
	},
	{
		name = "PakUmar",
		skin = rgb(200, 150, 104),
		shirt = rgb(240, 240, 232),
		pants = rgb(90, 96, 104),
		shoes = BLACK,
		hair = GREY,
		accent = BLACK,
		style = "peci",
		extra = "saku",
		height = 1.03,
		width = 1.02,
		beard = true,
	},
	{
		name = "Lala",
		skin = rgb(255, 214, 170),
		shirt = rgb(255, 214, 80),
		pants = rgb(255, 214, 80),
		shoes = rgb(255, 140, 180),
		hair = BROWN,
		accent = rgb(255, 140, 180),
		style = "sanggul",
		height = 0.82,
		width = 0.9,
		dress = true,
	},
	{
		name = "BangTogar",
		skin = rgb(120, 80, 52),
		shirt = rgb(240, 130, 50),
		pants = rgb(50, 54, 62),
		shoes = rgb(245, 245, 240),
		hair = BLACK,
		accent = rgb(50, 54, 62),
		style = "kribo",
		extra = "saku",
		height = 1.06,
		width = 1.1,
	},
	{
		name = "ChefWati",
		skin = rgb(240, 190, 140),
		shirt = rgb(250, 250, 246),
		pants = rgb(60, 60, 66),
		shoes = BLACK,
		hair = BROWN,
		accent = rgb(250, 250, 246),
		style = "pendek",
		extra = "celemek",
		height = 0.96,
		width = 1.02,
	},
	{
		name = "KakYusuf",
		skin = rgb(168, 116, 76),
		shirt = rgb(64, 190, 100),
		pants = rgb(200, 190, 170),
		shoes = rgb(60, 110, 200),
		hair = BLACK,
		accent = rgb(60, 110, 200),
		style = "topi",
		extra = "ransel",
		height = 1.06,
		width = 0.96,
	},
	{
		name = "BuAni",
		skin = rgb(224, 172, 120),
		shirt = rgb(90, 150, 235),
		pants = rgb(50, 60, 90),
		shoes = BLACK,
		hair = BLACK,
		accent = rgb(255, 150, 180),
		style = "hijab",
		extra = "jaket",
		height = 0.95,
		width = 1,
	},
	{
		name = "OmHendra",
		skin = rgb(240, 190, 140),
		shirt = rgb(200, 60, 60),
		pants = rgb(60, 60, 66),
		shoes = BROWN,
		hair = BLACK,
		accent = rgb(60, 60, 66),
		style = "botak",
		height = 1,
		width = 1.1,
		glasses = true,
		beard = true,
	},
	{
		name = "Tia",
		skin = rgb(120, 80, 52),
		shirt = rgb(40, 170, 170),
		pants = rgb(240, 240, 235),
		shoes = rgb(220, 70, 70),
		hair = BLACK,
		accent = rgb(255, 184, 0),
		style = "kribo",
		extra = "syal",
		height = 0.94,
		width = 0.92,
	},
	{
		name = "PakMade",
		skin = rgb(200, 150, 104),
		shirt = rgb(130, 80, 160),
		pants = rgb(70, 60, 56),
		shoes = BLACK,
		hair = GREY,
		accent = rgb(240, 200, 90),
		style = "pendek",
		extra = "saku",
		height = 1,
		width = 1.04,
	},
	{
		name = "Sinta",
		skin = rgb(255, 214, 170),
		shirt = rgb(220, 60, 80),
		pants = rgb(220, 60, 80),
		shoes = BLACK,
		hair = BLACK,
		accent = rgb(245, 245, 240),
		style = "panjang",
		height = 0.97,
		width = 0.92,
		dress = true,
		glasses = true,
	},
}

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
	local who = CHARACTERS[(index - 1) % #CHARACTERS + 1]
	description.HeightScale = who.height
	description.WidthScale = who.width
	description.DepthScale = who.width
	description.HeadScale = if who.height < 0.9 then 1.1 else 1
	local skin, shirt, pants = who.skin, who.shirt, who.pants
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
	model.Name = who.name
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
	local shoes = who.shoes
	local dress = who.dress == true -- terusan / gamis
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
	local hairColor = who.hair
	local smooth = Enum.Material.SmoothPlastic
	local ball, block, cylinder = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
	-- Rambut/topi: empat gaya dari part.
	local style = who.style
	if style == "pendek" then
		attach(
			model,
			head,
			Vector3.new(1.42, 1.3, 1.42),
			CFrame.new(0, 0.36, 0.08),
			hairColor,
			ball,
			smooth
		)
	elseif style == "panjang" then
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
	elseif style == "sanggul" then
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
	elseif style == "kribo" then
		attach(
			model,
			head,
			Vector3.new(2, 1.8, 2),
			CFrame.new(0, 0.5, 0.1),
			hairColor,
			ball,
			smooth
		)
	elseif style == "hijab" then -- kerudung: menutup kepala dan bahu
		attach(
			model,
			head,
			Vector3.new(1.6, 1.55, 1.6),
			CFrame.new(0, 0.12, 0.14),
			who.accent,
			ball,
			Enum.Material.Fabric
		)
		attach(
			model,
			head,
			Vector3.new(1.7, 0.9, 1.5),
			CFrame.new(0, -0.75, 0.12),
			who.accent,
			block,
			Enum.Material.Fabric
		)
	elseif style == "peci" then
		attach(
			model,
			head,
			Vector3.new(0.6, 1.25, 1.25),
			CFrame.new(0, 0.82, 0) * CFrame.Angles(0, 0, math.pi / 2),
			who.accent,
			cylinder,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(1.3, 0.4, 0.3),
			CFrame.new(0, 0.2, 0.55),
			hairColor,
			block,
			smooth
		)
	elseif style == "caping" then -- topi petani lebar
		attach(
			model,
			head,
			Vector3.new(0.2, 2.8, 2.8),
			CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2),
			who.accent,
			cylinder,
			smooth
		)
		attach(
			model,
			head,
			Vector3.new(0.45, 1.5, 1.5),
			CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
			who.accent,
			cylinder,
			smooth
		)
	elseif style ~= "botak" then -- topi bertepi ("botak": tanpa penutup kepala)
		local hat = who.accent
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
		local extra = who.extra
		if extra == "ransel" then
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
		elseif extra == "dasi" then
			attach(
				model,
				torso,
				Vector3.new(0.32, 1.2, 0.08),
				CFrame.new(0, 0.1, -0.52),
				who.accent,
				block,
				smooth
			)
		elseif extra == "celemek" then
			attach(
				model,
				torso,
				Vector3.new(1.5, 1.5, 0.1),
				CFrame.new(0, -0.1, -0.53),
				who.accent,
				block,
				Enum.Material.Fabric
			)
			attach(
				model,
				head,
				Vector3.new(0.8, 1.2, 1.2),
				CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.pi / 2),
				who.accent,
				cylinder,
				smooth
			) -- topi koki
		elseif extra == "syal" then
			attach(
				model,
				torso,
				Vector3.new(1.9, 0.4, 1.2),
				CFrame.new(0, 0.72, 0),
				who.accent,
				block,
				Enum.Material.Fabric
			)
			attach(
				model,
				torso,
				Vector3.new(0.4, 1, 0.12),
				CFrame.new(0.4, 0.2, -0.56),
				who.accent,
				block,
				Enum.Material.Fabric
			)
		elseif extra == "jaket" then
			attach(
				model,
				torso,
				Vector3.new(0.5, 1.5, 0.08),
				CFrame.new(0, 0, -0.52),
				rgb(245, 245, 240),
				block,
				smooth
			)
		elseif extra == "saku" then
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
	if who.beard then -- janggut / kumis
		attach(
			model,
			head,
			Vector3.new(0.95, 0.4, 0.14),
			CFrame.new(0, -0.4, -0.58),
			hairColor,
			block,
			smooth
		)
	end
	if who.glasses then
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

-- Warga dari templat avatar modern (ServerStorage.<folderName>): salin, rapikan, dan siap dianimasikan.
local function buildFromTemplate(folderName: string, index: number): Model?
	local templates = ServerStorage:FindFirstChild(folderName)
	if templates == nil then
		return nil
	end
	local list: { Model } = {}
	for _, child in templates:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			table.insert(list, child)
		end
	end
	if #list == 0 then
		return nil
	end
	local model = list[(index - 1) % #list + 1]:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or model.PrimaryPart == nil then
		model:Destroy()
		return nil
	end
	model.Name = "Petani"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = random:NextNumber(6, 9)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.BreakJointsOnDeath = false
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
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

-- Duduk santai di kursi kosong terdekat dari daftar, lalu berdiri lagi.
local function relax(model: Model, humanoid: Humanoid, seats: { Seat }, group: any)
	local free: { Seat } = {}
	for _, seat in seats do
		if seat.Parent and seat.Occupant == nil then
			table.insert(free, seat)
		end
	end
	if #free == 0 then
		return
	end
	local seat = pick(free)
	walkTo(model, humanoid, seat.Position + Vector3.new(0, 3, 0))
	if seat.Parent == nil or seat.Occupant ~= nil then
		return
	end
	seat:Sit(humanoid)
	-- pengunjung kafe memegang cangkir selama duduk
	local cup: Part? = nil
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if group.cup and hand and hand:IsA("BasePart") then
		local created = Instance.new("Part")
		created.Name = "Cangkir"
		created.Shape = Enum.PartType.Cylinder
		created.Size = Vector3.new(0.5, 0.55, 0.55)
		created.Color = Color3.fromRGB(250, 242, 226)
		created.Material = Enum.Material.SmoothPlastic
		created.Massless = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.CFrame = hand.CFrame
			* CFrame.new(0, -hand.Size.Y / 2 - 0.2, -0.3)
			* CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = created
		weld.Parent = created
		created.Parent = model
		cup = created
	end
	local sit = group.sitSeconds or { 12, 28 }
	task.wait(random:NextNumber(sit[1], sit[2]))
	if cup then
		cup:Destroy()
	end
	humanoid.Sit = false
	humanoid.Jump = true
	task.wait(1)
end

local function live(model: Model, places: { Vector3 }, seats: { Seat }, group: any)
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
		if #seats > 0 and random:NextNumber() < (group.relaxChance or 0.45) then
			relax(model, humanoid, seats, group)
		else
			walkTo(model, humanoid, near(pick(places)))
		end
	end
end

-- ---------------------------------------------------------------- penjual bakso keliling

-- Mang Ujang mendorong gerobak bakso keliling kota kecil, lalu mangkal sebentar di tiap tempat.
-- Saat mangkal, pemain bisa membeli semangkuk bakso di gerobaknya (harga dicek server).
local BAKSO = {
	price = 10,
	walkSpeed = 7,
	stopSeconds = { 35, 55 },
	stops = { "tamanPerumahan", "rumahSakit", "toko", "kafe", "balaiKota", "damkar" },
	buyCooldown = 4,
	-- ketukan "tek-tek" saat keliling: "Rock Impacts 19 (SFX)" dari ProSoundEffects (gratis di Creator Store)
	knockSound = "rbxassetid://9118623491",
	knockEvery = 2.6, -- detik antar dua ketukan
	eatSeconds = 12,
}

local function buildCart(root: BasePart): (Model, ProximityPrompt, TextLabel)
	local cart = Instance.new("Model")
	cart.Name = "GerobakBakso"
	local floorY = -(root.Size.Y / 2 + (root.Parent :: any).Humanoid.HipHeight) -- tanah relatif ke root
	local base = root.CFrame * CFrame.new(0, floorY, -4.4)
	local blue, white, wood = rgb(40, 110, 200), rgb(246, 246, 240), rgb(150, 104, 66)
	local function piece(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = base * cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CollisionGroup = GROUP_NPC
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = cart
		return p
	end
	local body = piece("Badan", Vector3.new(3.4, 2, 4.6), CFrame.new(0, 2.5, 0), blue)
	piece("Bingkai", Vector3.new(3.6, 0.25, 4.8), CFrame.new(0, 3.6, 0), white)
	piece("Garis", Vector3.new(3.44, 0.5, 4.64), CFrame.new(0, 2.5, 0), rgb(226, 54, 54))
	for _, sx in { -1, 1 } do
		piece(
			"Roda",
			Vector3.new(0.4, 2.4, 2.4),
			CFrame.new(sx * 1.9, 1.2, 0.4),
			rgb(34, 36, 42),
			nil,
			Enum.PartType.Cylinder
		)
		piece(
			"Velg",
			Vector3.new(0.46, 1, 1),
			CFrame.new(sx * 1.9, 1.2, 0.4),
			rgb(200, 204, 212),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		piece(
			"Gagang",
			Vector3.new(0.22, 0.22, 2.6),
			CFrame.new(sx * 1.3, 3.2, 3.5),
			wood,
			Enum.Material.Wood
		)
		for _, sz in { -2.1, 2.1 } do
			piece("TiangAtap", Vector3.new(0.2, 3, 0.2), CFrame.new(sx * 1.6, 5.2, sz), white)
		end
	end
	piece(
		"PalangGagang",
		Vector3.new(2.8, 0.22, 0.22),
		CFrame.new(0, 3.2, 4.7),
		wood,
		Enum.Material.Wood
	)
	piece("KakiDepan", Vector3.new(0.3, 1.5, 0.3), CFrame.new(0, 0.75, -2), rgb(60, 62, 70))
	piece("Atap", Vector3.new(4.2, 0.3, 5.2), CFrame.new(0, 6.8, 0), blue)
	piece("TepiAtap", Vector3.new(4.4, 0.2, 5.4), CFrame.new(0, 6.6, 0), white)
	-- etalase kaca berisi bakso, panci berasap, dan mangkuk
	local glass = piece(
		"Etalase",
		Vector3.new(3, 1.6, 2),
		CFrame.new(0, 4.55, -1.1),
		rgb(200, 230, 245),
		Enum.Material.Glass
	)
	glass.Transparency = 0.6
	for index, offset in
		{
			Vector3.new(-0.8, 0, 0),
			Vector3.new(0, 0, 0.3),
			Vector3.new(0.8, 0, -0.2),
			Vector3.new(-0.3, 0.55, 0),
			Vector3.new(0.4, 0.55, 0.2),
		}
	do
		local ball = piece(
			"Bakso" .. index,
			Vector3.new(0.6, 0.6, 0.6),
			CFrame.new(offset.X, 4.1 + offset.Y, -1.1 + offset.Z),
			rgb(170, 140, 120),
			nil,
			Enum.PartType.Ball
		)
		ball.CastShadow = false
	end
	local pot = piece(
		"Panci",
		Vector3.new(1.3, 1.6, 1.6),
		CFrame.new(0, 4.4, 1.2) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(196, 200, 208),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 5
	steam.Lifetime = NumberRange.new(1.2, 1.8)
	steam.Speed = NumberRange.new(1.2, 2)
	steam.SpreadAngle = Vector2.new(12, 12)
	steam.EmissionDirection = Enum.NormalId.Right -- silinder diputar: sumbu X-nya mengarah ke atas
	steam.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	steam.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	steam.Parent = pot
	for i = 0, 2 do
		piece(
			"Mangkuk",
			Vector3.new(0.3, 0.8, 0.8),
			CFrame.new(-1 + i * 1, 3.9, 2) * CFrame.Angles(0, 0, math.rad(90)),
			white,
			nil,
			Enum.PartType.Cylinder
		)
	end
	-- tulisan di kedua sisi
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "BAKSO"
		label.Parent = gui
		gui.Parent = body
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Papan"
	board.Size = UDim2.fromScale(9, 1.6)
	board.StudsOffset = Vector3.new(0, 6, 0)
	board.MaxDistance = 80
	local status = Instance.new("TextLabel")
	status.Size = UDim2.fromScale(1, 1)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Text = "Bakso Mang Ujang"
	status.Parent = board
	board.Parent = body
	body.CanQuery = true -- supaya tombol beli bisa dipakai
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BeliBakso"
	prompt.ActionText = "Beli bakso " .. Format.money(BAKSO.price)
	prompt.ObjectText = "Mang Ujang"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body
	return cart, prompt, status
end

-- Mangkuk bakso di tangan pemain selama beberapa detik (hanya hiasan).
local function giveBowl(player: Player)
	local character = player.Character
	local hand = if character
		then character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		else nil
	if character == nil or hand == nil or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("MangkukBakso")
	if old then
		old:Destroy()
	end
	local bowl = Instance.new("Part")
	bowl.Name = "MangkukBakso"
	bowl.Shape = Enum.PartType.Cylinder
	bowl.Size = Vector3.new(0.5, 1.1, 1.1)
	bowl.Color = rgb(246, 246, 240)
	bowl.Massless = true
	bowl.CanCollide = false
	bowl.CanTouch = false
	bowl.CanQuery = false
	bowl.CFrame = hand.CFrame
		* CFrame.new(0, -hand.Size.Y / 2 - 0.3, -0.4)
		* CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = bowl
	weld.Parent = bowl
	bowl.Parent = character
	task.delay(BAKSO.eatSeconds, function()
		bowl:Destroy()
	end)
end

local function startBaksoVendor()
	local stops: { Vector3 } = {}
	for _, key in BAKSO.stops do
		local position = placePosition(key)
		if position then
			table.insert(stops, position)
		end
	end
	local model = buildNpc(7) -- perawakan Pak Umar; namanya diganti
	if model == nil or #stops < 2 then
		return
	end
	model.Name = "MangUjang"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if humanoid == nil or root == nil then
		return
	end
	humanoid.DisplayName = "Mang Ujang"
	humanoid.WalkSpeed = BAKSO.walkSpeed
	model:PivotTo(CFrame.new(stops[1] + Vector3.new(4, 3, 4)))
	local cart, prompt, status = buildCart(root)
	cart.Parent = model
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	animate(humanoid)

	local lastBuy: { [Player]: number } = {}
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if lastBuy[player] and now - lastBuy[player] < BAKSO.buyCooldown then
			return
		end
		local character = player.Character
		local playerRoot = if character then character.PrimaryPart else nil
		if playerRoot == nil or (playerRoot.Position - root.Position).Magnitude > 24 then
			return
		end
		lastBuy[player] = now
		if not EconomyService.trySpend(player, BAKSO.price, "food:bakso") then
			EconomyService.notify(
				player,
				"Uangmu belum cukup. Semangkuk bakso " .. Format.money(BAKSO.price) .. "."
			)
			return
		end
		giveBowl(player)
		EconomyService.notify(player, "Bakso hangat dari Mang Ujang. Selamat makan!")
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)

	-- Suara "tek-tek": dua ketukan pendek berulang selama gerobak berkeliling (diam saat mangkal).
	local knock = Instance.new("Sound")
	knock.Name = "TekTek"
	knock.SoundId = BAKSO.knockSound
	knock.Volume = 0.7
	knock.PlaybackSpeed = 1.5
	knock.RollOffMode = Enum.RollOffMode.InverseTapered
	knock.RollOffMinDistance = 10
	knock.RollOffMaxDistance = 90
	knock.Parent = prompt.Parent
	task.spawn(function()
		while model.Parent ~= nil do
			if prompt.Enabled then
				task.wait(1)
			else
				knock:Play()
				task.wait(0.24)
				knock:Play()
				task.wait(BAKSO.knockEvery)
			end
		end
	end)

	task.spawn(function()
		local index = 1
		while model.Parent ~= nil do
			-- mangkal
			prompt.Enabled = true
			status.Text = "Bakso Mang Ujang · mangkal"
			task.wait(random:NextNumber(BAKSO.stopSeconds[1], BAKSO.stopSeconds[2]))
			-- keliling ke tempat berikutnya
			prompt.Enabled = false
			status.Text = "Bakso Mang Ujang · keliling"
			index = index % #stops + 1
			if root.Position.Y < -30 then
				model:PivotTo(CFrame.new(stops[index] + Vector3.new(4, 3, 4)))
			end
			walkTo(
				model,
				humanoid,
				stops[index] + Vector3.new(random:NextNumber(-4, 4), 3, random:NextNumber(3, 6))
			)
		end
	end)
end

-- ---------------------------------------------------------------- NPC avatar modern (LOD)

-- Tiap NPC bertemplat punya "slot". Modelnya hanya ada saat pemain dalam MODERN_SPAWN_RANGE stud dan
-- dihapus lagi saat semua pemain lebih jauh dari MODERN_DESPAWN_RANGE (jarak lebih besar supaya tidak
-- muncul-hilang berulang). Paling banyak MODERN_MAX yang aktif sekaligus.
local MODERN_SPAWN_RANGE = 150
local MODERN_DESPAWN_RANGE = 200
local MODERN_MAX = 10
local MODERN_CHECK_SECONDS = 3

type Slot = {
	template: string,
	index: number,
	places: { Vector3 },
	seats: { Seat },
	group: any,
	home: Vector3,
	model: Model?,
}
local modernSlots: { Slot } = {}

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

local function spawnSlot(slot: Slot)
	local model = buildFromTemplate(slot.template, slot.index)
	if model == nil then
		return
	end
	model:PivotTo(CFrame.new(slot.home))
	model.Parent = folder
	local root = model.PrimaryPart
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	slot.model = model
	task.spawn(live, model, slot.places, slot.seats, slot.group)
end

local function startModernManager()
	task.spawn(function()
		while true do
			task.wait(MODERN_CHECK_SECONDS)
			local active = 0
			for _, slot in modernSlots do
				if slot.model and slot.model.Parent then
					active += 1
				end
			end
			for _, slot in modernSlots do
				local model = slot.model
				if model and model.Parent then
					local root = model.PrimaryPart
					if root and not playerWithin(root.Position, MODERN_DESPAWN_RANGE) then
						slot.home = root.Position + Vector3.new(0, 1, 0)
						slot.model = nil
						model:Destroy()
						active -= 1
					end
				elseif active < MODERN_MAX and playerWithin(slot.home, MODERN_SPAWN_RANGE) then
					spawnSlot(slot)
					if slot.model then
						active += 1
					end
				end
			end
		end
	end)
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
		local seats: { Seat } = {}
		local map = Workspace:FindFirstChild("Map")
		local zone = if map and (group :: any).seatsIn
			then map:FindFirstChild((group :: any).seatsIn)
			else nil
		if zone then
			for _, d in zone:GetDescendants() do
				if d:IsA("Seat") then
					table.insert(seats, d)
				end
			end
		end
		for _ = 1, group.count do
			index += 1
			if (group :: any).template then
				-- Avatar modern berat (tekstur PBR, tulang): hanya aktif saat ada pemain di dekatnya.
				table.insert(modernSlots, {
					template = (group :: any).template,
					index = index,
					places = places,
					seats = seats,
					group = group,
					home = near(pick(places)),
					model = nil,
				})
				continue
			end
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
				task.spawn(live, model, places, seats, group)
			end
			task.wait(0.2)
		end
	end
	startModernManager()
	startBaksoVendor()
end

return NpcService
