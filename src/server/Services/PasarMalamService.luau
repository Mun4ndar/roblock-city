--!strict
--[[
	PasarMalamService: penghuni Pasar Malam Taman Kota.
	  * Tiap lapak (Model "Lapak*" di Workspace.Map.PasarMalam, dipasang FoodService saat pasar buka) punya penjual
	    ramah di titik "TitikPenjual": menyapa pemain yang mendekat dengan panggilan "Kak" (gelembung ucapan +
	    lambaian) dan berterima kasih saat pemain membeli (FoodService.Bought).
	  * Beberapa pembeli NPC berjalan dari lapak ke lapak, berhenti melihat-lihat dagangan.
	  * Semua NPC dibuat hanya saat ada pemain dalam SPAWN_RANGE stud dan dihapus lagi bila semua pemain lebih jauh
	    dari DESPAWN_RANGE atau lapaknya dibongkar (pasar tutup), supaya ringan di HP.
	Dagangan lapak dibuat map/BuildPasarMalam; data penjual/pembeli di Shared.PasarMalamConfig.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("PasarMalamConfig"))

local FoodService = require(script.Parent:WaitForChild("FoodService")) :: any

local PasarMalamService = {}

local GROUP_NPC = "Npc"
local CENTER = Vector3.new(700, 3, 125)
local CHECK_SECONDS = 3

local IDLE = "rbxassetid://507766388"
local WALK = "rbxassetid://913402848" -- jalan R15 resmi (bukan lari)
local WAVE = "rbxassetid://507770239"
local CHEER = "rbxassetid://507770677"

local rgb = Color3.fromRGB
local SP, FB = Enum.Material.SmoothPlastic, Enum.Material.Fabric
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

type Person = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	say: (string, number) -> (),
	wave: (AnimationTrack?) -> (),
}

type VendorEntry = {
	stall: Model,
	person: Person,
	menu: string,
	lastGreet: number,
}

type ShopperEntry = { person: Person, alive: boolean }

local folder: Folder
local vendors: { [Model]: VendorEntry } = {}
local shoppers: { ShopperEntry } = {}

-- ---------------------------------------------------------------- orang

local function attach(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType,
	material: Enum.Material,
	rotation: CFrame?
): Part
	local part = Instance.new("Part")
	part.Name = "Hiasan"
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless =
		false, false, false, false, true
	part.CFrame = to.CFrame * offset * (rotation or CFrame.identity)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function buildBubble(head: BasePart, accent: Color3): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanPasar"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(280, 58)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 45
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = rgb(255, 255, 255)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(50, 44, 40)
	label.Parent = frame
	frame.Parent = gui
	gui.Parent = head
	local token = 0
	return function(text: string, seconds: number)
		token += 1
		local mine = token
		label.Text = text
		gui.Enabled = true
		task.delay(seconds, function()
			if token == mine then
				gui.Enabled = false
			end
		end)
	end
end

local function loadTrack(
	humanoid: Humanoid,
	id: string,
	looped: boolean,
	priority: Enum.AnimationPriority
): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Looped = looped
	track.Priority = priority
	return track
end

