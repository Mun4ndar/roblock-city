--!strict
--[[
	PelabuhanService: petugas loket feri di kantor pelabuhan (Workspace.Map.Beach.Pelabuhan.LoketFeri).
	Petugas (R15 berseragam, dibuat dari kode) berdiri di part "TitikPetugas" di belakang meja loket dan menyapa
	pemain yang mendekat dengan gelembung ucapan + lambaian:
	  "Naik Ferry di belakang kak, sebentar lagi mau berangkat."
	Saat feri sedang berlayar ia bilang feri akan segera kembali. Status feri dibaca dari atribut "State" model Feri
	(diisi FerryService). Petugas hanya dibuat bila ada pemain dalam SPAWN_RANGE stud (hemat HP).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PelabuhanService = {}

local SPAWN_RANGE = 140
local GREET_RANGE = 26
local GREET_COOLDOWN = 9
local CHECK_SECONDS = 0.5

local IDLE = "rbxassetid://507766388"
local WAVE = "rbxassetid://507770239"

local rgb = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic

local TEXT_BOARD = "Naik Ferry di belakang kak, sebentar lagi mau berangkat."
local TEXT_AWAY = "Ferinya sedang berlayar kak, sebentar lagi kembali ya."

local officer: Model? = nil
local post: BasePart? = nil
local say: ((string, number) -> ())? = nil
local wave: AnimationTrack? = nil
local lastGreet = 0

local function attach(model: Model, to: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType)
	local part = Instance.new("Part")
	part.Name = "Hiasan"
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = SP
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless =
		false, false, false, false, true
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

local function buildBubble(head: BasePart): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanLoket"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(300, 62)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 50
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
	stroke.Color = rgb(30, 90, 190)
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

local function build(at: CFrame): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = rgb(224, 172, 138)
	description.LeftArmColor = rgb(224, 172, 138)
	description.RightArmColor = rgb(224, 172, 138)
	description.HeightScale = 0.98
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[Pelabuhan] gagal membuat petugas: " .. tostring(model))
		return nil
	end
	model.Name = "Kak Dewi"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("UpperTorso")
	if
		humanoid == nil
		or head == nil
		or rootPart == nil
		or torso == nil
		or not head:IsA("BasePart")
		or not rootPart:IsA("BasePart")
		or not torso:IsA("BasePart")
	then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	for _, child in model:GetChildren() do
		if child:IsA("LuaSourceContainer") or child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("Pants") then
			child:Destroy()
		end
	end
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy() -- wajah digambar FaceService
		end
	end
	local skin = rgb(224, 172, 138)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			part.Material = SP
			if n:match("Hand$") or n == "Head" then
				part.Color = skin
			elseif n:match("Foot$") then
				part.Color = rgb(30, 28, 32)
			elseif n:match("Leg$") then
				part.Color = rgb(28, 48, 96)
			else
				part.Color = rgb(255, 255, 255)
			end
		end
	end
	-- rompi biru + syal merah + lencana + topi pelaut + rambut dikuncir
	attach(model, torso, Vector3.new(1.0, 1.35, 0.1), CFrame.new(0, 0.1, -0.52), rgb(28, 48, 96), Enum.PartType.Block)
	attach(model, torso, Vector3.new(0.9, 0.22, 0.12), CFrame.new(0, 0.62, -0.55), rgb(200, 40, 48), Enum.PartType.Block)
	attach(model, torso, Vector3.new(0.28, 0.16, 0.06), CFrame.new(0.4, 0.3, -0.58), rgb(226, 172, 52), Enum.PartType.Block)
	attach(model, head, Vector3.new(1.4, 1.1, 1.4), CFrame.new(0, 0.38, 0.1), rgb(40, 28, 24), Enum.PartType.Ball)
	attach(model, head, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.55, 0.62), rgb(40, 28, 24), Enum.PartType.Ball)
	attach(model, head, Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 0.78, -0.02), rgb(255, 255, 255), Enum.PartType.Block)
	attach(model, head, Vector3.new(1.3, 0.12, 0.6), CFrame.new(0, 0.62, -0.7), rgb(28, 48, 96), Enum.PartType.Block)
	model:PivotTo(at)
	rootPart.Anchored = true
	model.Parent = Workspace
	return model
end

local function playerNear(point: Vector3, range: number): (boolean, Player?)
	local nearest: Player? = nil
	local best = range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") then
			local distance = (hrp.Position - point).Magnitude
			if distance < best then
				best = distance
				nearest = player
			end
		end
	end
	return nearest ~= nil, nearest
end

function PelabuhanService.init() end

function PelabuhanService.start()
	local pelabuhan = Workspace:WaitForChild("Map"):WaitForChild("Beach"):WaitForChild("Pelabuhan")
	local loket = pelabuhan:WaitForChild("LoketFeri", 30)
	if loket == nil then
		warn("[Pelabuhan] LoketFeri tidak ditemukan")
		return
	end
	local spot = loket:WaitForChild("TitikPetugas", 10)
	if spot == nil or not spot:IsA("BasePart") then
		return
	end
	post = spot

	local function spawn()
		local at = spot.CFrame
		local model = build(at)
		if model == nil then
			return
		end
		officer = model
		local head = model:FindFirstChild("Head") :: BasePart
		say = buildBubble(head)
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE
		local idleTrack = animator:LoadAnimation(idle)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack:Play()
		local waveAnim = Instance.new("Animation")
		waveAnim.AnimationId = WAVE
		wave = animator:LoadAnimation(waveAnim)
		if wave then
			wave.Priority = Enum.AnimationPriority.Action
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < CHECK_SECONDS then
			return
		end
		acc = 0
		local anyNear = playerNear(spot.Position, SPAWN_RANGE)
		if anyNear and officer == nil then
			spawn()
		elseif not anyNear and officer ~= nil then
			(officer :: Model):Destroy()
			officer, say, wave = nil, nil, nil
		end
		local model = officer
		if model == nil or say == nil then
			return
		end
		local near, player = playerNear(spot.Position, GREET_RANGE)
		if near and player and os.clock() - lastGreet > GREET_COOLDOWN then
			lastGreet = os.clock()
			local ship = pelabuhan:FindFirstChild("Feri")
			local away = ship ~= nil and ship:GetAttribute("State") == "cruising"
			say(if away then TEXT_AWAY else TEXT_BOARD, 6)
			if wave then
				wave:Play()
			end
			-- menghadap pemain yang mendekat (hanya memutar sumbu tegak)
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			local character = player.Character
			local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if rootPart and rootPart:IsA("BasePart") and hrp and hrp:IsA("BasePart") then
				local from = rootPart.Position
				local to = Vector3.new(hrp.Position.X, from.Y, hrp.Position.Z)
				if (to - from).Magnitude > 0.5 then
					model:PivotTo(CFrame.lookAt(from, to))
				end
			end
		end
	end)
end

return PelabuhanService
