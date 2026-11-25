--!strict
--[[
	ROBLOCK CITY: empat bangunan dari Creator Store pilihan pemilik game (gratis), sudah dibersihkan.

	Templat ada di ServerStorage.AsetPihakKetiga (pivot = tengah alas, depan = arah LookVector):
	  Indomart   dari "Indomart" (12439758352): dipasang apa adanya sebagai properti hiasan, termasuk
	             papan nama aslinya (keputusan pemilik game); model ini memang tanpa skrip.
	  SevenEleven dari "7-eleven shop" (18862885800): dipasang apa adanya sebagai properti hiasan,
	             termasuk logo aslinya (keputusan pemilik game); model ini memang tanpa skrip.
	  Warung     dari "Warung" (9434810483): tampilan asli dipertahankan (properti hiasan); hanya 50
	             tali dan 33 kamera sisa yang dibuang. Model ini memang tanpa skrip.
	  RumahSakitSAMU dari "SAMU" (9224621435): dua ambulans berskrip (120 skrip A-Chassis) dibuang,
	             tinggal gedungnya (102 part) tanpa skrip.
	  Masjid     dari "Mosque / Masjid Jami Al" (12385631655): 50 skrip, suara, kipas, pengeras
	             suara, sirene, dan pernak-pernik kecil dibuang (1.457 part jadi 255), papan nama baru.
	Tidak ada skrip di keempatnya.

	Tiga toko berjajar di sisi timur Boulevard (antara kota kecil dan pusat kota), masjid di tepi
	Jalan Mawar. Skrip ini menaruh keempatnya di lahan rumput kosong itu, memindahkan pohon/semak yang
	tertimpa ke ServerStorage.CadanganPeta.DiLahanToko, dan memasang pelataran dari tepi jalan.
	Hasil di Workspace.Map.Toko; aman dijalankan ulang. Titiknya juga dicatat di MissionConfig.EXTRA_PLACES.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- front = titik tengah sisi depan bangunan (di tanah); facing = arah hadap depan.
local SITES: { any } = {
	{ template = "Indomart", front = Vector3.new(146, 0, 45), facing = Vector3.new(-1, 0, 0) },
	{ template = "SevenEleven", front = Vector3.new(146, 0, -35), facing = Vector3.new(-1, 0, 0) },
	{ template = "Warung", front = Vector3.new(146, 0, -100), facing = Vector3.new(-1, 0, 0) },
	{ template = "Masjid", front = Vector3.new(556, 0, -20), facing = Vector3.new(1, 0, 0) },
	-- Rumah sakit kota kecil: menggantikan tampilan gedung lama (disembunyikan, tidak dihapus). Pintu
	-- masuk ke lobi (Map.Interiors.RumahSakit.PintuMasuk) dan titik tugas dokter tetap di tempatnya.
	{
		template = "RumahSakitSAMU",
		front = Vector3.new(40, 1, 428),
		facing = Vector3.new(0, 0, 1),
		y = 1,
		apron = false,
		hide = { "Residential", "Buildings", "Downtown", "RumahSakit" },
	},
}
local APRON = 12 -- lebar pelataran di depan bangunan (stud)
local PLANTS = { "pohon", "semak", "bush", "bunga", "batu" }

local function groundY(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit =
		Workspace:Raycast(Vector3.new(position.X, 200, position.Z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else 0
end

return function(): number
	local map = Workspace:FindFirstChild("Map")
	local assets = ServerStorage:FindFirstChild("AsetPihakKetiga")
	if map == nil or assets == nil then
		warn("[BuildShops] Workspace.Map atau ServerStorage.AsetPihakKetiga tidak ditemukan")
		return 0
	end
	local old = map:FindFirstChild("Toko")
	if old then
		old:Destroy()
	end
	local backup = ServerStorage:FindFirstChild("CadanganPeta") or Instance.new("Folder")
	backup.Name = "CadanganPeta"
	backup.Parent = ServerStorage
	local bin = backup:FindFirstChild("DiLahanToko") or Instance.new("Folder")
	bin.Name = "DiLahanToko"
	bin.Parent = backup

	-- tanaman di peta (dicari sekali)
	local plants: { Instance } = {}
	for index, d in map:GetDescendants() do
		if index % 5000 == 0 then
			task.wait()
		end
		if d:IsA("Model") or d:IsA("MeshPart") then
			local name = d.Name:lower()
			for _, word in PLANTS do
				if name:find(word, 1, true) then
					table.insert(plants, d)
					break
				end
			end
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Toko"
	local count = 0
	for _, site in SITES do
		local template = assets:FindFirstChild(site.template)
		if template == nil or not template:IsA("Model") then
			warn("[BuildShops] templat tidak ada: " .. site.template)
			continue
		end
		local model = template:Clone()
		local y = site.y or groundY(site.front)
		if site.hide then
			local target: Instance? = map
			for _, name in site.hide do
				target = if target then target:FindFirstChild(name) else nil
			end
			if target then
				for _, d in target:GetDescendants() do
					if d:IsA("BasePart") then
						d.Transparency = 1
						d.CanCollide = false
						d.CanQuery = false
						d.CastShadow = false
					elseif d:IsA("SurfaceGui") then
						d.Enabled = false
					end
				end
			end
		end
		-- taruh dulu dengan pivot di titik depan, lalu geser mundur sampai sisi depannya pas di titik itu
		model:PivotTo(
			CFrame.lookAt(
				Vector3.new(site.front.X, y, site.front.Z),
				Vector3.new(site.front.X, y, site.front.Z) + site.facing
			)
		)
		local box, size = model:GetBoundingBox()
		local half = Vector3.new(size.X, 0, size.Z) / 2
		local reach = math.abs(box.RightVector:Dot(site.facing)) * half.X
			+ math.abs(box.LookVector:Dot(site.facing)) * half.Z
		local frontNow = (box.Position - model:GetPivot().Position):Dot(site.facing) + reach
		model:PivotTo(model:GetPivot() - site.facing * frontNow)
		model.Parent = folder
		count += 1

		-- tanaman yang tertimpa bangunan atau pelataran dipindah ke cadangan
		local center, extent = model:GetBoundingBox()
		local reachX = math.abs(center.RightVector.X) * extent.X / 2
			+ math.abs(center.LookVector.X) * extent.Z / 2
			+ 4
		local reachZ = math.abs(center.RightVector.Z) * extent.X / 2
			+ math.abs(center.LookVector.Z) * extent.Z / 2
			+ 4
		local mid = center.Position + site.facing * (APRON / 2)
		reachX += math.abs(site.facing.X) * APRON / 2
		reachZ += math.abs(site.facing.Z) * APRON / 2
		for _, plant in plants do
			if plant.Parent ~= nil and plant:IsDescendantOf(map) then
				local p = if plant:IsA("Model")
					then plant:GetPivot().Position
					else (plant :: BasePart).Position
				if
					math.abs(p.X - mid.X) < reachX
					and math.abs(p.Z - mid.Z) < reachZ
					and p.Y < 60
				then
					plant.Parent = bin
				end
			end
		end

		-- pelataran dari sisi depan bangunan ke arah jalan
		local side = Vector3.new(-site.facing.Z, 0, site.facing.X)
		local width = math.abs(center.RightVector:Dot(side)) * extent.X
			+ math.abs(center.LookVector:Dot(side)) * extent.Z
		if site.apron == false then
			task.wait()
			continue
		end
		local apron = Instance.new("Part")
		apron.Name = "Pelataran" .. site.template
		apron.Anchored = true
		apron.Size = Vector3.new(width + 4, 0.4, APRON)
		apron.CFrame = CFrame.lookAt(
			Vector3.new(site.front.X, y + 0.05, site.front.Z) + site.facing * (APRON / 2),
			Vector3.new(site.front.X, y + 0.05, site.front.Z) + site.facing * APRON
		)
		apron.Color = Color3.fromRGB(196, 196, 190)
		apron.Material = Enum.Material.Pavement
		apron.TopSurface = Enum.SurfaceType.Smooth
		apron.Parent = folder
		task.wait()
	end
	folder.Parent = map
	return count
end
