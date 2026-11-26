--!strict
--[[
	CampService: Perkemahan tepi danau (lihat Shared.CampConfig dan map/BuildKemah).
	  * Memancing lengkap di server: beli pancing -> lempar di dermaga -> ikan menggigit -> tarik tepat waktu.
	    Client hanya mengirim aksi ("cast", "reel", "buy", ...); jarak, waktu gigitan, jenis ikan, harga, dan uang
	    ditentukan di sini. Ikan -> dibakar di api unggun / panggangan (lebih mahal) atau dijual ke Kak Sari.
	  * NPC: Kak Sari (penjual pancing, tenda, mie) dan Kak Bagas (gitaris, lagu ceria + gelembung nyanyi bareng).
	    NPC dan musik hanya ada bila ada pemain dalam SPAWN_RANGE (hemat HP). Semua NPC menyapa dengan "Kak".
	  * Tenda pemain: satu per pemain, maksimal MAX_TENTS di server, hilang saat pemain keluar.
	Data tersimpan di PlayerData.camp; client membaca atribut Player "Kemah" (JSON CampView).
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local Config = require(Shared:WaitForChild("CampConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local FoodService = require(script.Parent:WaitForChild("FoodService")) :: any

type Result = { ok: boolean, message: string }
type CampView = Config.CampView

type Person = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	say: (string, number) -> (),
}

type Session = {
	token: number,
	spot: BasePart,
	state: string, -- "wait" | "bite"
	biteAt: number,
	fishId: string,
	bobber: Part,
	rodPart: Part,
}

local CampService = {}

local rgb = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local IDLE = "rbxassetid://507766388"
local WAVE = "rbxassetid://507770239"
local CHEER = "rbxassetid://507770677"

local fishRemote: RemoteEvent
local openRemote: RemoteEvent
local lastCall: { [Player]: number } = {}
local lastCast: { [Player]: number } = {}
local sessions: { [Player]: Session } = {}
local busyUntil: { [Player]: number } = {}
local tents: { { owner: Player, model: Model } } = {}
local npcFolder: Folder
local tentsFolder: Folder
local vendor: Person? = nil
local guitarist: Person? = nil
local _music: Sound? = nil
local tokenCounter = 0
local songToken = 0

-- ---------------------------------------------------------------- data

local function getCamp(data: Types.PlayerData): CampView
	local anyData: any = data
	local camp: any = anyData.camp
	if type(camp) ~= "table" then
		camp = {}
		anyData.camp = camp
	end
	if type(camp.rod) ~= "string" then
		camp.rod = ""
	end
	camp.tent = camp.tent == true
	for _, key in { "mie", "mieMasak" } do
		if type(camp[key]) ~= "number" then
			camp[key] = 0
		end
	end
	for _, key in { "fish", "grilled" } do
		if type(camp[key]) ~= "table" then
			camp[key] = {}
		end
	end
	return camp
end

local function publish(player: Player, camp: CampView)
	player:SetAttribute(Config.ATTR_PLAYER, HttpService:JSONEncode(camp))
end

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function nearTagged(player: Player, tag: string, distance: number, kind: string?): BasePart?
	local root = rootOf(player)
	if root == nil then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = distance
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			if kind == nil or inst:GetAttribute("Kind") == kind then
				local d = (inst.Position - root.Position).Magnitude
				if d <= bestDistance then
					best, bestDistance = inst, d
				end
			end
		end
	end
	return best
end

local function say(person: Person?, line: string, seconds: number)
	if person then
		person.say(line, seconds)
	end
end

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

-- ---------------------------------------------------------------- NPC

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

local function buildBubble(head: BasePart, accent: Color3): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Gelembung"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(300, 58)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 48
	gui.AlwaysOnTop = true
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

local function loadTrack(humanoid: Humanoid, id: string, looped: boolean): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Looped = looped
	track.Priority = if looped then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Action
	return track
end

local function buildPerson(
	name: string,
	title: string,
	skin: Color3,
	top: Color3,
	bottom: Color3,
	hair: Color3,
	hat: string?,
	accent: Color3
): Person?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = top
	description.LeftLegColor = bottom
	description.RightLegColor = bottom
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Kemah] gagal membuat NPC: " .. tostring(model))
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
				part.Color = top
			elseif n == "LowerTorso" or n:match("Leg$") then
				part.Color = bottom
			else
				part.Color = skin
			end
		end
	end
	attach(model, head, Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 0.36, 0.08), hair, BALL, SP)
	attach(model, head, Vector3.new(1.3, 0.35, 0.6), CFrame.new(0, 0.62, -0.46), hair, BLOCK, SP)
	if hat == "topi" then
		attach(
			model,
			head,
			Vector3.new(1.45, 0.45, 1.45),
			CFrame.new(0, 0.62, 0),
			rgb(60, 130, 200),
			CYL,
			SP
		)
	elseif hat == "caping" then
		attach(
			model,
			head,
			Vector3.new(0.14, 2.6, 2.6),
			CFrame.new(0, 0.74, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(214, 180, 110),
			CYL,
			SP
		)
	end
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(170, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
	board.MaxDistance = 30
	board.AlwaysOnTop = true
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
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		say = buildBubble(head, accent),
	}
end

local function placeAt(person: Person, spot: BasePart, seated: boolean)
	local floorY = spot.Position.Y
	local lift = if seated then 0 else person.humanoid.HipHeight + person.root.Size.Y / 2
	local position = Vector3.new(spot.Position.X, floorY + lift, spot.Position.Z)
	local front = spot.CFrame.LookVector
	person.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(front.X, 0, front.Z)))
	person.root.Anchored = true
	person.model.Parent = npcFolder
