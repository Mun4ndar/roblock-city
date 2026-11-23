--[[
	ROBLOCK CITY: pemadatan peta (dijalankan SEKALI pada 2026-11-24, place v113; v108 = sebelum pemadatan).

	Pemain kebingungan karena peta terlalu renggang, jadi ruang kosong dipotong:
	  1. Pulau Pantai dirapatkan ke sisi timur kota. Jalur x 944..1400 (laut + jembatan panjang)
	     dihapus dan pulaunya ikut digeser z -240 supaya jalan masuknya menyambung lurus dengan
	     Jalan Selatan di simpang (900, -240).
	  2. Jalur taman kosong z -216..20 di antara pusat kota dan perumahan dihapus. 7-Eleven, Warung,
	     Masjid, dan lapangan basket dipindah dulu ke lahan kosong; Taman Kota dibangun ulang di
	     lahan kosong timur Jalan Mawar, pusat (740, 55).
	  3. Sungai, jalan desa, dan bukit di sambungan dirapikan (lihat RIVER dan COUNTRY_ROAD di bawah).
	  4. Gunung terrain bertingkat diganti mesh "Low Poly Mountain" (Creator Store 15173362991, tanpa
	     skrip; templat ServerStorage.AsetPihakKetiga.GunungLowPoly) -> Workspace.Map.Gunung.

	PENTING: pembangun lain di map/ (BuildWorld, BuildDowntown, dst.) dan tabel koordinat di
	skrip Style* masih memakai koordinat LAMA. Pakai Compact.remap(x, z) untuk mengubahnya, atau
	jalankan pembangun lalu potong ulang dengan Compact.cut seperti urutan di bawah. Koordinat di
	src/ (JobConfig.PLACES, MissionConfig, PlaneConfig, BoatConfig, VehicleConfig, MapData) sudah
	memakai koordinat baru.

	Urutan yang dipakai (mode Edit):
	  cut("X", 944, 1400, Vector3.new(0, 0, -240), semua part)          -- pantai
	  cut("Z", -216, 20, Vector3.zero, part dengan x < 944, kecuali Bundaran dan JalanDesa)
	  terrain: salin pulau pantai (x 1336..2200, z -600..780; air dijadikan udara), kosongkan jadi
	  laut, geser terrain z >= 20 ke z = -216 per lajur 392 stud, tempel pulau pantai di
	  (880, -840) tanpa sel kosong, isi rumput x 880..1100.
]]

local Compact = {}

Compact.BEACH_BAND = { 944, 1400 } -- sumbu X
Compact.BEACH_SHIFT_Z = -240
Compact.PARK_BAND = { -216, 20 } -- sumbu Z

-- Titik belok baru sesudah pemadatan
Compact.RIVER = {
	Vector2.new(-960, -470),
	Vector2.new(-935, -385),
	Vector2.new(-900, -330),
	Vector2.new(-830, -255),
	Vector2.new(-640, -36),
	Vector2.new(-610, 184),
	Vector2.new(-600, 464),
	Vector2.new(-575, 714),
	Vector2.new(-560, 1084),
}
-- Kit.smooth(titik, 60, 8), lebar 28
Compact.COUNTRY_ROAD = {
	Vector2.new(-950, -262),
	Vector2.new(-1150, -86),
	Vector2.new(-1100, 64),
	Vector2.new(-740, 64),
}
-- Gunung mesh: x, z, skala, putaran derajat
Compact.PEAKS = {
	{ -1150, -950, 1.3, 20 },
	{ -850, -1080, 0.85, 95 },
	{ -1380, -640, 0.75, 200 },
	{ -1330, -1160, 0.8, 140 },
	{ -950, -712, 0.55, 300 },
}

-- Koordinat lama (sebelum pemadatan) -> koordinat baru.
function Compact.remap(x: number, z: number): (number, number)
	if x > Compact.BEACH_BAND[1] then
		return x - (Compact.BEACH_BAND[2] - Compact.BEACH_BAND[1]), z + Compact.BEACH_SHIFT_Z
	end
	local a, b = Compact.PARK_BAND[1], Compact.PARK_BAND[2]
	if z >= b then
		return x, z - (b - a)
	elseif z > a then
		return x, a
	end
	return x, z
