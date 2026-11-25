--!strict
--[[
	ROBLOCK CITY: bendera Merah Putih berkibar di dua tiang Balai Kota.

	Aset Creator Store gratis 133453531685810 ("Bendera indo", Pamiix2908): model berisi 32 bingkai MeshPart
	(Flag.Flag.1..32, tekstur merah-putih). Skrip bawaannya TIDAK dipakai (hanya Animate sederhana, diganti
	skrip "Berkibar" buatan sendiri di bawah). Templat mentah dipasang sementara di ServerStorage.UjiBendera1,
	dihapus setelah dipasang. Hasil: Workspace.Map.BangunanBlender.BalaiKota.Bendera {BenderaKiri, BenderaKanan, Berkibar}.
	Skala 0,22 (kain sekitar 5,2 x 3,8 stud), tepi kiri tiap bingkai menempel tiang (x 136 dan 184, z 114,5), bagian atas kain di y 16,2 (puncak tiang 17).
	Kain bendera lama (BkFlag1 biru, BkFlag2 emas) di mesh Balai Kota dihapus.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SCALE = 0.22
local POLES = { { name = "BenderaKiri", x = 136, z = 114.5 }, { name = "BenderaKanan", x = 184, z = 114.5 } }

local ANIMATE = [[
-- Bendera Merah Putih berkibar: 32 bingkai mesh, hanya satu yang terlihat (12 bingkai per detik).
local folder = script.Parent
local flags = {}
for _, flag in folder:GetChildren() do
	if flag:IsA("Model") then
		local frames = {}
		for i = 1, 32 do
			frames[i] = flag.Frames:FindFirstChild(tostring(i))
		end
		table.insert(flags, { frames = frames, shown = 1, offset = #flags * 9 })
	end
end
while true do
	task.wait(1 / 12)
	local tick = math.floor(os.clock() * 12)
	for _, flag in flags do
		local nxt = (tick + flag.offset) % 32 + 1
		if nxt ~= flag.shown then
			flag.frames[flag.shown].Transparency = 1
			flag.frames[nxt].Transparency = 0
			flag.shown = nxt
		end
	end
end
]]

return function(): number
	local template = ServerStorage:FindFirstChild("UjiBendera1")
	local balai = Workspace.Map.BangunanBlender:FindFirstChild("BalaiKota")
	if template == nil or balai == nil then
		warn("[BenderaBalaiKota] templat UjiBendera1 (asset 133453531685810) atau BalaiKota tidak ada")
		return 0
	end
	local source = template["Bendera indo"].Flag.Flag
	for _, name in { "BkFlag1", "BkFlag2" } do
		local cloth = balai:FindFirstChild(name)
		if cloth then
			cloth:Destroy()
		end
	end
	local previous = balai:FindFirstChild("Bendera")
	if previous then
		previous:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bendera"
	folder.Parent = balai
	for _, pole in POLES do
		local model = Instance.new("Model")
		model.Name = pole.name
		local frames = Instance.new("Folder")
		frames.Name = "Frames"
		frames.Parent = model
		for _, part in source:GetChildren() do
			if part:IsA("MeshPart") then
				local clone = part:Clone()
				clone:ClearAllChildren()
				clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery, clone.CastShadow = true, false, false, false, false
				clone.Transparency = if clone.Name == "1" then 0 else 1
				clone.Parent = frames
			end
		end
		model.Parent = folder
		model.PrimaryPart = frames:FindFirstChild("1") :: BasePart
		model:ScaleTo(SCALE)
		-- setiap bingkai disejajarkan sendiri: tepi kiri (hoist) selalu menempel di tiang (0,3 stud dari sumbu,
		-- jari-jari tiang 0,35), pusat sedalam tiang, bagian atas kain sedikit di bawah puncak tiang
		for _, part in frames:GetChildren() do
			if part:IsA("BasePart") then
				local minX = part.Position.X - part.Size.X / 2
				part.CFrame += Vector3.new(pole.x + 0.3 - minX, 0, pole.z - part.Position.Z)
			end
		end
		local _, size = model:GetBoundingBox()
		local top = (model.PrimaryPart :: BasePart).Position.Y + size.Y / 2
		model:PivotTo(model:GetPivot() + Vector3.new(0, 16.2 - top, 0))
	end
	local script = Instance.new("Script")
	script.Name = "Berkibar"
	script.Source = ANIMATE
	script.Parent = folder
	return 2
end
