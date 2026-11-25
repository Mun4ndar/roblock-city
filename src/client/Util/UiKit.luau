--!strict
-- UiKit: pembantu kecil untuk panel baru (warna, sudut membulat, label, tombol) supaya
-- gaya panel baru seragam dengan panel lain. Tidak mengubah tombol/panel yang sudah ada.

local UiKit = {}

local rgb = Color3.fromRGB
UiKit.COLORS = {
	panel = rgb(255, 255, 255),
	card = rgb(244, 246, 250),
	text = rgb(40, 48, 60),
	subtle = rgb(110, 120, 135),
	accent = rgb(70, 140, 230),
	go = rgb(64, 190, 100),
	warn = rgb(255, 184, 0),
	close = rgb(235, 90, 90),
	locked = rgb(200, 205, 214),
}

function UiKit.corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function UiKit.label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = UiKit.COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = 14
	l.TextWrapped = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

function UiKit.button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = UiKit.COLORS.accent
	for key, value in props do
		(b :: any)[key] = value
	end
	UiKit.corner(b, 10)
	b.Parent = parent
	return b
end

-- Panel modal tengah layar dengan judul dan tombol tutup. Mengembalikan (panel, isi).
function UiKit.modal(
	gui: ScreenGui,
	name: string,
	title: string,
	size: Vector2
): (Frame, ScrollingFrame)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	panel.BackgroundColor3 = UiKit.COLORS.panel
	panel.Visible = false
	UiKit.corner(panel, 16)
	panel.Parent = gui
	UiKit.label(panel, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 30),
		Text = title,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		Name = "Judul",
	})
	local close = UiKit.button(panel, {
		Name = "Tutup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(34, 30),
		Text = "✖",
		BackgroundColor3 = UiKit.COLORS.close,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Isi"
	body.Position = UDim2.fromOffset(12, 46)
	body.Size = UDim2.new(1, -24, 1, -58)
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
	return panel, body
end

function UiKit.clear(body: ScrollingFrame)
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return UiKit
