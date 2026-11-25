--!nonstrict
--[[
	KafeKit: alat bantu untuk membangun interior kafe (Cafe Startduck dan Kafe Kota).
	Semua posisi relatif terhadap `origin` (tengah lantai, y = permukaan lantai), sumbu dunia:
	+X timur, +Z depan bangunan (arah jalan), +Y atas. Kursi/sofa menghadap -Z lokal lalu diputar `yaw`.
]]
local CollectionService = game:GetService("CollectionService")
local Kit = {}
Kit.__index = Kit

local M = Enum.Material
local rgb = Color3.fromRGB
local PI = math.pi
local GLASS = rgb(190, 225, 235)

function Kit.new(parent, origin)
	return setmetatable({ root = parent, cur = parent, o = origin, lightScale = 1 }, Kit)
end

function Kit:group(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = self.root
	self.cur = f
	return f
end

-- yaw (radian) supaya objek yang menghadap -Z lokal menghadap dari titik a ke titik b (bidang XZ)
function Kit.yawTo(a, b)
	return math.atan2(-(b.X - a.X), -(b.Z - a.Z))
end

function Kit:box(name, size, pos, color, mat, o)
	o = o or {}
	local p = Instance.new(o.class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(self.o + pos) * (o.rot or CFrame.identity)
	p.Material = mat or M.SmoothPlastic
	p.Color = if p.Material == M.Neon or p.Material == M.Glass then color else color:Lerp(Color3.new(0, 0, 0), 1 - (self.tone or 1))
	if p:IsA("Part") then
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	if o.t then p.Transparency = o.t end
	if o.solid == false then p.CanCollide = false end
	if o.refl then p.Reflectance = o.refl end
	if o.shadow == false then p.CastShadow = false end
	p.Parent = o.parent or self.cur
	return p
end

function Kit:cyl(name, d, h, pos, color, mat, o)
	o = o or {}
	local p = self:box(name, Vector3.new(h, d, d), pos, color, mat, {
		rot = (o.rot or CFrame.identity) * CFrame.Angles(0, 0, PI / 2),
		t = o.t, solid = o.solid, refl = o.refl, shadow = o.shadow, parent = o.parent,
	})
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- silinder mendatar sepanjang sumbu X (atau Z bila alongZ)
function Kit:hcyl(name, d, len, pos, color, mat, o, alongZ)
	o = o or {}
	local p = self:box(name, Vector3.new(len, d, d), pos, color, mat, {
		rot = (o.rot or CFrame.identity) * (if alongZ then CFrame.Angles(0, PI / 2, 0) else CFrame.identity),
		t = o.t, solid = o.solid, refl = o.refl, shadow = o.shadow, parent = o.parent,
	})
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit:ball(name, size, pos, color, mat, o)
	local p = self:box(name, size, pos, color, mat, o)
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit:glass(name, size, pos, o)
	o = o or {}
	return self:box(name, size, pos, o.color or GLASS, M.Glass, {
		t = o.t or 0.5, solid = o.solid, rot = o.rot, shadow = false, parent = o.parent,
	})
end

function Kit:light(part, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness * (self.lightScale or 1)
	l.Range = range
	l.Shadows = false
	l.Parent = part
	return l
end

function Kit:label(part, face, text, color, font, px)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = px or 50
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = g
	g.Parent = part
	return l
end

-- Papan menu: judul + baris {name, price}. theme: bg, title, text, price, font, px, line
function Kit:menuBoard(part, face, title, rows, theme)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = theme.px or 60
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = theme.bg
	bg.BorderSizePixel = 0
	bg.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.05, 0), UDim.new(0.04, 0)
	pad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.17)
	t.BackgroundTransparency = 1
	t.Font = theme.titleFont or theme.font
	t.TextScaled = true
	t.TextColor3 = theme.title
	t.Text = title
	t.Parent = bg
	local line = Instance.new("Frame")
	line.Position = UDim2.fromScale(0, 0.19)
	line.Size = UDim2.new(1, 0, 0, 3)
	line.BackgroundColor3 = theme.line or theme.title
	line.BorderSizePixel = 0
	line.Parent = bg
	local rowH = 0.76 / math.max(#rows, 5)
	for i, r in ipairs(rows) do
		local y = 0.215 + (i - 1) * rowH
		local n = Instance.new("TextLabel")
		n.Position = UDim2.fromScale(0, y)
		n.Size = UDim2.fromScale(0.68, rowH * 0.92)
		n.BackgroundTransparency = 1
		n.Font = theme.font
		n.TextScaled = true
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.TextColor3 = theme.text
		n.Text = r[1]
		n.Parent = bg
		local pr = Instance.new("TextLabel")
		pr.Position = UDim2.fromScale(0.68, y)
		pr.Size = UDim2.fromScale(0.32, rowH * 0.92)
		pr.BackgroundTransparency = 1
		pr.Font = theme.font
		pr.TextScaled = true
		pr.TextXAlignment = Enum.TextXAlignment.Right
		pr.TextColor3 = theme.price
		pr.Text = r[2]
		pr.Parent = bg
	end
	g.Parent = part
end

-- Dinding lurus. axis "z": memanjang di sumbu Z pada x = c; axis "x": memanjang di sumbu X pada z = c.
-- openings: { a, b, y0, y1, door=true | frame=Color3, cols=n, rows=n, glassT }
function Kit:wall(name, axis, c, thick, a0, a1, y0, y1, color, mat, openings)
	local function seg(nm, u0, u1, ya, yb, col, m, th, o)
		th = th or thick
		ya, yb = math.max(ya, y0), math.min(yb, y1)
		if u1 - u0 < 0.02 or yb - ya < 0.02 then return nil end
		local size, pos
		if axis == "z" then
			size = Vector3.new(th, yb - ya, u1 - u0)
			pos = Vector3.new(c, (ya + yb) / 2, (u0 + u1) / 2)
		else
			size = Vector3.new(u1 - u0, yb - ya, th)
			pos = Vector3.new((u0 + u1) / 2, (ya + yb) / 2, c)
		end
		return self:box(nm, size, pos, col, m, o)
	end
	local list = openings or {}
	table.sort(list, function(p, q) return p.a < q.a end)
	local cursor = a0
	for _, op in ipairs(list) do
		seg(name, cursor, op.a, y0, y1, color, mat)
		if op.door then
			seg("Ambang", op.a, op.b, op.y1, y1, color, mat)
		elseif op.hole then
			seg("Sekat", op.a, op.b, y0, op.y0, color, mat)
			seg("Ambang", op.a, op.b, op.y1, y1, color, mat)
		else
			seg("Sekat", op.a, op.b, y0, op.y0, color, mat)
			seg("Ambang", op.a, op.b, op.y1, y1, color, mat)
			local fc = op.frame or rgb(60, 48, 40)
			seg("Kaca", op.a, op.b, op.y0, op.y1, GLASS, M.Glass, 0.12, { t = op.glassT or 0.5, shadow = false })
			-- bingkai tepi + sekat kaca
			local fw = 0.2
			seg("BingkaiBawah", op.a, op.b, op.y0, op.y0 + fw, fc, M.Metal, thick * 0.6)
			seg("BingkaiAtas", op.a, op.b, op.y1 - fw, op.y1, fc, M.Metal, thick * 0.6)
			seg("BingkaiKiri", op.a, op.a + fw, op.y0, op.y1, fc, M.Metal, thick * 0.6)
			seg("BingkaiKanan", op.b - fw, op.b, op.y0, op.y1, fc, M.Metal, thick * 0.6)
			local cols, rows = op.cols or 1, op.rows or 1
			for i = 1, cols - 1 do
				local u = op.a + (op.b - op.a) * i / cols
				seg("SekatTegak", u - 0.07, u + 0.07, op.y0, op.y1, fc, M.Metal, thick * 0.5)
			end
			for i = 1, rows - 1 do
				local v = op.y0 + (op.y1 - op.y0) * i / rows
				seg("SekatMendatar", op.a, op.b, v - 0.07, v + 0.07, fc, M.Metal, thick * 0.5)
			end
		end
		cursor = op.b
	end
	seg(name, cursor, a1, y0, y1, color, mat)
end

-- Potongan melengkung (sudut bulat bangunan). Sudut dalam derajat dari +X ke +Z. rOut = jari-jari luar,
-- tebal ke arah dalam.
function Kit:arc(name, cx, cz, rOut, thick, a0, a1, y0, y1, color, mat, n)
	n = n or 8
	local rm = rOut - thick / 2
	local step = (a1 - a0) / n
	local half = math.rad(step) / 2
	for i = 0, n - 1 do
		local am = math.rad(a0 + step * (i + 0.5))
		local len = 2 * rOut * math.tan(half) + 0.06
		self:box(name, Vector3.new(thick, y1 - y0, len),
			Vector3.new(cx + rm * math.cos(am), (y0 + y1) / 2, cz + rm * math.sin(am)),
			color, mat, { rot = CFrame.Angles(0, -am, 0) })
	end
end

-- Pelat persegi panjang bersudut bulat (setengah ukuran hx, hz) untuk lantai/langit-langit/lantai atas.
function Kit:roundSlab(name, hx, hz, r, y0, y1, color, mat, cx, cz)
	cx, cz = cx or 0, cz or 0
	local h = y1 - y0
	local cy = (y0 + y1) / 2
	self:box(name, Vector3.new(hx * 2, h, (hz - r) * 2), Vector3.new(cx, cy, cz), color, mat)
	self:box(name, Vector3.new((hx - r) * 2, h - 0.02, hz * 2), Vector3.new(cx, cy - 0.01, cz), color, mat)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			self:cyl(name, r * 2, h - 0.04, Vector3.new(cx + sx * (hx - r), cy - 0.02, cz + sz * (hz - r)), color, mat)
		end
	end
end

-- Pintu kaca ganda berengsel otomatis (ShopDoorService: tag AutoDoor). Menghadap +Z (daun membuka ke luar).
-- cx,cz = pusat bukaan pintu (z = bidang dinding), lebar w, tinggi h.
function Kit:doors(name, cx, cz, w, h, frameColor, glassT, radius)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Radius", radius or 11)
	m.Parent = self.root
	local leafW = w / 2
	for _, side in { -1, 1 } do
		local hx = cx + side * w / 2
		local hinge = self:box("Engsel" .. (if side < 0 then "Kiri" else "Kanan"),
			Vector3.new(0.3, h, 0.3), Vector3.new(hx, h / 2, cz), frameColor, M.Metal,
			{ t = 1, solid = false, parent = m, shadow = false })
		hinge:SetAttribute("OpenAngle", if side < 0 then -90 else 90)
		local mid = hx - side * leafW / 2
		local function piece(nm, size, off, col, mat, o)
			o = o or {}
			o.parent = m
			local p = self:box(nm, size, Vector3.new(mid + off.X, off.Y, cz + off.Z), col, mat, o)
			p.Anchored = false
			local wd = Instance.new("WeldConstraint")
			wd.Part0, wd.Part1 = hinge, p
			wd.Parent = p
			return p
		end
		local sw = 0.28
		piece("Daun", Vector3.new(leafW - 0.04, h - 0.1, 0.1), Vector3.new(0, h / 2, 0), GLASS, M.Glass,
			{ t = glassT or 0.5, solid = false, shadow = false })
		piece("TiangLuar", Vector3.new(sw, h - 0.1, 0.22), Vector3.new(side * (leafW / 2 - sw / 2), h / 2, 0), frameColor, M.Metal)
		piece("TiangDalam", Vector3.new(sw, h - 0.1, 0.22), Vector3.new(-side * (leafW / 2 - sw / 2), h / 2, 0), frameColor, M.Metal)
		piece("RelAtas", Vector3.new(leafW - 0.04, sw, 0.22), Vector3.new(0, h - 0.2, 0), frameColor, M.Metal)
		piece("RelBawah", Vector3.new(leafW - 0.04, 0.9, 0.22), Vector3.new(0, 0.5, 0), frameColor, M.Metal)
		local hn = piece("Gagang", Vector3.new(0.12, 1.8, 0.12), Vector3.new(-side * (leafW / 2 - 0.55), h / 2 - 0.2, 0.28),
			rgb(200, 204, 210), M.Metal, { solid = false })
		piece("GagangDalam", Vector3.new(0.12, 1.8, 0.12), Vector3.new(-side * (leafW / 2 - 0.55), h / 2 - 0.2, -0.28),
			rgb(200, 204, 210), M.Metal, { solid = false })
	end
	CollectionService:AddTag(m, "AutoDoor")
	return m
end

-- ---------------------------------------------------------------- perabot

local function newModel(self, name, pos)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = self.cur
	return m
end

-- Kursi kayu bersandaran; menghadap arah (-sin yaw, -cos yaw)
function Kit:chair(pos, yaw, wood, cushion)
	local m = newModel(self, "Kursi")
	local rot = CFrame.Angles(0, yaw, 0)
	local function pc(n, size, off, col, mt, o)
		o = o or {}
		o.rot, o.parent = rot, m
		return self:box(n, size, pos + rot:VectorToWorldSpace(off), col, mt, o)
	end
	for _, sx in { -0.68, 0.68 } do
		for _, sz in { -0.68, 0.68 } do
			pc("Kaki", Vector3.new(0.16, 1.5, 0.16), Vector3.new(sx, 0.75, sz), wood, M.Wood)
		end
	end
	pc("Dudukan", Vector3.new(1.75, 0.25, 1.75), Vector3.new(0, 1.62, 0), cushion, M.Fabric, { class = "Seat" })
	pc("Sandaran", Vector3.new(1.75, 1.7, 0.16), Vector3.new(0, 2.5, 0.8), wood, M.Wood)
	pc("BantalSandaran", Vector3.new(1.4, 1.1, 0.12), Vector3.new(0, 2.5, 0.68), cushion, M.Fabric, { solid = false })
	return m
end

function Kit:stool(pos, color, topColor, yaw)
	local m = newModel(self, "Bangku")
	local function pc(n, size, off, col, mt, o)
		o = o or {}
		o.parent = m
		return self:box(n, size, pos + off, col, mt, o)
	end
	for _, sx in { -0.5, 0.5 } do
		for _, sz in { -0.5, 0.5 } do
			pc("Kaki", Vector3.new(0.14, 2.3, 0.14), Vector3.new(sx, 1.15, sz), color, M.Metal)
		end
	end
	pc("Pijakan", Vector3.new(1.2, 0.1, 1.2), Vector3.new(0, 0.9, 0), color, M.Metal, { solid = false })
	pc("Dudukan", Vector3.new(1.45, 0.25, 1.45), Vector3.new(0, 2.4, 0), topColor, M.Leather, { class = "Seat", rot = CFrame.Angles(0, yaw or 0, 0) })
	return m
end

-- Sofa lebar w (kelipatan ~2.4 per orang); punggung di +Z lokal, menghadap -Z lokal diputar yaw
function Kit:sofa(pos, yaw, w, fabric, legColor, mat, depth)
	depth = depth or 2.4
	local m = newModel(self, "Sofa")
	local rot = CFrame.Angles(0, yaw, 0)
	local function pc(n, size, off, col, mt, o)
		o = o or {}
		o.rot, o.parent = rot, m
		return self:box(n, size, pos + rot:VectorToWorldSpace(off), col, mt, o)
	end
	for _, sx in { -w / 2 + 0.25, w / 2 - 0.25 } do
		for _, sz in { -depth / 2 + 0.25, depth / 2 - 0.25 } do
			pc("Kaki", Vector3.new(0.2, 0.5, 0.2), Vector3.new(sx, 0.25, sz), legColor, M.Metal)
		end
	end
	pc("Rangka", Vector3.new(w, 0.8, depth), Vector3.new(0, 0.9, 0), fabric, mat)
	pc("Sandaran", Vector3.new(w, 2.0, 0.7), Vector3.new(0, 2.0, depth / 2 - 0.35), fabric, mat)
	pc("LenganKiri", Vector3.new(0.6, 1.5, depth), Vector3.new(-w / 2 + 0.3, 1.7, 0), fabric, mat)
	pc("LenganKanan", Vector3.new(0.6, 1.5, depth), Vector3.new(w / 2 - 0.3, 1.7, 0), fabric, mat)
	local n = math.max(1, math.floor((w - 1.2) / 2.2 + 0.5))
	local cw = (w - 1.2) / n
	for i = 1, n do
		pc("Bantal", Vector3.new(cw - 0.08, 0.55, depth - 0.9), Vector3.new(-w / 2 + 0.6 + cw * (i - 0.5), 1.55, -0.3),
			fabric, mat, { class = "Seat" })
	end
	return m
end

function Kit:roundTable(pos, d, h, topColor, topMat, baseColor)
	local m = newModel(self, "Meja")
	self:cyl("Alas", 1.7, 0.14, pos + Vector3.new(0, 0.07, 0), baseColor, M.Metal, { parent = m })
	self:cyl("Tiang", 0.3, h - 0.2, pos + Vector3.new(0, h / 2 - 0.05, 0), baseColor, M.Metal, { parent = m })
	self:cyl("Daun", d, 0.2, pos + Vector3.new(0, h - 0.1, 0), topColor, topMat, { parent = m })
	return m
end

function Kit:rectTable(pos, sx, sz, h, topColor, topMat, legColor)
	local m = newModel(self, "Meja")
	self:box("Daun", Vector3.new(sx, 0.25, sz), pos + Vector3.new(0, h - 0.12, 0), topColor, topMat, { parent = m })
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			self:box("Kaki", Vector3.new(0.2, h - 0.25, 0.2), pos + Vector3.new(a * (sx / 2 - 0.25), (h - 0.25) / 2, b * (sz / 2 - 0.25)),
				legColor, M.Metal, { parent = m })
		end
	end
	return m
end

function Kit:cup(pos, cup, coffee)
	self:cyl("Tatakan", 0.85, 0.06, pos + Vector3.new(0, 0.03, 0), cup, M.SmoothPlastic, { solid = false })
	self:cyl("Cangkir", 0.5, 0.36, pos + Vector3.new(0, 0.24, 0), cup, M.SmoothPlastic, { solid = false })
	self:cyl("Kopi", 0.42, 0.04, pos + Vector3.new(0, 0.42, 0), coffee or rgb(86, 54, 34), M.SmoothPlastic, { solid = false })
end

function Kit:plant(pos, scale, potColor, leaf)
	scale = scale or 1
	local m = newModel(self, "Tanaman")
	self:cyl("Pot", 1.9 * scale, 1.7 * scale, pos + Vector3.new(0, 0.85 * scale, 0), potColor, M.Concrete, { parent = m })
	self:cyl("Tanah", 1.6 * scale, 0.1, pos + Vector3.new(0, 1.72 * scale, 0), rgb(70, 50, 36), M.Slate, { parent = m, solid = false })
	self:cyl("Batang", 0.22 * scale, 2.6 * scale, pos + Vector3.new(0, 3 * scale, 0), rgb(110, 80, 56), M.Wood, { parent = m, solid = false })
	local spots = {
		{ 0, 4.6, 0, 2.0 }, { 0.9, 3.9, 0.3, 1.5 }, { -0.9, 4.0, -0.3, 1.6 }, { 0.2, 3.5, -0.9, 1.4 },
		{ -0.3, 3.6, 0.9, 1.4 }, { 0.5, 5.3, 0.4, 1.2 },
	}
	for i, s in ipairs(spots) do
		local c = Color3.new(leaf.R * (0.85 + 0.1 * (i % 3)), leaf.G * (0.9 + 0.08 * (i % 2)), leaf.B)
		self:ball("Daun", Vector3.new(s[4], s[4] * 0.85, s[4]) * scale, pos + Vector3.new(s[1], s[2], s[3]) * scale, c, M.Grass,
			{ parent = m, solid = false })
	end
	return m
end

-- Lampu gantung: kabel dari y = top ke kap; kap berwarna, bola lampu bercahaya
function Kit:pendant(pos, top, shadeColor, glow, brightness, range, shadeD)
	shadeD = shadeD or 1.6
	local m = newModel(self, "LampuGantung")
	local len = top - pos.Y
	self:cyl("Kabel", 0.08, len, Vector3.new(pos.X, pos.Y + len / 2, pos.Z), rgb(30, 30, 30), M.Metal, { parent = m, solid = false, shadow = false })
	self:cyl("Kap", shadeD, 0.6, pos + Vector3.new(0, 0.1, 0), shadeColor, M.Metal, { parent = m, solid = false })
	local bulb = self:ball("Bohlam", Vector3.new(0.7, 0.7, 0.7), pos + Vector3.new(0, -0.35, 0), glow, M.Neon, { parent = m, solid = false, shadow = false })
	self:light(bulb, glow, brightness or 1.2, range or 18)
	return m
end

function Kit:picture(pos, size, yaw, frame, faceText, canvas, textColor, font)
	local rot = CFrame.Angles(0, yaw, 0)
	local m = newModel(self, "Bingkai")
	self:box("Bingkai", Vector3.new(size.X, size.Y, 0.2), pos, frame, M.Wood, { rot = rot, parent = m, solid = false })
	local c = self:box("Kanvas", Vector3.new(size.X - 0.4, size.Y - 0.4, 0.1), pos + rot:VectorToWorldSpace(Vector3.new(0, 0, -0.1)), canvas,
		M.SmoothPlastic, { rot = rot, parent = m, solid = false })
	if faceText then
		self:label(c, Enum.NormalId.Front, faceText, textColor or rgb(60, 40, 30), font, 60)
	end
	return m
end

return Kit
