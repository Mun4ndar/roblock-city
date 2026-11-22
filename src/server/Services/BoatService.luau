--!strict
-- BoatService: perahu motor sewaan di pantai. Pemain menyewa di papan "Sewa Perahu", perahu muncul
-- di laut, lalu dikemudikan dari kursi kemudi (W/S maju-mundur, A/D belok; lompat untuk turun).
-- Perahu mengapung di air Terrain; gerak dan beloknya diatur server (fisika milik server), jadi
-- client hanya mengirim arah lewat VehicleSeat. Bentuk perahu: mesh buatan Blender di
-- ServerStorage.AsetKapal.perahu (assets/blender/perahu.fbx); tanpa templat, perahu tampil kotak.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local BoatConfig = require(Shared:WaitForChild("BoatConfig"))

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local BoatService = {}

type Boat = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	move: LinearVelocity,
	turn: AngularVelocity,
	speed: number,
	idle: number,
	checkIn: number,
	blockedFront: boolean,
	blockedBack: boolean,
}

local boats: { [Player]: Boat } = {}
local lastRent: { [Player]: number } = {}
local slotCounter = 0

local HULL_PHYSICS = PhysicalProperties.new(0.3, 0.3, 0, 1, 1)
local SEAT_COLOR = Color3.fromRGB(236, 206, 150)

