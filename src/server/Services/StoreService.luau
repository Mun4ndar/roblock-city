--!strict
-- StoreService: isi TOKO (minimarket). Lihat StoreConfig untuk daftar barang dan harga.
--   * pembelian divalidasi server: id barang, jarak ke kasir, jumlah maksimal, dan uang
--     (EconomyService.trySpend). Client tidak pernah mengirim harga.
--   * barang yang dibeli tersimpan di PlayerData.storeBag (id -> jumlah) dan muncul sebagai Tool
--     di hotbar (Backpack); dipasang ulang setiap respawn.
--   * makanan/minuman: klik untuk makan/minum (barang naik ke arah mulut, ada gelembung/remah dan
--     emoji), jumlahnya berkurang, lalu "kenyang semangat" (lari lebih cepat sebentar).
--   * mainan/payung: dibeli sekali, klik untuk bermain (tanpa damage).
--   * kasir: part bertag "StoreCounter" mendapat ProximityPrompt "Belanja".
--   * model: ServerStorage.StoreTemplates[id] kalau ada, kalau belum ada dipakai bentuk sementara.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local StoreConfig = require(Shared:WaitForChild("StoreConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local FoodService = require(script.Parent:WaitForChild("FoodService"))

local StoreService = {}

local ATTR_ITEM = "StoreItem"
local BUY_COOLDOWN = 0.35
local USE_COOLDOWN = 0.6

local openRemote: RemoteEvent
local animRemote: RemoteEvent
local lastBuy: { [Player]: number } = {}
local busy: { [Tool]: boolean } = {}
local lastUse: { [Tool]: number } = {}

-- ---------------------------------------------------------------- tas pemain

local function getBag(player: Player): { [string]: number }?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	if type(data.storeBag) ~= "table" then
		data.storeBag = {}
	end
	return data.storeBag
end

local function countOf(bag: { [string]: number }, id: string): number
	local n = bag[id]
	return if type(n) == "number" then n else 0
end

local function snapshot(bag: { [string]: number }): { [string]: number }
	local copy = {}
	for _, item in StoreConfig.ITEMS do
		local n = countOf(bag, item.id)
		if n > 0 then
			copy[item.id] = n
		end
	end
	return copy
end

local function toolLabel(item: StoreConfig.Item, count: number): string
	if item.reusable then
		return `{item.icon} {item.name}`
	end
	return `{item.icon} {item.name} x{count}`
end

-- ---------------------------------------------------------------- bentuk sementara

local PI2 = math.rad(90)

type Piece = {
	shape: string, -- "Block" | "Ball" | "Cylinder"
	size: Vector3,
	off: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	name: string?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Silinder tegak (sumbu panjang = Y): tinggi h, diameter d.
local function vcyl(h: number, d: number, y: number, color: Color3, extra: { [string]: any }?): Piece
	local piece: any = {
		shape = "Cylinder",
		size = Vector3.new(h, d, d),
		off = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, PI2),
		color = color,
	}
	if extra then
		for k, v in extra do
			piece[k] = v
		end
	end
	return piece :: Piece
end

local function block(size: Vector3, off: Vector3, color: Color3, extra: { [string]: any }?): Piece
	local piece: any = { shape = "Block", size = size, off = CFrame.new(off), color = color }
	if extra then
		for k, v in extra do
			piece[k] = v
		end
	end
	return piece :: Piece
end

local function ball(size: Vector3, off: Vector3, color: Color3, extra: { [string]: any }?): Piece
	local piece: any = { shape = "Ball", size = size, off = CFrame.new(off), color = color }
	if extra then
		for k, v in extra do
			piece[k] = v
		end
	end
	return piece :: Piece
end

local WHITE = rgb(250, 250, 250)
local GLASS = { material = Enum.Material.Glass, transparency = 0.25 }

local LOOKS: { [string]: { Piece } } = {
	air_mineral = {
		vcyl(1.0, 0.38, 0, rgb(170, 215, 255), GLASS),
		vcyl(0.22, 0.2, 0.6, rgb(170, 215, 255), GLASS),
		vcyl(0.12, 0.22, 0.76, rgb(40, 110, 220)),
		vcyl(0.36, 0.4, 0, rgb(40, 110, 220)),
	},
	es_teh = {
		vcyl(0.9, 0.5, 0, rgb(205, 130, 60), GLASS),
		vcyl(0.08, 0.56, 0.48, WHITE),
		block(Vector3.new(0.07, 0.8, 0.07), Vector3.new(0.1, 0.8, 0), rgb(230, 60, 60)),
		block(Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.08, 0.25, 0.05), rgb(235, 250, 255), GLASS),
	},
	kopi_susu = {
		vcyl(0.9, 0.5, 0, rgb(120, 75, 50), GLASS),
		vcyl(0.38, 0.5, 0.26, rgb(240, 225, 200), GLASS),
		vcyl(0.08, 0.56, 0.48, WHITE),
		block(Vector3.new(0.07, 0.8, 0.07), Vector3.new(0.1, 0.8, 0), WHITE),
	},
	susu_kotak = {
		block(Vector3.new(0.5, 0.8, 0.36), Vector3.new(0, 0, 0), WHITE),
		block(Vector3.new(0.52, 0.28, 0.38), Vector3.new(0, 0.05, 0), rgb(90, 160, 240)),
		block(Vector3.new(0.5, 0.12, 0.36), Vector3.new(0, 0.46, 0), rgb(90, 160, 240)),
		block(Vector3.new(0.06, 0.55, 0.06), Vector3.new(0.12, 0.75, 0), rgb(240, 90, 120)),
	},
	roti = {
		ball(Vector3.new(0.95, 0.6, 0.7), Vector3.new(0, 0, 0), rgb(214, 160, 90)),
		ball(Vector3.new(0.5, 0.18, 0.4), Vector3.new(0, 0.2, 0), rgb(236, 190, 120)),
	},
	onigiri = {
		ball(Vector3.new(0.8, 0.8, 0.4), Vector3.new(0, 0.05, 0), WHITE),
		block(Vector3.new(0.5, 0.36, 0.43), Vector3.new(0, -0.22, 0), rgb(25, 35, 30)),
	},
	keripik = {
		block(Vector3.new(0.7, 0.95, 0.2), Vector3.new(0, 0, 0), rgb(255, 210, 50)),
		block(Vector3.new(0.71, 0.3, 0.21), Vector3.new(0, 0.1, 0), rgb(230, 60, 50)),
		block(Vector3.new(0.7, 0.07, 0.24), Vector3.new(0, 0.48, 0), rgb(235, 190, 40)),
	},
	es_krim = {
		vcyl(0.6, 0.3, -0.25, rgb(225, 170, 90)),
		ball(Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 0.18, 0), rgb(255, 150, 190)),
		ball(Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 0.5, 0), rgb(120, 75, 50)),
	},
	cilok = {
		vcyl(0.45, 0.5, -0.25, rgb(235, 225, 200)),
		block(Vector3.new(0.05, 0.9, 0.05), Vector3.new(0, 0.2, 0), rgb(200, 170, 110)),
		ball(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.05, 0), rgb(245, 235, 220)),
		ball(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.35, 0), rgb(245, 235, 220)),
		ball(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.65, 0), rgb(245, 235, 220)),
		ball(Vector3.new(0.18, 0.12, 0.18), Vector3.new(0, 0.84, 0), rgb(170, 60, 40)),
	},
	permen = {
		block(Vector3.new(0.06, 0.9, 0.06), Vector3.new(0, -0.3, 0), WHITE),
		ball(Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.3, 0), rgb(255, 90, 160)),
		ball(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 0.3, -0.2), rgb(255, 225, 90)),
	},
	payung = {
		block(Vector3.new(0.06, 1.2, 0.06), Vector3.new(0, 0.1, 0), rgb(120, 80, 50)),
		ball(Vector3.new(1.8, 0.8, 1.8), Vector3.new(0, 0.75, 0), rgb(255, 205, 40), { name = "Canopy" }),
		block(Vector3.new(0.16, 0.06, 0.06), Vector3.new(0.05, -0.5, 0), rgb(120, 80, 50)),
	},
	bola_mainan = {
		ball(Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0, 0), rgb(230, 60, 60)),
		vcyl(0.1, 0.92, 0, rgb(255, 215, 60)),
		vcyl(0.1, 0.92, 0.2, rgb(60, 110, 230)),
	},
	mobil_mainan = {
		block(Vector3.new(0.7, 0.3, 1.1), Vector3.new(0, 0, 0), rgb(230, 60, 60)),
		block(Vector3.new(0.55, 0.25, 0.5), Vector3.new(0, 0.27, 0.05), rgb(170, 220, 255)),
		{ shape = "Cylinder", size = Vector3.new(0.12, 0.3, 0.3), off = CFrame.new(0.38, -0.15, 0.35), color = rgb(30, 30, 35) },
		{ shape = "Cylinder", size = Vector3.new(0.12, 0.3, 0.3), off = CFrame.new(-0.38, -0.15, 0.35), color = rgb(30, 30, 35) },
		{ shape = "Cylinder", size = Vector3.new(0.12, 0.3, 0.3), off = CFrame.new(0.38, -0.15, -0.35), color = rgb(30, 30, 35) },
		{ shape = "Cylinder", size = Vector3.new(0.12, 0.3, 0.3), off = CFrame.new(-0.38, -0.15, -0.35), color = rgb(30, 30, 35) },
	},
	boneka_beruang = {
		ball(Vector3.new(0.65, 0.75, 0.55), Vector3.new(0, 0, 0), rgb(160, 105, 65)),
		ball(Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 0.55, 0), rgb(160, 105, 65)),
		ball(Vector3.new(0.18, 0.18, 0.14), Vector3.new(0.2, 0.8, 0), rgb(160, 105, 65)),
		ball(Vector3.new(0.18, 0.18, 0.14), Vector3.new(-0.2, 0.8, 0), rgb(160, 105, 65)),
		ball(Vector3.new(0.22, 0.18, 0.16), Vector3.new(0, 0.5, -0.22), rgb(235, 205, 165)),
		ball(Vector3.new(0.07, 0.07, 0.07), Vector3.new(0.1, 0.62, -0.23), rgb(25, 25, 25)),
		ball(Vector3.new(0.07, 0.07, 0.07), Vector3.new(-0.1, 0.62, -0.23), rgb(25, 25, 25)),
	},
}

