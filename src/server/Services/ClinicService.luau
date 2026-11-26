--!strict
--[[
	ClinicService: klinik di dalam Rumah Sakit (Workspace.Map.Interiors.RumahSakit, y = 2000).

	Petugas tetap (NPC R15): Petugas Registrasi di meja pendaftaran dan Apoteker di apotek.
	Pasien (NPC atau pemain) mendaftar, dapat nomor antrean (papan antrean di dinding), lalu duduk.
	Tiga jenis keluhan, semuanya ringan dan ramah anak (tanpa darah):
	  demam      : Panggil ke ranjang -> Ukur suhu -> Periksa stetoskop -> obat
	  batuk pilek: Periksa stetoskop -> sirup
	  luka kecil : Bersihkan luka -> plester
	Setelah langkah periksa selesai, Apoteker NPC membawa obatnya sendiri ke Meja Dokter (dekat
	ranjang tindakan); dokter cukup mengambilnya di meja itu lalu memberikannya ke pasien, jadi tidak
	bolak-balik ke apotek. Gaji lewat JobService.payExternal; bintang 1-3 menurut kecepatan
	(bonus gaji). Semua keputusan di server.

	Hook untuk misi harian: ClinicService.PatientCured (dokter, jenisPasien, bintang, keluhan) dan
	atribut Player "KlinikSembuh" (jumlah pasien sembuh).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local JobService = require(script.Parent:WaitForChild("JobService"))
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClinicService = {}
local curedEvent = Instance.new("BindableEvent")
ClinicService.PatientCured = curedEvent.Event

-- ---------------------------------------------------------------- pengaturan
local CENTER = Vector3.new(40, 2000, 176)
local HALF_X, HALF_Z = 30, 24
local DOOR_INSIDE = Vector3.new(40, 2003.5, 195.5)
local DOOR_OUT = Vector3.new(40, 2003.5, 199.5)

local REG_NPC_HOME = Vector3.new(40, 2003.5, 158.4) -- petugas registrasi, di balik meja
local REG_FRONT = Vector3.new(40, 2003.5, 166.8) -- pasien berdiri di depan meja
local REGISTER_POINT = Vector3.new(40, 2003.2, 166.2) -- tombol daftar untuk pemain
local PHARMACIST_HOME = Vector3.new(64.2, 2003.5, 174.4)
local DESK_POINT = Vector3.new(58, 2003.4, 173.2) -- Meja Dokter (dekat ranjang tindakan)
local DESK_DELIVER = Vector3.new(61.2, 2003.5, 174.6)
local BOARD_POSITION = Vector3.new(20.5, 2008.2, 154.3)
local DOCTOR_SEAT = Vector3.new(58, 2001.55, 175.2) -- kursi dokter di belakang Meja Dokter
local DESK_CHAIR = Vector3.new(58.9, 2001.55, 170.5) -- kursi periksa pasien, menghadap dokter
local DESK_APPROACH = Vector3.new(58.9, 2003.5, 168.2)
local CALL_POINT = Vector3.new(56.4, 2003.4, 173.2) -- tombol panggil nomor antrean
local BED_LIE_HEIGHT = 2002.75 -- tinggi pusat badan pasien yang berbaring

local MAX_NPC = 4
local SPAWN_GAP = 14
local NPC_LIFETIME = 420
local IDLE_LEAVE = 75
local PLAYER_PATIENT_TIMEOUT = 420
local UNSEAT_GRACE = 15
local MAX_DISTANCE = 14
local PAY_NPC = 35
local PAY_PLAYER = 25
local PAIR_COOLDOWN = 180
local STAR3_SECONDS = 100 -- sejak mendaftar sampai sembuh
local STAR2_SECONDS = 190
local BONUS = { 0, 8, 15 } -- per bintang
local DUTY_BONUS = 5 -- tambahan gaji untuk dokter jaga
local BELL_SOUND = "rbxasset://sounds/electronicpingshort.wav"

-- mini-game ketuk per langkah periksa (kunci = teks langkah di TYPES)
local MINIGAMES: { [string]: { icon: string, title: string, taps: number, seconds: number } } = {
	["Ukur suhu"] = { icon = "🌡️", title = "Ketuk termometer!", taps = 5, seconds = 10 },
	["Periksa dengan stetoskop"] = {
		icon = "💗",
		title = "Ketuk detak jantung!",
		taps = 6,
		seconds = 11,
	},
	["Bersihkan luka"] = { icon = "🫧", title = "Ketuk gelembung sabun!", taps = 5, seconds = 10 },
}

type TypeDef = {
	name: string,
	icon: string,
	bed: boolean,
	steps: { string },
	holds: { number },
	tips: { string },
	medItem: string,
	medAction: string,
	medHold: number,
}

local TYPES: { [string]: TypeDef } = {
	demam = {
		name = "Demam",
		icon = "🌡️",
		bed = true,
		steps = { "Ukur suhu", "Periksa dengan stetoskop" },
		holds = { 2, 2 },
		tips = {
			"Suhunya agak tinggi. Sekarang dengarkan napasnya dengan stetoskop.",
			"Selesai diperiksa. Tunggu apoteker membawa obat penurun panas ke Meja Dokter.",
		},
		medItem = "obat",
		medAction = "Beri obat demam",
		medHold = 2,
	},
	batuk = {
		name = "Batuk pilek",
		icon = "🤧",
		bed = false,
		steps = { "Periksa dengan stetoskop" },
		holds = { 3 },
		tips = { "Selesai diperiksa. Tunggu apoteker membawa sirup ke Meja Dokter." },
		medItem = "sirup",
		medAction = "Beri sirup batuk",
		medHold = 2,
	},
	luka = {
		name = "Luka kecil",
		icon = "🩹",
		bed = false,
		steps = { "Bersihkan luka" },
		holds = { 2 },
		tips = { "Lukanya sudah bersih. Tunggu apoteker membawa plester ke Meja Dokter." },
		medItem = "plester",
		medAction = "Pasang plester",
		medHold = 2,
	},
}
local TYPE_KEYS = { "demam", "batuk", "luka" }
local PROP_MESH =
	{ obat = "PropKlinikObat", sirup = "PropKlinikSirup", plester = "PropKlinikPlester" }
local PROP_COLOR = {
	obat = Color3.fromRGB(26, 166, 158),
	sirup = Color3.fromRGB(95, 160, 215),
	plester = Color3.fromRGB(245, 195, 170),
}

local NAMES = {
	"Budi",
	"Siti",
	"Rina",
	"Dedi",
	"Putri",
	"Agus",
	"Nina",
	"Tono",
	"Maya",
	"Joko",
	"Dewi",
	"Fajar",
}
local SKINS = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 100),
	Color3.fromRGB(140, 96, 70),
}
local SHIRTS = {
	Color3.fromRGB(120, 190, 240),
	Color3.fromRGB(250, 190, 120),
	Color3.fromRGB(180, 230, 170),
	Color3.fromRGB(240, 160, 190),
	Color3.fromRGB(200, 180, 240),
}
local PANTS =
	{ Color3.fromRGB(60, 80, 130), Color3.fromRGB(90, 70, 60), Color3.fromRGB(70, 110, 90) }
local HAIRS =
	{ Color3.fromRGB(30, 25, 22), Color3.fromRGB(80, 55, 35), Color3.fromRGB(170, 120, 60) }

