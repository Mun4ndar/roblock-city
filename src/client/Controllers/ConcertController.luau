--!strict
--[[
	ConcertController: tampilan Panggung Konser Taman Kota di sisi client (lihat ConcertService, map/BuildPanggung).
	  - lampu sorot bergerak + berkas cahaya warna-warni (SpotLight asli hanya beberapa; sisanya berkas neon)
	  - layar LED (kisi Frame di SurfaceGui lokal) dengan pola mengikuti kenyaringan lagu
	  - kembang api dan confetti (dipicu atribut Workspace dari server)
	  - lantai joget: tekan E di pad, memainkan animasi dansa resmi sampai berjalan/melompat
	Semua animasi hanya berjalan kalau pemain dekat panggung. HP (layar sentuh) memakai kualitas LOW.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ConcertConfig"))
local Loc = require(Shared:WaitForChild("Loc"))

local ConcertController = {}

local player = Players.LocalPlayer
local LOW = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Q = if LOW then Config.QUALITY.LOW else Config.QUALITY.HIGH

type Lamp = { part: BasePart, light: SpotLight?, row: number, index: number, beam: Part? }
type Screen = {
	part: BasePart,
	kind: string,
	cols: number,
	rows: number,
	cells: { Frame },
	text: TextLabel,
	gui: SurfaceGui,
}

local lamps: { Lamp } = {}
local screens: { Screen } = {}
local signs: { BasePart } = {}
local localFolder: Folder
local beamsMade = false
local active = false
local inRange = false
local music: Sound? = nil

local frame = Config.frame()
local function stageWorld(x: number, y: number, z: number): Vector3
	return frame * Vector3.new(x, z, -y)
end

-- ---------------------------------------------------------------- bantu
local function loudness(): number
	local s = music
	if s == nil or s.Parent == nil then
		local anchor = Workspace:FindFirstChild("KonserHidup")
		local m = anchor and anchor:FindFirstChild("TitikMusik")
		s = if m then m:FindFirstChild("MusikKonser") :: Sound? else nil
		music = s
	end
	if s == nil or not s.IsPlaying then
		return 0
	end
	return math.clamp(s.PlaybackLoudness / 450, 0, 1)
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- ---------------------------------------------------------------- lampu
local function makeBeam(color: Color3): Part
	local b = Instance.new("Part")
	b.Name = "Berkas"
	b.Anchored = true
	b.CanCollide, b.CanQuery, b.CanTouch = false, false, false
	b.CastShadow = false
	b.Shape = Enum.PartType.Cylinder
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Transparency = 0.86
	b.Size = Vector3.new(60, 2.6, 2.6)
	b.Parent = localFolder
	return b
end

local function registerLamp(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local rank = part:GetAttribute("RealRank")
	local light = part:FindFirstChildOfClass("SpotLight")
	table.insert(lamps, {
		part = part,
		light = if rank and (rank :: number) <= Q.realLights then light else nil,
		row = (part:GetAttribute("Row") or 1) :: number,
		index = (part:GetAttribute("Index") or 1) :: number,
		beam = nil,
	})
end

local function ensureBeams()
	if beamsMade then
		return
	end
	beamsMade = true
	table.sort(lamps, function(a, b)
		return a.index < b.index
	end)
	-- HP: hanya sebagian lampu berkas (merata di dua batang)
	local step = math.max(1, math.floor(#lamps / Q.beams))
	for i, lamp in lamps do
		if (i - 1) % step == 0 then
			lamp.beam = makeBeam(Color3.new(1, 1, 1))
		end
	end
end

local function updateLamps(t: number, loud: number)
	for i, lamp in lamps do
		local phase = lamp.index * 0.7
		local speed = 0.7 + loud * 0.8
		-- titik sasaran di lantai depan panggung (koordinat Blender): menyapu kiri-kanan dan maju-mundur
		local tx = math.sin(t * speed + phase) * 20
		local ty = 28 + math.cos(t * speed * 0.8 + phase * 1.3) * 13
		local aim = stageWorld(tx, ty, 0)
		local pos = lamp.part.Position
		local dir = (aim - pos).Unit
		lamp.part.CFrame = CFrame.lookAt(pos, pos + dir)
		local hue = (t * 0.12 + i / #lamps) % 1
		local color = Color3.fromHSV(hue, 0.85, 1)
		if lamp.light then
			lamp.light.Enabled = true
			lamp.light.Color = color
			lamp.light.Brightness = 2.5 + loud * 3
		end
		local beam = lamp.beam
		if beam then
			local length = 62
			local center = pos + dir * (length / 2)
			beam.CFrame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.pi / 2, 0)
			beam.Size = Vector3.new(length, 2.2 + loud * 2.2, 2.2 + loud * 2.2)
			beam.Color = color
			beam.Transparency = 0.9 - loud * 0.12
		end
	end
end

local function lampsOff()
	for _, lamp in lamps do
		if lamp.light then
			lamp.light.Enabled = false
		end
		if lamp.beam then
			lamp.beam.Transparency = 1
		end
	end
end

-- ---------------------------------------------------------------- layar LED
local function buildScreen(part: BasePart)
	local kind = (part:GetAttribute("Kind") or "side") :: string
	local cols = if kind == "main" then Q.ledCols else Q.sideCols
	local rows = if kind == "main" then Q.ledRows else Q.sideRows
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LayarLED"
	gui.Face = Enum.NormalId.Front
	gui.Adornee = part
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(cols * 40, rows * 40)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.ResetOnSpawn = false
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local cells: { Frame } = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1 / cols, 1 / rows)
			f.Position = UDim2.fromScale(x / cols, y / rows)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.Parent = bg
			table.insert(cells, f)
		end
	end
	local text = Instance.new("TextLabel")
	text.Name = "Teks"
	text.Size = UDim2.fromScale(0.92, 0.5)
	text.Position = UDim2.fromScale(0.04, 0.25)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 10, 80)
	stroke.Parent = text
	text.Parent = bg
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(screens, {
		part = part,
		kind = kind,
		cols = cols,
		rows = rows,
		cells = cells,
		text = text,
		gui = gui,
	})
end

local MODES = 4
local function drawScreens(t: number, loud: number)
	local mode = (math.floor(t / 14) % MODES) + 1
	for _, s in screens do
		local cols, rows = s.cols, s.rows
		local showText = false
		for y = 0, rows - 1 do
			for x = 0, cols - 1 do
				local cell = s.cells[y * cols + x + 1]
				local color: Color3
				if mode == 1 then -- gelombang pelangi
					color = Color3.fromHSV(
						(x / cols * 0.7 + y / rows * 0.25 + t * 0.25) % 1,
						0.85,
						0.55 + 0.45 * loud
					)
				elseif mode == 2 then -- equalizer
					local h = (math.sin(t * 6 + x * 1.7) * 0.5 + 0.5) * (0.25 + loud * 0.75)
					local on = (1 - y / rows) <= h
					color = if on
						then Color3.fromHSV((x / cols + t * 0.1) % 1, 0.9, 1)
						else Color3.fromRGB(14, 8, 36)
				elseif mode == 3 then -- papan catur berkedip
					local flip = (math.floor(t * (2 + loud * 3)) + x + y) % 2 == 0
					color = if flip
						then Color3.fromHSV((t * 0.2) % 1, 0.8, 1)
						else Color3.fromHSV((t * 0.2 + 0.5) % 1, 0.8, 0.8)
				else -- cincin bergerak + teks
					local d = math.sqrt(((x - cols / 2) / cols) ^ 2 + ((y - rows / 2) / rows) ^ 2)
					color = Color3.fromHSV(
						(d * 1.5 - t * 0.3) % 1,
						0.8,
						0.45 + 0.4 * math.sin(d * 14 - t * 5) ^ 2
					)
					showText = s.kind == "main"
				end
				cell.BackgroundColor3 = color
			end
		end
		s.text.Visible = showText
		if showText then
			s.text.Text = Loc.t("KONSER TAMAN KOTA")
			s.text.TextColor3 = Color3.fromHSV((t * 0.4) % 1, 0.3, 1)
		end
	end
end

local function drawIdleScreens(t: number)
	for _, s in screens do
		local cols, rows = s.cols, s.rows
		for y = 0, rows - 1 do
			for x = 0, cols - 1 do
				local cell = s.cells[y * cols + x + 1]
				local v = 0.1 + 0.1 * math.sin(t * 1.2 + x * 0.5 + y * 0.4)
				cell.BackgroundColor3 = Color3.new(v * 0.8, v * 0.35, v)
			end
		end
		local main = s.kind == "main"
		s.text.Visible = main
		if main then
			s.text.Text = Loc.t("KONSER MALAM INI • MULAI 17.00")
			s.text.TextColor3 = Color3.fromRGB(255, 220, 120)
		end
	end
end

-- ---------------------------------------------------------------- kembang api dan confetti
local function emitterPart(position: Vector3): (Part, Attachment)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Transparency = 1
	p.Size = Vector3.new(0.4, 0.4, 0.4)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Position = position
	p.Parent = localFolder
	local a = Instance.new("Attachment")
	a.Parent = p
	return p, a
end

local function burst(position: Vector3, color: Color3)
	local p, a = emitterPart(position)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(40, 70)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 1.8
	pe.Acceleration = Vector3.new(0, -14, 0)
	pe.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) })
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(if LOW then 35 else 70)
	task.delay(2.6, function()
		p:Destroy()
	end)
