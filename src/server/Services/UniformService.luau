--!strict
-- UniformService: seragam pekerjaan ringan yang ditempelkan di atas avatar asli pemain.
-- Avatar pemain tidak diganti dan aksesori bawaan tidak disembunyikan; saat tidak
-- bekerja, model seragam dilepas sehingga pemain kembali memakai avatar Roblox
-- default miliknya sendiri.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JobConfig = require(Shared:WaitForChild("JobConfig"))
local FashionConfig = require(Shared:WaitForChild("FashionConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

type Uniform = JobConfig.Uniform

local UniformService = {}

local MODEL_NAME = "JobUniform"
local DARK = Color3.fromRGB(34, 36, 42)
local WHITE = Color3.fromRGB(248, 248, 250)
local SILVER = Color3.fromRGB(205, 210, 216)
local RED = Color3.fromRGB(225, 55, 55)
local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90))

-- ---------------------------------------------------------------- perakit

local function piece(
	model: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = anchor.CFrame * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function disc(
	model: Model,
	anchor: BasePart,
	name: string,
	height: number,
	diameter: number,
	y: number,
	color: Color3
): Part
	return piece(
		model,
		anchor,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(0, y, 0) * SIDEWAYS,
		color,
		Enum.PartType.Cylinder
	)
end

local function partOrNil(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function frontZ(part: BasePart, extra: number?): number
	return -(part.Size.Z / 2 + (extra or 0.055))
end

local function backZ(part: BasePart, extra: number?): number
	return part.Size.Z / 2 + (extra or 0.055)
end

local function panel(
	model: Model,
	torso: BasePart,
	name: string,
	color: Color3,
	widthScale: number,
	heightScale: number,
	z: number,
	y: number?
)
	local size = torso.Size
	piece(
		model,
		torso,
		name,
		Vector3.new(
			math.max(0.45, size.X * widthScale),
			math.max(0.45, size.Y * heightScale),
			0.065
		),
		CFrame.new(0, y or 0, z),
		color
	)
end

local function trimBar(
	model: Model,
	torso: BasePart,
	name: string,
	color: Color3,
	widthScale: number,
	y: number,
	z: number,
	height: number?
)
	piece(
		model,
		torso,
		name,
		Vector3.new(
			math.max(0.45, torso.Size.X * widthScale),
			height or math.max(0.07, torso.Size.Y * 0.08),
			0.08
		),
		CFrame.new(0, y, z),
		color
	)
end

local function verticalBar(
	model: Model,
	torso: BasePart,
	name: string,
	color: Color3,
	x: number,
	z: number,
	heightScale: number,
	width: number?
)
	piece(
		model,
		torso,
		name,
		Vector3.new(
			width or math.max(0.08, torso.Size.X * 0.08),
			math.max(0.45, torso.Size.Y * heightScale),
			0.08
		),
		CFrame.new(x, 0, z),
		color
	)
end

local function addBadge(
	model: Model,
	torso: BasePart,
	name: string,
	color: Color3,
	x: number,
	y: number,
	z: number,
	scale: number?
)
	local s = scale or math.max(0.18, torso.Size.X * 0.16)
	piece(model, torso, name, Vector3.new(s, s, 0.09), CFrame.new(x, y, z), color)
end

local function addArmBand(
	model: Model,
	character: Model,
	partName: string,
	color: Color3,
	nameSuffix: string?
)
	local arm = partOrNil(character, partName)
	if arm == nil then
		return
	end
	piece(
		model,
		arm,
		partName .. (nameSuffix or "JobBand"),
		Vector3.new(arm.Size.X + 0.07, math.max(0.08, arm.Size.Y * 0.16), arm.Size.Z + 0.07),
		CFrame.new(0, arm.Size.Y * 0.14, 0),
		color
	)
end

local function addBothArmBands(model: Model, character: Model, color: Color3, suffix: string?)
	addArmBand(model, character, "LeftUpperArm", color, suffix)
	addArmBand(model, character, "RightUpperArm", color, suffix)
	addArmBand(model, character, "Left Arm", color, suffix)
	addArmBand(model, character, "Right Arm", color, suffix)
end

local function buildDeliveryUniform(
	model: Model,
	torso: BasePart,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	panel(model, torso, "CourierVestFront", uniform.vest, 0.82, 0.82, z)
	panel(model, torso, "CourierVestBack", uniform.vest, 0.82, 0.82, backZ(torso))
	trimBar(model, torso, "CourierReflectiveTop", uniform.trim, 0.9, torso.Size.Y * 0.2, z - 0.02)
	trimBar(
		model,
		torso,
		"CourierReflectiveBottom",
		uniform.trim,
		0.9,
		-torso.Size.Y * 0.3,
		z - 0.02
	)
	piece(
		model,
		torso,
		"CourierDiagonalStrap",
		Vector3.new(torso.Size.X * 0.14, torso.Size.Y * 0.88, 0.09),
		CFrame.new(torso.Size.X * 0.08, 0, z - 0.035) * CFrame.Angles(0, 0, math.rad(-24)),
		uniform.trim
	)
	addBadge(
		model,
		torso,
		"CourierPackageBadge",
		uniform.badge,
		-torso.Size.X * 0.27,
		torso.Size.Y * 0.23,
		z - 0.06,
		torso.Size.X * 0.18
	)
	addBothArmBands(model, character, uniform.vest, "CourierBand")
end

local function buildMechanicUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	panel(model, torso, "MechanicCoverallFront", uniform.vest, 0.86, 0.9, z)
	panel(model, torso, "MechanicCoverallBack", uniform.vest, 0.86, 0.9, backZ(torso))
	verticalBar(model, torso, "MechanicZipper", SILVER, 0, z - 0.03, 0.82, 0.055)
	trimBar(
		model,
		torso,
		"MechanicNamePatch",
		uniform.trim,
		0.34,
		torso.Size.Y * 0.22,
		z - 0.05,
		math.max(0.08, torso.Size.Y * 0.09)
	)
	piece(
		model,
		torso,
		"MechanicWrenchHandle",
		Vector3.new(torso.Size.X * 0.34, 0.045, 0.09),
		CFrame.new(torso.Size.X * 0.22, -torso.Size.Y * 0.06, z - 0.055)
			* CFrame.Angles(0, 0, math.rad(-25)),
		SILVER
	)
	piece(
		model,
		torso,
		"MechanicWrenchHead",
		Vector3.new(torso.Size.X * 0.11, 0.11, 0.09),
		CFrame.new(torso.Size.X * 0.34, torso.Size.Y * 0.02, z - 0.06),
		SILVER
	)
	if lower then
		piece(
			model,
			lower,
			"MechanicToolBelt",
			Vector3.new(
				lower.Size.X * 0.96,
				math.max(0.11, lower.Size.Y * 0.18),
				lower.Size.Z + 0.18
			),
			CFrame.new(0, lower.Size.Y * 0.16, 0),
			DARK
		)
		piece(
			model,
			lower,
			"MechanicToolPouch",
			Vector3.new(lower.Size.X * 0.23, lower.Size.Y * 0.28, 0.09),
			CFrame.new(lower.Size.X * 0.28, lower.Size.Y * 0.02, frontZ(lower) - 0.04),
			uniform.trim
		)
	end
	addBothArmBands(model, character, uniform.trim, "MechanicSleeveStripe")
end

local function buildDriverUniform(model: Model, torso: BasePart, character: Model, uniform: Uniform)
	local z = frontZ(torso)
	panel(model, torso, "DriverJacketFront", uniform.vest, 0.86, 0.86, z)
	panel(model, torso, "DriverJacketBack", uniform.vest, 0.86, 0.86, backZ(torso))
	verticalBar(model, torso, "DriverShirt", WHITE, 0, z - 0.035, 0.78, torso.Size.X * 0.24)
	piece(
		model,
		torso,
		"DriverTie",
		Vector3.new(torso.Size.X * 0.15, torso.Size.Y * 0.48, 0.09),
		CFrame.new(0, -torso.Size.Y * 0.04, z - 0.075),
		uniform.trim
	)
	addBadge(
		model,
		torso,
		"DriverRouteBadge",
		uniform.badge,
		-torso.Size.X * 0.3,
		torso.Size.Y * 0.24,
		z - 0.08,
		torso.Size.X * 0.16
	)
	addBothArmBands(model, character, uniform.trim, "DriverCuff")
end

local function buildPilotUniform(model: Model, torso: BasePart, character: Model, uniform: Uniform)
	local z = frontZ(torso)
	panel(model, torso, "PilotJacketFront", uniform.vest, 0.88, 0.88, z)
	panel(model, torso, "PilotJacketBack", uniform.vest, 0.88, 0.88, backZ(torso))
	verticalBar(model, torso, "PilotWhiteShirt", WHITE, 0, z - 0.04, 0.8, torso.Size.X * 0.26)
	piece(
		model,
		torso,
		"PilotTie",
		Vector3.new(torso.Size.X * 0.14, torso.Size.Y * 0.5, 0.09),
		CFrame.new(0, -torso.Size.Y * 0.05, z - 0.08),
		DARK
	)
	piece(
		model,
		torso,
		"PilotLeftEpaulet",
		Vector3.new(torso.Size.X * 0.32, math.max(0.06, torso.Size.Y * 0.06), torso.Size.Z + 0.14),
		CFrame.new(-torso.Size.X * 0.34, torso.Size.Y * 0.43, 0),
		uniform.trim
	)
	piece(
		model,
		torso,
		"PilotRightEpaulet",
		Vector3.new(torso.Size.X * 0.32, math.max(0.06, torso.Size.Y * 0.06), torso.Size.Z + 0.14),
		CFrame.new(torso.Size.X * 0.34, torso.Size.Y * 0.43, 0),
		uniform.trim
	)
	piece(
		model,
		torso,
		"PilotWingLeft",
		Vector3.new(torso.Size.X * 0.18, 0.05, 0.09),
		CFrame.new(-torso.Size.X * 0.28, torso.Size.Y * 0.22, z - 0.075)
			* CFrame.Angles(0, 0, math.rad(12)),
		uniform.badge
	)
	piece(
		model,
		torso,
		"PilotWingRight",
		Vector3.new(torso.Size.X * 0.18, 0.05, 0.09),
		CFrame.new(-torso.Size.X * 0.14, torso.Size.Y * 0.22, z - 0.075)
			* CFrame.Angles(0, 0, math.rad(-12)),
		uniform.badge
	)
	addBothArmBands(model, character, uniform.trim, "PilotGoldCuff")
end

local function buildPoliceUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	panel(model, torso, "PoliceVestFront", uniform.vest, 0.9, 0.86, z)
	panel(model, torso, "PoliceVestBack", uniform.vest, 0.9, 0.86, backZ(torso))
	verticalBar(model, torso, "PoliceVestCenter", DARK, 0, z - 0.035, 0.78, torso.Size.X * 0.09)
	addBadge(
		model,
		torso,
		"PoliceGoldBadge",
		uniform.badge,
		-torso.Size.X * 0.28,
		torso.Size.Y * 0.24,
		z - 0.07,
		torso.Size.X * 0.18
	)
	piece(
		model,
		torso,
		"PoliceRadio",
		Vector3.new(torso.Size.X * 0.18, torso.Size.Y * 0.22, 0.08),
		CFrame.new(torso.Size.X * 0.3, torso.Size.Y * 0.2, z - 0.07),
		DARK
	)
	piece(
		model,
		torso,
		"PoliceRadioAntenna",
		Vector3.new(0.035, torso.Size.Y * 0.22, 0.05),
		CFrame.new(torso.Size.X * 0.37, torso.Size.Y * 0.39, z - 0.075),
		DARK
	)
	if lower then
		piece(
			model,
			lower,
			"PoliceDutyBelt",
			Vector3.new(
				lower.Size.X * 0.98,
				math.max(0.11, lower.Size.Y * 0.18),
				lower.Size.Z + 0.2
			),
			CFrame.new(0, lower.Size.Y * 0.18, 0),
			DARK
		)
	end
	addBothArmBands(model, character, uniform.badge, "PolicePatch")
end

local function buildFirefighterUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	panel(model, torso, "FirefighterCoatFront", uniform.vest, 0.92, 0.9, z)
	panel(model, torso, "FirefighterCoatBack", uniform.vest, 0.92, 0.9, backZ(torso))
	trimBar(model, torso, "FireReflectiveChest", uniform.trim, 0.96, torso.Size.Y * 0.18, z - 0.025)
	trimBar(
		model,
		torso,
		"FireReflectiveWaist",
		uniform.trim,
		0.96,
		-torso.Size.Y * 0.24,
		z - 0.025
	)
	verticalBar(
		model,
		torso,
		"FireReflectiveLeft",
		uniform.trim,
		-torso.Size.X * 0.26,
		z - 0.03,
		0.82,
		torso.Size.X * 0.09
	)
	verticalBar(
		model,
		torso,
		"FireReflectiveRight",
		uniform.trim,
		torso.Size.X * 0.26,
		z - 0.03,
		0.82,
		torso.Size.X * 0.09
	)
	addBadge(
		model,
		torso,
		"FireDeptBadge",
		uniform.badge,
		0,
		torso.Size.Y * 0.3,
		z - 0.07,
		torso.Size.X * 0.18
	)
	piece(
		model,
		torso,
		"FireAirTank",
		Vector3.new(torso.Size.X * 0.34, torso.Size.Y * 0.72, 0.16),
		CFrame.new(0, 0, backZ(torso) + 0.07),
		RED,
		Enum.PartType.Cylinder
	)
	if lower then
		piece(
			model,
			lower,
			"FireUtilityBelt",
			Vector3.new(
				lower.Size.X * 0.98,
				math.max(0.11, lower.Size.Y * 0.16),
				lower.Size.Z + 0.2
			),
			CFrame.new(0, lower.Size.Y * 0.18, 0),
			DARK
		)
	end
	addBothArmBands(model, character, uniform.trim, "FireReflectiveSleeve")
end

local function buildDoctorUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	piece(
		model,
		torso,
		"DoctorCoatLeft",
		Vector3.new(torso.Size.X * 0.42, torso.Size.Y * 0.9, 0.065),
		CFrame.new(-torso.Size.X * 0.22, 0, z),
		uniform.vest
	)
	piece(
		model,
		torso,
		"DoctorCoatRight",
		Vector3.new(torso.Size.X * 0.42, torso.Size.Y * 0.9, 0.065),
		CFrame.new(torso.Size.X * 0.22, 0, z),
		uniform.vest
	)
	panel(model, torso, "DoctorCoatBack", uniform.vest, 0.9, 0.9, backZ(torso))
	verticalBar(
		model,
		torso,
		"DoctorOpenCoatLine",
		uniform.trim,
		0,
		z - 0.035,
		0.84,
		torso.Size.X * 0.05
	)
	addBadge(
		model,
		torso,
		"DoctorRedCrossBase",
		RED,
		-torso.Size.X * 0.27,
		torso.Size.Y * 0.24,
		z - 0.07,
		torso.Size.X * 0.18
	)
	piece(
		model,
		torso,
		"DoctorRedCrossVertical",
		Vector3.new(torso.Size.X * 0.07, torso.Size.Y * 0.22, 0.1),
		CFrame.new(-torso.Size.X * 0.27, torso.Size.Y * 0.24, z - 0.09),
		WHITE
	)
	piece(
		model,
		torso,
		"DoctorRedCrossHorizontal",
		Vector3.new(torso.Size.X * 0.18, torso.Size.Y * 0.07, 0.1),
		CFrame.new(-torso.Size.X * 0.27, torso.Size.Y * 0.24, z - 0.1),
		WHITE
	)
	piece(
		model,
		torso,
		"StethoscopeCordLeft",
		Vector3.new(0.05, torso.Size.Y * 0.42, 0.07),
		CFrame.new(-torso.Size.X * 0.12, torso.Size.Y * 0.08, z - 0.08)
			* CFrame.Angles(0, 0, math.rad(-12)),
		DARK
	)
	piece(
		model,
		torso,
		"StethoscopeCordRight",
		Vector3.new(0.05, torso.Size.Y * 0.42, 0.07),
		CFrame.new(torso.Size.X * 0.12, torso.Size.Y * 0.08, z - 0.08)
			* CFrame.Angles(0, 0, math.rad(12)),
		DARK
	)
	piece(
		model,
		torso,
		"StethoscopeChestPiece",
		Vector3.new(torso.Size.X * 0.14, torso.Size.X * 0.14, 0.08),
		CFrame.new(0, -torso.Size.Y * 0.17, z - 0.09),
		SILVER,
		Enum.PartType.Cylinder
	)
	if lower then
		piece(
			model,
			lower,
			"DoctorCoatTail",
			Vector3.new(lower.Size.X * 0.9, lower.Size.Y * 0.32, lower.Size.Z + 0.12),
			CFrame.new(0, lower.Size.Y * 0.05, 0),
			uniform.vest
		)
	end
	addBothArmBands(model, character, uniform.trim, "DoctorTealCuff")
end

local function buildDefaultUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform
)
	local z = frontZ(torso)
	panel(model, torso, "WorkVestFront", uniform.vest, 0.84, 0.84, z)
	panel(model, torso, "WorkVestBack", uniform.vest, 0.84, 0.84, backZ(torso))
	trimBar(model, torso, "WorkVestTopTrim", uniform.trim, 0.92, torso.Size.Y * 0.18, z - 0.02)
	trimBar(model, torso, "WorkVestBottomTrim", uniform.trim, 0.92, -torso.Size.Y * 0.3, z - 0.02)
	addBadge(
		model,
		torso,
		"WorkBadge",
		uniform.badge,
		-torso.Size.X * 0.27,
		torso.Size.Y * 0.24,
		z - 0.06,
		torso.Size.X * 0.18
	)
	if lower then
		piece(
			model,
			lower,
			"WorkBelt",
			Vector3.new(
				lower.Size.X * 0.92,
				math.max(0.1, lower.Size.Y * 0.18),
				lower.Size.Z + 0.16
			),
			CFrame.new(0, lower.Size.Y * 0.16, 0),
			uniform.vest
		)
	end
	addBothArmBands(model, character, uniform.trim, "WorkBand")
end

-- Costume bermesh (dibuat dengan Meshy): templat MeshPart di ServerStorage.CostumeMesh, diberi nama
-- id costume, dengan atribut Anchor (bagian tubuh), Scale dan Offset (CFrame relatif ke Anchor).
local function meshTemplate(costumeId: string): BasePart?
	local root = ServerStorage:FindFirstChild("CostumeMesh")
	local found = if root then root:FindFirstChild(costumeId) else nil
	return if found and found:IsA("BasePart") then found else nil
end

local function attachMesh(
	model: Model,
	character: Model,
	costumeId: string,
	anchorName: string
): boolean
	local template = meshTemplate(costumeId)
	if template == nil or template:GetAttribute("Anchor") ~= anchorName then
		return false
	end
	local anchor = partOrNil(character, anchorName)
	if anchor == nil then
		return false
	end
	local scale = template:GetAttribute("Scale")
	local offset = template:GetAttribute("Offset")
	local mesh = template:Clone()
	mesh.Name = "Costume_" .. costumeId
	mesh.Size = template.Size * (if type(scale) == "number" then scale else 1)
	mesh.CFrame = anchor.CFrame * (if typeof(offset) == "CFrame" then offset else CFrame.new())
	mesh.Anchored = false
	mesh.Massless = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = mesh
	weld.Parent = mesh
	mesh.Parent = model
	return true
end

local function buildCostumeUniform(
	model: Model,
	torso: BasePart,
	lower: BasePart?,
	character: Model,
	uniform: Uniform,
	costumeId: string
)
	local z = frontZ(torso)
	if meshTemplate(costumeId) then
		-- Costume bermesh: hanya mesh-nya (tanpa panel kotak); topi/mahkota dipasang di buildHat.
		attachMesh(model, character, costumeId, "UpperTorso")
		return
	end
	if costumeId == "sayap_malaikat" then
		panel(model, torso, "AngelRobeFront", uniform.vest, 0.92, 0.9, z)
		panel(model, torso, "AngelRobeBack", uniform.vest, 0.92, 0.9, backZ(torso))
		piece(
			model,
			torso,
			"AngelLeftWing",
			Vector3.new(torso.Size.X * 1.35, torso.Size.Y * 0.95, 0.12),
			CFrame.new(-torso.Size.X * 0.72, torso.Size.Y * 0.05, backZ(torso) + 0.18)
				* CFrame.Angles(0, 0, math.rad(-24)),
			Color3.fromRGB(245, 248, 255)
		)
		piece(
			model,
			torso,
			"AngelRightWing",
			Vector3.new(torso.Size.X * 1.35, torso.Size.Y * 0.95, 0.12),
			CFrame.new(torso.Size.X * 0.72, torso.Size.Y * 0.05, backZ(torso) + 0.18)
				* CFrame.Angles(0, 0, math.rad(24)),
			Color3.fromRGB(245, 248, 255)
		)
		trimBar(
			model,
			torso,
			"AngelGoldenSash",
			uniform.trim,
			0.9,
			-torso.Size.Y * 0.18,
			z - 0.04,
			torso.Size.Y * 0.1
		)
		addBadge(
			model,
			torso,
			"AngelBlueGem",
			uniform.badge,
			0,
			torso.Size.Y * 0.22,
			z - 0.08,
			torso.Size.X * 0.18
		)
	elseif costumeId == "naga_api" then
		panel(model, torso, "DragonScaleFront", uniform.vest, 0.92, 0.9, z)
		panel(model, torso, "DragonScaleBack", uniform.vest, 0.92, 0.9, backZ(torso))
		for i = 1, 4 do
			piece(
				model,
				torso,
				"DragonBackSpike" .. tostring(i),
				Vector3.new(torso.Size.X * 0.18, torso.Size.Y * 0.16, 0.22),
				CFrame.new(0, torso.Size.Y * (0.35 - i * 0.18), backZ(torso) + 0.17),
				uniform.trim
			)
		end
		piece(
			model,
			torso,
			"DragonLeftWing",
			Vector3.new(torso.Size.X * 1.1, torso.Size.Y * 0.65, 0.1),
			CFrame.new(-torso.Size.X * 0.68, torso.Size.Y * 0.05, backZ(torso) + 0.16)
				* CFrame.Angles(0, 0, math.rad(-18)),
			uniform.trim
		)
		piece(
			model,
			torso,
			"DragonRightWing",
			Vector3.new(torso.Size.X * 1.1, torso.Size.Y * 0.65, 0.1),
			CFrame.new(torso.Size.X * 0.68, torso.Size.Y * 0.05, backZ(torso) + 0.16)
				* CFrame.Angles(0, 0, math.rad(18)),
			uniform.trim
		)
		addBothArmBands(model, character, uniform.trim, "DragonFireClaw")
	elseif costumeId == "mecha_wing" then
		panel(model, torso, "MechaChestPlate", uniform.vest, 0.94, 0.86, z)
		panel(model, torso, "MechaBackCore", uniform.vest, 0.75, 0.78, backZ(torso) + 0.08)
		piece(
			model,
			torso,
			"MechaLeftWing",
			Vector3.new(torso.Size.X * 1.25, 0.18, 0.12),
			CFrame.new(-torso.Size.X * 0.75, torso.Size.Y * 0.2, backZ(torso) + 0.24)
				* CFrame.Angles(0, 0, math.rad(-14)),
			uniform.trim
		)
		piece(
			model,
			torso,
			"MechaLeftWingLower",
			Vector3.new(torso.Size.X * 1.05, 0.16, 0.12),
			CFrame.new(-torso.Size.X * 0.66, -torso.Size.Y * 0.1, backZ(torso) + 0.22)
				* CFrame.Angles(0, 0, math.rad(14)),
			uniform.trim
		)
		piece(
			model,
			torso,
			"MechaRightWing",
			Vector3.new(torso.Size.X * 1.25, 0.18, 0.12),
			CFrame.new(torso.Size.X * 0.75, torso.Size.Y * 0.2, backZ(torso) + 0.24)
				* CFrame.Angles(0, 0, math.rad(14)),
			uniform.trim
		)
		piece(
			model,
			torso,
			"MechaRightWingLower",
			Vector3.new(torso.Size.X * 1.05, 0.16, 0.12),
			CFrame.new(torso.Size.X * 0.66, -torso.Size.Y * 0.1, backZ(torso) + 0.22)
				* CFrame.Angles(0, 0, math.rad(-14)),
			uniform.trim
		)
		addBadge(
			model,
			torso,
			"MechaPowerCore",
			uniform.badge,
			0,
			torso.Size.Y * 0.14,
			z - 0.08,
			torso.Size.X * 0.2
		)
	elseif costumeId == "penyihir_galaksi" then
		panel(model, torso, "GalaxyRobeFront", uniform.vest, 0.94, 0.9, z)
		panel(model, torso, "GalaxyCapeBack", uniform.vest, 1.08, 1, backZ(torso) + 0.08)
		for _, x in { -0.32, 0, 0.32 } do
			piece(
				model,
				torso,
				"GalaxyStar",
				Vector3.new(torso.Size.X * 0.11, torso.Size.X * 0.11, 0.1),
				CFrame.new(torso.Size.X * x, torso.Size.Y * 0.15, z - 0.08),
				uniform.badge
			)
		end
		piece(
			model,
			torso,
			"GalaxyBelt",
			Vector3.new(torso.Size.X * 0.95, 0.12, torso.Size.Z + 0.18),
			CFrame.new(0, -torso.Size.Y * 0.28, 0),
			uniform.trim
		)
		addBothArmBands(model, character, uniform.trim, "GalaxyMagicCuff")
	elseif costumeId == "raja_petir" then
		panel(model, torso, "ThunderArmorFront", uniform.vest, 0.94, 0.88, z)
		panel(model, torso, "ThunderCapeBack", uniform.vest, 1.02, 0.92, backZ(torso) + 0.08)
		piece(
			model,
			torso,
			"ThunderBoltChest",
			Vector3.new(torso.Size.X * 0.18, torso.Size.Y * 0.72, 0.12),
			CFrame.new(0, 0, z - 0.09) * CFrame.Angles(0, 0, math.rad(-20)),
			uniform.trim
		)
		piece(
			model,
			torso,
			"ThunderLeftAura",
			Vector3.new(torso.Size.X * 0.95, 0.12, 0.12),
			CFrame.new(-torso.Size.X * 0.58, torso.Size.Y * 0.1, backZ(torso) + 0.16)
				* CFrame.Angles(0, 0, math.rad(-28)),
			uniform.badge
		)
		piece(
			model,
			torso,
			"ThunderRightAura",
			Vector3.new(torso.Size.X * 0.95, 0.12, 0.12),
			CFrame.new(torso.Size.X * 0.58, torso.Size.Y * 0.1, backZ(torso) + 0.16)
				* CFrame.Angles(0, 0, math.rad(28)),
			uniform.badge
		)
		addBothArmBands(model, character, uniform.trim, "ThunderCuff")
	else
		buildDefaultUniform(model, torso, lower, character, uniform)
	end
end

local function buildBodyUniform(model: Model, character: Model, uniform: Uniform, jobId: string)
	local upper = partOrNil(character, "UpperTorso")
	local lower = partOrNil(character, "LowerTorso")
	local torso = upper or partOrNil(character, "Torso")
	if torso == nil then
		return
	end

	if jobId:sub(1, 8) == "costume:" then
		buildCostumeUniform(model, torso, lower, character, uniform, jobId:sub(9))
	elseif jobId == "kurir" then
		buildDeliveryUniform(model, torso, character, uniform)
	elseif jobId == "mekanik" then
		buildMechanicUniform(model, torso, lower, character, uniform)
	elseif jobId == "sopir" then
		buildDriverUniform(model, torso, character, uniform)
	elseif jobId == "pilot" then
		buildPilotUniform(model, torso, character, uniform)
	elseif jobId == "polisi" then
		buildPoliceUniform(model, torso, lower, character, uniform)
	elseif jobId == "pemadam" then
		buildFirefighterUniform(model, torso, lower, character, uniform)
	elseif jobId == "dokter" then
		buildDoctorUniform(model, torso, lower, character, uniform)
	else
		buildDefaultUniform(model, torso, lower, character, uniform)
	end
end

local function buildHat(model: Model, character: Model, uniform: Uniform, jobId: string)
	local head = partOrNil(character, "Head")
	if head == nil then
		return
	end

	local width = math.max(head.Size.X, head.Size.Z)
	local height = head.Size.Y
	if head:FindFirstChildOfClass("SpecialMesh") then
		width, height = 1.25, 1.25
	end
	width = math.clamp(width, 0.9, 2.2)
	local top = height / 2
	local color = uniform.hatColor
	local costumeId = if jobId:sub(1, 8) == "costume:" then jobId:sub(9) else ""
	if costumeId ~= "" and meshTemplate(costumeId) then
		attachMesh(model, character, costumeId, "Head")
		if costumeId ~= "sayap_malaikat" then
			return -- naga/mecha/topi/mahkota: cukup meshnya; malaikat tetap memakai halo
		end
	end
	if costumeId == "sayap_malaikat" then
		disc(model, head, "AngelHalo", 0.08, width * 1.28, top + 0.7, uniform.trim)
		piece(
			model,
			head,
			"AngelHaloGlow",
			Vector3.new(width * 0.8, 0.06, 0.06),
			CFrame.new(0, top + 0.7, -width * 0.02),
			uniform.badge
		)
		return
	elseif costumeId == "naga_api" then
		disc(model, head, "DragonHornBand", 0.14, width * 1.05, top + 0.02, color)
		piece(
			model,
			head,
			"DragonLeftHorn",
			Vector3.new(0.12, width * 0.55, 0.12),
			CFrame.new(-width * 0.34, top + 0.38, 0) * CFrame.Angles(0, 0, math.rad(-25)),
			uniform.trim
		)
		piece(
			model,
			head,
			"DragonRightHorn",
			Vector3.new(0.12, width * 0.55, 0.12),
			CFrame.new(width * 0.34, top + 0.38, 0) * CFrame.Angles(0, 0, math.rad(25)),
			uniform.trim
		)
		return
	elseif costumeId == "mecha_wing" then
		disc(model, head, "MechaHelmet", 0.34, width * 1.1, top + 0.14, color)
		piece(
			model,
			head,
			"MechaVisor",
			Vector3.new(width * 0.72, 0.16, 0.08),
			CFrame.new(0, top + 0.05, -width * 0.52),
			uniform.trim
		)
		return
	elseif costumeId == "penyihir_galaksi" then
		disc(model, head, "WizardHatBrim", 0.1, width * 1.45, top + 0.02, color)
		piece(
			model,
			head,
			"WizardHatCone",
			Vector3.new(width * 0.68, width * 0.82, width * 0.68),
			CFrame.new(0, top + 0.48, 0),
			color
		)
		piece(
			model,
			head,
			"WizardStarBadge",
			Vector3.new(width * 0.22, width * 0.22, 0.08),
			CFrame.new(0, top + 0.5, -width * 0.36),
			uniform.badge
		)
		return
	elseif costumeId == "raja_petir" then
		disc(model, head, "ThunderCrownBand", 0.12, width * 1.05, top + 0.08, uniform.trim)
		for _, x in { -0.32, 0, 0.32 } do
			piece(
				model,
				head,
				"ThunderCrownSpike",
				Vector3.new(width * 0.13, width * 0.38, 0.08),
				CFrame.new(width * x, top + 0.34, -width * 0.18),
				uniform.trim
			)
		end
		return
	end

	if uniform.hat == "cap" then
		disc(model, head, "WorkCapCrown", 0.24, width * 1.02, top + 0.05, color)
		piece(
			model,
			head,
			"WorkCapBrim",
			Vector3.new(width * 0.7, 0.08, width * 0.36),
			CFrame.new(0, top - 0.02, -width * 0.57),
			color
		)
		piece(
			model,
			head,
			jobId == "kurir" and "PackageCapLogo" or "ToolCapLogo",
			Vector3.new(width * 0.22, width * 0.2, 0.06),
			CFrame.new(0, top + 0.08, -width * 0.51),
			uniform.badge
		)
	elseif uniform.hat == "helmet" then
		disc(model, head, "FireHelmetBrim", 0.12, width * 1.42, top - 0.04, color)
		disc(model, head, "FireHelmetCrown", 0.4, width * 1.05, top + 0.17, color)
		piece(
			model,
			head,
			"FireHelmetStripe",
			Vector3.new(0.16, 0.12, width * 0.95),
			CFrame.new(0, top + 0.43, 0),
			uniform.trim
		)
		piece(
			model,
			head,
			"FireHelmetShield",
			Vector3.new(width * 0.26, width * 0.24, 0.07),
			CFrame.new(0, top + 0.12, -width * 0.54),
			uniform.badge
		)
	elseif uniform.hat == "peaked" then
		disc(model, head, "PeakedHatBand", 0.18, width * 1.02, top + 0.02, DARK)
		disc(model, head, "PeakedHatCrown", 0.24, width * 1.12, top + 0.24, color)
		piece(
			model,
			head,
			"PeakedHatVisor",
			Vector3.new(width * 0.75, 0.07, width * 0.34),
			CFrame.new(0, top - 0.05, -width * 0.55),
			DARK
		)
		piece(
			model,
			head,
			jobId == "pilot" and "PilotHatWings" or "OfficerHatBadge",
			Vector3.new(width * 0.22, width * 0.18, 0.06),
			CFrame.new(0, top + 0.12, -width * 0.52),
			uniform.badge
		)
		if jobId == "pilot" then
			piece(
				model,
				head,
				"PilotHatGoldBar",
				Vector3.new(width * 0.7, 0.045, 0.055),
				CFrame.new(0, top + 0.04, -width * 0.53),
				uniform.trim
			)
		end
	else -- "mirror": ikat kepala dokter dengan cermin kecil
		disc(model, head, "DoctorHeadBand", 0.12, width * 1.02, height * 0.18, uniform.trim)
		local mirror = piece(
			model,
			head,
			"DoctorHeadMirror",
			Vector3.new(0.06, width * 0.34, width * 0.34),
			CFrame.new(0, height * 0.25, -width * 0.54) * CFrame.Angles(0, math.rad(90), 0),
			color,
			Enum.PartType.Cylinder
		)
		mirror.Material = Enum.Material.Metal
	end
end

local function remove(character: Model)
	local existing = character:FindFirstChild(MODEL_NAME)
	if existing then
		existing.Parent = nil
	end
end

local function apply(character: Model, uniform: Uniform, jobId: string)
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("JobId", jobId)
	buildBodyUniform(model, character, uniform, jobId)
	buildHat(model, character, uniform, jobId)
	if #model:GetChildren() > 0 then
		model.Parent = character
	else
		model:Destroy()
	end
end

-- ---------------------------------------------------------------- API server

-- Menyesuaikan seragam karakter dengan pekerjaan pemain saat ini.
function UniformService.refresh(player: Player)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end

	remove(character)

	local data = DataService.getData(player)
	local def = if data then JobConfig.get(data.jobs.current) else nil
	if def then
		apply(character, def.uniform, def.id)
		return
	end
	-- Jika tidak sedang bekerja, tampilkan costume/fashion aktif pemain.
	local fashion: any = if data then data.fashion else nil
	local active = if type(fashion) == "table" and type(fashion.active) == "string"
		then fashion.active
		else ""
	local outfit = FashionConfig.get(active)
	if outfit then
		apply(character, outfit.look, "costume:" .. outfit.id)
	end
end

-- ---------------------------------------------------------------- bootstrap

local function safeRefresh(player: Player)
	local ok, err = pcall(UniformService.refresh, player)
	if not ok then
		warn("[Uniform] gagal memasang seragam: " .. tostring(err))
	end
end

local function onPlayerAdded(player: Player)
	-- Ukuran badan baru pasti setelah tampilan avatar selesai dimuat.
	player.CharacterAppearanceLoaded:Connect(function()
		safeRefresh(player)
	end)
	if player.Character and player:HasAppearanceLoaded() then
		safeRefresh(player)
	end
end

function UniformService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.ProfileLoaded:Connect(function(player: Player)
		if player:HasAppearanceLoaded() then
			safeRefresh(player)
		end
	end)
end

return UniformService
