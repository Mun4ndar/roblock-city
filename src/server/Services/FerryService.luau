--!strict
--[[
	FerryService: feri penumpang buatan Blender (Workspace.Map.Beach.Pelabuhan.Feri, dibangun map/BuildFerry).
	  * Bergoyang pelan di tambatan (angkat, oleng, angguk) sebagai pemanis.
	  * Bisa dinaiki: prompt "Naik Feri" di ujung dermaga. Penumpang duduk di kursi bangku geladak, feri menunggu
	    BOARD_SECONDS, lalu berlayar satu putaran lintasan oval (lurus ke timur, putar balik, lurus ke barat,
	    putar balik) dan kembali ke tambatan. Di sana penumpang diturunkan di ujung dermaga.
	Feri BUKAN fisika terapung: seluruh badan dilas ke satu akar tak terlihat yang dikendalikan AlignPosition +
	AlignOrientation menuju titik lintasan (server pemilik fisika), jadi tidak bisa tenggelam dan geraknya mulus
	di klien. Kursi (Seat bernama KursiFeri) sudah ada di model; haluan = LookVector (-Z) model.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local FerryService = {}

local BOARD_SECONDS = 12 -- menunggu penumpang sebelum berangkat
local CRUISE_SECONDS = 70 -- lama satu putaran
local LEG = 300 -- panjang lintasan lurus (stud)
local RADIUS = 36 -- jari-jari putar balik
local WATER_Y = -1.6 -- garis air feri
local DOCK_SPOT = Vector3.new(1304, 3.6, 628) -- tempat penumpang diturunkan (ujung dermaga)
local PROMPT_SPOT = Vector3.new(1304, 2.6, 634)

type Passenger = { player: Player, jump: number, power: number }

local state = "docked" -- "docked" | "boarding" | "cruising"
local passengers: { [Player]: Passenger } = {}
local seats: { Seat } = {}
local cruiseEndsAt = 0

-- panjang lintasan oval
local ARC = math.pi * RADIUS
local TOTAL = 2 * LEG + 2 * ARC

-- posisi (x, z) dan arah haluan (fx, fz) di jarak s sepanjang lintasan, mulai dari tambatan (haluan = +X)
local function pathAt(start: Vector3, s: number): (Vector3, Vector2)
	s %= TOTAL
	if s < LEG then
		return Vector3.new(start.X + s, 0, start.Z), Vector2.new(1, 0)
	end
	s -= LEG
	if s < ARC then
		local t = s / RADIUS
		local cx, cz = start.X + LEG, start.Z + RADIUS
		return Vector3.new(cx + RADIUS * math.sin(t), 0, cz - RADIUS * math.cos(t)),
			Vector2.new(math.cos(t), math.sin(t))
	end
	s -= ARC
	if s < LEG then
		return Vector3.new(start.X + LEG - s, 0, start.Z + 2 * RADIUS), Vector2.new(-1, 0)
	end
	s -= LEG
	local t = s / RADIUS
	local cx, cz = start.X, start.Z + RADIUS
	return Vector3.new(cx - RADIUS * math.sin(t), 0, cz + RADIUS * math.cos(t)),
		Vector2.new(-math.cos(t), -math.sin(t))
end

local function root(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?,
		character:FindFirstChildOfClass("Humanoid")
end

local function seatFree(seat: Seat): boolean
	return seat.Occupant == nil
end

local function unboard(player: Player, toDock: boolean)
	local info = passengers[player]
	if info == nil then
		return
	end
	passengers[player] = nil
	local _, human = root(player)
	if human then
		human.JumpHeight = info.jump
		human.JumpPower = info.power
		human.Sit = false
	end
	if toDock then
		-- tunggu las kursi lepas dulu, baru pindahkan ke dermaga (kalau langsung, las menarik pemain kembali)
		task.delay(0.3, function()
			local r = root(player)
			if r and player.Character then
				player.Character:PivotTo(CFrame.lookAt(DOCK_SPOT, DOCK_SPOT + Vector3.new(0, 0, -1)))
				r.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
end

local function sitOn(seat: Seat, human: Humanoid, character: Model)
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(human)
end

local function board(player: Player)
	if passengers[player] ~= nil then
		return
	end
	local _, human = root(player)
	if human == nil or human.Health <= 0 or human.SeatPart ~= nil or player.Character == nil then
		return
	end
	local free: Seat? = nil
	for _, seat in seats do
		if seatFree(seat) then
			free = seat
			break
		end
	end
	if free == nil then
		EconomyService.notify(player, "Feri penuh. Tunggu putaran berikutnya ya!")
		return
	end
	passengers[player] = { player = player, jump = human.JumpHeight, power = human.JumpPower }
	human.JumpHeight = 0
	human.JumpPower = 0
	sitOn(free, human, player.Character)
	human.Died:Once(function()
		unboard(player, false)
	end)
end

local function makeWake(hull: BasePart, offset: Vector3, size: number): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "Ombak"
	attachment.Position = offset
	attachment.Parent = hull
	local wake = Instance.new("ParticleEmitter")
	wake.Name = "Buih"
	wake.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
	wake.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.6),
		NumberSequenceKeypoint.new(1, size * 2.2),
	})
	wake.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	wake.Lifetime = NumberRange.new(1.6, 2.6)
	wake.Speed = NumberRange.new(2, 5)
	wake.SpreadAngle = Vector2.new(60, 8)
	wake.Rate = 26
	wake.Rotation = NumberRange.new(0, 360)
	wake.EmissionDirection = Enum.NormalId.Top
	wake.Enabled = false
	wake.Parent = attachment
	return wake
end

function FerryService.init() end

function FerryService.start()
	local pelabuhan = Workspace:WaitForChild("Map"):WaitForChild("Beach"):WaitForChild("Pelabuhan")
	local ship = pelabuhan:WaitForChild("Feri", 30)
	if ship == nil or not ship:IsA("Model") then
		warn("[Feri] model Feri tidak ditemukan")
		return
	end
	CollectionService:AddTag(ship, "Kapal")
	local hull = ship.PrimaryPart
	if hull == nil then
		warn("[Feri] Feri tanpa PrimaryPart")
		return
	end
	local berth = hull.CFrame
	local start = berth.Position

	-- semua bagian: dilas ke akar, ringan, tanpa tabrakan; lalu akar dilepas dari jangkar dan dikendalikan constraint
	for _, inst in ship:GetDescendants() do
		if inst:IsA("BasePart") then
			if inst ~= hull then
				inst.Anchored = false
				inst.Massless = true
				inst.CanCollide = false
				inst.CanTouch = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hull
				weld.Part1 = inst
				weld.Parent = inst
			end
			if inst:IsA("Seat") then
				table.insert(seats, inst)
			end
		end
	end
	table.sort(seats, function(a: Seat, b: Seat)
		return a.Name < b.Name or (a.Name == b.Name and a.Position.Z > b.Position.Z)
	end)
	hull.CanCollide = false
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0, 1, 1)

	local pose = Instance.new("Attachment")
	pose.Name = "Pose"
	pose.Parent = hull
	local move = Instance.new("AlignPosition")
	move.Name = "Posisi"
	move.Mode = Enum.PositionAlignmentMode.OneAttachment
	move.Attachment0 = pose
	move.Position = berth.Position
	move.MaxForce = 1e10
	move.MaxVelocity = 200
	move.Responsiveness = 18
	move.ApplyAtCenterOfMass = true
	move.Parent = hull
	local turn = Instance.new("AlignOrientation")
	turn.Name = "Arah"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = pose
	turn.CFrame = berth.Rotation
	turn.MaxTorque = 1e10
	turn.MaxAngularVelocity = 20
	turn.Responsiveness = 18
	turn.Parent = hull
	hull.Anchored = false
	hull:SetNetworkOwner(nil)

	local wakes = {
		makeWake(hull, Vector3.new(0, -1.2, 30), 3.4), -- buritan
		makeWake(hull, Vector3.new(-7, -1.2, -22), 2.2),
		makeWake(hull, Vector3.new(7, -1.2, -22), 2.2),
	}

	-- prompt naik di ujung dermaga
	local gate = Instance.new("Part")
	gate.Name = "GerbangFeri"
	gate.Anchored = true
	gate.CanCollide = false
	gate.CanQuery = false
	gate.Transparency = 1
	gate.Size = Vector3.new(6, 4, 6)
	gate.CFrame = CFrame.new(PROMPT_SPOT)
	gate.Parent = pelabuhan
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NaikFeri"
	prompt.ActionText = "Naik Feri"
	prompt.ObjectText = "Feri Pelabuhan"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate

	local cruiseStart = 0
	local function depart()
		state = "cruising"
		prompt.Enabled = false
		for _, w in wakes do
			w.Enabled = true
		end
		cruiseStart = os.clock()
		cruiseEndsAt = cruiseStart + CRUISE_SECONDS
	end

	prompt.Triggered:Connect(function(player: Player)
		if state == "cruising" then
			EconomyService.notify(
				player,
				`Feri sedang berlayar. Kembali dalam {math.max(
					1,
					math.ceil(cruiseEndsAt - os.clock())
				)} detik.`
			)
			return
		end
		board(player)
		if passengers[player] == nil then
			return
		end
		if state == "docked" then
			state = "boarding"
			ship:SetAttribute("BoardingEndsAt", Workspace:GetServerTimeNow() + BOARD_SECONDS)
			task.delay(BOARD_SECONDS, depart)
		end
		EconomyService.notify(player, "Selamat naik feri! Duduk manis, kita segera berangkat.")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		passengers[player] = nil
	end)

	ship:SetAttribute("State", state)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		local cruising = state == "cruising"
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local t = Workspace:GetServerTimeNow()
		local lift = math.sin(t * 0.9) * 0.3
		local roll = math.sin(t * 0.7) * math.rad(1.1)
		local pitch = math.sin(t * 0.5 + 1) * math.rad(0.6)
		local position = Vector3.new(start.X, 0, start.Z)
		local heading = Vector2.new(1, 0)
		if cruising then
			local u = math.clamp((os.clock() - cruiseStart) / CRUISE_SECONDS, 0, 1)
			local eased = u * u * (3 - 2 * u)
			position, heading = pathAt(start, eased * TOTAL)
			if u >= 1 then
				state = "docked"
				ship:SetAttribute("State", state)
				prompt.Enabled = true
				for _, w in wakes do
					w.Enabled = false
				end
				for player in passengers do
					unboard(player, true)
				end
				heading = Vector2.new(1, 0)
				position = Vector3.new(start.X, 0, start.Z)
			end
		end
		-- haluan model = LookVector (-Z)
		local pos = Vector3.new(position.X, WATER_Y + lift, position.Z)
		local target = CFrame.lookAt(pos, pos + Vector3.new(heading.X, 0, heading.Y))
			* CFrame.Angles(pitch, 0, roll)
		move.Position = target.Position
		turn.CFrame = target.Rotation
		-- penumpang yang belum duduk (mis. kursi lepas) dipaksa duduk lagi saat berlayar
		if cruising then
			for _, info in passengers do
				local _, human = root(info.player)
				if human and human.SeatPart == nil and info.player.Character then
					for _, seat in seats do
						if seatFree(seat) then
							sitOn(seat, human, info.player.Character)
							break
						end
					end
				end
			end
		end
	end)
	ship:SetAttribute("State", state)
end

return FerryService
