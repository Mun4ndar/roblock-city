--!strict
-- OnboardingController: tampilan panduan pemain baru (semua angka dihitung OnboardingService).
--   * kartu "Misi Pemula" di kanan atas + GPS otomatis (NavController) ke tujuan tiap langkah
--   * penunjuk ke tombol Pekerjaan saat langkah 1 (tombolnya sendiri tidak diubah)
--   * penghitung waktu bonus main
--   * pengingat "Hari ke-N menunggumu!" di akhir misi dan saat menu Roblox dibuka (mau keluar)
--   * aplikasi HP "Teleport" ke tempat-tempat seru

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local OnboardingConfig = require(Shared:WaitForChild("OnboardingConfig"))
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local JobController = require(script.Parent:WaitForChild("JobController"))
local NavController = require(script.Parent:WaitForChild("NavController"))
local PhoneController = require(script.Parent:WaitForChild("PhoneController"))
local RetentionController = require(script.Parent:WaitForChild("RetentionController"))
local Util = script.Parent.Parent:WaitForChild("Util")
local UiKit = require(Util:WaitForChild("UiKit"))
local UiScale = require(Util:WaitForChild("UiScale"))

local player = Players.LocalPlayer

local OnboardingController = {}

local STEP_COUNT = #OnboardingConfig.STEPS
local COLORS = UiKit.COLORS
local GOLD = Color3.fromRGB(255, 184, 0)
local TOP_OFFSET = 76 -- di bawah panel uang dan tombol hadiah harian (ukuran penuh)

local gui: ScreenGui
local stack: Frame
local card: TextButton
local cardTitle: TextLabel
local cardStep: TextLabel
local cardHint: TextLabel
local timerChip: TextLabel
local pointer: TextLabel
local banner: TextLabel
local donePanel: Frame
local doneBody: ScrollingFrame
local teleportPanel: Frame
local teleportBody: ScrollingFrame

local knownStep: number? = nil
local bonusEndsAt = 0
local bonusClaimed = true
local lastTaskTarget: Vector3? = nil
local shopTargetSet = false
local jobsButton: GuiObject? = nil
local teleporting = false

-- ---------------------------------------------------------------- util

local function rootPart(): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

local function retentionView(): RetentionConfig.RetentionView?
	local raw = player:GetAttribute(RetentionConfig.ATTR)
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded :: any else nil
end

-- Kalimat pengingat untuk kembali besok, memakai hadiah login yang sebenarnya.
local function teaser(): (string, boolean)
	local view = retentionView()
	if view == nil or type(view.nextDay) ~= "number" then
		return "Kembali besok untuk hadiah login!", false
	end
	local day = if view.claimedToday then view.nextDay else view.nextDay % 7 + 1
	local base = RetentionConfig.STREAK[day] or RetentionConfig.STREAK[1]
	local mult = if player:GetAttribute("VIP") == true then RetentionConfig.VIP_MULTIPLIER else 1
	return `Hari ke-{day} menunggumu! Login besok: hadiah {Format.money(base * mult)}`,
		not view.claimedToday
end

local function formatClock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

-- ---------------------------------------------------------------- GPS

local function gpsToTask()
	local target = JobController.getTarget()
	if target == nil or rootPart() == nil then
		return
	end
	local last = lastTaskTarget
	if last and (target - last).Magnitude < 5 then
		return
	end
	lastTaskTarget = target
	NavController.setTarget({
		id = nil,
		name = "tugasmu",
		icon = "⭐",
		position = target,
		arrive = 12,
	})
end

