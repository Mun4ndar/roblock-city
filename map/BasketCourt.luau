--!strict
--[[
	ROBLOCK CITY: lapangan basket rapi (dipakai FixHousesCourt dan BuildResidential).
	BasketCourt.build(center, parent) -> Model "LapanganBasket"

	center = CFrame di permukaan tanah (y = tanah), sumbu X lokal = panjang lapangan.
	Isi: alas biru 68x40, lapangan oranye 56x30 dengan garis resmi (garis tepi, tengah, lingkaran
	tengah, area cat, lingkaran lemparan bebas, garis tiga angka), dua ring menghadap ke dalam,
	pagar kawat 8,5 stud dengan pintu di tengah kedua sisi panjang, dan bola basket.
	Semua ukuran memakai stud (1 m = 2 stud).
]]

local BasketCourt = {}

local WHITE = Color3.fromRGB(245, 245, 245)
local APRON = Color3.fromRGB(70, 120, 200)
local FLOOR = Color3.fromRGB(235, 140, 70)
local RIM = Color3.fromRGB(240, 100, 40)
local STEEL = Color3.fromRGB(60, 60, 65)

local HALF_L, HALF_W = 28, 15 -- lapangan 56 x 30
local APRON_HX, APRON_HZ = 34, 20 -- alas 68 x 40
local FLOOR_TOP = 0.47
local LINE_W = 0.5
local FENCE_H = 8.5

