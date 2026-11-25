--!strict
-- SchoolService: guru, murid, kepala sekolah, dan satpam NPC di dalam GedungSekolah.
-- Titik NPC dibuat saat edit-time sebagai Part bertag "SchoolNpc" (Workspace.Map.BangunanBlender.GedungSekolah.Interior.*.TitikNPC)
-- dengan atribut Nama, Peran, Pose (Duduk/Berdiri), Kelamin, Kulit, Rambut, Gaya, Skala, Baju, Ruang.
-- Agar ringan di HP, NPC baru dibuat saat ada pemain dalam jarak ACTIVE_RADIUS dari gedung dan dihapus lagi saat semua pemain jauh.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SchoolService = {}

local rgb = Color3.fromRGB

local TAG = "SchoolNpc"
local ANIM_IDLE = "rbxassetid://507766388"
local ANIM_SIT = "rbxassetid://2506281703"
local ANIM_WAVE = "rbxassetid://507770239"
local ANIM_POINT = "rbxassetid://507770453"

local CENTER = Vector3.new(-183, 10, -61)
local ACTIVE_RADIUS = 120
local DESPAWN_RADIUS = 170
local GREET_DISTANCE = 11
local TALK_DISTANCE = 32
local SIT_OFFSET = 0.9 -- pusat HumanoidRootPart di atas permukaan kursi (skala 1)

local LINES: { [string]: { string } } = {
	Guru = {
		"Anak-anak, perhatikan papan tulis ya! 📖",
		"2 + 3 berapa hasilnya? Siapa yang tahu?",
		"Ayo kerjakan dengan rapi dan teliti!",
		"Pintar sekali! Beri tepuk tangan! 👏",
		"Jangan lupa kerjakan PR-nya ya.",
		"Belajar itu menyenangkan, kan?",
	},
	GuruRuang = {
		"Kopinya enak ya ☕",
		"Nilai ulangan sudah selesai dikoreksi.",
		"Besok ada rapat guru, jangan lupa.",
		"Murid-murid kelas kita rajin sekali!",
	},
	Murid = {
		"Saya, Bu! 🙋",
		"Lima, Pak!",
		"Aku suka belajar! 📚",
		"Siap, Bu Guru!",
		"Nanti istirahat jajan es krim yuk!",
		"Boleh pinjam penghapusnya?",
	},
	MuridLobi = {
		"Ayo ke kelas, bel sudah bunyi! 🔔",
		"Nanti jajan di TOKO yuk!",
		"Hari ini ada pelajaran olahraga!",
	},
	["Kepala Sekolah"] = {
		"Selamat datang di sekolah kami! 😊",
		"Belajar yang rajin ya, Nak!",
		"Jaga kebersihan sekolah kita bersama-sama.",
	},
	Satpam = {
		"Selamat datang di sekolah! 👋",
		"Jangan berlari di koridor ya!",
		"Hati-hati di jalan, Dik!",
	},
}

local function skinOf(marker: BasePart): Color3
	local c = marker:GetAttribute("Kulit")
	return if typeof(c) == "Color3" then c else rgb(224, 172, 120)
end

local function colorAttr(marker: BasePart, name: string, fallback: Color3): Color3
	local c = marker:GetAttribute(name)
	return if typeof(c) == "Color3" then c else fallback
end

local function decorate(model: Model, on: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, ball: boolean?)
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
end

local function addHair(model: Model, head: BasePart, style: string, color: Color3, s: number)
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * s
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	if style == "topi" then
		local navy = rgb(32, 52, 92)
		decorate(model, head, "Topi", v(1.5, 0.45, 1.5), navy, at(0, 0.62, 0))
		decorate(model, head, "TopiLidah", v(1.1, 0.12, 0.7), navy, at(0, 0.42, -0.85))
		return
	end
	decorate(model, head, "Rambut", v(1.42, 1.2, 1.42), color, at(0, 0.34, 0.08), true)
	if style == "panjang" then
		decorate(model, head, "RambutBelakang", v(1.35, 2.0, 0.5), color, at(0, -0.35, 0.58))
	elseif style == "kucir" then
		decorate(model, head, "KucirKiri", v(0.5, 0.5, 0.5), color, at(-0.82, -0.1, 0.25), true)
		decorate(model, head, "KucirKanan", v(0.5, 0.5, 0.5), color, at(0.82, -0.1, 0.25), true)
		decorate(model, head, "Pita", v(1.0, 0.18, 0.18), rgb(230, 70, 110), at(0, 0.62, -0.5))
	elseif style == "sanggul" then
		decorate(model, head, "Sanggul", v(0.7, 0.7, 0.7), color, at(0, 0.75, 0.62), true)
	end
