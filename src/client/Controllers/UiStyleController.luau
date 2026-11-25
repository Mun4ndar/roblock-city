--!strict
-- UiStyleController: satu tempat untuk gaya modern semua tombol dan menu HUD, supaya seragam dengan ikon HP
-- dan peta baru (gradien lembut, bingkai putih, sudut bulat, ikon dalam lingkaran).
--   * Tombol menu kiri (Kendaraan, Pekerjaan, Rumah): pil berwarna dengan lingkaran ikon
--   * Panel uang, Hadiah Harian, tombol Hewan: kapsul gradien emas / merah muda
--   * Semua panel menu (Kendaraan, Pekerjaan, Rumah, Hewan, Costume, Kebun, Kafe, Toko Koin, Modifikasi):
--     sudut lebih bulat, bingkai tebal berwarna sesuai tema, tombol di dalamnya bergradien (juga yang baru
--     dibuat saat daftar diisi ulang)
-- Dipasang sebagai lapisan hias di atas controller lain: tidak mengubah logika mereka.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local UiStyleController = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local SHINE = ColorSequence.new(rgb(255, 255, 255), rgb(206, 208, 222)) -- dikalikan warna dasar

-- gui -> warna tema panel
local MENU_THEMES: { [string]: Color3 } = {
	VehicleMenu = rgb(86, 142, 235),
	VehicleModMenu = rgb(86, 142, 235),
	JobMenu = rgb(240, 150, 40),
	HouseMenu = rgb(46, 170, 150),
	PetMenu = rgb(236, 110, 160),
	FashionMenu = rgb(150, 96, 240),
	FarmMenu = rgb(70, 180, 96),
	BusinessMenu = rgb(214, 140, 70),
	ShopMenu = rgb(244, 190, 40),
}

local function corner(parent: Instance, radius: number)
	local existing = parent:FindFirstChildOfClass("UICorner")
	local c: UICorner = if existing then existing else Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function gradient(parent: Instance, colors: ColorSequence, rotation: number)
	local existing = parent:FindFirstChildOfClass("UIGradient")
	local g: UIGradient = if existing then existing else Instance.new("UIGradient")
	g.Color = colors
	g.Rotation = rotation
	g.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number)
	local existing = parent:FindFirstChildOfClass("UIStroke")
	local s: UIStroke = if existing then existing else Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.Parent = parent
end

-- ---------------------------------------------------------------- tombol HUD

-- Pil menu: warna dasar tetap, ikon (emoji pertama di teks) pindah ke lingkaran di kiri.
local function stylePill(button: TextButton)
	if button:GetAttribute("Dihias") then
		return
	end
	button:SetAttribute("Dihias", true)
	local icon, name = string.match(button.Text, "^(%S+)%s+(.+)$")
	if icon == nil or name == nil then
		return
	end
	button.Text = name
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextSize = 17
	button.Size = UDim2.fromOffset(138, 44)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 46)
	pad.Parent = button
	corner(button, 22)
	gradient(button, SHINE, 90)
	stroke(button, WHITE, 3, 0.1)
	local chip = Instance.new("TextLabel")
	chip.Name = "Ikon"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.new(0, 5, 0.5, 0)
	chip.Size = UDim2.fromOffset(32, 32)
	chip.BackgroundColor3 = WHITE
	chip.BackgroundTransparency = 0.12
	chip.Font = Enum.Font.GothamMedium
	chip.TextSize = 19
	chip.Text = icon
	chip.ZIndex = button.ZIndex + 1
	corner(chip, 16)
	chip.Parent = button
	-- UIPadding ikut menggeser anak; samakan agar lingkaran tetap di tepi kiri
	chip.Position = UDim2.new(0, 5 - 46, 0.5, 0)
end

local function styleRound(button: TextButton, light: Color3)
	if button:GetAttribute("Dihias") then
		return
	end
	button:SetAttribute("Dihias", true)
	corner(button, 26)
	gradient(button, SHINE, 90)
	stroke(button, WHITE, 3, 0.1)
	button.TextStrokeTransparency = 1
	button.BackgroundColor3 = light
end

