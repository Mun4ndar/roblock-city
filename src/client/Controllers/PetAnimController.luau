--!strict
-- PetAnimController: menghidupkan hewan berkerangka (Motor6D) di Workspace.Hewan.
-- Tiap client menggerakkan sendi semua hewan di dekatnya sendiri (Motor6D.Transform tidak perlu
-- direplikasi): kaki berayun mengikuti kecepatan jalan, ekor dan telinga bergoyang, dan pose
-- bermanja mengikuti atribut model "Mood" yang diputuskan server (PetService). Teks melayang
-- ("Purrr~ ♥") muncul saat atribut "EmoteId" berubah.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("PetConfig"))

local PetAnimController = {}

local JOINTS =
	{ "Body", "Head", "EarL", "EarR", "LegFL", "LegFR", "LegBL", "LegBR", "Tail", "TailB" }
local ANIM_RANGE = 160

-- pose satu sendi: { pitch, yaw, roll, x, y, z }. pitch + = ujung depan naik (kepala: dongak,
-- kaki: melangkah ke depan, telinga/ekor: ke belakang/turun).
type Pose = { [string]: { number } }

type Animal = {
	model: Model,
	root: BasePart,
	id: string,
	motors: { [string]: Motor6D },
	lastPos: Vector3,
	speed: number,
	phase: number,
	scanAt: number,
}

local animals: { [Model]: Animal } = {}

local function newPose(): Pose
	local pose: Pose = {}
	for _, name in JOINTS do
		pose[name] = { 0, 0, 0, 0, 0, 0 }
	end
	return pose
end

local function toCFrame(v: { number }): CFrame
	return CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
end

-- ---------------------------------------------------------------- pose dasar (cara jalan)

local function gaitPose(p: Pose, gait: string, a: Animal, t: number)
	local walk = math.clamp(a.speed / 14, 0, 1)
	local ph = a.phase
	local s = math.sin(ph)
	if gait == "hop" then
		local hop = math.max(0, s) * walk
		p.Body[5] = hop * 0.95
		p.Body[1] = math.cos(ph) * 0.22 * walk
		p.LegFL[1], p.LegFR[1] = hop * 0.9, hop * 0.9
		p.LegBL[1], p.LegBR[1] = -hop * 1.1, -hop * 1.1
		p.EarL[1], p.EarR[1] = hop * 0.7, hop * 0.7
		p.Head[1] = -math.cos(ph) * 0.12 * walk
	else
		local amp = (if gait == "waddle" then 0.55 elseif gait == "sneak" then 0.6 else 0.75) * walk
		p.LegFL[1], p.LegBR[1] = s * amp, s * amp
		p.LegFR[1], p.LegBL[1] = -s * amp, -s * amp
		p.Body[5] = math.abs(s) * 0.12 * walk
		p.Head[1] = -math.sin(ph * 2) * 0.05 * walk
		p.Tail[2] = math.sin(ph) * 0.25 * walk
		if gait == "waddle" then
			p.Body[3] = s * 0.14 * walk
			p.Body[2] = s * 0.06 * walk
		elseif gait == "sneak" then
			p.Body[5] -= 0.22 * walk
			p.Head[1] -= 0.25 * walk
			p.Tail[1] += 0.35 * walk
		end
		p.EarL[1] = math.sin(ph * 2) * 0.08 * walk
		p.EarR[1] = p.EarL[1]
	end
	-- napas dan ekor santai
	p.Body[5] += math.sin(t * 2) * 0.02
	p.Tail[2] += math.sin(t * 1.7) * 0.25 * (1 - walk)
	p.TailB[2] = math.sin(t * 1.7 - 0.8) * 0.3 * (1 - walk) + p.Tail[2] * 0.5
end

local function sit(p: Pose, depth: number)
	p.Body[1] = 0.5
	p.Body[5] = -0.55 * depth
	p.LegBL[1], p.LegBR[1] = 1.25, 1.25
	p.LegFL[1], p.LegFR[1] = -0.1, -0.1
	p.Head[1] = -0.4
	p.Tail[1] = 0.4
end

-- ---------------------------------------------------------------- pose mood

local moods: { [string]: (Pose, number) -> () } = {}

