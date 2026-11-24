--!strict
-- FarmController: tampilan perkebunan di client.
--   * menggambar tanaman milik pemain di 8 petak Kebun Warga (hanya di layar sendiri)
--   * panel Pasar Tani (beli bibit, jual hasil panen) dan panel pilih bibit saat menanam
-- Semua aksi lewat remote; harga, stok, jarak, dan kematangan dicek server (FarmService).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Format = require(Shared:WaitForChild("Format"))
local FarmConfig = require(Shared:WaitForChild("FarmConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

type FarmView = FarmConfig.FarmView

local player = Players.LocalPlayer

local FarmController = {}

local rgb = Color3.fromRGB
local COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(240, 246, 236),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(86, 160, 80),
	buy = rgb(255, 184, 0),
	locked = rgb(200, 205, 214),
	close = rgb(235, 90, 90),
}
local STEM = rgb(70, 150, 70)
local REFRESH_SECONDS = 2

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local body: ScrollingFrame
local scale: UIScale
local folder: Folder

local busy = false
local mode: string? = nil -- "market" | "plant"
local plantIndex = 0
local marketName = "Pasar Tani"
local drawn: { [number]: string } = {} -- petak -> tanda keadaan yang sudah digambar
local refreshPanel: () -> ()

-- ---------------------------------------------------------------- util

local function corner(parent: GuiObject, radius: number)
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
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = COLORS.accent
	b.AutoButtonColor = true
	for key, value in props do
		(b :: any)[key] = value
	end
	corner(b, 10)
	return b
end

local function getView(): FarmView
	local raw = player:GetAttribute(FarmConfig.ATTR_PLAYER)
	if type(raw) == "string" then
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(value) == "table" then
			return {
				plots = if type(value.plots) == "table" then value.plots else {},
				seeds = if type(value.seeds) == "table" then value.seeds else {},
				crops = if type(value.crops) == "table" then value.crops else {},
			}
		end
	end
	return { plots = {}, seeds = {}, crops = {} }
end

local function call(remoteName: string, a: any?, b: any?): boolean
	if busy then
		return false
	end
	busy = true
	local ok, value = pcall(function(): any
		return Net.func(remoteName):InvokeServer(a, b)
	end)
	local good = ok and type(value) == "table" and type(value.message) == "string"
	HudController.toast(if good then value.message else "Gagal terhubung, coba lagi.")
	busy = false
	return good and value.ok == true
end

-- ---------------------------------------------------------------- tanaman di petak

local function plotParts(): { [number]: BasePart }
	local list: { [number]: BasePart } = {}
	for _, inst in CollectionService:GetTagged(FarmConfig.TAG_PLOT) do
		local index = inst:GetAttribute(FarmConfig.ATTR_PLOT_INDEX)
		if inst:IsA("BasePart") and type(index) == "number" then
			list[index] = inst
		end
	end
	return list
end

local function deco(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
end

local function plantTemplate(name: string?): Model?
	if name == nil then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder_ = if assets then assets:FindFirstChild("Tanaman") else nil
	local template = if folder_ then folder_:FindFirstChild(name) else nil
	return if template and template:IsA("Model") then template else nil
end

-- Tanaman mesh (Food Pack): 3x3 rumpun per petak, ukurannya tumbuh dari kecil sampai matang.
local function drawMeshPlot(
	model: Model,
	index: number,
	soil: BasePart,
	template: Model,
	crop: FarmConfig.CropDef,
	growth: number
)
	local top = soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)
	local spacing = math.min(soil.Size.X, soil.Size.Z) / 3.4
	local size = (crop.scale or 2) * (0.25 + 0.75 * growth)
	for ix = -1, 1 do
		for iz = -1, 1 do
			local rng = Random.new(index * 97 + ix * 13 + iz * 5)
			local plant = template:Clone()
			plant:ScaleTo(size * (0.9 + 0.2 * rng:NextNumber()))
			local height = plant:GetExtentsSize().Y
			plant:PivotTo(
				top
					* CFrame.new(
						ix * spacing + rng:NextNumber(-0.3, 0.3),
						height / 2 - 0.05,
						iz * spacing + rng:NextNumber(-0.3, 0.3)
					)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			)
			plant.Parent = model
		end
	end
end

-- Enam tanaman per petak; tinggi batang mengikuti kematangan, buah muncul saat siap panen.
local function drawPlot(index: number, soil: BasePart, crop: FarmConfig.CropDef, growth: number)
	local model = Instance.new("Model")
	model.Name = "Tanaman" .. index
	local template = plantTemplate(crop.model)
	if template then
		drawMeshPlot(model, index, soil, template, crop, growth)
		model.Parent = folder
		return
	end
	local top = soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)
	local height = 0.5 + 2.6 * growth
	for ix = -1, 1 do
		for iz = 0, 1 do
			local base = top * CFrame.new(ix * 3, 0, -1.8 + iz * 3.6)
			deco(
				model,
				Vector3.new(height, 0.35, 0.35),
				base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
				STEM,
				Enum.PartType.Cylinder
			)
			deco(
				model,
				Vector3.one * (0.7 + growth),
				base * CFrame.new(0, height, 0),
				STEM,
				Enum.PartType.Ball
			)
			if growth >= 1 then
				deco(
					model,
					Vector3.one * 1.3,
					base * CFrame.new(0.5, height * 0.6, 0.4),
					crop.color,
					Enum.PartType.Ball
				)
				deco(
					model,
					Vector3.one * 1.1,
					base * CFrame.new(-0.5, height * 0.8, -0.3),
					crop.color,
					Enum.PartType.Ball
				)
			end
		end
	end
	model.Parent = folder