local function buildPerson(name: string, title: string?, look: Config.Look, accent: Color3): Person?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.top
	description.LeftLegColor = look.bottom
	description.RightLegColor = look.bottom
	description.HeightScale = 0.96 + math.random() * 0.1
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[PasarMalam] gagal membuat NPC: " .. tostring(model))
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	local upper = model:FindFirstChild("UpperTorso")
	if
		humanoid == nil
		or head == nil
		or not head:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
		or upper == nil
		or not upper:IsA("BasePart")
	then
		model:Destroy()
		return nil
	end
	model.Name = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 6
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy() -- wajah senyum digambar FaceService
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			part.Material = SP
			if n:match("Foot$") then
				part.Color = rgb(44, 38, 36)
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				part.Color = look.top
			elseif n == "LowerTorso" or n:match("Leg$") then
				part.Color = look.bottom
			else
				part.Color = look.skin
			end
		end
	end
	-- celemek
	if look.apron then
		attach(
			model,
			upper,
			Vector3.new(1.05, 1.5, 0.1),
			CFrame.new(0, -0.1, -0.54),
			look.apron,
			BLOCK,
			SP,
			nil
		)
	end
	-- rambut
	local hat = look.hat
	if hat ~= "hijab" and hat ~= "caping" then
		attach(
			model,
			head,
			Vector3.new(1.4, 1.2, 1.4),
			CFrame.new(0, 0.36, 0.08),
			look.hair,
			BALL,
			SP,
			nil
		)
		if look.hairStyle == "sanggul" then
			attach(
				model,
				head,
				Vector3.new(0.7, 0.7, 0.7),
				CFrame.new(0, 0.72, 0.58),
				look.hair,
				BALL,
				SP,
				nil
			)
		elseif look.hairStyle == "kuncir" then
			attach(
				model,
				head,
				Vector3.new(0.45, 0.8, 0.45),
				CFrame.new(0, 0.1, 0.8),
				look.hair,
				BALL,
				SP,
				nil
			)
		else
			attach(
				model,
				head,
				Vector3.new(1.3, 0.35, 0.6),
				CFrame.new(0, 0.62, -0.46),
				look.hair,
				BLOCK,
				SP,
				nil
			)
		end
	end
	-- penutup kepala
	if hat == "peci" then
		attach(
			model,
			head,
			Vector3.new(0.5, 1.2, 1.2),
			CFrame.new(0, 0.74, 0),
			rgb(30, 28, 30),
			CYL,
			SP,
			CFrame.Angles(0, 0, math.rad(90))
		)
	elseif hat == "bandana" then
		attach(
			model,
			head,
			Vector3.new(1.3, 0.2, 1.3),
			CFrame.new(0, 0.5, 0.02),
			rgb(200, 50, 50),
			BLOCK,
			SP,
			nil
		)
		attach(
			model,
			head,
			Vector3.new(1.3, 0.5, 1.3),
			CFrame.new(0, 0.7, 0.1),
			rgb(200, 50, 50),
			BALL,
			SP,
			nil
		)
	elseif hat == "hijab" then
		attach(
			model,
			head,
			Vector3.new(1.65, 1.6, 1.5),
			CFrame.new(0, 0.12, 0.22),
			look.top,
			BALL,
			FB,
			nil
		)
		attach(
			model,
			head,
			Vector3.new(1.2, 0.5, 0.4),
			CFrame.new(0, -0.7, 0.05),
			look.top,
			BLOCK,
			FB,
			nil
		)
	elseif hat == "caping" then
		attach(
			model,
			head,
			Vector3.new(0.14, 2.6, 2.6),
			CFrame.new(0, 0.74, 0),
			rgb(214, 180, 110),
			CYL,
			SP,
			CFrame.Angles(0, 0, math.rad(90))
		)
		attach(
			model,
			head,
			Vector3.new(1.3, 0.9, 1.3),
			CFrame.new(0, 1.0, 0),
			rgb(214, 180, 110),
			BALL,
			SP,
			nil
		)
		attach(
			model,
			head,
			Vector3.new(1.4, 1.2, 1.4),
			CFrame.new(0, 0.3, 0.1),
			look.hair,
			BALL,
			SP,
			nil
		)
	end
	-- papan nama
	if title then
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(170, 40)
		board.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
		board.MaxDistance = 26
		board.AlwaysOnTop = false
		board.Parent = head
		local function line(text: string, y: number, h: number, size: number, color: Color3)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0, y)
			l.Size = UDim2.new(1, 0, h, 0)
			l.Text = text
			l.Font = Enum.Font.GothamBold
			l.TextSize = size
			l.TextColor3 = color
			l.TextStrokeTransparency = 0.4
			l.Parent = board
		end
		line(name, 0, 0.55, 16, rgb(255, 255, 255))
		line(title, 0.52, 0.45, 12, rgb(255, 232, 160))
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GROUP_NPC
			d.CanTouch = false
		end
	end
	local waveTrack = loadTrack(humanoid, WAVE, false, Enum.AnimationPriority.Action)
	local cheerTrack = loadTrack(humanoid, CHEER, false, Enum.AnimationPriority.Action)
	local say = buildBubble(head, accent)
	local person: Person
	person = {
		model = model,
		humanoid = humanoid,
		root = root,
		say = say,
		wave = function(track: AnimationTrack?)
			local t = track or (if math.random() < 0.5 then waveTrack else cheerTrack)
			t:Play(0.2)
		end,
	}
	return person
end

-- ---------------------------------------------------------------- penjual