end

local function topModel(map: Instance, part: Instance): Model?
	local top: Model? = nil
	local current = part.Parent
	while current and current ~= map do
		if current:IsA("Model") then
			top = current
		end
		current = current.Parent
	end
	return top
end

-- Sumbu lokal part yang sejajar sumbu dunia; nil kalau part miring.
local function localAxis(part: BasePart, axis: string): string?
	local world = if axis == "X" then Vector3.xAxis else Vector3.zAxis
	local cf = part.CFrame
	if math.abs(cf.RightVector:Dot(world)) > 0.9995 then
		return "X"
	elseif math.abs(cf.UpVector:Dot(world)) > 0.9995 then
		return "Y"
	elseif math.abs(cf.LookVector:Dot(world)) > 0.9995 then
		return "Z"
	end
	return nil
end

--[[
	Menghapus jalur a..b pada sumbu "X"/"Z" dari Workspace.Map:
	  - Model (unit utuh) di seberang b digeser, yang pusatnya di dalam jalur dihapus.
	  - Part lepas yang panjang (>= 40) dan sejajar sumbu (jalan, trotoar, garis) dipendekkan.
	  - Part lepas lain digeser atau dihapus menurut pusatnya.
	extra = geseran tambahan untuk semua yang pindah. filter memilih part yang ikut.
	Terrain tidak disentuh (lihat catatan di atas).
]]
function Compact.cut(
	axis: string,
	a: number,
	b: number,
	extra: Vector3,
	filter: (BasePart) -> boolean
): (number, number, number)
	local map = workspace:FindFirstChild("Map") :: Instance
	local d = b - a
	local step = Vector3.new(if axis == "X" then -d else 0, 0, if axis == "Z" then -d else 0)
		+ extra
	local function f(v: number): number
		return if v <= a then v elseif v >= b then v - d else a
	end
	local units: { [Model]: boolean } = {}
	local loose: { BasePart } = {}
	for _, inst in map:GetDescendants() do
		if inst:IsA("BasePart") and filter(inst) then
			local model = topModel(map, inst)
			if model then
				units[model] = true
			else
				table.insert(loose, inst)
			end
		end
	end
	local shifted, deleted, squashed = 0, 0, 0
	local count = 0
	for model in units do
		local v = (model:GetBoundingBox().Position :: any)[axis]
		if v >= b then
			model:PivotTo(model:GetPivot() + step)
			shifted += 1
		elseif v > a then
			model:Destroy()
			deleted += 1
		end
		count += 1
		if count % 300 == 0 then
			task.wait()
		end
	end
	for _, part in loose do
		local cf, s = part.CFrame, part.Size
		local world = if axis == "X" then Vector3.xAxis else Vector3.zAxis
		local half = (
			math.abs(cf.RightVector:Dot(world)) * s.X
			+ math.abs(cf.UpVector:Dot(world)) * s.Y
			+ math.abs(cf.LookVector:Dot(world)) * s.Z
		) / 2
		local c = (part.Position :: any)[axis]
		local lo, hi = c - half, c + half
		if hi > a then
			local la = localAxis(part, axis)
			local block = not part:IsA("Part") or part.Shape == Enum.PartType.Block
			if la and block and hi - lo >= 40 and lo < b and (lo < a or hi > b) then
				local nlo, nhi = f(lo), f(hi)
				local len = nhi - nlo
				if len < 0.5 then
					part:Destroy()
					deleted += 1
				else
					part.Size = Vector3.new(
						if la == "X" then len else s.X,
						if la == "Y" then len else s.Y,
						if la == "Z" then len else s.Z
					)
					local mid = (nlo + nhi) / 2
					local p = part.Position
					part.Position = Vector3.new(
						if axis == "X" then mid else p.X,
						p.Y,
						if axis == "Z" then mid else p.Z
					) + extra
					squashed += 1
				end
			elseif c >= b then
				part.Position += step
				shifted += 1
			elseif c > a then
				part:Destroy()
				deleted += 1
			end
		end
		count += 1
		if count % 400 == 0 then
			task.wait()
		end
	end
	return shifted, deleted, squashed
end

return Compact
