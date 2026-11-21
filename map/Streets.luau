--[[
	Streets: grid jalan lurus dengan persimpangan, marka, zebra cross, dan trotoar.
	Jalan: { name, axis = "x" (timur-barat di z = at) | "z" (utara-selatan di x = at),
	         at, from, to, w, lanes (2|4), zebraFrom?, zebraTo?, noWalk? }
	zebraFrom/zebraTo: tambahkan zebra cross di ujung yang menempel jalan lain (mis. jalan lingkar).
]]

local Kit = require(script.Parent.MapKit)

local St = {}

local function streetCF(s, along: number, y: number): CFrame
	if s.axis == "x" then
		return CFrame.new(along, y, s.at) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return CFrame.new(s.at, y, along)
end

function St.buildGrid(streets, parent: Instance, opt: { [string]: any }?)
	local o = opt or {}
	local C = Kit.C
	local TOP = Kit.ROAD_TOP
	local walkW = o.walkWidth or 6
	local walkTop = o.walkTop or 0.6
	local f = Kit.folder(o.name or "Roads")
	local segs = Kit.folder("Segments", f)
	local marks = Kit.folder("Markings", f)
	local inters = Kit.folder("Intersections", f)
	local walks = Kit.folder("Sidewalks", f)

	local cuts = {}
	for _, s in streets do
		cuts[s] = {}
	end
	for _, sx in streets do
		if sx.axis == "x" then
			for _, sz in streets do
				if
					sz.axis == "z"
					and sz.at >= sx.from - 0.5
					and sz.at <= sx.to + 0.5
					and sx.at >= sz.from - 0.5
					and sx.at <= sz.to + 0.5
				then
					table.insert(cuts[sx], { sz.at - sz.w / 2, sz.at + sz.w / 2 })
					table.insert(cuts[sz], { sx.at - sx.w / 2, sx.at + sx.w / 2 })
					Kit.P({
						Name = "Simpang",
						Size = Vector3.new(sz.w, TOP, sx.w),
						CFrame = CFrame.new(sz.at, TOP / 2, sx.at),
						Color = C.asphalt,
						Material = Enum.Material.Asphalt,
						Parent = inters,
					})
				end
			end
		end
	end

	local function segment(s, a: number, b: number, zA: boolean, zB: boolean)
		local len = b - a
		if len <= 1 then
			return
		end
		local w = s.w
		local cf = streetCF(s, (a + b) / 2, TOP / 2)
		Kit.P({
			Name = s.name,
			Size = Vector3.new(w, TOP, len),
			CFrame = cf,
			Color = C.asphalt,
			Material = Enum.Material.Asphalt,
			Parent = segs,
		})
		local my = TOP / 2 + 0.025
		local function line(x: number, l: number, zc: number, thick: number, color: Color3)
			Kit.deco({
				Name = "Line",
				Size = Vector3.new(thick, 0.05, l),
				CFrame = cf * CFrame.new(x, my, zc),
				Color = color,
				Parent = marks,
			})
		end
		for _, sd in { -1, 1 } do
			line(sd * (w / 2 - 1.5), len, 0, 0.5, C.white)
		end
		local z0 = -len / 2 + (if zA then 10 else 2)
		local z1 = len / 2 - (if zB then 10 else 2)
		local function dashes(x: number, color: Color3)
			local t = z0
			while t + 8 <= z1 do
				line(x, 8, t + 4, 0.5, color)
				t += 24
			end
		end
		if (s.lanes or 2) >= 4 then
			line(-0.5, len, 0, 0.35, C.yellow)
			line(0.5, len, 0, 0.35, C.yellow)
			dashes(-w / 4, C.white)
			dashes(w / 4, C.white)
		else
			dashes(0, C.yellow)
		end
		for _, e in { { zA, -len / 2 + 4 }, { zB, len / 2 - 4 } } do
			if e[1] then
				local x = -w / 2 + 4
				while x <= w / 2 - 4 do
					line(x, 6, e[2], 2.5, C.white)
					x += 5
				end
			end
		end
		if not s.noWalk then
			for _, sd in { -1, 1 } do
				Kit.P({
					Name = "Trotoar",
					Size = Vector3.new(walkW, walkTop, len),
					CFrame = streetCF(s, (a + b) / 2, walkTop / 2)
						* CFrame.new(sd * (w / 2 + walkW / 2), 0, 0),
					Color = C.walk,
					Material = Enum.Material.Concrete,
					Parent = walks,
				})
			end
		end
	end

	for _, s in streets do
		local list = cuts[s]
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		local pos = s.from
		local prev = s.zebraFrom == true
		for _, c in list do
			segment(s, pos, c[1], prev, true)
			pos = c[2]
			prev = true
		end
		segment(s, pos, s.to, prev, s.zebraTo == true)
	end

	Kit.flush(f, parent)
	return f
end

-- Titik-titik di sisi jalan (side = -1 / 1) untuk menaruh rumah/pohon/lampu.
-- Mengembalikan { pos: Vector3, yaw: number } dengan yaw menghadap ke jalan.
function St.sideSpots(
	s,
	side: number,
	offset: number,
	from: number,
	to: number,
	step: number,
	skip: { { number } }?
): { { pos: Vector3, yaw: number } }
	local out = {}
	local t = from
	while t <= to do
		local blocked = false
		for _, r in skip or {} do
			if t >= r[1] and t <= r[2] then
				blocked = true
			end
		end
		if not blocked then
			if s.axis == "x" then
				-- side -1 = utara (z lebih kecil) menghadap +Z
				table.insert(out, {
					pos = Vector3.new(t, 0, s.at + side * offset),
					yaw = if side < 0 then math.pi else 0,
				})
			else
				-- side -1 = barat (x lebih kecil) menghadap +X
				table.insert(out, {
					pos = Vector3.new(s.at + side * offset, 0, t),
					yaw = if side < 0 then -math.pi / 2 else math.pi / 2,
				})
			end
		end
		t += step
	end
	return out
end

return St
