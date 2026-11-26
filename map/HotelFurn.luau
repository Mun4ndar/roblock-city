--!nonstrict
--[[
	HotelFurn: perabot untuk Hotel Bintang Kota (lobi dan kamar). Semua fungsi menerima ctx dari HotelKit
	yang frame-nya sudah ditaruh di titik perabot; perabot menghadap +z (depan = +z), lantai y = 0.
]]
local Kit = require(script.Parent:WaitForChild("HotelKit"))
local C = Kit.C
local M = Enum.Material

local F = {}

local function seatBox(c, name, x0, x1, y0, y1, z0, z1, color, mat)
	local s = Instance.new("Seat")
	s.Name = name
	s.Anchored = true
	s.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	s.CFrame = c.frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	s.Color = color
	s.Material = mat or M.Fabric
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Parent = c.parent
	return s
end
F.seatBox = seatBox

function F.sofa(c, w, color, accent)
	local half = w / 2
	c.box("SofaDasar", -half, half, 0.3, 1.4, -1.5, 1.5, color, M.Fabric)
	c.box("SofaSandaran", -half, half, 1.4, 3.7, -1.5, -0.6, color, M.Fabric)
	c.box("SofaLenganKiri", -half, -half + 0.8, 1.4, 2.6, -0.6, 1.5, color, M.Fabric)
	c.box("SofaLenganKanan", half - 0.8, half, 1.4, 2.6, -0.6, 1.5, color, M.Fabric)
	local n = math.max(1, math.floor((w - 1.6) / 3.2 + 0.5))
	local cw = (w - 1.6) / n
	for i = 1, n do
		local x0 = -half + 0.8 + (i - 1) * cw
		seatBox(
			c,
			"SofaDudukan",
			x0 + 0.05,
			x0 + cw - 0.05,
			1.4,
			2.0,
			-0.6,
			1.5,
			accent or color,
			M.Fabric
		)
		c.box(
			"SofaBantalSandar",
			x0 + 0.25,
			x0 + cw - 0.25,
			2.0,
			3.3,
			-0.6,
			-0.25,
			accent or color,
			M.Fabric
		)
	end
	for _, sx in { -half + 0.5, half - 0.5 } do
		for _, sz in { -1.1, 1.1 } do
			c.cyl("KakiSofa", sx, 0, sz, 0.3, 0.3, C.gold, M.Metal)
		end
	end
end

function F.armchair(c, color)
	c.box("KursiDasar", -1.6, 1.6, 0.3, 1.4, -1.5, 1.5, color, M.Fabric)
	c.box("KursiSandaran", -1.6, 1.6, 1.4, 3.6, -1.5, -0.7, color, M.Fabric)
	c.box("KursiLenganKiri", -1.6, -1.0, 1.4, 2.5, -0.7, 1.5, color, M.Fabric)
	c.box("KursiLenganKanan", 1.0, 1.6, 1.4, 2.5, -0.7, 1.5, color, M.Fabric)
	seatBox(c, "KursiDudukan", -1.0, 1.0, 1.4, 1.9, -0.7, 1.5, color, M.Fabric)
	for _, sx in { -1.2, 1.2 } do
		for _, sz in { -1.1, 1.1 } do
			c.cyl("KakiKursi", sx, 0, sz, 0.3, 0.3, C.gold, M.Metal)
		end
	end
end

function F.coffeeTable(c, w, d)
	c.box("MejaTop", -w / 2, w / 2, 1.3, 1.6, -d / 2, d / 2, C.walnut, M.Wood)
	c.box(
		"MejaKaca",
		-w / 2 + 0.3,
		w / 2 - 0.3,
		1.6,
		1.68,
		-d / 2 + 0.3,
		d / 2 - 0.3,
		C.glass,
		M.Glass,
		0.5
	)
	for _, sx in { -w / 2 + 0.4, w / 2 - 0.4 } do
		for _, sz in { -d / 2 + 0.4, d / 2 - 0.4 } do
			c.cyl("MejaKaki", sx, 0, sz, 0.3, 1.3, C.gold, M.Metal)
		end
	end
end

