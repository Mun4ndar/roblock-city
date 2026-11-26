--!strict
--[[
	MasjidService: Masjid Al Munawaroh yang hidup.
	  * NPC: Ustadz Hamid (imam), Pak Rizky (muazin), Pak Jaka (marbot, menyapu dan menyapa pemain),
	    dan 10 jamaah berpeci / bersarung / bermukena. Dibuat saat ada pemain dalam SPAWN_RADIUS, dihapus saat jauh.
	  * Acara per waktu sholat (jadwal MasjidConfig.PRAYERS mengikuti jam dunia): adzan (teks) -> iqamah ->
	    sholat berjamaah -> tausiah ~1 menit (isi beda tiap waktu sholat, ada balasan jamaah) -> selesai.
	  * Pemain boleh ikut sholat (E di sajadah saat adzan/iqamah) dan duduk mendengarkan tausiah (E di bantal).
	  * Server hanya mengatur posisi, teks, dan atribut. Gerakan tubuh (pose) dipentaskan MasjidController di client
	    lewat SholatPose, berdasarkan atribut Workspace.Masjid* dan tag "SholatPose".
	  * Tidak ada audio. Adzan ditampilkan sebagai teks (latin + arti).
	Alat uji (hanya Studio): ServerStorage.MasjidDebug:Invoke("mulai", "dzuhur"), Invoke("status").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("MasjidConfig"))
local TimeService = require(script.Parent:WaitForChild("TimeService"))

local MasjidService = {}

local rgb = Color3.fromRGB
local FLOOR_Y = Config.FLOOR_Y
local QIBLA = Config.QIBLA
local FACE_QIBLA = QIBLA
local FACE_JAMAAH = -QIBLA

local TAG_POSE = "SholatPose"
local ANIM_IDLE = "rbxassetid://507766388"
local ANIM_WALK = "rbxassetid://507777826"
local ANIM_WAVE = "rbxassetid://507770239"

-- ---------------------------------------------------------------- daftar NPC
type Spec = {
	id: string,
	name: string,
	role: string, -- Imam | Muazin | Marbot | Jamaah
	label: string,
	spot: Vector2,
	skin: Color3,
	shirt: Color3,
	legs: Color3,
	cap: string, -- peci | pecihaji | hijab | none
	capColor: Color3?,
	scale: number?,
	female: boolean?,
}

local SKIN_A = rgb(224, 172, 120)
local SKIN_B = rgb(198, 140, 95)
local SKIN_C = rgb(166, 114, 78)
local SKIN_D = rgb(238, 192, 152)
local WHITE = rgb(246, 246, 242)
local CREAM = rgb(240, 228, 200)
local SKY = rgb(190, 214, 240)
local MINT = rgb(200, 232, 208)
local BLACK_CAP = rgb(34, 30, 30)
local MUKENA = rgb(246, 244, 250)

local ROSTER: { Spec } = {
	{
		id = "Imam",
		name = "Ustadz Hamid",
		role = "Imam",
		label = "Imam",
		spot = Config.IMAM_SPOT,
		skin = SKIN_B,
		shirt = WHITE,
		legs = WHITE,
		cap = "pecihaji",
	},
	{
		id = "Muazin",
		name = "Pak Rizky",
		role = "Muazin",
		label = "Muazin",
		spot = Vector2.new(494, -30),
		skin = SKIN_A,
		shirt = MINT,
		legs = rgb(40, 60, 110),
		cap = "peci",
	},
	{
		id = "PakBudi",
		name = "Pak Budi",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(494, -25),
		skin = SKIN_C,
		shirt = WHITE,
		legs = rgb(130, 45, 55),
		cap = "peci",
	},
	{
		id = "PakHaji",
		name = "Pak Haji Ali",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(494, -20),
		skin = SKIN_D,
		shirt = CREAM,
		legs = rgb(40, 110, 80),
		cap = "pecihaji",
	},
	{
		id = "PakJoko",
		name = "Pak Joko",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(494, -15),
		skin = SKIN_B,
		shirt = SKY,
		legs = rgb(120, 85, 55),
		cap = "peci",
	},
	{
		id = "Dimas",
		name = "Dimas",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(494, -10),
		skin = SKIN_A,
		shirt = WHITE,
		legs = rgb(40, 60, 110),
		cap = "peci",
		scale = 0.78,
	},
	{
		id = "PakRudi",
		name = "Pak Rudi",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(500, -27),
		skin = SKIN_A,
		shirt = MINT,
		legs = rgb(70, 90, 120),
		cap = "peci",
	},
	{
		id = "PakDedi",
		name = "Pak Dedi",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(500, -21),
		skin = SKIN_C,
		shirt = CREAM,
		legs = rgb(130, 45, 55),
		cap = "peci",
	},
	{
		id = "PakAndi",
		name = "Pak Andi",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(500, -15),
		skin = SKIN_D,
		shirt = WHITE,
		legs = rgb(40, 110, 80),
		cap = "peci",
	},
	{
		id = "BuSiti",
		name = "Bu Siti",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(522, -26),
		skin = SKIN_D,
		shirt = MUKENA,
		legs = MUKENA,
		cap = "hijab",
		capColor = MUKENA,
		female = true,
	},
	{
		id = "BuAisyah",
		name = "Bu Aisyah",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(522, -20),
		skin = SKIN_B,
		shirt = rgb(238, 226, 246),
		legs = rgb(238, 226, 246),
		cap = "hijab",
		capColor = rgb(238, 226, 246),
		female = true,
	},
	{
		id = "KakNurul",
		name = "Kak Nurul",
		role = "Jamaah",
		label = "Jamaah",
		spot = Vector2.new(522, -14),
		skin = SKIN_A,
		shirt = rgb(250, 228, 236),
		legs = rgb(250, 228, 236),
		cap = "hijab",
		capColor = rgb(250, 228, 236),
		female = true,
		scale = 0.86,
	},
	{
		id = "Marbot",
		name = "Pak Jaka",
		role = "Marbot",
		label = "Marbot",
		spot = Config.SWEEP_SPOTS[1],
		skin = SKIN_C,
		shirt = rgb(196, 176, 124),
		legs = rgb(120, 85, 55),
		cap = "peci",
	},
}

-- ---------------------------------------------------------------- keadaan
type Npc = {
	spec: Spec,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	say: (string, number) -> (),
	animator: Animator?,
	walk: AnimationTrack?,
	wave: AnimationTrack?,
	idle: AnimationTrack?,
	lastGreet: number,
	slotCFrame: CFrame?,
}

local folder: Folder
local npcs: { [string]: Npc } = {}
local npcActive = false
local generation = 0

local phase = "Idle"
local running = false
local pending: string? = nil -- id sholat yang diminta (uji Studio)
local doneKey: { [string]: number } = {}
local dayIndex = 0
local lastClock = 0

type Slot = { part: BasePart, prompt: ProximityPrompt, owner: Player? }
local slots: { Slot } = {}
local seats: { { part: Seat, prompt: ProximityPrompt } } = {}
local joined: {
	[Player]: {
		slot: number,
		speed: number,
		jumpPower: number,
		jumpHeight: number,
		useJumpPower: boolean,
	},
} =
	{}

-- ---------------------------------------------------------------- tampilan NPC
local function decorate(
	model: Model,
	on: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	shape: Enum.PartType?,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = on.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = on
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- silinder berdiri tegak

local function addOutfit(model: Model, spec: Spec, s: number)
	local head = model:FindFirstChild("Head") :: BasePart
	local lower = model:FindFirstChild("LowerTorso") :: BasePart
	local upper = model:FindFirstChild("UpperTorso") :: BasePart
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * s
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	if spec.cap == "peci" or spec.cap == "pecihaji" then
		local color = if spec.cap == "pecihaji" then rgb(250, 250, 250) else BLACK_CAP
		decorate(
			model,
			head,
			"Peci",
			v(0.5, 1.3, 1.3),
			color,
			at(0, 0.6, 0) * VERTICAL,
			Enum.PartType.Cylinder
		)
		if spec.cap == "peci" then
			decorate(
				model,
				head,
				"PeciPita",
				v(0.12, 1.34, 1.34),
				rgb(200, 170, 80),
				at(0, 0.4, 0) * VERTICAL,
				Enum.PartType.Cylinder
			)
		end
	elseif spec.cap == "hijab" then
		local color = spec.capColor or MUKENA
		decorate(
			model,
			head,
			"Hijab",
			v(1.55, 1.55, 1.5),
			color,
			at(0, 0.08, 0.28),
			Enum.PartType.Ball,
			Enum.Material.Fabric
		)
		decorate(
			model,
			upper,
			"Mukena",
			v(2.3, 1.7, 1.3),
			color,
			at(0, 0.28, 0.1),
			nil,
			Enum.Material.Fabric
		)
		decorate(
			model,
			upper,
			"MukenaBelakang",
			v(2.1, 2.7, 0.35),
			color,
			at(0, -0.1, 0.55),
			nil,
			Enum.Material.Fabric
		)
	end
	if spec.role ~= "Jamaah" or not spec.female then
		if spec.legs ~= WHITE and spec.role ~= "Imam" then
			-- ikat pinggang sarung
			decorate(
				model,
				lower,
				"IkatSarung",
				v(2.12, 0.34, 1.14),
				rgb(46, 34, 30),
				at(0, 0.05, 0)
			)
		end
	end
	if spec.role == "Imam" then
		-- selendang hijau tua di bahu
		decorate(model, upper, "Selendang", v(2.2, 0.35, 1.2), rgb(36, 96, 70), at(0, 0.7, 0))
	end
	if spec.role == "Marbot" then
		local hand = model:FindFirstChild("RightHand") :: BasePart
		decorate(
			model,
			hand,
			"GagangSapu",
			v(0.22, 4.2, 0.22),
			rgb(150, 110, 70),
			at(0, -0.6, -0.35) * CFrame.Angles(math.rad(-24), 0, 0),
			nil,
			Enum.Material.Wood
		)
		local handle = model:FindFirstChild("GagangSapu") :: BasePart
		decorate(
			model,
			handle,
			"BuluSapu",
			v(1.3, 0.5, 0.55),
			rgb(226, 190, 90),
			CFrame.new(0, -2.05 * s, 0) * CFrame.Angles(math.rad(24), 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end
end

local function buildLabels(
	head: BasePart,
	name: string,
	label: string,
	s: number
): (string, number) -> ()
	local tag = Instance.new("BillboardGui")
	tag.Name = "NamaNpc"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(110, 14)
	tag.StudsOffset = Vector3.new(0, 1.7 * s + 0.4, 0)
	tag.MaxDistance = 9
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rgb(255, 255, 255)
	text.TextStrokeTransparency = 0.3
	text.Text = name .. " · " .. label
	text.Parent = tag
	tag.Parent = head

	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanNpc"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(210, 46)
	gui.StudsOffset = Vector3.new(0, 2.9 * s + 0.6, 0)
	gui.MaxDistance = 34
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = rgb(255, 255, 255)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.new(1, -16, 1, -8)
	bubble.Position = UDim2.fromOffset(8, 4)
	bubble.BackgroundTransparency = 1
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextScaled = true
	bubble.TextColor3 = rgb(40, 60, 80)
	bubble.Parent = frame
	frame.Parent = gui
	gui.Parent = head
	local token = 0
	return function(line: string, seconds: number)
		token += 1
		local mine = token
		bubble.Text = line
		gui.Enabled = true
		task.delay(seconds, function()
			if token == mine then
				gui.Enabled = false
			end
		end)
	end
end

local function loadTrack(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

local function faceCFrame(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir)
end

local function standY(npc: Npc): number
	return FLOOR_Y + npc.humanoid.HipHeight + npc.root.Size.Y / 2
end

local function spotCFrame(npc: Npc, spot: Vector2, dir: Vector3): CFrame
	return faceCFrame(Vector3.new(spot.X, standY(npc), spot.Y), dir)
end

local function buildNpc(spec: Spec, startSpot: Vector2?, startDir: Vector3?): Npc?
	local s = spec.scale or 1
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = spec.skin
	description.LeftArmColor = spec.skin
	description.RightArmColor = spec.skin
	description.TorsoColor = spec.shirt
	description.LeftLegColor = spec.legs
	description.RightLegColor = spec.legs
	if s ~= 1 then
		description.HeightScale = s
		description.WidthScale = s
		description.DepthScale = s
		description.HeadScale = s
		description.BodyTypeScale = 0
		description.ProportionScale = 0
	end
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Masjid] gagal membuat NPC " .. spec.name .. ": " .. tostring(model))
		return nil
	end
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
	model.Name = spec.id
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	-- warna: baju koko lengan panjang (lengan bawah ikut warna baju), sarung/gamis di kaki, kaki dan tangan kulit
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local n = part.Name
			if n:match("Foot$") or n:match("Hand$") then
				part.Color = spec.skin
			elseif n:match("UpperArm$") or n:match("LowerArm$") or n == "UpperTorso" then
				part.Color = spec.shirt
			elseif n == "LowerTorso" or n:match("UpperLeg$") or n:match("LowerLeg$") then
				part.Color = spec.legs
			elseif n ~= "HumanoidRootPart" then
				part.Color = spec.skin
			end
		end
	end
	addOutfit(model, spec, s)

	model:SetAttribute("Peran", spec.role)
	model:SetAttribute("NpcId", spec.id)
	model:SetAttribute("TanpaGerak", true)
	local say = buildLabels(head, spec.name, spec.label, s)

	local npc: Npc = {
		spec = spec,
		model = model,
		root = root,
		humanoid = humanoid,
		say = say,
		animator = nil,
		walk = nil,
		wave = nil,
		idle = nil,
		lastGreet = 0,
		slotCFrame = nil,
	}
	local cf = spotCFrame(npc, startSpot or spec.spot, startDir or FACE_QIBLA)
	model:PivotTo(cf)
	if spec.role == "Marbot" then
		humanoid.WalkSpeed = 6
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		CollectionService:AddTag(model, TAG_POSE) -- client memakai pose menyapu / sholat saat atribut Menyapu / Ikut aktif
	else
		root.Anchored = true
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = part.Name == "HumanoidRootPart"
				part.CanTouch = false
			end
		end
		CollectionService:AddTag(model, TAG_POSE)
	end
	model.Parent = folder
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	npc.animator = animator
	npc.walk = loadTrack(animator, ANIM_WALK, Enum.AnimationPriority.Movement, true)
	if spec.role == "Marbot" then
		npc.idle = loadTrack(animator, ANIM_IDLE, Enum.AnimationPriority.Idle, true)
		npc.wave = loadTrack(animator, ANIM_WAVE, Enum.AnimationPriority.Action2, false)
	end
	return npc
end

-- ---------------------------------------------------------------- pemain terdekat
local function nearestPlayerDistance(position: Vector3): (BasePart?, number)
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") then
			local distance = (hrp.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = hrp, distance
			end
		end
	end
	return best, bestDistance
end

-- ---------------------------------------------------------------- acara: bantu
local function setAttr(name: string, value: any)
	Workspace:SetAttribute("Masjid" .. name, value)
end

local function setPhase(name: string)
	phase = name
	setAttr("Fase", name)
	setAttr("MulaiFase", Workspace:GetServerTimeNow())
	local joinOpen = name == "Azan" or name == "Iqamah"
	for _, slot in slots do
		slot.prompt.Enabled = joinOpen and slot.owner == nil
	end
	local seatOpen = name == "Tausiah" or name == "Selesai"
	for _, seat in seats do
		seat.prompt.Enabled = seatOpen
	end
end

local function setText(title: string, text: string, meaning: string)
	setAttr("Judul", title)
	setAttr("Teks", text)
	setAttr("Arti", meaning)
end

local function npcSay(id: string, text: string, seconds: number)
	local npc = npcs[id]
	if npc then
		npc.say(text, seconds)
	end
end

local function placeNpc(id: string, spot: Vector2, dir: Vector3)
	local npc = npcs[id]
	if npc then
		npc.model:PivotTo(spotCFrame(npc, spot, dir))
	end
end

local function pause(seconds: number)
	task.wait(seconds)
end

local function playersNearMasjid(radius: number): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") and (hrp.Position - Config.CENTER).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

-- ---------------------------------------------------------------- pemain ikut sholat / duduk
local function releasePlayer(player: Player)
	local state = joined[player]
	if state == nil then
		return
	end
	joined[player] = nil
	local slot = slots[state.slot]
	if slot and slot.owner == player then
		slot.owner = nil
		slot.prompt.Enabled = phase == "Azan" or phase == "Iqamah"
	end
	player:SetAttribute("MasjidSlot", nil)
	local character = player.Character
	if character then
		CollectionService:RemoveTag(character, TAG_POSE)
		character:SetAttribute("Sholat", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = state.speed
			humanoid.UseJumpPower = state.useJumpPower
			humanoid.JumpPower = state.jumpPower
			humanoid.JumpHeight = state.jumpHeight
		end
	end
end

local function joinPrayer(player: Player, index: number, anyDistance: boolean?)
	if phase ~= "Azan" and phase ~= "Iqamah" then
		return
	end
	local slot = slots[index]
	if slot == nil or slot.owner ~= nil or joined[player] ~= nil then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if
		character == nil
		or humanoid == nil
		or root == nil
		or not root:IsA("BasePart")
		or humanoid.Health <= 0
	then
		return
	end
	if not anyDistance and (root.Position - slot.part.Position).Magnitude > 16 then
		return
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	joined[player] = {
		slot = index,
		speed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		useJumpPower = humanoid.UseJumpPower,
	}
	slot.owner = player
	slot.prompt.Enabled = false
	local target = Vector3.new(
		slot.part.Position.X,
		FLOOR_Y + humanoid.HipHeight + root.Size.Y / 2,
		slot.part.Position.Z
	)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = faceCFrame(target, FACE_QIBLA)
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	player:SetAttribute("MasjidSlot", index)
	character:SetAttribute("Sholat", true)
	CollectionService:AddTag(character, TAG_POSE)
end

local function sitPlayer(player: Player, seat: Seat, anyDistance: boolean?)
	if phase ~= "Tausiah" and phase ~= "Selesai" then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	if
		seat.Occupant ~= nil or (not anyDistance and (root.Position - seat.Position).Magnitude > 16)
	then
		return
	end
	releasePlayer(player)
	seat:Sit(humanoid)
end

local PAD_COLORS = {
	rgb(38, 110, 84),
	rgb(40, 76, 130),
	rgb(130, 44, 58),
	rgb(90, 66, 120),
	rgb(150, 110, 50),
	rgb(30, 100, 110),
}

local function buildFurniture()
	-- penanda area duduk tausiah
	local anchor = Instance.new("Part")
	anchor.Name = "PenandaTausiah"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = Vector3.new(533, FLOOR_Y + 4.5, -21.5)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(110, 16)
	sign.MaxDistance = 14
	sign.AlwaysOnTop = false
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundColor3 = Color3.fromRGB(20, 70, 56)
	signText.BackgroundTransparency = 0.15
	signText.Font = Enum.Font.FredokaOne
	signText.TextScaled = true
	signText.TextColor3 = Color3.fromRGB(246, 224, 140)
	signText.Text = "Area duduk tausiah"
	local signCorner = Instance.new("UICorner")
	signCorner.CornerRadius = UDim.new(0, 8)
	signCorner.Parent = signText
	signText.Parent = sign
	sign.Parent = anchor
	anchor.Parent = folder
	-- sajadah di bawah tiap NPC (imam, muazin, jamaah, marbot)
	local function npcMat(x: number, z: number, index: number)
		local mat = Instance.new("Part")
		mat.Name = "SajadahNpc"
		mat.Anchored = true
		mat.CanCollide = false
		mat.CanQuery = false
		mat.Size = Vector3.new(4.2, 0.12, 2.2)
		mat.Material = Enum.Material.Fabric
		mat.Color = PAD_COLORS[(index - 1) % #PAD_COLORS + 1]
		mat.CFrame = CFrame.new(x, FLOOR_Y + 0.07, z)
		mat.Parent = folder
	end
	for index, spec in ROSTER do
		if spec.role ~= "Marbot" then
			npcMat(spec.spot.X, spec.spot.Y, index)
		end
	end
	npcMat(Config.MARBOT_SLOT.X, Config.MARBOT_SLOT.Y, 3)
	for index, spot in Config.PLAYER_SLOTS do
		local part = Instance.new("Part")
		part.Name = "Sajadah" .. index
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(4.2, 0.12, 2.2)
		part.Material = Enum.Material.Fabric
		part.Color = PAD_COLORS[(index - 1) % #PAD_COLORS + 1]
		part.CFrame = CFrame.new(spot.X, FLOOR_Y + 0.07, spot.Y)
		local edge = Instance.new("Part")
		edge.Name = "SajadahTepi"
		edge.Anchored = true
		edge.CanCollide = false
		edge.CanQuery = false
		edge.Size = Vector3.new(0.35, 0.14, 2.2)
		edge.Material = Enum.Material.Fabric
		edge.Color = rgb(236, 208, 120)
		edge.CFrame = part.CFrame * CFrame.new(-1.85, 0, 0)
		edge.Parent = part
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = edge
		weld.Parent = edge
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "IkutSholat"
		prompt.ActionText = "Ikut sholat berjamaah"
		prompt.ObjectText = "Sajadah"
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = part
		part.Parent = folder
		local slot: Slot = { part = part, prompt = prompt, owner = nil }
		table.insert(slots, slot)
		prompt.Triggered:Connect(function(player: Player)
			joinPrayer(player, index)
		end)
	end
	for index, spot in Config.SEATS do
		local seat = Instance.new("Seat")
		seat.Name = "BantalTausiah" .. index
		seat.Anchored = true
		seat.Shape = Enum.PartType.Cylinder
		seat.Size = Vector3.new(0.6, 3.2, 3.2)
		seat.Material = Enum.Material.Fabric
		seat.Color = rgb(34, 120, 90)
		seat.Disabled = true
		seat.CFrame = faceCFrame(Vector3.new(spot.X, FLOOR_Y + 0.3, spot.Y), FACE_QIBLA) * VERTICAL
		local ring = Instance.new("Part")
		ring.Name = "BantalTepi"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, 3.5, 3.5)
		ring.Material = Enum.Material.Fabric
		ring.Color = rgb(236, 208, 120)
		ring.CFrame = seat.CFrame * CFrame.new(-0.28, 0, 0)
		ring.Parent = seat
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = seat
		weld.Part1 = ring
		weld.Parent = ring
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DudukTausiah"
		prompt.ActionText = "Duduk mendengarkan tausiah"
		prompt.ObjectText = "Bantal Duduk"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = seat
		seat.Parent = folder
		table.insert(seats, { part = seat, prompt = prompt })
		prompt.Triggered:Connect(function(player: Player)
			sitPlayer(player, seat)
		end)
	end
end

-- ---------------------------------------------------------------- marbot
local function setBroom(npc: Npc, visible: boolean)
	for _, name in { "GagangSapu", "BuluSapu" } do
		local part = npc.model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
		end
	end
end

local function stopMarbotTracks(npc: Npc)
	if npc.walk then
		npc.walk:Stop(0.1)
	end
	if npc.idle then
		npc.idle:Stop(0.1)
	end
end

local marbotBusy = false -- true selama acara: marbot ikut sholat dan tidak menyapu

local function walkTo(npc: Npc, spot: Vector2, mine: number): boolean
	local humanoid = npc.humanoid
	local target = Vector3.new(spot.X, FLOOR_Y, spot.Y)
	npc.model:SetAttribute("Menyapu", false)
	if npc.idle then
		npc.idle:Stop(0.1)
	end
	if npc.walk and not npc.walk.IsPlaying then
		npc.walk:Play(0.2)
	end
	humanoid:MoveTo(target + Vector3.new(0, humanoid.HipHeight, 0))
	local started = os.clock()
	while generation == mine and not marbotBusy and npc.model.Parent do
		task.wait(0.2)
		local flat = Vector3.new(npc.root.Position.X - target.X, 0, npc.root.Position.Z - target.Z)
		if flat.Magnitude < 1.6 then
			break
		end
		if os.clock() - started > 22 then
			npc.model:PivotTo(
				faceCFrame(Vector3.new(target.X, standY(npc), target.Z), npc.root.CFrame.LookVector)
			)
			break
		end
	end
	if npc.walk then
		npc.walk:Stop(0.2)
	end
	return generation == mine and not marbotBusy
end

local function marbotLoop(mine: number)
	local npc = npcs.Marbot
	if npc == nil then
		return
	end
	local index = 1
	while generation == mine and npc.model.Parent do
		if marbotBusy then
			task.wait(0.5)
			continue
		end
		index = index % #Config.SWEEP_SPOTS + 1
		if not walkTo(npc, Config.SWEEP_SPOTS[index], mine) then
			continue
		end
		-- menyapu di tempat
		stopMarbotTracks(npc)
		npc.model:SetAttribute("Menyapu", true)
		local sweepUntil = os.clock() + math.random(6, 10)
		while generation == mine and not marbotBusy and os.clock() < sweepUntil do
			task.wait(0.4)
		end
		npc.model:SetAttribute("Menyapu", false)
	end
end

local function marbotGreet(npc: Npc, now: number)
	if marbotBusy or now - npc.lastGreet < 30 then
		return
	end
	local hrp, distance = nearestPlayerDistance(npc.root.Position)
	if hrp == nil or distance > 12 then
		return
	end
	npc.lastGreet = now
	local lines = {
		"Assalamu'alaikum, selamat datang di masjid, Kak! 😊",
		"Wa'alaikumussalam! Mari masuk, lepas alas kaki ya.",
		"Alhamdulillah, masjidnya bersih dan nyaman. 🧹",
	}
	npc.say(lines[math.random(1, #lines)], 5)
	if npc.wave then
		npc.model:SetAttribute("Menyapu", false)
		if npc.walk then
			npc.walk:Stop(0.1)
		end
		npc.wave:Play(0.2)
	end
end

-- ---------------------------------------------------------------- NPC muncul/hilang
local function despawnAll()
	generation += 1
	npcActive = false
	for _, npc in npcs do
		npc.model:Destroy()
	end
	table.clear(npcs)
	marbotBusy = false
end

local function applyPhaseToNpcs()
	-- Memindahkan NPC sesuai fase saat ini (dipakai saat NPC baru muncul di tengah acara).
	local imam = npcs.Imam
	local muazin = npcs.Muazin
	if imam then
		local dir = if phase == "Tausiah" then FACE_JAMAAH else FACE_QIBLA
		placeNpc("Imam", Config.IMAM_SPOT, dir)
	end
	if muazin then
		if phase == "Azan" then
			placeNpc("Muazin", Config.AZAN_SPOT, FACE_QIBLA)
		else
			placeNpc("Muazin", muazin.spec.spot, FACE_QIBLA)
		end
	end
end

local function spawnAll()
	if npcActive then
		return
	end
	npcActive = true
	generation += 1
	local mine = generation
	task.spawn(function()
		for _, spec in ROSTER do
			if generation ~= mine then
				return
			end
			local npc = if spec.role == "Marbot" or running then buildNpc(spec) else nil
			if npc then
				if generation ~= mine then
					npc.model:Destroy()
					return
				end
				npcs[spec.id] = npc
			end
			task.wait(0.05)
		end
		applyPhaseToNpcs()
		local marbot = npcs.Marbot
		if marbot then
			if phase == "Azan" or phase == "Iqamah" or phase == "Sholat" or phase == "Tausiah" then
				marbotBusy = true
				marbot.root.Anchored = true
				marbot.model:PivotTo(spotCFrame(marbot, Config.MARBOT_SLOT, FACE_QIBLA))
				marbot.model:SetAttribute("Ikut", true)
				setBroom(marbot, false)
			end
			task.spawn(marbotLoop, mine)
		end
	end)
end

-- ---------------------------------------------------------------- jam digital di dinding
local clockTimeLabel: TextLabel? = nil
local clockCells: { { frame: Frame, name: TextLabel, time: TextLabel, prayer: Config.Prayer } } = {}
local lastClockKey = ""

local function formatTime(hour: number): string
	local hours = math.floor(hour) % 24
	local minutes = math.floor((hour - math.floor(hour)) * 60)
	return string.format("%02d:%02d", hours, minutes)
end

local function clockLabel(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	color: Color3,
	font: Enum.Font
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

-- Papan jam di dinding mihrab (sisi barat), menghadap ke dalam ruang sholat. Opak, jadi tidak tembus dari luar.
local function buildClock()
	local hit = Workspace:Raycast(Vector3.new(500, 12, -38), Vector3.new(-40, 0, 0))
	local x = if hit then hit.Position.X + 0.25 else 484
	local board = Instance.new("Part")
	board.Name = "JamDigital"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.Material = Enum.Material.SmoothPlastic
	board.Color = rgb(12, 24, 20)
	board.Size = Vector3.new(14, 4.2, 0.4)
	local pos = Vector3.new(x, FLOOR_Y + 6.4, -38)
	board.CFrame = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(840, 252)
	gui.LightInfluence = 0
	gui.Parent = board
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(12, 24, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local gold = rgb(246, 224, 140)
	clockLabel(
		back,
		"WAKTU GAME",
		UDim2.fromOffset(20, 14),
		UDim2.fromOffset(270, 34),
		gold,
		Enum.Font.FredokaOne
	)
	clockTimeLabel = clockLabel(
		back,
		"--:--",
		UDim2.fromOffset(20, 54),
		UDim2.fromOffset(270, 120),
		rgb(120, 255, 190),
		Enum.Font.RobotoMono
	)
	clockLabel(
		back,
		"Masjid Al Munawaroh",
		UDim2.fromOffset(20, 186),
		UDim2.fromOffset(270, 40),
		rgb(200, 232, 214),
		Enum.Font.GothamMedium
	)
	for index, prayer in Config.PRAYERS do
		local cell = Instance.new("Frame")
		cell.Position = UDim2.fromOffset(310 + (index - 1) * 106, 20)
		cell.Size = UDim2.fromOffset(98, 212)
		cell.BackgroundColor3 = rgb(28, 64, 52)
		cell.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = cell
		local name = clockLabel(
			cell,
			prayer.name,
			UDim2.fromOffset(4, 22),
			UDim2.new(1, -8, 0, 62),
			gold,
			Enum.Font.FredokaOne
		)
		local time = clockLabel(
			cell,
			formatTime(prayer.time),
			UDim2.fromOffset(4, 110),
			UDim2.new(1, -8, 0, 60),
			rgb(255, 255, 255),
			Enum.Font.RobotoMono
		)
		cell.Parent = back
		table.insert(clockCells, { frame = cell, name = name, time = time, prayer = prayer })
	end
	board.Parent = folder
end

local function updateClock()
	local label = clockTimeLabel
	if label == nil then
		return
	end
	local clock = TimeService.getClock()
	local text = formatTime(clock)
	local current = Workspace:GetAttribute("MasjidSholat")
	local key = text .. "|" .. tostring(current)
	if key == lastClockKey then
		return
	end
	lastClockKey = key
	label.Text = text
	local target = Config.PRAYERS[1]
	for _, p in Config.PRAYERS do
		if p.time > clock then
			target = p
			break
		end
	end
	for _, cell in clockCells do
		local active = cell.prayer == target
		local now = type(current) == "string" and current == cell.prayer.name
		cell.frame.BackgroundColor3 = if now
			then rgb(90, 220, 150)
			elseif active then rgb(236, 190, 70)
			else rgb(28, 64, 52)
		local dark = now or active
		cell.name.TextColor3 = if dark then rgb(20, 40, 30) else rgb(246, 224, 140)
		cell.time.TextColor3 = if dark then rgb(20, 40, 30) else rgb(255, 255, 255)
	end
end

local function npcTick()
	local _, distance = nearestPlayerDistance(Config.CENTER)
	if distance < 250 then
		updateClock()
	end
	if not npcActive and distance < Config.SPAWN_RADIUS then
		spawnAll()
	elseif npcActive and distance > Config.DESPAWN_RADIUS then
		despawnAll()
		return
	end
	local marbot = npcs.Marbot
	if marbot then
		marbotGreet(marbot, os.clock())
	end
end

-- ---------------------------------------------------------------- jamaah datang dan pergi
local GATES = { -49, -39, -30, -20, -10, -1, 9 } -- tengah lengkung di sisi timur masjid

local function gateZ(z: number): number
	local best = GATES[1]
	for _, g in GATES do
		if math.abs(g - z) < math.abs(best - z) then
			best = g
		end
	end
	return best
end

local function walkPath(npc: Npc, points: { Vector3 }, finalDir: Vector3?, speed: number)
	local model = npc.model
	model:SetAttribute("Jalan", true)
	if npc.walk then
		npc.walk:Play(0.2)
	end
	local pos = Vector3.new(npc.root.Position.X, standY(npc), npc.root.Position.Z)
	for _, point in points do
		local target = Vector3.new(point.X, standY(npc), point.Z)
		while model.Parent do
			local delta = target - pos
			local dist = delta.Magnitude
			if dist < 0.2 then
				break
			end
			pos += delta.Unit * math.min(dist, speed * 0.1)
			model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(delta.X, 0, delta.Z)))
			task.wait(0.1)
		end
	end
	if not model.Parent then
		return
	end
	if npc.walk then
		npc.walk:Stop(0.2)
	end
	if finalDir then
		model:PivotTo(CFrame.lookAt(pos, pos + finalDir))
	end
	model:SetAttribute("Jalan", false)
end

-- Imam, muazin, dan jamaah masuk lewat lengkung timur saat adzan mulai.
local function summon()
	local mine = generation
	task.spawn(function()
		for _, spec in ROSTER do
			if generation ~= mine then
				return
			end
			if spec.role ~= "Marbot" and npcs[spec.id] == nil then
				local gz = gateZ(spec.spot.Y)
				local npc = buildNpc(spec, Vector2.new(558, gz), -Config.QIBLA * -1 * -1)
				if npc then
					npcs[spec.id] = npc
					local goal = if spec.id == "Muazin" then Config.AZAN_SPOT else spec.spot
					local delay = if spec.role == "Jamaah" then math.random(0, 120) / 10 else 0
					task.delay(delay, function()
						walkPath(
							npc,
							{ Vector3.new(541, 0, gz), Vector3.new(goal.X, 0, goal.Y) },
							FACE_QIBLA,
							8
						)
					end)
				end
				task.wait(0.05)
			end
		end
	end)
end

-- Setelah tausiah mereka keluar lewat lengkung timur lalu menghilang.
local function dismiss()
	for id, npc in npcs do
		if npc.spec.role ~= "Marbot" then
			task.spawn(function()
				task.wait(math.random(0, 40) / 10)
				local gz = gateZ(npc.root.Position.Z)
				walkPath(npc, { Vector3.new(541, 0, gz), Vector3.new(558, 0, gz) }, nil, 8)
				if npcs[id] == npc then
					npcs[id] = nil
				end
				npc.model:Destroy()
			end)
		end
	end
end

-- ---------------------------------------------------------------- acara sholat
local function marbotJoinPrayer()
	local npc = npcs.Marbot
	if npc == nil then
		return
	end
	marbotBusy = true
	npc.model:SetAttribute("Menyapu", false)
	stopMarbotTracks(npc)
	if npc.wave then
		npc.wave:Stop(0.1)
	end
	npc.root.Anchored = true
	npc.model:PivotTo(spotCFrame(npc, Config.MARBOT_SLOT, FACE_QIBLA))
	npc.model:SetAttribute("Ikut", true)
	setBroom(npc, false)
end

local function marbotLeavePrayer()
	local npc = npcs.Marbot
	if npc == nil then
		marbotBusy = false
		return
	end
	npc.model:SetAttribute("Ikut", false)
	setBroom(npc, true)
	npc.root.Anchored = false
	npc.model:PivotTo(spotCFrame(npc, Config.SWEEP_SPOTS[1], FACE_QIBLA))
	marbotBusy = false
	if npc.idle then
		npc.idle:Play(0.3)
	end
end

local function announce(prayer: Config.Prayer)
	local notify = Net.event(Net.Names.Notify)
	local message = "Waktu "
		.. prayer.name
		.. ". Adzan berkumandang di Masjid Al Munawaroh. Kamu boleh ikut sholat berjamaah di dalam masjid."
	for _, player in playersNearMasjid(240) do
		notify:FireClient(player, message)
	end
end

local tausiahBag: { number } = {}
local lastTausiah = 0

-- Ambil tausiah berikutnya dari kantong acak: semua topik keluar sekali dulu sebelum ada yang berulang.
local function nextTausiah(): Config.Tausiah
	local pool = Config.tausiahPool()
	if #tausiahBag == 0 then
		for index = 1, #pool do
			table.insert(tausiahBag, index)
		end
		for index = #tausiahBag, 2, -1 do
			local other = math.random(1, index)
			tausiahBag[index], tausiahBag[other] = tausiahBag[other], tausiahBag[index]
		end
		if #tausiahBag > 1 and tausiahBag[#tausiahBag] == lastTausiah then
			tausiahBag[#tausiahBag], tausiahBag[1] = tausiahBag[1], tausiahBag[#tausiahBag]
		end
	end
	lastTausiah = table.remove(tausiahBag) :: number
	return pool[lastTausiah]
end

local function runEvent(prayer: Config.Prayer)
	running = true
	setAttr("Sholat", prayer.name)
	setAttr("Rakaat", prayer.rakaat)
	setAttr("Langkah", "")
	announce(prayer)
	if npcActive then
		summon()
	end

	-- ADZAN
	setPhase("Azan")
	marbotJoinPrayer() -- marbot berhenti menyapu begitu adzan berkumandang dan ikut sholat
	for _, line in Config.azanLines(prayer) do
		setText("Adzan " .. prayer.name, line.text, line.meaning)
		npcSay("Muazin", line.text, line.seconds - 0.3)
		pause(line.seconds)
	end

	-- IQAMAH
	setPhase("Iqamah")
	placeNpc("Muazin", npcs.Muazin and npcs.Muazin.spec.spot or Config.AZAN_SPOT, FACE_QIBLA)
	local iqamah = Config.IQAMAH_LINE
	setText("Iqamah " .. prayer.name, iqamah.text, iqamah.meaning)
	npcSay("Muazin", iqamah.text, iqamah.seconds - 0.5)
	pause(iqamah.seconds)

	-- SHOLAT
	setPhase("Sholat")
	setAttr("MulaiSholat", Workspace:GetServerTimeNow())
	local sequence = Config.sholatSequence(prayer.rakaat)
	for _, step in sequence do
		setText(
			"Sholat " .. prayer.name .. " • Rakaat " .. step.rakaat .. " dari " .. prayer.rakaat,
			step.label,
			"Imam memimpin dan jamaah mengikuti. Kamu boleh ikut atau menonton dengan tenang."
		)
		setAttr("Langkah", step.label)
		if step.say then
			npcSay("Imam", step.say, math.min(step.seconds, 2.6))
		end
		pause(step.seconds)
	end
	for _, player in Players:GetPlayers() do
		releasePlayer(player)
	end

	-- TAUSIAH
	setPhase("Tausiah")
	placeNpc("Imam", Config.IMAM_SPOT, FACE_JAMAAH)
	local tausiah = nextTausiah()
	local lineSeconds = Config.tausiahLineSeconds(tausiah)
	if tausiah then
		for _, line in tausiah.lines do
			setText("Tausiah: " .. tausiah.title, line.text, "Ustadz Hamid")
			if line.replyBy and line.reply then
				local replyBy = line.replyBy
				local reply = line.reply
				task.delay(3.6, function()
					if replyBy == "Semua" then
						for id, npc in npcs do
							if npc.spec.role == "Jamaah" or id == "Muazin" then
								npc.say(reply, 3)
							end
						end
					else
						npcSay(replyBy, reply, 3.2)
					end
				end)
			end
			pause(lineSeconds)
		end
	end

	-- SELESAI
	setPhase("Selesai")
	setText("Selesai", Config.CLOSING_SAY, "Terima kasih sudah datang ke Masjid Al Munawaroh.")
	npcSay("Imam", Config.CLOSING_SAY, Config.CLOSING_SECONDS - 0.5)
	dismiss()
	pause(Config.CLOSING_SECONDS)
	marbotLeavePrayer()
	setPhase("Idle")
	setText("", "", "")
	setAttr("Sholat", "")
	running = false
end

-- Cari sholat yang sudah masuk waktunya dan belum dilaksanakan hari ini.
local function duePrayer(clock: number): Config.Prayer?
	for _, p in Config.PRAYERS do
		if Config.inWindow(p, clock) then
			local key = dayIndex
			if p.endT > 24 and clock < p.endT - 24 then
				key = dayIndex - 1
			end
			if doneKey[p.id] ~= key then
				return p
			end
		end
	end
	return nil
end

local function markDone(p: Config.Prayer, clock: number)
	local key = dayIndex
	if p.endT > 24 and clock < p.endT - 24 then
		key = dayIndex - 1
	end
	doneKey[p.id] = key
end

local function directorTick()
	local clock = TimeService.getClock()
	if clock < lastClock - 6 then
		dayIndex += 1
	end
	lastClock = clock
	if running then
		return
	end
	local forced = pending
	if forced then
		pending = nil
		local prayer = Config.prayerById(forced)
		if prayer then
			runEvent(prayer)
		end
		return
	end
	local prayer = duePrayer(clock)
	if prayer then
		markDone(prayer, clock)
		runEvent(prayer)
	end
end

-- ---------------------------------------------------------------- init / start
function MasjidService.init() end

function MasjidService.start()
	local leave = Net.event(Net.Names.MasjidAction)
	leave.OnServerEvent:Connect(function(player: Player, action: any)
		if action == "leave" then
			releasePlayer(player)
		elseif action == "join" or action == "sit" then
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and (root.Position - Config.CENTER).Magnitude < 60 then
				local best: number? = nil
				local bestDistance = math.huge
				local list: { any } = if action == "join" then slots else seats
				for index, entry in list do
					local free = if action == "join"
						then entry.owner == nil
						else entry.part.Occupant == nil
					local distance = (entry.part.Position - root.Position).Magnitude
					if free and distance < bestDistance then
						best, bestDistance = index, distance
					end
				end
				if best then
					if action == "join" then
						joinPrayer(player, best, true)
					else
						sitPlayer(player, seats[best].part, true)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		releasePlayer(player)
	end)

	folder = Instance.new("Folder")
	folder.Name = "Masjid"
	folder.Parent = Workspace
	buildFurniture()
	buildClock()
	setPhase("Idle")
	setText("", "", "")

	-- Waktu sholat yang sudah lewat saat server mulai dianggap selesai.
	lastClock = TimeService.getClock()
	for _, p in Config.PRAYERS do
		if p.endT <= 24 and p.time <= lastClock then
			doneKey[p.id] = dayIndex
		end
	end

	if RunService:IsStudio() then
		local debug = Instance.new("BindableFunction")
		debug.Name = "MasjidDebug"
		debug.OnInvoke = function(command: any, arg: any): any
			if command == "mulai" and type(arg) == "string" and Config.prayerById(arg) then
				pending = arg
				return "dijadwalkan " .. arg
			elseif command == "status" then
				return phase .. " npc=" .. tostring(npcActive)
			end
			return nil
		end
		debug.Parent = ServerStorage
	end

	task.spawn(function()
		while true do
			local ok, err = pcall(npcTick)
			if not ok then
				warn("[Masjid] npc: " .. tostring(err))
			end
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(directorTick)
			if not ok then
				warn("[Masjid] acara: " .. tostring(err))
				running = false
				setPhase("Idle")
			end
			task.wait(1)
		end
	end)
end

return MasjidService