local function buildBoat(owner: Player): Boat
	local model = Instance.new("Model")
	model.Name = "Boat_" .. owner.UserId
	model:SetAttribute(BoatConfig.ATTR_OWNER, owner.UserId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Lambung tabrakan (tak terlihat bila ada mesh): kotak ringan yang mengapung, alasnya = lunas.
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = Vector3.new(5.4, 1, 14)
	hull.CFrame = CFrame.new(0, 0.5, 0)
	hull.Color = Color3.fromRGB(245, 247, 250)
	hull.Material = Enum.Material.SmoothPlastic
	hull.CustomPhysicalProperties = HULL_PHYSICS
	hull.PivotOffset = CFrame.new(0, -0.5, 0)
	hull.Parent = model
	model.PrimaryPart = hull

	local function weld(part: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hull
		w.Part1 = part
		w.Parent = part
	end

	local assets = ServerStorage:FindFirstChild("AsetKapal")
	local template = if assets then assets:FindFirstChild("perahu") else nil
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
				weld(clone)
				clone.Parent = model
			end
		end
	end

	-- Kursi: kemudi di kiri depan (di belakang setir), lalu penumpang.
	local spots = {
		Vector3.new(-1.2, 2.0, 0.4),
		Vector3.new(1.2, 2.0, 0.4),
		Vector3.new(-1.2, 2.0, 5.2),
		Vector3.new(1.2, 2.0, 5.2),
	}
	local driveSeat: VehicleSeat? = nil
	for index = 1, math.min(BoatConfig.SEATS, #spots) do
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
		seat.Size = Vector3.new(2, 0.2, 1.4)
		seat.CFrame = CFrame.new(spots[index])
		seat.Color = SEAT_COLOR
		seat.Transparency = if template then 1 else 0
		seat.Massless = true
		seat.CanCollide = false
		seat.CanTouch = false -- naik hanya lewat tombol (dicek server)
		weld(seat)
		seat.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EnterPrompt"
		prompt.ActionText = if index == 1 then "Kemudikan" else "Naik"
		prompt.ObjectText = "Perahu Motor"
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
				EconomyService.notify(player, "Hanya penyewa yang boleh mengemudikan perahu ini.")
				return
			end
			(seat :: any):Sit(humanoid)
		end)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = hull

	-- Gerak maju-mundur searah perahu dan nol ke samping; naik-turun tetap ikut air.
	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = attachment
	move.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	move.MaxAxesForce = Vector3.new(60000, 0, 60000) -- sumbu tegak bebas: perahu tetap mengapung
	move.VectorVelocity = Vector3.zero
	move.Parent = hull

	-- Belok terhadap sumbu tegak; sekaligus menahan perahu supaya tidak oleng atau terbalik.
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 4000000
	turn.Parent = hull

	CollectionService:AddTag(model, BoatConfig.TAG_BOAT)
	return {
		model = model,
		hull = hull,
		seat = driveSeat :: VehicleSeat,
		move = move,
		turn = turn,
		speed = 0,
		idle = 0,
		checkIn = 0,
		blockedFront = false,
		blockedBack = false,
	}
end

local function removeBoat(player: Player)
	local boat = boats[player]
	if boat then
		boats[player] = nil
		boat.model:Destroy()
	end
end

-- true jika di titik itu bukan air (pasir, dermaga, perahu lain, tepi peta): perahu tidak boleh maju ke sana.
local function isBlocked(boat: Boat, offsetZ: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { boat.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local origin = (boat.hull.CFrame * CFrame.new(0, 0, offsetZ)).Position
	local hit = Workspace:Raycast(
		Vector3.new(origin.X, BoatConfig.WATER_Y + 5, origin.Z),
		Vector3.new(0, -12, 0),
		params
	)
	-- tanpa hasil = di luar tepi laut peta: juga tidak boleh
	return hit == nil
		or hit.Material ~= Enum.Material.Water
		or hit.Position.Y < BoatConfig.WATER_Y - 1.5
end

local function step(boat: Boat, dt: number)
	local seat = boat.seat
	local throttle, steer = 0, 0
	if seat.Occupant then
		throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		boat.idle = 0
	else
		boat.idle += dt
	end
	boat.checkIn -= dt
	if boat.checkIn <= 0 then
		boat.checkIn = 0.1
		-- makin kencang, makin jauh ke depan yang diperiksa
		boat.blockedFront = isBlocked(boat, -9)
			or isBlocked(boat, -9 - math.max(boat.speed, 0) * 0.4)
		boat.blockedBack = isBlocked(boat, 9)
	end
	local target = if throttle > 0
		then throttle * BoatConfig.MAX_SPEED
		else throttle * BoatConfig.REVERSE_SPEED
	if boat.blockedFront then
		target = math.min(target, 0)
		boat.speed = math.min(boat.speed, 0)
	end
	if boat.blockedBack then
		target = math.max(target, 0)
		boat.speed = math.max(boat.speed, 0)
	end
	local change = BoatConfig.ACCELERATION * dt
	boat.speed += math.clamp(target - boat.speed, -change, change)
	boat.move.VectorVelocity = Vector3.new(0, 0, -boat.speed)
	-- belok penuh saat melaju (saat mundur arahnya terbalik); saat diam masih bisa berputar pelan
	-- supaya perahu yang mentok di pantai atau tepi laut bisa diarahkan lagi
	local grip = math.clamp(boat.speed / 12, -1, 1)
	if math.abs(grip) < 0.35 then
		grip = if grip < -0.05 then -0.35 else 0.35
	end
	boat.turn.AngularVelocity = Vector3.new(0, -steer * BoatConfig.TURN_RATE * grip, 0)
end

local function rent(player: Player)
	local now = os.clock()
	if lastRent[player] and now - lastRent[player] < BoatConfig.RENT_COOLDOWN then
		EconomyService.notify(player, "Pelan-pelan ya, coba lagi sebentar.")
		return
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if
		root == nil
		or (root.Position - BoatConfig.RENT_POSITION).Magnitude > BoatConfig.RENT_RANGE
	then
		return
	end
	if not EconomyService.trySpend(player, BoatConfig.RENT_PRICE, "boat:rent") then
		EconomyService.notify(
			player,
			"Uangmu belum cukup. Sewa perahu " .. Format.money(BoatConfig.RENT_PRICE) .. "."
		)
		return
	end
	lastRent[player] = now
	removeBoat(player)
	local boat = buildBoat(player)
	slotCounter = (slotCounter % BoatConfig.SPAWN_SLOTS) + 1
	local offset = (slotCounter - (BoatConfig.SPAWN_SLOTS + 1) / 2) * BoatConfig.SPAWN_SPACING
	boat.model:PivotTo(BoatConfig.SPAWN * CFrame.new(offset, 0.2, 0))
	boat.model.Parent = Workspace
	boat.hull:SetNetworkOwner(nil)
	boats[player] = boat
	EconomyService.notify(
		player,
		'Perahumu siap di laut! Berenang ke sana, tekan "Kemudikan", lalu lompat untuk turun.'
	)
end

function BoatService.init()
	local base = CFrame.new(BoatConfig.RENT_POSITION)
	local folder = Instance.new("Folder")
	folder.Name = "SewaPerahu"
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
	part(
		"Tiang",
		Vector3.new(0.8, 9, 0.8),
		base * CFrame.new(0, 4.5, -3.4),
		Color3.fromRGB(120, 85, 55)
	)
	part(
		"Tiang",
		Vector3.new(0.8, 9, 0.8),
		base * CFrame.new(0, 4.5, 3.4),
		Color3.fromRGB(120, 85, 55)
	)
	local board = part(
		"Papan",
		Vector3.new(0.5, 3.4, 8),
		base * CFrame.new(0, 7.6, 0),
		Color3.fromRGB(40, 110, 200)
	)
	board.Material = Enum.Material.SmoothPlastic
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "SEWA PERAHU"
		label.Parent = gui
		gui.Parent = board
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sewa " .. Format.money(BoatConfig.RENT_PRICE)
	prompt.ObjectText = "Perahu Motor"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(rent)
	folder.Parent = Workspace
end

function BoatService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		removeBoat(player)
		lastRent[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		for player, boat in boats do
			if
				boat.model.Parent == nil
				or boat.idle > BoatConfig.IDLE_SECONDS
				or boat.hull.Position.Y < BoatConfig.WATER_Y - 30
			then
				removeBoat(player)
			else
				step(boat, dt)
			end
		end
	end)
end

return BoatService
