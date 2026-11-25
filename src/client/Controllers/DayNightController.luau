--!strict
-- DayNightController: tampilan siang/malam di client.
--   * menghaluskan jam di antara pembaruan server
--   * memudarkan pencahayaan ke suasana malam (tetap cukup terang untuk anak-anak)
--   * menyalakan lampu (tag NightLight) dan sebagian jendela (tag NightWindow)
-- Nilai siang diambil dari Lighting saat masuk (hasil StyleWorld), jadi kalau
-- tampilan siang diubah di Studio, modul ini ikut tanpa disentuh.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))

local DayNightController = {}

local rgb = Color3.fromRGB

-- Suasana malam penuh. Siang = nilai Lighting saat masuk.
local NIGHT = {
	brightness = 0.9,
	exposure = 0.15,
	ambient = rgb(58, 64, 96),
	outdoorAmbient = rgb(84, 96, 140),
	atmosphereColor = rgb(52, 62, 96),
	atmosphereDecay = rgb(24, 30, 56),
	atmosphereDensity = 0.2,
	atmosphereHaze = 0.2,
	atmosphereGlare = 0,
}
-- Rona jingga saat matahari terbit/terbenam (puncaknya di tengah peralihan).
local TWILIGHT_TINT = rgb(255, 214, 178)

local WINDOW_COLORS =
	{ rgb(255, 190, 96), rgb(255, 204, 120), rgb(250, 176, 84), rgb(176, 208, 240) }
local LAMP_OFF_COLOR = rgb(196, 196, 190)
local APPLY_PER_FRAME = 40
local HEADLIGHT_CHECK_SECONDS = 2 -- mobil yang baru muncul saat malam ikut menyala

type Saved = { material: Enum.Material, color: Color3, reflectance: number }

-- Tabel biasa (bukan weak): pembungkus Instance di Luau bisa ikut tersapu GC
-- walau part-nya masih ada, lalu tampilan asli hilang. Dibersihkan saat part dilepas.
local saved: { [BasePart]: Saved } = {}
local queue: { Instance } = {}
local lightsOn = false
local lastFactor = -1
local headlightTimer = 0

local day: {
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
	tint: Color3,
}
local atmosphere: Atmosphere?
local colorCorrection: ColorCorrectionEffect?

-- ---------------------------------------------------------------- lampu & jendela

local function remember(part: BasePart): Saved
	local s = saved[part]
	if s == nil then
		s = { material = part.Material, color = part.Color, reflectance = part.Reflectance }
		saved[part] = s
	end
	return s
end

-- Pilihan tetap per jendela (dari posisinya), supaya sama di semua pemain.
local function windowSeed(part: BasePart): number
	local p = part.Position
	return math.floor(math.abs(p.X * 7.31 + p.Y * 13.17 + p.Z * 3.73))
end

