--!strict
--[[
	ROBLOCK CITY: bendera Merah Putih berkibar di dua tiang Balai Kota (buatan Blender: tools/blender/bendera.py).

	Aset Store "Bendera indo" TIDAK dipakai lagi: bingkainya berotasi -53,7 derajat dan kainnya miring, jadi hanya
	sudut bawah kain menyentuh tiang (bagian atas menjauh 1-3 stud). Gantinya: mesh sendiri, 16 bingkai gelombang
	dengan tepi tiang (x = 0 di Blender) yang tidak pernah bergerak, tiap bingkai terdiri dari dua mesh (BdMerahNN,
	BdPutihNN). Diunggah sebagai asset 76789167366217 dan dipasang di ServerStorage.BenderaMentah.
	Hasil: Workspace.Map.BangunanBlender.BalaiKota.Bendera {BenderaKiri, BenderaKanan, Berkibar}.
	Tepi kain 0,2 stud dari sumbu tiang (jari-jari tiang 0,35), bagian atas kain di y 16,2 (puncak tiang 17).
	Pusat bbox Blender (2,5; 0; 1,583); Blender (x, y, z) -> Roblox lokal (x, z, -y).
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local FRAMES = 16
local BL_CENTER = Vector3.new(2.5, 0, 1.583)
local FLAG_HEIGHT = 3.333
local POLES = { { name = "BenderaKiri", x = 136 }, { name = "BenderaKanan", x = 184 } }
local POLE_Z = 114.5
local TOP_Y = 16.2
local LOOK = { BdMerah = Color3.fromRGB(206, 17, 38), BdPutih = Color3.fromRGB(250, 250, 250) }

local ANIMATE = [[
-- Bendera Merah Putih berkibar: 16 bingkai (merah + putih per bingkai), hanya satu bingkai terlihat. 12 bingkai per detik.
local folder = script.Parent
local FRAMES = 16
local flags = {}
for _, flag in folder:GetChildren() do
	if flag:IsA("Model") then
		local frames = {}
		for i = 1, FRAMES do
			local id = string.format("%02d", i)
			frames[i] = { flag.Frames:FindFirstChild("BdMerah" .. id), flag.Frames:FindFirstChild("BdPutih" .. id) }
		end
		table.insert(flags, { frames = frames, shown = 1, offset = #flags * 5 })
	end
end
local function setFrame(frame, transparency)
	frame[1].Transparency = transparency
	frame[2].Transparency = transparency
end
while true do
	task.wait(1 / 12)
	local tick = math.floor(os.clock() * 12)
	for _, flag in flags do
		local nxt = (tick + flag.offset) % FRAMES + 1
		if nxt ~= flag.shown then
			setFrame(flag.frames[flag.shown], 1)
			setFrame(flag.frames[nxt], 0)
			flag.shown = nxt
		end
	end
end
]]

return function(): number
	local raw = ServerStorage:FindFirstChild("BenderaMentah")
	local balai = Workspace.Map.BangunanBlender:FindFirstChild("BalaiKota")
	if raw == nil or balai == nil then
		warn("[BenderaBalaiKota] ServerStorage.BenderaMentah (asset 76789167366217) atau BalaiKota tidak ada")
		return 0
	end
	for _, d in raw:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	local previous = balai:FindFirstChild("Bendera")
	if previous then
		previous:Destroy()
	end

	local parts: { MeshPart } = {}
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in raw:GetDescendants() do
		if p:IsA("MeshPart") then
			local half = p.Size / 2
			mn = mn:Min(p.Position - half)
			mx = mx:Max(p.Position + half)
			table.insert(parts, p)
		end
	end
	local rawCenter = (mn + mx) / 2
	-- rotasi bawaan part hasil impor FBX berbeda-beda (kelipatan 90 derajat); batalkan di sekitar pusat
	local r0 = select(2, parts[1].CFrame:ToOrientation())
	local undo = -(math.round(r0 / (math.pi / 2)) * (math.pi / 2) + math.pi)

	local folder = Instance.new("Folder")
	folder.Name = "Bendera"
	folder.Parent = balai
	for _, pole in POLES do
		local origin = Vector3.new(pole.x + 0.2, TOP_Y - FLAG_HEIGHT, POLE_Z) -- titik (0,0,0) Blender di dunia
		local center = CFrame.new(origin + Vector3.new(BL_CENTER.X, BL_CENTER.Z, -BL_CENTER.Y))
		local model = Instance.new("Model")
		model.Name = pole.name
		local frames = Instance.new("Folder")
		frames.Name = "Frames"
		frames.Parent = model
		for _, p in parts do
			local key = string.match(p.Name, "^%a+") :: string
			local idx = string.match(p.Name, "%d+$") :: string
			local clone = p:Clone()
			clone:ClearAllChildren()
			clone.CFrame = center * CFrame.Angles(0, undo, 0) * CFrame.new(p.Position - rawCenter) * p.CFrame.Rotation
			clone.Color, clone.Material = LOOK[key], Enum.Material.SmoothPlastic
			clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery, clone.CastShadow = true, false, false, false, false
			clone.Name = key .. idx
			clone.Transparency = if tonumber(idx) == 1 then 0 else 1
			clone.Parent = frames
		end
		model.Parent = folder
	end
	local script = Instance.new("Script")
	script.Name = "Berkibar"
	script.Source = ANIMATE
	script.Parent = folder
	return #POLES
end
