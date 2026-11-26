--!nocheck
--[[
	ROBLOCK CITY: sambungan jalan Pelabuhan + loket feri (jalankan di Studio Edit lewat execute_luau; aman diulang).

	Masalah: Jalan Pantai (ujung selatan ~(1324,450)) berhenti di pasir 15 stud sebelum Terminal Feri, dan tidak ada
	jalan ke dermaga/kuay di belakang terminal.
	Hasil (Workspace.Map.Beach.Pelabuhan):
	  JalanPelabuhan : halaman aspal di depan terminal (x 1262..1366, z 438..465) menyatu dengan ujung Jalan Pantai,
	                   dua jalan samping (x 1248..1276 dan x 1352..1380) mengitari terminal sampai tepi kuay (z 500),
	                   tanjakan kecil ke atas kuay, garis tepi putih dan garis tengah putus-putus kuning.
	  LoketFeri      : teras + meja loket beratap di samping pintu terminal, papan "LOKET FERI", dan part
	                   "TitikPetugas" tempat PelabuhanService menaruh petugas.
]]

local pelabuhan = workspace.Map.Beach.Pelabuhan
for _, name in { "JalanPelabuhan", "LoketFeri" } do
	local old = pelabuhan:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local rgb = Color3.fromRGB
local ASPHALT = rgb(58, 60, 66)
local WHITE = rgb(245, 245, 245)
local YELLOW = rgb(250, 210, 60)
local ROAD_TOP = 0.4
local SP = Enum.Material.SmoothPlastic

