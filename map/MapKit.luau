--[[
	MapKit: alat bersama untuk skrip pembangun peta di folder map/.
	Semua part dibuat Anchored. Hiasan kecil (deco) tanpa tabrakan & bayangan supaya ringan di HP.
]]

local Kit = {}

Kit.ROAD_TOP = 0.4

Kit.C = {
	grass = Color3.fromRGB(106, 170, 76),
	asphalt = Color3.fromRGB(58, 60, 66),
	walk = Color3.fromRGB(196, 196, 190),
	yellow = Color3.fromRGB(245, 200, 40),
	white = Color3.fromRGB(240, 240, 240),
	glass = Color3.fromRGB(150, 205, 235),
	door = Color3.fromRGB(110, 75, 50),
	trunk = Color3.fromRGB(110, 78, 52),
	metal = Color3.fromRGB(70, 75, 85),
}

function Kit.P(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

function Kit.deco(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	props.CastShadow = false
	return Kit.P(props)
end

function Kit.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Ambil (atau buat) Workspace.Map, hapus zona lama dengan nama ini, kembalikan folder zona baru
-- yang BELUM di-parent (parent-kan sedikit demi sedikit lewat Kit.flush).
function Kit.zone(name: string): (Folder, Folder)
	local map = workspace:FindFirstChild("Map")
	if not map then
		map = Kit.folder("Map", workspace)
	end
	local old = map:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local z = Kit.folder(name, map)
	return z, map
end

function Kit.flush(f: Instance, parent: Instance)
	f.Parent = parent
	task.wait()
end

function Kit.sign(part: BasePart, text: string, textColor: Color3?, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or Kit.C.white
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

--------------------------------------------------------------------------
-- Jalan
--------------------------------------------------------------------------

-- Titik-titik persegi panjang bersudut bulat (searah jarum jam), untuk jalan lingkar.
function Kit.roundedRect(
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	r: number,
	steps: number
): { Vector2 }
	local pts = {}
	local corners = {
		{ x1 - r, z0 + r, -math.pi / 2 },
		{ x1 - r, z1 - r, 0 },
		{ x0 + r, z1 - r, math.pi / 2 },
		{ x0 + r, z0 + r, math.pi },
	}
	for _, c in corners do
		for s = 0, steps do
			local a = c[3] + (s / steps) * (math.pi / 2)
			table.insert(pts, Vector2.new(c[1] + math.cos(a) * r, c[2] + math.sin(a) * r))
		end
	end
	return pts
end

export type RoadOpts = {
	width: number?,
	lanes: number?, -- 2 atau 4
	closed: boolean?,
	parent: Instance,
	name: string?,
	top: number?,
	color: Color3?,
}

-- Jalan aspal mengikuti polyline (Vector2 = X,Z). Sambungan ditutup piringan silinder.
function Kit.road(points: { Vector2 }, opt: RoadOpts): Folder
	local w = opt.width or 32
	local lanes = opt.lanes or 2
	local top = opt.top or Kit.ROAD_TOP
	local root = Kit.folder(opt.name or "Road", opt.parent)
	local marks = Kit.folder("Markings", root)
	local C = Kit.C
	local n = #points
	local last = if opt.closed then n else n - 1
	local my = top / 2 + 0.025

	for i = 1, last do
		local a, b = points[i], points[i % n + 1]
		local A, B = Vector3.new(a.X, 0, a.Y), Vector3.new(b.X, 0, b.Y)
		local d = B - A
		local L = d.Magnitude
		local pieces = math.max(1, math.ceil(L / 400))
		for k = 0, pieces - 1 do
			local pa, pb = A + d * (k / pieces), A + d * ((k + 1) / pieces)
			local l = L / pieces
			local cf = CFrame.lookAt(
				(pa + pb) / 2 + Vector3.new(0, top / 2, 0),
				pb + Vector3.new(0, top / 2, 0)
			)
			Kit.P({
				Name = "Segment",
				Size = Vector3.new(w, top, l),
				CFrame = cf,
				Color = opt.color or C.asphalt,
				Material = Enum.Material.Asphalt,
				Parent = root,
			})

			local function line(x: number, len: number, zc: number, thick: number, color: Color3)
				Kit.deco({
					Name = "Line",
					Size = Vector3.new(thick, 0.05, len),
					CFrame = cf * CFrame.new(x, my, zc),
					Color = color,
					Parent = marks,
				})
			end
			for _, s in { -1, 1 } do
				line(s * (w / 2 - 1.5), l, 0, 0.5, C.white)
			end
			local function dashes(x: number, color: Color3)
				local t = -l / 2 + 3
				while t + 10 <= l / 2 do
					line(x, 10, t + 5, 0.5, color)
					t += 30
				end
			end
			if lanes >= 4 then
				line(-0.5, l, 0, 0.35, C.yellow)
				line(0.5, l, 0, 0.35, C.yellow)
				dashes(-w / 4, C.white)
				dashes(w / 4, C.white)
			else
				dashes(0, C.yellow)
			end
		end
	end

	-- piringan penutup celah di tikungan (sedikit lebih rendah agar tidak berkedip)
	local first = if opt.closed then 1 else 2
	for i = first, if opt.closed then n else n - 1 do
		local p = points[i]
		local h = top - 0.05
		Kit.P({
			Name = "Joint",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, w, w),
			CFrame = CFrame.new(p.X, h / 2, p.Y) * CFrame.Angles(0, 0, math.pi / 2),
			Color = opt.color or C.asphalt,
			Material = Enum.Material.Asphalt,
			Parent = root,
		})
	end
	return root
end

-- Titik-titik di sepanjang polyline setiap `spacing` stud, digeser `across` ke kanan arah jalan.
function Kit.along(
	points: { Vector2 },
	closed: boolean,
	spacing: number,
	across: number
): { { pos: Vector3, yaw: number } }
	local out = {}
	local n = #points
	local carry = spacing / 2
	for i = 1, if closed then n else n - 1 do
		local a, b = points[i], points[i % n + 1]
		local d = b - a
		local L = d.Magnitude
		if L > 0 then
			local dir = d / L
			local right = Vector2.new(-dir.Y, dir.X)
			local t = carry
			while t <= L do
				local p = a + dir * t + right * across
				-- yaw supaya lokal -Z menghadap ke tengah jalan
				local toRoad = if across >= 0 then -right else right
				table.insert(
					out,
					{ pos = Vector3.new(p.X, 0, p.Y), yaw = math.atan2(-toRoad.X, -toRoad.Y) }
				)
				t += spacing
			end
			carry = t - L
		end
	end
	return out
end

--------------------------------------------------------------------------
-- Properti
--------------------------------------------------------------------------

local LEAVES = {
	Color3.fromRGB(70, 150, 60),
	Color3.fromRGB(90, 165, 70),
	Color3.fromRGB(60, 135, 75),
	Color3.fromRGB(110, 175, 60),
}

function Kit.rnd(i: number): number
	return (math.sin(i * 12.9898 + 78.233) * 43758.5453) % 1
end

-- kind: "round" (pohon bulat), "palm", "pine"
function Kit.tree(pos: Vector3, scale: number, parent: Instance, kind: string?, seed: number?)
	local m = Kit.model("Pohon", nil)
	seed = seed or (pos.X * 0.37 + pos.Z * 0.71)
	local leaf = LEAVES[math.floor(Kit.rnd(seed) * #LEAVES) + 1]
	kind = kind or "round"
	if kind == "palm" then
		local th = 16 * scale
		local lean = (Kit.rnd(seed + 1) - 0.5) * 0.25
		local base = CFrame.new(pos)
			* CFrame.Angles(0, Kit.rnd(seed + 2) * 6.28, 0)
			* CFrame.Angles(lean, 0, 0)
		local trunk = Kit.P({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(th, 1.3 * scale, 1.3 * scale),
			CFrame = base * CFrame.new(0, th / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(150, 115, 75),
			Material = Enum.Material.Wood,
			Parent = m,
		})
		local crown = base * CFrame.new(0, th, 0)
		for f = 0, 4 do
			local cf = crown
				* CFrame.Angles(0, f * (math.pi * 2 / 5), 0)
				* CFrame.Angles(-0.35, 0, 0)
				* CFrame.new(0, 0, -3.5 * scale)
			Kit.deco({
				Name = "Frond",
				Size = Vector3.new(2.6 * scale, 0.4, 8 * scale),
				CFrame = cf,
				Color = Color3.fromRGB(60, 150, 70),
				Material = Enum.Material.Grass,
				Parent = m,
			})
		end
		m.PrimaryPart = trunk
	elseif kind == "pine" then
		-- cemara bergaya low-poly: batang + tiga tingkat silinder mengecil
		local th = 5 * scale
		local trunk = Kit.P({
			Name = "Trunk",
			Size = Vector3.new(1.4 * scale, th, 1.4 * scale),
			Position = pos + Vector3.new(0, th / 2, 0),
			Color = Kit.C.trunk,
			Material = Enum.Material.Wood,
			Parent = m,
		})
		local green = Color3.fromRGB(45, 115, 65):Lerp(leaf, 0.25)
		for lvl = 0, 2 do
			local d = (9 - lvl * 2.6) * scale
			local h = 3.2 * scale
			Kit.P({
				Name = "Needles",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(h, d, d),
				CFrame = CFrame.new(pos + Vector3.new(0, th + lvl * 3 * scale + h / 2, 0))
					* CFrame.Angles(0, 0, math.pi / 2),
				Color = green,
				Material = Enum.Material.Grass,
				CanCollide = lvl == 0,
				Parent = m,
			})
		end
		m.PrimaryPart = trunk
	else
		local th = 7 * scale
		local trunk = Kit.P({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(th, 1.4 * scale, 1.4 * scale),
			CFrame = CFrame.new(pos + Vector3.new(0, th / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Kit.C.trunk,
			Material = Enum.Material.Wood,
			Parent = m,
		})
		Kit.P({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 8 * scale,
			Position = pos + Vector3.new(0, th + 2.5 * scale, 0),
			Color = leaf,
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = m,
		})
		Kit.deco({
			Name = "LeavesTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 5.5 * scale,
			Position = pos + Vector3.new(0.6 * scale, th + 6 * scale, 0.4 * scale),
			Color = leaf:Lerp(Color3.new(1, 1, 0.6), 0.12),
			Material = Enum.Material.Grass,
			Parent = m,
		})
		m.PrimaryPart = trunk
	end
	m.Parent = parent
	return m
end

-- Lampu jalan; lengan (lokal -Z) menjorok ke arah yaw.
function Kit.streetLight(pos: Vector3, yaw: number, parent: Instance)
	local m = Kit.model("Lampu", nil)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local pole = Kit.P({
		Name = "Pole",
		Size = Vector3.new(0.6, 14, 0.6),
		CFrame = base * CFrame.new(0, 7, 0),
		Color = Kit.C.metal,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	Kit.deco({
		Name = "Arm",
		Size = Vector3.new(0.4, 0.4, 4),
		CFrame = base * CFrame.new(0, 13.8, -2),
		Color = Kit.C.metal,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local head = Kit.deco({
		Name = "Lamp",
		Size = Vector3.new(1.6, 0.6, 2),
		CFrame = base * CFrame.new(0, 13.4, -3.6),
		Color = Color3.fromRGB(255, 236, 180),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Shadows = false
	light.Parent = head
	m.PrimaryPart = pole
	m.Parent = parent
	return m
end

function Kit.bench(cf: CFrame, parent: Instance)
	local m = Kit.model("Bangku", nil)
	local wood = Color3.fromRGB(150, 100, 60)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(6, 0.5, 2)
	seat.CFrame = cf * CFrame.new(0, 1.8, 0)
	seat.Color = wood
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = m
	Kit.deco({
		Name = "Back",
		Size = Vector3.new(6, 2, 0.4),
		CFrame = cf * CFrame.new(0, 3, 0.9),
		Color = wood,
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for _, lx in { -2.5, 2.5 } do
		Kit.deco({
			Name = "Leg",
			Size = Vector3.new(0.4, 1.6, 1.8),
			CFrame = cf * CFrame.new(lx, 0.8, 0),
			Color = Kit.C.metal,
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	m.PrimaryPart = seat
	m.Parent = parent
	return m
end

function Kit.countParts(inst: Instance): number
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return Kit
