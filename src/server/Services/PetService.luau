--!strict
-- PetService: hewan peliharaan (beli, pilih, beri makan). Hewan yang dipilih mengikuti
-- pemiliknya: model ringan tanpa tabrakan yang ditarik AlignPosition ke samping pemilik
-- (fisikanya dijalankan client pemilik, jadi gerakannya halus dan murah untuk server).
-- Tersimpan di PlayerData.pets; dikirim ke client lewat atribut Player "Pets".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local PetConfig = require(Shared:WaitForChild("PetConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

type Result = { ok: boolean, message: string }
type PetData = Types.PetData

local PetService = {}

local models: { [Player]: Model } = {}
local lastCall: { [Player]: number } = {}
local folder: Folder

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function getPets(data: Types.PlayerData): PetData
	local pets: any = data.pets
	if type(pets) ~= "table" or type(pets.owned) ~= "table" then
		pets = { owned = {}, active = "", fedAt = 0 }
		data.pets = pets
	end
	if type(pets.active) ~= "string" then
		pets.active = ""
	end
	if type(pets.fedAt) ~= "number" then
		pets.fedAt = 0
	end
	return pets
end

local function publish(player: Player, pets: PetData)
	local view: PetConfig.PetView = { owned = pets.owned, active = pets.active, fedAt = pets.fedAt }
	player:SetAttribute(PetConfig.ATTR_PLAYER, HttpService:JSONEncode(view))
end

-- ---------------------------------------------------------------- model hewan

local function piece(
	model: Model,
	root: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType
)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
end

-- Hewan berkerangka dari Blender: ServerStorage.AsetHewanRig.<id> = Model berisi part "Root" (tak terlihat,
-- di tanah), MeshPart tiap bagian tubuh, dan Motor6D per sendi (Body, Head, LegFL, ...). Gerakan sendi
-- dimainkan tiap client oleh PetAnimController; server hanya memilih mood (atribut "Mood").
local function buildRigged(def: PetConfig.PetDef, at: CFrame): (Model?, BasePart?)
	local rigs = game:GetService("ServerStorage"):FindFirstChild("AsetHewanRig")
	local template = if rigs then rigs:FindFirstChild(def.id) else nil
	if template == nil or not template:IsA("Model") then
		return nil, nil
	end
	local model = template:Clone()
	local root = model:FindFirstChild("Root")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil
	end
	model.Name = "Hewan_" .. def.id
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = part ~= root
		end
	end
	model.PrimaryPart = root
	model:PivotTo(at)
	model:SetAttribute("Mesh", true)
	model:SetAttribute("Rig", true)
	model:SetAttribute("PetId", def.id)
	model:SetAttribute("Mood", "idle")
	local height = model:GetAttribute("Height")
	local tag = Instance.new("BillboardGui")
	tag.Name = "Nama"
	tag.Size = UDim2.fromScale(5, 1)
	tag.StudsOffset = Vector3.new(0, (if type(height) == "number" then height else 3.4) + 0.9, 0)
	tag.MaxDistance = 45
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = def.name
	text.Parent = tag
	tag.Parent = root
	return model, root
end

local function buildPet(def: PetConfig.PetDef, at: CFrame): (Model, BasePart)
	local rigModel, rigRoot = buildRigged(def, at)
	if rigModel and rigRoot then
		return rigModel, rigRoot
	end
	local k = def.size
	local model = Instance.new("Model")
	model.Name = "Hewan_" .. def.id
	local ball, block = Enum.PartType.Ball, Enum.PartType.Block
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = ball
	root.Size = Vector3.new(1.8, 1.8, 1.8) * k
	root.Color = def.body
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root

	-- Kalau ada templat mesh ServerStorage.AsetHewan.<id> (buatan Blender, assets/blender/hewan_*.fbx),
	-- hewan tampil dengan mesh itu. Titik asal templat = tanah di bawah hewan; Root jadi tak terlihat.
	local assets = game:GetService("ServerStorage"):FindFirstChild("AsetHewan")
	local template = if assets then assets:FindFirstChild(def.id) else nil
	if template then
		root.Transparency = 1
		root.Size = Vector3.new(1, 1, 1)
		model:SetAttribute("Mesh", true)
		for _, source in template:GetChildren() do
			if source:IsA("BasePart") then
				local clone = source:Clone()
				clone.Anchored = false
				clone.Massless = true
				clone.CanCollide = false
				clone.CanQuery = false
				clone.CanTouch = false
				clone.CFrame = at * source.CFrame
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = clone
				weld.Parent = clone
				clone.Parent = model
			end
		end
		local height = template:GetAttribute("Height")
		local nameTag = Instance.new("BillboardGui")
		nameTag.Name = "Nama"
		nameTag.Size = UDim2.fromScale(5, 1)
		nameTag.StudsOffset =
			Vector3.new(0, (if type(height) == "number" then height else 3) + 0.9, 0)
		nameTag.MaxDistance = 45
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.Text = def.name
		nameLabel.Parent = nameTag
		nameTag.Parent = root
		return model, root
	end
	local function add(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType)
		piece(
			model,
			root,
			size * k,
			CFrame.new(offset.Position * k) * offset.Rotation,
			color,
			shape
		)
	end
	add(Vector3.new(1.6, 1.5, 1.2), CFrame.new(0, -0.05, 0.9), def.body, ball) -- badan belakang
	add(Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 0.75, -0.95), def.body, ball) -- kepala
	add(Vector3.new(0.7, 0.55, 0.6), CFrame.new(0, 0.5, -1.65), def.accent, ball) -- moncong
	add(Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.62, -1.95), Color3.fromRGB(40, 36, 40), ball) -- hidung
	for _, sx in { -1, 1 } do
		add(
			Vector3.new(0.2, 0.26, 0.2),
			CFrame.new(sx * 0.36, 0.95, -1.62),
			Color3.fromRGB(30, 30, 36),
			ball
		) -- mata
		if def.ears == "panjang" then
			add(Vector3.new(0.34, 1.5, 0.24), CFrame.new(sx * 0.4, 2, -0.85), def.body, block)
			add(Vector3.new(0.18, 1.1, 0.1), CFrame.new(sx * 0.4, 2, -0.98), def.accent, block)
		elseif def.ears == "runcing" then
			add(
				Vector3.new(0.5, 0.6, 0.3),
				CFrame.new(sx * 0.5, 1.6, -0.9) * CFrame.Angles(0, 0, sx * -0.35),
				def.accent,
				block
			)
		else
			add(Vector3.new(0.6, 0.6, 0.3), CFrame.new(sx * 0.62, 1.45, -0.9), def.accent, ball)
		end
		for _, sz in { -0.5, 1.1 } do
			add(Vector3.new(0.42, 0.9, 0.42), CFrame.new(sx * 0.48, -0.95, sz), def.accent, block) -- kaki
		end
	end
	add(
		Vector3.new(0.4, 0.4, 1.1),
		CFrame.new(0, 0.35, 1.9) * CFrame.Angles(0.6, 0, 0),
		def.accent,
		block
	) -- ekor

	local tag = Instance.new("BillboardGui")
	tag.Name = "Nama"
	tag.Size = UDim2.fromScale(5, 1)
	tag.StudsOffset = Vector3.new(0, 2.4 * k, 0)
	tag.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = def.name
	label.Parent = tag
	tag.Parent = root
	return model, root
