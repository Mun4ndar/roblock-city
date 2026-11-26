--!nocheck
-- Memasang feri Blender: ServerStorage.FeriMentah (hasil insert_asset FBX feri_blender.fbx) -> Workspace.Map.Beach.Pelabuhan.Feri.
-- Dijalankan di Studio (Edit) lewat execute_luau. Data (pusat bagian + kursi) datang dari map/FerryData.luau (koordinat Blender,
-- haluan -Y, atas +Z); koordinat model Roblox = (-bx, bz, by): haluan = -Z (LookVector) dan tanpa cermin.
-- Idempoten: menghapus Feri / KapalFeriMeshy lama sebelum membangun. Warna tiap bagian menurut nama bahan.
local ServerStorage = game:GetService("ServerStorage")
local DATA = DATA_DARI_FerryData -- (ditempel saat menjalankan: isi `return {...}` FerryData.luau)

local WATER_Y = -1.6
local BERTH = Vector3.new(1304, WATER_Y, 658)
local rgb = Color3.fromRGB

local LOOK = {
	Bawah = { rgb(18, 33, 76), Enum.Material.SmoothPlastic },
	Garis = { rgb(200, 26, 32), Enum.Material.SmoothPlastic },
	Badan = { rgb(246, 247, 250), Enum.Material.SmoothPlastic },
	Geladak = { rgb(176, 128, 80), Enum.Material.WoodPlanks },
	Putih = { rgb(246, 247, 250), Enum.Material.SmoothPlastic },
	Kayu = { rgb(140, 92, 52), Enum.Material.Wood },
	Jok = { rgb(26, 92, 184), Enum.Material.Fabric },
	Besi = { rgb(190, 196, 206), Enum.Material.Metal },
	Kaca = { rgb(70, 120, 160), Enum.Material.Glass, 0.25 },
	Hitam = { rgb(24, 24, 28), Enum.Material.SmoothPlastic },
	Merah = { rgb(214, 30, 30), Enum.Material.SmoothPlastic },
	Oranye = { rgb(255, 140, 26), Enum.Material.SmoothPlastic },
	Kuning = { rgb(255, 210, 40), Enum.Material.Neon },
	LampuMerah = { rgb(255, 40, 40), Enum.Material.Neon },
	LampuHijau = { rgb(40, 230, 80), Enum.Material.Neon },
	Biru = { rgb(26, 92, 184), Enum.Material.SmoothPlastic },
}

local pelabuhan = workspace.Map.Beach.Pelabuhan
for _, name in { "Feri", "KapalFeriMeshy" } do
	local old = pelabuhan:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local raw = ServerStorage:FindFirstChild("FeriMentah")
assert(raw, "ServerStorage.FeriMentah belum ada (insert_asset 87542642464903)")
local meshes = {}
for _, d in raw:GetDescendants() do
	if d:IsA("MeshPart") then
		meshes[d.Name] = d
	end
end

local berth = CFrame.lookAt(BERTH, BERTH + Vector3.new(1, 0, 0))
local model = Instance.new("Model")
model.Name = "Feri"
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local akar = Instance.new("Part")
akar.Name = "Akar"
akar.Size = Vector3.new(2, 2, 2)
akar.Transparency = 1
akar.CanCollide, akar.CanTouch, akar.CanQuery, akar.CastShadow = false, false, false, false
akar.Anchored = true
akar.CFrame = berth
akar.Parent = model
model.PrimaryPart = akar

local made, missing = 0, {}
for name, info in DATA.parts do
	local src = meshes[name]
	if src == nil then
		table.insert(missing, name)
		continue
	end
	local part = src:Clone()
	part.Name = name
	local c = info.center
	part.CFrame = berth * CFrame.new(-c.X, c.Z, c.Y)
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = true
	local look = LOOK[name] or { rgb(200, 200, 200), Enum.Material.SmoothPlastic }
	part.Color = look[1]
	part.Material = look[2]
	part.Transparency = look[3] or 0
	part.Parent = model
	made += 1
end

for i, s in DATA.seats do
	local seat = Instance.new("Seat")
	seat.Name = "KursiFeri"
	seat.Size = Vector3.new(2.4, 0.4, 2.4)
	seat.Transparency = 1
	seat.Anchored = true
	seat.CanCollide, seat.CanTouch, seat.CanQuery = false, false, false
	local at = Vector3.new(-s[1], s[3] - 0.2, s[2]) -- kursi.y = permukaan bantalan - 0.2
	seat.CFrame = berth * CFrame.lookAt(at, at + Vector3.new(0, 0, s[4]))
	seat.Parent = model
end

model.Parent = pelabuhan
return `Feri: {made} bagian, {#DATA.seats} kursi, hilang: {table.concat(missing, ",")}`
