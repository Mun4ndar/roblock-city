--!strict
-- SocialController: panel "Sosial" di HP (teman & kunjungan rumah, kru, akses rumah, emote)
-- dan Mode Foto (kamera bebas, filter, pose, simpan ke galeri Roblox).
-- Semua perubahan data lewat remote SocialAction; emote dimainkan lokal di Animator sendiri
-- (Roblox mereplikasinya ke pemain lain).

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local HouseConfig = require(Shared:WaitForChild("HouseConfig"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))
local PhoneController = require(script.Parent:WaitForChild("PhoneController"))
local UiScale = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UiScale"))

local player = Players.LocalPlayer

local SocialController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(238, 246, 252),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(70, 140, 230),
	go = rgb(64, 190, 100),
	warn = rgb(255, 184, 0),
	close = rgb(235, 90, 90),
	locked = rgb(200, 205, 214),
}
local TABS = { "Teman", "Kru", "Rumah", "Emote" }

local gui: ScreenGui
local panel: Frame
local body: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Teman"
local busy = false
local inviteFrame: Frame
local inviteText: TextLabel
local inviteToken = 0

-- ---------------------------------------------------------------- util UI

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = 14
	l.TextWrapped = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	b.Parent = parent
	return b
end

local function clearBody()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -8, 0, height)
	f.BackgroundColor3 = COLORS.card
	f.LayoutOrder = order
	corner(f, 10)
	f.Parent = body
	return f
end

local function heading(text: string, order: number)
	local l = label(body, {
		Size = UDim2.new(1, -8, 0, 22),
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		LayoutOrder = order,
	})
	l.TextColor3 = COLORS.accent
end

local function getHouseLive(p: Player): number
	local raw = p:GetAttribute(HouseConfig.ATTR_PLAYER)
	if type(raw) ~= "string" then
		return 0
	end
	local ok, value = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(value) == "table" and type(value.live) == "number" then
		return value.live
	end
	return 0
end

local function myCrewId(): string
	local id = player:GetAttribute(SocialConfig.ATTR_CREW_ID)
	return if type(id) == "string" then id else ""
end

local refresh: () -> ()

local function call(action: string, arg: any?): any
	if busy then
		return nil
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func("SocialAction"):InvokeServer(action, arg)
	end)
	busy = false
	if ok and type(value) == "table" then
		if type(value.message) == "string" and value.message ~= "" then
			HudController.toast(value.message)
		end
		return value
	end
	HudController.toast("Gagal terhubung, coba lagi.")
	return nil
end

-- ---------------------------------------------------------------- emote & pose

local currentTrack: AnimationTrack? = nil
local runningConnection: RBXScriptConnection? = nil