function F.sideTable(c)
	c.cyl("MejaSampingTop", 0, 1.9, 0, 1.8, 0.2, C.walnut, M.Wood)
	c.cyl("MejaSampingKaki", 0, 0, 0, 0.3, 1.9, C.gold, M.Metal)
	c.cyl("MejaSampingAlas", 0, 0, 0, 1.1, 0.12, C.gold, M.Metal)
end

function F.plant(c, size)
	size = size or 1
	c.cyl("Pot", 0, 0, 0, 2.2 * size, 1.8 * size, C.pot, M.Concrete)
	c.cyl("Tanah", 0, 1.8 * size, 0, 1.9 * size, 0.15, C.black, M.Ground)
	c.cyl("Batang", 0, 1.9 * size, 0, 0.3 * size, 2.2 * size, C.walnut, M.Wood)
	c.ball("Daun1", 0, 4.6 * size, 0, 2.8 * size, C.leaf, M.Grass)
	c.ball("Daun2", 0.9 * size, 3.6 * size, 0.4 * size, 2.0 * size, C.leafD, M.Grass)
	c.ball("Daun3", -0.9 * size, 3.9 * size, -0.4 * size, 2.2 * size, C.leaf, M.Grass)
end

function F.floorLamp(c)
	c.cyl("LampuAlas", 0, 0, 0, 1.2, 0.2, C.gold, M.Metal)
	c.cyl("LampuTiang", 0, 0.2, 0, 0.18, 4.6, C.gold, M.Metal)
	local shade = c.cyl("LampuKap", 0, 4.4, 0, 1.6, 1.5, C.cream, M.Neon)
	shade.Transparency = 0.15
	c.light(shade, 12, 0.3)
end

function F.chair(c, color) -- kursi meja kerja / makan
	local s = seatBox(c, "KursiDudukan", -1, 1, 1.5, 1.8, -1, 1, color or C.walnutL, M.Wood)
	s.Color = color or C.walnutL
	c.box("KursiSandaran", -1, 1, 1.8, 3.6, -1, -0.8, color or C.walnutL, M.Wood)
	for _, sx in { -0.8, 0.8 } do
		for _, sz in { -0.8, 0.8 } do
			c.box("KursiKaki", sx - 0.1, sx + 0.1, 0, 1.5, sz - 0.1, sz + 0.1, C.gold, M.Metal)
		end
	end
end

function F.stool(c) -- bangku bar
	local s = seatBox(c, "BangkuDudukan", -0.9, 0.9, 2.5, 2.9, -0.9, 0.9, C.burgundy, M.Fabric)
	c.cyl("BangkuTiang", 0, 0.2, 0, 0.25, 2.3, C.gold, M.Metal)
	c.cyl("BangkuAlas", 0, 0, 0, 1.4, 0.2, C.gold, M.Metal)
	return s
end

function F.painting(c, w, h, colors, name)
	local frame =
		c.box(name or "Lukisan", -w / 2 - 0.3, w / 2 + 0.3, 0, h + 0.6, -0.2, 0.2, C.gold, M.Metal)
	frame.CanCollide = false
	local canvas =
		c.box("LukisanKanvas", -w / 2, w / 2, 0.3, h + 0.3, 0.2, 0.3, colors[1], M.SmoothPlastic)
	canvas.CanCollide = false
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.Parent = canvas
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = g
	local grad = Instance.new("UIGradient")
	local seq = {}
	for i, col in colors do
		table.insert(seq, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), col))
	end
	grad.Color = ColorSequence.new(seq)
	grad.Rotation = 35
	grad.Parent = f
	return frame
end

function F.tv(c) -- menghadap +z
	local tvb = c.box("TvBingkai", -3.2, 3.2, 0, 3.8, -0.2, 0.2, C.black, M.SmoothPlastic)
	tvb.CanCollide = false
	local scr = c.box("TvLayar", -3.0, 3.0, 0.2, 3.6, 0.2, 0.3, rgb and C.black or C.black, M.Glass)
	scr.Color = Color3.fromRGB(20, 26, 40)
	scr.Reflectance = 0.2
	scr.CanCollide = false
	return scr
end

return F
