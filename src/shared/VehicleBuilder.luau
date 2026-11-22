--!strict
-- VehicleBuilder: merakit model mobil dari Part berdasarkan VehicleConfig.
-- Semua bentuk parametris (panjang, lebar, kabin, roda), jadi kendaraan baru
-- cukup didefinisikan di VehicleConfig tanpa membuat model manual.
--
--   build(def)                 -> mobil yang bisa dikendarai (kursi, roda berengsel)
--   build(def, { static=true }) -> pajangan dealer (semua part Anchored, tanpa kursi)
--
-- Susunan model:
--   Chassis (PrimaryPart, satu-satunya part bermassa selain roda)
--   Body/   part hiasan + Lower & Cabin sebagai badan tabrakan
--   Wheels/ FL FR RL RR (silinder)
--   DriveSeat (VehicleSeat) + Seat2..4
-- Di dalam Chassis: engsel MotorFL/FR/RL/RR (penggerak) dan attachment
-- SteerFL/SteerFR (diputar client pengemudi untuk membelokkan roda depan).

local CollectionService = game:GetService("CollectionService")

local VehicleConfig = require(script.Parent.VehicleConfig)

type VehicleDef = VehicleConfig.VehicleDef

export type BuildOptions = {
	static: boolean?,
	color: Color3?,
}

local VehicleBuilder = {}

VehicleBuilder.GROUP_BODY = "VehicleBody"
VehicleBuilder.GROUP_WHEEL = "VehicleWheel"

local DARK = Color3.fromRGB(34, 36, 42)
local TIRE = Color3.fromRGB(24, 24, 28)
local RIM = Color3.fromRGB(205, 210, 218)
local GLASS = Color3.fromRGB(150, 200, 230)
local HEADLIGHT = Color3.fromRGB(255, 244, 200)
local TAILLIGHT = Color3.fromRGB(255, 60, 50)
local SEAT_COLOR = Color3.fromRGB(70, 74, 84)

local WHEEL_PHYSICS = PhysicalProperties.new(1.2, 1.7, 0, 100, 100)
local BODY_PHYSICS = PhysicalProperties.new(0.7, 0.25, 0, 1, 100)
local CHASSIS_PHYSICS = PhysicalProperties.new(3, 0.25, 0, 1, 100)

-- Part bodi kotak yang digantikan bodi mesh (lihat akhir build()).
local SHELL_REPLACES = {
	Lower = true,
	Cabin = true,
	Roof = true,
	Windshield = true,
	RearWindow = true,
	Pillar = true,
	Stripe = true,
}

local function findShell(id: string): Instance?
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local shells = if assets then assets:FindFirstChild("CarShells") else nil
	return if shells then shells:FindFirstChild(id) else nil
end