end

local function campFolder(): Instance?
	for _, part in CollectionService:GetTagged(Config.TAG_CENTER) do
		return part.Parent
	end
	return nil
end

local function campCenter(): Vector3?
	for _, part in CollectionService:GetTagged(Config.TAG_CENTER) do
		if part:IsA("BasePart") then
			return part.Position
		end
	end
	return nil
end

local function spawnVendor()
	local folder = campFolder()
	local spot = if folder then folder:FindFirstChild("TitikPenjual") else nil
	if spot == nil or not spot:IsA("BasePart") then
		return
	end
	local person = buildPerson(
		"Kak Sari",
		"Warung Kemah",
		rgb(222, 170, 130),
		rgb(240, 140, 90),
		rgb(90, 110, 150),
		rgb(50, 36, 30),
		"caping",
		rgb(255, 190, 70)
	)
	if person == nil then
		return
	end
	placeAt(person, spot, false)
	person.model:SetAttribute("Penjual", true)
	loadTrack(person.humanoid, IDLE, true):Play(0.3)
	vendor = person
end

local function spawnGuitarist()
	local folder = campFolder()
	local spot = if folder then folder:FindFirstChild("TitikGitaris") else nil
	if spot == nil or not spot:IsA("BasePart") then
		return
	end
	local person = buildPerson(
		"Kak Bagas",
		"Gitaris Kemah",
		rgb(200, 150, 112),
		rgb(70, 140, 100),
		rgb(80, 90, 120),
		rgb(30, 24, 22),
		"topi",
		rgb(120, 200, 255)
	)
	if person == nil then
		return
	end
	placeAt(person, spot, true)
	local upper = person.model:FindFirstChild("UpperTorso") :: BasePart
	-- gitar: badan + lubang suara + leher + kepala gitar
	local wood = rgb(176, 110, 60)
	attach(
		person.model,
		upper,
		Vector3.new(1.5, 1.7, 0.4),
		CFrame.new(0.15, -0.55, -0.75) * CFrame.Angles(0, 0, math.rad(-22)),
		wood,
		BALL,
		SP
	)
	attach(
		person.model,
		upper,
		Vector3.new(0.5, 0.5, 0.1),
		CFrame.new(0.15, -0.5, -0.98) * CFrame.Angles(0, 0, math.rad(-22)),
		rgb(40, 30, 28),
		CYL,
		SP
	)
	attach(
		person.model,
		upper,
		Vector3.new(0.22, 2.4, 0.16),
		CFrame.new(-0.85, 0.65, -0.75) * CFrame.Angles(0, 0, math.rad(-22)),
		rgb(70, 46, 30),
		BLOCK,
		SP
	)
	attach(
		person.model,
		upper,
		Vector3.new(0.38, 0.5, 0.18),
		CFrame.new(-1.3, 1.95, -0.75) * CFrame.Angles(0, 0, math.rad(-22)),
		rgb(70, 46, 30),
		BLOCK,
		SP
	)
	person.model:SetAttribute("Gitaris", true)
	CollectionService:AddTag(person.model, Config.TAG_GUITAR)
	guitarist = person
	-- musik gitar berlisensi (APM Music via Roblox), tanpa vokal; 3D supaya hanya terdengar di sekitar api unggun
	local head = person.model:FindFirstChild("Head") :: BasePart
	local sound = Instance.new("Sound")
	sound.Name = "MusikGitar"
	sound.Volume = 0.55
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 95
	sound.Parent = head
	_music = sound
	songToken += 1
	local mine = songToken
	task.spawn(function()
		local index = 0
		while songToken == mine and sound.Parent ~= nil do
			index = index % #Config.GUITAR_TRACKS + 1
			sound.SoundId = "rbxassetid://" .. Config.GUITAR_TRACKS[index]
			sound:Play()
			local started = os.clock()
			repeat
				task.wait(1)
			until songToken ~= mine
				or sound.Parent == nil
				or (not sound.IsPlaying and os.clock() - started > 4)
		end
	end)
	-- gelembung nyanyi bareng
	task.spawn(function()
		local i = 0
		task.wait(2)
		while songToken == mine and person.model.Parent ~= nil do
			i = i % #Config.SONG + 1
			person.say(Config.SONG[i], 5)
			task.wait(6.5)
		end
	end)
