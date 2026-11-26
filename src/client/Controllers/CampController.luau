--!strict
--[[
	CampController: sisi client Perkemahan (lihat CampService / CampConfig).
	  * Panel "Warung Kemah" (beli pancing/tenda/mie, jual ikan, pasang tenda) dan panel api unggun/panggangan
	    (bakar ikan, masak mie, makan). Semua tombol hanya mengirim aksi; server yang memutuskan.
	  * Tombol besar "TARIK!" muncul saat ikan menggigit (event CampFish dari server).
	  * Gerak gitaris Kak Bagas: duduk memetik gitar lewat Motor6D.Transform lokal (tanpa animasi dari server),
	    hanya untuk model dalam POSE_DISTANCE dari kamera (hemat HP).
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local Config = require(Shared:WaitForChild("CampConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

type CampView = Config.CampView

local player = Players.LocalPlayer
local CampController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 250, 240),
	card = rgb(247, 238, 222),
	text = rgb(60, 44, 30),
	subtle = rgb(125, 105, 85),
	accent = rgb(86, 160, 80),
	buy = rgb(255, 170, 0),
	close = rgb(235, 90, 90),
	locked = rgb(200, 195, 188),
}
local POSE_DISTANCE = 100

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local body: ScrollingFrame
local scaleObj: UIScale
local reelButton: TextButton
local waitLabel: TextLabel
local mode: string? = nil
local fireKind = "unggun"
local busy = false
local refreshPanel: () -> ()
local biteToken = 0

-- ---------------------------------------------------------------- util

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
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
	return l
end

local function button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	return b
end

local function getView(): CampView
	local raw = player:GetAttribute(Config.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" then
			return {
				rod = if type(value.rod) == "string" then value.rod else "",
				tent = value.tent == true,
				mie = if type(value.mie) == "number" then value.mie else 0,
				mieMasak = if type(value.mieMasak) == "number" then value.mieMasak else 0,
				fish = if type(value.fish) == "table" then value.fish else {},
				grilled = if type(value.grilled) == "table" then value.grilled else {},
			}
		end
	end
	return { rod = "", tent = false, mie = 0, mieMasak = 0, fish = {}, grilled = {} }
end

local function act(action: string, a: any?, b: any?): boolean
	if busy then
		return false
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func("CampAction"):InvokeServer(action, a, b)
	end)
	local good = ok and type(value) == "table" and type(value.message) == "string"
	HudController.toast(if good then value.message else "Gagal terhubung, coba lagi.")
	busy = false
	if refreshPanel then
		refreshPanel()
	end
	return good and value.ok == true
end

-- ---------------------------------------------------------------- panel

local rowOrder = 0

local function header(text: string)
	rowOrder += 1
	label({
		LayoutOrder = rowOrder,
		Size = UDim2.new(1, -8, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = COLORS.accent,
		Text = text,
	}).Parent =
		body
end

local function row(
	title: string,
	subtitle: string,
	buttons: { { text: string, color: Color3?, enabled: boolean, onClick: () -> () } }
)
	rowOrder += 1
	local f = Instance.new("Frame")
	f.BackgroundColor3 = COLORS.card
	f.Size = UDim2.new(1, -8, 0, 58)
	f.LayoutOrder = rowOrder
	corner(f, 10)
	f.Parent = body
	local width = #buttons * 84 + 8
	label({
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -width - 12, 0, 22),
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = title,
	}).Parent =
		f
	label({
		Position = UDim2.fromOffset(10, 27),
		Size = UDim2.new(1, -width - 12, 0, 28),
		TextColor3 = COLORS.subtle,
		TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = subtitle,
	}).Parent =
		f
	for i, spec in buttons do
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (#buttons - i) * 84, 0.5, 0),
			Size = UDim2.fromOffset(78, 38),
			Text = spec.text,
			BackgroundColor3 = if spec.enabled
				then (spec.color or COLORS.accent)
				else COLORS.locked,
			Name = "Aksi" .. i,
		})
		b.Parent = f
		b.Activated:Connect(function()
			if spec.enabled then
				spec.onClick()
			end
		end)
	end
end

local function note(text: string)
	rowOrder += 1
	label({
		LayoutOrder = rowOrder,
		Size = UDim2.new(1, -8, 0, 34),
		TextColor3 = COLORS.subtle,
		TextSize = 13,
		Text = text,
	}).Parent =
		body
end

local function clearBody()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rowOrder = 0
end

local function buildShop(view: CampView)
	titleLabel.Text = "🏕️ Warung Kemah"
	local money = player:GetAttribute("Money")
	local rich = type(money) == "number" and money
	header("Beli")
	for _, item in Config.ITEMS do
		local owned = (item.id == "pancing_kayu" and view.rod ~= "")
			or (item.id == "pancing_fiber" and view.rod == "fiber")
			or (item.id == "tenda" and view.tent)
		local afford = rich ~= false and (rich :: number) >= item.price
		local extra = if item.id == "mie" then ` (punya {view.mie})` else ""
		row(`{item.icon} {item.name}{extra}`, `{item.desc}`, {
			{
				text = if owned then "Punya" else Format.money(item.price),
				color = COLORS.buy,
				enabled = (not owned) and afford,
				onClick = function()
					act("buy", item.id)
				end,
			},
		})
	end
	header("Jual ikan")
	local any = false
	for _, fish in Config.FISH do
		local raw = view.fish[fish.id] or 0
		local grilled = view.grilled[fish.id] or 0
		if raw > 0 then
			any = true
			row(`{fish.icon} {fish.name} x{raw}`, `Mentah: {Format.money(fish.price)} per ekor`, {
				{
					text = "Jual",
					enabled = true,
					onClick = function()
						act("sell", fish.id, "raw")
					end,
				},
			})
		end
		if grilled > 0 then
			any = true
			row(
				`🔥 {fish.name} bakar x{grilled}`,
				`Bakar: {Format.money(Config.grilledPrice(fish, nil))} per ekor`,
				{
					{
						text = "Jual",
						enabled = true,
						onClick = function()
							act("sell", fish.id, "grilled")
						end,
					},
				}
			)
		end
	end
	if any then
		row("💰 Jual semua ikan", "Mentah dan bakar sekaligus", {
			{
				text = "Jual",
				color = COLORS.buy,
				enabled = true,
				onClick = function()
					act("sell", "all", "all")
				end,
			},
		})
	else
		note("Belum ada ikan. Beli pancing lalu mancing di dermaga! 🎣")
	end
	if view.tent then
		header("Tendaku")
		row("⛺ Tenda Kemah", "Pasang di depanmu (dekat perkemahan) atau bongkar.", {
			{
				text = "Pasang",
				enabled = true,
				onClick = function()
					act("place")
				end,
			},
			{
				text = "Bongkar",
				color = COLORS.close,
				enabled = true,
				onClick = function()
					act("pack")
				end,
			},
		})
	end
end

local function buildFire(view: CampView)
	local bbq = fireKind == "panggangan"
	titleLabel.Text = if bbq then "🍖 Panggangan" else "🔥 Api Unggun"
	header("Bakar ikan")
	local any = false
	local cap = Config.GRILL_CAPACITY[fireKind] or 2
	for _, fish in Config.FISH do
		local raw = view.fish[fish.id] or 0
		if raw > 0 then
			any = true
			row(
				`{fish.icon} {fish.name} x{raw}`,
				`Bakar sampai {cap} sekaligus: jadi {Format.money(
					Config.grilledPrice(fish, fireKind)
				)} per ekor`,
				{
					{
						text = "Bakar",
						enabled = true,
						onClick = function()
							act("grill", fish.id)
						end,
					},
				}
			)
		end
	end
	if not any then
		note("Tidak ada ikan mentah. Mancing dulu di dermaga! 🎣")
	end
	if not bbq then
		header("Masak mie")
		row(`🍜 Mie Cup x{view.mie}`, "Rebus di api unggun, 5 detik.", {
			{
				text = "Masak",
				enabled = view.mie > 0,
				onClick = function()
					act("cook")
				end,
			},
		})
	end
	header("Makan")
	local ate = false
	for _, fish in Config.FISH do
		local g = view.grilled[fish.id] or 0
		if g > 0 then
			ate = true
			row(`🔥 {fish.name} bakar x{g}`, "Makan: lari lebih cepat sebentar.", {
				{
					text = "Makan",
					enabled = true,
					onClick = function()
						act("eat", fish.id)
					end,
				},
			})
		end
	end
	if view.mieMasak > 0 then
		ate = true
		row(`🍜 Mie rebus x{view.mieMasak}`, "Makan: lari lebih cepat sebentar.", {
			{
				text = "Makan",
				enabled = true,
				onClick = function()
					act("eat", "mie")
				end,
			},
		})
	end
	if not ate then
		note("Belum ada makanan matang.")
	end
end

refreshPanel = function()
	if mode == nil then
		return
	end
	clearBody()
	local view = getView()
	if mode == "shop" then
		buildShop(view)
	else
		buildFire(view)
	end
end

local function closePanel()
	mode = nil
	panel.Visible = false
end

local function openPanel(newMode: string, title: string, kind: string?)
	mode = newMode
	fireKind = kind or "unggun"
	titleLabel.Text = title
	panel.Visible = true
	refreshPanel()
end

-- ---------------------------------------------------------------- tombol memancing

local function showWait(text: string?)
	waitLabel.Visible = text ~= nil
	if text then
		waitLabel.Text = text
	end
end

local function onFishEvent(state: any, a: any)
	biteToken += 1
	local mine = biteToken
	reelButton.Visible = false
	if state == "cast" then
		showWait("🎣 Menunggu ikan menggigit...")
	elseif state == "bite" then
		showWait(nil)
		reelButton.Visible = true
		task.delay((type(a) == "number" and a or 2) + 0.4, function()
			if biteToken == mine then
				reelButton.Visible = false
			end
		end)
	elseif state == "catch" then
		showWait(nil)
		local fish = Config.fish(a)
		HudController.toast(if fish then `{fish.icon} Dapat {fish.name}!` else "Dapat ikan!")
	else
		showWait(nil)
	end
end

-- ---------------------------------------------------------------- gitaris

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local guitarJoints: { [Model]: { [string]: any } } = {}

local function bind(model: Model): { [string]: any }?
	local joints: { [string]: any } = {}
	for _, name in
		{
			"Root",
			"RightShoulder",
			"LeftShoulder",
			"RightElbow",
			"LeftElbow",
			"RightHip",
			"LeftHip",
			"RightKnee",
			"LeftKnee",
			"Neck",
			"Waist",
		}
	do
		local j = model:FindFirstChild(name, true)
		if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
			joints[name] = j
		end
	end
	if joints.RightShoulder == nil or joints.RightElbow == nil then
		return nil
	end
	return joints
end

local function stepGuitar()
	local camera = Workspace.CurrentCamera
	for _, model in CollectionService:GetTagged(Config.TAG_GUITAR) do
		if model:IsA("Model") and model:IsDescendantOf(Workspace) then
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if
				camera
				and root
				and root:IsA("BasePart")
				and (root.Position - camera.CFrame.Position).Magnitude <= POSE_DISTANCE
			then
				local joints = guitarJoints[model]
				if joints == nil then
					joints = bind(model)
					if joints then
						guitarJoints[model] = joints
					end
				end
				if joints then
					local t = os.clock()
					local strum = math.sin(t * 8) * 14
					local function set(name: string, cf: CFrame)
						local j = joints[name]
						if j then
							j.Transform = cf
						end
					end
					set("Root", CFrame.new(0, -0.35, 0))
					set("RightHip", R(86, 0, 4))
					set("LeftHip", R(86, 0, -4))
					set("RightKnee", R(-86, 0, 0))
					set("LeftKnee", R(-86, 0, 0))
					set("RightShoulder", R(42, 0, -12))
					set("RightElbow", R(52 + strum, 0, 0))
					set("LeftShoulder", R(66, 0, 22))
					set("LeftElbow", R(38, 0, 0))
					set("Neck", R(math.sin(t * 2) * 4, math.sin(t * 1.3) * 6, 0))
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- GUI

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "KemahUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "PanelKemah"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(400, 440)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(190, 140, 80)
	stroke.Thickness = 3
	stroke.Parent = panel
	scaleObj = Instance.new("UIScale")
	scaleObj.Parent = panel
	panel.Parent = gui

	titleLabel = label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 34),
		Font = Enum.Font.FredokaOne,
		TextSize = 24,
		Text = "Perkemahan",
	})
	titleLabel.Parent = panel
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(42, 34),
		Text = "✖",
		BackgroundColor3 = COLORS.close,
		Name = "Tutup",
	})
	close.Parent = panel
	close.Activated:Connect(closePanel)

	body = Instance.new("ScrollingFrame")
	body.Name = "Isi"
	body.Position = UDim2.fromOffset(12, 50)
	body.Size = UDim2.new(1, -24, 1, -62)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	body.Parent = panel

	reelButton = button({
		Name = "Tarik",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(210, 70),
		Text = "🎣 TARIK!",
		TextSize = 30,
		BackgroundColor3 = rgb(235, 90, 60),
		Visible = false,
	})
	reelButton.Parent = gui
	reelButton.Activated:Connect(function()
		reelButton.Visible = false
		act("reel")
	end)

	waitLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(300, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = rgb(255, 255, 255),
		TextStrokeTransparency = 0.3,
		Visible = false,
		Text = "",
	})
	waitLabel.Parent = gui

	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scaleObj.Scale = math.clamp(math.min(size.X / 520, size.Y / 500), 0.6, 1)
		end
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
end

function CampController.init()
	buildGui()
end

function CampController.start()
	Net.event("CampOpen").OnClientEvent:Connect(function(newMode: any, title: any, kind: any)
		if (newMode == "shop" or newMode == "fire") and type(title) == "string" then
			openPanel(newMode, title, if type(kind) == "string" then kind else nil)
		end
	end)
	Net.event("CampFish").OnClientEvent:Connect(onFishEvent)
	player:GetAttributeChangedSignal(Config.ATTR_PLAYER):Connect(function()
		if mode then
			refreshPanel()
		end
	end)
	-- tutup panel bila pemain menjauh dari lapak / api
	task.spawn(function()
		while true do
			task.wait(1)
			if mode then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local tag = if mode == "shop" then Config.TAG_VENDOR else Config.TAG_FIRE
				local near = false
				if root and root:IsA("BasePart") then
					for _, part in CollectionService:GetTagged(tag) do
						if
							part:IsA("BasePart")
							and (part.Position - root.Position).Magnitude
								<= Config.TALK_DISTANCE + 6
						then
							near = true
							break
						end
					end
				end
				if not near then
					closePanel()
				end
			end
		end
	end)
	RunService.PreSimulation:Connect(stepGuitar)
end

return CampController