local CHAIR_X = { 20.6, 25 }
local CHAIR_Z = { 164, 169, 174, 179, 184 }
local BEDS = { Vector3.new(55, 2002.7, 166), Vector3.new(64.5, 2002.7, 166) }

-- ---------------------------------------------------------------- keadaan
type Patient = {
	kind: "npc" | "player",
	name: string,
	typeKey: string,
	ticket: string,
	stage: string, -- antre | menunggu | diRanjang | tungguObat | obatSiap | sembuh
	step: number, -- jumlah langkah periksa yang sudah selesai
	onBed: boolean,
	seat: Seat,
	prompt: ProximityPrompt,
	label: TextLabel,
	model: Model?,
	player: Player?,
	bornAt: number,
	registeredAt: number,
	unseatedAt: number?,
	carrier: Player?,
	called: boolean,
	lying: boolean,
	calledAt: number?,
}

local folder: Folder
local seatInfo: { [Seat]: { patient: Patient?, bed: boolean, desk: boolean? } } = {}
local patients: { Patient } = {}
local orders: { Patient } = {}
local deskItems: { { patient: Patient, prop: BasePart } } = {}
local hasMedicine: { [Player]: Patient } = {}
local handProp: { [Player]: BasePart } = {}
local lastAction: { [Player]: number } = {}
local lastPaid: { [string]: number } = {}
local lastSpawn = 0
local lastDoctorSeen = os.clock()
local doctorPresent = false
local ticketCounter = 0
local rng = Random.new()
local regNpc: Model? = nil
local pharmacist: Model? = nil
local deskPrompt: ProximityPrompt? = nil
local boardBody: TextLabel? = nil
local lastBoardText = ""
local pending: {
	[Player]: {
		patient: Patient,
		step: number,
		token: string,
		startedAt: number,
		taps: number,
		seconds: number,
	},
} =
	{}
local doctorSince: { [Player]: number } = {}
local dutyDoctor: Player? = nil
local dutyTag: BillboardGui? = nil
local deskSeat: Seat? = nil
local callPrompt: ProximityPrompt? = nil
local inClinic: { [Player]: boolean } = {}
local noDoctorAt: number? = nil
local doctorSeatRef: Seat? = nil
local sitPromptRef: ProximityPrompt? = nil
local dutyLabel: TextLabel? = nil
local bellSound: Sound? = nil
local startRemote: RemoteEvent
local doneRemote: RemoteEvent

-- ---------------------------------------------------------------- utilitas
local function inside(position: Vector3): boolean
	return math.abs(position.X - CENTER.X) < HALF_X
		and math.abs(position.Z - CENTER.Z) < HALF_Z
		and position.Y > CENTER.Y - 6
		and position.Y < CENTER.Y + 30
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function isDoctor(player: Player): boolean
	return JobService.getJob(player) == "dokter"
end