end

local function despawnNpc()
	songToken += 1
	if vendor then
		vendor.model:Destroy()
		vendor = nil
	end
	if guitarist then
		guitarist.model:Destroy()
		guitarist = nil
	end
	_music = nil
end

local function nearestPlayerDistance(position: Vector3): number
	local best = math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			best = math.min(best, (root.Position - position).Magnitude)
		end
	end
	return best
end

local function manage()
	local center = campCenter()
	if center == nil then
		despawnNpc()
		return
	end
	local distance = nearestPlayerDistance(center)
	if distance > Config.DESPAWN_RANGE then
		despawnNpc()
	elseif distance <= Config.SPAWN_RANGE then
		if vendor == nil then
			spawnVendor()
		end
		if guitarist == nil then
			spawnGuitarist()
		end
	end
end

local function greetLoop()
	local lastVendor, lastGuitar = -100, -100
	while true do
		task.wait(0.6)
		local now = os.clock()
		if
			vendor
			and now - lastVendor > 14
			and nearestPlayerDistance(vendor.root.Position) <= 18
		then
			lastVendor = now
			vendor.say(pick(Config.VENDOR_LINES), 5)
			local wave =
				loadTrack(vendor.humanoid, if math.random() < 0.5 then WAVE else CHEER, false)
			wave:Play(0.2)
		end
		if
			guitarist
			and now - lastGuitar > 30
			and nearestPlayerDistance(guitarist.root.Position) <= 14
		then
			lastGuitar = now
			guitarist.say(pick(Config.GREETINGS), 5)
		end
	end
end

-- ---------------------------------------------------------------- memancing

local function cleanSession(player: Player, session: Session?)
	local s = session or sessions[player]
	if s == nil then
		return
	end
	if sessions[player] == s then
		sessions[player] = nil
	end
	s.bobber:Destroy()
	s.rodPart:Destroy()
end

local function pickFish(rod: string): Config.Fish
	local total = 0
	for _, fish in Config.FISH do
		total += Config.weightFor(fish, rod)
	end
	local roll = math.random() * total
	for _, fish in Config.FISH do
		roll -= Config.weightFor(fish, rod)
		if roll <= 0 then
			return fish
		end
	end
	return Config.FISH[1]
end

local function addTo(map: { [string]: number }, id: string, amount: number)
	map[id] = math.clamp((map[id] or 0) + amount, 0, Config.STACK_MAX)
	if map[id] == 0 then
		map[id] = nil
	end
end