function BasketCourt.build(center: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "LapanganBasket"

	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, solid: boolean, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = center * offset
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.CastShadow = solid
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- garis dari titik a ke titik b (koordinat lokal, bidang XZ)
	local function line(name: string, a: Vector2, b: Vector2, width: number?)
		local d = b - a
		local len = d.Magnitude
		if len < 0.01 then
			return
		end
		local mid = (a + b) / 2
		local ang = math.atan2(-d.Y, d.X)
		part(
			name,
			Vector3.new(len + 0.05, 0.07, width or LINE_W),
			CFrame.new(mid.X, FLOOR_TOP + 0.005, mid.Y) * CFrame.Angles(0, ang, 0),
			WHITE,
			false
		)
	end

	local function arc(name: string, c: Vector2, r: number, from: number, to: number, steps: number)
		local prev: Vector2? = nil
		for i = 0, steps do
			local t = from + (to - from) * i / steps
			local pt = c + Vector2.new(math.cos(t), math.sin(t)) * r
			if prev then
				line(name, prev, pt)
			end
			prev = pt
		end
	end

	-- alas + lantai lapangan
	part("Alas", Vector3.new(APRON_HX * 2, 0.3, APRON_HZ * 2), CFrame.new(0, 0.2, 0), APRON, true)
	part("Lantai", Vector3.new(HALF_L * 2, 0.12, HALF_W * 2), CFrame.new(0, FLOOR_TOP - 0.06, 0), FLOOR, true)

	-- garis tepi, tengah, lingkaran tengah
	line("GarisTepi", Vector2.new(-HALF_L, -HALF_W), Vector2.new(HALF_L, -HALF_W))
	line("GarisTepi", Vector2.new(-HALF_L, HALF_W), Vector2.new(HALF_L, HALF_W))
	line("GarisTepi", Vector2.new(-HALF_L, -HALF_W), Vector2.new(-HALF_L, HALF_W))
	line("GarisTepi", Vector2.new(HALF_L, -HALF_W), Vector2.new(HALF_L, HALF_W))
	line("GarisTengah", Vector2.new(0, -HALF_W), Vector2.new(0, HALF_W))
	arc("LingkaranTengah", Vector2.zero, 4.5, 0, math.pi * 2, 28)

	local HOOP_X = 24.1 -- pusat ring dari tengah lapangan
	local BOARD_X = 25.6
	local POLE_X = 31.5
	local RIM_Y = 9.2

	for _, s in { -1, 1 } do
		-- area cat (key) 11,6 x 9,8 dan lingkaran lemparan bebas
		local keyLen, keyWid = 11.6, 9.8
		local keyEnd = s * HALF_L
		local keyIn = s * (HALF_L - keyLen)
		part(
			"AreaCat",
			Vector3.new(keyLen, 0.03, keyWid),
			CFrame.new((keyEnd + keyIn) / 2, FLOOR_TOP + 0.015, 0),
			APRON,
			false
		)
		line("GarisAreaCat", Vector2.new(keyEnd, -keyWid / 2), Vector2.new(keyIn, -keyWid / 2))
		line("GarisAreaCat", Vector2.new(keyEnd, keyWid / 2), Vector2.new(keyIn, keyWid / 2))
		line("GarisAreaCat", Vector2.new(keyIn, -keyWid / 2 - LINE_W / 2), Vector2.new(keyIn, keyWid / 2 + LINE_W / 2))
		arc("LingkaranBebas", Vector2.new(keyIn, 0), 3.6, 0, math.pi * 2, 20)

		-- garis tiga angka: busur jari-jari 13,5 dari pusat ring + dua garis lurus di tepi
		local c = Vector2.new(s * HOOP_X, 0)
		local zEdge = HALF_W - 1.8
		local r = 13.5
		local a = math.asin(zEdge / r)
		local dx = math.sqrt(r * r - zEdge * zEdge)
		local base = if s > 0 then math.pi else 0 -- busur membuka ke arah tengah lapangan
		arc("GarisTigaAngka", c, r, base - a, base + a, 18)
		local xArcEnd = s * (HOOP_X - dx)
		line("GarisTigaAngka", Vector2.new(xArcEnd, -zEdge), Vector2.new(s * HALF_L, -zEdge))
		line("GarisTigaAngka", Vector2.new(xArcEnd, zEdge), Vector2.new(s * HALF_L, zEdge))

		-- tiang ring di belakang garis dasar, papan menghadap tengah
		local top = 0.35
		part("TiangRing", Vector3.new(0.7, 13, 0.7), CFrame.new(s * POLE_X, top + 6.5, 0), STEEL, true, Enum.Material.Metal)
		part("DasarTiang", Vector3.new(1.8, 0.5, 1.8), CFrame.new(s * POLE_X, top + 0.25, 0), STEEL, true, Enum.Material.Metal)
		part(
			"LenganRing",
			Vector3.new(POLE_X - BOARD_X, 0.5, 0.5),
			CFrame.new(s * (POLE_X + BOARD_X) / 2, 10.6, 0),
			STEEL,
			false,
			Enum.Material.Metal
		)
		part("Papan", Vector3.new(0.4, 4, 6), CFrame.new(s * BOARD_X, 10.6, 0), WHITE, true)
		part("KotakPapan", Vector3.new(0.06, 1.6, 2.4), CFrame.new(s * (BOARD_X - 0.2), 9.9, 0), RIM, false)
		part("PenyanggaRing", Vector3.new(0.3, 0.3, 0.6), CFrame.new(s * (HOOP_X + 1.35), RIM_Y, 0), RIM, false)

		-- ring dari 14 ruas
		local segs = 14
		local rr = 1.15
		for i = 0, segs - 1 do
			local t = i / segs * math.pi * 2
			local seg = part(
				"Ring",
				Vector3.new(2 * rr * math.tan(math.pi / segs) + 0.15, 0.3, 0.3),
				CFrame.new(s * HOOP_X + math.cos(t) * rr, RIM_Y, math.sin(t) * rr) * CFrame.Angles(0, -t + math.pi / 2, 0),
				RIM,
				true
			)
			seg.CanCollide = false
		end
		local net = part(
			"Jaring",
			Vector3.new(1.5, 1.9, 1.9),
			CFrame.new(s * HOOP_X, RIM_Y - 0.85, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WHITE,
			false
		)
		net.Shape = Enum.PartType.Cylinder
		net.Transparency = 0.55
	end

	-- pagar kawat: tiang tiap segmen, panel tembus pandang, pintu di tengah sisi panjang
	local FENCE_COLOR = Color3.fromRGB(150, 155, 160)
	local function fenceRun(name: string, from: Vector2, to: Vector2, sections: number, gateIndex: number?)
		local d = to - from
		local len = d.Magnitude
		local ang = math.atan2(-d.Y, d.X)
		local seg = len / sections
		for i = 0, sections do
			local p = from + d.Unit * (seg * i)
			part(name .. "Tiang", Vector3.new(0.5, FENCE_H, 0.5), CFrame.new(p.X, 0.35 + FENCE_H / 2, p.Y), STEEL, true, Enum.Material.Metal)
		end
		for i = 1, sections do
			local mid = from + d.Unit * (seg * (i - 0.5))
			if i == gateIndex then
				part(name .. "Palang", Vector3.new(seg, 0.4, 0.4), CFrame.new(mid.X, 0.35 + FENCE_H - 0.2, mid.Y) * CFrame.Angles(0, ang, 0), STEEL, false, Enum.Material.Metal)
			else
				local panel = part(
					name .. "Kawat",
					Vector3.new(seg - 0.5, FENCE_H - 0.9, 0.12),
					CFrame.new(mid.X, 0.35 + (FENCE_H - 0.9) / 2 + 0.2, mid.Y) * CFrame.Angles(0, ang, 0),
					FENCE_COLOR,
					true
				)
				panel.Transparency = 0.6
				part(name .. "Rel", Vector3.new(seg, 0.3, 0.3), CFrame.new(mid.X, 0.35 + FENCE_H - 0.15, mid.Y) * CFrame.Angles(0, ang, 0), STEEL, false, Enum.Material.Metal)
			end
		end
	end
	local hx, hz = APRON_HX, APRON_HZ
	fenceRun("PagarSelatan", Vector2.new(-hx, hz), Vector2.new(hx, hz), 7, 4)
	fenceRun("PagarUtara", Vector2.new(-hx, -hz), Vector2.new(hx, -hz), 7, 4)
	fenceRun("PagarBarat", Vector2.new(-hx, -hz), Vector2.new(-hx, hz), 5, nil)
	fenceRun("PagarTimur", Vector2.new(hx, -hz), Vector2.new(hx, hz), 5, nil)

	local ball = Instance.new("Part")
	ball.Name = "BolaBasket"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.6
	ball.CFrame = center * CFrame.new(0, FLOOR_TOP + 0.8, 0)
	ball.Color = Color3.fromRGB(235, 120, 40)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = false
	ball.Parent = model

	model.Parent = parent
	return model
end

return BasketCourt