local function insideDoctors(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isDoctor(player) and inside(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function allow(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.4 then
		return false
	end
	lastAction[player] = now
	return true
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function makeInvisible(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
end

local function makeSeat(
	name: string,
	position: Vector3,
	facing: Vector3,
	bed: boolean,
	track: boolean?
): Seat
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Size = Vector3.new(2, 0.4, 2)
	makeInvisible(seat)
	seat.CFrame = CFrame.lookAt(position, position + facing)
	seat.Parent = folder
	if track ~= false then
		seatInfo[seat] = { patient = nil, bed = bed }
	end
	return seat
end

local function makePrompt(
	parent: BasePart,
	action: string,
	object: string,
	hold: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function makeBillboard(
	adornee: BasePart,
	width: number,
	offset: number,
	textColor: Color3
): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(math.floor(width * 0.74), 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 16
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function typeOf(patient: Patient): TypeDef
	return TYPES[patient.typeKey]
end

local function starsText(stars: number): string
	return string.rep("⭐", stars)
end

-- jalan ke titik (mendatar) dengan batas waktu; tidak menggantung bila terhalang
local function walkTo(model: Model, target: Vector3, timeout: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return
	end
	humanoid:MoveTo(target)
	local started = os.clock()
	local refreshed = started
	while os.clock() - started < timeout do
		if model.Parent == nil then
			return
		end
		local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
		if flat.Magnitude < 2 then
			return
		end
		task.wait(0.15)
		if os.clock() - refreshed > 5 then
			refreshed = os.clock()
			humanoid:MoveTo(target)
		end
	end
end

-- ---------------------------------------------------------------- NPC
-- wajah ramah (mata, pipi, mulut tersenyum) digambar sebagai SurfaceGui di sisi depan kepala
local function addFace(head: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Wajah"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0
	gui.Parent = head
	local ink = Color3.fromRGB(35, 30, 32)
	local function dot(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		transparency: number?
	)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency or 0
		f.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = gui
	end
	dot(68, 84, 26, 38, ink) -- mata
	dot(132, 84, 26, 38, ink)
	dot(73, 76, 9, 12, Color3.new(1, 1, 1)) -- kilau mata
	dot(137, 76, 9, 12, Color3.new(1, 1, 1))
	dot(44, 124, 30, 18, Color3.fromRGB(255, 130, 140), 0.55) -- pipi
	dot(156, 124, 30, 18, Color3.fromRGB(255, 130, 140), 0.55)
	for index = 0, 6 do -- mulut senyum melengkung
		local t = (index - 3) / 3
		dot(100 + t * 38, 152 - t * t * 22, 15, 13, ink) -- ujung mulut lebih tinggi dari tengah = senyum
	end
end

local function buildNpc(
	name: string,
	shirt: Color3?,
	pants: Color3?,
	hair: Color3?,
	sleeves: Color3?
): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKINS)
	local shirtColor = shirt or pick(SHIRTS)
	local pantsColor = pants or pick(PANTS)
	description.HeadColor = skin
	description.LeftArmColor = sleeves or skin
	description.RightArmColor = sleeves or skin
	description.TorsoColor = shirtColor
	description.LeftLegColor = pantsColor
	description.RightLegColor = pantsColor
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or model == nil then
		return nil
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head") :: BasePart?
	if humanoid == nil or head == nil then
		model:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 9
	local hairPart = Instance.new("Part")
	hairPart.Name = "Rambut"
	hairPart.Size = Vector3.new(1.3, 0.55, 1.3)
	hairPart.Color = hair or pick(HAIRS)
	hairPart.Material = Enum.Material.SmoothPlastic
	hairPart.CanCollide = false
	hairPart.Massless = true
	hairPart.Parent = model
	hairPart.CFrame = head.CFrame * CFrame.new(0, 0.62, 0)
	addFace(head)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hairPart
	weld.Parent = hairPart
	return model
end

-- jas putih apoteker: ekor jas di pinggul + lencana palang hijau di dada
local function addCoat(model: Model)
	local function attach(part: Part, anchorName: string, offset: CFrame)
		local anchor = model:FindFirstChild(anchorName) :: BasePart?
		if anchor == nil then
			part:Destroy()
			return
		end
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = anchor.CFrame * offset
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.Parent = part
	end
	local tail = Instance.new("Part")
	tail.Name = "EkorJas"
	tail.Size = Vector3.new(2.15, 1.5, 1.15)
	tail.Color = Color3.fromRGB(245, 247, 250)
	attach(tail, "LowerTorso", CFrame.new(0, -0.55, 0))
	local green = Color3.fromRGB(40, 180, 160)
	local bar1 = Instance.new("Part")
	bar1.Name = "LencanaA"
	bar1.Size = Vector3.new(0.7, 0.2, 0.1)
	bar1.Color = green
	attach(bar1, "UpperTorso", CFrame.new(0.55, 0.4, -0.55))
	local bar2 = Instance.new("Part")
	bar2.Name = "LencanaB"
	bar2.Size = Vector3.new(0.2, 0.7, 0.1)
	bar2.Color = green
	attach(bar2, "UpperTorso", CFrame.new(0.55, 0.4, -0.55))
end

local function placeStaff(model: Model, home: Vector3, tag: string)
	model.Parent = Workspace
	model:PivotTo(CFrame.lookAt(home, home + Vector3.new(0, 0, 1)))
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local head = model:FindFirstChild("Head") :: BasePart
	local label = makeBillboard(head, 150, 3.0, Color3.fromRGB(30, 110, 100))
	label.Text = tag
	label.Name = "Nama"
end

-- gelembung ucapan singkat di atas kepala NPC
local bubbleToken: { [Model]: number } = {}
local function say(model: Model?, text: string, seconds: number)
	if model == nil or model.Parent == nil then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head == nil then
		return
	end
	local gui = head:FindFirstChild("Gelembung") :: BillboardGui?
	if gui == nil then
		local label = makeBillboard(head, 230, 4.6, Color3.fromRGB(40, 60, 90))
		gui = label.Parent :: BillboardGui
		gui.Name = "Gelembung"
	end
	local label = (gui :: BillboardGui):FindFirstChildOfClass("TextLabel") :: TextLabel
	label.Text = text;
	(gui :: BillboardGui).Enabled = true
	local token = (bubbleToken[model] or 0) + 1
	bubbleToken[model] = token
	task.delay(seconds, function()
		if bubbleToken[model] == token and gui and gui.Parent then
			(gui :: BillboardGui).Enabled = false
		end
	end)
end

local function makeProp(item: string): BasePart
	local library = ServerStorage:FindFirstChild("PropKlinik")
	local template = if library then library:FindFirstChild(PROP_MESH[item]) else nil
	local prop: BasePart
	if template and template:IsA("MeshPart") then
		prop = template:Clone()
	else
		prop = Instance.new("Part")
		prop.Size = Vector3.new(1.2, 1, 1.2)
	end
	prop.Name = "ObatKlinik"
	prop.Color = PROP_COLOR[item]
	prop.Material = Enum.Material.SmoothPlastic
	prop.Anchored = false
	prop.CanCollide = false
	prop.CanQuery = false
	prop.CanTouch = false
	prop.Massless = true
	prop.TextureID = ""
	return prop
end

local function attachToHand(character: Model?, prop: BasePart): boolean
	local hand = if character
		then character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		else nil
	if hand == nil or not hand:IsA("BasePart") then
		return false
	end
	prop.CFrame = hand.CFrame * CFrame.new(0, -0.5, -0.7)
	prop.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = prop
	weld.Parent = prop
	return true
end

-- ---------------------------------------------------------------- tampilan pasien
local function setLabel(patient: Patient)
	local t = typeOf(patient)
	local text: string
	if patient.stage == "antre" then
		text = `{t.icon} Mendaftar...`
	elseif patient.stage == "menunggu" then
		text = `{if patient.called then "🔔 " else ""}{patient.ticket} {t.icon} {t.name}`
	elseif patient.stage == "dipanggil" then
		text = `🔔 {patient.ticket} dipanggil`
	elseif patient.stage == "diMeja" then
		text = `{patient.ticket} 🩺 Di meja dokter`
	elseif patient.stage == "diRanjang" then
		text = `{patient.ticket} 🩺 Sedang diperiksa`
	elseif patient.stage == "tungguObat" then
		text = `{patient.ticket} ⏳ Menunggu obat`
	elseif patient.stage == "obatSiap" then
		text = `{patient.ticket} 💊 Siap diberi obat`
	else
		text = "😊 Sembuh!"
	end
	patient.label.Text = text
end

local function freeSeat(wantBed: boolean): Seat?
	local candidates: { Seat } = {}
	for seat, info in seatInfo do
		if info.patient == nil and info.bed == wantBed and not info.desk then
			table.insert(candidates, seat)
		end
	end
	if #candidates == 0 then
		return nil
	end
	table.sort(candidates, function(a, b)
		return a.Name < b.Name
	end)
	return if wantBed then candidates[1] else pick(candidates)
end

local function updatePrompt(patient: Patient)
	local t = typeOf(patient)
	local prompt = patient.prompt
	local enabled = doctorPresent
	if patient.stage == "antre" or patient.stage == "sembuh" then
		enabled = false
	elseif patient.stage == "menunggu" or patient.stage == "dipanggil" then
		prompt.ActionText = if patient.stage == "menunggu"
			then "Menunggu dipanggil"
			else "Menuju meja dokter"
		prompt.ObjectText = `Pasien {patient.name} ({t.name})`
		prompt.HoldDuration = 0
		enabled = false
	elseif patient.stage == "tungguObat" then
		prompt.ActionText = "Menunggu obat"
		prompt.ObjectText = `Pasien {patient.name} ({t.name})`
		prompt.HoldDuration = 0
		enabled = false
	elseif patient.stage == "obatSiap" then
		prompt.ActionText = t.medAction
		prompt.ObjectText = `Pasien {patient.name} ({t.name})`
		prompt.HoldDuration = t.medHold
	else
		if not (patient.called or patient.onBed or patient.step > 0) then
			prompt.ActionText = "Menunggu dipanggil"
			prompt.ObjectText = `Pasien {patient.name} ({t.name})`
			prompt.HoldDuration = 0
			enabled = false
		elseif t.bed and not patient.onBed then
			prompt.ActionText = "Panggil ke ranjang"
			prompt.ObjectText = `Pasien {patient.name} ({t.name})`
			prompt.HoldDuration = 1
			if freeSeat(true) == nil then
				enabled = false
			end
		else
			local index = math.min(patient.step + 1, #t.steps)
			prompt.ActionText = t.steps[index]
			prompt.ObjectText = `Pasien {patient.name} ({t.name})`
			prompt.HoldDuration = t.holds[index]
		end
	end
	prompt.Enabled = enabled
end

local function removeMedicine(patient: Patient)
	for index = #deskItems, 1, -1 do
		if deskItems[index].patient == patient then
			deskItems[index].prop:Destroy()
			table.remove(deskItems, index)
		end
	end
	local orderIndex = table.find(orders, patient)
	if orderIndex then
		table.remove(orders, orderIndex)
	end
	local carrier = patient.carrier
	if carrier then
		if hasMedicine[carrier] == patient then
			hasMedicine[carrier] = nil
			carrier:SetAttribute("BawaObat", nil)
		end
		local prop = handProp[carrier]
		if prop then
			prop:Destroy()
			handProp[carrier] = nil
		end
		patient.carrier = nil
	end
end

-- bangunkan pasien yang berbaring di ranjang (lepas jangkar, berdiri di samping ranjang)
local function standUp(patient: Patient)
	if not patient.lying then
		return
	end
	patient.lying = false
	local char = if patient.kind == "npc"
		then patient.model
		else (if patient.player then patient.player.Character else nil)
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if char and root and humanoid then
		char:PivotTo(CFrame.new(patient.seat.Position.X + 3.8, 2003.6, 170.8))
		root.Anchored = false
		humanoid.PlatformStand = false
	end
	local wake = patient.seat:FindFirstChild("BangunPrompt")
	if wake then
		wake:Destroy()
	end
end

local function removePatient(patient: Patient)
	standUp(patient)
	removeMedicine(patient)
	local index = table.find(patients, patient)
	if index then
		table.remove(patients, index)
	end
	local info = seatInfo[patient.seat]
	if info and info.patient == patient then
		info.patient = nil
	end
	patient.prompt:Destroy()
	if patient.player then
		patient.player:SetAttribute("PasienKlinik", nil)
	end
	local gui = patient.label.Parent
	if gui then
		gui:Destroy()
	end
end

local function sitNpc(patient: Patient, via: Vector3?)
	local model = patient.model
	if model == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local seatPosition = patient.seat.Position
	if via then
		walkTo(model, via, 10)
	end
	walkTo(model, Vector3.new(seatPosition.X + 1.5, seatPosition.Y + 1, seatPosition.Z), 10)
	if model.Parent == nil or patient.seat.Parent == nil then
		return
	end
	pcall(function()
		patient.seat:Sit(humanoid)
	end)
end

local function npcLeave(patient: Patient)
	local model = patient.model
	removePatient(patient)
	if model == nil then
		return
	end
	task.spawn(function()
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			model:Destroy()
			return
		end
		humanoid.Sit = false
		humanoid.Jump = true
		task.wait(0.5)
		walkTo(model, Vector3.new(40, DOOR_INSIDE.Y, DOOR_INSIDE.Z - 8), 10)
		walkTo(model, DOOR_OUT, 8)
		model:Destroy()
	end)
end

local function nextTicket(): string
	ticketCounter = ticketCounter % 99 + 1
	return string.format("A%02d", ticketCounter)
end

local function newPatient(
	seat: Seat,
	kind: "npc" | "player",
	name: string,
	typeKey: string,
	adornee: BasePart,
	model: Model?,
	player: Player?,
	stage: string
): Patient
	local t = TYPES[typeKey]
	local label = makeBillboard(adornee, 190, 3.2, Color3.fromRGB(30, 110, 100))
	label.Name = "StatusPasien"
	local patient: Patient = {
		kind = kind,
		name = name,
		typeKey = typeKey,
		ticket = "",
		stage = stage,
		step = 0,
		onBed = false,
		seat = seat,
		prompt = makePrompt(seat, "Periksa pasien", `Pasien {name} ({t.name})`, 2),
		label = label,
		model = model,
		player = player,
		bornAt = os.clock(),
		registeredAt = os.clock(),
		unseatedAt = nil,
		carrier = nil,
		called = false,
		lying = false,
		calledAt = nil,
	}
	seatInfo[seat].patient = patient
	table.insert(patients, patient)
	setLabel(patient)
	updatePrompt(patient)
	patient.prompt.Triggered:Connect(function(doctor: Player)
		ClinicService._onPatientPrompt(doctor, patient)
	end)
	return patient
end

local function register(patient: Patient)
	patient.ticket = nextTicket()
	patient.stage = "menunggu"
	patient.registeredAt = os.clock()
	setLabel(patient)
	updatePrompt(patient)
	say(
		regNpc,
		`Antrean {patient.ticket}: {patient.name} ({typeOf(patient).name}). Silakan duduk ya!`,
		5
	)
end

local function spawnNpc()
	local seat = freeSeat(false)
	if seat == nil then
		return
	end
	local name = pick(NAMES)
	local model = buildNpc("Pasien_" .. name)
	if model == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.Parent = Workspace
	model:PivotTo(CFrame.new(DOOR_INSIDE + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.pi, 0))
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local forced = folder:GetAttribute("PaksaJenis")
	local typeKey = if type(forced) == "string" and TYPES[forced] ~= nil
		then forced
		else pick(TYPE_KEYS)
	local patient = newPatient(
		seat,
		"npc",
		name,
		typeKey,
		model:FindFirstChild("Head") :: BasePart,
		model,
		nil,
		"antre"
	)
	lastSpawn = os.clock()
	task.spawn(function()
		walkTo(model, REG_FRONT, 14)
		task.wait(0.8)
		if table.find(patients, patient) == nil then
			return
		end
		register(patient)
		sitNpc(patient, Vector3.new(32, seat.Position.Y + 1, 168))
	end)
end

-- ---------------------------------------------------------------- pemain sebagai pasien
local function registerPlayer(player: Player)
	if not allow(player) then
		return
	end
	local root = rootOf(player)
	local humanoid = if player.Character
		then player.Character:FindFirstChildOfClass("Humanoid")
		else nil
	if root == nil or humanoid == nil or humanoid.Health <= 0 or not inside(root.Position) then
		return
	end
	if isDoctor(player) then
		EconomyService.notify(
			player,
			"Kamu dokter di sini, jadi tidak perlu mendaftar sebagai pasien."
		)
		return
	end
	for _, patient in patients do
		if patient.player == player then
			EconomyService.notify(
				player,
				`Kamu sudah terdaftar dengan antrean {patient.ticket}. Tunggu dokter ya!`
			)
			return
		end
	end
	local seat = freeSeat(false)
	local head = if player.Character
		then player.Character:FindFirstChild("Head") :: BasePart?
		else nil
	if seat == nil or head == nil then
		EconomyService.notify(player, "Ruang tunggu penuh. Coba lagi sebentar lagi ya!")
		return
	end
	local patient = newPatient(
		seat,
		"player",
		player.DisplayName,
		pick(TYPE_KEYS),
		head,
		nil,
		player,
		"menunggu"
	)
	register(patient)
	player:SetAttribute("PasienKlinik", true)
	pcall(function()
		seat:Sit(humanoid)
	end)
	EconomyService.notify(
		player,
		`Antrean {patient.ticket}: {typeOf(patient).name}. Duduk dan tunggu dokter ya!`
	)
end

-- berbaring di ranjang: badan dibuat telentang di atas kasur dan dijangkarkan (PlatformStand)
local function lieDown(patient: Patient, bed: Seat)
	local char = if patient.kind == "npc"
		then patient.model
		else (if patient.player then patient.player.Character else nil)
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if char == nil or root == nil or humanoid == nil or bed.Parent == nil then
		return
	end
	humanoid.Sit = false
	humanoid.PlatformStand = true
	root.Anchored = true -- jangkarkan dulu, baru pindahkan (supaya posisi baru ikut terkirim ke client)
	char:PivotTo(
		CFrame.new(bed.Position.X, BED_LIE_HEIGHT, 166.6)
			* CFrame.Angles(0, math.pi, 0)
			* CFrame.Angles(math.pi / 2, 0, 0)
	)
	patient.lying = true
	if patient.kind == "player" and patient.player then
		local wake = Instance.new("ProximityPrompt")
		wake.Name = "BangunPrompt"
		wake.ActionText = "Bangun dari ranjang"
		wake.ObjectText = "Ranjang tindakan"
		wake.HoldDuration = 0.5
		wake.KeyboardKeyCode = Enum.KeyCode.G
		wake.MaxActivationDistance = 6
		wake.RequiresLineOfSight = false
		wake.Parent = bed
		wake.Triggered:Connect(function(who: Player)
			if who == patient.player and table.find(patients, patient) ~= nil then
				removePatient(patient)
				EconomyService.notify(who, "Kamu bangun dari ranjang. Pendaftaranmu dibatalkan.")
			end
		end)
		EconomyService.notify(
			patient.player,
			"Kamu berbaring di ranjang tindakan. Tekan Bangun kalau ingin turun."
		)
	end
end

local function moveToBed(patient: Patient, bed: Seat)
	local old = seatInfo[patient.seat]
	if old and old.patient == patient then
		old.patient = nil
	end
	seatInfo[bed].patient = patient
	patient.seat = bed
	patient.prompt.Parent = bed
	patient.onBed = true
	patient.stage = "diRanjang"
	patient.unseatedAt = nil
	setLabel(patient)
	updatePrompt(patient)
	if patient.kind == "npc" then
		local model = patient.model
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Sit = false
			end
			task.spawn(function()
				walkTo(model, Vector3.new(bed.Position.X, bed.Position.Y + 1, 170.8), 12)
				if model.Parent and bed.Parent and patient.seat == bed then
					lieDown(patient, bed)
				end
			end)
		end
	else
		lieDown(patient, bed)
	end
end

-- ---------------------------------------------------------------- dokter
local function cure(doctor: Player, patient: Patient)
	local elapsed = os.clock() - patient.registeredAt
	local stars = if elapsed <= STAR3_SECONDS then 3 elseif elapsed <= STAR2_SECONDS then 2 else 1
	patient.stage = "sembuh"
	patient.label.Text = `{starsText(stars)} Sembuh!`
	updatePrompt(patient)
	removeMedicine(patient)
	local pay = 0
	local base = (if patient.kind == "npc" then PAY_NPC else PAY_PLAYER)
		+ (if doctor == dutyDoctor then DUTY_BONUS else 0)
	if patient.kind == "player" then
		local key = `{doctor.UserId}:{patient.player and patient.player.UserId or 0}`
		if os.clock() - (lastPaid[key] or -PAIR_COOLDOWN) >= PAIR_COOLDOWN then
			lastPaid[key] = os.clock()
			pay = JobService.payExternal(doctor, "dokter", base + BONUS[stars], "klinik")
		end
	else
		pay = JobService.payExternal(doctor, "dokter", base + BONUS[stars], "klinik")
	end
	local ratingText = `{starsText(stars)} ({math.floor(elapsed)} dtk)`
	if pay > 0 then
		EconomyService.notify(
			doctor,
			`Pasien {patient.name} sembuh! {ratingText} Kamu dapat ${pay}.`
		)
	else
		EconomyService.notify(
			doctor,
			`Pasien {patient.name} sembuh! {ratingText} Terima kasih, Dok.`
		)
	end
	doctor:SetAttribute("KlinikSembuh", (doctor:GetAttribute("KlinikSembuh") or 0) + 1)
	curedEvent:Fire(doctor, patient.kind, stars, patient.typeKey)
	local target = patient.player
	if target then
		EconomyService.notify(
			target,
			`Kamu sudah sembuh! {starsText(stars)} Terima kasih, dokter {doctor.DisplayName}.`
		)
		local humanoid = if target.Character
			then target.Character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid then
			humanoid.Sit = false
		end
	end
	task.delay(3, function()
		if patient.kind == "npc" then
			npcLeave(patient)
		else
			removePatient(patient)
		end
	end)
end

-- langkah periksa selesai: naikkan langkah, atau lanjut ke tahap obat bila langkah terakhir
local function advanceStep(doctor: Player, patient: Patient)
	local t = typeOf(patient)
	patient.step += 1
	local tip = t.tips[math.min(patient.step, #t.tips)]
	if patient.step >= #t.steps then
		patient.stage = "tungguObat"
		table.insert(orders, patient)
	end
	EconomyService.notify(doctor, tip)
	setLabel(patient)
	updatePrompt(patient)
end

local function startMinigame(doctor: Player, patient: Patient)
	local t = typeOf(patient)
	local index = patient.step + 1
	local spec = MINIGAMES[t.steps[index]]
	local current = pending[doctor]
	if current and os.clock() - current.startedAt < current.seconds + 3 then
		return
	end
	if spec == nil then
		advanceStep(doctor, patient)
		return
	end
	local token = HttpService:GenerateGUID(false)
	pending[doctor] = {
		patient = patient,
		step = index,
		token = token,
		startedAt = os.clock(),
		taps = spec.taps,
		seconds = spec.seconds,
	}
	startRemote:FireClient(doctor, token, spec.icon, spec.title, spec.taps, spec.seconds)
end

local function onMinigameDone(player: Player, token: any, taps: any)
	local entry = pending[player]
	if entry == nil or type(token) ~= "string" or token ~= entry.token then
		return
	end
	pending[player] = nil
	local patient = entry.patient
	local elapsed = os.clock() - entry.startedAt
	if type(taps) ~= "number" or taps < entry.taps then
		EconomyService.notify(player, "Belum berhasil. Tahan tombol periksa lagi dan coba lagi ya!")
		return
	end
	if elapsed < entry.taps * 0.2 or elapsed > entry.seconds + 4 then
		return
	end
	local root = rootOf(player)
	if
		root == nil
		or not inside(root.Position)
		or (root.Position - patient.seat.Position).Magnitude > MAX_DISTANCE + 8
	then
		return
	end
	if table.find(patients, patient) == nil or patient.step + 1 ~= entry.step then
		return
	end
	if patient.stage ~= "diMeja" and patient.stage ~= "diRanjang" then
		return
	end
	advanceStep(player, patient)
end

function ClinicService._onPatientPrompt(doctor: Player, patient: Patient)
	if not allow(doctor) then
		return
	end
	local root = rootOf(doctor)
	if root == nil or not inside(root.Position) then
		return
	end
	if not isDoctor(doctor) then
		EconomyService.notify(
			doctor,
			"Hanya Dokter yang bisa memeriksa pasien. Ambil pekerjaan Dokter di menu Pekerjaan ya!"
		)
		return
	end
	if patient.player == doctor or table.find(patients, patient) == nil then
		return
	end
	if (root.Position - patient.seat.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local t = typeOf(patient)
	if patient.stage == "diMeja" or patient.stage == "diRanjang" then
		if t.bed and not patient.onBed then
			local bed = freeSeat(true)
			if bed == nil then
				EconomyService.notify(doctor, "Ranjang tindakan penuh. Tunggu sebentar ya!")
				return
			end
			moveToBed(patient, bed)
			EconomyService.notify(
				doctor,
				`Pasien {patient.name} dibawa ke ranjang tindakan. Ukur suhunya!`
			)
			return
		end
		if not (patient.called or patient.onBed or patient.step > 0) then
			EconomyService.notify(doctor, "Pasien ini belum dipanggil. Lihat papan antrean ya!")
			return
		end
		startMinigame(doctor, patient)
	elseif patient.stage == "obatSiap" then
		if patient.carrier ~= doctor then
			EconomyService.notify(
				doctor,
				"Obat pasien ini ada di dokter lain. Ambil obatmu di Meja Dokter ya!"
			)
			return
		end
		cure(doctor, patient)
	end
end

local function onDeskPrompt(doctor: Player)
	if not allow(doctor) then
		return
	end
	local root = rootOf(doctor)
	if
		root == nil
		or not inside(root.Position)
		or (root.Position - DESK_POINT).Magnitude > MAX_DISTANCE
	then
		return
	end
	if not isDoctor(doctor) then
		EconomyService.notify(doctor, "Meja ini khusus Dokter yang sedang bertugas.")
		return
	end
	if hasMedicine[doctor] ~= nil then
		EconomyService.notify(doctor, "Kamu masih membawa obat. Berikan dulu ke pasiennya!")
		return
	end
	local entry = table.remove(deskItems, 1)
	if entry == nil then
		return
	end
	entry.prop:Destroy()
	local patient = entry.patient
	if table.find(patients, patient) == nil or patient.stage ~= "tungguObat" then
		return
	end
	patient.stage = "obatSiap"
	patient.carrier = doctor
	hasMedicine[doctor] = patient
	doctor:SetAttribute("BawaObat", typeOf(patient).medItem)
	local prop = makeProp(typeOf(patient).medItem)
	if attachToHand(doctor.Character, prop) then
		handProp[doctor] = prop
	else
		prop:Destroy()
	end
	setLabel(patient)
	updatePrompt(patient)
	EconomyService.notify(
		doctor,
		`Obat diambil. Berikan ke pasien {patient.name} ({patient.ticket})!`
	)
end

-- ---------------------------------------------------------------- apoteker
local function runPharmacist()
	while true do
		task.wait(1)
		local model = pharmacist
		if model == nil or model.Parent == nil or #orders == 0 or not doctorPresent then
			continue
		end
		local patient = table.remove(orders, 1) :: Patient
		if table.find(patients, patient) == nil or patient.stage ~= "tungguObat" then
			continue
		end
		local item = typeOf(patient).medItem
		local prop = makeProp(item)
		local carrying = attachToHand(model, prop)
		say(model, `Obat untuk {patient.name}, segera!`, 4)
		walkTo(model, DESK_DELIVER, 14)
		if carrying then
			prop:Destroy()
		end
		if table.find(patients, patient) ~= nil and patient.stage == "tungguObat" then
			local onDesk = makeProp(item)
			onDesk.Anchored = true
			onDesk.CFrame =
				CFrame.new(DESK_POINT + Vector3.new(0, -0.3 + rng:NextNumber(0, 0.05), 0))
			onDesk.Parent = folder
			table.insert(deskItems, { patient = patient, prop = onDesk })
			say(model, "Obat sudah di Meja Dokter ya!", 5)
		end
		walkTo(model, PHARMACIST_HOME, 14)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			model:PivotTo(CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)))
		end
	end
end

-- ---------------------------------------------------------------- papan antrean
local function updateBoard()
	if boardBody == nil then
		return
	end
	local list: { Patient } = {}
	for _, patient in patients do
		if patient.ticket ~= "" and patient.stage ~= "sembuh" then
			table.insert(list, patient)
		end
	end
	table.sort(list, function(a, b)
		return a.ticket < b.ticket
	end)
	local lines = {}
	for index = 1, math.min(3, #list) do
		local patient = list[index]
		local where = if patient.onBed
			then " → Ranjang"
			elseif patient.stage == "dipanggil" or patient.stage == "diMeja" then " → Meja"
			elseif patient.stage == "tungguObat" then " ⏳"
			elseif patient.stage == "obatSiap" then " 💊"
			else ""
		local bell = if patient.stage == "dipanggil" then "🔔 " else ""
		table.insert(
			lines,
			`{bell}{patient.ticket}  {patient.name} · {typeOf(patient).name}{where}`
		)
	end
	local text = if #lines == 0 then "Tidak ada antrean" else table.concat(lines, "\n")
	if text ~= lastBoardText then
		lastBoardText = text
		boardBody.Text = text
	end
end

-- ---------------------------------------------------------------- bel antrean dan dokter jaga
local function ringBell()
	local sound = bellSound
	if sound == nil then
		return
	end
	sound.PlaybackSpeed = 1.3
	sound:Play()
	task.delay(0.5, function()
		sound.PlaybackSpeed = 0.95
		sound:Play()
	end)
end

local function _updateCalls(doctorCount: number)
	if doctorCount == 0 then
		return
	end
	local slots = math.min(2, doctorCount)
	local calledWaiting = 0
	local waiting: { Patient } = {}
	for _, patient in patients do
		if
			patient.stage == "menunggu"
			and patient.ticket ~= ""
			and patient.step == 0
			and not patient.onBed
		then
			if patient.called then
				calledWaiting += 1
			else
				table.insert(waiting, patient)
			end
		end
	end
	table.sort(waiting, function(a, b)
		return a.ticket < b.ticket
	end)
	while calledWaiting < slots and #waiting > 0 do
		local patient = table.remove(waiting, 1) :: Patient
		patient.called = true
		calledWaiting += 1
		setLabel(patient)
		ringBell()
		say(regNpc, `Antrean {patient.ticket}, {patient.name}, silakan ke dokter!`, 6)
		if patient.player then
			EconomyService.notify(
				patient.player,
				`Antreanmu {patient.ticket} dipanggil! Dokter siap memeriksa.`
			)
		end
	end
end

local function updateDuty(doctors: { Player }, now: number)
	for _, doctor in doctors do
		if doctorSince[doctor] == nil then
			doctorSince[doctor] = now
		end
	end
	local present: { [Player]: boolean } = {}
	for _, doctor in doctors do
		present[doctor] = true
	end
	for doctor in doctorSince do
		if not present[doctor] then
			doctorSince[doctor] = nil
		end
	end
	if dutyDoctor == nil or not present[dutyDoctor] then
		dutyDoctor = nil
		local best: Player? = nil
		for _, doctor in doctors do
			if best == nil or doctorSince[doctor] < doctorSince[best] then
				best = doctor
			end
		end
		dutyDoctor = best
		if dutyTag then
			dutyTag:Destroy()
			dutyTag = nil
		end
		local character = if best then best.Character else nil
		local head = if character then character:FindFirstChild("Head") :: BasePart? else nil
		if best and head then
			local label = makeBillboard(head, 190, 4.4, Color3.fromRGB(200, 60, 80))
			label.Text = "🩺 Dokter Jaga"
			dutyTag = label.Parent :: BillboardGui
		end
	end
	if dutyLabel then
		dutyLabel.Text = if dutyDoctor
			then `🩺 Dokter jaga: {dutyDoctor.DisplayName}`
			else "🩺 Belum ada dokter jaga"
	end
	for doctor, entry in table.clone(pending) do
		if now - entry.startedAt > entry.seconds + 5 then
			pending[doctor] = nil
		end
	end
end

-- dokter memanggil nomor urut berikutnya dari mejanya; pasien datang sendiri ke kursi periksa
local function nextWaiting(): Patient?
	local best: Patient? = nil
	for _, patient in patients do
		if patient.stage == "menunggu" and patient.ticket ~= "" then
			if best == nil or patient.ticket < best.ticket then
				best = patient
			end
		end
	end
	return best
end

local function updateCallPrompt()
	if callPrompt == nil or deskSeat == nil then
		return
	end
	local busy = seatInfo[deskSeat].patient ~= nil
	local nextPatient = nextWaiting()
	callPrompt.Enabled = doctorPresent and not busy and nextPatient ~= nil
	if nextPatient then
		callPrompt.ObjectText = `Berikutnya: {nextPatient.ticket} {nextPatient.name}`
	end
end

local function onCallPrompt(doctor: Player)
	if not allow(doctor) then
		return
	end
	local root = rootOf(doctor)
	if
		root == nil
		or not inside(root.Position)
		or (root.Position - DESK_POINT).Magnitude > MAX_DISTANCE
	then
		return
	end
	if not isDoctor(doctor) then
		EconomyService.notify(doctor, "Meja ini khusus Dokter yang sedang bertugas.")
		return
	end
	local desk = deskSeat
	if desk == nil or seatInfo[desk].patient ~= nil then
		EconomyService.notify(doctor, "Masih ada pasien di meja dokter. Selesaikan dulu ya!")
		return
	end
	local patient = nextWaiting()
	if patient == nil then
		EconomyService.notify(doctor, "Tidak ada antrean sekarang.")
		return
	end
	local old = seatInfo[patient.seat]
	if old and old.patient == patient then
		old.patient = nil
	end
	seatInfo[desk].patient = patient
	patient.seat = desk
	patient.prompt.Parent = desk
	patient.called = true
	patient.stage = "dipanggil"
	patient.unseatedAt = nil
	patient.calledAt = os.clock()
	setLabel(patient)
	updatePrompt(patient)
	ringBell()
	say(regNpc, `Antrean {patient.ticket}, {patient.name}, silakan ke meja dokter!`, 6)
	if patient.kind == "npc" then
		task.spawn(function()
			local model = patient.model
			local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
			if model == nil or humanoid == nil then
				return
			end
			humanoid.Sit = false
			humanoid.Jump = true
			task.wait(0.4)
			walkTo(model, DESK_APPROACH, 12)
			if model.Parent and desk.Parent and patient.seat == desk then
				pcall(function()
					desk:Sit(humanoid)
				end)
				task.wait(0.6)
				if
					patient.seat == desk
					and table.find(patients, patient) ~= nil
					and patient.stage == "dipanggil"
				then
					patient.stage = "diMeja"
					setLabel(patient)
					updatePrompt(patient)
				end
			end
		end)
	elseif patient.player then
		EconomyService.notify(
			patient.player,
			`Antreanmu {patient.ticket} dipanggil! Duduk di kursi periksa dekat meja dokter ya.`
		)
	end
end

-- ---------------------------------------------------------------- siklus
local function tick()
	local now = os.clock()
	local doctors = insideDoctors()
	doctorPresent = #doctors > 0
	if doctorPresent then
		lastDoctorSeen = now
	end
	for _, patient in table.clone(patients) do
		if patient.kind == "npc" then
			local gone = patient.model == nil or patient.model.Parent == nil
			if gone then
				removePatient(patient)
			elseif patient.stage == "dipanggil" and now - (patient.calledAt or now) > 25 then
				-- NPC tersangkut di jalan menuju meja: pindahkan langsung ke kursi periksa
				local model = patient.model
				local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
				if model and humanoid then
					model:PivotTo(CFrame.new(DESK_APPROACH))
					pcall(function()
						patient.seat:Sit(humanoid)
					end)
					patient.stage = "diMeja"
					setLabel(patient)
					updatePrompt(patient)
				end
			elseif
				patient.stage ~= "sembuh"
				and (now - patient.bornAt > NPC_LIFETIME or now - lastDoctorSeen > IDLE_LEAVE)
			then
				npcLeave(patient)
			end
		else
			local target = patient.player
			local humanoid = if target and target.Character
				then target.Character:FindFirstChildOfClass("Humanoid")
				else nil
			local root = if target then rootOf(target) else nil
			local dropped = target == nil
				or target.Parent == nil
				or humanoid == nil
				or humanoid.Health <= 0
				or root == nil
				or not inside(root.Position)
			if not dropped and humanoid ~= nil and patient.stage == "dipanggil" then
				if humanoid.SeatPart == patient.seat then
					patient.stage = "diMeja"
					patient.unseatedAt = nil
					setLabel(patient)
					updatePrompt(patient)
				elseif now - (patient.calledAt or now) > 40 then
					pcall(function()
						patient.seat:Sit(humanoid)
					end)
					if now - (patient.calledAt or now) > 70 then
						dropped = true
					end
				end
			elseif not dropped and humanoid ~= nil and patient.lying then
				if noDoctorAt ~= nil and now - noDoctorAt > 20 then
					dropped = true
					if target then
						EconomyService.notify(
							target,
							"Dokter sedang tidak ada, kamu dibangunkan dari ranjang."
						)
					end
				end
			elseif not dropped and humanoid ~= nil and patient.stage ~= "sembuh" then
				if humanoid.SeatPart ~= patient.seat then
					patient.unseatedAt = patient.unseatedAt or now
					if now - (patient.unseatedAt :: number) > UNSEAT_GRACE then
						dropped = true
						if target then
							EconomyService.notify(
								target,
								"Pendaftaranmu dibatalkan karena kamu meninggalkan tempat duduk."
							)
						end
					end
				else
					patient.unseatedAt = nil
				end
				if now - patient.bornAt > PLAYER_PATIENT_TIMEOUT then
					dropped = true
				end
			end
			if dropped then
				removePatient(patient)
			end
		end
	end
	local presentDoctors: { [Player]: boolean } = {}
	for _, doctor in doctors do
		presentDoctors[doctor] = true
		if not inClinic[doctor] then
			inClinic[doctor] = true
			doctor:SetAttribute("SedangKlinik", true)
			JobService.setClinicMode(doctor, true)
		end
	end
	for member in table.clone(inClinic) do
		if not presentDoctors[member] then
			inClinic[member] = nil
			if member.Parent ~= nil then
				member:SetAttribute("SedangKlinik", nil)
				member:SetAttribute("KlinikDuduk", nil)
				JobService.setClinicMode(member, false)
			end
		end
	end
	if doctorPresent then
		noDoctorAt = nil
	elseif noDoctorAt == nil then
		noDoctorAt = now
	end
	for _, doctor in doctors do
		local humanoid = if doctor.Character
			then doctor.Character:FindFirstChildOfClass("Humanoid")
			else nil
		local seated = humanoid ~= nil
			and doctorSeatRef ~= nil
			and humanoid.SeatPart == doctorSeatRef
		if (doctor:GetAttribute("KlinikDuduk") == true) ~= seated then
			doctor:SetAttribute("KlinikDuduk", if seated then true else nil)
		end
	end
	if sitPromptRef and doctorSeatRef then
		local occupied = doctorSeatRef.Occupant ~= nil
		if sitPromptRef.Enabled == occupied then
			sitPromptRef.Enabled = not occupied -- tombol "Duduk" disembunyikan saat kursi sudah dipakai
		end
	end
	updateDuty(doctors, now)
	updateCallPrompt()
	for _, patient in patients do
		updatePrompt(patient)
	end
	if deskPrompt then
		local first = deskItems[1]
		deskPrompt.Enabled = doctorPresent and first ~= nil
		if first then
			deskPrompt.ObjectText = `Obat untuk {first.patient.name}`
		end
	end
	updateBoard()
	-- petugas kembali ke tempatnya bila terdorong
	if regNpc and regNpc.Parent then
		local root = regNpc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - REG_NPC_HOME).Magnitude > 3 then
			regNpc:PivotTo(CFrame.lookAt(REG_NPC_HOME, REG_NPC_HOME + Vector3.new(0, 0, 1)))
		end
	end
	if doctorPresent then
		local npcCount = 0
		for _, patient in patients do
			if patient.kind == "npc" and patient.stage ~= "sembuh" then
				npcCount += 1
			end
		end
		if npcCount < math.min(MAX_NPC, 1 + #doctors) and now - lastSpawn >= SPAWN_GAP then
			spawnNpc()
		end
	end
end

function ClinicService.init()
	startRemote = Net.event(Net.Names.KlinikMulai)
	doneRemote = Net.event(Net.Names.KlinikSelesai)
	doneRemote.OnServerEvent:Connect(onMinigameDone)
end

function ClinicService.start()
	local map = Workspace:FindFirstChild("Map")
	local interiors = map and map:FindFirstChild("Interiors")
	local hospital = interiors and interiors:FindFirstChild("RumahSakit")
	if hospital == nil then
		warn("[Clinic] Workspace.Map.Interiors.RumahSakit tidak ditemukan")
		return
	end
	local old = hospital:FindFirstChild("Klinik")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Klinik"
	folder.Parent = hospital

	local west = Vector3.new(-1, 0, 0)
	for _, x in CHAIR_X do
		for index, z in CHAIR_Z do
			makeSeat(
				`Kursi_{string.format("%02d", index)}_{x}`,
				Vector3.new(x, 2001.55, z),
				west,
				false
			)
		end
	end
	for index, position in BEDS do
		makeSeat(`Ranjang_{index}`, position, Vector3.new(0, 0, 1), true)
	end
	deskSeat = makeSeat("KursiPeriksa", DESK_CHAIR, Vector3.new(0, 0, 1), false)
	seatInfo[deskSeat].desk = true
	local doctorSeat = makeSeat("KursiDokter", DOCTOR_SEAT, Vector3.new(0, 0, -1), false, false)
	local sitPrompt = makePrompt(doctorSeat, "Duduk di meja dokter", "Kursi Dokter", 0)
	sitPromptRef = sitPrompt
	doctorSeatRef = doctorSeat
	sitPrompt.Triggered:Connect(function(player: Player)
		local humanoid = if player.Character
			then player.Character:FindFirstChildOfClass("Humanoid")
			else nil
		local root = rootOf(player)
		if humanoid == nil or root == nil or not inside(root.Position) then
			return
		end
		if not isDoctor(player) then
			EconomyService.notify(player, "Kursi ini khusus Dokter yang sedang bertugas.")
			return
		end
		pcall(function()
			doctorSeat:Sit(humanoid)
		end)
	end)

	local registerPart = Instance.new("Part")
	registerPart.Name = "TitikPendaftaran"
	registerPart.Size = Vector3.new(2, 2, 2)
	makeInvisible(registerPart)
	registerPart.Position = REGISTER_POINT
	registerPart.Parent = folder
	makePrompt(registerPart, "Daftar berobat", "Petugas Registrasi", 1).Triggered:Connect(
		registerPlayer
	)

	local callPart = Instance.new("Part")
	callPart.Name = "TitikPanggil"
	callPart.Size = Vector3.new(2, 2, 2)
	makeInvisible(callPart)
	callPart.Position = CALL_POINT
	callPart.Parent = folder
	callPrompt = makePrompt(callPart, "Panggil pasien", "Antrean", 0.5)
	callPrompt.KeyboardKeyCode = Enum.KeyCode.R
	callPrompt.Enabled = false
	callPrompt.Triggered:Connect(onCallPrompt)

	local desk = Instance.new("Part")
	desk.Name = "TitikMejaDokter"
	desk.Size = Vector3.new(2, 2, 2)
	makeInvisible(desk)
	desk.Position = DESK_POINT
	desk.Parent = folder
	deskPrompt = makePrompt(desk, "Ambil obat", "Meja Dokter", 1)
	deskPrompt.Enabled = false
	deskPrompt.Triggered:Connect(onDeskPrompt)

	-- papan antrean di dinding utara
	local board = Instance.new("Part")
	board.Name = "PapanAntrean"
	board.Size = Vector3.new(10, 4.6, 0.2)
	board.Color = Color3.fromRGB(20, 70, 80)
	board.Material = Enum.Material.SmoothPlastic
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.Position = BOARD_POSITION
	board.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Text = "ANTREAN PASIEN"
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromScale(0.04, 0.27)
	body.Size = UDim2.fromScale(0.92, 0.5)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextScaled = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(255, 255, 255)
	body.Text = "Tidak ada antrean"
	body.Parent = gui
	boardBody = body
	dutyLabel = Instance.new("TextLabel")
	dutyLabel.Position = UDim2.fromScale(0.04, 0.78)
	dutyLabel.Size = UDim2.fromScale(0.92, 0.18)
	dutyLabel.BackgroundTransparency = 1
	dutyLabel.Font = Enum.Font.GothamBold
	dutyLabel.TextScaled = true
	dutyLabel.TextXAlignment = Enum.TextXAlignment.Left
	dutyLabel.TextColor3 = Color3.fromRGB(120, 235, 215)
	dutyLabel.Text = "🩺 Belum ada dokter jaga"
	dutyLabel.Parent = gui
	local bellPart = Instance.new("Part")
	bellPart.Name = "TitikBel"
	bellPart.Size = Vector3.new(1, 1, 1)
	makeInvisible(bellPart)
	bellPart.Position = Vector3.new(40, 2009, 158.6)
	bellPart.Parent = folder
	bellSound = Instance.new("Sound")
	bellSound.Name = "BelAntrean"
	bellSound.SoundId = BELL_SOUND
	bellSound.Volume = 0.9
	bellSound.RollOffMaxDistance = 90
	bellSound.Parent = bellPart

	-- petugas tetap
	regNpc = buildNpc(
		"PetugasRegistrasi",
		Color3.fromRGB(40, 180, 160),
		Color3.fromRGB(50, 60, 90),
		Color3.fromRGB(50, 35, 25)
	)
	if regNpc then
		placeStaff(regNpc, REG_NPC_HOME, "Petugas Registrasi")
	end
	pharmacist = buildNpc(
		"Apoteker",
		Color3.fromRGB(245, 247, 250),
		Color3.fromRGB(60, 80, 110),
		Color3.fromRGB(35, 30, 28),
		Color3.fromRGB(245, 247, 250)
	)
	if pharmacist then
		addCoat(pharmacist)
		placeStaff(pharmacist, PHARMACIST_HOME, "Apoteker")
		pharmacist:PivotTo(CFrame.lookAt(PHARMACIST_HOME, PHARMACIST_HOME + Vector3.new(0, 0, -1)))
	end

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		pending[player] = nil
		doctorSince[player] = nil
		inClinic[player] = nil
		for _, patient in table.clone(patients) do
			if patient.player == player or patient.carrier == player then
				if patient.player == player then
					removePatient(patient)
				else
					patient.carrier = nil
					patient.stage = "tungguObat"
					table.insert(orders, patient)
				end
			end
		end
		hasMedicine[player] = nil
		handProp[player] = nil
	end)

	task.spawn(runPharmacist)
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Clinic] " .. tostring(err))
			end
		end
	end)
end

return ClinicService