local function getAnimator(): (Animator?, Humanoid?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	return animator, humanoid
end

local function stopEmote()
	if currentTrack then
		currentTrack:Stop(0.2)
		currentTrack = nil
	end
end

local function watchMovement(humanoid: Humanoid)
	if runningConnection then
		runningConnection:Disconnect()
	end
	runningConnection = humanoid.Running:Connect(function(speed: number)
		if speed > 1.5 then
			stopEmote()
		end
	end)
end

local function loadTrack(animId: number): (AnimationTrack?, Humanoid?)
	stopEmote()
	local animator, humanoid = getAnimator()
	if animator == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	watchMovement(humanoid)
	return track, humanoid
end

local function playEmote(def: SocialConfig.Emote)
	local track = loadTrack(def.anim)
	if track == nil then
		return
	end
	track.Looped = def.loop
	track:Play(0.15)
	currentTrack = track
end

local function playPose(def: SocialConfig.Pose)
	local track = loadTrack(def.anim)
	if track == nil then
		return
	end
	track.Looped = true
	track:Play(0)
	currentTrack = track
	task.spawn(function()
		local waited = 0
		while track.Length <= 0 and waited < 3 do
			waited += task.wait(0.1)
		end
		if currentTrack == track then
			track.TimePosition = track.Length * def.at
			track:AdjustSpeed(0)
		end
	end)
end

local function sitDown()
	local _, humanoid = getAnimator()
	if humanoid and humanoid.SeatPart == nil then
		stopEmote()
		humanoid.Sit = true
	end
end

-- ---------------------------------------------------------------- Mode Foto

local photo = {
	active = false,
	yaw = 0,
	pitch = 0.12,
	dist = 9,
	fov = 70,
	filter = 1,
	poseIndex = 0,
	hidden = {} :: { [ScreenGui]: boolean },
	gui = nil :: ScreenGui?,
	bar = nil :: Frame?,
	effect = nil :: ColorCorrectionEffect?,
	dragging = false,
	connections = {} :: { RBXScriptConnection },
}
local FOVS = { 50, 70, 90 }

local function setControlsEnabled(enabled: boolean)
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local moduleScript = if scripts then scripts:FindFirstChild("PlayerModule") else nil
		if moduleScript == nil then
			return
		end
		local module = require(moduleScript :: ModuleScript) :: any
		local controls = module:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function applyFilter()
	local effect = photo.effect
	if effect == nil then
		return
	end
	local f = SocialConfig.FILTERS[photo.filter]
	effect.Brightness = f.brightness
	effect.Contrast = f.contrast
	effect.Saturation = f.saturation
	effect.TintColor = f.tint
end

local function exitPhoto()
	if not photo.active then
		return
	end
	photo.active = false
	RunService:UnbindFromRenderStep("RoblockPhoto")
	for _, c in photo.connections do
		c:Disconnect()
	end
	table.clear(photo.connections)
	for g in photo.hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(photo.hidden)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	if photo.gui then
		photo.gui:Destroy()
		photo.gui = nil
	end
	if photo.effect then
		photo.effect:Destroy()
		photo.effect = nil
	end
	stopEmote()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
	setControlsEnabled(true)
end

local function takeShot()
	local bar = photo.bar
	if bar == nil then
		return
	end
	bar.Visible = false
	task.wait(0.2)
	local done = false
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService")
		CaptureService:CaptureScreenshot(function(contentId: string)
			done = true
			bar.Visible = true
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)
	if not ok then
		bar.Visible = true
		HudController.toast("Foto tidak bisa disimpan di sini. Pakai tombol kamera Roblox.")
		return
	end
	task.delay(4, function()
		if not done and bar.Parent then
			bar.Visible = true
		end
	end)
end

local function enterPhoto()
	if photo.active then
		return
	end
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	local camera = Workspace.CurrentCamera
	if root == nil or camera == nil then
		return
	end
	photo.active = true
	panel.Visible = false
	local look = root.CFrame.LookVector
	photo.yaw = math.atan2(look.X, look.Z) -- kamera di depan wajah
	photo.pitch = 0.12
	photo.dist = 9
	photo.filter = 1
	photo.poseIndex = 1
	photo.fov = 70

	local playerGui = player:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Enabled and child ~= gui then
			photo.hidden[child] = true
			child.Enabled = false
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	setControlsEnabled(false)

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "FotoFilter"
	effect.Parent = Lighting
	photo.effect = effect

	local pg = Instance.new("ScreenGui")
	pg.Name = "PhotoGui"
	pg.ResetOnSpawn = false
	pg.IgnoreGuiInset = true
	pg.DisplayOrder = 50
	pg.Parent = playerGui
	photo.gui = pg

	local bar = Instance.new("Frame")
	bar.Name = "FotoBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -14)
	bar.Size = UDim2.fromOffset(416, 52)
	bar.BackgroundColor3 = rgb(20, 24, 32)
	bar.BackgroundTransparency = 0.25
	corner(bar, 14)
	bar.Parent = pg
	UiScale.attach(bar)
	photo.bar = bar
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	local barCount = 0

	local function bt(name: string, text: string, color: Color3?, onClick: (TextButton) -> ())
		barCount += 1
		local b = button(bar, {
			Name = name,
			LayoutOrder = barCount,
			Size = UDim2.fromOffset(52, 40),
			Text = text,
			TextSize = 18,
			BackgroundColor3 = color or rgb(70, 78, 96),
		})
		b.Activated:Connect(function()
			onClick(b)
		end)
	end
	bt("Jepret", "📸", COLORS.go, function()
		task.spawn(takeShot)
	end)
	bt("Putar", "🔄", nil, function()
		photo.yaw += math.pi
	end)
	bt("Dekat", "➕", nil, function()
		photo.dist = math.max(3, photo.dist - 2)
	end)
	bt("Jauh", "➖", nil, function()
		photo.dist = math.min(30, photo.dist + 2)
	end)
	bt("Lensa", "🔍", nil, function()
		local index = table.find(FOVS, photo.fov) or 1
		photo.fov = FOVS[index % #FOVS + 1]
	end)
	bt("Filter", "🎨", nil, function()
		photo.filter = photo.filter % #SocialConfig.FILTERS + 1
		applyFilter()
		HudController.toast("Filter: " .. SocialConfig.FILTERS[photo.filter].name)
	end)
	bt("Pose", "🧍", nil, function()
		photo.poseIndex = photo.poseIndex % (#SocialConfig.POSES + 1) + 1
		local def = SocialConfig.POSES[photo.poseIndex - 1]
		if photo.poseIndex == 1 or def == nil then
			photo.poseIndex = 1
			stopEmote()
			HudController.toast("Pose: biasa")
		else
			playPose(def)
			HudController.toast("Pose: " .. def.name)
		end
	end)
	local exit = button(pg, {
		Name = "Keluar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(110, 38),
		Text = "✖ Keluar",
		BackgroundColor3 = COLORS.close,
	})
	UiScale.attach(exit)
	exit.Activated:Connect(exitPhoto)

	-- Putar kamera: seret satu jari/tombol mouse kanan; zoom: roda mouse / cubit.
	table.insert(
		photo.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
			then
				photo.dragging = true
			end
		end)
	)
	table.insert(
		photo.connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
			then
				photo.dragging = false
			end
		end)
	)
	table.insert(
		photo.connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				photo.dist = math.clamp(photo.dist - input.Position.Z * 1.5, 3, 30)
			elseif
				photo.dragging
				and not processed
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				photo.yaw -= input.Delta.X * 0.008
				photo.pitch = math.clamp(photo.pitch + input.Delta.Y * 0.006, -0.5, 1.2)
			end
		end)
	)
	table.insert(
		photo.connections,
		UserInputService.TouchPinch:Connect(function(_, scaleDelta: number)
			photo.dist = math.clamp(photo.dist / math.max(scaleDelta, 0.5), 3, 30)
		end)
	)
	table.insert(photo.connections, player.CharacterAdded:Connect(exitPhoto))

	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("RoblockPhoto", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local r = if char then char.PrimaryPart else nil
		if cam == nil or r == nil then
			return
		end
		local focus = r.Position + Vector3.new(0, 2, 0)
		local cp, sp = math.cos(photo.pitch), math.sin(photo.pitch)
		local dir = Vector3.new(cp * math.sin(photo.yaw), sp, cp * math.cos(photo.yaw))
		cam.FieldOfView = photo.fov
		cam.CFrame = CFrame.lookAt(focus + dir * photo.dist, focus)
	end)
	HudController.toast("Mode Foto: seret layar untuk memutar kamera.")