end

local function launch(from: Vector3, height: number, color: Color3)
	local rocket, a = emitterPart(from)
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.new(1, 0.9, 0.6))
	trail.LightEmission = 1
	trail.Lifetime = NumberRange.new(0.5, 0.8)
	trail.Speed = NumberRange.new(2, 5)
	trail.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	trail.Rate = if LOW then 25 else 60
	trail.Parent = a
	local goal = from + Vector3.new(0, height, 0)
	local tween = TweenService:Create(
		rocket,
		TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = goal }
	)
	tween:Play()
	tween.Completed:Once(function()
		trail.Enabled = false
		burst(goal, color)
		task.delay(1, function()
			rocket:Destroy()
		end)
	end)
end

local function fireworks()
	local root = rootPart()
	if root == nil or (root.Position - Config.CENTER).Magnitude > Config.FIREWORK_RANGE then
		return
	end
	task.spawn(function()
		for i = 1, Q.bursts do
			local x = (i - (Q.bursts + 1) / 2) * 14 + math.random(-4, 4)
			local from = stageWorld(x, -17, 2)
			launch(from, math.random(85, 125), Color3.fromHSV(math.random(), 0.8, 1))
			task.wait(0.45)
		end
	end)
end

local function confetti()
	local root = rootPart()
	if root == nil or (root.Position - Config.CENTER).Magnitude > Config.VISUAL_RANGE then
		return
	end
	-- semprotan dari langit-langit atap depan: dua pemancar kiri dan kanan
	for _, sx in { -12, 12 } do
		local p, a = emitterPart(stageWorld(sx, 12.5, 24))
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 170)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 50)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 210, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 240)),
		})
		pe.LightEmission = 0.3
		pe.Lifetime = NumberRange.new(4, 6)
		pe.Speed = NumberRange.new(10, 26)
		pe.SpreadAngle = Vector2.new(70, 70)
		pe.Acceleration = Vector3.new(0, -9, 0)
		pe.RotSpeed = NumberRange.new(-200, 200)
		pe.Size = NumberSequence.new(0.7)
		pe.Rate = 0
		pe.Parent = a
		-- arah semprot: ke depan panggung (audiens), sedikit turun
		local dir = frame:VectorToWorldSpace(Vector3.new(0, -0.35, -1))
		p.CFrame = CFrame.lookAt(p.Position, p.Position + dir)
		pe.EmissionDirection = Enum.NormalId.Front
		pe:Emit(Q.confetti)
		task.delay(7, function()
			p:Destroy()
		end)
	end