local function buildRig(player: Player, spot: BasePart): (Part?, Part?)
	local character = player.Character
	local hand = if character then character:FindFirstChild("RightHand") else nil
	if hand == nil or not hand:IsA("BasePart") then
		return nil, nil
	end
	local lx, lz, wy =
		spot:GetAttribute("LookX"), spot:GetAttribute("LookZ"), spot:GetAttribute("WaterY")
	local look = Vector3.new(
		if type(lx) == "number" then lx else -1,
		0,
		if type(lz) == "number" then lz else 0
	)
	local waterY = if type(wy) == "number" then wy else -1
	local bobberPos = spot.Position + look.Unit * 13
	local bobber = Instance.new("Part")
	bobber.Name = "Pelampung"
	bobber.Shape = BALL
	bobber.Size = Vector3.one * 0.9
	bobber.Color = rgb(235, 60, 60)
	bobber.Material = SP
	bobber.Anchored = true
	bobber.CanCollide, bobber.CanTouch, bobber.CanQuery = false, false, false
	bobber.Position = Vector3.new(bobberPos.X, waterY + 0.25, bobberPos.Z)
	local band = Instance.new("Part")
	band.Shape = BALL
	band.Size = Vector3.one * 0.5
	band.Color = rgb(255, 255, 255)
	band.Material = SP
	band.CanCollide, band.CanTouch, band.CanQuery, band.Massless = false, false, false, true
	band.CFrame = bobber.CFrame * CFrame.new(0, 0.42, 0)
	local bw = Instance.new("WeldConstraint")
	bw.Part0 = bobber
	bw.Part1 = band
	bw.Parent = band
	band.Parent = bobber
	local bobberAtt = Instance.new("Attachment")
	bobberAtt.Position = Vector3.new(0, 0.3, 0)
	bobberAtt.Parent = bobber
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Cipratan"
	splash.Enabled = false
	splash.Rate = 0
	splash.Lifetime = NumberRange.new(0.4, 0.8)
	splash.Speed = NumberRange.new(6, 10)
	splash.SpreadAngle = Vector2.new(40, 40)
	splash.Size = NumberSequence.new(0.5, 0)
	splash.Color = ColorSequence.new(rgb(200, 235, 255))
	splash.Acceleration = Vector3.new(0, -24, 0)
	splash.Parent = bobber
	bobber.Parent = Workspace
	-- joran di tangan kanan + tali
	local rod = Instance.new("Part")
	rod.Name = "Joran"
	rod.Shape = CYL
	rod.Size = Vector3.new(6, 0.18, 0.18)
	rod.Color = rgb(120, 82, 50)
	rod.Material = Enum.Material.Wood
	rod.CanCollide, rod.CanTouch, rod.CanQuery, rod.CastShadow, rod.Massless =
		false, false, false, false, true
	-- ujung joran menjauh ke depan-atas dari tangan
	rod.CFrame = hand.CFrame
		* CFrame.new(0, -0.3, -2.6)
		* CFrame.Angles(0, math.rad(90), math.rad(20))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = rod
	weld.Parent = rod
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(-3, 0, 0)
	tip.Parent = rod
	local beam = Instance.new("Beam")
	beam.Attachment0 = tip
	beam.Attachment1 = bobberAtt
	beam.Width0, beam.Width1 = 0.05, 0.05
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(rgb(240, 240, 240))
	beam.Parent = rod
	rod.Parent = character
	return bobber, rod
end

local function castLine(player: Player, data: Types.PlayerData): Result
	local camp = getCamp(data)
	if camp.rod == "" then
		return result(
			false,
			"Kamu belum punya pancing. Beli di Warung Kemah ya, Kak Sari menjualnya."
		)
	end
	local now = os.clock()
	if lastCast[player] and now - lastCast[player] < Config.CAST_COOLDOWN then
		return result(false, "Pelan-pelan, Kak.")
	end
	lastCast[player] = now
	local spot = nearTagged(player, Config.TAG_SPOT, Config.SPOT_DISTANCE, nil)
	if spot == nil then
		return result(false, "Pergi ke dermaga dulu untuk memancing.")
	end
	if sessions[player] then
		return result(false, "Pancingmu sudah di air. Tunggu ikan menggigit!")
	end
	local bobber, rodPart = buildRig(player, spot)
	if bobber == nil or rodPart == nil then
		return result(false, "Gagal melempar pancing, coba lagi.")
	end
	tokenCounter += 1
	local lo, hi = Config.biteDelay(camp.rod)
	local delay = lo + math.random() * (hi - lo)
	local fish = pickFish(camp.rod)
	local session: Session = {
		token = tokenCounter,
		spot = spot,
		state = "wait",
		biteAt = now + delay,
		fishId = fish.id,
		bobber = bobber,
		rodPart = rodPart,
	}
	sessions[player] = session
	fishRemote:FireClient(player, "cast")
	task.delay(delay, function()
		if sessions[player] ~= session or session.state ~= "wait" then
			return
		end
		session.state = "bite"
		bobber.Position -= Vector3.new(0, 0.55, 0)
		local splash = bobber:FindFirstChild("Cipratan") :: ParticleEmitter?
		if splash then
			splash:Emit(14)
		end
		fishRemote:FireClient(player, "bite", Config.BITE_WINDOW)
		task.delay(Config.BITE_WINDOW + Config.BITE_GRACE, function()
			if sessions[player] == session and session.state == "bite" then
				cleanSession(player, session)
				fishRemote:FireClient(player, "miss")
			end
		end)
	end)
	return result(true, "Pancing dilempar. Tunggu pelampung bergerak...")
