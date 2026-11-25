--!nocheck
--[[
	ROBLOCK CITY: Panggung Konser Taman Kota -> Workspace.Map.Panggung.
	Mesh: tools/blender/panggung.py (asset 77862548280334 -> ServerStorage.PanggungMentah), satu MeshPart per bahan;
	semua bagian memakai satu SurfaceAppearance dari atlas PBR 1024 px (KidsConcertStage_*; Albedo 118420539806352,
	Normal 134045324086819, Roughness 78452884770548, Metallic 101266156526385) kecuali lensa lampu dan bintang (Neon).
	Angka posisi lampu/layar/pad dari map/PanggungData.luau (dibuat otomatis oleh skrip Blender).
	Koordinat Blender (x, y, z) -> dunia: ConcertConfig.frame() * (x, z, -y). Depan panggung (+Y Blender) menghadap barat.
	Isi: Visual (mesh), Fisik (penabrak tak terlihat), Lampu (bertag KonserLampu), Layar (KonserLayar), Papan (KonserPapan),
	Pad joget (KonserJogetPad + ProximityPrompt). Pohon/bangku yang menghalangi dipindah ke ServerStorage.CadanganPeta.TamanKotaLama.
	Aman dijalankan ulang. Pakai: require(ServerStorage.MapBuilders.BuildPanggung)()
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB
local M = Enum.Material

local TEX = {
	Color = "rbxassetid://118420539806352",
	Normal = "rbxassetid://134045324086819",
	Roughness = "rbxassetid://78452884770548",
	Metalness = "rbxassetid://101266156526385",
}
local NEON_PARTS = { LampuLensa = rgb(255, 236, 160), Bintang = rgb(255, 210, 60) }
local NO_SHADOW = { Tali = true, BuntingMerah = true, BuntingKuning = true, BuntingHijau = true, BuntingBiru = true, LampuBadan = true, Balon = true }

local function build()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("ConcertConfig"))
	local Data = require(script.Parent:WaitForChild("PanggungData"))
	local raw = ServerStorage:FindFirstChild("PanggungMentah")
	assert(raw, "ServerStorage.PanggungMentah tidak ada (insert asset 77862548280334)")

	local frame = Config.frame()
	local function W(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, z, -y)
	end

	local map = Workspace:WaitForChild("Map")
	local old = map:FindFirstChild("Panggung")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "Panggung"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual.Parent = root
	local fisik = Instance.new("Folder")
	fisik.Name = "Fisik"
	fisik.Parent = root

	-- ------------------------------------------------ singkirkan pohon/bangku di tapak panggung (disimpan di cadangan)
	do
		local cb = ServerStorage:FindFirstChild("CadanganPeta")
		if cb == nil then
			cb = Instance.new("Folder")
			cb.Name = "CadanganPeta"
			cb.Parent = ServerStorage
		end
		local keep = cb:FindFirstChild("TamanKotaLama")
		if keep == nil then
			keep = Instance.new("Folder")
			keep.Name = "TamanKotaLama"
			keep.Parent = cb
		end
		local c = W(0, 16.7, 18)
		local params = OverlapParams.new()
		local parts = Workspace:GetPartBoundsInBox(c, Vector3.new(66, 60, 64), params)
		local moved = {}
		for _, p in parts do
			-- naik dari part sampai ketemu objek bernama pohon/bangku/semak (yang paling dekat dengan part)
			local anc: Instance? = p
			while anc and anc ~= map and anc ~= Workspace do
				local nm = anc.Name
				if string.find(nm, "Pohon") or string.find(nm, "Bangku") or string.find(nm, "Semak") or string.find(nm, "Bunga") then
					moved[anc] = true
					break
				end
				anc = anc.Parent
			end
		end
		local n = 0
		for inst in moved do
			inst.Parent = keep
			n += 1
		end
		print("[BuildPanggung] pohon/bangku dipindah:", n)
	end

	-- ------------------------------------------------ mesh
	-- Model hasil insert FBX berputar sembarang di sumbu Y (theta); di kerangka modelnya, mesh Blender tampil dengan
	-- sumbu Z terbalik dan X mirror, yaitu ideal diputar 180 derajat. Hitung pusat di kerangka model, lalu putar balik pi.
	local anyPart = raw:FindFirstChildWhichIsA("MeshPart", true)
	local theta = select(2, anyPart.CFrame:ToOrientation())
	local Ri = CFrame.Angles(0, theta, 0):Inverse()
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local h = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = Ri * (part.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
						mn, mx = mn:Min(p), mx:Max(p)
					end
				end
			end
		end
	end
	local modelCenter = (mn + mx) / 2
	local center = W(Data.bboxCenter.X, Data.bboxCenter.Y, Data.bboxCenter.Z)
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			local key = string.match(part.Name, "^%a+")
			local clone = part:Clone()
			clone:ClearAllChildren()
			clone.Name = key
			clone.CFrame = center * CFrame.Angles(0, math.pi, 0) * CFrame.new(Ri * part.Position - modelCenter) * (Ri * part.CFrame).Rotation
			clone.Anchored = true
			clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
			clone.CastShadow = not (NO_SHADOW[key] or string.sub(key, 1, 5) == "Balon")
			if NEON_PARTS[key] then
				clone.Material = M.Neon
				clone.Color = NEON_PARTS[key]
			else
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap, sa.NormalMap, sa.RoughnessMap, sa.MetalnessMap = TEX.Color, TEX.Normal, TEX.Roughness, TEX.Metalness
				sa.Parent = clone
			end
			clone.Parent = visual
		end
	end

	-- ------------------------------------------------ penabrak tak terlihat
	local function box(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Transparency = 1
		p.CastShadow = false
		p.CanTouch = false
		p.Size = Vector3.new(x1 - x0, z1 - z0, y1 - y0)
		p.CFrame = W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Parent = fisik
	end
	box("Dek", -22, 22, -11, 13, 0, 3)
	box("Podium", -4.5, 4.5, -9, -3.4, 3, 3.7)
	box("DindingLayar", -22, 22, -10.7, -10.3, 3, 19.8)
	box("LantaiDansa", -20, 20, 19, 43, 0, 0.4)
	for _, sx in { -1, 1 } do
		for j = 3, 1, -1 do
			local y0 = 13 + 1.8 * (3 - j)
			box("Tangga", sx * 16 - 4, sx * 16 + 4, y0, y0 + 1.8, 0, j)
		end
		for _, cy in { 11.5, -9.5 } do
			box("Kolom", sx * 21.8 - 1.15, sx * 21.8 + 1.15, cy - 1.15, cy + 1.15, 3, 20)
		end
		box("Speaker", sx * 28 - 2.2, sx * 28 + 2.2, 2.2, 5.8, 0, 13.9)
	end

	-- ------------------------------------------------ lampu sorot (tag KonserLampu; cahaya diatur client)
	local REAL = { [3] = 1, [6] = 2, [9] = 3, [14] = 4, [17] = 5, [20] = 6 }
	local toAudience = frame:VectorToWorldSpace(Vector3.new(0, -0.5, -1)).Unit
	for i, f in Data.fixtures do
		local p = Instance.new("Part")
		p.Name = "Lampu" .. i
		p.Anchored = true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(0.6, 0.6, 0.6)
		local pos = frame * Vector3.new(f.X, f.Z, -f.Y)
		p.CFrame = CFrame.lookAt(pos, pos + toAudience)
		p:SetAttribute("Index", i)
		p:SetAttribute("Row", if f.Y > 3 then 1 else 2)
		local rank = REAL[i]
		if rank then
			p:SetAttribute("RealRank", rank)
			local l = Instance.new("SpotLight")
			l.Name = "Sorot"
			l.Face = Enum.NormalId.Front
			l.Angle = 50
			l.Range = 70
			l.Brightness = 3
			l.Shadows = false
			l.Enabled = false
			l.Parent = p
		end
		CollectionService:AddTag(p, Config.TAG_LAMP)
		p.Parent = root
	end

	-- ------------------------------------------------ layar LED (gambar digambar client)
	for _, s in Data.screens do
		local p = Instance.new("Part")
		p.Name = "Layar" .. s.name
		p.Anchored = true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CastShadow = false
		p.Color = rgb(10, 10, 20)
		p.Material = M.SmoothPlastic
		p.Size = Vector3.new(s.w, s.h, 0.1)
		p.CFrame = W(s.cx, s.y, s.cz)
		p:SetAttribute("Kind", if s.name == "Utama" then "main" else "side")
		CollectionService:AddTag(p, Config.TAG_SCREEN)
		p.Parent = root
	end

	-- ------------------------------------------------ papan nama di atap
	do
		local mq = Data.marquee
		local p = Instance.new("Part")
		p.Name = "PapanKonser"
		p.Anchored = true
		p.CanCollide, p.CanTouch = false, false
		p.CastShadow = false
		p.Color = rgb(36, 20, 80)
		p.Material = M.SmoothPlastic
		p.Size = Vector3.new(mq.w, mq.h, 0.5)
		p.CFrame = W(mq.cx, mq.y, mq.cz)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.Name = "Judul"
		t.Size = UDim2.fromScale(0.96, 0.62)
		t.Position = UDim2.fromScale(0.02, 0.04)
		t.BackgroundTransparency = 1
		t.Text = "KONSER TAMAN KOTA"
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		local gr = Instance.new("UIGradient")
		gr.Name = "Pelangi"
		gr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 90, 170)),
			ColorSequenceKeypoint.new(0.35, rgb(255, 210, 50)),
			ColorSequenceKeypoint.new(0.7, rgb(60, 210, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 90, 170)),
		})
		gr.Parent = t
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = rgb(60, 20, 110)
		st.Parent = t
		t.Parent = g
		local s2 = Instance.new("TextLabel")
		s2.Name = "Sub"
		s2.Size = UDim2.fromScale(0.96, 0.26)
		s2.Position = UDim2.fromScale(0.02, 0.7)
		s2.BackgroundTransparency = 1
		s2.Text = "Joget bareng di depan panggung!"
		s2.Font = Enum.Font.FredokaOne
		s2.TextScaled = true
		s2.TextColor3 = rgb(255, 255, 255)
		s2.Parent = g
		CollectionService:AddTag(p, Config.TAG_SIGN)
		p.Parent = root
	end

	-- ------------------------------------------------ pad joget (lantai dansa)
	local PADC = { rgb(255, 90, 170), rgb(60, 210, 255), rgb(255, 210, 50) }
	for i, v in Data.pads do
		local pad = Instance.new("Part")
		pad.Name = "PadJoget" .. i
		pad.Shape = Enum.PartType.Cylinder
		pad.Anchored = true
		pad.CanCollide, pad.CanTouch = false, false
		pad.CastShadow = false
		pad.Size = Vector3.new(0.2, 6, 6)
		pad.Material = M.Neon
		pad.Color = PADC[i]
		pad.CFrame = W(v.X, v.Y, 0.5) * CFrame.Angles(0, 0, math.pi / 2)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Joget"
		prompt.ActionText = Config.PAD_PROMPT.action
		prompt.ObjectText = Config.PAD_PROMPT.object
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		CollectionService:AddTag(pad, Config.TAG_PAD)
		pad.Parent = root
	end

	root.Parent = map
	print("[BuildPanggung] selesai: " .. #visual:GetChildren() .. " mesh, " .. #Data.fixtures .. " lampu")
	return root
end

return build