end

-- ---------------------------------------------------------------- lantai joget
local currentTrack: AnimationTrack? = nil
local dancing = false
local danceToken = 0

local function stopDance()
	dancing = false
	danceToken += 1
	if currentTrack then
		currentTrack:Stop(0.25)
		currentTrack = nil
	end
end

local function startDance()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if humanoid == nil or animator == nil or humanoid.Health <= 0 then
		return
	end
	stopDance()
	dancing = true
	danceToken += 1
	local token = danceToken
	local conn: RBXScriptConnection
	conn = humanoid.Running:Connect(function(speed: number)
		if speed > 1.5 then
			stopDance()
		end
	end)
	local jumpConn = humanoid.Jumping:Connect(stopDance)
	task.spawn(function()
		local index = math.random(1, #Config.DANCE_ANIMATIONS)
		while dancing and token == danceToken do
			local animation = Instance.new("Animation")
			animation.AnimationId = Config.DANCE_ANIMATIONS[index]
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
			if currentTrack then
				currentTrack:Stop(0.3)
			end
			currentTrack = track
			local waited = 0
			while waited < Config.DANCE_SWITCH_SECONDS and dancing and token == danceToken do
				task.wait(0.25)
				waited += 0.25
			end
			index = (index % #Config.DANCE_ANIMATIONS) + 1
		end
		conn:Disconnect()
		jumpConn:Disconnect()
	end)
end

local function registerPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local prompt = pad:WaitForChild("Joget", 10)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(who: Player)
			if who == player then
				if dancing then
					stopDance()
				else
					startDance()
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------- loop
local function onHeartbeat()
	local root = rootPart()
	local near = root ~= nil and (root.Position - Config.CENTER).Magnitude <= Config.VISUAL_RANGE
	if not near then
		if inRange then
			inRange = false
			lampsOff()
		end
		return
	end
	inRange = true
	local t = os.clock()
	if active then
		ensureBeams()
		local loud = loudness()
		updateLamps(t, loud)
		for _, sign in signs do
			local g = sign:FindFirstChildWhichIsA("SurfaceGui")
			local label = if g then g:FindFirstChild("Judul") else nil
			local grad = if label then label:FindFirstChild("Pelangi") else nil
			if grad and grad:IsA("UIGradient") then
				grad.Offset = Vector2.new((t * 0.35) % 2 - 1, 0)
			end
		end
	else
		lampsOff()
	end
end

local acc = 0
local function onLed(dt: number)
	if not inRange then
		return
	end
	acc += dt
	if acc < 1 / Q.ledHz then
		return
	end
	acc = 0
	local t = os.clock()
	if active then
		drawScreens(t, loudness())
	else
		drawIdleScreens(t)
	end
end

function ConcertController.init() end

function ConcertController.start()
	localFolder = Instance.new("Folder")
	localFolder.Name = "KonserLokal"
	localFolder.Parent = Workspace

	local function track(tag: string, onAdd: (Instance) -> ())
		for _, inst in CollectionService:GetTagged(tag) do
			onAdd(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	end
	track(Config.TAG_LAMP, registerLamp)
	track(Config.TAG_SCREEN, function(inst)
		if inst:IsA("BasePart") then
			buildScreen(inst)
		end
	end)
	track(Config.TAG_SIGN, function(inst)
		if inst:IsA("BasePart") then
			table.insert(signs, inst)
		end
	end)
	track(Config.TAG_PAD, registerPad)

	local function sync()
		active = Workspace:GetAttribute(Config.ATTR_ACTIVE) == true
		if not active then
			lampsOff()
		end
	end
	sync()
	Workspace:GetAttributeChangedSignal(Config.ATTR_ACTIVE):Connect(sync)
	Workspace:GetAttributeChangedSignal(Config.ATTR_FIREWORK):Connect(function()
		if active then
			fireworks()
		end
	end)
	Workspace:GetAttributeChangedSignal(Config.ATTR_TRACK):Connect(function()
		if active then
			confetti()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		onHeartbeat()
		onLed(dt)
	end)
end

return ConcertController