end

local function reelIn(player: Player, data: Types.PlayerData): Result
	local session = sessions[player]
	if session == nil then
		return result(false, "Lempar pancingmu dulu di dermaga.")
	end
	local root = rootOf(player)
	if
		root == nil
		or (root.Position - session.spot.Position).Magnitude > Config.SPOT_DISTANCE + 8
	then
		cleanSession(player, session)
		fishRemote:FireClient(player, "cancel")
		return result(false, "Kamu terlalu jauh dari dermaga, pancing ditarik.")
	end
	if session.state == "wait" then
		cleanSession(player, session)
		fishRemote:FireClient(player, "cancel")
		return result(false, "Terlalu cepat! Ikannya kabur. Tunggu pelampung tenggelam ya.")
	end
	local elapsed = os.clock() - session.biteAt
	local fish = Config.fish(session.fishId)
	cleanSession(player, session)
	if fish == nil or elapsed > Config.BITE_WINDOW + Config.BITE_GRACE then
		fishRemote:FireClient(player, "miss")
		return result(false, "Ikannya lepas! Coba lagi, Kak.")
	end
	local camp = getCamp(data)
	if (camp.fish[fish.id] or 0) >= Config.STACK_MAX then
		return result(false, "Ember ikanmu penuh! Jual atau bakar dulu.")
	end
	addTo(camp.fish, fish.id, 1)
	publish(player, camp)
	fishRemote:FireClient(player, "catch", fish.id)
	return result(true, `{fish.icon} Dapat {fish.name}! Bakar di api unggun atau jual ke Kak Sari.`)
end

-- ---------------------------------------------------------------- transaksi

local function ensureVendor(player: Player): boolean
	return nearTagged(player, Config.TAG_VENDOR, Config.TALK_DISTANCE, nil) ~= nil
end

local function buyItem(player: Player, camp: CampView, itemId: any): Result
	local item = Config.item(itemId)
	if item == nil then
		return result(false, "Barang itu tidak dijual.")
	end
	if not ensureVendor(player) then
		return result(false, "Dekati Warung Kemah dulu ya.")
	end
	if item.id == "pancing_kayu" and camp.rod ~= "" then
		return result(false, "Kamu sudah punya pancing.")
	elseif item.id == "pancing_fiber" and camp.rod == "fiber" then
		return result(false, "Kamu sudah punya Pancing Fiber.")
	elseif item.id == "tenda" and camp.tent then
		return result(false, "Kamu sudah punya tenda. Pasang lewat menu ini.")
	elseif item.id == "mie" and camp.mie >= Config.STACK_MAX then
		return result(false, "Persediaan mie penuh.")
	end
	if not EconomyService.trySpend(player, item.price, "kemah:" .. item.id) then
		return result(false, "Uangmu belum cukup untuk " .. item.name .. ".")
	end
	if item.id == "pancing_kayu" then
		camp.rod = "kayu"
	elseif item.id == "pancing_fiber" then
		camp.rod = "fiber"
	elseif item.id == "tenda" then
		camp.tent = true
	elseif item.id == "mie" then
		camp.mie += 1
	end
	publish(player, camp)
	say(vendor, pick(Config.THANKS), 4)
	return result(true, `{item.icon} {item.name} dibeli. Terima kasih, Kak!`)
end