end

local function buildLabels(head: BasePart, name: string, role: string, s: number): (string, number) -> ()
	local tag = Instance.new("BillboardGui")
	tag.Name = "NamaNpc"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(150, 38)
	tag.StudsOffset = Vector3.new(0, 1.7 * s + 0.4, 0)
	tag.MaxDistance = 26
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = name .. " · " .. role
	label.Parent = tag
	tag.Parent = head

	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanNpc"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(250, 56)
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
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -16, 1, -8)
	text.Position = UDim2.fromOffset(8, 4)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rgb(40, 60, 80)
	text.Parent = frame
	frame.Parent = gui
	gui.Parent = head
	local token = 0
	return function(line: string, seconds: number)
		token += 1
		local mine = token
		text.Text = line
		gui.Enabled = true
		task.delay(seconds, function()
			if token == mine then
				gui.Enabled = false
			end
		end)
	end
end

type Npc = {
	model: Model,
	root: BasePart,
	base: CFrame,
	say: (string, number) -> (),
	role: string,
	room: string,
	sitting: boolean,
	wave: AnimationTrack,
	point: AnimationTrack,
	nextTalk: number,
	lastGreet: number,
}

local folder: Folder? = nil
local npcs: { Npc } = {}
local active = false
local generation = 0

local function track(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local t = animator:LoadAnimation(animation)
	t.Priority = priority
	t.Looped = looped
	return t
end

local function spawnNpc(marker: BasePart, parent: Folder): Npc?
	local scale = marker:GetAttribute("Skala")
	local s = if type(scale) == "number" then scale else 1
	local role = tostring(marker:GetAttribute("Peran") or "Murid")
	local name = tostring(marker:GetAttribute("Nama") or "Warga")
	local sitting = marker:GetAttribute("Pose") == "Duduk"
	local skin = skinOf(marker)
	local hairColor = colorAttr(marker, "Rambut", rgb(30, 24, 22))

	local shirt: Color3
	local pants: Color3
	if role == "Murid" then
		shirt = rgb(250, 250, 250)
		pants = rgb(200, 35, 40) -- seragam merah putih
	elseif role == "Kepala Sekolah" then
		shirt = colorAttr(marker, "Baju", rgb(196, 170, 120))
		pants = rgb(90, 76, 60)
	elseif role == "Satpam" then
		shirt = colorAttr(marker, "Baju", rgb(70, 90, 120))
		pants = rgb(40, 50, 70)
	else
		shirt = colorAttr(marker, "Baju", rgb(60, 110, 170))
		pants = if marker:GetAttribute("Kelamin") == "P" then rgb(60, 50, 70) else rgb(50, 50, 60)
	end

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
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
		warn("[School] gagal membuat NPC " .. name .. ": " .. tostring(model))
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or head == nil or not head:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
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
			d:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local n = part.Name
			if n:match("Foot$") then
				part.Color = if role == "Murid" then rgb(250, 250, 250) else rgb(50, 42, 40)
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				part.Color = shirt
			elseif n == "LowerTorso" or n:match("UpperLeg$") or n:match("LowerLeg$") then
				part.Color = pants
			elseif n ~= "HumanoidRootPart" then
				part.Color = skin
			end
		end
	end
	local style = tostring(marker:GetAttribute("Gaya") or "pendek")
	addHair(model, head, style, hairColor, s)

	local facing = marker.CFrame.LookVector
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, 1)
	end
	local y: number
	if sitting then
		y = marker.Position.Y + SIT_OFFSET * s
	else
		y = marker.Position.Y + humanoid.HipHeight + root.Size.Y / 2
	end
	local pos = Vector3.new(marker.Position.X, y, marker.Position.Z)
	local base = CFrame.lookAt(pos, pos + flat.Unit)
	model:PivotTo(base)
	root.Anchored = true
	model:SetAttribute("TanpaGerak", true)
	model.Parent = parent

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	if sitting then
		track(animator, ANIM_SIT, Enum.AnimationPriority.Action, true):Play(0)
	else
		track(animator, ANIM_IDLE, Enum.AnimationPriority.Idle, true):Play(0)
	end
	local wave = track(animator, ANIM_WAVE, Enum.AnimationPriority.Action2, false)
	local point = track(animator, ANIM_POINT, Enum.AnimationPriority.Action2, false)
	local say = buildLabels(head, name, role, s)

	return {
		model = model,
		root = root,
		base = base,
		say = say,
		role = role,
		room = tostring(marker:GetAttribute("Ruang") or ""),
		sitting = sitting,
		wave = wave,
		point = point,
		nextTalk = os.clock() + math.random(3, 12),
		lastGreet = 0,
	}
