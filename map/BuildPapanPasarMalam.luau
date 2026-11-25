--!strict
-- BuildPapanPasarMalam: papan penanda PERMANEN di lokasi Pasar Malam (Taman Kota, tengah lorong lapak).
-- Lapak pasar hanya dipasang FoodService jam 17.30-02.00, jadi siang hari lahannya tampak kosong; papan ini
-- memberi tahu pemain bahwa tempatnya benar dan kapan bukanya. Workspace.Map.PapanPasarMalam, aman dijalankan ulang.
-- Pakai: require(ServerStorage.MapBuilders.BuildPapanPasarMalam)()

local Workspace = game:GetService("Workspace")

local CENTER = Vector3.new(682, 0.02, 122) -- lorong antara dua baris lapak (z 108 dan 136), bebas dari pohon
local W, H, LEG = 12, 5.5, 3.2

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function face(board: Part, normal: Enum.NormalId)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Muka"
	sg.Face = normal
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(960, 440)
	sg.LightInfluence = 0
	sg.Parent = board
	local function label(text: string, y: number, h: number, size: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.fromOffset(960, h)
		l.Text = text
		l.TextSize = size
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = color
		l.Parent = sg
	end
	label("🏮 PASAR MALAM 🏮", 24, 110, 96, Color3.fromRGB(255, 205, 70))
	label("Jajanan, permainan, dan lampu-lampu cantik", 150, 56, 38, Color3.fromRGB(235, 240, 255))
	label("Buka jam 17.30 – 02.00 (waktu dalam game)", 230, 64, 46, Color3.fromRGB(120, 215, 255))
	label("Akhir pekan: Festival Kuliner, jajanan diskon!", 330, 64, 34, Color3.fromRGB(255, 160, 110))
end

local function build()
	local map = Workspace:WaitForChild("Map")
	local old = map:FindFirstChild("PapanPasarMalam")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "PapanPasarMalam"
	local frame = CFrame.new(CENTER)
	local wood = Color3.fromRGB(96, 66, 44)
	for _, x in { -W / 2 - 0.9, W / 2 + 0.9 } do
		part(model, "Tiang", Vector3.new(1.2, LEG + H, 1.2), frame * CFrame.new(x, (LEG + H) / 2, 0), wood, Enum.Material.Wood)
	end
	local board = part(
		model,
		"Papan",
		Vector3.new(W, H, 0.6),
		frame * CFrame.new(0, LEG + H / 2, 0),
		Color3.fromRGB(28, 20, 56),
		Enum.Material.SmoothPlastic
	)
	part(model, "Bingkai", Vector3.new(W + 0.8, H + 0.8, 0.4), frame * CFrame.new(0, LEG + H / 2, 0), Color3.fromRGB(255, 120, 60), Enum.Material.SmoothPlastic)
	face(board, Enum.NormalId.Front)
	face(board, Enum.NormalId.Back)
	model.Parent = map
	return model
end

return build