local function sellFish(player: Player, camp: CampView, fishId: any, form: any): Result
	if not ensureVendor(player) then
		return result(false, "Dekati Kak Sari dulu untuk menjual ikan.")
	end
	local total, count = 0, 0
	for _, fish in Config.FISH do
		if fishId == "all" or fishId == fish.id then
			if form == "raw" or form == "all" then
				local n = camp.fish[fish.id] or 0
				total += n * fish.price
				count += n
				camp.fish[fish.id] = nil
			end
			if form == "grilled" or form == "all" then
				local n = camp.grilled[fish.id] or 0
				total += n * Config.grilledPrice(fish, nil)
				count += n
				camp.grilled[fish.id] = nil
			end
		end
	end
	if count == 0 or total <= 0 then
		return result(false, "Tidak ada ikan untuk dijual.")
	end
	EconomyService.addMoney(player, total, "kemah:jual")
	publish(player, camp)
	say(vendor, pick(Config.THANKS), 4)
	return result(true, `Terjual {count} ikan: dapat {Format.money(total)}!`)
end

local function finishGrill(player: Player, fishId: string, count: number, _kind: string)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local camp = getCamp(data)
	addTo(camp.grilled, fishId, count)
	publish(player, camp)
	EconomyService.notify(player, "🔥 Ikan bakar sudah matang! Jual ke Kak Sari atau makan.")
end

local function grillFish(player: Player, camp: CampView, fishId: any): Result
	local fish = Config.fish(fishId)
	if fish == nil then
		return result(false, "Ikan tidak dikenal.")
	end
	local fire = nearTagged(player, Config.TAG_FIRE, Config.TALK_DISTANCE, nil)
	if fire == nil then
		return result(false, "Dekati api unggun atau panggangan dulu.")
	end
	if (busyUntil[player] or 0) > os.clock() then
		return result(false, "Tunggu ikan sebelumnya matang dulu ya.")
	end
	local kind = tostring(fire:GetAttribute("Kind"))
	local capacity = Config.GRILL_CAPACITY[kind] or 2
	local have = camp.fish[fish.id] or 0
	if have < 1 then
		return result(false, "Kamu tidak punya " .. fish.name .. ".")
	end
	local count = math.min(have, capacity)
	addTo(camp.fish, fish.id, -count)
	publish(player, camp)
	busyUntil[player] = os.clock() + Config.GRILL_SECONDS
	local smoke = fire:FindFirstChild("Asap")
	if smoke and smoke:IsA("ParticleEmitter") then
		smoke.Enabled = true
		task.delay(Config.GRILL_SECONDS, function()
			smoke.Enabled = kind == "panggangan"
		end)
	end
	task.delay(Config.GRILL_SECONDS, function()
		finishGrill(player, fish.id, count, kind)
	end)
	return result(true, `🔥 Membakar {count} {fish.name}... ({Config.GRILL_SECONDS} detik)`)
end

local function cookNoodle(player: Player, camp: CampView): Result
	local fire = nearTagged(player, Config.TAG_FIRE, Config.TALK_DISTANCE, "unggun")
	if fire == nil then
		return result(false, "Dekati api unggun untuk memasak mie.")
	end
	if camp.mie < 1 then
		return result(false, "Kamu tidak punya Mie Cup. Beli di Warung Kemah.")
	end
	if (busyUntil[player] or 0) > os.clock() then
		return result(false, "Tunggu masakan sebelumnya selesai dulu ya.")
	end
	camp.mie -= 1
	publish(player, camp)
	busyUntil[player] = os.clock() + Config.GRILL_SECONDS
	task.delay(Config.GRILL_SECONDS, function()
		local data = DataService.getData(player)
		if data then
			local c = getCamp(data)
			c.mieMasak = math.min(c.mieMasak + 1, Config.STACK_MAX)
			publish(player, c)
			EconomyService.notify(player, "🍜 Mie rebus matang! Ayo dimakan, Kak.")
		end
	end)
	return result(true, `🍜 Memasak mie... ({Config.GRILL_SECONDS} detik)`)
end