local function styleMoney(panel: Frame)
	if panel:GetAttribute("Dihias") then
		return
	end
	panel:SetAttribute("Dihias", true)
	panel.BackgroundColor3 = rgb(28, 34, 70)
	panel.BackgroundTransparency = 0.05
	corner(panel, 17)
	gradient(panel, ColorSequence.new(rgb(255, 255, 255), rgb(190, 196, 230)), 90)
	stroke(panel, rgb(255, 205, 70), 2.5, 0)
	local amount = panel:FindFirstChild("Amount") :: TextLabel?
	if amount then
		amount.Position = UDim2.fromOffset(38, 0)
		amount.Size = UDim2.new(1, -46, 1, 0)
		amount.TextColor3 = rgb(255, 214, 90)
	end
	local coin = Instance.new("TextLabel")
	coin.Name = "Koin"
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 5, 0.5, 0)
	coin.Size = UDim2.fromOffset(26, 26)
	coin.BackgroundColor3 = rgb(255, 196, 40)
	coin.Font = Enum.Font.FredokaOne
	coin.TextSize = 16
	coin.TextColor3 = rgb(120, 70, 0)
	coin.Text = "$"
	corner(coin, 13)
	stroke(coin, WHITE, 2, 0.2)
	coin.Parent = panel
end

local function styleReward(button: TextButton)
	if button:GetAttribute("Dihias") then
		return
	end
	button:SetAttribute("Dihias", true)
	corner(button, 14)
	gradient(button, SHINE, 90)
	stroke(button, WHITE, 2.5, 0.1)
	button.TextColor3 = rgb(90, 50, 0)
end

-- ---------------------------------------------------------------- panel menu

local function styleInnerButton(button: TextButton)
	if button:GetAttribute("Dihias") or button.BackgroundTransparency > 0.9 then
		return
	end
	button:SetAttribute("Dihias", true)
	if button:FindFirstChildOfClass("UIGradient") == nil then
		gradient(button, SHINE, 90)
	end
	local c = button:FindFirstChildOfClass("UICorner")
	if c == nil or c.CornerRadius.Offset < 10 then
		corner(button, 12)
	end
end

local function stylePanel(panel: Frame, theme: Color3)
	if panel:GetAttribute("Dihias") then
		return
	end
	panel:SetAttribute("Dihias", true)
	corner(panel, 26)
	gradient(panel, ColorSequence.new(rgb(255, 255, 255), rgb(234, 240, 255)), 90)
	stroke(panel, theme, 5, 0)
	for _, d in panel:GetDescendants() do
		if d:IsA("TextButton") then
			styleInnerButton(d)
		end
	end
	panel.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("TextButton") then
			task.defer(styleInnerButton, d)
		end
	end)
end

local function styleMenu(gui: ScreenGui, theme: Color3)
	local panel = gui:FindFirstChild("Panel")
	if panel and panel:IsA("Frame") then
		stylePanel(panel, theme)
	end
end

function UiStyleController.init() end

function UiStyleController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local function wait(gui: Instance, name: string): Instance?
		return gui:WaitForChild(name, 15)
	end
	local pills = {
		{ "VehicleMenu", "OpenVehicles" },
		{ "JobMenu", "OpenJobs" },
		{ "HouseMenu", "OpenHouse" },
	}
	for _, entry in pills do
		task.spawn(function()
			local gui = wait(playerGui, entry[1])
			local button = if gui then wait(gui, entry[2]) else nil
			if button and button:IsA("TextButton") then
				stylePill(button)
			end
		end)
	end
	task.spawn(function()
		local hud = wait(playerGui, "Hud")
		if hud == nil then
			return
		end
		local money = wait(hud, "MoneyPanel")
		local reward = wait(hud, "DailyReward")
		if money and money:IsA("Frame") then
			styleMoney(money)
		end
		if reward and reward:IsA("TextButton") then
			styleReward(reward)
		end
	end)
	task.spawn(function()
		local gui = wait(playerGui, "PetMenu")
		local paw = if gui then wait(gui, "OpenPets") else nil
		if paw and paw:IsA("TextButton") then
			styleRound(paw, rgb(255, 120, 170))
			paw.Size = UDim2.fromOffset(56, 56)
		end
	end)
	for name, theme in MENU_THEMES do
		task.spawn(function()
			local gui = wait(playerGui, name)
			if gui and gui:IsA("ScreenGui") then
				styleMenu(gui, theme)
			end
		end)
	end
end

return UiStyleController
