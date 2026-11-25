--!strict
-- RoadRouter: mencari rute LEWAT JALAN (bukan garis lurus) memakai data jalan di MapData.
-- Jalan digambar ke kisi sel 6 stud, lalu dicari dengan A*: sel dekat tepi jalan lebih mahal supaya rute
-- cenderung lewat tengah jalan, dan hasilnya diluruskan jadi sedikit titik belok.
-- Murni hitungan (tanpa Instance), jadi aman dipakai di client maupun server.

local MapData = require(script.Parent:WaitForChild("MapData"))

local RoadRouter = {}

export type Route = {
	points: { Vector3 }, -- titik rute berurutan (Y = 0)
	cumulative: { number }, -- jarak dari titik awal sampai titik ke-i
	length: number, -- panjang total (stud)
}

local CELL = 6
local PAD = 60
local SEARCH_RADIUS = 360 -- stud: sejauh ini titik awal/tujuan dicarikan jalan terdekat

local bounds = MapData.BOUNDS
local minX = bounds.minX - PAD
local minZ = bounds.minZ - PAD
local cols = math.ceil((bounds.maxX + PAD - minX) / CELL)
local rows = math.ceil((bounds.maxZ + PAD - minZ) / CELL)

local roadGrid: buffer? = nil -- 1 = jalan
local clearGrid: buffer? = nil -- jarak ke tepi jalan (satuan setengah sel, maks 255)
local compGrid: buffer? = nil
local mainId = 0

local DIRS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, 1.4142 },
	{ -1, 1, 1.4142 },
	{ 1, -1, 1.4142 },
	{ -1, -1, 1.4142 },
}

local function build()
	if roadGrid then
		return
	end
	local grid = buffer.create(cols * rows)
	for _, r in MapData.ROADS :: { { number } } do
		if r[6] ~= 2 then
			local x, z, sx, sz = r[1], r[2], r[3], r[4]
			local rad = math.rad(r[5])
			local c, s = math.cos(rad), math.sin(rad)
			local reach = math.sqrt(sx * sx + sz * sz) / 2
			local c0 = math.max(0, math.floor((x - reach - minX) / CELL))
			local c1 = math.min(cols - 1, math.floor((x + reach - minX) / CELL))
			local r0 = math.max(0, math.floor((z - reach - minZ) / CELL))
			local r1 = math.min(rows - 1, math.floor((z + reach - minZ) / CELL))
			local hx, hz = sx / 2, sz / 2
			for row = r0, r1 do
				local dz = minZ + (row + 0.5) * CELL - z
				for col = c0, c1 do
					local dx = minX + (col + 0.5) * CELL - x
					local inside
					if r[6] == 1 then
						inside = dx * dx + dz * dz <= hx * hx
					else
						local lx = dx * c - dz * s
						local lz = dx * s + dz * c
						inside = math.abs(lx) <= hx and math.abs(lz) <= hz
					end
					if inside then
						buffer.writeu8(grid, row * cols + col, 1)
					end
				end
			end
		end
	end
	-- jarak ke tepi (chamfer 2 lintasan; satuan 0.5 sel: tegak 2, miring 3)
	local clear = buffer.create(cols * rows)
	for i = 0, cols * rows - 1 do
		if buffer.readu8(grid, i) == 1 then
			buffer.writeu8(clear, i, 255)
		end
	end
	local function at(col: number, row: number): number
		if col < 0 or col >= cols or row < 0 or row >= rows then
			return 0
		end
		return buffer.readu8(clear, row * cols + col)
	end
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local i = row * cols + col
			local v = buffer.readu8(clear, i)
			if v > 0 then
				v = math.min(v, at(col - 1, row) + 2, at(col, row - 1) + 2)
				v = math.min(v, at(col - 1, row - 1) + 3, at(col + 1, row - 1) + 3)
				buffer.writeu8(clear, i, v)
			end
		end
	end
	for row = rows - 1, 0, -1 do
		for col = cols - 1, 0, -1 do
			local i = row * cols + col
			local v = buffer.readu8(clear, i)
			if v > 0 then
				v = math.min(v, at(col + 1, row) + 2, at(col, row + 1) + 2)
				v = math.min(v, at(col + 1, row + 1) + 3, at(col - 1, row + 1) + 3)
				buffer.writeu8(clear, i, v)
			end
		end
	end
	roadGrid = grid
	clearGrid = clear
	-- komponen jalan yang tersambung; hanya jaringan terbesar dipakai sebagai titik awal/tujuan rute
	local comp = buffer.create(cols * rows * 2)
	local bestId, bestSize, nextId = 0, 0, 0
	for start = 0, cols * rows - 1 do
		if buffer.readu8(grid, start) == 1 and buffer.readu16(comp, start * 2) == 0 then
			nextId += 1
			local stack, size = { start }, 0
			buffer.writeu16(comp, start * 2, nextId)
			while #stack > 0 do
				local node = table.remove(stack) :: number
				size += 1
				local row = node // cols
				local col = node - row * cols
				for _, d in DIRS do
					local nc, nr = col + d[1], row + d[2]
					if nc >= 0 and nc < cols and nr >= 0 and nr < rows then
						local n = nr * cols + nc
						if buffer.readu8(grid, n) == 1 and buffer.readu16(comp, n * 2) == 0 then
							buffer.writeu16(comp, n * 2, nextId)
							table.insert(stack, n)
						end
					end
				end
			end
			if size > bestSize then
				bestId, bestSize = nextId, size
			end
		end
	end
	compGrid = comp
	mainId = bestId
