--!nonstrict
--[[
	HotelKit: alat bantu pembangun Hotel Bintang Kota (map/BuildHotel, map/BuildHotelLantai).
	Koordinat lokal: x timur, y atas (0 = lantai), z selatan (depan hotel = -z, menghadap jalan di utara).
	Setiap ctx punya frame (CFrame dunia) sehingga kamar bisa dibangun satu kali lalu dipasang
	ke 8 posisi (utara/selatan) hanya dengan mengganti frame.
]]
local CollectionService = game:GetService("CollectionService")

local Kit = {}
local rgb = Color3.fromRGB
local M = Enum.Material

Kit.ORIGIN = Vector3.new(270, 0.6, -52) -- tengah hotel, atas lantai lobi
Kit.W = 96
Kit.D = 52
Kit.H1 = 16 -- lantai koridor di atas lantai lobi
Kit.LOBBY_H = 14.8
Kit.ROOM_H = 10
Kit.CORE = { x0 = -6, x1 = 6, z0 = 3.5, z1 = 13.8 }
Kit.FLOORS = 8 -- L, 2..8
Kit.GAIN = 1 -- penguat lampu titik dalam ruangan (3 terlalu terang di HP)

Kit.C = {
	charcoal = rgb(52, 56, 64),
	charcoalD = rgb(34, 36, 42),
	stone = rgb(204, 194, 180),
	stoneD = rgb(150, 142, 132),
	gold = rgb(208, 168, 86),
	goldD = rgb(160, 124, 56),
	cream = rgb(242, 234, 218),
	creamD = rgb(224, 212, 190),
	walnut = rgb(104, 70, 48),
	walnutL = rgb(150, 106, 72),
	burgundy = rgb(112, 34, 46),
	navy = rgb(28, 44, 66),
	glass = rgb(150, 196, 216),
	glassD = rgb(96, 132, 156),
	steel = rgb(196, 200, 206),
	steelD = rgb(110, 116, 124),
	white = rgb(250, 248, 244),
	linen = rgb(246, 244, 238),
	black = rgb(24, 24, 28),
	leaf = rgb(70, 140, 70),
	leafD = rgb(48, 108, 56),
	pot = rgb(176, 110, 76),
	warm = rgb(255, 226, 170),
	teal = rgb(46, 124, 130),
	sofa = rgb(88, 104, 120),
	mirror = rgb(196, 222, 232),
}

