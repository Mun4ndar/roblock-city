--[[
	ROBLOCK CITY: penyambung jalan (jalankan setelah semua pembangun jalan; aman diulang).

	Menutup celah dan ujung buntu yang ditemukan lewat audit ujung jalan:
	  LINKS : ruas aspal penyambung di antara dua jalan yang tidak bertemu (bisa dengan jembatan)
	  ENDS  : ujung jalan yang memang berakhir di situ diberi bundaran putar balik, supaya tidak
	          terlihat seperti jalan terputus
	Hasil: Workspace.Map.RoadFixes (dibuat ulang setiap dijalankan).

	Pakai: require(game.ServerStorage.MapBuilders.FixRoads)()
]]

local ROAD_TOP = 0.4
local ASPHALT = Color3.fromRGB(58, 60, 66)
local WHITE = Color3.fromRGB(245, 245, 245)
local CONCRETE = Color3.fromRGB(190, 190, 195)

-- from/to = titik tengah jalan (x, z); width = lebar; bridge = { x0, x1 } rentang jembatan (opsional)
local LINKS = {
	-- jalan masuk Pulau Pantai berhenti 8 stud sebelum Jalan Pantai
	{ name = "SambungPantai", from = Vector2.new(1794, 0), to = Vector2.new(1806, 0), width = 48 },
	-- jalan terminal bandara berhenti 12 stud sebelum jalan raya ke bandara
	{
		name = "SambungBandara",
		from = Vector2.new(-716, 862),
		to = Vector2.new(-696, 858),
		width = 30,
	},
	-- jalan desa berakhir di rumput dekat Pasar Tani: sambung ke jalan lingkar lewat jembatan sungai
	{
		name = "JalanPasarTani",
		from = Vector2.new(-742, 300),
		to = Vector2.new(-502, 300),
		width = 28,
		bridge = { -652, -594 },
	},
}

-- pos = ujung jalan (x, z); width = lebar jalan
local ENDS = {
	{ pos = Vector2.new(300, 330), width = 32 },
	-- (ujung barat kota kecil berakhir di sekolah dan dealer mobil, jadi tidak diberi bundaran)
	{ pos = Vector2.new(300, 570), width = 32 },
	{ pos = Vector2.new(-20, 250), width = 32 },
	{ pos = Vector2.new(220, 250), width = 32 },
	{ pos = Vector2.new(-20, 650), width = 32 },
	{ pos = Vector2.new(220, 650), width = 32 },
	-- (ujung selatan Jalan Pantai berakhir di Terminal Feri, jadi tidak perlu bundaran)
	{ pos = Vector2.new(1820, -380), width = 32 },
	{ pos = Vector2.new(-1150, 620), width = 28 },
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end

return function(): number
	local map = workspace:FindFirstChild("Map")
	if not map then
		return 0
	end
	local old = map:FindFirstChild("RoadFixes")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "RoadFixes"
	local sample = map:FindFirstChild("Simpang", true)
	local color = if sample and sample:IsA("BasePart") then sample.Color else ASPHALT

	for _, link in LINKS do
		local a = Vector3.new(link.from.X, ROAD_TOP - 0.2, link.from.Y)
		local b = Vector3.new(link.to.X, ROAD_TOP - 0.2, link.to.Y)
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		part(
			root,
			link.name,
			Vector3.new(link.width, 0.4, length),
			cf,
			color,
			Enum.Material.Asphalt
		)
		if length > 40 then
			-- garis tengah putus-putus dan garis tepi
			for d = 6, length - 6, 14 do
				part(
					root,
					"GarisTengah",
					Vector3.new(0.6, 0.05, 6),
					cf * CFrame.new(0, 0.21, -length / 2 + d),
					Color3.fromRGB(250, 210, 60),
					Enum.Material.SmoothPlastic
				).CanCollide =
					false
			end
			for _, sx in { -1, 1 } do
				part(
					root,
					"GarisTepi",
					Vector3.new(0.6, 0.05, length),
					cf * CFrame.new(sx * (link.width / 2 - 1), 0.21, 0),
					WHITE,
					Enum.Material.SmoothPlastic
				).CanCollide =
					false
			end
			-- potong tanah yang menonjol di atas jalan baru
			workspace.Terrain:FillBlock(
				cf * CFrame.new(0, 12.2, 0),
				Vector3.new(link.width + 20, 24, length),
				Enum.Material.Air
			)
		end
		local bridge = (link :: any).bridge
		if bridge then
			local x0, x1 = bridge[1], bridge[2]
			local mid = Vector3.new((x0 + x1) / 2, 0, link.from.Y)
			local span = math.abs(x1 - x0)
			part(
				root,
				"DekJembatan",
				Vector3.new(span, 2, link.width + 6),
				CFrame.new(mid + Vector3.new(0, -1, 0)),
				CONCRETE,
				Enum.Material.Concrete
			)
			for _, sz in { -1, 1 } do
				local z = link.from.Y + sz * (link.width / 2 + 2)
				part(
					root,
					"PagarJembatan",
					Vector3.new(span, 0.5, 0.5),
					CFrame.new(mid.X, 3.2, z),
					WHITE,
					Enum.Material.Metal
				)
				part(
					root,
					"PagarJembatan",
					Vector3.new(span, 0.4, 0.4),
					CFrame.new(mid.X, 1.8, z),
					WHITE,
					Enum.Material.Metal
				)
				for x = x0, x1, 8 do
					part(
						root,
						"TiangPagar",
						Vector3.new(0.6, 3.4, 0.6),
						CFrame.new(x, 1.7, z),
						WHITE,
						Enum.Material.Metal
					)
				end
				for _, x in { x0 + 6, x1 - 6 } do
					part(
						root,
						"TiangJembatan",
						Vector3.new(3, 8, 3),
						CFrame.new(x, -5, z - sz * 4),
						CONCRETE,
						Enum.Material.Concrete
					)
				end
			end
		end
	end

	for index, dead in ENDS do
		local disc = part(
			root,
			"PutarBalik" .. index,
			Vector3.new(0.4, dead.width * 1.7, dead.width * 1.7),
			CFrame.new(dead.pos.X, ROAD_TOP - 0.2, dead.pos.Y) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.Material.Asphalt
		)
		disc.Shape = Enum.PartType.Cylinder
		local island = part(
			root,
			"PulauPutar",
			Vector3.new(0.5, dead.width * 0.5, dead.width * 0.5),
			CFrame.new(dead.pos.X, ROAD_TOP + 0.05, dead.pos.Y) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(110, 180, 90),
			Enum.Material.Grass
		)
		island.Shape = Enum.PartType.Cylinder
		workspace.Terrain:FillBlock(
			CFrame.new(dead.pos.X, 12.4, dead.pos.Y),
			Vector3.new(dead.width * 1.8, 24, dead.width * 1.8),
			Enum.Material.Air
		)
	end

	root.Parent = map
	return #root:GetChildren()
end