local function apply(inst: Instance, on: boolean)
	if not inst:IsA("BasePart") then
		return
	end
	local s = remember(inst)
	if CollectionService:HasTag(inst, DayNightConfig.TAG_WINDOW) then
		local seed = windowSeed(inst)
		if on and seed % 100 < DayNightConfig.WINDOW_LIT_PERCENT then
			inst.Material = Enum.Material.Neon
			inst.Color = WINDOW_COLORS[seed % #WINDOW_COLORS + 1]
			inst.Reflectance = 0
		else
			inst.Material = s.material
			inst.Color = s.color
			inst.Reflectance = s.reflectance
		end
		return
	end
	if s.material == Enum.Material.Neon then
		inst.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		inst.Color = if on then s.color else LAMP_OFF_COLOR
	end
	for _, child in inst:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = on
		end
	end
end

local function setLights(on: boolean)
	lightsOn = on
	table.clear(queue)
	for _, tag in { DayNightConfig.TAG_LIGHT, DayNightConfig.TAG_WINDOW } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(queue, inst)
		end
	end
	-- Acak urutannya supaya lampu kota menyala bergiliran, tidak serentak.
	local random = Random.new()
	for i = #queue, 2, -1 do
		local j = random:NextInteger(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end
end

-- Lampu depan mobil: sorot lokal di part "Headlight" tiap kendaraan (hanya tampilan).
local function setHeadlights(on: boolean)
	for _, vehicle in CollectionService:GetTagged(VehicleConfig.TAG_VEHICLE) do
		for _, d in vehicle:GetDescendants() do
			if d.Name == "Headlight" and d:IsA("BasePart") then
				local light = d:FindFirstChildOfClass("SpotLight")
				if light == nil and on then
					local created = Instance.new("SpotLight")
					created.Face = Enum.NormalId.Front
					created.Angle = 75
					created.Range = 60
					created.Brightness = 2.5
					created.Color = d.Color
					created.Shadows = false
					created.Parent = d
					light = created
				end
				if light then
					light.Enabled = on
				end
			end
		end
	end
end

local function drainQueue()
	local count = math.min(#queue, APPLY_PER_FRAME)
	for _ = 1, count do
		local inst = table.remove(queue) :: Instance
		if inst.Parent then
			apply(inst, lightsOn)
		end
	end
end

-- ---------------------------------------------------------------- pencahayaan

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function applyLighting(f: number)
	Lighting.Brightness = lerp(day.brightness, NIGHT.brightness, f)
	Lighting.ExposureCompensation = lerp(day.exposure, NIGHT.exposure, f)
	Lighting.Ambient = day.ambient:Lerp(NIGHT.ambient, f)
	Lighting.OutdoorAmbient = day.outdoorAmbient:Lerp(NIGHT.outdoorAmbient, f)
	if atmosphere then
		atmosphere.Color = day.atmosphereColor:Lerp(NIGHT.atmosphereColor, f)
		atmosphere.Decay = day.atmosphereDecay:Lerp(NIGHT.atmosphereDecay, f)
		atmosphere.Density = lerp(day.atmosphereDensity, NIGHT.atmosphereDensity, f)
		atmosphere.Haze = lerp(day.atmosphereHaze, NIGHT.atmosphereHaze, f)
		atmosphere.Glare = lerp(day.atmosphereGlare, NIGHT.atmosphereGlare, f)
	end
	if colorCorrection then
		local twilight = 1 - math.abs(2 * f - 1)
		colorCorrection.TintColor = day.tint:Lerp(TWILIGHT_TINT, twilight * 0.7)
	end
end

-- Langit berubah sangat pelan, jadi jam cukup diperbarui ~10x per detik (hemat di HP).
local CLOCK_STEP = 0.1
local clockAccum = 0

local function update(frameDt: number)
	clockAccum += frameDt
	if clockAccum < CLOCK_STEP then
		return
	end
	local dt = clockAccum
	clockAccum = 0
	local clock = Lighting.ClockTime
	-- Majukan jam secara lokal; server mengoreksi tiap beberapa detik.
	clock = (clock + DayNightConfig.hoursPerSecond(clock) * dt) % 24
	Lighting.ClockTime = clock

	local f = DayNightConfig.nightFactor(clock)
	if math.abs(f - lastFactor) > 0.004 then
		lastFactor = f
		applyLighting(f)
	end
	local shouldBeOn = f >= DayNightConfig.LIGHTS_ON_AT
	if shouldBeOn ~= lightsOn then
		setLights(shouldBeOn)
		setHeadlights(shouldBeOn)
	end
	headlightTimer += dt
	if lightsOn and headlightTimer >= HEADLIGHT_CHECK_SECONDS then
		headlightTimer = 0
		setHeadlights(true)
	end
	if #queue > 0 then
		drainQueue()
	end
end

-- ---------------------------------------------------------------- bootstrap

function DayNightController.isNight(): boolean
	return lightsOn
end

function DayNightController.init()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	day = {
		brightness = Lighting.Brightness,
		exposure = Lighting.ExposureCompensation,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		atmosphereColor = if atmosphere then atmosphere.Color else NIGHT.atmosphereColor,
		atmosphereDecay = if atmosphere then atmosphere.Decay else NIGHT.atmosphereDecay,
		atmosphereDensity = if atmosphere then atmosphere.Density else NIGHT.atmosphereDensity,
		atmosphereHaze = if atmosphere then atmosphere.Haze else NIGHT.atmosphereHaze,
		atmosphereGlare = if atmosphere then atmosphere.Glare else NIGHT.atmosphereGlare,
		tint = if colorCorrection then colorCorrection.TintColor else Color3.new(1, 1, 1),
	}
end

function DayNightController.start()
	-- Siang hari lampu padam: terapkan ke semua yang sudah ter-stream.
	setLights(DayNightConfig.nightFactor(Lighting.ClockTime) >= DayNightConfig.LIGHTS_ON_AT)

	-- Bagian peta yang baru ter-stream menyesuaikan keadaan saat ini.
	for _, tag in { DayNightConfig.TAG_LIGHT, DayNightConfig.TAG_WINDOW } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
			apply(inst, lightsOn)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
			saved[inst :: BasePart] = nil
		end)
	end

	RunService.Heartbeat:Connect(update)
end

return DayNightController
