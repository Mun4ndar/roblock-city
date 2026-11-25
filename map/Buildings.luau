--[[
	Buildings: pembuat gedung bergaya low-poly untuk semua kawasan.
	Arah depan gedung = -Z lokal; yaw 0 menghadap -Z (utara), math.pi menghadap +Z (selatan).
]]

local Kit = require(script.Parent.MapKit)

local B = {}

local GLASS_DARK = Color3.fromRGB(45, 60, 75)

-- Balok atau silinder tegak dengan ukuran (lebar, tinggi, dalam) dan CFrame pusat.
local function block(
	name: string,
	w: number,
	h: number,
	d: number,
	cf: CFrame,
	color: Color3,
	parent: Instance,
	cyl: boolean?,
	props: { [string]: any }?
)
	local p: { [string]: any } = props or {}
	p.Name = name
	p.Color = color
	p.Parent = parent
	if cyl then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(h, w, w)
		p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	else
		p.Size = Vector3.new(w, h, d)
		p.CFrame = cf
	end
	return Kit.P(p)
end
B.block = block

export type TowerDef = {
	name: string,
	x: number,
	z: number,
	w: number,
	d: number,
	h: number,
	yaw: number?,
	baseY: number?,
	color: Color3,
	band: Color3?,
	bandEvery: number?,
	shape: string?, -- "box" | "cyl"
	tiers: { { number } }?, -- { faktorLebar, porsiTinggi }
	crown: string?, -- "spire" | "helipad" | "neon" | "ac"
	crownColor: Color3?,
	stripe: Color3?,
	sign: string?,
	signColor: Color3?,
	signText: Color3?,
	lobby: boolean?,
}

