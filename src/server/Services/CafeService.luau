--!strict
-- CafeService: pelayan ramah di dua kafe dalam ruangan (Cafe Startduck dan Kafe Kota) dan pemesanan menu.
--   * tiap kafe punya barista di belakang konter (mengelap meja, menyapa, melambai, gelembung ucapan) dan
--     satu pelayan yang berkeliling di lorong antara meja, berhenti menyapa pemain yang lewat.
--   * "Lihat Menu" (ProximityPrompt) di barista, pelayan, dan konter membuka menu di client (CafeController).
--   * pesanan divalidasi server: menu, jarak ke pelayan, uang (EconomyService.trySpend). Lalu pemain
--     minum/makan lewat StoreService.serve (animasi sama dengan toko); uang dikembalikan bila gagal.
--   * titik berdiri/jalur pelayan dibaca dari Workspace.Map.KafeTitik (dibuat BuildStarduckDalam dan
--     BuildKafeKotaDalam), atribut Venue, Role (Barista | Meja | Jalur), Index, Facing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CafeConfig = require(Shared:WaitForChild("CafeConfig"))
local Net = require(Shared:WaitForChild("Net"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local StoreService = require(script.Parent:WaitForChild("StoreService"))

local CafeService = {}

local rgb = Color3.fromRGB

local IDLE = "rbxassetid://507766388"
local WALK = "rbxassetid://507777826"
local WAVE = "rbxassetid://507770239"
local CHEER = "rbxassetid://507770677"
local WIPE = "rbxassetid://522635514" -- ayun lengan: mengelap meja

type Look = {
	name: string,
	title: string,
	skin: Color3,
	top: Color3,
	bottom: Color3,
	shoes: Color3,
	hair: Color3,
	hairStyle: string, -- "bun" | "short" | "pony"
	apron: Color3?,
	accent: Color3,
	cap: Color3?,
}

type Staff = { root: BasePart, say: (string, number) -> (), celebrate: () -> () }

local LOOKS: { [string]: { barista: Look, waiter: Look } } = {
	startduck = {
		barista = {
			name = "Dinda", title = "Barista", skin = rgb(224, 172, 120), top = rgb(252, 244, 228),
			bottom = rgb(60, 46, 40), shoes = rgb(60, 46, 40), hair = rgb(40, 28, 26), hairStyle = "bun",
			apron = rgb(110, 70, 44), accent = rgb(255, 200, 50),
		},
		waiter = {
			name = "Raka", title = "Pelayan", skin = rgb(214, 160, 116), top = rgb(252, 244, 228),
			bottom = rgb(60, 46, 40), shoes = rgb(50, 40, 36), hair = rgb(34, 26, 24), hairStyle = "short",
			apron = nil, accent = rgb(255, 200, 50), cap = nil,
		},
	},
	kafekota = {
		barista = {
			name = "Bayu", title = "Barista", skin = rgb(214, 160, 116), top = rgb(60, 64, 72),
			bottom = rgb(34, 36, 40), shoes = rgb(30, 30, 34), hair = rgb(30, 24, 22), hairStyle = "short",
			apron = rgb(30, 32, 36), accent = rgb(255, 160, 60), cap = rgb(255, 160, 60),
		},
		waiter = {
			name = "Sari", title = "Pelayan", skin = rgb(240, 190, 140), top = rgb(245, 245, 240),
			bottom = rgb(34, 36, 40), shoes = rgb(30, 30, 34), hair = rgb(60, 36, 28), hairStyle = "pony",
			apron = rgb(30, 32, 36), accent = rgb(255, 160, 60),
		},
	},
}

local GREETINGS = {
	startduck = {
		"Selamat datang di Cafe Startduck, Kak! 🦆",
		"Ada Duck Latte yang lagi favorit lho! ☕",
		"Silakan duduk di lantai atas, pemandangannya enak! 😊",
		"Croissant mentega baru keluar dari oven! 🥐",
	},
	kafekota = {
		"Selamat datang di Kafe Kota, Kak! ☕",
		"Kopi susu gula aren kami paling laris! 😊",
		"Silakan duduk di sofa atau bar jendela, Kak!",
		"Mau coba roti bakar cokelat yang hangat? 🍞",
	},
}

local folder: Folder
local baristas: { [string]: Staff } = {}
local waiters: { [string]: Staff } = {}
local busy: { [Player]: boolean } = {}

local function decorate(model: Model, on: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, ball: boolean?, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = on.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = on
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

local function buildBubble(head: BasePart, accent: Color3): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanKafe"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(270, 58)
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
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

local function buildPerson(look: Look): (Model?, Humanoid?, BasePart?, BasePart?)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.top
	description.LeftLegColor = look.bottom
	description.RightLegColor = look.bottom
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Cafe] gagal membuat pelayan: " .. tostring(model))
		return nil, nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or head == nil or not head:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil, nil, nil
	end
	model.Name = look.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
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
		if part:IsA("BasePart") then
			local n = part.Name
			if n:match("Foot$") then
				part.Color = look.shoes
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				part.Color = look.top
			elseif n == "LowerTorso" or n:match("Leg$") then
				part.Color = look.bottom
			elseif n ~= "HumanoidRootPart" then
				part.Color = look.skin
			end
		end
	end
	local upper = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if upper and lower and upper:IsA("BasePart") and lower:IsA("BasePart") then
		if look.apron then
			local a = look.apron
			decorate(model, upper, "CelemekAtas", Vector3.new(1.55, 1.15, 0.12), a, CFrame.new(0, -0.2, -0.54))
			decorate(model, lower, "CelemekBawah", Vector3.new(1.7, 1.0, 0.12), a, CFrame.new(0, -0.5, -0.54))
			decorate(model, upper, "KantongCelemek", Vector3.new(0.7, 0.35, 0.05), look.accent, CFrame.new(0, -0.3, -0.62))
			decorate(model, upper, "TaliKiri", Vector3.new(0.18, 0.75, 0.1), a, CFrame.new(-0.5, 0.45, -0.52))
			decorate(model, upper, "TaliKanan", Vector3.new(0.18, 0.75, 0.1), a, CFrame.new(0.5, 0.45, -0.52))
		else
			-- rompi kayu + dasi kupu-kupu
			decorate(model, upper, "RompiKiri", Vector3.new(0.62, 1.2, 0.1), rgb(110, 70, 44), CFrame.new(-0.42, -0.2, -0.54))
			decorate(model, upper, "RompiKanan", Vector3.new(0.62, 1.2, 0.1), rgb(110, 70, 44), CFrame.new(0.42, -0.2, -0.54))
			decorate(model, upper, "DasiKupu", Vector3.new(0.6, 0.25, 0.1), look.accent, CFrame.new(0, 0.5, -0.58))
		end
	end
	local style = look.hairStyle
	decorate(model, head, "Rambut", Vector3.new(1.42, 1.15, 1.42), look.hair, CFrame.new(0, 0.34, 0.08), true)
	if style == "bun" then
		decorate(model, head, "Sanggul", Vector3.new(0.8, 0.8, 0.8), look.hair, CFrame.new(0, 0.95, 0.25), true)
		decorate(model, head, "IkatRambut", Vector3.new(0.45, 0.2, 0.45), look.accent, CFrame.new(0, 0.7, 0.35), true)
	elseif style == "pony" then
		decorate(model, head, "Kuncir", Vector3.new(0.5, 1.1, 0.5), look.hair, CFrame.new(0, 0.0, 0.8), true)
		decorate(model, head, "IkatRambut", Vector3.new(0.4, 0.2, 0.4), look.accent, CFrame.new(0, 0.45, 0.78), true)
	end
	if look.cap then
		decorate(model, head, "Topi", Vector3.new(1.5, 0.4, 1.5), look.cap, CFrame.new(0, 0.62, 0))
		decorate(model, head, "TopiLidah", Vector3.new(1.1, 0.12, 0.7), look.cap, CFrame.new(0, 0.42, -0.85))
	end
	return model, humanoid, head, root
end

local function track(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local t = animator:LoadAnimation(animation)
	t.Priority = priority
	t.Looped = looped
	return t
end

local function markersOf(venue: string): { [string]: any }
	local found: { [string]: any } = { Jalur = {} }
	local titik = Workspace:WaitForChild("Map"):WaitForChild("KafeTitik", 30)
	if titik == nil then
		return found
	end
	for _, part in titik:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("Venue") == venue then
			local role = part:GetAttribute("Role")
			if role == "Jalur" then
				table.insert(found.Jalur, part)
			elseif type(role) == "string" then
				found[role] = part
			end
		end
	end
	table.sort(found.Jalur, function(a: any, b: any)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	return found
end

local function addPrompt(parent: Instance, objectText: string, venueKey: string, say: ((string, number) -> ())?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MenuKafePrompt"
	prompt.ActionText = "Lihat Menu"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player: Player)
		Net.event(CafeConfig.OPEN_EVENT):FireClient(player, venueKey)
		if say then
			say("Silakan pilih menunya, Kak! 😊", 4)
		end
	end)
end

local function startVenue(key: string)
	local venue = CafeConfig.VENUES[key]
	local looks = LOOKS[key]
	local points = markersOf(key)
	local baristaPoint = points.Barista
	if venue == nil or looks == nil or baristaPoint == nil then
		warn("[Cafe] titik barista " .. key .. " tidak ditemukan")
		return
	end
	local lines = GREETINGS[key]

	-- ------------------------------------------------ barista di belakang konter
	local model, humanoid, head, root = buildPerson(looks.barista)
	if model and humanoid and head and root then
		local pos = baristaPoint.Position
		local facing = baristaPoint:GetAttribute("Facing")
		local face = if typeof(facing) == "Vector3" then facing else Vector3.new(0, 0, 1)
		local y = pos.Y + humanoid.HipHeight + root.Size.Y / 2
		local base = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X + face.X, y, pos.Z + face.Z))
		model:PivotTo(base)
		root.Anchored = true
		model.Parent = folder
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		track(animator, IDLE, Enum.AnimationPriority.Idle, true):Play(0)
		local wipe = track(animator, WIPE, Enum.AnimationPriority.Action, true)
		local wave = track(animator, WAVE, Enum.AnimationPriority.Action2, false)
		local cheer = track(animator, CHEER, Enum.AnimationPriority.Action2, false)
		local say = buildBubble(head, venue.accent)
		baristas[key] = {
			root = root,
			say = say,
			celebrate = function()
				cheer:Play(0.2)
			end,
		}
		addPrompt(root, looks.barista.title .. " " .. venue.title, key, say)
		local desk = points.Meja
		if desk then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "MenuKafePrompt"
			prompt.ActionText = "Lihat Menu"
			prompt.ObjectText = "Kasir " .. venue.title
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = desk
			prompt.Triggered:Connect(function(player: Player)
				Net.event(CafeConfig.OPEN_EVENT):FireClient(player, key)
				say("Silakan pilih menunya, Kak! 😊", 4)
			end)
		end
		task.spawn(function()
			while model.Parent do
				wipe:Play(0.4)
				wipe:AdjustSpeed(0.45)
				task.wait(9)
				wipe:Stop(0.5)
				task.wait(2.5)
			end
		end)
		task.spawn(function()
			local greeted = false
			local lastWave = 0
			local lastLine = 0
			local lineIndex = 0
			while model.Parent do
				local player, distance = nearestPlayer(root.Position)
				if player and distance < 16 then
					local character = player.Character
					local theirRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if theirRoot and theirRoot:IsA("BasePart") then
						local here = model:GetPivot().Position
						model:PivotTo(CFrame.lookAt(here, Vector3.new(theirRoot.Position.X, here.Y, theirRoot.Position.Z)))
					end
					if not greeted or os.clock() - lastWave > 14 then
						greeted = true
						lastWave = os.clock()
						wave:Play(0.2)
						say(lines[1], 5)
					elseif os.clock() - lastLine > 9 then
						lastLine = os.clock()
						lineIndex = lineIndex % #lines + 1
						say(lines[lineIndex], 5)
					end
				elseif greeted then
					greeted = false
					model:PivotTo(base)
				end
				task.wait(0.5)
			end
		end)
	end

	-- ------------------------------------------------ pelayan berkeliling
	local route: { BasePart } = points.Jalur
	if #route < 2 then
		return
	end
	local wModel, wHumanoid, wHead, wRoot = buildPerson(looks.waiter)
	if wModel == nil or wHumanoid == nil or wHead == nil or wRoot == nil then
		return
	end
	local start = route[1].Position
	wHumanoid.WalkSpeed = 6
	wHumanoid.JumpPower = 0
	wHumanoid.JumpHeight = 0
	wModel:PivotTo(CFrame.new(start.X, start.Y + wHumanoid.HipHeight + wRoot.Size.Y / 2 + 0.2, start.Z))
	wModel.Parent = folder
	pcall(function()
		wRoot:SetNetworkOwner(nil)
	end)
	local wAnimator = wHumanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	wAnimator.Parent = wHumanoid
	local idle = track(wAnimator, IDLE, Enum.AnimationPriority.Idle, true)
	local walk = track(wAnimator, WALK, Enum.AnimationPriority.Movement, true)
	local wWave = track(wAnimator, WAVE, Enum.AnimationPriority.Action2, false)
	idle:Play(0)
	local wSay = buildBubble(wHead, venue.accent)
	waiters[key] = { root = wRoot, say = wSay, celebrate = function() wWave:Play(0.2) end }
	addPrompt(wRoot, looks.waiter.title .. " " .. venue.title, key, wSay)

	local index = 1
	local greetedAt: { [Player]: number } = {}
	local lineIndex = 0
	task.spawn(function()
		while wModel.Parent do
			index = index % #route + 1
			local goal = route[index].Position
			wHumanoid:MoveTo(goal)
			idle:Stop(0.2)
			walk:Play(0.2)
			local stuckSince = os.clock()
			while wModel.Parent do
				local player, distance = nearestPlayer(wRoot.Position)
				if player and distance < 9 and os.clock() - (greetedAt[player] or 0) > 40 then
					-- berhenti, menghadap pemain, melambai, menyapa
					greetedAt[player] = os.clock()
					wHumanoid:MoveTo(wRoot.Position)
					walk:Stop(0.2)
					idle:Play(0.2)
					local character = player.Character
					local theirRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if theirRoot and theirRoot:IsA("BasePart") then
						local here = wRoot.Position
						wRoot.CFrame = CFrame.lookAt(here, Vector3.new(theirRoot.Position.X, here.Y, theirRoot.Position.Z))
					end
					wWave:Play(0.2)
					lineIndex = lineIndex % #lines + 1
					wSay(lines[lineIndex], 5)
					task.wait(3.5)
					wHumanoid:MoveTo(goal)
					idle:Stop(0.2)
					walk:Play(0.2)
					stuckSince = os.clock()
				end
				local flat = Vector3.new(goal.X - wRoot.Position.X, 0, goal.Z - wRoot.Position.Z)
				if flat.Magnitude < 1.8 or os.clock() - stuckSince > 14 then
					break
				end
				task.wait(0.25)
			end
			walk:Stop(0.2)
			idle:Play(0.2)
			if os.clock() - stuckSince > 14 then
				-- tersangkut: pindahkan ke titik jalur
				wModel:PivotTo(CFrame.new(goal.X, goal.Y + wHumanoid.HipHeight + wRoot.Size.Y / 2 + 0.2, goal.Z))
			end
			task.wait(2 + math.random() * 2)
		end
	end)
end

local function order(player: Player, venueKey: any, index: any): any
	local entry = CafeConfig.entry(venueKey, index)
	local item = if entry then StoreConfig.get(entry.id) else nil
	if entry == nil or item == nil or type(venueKey) ~= "string" then
		return { ok = false, message = "Menu itu tidak ada." }
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return { ok = false, message = "Tunggu sebentar ya." }
	end
	local staff = baristas[venueKey]
	local waiter = waiters[venueKey]
	local near = false
	for _, who in { staff, waiter } do
		if who and (root.Position - who.root.Position).Magnitude <= CafeConfig.ORDER_DISTANCE then
			near = true
		end
	end
	if staff == nil or not near then
		return { ok = false, message = "Dekati pelayan kafe dulu ya." }
	end
	if humanoid.SeatPart ~= nil and humanoid.SeatPart:IsA("VehicleSeat") then
		return { ok = false, message = "Turun dari kendaraan dulu ya." }
	end
	if busy[player] then
		return { ok = false, message = "Habiskan pesananmu dulu ya." }
	end
	if not EconomyService.trySpend(player, entry.price, "kafe:" .. venueKey .. ":" .. entry.id) then
		return { ok = false, message = "Uangmu belum cukup." }
	end
	busy[player] = true
	staff.say(`Ini pesananmu, Kak! {entry.name} {item.icon}`, 4)
	staff.celebrate()
	task.spawn(function()
		local ok, served = pcall(StoreService.serve, player, entry.id, true)
		if not ok or served ~= true then
			EconomyService.addMoney(player, entry.price, "kafe-kembali:" .. entry.id)
		end
		busy[player] = nil
	end)
	return { ok = true, message = `{item.icon} {entry.name} datang! Selamat menikmati.` }
end

function CafeService.init()
	folder = Instance.new("Folder")
	folder.Name = CafeConfig.FOLDER
	folder.Parent = Workspace
	Net.event(CafeConfig.OPEN_EVENT)
	Net.func(CafeConfig.ORDER_FUNC).OnServerInvoke = function(player: Player, venueKey: any, index: any): any
		local ok, value = pcall(order, player, venueKey, index)
		if ok then
			return value
		end
		warn("[Cafe] pesanan error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi." }
	end
end

function CafeService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
	end)
	for key in CafeConfig.VENUES do
		task.spawn(startVenue, key)
	end
end

return CafeService
