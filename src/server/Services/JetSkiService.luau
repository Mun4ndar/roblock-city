--!strict
-- JetSkiService: sewa Jet Ski di pantai + tantangan cincin di laut (opsional).
-- Pemain menyewa di papan "Sewa Jet Ski"; jet ski muncul di laut dan penyewa langsung duduk di
-- atasnya (W/S maju-mundur, A/D belok; lompat untuk turun). Di laut ada lintasan cincin melayang:
-- tekan "Mulai Tantangan" di pelampung mulai (sambil naik jet ski sendiri), lalu lewati semua
-- cincin secepat mungkin. SERVER yang menentukan segalanya: posisi jet ski (fisika milik server),
-- cincin yang sudah dilewati, waktu, hadiah, dan rekor. Client hanya menerima event JetSkiRun
-- untuk tampilan (JetSkiController). Bentuk jet ski: mesh Blender di ServerStorage.AsetKapal.jetski.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local JetSkiConfig = require(Shared:WaitForChild("JetSkiConfig"))
local Net = require(Shared:WaitForChild("Net"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local JetSkiService = {}

type Ski = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	move: LinearVelocity,
	turn: AngularVelocity,
	spray: ParticleEmitter,
	speed: number,
	idle: number,
	checkIn: number,
	blockedFront: boolean,
	blockedBack: boolean,
}

type Run = {
	next: number, -- indeks cincin berikutnya yang harus dilewati
	startedAt: number,
	unseated: number,
	earned: number,
}

local skis: { [Player]: Ski } = {}
local runs: { [Player]: Run } = {}
local lastRent: { [Player]: number } = {}
local lastRunEnd: { [Player]: number } = {}
local slotCounter = 0
local runRemote: RemoteEvent
local ringCenters: { Vector3 } = {}
local ringNormals: { Vector3 } = {}
local startPosition = Vector3.zero
local sessionBest: { [number]: { name: string, time: number } } = {}
local boardLabels: { TextLabel } = {}

local HULL_PHYSICS = PhysicalProperties.new(0.05, 0.3, 0, 1, 1)
local SEAT_COLOR = Color3.fromRGB(40, 40, 50)
local PART_LOOK: { [string]: { color: Color3, material: Enum.Material, transparency: number } } = {
	JetBody = {
		color = Color3.fromRGB(255, 200, 20),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
	},
	JetWhite = {
		color = Color3.fromRGB(245, 247, 250),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
	},
	JetTrim = {
		color = Color3.fromRGB(30, 100, 220),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
	},
	JetSeatAll = {
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
	},
	JetGlass = {
		color = Color3.fromRGB(150, 215, 255),
		material = Enum.Material.Glass,
		transparency = 0.35,
	},
}

-- Data jetski disimpan di profil pemain (tabel `jetski` dibuat saat pertama dipakai; profil
-- menyimpan seluruh tabel data, jadi tidak perlu mengubah skema bersama).
local function jetData(player: Player): { best: number, runs: number }?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	if type(data.jetski) ~= "table" then
		data.jetski = { best = 0, runs = 0 }
	end
	if type(data.jetski.best) ~= "number" then
		data.jetski.best = 0
	end
	if type(data.jetski.runs) ~= "number" then
		data.jetski.runs = 0
	end
	return data.jetski
end

-- ---------------------------------------------------------------- jet ski

local function buildSki(owner: Player): Ski
	local model = Instance.new("Model")
	model.Name = "JetSki_" .. owner.UserId
	model:SetAttribute(JetSkiConfig.ATTR_OWNER, owner.UserId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Lambung tabrakan (tak terlihat bila ada mesh): kotak ringan yang mengapung, alasnya = lunas.
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = Vector3.new(2.6, 2, 7)
	hull.CFrame = CFrame.new(0, 1, 0)
	hull.Color = Color3.fromRGB(255, 200, 20)
	hull.Material = Enum.Material.SmoothPlastic
	hull.CustomPhysicalProperties = HULL_PHYSICS
	hull.PivotOffset = CFrame.new(0, -1, 0)
	hull.Parent = model
	model.PrimaryPart = hull

	local function weld(part: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hull
		w.Part1 = part
		w.Parent = part
	end

	local assets = ServerStorage:FindFirstChild("AsetKapal")
	local template = if assets then assets:FindFirstChild("jetski") else nil
	if template then
		hull.Transparency = 1
		for _, piece in template:GetChildren() do
			if piece:IsA("BasePart") then
				local clone = piece:Clone()
				clone.Anchored = false
				clone.Massless = true
				clone.CanCollide = false
				clone.CanTouch = false
				clone.CanQuery = false
				local look = PART_LOOK[clone.Name]
				if look then
					clone.Color = look.color
					clone.Material = look.material
					clone.Transparency = look.transparency
				end
				weld(clone)
				clone.Parent = model
			end
		end
	end

	-- Kursi: pengemudi di depan, penumpang di belakangnya.
	local spots = { Vector3.new(0, 1.8, 0.4), Vector3.new(0, 1.8, 1.9) }
	local driveSeat: VehicleSeat? = nil
	for index = 1, math.min(JetSkiConfig.SEATS, #spots) do
		local seat: BasePart
		if index == 1 then
			local vs = Instance.new("VehicleSeat")
			vs.Name = "DriveSeat"
			vs.MaxSpeed = 0
			vs.Torque = 0
			vs.TurnSpeed = 0
			vs.HeadsUpDisplay = false
			driveSeat = vs
			seat = vs
		else
			local s = Instance.new("Seat")
			s.Name = "Seat" .. index
			seat = s
		end
		seat.Size = Vector3.new(1.4, 0.2, 1.4)
		seat.CFrame = CFrame.new(spots[index])
		seat.Color = SEAT_COLOR
		seat.Transparency = 1
		seat.Massless = true
		seat.CanCollide = false
		seat.CanTouch = false -- naik hanya lewat tombol (dicek server)
		weld(seat)
		seat.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EnterPrompt"
		prompt.ActionText = if index == 1 then "Kemudikan" else "Naik"
		prompt.ObjectText = "Jet Ski"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
		prompt.Triggered:Connect(function(player: Player)
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local root = if character then character.PrimaryPart else nil
			if humanoid == nil or root == nil or humanoid.Health <= 0 or humanoid.SeatPart then
				return
			end
			if (root.Position - seat.Position).Magnitude > 24 then
				return
			end
			if (seat :: any).Occupant then
				return
			end
			if index == 1 and player ~= owner then
				EconomyService.notify(player, "Hanya penyewa yang boleh mengemudikan jet ski ini.")
				return
			end
			(seat :: any):Sit(humanoid)
		end)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = hull

	-- Gerak maju-mundur searah jet ski dan nol ke samping; naik-turun tetap ikut air.
	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = attachment
	move.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	move.MaxAxesForce = Vector3.new(60000, 0, 60000) -- sumbu tegak bebas: tetap mengapung
	move.VectorVelocity = Vector3.zero
	move.Parent = hull

	-- Belok terhadap sumbu tegak; sekaligus menahan supaya tidak oleng atau terbalik.
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 4000000
	turn.Parent = hull

	-- Cipratan air di belakang saat melaju.
	local tail = Instance.new("Attachment")
	tail.Name = "Tail"
	tail.Position = Vector3.new(0, 0.6, 3.6)
	tail.Parent = hull
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 3),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Lifetime = NumberRange.new(0.5, 0.9)
	spray.Speed = NumberRange.new(5, 10)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, -12, 0)
	spray.Rate = 40
	spray.Enabled = false
	spray.Parent = tail

	CollectionService:AddTag(model, JetSkiConfig.TAG)
	return {
		model = model,
		hull = hull,
		seat = driveSeat :: VehicleSeat,
		move = move,
		turn = turn,
		spray = spray,
		speed = 0,
		idle = 0,
		checkIn = 0,
		blockedFront = false,
		blockedBack = false,
	}
end

local function sendRun(player: Player, payload: { [string]: any })
	runRemote:FireClient(player, payload)
end

local function endRun(player: Player, reason: string?)
	local run = runs[player]
	if run == nil then
		return
	end
	runs[player] = nil
	lastRunEnd[player] = os.clock()
	if reason then
		sendRun(player, { kind = "fail", reason = reason })
	end
end

local function removeSki(player: Player)
	endRun(player, nil)
	local ski = skis[player]
	if ski then
		skis[player] = nil
		ski.model:Destroy()
	end
end

-- true jika di titik itu bukan air (pasir, dermaga, jet ski lain, tepi peta): tidak boleh maju ke sana.
local function isBlocked(ski: Ski, offsetZ: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { ski.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local origin = (ski.hull.CFrame * CFrame.new(0, 0, offsetZ)).Position
	local hit = Workspace:Raycast(
		Vector3.new(origin.X, JetSkiConfig.WATER_Y + 5, origin.Z),
		Vector3.new(0, -12, 0),
		params
	)
	return hit == nil
		or hit.Material ~= Enum.Material.Water
		or hit.Position.Y < JetSkiConfig.WATER_Y - 1.5
end

local function step(ski: Ski, dt: number)
	local seat = ski.seat
	local throttle, steer = 0, 0
	if seat.Occupant then
		throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		ski.idle = 0
	else
		ski.idle += dt
	end
	ski.checkIn -= dt
	if ski.checkIn <= 0 then
		ski.checkIn = 0.1
		-- makin kencang, makin jauh ke depan yang diperiksa
		ski.blockedFront = isBlocked(ski, -6) or isBlocked(ski, -6 - math.max(ski.speed, 0) * 0.4)
		ski.blockedBack = isBlocked(ski, 6)
	end
	local target = if throttle > 0
		then throttle * JetSkiConfig.MAX_SPEED
		else throttle * JetSkiConfig.REVERSE_SPEED
	if ski.blockedFront then
		target = math.min(target, 0)
		ski.speed = math.min(ski.speed, 0)
	end
	if ski.blockedBack then
		target = math.max(target, 0)
		ski.speed = math.max(ski.speed, 0)
	end
	local change = JetSkiConfig.ACCELERATION * dt
	ski.speed += math.clamp(target - ski.speed, -change, change)
	ski.move.VectorVelocity = Vector3.new(0, 0, -ski.speed)
	-- belok penuh saat melaju (saat mundur arahnya terbalik); saat diam masih bisa berputar pelan
	-- supaya yang mentok di pantai atau tepi laut bisa diarahkan lagi
	local grip = math.clamp(ski.speed / 12, -1, 1)
	if math.abs(grip) < 0.35 then
		grip = if grip < -0.05 then -0.35 else 0.35
	end
	ski.turn.AngularVelocity = Vector3.new(0, -steer * JetSkiConfig.TURN_RATE * grip, 0)
	ski.spray.Enabled = math.abs(ski.speed) > 10
end

local function rent(player: Player)
	local now = os.clock()
	if lastRent[player] and now - lastRent[player] < JetSkiConfig.RENT_COOLDOWN then
		EconomyService.notify(player, "Pelan-pelan ya, coba lagi sebentar.")
		return
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		root == nil
		or humanoid == nil
		or humanoid.Health <= 0
		or (root.Position - JetSkiConfig.RENT_POSITION).Magnitude > JetSkiConfig.RENT_RANGE
	then
		return
	end
	if humanoid.SeatPart ~= nil then
		return
	end
	if not EconomyService.trySpend(player, JetSkiConfig.RENT_PRICE, "jetski:rent") then
		EconomyService.notify(
			player,
			"Uangmu belum cukup. Sewa jet ski " .. Format.money(JetSkiConfig.RENT_PRICE) .. "."
		)
		return
	end
	lastRent[player] = now
	removeSki(player)
	local ski = buildSki(player)
	slotCounter = (slotCounter % JetSkiConfig.SPAWN_SLOTS) + 1
	local offset = (slotCounter - (JetSkiConfig.SPAWN_SLOTS + 1) / 2) * JetSkiConfig.SPAWN_SPACING
	ski.model:PivotTo(JetSkiConfig.SPAWN * CFrame.new(offset, 0.2, 0))
	ski.model.Parent = Workspace
	ski.hull:SetNetworkOwner(nil)
	skis[player] = ski
	-- penyewa langsung duduk di jet ski (tidak perlu berenang)
	character:PivotTo(ski.seat.CFrame * CFrame.new(0, 3, 0));
	(ski.seat :: any):Sit(humanoid)
	EconomyService.notify(
		player,
		'Jet skimu siap! Mau tantangan cincin? Meluncur ke pelampung kuning di laut lalu tekan "Mulai Tantangan".'
	)
end

-- ---------------------------------------------------------------- papan skor

local function refreshBoards()
	local list: { { name: string, time: number } } = {}
	for _, entry in sessionBest do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.time < b.time
	end)
	local lines = { "REKOR TANTANGAN CINCIN" }
	for i = 1, JetSkiConfig.BOARD_ROWS do
		local entry = list[i]
		if entry then
			table.insert(lines, string.format("%d. %s  %.1f dtk", i, entry.name, entry.time))
		else
			table.insert(lines, string.format("%d. ---", i))
		end
	end
	local text = table.concat(lines, "\n")
	for _, label in boardLabels do
		label.Text = text
	end
end

-- ---------------------------------------------------------------- tantangan

local function startRun(player: Player)
	if runs[player] then
		return
	end
	local ski = skis[player]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if ski == nil or humanoid == nil or humanoid.SeatPart ~= ski.seat then
		EconomyService.notify(player, "Sewa jet ski dulu, lalu naik dan mendekat ke pelampung.")
		return
	end
	local last = lastRunEnd[player]
	if last and os.clock() - last < JetSkiConfig.RUN_COOLDOWN then
		return
	end
	local flat = Vector3.new(ski.hull.Position.X, 0, ski.hull.Position.Z)
	if (flat - startPosition).Magnitude > JetSkiConfig.START_RANGE then
		EconomyService.notify(player, "Dekatkan jet skimu ke pelampung mulai.")
		return
	end
	runs[player] = { next = 1, startedAt = os.clock(), unseated = 0, earned = 0 }
	local data = jetData(player)
	sendRun(player, {
		kind = "start",
		total = #ringCenters,
		limit = JetSkiConfig.TIME_LIMIT,
		best = if data then data.best else 0,
	})
end

local function finishRun(player: Player, run: Run)
	local elapsed = os.clock() - run.startedAt
	runs[player] = nil
	lastRunEnd[player] = os.clock()

	local reward = JetSkiConfig.REWARD_FINISH
	local faster = math.max(0, JetSkiConfig.PAR_TIME - elapsed)
	reward += math.min(
		JetSkiConfig.REWARD_TIME_BONUS_MAX,
		math.floor(faster * JetSkiConfig.REWARD_PER_SECOND_FASTER)
	)
	local data = jetData(player)
	local newBest = false
	if data then
		data.runs += 1
		if data.best <= 0 or elapsed < data.best then
			newBest = true
			data.best = math.floor(elapsed * 10 + 0.5) / 10
		end
	end
	if newBest then
		reward += JetSkiConfig.REWARD_NEW_BEST
	end
	EconomyService.addMoney(player, reward, "jetski:finish")

	local entry = sessionBest[player.UserId]
	if entry == nil or elapsed < entry.time then
		sessionBest[player.UserId] = {
			name = player.DisplayName,
			time = math.floor(elapsed * 10 + 0.5) / 10,
		}
		refreshBoards()
	end
	sendRun(player, {
		kind = "finish",
		time = elapsed,
		newBest = newBest,
		best = if data then data.best else elapsed,
		reward = reward,
		total = run.earned + reward,
	})
end

local function checkRun(player: Player, run: Run, dt: number)
	local ski = skis[player]
	if ski == nil or ski.model.Parent == nil then
		endRun(player, "Jet skimu hilang. Tantangan dihentikan.")
		return
	end
	local elapsed = os.clock() - run.startedAt
	if elapsed > JetSkiConfig.TIME_LIMIT then
		endRun(player, "Waktu habis! Coba lagi ya.")
		return
	end
	-- harus tetap di jet ski sendiri (boleh jatuh sebentar)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.SeatPart ~= ski.seat then
		run.unseated += dt
		if run.unseated > JetSkiConfig.UNSEATED_GRACE then
			endRun(player, "Kamu turun dari jet ski. Tantangan dihentikan.")
			return
		end
	else
		run.unseated = 0
	end
	-- cincin berikutnya: harus melintasi bidang cincin dan lewat di dalam lubangnya
	local center = ringCenters[run.next]
	local normal = ringNormals[run.next]
	local offset = ski.hull.Position + Vector3.new(0, 1.5, 0) - center
	local side = offset:Dot(normal)
	local lateral = (offset - normal * side).Magnitude
	if math.abs(side) < 5 and lateral < JetSkiConfig.RING_RADIUS + 1.5 then
		local passed = run.next
		run.earned += JetSkiConfig.REWARD_RING
		EconomyService.addMoney(player, JetSkiConfig.REWARD_RING, "jetski:ring")
		if passed >= #ringCenters then
			finishRun(player, run)
		else
			run.next += 1
			sendRun(player, {
				kind = "ring",
				index = passed,
				total = #ringCenters,
				elapsed = elapsed,
				reward = JetSkiConfig.REWARD_RING,
			})
		end
	end
end

-- ---------------------------------------------------------------- dunia (papan sewa, lintasan)

local function buildRentBoard(folder: Folder)
	local base = CFrame.new(JetSkiConfig.RENT_POSITION)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.WoodPlanks
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	local function sign(board: Part, text: string, textSize: number?)
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextColor3 = Color3.new(1, 1, 1)
			if textSize then
				label.TextSize = textSize
				label.TextWrapped = true
			else
				label.TextScaled = true
			end
			label.Text = text
			label.Parent = gui
			gui.Parent = board
			if textSize then
				table.insert(boardLabels, label)
			end
		end
	end

	-- papan sewa
	local woodColor = Color3.fromRGB(120, 85, 55)
	part("Tiang", Vector3.new(0.8, 9, 0.8), base * CFrame.new(0, 4.5, -3.4), woodColor)
	part("Tiang", Vector3.new(0.8, 9, 0.8), base * CFrame.new(0, 4.5, 3.4), woodColor)
	local board = part(
		"Papan",
		Vector3.new(0.5, 3.4, 8),
		base * CFrame.new(0, 7.6, 0),
		Color3.fromRGB(255, 160, 20)
	)
	board.Material = Enum.Material.SmoothPlastic
	sign(board, "SEWA JET SKI", nil)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sewa " .. Format.money(JetSkiConfig.RENT_PRICE)
	prompt.ObjectText = "Jet Ski"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(rent)

	-- papan rekor (di sebelahnya)
	local scoreBase = base * CFrame.new(0, 0, 14)
	part("Tiang", Vector3.new(0.8, 8, 0.8), scoreBase * CFrame.new(0, 4, -4.6), woodColor)
	part("Tiang", Vector3.new(0.8, 8, 0.8), scoreBase * CFrame.new(0, 4, 4.6), woodColor)
	local score = part(
		"PapanSkor",
		Vector3.new(0.5, 6, 10),
		scoreBase * CFrame.new(0, 8, 0),
		Color3.fromRGB(25, 70, 130)
	)
	score.Material = Enum.Material.SmoothPlastic
	sign(score, "", 26)
	refreshBoards()
end

-- Satu cincin: lingkaran segmen neon, berdiri tegak menghadap arah lintasan.
local function buildRing(
	folder: Folder,
	index: number,
	center: Vector3,
	normal: Vector3,
	finish: boolean
)
	local model = Instance.new("Model")
	model.Name = "Ring" .. index
	model:SetAttribute("Index", index)
	local look = CFrame.lookAt(center, center + normal)
	local radius = JetSkiConfig.RING_RADIUS
	local count = JetSkiConfig.RING_SEGMENTS
	local length = 2 * math.pi * (radius + 0.8) / count * 1.15
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		local seg = Instance.new("Part")
		seg.Name = "Seg"
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanTouch = false
		seg.CanQuery = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = if finish then Color3.fromRGB(255, 205, 40) else Color3.fromRGB(80, 220, 255)
		seg.Transparency = 0.35
		seg.Size = Vector3.new(length, 1.6, 1.6)
		-- segmen menyinggung lingkaran: sumbu panjang tegak lurus jari-jari
		seg.CFrame = look
			* CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
			* CFrame.Angles(0, 0, a + math.pi / 2)
		seg.Parent = model
	end
	model.Parent = folder
end

local function buildCourse()
	local parent = Workspace:FindFirstChild("Map") or Workspace
	local old = parent:FindFirstChild("TantanganJetSki")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TantanganJetSki"
	local y = JetSkiConfig.WATER_Y + JetSkiConfig.RING_LIFT
	local points: { Vector3 } = { Vector3.new(JetSkiConfig.START.X, y, JetSkiConfig.START.Y) }
	for _, p in JetSkiConfig.COURSE do
		table.insert(points, Vector3.new(p.X, y, p.Y))
	end
	startPosition = Vector3.new(points[1].X, 0, points[1].Z)
	table.clear(ringCenters)
	table.clear(ringNormals)
	for i = 2, #points do
		local before = points[i - 1]
		local after = if i < #points then points[i + 1] else points[i]
		local dir = after - before
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		ringCenters[i - 1] = points[i]
		ringNormals[i - 1] = dir
		buildRing(folder, i - 1, points[i], dir, i == #points)
	end

	-- pelampung mulai: tiang bendera + tombol
	local buoy = Instance.new("Part")
	buoy.Name = "PelampungMulai"
	buoy.Shape = Enum.PartType.Ball
	buoy.Size = Vector3.new(6, 6, 6)
	buoy.Anchored = true
	buoy.CanCollide = false
	buoy.Material = Enum.Material.SmoothPlastic
	buoy.Color = Color3.fromRGB(255, 220, 30)
	buoy.Position = Vector3.new(startPosition.X, JetSkiConfig.WATER_Y + 0.5, startPosition.Z)
	buoy.Parent = folder
	local pole = Instance.new("Part")
	pole.Name = "Tiang"
	pole.Anchored = true
	pole.CanCollide = false
	pole.Size = Vector3.new(0.6, 12, 0.6)
	pole.Color = Color3.fromRGB(240, 240, 245)
	pole.Position = buoy.Position + Vector3.new(0, 8, 0)
	pole.Parent = folder
	local flag = Instance.new("Part")
	flag.Name = "Bendera"
	flag.Anchored = true
	flag.CanCollide = false
	flag.Size = Vector3.new(0.3, 3, 5)
	flag.Color = Color3.fromRGB(235, 60, 60)
	flag.Position = pole.Position + Vector3.new(0, 4, 2.8)
	flag.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "TANTANGAN CINCIN"
	label.Parent = gui
	gui.Parent = pole
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartPrompt"
	prompt.ActionText = "Mulai Tantangan"
	prompt.ObjectText = "Cincin Jet Ski"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = JetSkiConfig.START_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = buoy
	prompt.Triggered:Connect(startRun)
	folder.Parent = parent
end

function JetSkiService.init()
	runRemote = Net.event(JetSkiConfig.REMOTE_RUN)
	local folder = Instance.new("Folder")
	folder.Name = "SewaJetSki"
	buildRentBoard(folder)
	folder.Parent = Workspace
	buildCourse()
end

function JetSkiService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		removeSki(player)
		lastRent[player] = nil
		lastRunEnd[player] = nil
		sessionBest[player.UserId] = nil
		refreshBoards()
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		for player, ski in skis do
			if
				ski.model.Parent == nil
				or ski.idle > JetSkiConfig.IDLE_SECONDS
				or ski.hull.Position.Y < JetSkiConfig.WATER_Y - 30
			then
				removeSki(player)
			else
				step(ski, dt)
			end
		end
		for player, run in runs do
			checkRun(player, run, dt)
		end
	end)
end

return JetSkiService