local function gpsToShop()
	local root = rootPart()
	if shopTargetSet or root == nil then
		return
	end
	local best: DestinationConfig.Destination? = nil
	local bestDistance = math.huge
	for _, id in OnboardingConfig.SHOP_TARGETS do
		local destination = DestinationConfig.get(id)
		if destination then
			local distance = (destination.position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = destination, distance
			end
		end
	end
	if best then
		shopTargetSet = true
		NavController.setTarget({
			id = best.id,
			name = best.name,
			icon = best.icon,
			position = best.position,
			arrive = best.arrive,
		})
	end
end

local function refreshGps(step: number)
	if step == 1 then
		gpsToTask()
	elseif step == 2 then
		gpsToShop()
	end
end

-- ---------------------------------------------------------------- tampilan

local function showDone()
	UiKit.clear(doneBody)
	local final = OnboardingConfig.STEPS[STEP_COUNT]
	UiKit.label(doneBody, {
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 62),
		TextSize = 14,
		Text = `Hadiahmu: {Format.money(final.reward)} dan setelan gratis Jaket Warga Baru. Setelan terlihat saat kamu tidak sedang bekerja.`,
	})
	local text, canClaim = teaser()
	local day = UiKit.label(doneBody, {
		LayoutOrder = 2,
		Size = UDim2.new(1, -6, 0, 58),
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "📅 " .. text,
	})
	UiKit.corner(day, 10)
	if canClaim then
		local claim = UiKit.button(doneBody, {
			Name = "HadiahLogin",
			LayoutOrder = 3,
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = COLORS.accent,
			TextSize = 15,
			Text = "🎁 Ambil hadiah login hari ini",
		})
		claim.Activated:Connect(function()
			donePanel.Visible = false
			RetentionController.open("Login")
		end)
	end
	local go = UiKit.button(doneBody, {
		Name = "Lanjut",
		LayoutOrder = 4,
		Size = UDim2.new(1, -6, 0, 40),
		BackgroundColor3 = COLORS.go,
		TextSize = 15,
		Text = "Lanjut main!",
	})
	go.Activated:Connect(function()
		donePanel.Visible = false
	end)
	donePanel.Visible = true
end

local function refreshCard(view: OnboardingConfig.View)
	local def = OnboardingConfig.STEPS[view.step + 1]
	card.Visible = not view.done and def ~= nil
	if def then
		cardTitle.Text = `⭐ Misi Pemula {view.step + 1}/{STEP_COUNT}`
		cardStep.Text = def.icon .. " " .. def.title
		cardHint.Text = `{def.hint} Hadiah {Format.money(def.reward)}`
	end
end

local function refreshTimer()
	if bonusClaimed then
		timerChip.Visible = false
		return
	end
	local left = bonusEndsAt - os.clock()
	timerChip.Visible = true
	timerChip.Text = if left > 0
		then `🎁 Bonus {Format.money(OnboardingConfig.PLAY_BONUS_AMOUNT)} dalam {formatClock(left)}`
		else "🎁 Bonus sedang dikirim..."
end

local function onView()
	local view = OnboardingConfig.read(player)
	if view == nil then
		return
	end
	bonusClaimed = view.bonusClaimed == true
	bonusEndsAt = os.clock() + (if type(view.bonusLeft) == "number" then view.bonusLeft else 0)
	refreshCard(view)
	refreshTimer()

	local previous = knownStep
	knownStep = view.step
	if previous ~= nil and previous ~= view.step then
		lastTaskTarget = nil
		if view.done then
			NavController.clear()
			showDone()
		end
	end
end

-- Penunjuk di samping tombol Pekerjaan (langkah 1). Mengikuti posisi tombol; tombol tidak diubah.
local function updatePointer(now: number)
	if knownStep ~= 0 then
		pointer.Visible = false
		return
	end
	local button = jobsButton
	if button == nil or button.Parent == nil then
		local found = player:WaitForChild("PlayerGui"):FindFirstChild("OpenJobs", true)
		button = if found and found:IsA("GuiObject") then found else nil
		jobsButton = button
	end
	if button == nil then
		pointer.Visible = false
		return
	end
	local parent = button.Parent
	local jobPanel = if parent then parent:FindFirstChild("Panel") else nil
	local panelOpen = jobPanel ~= nil and jobPanel:IsA("GuiObject") and jobPanel.Visible
	pointer.Visible = button.Visible and not panelOpen
	local bob = 6 * math.abs(math.sin(now * 4))
	pointer.Position = UDim2.fromOffset(
		button.AbsolutePosition.X + button.AbsoluteSize.X + 6 + bob,
		button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2
	)
end

-- ---------------------------------------------------------------- teleport

local function teleportTo(spot: OnboardingConfig.Spot)
	if teleporting then
		return
	end
	teleporting = true
	local ok, value = pcall(function(): any
		return Net.func(Net.Names.OnboardingAction):InvokeServer("teleport", spot.id)
	end)
	local good = ok and type(value) == "table" and value.ok == true
	HudController.toast(
		if ok
				and type(value) == "table"
				and type(value.message) == "string"
			then value.message
			else "Gagal terhubung, coba lagi."
	)
	if good then
		teleportPanel.Visible = false
	end
	task.wait(0.4)
	teleporting = false
end