end

local function nearestPlayer(position: Vector3): (BasePart?, number)
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

local function linesFor(npc: Npc): { string }
	if npc.role == "Guru" and npc.room == "RUANG GURU" then
		return LINES.GuruRuang :: { string }
	elseif npc.role == "Murid" and npc.room == "Lobi" then
		return LINES.MuridLobi :: { string }
	end
	return (LINES[npc.role] or LINES.Murid) :: { string }
end

local function despawnAll()
	generation += 1
	active = false
	for _, npc in npcs do
		npc.model:Destroy()
	end
	table.clear(npcs)
end

local function spawnAll()
	if active then
		return
	end
	active = true
	generation += 1
	local mine = generation
	local parent = folder
	if parent == nil then
		return
	end
	task.spawn(function()
		for _, instance in CollectionService:GetTagged(TAG) do
			if generation ~= mine then
				return
			end
			if instance:IsA("BasePart") then
				local npc = spawnNpc(instance, parent)
				if npc then
					if generation ~= mine then
						npc.model:Destroy()
						return
					end
					table.insert(npcs, npc)
				end
				task.wait(0.05)
			end
		end
	end)
end

local function tick()
	local _, centerDistance = nearestPlayer(CENTER)
	if not active and centerDistance < ACTIVE_RADIUS then
		spawnAll()
	elseif active and centerDistance > DESPAWN_RADIUS then
		despawnAll()
		return
	end
	local now = os.clock()
	for _, npc in npcs do
		local hrp, distance = nearestPlayer(npc.root.Position)
		if hrp == nil then
			continue
		end
		if distance < GREET_DISTANCE then
			if not npc.sitting then
				local here = npc.base.Position
				npc.model:PivotTo(CFrame.lookAt(here, Vector3.new(hrp.Position.X, here.Y, hrp.Position.Z)))
			end
			if now - npc.lastGreet > 25 then
				npc.lastGreet = now
				npc.wave:Play(0.2)
				if npc.role == "Murid" then
					npc.say("Selamat datang di sekolah, Kak! 😊", 4)
				elseif npc.role == "Kepala Sekolah" then
					npc.say("Selamat datang, silakan masuk! 😊", 4)
				else
					npc.say("Selamat datang di sekolah kami! 😊", 4)
				end
				npc.nextTalk = now + 8
			end
		elseif not npc.sitting and distance >= GREET_DISTANCE + 3 then
			npc.model:PivotTo(npc.base)
		end
		if distance < TALK_DISTANCE and now >= npc.nextTalk then
			local pool = linesFor(npc)
			npc.say(pool[math.random(1, #pool)], 5)
			if npc.role == "Guru" and not npc.sitting then
				npc.point:Play(0.2)
			elseif npc.role == "Murid" and npc.sitting and math.random(1, 3) == 1 then
				npc.wave:Play(0.2) -- mengangkat tangan
			end
			npc.nextTalk = now + math.random(10, 24)
		end
	end
end

function SchoolService.init() end

function SchoolService.start()
	local container = Instance.new("Folder")
	container.Name = "NpcSekolah"
	container.Parent = Workspace
	folder = container
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[School] " .. tostring(err))
			end
			task.wait(0.5)
		end
	end)
end

return SchoolService
