-- SchoolLib: helper pembangun interior sekolah (dipakai saat edit-time lewat execute_luau)
local L = {}
local rgb = Color3.fromRGB
L.rgb = rgb
local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass
local CS = game:GetService("CollectionService")

function L.box(parent, name, x0, y0, z0, x1, y1, z1, color, mat, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(math.max(math.abs(x1 - x0), 0.02), math.max(math.abs(y1 - y0), 0.02), math.max(math.abs(z1 - z0), 0.02))
	p.Position = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color or rgb(255, 255, 255)
	p.Material = mat or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		for k, v in pairs(opts) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- bagian lokal: base = CFrame dasar; off = Vector3 (posisi lokal) atau CFrame
function L.lp(parent, base, name, size, off, color, mat, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	if typeof(off) == "Vector3" then
		p.CFrame = base * CFrame.new(off)
	else
		p.CFrame = base * off
	end
	p.Color = color or rgb(255, 255, 255)
	p.Material = mat or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		for k, v in pairs(opts) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

function L.ball(parent, base, name, diameter, off, color, mat)
	local p = L.lp(parent, base, name, Vector3.new(diameter, diameter, diameter), off, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

function L.invisible(p)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
end

-- Tembok lurus dengan lubang (pintu/jendela). axis "x": memanjang sepanjang x di z=fixed; axis "z": sepanjang z di x=fixed
function L.wall(parent, name, axis, fixed, a0, a1, y0, y1, t, color, mat, openings)
	openings = openings or {}
	table.sort(openings, function(p, q)
		return p.a0 < q.a0
	end)
	local function bx(s0, h0, s1, h1, f0, f1, c, m, o)
		if axis == "x" then
			return L.box(parent, name, s0, h0, fixed + f0, s1, h1, fixed + f1, c, m, o)
		else
			return L.box(parent, name, fixed + f0, h0, s0, fixed + f1, h1, s1, c, m, o)
		end
	end
	local function seg(s0, s1, h0, h1)
		if s1 - s0 < 0.02 or h1 - h0 < 0.02 then
			return
		end
		bx(s0, h0, s1, h1, -t / 2, t / 2, color, mat)
	end
	local cur = a0
	local white = rgb(250, 250, 248)
	for _, o in ipairs(openings) do
		seg(cur, o.a0, y0, y1)
		seg(o.a0, o.a1, y0, o.y0)
		seg(o.a0, o.a1, o.y1, y1)
		if o.glass then
			local mid = (o.a0 + o.a1) / 2
			bx(o.a0, o.y0, o.a1, o.y1, -0.06, 0.06, rgb(185, 222, 245), GLASS, { Transparency = 0.55 })
			bx(o.a0 - 0.25, o.y0 - 0.2, o.a1 + 0.25, o.y0 + 0.1, -t / 2 - 0.2, t / 2 + 0.2, white, SMOOTH)
			bx(o.a0 - 0.15, o.y1 - 0.1, o.a1 + 0.15, o.y1 + 0.15, -t / 2 - 0.08, t / 2 + 0.08, white, SMOOTH)
			bx(mid - 0.1, o.y0, mid + 0.1, o.y1, -t / 2 - 0.05, t / 2 + 0.05, white, SMOOTH)
			bx(o.a0, (o.y0 + o.y1) / 2 - 0.1, o.a1, (o.y0 + o.y1) / 2 + 0.1, -t / 2 - 0.05, t / 2 + 0.05, white, SMOOTH)
		end
		cur = o.a1
	end
	seg(cur, a1, y0, y1)
end

-- Pintu berengsel otomatis (tag AutoDoor, ShopDoorService). Dinding memanjang sepanjang x di z=fixed.
-- d = +1/-1 arah daun dari engsel sepanjang x; sOut = +1/-1 arah ayunan (sumbu z)
function L.door(parent, name, hingeX, y0, fixed, width, height, d, sOut, kind, radius)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Radius", radius or 9)
	CS:AddTag(model, "AutoDoor")
	local wood = rgb(120, 78, 46)
	local hinge = Instance.new("Part")
	hinge.Name = "Engsel"
	hinge.Size = Vector3.new(0.3, height, 0.3)
	hinge.Position = Vector3.new(hingeX, y0 + height / 2, fixed)
	hinge.Anchored = true
	hinge.CanCollide = false
	hinge.CanQuery = false
	hinge.Transparency = 1
	hinge:SetAttribute("OpenAngle", -90 * sOut * d)
	hinge.Parent = model
	local cx = hingeX + d * width / 2
	local function leaf(nm, size, pos, color, mat, collide, transp)
		local p = Instance.new("Part")
		p.Name = nm
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = mat
		p.Anchored = false
		p.CanCollide = collide
		p.CanQuery = collide
		p.Transparency = transp or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = hinge
		w.Part1 = p
		w.Parent = p
		return p
	end
	leaf("Daun", Vector3.new(width, height, 0.3), Vector3.new(cx, y0 + height / 2, fixed), wood, Enum.Material.Wood, true)
	if kind == "glass" then
		leaf("Kaca", Vector3.new(width - 0.9, height - 1.3, 0.36), Vector3.new(cx, y0 + height / 2 + 0.2, fixed), rgb(190, 228, 245), GLASS, false, 0.5)
	else
		leaf("Kaca", Vector3.new(1.4, 2.2, 0.36), Vector3.new(cx, y0 + height * 0.66, fixed), rgb(190, 228, 245), GLASS, false, 0.45)
	end
	leaf("Gagang", Vector3.new(0.12, 1.3, 0.5), Vector3.new(hingeX + d * (width - 0.45), y0 + height * 0.45, fixed), rgb(220, 220, 225), Enum.Material.Metal, false)
	model.Parent = parent
	return model
end

function L.sign(parent, name, cf, size, text, bg, fg, font, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = bg
	p.Material = mat or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	if text and text ~= "" then
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.Parent = p
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = text
		tl.TextColor3 = fg
		tl.TextScaled = true
		tl.Font = font or Enum.Font.FredokaOne
		tl.Parent = g
	end
	return p
end

function L.lamp(parent, x, y, z, w, d, bright)
	local p = L.box(parent, "Lampu", x - (w or 3.6) / 2, y - 0.15, z - (d or 1.5) / 2, x + (w or 3.6) / 2, y, z + (d or 1.5) / 2, rgb(255, 250, 225), Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	local l = Instance.new("PointLight")
	l.Range = 24
	l.Brightness = bright or 0.55
	l.Color = rgb(255, 244, 220)
	l.Shadows = false
	l.Parent = p
	return p
end

function L.plant(parent, x, fy, z, scale)
	scale = scale or 1
	local m = Instance.new("Model")
	m.Name = "Tanaman"
	local base = CFrame.new(x, fy, z)
	L.lp(m, base, "Pot", Vector3.new(1.3, 1.2, 1.3) * scale, Vector3.new(0, 0.6 * scale, 0), rgb(176, 96, 64), Enum.Material.Concrete)
	local b = L.ball(m, base, "Daun", 2.6 * scale, Vector3.new(0, 2.2 * scale, 0), rgb(70, 150, 70), Enum.Material.Grass)
	L.ball(m, base, "Daun2", 1.8 * scale, Vector3.new(0.5 * scale, 3.1 * scale, 0.2), rgb(90, 175, 80), Enum.Material.Grass)
	b.CanCollide = false
	m.Parent = parent
	return m
end

-- bangku/kursi siswa: menghadap +z lokal, kursi di z=-2
function L.studentSet(parent, base, rng)
	local m = Instance.new("Model")
	m.Name = "MejaSiswa"
	local woodT = rgb(214, 170, 110)
	local metal = rgb(96, 110, 124)
	L.lp(m, base, "PapanMeja", Vector3.new(3.2, 0.2, 2.0), Vector3.new(0, 2.6, 0), woodT, Enum.Material.WoodPlanks)
	L.lp(m, base, "KakiMeja", Vector3.new(0.2, 2.5, 1.7), Vector3.new(-1.4, 1.25, 0), metal, Enum.Material.Metal)
	L.lp(m, base, "KakiMeja", Vector3.new(0.2, 2.5, 1.7), Vector3.new(1.4, 1.25, 0), metal, Enum.Material.Metal)
	local cols = { rgb(220, 70, 70), rgb(70, 130, 220), rgb(80, 180, 100), rgb(240, 190, 60), rgb(170, 100, 200) }
	local book = L.lp(m, base, "Buku", Vector3.new(0.9, 0.14, 0.7), CFrame.new(rng:NextNumber(-0.9, 0.9), 2.77, rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), cols[rng:NextInteger(1, #cols)])
	book.CanCollide = false
	L.lp(m, base, "DudukanKursi", Vector3.new(1.9, 0.22, 1.9), Vector3.new(0, 1.55, -2.1), rgb(70, 140, 220), SMOOTH)
	L.lp(m, base, "SandaranKursi", Vector3.new(1.9, 1.5, 0.18), Vector3.new(0, 2.45, -3.0), rgb(70, 140, 220), SMOOTH)
	L.lp(m, base, "KakiKursi", Vector3.new(0.18, 1.45, 1.6), Vector3.new(-0.8, 0.72, -2.1), metal, Enum.Material.Metal, { CanCollide = false })
	L.lp(m, base, "KakiKursi", Vector3.new(0.18, 1.45, 1.6), Vector3.new(0.8, 0.72, -2.1), metal, Enum.Material.Metal, { CanCollide = false })
	m.Parent = parent
	return m
end

-- meja kerja guru / kepala sekolah: pengguna duduk di sisi -z lokal menghadap +z. width = lebar meja
function L.deskSet(parent, base, width, withChair, tone)
	local m = Instance.new("Model")
	m.Name = "MejaGuru"
	local wood = tone or rgb(150, 100, 62)
	L.lp(m, base, "PapanMeja", Vector3.new(width, 0.25, 2.4), Vector3.new(0, 2.85, 0), wood, Enum.Material.Wood)
	L.lp(m, base, "PanelDepan", Vector3.new(width - 0.2, 2.6, 0.2), Vector3.new(0, 1.5, 1.0), wood, Enum.Material.Wood)
	L.lp(m, base, "LaciKiri", Vector3.new(1.3, 2.6, 2.1), Vector3.new(-width / 2 + 0.8, 1.5, 0), wood:Lerp(rgb(0, 0, 0), 0.12), Enum.Material.Wood)
	L.lp(m, base, "LaciKanan", Vector3.new(1.3, 2.6, 2.1), Vector3.new(width / 2 - 0.8, 1.5, 0), wood:Lerp(rgb(0, 0, 0), 0.12), Enum.Material.Wood)
	if withChair then
		local c = rgb(60, 70, 95)
		L.lp(m, base, "DudukanKursi", Vector3.new(2.1, 0.3, 2.1), Vector3.new(0, 1.85, -2.5), c, SMOOTH)
		L.lp(m, base, "SandaranKursi", Vector3.new(2.1, 2.2, 0.25), Vector3.new(0, 3.1, -3.5), c, SMOOTH)
		L.lp(m, base, "TiangKursi", Vector3.new(0.4, 1.7, 0.4), Vector3.new(0, 0.85, -2.5), rgb(60, 60, 64), Enum.Material.Metal, { CanCollide = false })
		L.lp(m, base, "AlasKursi", Vector3.new(1.8, 0.2, 1.8), Vector3.new(0, 0.1, -2.5), rgb(60, 60, 64), Enum.Material.Metal, { CanCollide = false })
	end
	m.Parent = parent
	return m
end

function L.bookshelf(parent, base, width, height, rng)
	local m = Instance.new("Model")
	m.Name = "RakBuku"
	local wood = rgb(140, 92, 56)
	local depth = 1.4
	L.lp(m, base, "Belakang", Vector3.new(width, height, 0.15), Vector3.new(0, height / 2, -depth / 2 + 0.07), wood, Enum.Material.Wood)
	L.lp(m, base, "SisiKiri", Vector3.new(0.2, height, depth), Vector3.new(-width / 2 + 0.1, height / 2, 0), wood, Enum.Material.Wood)
	L.lp(m, base, "SisiKanan", Vector3.new(0.2, height, depth), Vector3.new(width / 2 - 0.1, height / 2, 0), wood, Enum.Material.Wood)
	local shelves = math.floor(height / 1.7)
	local cols = { rgb(210, 70, 70), rgb(70, 120, 210), rgb(80, 170, 100), rgb(240, 190, 60), rgb(160, 100, 200), rgb(240, 130, 60), rgb(250, 250, 245) }
	for i = 0, shelves do
		local y = 0.15 + i * ((height - 0.3) / shelves)
		L.lp(m, base, "Rak", Vector3.new(width - 0.2, 0.2, depth), Vector3.new(0, y, 0), wood, Enum.Material.Wood)
		if i < shelves then
			local x = -width / 2 + 0.5
			while x < width / 2 - 0.7 do
				local w = rng:NextNumber(0.25, 0.5)
				local h = rng:NextNumber(0.9, 1.3)
				L.lp(m, base, "Buku", Vector3.new(w, h, 0.9), Vector3.new(x + w / 2, y + 0.1 + h / 2, 0.05), cols[rng:NextInteger(1, #cols)], SMOOTH, { CanCollide = false })
				x += w + 0.04
			end
		end
	end
	m.Parent = parent
	return m
end

function L.locker(parent, base, color)
	local p = L.lp(parent, base, "Loker", Vector3.new(1.4, 5.6, 1.2), Vector3.new(0, 2.8, 0), color, Enum.Material.Metal)
	L.lp(parent, base, "LokerGagang", Vector3.new(0.12, 0.7, 0.1), Vector3.new(0.4, 3.4, 0.62), rgb(235, 235, 240), Enum.Material.Metal, { CanCollide = false })
	L.lp(parent, base, "LokerCelah", Vector3.new(0.9, 0.1, 0.06), Vector3.new(0, 4.6, 0.62), color:Lerp(rgb(0, 0, 0), 0.4), SMOOTH, { CanCollide = false })
	return p
end

function L.sofa(parent, base, width, color)
	local m = Instance.new("Model")
	m.Name = "Sofa"
	L.lp(m, base, "Dudukan", Vector3.new(width, 1.2, 2.6), Vector3.new(0, 1.0, 0), color, SMOOTH)
	L.lp(m, base, "Sandaran", Vector3.new(width, 2.0, 0.8), Vector3.new(0, 2.2, -1.0), color, SMOOTH)
	L.lp(m, base, "LenganKiri", Vector3.new(0.8, 1.8, 2.6), Vector3.new(-width / 2 + 0.4, 1.6, 0), color:Lerp(rgb(0, 0, 0), 0.1), SMOOTH)
	L.lp(m, base, "LenganKanan", Vector3.new(0.8, 1.8, 2.6), Vector3.new(width / 2 - 0.4, 1.6, 0), color:Lerp(rgb(0, 0, 0), 0.1), SMOOTH)
	m.Parent = parent
	return m
end

function L.marker(parent, cf, attrs)
	local p = Instance.new("Part")
	p.Name = "TitikNPC"
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	for k, v in pairs(attrs) do
		p:SetAttribute(k, v)
	end
	CS:AddTag(p, "SchoolNpc")
	p.Parent = parent
	return p
end

return L