end

local function cellOf(x: number, z: number): (number, number)
	return math.floor((x - minX) / CELL), math.floor((z - minZ) / CELL)
end

local function isRoadCell(col: number, row: number): boolean
	if col < 0 or col >= cols or row < 0 or row >= rows then
		return false
	end
	return buffer.readu8(roadGrid :: buffer, row * cols + col) == 1
end

local function isMainCell(col: number, row: number): boolean
	if not isRoadCell(col, row) then
		return false
	end
	return buffer.readu16(compGrid :: buffer, (row * cols + col) * 2) == mainId
end

local function clearAt(col: number, row: number): number
	if col < 0 or col >= cols or row < 0 or row >= rows then
		return 0
	end
	return buffer.readu8(clearGrid :: buffer, row * cols + col)
end

-- Apakah titik dunia (x, z) ada di jalan.
function RoadRouter.isOnRoad(x: number, z: number): boolean
	build()
	local col, row = cellOf(x, z)
	return isRoadCell(col, row)
end

-- Sel jalan terdekat dari titik dunia (pencarian melingkar); nil bila terlalu jauh.
local function snap(x: number, z: number): (number?, number?)
	local col0, row0 = cellOf(x, z)
	if isMainCell(col0, row0) then
		return col0, row0
	end
	local maxRing = math.ceil(SEARCH_RADIUS / CELL)
	local bestCol, bestRow, bestDist = nil, nil, math.huge
	for ring = 1, maxRing do
		if bestDist <= (ring - 1) * CELL then
			break
		end
		for dr = -ring, ring do
			for dc = -ring, ring do
				if math.max(math.abs(dr), math.abs(dc)) == ring then
					local col, row = col0 + dc, row0 + dr
					if isMainCell(col, row) then
						local cx, cz = minX + (col + 0.5) * CELL, minZ + (row + 0.5) * CELL
						local d = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
						if d < bestDist then
							bestCol, bestRow, bestDist = col, row, d
						end
					end
				end
			end
		end
	end
	if bestDist > SEARCH_RADIUS then
		return nil, nil
	end
	return bestCol, bestRow
end

-- Titik jalan terdekat (untuk uji).
function RoadRouter.nearestRoad(position: Vector3): Vector3?
	build()
	local col, row = snap(position.X, position.Z)
	if col == nil or row == nil then
		return nil
	end
	return Vector3.new(minX + (col + 0.5) * CELL, 0, minZ + (row + 0.5) * CELL)