local function makePart(piece: Piece, origin: CFrame): Part
	local part = Instance.new("Part")
	part.Name = piece.name or "Bagian"
	if piece.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif piece.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	else
		part.Shape = Enum.PartType.Block
	end
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = origin * piece.off
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	return part
end

local function fillFromTemplate(tool: Tool, handle: Part, id: string): boolean
	local folder = ServerStorage:FindFirstChild("StoreTemplates")
	local template = if folder then folder:FindFirstChild(id) else nil
	if template == nil then
		return false
	end
	local origin = handle.CFrame
	local clone = template:Clone()
	if clone:IsA("Model") then
		clone:PivotTo(origin)
	elseif clone:IsA("BasePart") then
		clone.CFrame = origin
	else
		clone:Destroy()
		return false
	end
	local any = false
	local parts = if clone:IsA("Model") then clone:GetDescendants() else { clone }
	for _, d in parts do
		if d:IsA("BasePart") then
			any = true
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = d
			weld.Parent = d
			d.Parent = tool
		end
	end
	clone:Destroy()
	return any
end

local function buildTool(item: StoreConfig.Item, count: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = toolLabel(item, count)
	tool.ToolTip = item.desc
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(ATTR_ITEM, item.id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new(0, 100, 0)
	handle.Parent = tool

	if not fillFromTemplate(tool, handle, item.id) then
		local look = LOOKS[item.id]
		if look then
			for _, piece in look do
				local part = makePart(piece, handle.CFrame)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
				part.Parent = tool
			end
		end
	end
	return tool
end

-- ---------------------------------------------------------------- efek

local function floatEmoji(anchor: BasePart, emoji: string, count: number)
	for i = 1, count do
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(34, 34)
		gui.StudsOffset = Vector3.new((i - (count + 1) / 2) * 0.9, 0.5, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 70
		gui.Adornee = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = emoji
		label.TextScaled = true
		label:SetAttribute("NoLoc", true)
		label.Parent = gui
		gui.Parent = anchor
		TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = gui.StudsOffset + Vector3.new(0, 3.2, 0),
		}):Play()
		TweenService:Create(label, TweenInfo.new(1.4), { TextTransparency = 1 }):Play()
		task.delay(1.5, function()
			gui:Destroy()
		end)
	end
end

local function burst(handle: BasePart, color: Color3, kind: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(2, 4.5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, if kind == "drink" then 4 else -6, 0)
	emitter.Size = NumberSequence.new(if kind == "drink" then 0.28 else 0.16, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.LightEmission = if kind == "drink" then 0.4 else 0
	emitter.Color = ColorSequence.new(color)
	emitter.Parent = handle
	return emitter
end

local function characterOf(tool: Tool): (Model?, Humanoid?)
	local parent = tool.Parent
	if parent and parent:IsA("Model") then
		return parent, parent:FindFirstChildOfClass("Humanoid")
	end
	return nil, nil
end

-- ---------------------------------------------------------------- pakai

-- Pose barang saat dimakan/diminum: relatif terhadap Grip awal (barang naik ke arah mulut).
-- Grip menggeser pegangan di ruang tangan, jadi pose = kebalikan dari gerak barang yang diinginkan
-- (geser ke arah mulut + miring ke belakang). Sumbu barang searah kepala: x kanan, y atas, z belakang.
local USE_POSE: { [string]: CFrame } = {
	drink = (CFrame.new(-0.9, 0.6, 0.9) * CFrame.Angles(math.rad(35), 0, 0)):Inverse(),
	eat = (CFrame.new(-0.8, 0.5, 0.9) * CFrame.Angles(math.rad(15), 0, 0)):Inverse(),
}

local function animateUse(tool: Tool, kind: string, duration: number): boolean
	local owner = Players:GetPlayerFromCharacter(tool.Parent)
	if owner then
		animRemote:FireClient(owner, kind, duration) -- lengan digerakkan di client (ConsumeAnimController)
	end
	local base = tool.Grip
	local pose = USE_POSE[kind] or USE_POSE.eat
	local started = os.clock()
	local completed = true
	while true do
		local t = os.clock() - started
		if t >= duration then
			break
		end
		local character = characterOf(tool)
		if character == nil or tool.Parent ~= character then
			completed = false
			break
		end
		local up = math.clamp(t / 0.35, 0, 1)
		local down = math.clamp((duration - t) / 0.3, 0, 1)
		local a = math.min(up, down)
		a = a * a * (3 - 2 * a) -- halus
		-- goyang kecil seperti menyesap / menggigit
		local sip = math.abs(math.sin(t * 7)) * 0.12 * a
		tool.Grip = base:Lerp(base * pose, a) * CFrame.new(0, 0, sip)
		RunService.Heartbeat:Wait()
	end
	tool.Grip = base
	return completed
end

local function consume(player: Player, tool: Tool, item: StoreConfig.Item)
	local bag = getBag(player)
	if bag == nil then
		tool:Destroy() -- data belum siap: tetap habiskan barangnya
		return
	end
	local count = countOf(bag, item.id)
	if count <= 0 then
		tool:Destroy()
		return
	end
	count -= 1
	bag[item.id] = if count > 0 then count else nil
	if count > 0 then
		tool.Name = toolLabel(item, count)
	else
		tool:Destroy()
	end
end

local function useConsumable(player: Player, tool: Tool, item: StoreConfig.Item)
	local character, humanoid = characterOf(tool)
	local handle = tool:FindFirstChild("Handle")
	if character == nil or humanoid == nil or humanoid.Health <= 0 or handle == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	local emitter: ParticleEmitter? = nil
	if handle:IsA("BasePart") then
		emitter = burst(
			handle,
			if item.kind == "drink" then rgb(200, 235, 255) else rgb(235, 190, 110),
			item.kind
		)
	end
	local doneAnim = false
	task.spawn(function()
		while not doneAnim do
			if emitter then
				emitter:Emit(2)
			end
			task.wait(0.22)
		end
	end)
	local completed = animateUse(tool, item.kind, StoreConfig.USE_SECONDS)
	doneAnim = true
	if emitter then
		emitter:Destroy()
	end
	if not completed or not tool.Parent then
		return
	end
	consume(player, tool, item)
	if item.buffSeconds then
		FoodService.giveBuff(player, item.buffSeconds)
	end
	if head and head:IsA("BasePart") then
		floatEmoji(head, "😋", 1)
		floatEmoji(head, "✨", 2)
	end
	EconomyService.notify(
		player,
		if item.kind == "drink"
			then `Segar! {item.name} habis. Kamu merasa semangat.`
			else `Enak! {item.name} habis. Kamu merasa semangat.`
	)
end

local function usePlay(player: Player, tool: Tool, item: StoreConfig.Item)
	local character = characterOf(tool)
	local handle = tool:FindFirstChild("Handle")
	if character == nil or handle == nil or not handle:IsA("BasePart") then
		return
	end
	if item.kind == "umbrella" then
		local canopy = tool:FindFirstChild("Canopy")
		local open = tool:GetAttribute("Open") == true
		tool:SetAttribute("Open", not open)
		if canopy and canopy:IsA("BasePart") then
			local target = if open then Vector3.new(0.5, 1.4, 0.5) else Vector3.new(1.8, 0.8, 1.8)
			TweenService:Create(canopy, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = target }):Play()
		end
		floatEmoji(handle, "☔", 1)
		return
	end
	-- mainan
	local anim = tool:FindFirstChild("toolanim")
	if anim == nil then
		local value = Instance.new("StringValue")
		value.Name = "toolanim"
		value.Parent = tool
		anim = value
	end
	if anim and anim:IsA("StringValue") then
		anim.Value = "Slash"
	end
	local emoji = if item.id == "bola_mainan" then "⚽" elseif item.id == "mobil_mainan" then "📣" else "💖"
	floatEmoji(handle, emoji, if item.id == "boneka_beruang" then 3 else 2)
end

local function wireTool(player: Player, tool: Tool, item: StoreConfig.Item)
	tool.Activated:Connect(function()
		local now = os.clock()
		if busy[tool] or (lastUse[tool] and now - lastUse[tool] < USE_COOLDOWN) then
			return
		end
		lastUse[tool] = now
		busy[tool] = true
		local ok, err = pcall(function()
			if item.reusable then
				usePlay(player, tool, item)
			else
				useConsumable(player, tool, item)
			end
		end)
		busy[tool] = nil
		if not ok then
			warn("[Store] pakai gagal: " .. tostring(err))
		end
	end)
	tool.Destroying:Connect(function()
		busy[tool] = nil
		lastUse[tool] = nil
	end)
end

-- ---------------------------------------------------------------- tool di hotbar

local function findTool(player: Player, id: string): Tool?
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(ATTR_ITEM) == id then
					return child
				end
			end
		end
	end
	return nil
end

-- Memasang/menyesuaikan Tool sesuai isi tas pemain.
function StoreService.refresh(player: Player)
	local bag = getBag(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if bag == nil or backpack == nil then
		return
	end
	for _, item in StoreConfig.ITEMS do
		local count = countOf(bag, item.id)
		local tool = findTool(player, item.id)
		if count > 0 and tool == nil then
			local newTool = buildTool(item, count)
			wireTool(player, newTool, item)
			newTool.Parent = backpack
		elseif count > 0 and tool then
			tool.Name = toolLabel(item, count)
		end
	end
end

-- ---------------------------------------------------------------- beli

local function nearCounter(player: Player): boolean
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if root == nil then
		return false
	end
	for _, inst in CollectionService:GetTagged(StoreConfig.TAG_COUNTER) do
		if
			inst:IsA("BasePart")
			and inst:IsDescendantOf(Workspace)
			and (inst.Position - root.Position).Magnitude <= StoreConfig.BUY_DISTANCE
		then
			return true
		end
	end
	return false
end

local function buy(player: Player, id: any): { ok: boolean, message: string, bag: { [string]: number }? }
	local now = os.clock()
	local last = lastBuy[player]
	if last and now - last < BUY_COOLDOWN then
		return { ok = false, message = "Pelan-pelan ya." }
	end
	lastBuy[player] = now
	local item = StoreConfig.get(id)
	if item == nil then
		return { ok = false, message = "Barang itu tidak dijual di sini." }
	end
	local bag = getBag(player)
	if bag == nil then
		return { ok = false, message = "Data kamu masih dimuat..." }
	end
	if not nearCounter(player) then
		return { ok = false, message = "Dekati kasir toko dulu ya." }
	end
	local count = countOf(bag, item.id)
	if item.reusable and count >= 1 then
		return { ok = false, message = `Kamu sudah punya {item.name}.` , bag = snapshot(bag) }
	end
	if count >= item.maxStack then
		return { ok = false, message = `Tasmu penuh untuk {item.name} (maksimal {item.maxStack}).`, bag = snapshot(bag) }
	end
	if not EconomyService.trySpend(player, item.price, "toko:" .. item.id) then
		return { ok = false, message = "Uangmu belum cukup.", bag = snapshot(bag) }
	end
	bag[item.id] = count + 1
	StoreService.refresh(player)
	return {
		ok = true,
		message = if item.reusable
			then `{item.icon} {item.name} dibeli! Cek hotbar di bawah.`
			else `{item.icon} {item.name} dibeli! Cek hotbar di bawah, klik untuk memakainya.`,
		bag = snapshot(bag),
	}
end

-- Dipakai tempat lain (mis. Kafe Pantai): pemain memegang barang toko sementara lalu makan/minum
-- dengan animasi yang sama. Tidak menyentuh tas pemain dan tidak memungut uang (urusan pemanggil).
function StoreService.serve(player: Player, itemId: string, withBuff: boolean?): boolean
	local item = StoreConfig.get(itemId)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if item == nil or item.reusable or character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local tool = buildTool(item, 1)
	tool.Name = item.name
	tool:SetAttribute("ServeOnly", true)
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)
	task.wait(0.4)
	local handle = tool:FindFirstChild("Handle")
	local emitter = if handle and handle:IsA("BasePart")
		then burst(handle, if item.kind == "drink" then rgb(200, 235, 255) else rgb(235, 190, 110), item.kind)
		else nil
	local doneAnim = false
	task.spawn(function()
		while not doneAnim do
			if emitter then
				emitter:Emit(2)
			end
			task.wait(0.22)
		end
	end)
	local completed = animateUse(tool, item.kind, StoreConfig.USE_SECONDS)
	doneAnim = true
	local head = character:FindFirstChild("Head")
	tool:Destroy()
	if not completed then
		return false
	end
	if withBuff == true and item.buffSeconds then
		FoodService.giveBuff(player, item.buffSeconds)
	end
	if head and head:IsA("BasePart") then
		floatEmoji(head, "😋", 1)
		floatEmoji(head, "✨", 2)
	end
	return true
end

-- ---------------------------------------------------------------- kasir

local function registerCounter(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("BelanjaPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BelanjaPrompt"
	prompt.ActionText = "Belanja"
	prompt.ObjectText = "Toko"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		local bag = getBag(player)
		openRemote:FireClient(player, if bag then snapshot(bag) else {})
	end)
	prompt.Parent = inst
end

-- ---------------------------------------------------------------- bootstrap

function StoreService.init()
	openRemote = Net.event(StoreConfig.OPEN_EVENT)
	animRemote = Net.event("ConsumeAnim")
	Net.func(StoreConfig.BUY_FUNC).OnServerInvoke = function(player: Player, id: any): any
		local ok, value = pcall(buy, player, id)
		if ok then
			return value
		end
		warn("[Store] beli error: " .. tostring(value))
		return { ok = false, message = "Terjadi kesalahan, coba lagi." }
	end
	CollectionService:GetInstanceAddedSignal(StoreConfig.TAG_COUNTER):Connect(registerCounter)
	for _, inst in CollectionService:GetTagged(StoreConfig.TAG_COUNTER) do
		registerCounter(inst)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		player:WaitForChild("Backpack", 10)
		task.defer(StoreService.refresh, player)
	end)
	if player.Character then
		task.defer(StoreService.refresh, player)
	end
end

function StoreService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.ProfileLoaded:Connect(function(player: Player)
		StoreService.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuy[player] = nil
	end)
end

return StoreService