moods.sit = function(p, t)
	sit(p, 1)
	p.Head[2] = math.sin(t * 0.8) * 0.2
	p.Tail[2] = math.sin(t * 2) * 0.3
end

moods.rub = function(p, t)
	p.Body[3] = math.sin(t * 2.2) * 0.16
	p.Head[2] = math.sin(t * 3.2) * 0.5
	p.Head[1] = 0.2
	p.Tail[1] = -0.7
	p.Tail[2] = math.sin(t * 5) * 0.3
	p.TailB[2] = math.sin(t * 5 - 1) * 0.5
end

moods.beg = function(p, t)
	sit(p, 0.6)
	p.Body[1] = 0.85
	p.Head[1] = -0.7
	p.LegFL[1] = 1.3 + math.sin(t * 7) * 0.25
	p.LegFR[1] = 1.3 - math.sin(t * 7) * 0.25
	p.LegBL[1], p.LegBR[1] = 0.6, 0.6
	p.Tail[2] = math.sin(t * 14) * 0.7
end

moods.nuzzle = function(p, t)
	p.Body[5] = -0.2
	p.Body[1] = -0.1
	p.Head[1] = -0.5
	p.Head[2] = math.sin(t * 4) * 0.35
	p.EarL[1], p.EarR[1] = 0.8, 0.8
end

moods.binky = function(p, t)
	local j = math.abs(math.sin(t * 3.2))
	p.Body[5] = j * 1.3
	p.Body[2] = math.sin(t * 3.2) * 0.8
	p.Body[3] = math.sin(t * 3.2) * 0.3
	p.LegFL[1], p.LegFR[1] = j * 0.7, j * 0.7
	p.LegBL[1], p.LegBR[1] = -j * 0.9, -j * 0.9
	p.EarL[1], p.EarR[1] = j * 0.6, j * 0.6
end

moods.curl = function(p, t)
	p.Body[5] = -0.85 + math.sin(t * 1.6) * 0.04
	p.LegFL[1], p.LegFR[1] = 1.4, 1.4
	p.LegBL[1], p.LegBR[1] = 1.4, 1.4
	p.Head[1] = -0.5
	p.Head[5] = -0.1
	p.Tail[2] = 2.3
	p.Tail[1] = 0.2
	p.EarL[1], p.EarR[1] = 0.5, 0.5
end

moods.pounce = function(p, t)
	p.Body[1] = -0.5
	p.Body[5] = -0.1 + math.sin(t * 6) * 0.12
	p.LegFL[1], p.LegFR[1] = 0.5, 0.5
	p.Head[1] = 0.5
	p.Tail[1] = -0.4
	p.Tail[2] = math.sin(t * 10) * 0.6
end

moods.hug = function(p, t)
	p.Body[1] = 1.0
	p.Body[5] = 0.6
	p.Body[3] = math.sin(t * 2) * 0.08
	p.LegBL[1], p.LegBR[1] = -1.0, -1.0
	p.LegFL[1], p.LegFR[1] = 1.9, 1.9
	p.Head[1] = -0.9
	p.EarL[1] = math.sin(t * 3) * 0.1
	p.EarR[1] = p.EarL[1]
end

moods.roll = function(p, t)
	p.Body[3] = t * 2.4
	p.Body[5] = 0.7
	p.LegFL[1] = 0.6 + math.sin(t * 6) * 0.5
	p.LegFR[1] = 0.6 - math.sin(t * 6) * 0.5
	p.LegBL[1] = 0.3 - math.sin(t * 6) * 0.5
	p.LegBR[1] = 0.3 + math.sin(t * 6) * 0.5
end

-- reaksi dielus
moods.purr = function(p, t)
	p.Body[5] = math.sin(t * 30) * 0.015
	p.Body[3] = 0.1
	p.Head[1] = 0.35
	p.Head[2] = math.sin(t * 2) * 0.2
	p.Tail[1] = -0.5
	p.Tail[2] = math.sin(t * 3) * 0.4
	p.TailB[2] = math.sin(t * 3 - 1) * 0.5
	p.EarL[1], p.EarR[1] = 0.3, 0.3
end