-- Gedung tinggi: lobi kaca, badan bertingkat (setback), pita lantai, mahkota.
function B.tower(def: TowerDef, parent: Instance): Model
	local m = Kit.model(def.name, nil)
	local base = CFrame.new(def.x, def.baseY or 1, def.z) * CFrame.Angles(0, def.yaw or 0, 0)
	local cyl = def.shape == "cyl"
	local bandEvery = def.bandEvery or 12
	local bandColor = def.band or Color3.fromRGB(235, 235, 240)
	local lobbyH = if def.lobby == false then 0 else 10
	local w, d = def.w, def.d

	local first: BasePart? = nil
	if lobbyH > 0 then
		first = block(
			"Lobby",
			w - 2,
			lobbyH,
			d - 2,
			base * CFrame.new(0, lobbyH / 2, 0),
			GLASS_DARK,
			m,
			cyl,
			{ Reflectance = 0.25 }
		)
		local front = if cyl then -(w - 2) / 2 else -(d - 2) / 2
		Kit.deco({
			Name = "Canopy",
			Size = Vector3.new(math.min(16, w - 6), 0.6, 5),
			CFrame = base * CFrame.new(0, 8, front - 2.5),
			Color = bandColor,
			Parent = m,
		})
		Kit.deco({
			Name = "Entrance",
			Size = Vector3.new(8, 7, 0.3),
			CFrame = base * CFrame.new(0, 3.5, front - 0.2),
			Color = Color3.fromRGB(170, 215, 240),
			Reflectance = 0.3,
			Parent = m,
		})
	end

	local tiers = def.tiers or { { 1, 1 } }
	local y0 = lobbyH
	local bodyH = def.h - lobbyH
	local tw, td = w, d
	for ti, tier in tiers do
		tw, td = w * tier[1], d * tier[1]
		local th = bodyH * tier[2]
		local body = block(
			"Body" .. ti,
			tw,
			th,
			td,
			base * CFrame.new(0, y0 + th / 2, 0),
			def.color,
			m,
			cyl,
			{ Reflectance = 0.12 }
		)
		first = first or body
		local k = bandEvery
		while k < th - 2 do
			block(
				"Band",
				tw + 0.4,
				1.2,
				td + 0.4,
				base * CFrame.new(0, y0 + k, 0),
				bandColor,
				m,
				cyl,
				{ CanCollide = false, CastShadow = false, CanQuery = false }
			)
			k += bandEvery
		end
		if def.stripe and not cyl then
			Kit.deco({
				Name = "Stripe",
				Size = Vector3.new(tw * 0.18, th, 0.5),
				CFrame = base * CFrame.new(0, y0 + th / 2, -td / 2 - 0.2),
				Color = def.stripe,
				Parent = m,
			})
		end
		y0 += th
		block(
			"Cap" .. ti,
			tw + 1,
			1.5,
			td + 1,
			base * CFrame.new(0, y0 + 0.75, 0),
			bandColor,
			m,
			cyl
		)
		y0 += 1.5
	end

	local top = base * CFrame.new(0, y0, 0)
	local crown = def.crown
	if crown == "spire" then
		local sh = math.max(20, def.h * 0.18)
		Kit.deco({
			Name = "Spire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(sh, 1.6, 1.6),
			CFrame = top * CFrame.new(0, sh / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(220, 220, 228),
			Material = Enum.Material.Metal,
			Parent = m,
		})
		Kit.deco({
			Name = "Beacon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = top * CFrame.new(0, sh + 1, 0),
			Color = Color3.fromRGB(255, 70, 70),
			Material = Enum.Material.Neon,
			Parent = m,
		})
	elseif crown == "helipad" then
		local pd = math.min(tw, td) * 0.8
		Kit.P({
			Name = "Helipad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, pd, pd),
			CFrame = top * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(60, 65, 70),
			Parent = m,
		})
		local mark = Kit.deco({
			Name = "HelipadMark",
			Size = Vector3.new(pd * 0.5, 0.1, pd * 0.5),
			CFrame = top * CFrame.new(0, 1.05, 0),
			Transparency = 1,
			Parent = m,
		})
		Kit.sign(mark, "H", Color3.fromRGB(255, 220, 60), Enum.NormalId.Top)
	elseif crown == "neon" then
		block(
			"NeonCrown",
			tw + 0.6,
			2,
			td + 0.6,
			top * CFrame.new(0, -4, 0),
			def.crownColor or Color3.fromRGB(90, 200, 255),
			m,
			cyl,
			{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
		)
	else
		-- unit AC di atap
		for i, off in { Vector3.new(-tw * 0.2, 0, td * 0.15), Vector3.new(tw * 0.2, 0, -td * 0.1) } do
			Kit.deco({
				Name = "AC" .. i,
				Size = Vector3.new(math.min(10, tw * 0.25), 4, math.min(8, td * 0.25)),
				CFrame = top * CFrame.new(off + Vector3.new(0, 2, 0)),
				Color = Color3.fromRGB(190, 195, 200),
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end

	if def.sign then
		local sw = math.min(tw - 4, #def.sign * 3.2 + 6)
		local front = if cyl then -tw / 2 else -td / 2
		local s = Kit.deco({
			Name = "Sign",
			Size = Vector3.new(sw, 5, 0.5),
			CFrame = base * CFrame.new(0, y0 - 8, front - 0.6),
			Color = def.signColor or Color3.fromRGB(240, 90, 90),
			Parent = m,
		})
		Kit.sign(s, def.sign, def.signText)
	end

	m.PrimaryPart = first
	m.Parent = parent
	return m
end

export type ShopDef = {
	name: string,
	x: number,
	z: number,
	yaw: number?,
	baseY: number?,
	w: number,
	d: number,
	h: number,
	floors: number,
	color: Color3,
	trim: Color3,
	material: Enum.Material?,
	sign: string,
	signColor: Color3,
	signText: Color3?,
	doors: { { x: number, w: number, h: number, color: Color3? } }?,
	storefront: boolean?,
	awning: Color3?,
}

-- Gedung rendah (toko, kantor, layanan): kaca etalase, jendela per lantai, pintu, papan nama.
function B.shop(def: ShopDef, parent: Instance): Model
	local m = Kit.model(def.name, nil)
	local base = CFrame.new(def.x, def.baseY or 1, def.z) * CFrame.Angles(0, def.yaw or 0, 0)
	local w, d, h = def.w, def.d, def.h
	local front = -d / 2
	local body = Kit.P({
		Name = "Body",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = def.color,
		Material = def.material or Enum.Material.SmoothPlastic,
		Parent = m,
	})
	Kit.P({
		Name = "Roof",
		Size = Vector3.new(w + 2, 1, d + 2),
		CFrame = base * CFrame.new(0, h + 0.5, 0),
		Color = def.trim,
		Parent = m,
	})

	local floorH = h / def.floors
	for f = 1, def.floors do
		if f == 1 and def.storefront then
			Kit.deco({
				Name = "Storefront",
				Size = Vector3.new(w - 4, floorH * 0.55, 0.2),
				CFrame = base * CFrame.new(0, floorH * 0.45, front - 0.1),
				Color = Kit.C.glass,
				Reflectance = 0.2,
				Parent = m,
			})
		elseif f > 1 then
			Kit.deco({
				Name = "Windows" .. f,
				Size = Vector3.new(w - 4, floorH * 0.45, 0.2),
				CFrame = base * CFrame.new(0, (f - 0.5) * floorH, front - 0.1),
				Color = Kit.C.glass,
				Reflectance = 0.2,
				Parent = m,
			})
		end
	end
	for i, door in def.doors or { { x = 0, w = 6, h = 6.5 } } do
		Kit.deco({
			Name = "Door" .. i,
			Size = Vector3.new(door.w, door.h, 0.3),
			CFrame = base * CFrame.new(door.x, door.h / 2, front - 0.2),
			Color = door.color or Kit.C.door,
			Parent = m,
		})
	end
	if def.awning then
		Kit.deco({
			Name = "Awning",
			Size = Vector3.new(w - 2, 0.5, 4),
			CFrame = base
				* CFrame.new(0, math.min(floorH - 1, 8), front - 2)
				* CFrame.Angles(math.rad(-12), 0, 0),
			Color = def.awning,
			Parent = m,
		})
	end
	local signH = 3
	local signY = if def.floors > 1 then floorH else h - signH / 2 - 0.5
	local sign = Kit.deco({
		Name = "Sign",
		Size = Vector3.new(math.min(w - 2, #def.sign * 2.2 + 4), signH, 0.4),
		CFrame = base * CFrame.new(0, signY, front - 0.45),
		Color = def.signColor,
		Parent = m,
	})
	Kit.sign(sign, def.sign, def.signText)
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Lampu lalu lintas hias; lengan (lokal -Z) menjorok ke jalan.
function B.trafficLight(pos: Vector3, yaw: number, parent: Instance, armLen: number?)
	local m = Kit.model("LampuLaluLintas", nil)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local len = armLen or 12
	local pole = Kit.P({
		Name = "Pole",
		Size = Vector3.new(0.7, 16, 0.7),
		CFrame = base * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(55, 60, 65),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	Kit.deco({
		Name = "Arm",
		Size = Vector3.new(0.5, 0.5, len),
		CFrame = base * CFrame.new(0, 15.5, -len / 2),
		Color = Color3.fromRGB(55, 60, 65),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local head = base * CFrame.new(0, 13, -len + 1)
	Kit.deco({
		Name = "Housing",
		Size = Vector3.new(1.6, 4.4, 1.2),
		CFrame = head,
		Color = Color3.fromRGB(35, 38, 40),
		Parent = m,
	})
	local colors =
		{ Color3.fromRGB(120, 40, 40), Color3.fromRGB(120, 100, 40), Color3.fromRGB(60, 255, 120) }
	for i, c in colors do
		Kit.deco({
			Name = "Lamp" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			CFrame = head * CFrame.new(0, 1.4 - (i - 1) * 1.4, 0.55),
			Color = c,
			Material = if i == 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Parent = m,
		})
	end
	m.PrimaryPart = pole
	m.Parent = parent
	return m
end

-- Lahan parkir: aspal + garis putih. Mobil masuk dari sisi depan (-Z lokal).
function B.parkingLot(name: string, cf: CFrame, w: number, d: number, parent: Instance)
	local m = Kit.model(name, nil)
	local lot = Kit.P({
		Name = "Lot",
		Size = Vector3.new(w, 0.3, d),
		CFrame = cf * CFrame.new(0, 0.15, 0),
		Color = Color3.fromRGB(70, 72, 78),
		Material = Enum.Material.Asphalt,
		Parent = m,
	})
	local rows = { -d / 4, d / 4 }
	for _, rz in rows do
		local x = -w / 2 + 6
		while x <= w / 2 - 6 do
			Kit.deco({
				Name = "Line",
				Size = Vector3.new(0.4, 0.05, d / 2 - 14),
				CFrame = cf * CFrame.new(x, 0.33, rz),
				Color = Kit.C.white,
				Parent = m,
			})
			x += 12
		end
	end
	m.PrimaryPart = lot
	m.Parent = parent
	return m
end

-- Air mancur bundar
function B.fountain(pos: Vector3, r: number, parent: Instance)
	local m = Kit.model("AirMancur", nil)
	local rim = Kit.P({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, r * 2, r * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(205, 205, 212),
		Material = Enum.Material.Marble,
		Parent = m,
	})
	Kit.deco({
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, r * 2 - 2, r * 2 - 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(80, 175, 235),
		Transparency = 0.25,
		Reflectance = 0.15,
		Parent = m,
	})
	Kit.P({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.5, 2.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(205, 205, 212),
		Material = Enum.Material.Marble,
		Parent = m,
	})
	Kit.deco({
		Name = "Spray",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		Position = pos + Vector3.new(0, 8.5, 0),
		Color = Color3.fromRGB(150, 210, 245),
		Transparency = 0.4,
		Parent = m,
	})
	m.PrimaryPart = rim
	m.Parent = parent
	return m
end

return B
