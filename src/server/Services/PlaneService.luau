--!strict
-- PlaneService: pesawat kecil untuk pekerjaan Pilot. Pilot mengambil pesawat di papan "PESAWAT PILOT"
-- di tepi landasan bandara; pesawat muncul di ujung landasan. Cara terbangnya dibuat mudah
-- (lihat PlaneConfig): W/S menambah/mengurangi kecepatan, A/D belok, tinggi mengikuti kecepatan.
-- Fisika milik server; client hanya mengirim arah lewat VehicleSeat. Bentuk pesawat: mesh buatan
-- Blender di ServerStorage.AsetPesawat.pesawat (assets/blender/pesawat.fbx).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlaneConfig = require(Shared:WaitForChild("PlaneConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local PlaneService = {}

type Plane = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	move: LinearVelocity,
	turn: AngularVelocity,
	speed: number,
	target: number,
	idle: number,
	checkIn: number,
	clearance: number, -- jarak dasar pesawat ke tanah di bawahnya
}

local planes: { [Player]: Plane } = {}
local lastSpawn: { [Player]: number } = {}
local spawnCounter = 0

local HULL_SIZE = Vector3.new(4.6, 6.6, 24)
local HULL_PHYSICS = PhysicalProperties.new(0.2, 0, 0, 100, 1)
local FORCE = 400000

local function isPilot(player: Player): boolean
	local data = DataService.getData(player)
	return data ~= nil and data.jobs.current == PlaneConfig.JOB
end

local function buildPlane(owner: Player): Plane
	local model = Instance.new("Model")
	model.Name = "Plane_" .. owner.UserId
	model:SetAttribute(PlaneConfig.ATTR_OWNER, owner.UserId)
	model:SetAttribute(PlaneConfig.ATTR_SPEED, 0)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Badan tabrakan: satu kotak dari tanah sampai atap badan pesawat (sayap tidak ikut menabrak).
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = HULL_SIZE
	hull.CFrame = CFrame.new(0, HULL_SIZE.Y / 2, 0)
	hull.Color = Color3.fromRGB(245, 247, 250)
	hull.Material = Enum.Material.SmoothPlastic
	hull.CustomPhysicalProperties = HULL_PHYSICS
	hull.PivotOffset = CFrame.new(0, -HULL_SIZE.Y / 2, 0)
	hull.Parent = model
	model.PrimaryPart = hull

	local function weld(part: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hull
		w.Part1 = part
		w.Parent = part
	end

	local assets = ServerStorage:FindFirstChild("AsetPesawat")
	local template = if assets then assets:FindFirstChild("pesawat") else nil
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

	-- Kursi: pilot di kokpit kiri, kopilot di kanan, lalu empat kursi kabin.
	local spots = {
		Vector3.new(-0.95, 2.6, -8.2),
		Vector3.new(0.95, 2.6, -8.2),
		Vector3.new(-1, 2.3, -3.5),
		Vector3.new(1, 2.3, -3.5),
		Vector3.new(-1, 2.3, 0.5),
		Vector3.new(1, 2.3, 0.5),
	}
	local driveSeat: VehicleSeat? = nil
	for index, spot in spots do
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
		seat.Size = Vector3.new(1.6, 0.2, 1.4)
		seat.CFrame = CFrame.new(spot)
		seat.Transparency = if template then 1 else 0
		seat.Massless = true
		seat.CanCollide = false
		seat.CanTouch = false -- naik hanya lewat tombol (dicek server)
		weld(seat)
		seat.Parent = model

		-- Tombol naik ada di luar badan pesawat (pilot di dekat hidung, penumpang di pintu kabin).
		local door = Instance.new("Part")
		door.Name = "Door" .. index
		door.Size = Vector3.new(1, 1, 1)
		door.Transparency = 1
		door.CFrame = CFrame.new(if spot.X < 0 then -3.4 else 3.4, 3, spot.Z)
		door.Massless = true
		door.CanCollide = false
		door.CanTouch = false
		door.CanQuery = false
		weld(door)
		door.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EnterPrompt"
		prompt.ActionText = if index == 1 then "Terbangkan" else "Naik"
		prompt.ObjectText = "Pesawat"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = door
		prompt.Triggered:Connect(function(player: Player)
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local root = if character then character.PrimaryPart else nil
			if humanoid == nil or root == nil or humanoid.Health <= 0 or humanoid.SeatPart then
				return
			end
			if (root.Position - door.Position).Magnitude > 20 then
				return
			end
			if (seat :: any).Occupant then
				return
			end
			if index == 1 and player ~= owner then
				EconomyService.notify(player, "Hanya pilotnya yang boleh menerbangkan pesawat ini.")
				return
			end
			(seat :: any):Sit(humanoid)
		end)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = hull

	-- Maju searah hidung, nol ke samping. Sumbu tegak baru diberi gaya saat terbang atau turun.
	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = attachment
	move.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	move.MaxAxesForce = Vector3.new(FORCE, 0, FORCE)
	move.VectorVelocity = Vector3.zero
	move.Parent = hull

	-- Belok terhadap sumbu tegak; sekaligus menjaga pesawat tetap datar.
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 40000000
	turn.Parent = hull

	CollectionService:AddTag(model, PlaneConfig.TAG_PLANE)
	return {
		model = model,
		hull = hull,
		seat = driveSeat :: VehicleSeat,
		move = move,
		turn = turn,
		speed = 0,
		target = 0,
		idle = 0,
		checkIn = 0,
		clearance = 0,
	}
end

local function removePlane(player: Player)
	local plane = planes[player]
	if plane then
		planes[player] = nil
		plane.model:Destroy()
	end
end

-- Jarak dari dasar pesawat ke tanah/bangunan di bawahnya.
local function measureClearance(plane: Plane): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { plane.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local bottom = plane.hull.Position - Vector3.new(0, HULL_SIZE.Y / 2 - 0.5, 0)
	local hit = Workspace:Raycast(bottom, Vector3.new(0, -600, 0), params)
	return if hit then (bottom.Y - hit.Position.Y) - 0.5 else 600
end

local function step(plane: Plane, dt: number)
	local seat = plane.seat
	local throttle, steer = 0, 0
	if seat.Occupant then
		throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		plane.idle = 0
	else
		plane.idle += dt
		plane.target = math.max(0, plane.target - PlaneConfig.THROTTLE_RATE * dt) -- tanpa pilot: melambat dan turun
	end
	plane.checkIn -= dt
	if plane.checkIn <= 0 then
		plane.checkIn = 0.1
		plane.clearance = measureClearance(plane)
	end
	local onGround = plane.clearance < 1.5

	-- W/S menggeser kecepatan tujuan; dilepas = kecepatan dipertahankan.
	local minTarget = if onGround then -PlaneConfig.REVERSE_SPEED else 0
	plane.target = math.clamp(
		plane.target + throttle * PlaneConfig.THROTTLE_RATE * dt,
		minTarget,
		PlaneConfig.MAX_SPEED
	)
	local change = PlaneConfig.ACCELERATION * dt
	plane.speed += math.clamp(plane.target - plane.speed, -change, change)

	-- Tinggi mengikuti kecepatan: di bawah kecepatan lepas landas turun ke tanah.
	local lift = math.clamp(
		(plane.speed - PlaneConfig.TAKEOFF_SPEED)
			/ (PlaneConfig.MAX_SPEED - PlaneConfig.TAKEOFF_SPEED),
		0,
		1
	)
	local vertical, verticalForce = 0, 0
	if lift > 0 then
		local wantY = PlaneConfig.GROUND_Y + HULL_SIZE.Y / 2 + lift * PlaneConfig.CRUISE_HEIGHT
		vertical = math.clamp(
			(wantY - plane.hull.Position.Y) * 0.6,
			-PlaneConfig.DESCENT_SPEED,
			PlaneConfig.CLIMB_SPEED
		)
		verticalForce = FORCE
	elseif not onGround then
		vertical = -math.min(PlaneConfig.DESCENT_SPEED, 4 + plane.clearance * 0.6) -- mendarat pelan
		verticalForce = FORCE
	end
	plane.move.MaxAxesForce = Vector3.new(FORCE, verticalForce, FORCE)
	plane.move.VectorVelocity = Vector3.new(0, vertical, -plane.speed)

	-- Di luar batas peta pesawat berbelok sendiri sampai menghadap kembali ke kota.
	local position = plane.hull.Position
	local low, high = PlaneConfig.BOUNDS_MIN, PlaneConfig.BOUNDS_MAX
	if position.X < low.X or position.X > high.X or position.Z < low.Z or position.Z > high.Z then
		local center = (low + high) / 2
		local toCenter = Vector3.new(center.X - position.X, 0, center.Z - position.Z).Unit
		local look = plane.hull.CFrame.LookVector
		if look:Dot(toCenter) < 0.9 then
			steer = if look:Cross(toCenter).Y > 0 then -1 else 1
		end
	end
	local grip = math.clamp(plane.speed / 40, -1, 1)
	if math.abs(grip) < 0.3 then
		grip = if grip < -0.05 then -0.3 else 0.3
	end
	plane.turn.AngularVelocity = Vector3.new(0, -steer * PlaneConfig.TURN_RATE * grip, 0)
	plane.model:SetAttribute(PlaneConfig.ATTR_SPEED, math.floor(plane.speed + 0.5))
end

local function spawnPlane(player: Player)
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < PlaneConfig.SPAWN_COOLDOWN then
		EconomyService.notify(player, "Pelan-pelan ya, coba lagi sebentar.")
		return
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if
		root == nil
		or (root.Position - PlaneConfig.HANGAR_POSITION).Magnitude > PlaneConfig.HANGAR_RANGE
	then
		return
	end
	if not isPilot(player) then
		EconomyService.notify(
			player,
			"Pesawat ini untuk Pilot. Pilih pekerjaan Pilot di menu Pekerjaan ya."
		)
		return
	end
	lastSpawn[player] = now
	removePlane(player)
	local plane = buildPlane(player)
	spawnCounter = (spawnCounter % 4) + 1
	plane.model:PivotTo(PlaneConfig.SPAWN * CFrame.new(0, 0.1, (spawnCounter - 1) * 34))
	plane.model.Parent = Workspace
	plane.hull:SetNetworkOwner(nil)
	planes[player] = plane
	EconomyService.notify(
		player,
		"Pesawatmu siap di landasan! W tambah kecepatan, S kurangi, A/D belok. Pelankan untuk mendarat."
	)
end

-- ---------------------------------------------------------------- API server

-- true jika pemain sedang duduk di kursi pilot pesawatnya sendiri.
function PlaneService.isFlying(player: Player): boolean
	local plane = planes[player]
	if plane == nil then
		return false
	end
	local occupant = plane.seat.Occupant
	return occupant ~= nil and occupant.Parent == player.Character
end

-- Kecepatan pesawat pemain dan apakah rodanya di tanah.
function PlaneService.getState(player: Player): (number, boolean)
	local plane = planes[player]
	if plane == nil then
		return 0, false
	end
	return plane.speed, plane.clearance < 1.5
end

function PlaneService.init()
	local base = CFrame.new(PlaneConfig.HANGAR_POSITION)
	local folder = Instance.new("Folder")
	folder.Name = "PapanPilot"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.Metal
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	part(
		"Tiang",
		Vector3.new(0.8, 9, 0.8),
		base * CFrame.new(-4.4, 4.5, 0),
		Color3.fromRGB(90, 96, 110)
	)
	part(
		"Tiang",
		Vector3.new(0.8, 9, 0.8),
		base * CFrame.new(4.4, 4.5, 0),
		Color3.fromRGB(90, 96, 110)
	)
	local board = part(
		"Papan",
		Vector3.new(10, 3.4, 0.5),
		base * CFrame.new(0, 7.6, 0),
		Color3.fromRGB(40, 70, 130)
	)
	board.Material = Enum.Material.SmoothPlastic
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
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
		label.Text = "PESAWAT PILOT"
		label.Parent = gui
		gui.Parent = board
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ambil pesawat"
	prompt.ObjectText = "Pilot"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(spawnPlane)
	folder.Parent = Workspace
end

function PlaneService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		removePlane(player)
		lastSpawn[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		for player, plane in planes do
			if
				plane.model.Parent == nil
				or plane.idle > PlaneConfig.IDLE_SECONDS
				or plane.hull.Position.Y < -60
				or (plane.idle > 5 and not isPilot(player))
			then
				removePlane(player)
			else
				step(plane, dt)
			end
		end
	end)
end

return PlaneService