local function eat(player: Player, camp: CampView, what: any): Result
	if what == "mie" then
		if camp.mieMasak < 1 then
			return result(false, "Tidak ada mie rebus.")
		end
		camp.mieMasak -= 1
	elseif type(what) == "string" and Config.fish(what) and (camp.grilled[what] or 0) > 0 then
		addTo(camp.grilled, what, -1)
	else
		return result(false, "Tidak ada makanan itu.")
	end
	publish(player, camp)
	pcall(function()
		Net.event("ConsumeAnim"):FireClient(player, "eat", 3)
	end)
	pcall(function()
		FoodService.giveBuff(player, Config.EAT_BUFF_SECONDS)
	end)
	return result(
		true,
		`Nyam, enak sekali! Kenyang semangat {Config.EAT_BUFF_SECONDS} detik: lari lebih cepat.`
	)
end

-- ---------------------------------------------------------------- tenda

local function removeTent(owner: Player)
	for i = #tents, 1, -1 do
		if tents[i].owner == owner then
			tents[i].model:Destroy()
			table.remove(tents, i)
		end
	end
end

local function placeTent(player: Player, camp: CampView): Result
	if not camp.tent then
		return result(false, "Beli Tenda Kemah dulu di Warung Kemah.")
	end
	local center = campCenter()
	local root = rootOf(player)
	local assets = ServerStorage:FindFirstChild("AsetKemah")
	local template = if assets then assets:FindFirstChild("TendaStilasi") else nil
	if center == nil or root == nil or template == nil then
		return result(false, "Tidak bisa memasang tenda sekarang.")
	end
	if (root.Position - center).Magnitude > Config.PLACE_RADIUS then
		return result(false, "Pasang tendamu di dekat perkemahan ya.")
	end
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local target = root.Position + flat.Unit * 13
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { tentsFolder, npcFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	if hit == nil or hit.Material == Enum.Material.Water then
		return result(false, "Tempat itu tidak cocok untuk tenda.")
	end
	removeTent(player)
	while #tents >= Config.MAX_TENTS do
		tents[1].model:Destroy()
		table.remove(tents, 1)
	end
	local tent = (template :: Model):Clone()
	for _, d in tent:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local yaw = CFrame.lookAt(Vector3.zero, -flat.Unit)
	tent:PivotTo(CFrame.new(hit.Position + Vector3.new(0, 6, 0)) * yaw.Rotation)
	local box, size = tent:GetBoundingBox()
	tent:PivotTo(
		tent:GetPivot() + Vector3.new(0, hit.Position.Y - (box.Position.Y - size.Y / 2) - 0.05, 0)
	)
	tent.Name = "Tenda_" .. player.Name
	tent:SetAttribute("OwnerId", player.UserId)
	tent.Parent = tentsFolder
	table.insert(tents, { owner = player, model = tent })
	return result(true, "⛺ Tendamu terpasang! Selamat berkemah, Kak.")
end

local function packTent(player: Player): Result
	for _, entry in tents do
		if entry.owner == player then
			removeTent(player)
			return result(true, "Tenda dibongkar. Bisa dipasang lagi kapan saja.")
		end
	end
	return result(false, "Tendamu belum dipasang.")
end

-- ---------------------------------------------------------------- nyanyi

local singCooldown: { [Player]: number } = {}

local function sing(player: Player): Result
	local spot = guitarist
	local root = rootOf(player)
	if spot == nil or root == nil or (root.Position - spot.root.Position).Magnitude > 22 then
		return result(false, "Dekati Kak Bagas dulu untuk ikut nyanyi.")
	end
	local now = os.clock()
	if singCooldown[player] and now - singCooldown[player] < 6 then
		return result(false, "Tarik napas dulu, Kak 😄")
	end
	singCooldown[player] = now
	local head = player.Character and player.Character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local old = head:FindFirstChild("Nyanyi")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Nyanyi"
		gui.Adornee = head
		gui.Size = UDim2.fromOffset(300, 50)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = 48
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = rgb(255, 245, 200)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = rgb(70, 50, 30)
		label.Text = pick(Config.SONG)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = label
		label.Parent = gui
		gui.Parent = head
		task.delay(5, function()
			gui:Destroy()
		end)
	end
	spot.say(pick(Config.SING_REPLIES), 4)
	return result(true, "🎶 Kamu ikut bernyanyi bersama Kak Bagas!")
end

-- ---------------------------------------------------------------- remote

local function handle(player: Player, action: any, a: any, b: any): Result
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < Config.CALL_COOLDOWN then
		return result(false, "Pelan-pelan ya, Kak.")
	end
	lastCall[player] = now
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local camp = getCamp(data)
	if action == "buy" then
		return buyItem(player, camp, a)
	elseif action == "sell" then
		return sellFish(player, camp, a, b)
	elseif action == "grill" then
		return grillFish(player, camp, a)
	elseif action == "cook" then
		return cookNoodle(player, camp)
	elseif action == "eat" then
		return eat(player, camp, a)
	elseif action == "cast" then
		return castLine(player, data)
	elseif action == "reel" then
		return reelIn(player, data)
	elseif action == "place" then
		return placeTent(player, camp)
	elseif action == "pack" then
		return packTent(player)
	elseif action == "sing" then
		return sing(player)
	end
	return result(false, "Aksi tidak dikenal.")
end

-- ---------------------------------------------------------------- prompt

local function addPrompt(
	part: BasePart,
	name: string,
	action: string,
	object: string,
	onTrigger: (Player) -> ()
)
	if part:FindFirstChild(name) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTrigger)
	prompt.Parent = part