end

-- ---------------------------------------------------------------- A*

local function findCells(
	startCol: number,
	startRow: number,
	goalCol: number,
	goalRow: number,
	yieldFn: (() -> ())?
): { number }?
	local heapF: { number } = {}
	local heapN: { number } = {}
	local size = 0
	local function push(f: number, node: number)
		size += 1
		local i = size
		heapF[i], heapN[i] = f, node
		while i > 1 do
			local parent = i // 2
			if heapF[parent] <= heapF[i] then
				break
			end
			heapF[parent], heapF[i] = heapF[i], heapF[parent]
			heapN[parent], heapN[i] = heapN[i], heapN[parent]
			i = parent
		end
	end
	local function pop(): (number, number)
		local f, node = heapF[1], heapN[1]
		heapF[1], heapN[1] = heapF[size], heapN[size]
		heapF[size], heapN[size] = nil, nil
		size -= 1
		local i = 1
		while true do
			local l, r = i * 2, i * 2 + 1
			local m = i
			if l <= size and heapF[l] < heapF[m] then
				m = l
			end
			if r <= size and heapF[r] < heapF[m] then
				m = r
			end
			if m == i then
				break
			end
			heapF[m], heapF[i] = heapF[i], heapF[m]
			heapN[m], heapN[i] = heapN[i], heapN[m]
			i = m
		end
		return f, node
	end

	local startNode = startRow * cols + startCol
	local goalNode = goalRow * cols + goalCol
	local g: { [number]: number } = { [startNode] = 0 }
	local came: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local function h(col: number, row: number): number
		return math.sqrt((col - goalCol) ^ 2 + (row - goalRow) ^ 2)
	end
	push(h(startCol, startRow), startNode)
	local expanded = 0
	while size > 0 do
		local _, node = pop()
		if node == goalNode then
			local cells = { node }
			while came[node] do
				node = came[node]
				table.insert(cells, 1, node)
			end
			return cells
		end
		if not closed[node] then
			closed[node] = true
			expanded += 1
			if yieldFn and expanded % 3000 == 0 then
				yieldFn()
			end
			local row = node // cols
			local col = node - row * cols
			local gHere = g[node]
			for _, d in DIRS do
				local nc, nr = col + d[1], row + d[2]
				if
					isRoadCell(nc, nr)
					and (d[3] == 1 or (isRoadCell(col + d[1], row) and isRoadCell(col, row + d[2])))
				then
					local nextNode = nr * cols + nc
					if not closed[nextNode] then
						local clear = clearAt(nc, nr) / 2
						local penalty = math.max(0, 3 - clear) * 0.6
						local cost = gHere + d[3] * (1 + penalty)
						local old = g[nextNode]
						if old == nil or cost < old then
							g[nextNode] = cost
							came[nextNode] = node
							push(cost + h(nc, nr), nextNode)
						end
					end
				end
			end
		end
	end
	return nil
end

-- Luruskan jalur sel: lompat ke titik terjauh yang masih terlihat dan tetap di dalam jalan.
local function lineClear(ax: number, az: number, bx: number, bz: number, minClear: number): boolean
	local dx, dz = bx - ax, bz - az
	local dist = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(dist / (CELL * 0.5)))
	for i = 0, steps do
		local t = i / steps
		local col, row = cellOf(ax + dx * t, az + dz * t)
		if clearAt(col, row) < minClear then
			return false
		end
	end
	return true
end

local function simplify(cells: { number }): { Vector3 }
	local pts: { Vector3 } = {}
	for _, node in cells do
		local row = node // cols
		local col = node - row * cols
		table.insert(pts, Vector3.new(minX + (col + 0.5) * CELL, 0, minZ + (row + 0.5) * CELL))
	end
	if #pts <= 2 then
		return pts
	end
	local out: { Vector3 } = { pts[1] }
	local i = 1
	while i < #pts do
		local from = pts[i]
		local fc, fr = cellOf(from.X, from.Z)
		local best = i + 1
		for j = #pts, i + 2, -1 do
			local to = pts[j]
			local tc, tr = cellOf(to.X, to.Z)
			local need = math.min(4, math.max(clearAt(fc, fr), clearAt(tc, tr)))
			if lineClear(from.X, from.Z, to.X, to.Z, need) then
				best = j
				break
			end
		end
		table.insert(out, pts[best])
		i = best
	end
	return out