local function nearestPlayer(position: Vector3): (Player?, number)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function spawnVendor(stall: Model)
	local stallName = stall:GetAttribute("StallName")
	local spot = stall:FindFirstChild("TitikPenjual")
	local data = if type(stallName) == "string" then Config.VENDORS[stallName] else nil
	if data == nil or spot == nil or not spot:IsA("BasePart") then
		return
	end
	local person = buildPerson(data.name, data.title, data.look, rgb(255, 190, 70))
	if person == nil then
		return
	end
	local floorY = spot.Position.Y
	local position = Vector3.new(
		spot.Position.X,
		floorY + person.humanoid.HipHeight + person.root.Size.Y / 2,
		spot.Position.Z
	)
	local front = spot.CFrame.LookVector
	person.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(front.X, 0, front.Z)))
	person.root.Anchored = true
	person.model.Parent = folder
	loadTrack(person.humanoid, IDLE, true, Enum.AnimationPriority.Idle):Play(0.3)
	local menu = stall:GetAttribute("Menu")
	vendors[stall] = {
		stall = stall,
		person = person,
		menu = if type(menu) == "string" then menu else "",
		lastGreet = -100,
	}
end

local function removeVendor(stall: Model)
	local entry = vendors[stall]
	if entry then
		entry.person.model:Destroy()
		vendors[stall] = nil
	end
end