end

local function register(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if CollectionService:HasTag(inst, Config.TAG_VENDOR) then
		addPrompt(inst, "PromptKemah", "Belanja & jual ikan", "Warung Kemah", function(player)
			openRemote:FireClient(player, "shop", "Warung Kemah")
		end)
	end
	if CollectionService:HasTag(inst, Config.TAG_FIRE) then
		local kind = tostring(inst:GetAttribute("Kind"))
		addPrompt(
			inst,
			"PromptKemah",
			if kind == "panggangan" then "Panggang" else "Bakar & masak",
			if kind == "panggangan" then "Panggangan" else "Api Unggun",
			function(player)
				openRemote:FireClient(
					player,
					"fire",
					if kind == "panggangan" then "Panggangan" else "Api Unggun",
					kind
				)
			end
		)
	end
	if CollectionService:HasTag(inst, Config.TAG_SPOT) then
		addPrompt(inst, "PromptKemah", "Memancing", "Dermaga", function(player)
			local data = DataService.getData(player)
			if data == nil then
				return
			end
			local res = if sessions[player] then reelIn(player, data) else castLine(player, data)
			EconomyService.notify(player, res.message)
		end)
	end
end

local function watchGuitarPrompt()
	while true do
		task.wait(2)
		local person = guitarist
		if person then
			local upper = person.model:FindFirstChild("UpperTorso")
			if upper and upper:IsA("BasePart") then
				addPrompt(upper, "PromptNyanyi", "Ikut Nyanyi", "Kak Bagas", function(player)
					local res = sing(player)
					EconomyService.notify(player, res.message)
				end)
			end
		end
	end
end

-- ---------------------------------------------------------------- bootstrap

function CampService.init()
	fishRemote = Net.event("CampFish")
	openRemote = Net.event("CampOpen")
	local actionRemote = Net.func("CampAction")
	actionRemote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
		local ok, res = pcall(handle, player, action, a, b)
		if ok then
			return res
		end
		warn("[Kemah] " .. tostring(res))
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
	for _, name in { "NpcKemah", "TendaPemain" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NpcKemah"
	npcFolder.Parent = Workspace
	tentsFolder = Instance.new("Folder")
	tentsFolder.Name = "TendaPemain"
	tentsFolder.Parent = Workspace
end

function CampService.start()
	for _, tag in { Config.TAG_VENDOR, Config.TAG_FIRE, Config.TAG_SPOT } do
		for _, inst in CollectionService:GetTagged(tag) do
			register(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(register)
	end
	DataService.ProfileLoaded:Connect(function(player: Player, data: Types.PlayerData)
		publish(player, getCamp(data))
	end)
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data then
			publish(player, getCamp(data))
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		cleanSession(player, nil)
		removeTent(player)
		lastCall[player], lastCast[player], busyUntil[player], singCooldown[player] =
			nil, nil, nil, nil
	end)
	task.spawn(greetLoop)
	task.spawn(watchGuitarPrompt)
	task.spawn(function()
		while true do
			local ok, err = pcall(manage)
			if not ok then
				warn("[Kemah] " .. tostring(err))
			end
			task.wait(3)
		end
	end)
end

return CampService