function Kit.ctx(parent, frame)
	local c = { parent = parent, frame = frame }

	function c.box(name, x0, x1, y0, y1, z0, z1, color, mat, tr, par)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size =
			Vector3.new(math.max(x1 - x0, 0.05), math.max(y1 - y0, 0.05), math.max(z1 - z0, 0.05))
		p.CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.Transparency = tr or 0
		p.Parent = par or parent
		return p
	end

	-- silinder tegak: pusat (x,z), dasar y0, diameter d, tinggi h
	function c.cyl(name, x, y0, z, d, h, color, mat, par)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(h, d, d)
		p.CFrame = frame * CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = par or parent
		return p
	end

	function c.ball(name, x, y, z, d, color, mat, par)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(d, d, d)
		p.CFrame = frame * CFrame.new(x, y, z)
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = par or parent
		return p
	end

	-- lampu titik redup di dalam ruangan
	function c.light(part, range, brightness, color)
		local l = Instance.new("PointLight")
		l.Range = range
		l.Brightness = brightness * Kit.GAIN
		l.Color = color or Kit.C.warm
		l.Shadows = false
		l.Parent = part
		return l
	end

	-- teks di sisi part (SurfaceGui). face: Enum.NormalId
	function c.text(part, face, text, o)
		o = o or {}
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = o.pps or 30
		g.LightInfluence = o.light or 0
		g.Brightness = o.brightness or 1
		g.Parent = part
		local t = Instance.new("TextLabel")
		t.Name = "Teks"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = text
		t.TextColor3 = o.color or Kit.C.gold
		t.Font = o.font or Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = g
		if o.bg then
			g.Parent = part
			local bg = Instance.new("Frame")
			bg.Name = "Latar"
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = o.bg
			bg.BorderSizePixel = 0
			bg.ZIndex = 0
			bg.Parent = g
		end
		if o.tag then
			t:SetAttribute("Pattern", text)
			CollectionService:AddTag(t, o.tag)
		end
		return t
	end

	-- papan teks: kotak tipis dengan teks di salah satu sisi
	function c.sign(name, x0, x1, y0, y1, z0, z1, face, text, o)
		o = o or {}
		local p = c.box(
			name,
			x0,
			x1,
			y0,
			y1,
			z0,
			z1,
			o.bg or Kit.C.charcoalD,
			o.mat or M.SmoothPlastic,
			0,
			o.parent
		)
		p.CanCollide = false
		p.CastShadow = false
		c.text(p, face, text, o)
		return p
	end

	-- pintu kaca berengsel (tag SwingDoor, digerakkan DoorService).
	-- engsel (hx,hz) lokal, daun memanjang ke arah (dx,dz), lebar w, tinggi h,
	-- membuka ke arah (sx,sz) (lokal). o.frost = kaca buram, o.wood = pintu kayu.
	function c.door(name, hx, hz, y0, h, dx, dz, w, sx, sz, o)
		o = o or {}
		local right = Vector3.new(dx, 0, dz).Unit
		local center = Vector3.new(hx, y0 + h / 2, hz) + right * (w / 2)
		local leafCF = frame
			* CFrame.fromMatrix(center, right, Vector3.yAxis, right:Cross(Vector3.yAxis))
		local model = Instance.new("Model")
		model.Name = name
		local function leafPart(pn, cx, cy, sx_, sy_, sz_, color, mat, tr)
			local p = Instance.new("Part")
			p.Name = pn
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			p.Size = Vector3.new(sx_, sy_, sz_)
			p.CFrame = leafCF * CFrame.new(cx, cy, 0)
			p.Color = color
			p.Material = mat
			p.Transparency = tr or 0
			p.Parent = model
			return p
		end
		local frameColor = o.frame or Kit.C.gold
		local frameMat = o.frameMat or M.Metal
		local st = 0.4
		leafPart("StileEngsel", -w / 2 + st / 2, 0, st, h, 0.3, frameColor, frameMat)
		leafPart("StileBebas", w / 2 - st / 2, 0, st, h, 0.3, frameColor, frameMat)
		leafPart("RelAtas", 0, h / 2 - st / 2, w, st, 0.3, frameColor, frameMat)
		leafPart("RelBawah", 0, -h / 2 + 0.5, w, 1.0, 0.3, frameColor, frameMat)
		if o.wood then
			leafPart("Panel", 0, 0.2, w - 2 * st, h - 1.4 - st, 0.25, Kit.C.walnutL, M.Wood)
		else
			leafPart(
				"Kaca",
				0,
				0.2,
				w - 2 * st,
				h - 1.4 - st,
				0.18,
				o.frost and rgb(220, 236, 244) or Kit.C.glass,
				M.Glass,
				o.frost and 0.25 or 0.5
			)
		end
		local handle =
			leafPart("Gagang", w / 2 - 0.9, -h * 0.05, 0.25, 2.4, 0.5, Kit.C.steel, M.Metal)
		handle.Size = Vector3.new(0.25, 2.4, 0.5)
		model.WorldPivot = leafCF
		-- sudut buka: pilih tanda supaya daun berputar ke arah (sx,sz)
		local swing = frame:VectorToWorldSpace(Vector3.new(sx, 0, sz)).Unit
		local dWorld = frame:VectorToWorldSpace(right)
		local rotated = Vector3.new(dWorld.Z, 0, -dWorld.X) -- hasil putar +90 derajat pada sumbu Y
		local openDeg = if rotated:Dot(swing) > 0 then 90 else -90
		local hingeWorld = frame * Vector3.new(hx, y0 + h / 2, hz)
		model:SetAttribute("HingeX", hingeWorld.X)
		model:SetAttribute("HingeY", hingeWorld.Y)
		model:SetAttribute("HingeZ", hingeWorld.Z)
		model:SetAttribute("OpenDeg", o.openDeg or openDeg)
		model:SetAttribute("Radius", o.radius or 8)
		CollectionService:AddTag(model, "SwingDoor")
		model.Parent = o.parent or parent
		return model
	end

	return c
