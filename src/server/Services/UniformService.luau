--!strict
-- UniformService: seragam pekerjaan. Selama pemain menjalani pekerjaan, topi dan
-- rompi sederhana (dari Part) ditempelkan ke karakternya; saat berhenti, dilepas.
-- Bentuk dan warna tiap seragam ada di JobConfig (`uniform`), jadi pekerjaan
-- baru cukup mengisi data itu.
--   * ukuran mengikuti ukuran kepala/badan avatar (R15 maupun R6)
--   * topi bawaan avatar disembunyikan sementara supaya tidak bertumpuk
--   * semua part tanpa massa dan tanpa tabrakan, jadi tidak mengubah gerak karakter

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local JobConfig = require(Shared:WaitForChild("JobConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

type Uniform = JobConfig.Uniform

local UniformService = {}

local MODEL_NAME = "JobUniform"
local ATTR_RESTORE = "UniformRestore" -- transparansi asli topi avatar yang disembunyikan
local DARK = Color3.fromRGB(34, 36, 42)
local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90)) -- silinder berdiri tegak

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

local function buildVest(model: Model, character: Model, uniform: Uniform)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	local size = torso.Size
	piece(model, torso, "Vest", size + Vector3.new(0.3, 0.06, 0.3), CFrame.new(), uniform.vest)
	piece(
		model,
		torso,
		"VestStripe",
		Vector3.new(size.X + 0.36, 0.22, size.Z + 0.36),
		CFrame.new(0, -size.Y * 0.2, 0),
		uniform.trim
	)
	piece(
		model,
		torso,
		"Badge",
		Vector3.new(0.34, 0.34, 0.08),
		CFrame.new(-size.X * 0.24, size.Y * 0.22, -(size.Z / 2 + 0.17)),
		uniform.badge
	)
	local lower = character:FindFirstChild("LowerTorso")
	if lower and lower:IsA("BasePart") then
		piece(
			model,
			lower,
			"VestLower",
			lower.Size + Vector3.new(0.3, 0.02, 0.3),
			CFrame.new(),
			uniform.vest
		)
	end
end

local function buildHat(model: Model, character: Model, uniform: Uniform)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	-- Kepala R6 adalah Part 2x1x1 dengan mesh bulat berskala 1,25.
	local width = math.max(head.Size.X, head.Size.Z)
	local height = head.Size.Y
	if head:FindFirstChildOfClass("SpecialMesh") then
		width, height = 1.25, 1.25
	end
	width = math.clamp(width, 1, 2.2)
	local top = height / 2
	local color = uniform.hatColor

	if uniform.hat == "cap" then
		disc(model, head, "CapCrown", 0.45, width * 1.12, top + 0.12, color)
		piece(
			model,
			head,
			"CapBrim",
			Vector3.new(width * 0.9, 0.1, width * 0.55),
			CFrame.new(0, top - 0.02, -width * 0.75),
			color
		)
	elseif uniform.hat == "helmet" then
		disc(model, head, "HelmetBrim", 0.12, width * 1.7, top - 0.08, color)
		disc(model, head, "HelmetCrown", 0.6, width * 1.15, top + 0.22, color)
		piece(
			model,
			head,
			"HelmetCrest",
			Vector3.new(0.22, 0.25, width * 1.15),
			CFrame.new(0, top + 0.6, 0),
			uniform.trim
		)
		piece(
			model,
			head,
			"HelmetBadge",
			Vector3.new(0.4, 0.36, 0.08),
			CFrame.new(0, top + 0.24, -width * 0.585),
			uniform.badge
		)
	elseif uniform.hat == "peaked" then
		disc(model, head, "HatBand", 0.26, width * 1.1, top + 0.02, DARK)
		disc(model, head, "HatCrown", 0.3, width * 1.36, top + 0.3, color)
		piece(
			model,
			head,
			"HatVisor",
			Vector3.new(width * 0.9, 0.08, width * 0.45),
			CFrame.new(0, top - 0.08, -width * 0.7),
			DARK
		)
		piece(
			model,
			head,
			"HatBadge",
			Vector3.new(0.3, 0.3, 0.08),
			CFrame.new(0, top + 0.16, -width * 0.57),
			uniform.badge
		)
	else -- "mirror": ikat kepala dokter dengan cermin kecil
		disc(model, head, "HeadBand", 0.16, width * 1.08, height * 0.24, uniform.trim)
		local mirror = piece(
			model,
			head,
			"HeadMirror",
			Vector3.new(0.08, 0.5, 0.5),
			CFrame.new(0, height * 0.3, -width * 0.58) * CFrame.Angles(0, math.rad(90), 0),
			color,
			Enum.PartType.Cylinder
		)
		mirror.Material = Enum.Material.Metal
	end
end

local function setAvatarHatsHidden(character: Model, hidden: boolean)
	for _, child in character:GetChildren() do
		if not child:IsA("Accessory") or child.AccessoryType ~= Enum.AccessoryType.Hat then
			continue
		end
		local handle = child:FindFirstChild("Handle")
		if handle == nil or not handle:IsA("BasePart") then
			continue
		end
		local saved = handle:GetAttribute(ATTR_RESTORE)
		if hidden and saved == nil then
			handle:SetAttribute(ATTR_RESTORE, handle.Transparency)
			handle.Transparency = 1
		elseif not hidden and type(saved) == "number" then
			handle.Transparency = saved
			handle:SetAttribute(ATTR_RESTORE, nil)
		end
	end
end

local function remove(character: Model)
	local existing = character:FindFirstChild(MODEL_NAME)
	if existing then
		existing:Destroy()
	end
	setAvatarHatsHidden(character, false)
end

local function apply(character: Model, uniform: Uniform)
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	buildVest(model, character, uniform)
	buildHat(model, character, uniform)
	setAvatarHatsHidden(character, uniform.hat ~= "mirror")
	model.Parent = character
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
		apply(character, def.uniform)
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
