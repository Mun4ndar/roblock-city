--!strict
-- BuildPapanInfo: papan info besar di taman tempat pemain muncul (Workspace.Map.PapanInfo).
-- Muka papan menampilkan gambar kecil dari atlas InfoBoardConfig; ProximityPrompt (atribut InfoBoard)
-- membuka panel daftar di client (InfoBoardController). Bisa dijalankan ulang: model lama diganti.
-- Pakai: require(ServerStorage.MapBuilders.BuildPapanInfo)()

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local function build()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))
	local Config = require(Shared:WaitForChild("InfoBoardConfig"))

	local map = Workspace:WaitForChild("Map")
	local old = map:FindFirstChild("PapanInfo")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "PapanInfo"

	local W, H = 26, 12 -- papan (lebar, tinggi)
	local legH = 6
	local base = Config.POSITION
	local facing = Config.FACING.Unit
	-- kerangka arah: -Z lokal menghadap pemain (Face Front terbaca dari depan)
	local frame = CFrame.lookAt(base, base + facing)
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end

	local wood = Color3.fromRGB(96, 66, 44)
	local navy = Color3.fromRGB(24, 32, 60)
	local yellow = Color3.fromRGB(255, 196, 40)

	-- tiang
	for _, x in { -W / 2 + 2, W / 2 - 2 } do
		part(model, "Tiang", Vector3.new(1.6, legH + H, 1.6), at(x, (legH + H) / 2, 0.6), wood, Enum.Material.Wood)
	end
	-- papan
	local board = part(model, "Papan", Vector3.new(W, H, 1), at(0, legH + H / 2, 0), navy, Enum.Material.SmoothPlastic)
	board:SetAttribute("InfoBoard", true)
	CollectionService:AddTag(board, "InfoBoard")
	part(model, "Bingkai", Vector3.new(W + 1.2, H + 1.2, 0.6), at(0, legH + H / 2, 0.3), yellow, Enum.Material.SmoothPlastic)
	part(model, "Atap", Vector3.new(W + 3, 0.8, 3), at(0, legH + H + 1, -0.4), Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic)
	-- alas batu kecil di bawah supaya terlihat disengaja
	part(model, "Alas", Vector3.new(W + 2, 0.4, 6), at(0, 0.2, 2.2), Color3.fromRGB(190, 184, 170), Enum.Material.Cobblestone)

	-- muka papan (SurfaceGui, tampil dari depan)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Muka"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(1040, 480)
	sg.LightInfluence = 0
	sg.Parent = board

	local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.Text = text
		l.TextSize = textSize
		l.TextColor3 = color
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = false
		l.Parent = parent
		return l
	end

	label(sg, "SELAMAT DATANG DI ROBLOCK CITY!", UDim2.fromOffset(0, 10), UDim2.fromOffset(1040, 56), 46, yellow)
	label(sg, "Ketuk satu tempat, GPS menuntunmu lewat jalan", UDim2.fromOffset(0, 62), UDim2.fromOffset(1040, 28), 24, Color3.fromRGB(190, 205, 240))

	-- galeri gambar kecil (yang ditandai featured, maksimal 8)
	local cell = Config.CELL
	local shown = 0
	for _, entry in Config.ENTRIES do
		if entry.featured and shown < 8 then
			local dest = DestinationConfig.get(entry.dest)
			if dest then
				local col, row = shown % 4, math.floor(shown / 4)
				local tile = Instance.new("ImageLabel")
				tile.Position = UDim2.fromOffset(22 + col * 256, 100 + row * 168)
				tile.Size = UDim2.fromOffset(244, 137)
				tile.BackgroundColor3 = DestinationConfig.zone(dest.zone).color
				tile.ScaleType = Enum.ScaleType.Crop
				if entry.cell ~= nil and Config.ATLAS_ID ~= "" then
					tile.Image = Config.ATLAS_ID
					tile.ImageRectSize = cell
					tile.ImageRectOffset =
						Vector2.new((entry.cell % Config.COLUMNS) * cell.X, math.floor(entry.cell / Config.COLUMNS) * cell.Y)
				end
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 12)
				corner.Parent = tile
				local strip = Instance.new("Frame")
				strip.AnchorPoint = Vector2.new(0, 1)
				strip.Position = UDim2.fromScale(0, 1)
				strip.Size = UDim2.new(1, 0, 0, 34)
				strip.BackgroundColor3 = Color3.new(0, 0, 0)
				strip.BackgroundTransparency = 0.35
				strip.BorderSizePixel = 0
				strip.Parent = tile
				local sc = Instance.new("UICorner")
				sc.CornerRadius = UDim.new(0, 12)
				sc.Parent = strip
				label(strip, dest.icon .. " " .. dest.name, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 22, Color3.new(1, 1, 1))
				if entry.enter then
					local badge = label(tile, " 🚪 Bisa masuk ", UDim2.fromOffset(8, 8), UDim2.fromOffset(0, 30), 20, Color3.new(1, 1, 1))
					badge.AutomaticSize = Enum.AutomaticSize.X
					badge.BackgroundTransparency = 0.1
					badge.BackgroundColor3 = Color3.fromRGB(64, 190, 100)
					local bc = Instance.new("UICorner")
					bc.CornerRadius = UDim.new(0, 15)
					bc.Parent = badge
				end
				tile.Parent = sg
				shown += 1
			end
		end
	end

	local footer = Instance.new("Frame")
	footer.Position = UDim2.fromOffset(180, 432)
	footer.Size = UDim2.fromOffset(680, 40)
	footer.BackgroundColor3 = Color3.fromRGB(46, 150, 255)
	footer.BorderSizePixel = 0
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 20)
	fc.Parent = footer
	footer.Parent = sg
	label(footer, "Tekan  E  untuk daftar lengkap semua tempat", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 26, Color3.new(1, 1, 1))

	-- tombol interaksi
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BukaPapan"
	prompt.ActionText = "Lihat Papan Info"
	prompt.ObjectText = "Peta Petualangan"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("InfoBoard", true)
	prompt.Parent = board

	model.Parent = map
	return model
end

return build