end

-- lift: inti (x -6..6, z 3.5..13.8), pintu geser menghadap utara. level = "lobi" | "lantai".
-- h = tinggi ruang pada level itu.
function Kit.lift(c, level, h, parent)
	local C = Kit.C
	local folder = Instance.new("Model")
	folder.Name = "Lift_" .. level
	folder.Parent = parent
	folder:SetAttribute("Level", level)
	CollectionService:AddTag(folder, "HotelLift")
	local dh = 8.2
	-- dinding inti (pintu geser berada di kantong z 4.3..4.8)
	c.box("IntiDepanKiri", -6, -2.5, 0, h, 3.5, 4.3, C.charcoal, M.Concrete, 0, folder)
	c.box("IntiDepanKanan", 2.5, 6, 0, h, 3.5, 4.3, C.charcoal, M.Concrete, 0, folder)
	c.box("IntiDepanAtas", -2.5, 2.5, dh, h, 3.5, 4.3, C.charcoal, M.Concrete, 0, folder)
	c.box("IntiSampingKiri", -6, -4, 0, h, 4.3, 13.8, C.charcoalD, M.Concrete, 0, folder)
	c.box("IntiSampingKanan", 4, 6, 0, h, 4.3, 13.8, C.charcoalD, M.Concrete, 0, folder)
	c.box("IntiBelakang", -4, 4, 0, h, 12.8, 13.8, C.charcoalD, M.Concrete, 0, folder)
	c.box("IntiAtasKabin", -4, 4, 8.5, h, 4.8, 12.8, C.charcoalD, M.Concrete, 0, folder)
	-- kusen emas pintu
	c.box("KusenKiri", -2.9, -2.5, 0, dh, 3.3, 4.4, C.gold, M.Metal, 0, folder)
	c.box("KusenKanan", 2.5, 2.9, 0, dh, 3.3, 4.4, C.gold, M.Metal, 0, folder)
	c.box("KusenAtas", -2.9, 2.9, dh, dh + 0.4, 3.3, 4.4, C.gold, M.Metal, 0, folder)
	c.box("AmbangPintu", -2.5, 2.5, 0, 0.12, 3.5, 4.8, C.steelD, M.Metal, 0, folder)
	-- pintu geser
	local dl = c.box("PintuKiri", -2.5, 0, 0, dh, 4.3, 4.8, C.steel, M.Metal, 0, folder)
	local dr = c.box("PintuKanan", 0, 2.5, 0, dh, 4.3, 4.8, C.steel, M.Metal, 0, folder)
	local right = c.frame.RightVector
	dl:SetAttribute("Slide", -right * 2.5)
	dr:SetAttribute("Slide", right * 2.5)
	for _, d in { dl, dr } do
		d:SetAttribute("Closed", d.CFrame)
		d.Name = d.Name
		CollectionService:AddTag(d, "HotelLiftDoor")
	end
	c.box("GarisPintuTengah", -0.05, 0.05, 0.4, dh - 0.4, 3.9, 4.3, C.steelD, M.Metal, 0, folder)
	-- lantai dan langit-langit kabin
	c.box("LantaiKabin", -4, 4, 0, 0.15, 4.8, 12.8, C.cream, M.Marble, 0, folder)
	c.box("LantaiKabinEmas", -3.4, 3.4, 0.15, 0.2, 5.4, 12.2, C.gold, M.Metal, 0, folder)
	c.box("LantaiKabinTengah", -3.0, 3.0, 0.2, 0.25, 5.8, 11.8, C.charcoal, M.Marble, 0, folder)
	local lamp = c.box("LampuKabin", -2.2, 2.2, 8.2, 8.5, 6.6, 11.0, C.warm, M.Neon, 0, folder)
	c.light(lamp, 10, 0.1)
	c.box("PlafonKabin", -4, 4, 8.35, 8.5, 4.8, 12.8, C.steelD, M.Metal, 0, folder)
	-- dinding kabin: baja, cermin di belakang
	c.box("DindingKabinKiri", -4, -3.8, 0.15, 8.35, 4.8, 12.8, C.steel, M.Metal, 0, folder)
	c.box("DindingKabinKanan", 3.8, 4, 0.15, 8.35, 4.8, 12.8, C.steel, M.Metal, 0, folder)
	c.box("CerminKabin", -3.8, 3.8, 0.9, 7.6, 12.6, 12.8, C.mirror, M.Metal, 0, folder).Reflectance =
		0.55
	c.box("PegangBelakang", -3.2, 3.2, 3.3, 3.55, 12.35, 12.6, C.gold, M.Metal, 0, folder)
	c.box("PegangKiri", -3.8, -3.55, 3.3, 3.55, 6.0, 11.6, C.gold, M.Metal, 0, folder)
	-- zona dalam kabin (tak terlihat): dipakai HotelService
	local zone = c.box("Dalam", -4, 4, 0.3, 8.3, 4.8, 12.8, C.white, M.SmoothPlastic, 1, folder)
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	-- panel pilih lantai di dinding kanan kabin (menghadap barat)
	local plate =
		c.box("PanelPilih", 3.45, 3.8, 1.6, 7.0, 9.0, 11.0, C.charcoalD, M.Metal, 0, folder)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PilihLantai"
	prompt.ActionText = "Pilih lantai"
	prompt.ObjectText = "Lift"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	local names = { "L", "2", "3", "4", "5", "6", "7", "8" }
	for i = 1, Kit.FLOORS do
		local y = 1.9 + (i - 1) * 0.62
		local lp = c.box(
			"LampuLantai" .. i,
			3.2,
			3.45,
			y,
			y + 0.5,
			9.4,
			10.6,
			C.steelD,
			M.SmoothPlastic,
			0,
			folder
		)
		lp.CanCollide = false
		lp:SetAttribute("Idx", i)
		lp:SetAttribute("Level", level)
		CollectionService:AddTag(lp, "HotelLamp")
		c.text(
			lp,
			Enum.NormalId.Left,
			names[i],
			{ color = C.white, font = Enum.Font.GothamBlack, pps = 60 }
		)
	end
	-- indikator di atas pintu (sisi luar, menghadap koridor/lobi)
	for i = 1, Kit.FLOORS do
		local x0 = 4.1 - (i - 1) * 1.3 -- dilihat dari depan (menghadap selatan), L di kiri
		local lp = c.box(
			"IndikatorLantai" .. i,
			x0,
			x0 + 1.0,
			8.75,
			9.75,
			3.05,
			3.5,
			C.steelD,
			M.SmoothPlastic,
			0,
			folder
		)
		lp.CanCollide = false
		lp:SetAttribute("Idx", i)
		lp:SetAttribute("Level", level)
		CollectionService:AddTag(lp, "HotelLamp")
		c.text(
			lp,
			Enum.NormalId.Front,
			names[i],
			{ color = C.white, font = Enum.Font.GothamBlack, pps = 60 }
		)
	end
	if h > 12 then
		c.sign(
			"PapanLift",
			-2.5,
			2.5,
			10.6,
			11.6,
			3.2,
			3.5,
			Enum.NormalId.Front,
			"LIFT",
			{ bg = C.charcoalD, color = C.gold, pps = 50 }
		)
	end
	return folder
end

return Kit