end

-- ---------------------------------------------------------------- isi panel

local function tabFriends()
	heading("Pemain di server ini", 0)
	local iAmLeader = player:GetAttribute(SocialConfig.ATTR_CREW_LEADER) == true
	local order = 1
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= player then
			others += 1
			local r = row(52, order)
			order += 1
			local crewName = p:GetAttribute(SocialConfig.ATTR_CREW_NAME)
			local access = p:GetAttribute(SocialConfig.ATTR_ACCESS)
			local icon = "🏠"
			for _, a in SocialConfig.ACCESS do
				if a.id == access then
					icon = a.icon
				end
			end
			local hasHouse = getHouseLive(p) > 0
			label(r, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -150, 1, 0),
				Text = `{p.DisplayName}{if type(crewName) == "string" and crewName ~= ""
					then "\n👥 " .. crewName
					else ""}{if hasHouse then "\n" .. icon .. " punya rumah" else ""}`,
				TextSize = 13,
			})
			local x = -8
			if hasHouse then
				local b = button(r, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(62, 34),
					Text = "🏠 Kunjungi",
					TextSize = 11,
					BackgroundColor3 = COLORS.go,
				})
				b.Activated:Connect(function()
					call("visit", p.UserId)
				end)
				x -= 68
			end
			if iAmLeader and p:GetAttribute(SocialConfig.ATTR_CREW_ID) == "" then
				local b = button(r, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(62, 34),
					Text = "👥 Undang",
					TextSize = 11,
					BackgroundColor3 = COLORS.warn,
				})
				b.Activated:Connect(function()
					call("crewInvite", p.UserId)
				end)
			end
		end
	end
	if others == 0 then
		label(body, {
			Size = UDim2.new(1, -8, 0, 60),
			Text = "Belum ada pemain lain di server ini. Ajak temanmu main bareng!",
			TextColor3 = COLORS.subtle,
			LayoutOrder = 1,
		})
	end
