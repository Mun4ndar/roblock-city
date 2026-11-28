--!strict
-- BeachLifeService: menghidupkan pantai.
--   * dua pemain voli (NPC R15) di lapangan pantai, kiri dan kanan jaring, saling memukul bola. Animasi
--     lewat Animator (animasi resmi Roblox) sehingga terlihat semua pemain. Bola digambar di client
--     (BeachLifeController) dari waktu server: server hanya memutar animasi pukulan tepat saat bola tiba.
--   * penjual pantai (Config.VENDORS): pelayan Kafe Pantai (apron, mengelap meja) dan penjaga Kios Es Krim
--     (topi dan celemek kios). Keduanya tersenyum (wajah dari FaceService), menyapa pemain yang mendekat,
--     dan menawarkan menu lewat ProximityPrompt "Lihat Menu". Pesanan memakai StoreService.serve: pemain
--     minum/makan dengan animasi yang sama seperti di toko.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("BeachLifeConfig"))
local Net = require(Shared:WaitForChild("Net"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local StoreService = require(script.Parent:WaitForChild("StoreService"))

local BeachLifeService = {}

local rgb = Color3.fromRGB

-- Animasi R15 resmi Roblox.
local IDLE = "rbxassetid://507766388"
local SLASH = "rbxassetid://522635514" -- ayun lengan (toolslash): pukulan bola / mengelap meja
local WAVE = "rbxassetid://507770239"
local CHEER = "rbxassetid://507770677"
local DANCE = "rbxassetid://507771019"

type Look = {
	name: string,
	skin: Color3,
	top: Color3,
	bottom: Color3,
	shoes: Color3,
	hair: Color3,
	skirt: boolean?,
	laugh: boolean?,
	scale: number,
}

local folder: Folder
local busy: { [Player]: boolean } = {}

local function floorY(x: number, z: number, fromY: number, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function decorate(
	model: Model,
	on: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	ball: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
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
	return part
end

-- Wajah tertawa lebar: mata terpejam melengkung, pipi merah, mulut terbuka dengan gigi dan lidah. Hanya
-- Frame bulat + UICorner seperti FaceService.addFace (tanpa TextLabel dan tanpa ClipsDescendants, yang di
-- HP membuat wajah tampak hitam polos). Diberi nama "Wajah" supaya FaceService tidak menimpanya.
local function addLaughFace(head: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Wajah"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local ink = rgb(35, 30, 32)
	local order = 0
	-- radius nil = bulat penuh (lingkaran/oval)
	local function dot(x: number, y: number, w: number, h: number, color: Color3, transparency: number?, radius: number?)
		order += 1
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency or 0
		f.BorderSizePixel = 0
		f.ZIndex = order
		local c = Instance.new("UICorner")
		c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = gui
	end
	-- mata tertawa: busur lima titik, ujung lebih rendah dari tengah
	for _, cx in { 64, 136 } do
		for index = -2, 2 do
			local t = index / 2
			dot(cx + t * 17, 76 + t * t * 13, 12, 12, ink)
		end
	end
	dot(38, 116, 32, 20, rgb(255, 130, 140), 0.45) -- pipi
	dot(162, 116, 32, 20, rgb(255, 130, 140), 0.45)
	dot(100, 146, 86, 60, ink) -- mulut terbuka lebar
	dot(100, 161, 46, 26, rgb(255, 110, 130)) -- lidah
	for index = 0, 3 do -- deretan gigi atas
		dot(79 + index * 14, 127, 13, 12, rgb(255, 255, 255), 0, 3)
	end
	gui.Parent = head
end

-- Rig R15 polos (warna kulit/baju/celana sendiri, rambut dari part). Wajah tersenyum digambar
-- FaceService pada kepala yang belum punya Decal.
local function buildPerson(look: Look): (Model?, Humanoid?, BasePart?)
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
		warn("[BeachLife] gagal membuat " .. look.name .. ": " .. tostring(model))
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	local upper = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if
		humanoid == nil
		or head == nil
		or not head:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
		or upper == nil
		or not upper:IsA("BasePart")
		or lower == nil
		or not lower:IsA("BasePart")
	then
		model:Destroy()
		return nil, nil, nil
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
			d:Destroy() -- wajah bawaan diganti wajah tersenyum FaceService
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local n = part.Name
			if n:match("Foot$") then
				part.Color = look.shoes
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				part.Color = look.top
			elseif n == "LowerTorso" or n:match("UpperLeg$") then
				part.Color = look.bottom
			elseif n:match("LowerLeg$") then
				part.Color = if look.skirt then look.skin else look.bottom
			elseif n ~= "HumanoidRootPart" then
				part.Color = look.skin
			end
		end
	end
	-- kepala selalu berwarna kulit: tanpa tekstur bawaan dan tanpa SurfaceAppearance yang bisa menggelapkannya
	head.Color = look.skin
	head.Material = Enum.Material.SmoothPlastic
	if head:IsA("MeshPart") then
		head.TextureID = ""
	end
	for _, d in head:GetChildren() do
		if d:IsA("SurfaceAppearance") or d:IsA("FaceControls") then
			d:Destroy()
		end
	end
	decorate(model, head, "Rambut", Vector3.new(1.42, 1.3, 1.42), look.hair, CFrame.new(0, 0.36, 0.08), true)
	if look.laugh then
		addLaughFace(head)
	end
	return model, humanoid, root
end

local function placeModel(model: Model, humanoid: Humanoid, root: BasePart, at: Vector3, facing: Vector3, ground: number)
	local y = ground + humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X + facing.X, y, at.Z + facing.Z)))
	root.Anchored = true
	model.Parent = folder
end

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

local function animatorOf(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

-- ---------------------------------------------------------------- voli pantai

local PLAYERS_LOOK: { Look } = {
	{
		name = "PemainVoliRafi",
		skin = rgb(224, 172, 120),
		top = rgb(255, 214, 60),
		bottom = rgb(40, 130, 230),
		shoes = rgb(245, 245, 240),
		hair = rgb(30, 26, 26),
		laugh = true,
		scale = Config.PLAYER_SCALE,
	},
	{
		name = "PemainVoliNadia",
		skin = rgb(240, 190, 140),
		top = rgb(255, 110, 140),
		bottom = rgb(250, 250, 245),
		shoes = rgb(245, 245, 240),
		hair = rgb(96, 62, 40),
		laugh = true,
		scale = Config.PLAYER_SCALE,
	},
}

-- Gerakan sesaat dengan memindahkan seluruh model (akar dikunci, jadi digerakkan lewat PivotTo).
local function tweenPivot(model: Model, from: CFrame, to: CFrame, seconds: number)
	local steps = math.max(2, math.floor(seconds * 30))
	for i = 1, steps do
		local alpha = i / steps
		alpha = alpha * alpha * (3 - 2 * alpha)
		model:PivotTo(from:Lerp(to, alpha))
		task.wait(seconds / steps)
	end
end

type Athlete = {
	model: Model,
	base: CFrame,
	slash: AnimationTrack,
	cheer: AnimationTrack,
	wave: AnimationTrack,
	dance: AnimationTrack,
}

-- Lima variasi gerakan (Config.VARIATIONS); dipanggil sebelum waktu kontak. Kontak terjadi `lead` detik
-- setelah fungsi ini dimulai.
local function performVariation(who: Athlete, name: string)
	local model, base = who.model, who.base
	if name == "bump" then
		task.wait(0.25)
		who.slash:Play(0.08)
		who.slash:AdjustSpeed(1.6)
	elseif name == "set" then
		who.cheer:Play(0.1)
		who.cheer:AdjustSpeed(2.4)
		task.wait(0.9)
		who.cheer:Stop(0.3)
	elseif name == "spike" then
		-- lompat, ayun lengan di puncak, mendarat
		local up = base + Vector3.new(0, 2.6, 0)
		tweenPivot(model, base, up, 0.28)
		who.slash:Play(0.05)
		who.slash:AdjustSpeed(2)
		task.wait(0.2)
		tweenPivot(model, up, base, 0.3)
	elseif name == "dive" then
		-- menyelam ke depan: badan condong dan turun, lalu bangun lagi
		local down = base * CFrame.new(0, -1.7, -1.2) * CFrame.Angles(math.rad(-62), 0, 0)
		tweenPivot(model, base, down, 0.3)
		who.slash:Play(0.05)
		who.slash:AdjustSpeed(1.6)
		task.wait(0.55)
		tweenPivot(model, down, base, 0.5)
	else -- celebrate
		task.wait(0.25)
		who.slash:Play(0.08)
		who.slash:AdjustSpeed(1.6)
		task.wait(0.5)
		who.cheer:Play(0.2)
		who.dance:Play(0.3)
		task.wait(1.6)
		who.dance:Stop(0.3)
		who.cheer:Stop(0.3)
	end
end

local function startVolley()
	local c = Config.COURT_CENTER
	local people: { Athlete } = {}
	for side = 0, 1 do
		local model, humanoid, root = buildPerson(PLAYERS_LOOK[side + 1])
		if model == nil or humanoid == nil or root == nil then
			return
		end
		if side == 1 then
			local head = model:FindFirstChild("Head") :: BasePart
			-- Nadia: kuncir kecil di belakang kepala
			decorate(model, head, "Kuncir", Vector3.new(0.5, 0.9, 0.5), PLAYERS_LOOK[2].hair, CFrame.new(0, 0.2, 0.75), true)
		end
		model:ScaleTo(PLAYERS_LOOK[side + 1].scale)
		local at = Config.hitPoint(side)
		local ground = floorY(at.X, at.Z, c.Y + 10, c.Y)
		placeModel(model, humanoid, root, Vector3.new(at.X, 0, at.Z), Vector3.new(0, 0, if side == 0 then 1 else -1), ground)
		local animator = animatorOf(humanoid)
		loadTrack(animator, IDLE, Enum.AnimationPriority.Idle, true):Play(0)
		people[side + 1] = {
			model = model,
			base = model:GetPivot(),
			slash = loadTrack(animator, SLASH, Enum.AnimationPriority.Action2, false),
			cheer = loadTrack(animator, CHEER, Enum.AnimationPriority.Action2, false),
			wave = loadTrack(animator, WAVE, Enum.AnimationPriority.Action2, false),
			dance = loadTrack(animator, DANCE, Enum.AnimationPriority.Action2, true),
		}
	end

	local epoch = Workspace:GetServerTimeNow() + 1
	folder:SetAttribute("Epoch", epoch)
	local lead = 0.45 -- gerakan dimulai sedikit lebih awal supaya kontak tepat saat bola tiba
	local n = 0
	while folder.Parent do
		local waitFor = epoch + Config.hitTime(n) - lead - Workspace:GetServerTimeNow()
		if waitFor > 0 then
			task.wait(waitFor)
		end
		local who = people[n % 2 + 1]
		local name = Config.variationOf(n).name
		task.spawn(performVariation, who, name)
		n += 1
		task.wait(0.05)
	end
end

-- ---------------------------------------------------------------- penjual pantai (kafe dan kios es krim)

local CAFE_MAIN = "Silahkan pilih menu dulu kak, baru duduk. 😊"
local ESKRIM_MAIN = "Es krim dingin, Kak! Silakan pilih rasa 🍦"

type VendorSetup = {
	look: Look,
	dress: (model: Model, head: BasePart, upper: BasePart, lower: BasePart) -> (),
	main: string, -- sapaan utama: saat pemain mendekat dan saat "Lihat Menu" ditekan
	lines: { string }, -- ucapan bergilir selama pemain masih di dekat penjual
	seatLine: string?, -- diucapkan bila pemain duduk di dekat penjual padahal belum pernah memesan
}

type VendorState = {
	def: Config.Vendor,
	root: BasePart,
	say: (string, number) -> (),
	celebrate: () -> (),
}

local vendors: { [string]: VendorState } = {}
local ordered: { [string]: { [Player]: boolean } } = {} -- [vendorId][pemain] = pernah memesan

local SETUPS: { [string]: VendorSetup } = {
	cafe = {
		look = {
			name = Config.VENDORS.cafe.npcName,
			skin = rgb(224, 172, 120),
			top = rgb(252, 250, 245),
			bottom = rgb(30, 120, 130),
			shoes = rgb(70, 52, 44),
			hair = rgb(58, 38, 30),
			skirt = true,
			scale = 1,
		},
		dress = function(model: Model, head: BasePart, upper: BasePart, lower: BasePart)
			local coral = rgb(255, 118, 108)
			local cream = rgb(255, 244, 226)
			local hair = rgb(58, 38, 30)
			-- celemek (apron) kafe: bagian dada, rok, dan dua tali bahu
			decorate(model, upper, "CelemekAtas", Vector3.new(1.55, 1.15, 0.12), coral, CFrame.new(0, -0.2, -0.54))
			decorate(model, lower, "CelemekBawah", Vector3.new(1.7, 1.0, 0.12), coral, CFrame.new(0, -0.5, -0.54))
			decorate(model, upper, "KantongCelemek", Vector3.new(0.7, 0.35, 0.05), cream, CFrame.new(0, -0.3, -0.62))
			decorate(model, upper, "TaliKiri", Vector3.new(0.18, 0.75, 0.1), coral, CFrame.new(-0.5, 0.45, -0.52))
			decorate(model, upper, "TaliKanan", Vector3.new(0.18, 0.75, 0.1), coral, CFrame.new(0.5, 0.45, -0.52))
			-- sanggul rambut dengan ikat rambut
			decorate(model, head, "Sanggul", Vector3.new(0.75, 0.75, 0.75), hair, CFrame.new(0, 0.95, 0.2), true)
			decorate(model, head, "IkatRambut", Vector3.new(0.4, 0.4, 0.4), coral, CFrame.new(0, 0.72, 0.5), true)
		end,
		main = CAFE_MAIN,
		lines = {
			CAFE_MAIN,
			"Mau pesan apa, Kak? Ada es teh, kopi susu, es krim...",
			CAFE_MAIN,
			"Minuman dingin cocok buat main di pantai! 🍹",
		},
		seatLine = CAFE_MAIN,
	},
	eskrim = {
		look = {
			name = Config.VENDORS.eskrim.npcName,
			skin = rgb(236, 184, 132),
			top = rgb(255, 255, 255),
			bottom = rgb(70, 150, 220),
			shoes = rgb(250, 250, 250),
			hair = rgb(48, 32, 26),
			scale = 1,
		},
		dress = function(model: Model, head: BasePart, upper: BasePart, lower: BasePart)
			local pink = rgb(240, 120, 170)
			local white = rgb(255, 255, 255)
			local mint = rgb(150, 225, 200)
			-- seragam kios: celemek merah muda bergaris putih dengan lencana es krim
			decorate(model, upper, "CelemekAtas", Vector3.new(1.55, 1.15, 0.12), pink, CFrame.new(0, -0.2, -0.54))
			decorate(model, lower, "CelemekBawah", Vector3.new(1.7, 0.9, 0.12), pink, CFrame.new(0, -0.45, -0.54))
			decorate(model, upper, "GarisCelemek", Vector3.new(1.55, 0.16, 0.05), white, CFrame.new(0, 0.2, -0.61))
			decorate(model, upper, "LencanaCone", Vector3.new(0.22, 0.3, 0.05), rgb(230, 180, 110), CFrame.new(0.4, -0.3, -0.62))
			decorate(model, upper, "LencanaScoop", Vector3.new(0.3, 0.3, 0.12), mint, CFrame.new(0.4, -0.08, -0.62), true)
			decorate(model, upper, "TaliKiri", Vector3.new(0.18, 0.75, 0.1), pink, CFrame.new(-0.5, 0.45, -0.52))
			decorate(model, upper, "TaliKanan", Vector3.new(0.18, 0.75, 0.1), pink, CFrame.new(0.5, 0.45, -0.52))
			-- topi kios: mahkota merah muda, pita putih, lidah topi, dan pompon
			decorate(model, head, "Topi", Vector3.new(1.34, 0.5, 1.34), pink, CFrame.new(0, 0.93, 0.06))
			decorate(model, head, "PitaTopi", Vector3.new(1.38, 0.14, 1.38), white, CFrame.new(0, 0.74, 0.06))
			decorate(model, head, "LidahTopi", Vector3.new(1.2, 0.1, 0.55), pink, CFrame.new(0, 0.7, -0.85))
			decorate(model, head, "Pompon", Vector3.new(0.34, 0.34, 0.34), white, CFrame.new(0, 1.3, 0.06), true)
		end,
		main = ESKRIM_MAIN,
		lines = {
			ESKRIM_MAIN,
			"Panas-panas begini paling enak makan es krim! ☀️",
			"Ada permen lolipop dan susu kotak juga, Kak! 🍭",
		},
	},
}

local function buildBubble(head: BasePart): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanPelayan"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(250, 56)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
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
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(40, 60, 80)
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

-- Pemain yang baru duduk (bukan di kendaraan) dalam jarak `range` dari penjual padahal belum pernah memesan.
local function newlySeated(position: Vector3, range: number, told: { [Player]: Instance }, served: { [Player]: boolean }): boolean
	local found = false
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local seat = if humanoid then humanoid.SeatPart else nil
		if seat == nil or seat:IsA("VehicleSeat") or (seat.Position - position).Magnitude > range then
			told[player] = nil
		elseif told[player] ~= seat then
			told[player] = seat
			if not served[player] then
				found = true
			end
		end
	end
	return found
end

local function startVendor(def: Config.Vendor, setup: VendorSetup)
	local model, humanoid, root = buildPerson(setup.look)
	if model == nil or humanoid == nil or root == nil then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart
	local upper = model:FindFirstChild("UpperTorso") :: BasePart
	local lower = model:FindFirstChild("LowerTorso") :: BasePart
	setup.dress(model, head, upper, lower)
	local p = def.position
	local ground = floorY(p.X, p.Z, p.Y + 3, p.Y)
	placeModel(model, humanoid, root, Vector3.new(p.X, 0, p.Z), def.facing, ground)

	local animator = animatorOf(humanoid)
	loadTrack(animator, IDLE, Enum.AnimationPriority.Idle, true):Play(0)
	local wipe = loadTrack(animator, SLASH, Enum.AnimationPriority.Action, true)
	local wave = loadTrack(animator, WAVE, Enum.AnimationPriority.Action2, false)
	local cheer = loadTrack(animator, CHEER, Enum.AnimationPriority.Action2, false)
	local say = buildBubble(head)
	local served: { [Player]: boolean } = {}
	ordered[def.id] = served
	vendors[def.id] = {
		def = def,
		root = root,
		say = say,
		celebrate = function()
			cheer:Play(0.2)
		end,
	}

	-- Mengelap meja/konter terus-menerus, istirahat sebentar tiap beberapa detik.
	task.spawn(function()
		while model.Parent do
			wipe:Play(0.4)
			wipe:AdjustSpeed(0.45)
			task.wait(9)
			wipe:Stop(0.5)
			task.wait(2.5)
		end
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MenuKafePrompt"
	prompt.ActionText = "Lihat Menu"
	prompt.ObjectText = def.objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		Net.event(Config.OPEN_EVENT):FireClient(player, def.id)
		say(setup.main, 5)
	end)

	-- Menyapa pemain yang mendekat: berbalik, melambai, lalu mengucapkan sapaan utama.
	task.spawn(function()
		local greeted = false
		local lastWave = 0
		local lastLine = 0
		local lineIndex = 1 -- lines[1] = sapaan utama, sudah diucapkan saat pemain datang
		local baseCFrame = model:GetPivot()
		local told: { [Player]: Instance } = {}
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
					lastLine = os.clock()
					lineIndex = 1
					wave:Play(0.2)
					say(setup.main, 6)
				elseif os.clock() - lastLine > 9 then
					lastLine = os.clock()
					lineIndex = lineIndex % #setup.lines + 1
					say(setup.lines[lineIndex], 5)
				end
			elseif greeted then
				greeted = false
				model:PivotTo(baseCFrame)
			end
			local seatLine = setup.seatLine
			if seatLine and newlySeated(root.Position, 30, told, served) then
				lastLine = os.clock()
				lastWave = os.clock()
				wave:Play(0.2)
				say(seatLine, 7)
			end
			task.wait(0.5)
		end
	end)
end

local function order(player: Player, id: any, vendorId: any): any
	if type(id) ~= "string" then
		return { ok = false, message = "Pesanan tidak valid." }
	end
	local def = Config.vendor(vendorId)
	local state = if def then vendors[def.id] else nil
	if def == nil or state == nil then
		return { ok = false, message = "Penjualnya belum siap, coba lagi ya." }
	end
	local item = StoreConfig.get(id)
	if item == nil or table.find(def.menu, id) == nil then
		return { ok = false, message = "Menu itu tidak ada." }
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return { ok = false, message = "Tunggu sebentar ya." }
	end
	if (root.Position - state.root.Position).Magnitude > Config.ORDER_DISTANCE then
		return { ok = false, message = `Dekati {string.lower(def.objectText)} dulu ya.` }
	end
	if humanoid.SeatPart ~= nil then
		return { ok = false, message = "Turun dari kendaraan atau kursi dulu ya." }
	end
	if busy[player] then
		return { ok = false, message = "Habiskan pesananmu dulu ya." }
	end
	local reason = if def.id == "cafe" then "kafe" else def.id
	local price = Config.price(id)
	if not EconomyService.trySpend(player, price, `{reason}:{id}`) then
		return { ok = false, message = "Uangmu belum cukup." }
	end
	busy[player] = true
	local served = ordered[def.id]
	if served then
		served[player] = true
	end
	state.say(`Ini pesananmu, Kak! {item.name} {item.icon}`, 4)
	state.celebrate()
	task.spawn(function()
		local ok, done = pcall(StoreService.serve, player, id, true)
		if not ok or done ~= true then
			EconomyService.addMoney(player, price, `{reason}-kembali:{id}`)
		end
		busy[player] = nil
	end)
	return { ok = true, message = `{item.icon} {item.name} datang! Selamat menikmati.` }
end

function BeachLifeService.init()
	folder = Instance.new("Folder")
	folder.Name = Config.FOLDER
	folder.Parent = Workspace
	Net.event(Config.OPEN_EVENT)
	Net.func(Config.ORDER_FUNC).OnServerInvoke = function(player: Player, id: any, vendorId: any): any
		local ok, value = pcall(order, player, id, vendorId)
		if ok then
			return value
		end
		warn("[BeachLife] pesanan error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi." }
	end
end

function BeachLifeService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
		for _, served in ordered do
			served[player] = nil
		end
	end)
	for id, def in Config.VENDORS do
		local setup = SETUPS[id]
		if setup then
			task.spawn(startVendor, def, setup)
		end
	end
	task.spawn(startVolley)
end

return BeachLifeService
