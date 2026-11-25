--!strict
-- GadgetService: barang ROBLOCK STORE yang sudah dibeli (PlayerData.gadgets.owned) muncul sebagai
-- Tool di Backpack pemain dan dipasang ulang setiap respawn. Semuanya mainan/kosmetik:
-- TIDAK ada damage, tidak ada Touched. Templat visual dari ServerStorage.GadgetTemplates
-- (dibuat map/BuildGadgets.luau).
--   boombox_neon      : Boombox Neon, klik = nyala/mati (lampu neon berganti warna + not musik)
--   skateboard_rocket : Skateboard Rocket, klik = naik/turun papan (lari lebih cepat)
--   headset_gamer     : Headset Gamer, klik = pasang/lepas di kepala
--   pedang_cahaya     : Pedang Cahaya, klik = ayun (kilau cahaya saja, tidak melukai siapa pun)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local DataService = require(script.Parent:WaitForChild("DataService"))

local GadgetService = {}

local ATTR = "Gadget"
local RIDE_SPEED = 30
local CLICK_COOLDOWN = 0.5

type Def = {
	name: string,
	tip: string,
	grip: CFrame?,
	setup: (tool: Tool, player: Player) -> (),
}

local lastClick: { [Tool]: number } = {}

-- ---------------------------------------------------------------- util

local function templates(): Instance?
	return ServerStorage:FindFirstChild("GadgetTemplates")
end

local function character(tool: Tool): Model?
	local parent = tool.Parent
	return if parent and parent:IsA("Model") then parent else nil
end

local function throttle(tool: Tool): boolean
	local now = os.clock()
	local last = lastClick[tool]
	if last and now - last < CLICK_COOLDOWN then
		return false
	end
	lastClick[tool] = now
	return true
end

local function setVisible(root: Instance, visible: boolean)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" then
			d.Transparency = if visible then 0 else 1
		end
	end
end

local function neonParts(root: Instance): { BasePart }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(list, d)
		end
	end
	return list
end

-- Menempel semua part model ke core, lalu core ke anchor.
local function weldModel(clone: Model, anchor: BasePart)
	local core = clone.PrimaryPart :: BasePart
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if d ~= core then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = core
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = core
	weld.Parent = core
end

-- ---------------------------------------------------------------- perilaku

local function setupBoombox(tool: Tool, _player: Player)
	local on = false
	local token = 0
	local function stop()
		on = false
		token += 1
		for _, d in tool:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end
	tool.Unequipped:Connect(stop)
	tool.Activated:Connect(function()
		if not throttle(tool) then
			return
		end
		if on then
			stop()
			return
		end
		on = true
		token += 1
		local mine = token
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if handle then
			local emitter = handle:FindFirstChildOfClass("ParticleEmitter")
			if emitter == nil then
				local e = Instance.new("ParticleEmitter")
				e.Rate = 4
				e.Lifetime = NumberRange.new(1.2, 1.8)
				e.Speed = NumberRange.new(3, 5)
				e.SpreadAngle = Vector2.new(35, 35)
				e.Size = NumberSequence.new(0.5, 0)
				e.LightEmission = 1
				e.Color =
					ColorSequence.new(Color3.fromRGB(255, 80, 220), Color3.fromRGB(80, 230, 255))
				e.Parent = handle
				emitter = e
			end
			if emitter then
				emitter.Enabled = true
			end
		end
		local glow = neonParts(tool)
		task.spawn(function()
			local t = 0
			while on and token == mine and tool.Parent do
				t += 0.1
				for i, part in glow do
					part.Color = Color3.fromHSV((t * 0.5 + i * 0.07) % 1, 0.8, 1)
				end
				task.wait(0.1)
			end
		end)
	end)
end

local function setupSkateboard(tool: Tool, player: Player)
	local board: Model? = nil
	local previousSpeed: number? = nil
	local function stop()
		if board then
			board:Destroy()
			board = nil
		end
		setVisible(tool, true)
		local char = player.Character
		local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and previousSpeed then
			humanoid.WalkSpeed = previousSpeed
		end
		previousSpeed = nil
	end
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
	tool.Activated:Connect(function()
		if not throttle(tool) then
			return
		end
		if board then
			stop()
			return
		end
		local char = character(tool)
		local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local folder = templates()
		local template = if folder then folder:FindFirstChild("skateboard_rocket") else nil
		if
			char == nil
			or humanoid == nil
			or root == nil
			or not root:IsA("BasePart")
			or template == nil
		then
			return
		end
		local clone = template:Clone() :: Model
		local drop = humanoid.HipHeight + root.Size.Y / 2 - 0.35
		clone:PivotTo(root.CFrame * CFrame.new(0, -drop, 0))
		weldModel(clone, root)
		clone.Name = "PapanDipakai"
		clone.Parent = char
		board = clone
		setVisible(tool, false)
		previousSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = RIDE_SPEED
		humanoid.Died:Once(stop)
	end)
end