end

local function tabCrew()
	local crewId = myCrewId()
	if crewId == "" then
		heading("Belum punya kru", 0)
		label(body, {
			Size = UDim2.new(1, -8, 0, 50),
			Text = "Kru = keluarga atau geng kecilmu (sampai 6 orang). Anggota kru boleh masuk rumah satu sama lain.",
			TextColor3 = COLORS.subtle,
			LayoutOrder = 1,
		})
		local r = row(48, 2)
		local box = Instance.new("TextBox")
		box.Name = "NamaKru"
		box.Position = UDim2.fromOffset(8, 7)
		box.Size = UDim2.new(1, -108, 0, 34)
		box.BackgroundColor3 = Color3.new(1, 1, 1)
		box.PlaceholderText = "Nama kru (3-16 huruf)"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 14
		box.TextColor3 = COLORS.text
		corner(box, 8)
		box.Parent = r
		local b = button(r, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(86, 34),
			Text = "Buat Kru",
			BackgroundColor3 = COLORS.go,
		})
		b.Activated:Connect(function()
			call("crewCreate", box.Text)
		end)
		return
	end
	local data = call("roster")
	if data == nil or type(data.members) ~= "table" then
		return
	end
	heading(`👥 {data.crewName}`, 0)
	local iAmLeader = player:GetAttribute(SocialConfig.ATTR_CREW_LEADER) == true
	local order = 1
	for _, m in data.members do
		local r = row(44, order)
		order += 1
		label(r, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Text = `{if m.leader then "👑 " else ""}{m.name}{if m.online
				then "  🟢"
				else "  ⚪"}`,
		})
		if iAmLeader and not m.leader then
			local b = button(r, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(80, 32),
				Text = "Keluarkan",
				TextSize = 12,
				BackgroundColor3 = COLORS.close,
			})
			b.Activated:Connect(function()
				call("crewKick", m.userId)
			end)
		end
	end
	local leave = button(body, {
		Size = UDim2.new(1, -8, 0, 38),
		Text = "Keluar dari kru",
		BackgroundColor3 = COLORS.close,
		LayoutOrder = order + 1,
	})
	leave.Activated:Connect(function()
		call("crewLeave")
	end)
	if iAmLeader then
		label(body, {
			Size = UDim2.new(1, -8, 0, 40),
			Text = "Untuk mengundang, dekati pemain lain lalu pilih Undang di tab Teman.",
			TextColor3 = COLORS.subtle,
			LayoutOrder = order + 2,
		})
	end
end

local function tabHouse()
	heading("Siapa boleh masuk rumahmu?", 0)
	local mode = player:GetAttribute(SocialConfig.ATTR_ACCESS)
	for i, a in SocialConfig.ACCESS do
		local r = row(54, i)
		label(r, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -100, 1, 0),
			Text = `{a.icon} {a.name}\n{a.note}`,
			TextSize = 13,
		})
		local selected = mode == a.id
		local b = button(r, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(78, 32),
			Text = if selected then "✔ Dipilih" else "Pilih",
			BackgroundColor3 = if selected then COLORS.go else COLORS.accent,
		})
		b.Activated:Connect(function()
			call("access", a.id)
		end)
	end
	label(body, {
		Size = UDim2.new(1, -8, 0, 60),
		Text = "Rumah hanya bisa dikunjungi saat pemiliknya sedang online di server yang sama. Cat dan hiasan diatur lewat HP > Rumahku.",
		TextColor3 = COLORS.subtle,
		LayoutOrder = 10,
	})
end

local function tabEmotes()
	heading("Emote", 0)
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 1
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(100, 44)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.Parent = grid
	for _, e in SocialConfig.EMOTES do
		local b = button(grid, { Text = `{e.icon} {e.name}`, TextSize = 13 })
		b.Activated:Connect(function()
			playEmote(e)
		end)
	end
	local sit = button(grid, { Text = "🪑 Duduk", TextSize = 13, BackgroundColor3 = COLORS.warn })
	sit.Activated:Connect(sitDown)
	local stop =
		button(grid, { Text = "⏹ Berhenti", TextSize = 13, BackgroundColor3 = COLORS.locked })
	stop.Activated:Connect(stopEmote)
	heading("Foto", 2)
	local photoButton = button(body, {
		Name = "BukaFoto",
		Size = UDim2.new(1, -8, 0, 44),
		Text = "📸 Buka Mode Foto",
		BackgroundColor3 = COLORS.go,
		LayoutOrder = 3,
	})
	photoButton.Activated:Connect(enterPhoto)
	label(body, {
		Size = UDim2.new(1, -8, 0, 40),
		Text = "Joget berhenti kalau kamu berjalan. Mode Foto punya pose, filter, dan simpan ke galeri.",
		TextColor3 = COLORS.subtle,
		LayoutOrder = 4,
	})