local function buildTeleportRows()
	for order, spot in OnboardingConfig.SPOTS do
		local row = Instance.new("Frame")
		row.Name = spot.id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -6, 0, 56)
		row.BackgroundColor3 = COLORS.card
		UiKit.corner(row, 10)
		UiKit.label(row, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -108, 0, 22),
			Font = Enum.Font.FredokaOne,
			TextSize = 16,
			TextWrapped = false,
			Text = spot.icon .. " " .. spot.name,
		})
		UiKit.label(row, {
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -108, 0, 22),
			TextColor3 = COLORS.subtle,
			TextSize = 11,
			Text = spot.note,
		})
		local go = UiKit.button(row, {
			Name = "Pergi",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(84, 36),
			BackgroundColor3 = COLORS.go,
			Text = "Pergi",
		})
		go.Activated:Connect(function()
			teleportTo(spot)
		end)
		row.Parent = teleportBody
	end
end

-- ---------------------------------------------------------------- UI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "OnboardingGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.BackgroundTransparency = 1
	stack.Size = UDim2.fromOffset(210, 120)
	UiScale.attach(stack)
	UiScale.onChange(function(value: number)
		stack.Position = UDim2.new(1, -8, 0, 4 + TOP_OFFSET * value)
	end)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = stack
	stack.Parent = gui

	card = Instance.new("TextButton")
	card.Name = "MisiPemula"
	card.LayoutOrder = 1
	card.Size = UDim2.fromOffset(210, 84)
	card.BackgroundColor3 = COLORS.panel
	card.BackgroundTransparency = 0.1
	card.AutoButtonColor = false
	card.Text = ""
	card.Visible = false
	UiKit.corner(card, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = GOLD
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	card.Parent = stack

	cardTitle = UiKit.label(card, {
		Name = "Judul",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.FredokaOne,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 130, 0),
		TextWrapped = false,
		Text = "",
	})
	cardStep = UiKit.label(card, {
		Name = "Langkah",
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	cardHint = UiKit.label(card, {
		Name = "Petunjuk",
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 0, 38),
		TextColor3 = COLORS.subtle,
		TextSize = 11,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})

	timerChip = UiKit.label(stack, {
		Name = "BonusMain",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(210, 26),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = COLORS.panel,
		Font = Enum.Font.FredokaOne,
		TextSize = 13,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Text = "",
	})
	UiKit.corner(timerChip, 10)

	pointer = UiKit.label(gui, {
		Name = "Penunjuk",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(170, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Text = "◀ Mulai di sini!",
	})
	UiKit.corner(pointer, 10)
	UiScale.attach(pointer)

	banner = UiKit.label(gui, {
		Name = "PengingatBesok",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(380, 46),
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Text = "",
	})
	UiKit.corner(banner, 12)
	UiScale.attach(banner)

	donePanel, doneBody =
		UiKit.modal(gui, "PemulaSelesai", "🎉 Misi Pemula selesai!", Vector2.new(340, 290))
	UiScale.attach(donePanel)
	teleportPanel, teleportBody =
		UiKit.modal(gui, "TeleportCepat", "🚀 Teleport Cepat", Vector2.new(330, 380))
	UiScale.attach(teleportPanel)
	buildTeleportRows()

	gui.Parent = player:WaitForChild("PlayerGui")
end

function OnboardingController.openTeleport()
	donePanel.Visible = false
	teleportPanel.Visible = true
end

function OnboardingController.init()
	buildGui()
end

function OnboardingController.start()
	PhoneController.addApp("🚀", "Teleport", OnboardingController.openTeleport)

	player:GetAttributeChangedSignal(OnboardingConfig.ATTR):Connect(onView)
	onView()

	-- Ketuk kartu = pasang ulang GPS ke tujuan langkah ini.
	card.Activated:Connect(function()
		local step = knownStep
		if step == 0 then
			HudController.toast("Tekan tombol Pekerjaan di kiri, lalu tekan Mulai.")
		elseif step then
			lastTaskTarget = nil
			shopTargetSet = false
			refreshGps(step)
		end
	end)

	-- Pemain membuka menu Roblox (biasanya mau keluar): ingatkan hadiah besok.
	GuiService.MenuOpened:Connect(function()
		local text = teaser()
		banner.Text = "📅 " .. text
		banner.Visible = true
	end)
	GuiService.MenuClosed:Connect(function()
		task.delay(4, function()
			if not GuiService.MenuIsOpen then
				banner.Visible = false
			end
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if knownStep == 0 or pointer.Visible then
			updatePointer(os.clock())
		end
	end)

	while true do
		task.wait(1)
		refreshTimer()
		local step = knownStep
		if step and step > 0 and step < STEP_COUNT then
			refreshGps(step)
		end
	end
end

return OnboardingController
