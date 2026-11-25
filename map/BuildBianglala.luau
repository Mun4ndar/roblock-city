--!strict
--[[
	ROBLOCK CITY: bianglala dermaga pantai (Blender: tools/blender/bianglala.py).
	Templat mentah di ServerStorage: BianglalaStatikMentah (asset 135896741561405), BianglalaPutarMentah
	(114841013950399), BianglalaKabinMentah (115044248602339).
	Hasil: Workspace.Map.Beach.Dermaga.Bianglala (model lama disalin ke ServerStorage.CadanganPeta.BianglalaLama).
	  - rangka A-frame diam (anchored) + sumbu "Poros"
	  - roda: semua MeshPart di-weld ke "Hub"; Hub berputar lewat HingeConstraint motor (tag FerrisMotor,
	    dikendalikan FerrisService: putar 45 derajat, berhenti, ulangi)
	  - 8 kabin: tiap kabin tergantung di pin roda lewat sendi bebas + AlignOrientation (tetap tegak); dua
	    Seat berhadapan di tiap kabin. Semua bagian bergerak ada di grup tabrakan "Ferris".
	Catatan impor FBX: koordinat Blender (x, y, z) -> dunia (-x, z, y) relatif terhadap satu bagian acuan; kita
	susun lewat CFrame relatif ke bagian acuan (WsWhite / WhHub / KbFloor).
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GROUP = "Ferris"
local HUB = Vector3.new(1924, 46, -120) -- pusat poros
local GROUND_Y = 3.0 -- permukaan lantai dermaga
local R = 36 -- jari-jari titik gantung
local DROP = 6.0 -- pusat lantai kabin di bawah titik gantung
local CABINS = 8

local function c3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local SP, MT, NE, GL = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Glass

local STATIC_LOOK: { [string]: { any } } = {
	WsWhite = { c3(240, 240, 246), SP, 0 },
	WsDark = { c3(50, 54, 66), MT, 0 },
	WsBlue = { c3(60, 130, 225), MT, 0 },
}
local WHEEL_LOOK: { [string]: { any } } = {
	WhHub = { c3(230, 232, 240), MT, 0 },
	WhRim = { c3(245, 100, 175), SP, 0 },
	WhRimIn = { c3(130, 205, 240), SP, 0 },
	WhSpoke = { c3(245, 245, 250), SP, 0 },
	WhLampA = { c3(255, 130, 200), NE, 0 },
	WhLampB = { c3(255, 225, 80), NE, 0 },
	WhPin = { c3(80, 84, 100), MT, 0 },
	WhCap = { c3(255, 205, 60), SP, 0 },
}
local CABIN_LOOK: { [string]: { any } } = {
	KbFloor = { c3(200, 200, 210), SP, 0 },
	KbHang = { c3(80, 84, 100), MT, 0 },
	KbDark = { c3(50, 54, 66), MT, 0 },
	KbWall = { c3(245, 245, 250), SP, 0 },
	KbGlass = { c3(160, 215, 240), GL, 0.5 },
	KbSeat = { c3(60, 100, 200), SP, 0 },
	KbSeatTop = { c3(255, 205, 60), SP, 0 },
	KbLamp = { c3(255, 248, 225), NE, 0 },
}
local CABIN_COLORS = {
	c3(245, 100, 175),
	c3(255, 205, 60),
	c3(90, 215, 170),
	c3(90, 160, 245),
	c3(255, 150, 60),
	c3(170, 120, 235),
	c3(235, 80, 90),
	c3(60, 200, 215),
}

local function setup(part: BasePart, anchored: boolean, group: string?)
	part.Anchored = anchored
	part.CanTouch = false
	part.CanQuery = false
	if group then
		part.CollisionGroup = group
	end
end

local function hidden(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function copyMeshes(
	raw: Instance,
	look: { [string]: { any } },
	refName: string,
	base: CFrame,
	parent: Instance,
	anchored: boolean,
	group: string?,
	skip: { [string]: boolean }?
): { MeshPart }
	local ref = raw:FindFirstChild(refName) :: MeshPart
	local made: { MeshPart } = {}
	for _, d in raw:GetChildren() do
		local spec = look[d.Name]
		if d:IsA("MeshPart") and (spec or (skip and skip[d.Name] == false)) then
			local part = d:Clone()
			part:ClearAllChildren()
			part.CFrame = base * ref.CFrame:ToObjectSpace(d.CFrame)
			if spec then
				part.Color, part.Material, part.Transparency = spec[1], spec[2], spec[3]
			end
			setup(part, anchored, group)
			part.CanCollide = false
			part.Massless = not anchored
			part.CastShadow = part.Transparency == 0
			part.Parent = parent
			table.insert(made, part)
		end
	end
	return made
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

local function attach(parent: BasePart, name: string, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = offset
	a.Parent = parent
	return a
end

return function(): number
	local staticRaw = ServerStorage:FindFirstChild("BianglalaStatikMentah")
	local wheelRaw = ServerStorage:FindFirstChild("BianglalaPutarMentah")
	local cabinRaw = ServerStorage:FindFirstChild("BianglalaKabinMentah")
	local dermaga = Workspace.Map.Beach:FindFirstChild("Dermaga")
	if staticRaw == nil or wheelRaw == nil or cabinRaw == nil or dermaga == nil then
		warn("[BuildBianglala] templat atau Dermaga tidak ada")
		return 0
	end
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
	local backups = ServerStorage:FindFirstChild("CadanganPeta")
	local old = dermaga:FindFirstChild("Bianglala")
	if old then
		if backups and backups:FindFirstChild("BianglalaLama") == nil then
			local copy = old:Clone()
			copy.Name = "BianglalaLama"
			copy.Parent = backups
		end
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Bianglala"

	-- ------------------------------------------------ rangka diam
	copyMeshes(
		staticRaw,
		STATIC_LOOK,
		"WsWhite",
		CFrame.new(HUB.X, GROUND_Y + 21.25, HUB.Z),
		model,
		true,
		nil,
		nil
	)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local a = Vector3.new(HUB.X + sx * 8, GROUND_Y + 0.5, HUB.Z + sy * 25)
			local b = Vector3.new(HUB.X + sx * 8, HUB.Y - 1, HUB.Z + sy * 1.2)
			hidden(
				"KakiRangka",
				Vector3.new(2.3, 2.3, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				model
			).CanCollide = true
		end
	end
	local poros = hidden("Poros", Vector3.new(1, 1, 1), CFrame.new(HUB), model)
	poros.Anchored = true

	-- ------------------------------------------------ roda
	local hub = hidden("Hub", Vector3.new(2, 2, 2), CFrame.new(HUB), model)
	hub.Anchored = false
	hub.CustomPhysicalProperties = PhysicalProperties.new(20, 0.3, 0.5)
	hub.CollisionGroup = GROUP
	local wheelParts = copyMeshes(wheelRaw, WHEEL_LOOK, "WhHub", CFrame.new(HUB), model, false, GROUP, nil)
	for _, part in wheelParts do
		weld(hub, part)
	end
	local motorPoros = attach(poros, "SumbuPoros", Vector3.zero)
	local motorHub = attach(hub, "SumbuHub", Vector3.zero)
	local motor = Instance.new("HingeConstraint")
	motor.Name = "MotorRoda"
	motor.Attachment0 = motorPoros
	motor.Attachment1 = motorHub
	motor.ActuatorType = Enum.ActuatorType.Motor
	motor.MotorMaxTorque = 1e9
	motor.MotorMaxAcceleration = 0.35
	motor.AngularVelocity = 0
	motor.Parent = poros
	CollectionService:AddTag(motor, "FerrisMotor")

	-- ------------------------------------------------ kabin
	local cabinFloor = cabinRaw:FindFirstChild("KbFloor") :: MeshPart
	for i = 0, CABINS - 1 do
		local a = math.rad(360 / CABINS * i)
		local rim = Vector3.new(0, R * math.cos(a), R * math.sin(a)) -- titik gantung relatif ke poros
		local hanger = HUB + rim
		local cabin = Instance.new("Model")
		cabin.Name = "Kabin" .. (i + 1)
		local color = CABIN_COLORS[i % #CABIN_COLORS + 1]
		local look = table.clone(CABIN_LOOK)
		look.KbBody = { color, SP, 0 }
		look.KbRoof = { color:Lerp(Color3.new(1, 1, 1), 0.1), SP, 0 }
		local floorCF = CFrame.new(hanger - Vector3.new(0, DROP, 0))
		local parts = copyMeshes(cabinRaw, look, "KbFloor", floorCF, cabin, false, GROUP, nil)
		local core = hidden("Inti", Vector3.new(6, 0.4, 7), floorCF, cabin)
		core.Anchored = false
		core.CanCollide = true
		core.CollisionGroup = GROUP
		core.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.5)
		for _, part in parts do
			weld(core, part)
		end
		local floorTop = hanger.Y - DROP + 0.2
		local function solid(name: string, size: Vector3, pos: Vector3)
			local p = hidden(name, size, CFrame.new(pos), cabin)
			p.CanCollide = true
			p.Massless = true
			p.CollisionGroup = GROUP
			weld(core, p)
		end
		for _, sz in { -1, 1 } do
			solid("DindingUjung", Vector3.new(5.4, 4.7, 0.3), Vector3.new(hanger.X, floorTop + 2.35, hanger.Z + sz * 3.3))
			for _, sx in { -1, 1 } do
				solid(
					"DindingSamping",
					Vector3.new(0.3, 1.5, 1.9),
					Vector3.new(hanger.X + sx * 2.8, floorTop + 0.75, hanger.Z + sz * 2.55)
				)
			end
			local seat = Instance.new("Seat")
			seat.Name = "Kursi"
			seat.Size = Vector3.new(4.6, 0.4, 1.8)
			seat.CFrame = CFrame.new(hanger.X, floorTop + 1.1, hanger.Z + sz * 2.0)
				* (if sz < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
			seat.Transparency = 1
			seat.CanCollide = true
			seat.CanQuery = false
			seat.CanTouch = true
			seat.Massless = true
			seat.CollisionGroup = GROUP
			seat.Parent = cabin
			weld(core, seat)
		end
		-- sendi gantung bebas di pin roda + penjaga tegak
		local hinge = Instance.new("HingeConstraint")
		hinge.Name = "SendiGantung"
		hinge.Attachment0 = attach(hub, "PinKabin" .. (i + 1), rim)
		hinge.Attachment1 = attach(core, "Gantungan", Vector3.new(0, DROP, 0))
		hinge.Parent = core
		local upright = Instance.new("AlignOrientation")
		upright.Name = "JagaTegak"
		upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
		upright.Attachment0 = attach(core, "Tegak", Vector3.zero)
		upright.CFrame = CFrame.new()
		upright.RigidityEnabled = false
		upright.MaxTorque = 1e7
		upright.Responsiveness = 40
		upright.Parent = core
		cabin.PrimaryPart = core
		cabin.Parent = model
	end

	model.Parent = dermaga
	return #model:GetDescendants()
end