end

local TAB_FUNCS: { [string]: () -> () } = {
	Teman = tabFriends,
	Kru = tabCrew,
	Rumah = tabHouse,
	Emote = tabEmotes,
}

function refresh()
	if not panel.Visible then
		return
	end
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then COLORS.accent else COLORS.locked
	end
	clearBody()
	TAB_FUNCS[currentTab]()
end

local function showTab(name: string)
	currentTab = name
	refresh()
end

function SocialController.open()
	panel.Visible = true
	showTab(currentTab)
end

-- ---------------------------------------------------------------- bangun GUI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "SocialGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "SocialPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(400, 430)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 16)
	panel.Parent = gui
	UiScale.attach(panel)

	label(panel, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 30),
		Text = "👥 Sosial",
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
	})
	local close = button(panel, {
		Name = "Tutup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(34, 30),
		Text = "✖",
		BackgroundColor3 = COLORS.close,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.fromOffset(12, 44)
	tabs.Size = UDim2.new(1, -24, 0, 34)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	for index, name in TABS do
		local b = button(tabs, {
			Name = "Tab" .. name,
			LayoutOrder = index,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			Text = name,
			BackgroundColor3 = COLORS.locked,
		})
		b.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = b
	end

	body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(12, 86)
	body.Size = UDim2.new(1, -24, 1, -98)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	-- Undangan kru masuk.
	inviteFrame = Instance.new("Frame")
	inviteFrame.Name = "UndanganKru"
	inviteFrame.AnchorPoint = Vector2.new(0.5, 0)
	inviteFrame.Position = UDim2.new(0.5, 0, 0, 70)
	inviteFrame.Size = UDim2.fromOffset(320, 96)
	inviteFrame.BackgroundColor3 = COLORS.panel
	inviteFrame.Visible = false
	corner(inviteFrame, 14)
	inviteFrame.Parent = gui
	UiScale.attach(inviteFrame)
	inviteText = label(inviteFrame, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 48),
		Text = "",
	})
	local yes = button(inviteFrame, {
		Name = "Terima",
		Position = UDim2.new(0, 12, 1, -40),
		Size = UDim2.new(0.5, -18, 0, 32),
		Text = "Terima",
		BackgroundColor3 = COLORS.go,
	})
	local no = button(inviteFrame, {
		Name = "Tolak",
		Position = UDim2.new(0.5, 6, 1, -40),
		Size = UDim2.new(0.5, -18, 0, 32),
		Text = "Tolak",
		BackgroundColor3 = COLORS.close,
	})
	yes.Activated:Connect(function()
		inviteFrame.Visible = false
		call("crewAccept")
		refresh()
	end)
	no.Activated:Connect(function()
		inviteFrame.Visible = false
		call("crewDecline")
	end)
end

function SocialController.init()
	buildGui()
end

function SocialController.start()
	PhoneController.addApp("👥", "Sosial", SocialController.open)
	PhoneController.addApp("📸", "Mode Foto", enterPhoto)

	Net.event("SocialInvite").OnClientEvent:Connect(function(crewName: any, fromName: any)
		inviteToken += 1
		local token = inviteToken
		inviteText.Text = `{tostring(fromName)} mengundangmu masuk kru "{tostring(crewName)}".`
		inviteFrame.Visible = true
		task.delay(SocialConfig.INVITE_SECONDS, function()
			if token == inviteToken then
				inviteFrame.Visible = false
			end
		end)
	end)

	for _, attr in
		{ SocialConfig.ATTR_CREW_ID, SocialConfig.ATTR_ACCESS, SocialConfig.ATTR_CREW_LEADER }
	do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	Players.PlayerAdded:Connect(function()
		task.defer(refresh)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
end

return SocialController