moods.wag = function(p, t)
	p.Tail[2] = math.sin(t * 16) * 0.9
	p.Body[5] = math.abs(math.sin(t * 5)) * 0.3
	p.LegFL[1] = 0.5 + math.sin(t * 10) * 0.3
	p.LegFR[1] = 0.5 - math.sin(t * 10) * 0.3
	p.Head[1] = 0.3
end

moods.melt = function(p, t)
	p.Body[5] = -0.3
	p.Body[1] = -0.15
	p.Head[1] = -0.4
	p.EarL[1], p.EarR[1] = 0.9, 0.9
	p.LegFL[1], p.LegFR[1] = -0.4, -0.4
end

moods.wiggle = function(p, t)
	p.Body[3] = math.sin(t * 7) * 0.35
	p.Body[2] = math.sin(t * 7) * 0.2
	p.Tail[2] = math.sin(t * 14) * 0.8
	p.Head[1] = 0.3
end

moods.sway = function(p, t)
	p.Body[3] = math.sin(t * 3) * 0.2
	p.Body[5] = math.abs(math.sin(t * 3)) * 0.08
	p.LegFL[1], p.LegFR[1] = 1.0, 1.0
	p.Head[2] = math.sin(t * 3) * 0.25
	p.EarL[1] = math.sin(t * 6) * 0.15
	p.EarR[1] = -p.EarL[1]
end

-- ---------------------------------------------------------------- teks melayang

local function floatText(a: Animal, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.4)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 170)
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = a.root
	local info = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 7.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.9, function()
		gui:Destroy()
	end)
end

-- ---------------------------------------------------------------- daftar hewan

local function register(model: Model)
	if animals[model] or model:GetAttribute("Rig") ~= true then
		return
	end
	local root = model:WaitForChild("Root", 10)
	local id = model:GetAttribute("PetId")
	if root == nil or not root:IsA("BasePart") or type(id) ~= "string" or animals[model] then
		return
	end
	local a: Animal = {
		model = model,
		root = root,
		id = id,
		motors = {},
		lastPos = root.Position,
		speed = 0,
		phase = 0,
		scanAt = 0,
	}
	animals[model] = a
	model:GetAttributeChangedSignal("EmoteId"):Connect(function()
		local text = model:GetAttribute("Emote")
		if type(text) == "string" and text ~= "" then
			floatText(a, text)
		end
	end)
	model.Destroying:Connect(function()
		animals[model] = nil
	end)
end

local function scan(a: Animal)
	for _, d in a.model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
			a.motors[d.Name] = d
		end
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	for model, a in animals do
		if model.Parent == nil then
			continue
		end
		local pos = a.root.Position
		local moved = Vector3.new(pos.X - a.lastPos.X, 0, pos.Z - a.lastPos.Z).Magnitude
		a.lastPos = pos
		if dt > 0 then
			a.speed += (math.min(moved / dt, 60) - a.speed) * math.min(1, dt * 8)
		end
		if camera and (camera.CFrame.Position - pos).Magnitude > ANIM_RANGE then
			continue
		end
		if now >= a.scanAt then
			scan(a)
			a.scanAt = now + (if a.motors.Body then 5 else 1)
		end
		local gait = PetConfig.personality(a.id).gait
		if a.speed > 1.2 then
			local rate = if gait == "hop" then 2.4 + a.speed * 0.28 else 4 + a.speed * 0.5
			a.phase += dt * rate
		end
		local pose = newPose()
		gaitPose(pose, gait, a, now)
		local mood = model:GetAttribute("Mood")
		local fn = if type(mood) == "string" then moods[mood] else nil
		if fn then
			fn(pose, now)
		end
		local alpha = 1 - math.exp(-dt * 18)
		for name, motor in a.motors do
			local v = pose[name]
			if v then
				motor.Transform = motor.Transform:Lerp(toCFrame(v), alpha)
			end
		end
	end
end

function PetAnimController.init() end

function PetAnimController.start()
	local folder = Workspace:WaitForChild("Hewan")
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.spawn(register, child)
		end
	end)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			task.spawn(register, child)
		end
	end
	RunService.RenderStepped:Connect(step)
end

return PetAnimController
