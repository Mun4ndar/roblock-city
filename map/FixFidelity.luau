--!nocheck
-- FixFidelity: aturan RenderFidelity untuk Workspace.Map (jalankan di Studio, mode Edit).
-- Dinding/lantai/atap gedung adalah mesh tipis dan besar: pada "Automatic" dinding bisa tembus pandang
-- dari jauh, jadi cangkang bangunan dan semua mesh non-tanaman >= 3 stud memakai Precise.
-- Hanya dedaunan/pohon dan mesh kecil (< 3 stud) yang memakai Automatic (hemat di HP, tampilan sama).
-- Aman diulang. APPLY = false hanya menghitung.
local APPLY = true
local FOLIAGE = { "leaves", "leaf", "trunk", "daun", "pohon", "palm", "bush", "semak", "grass", "rumput", "flower", "bunga", "batang", "ranting", "pine", "cemara", "tree" }
local FOLIAGE_PARENT = { "pohon", "tree", "palm", "hutan", "scenery", "semak" }

local function isFoliage(d: Instance): boolean
	local n = d.Name:lower()
	for _, f in FOLIAGE do
		if n:find(f, 1, true) then
			return true
		end
	end
	local a = d.Parent
	while a and a ~= workspace.Map do
		local an = a.Name:lower()
		for _, f in FOLIAGE_PARENT do
			if an:find(f, 1, true) then
				return true
			end
		end
		a = a.Parent
	end
	return false
end

local changed = 0
for _, d in workspace.Map:GetDescendants() do
	if d:IsA("MeshPart") and d.RenderFidelity == Enum.RenderFidelity.Automatic then
		local s = d.Size
		if not isFoliage(d) and math.max(s.X, s.Y, s.Z) >= 3 then
			changed += 1
			if APPLY then
				d.RenderFidelity = Enum.RenderFidelity.Precise
			end
		end
	end
end
return changed
