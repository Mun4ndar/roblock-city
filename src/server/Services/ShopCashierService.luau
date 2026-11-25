--!strict
-- ShopCashierService: NPC kasir yang berjaga di belakang meja kasir TOKO (Map.BangunanBlender.TokoModern).
-- Ramah: tersenyum, berbalik menghadap pembeli yang masuk, melambai dan menyapa lewat gelembung teks.
-- Belanja tetap lewat ProximityPrompt "Belanja" di Map.Toko.KasirToko (StoreService).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ShopCashierService = {}

local rgb = Color3.fromRGB

local IDLE = "rbxassetid://507766388"
local WAVE = "rbxassetid://507770239"

local POSITION = Vector3.new(145.2, 0, 193.4) -- di belakang meja kasir (meja di x 146.5, z 190.5)
local FLOOR_Y = 1.0
local FACING = Vector3.new(0, 0, -1) -- menghadap ke dalam toko
local GREET_DISTANCE = 15

local GREETINGS = {
	"Selamat datang di TOKO! 😊",
	"Silakan belanja, Kak! Ada es teh, roti, es krim...",
	"Mau tebus diskon murahnya kak, ada Teh Botol sama Rotinya kak 😊",
	"Terima kasih sudah mampir! ✨",
}

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

local function buildBubble(head: BasePart): (string, number) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SapaanKasir"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(250, 56)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 40
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

local function spawnCashier()
	local description = Instance.new("HumanoidDescription")
	local skin = rgb(224, 172, 120)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = rgb(255, 150, 40)
	description.LeftLegColor = rgb(35, 70, 140)
	description.RightLegColor = rgb(35, 70, 140)
	local ok, model = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" then
		warn("[ShopCashier] gagal membuat kasir: " .. tostring(model))
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or head == nil or not head:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	model.Name = "KasirToko"
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
				part.Color = rgb(60, 50, 46)
			elseif n:match("UpperArm$") or n == "UpperTorso" then
				part.Color = rgb(255, 150, 40)
			elseif n == "LowerTorso" or n:match("Leg$") then
				part.Color = rgb(35, 70, 140)
			elseif n ~= "HumanoidRootPart" then
				part.Color = skin
			end
		end
	end
	-- rambut dan topi biru TOKO
	decorate(model, head, "Rambut", Vector3.new(1.42, 1.2, 1.42), rgb(40, 30, 28), CFrame.new(0, 0.34, 0.08), true)
	decorate(model, head, "Topi", Vector3.new(1.5, 0.45, 1.5), rgb(35, 110, 210), CFrame.new(0, 0.62, 0))
	decorate(model, head, "TopiLidah", Vector3.new(1.1, 0.12, 0.7), rgb(35, 110, 210), CFrame.new(0, 0.42, -0.85))

	local y = FLOOR_Y + humanoid.HipHeight + root.Size.Y / 2
	local base = CFrame.lookAt(Vector3.new(POSITION.X, y, POSITION.Z), Vector3.new(POSITION.X + FACING.X, y, POSITION.Z + FACING.Z))
	model:PivotTo(base)
	root.Anchored = true
	model.Parent = Workspace

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function track(id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local t = animator:LoadAnimation(animation)
		t.Priority = priority
		t.Looped = looped
		return t
	end
	track(IDLE, Enum.AnimationPriority.Idle, true):Play(0)
	local wave = track(WAVE, Enum.AnimationPriority.Action2, false)
	local say = buildBubble(head)

	local greeted = false
	local lastWave = 0
	local lastLine = 0
	local lineIndex = 0
	while model.Parent do
		local player, distance = nearestPlayer(root.Position)
		if player and distance < GREET_DISTANCE then
			local character = player.Character
			local theirRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if theirRoot and theirRoot:IsA("BasePart") then
				local here = model:GetPivot().Position
				model:PivotTo(CFrame.lookAt(here, Vector3.new(theirRoot.Position.X, here.Y, theirRoot.Position.Z)))
			end
			if not greeted or os.clock() - lastWave > 20 then
				greeted = true
				lastWave = os.clock()
				wave:Play(0.2)
				say("Selamat datang di TOKO, Kak! 😊", 4)
			elseif os.clock() - lastLine > 10 then
				lastLine = os.clock()
				lineIndex = lineIndex % #GREETINGS + 1
				say(GREETINGS[lineIndex], 5)
			end
		elseif greeted then
			greeted = false
			model:PivotTo(base)
		end
		task.wait(0.5)
	end
end

function ShopCashierService.init() end

function ShopCashierService.start()
	task.spawn(spawnCashier)
end

return ShopCashierService
