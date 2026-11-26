--!strict
--[[
	FerryService: kapal feri besar (mesh Meshy + tekstur, Workspace.Map.Beach.Pelabuhan.KapalFeriMeshy).
	  * Bergoyang pelan di tambatan (angkat, oleng, angguk) sebagai pemanis.
	  * Bisa dinaiki: prompt "Naik Feri" di ujung dermaga. Penumpang duduk di kursi geladak, feri menunggu
	    BOARD_SECONDS, lalu berlayar satu putaran lintasan oval (lurus ke timur, putar balik, lurus ke barat,
	    putar balik) dan kembali ke tambatan. Di sana penumpang diturunkan di ujung dermaga.
	Haluan mesh = +X (sumbu panjang). Kursi dibuat saat mulai dengan sinar ke geladak, jadi mengikuti modelnya.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local FerryService = {}

local BOARD_SECONDS = 12 -- menunggu penumpang sebelum berangkat
local CRUISE_SECONDS = 62 -- lama satu putaran
local LEG = 300 -- panjang lintasan lurus (stud)
local RADIUS = 30 -- jari-jari putar balik
local DOCK_SPOT = Vector3.new(1304, 3.6, 628) -- tempat penumpang diturunkan (ujung dermaga)
local PROMPT_SPOT = Vector3.new(1304, 2.6, 634)
local SEAT_SPOTS = {
	Vector2.new(-12, -6),
	Vector2.new(-12, -2),
	Vector2.new(-12, 2),
	Vector2.new(-12, 6),
	Vector2.new(12, -4),
	Vector2.new(12, 4),
}

type Passenger = { player: Player, jump: number }

local state = "docked" -- "docked" | "boarding" | "cruising"
local passengers: { [Player]: Passenger } = {}
local seats: { { part: Seat, rel: CFrame } } = {}
local cruiseEndsAt = 0

-- panjang lintasan oval
local ARC = math.pi * RADIUS
local TOTAL = 2 * LEG + 2 * ARC

-- posisi (x, z) dan arah haluan (fx, fz) di jarak s sepanjang lintasan, mulai dari tambatan
local function pathAt(start: Vector3, s: number): (Vector3, Vector2)
	s %= TOTAL
	if s < LEG then
		return Vector3.new(start.X + s, 0, start.Z), Vector2.new(1, 0)
	end
	s -= LEG
	if s < ARC then
		local t = s / RADIUS
		local cx, cz = start.X + LEG, start.Z + RADIUS
		return Vector3.new(cx + RADIUS * math.sin(t), 0, cz - RADIUS * math.cos(t)), Vector2.new(math.cos(t), math.sin(t))
	end
	s -= ARC
	if s < LEG then
		return Vector3.new(start.X + LEG - s, 0, start.Z + 2 * RADIUS), Vector2.new(-1, 0)
	end
	s -= LEG
	local t = s / RADIUS
	local cx, cz = start.X, start.Z + RADIUS
	return Vector3.new(cx - RADIUS * math.sin(t), 0, cz + RADIUS * math.cos(t)), Vector2.new(-math.cos(t), -math.sin(t))
end

local function root(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
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
		human.Sit = false
	end
	if toDock then
		-- tunggu las kursi lepas dulu, baru pindahkan ke dermaga (kalau langsung, las menarik pemain kembali)
		task.delay(0.25, function()
			local r = root(player)
			if r and player.Character then
				player.Character:PivotTo(CFrame.lookAt(DOCK_SPOT, DOCK_SPOT + Vector3.new(0, 0, -1)))
				r.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
end

local function board(player: Player)
	if passengers[player] ~= nil then
		return
	end
	local _, human = root(player)
	if human == nil or human.Health <= 0 then
		return
	end
	local free: Seat? = nil
	for _, entry in seats do
		if seatFree(entry.part) then
			free = entry.part
			break
		end
	end
	if free == nil then
		EconomyService.notify(player, "Feri penuh. Tunggu putaran berikutnya ya!")
		return
	end
	passengers[player] = { player = player, jump = human.JumpHeight }
	human.JumpHeight = 0
	free:Sit(human)
	human.Died:Once(function()
		unboard(player, false)
	end)
end

function FerryService.init() end

function FerryService.start()
	local pelabuhan = Workspace:WaitForChild("Map"):WaitForChild("Beach"):WaitForChild("Pelabuhan")
	local ship = pelabuhan:WaitForChild("KapalFeriMeshy", 30)
	if ship == nil or not ship:IsA("Model") then
		return
	end
	CollectionService:AddTag(ship, "Kapal")
	local hull = ship.PrimaryPart
	if hull == nil then
		return
	end
	local base = hull.CFrame
	local baseRot = base - base.Position
	local start = base.Position

	-- kursi di geladak: tinggi geladak dari sinar ke bawah
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ship }
	for _, spot in SEAT_SPOTS do
		local hit = Workspace:Raycast(Vector3.new(start.X + spot.X, start.Y + 40, start.Z + spot.Y), Vector3.new(0, -80, 0), params)
		if hit then
			local seat = Instance.new("Seat")
			seat.Name = "KursiFeri"
			seat.Anchored = true
			seat.CanCollide = false
			seat.Transparency = 1
			seat.Size = Vector3.new(2.4, 0.4, 2.4)
			local at = Vector3.new(start.X + spot.X, hit.Position.Y + 0.2, start.Z + spot.Y)
			local cf = CFrame.lookAt(at, at + Vector3.new(1, 0, 0)) -- menghadap haluan (+X)
			seat.CFrame = cf
			seat.Parent = ship
			table.insert(seats, { part = seat, rel = base:ToObjectSpace(cf) })
		end
	end

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
		for _, info in passengers do
			local _, human = root(info.player)
			if human and human.SeatPart == nil then
				for _, entry in seats do
					if seatFree(entry.part) then
						entry.part:Sit(human)
						break
					end
				end
			end
		end
		cruiseStart = os.clock()
		cruiseEndsAt = cruiseStart + CRUISE_SECONDS
	end

	prompt.Triggered:Connect(function(player: Player)
		if state == "cruising" then
			EconomyService.notify(
				player,
				`Feri sedang berlayar. Kembali dalam {math.max(1, math.ceil(cruiseEndsAt - os.clock()))} detik.`
			)
			return
		end
		board(player)
		if passengers[player] == nil then
			return
		end
		if state == "docked" then
			state = "boarding"
			task.delay(BOARD_SECONDS, depart)
		end
		EconomyService.notify(player, "Selamat naik feri! Duduk manis, kita segera berangkat.")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		passengers[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		local cruising = state == "cruising"
		if not cruising and acc < 1 / 20 then
			return
		end
		acc = 0
		local t = Workspace:GetServerTimeNow()
		local lift = math.sin(t * 0.9) * 0.35
		local roll = math.sin(t * 0.7) * math.rad(1.2)
		local pitch = math.sin(t * 0.5 + 1) * math.rad(0.7)
		local position = Vector3.new(start.X, 0, start.Z)
		local heading = Vector2.new(1, 0)
		if cruising then
			local u = math.clamp((os.clock() - cruiseStart) / CRUISE_SECONDS, 0, 1)
			local eased = u * u * (3 - 2 * u)
			position, heading = pathAt(start, eased * TOTAL)
			if u >= 1 then
				state = "docked"
				prompt.Enabled = true
				for player in passengers do
					unboard(player, true)
				end
				heading = Vector2.new(1, 0)
				position = Vector3.new(start.X, 0, start.Z)
			end
		end
		local yaw = math.atan2(-heading.Y, heading.X)
		local hullCF = CFrame.new(position.X, start.Y + lift, position.Z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(roll, 0, pitch)
			* baseRot
		hull.CFrame = hullCF
		for _, entry in seats do
			entry.part.CFrame = hullCF * entry.rel
		end
	end)
end

return FerryService