end

-- ---------------------------------------------------------------- otak hewan (kepribadian)
-- Tiap hewan memilih mood sesuai keadaan pemilik: berjalan, diam sebentar, lalu bermanja dengan
-- gaya khas spesiesnya (PetConfig.PERSONALITY). Mood + titik berdiri dikirim lewat atribut model
-- dan Attachment target; gerak sendinya digambar client. Server yang memutuskan, client hanya menampilkan.

type Brain = {
	player: Player,
	model: Model,
	root: BasePart,
	target: Attachment,
	def: PetConfig.PetDef,
	mood: string,
	moodUntil: number,
	idleFor: number,
	petUntil: number,
	petMood: string,
	lastPet: number,
	orbit: number,
	nextEmote: number,
	emoteN: number,
}

local brains: { [Player]: Brain } = {}
local brainClock = 0
local brainConn: RBXScriptConnection? = nil

local function emote(brain: Brain, text: string)
	if text == "" then
		return
	end
	brain.emoteN += 1
	brain.model:SetAttribute("Emote", text)
	brain.model:SetAttribute("EmoteId", brain.emoteN)
end

local function setMood(brain: Brain, mood: string)
	if brain.mood == mood then
		return
	end
	brain.mood = mood
	brain.model:SetAttribute("Mood", mood)
	local def = PetConfig.MOODS[mood]
	if def then
		emote(brain, def.emote)
		brain.nextEmote = os.clock() + 4
	end
end