end

local function toRoute(points: { Vector3 }): Route
	local cumulative = { 0 }
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
		cumulative[i] = length
	end
	return { points = points, cumulative = cumulative, length = length }
end

-- Rute dari `from` ke `to`. `yieldFn` (opsional) dipanggil berkala supaya pencarian panjang tidak
-- membekukan layar. Hasil nil = tidak ada jalan yang menyambung (pemanggil boleh pakai garis lurus).
function RoadRouter.route(from: Vector3, to: Vector3, yieldFn: (() -> ())?): Route?
	build()
	local sc, sr = snap(from.X, from.Z)
	local gc, gr = snap(to.X, to.Z)
	if sc == nil or sr == nil or gc == nil or gr == nil then
		return nil
	end
	local cells = findCells(sc, sr, gc, gr, yieldFn)
	if cells == nil then
		return nil
	end
	local mid = simplify(cells)
	local points: { Vector3 } = {}
	local start = Vector3.new(from.X, 0, from.Z)
	local finish = Vector3.new(to.X, 0, to.Z)
	table.insert(points, start)
	for index, p in mid do
		local skip = (index == 1 and (p - start).Magnitude < CELL)
			or (index == #mid and (p - finish).Magnitude < CELL)
		if not skip then
			table.insert(points, p)
		end
	end
	table.insert(points, finish)
	return toRoute(points)
end

-- Posisi `position` terhadap rute. `hint` = indeks segmen terakhir yang diketahui (pencarian dimulai dari
-- sana supaya rute yang berkelok tidak salah menempel). Mengembalikan: indeks segmen, titik terdekat pada
-- rute, jarak ke rute, dan sisa jarak sampai tujuan.
function RoadRouter.progress(
	route: Route,
	position: Vector3,
	hint: number?
): (number, Vector3, number, number)
	local pts = route.points
	local flat = Vector3.new(position.X, 0, position.Z)
	local start = hint or 1
	local first = math.max(1, start - 1)
	local last = math.min(#pts - 1, start + 40)
	local bestIndex, bestPoint, bestDist = first, pts[first], math.huge
	for i = first, last do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab.X * ab.X + ab.Z * ab.Z
		local t = if len2 > 0 then math.clamp(((flat - a):Dot(ab)) / len2, 0, 1) else 0
		local p = a + ab * t
		local d = (flat - p).Magnitude
		if d < bestDist then
			bestIndex, bestPoint, bestDist = i, p, d
		end
	end
	local remaining = route.length
		- (route.cumulative[bestIndex] + (bestPoint - pts[bestIndex]).Magnitude)
	return bestIndex, bestPoint, bestDist, math.max(0, remaining)
end

-- Titik `ahead` stud di depan titik `from` (yang berada di segmen `index`) menurut rute.
function RoadRouter.pointAhead(route: Route, index: number, from: Vector3, ahead: number): Vector3
	local pts = route.points
	local remaining = ahead
	local current = Vector3.new(from.X, 0, from.Z)
	for i = index + 1, #pts do
		local step = (pts[i] - current).Magnitude
		if step >= remaining and step > 0 then
			return current:Lerp(pts[i], remaining / step)
		end
		remaining -= step
		current = pts[i]
	end
	return pts[#pts]
end

-- Untuk uji: jumlah sel jalan dan ukuran kisi.
function RoadRouter.stats(): (number, number, number)
	build()
	local n = 0
	for i = 0, cols * rows - 1 do
		n += buffer.readu8(roadGrid :: buffer, i)
	end
	return n, cols, rows
end

return RoadRouter