function VehicleBuilder.build(def: VehicleDef, options: BuildOptions?): Model
	local static = options ~= nil and options.static == true
	local paint = if options and options.color then options.color else def.color
	local b = def.body

	local model = Instance.new("Model")
	model.Name = "Vehicle_" .. def.id
	model:SetAttribute(VehicleConfig.ATTR_VEHICLE_ID, def.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local bodyFolder = Instance.new("Folder")
	bodyFolder.Name = "Body"
	bodyFolder.Parent = model
	local wheelFolder = Instance.new("Folder")
	wheelFolder.Name = "Wheels"
	wheelFolder.Parent = model

	local L, W = b.length, b.width
	local y0 = b.clearance
	local y1 = y0 + b.lowerHeight
	local glassH = b.cabinHeight - 0.35
	local y2 = y1 + b.cabinHeight
	local front, back = -L / 2, L / 2
	local function zAt(fraction: number): number
		return front + fraction * L
	end

	-- ------------------------------------------------------------ Chassis
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W - 1.4, 0.6, L - 1.2)
	chassis.CFrame = CFrame.new(0, y0 + 0.3, 0)
	chassis.Color = DARK
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CustomPhysicalProperties = CHASSIS_PHYSICS
	chassis.CollisionGroup = VehicleBuilder.GROUP_BODY
	chassis.RootPriority = 20
	chassis.Anchored = static
	chassis.PivotOffset = CFrame.new(0, -(y0 + 0.3), 0)
	chassis.Parent = model
	model.PrimaryPart = chassis

	local function weld(part: BasePart)
		if static then
			part.Anchored = true
			return
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = chassis
		w.Part1 = part
		w.Parent = part
	end

	-- Part bodi. collide=true hanya untuk badan utama; sisanya hiasan ringan.
	local function part(props: { [string]: any }, collide: boolean?, paintRole: string?): BasePart
		local p = Instance.new(props.ClassName or "Part") :: BasePart
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		p.Massless = true
		p.CanCollide = collide == true
		p.CanTouch = false
		p.CastShadow = collide == true
		p.CustomPhysicalProperties = BODY_PHYSICS
		p.CollisionGroup = VehicleBuilder.GROUP_BODY
		for key, value in props do
			if key ~= "ClassName" then
				(p :: any)[key] = value
			end
		end
		if paintRole then
			p:SetAttribute("Paint", paintRole)
		end
		weld(p)
		p.Parent = bodyFolder
		return p
	end

	-- ------------------------------------------------------------ bodi bawah
	part({
		Name = "Lower",
		Size = Vector3.new(W, b.lowerHeight, L - 0.8),
		CFrame = CFrame.new(0, y0 + b.lowerHeight / 2, 0),
		Color = paint,
	}, true, "body")

	for _, side in { -1, 1 } do
		local z = side * (L / 2 - 0.4)
		part({
			Name = if side < 0 then "BumperFront" else "BumperRear",
			Size = Vector3.new(W + 0.2, 0.9, 0.9),
			CFrame = CFrame.new(0, y0 + 0.5, z),
			Color = DARK,
		})
		part({
			Name = "Plate",
			Size = Vector3.new(1.9, 0.6, 0.1),
			CFrame = CFrame.new(0, y0 + 0.55, z + side * 0.46),
			Color = Color3.fromRGB(245, 245, 245),
		})
		-- lampu: depan kuning pucat, belakang merah
		for _, lx in { -1, 1 } do
			part({
				Name = if side < 0 then "Headlight" else "Taillight",
				Size = Vector3.new(1.4, 0.55, 0.2),
				CFrame = CFrame.new(lx * (W / 2 - 1.2), y1 - 0.65, side * (L / 2 - 0.4)),
				Color = if side < 0 then HEADLIGHT else TAILLIGHT,
				Material = Enum.Material.Neon,
			})
		end
	end
	part({
		Name = "Grille",
		Size = Vector3.new(W * 0.36, 0.55, 0.2),
		CFrame = CFrame.new(0, y1 - 0.65, front + 0.4),
		Color = DARK,
	})
	-- strip samping warna aksen
	for _, sx in { -1, 1 } do
		part({
			Name = "Stripe",
			Size = Vector3.new(0.1, 0.3, L * 0.78),
			CFrame = CFrame.new(sx * (W / 2 + 0.02), y0 + b.lowerHeight * 0.45, 0),
			Color = def.accent,
		}, false, "accent")
	end

	-- ------------------------------------------------------------ kabin
	local cabinW = W - 0.8
	local zc0, zc1 = zAt(b.cabinFront), zAt(b.cabinBack)
	local zm0, zm1 = zc0 + b.rakeFront, zc1 - b.rakeBack
	local glassY = y1 + glassH / 2

	part({
		ClassName = "WedgePart",
		Name = "Windshield",
		Size = Vector3.new(cabinW, glassH, b.rakeFront),
		CFrame = CFrame.new(0, glassY, (zc0 + zm0) / 2),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	part({
		ClassName = "WedgePart",
		Name = "RearWindow",
		Size = Vector3.new(cabinW, glassH, b.rakeBack),
		CFrame = CFrame.new(0, glassY, (zm1 + zc1) / 2) * CFrame.Angles(0, math.pi, 0),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	part({
		Name = "Cabin",
		Size = Vector3.new(cabinW, glassH, zm1 - zm0),
		CFrame = CFrame.new(0, glassY, (zm0 + zm1) / 2),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	}, true)
	part({
		Name = "Roof",
		Size = Vector3.new(cabinW + 0.2, 0.35, zm1 - zm0 + 0.5),
		CFrame = CFrame.new(0, y2 - 0.175, (zm0 + zm1) / 2),
		Color = paint,
	}, false, "body")
	-- tiang: sudut depan, tengah, sudut belakang
	for _, pz in { zm0 + 0.15, (zm0 + zm1) / 2, zm1 - 0.15 } do
		for _, sx in { -1, 1 } do
			part({
				Name = "Pillar",
				Size = Vector3.new(0.3, glassH, 0.4),
				CFrame = CFrame.new(sx * (cabinW / 2 - 0.1), glassY, pz),
				Color = paint,
			}, false, "body")
		end
	end
	for _, sx in { -1, 1 } do
		part({
			Name = "Mirror",
			Size = Vector3.new(0.7, 0.45, 0.3),
			CFrame = CFrame.new(sx * (W / 2 + 0.15), y1 + 0.35, zm0 - 0.2),
			Color = paint,
		}, false, "body")
	end

	if b.spoiler then
		for _, sx in { -1, 1 } do
			part({
				Name = "SpoilerPost",
				Size = Vector3.new(0.3, 0.8, 0.5),
				CFrame = CFrame.new(sx * (W / 2 - 1.2), y1 + 0.4, back - 1.4),
				Color = DARK,
			})
		end
		part({
			Name = "SpoilerWing",
			Size = Vector3.new(W - 0.4, 0.2, 1.3),
			CFrame = CFrame.new(0, y1 + 0.9, back - 1.3) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = def.accent,
		}, false, "accent")
	end
	if b.roofRack then
		for _, sx in { -1, 1 } do
			part({
				Name = "RackRail",
				Size = Vector3.new(0.25, 0.25, (zm1 - zm0) * 0.8),
				CFrame = CFrame.new(sx * (cabinW / 2 - 0.5), y2 + 0.3, (zm0 + zm1) / 2),
				Color = DARK,
			})
		end
		for _, t in { 0.25, 0.75 } do
			part({
				Name = "RackBar",
				Size = Vector3.new(cabinW - 0.6, 0.2, 0.3),
				CFrame = CFrame.new(0, y2 + 0.3, zm0 + (zm1 - zm0) * t),
				Color = DARK,
			})
		end
	end

	-- ------------------------------------------------------------ kendaraan dinas
	local topY = y2 -- titik tertinggi bodi
	local boxZ0 = zc1 + 0.15
	local boxZ1 = back - 0.4
	local box = b.box
	if box then
		topY = y1 + box.height
		part({
			Name = "Box",
			Size = Vector3.new(W - 0.1, box.height, boxZ1 - boxZ0),
			CFrame = CFrame.new(0, y1 + box.height / 2, (boxZ0 + boxZ1) / 2),
			Color = box.color,
		}, true)
		part({
			Name = "BoxDoor",
			Size = Vector3.new(W - 1.6, box.height - 0.8, 0.1),
			CFrame = CFrame.new(0, y1 + box.height / 2, boxZ1 + 0.03),
			Color = DARK,
			Transparency = 0.6,
		})
		if b.ladder then
			for _, sx in { -1, 1 } do
				part({
					Name = "LadderRail",
					Size = Vector3.new(0.25, 0.25, boxZ1 - boxZ0 + 1.5),
					CFrame = CFrame.new(sx * 1.1, topY + 0.35, (boxZ0 + boxZ1) / 2),
					Color = RIM,
					Material = Enum.Material.Metal,
				})
			end
			local rungs = 7
			for index = 1, rungs do
				local t = (index - 0.5) / rungs
				part({
					Name = "LadderRung",
					Size = Vector3.new(2.2, 0.18, 0.18),
					CFrame = CFrame.new(0, topY + 0.35, boxZ0 + (boxZ1 - boxZ0) * t),
					Color = RIM,
					Material = Enum.Material.Metal,
				})
			end
		end
	end
	if b.band then
		for _, sx in { -1, 1 } do
			part({
				Name = "Band",
				Size = Vector3.new(0.12, 0.8, L - 1.2),
				CFrame = CFrame.new(sx * (W / 2 + 0.03), y1 - 0.75, 0),
				Color = b.band,
			})
		end
	end
	if b.sideText then
		-- Tulisan di boks jika ada, kalau tidak di pintu (bodi bawah).
		local textH = if box then math.min(1.6, box.height - 1.2) else 1
		local textL = if box then (boxZ1 - boxZ0) * 0.8 else L * 0.36
		local textY = if box then y1 + box.height * 0.55 else y0 + b.lowerHeight * 0.36
		local textZ = if box then (boxZ0 + boxZ1) / 2 else (zm0 + zm1) / 2
		local textX = if box then W / 2 - 0.02 else W / 2 + 0.05
		for _, sx in { -1, 1 } do
			local plate = part({
				Name = "SideText",
				Size = Vector3.new(0.1, textH, textL),
				CFrame = CFrame.new(sx * textX, textY, textZ),
				Transparency = 1,
			})
			local gui = Instance.new("SurfaceGui")
			gui.Face = if sx > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0.4
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = def.accent
			label.Text = b.sideText
			label.Parent = gui
			gui.Parent = plate
		end
	end
	local lightBar = b.lightBar
	if lightBar then
		local barZ = (zm0 + zm1) / 2
		local barY = y2 + 0.1
		part({
			Name = "LightBarBase",
			Size = Vector3.new(cabinW * 0.7, 0.2, 1.1),
			CFrame = CFrame.new(0, barY, barZ),
			Color = DARK,
		})
		for index, sx in { -1, 1 } do
			local lamp = part({
				Name = "Beacon",
				Size = Vector3.new(cabinW * 0.3, 0.5, 0.9),
				CFrame = CFrame.new(sx * cabinW * 0.18, barY + 0.35, barZ),
				Color = lightBar[index] or lightBar[1],
			})
			lamp:SetAttribute(VehicleConfig.ATTR_BEACON_PHASE, index - 1)
			if not static then
				CollectionService:AddTag(lamp, VehicleConfig.TAG_BEACON)
			end
		end
	end

	-- ------------------------------------------------------------ roda
	local r = b.wheelRadius
	local wheelX = W / 2 - b.wheelWidth / 2 + 0.15
	local wheelPos = {
		FL = Vector3.new(-wheelX, r, -b.wheelbase / 2),
		FR = Vector3.new(wheelX, r, -b.wheelbase / 2),
		RL = Vector3.new(-wheelX, r, b.wheelbase / 2),
		RR = Vector3.new(wheelX, r, b.wheelbase / 2),
	}

	local function attachment(parent: BasePart, worldCFrame: CFrame, name: string): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = parent.CFrame:ToObjectSpace(worldCFrame)
		a.Parent = parent
		return a
	end

	for _, key in { "FL", "FR", "RL", "RR" } do
		local pos = (wheelPos :: any)[key] :: Vector3
		local wheel = Instance.new("Part")
		wheel.Name = key
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(b.wheelWidth, r * 2, r * 2)
		wheel.CFrame = CFrame.new(pos)
		wheel.Color = TIRE
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.TopSurface = Enum.SurfaceType.Smooth
		wheel.BottomSurface = Enum.SurfaceType.Smooth
		wheel.CustomPhysicalProperties = WHEEL_PHYSICS
		wheel.CollisionGroup = VehicleBuilder.GROUP_WHEEL
		wheel.CanTouch = false
		wheel.Anchored = static
		wheel.Parent = wheelFolder

		local rim = Instance.new("Part")
		rim.Name = "Rim"
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(b.wheelWidth + 0.12, r * 1.15, r * 1.15)
		rim.CFrame = CFrame.new(pos)
		rim.Color = RIM
		rim.Material = Enum.Material.Metal
		rim.Massless = true
		rim.CanCollide = false
		rim.CanTouch = false
		rim.CanQuery = false
		rim.CastShadow = false
		rim.CollisionGroup = VehicleBuilder.GROUP_WHEEL
		rim.Anchored = static
		rim:SetAttribute("Paint", "rim")
		rim.Parent = wheel
		if not static then
			local rw = Instance.new("WeldConstraint")
			rw.Part0 = wheel
			rw.Part1 = rim
			rw.Parent = rim
		end

		if static then
			continue
		end

		-- Sumbu X attachment = sumbu putar roda. Roda depan dibelokkan dengan memutar
		-- attachment "SteerFL/FR" di chassis terhadap sumbu Y (lihat VehicleController);
		-- engsel memaksa roda mengikuti, jadi kemudi kaku tanpa part/servo tambahan.
		local axle = CFrame.new(pos)
		local isFront = key == "FL" or key == "FR"
		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor" .. key
		motor.Attachment0 = attachment(chassis, axle, (if isFront then "Steer" else "Axle") .. key)
		motor.Attachment1 = attachment(wheel, axle, "Axle")
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.AngularVelocity = 0 -- diam = rem parkir
		motor.MotorMaxTorque = 60000
		motor.MotorMaxAcceleration = 60
		motor.Parent = chassis
	end

	-- ------------------------------------------------------------ kursi
	if not static then
		local seatY = y0 + 0.1
		local frontZ = zm0 + 1.7
		local seatX = W / 4 - 0.1
		local spots = { Vector3.new(seatX, seatY, frontZ) } -- setir kanan
		if def.seats >= 2 then
			table.insert(spots, Vector3.new(-seatX, seatY, frontZ))
		end
		if def.seats >= 4 then
			table.insert(spots, Vector3.new(seatX, seatY, frontZ + 3.3))
			table.insert(spots, Vector3.new(-seatX, seatY, frontZ + 3.3))
		end
		for index, pos in spots do
			local seat: BasePart
			if index == 1 then
				local vs = Instance.new("VehicleSeat")
				vs.Name = "DriveSeat"
				vs.MaxSpeed = 0
				vs.Torque = 0
				vs.TurnSpeed = 0
				vs.HeadsUpDisplay = false
				seat = vs
			else
				local s = Instance.new("Seat")
				s.Name = "Seat" .. index
				seat = s
			end
			seat.Size = Vector3.new(2.4, 0.4, 2.4)
			seat.CFrame = CFrame.new(pos)
			seat.Color = SEAT_COLOR
			seat.Material = Enum.Material.Fabric
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.BottomSurface = Enum.SurfaceType.Smooth
			seat.Massless = true
			seat.CanCollide = false
			seat.CanTouch = false -- naik hanya lewat ProximityPrompt (dicek server)
			seat.CollisionGroup = VehicleBuilder.GROUP_BODY
			weld(seat)
			seat.Parent = model

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "EnterPrompt"
			prompt.ActionText = if index == 1 then "Kemudikan" else "Naik"
			prompt.ObjectText = def.name
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = seat
		end
		-- setir (hiasan)
		part({
			Name = "SteeringWheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1.3, 1.3),
			CFrame = CFrame.new(seatX, y1 + 0.2, frontZ - 1.5)
				* CFrame.Angles(0, math.pi / 2, math.rad(20)),
			Color = DARK,
		})
	end

	-- ------------------------------------------------------------ bodi mesh (opsional)
	-- Kalau ada templat ReplicatedStorage.Assets.CarShells.<id> (mesh buatan Blender, sumbernya di
	-- assets/blender), bodi kotak disembunyikan dan diganti mesh itu. Lampu, bumper, roda, kursi,
	-- dan tabrakan tetap dari bodi kotak. Tanpa templat, mobil tampil dengan bodi kotak seperti biasa.
	local shellSource = findShell(def.id)
	local shellBody = if shellSource then shellSource:FindFirstChild("ShellBody") else nil
	if shellSource and shellBody and shellBody:IsA("BasePart") then
		for _, old in bodyFolder:GetChildren() do
			if old:IsA("BasePart") and SHELL_REPLACES[old.Name] then
				old.Transparency = 1
				old.CastShadow = false
			end
		end
		local target = CFrame.new(0, y0 + shellBody.Size.Y / 2, 0)
		for _, piece in shellSource:GetChildren() do
			if piece:IsA("MeshPart") then
				local clone = piece:Clone()
				clone.CFrame = target * shellBody.CFrame:ToObjectSpace(piece.CFrame)
				clone.Anchored = false
				clone.Massless = true
				clone.CanCollide = false
				clone.CanTouch = false
				clone.CanQuery = false
				clone.DoubleSided = true
				clone.CustomPhysicalProperties = BODY_PHYSICS
				clone.CollisionGroup = VehicleBuilder.GROUP_BODY
				if piece.Name == "ShellGlass" then
					clone.Color = Color3.fromRGB(70, 96, 120)
					clone.Material = Enum.Material.Glass
					clone.Transparency = 0.35
					clone.Reflectance = 0.15
					clone.CastShadow = false
				else
					clone.Color = paint
					clone.Material = Enum.Material.SmoothPlastic
					clone.Reflectance = 0.08
					clone:SetAttribute("Paint", "body")
				end
				weld(clone)
				clone.Parent = bodyFolder
			end
		end
	end

	return model
end

return VehicleBuilder