local function stepBrain(brain: Brain, dt: number)
	local character = brain.player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	local personality = PetConfig.personality(brain.def.id)
	local now = os.clock()
	local velocity = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed > 2.5 then
		brain.idleFor = 0
	else
		brain.idleFor += dt
	end

	if now < brain.petUntil then
		setMood(brain, brain.petMood)
	elseif speed > 2.5 then
		setMood(brain, "walk")
		brain.moodUntil = 0
	elseif brain.idleFor < 2.5 then
		setMood(brain, "idle")
		brain.moodUntil = 0
	elseif now >= brain.moodUntil then
		-- pilih gaya bermanja berikutnya (tidak mengulang yang sama persis kalau ada pilihan lain)
		local list = personality.idle
		local pick = list[math.random(1, #list)]
		if pick == brain.mood and #list > 1 then
			pick = list[math.random(1, #list)]
		end
		setMood(brain, pick)
		local def = PetConfig.MOODS[pick]
		brain.moodUntil = now + (if def then def.seconds else 6) * (0.8 + math.random() * 0.4)
	end

	-- titik berdiri (ruang lokal pemilik; pemilik menghadap -Z, +Z = belakang)
	local def = PetConfig.MOODS[brain.mood]
	local place = if def then def.place else "follow"
	local ground = if brain.model:GetAttribute("Mesh") then -2.95 else -1.9 + 0.95 * brain.def.size
	local px, pz, yaw = personality.follow.X, personality.follow.Z, 0
	if place == "near" then
		px, pz = 1.4, -1.2
		yaw = math.atan2(px, pz)
	elseif place == "orbit8" then
		brain.orbit += dt * 2.2
		local a = brain.orbit
		px, pz = 1.6 * math.sin(a), 1.1 * math.sin(2 * a)
		yaw = math.atan2(-(1.6 * math.cos(a)), -(2.2 * math.cos(2 * a)))
	elseif place == "circle" then
		brain.orbit += dt * 1.4
		local a = brain.orbit
		px, pz = 3.4 * math.sin(a), 3.4 * math.cos(a)
		yaw = math.atan2(-math.cos(a), math.sin(a))
	end
	brain.target.Position = Vector3.new(px, ground, pz)
	brain.target.Orientation = Vector3.new(0, math.deg(yaw), 0)

	-- sesekali berseru lagi kalau masih bermanja
	if def and def.emote ~= "" and now >= brain.nextEmote then
		brain.nextEmote = now + 4.5
		emote(brain, def.emote)
	end
end

local function attachBrain(
	player: Player,
	model: Model,
	root: BasePart,
	target: Attachment,
	def: PetConfig.PetDef
)
	local brain: Brain = {
		player = player,
		model = model,
		root = root,
		target = target,
		def = def,
		mood = "idle",
		moodUntil = 0,
		idleFor = 0,
		petUntil = 0,
		petMood = "",
		lastPet = 0,
		orbit = 0,
		nextEmote = 0,
		emoteN = 0,
	}
	brains[player] = brain
	-- elus hewan: tahan E dekat hewan (siapa pun boleh mengelus, pemilik atau teman)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Elus"
	prompt.ActionText = "Elus"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(who: Player)
		local c = who.Character
		local r = if c then c:FindFirstChild("HumanoidRootPart") else nil
		local now = os.clock()
		if
			r == nil
			or not r:IsA("BasePart")
			or (r.Position - root.Position).Magnitude > PetConfig.PET_RANGE
		then
			return
		end
		if now - brain.lastPet < PetConfig.PET_COOLDOWN then
			return
		end
		brain.lastPet = now
		brain.petUntil = now + 4
		brain.petMood = PetConfig.personality(def.id).petMood
		brain.moodUntil = 0
		brain.nextEmote = 0
		brain.mood = "" -- paksa emote baru
		setMood(brain, brain.petMood)
	end)
	if brainConn == nil then
		brainConn = game:GetService("RunService").Heartbeat:Connect(function(dt: number)
			brainClock += dt
			if brainClock < 1 / 15 then
				return
			end
			local step = brainClock
			brainClock = 0
			for _, b in brains do
				if b.model.Parent ~= nil then
					stepBrain(b, step)
				end
			end
		end)
	end
end

local function removePet(player: Player)
	local model = models[player]
	if model then
		model:Destroy()
		models[player] = nil
		brains[player] = nil
	end
end

local function spawnPet(player: Player)
	removePet(player)
	local data = DataService.getData(player)
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if data == nil or hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	local def = PetConfig.get(getPets(data).active)
	if def == nil then
		return
	end
	local model, root = buildPet(def, hrp.CFrame * CFrame.new(3, -1.4, 2.5))
	-- titik tujuan: di samping belakang pemilik, setinggi tanah
	local target = Instance.new("Attachment")
	target.Name = "PetTarget"
	-- hewan mesh: Root ada di tanah (kaki pemilik ~3 stud di bawah HumanoidRootPart)
	target.Position = if model:GetAttribute("Mesh")
		then Vector3.new(3, -2.95, 2.5)
		else Vector3.new(3, -1.9 + 0.95 * def.size, 2.5)
	target.Parent = hrp
	local anchor = Instance.new("Attachment")
	anchor.Parent = root
	local move = Instance.new("AlignPosition")
	move.Attachment0 = anchor
	move.Attachment1 = target
	move.MaxForce = 1e6
	move.MaxVelocity = 60
	move.Responsiveness = 18
	move.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Attachment0 = anchor
	turn.Attachment1 = target
	turn.MaxTorque = 1e6
	turn.Responsiveness = 14
	turn.Parent = root
	model.Destroying:Connect(function()
		target:Destroy()
	end)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	models[player] = model
	attachBrain(player, model, root, target, def)
end

-- ---------------------------------------------------------------- remote handler

local function nearShop(player: Player): boolean
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	return root ~= nil
		and (root.Position - PetConfig.SHOP_POSITION).Magnitude <= PetConfig.SHOP_RANGE
end

-- action: "buy" | "equip" | "feed"; petId untuk buy/equip ("" pada equip = simpan hewan).
local function act(player: Player, action: any, petId: any): Result
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	local pets = getPets(data)
	if action == "buy" then
		local def = PetConfig.get(petId)
		if def == nil then
			return result(false, "Hewan tidak dikenal.")
		end
		if pets.owned[def.id] then
			return result(false, "Kamu sudah punya " .. def.name .. ".")
		end
		if not nearShop(player) then
			return result(false, "Datang dulu ke Toko Hewan di dalam ROBLOCK Mall ya.")
		end
		if not EconomyService.trySpend(player, def.price, "pet:" .. def.id) then
			return result(false, "Uangmu belum cukup. Harganya " .. Format.money(def.price) .. ".")
		end
		pets.owned[def.id] = true
		pets.active = def.id
		pets.fedAt = math.floor(Workspace:GetServerTimeNow())
		publish(player, pets)
		spawnPet(player)
		return result(true, def.name .. " sekarang jadi temanmu!")
	elseif action == "equip" then
		if petId == "" then
			pets.active = ""
			publish(player, pets)
			removePet(player)
			return result(true, "Hewanmu beristirahat di rumah.")
		end
		local def = PetConfig.get(petId)
		if def == nil or not pets.owned[def.id] then
			return result(false, "Kamu belum punya hewan itu.")
		end
		pets.active = def.id
		publish(player, pets)
		spawnPet(player)
		return result(true, def.name .. " ikut jalan-jalan!")
	elseif action == "feed" then
		local def = PetConfig.get(pets.active)
		if def == nil then
			return result(false, "Ajak dulu salah satu hewanmu.")
		end
		if not EconomyService.trySpend(player, PetConfig.FEED_PRICE, "pet:feed") then
			return result(
				false,
				"Uangmu belum cukup untuk makanan (" .. Format.money(PetConfig.FEED_PRICE) .. ")."
			)
		end
		pets.fedAt = math.floor(Workspace:GetServerTimeNow())
		publish(player, pets)
		return result(true, def.name .. " kenyang dan senang!")
	end
	return result(false, "Perintah tidak dikenal.")
end

-- ---------------------------------------------------------------- bootstrap

function PetService.init()
	folder = Instance.new("Folder")
	folder.Name = "Hewan"
	folder.Parent = Workspace

	Net.func(Net.Names.PetAction).OnServerInvoke = function(player: Player, action: any, petId: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(act, player, action, petId)
		if ok then
			return value
		end
		warn("[Pet] PetAction error: " .. tostring(value))
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end

	-- Toko Hewan: titik tombol di depan mall
	local shop = Instance.new("Part")
	shop.Name = "TokoHewan"
	shop.Anchored = true
	shop.CanCollide = false
	shop.CanQuery = false
	shop.Transparency = 1
	shop.Size = Vector3.new(2, 2, 2)
	shop.Position = PetConfig.SHOP_POSITION + Vector3.new(0, 4, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lihat hewan"
	prompt.ObjectText = "Toko Hewan"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(PetConfig.ATTR_PROMPT, true)
	prompt.Parent = shop
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(12, 2.4)
	sign.StudsOffset = Vector3.new(0, 6, 0)
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 170, 200)
	label.TextStrokeTransparency = 0.2
	label.Text = "🐾 Toko Hewan"
	label.Parent = sign
	sign.Enabled = false -- papan nama toko sudah ada di dalam mall
	sign.Parent = shop
	shop.Parent = Workspace
end

function PetService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			spawnPet(player)
		end)
	end
	local function onProfileLoaded(player: Player, data: Types.PlayerData)
		publish(player, getPets(data))
		spawnPet(player)
	end
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		local data = DataService.getData(player)
		if data and player:GetAttribute(PetConfig.ATTR_PLAYER) == nil then
			onProfileLoaded(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		removePet(player)
		lastCall[player] = nil
	end)
end

return PetService