local function part(parent, name, size, cf, color, material, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if canCollide == false then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------- jalan
local roads = Instance.new("Folder")
roads.Name = "JalanPelabuhan"

local function slab(name, x0, x1, z0, z1)
	part(
		roads,
		name,
		Vector3.new(x1 - x0, 0.4, z1 - z0),
		CFrame.new((x0 + x1) / 2, ROAD_TOP - 0.2, (z0 + z1) / 2),
		ASPHALT,
		Enum.Material.Asphalt
	)
end

slab("Halaman", 1262, 1366, 438, 465)
slab("JalanBarat", 1248, 1276, 438, 500)
slab("JalanTimur", 1352, 1380, 438, 500)

-- tanjakan ke kuay (permukaan kuay y = 1.0, aspal y = 0.4)
local rise = 0.6
local rampLen = 6
local angle = math.asin(rise / rampLen)
for _, cx in { 1262, 1366 } do
	part(
		roads,
		"Tanjakan",
		Vector3.new(28, 0.4, rampLen),
		CFrame.new(cx, ROAD_TOP + rise / 2 - 0.2, 500 + rampLen / 2 - 0.5) * CFrame.Angles(-angle, 0, 0),
		ASPHALT,
		Enum.Material.Asphalt
	)
end

-- marka: garis tepi putih + garis tengah putus-putus pada jalan samping
local function line(name, size, cf, color)
	part(roads, name, size, cf, color, SP, false)
end
for _, cx in { 1262, 1366 } do
	for _, sx in { -1, 1 } do
		line("GarisTepi", Vector3.new(0.5, 0.05, 62), CFrame.new(cx + sx * 12.5, ROAD_TOP + 0.03, 469), WHITE)
	end
	for z = 442, 494, 12 do
		line("GarisTengah", Vector3.new(0.5, 0.05, 6), CFrame.new(cx, ROAD_TOP + 0.03, z + 3), YELLOW)
	end
end
-- halaman: garis tepi depan + penyeberangan zebra ke pintu terminal
line("GarisTepiHalaman", Vector3.new(100, 0.05, 0.5), CFrame.new(1314, ROAD_TOP + 0.03, 439.5), WHITE)
for i = -3, 3 do
	line("Zebra", Vector3.new(1.6, 0.05, 9), CFrame.new(1314 + i * 3, ROAD_TOP + 0.03, 449), WHITE)
end
-- tempat parkir kecil (kotak putih) di depan teras
for i = 0, 5 do
	if i ~= 2 and i ~= 3 then
		line("Parkir", Vector3.new(0.4, 0.05, 8), CFrame.new(1272 + i * 17, ROAD_TOP + 0.03, 452), WHITE)
	end
end
roads.Parent = pelabuhan

-- ---------------------------------------------------------------- loket feri
local loket = Instance.new("Model")
loket.Name = "LoketFeri"
local CX, TOP = 1296, 0.8 -- tengah loket, permukaan teras
local FRONT = 458.6 -- sisi depan meja (menghadap jalan, -Z)

part(loket, "Teras", Vector3.new(86, 0.8, 7), CFrame.new(1314, 0.4, 461.5), rgb(214, 210, 200), Enum.Material.Concrete)
-- meja loket
part(loket, "Meja", Vector3.new(8, 3.2, 1.8), CFrame.new(CX, TOP + 1.6, FRONT + 0.9), rgb(30, 96, 190), SP)
part(loket, "MejaAtas", Vector3.new(8.8, 0.3, 2.6), CFrame.new(CX, TOP + 3.35, FRONT + 0.8), rgb(245, 245, 245), SP)
part(loket, "MejaGaris", Vector3.new(8.02, 0.5, 1.82), CFrame.new(CX, TOP + 2.2, FRONT + 0.9), rgb(210, 40, 48), SP)
-- komputer + mesin tiket di meja
part(loket, "Monitor", Vector3.new(1.8, 1.2, 0.2), CFrame.new(CX - 1.8, TOP + 4.5, FRONT + 1.5) * CFrame.Angles(math.rad(-12), 0, 0), rgb(30, 34, 44), SP)
part(loket, "MonitorLayar", Vector3.new(1.5, 0.9, 0.05), CFrame.new(CX - 1.8, TOP + 4.5, FRONT + 1.37) * CFrame.Angles(math.rad(-12), 0, 0), rgb(120, 200, 255), Enum.Material.Neon, false)
part(loket, "MonitorKaki", Vector3.new(0.3, 0.7, 0.3), CFrame.new(CX - 1.8, TOP + 3.85, FRONT + 1.6), rgb(30, 34, 44), SP)
part(loket, "MesinTiket", Vector3.new(1.4, 0.8, 1.0), CFrame.new(CX + 1.8, TOP + 3.85, FRONT + 1.2), rgb(220, 224, 230), SP)
part(loket, "Tiket", Vector3.new(0.7, 0.05, 1.0), CFrame.new(CX + 1.8, TOP + 4.3, FRONT + 0.6), rgb(255, 235, 120), SP, false)
-- kanopi: 4 tiang + atap
for _, dx in { -4.6, 4.6 } do
	for _, z in { FRONT - 0.4, 464 } do
		part(loket, "Tiang", Vector3.new(0.6, 9, 0.6), CFrame.new(CX + dx, TOP + 4.5, z), rgb(245, 245, 245), SP)
	end
end
part(loket, "Atap", Vector3.new(11.4, 0.6, 7.6), CFrame.new(CX, TOP + 9.3, 461.2), rgb(30, 96, 190), SP)
part(loket, "AtapGaris", Vector3.new(11.45, 0.2, 7.65), CFrame.new(CX, TOP + 8.95, 461.2), rgb(245, 245, 245), SP)
-- papan nama menggantung
local sign = part(loket, "Papan", Vector3.new(9, 2.2, 0.4), CFrame.new(CX, TOP + 7.5, FRONT - 0.5), rgb(30, 96, 190), SP)
local gui = Instance.new("SurfaceGui")
gui.Name = "TulisanLoket"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 50
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.Text = "LOKET FERI"
text.Font = Enum.Font.FredokaOne
text.TextScaled = true
text.TextColor3 = rgb(255, 255, 255)
text.Parent = gui
-- lampu jangkar kecil di sisi papan
part(loket, "Lampu", Vector3.new(0.8, 0.8, 0.8), CFrame.new(CX + 4.9, TOP + 7.5, FRONT - 0.5), rgb(255, 214, 90), Enum.Material.Neon, false)
part(loket, "Lampu", Vector3.new(0.8, 0.8, 0.8), CFrame.new(CX - 4.9, TOP + 7.5, FRONT - 0.5), rgb(255, 214, 90), Enum.Material.Neon, false)
-- titik berdiri petugas (menghadap -Z, ke jalan)
local spot = part(loket, "TitikPetugas", Vector3.new(1, 1, 1), CFrame.new(CX, TOP + 3.05, 462.3), WHITE, SP, false)
spot.Transparency = 1
loket.PrimaryPart = spot
loket.Parent = pelabuhan
return "ok"
