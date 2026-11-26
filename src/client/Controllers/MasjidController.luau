--!strict
--[[
	MasjidController: sisi client Masjid Al Munawaroh (lihat MasjidService dan MasjidConfig).
	  * Pose tubuh: semua model bertag "SholatPose" (imam, muazin, jamaah, marbot, dan pemain yang ikut sholat)
	    digerakkan lewat SholatPose berdasarkan atribut Workspace Masjid* yang diisi server. Hanya model dalam
	    POSE_DISTANCE dari kamera yang diproses (hemat HP). Pose = Motor6D/AnimationConstraint.Transform lokal.
	  * Panel teks di atas layar: adzan (latin + arti), langkah sholat, dan tausiah. Muncul saat pemain dekat masjid.
	  * Tombol "Berhenti ikut sholat" saat pemain sedang ikut berjamaah.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("MasjidConfig"))
local Pose = require(Shared:WaitForChild("SholatPose"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local MasjidController = {}

local player = Players.LocalPlayer
local TAG = "SholatPose"
local POSE_DISTANCE = 120
local PANEL_DISTANCE = 46
local BLEND_SECONDS = 0.85

type Entry = {
	model: Model,
	rig: Pose.Rig,
	humanoid: Humanoid?,
	current: { [string]: CFrame },
	from: { [string]: CFrame },
	toName: string,
	t0: number,
	posed: boolean,
	isPlayer: boolean,
}

local entries: { [Model]: Entry } = {}

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- ---------------------------------------------------------------- pose
local function makeEntry(model: Model): Entry?
	local rig = Pose.bind(model)
	if rig == nil then
		return nil
	end
	local current: { [string]: CFrame } = {}
	local from: { [string]: CFrame } = {}
	for _, name in Pose.JOINTS do
		current[name] = CFrame.identity
		from[name] = CFrame.identity
	end
	return {
		model = model,
		rig = rig,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		current = current,
		from = from,
		toName = "",
		t0 = 0,
		posed = false,
		isPlayer = Players:GetPlayerFromCharacter(model) ~= nil,
	}
end

local function register(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local entry = makeEntry(instance)
	if entry == nil then
		-- tubuh belum lengkap (streaming): coba lagi sebentar lagi
		task.delay(0.6, function()
			if
				instance.Parent
				and CollectionService:HasTag(instance, TAG)
				and entries[instance] == nil
			then
				local retry = makeEntry(instance)
				if retry then
					entries[instance] = retry
				end
			end
		end)
		return
	end
	entries[instance] = entry
end

local function unregister(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = entries[instance]
	if entry then
		entries[instance] = nil
		if entry.posed then
			Pose.reset(entry.rig)
		end
	end
end

-- Nama pose yang dituju model sekarang, atau nil bila tidak perlu diposekan.
local function desiredPose(entry: Entry, phase: string): string?
	local model = entry.model
	if model:GetAttribute("Jalan") == true then
		return nil -- sedang berjalan: animasi jalan dari server
	end
	local role = model:GetAttribute("Peran")
	if entry.isPlayer then
		if model:GetAttribute("Sholat") ~= true then
			return nil
		end
		if phase == "Sholat" then
			local rakaat = Workspace:GetAttribute("MasjidRakaat")
			local started = Workspace:GetAttribute("MasjidMulaiSholat")
			if type(rakaat) == "number" and type(started) == "number" then
				local t = math.max(0, Workspace:GetServerTimeNow() - started)
				local index = Config.stepAt(rakaat, t)
				return Config.sholatSequence(rakaat)[index].pose
			end
		end
		return "berdiri"
	end
	if role == "Marbot" then
		if model:GetAttribute("Ikut") ~= true then
			if model:GetAttribute("Menyapu") == true then
				return "menyapu"
			end
			return nil
		end
	end
	if phase == "Sholat" then
		local rakaat = Workspace:GetAttribute("MasjidRakaat")
		local started = Workspace:GetAttribute("MasjidMulaiSholat")
		if type(rakaat) == "number" and type(started) == "number" then
			local t = math.max(0, Workspace:GetServerTimeNow() - started)
			local index = Config.stepAt(rakaat, t)
			return Config.sholatSequence(rakaat)[index].pose
		end
		return "berdiri"
	elseif phase == "Iqamah" then
		return "berdiri"
	elseif phase == "Azan" and role == "Muazin" then
		return "takbir"
	end
	return "bersila"
end

local sweepExtra: { [string]: CFrame } = {}

local function updateEntry(entry: Entry, phase: string, now: number)
	local name = desiredPose(entry, phase)
	if name == nil then
		if entry.posed then
			Pose.reset(entry.rig)
			entry.posed = false
			entry.toName = ""
			for jointName in entry.current do
				entry.current[jointName] = CFrame.identity
			end
		end
		return
	end
	if name ~= entry.toName then
		for jointName, cf in entry.current do
			entry.from[jointName] = cf
		end
		entry.toName = name
		entry.t0 = now
	end
	local target = Pose.POSES[name] or Pose.POSES.berdiri
	local alpha = math.clamp((now - entry.t0) / BLEND_SECONDS, 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local humanoid = entry.humanoid
	local scale = if humanoid then math.clamp(humanoid.HipHeight / 2, 0.4, 1.6) else 1
	local extra: { [string]: CFrame }? = nil
	if name == "menyapu" then
		local swing = math.sin(now * 4.2)
		sweepExtra.RightShoulder = R(swing * 12, 0, 0)
		sweepExtra.LeftShoulder = R(swing * 8, 0, 0)
		sweepExtra.Waist = R(-math.abs(swing) * 5, math.sin(now * 2.1) * 8, 0)
		extra = sweepExtra
	end
	for _, jointName in Pose.JOINTS do
		local motor = entry.rig[jointName]
		if motor then
			local cf = entry.from[jointName]:Lerp(target[jointName] or CFrame.identity, alpha)
			entry.current[jointName] = cf
			local out = cf
			if jointName == "Root" and scale ~= 1 then
				out = CFrame.new(cf.Position * scale) * cf.Rotation
			end
			if extra and extra[jointName] then
				out = out * extra[jointName]
			end
			motor.Transform = out
		end
	end
	entry.posed = true
	-- animasi bawaan karakter sendiri dihentikan supaya tidak melawan pose
	if entry.isPlayer and entry.model == player.Character and humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		end
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local phase = Workspace:GetAttribute("MasjidFase")
	if type(phase) ~= "string" then
		phase = "Idle"
	end
	local now = os.clock()
	local origin = camera.CFrame.Position
	for model, entry in entries do
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
			continue
		end
		if root == nil then
			continue
		end
		local isOwn = entry.isPlayer and model == player.Character
		if isOwn or (root.Position - origin).Magnitude < POSE_DISTANCE then
			updateEntry(entry, phase :: string, now)
		end
	end
end

-- ---------------------------------------------------------------- panel teks
local panel: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local meaningLabel: TextLabel
local leaveButton: TextButton
local actionButton: TextButton
local actionMode = ""

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MasjidUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = false

	panel = Instance.new("Frame")
	panel.Name = "PanelMasjid"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 6)
	panel.Size = UDim2.fromOffset(380, 96)
	panel.BackgroundColor3 = Color3.fromRGB(20, 70, 56)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(236, 208, 120)
	stroke.Thickness = 2
	stroke.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Judul"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(10, 3)
	titleLabel.Size = UDim2.new(1, -20, 0, 18)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color3.fromRGB(246, 224, 140)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Teks"
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromOffset(10, 21)
	textLabel.Size = UDim2.new(1, -20, 0, 50)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextSize = 16
	textLabel.TextWrapped = true
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = panel

	meaningLabel = Instance.new("TextLabel")
	meaningLabel.Name = "Arti"
	meaningLabel.BackgroundTransparency = 1
	meaningLabel.Position = UDim2.fromOffset(10, 72)
	meaningLabel.Size = UDim2.new(1, -20, 0, 22)
	meaningLabel.Font = Enum.Font.GothamMedium
	meaningLabel.TextSize = 11
	meaningLabel.TextWrapped = true
	meaningLabel.TextColor3 = Color3.fromRGB(200, 232, 214)
	meaningLabel.TextXAlignment = Enum.TextXAlignment.Left
	meaningLabel.TextYAlignment = Enum.TextYAlignment.Top
	meaningLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "BerhentiSholat"
	leaveButton.AnchorPoint = Vector2.new(0.5, 0)
	leaveButton.Position = UDim2.new(0.5, 0, 1, 8)
	leaveButton.Size = UDim2.fromOffset(190, 34)
	leaveButton.BackgroundColor3 = Color3.fromRGB(196, 70, 70)
	leaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaveButton.Font = Enum.Font.FredokaOne
	leaveButton.TextSize = 17
	leaveButton.Text = "Berhenti ikut sholat"
	leaveButton.Visible = false
	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 12)
	leaveCorner.Parent = leaveButton
	leaveButton.Parent = panel

	actionButton = Instance.new("TextButton")
	actionButton.Name = "AksiMasjid"
	actionButton.AnchorPoint = Vector2.new(0.5, 0)
	actionButton.Position = UDim2.new(0.5, 0, 1, 8)
	actionButton.Size = UDim2.fromOffset(250, 36)
	actionButton.BackgroundColor3 = Color3.fromRGB(40, 150, 100)
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Font = Enum.Font.FredokaOne
	actionButton.TextSize = 17
	actionButton.Visible = false
	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 12)
	actionCorner.Parent = actionButton
	actionButton.Parent = panel
	actionButton.Activated:Connect(function()
		if actionMode ~= "" then
			Net.event(Net.Names.MasjidAction):FireServer(actionMode)
		end
	end)

	panel.Parent = gui
	UiScale.attach(panel)
	gui.Parent = player:WaitForChild("PlayerGui")

	leaveButton.Activated:Connect(function()
		Net.event(Net.Names.MasjidAction):FireServer("leave")
	end)
end

local function refreshPanel()
	local phase = Workspace:GetAttribute("MasjidFase")
	local title = Workspace:GetAttribute("MasjidJudul")
	titleLabel.Text = if type(title) == "string" then title else ""
	local text = Workspace:GetAttribute("MasjidTeks")
	textLabel.Text = if type(text) == "string" then text else ""
	local meaning = Workspace:GetAttribute("MasjidArti")
	meaningLabel.Text = if type(meaning) == "string" then meaning else ""
	local joined = player:GetAttribute("MasjidSlot") ~= nil
	leaveButton.Visible = joined and phase ~= "Idle"
	if (phase == "Azan" or phase == "Iqamah") and not joined then
		actionMode = "join"
		actionButton.Text = "Ikut sholat berjamaah"
	elseif phase == "Tausiah" or phase == "Selesai" then
		actionMode = "sit"
		actionButton.Text = "Duduk mendengarkan tausiah"
	else
		actionMode = ""
	end
	actionButton.Visible = actionMode ~= ""
end

local function updateVisibility()
	local phase = Workspace:GetAttribute("MasjidFase")
	local near = false
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		near = (root.Position - Config.CENTER).Magnitude < PANEL_DISTANCE
	end
	panel.Visible = near and type(phase) == "string" and phase ~= "Idle" and titleLabel.Text ~= ""
end

-- Selama pemain ikut sholat, prompt "Ikut sholat berjamaah" disembunyikan (hanya di layar pemain ini).
local function syncJoinPrompts()
	local joined = player:GetAttribute("MasjidSlot") ~= nil
	local phase = Workspace:GetAttribute("MasjidFase")
	local folder = Workspace:FindFirstChild("Masjid")
	if folder == nil then
		return
	end
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "IkutSholat" then
			descendant.Enabled = (not joined) and (phase == "Azan" or phase == "Iqamah")
		end
	end
end

function MasjidController.init() end

function MasjidController.start()
	buildUi()
	for _, instance in CollectionService:GetTagged(TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
	RunService.PreSimulation:Connect(step)
	-- model bertag yang belum punya entri (tubuh belum lengkap saat streaming) dicoba lagi tiap detik
	task.spawn(function()
		while true do
			task.wait(1)
			for _, instance in CollectionService:GetTagged(TAG) do
				if
					instance:IsA("Model")
					and entries[instance] == nil
					and instance:IsDescendantOf(Workspace)
				then
					local entry = makeEntry(instance)
					if entry then
						entries[instance] = entry
					end
				end
			end
		end
	end)

	for _, name in { "MasjidFase", "MasjidJudul", "MasjidTeks", "MasjidArti" } do
		Workspace:GetAttributeChangedSignal(name):Connect(refreshPanel)
	end
	player:GetAttributeChangedSignal("MasjidSlot"):Connect(refreshPanel)
	player:GetAttributeChangedSignal("MasjidSlot"):Connect(syncJoinPrompts)
	game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "IkutSholat" and player:GetAttribute("MasjidSlot") ~= nil then
			prompt.Enabled = false
		end
	end)
	refreshPanel()
	task.spawn(function()
		while true do
			updateVisibility()
			task.wait(0.5)
		end
	end)
end

return MasjidController
