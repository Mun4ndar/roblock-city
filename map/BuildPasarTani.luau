--[[
	ROBLOCK CITY: Pasar Tani yang diperbarui sesuai tanaman di ladang (FarmConfig.CROPS).
	Memakai kasir, tiang kasir, dan papan "PASAR TANI" yang sudah ada di Workspace.Map.Farm.PasarTani; lapak lama
	(bola oranye/merah) dibuang dan diganti sembilan lapak, satu per tanaman, berisi mesh realistis yang sama
	dengan yang ditanam (ReplicatedStorage.Assets.Tanaman). Lantai dilebarkan ke barat, dua baris lapak saling
	berhadapan dengan lorong di tengah. Aman dijalankan ulang.

	Pakai (Studio, mode Edit): require(game.ServerStorage.MapBuilders.BuildPasarTani)()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FLOOR_Y = 0.5 -- permukaan lantai pasar
local ROWS = {
	-- z baris, arah depan lapak (menghadap lorong tengah), posisi x tiap lapak
	{ z = 99.5, front = 1, xs = { -704, -696, -688, -680, -672, -648 } },
	{ z = 114, front = -1, xs = { -704, -696, -688 } },
}
-- skala tampilan produk di atas meja (bukan skala tanam di ladang)
local DISPLAY = {
	padi = { scale = 1.15, count = 6 },
	gandum = { scale = 0.8, count = 6 },
	jagung = { scale = 0.3, count = 6 },
	selada = { scale = 3.4, count = 6 },
	kubis = { scale = 2.8, count = 6 },
	bit = { scale = 1.7, count = 8 },
	kembangkol = { scale = 2.6, count = 6 },
	semangka = { scale = 2.5, count = 4 },
	labu = { scale = 2.3, count = 5 },
}
local AWNING = {
	Color3.fromRGB(205, 60, 55),
	Color3.fromRGB(60, 130, 210),
	Color3.fromRGB(70, 160, 80),
	Color3.fromRGB(235, 170, 40),
}

local function build()
	local pasar = workspace.Map.Farm:FindFirstChild("PasarTani")
	local FarmConfig = require(ReplicatedStorage.Shared.FarmConfig)
	local templates = ReplicatedStorage.Assets.Tanaman
	if pasar == nil then
		warn("[BuildPasarTani] Workspace.Map.Farm.PasarTani tidak ada")
		return 0
	end
	-- buang lapak lama; kasir, tiang kasir, papan, dan lantai dipertahankan
	local keep = { Kasir = true, TiangKasir = true, PapanPasar = true, LantaiPasar = true }
	for _, child in pasar:GetChildren() do
		if not keep[child.Name] and child.Name ~= "Lapak" then
			child:Destroy()
		end
	end
	local old = pasar:FindFirstChild("Lapak")
	if old then
		old:Destroy()
	end
	local floor = pasar.LantaiPasar
	floor.Size = Vector3.new(80, 0.4, 30)
	floor.Position = Vector3.new(-678, 0.3, 106)

	local root = Instance.new("Folder")
	root.Name = "Lapak"
	local wood = Color3.fromRGB(150, 104, 66)
	local darkWood = Color3.fromRGB(110, 78, 50)

	local function part(parent, name, size, cf, color, material, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide == true
		p.CastShadow = collide == true
		p.Parent = parent
		return p
	end

	local stallIndex = 0
	for _, row in ROWS do
		for _, x in row.xs do
			stallIndex += 1
			local crop = FarmConfig.CROPS[stallIndex]
			if crop == nil then
				break
			end
			-- bingkai lapak: depan = -Z lokal (menghadap lorong)
			local frame = CFrame.lookAt(Vector3.new(x, FLOOR_Y, row.z), Vector3.new(x, FLOOR_Y, row.z + row.front))
			local stall = Instance.new("Model")
			stall.Name = "Lapak_" .. crop.id
			part(stall, "Meja", Vector3.new(7, 3, 3.2), frame * CFrame.new(0, 1.5, 0), wood, Enum.Material.WoodPlanks, true)
			part(stall, "AlasProduk", Vector3.new(6.4, 0.4, 2.6), frame * CFrame.new(0, 3.2, 0), darkWood, Enum.Material.WoodPlanks, false)
			for _, sx in { -3.2, 3.2 } do
				part(stall, "TiangBelakang", Vector3.new(0.5, 8, 0.5), frame * CFrame.new(sx, 4, 1.5), darkWood, Enum.Material.WoodPlanks, false)
				part(stall, "TiangDepan", Vector3.new(0.5, 7, 0.5), frame * CFrame.new(sx, 3.5, -1.6), darkWood, Enum.Material.WoodPlanks, false)
			end
			for i = 0, 3 do
				part(
					stall,
					"Atap",
					Vector3.new(1.95, 0.3, 5.2),
					frame * CFrame.new(-2.925 + i * 1.95, 7.9, 0) * CFrame.Angles(math.rad(-10), 0, 0),
					if i % 2 == 0 then AWNING[(stallIndex - 1) % #AWNING + 1] else Color3.fromRGB(250, 250, 245),
					nil,
					false
				)
			end
			-- papan nama (SurfaceGui Front = ke arah lorong)
			local board = part(stall, "PapanNama", Vector3.new(5.6, 1.1, 0.15), frame * CFrame.new(0, 6.5, -2.05), Color3.fromRGB(250, 246, 232), Enum.Material.SmoothPlastic, false)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.Parent = board
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = crop.name
			label.TextColor3 = Color3.fromRGB(60, 90, 40)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Parent = gui
			-- produk mesh yang sama dengan di ladang
			local template = templates:FindFirstChild(crop.model or crop.id)
			local display = DISPLAY[crop.id] or { scale = 1.5, count = 6 }
			if template then
				local columns = 3
				for n = 0, display.count - 1 do
					local item = template:Clone()
					item:ScaleTo(display.scale)
					local height = item:GetExtentsSize().Y
					local cx = (n % columns - (columns - 1) / 2) * 1.9
					local cz = (math.floor(n / columns) - 0.5) * 1.2
					local jitter = Random.new(stallIndex * 31 + n)
					item:PivotTo(
						frame
							* CFrame.new(cx + jitter:NextNumber(-0.2, 0.2), 3.4 + height / 2, cz)
							* CFrame.Angles(0, jitter:NextNumber(0, math.pi * 2), 0)
					)
					item.Parent = stall
				end
			end
			stall.Parent = root
		end
	end
	root.Parent = pasar
	return #root:GetDescendants()
end

return build