local function greetLoop()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, entry in vendors do
			if now - entry.lastGreet >= Config.GREET_COOLDOWN then
				local _, distance = nearestPlayer(entry.person.root.Position)
				if distance <= Config.GREET_RANGE then
					entry.lastGreet = now
					local line = Config.VENDORS[entry.stall:GetAttribute("StallName") :: string]
					if line then
						entry.person.say(line.lines[math.random(1, #line.lines)][1], 5)
						entry.person.wave(nil)
					end
				end
			end
		end
	end
end

local function onBought(player: Player, menuId: string)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local best: VendorEntry? = nil
	local bestDistance = 28
	for _, entry in vendors do
		if entry.menu == menuId then
			local distance = (entry.person.root.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = entry, distance
			end
		end
	end
	if best then
		best.lastGreet = os.clock()
		best.person.say(Config.THANKS[math.random(1, #Config.THANKS)][1], 4)
		best.person.wave(nil)
	end
end

-- ---------------------------------------------------------------- pembeli

local function frontPoints(): { { point: Vector3, look: Vector3 } }
	local list = {}
	for stall in vendors do
		local pivot = stall:GetPivot()
		local floorY = pivot.Position.Y
		local front = pivot.LookVector
		for _, side in { -3, 0, 3 } do
			local p = pivot.Position + pivot.RightVector * side + front * 7.5
			table.insert(list, { point = Vector3.new(p.X, floorY, p.Z), look = pivot.Position })
		end
	end
	return list
end

local function lineClear(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local origin = from + Vector3.new(0, 2.5, 0)
	local goal = to + Vector3.new(0, 2.5, 0)
	local hit = Workspace:Raycast(origin, goal - origin, params)
	return hit == nil or hit.Instance:IsA("Terrain")
end

local function shopperLoop(entry: ShopperEntry, walk: AnimationTrack, idle: AnimationTrack)
	local person = entry.person
	local bag: Part? = nil
	task.wait(math.random() * 3)
	while entry.alive and person.model.Parent do
		local points = frontPoints()
		if #points == 0 then
			break
		end
		local here = person.root.Position
		local target = points[math.random(1, #points)]
		local tries = 0
		while tries < 6 and not lineClear(here, target.point, { person.model, folder }) do
			target = points[math.random(1, #points)]
			tries += 1
		end
		if tries < 6 then
			idle:Stop(0.2)
			walk:Play(0.2, 1, 0.55) -- diperlambat: jalan santai
			local goal = Vector3.new(target.point.X, here.Y, target.point.Z)
			person.humanoid:MoveTo(goal)
			local waited = 0
			while
				entry.alive
				and person.model.Parent
				and (person.root.Position * Vector3.new(1, 0, 1) - goal * Vector3.new(1, 0, 1)).Magnitude > 2.5
				and waited < 18
			do
				waited += task.wait(0.3)
				person.humanoid:MoveTo(goal)
			end
			walk:Stop(0.2)
			idle:Play(0.2)
			if entry.alive and person.model.Parent then
				local pos = person.root.Position
				local lookAt = Vector3.new(target.look.X, pos.Y, target.look.Z)
				if (lookAt - pos).Magnitude > 0.5 then
					person.root.CFrame = CFrame.lookAt(pos, lookAt)
				end
				if math.random() < 0.4 then
					local line = Config.SHOPPER_LINES[math.random(1, #Config.SHOPPER_LINES)][1]
					person.say(line, 4)
				end
				if bag == nil and math.random() < 0.5 then
					local hand = person.model:FindFirstChild("RightHand")
					if hand and hand:IsA("BasePart") then
						bag = attach(
							person.model,
							hand,
							Vector3.new(0.6, 0.8, 0.45),
							CFrame.new(0, -0.5, 0),
							rgb(190, 146, 96),
							BLOCK,
							SP,
							nil
						)
					end
				end
			end
		end
		task.wait(3 + math.random() * 5)
	end
end

local function spawnShopper(index: number): ShopperEntry?
	local data = Config.SHOPPERS[(index - 1) % #Config.SHOPPERS + 1]
	local points = frontPoints()
	if #points == 0 then
		return nil
	end
	local person = buildPerson(data.name, "Pembeli", data.look, rgb(120, 200, 255))
	if person == nil then
		return nil
	end
	local start = points[math.random(1, #points)].point
	local position =
		Vector3.new(start.X, start.Y + person.humanoid.HipHeight + person.root.Size.Y / 2, start.Z)
	person.model:PivotTo(CFrame.new(position))
	person.model.Parent = folder
	pcall(function()
		person.root:SetNetworkOwner(nil)
	end)
	local walk = loadTrack(person.humanoid, WALK, true, Enum.AnimationPriority.Movement)
	local idle = loadTrack(person.humanoid, IDLE, true, Enum.AnimationPriority.Idle)
	idle:Play(0.2)
	local entry: ShopperEntry = { person = person, alive = true }
	task.spawn(shopperLoop, entry, walk, idle)
	return entry
end

local function clearShoppers()
	for _, entry in shoppers do
		entry.alive = false
		entry.person.model:Destroy()
	end
	table.clear(shoppers)
end

-- ---------------------------------------------------------------- pengelola

local function mountedStalls(): { Model }
	local list = {}
	local map = Workspace:FindFirstChild("Map")
	local root = if map then map:FindFirstChild("PasarMalam") else nil
	if root then
		for _, group in root:GetChildren() do
			for _, child in group:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("Look") ~= nil then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

local function playerWithin(range: number): boolean
	local _, distance = nearestPlayer(CENTER)
	return distance <= range
end

local function manage()
	local stalls = mountedStalls()
	local live: { [Model]: boolean } = {}
	for _, stall in stalls do
		live[stall] = true
	end
	for stall in vendors do
		if not live[stall] or stall.Parent == nil then
			removeVendor(stall)
		end
	end
	local near = playerWithin(Config.SPAWN_RANGE)
	local far = not playerWithin(Config.DESPAWN_RANGE)
	if #stalls == 0 or far then
		for stall in vendors do
			removeVendor(stall)
		end
		clearShoppers()
		return
	end
	if not near then
		return
	end
	local festival = Workspace:GetAttribute("FestivalKuliner") == true
	for _, stall in stalls do
		if vendors[stall] == nil then
			spawnVendor(stall)
		end
	end
	for i = #shoppers, 1, -1 do
		if shoppers[i].person.model.Parent == nil then
			shoppers[i].alive = false
			table.remove(shoppers, i)
		end
	end
	local wanted = if festival then Config.SHOPPERS_FESTIVAL else Config.SHOPPERS_NIGHT
	while #shoppers < wanted do
		local entry = spawnShopper(#shoppers + 1)
		if entry == nil then
			break
		end
		table.insert(shoppers, entry)
	end
end

function PasarMalamService.init()
	local existing = Workspace:FindFirstChild("PenghuniPasarMalam")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "PenghuniPasarMalam"
	folder.Parent = Workspace
end

function PasarMalamService.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NPC)
	end)
	if FoodService.Bought then
		FoodService.Bought:Connect(onBought)
	end
	task.spawn(greetLoop)
	task.spawn(function()
		while true do
			local ok, err = pcall(manage)
			if not ok then
				warn("[PasarMalam] " .. tostring(err))
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return PasarMalamService