end

local function refreshPlots()
	local view = getView()
	local now = Workspace:GetServerTimeNow()
	for index, soil in plotParts() do
		local plot = view.plots[tostring(index)]
		local crop = if plot then FarmConfig.crop(plot.crop) else nil
		local growth = if plot and crop then FarmConfig.growth(plot, now) else 0
		local stage = if crop then crop.id .. ":" .. tostring(math.floor(growth * 8)) else ""
		local prompt = soil:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = if crop == nil
				then "Tanam"
				elseif growth >= 1 then "Panen"
				else "Lihat"
			prompt.ObjectText = if crop then crop.icon .. " " .. crop.name else "Petak " .. index
		end
		if drawn[index] ~= stage then
			drawn[index] = stage
			local old = folder:FindFirstChild("Tanaman" .. index)
			if old then
				old:Destroy()
			end
			if crop then
				drawPlot(index, soil, crop, growth)
			end
		end
	end
end

-- ---------------------------------------------------------------- panel

local function row(height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = COLORS.card
	f.Size = UDim2.new(1, -8, 0, height)
	f.LayoutOrder = order
	corner(f, 10)
	f.Parent = body
	return f
end

local function buildMarket(view: FarmView)
	titleLabel.Text = marketName
	local money = player:GetAttribute("Money")
	local total = 0
	for order, crop in FarmConfig.CROPS do
		local seeds = view.seeds[crop.id] or 0
		local harvested = view.crops[crop.id] or 0
		total += harvested * crop.sellPrice
		local r = row(62, order)
		label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 22),
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
			Text = `{crop.icon} {crop.name}`,
		}).Parent =
			r
		label({
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -150, 0, 30),
			TextColor3 = COLORS.subtle,
			TextSize = 12,
			Text = `Tumbuh {Format.duration(crop.growSeconds)} · dijual {Format.money(
				crop.sellPrice
			)}\nBibit: {seeds} · Hasil panen: {harvested}`,
		}).Parent =
			r
		local affordable = type(money) == "number" and money >= crop.seedPrice
		local buy = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(124, 40),
			TextSize = 15,
			Text = "Bibit " .. Format.money(crop.seedPrice),
			TextColor3 = COLORS.text,
			BackgroundColor3 = if affordable then COLORS.buy else COLORS.locked,
		})
		buy.Parent = r
		buy.Activated:Connect(function()
			call(Net.Names.FarmBuySeed, crop.id)
		end)
	end
	local sellRow = row(52, 50)
	sellRow.BackgroundTransparency = 1
	local sell = button({
		Size = UDim2.new(1, 0, 0, 46),
		TextSize = 18,
		Text = if total > 0
			then "Jual semua hasil panen (" .. Format.money(total) .. ")"
			else "Belum ada hasil panen untuk dijual",
		BackgroundColor3 = if total > 0 then COLORS.accent else COLORS.locked,
	})
	sell.Parent = sellRow
	sell.Activated:Connect(function()
		call(Net.Names.FarmSell)
	end)