local function setupHeadset(tool: Tool, player: Player)
	local worn: Model? = nil
	tool.Destroying:Connect(function()
		if worn then
			worn:Destroy()
			worn = nil
		end
	end)
	tool.Activated:Connect(function()
		if not throttle(tool) then
			return
		end
		if worn then
			worn:Destroy()
			worn = nil
			setVisible(tool, true)
			return
		end
		local char = player.Character
		local head = if char then char:FindFirstChild("Head") else nil
		local folder = templates()
		local template = if folder then folder:FindFirstChild("headset_gamer") else nil
		if char == nil or head == nil or not head:IsA("BasePart") or template == nil then
			return
		end
		local clone = template:Clone() :: Model
		clone:ScaleTo(0.85)
		clone:PivotTo(head.CFrame * CFrame.new(0, 0.1, 0.05))
		weldModel(clone, head)
		clone.Name = "HeadsetDipakai"
		clone.Parent = char
		worn = clone
		setVisible(tool, false)
	end)
end

local function setupSaber(tool: Tool, _player: Player)
	local blade = tool:FindFirstChild("Blade", true) :: BasePart?
	local tip = tool:FindFirstChild("BladeTip", true) :: BasePart?
	local light = if blade then blade:FindFirstChildOfClass("PointLight") else nil
	local sparks: ParticleEmitter? = nil
	if tip then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Lifetime = NumberRange.new(0.4, 0.7)
		emitter.Speed = NumberRange.new(6, 12)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.LightEmission = 1
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 245, 255))
		emitter.Parent = tip
		sparks = emitter
	end
	tool.Activated:Connect(function()
		if not throttle(tool) then
			return
		end
		local anim = tool:FindFirstChild("toolanim")
		if anim == nil then
			anim = Instance.new("StringValue")
			anim.Name = "toolanim"
			anim.Parent = tool
		end
		if anim and anim:IsA("StringValue") then
			anim.Value = "Slash"
		end
		if sparks then
			sparks:Emit(14)
		end
		if light then
			light.Brightness = 3
			TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0.8 }):Play()
		end
	end)
end

local DEFS: { [string]: Def } = {
	boombox_neon = {
		name = "Boombox Neon",
		tip = "Klik untuk menyalakan lampu neon dan not musik",
		grip = CFrame.new(0, -0.2, 0),
		setup = setupBoombox,
	},
	skateboard_rocket = {
		name = "Skateboard Rocket",
		tip = "Klik untuk naik papan dan meluncur lebih cepat",
		grip = CFrame.Angles(0, 0, math.rad(90)),
		setup = setupSkateboard,
	},
	headset_gamer = {
		name = "Headset Gamer",
		tip = "Klik untuk memasang atau melepas di kepala",
		grip = nil,
		setup = setupHeadset,
	},
	pedang_cahaya = {
		name = "Pedang Cahaya",
		tip = "Mainan cahaya, klik untuk mengayun (tidak melukai siapa pun)",
		grip = CFrame.new(0, 0, 0.6),
		setup = setupSaber,
	},
}

-- ---------------------------------------------------------------- Tool

local function buildTool(key: string, def: Def, player: Player): Tool?
	local folder = templates()
	local template = if folder then folder:FindFirstChild(key) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.ToolTip = def.tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(ATTR, key)
	local handle = (template:FindFirstChild("Core") :: BasePart):Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	for _, child in template:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Core" then
			local clone = child:Clone() :: BasePart
			clone.Anchored = false
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = clone
			weld.Parent = clone
			clone.Parent = tool
		end
	end
	if def.grip then
		tool.Grip = def.grip
	end
	def.setup(tool, player)
	return tool
end

local function hasTool(player: Player, key: string): boolean
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(ATTR) == key then
					return true
				end
			end
		end
	end
	return false
end

-- Memasang Tool untuk semua barang yang dimiliki dan belum ada di Backpack/tangan pemain.
function GadgetService.refresh(player: Player)
	local data = DataService.getData(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if data == nil or backpack == nil then
		return
	end
	local gadgets: any = data.gadgets
	local owned: any = if type(gadgets) == "table" and type(gadgets.owned) == "table"
		then gadgets.owned
		else {}
	for key, def in DEFS do
		if owned[key] == true and not hasTool(player, key) then
			local tool = buildTool(key, def, player)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

function GadgetService.owns(player: Player, key: string): boolean
	local data = DataService.getData(player)
	local gadgets: any = if data then data.gadgets else nil
	return type(gadgets) == "table"
		and type(gadgets.owned) == "table"
		and gadgets.owned[key] == true
end

-- ---------------------------------------------------------------- bootstrap

local function onCharacter(player: Player)
	player:WaitForChild("Backpack", 10)
	GadgetService.refresh(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(onCharacter, player)
	end)
	if player.Character then
		task.defer(onCharacter, player)
	end
end

function GadgetService.init() end

function GadgetService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.ProfileLoaded:Connect(function(player: Player)
		GadgetService.refresh(player)
	end)
end

return GadgetService