end

local function buildPlant(view: FarmView)
	titleLabel.Text = "Tanam di Petak " .. plantIndex
	local any = false
	for order, crop in FarmConfig.CROPS do
		local seeds = view.seeds[crop.id] or 0
		if seeds > 0 then
			any = true
			local r = row(52, order)
			r.BackgroundTransparency = 1
			local b = button({
				Size = UDim2.new(1, 0, 0, 46),
				Text = `{crop.icon} {crop.name}  (bibit: {seeds}, tumbuh {Format.duration(
					crop.growSeconds
				)})`,
			})
			b.Parent = r
			b.Activated:Connect(function()
				if call(Net.Names.FarmPlant, plantIndex, crop.id) then
					panel.Visible = false
				end
			end)
		end
	end
	if not any then
		local r = row(60, 1)
		r.BackgroundTransparency = 1
		label({
			Size = UDim2.fromScale(1, 1),
			Text = "Kamu belum punya bibit. Beli dulu di Toko Bibit di dekat kebun.",
		}).Parent =
			r
	end
end

function refreshPanel()
	if not panel.Visible then
		return
	end
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if mode == "plant" then
		buildPlant(getView())
	else
		buildMarket(getView())
	end
end

local function open(newMode: string)
	mode = newMode
	panel.Visible = true
	refreshPanel()
end

local function onPlotPrompt(index: number)
	local view = getView()
	local plot = view.plots[tostring(index)]
	local crop = if plot then FarmConfig.crop(plot.crop) else nil
	if plot == nil or crop == nil then
		plantIndex = index
		open("plant")
	elseif FarmConfig.growth(plot, Workspace:GetServerTimeNow()) >= 1 then
		call(Net.Names.FarmHarvest, index)
	else
		local left = crop.growSeconds - (Workspace:GetServerTimeNow() - plot.plantedAt)
		HudController.toast(
			`{crop.icon} {crop.name} sedang tumbuh. Siap panen dalam {Format.duration(
				math.ceil(left)
			)}.`
		)
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "FarmMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 440)
	panel.BackgroundColor3 = COLORS.panel
	panel.Visible = false
	corner(panel, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.accent
	stroke.Parent = panel
	scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	titleLabel = label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		Text = "Pasar Tani",
	})
	titleLabel.Parent = panel
	local close = button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = COLORS.close,
		TextSize = 20,
		Text = "X",
	})
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(16, 54)
	body.Size = UDim2.new(1, -28, 1, -66)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	body.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 500, size.Y / 480), 0.55, 1)
	end
end

function FarmController.init()
	buildGui()
	folder = Instance.new("Folder")
	folder.Name = "FarmLocal"
	folder.Parent = Workspace
end

function FarmController.start()
	player:GetAttributeChangedSignal(FarmConfig.ATTR_PLAYER):Connect(function()
		refreshPlots()
		refreshPanel()
	end)
	player:GetAttributeChangedSignal("Money"):Connect(refreshPanel)
	-- Petak yang baru ter-stream digambar saat muncul.
	CollectionService:GetInstanceAddedSignal(FarmConfig.TAG_PLOT):Connect(function()
		table.clear(drawn)
		task.defer(refreshPlots)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local part = prompt.Parent
		if part == nil or prompt.Name ~= "FarmPrompt" then
			return
		end
		if CollectionService:HasTag(part, FarmConfig.TAG_MARKET) then
			local name = part:GetAttribute("MarketName")
			marketName = if type(name) == "string" then name else "Pasar Tani"
			open("market")
		elseif CollectionService:HasTag(part, FarmConfig.TAG_PLOT) then
			local index = part:GetAttribute(FarmConfig.ATTR_PLOT_INDEX)
			if type(index) == "number" then
				onPlotPrompt(index)
			end
		end
	end)

	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	while true do
		refreshPlots()
		task.wait(REFRESH_SECONDS)
	end
end

return FarmController
