--[[
	ROBLOCK CITY — Pembangun "Dealer Mobil", di seberang barat taman kota (dekat titik spawn).

	Membangun ulang Workspace.Map.Dealer (kawasan lain tidak disentuh).
	Pakai (Studio, mode Edit): require(game.ServerStorage.MapBuilders.BuildDealer)()

	Lahan: x -98..-36, z 474..548 (tepi timur menempel jalan NS di x = -20, lebar 32).
	Yang dipakai kode game (src/server/Services/VehicleService):
	  * Part bertag "VehicleDealer"      : penanda lokasi; pemain harus di dekatnya untuk membeli.
	  * Part bertag "VehicleDisplaySlot" : alas pajangan; server menaruh satu mobil dari
	    VehicleConfig.LIST di tiap alas (urut atribut Order). Depan alas = lokal -Z.
	Menambah kendaraan baru cukup di VehicleConfig; alas kosong tersedia sampai 6 mobil.
]]

local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.MapKit)
local P, deco, C = Kit.P, Kit.deco, Kit.C

local X0, X1 = -98, -36
local Z0, Z1 = 474, 548
local ZC = (Z0 + Z1) / 2
local TOP = Kit.ROAD_TOP

local BLUE = Color3.fromRGB(52, 120, 220)
local YELLOW = Color3.fromRGB(255, 196, 46)
local WALL = Color3.fromRGB(238, 240, 244)
local PAD = Color3.fromRGB(214, 218, 226)

local SLOT_COUNT = 6
local SLOT_SPACING = 11
local SLOT_X = -66

return function()
	local zone = Kit.zone("Dealer")

	-- lahan aspal, rata dengan jalan
	P({
		Name = "Lot",
		Size = Vector3.new(X1 - X0, TOP, Z1 - Z0),
		Position = Vector3.new((X0 + X1) / 2, TOP / 2, ZC),
		Color = Color3.fromRGB(72, 75, 82),
		Material = Enum.Material.Asphalt,
		Parent = zone,
	})
	-- garis tepi kuning
	for _, z in { Z0 + 0.6, Z1 - 0.6 } do
		deco({
			Name = "Edge",
			Size = Vector3.new(X1 - X0, 0.05, 0.6),
			Position = Vector3.new((X0 + X1) / 2, TOP + 0.025, z),
			Color = YELLOW,
			Parent = zone,
		})
	end

	local marker = P({
		Name = "DealerZone",
		Size = Vector3.new(4, 4, 4),
		Position = Vector3.new(-62, 4, ZC),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = zone,
	})
	CollectionService:AddTag(marker, "VehicleDealer")

	---------------------------------------------------------------- showroom
	local building = Kit.folder("Showroom", zone)
	local bx0, bx1 = X0 + 1, -80 -- kedalaman 17
	local bz0, bz1 = Z0 + 6, Z1 - 6
	local bh = 14
	local bw = bx1 - bx0
	local bl = bz1 - bz0
	P({
		Name = "Floor",
		Size = Vector3.new(bw, 0.5, bl),
		Position = Vector3.new((bx0 + bx1) / 2, TOP + 0.25, ZC),
		Color = Color3.fromRGB(250, 250, 250),
		Parent = building,
	})
	P({
		Name = "BackWall",
		Size = Vector3.new(1, bh, bl),
		Position = Vector3.new(bx0 + 0.5, TOP + bh / 2, ZC),
		Color = WALL,
		Parent = building,
	})
	for _, z in { bz0 + 0.5, bz1 - 0.5 } do
		P({
			Name = "SideWall",
			Size = Vector3.new(bw, bh, 1),
			Position = Vector3.new((bx0 + bx1) / 2, TOP + bh / 2, z),
			Color = WALL,
			Parent = building,
		})
	end
	P({
		Name = "Roof",
		Size = Vector3.new(bw + 2, 1, bl + 2),
		Position = Vector3.new((bx0 + bx1) / 2, TOP + bh + 0.5, ZC),
		Color = BLUE,
		Parent = building,
	})
	-- depan kaca dengan tiang; bagian tengah terbuka sebagai pintu
	local bays = 6
	local bayL = bl / bays
	for i = 0, bays do
		P({
			Name = "Pillar",
			Size = Vector3.new(1, bh, 1),
			Position = Vector3.new(bx1 - 0.5, TOP + bh / 2, bz0 + i * bayL),
			Color = BLUE,
			Parent = building,
		})
	end
	for i = 0, bays - 1 do
		local isDoor = i == 2 or i == 3
		local gh = if isDoor then 3 else bh - 1
		P({
			Name = if isDoor then "DoorTop" else "Glass",
			Size = Vector3.new(0.3, gh, bayL - 1),
			Position = Vector3.new(bx1 - 0.5, TOP + bh - gh / 2, bz0 + (i + 0.5) * bayL),
			Color = C.glass,
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Parent = building,
		})
	end
	local sign = P({
		Name = "Sign",
		Size = Vector3.new(1, 5, 44),
		Position = Vector3.new(bx1 + 0.6, TOP + bh + 3.5, ZC),
		Color = BLUE,
		Parent = building,
	})
	Kit.sign(sign, "DEALER MOBIL ROBLOCK", Color3.new(1, 1, 1), Enum.NormalId.Right)
	deco({
		Name = "SignStripe",
		Size = Vector3.new(1.1, 0.6, 44),
		Position = Vector3.new(bx1 + 0.6, TOP + bh + 0.7, ZC),
		Color = YELLOW,
		Parent = building,
	})
	-- meja layanan di dalam
	P({
		Name = "Counter",
		Size = Vector3.new(3, 3.4, 14),
		Position = Vector3.new(bx0 + 5, TOP + 0.5 + 1.7, ZC),
		Color = BLUE,
		Parent = building,
	})
	deco({
		Name = "CounterTop",
		Size = Vector3.new(3.6, 0.3, 14.6),
		Position = Vector3.new(bx0 + 5, TOP + 0.5 + 3.55, ZC),
		Color = Color3.fromRGB(250, 250, 250),
		Parent = building,
	})

	---------------------------------------------------------------- kanopi + alas pajangan
	local canopy = Kit.folder("Canopy", zone)
	local cx0, cx1 = -77, -55
	local ch = 13
	P({
		Name = "CanopyRoof",
		Size = Vector3.new(cx1 - cx0, 0.8, Z1 - Z0 - 4),
		Position = Vector3.new((cx0 + cx1) / 2, TOP + ch, ZC),
		Color = WALL,
		Parent = canopy,
	})
	deco({
		Name = "CanopyTrim",
		Size = Vector3.new(cx1 - cx0 + 0.4, 1, Z1 - Z0 - 3.6),
		Position = Vector3.new((cx0 + cx1) / 2, TOP + ch - 0.2, ZC),
		Color = YELLOW,
		Parent = canopy,
	})
	for _, z in { Z0 + 3, ZC, Z1 - 3 } do
		P({
			Name = "Post",
			Size = Vector3.new(1, ch, 1),
			Position = Vector3.new(cx1 - 1, TOP + ch / 2, z),
			Color = BLUE,
			Parent = canopy,
		})
	end

	local slots = Kit.folder("DisplaySlots", zone)
	local firstZ = ZC - (SLOT_COUNT - 1) * SLOT_SPACING / 2
	for i = 1, SLOT_COUNT do
		local pos = Vector3.new(SLOT_X, TOP + 0.15, firstZ + (i - 1) * SLOT_SPACING)
		local slot = P({
			Name = "Slot" .. i,
			Size = Vector3.new(9, 0.3, 18),
			CFrame = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0)), -- mobil menghadap jalan (timur)
			Color = PAD,
			Parent = slots,
		})
		slot:SetAttribute("Order", i)
		CollectionService:AddTag(slot, "VehicleDisplaySlot")
	end

	---------------------------------------------------------------- halaman depan
	local yard = Kit.folder("Yard", zone)
	-- tiang papan nama di tepi jalan
	for _, z in { Z0 + 3, Z1 - 3 } do
		P({
			Name = "PylonPost",
			Size = Vector3.new(1.2, 18, 1.2),
			Position = Vector3.new(X1 - 3, TOP + 9, z),
			Color = C.metal,
			Material = Enum.Material.Metal,
			Parent = yard,
		})
		local board = P({
			Name = "PylonSign",
			Size = Vector3.new(1, 5, 12),
			Position = Vector3.new(X1 - 3, TOP + 18, z),
			Color = YELLOW,
			Parent = yard,
		})
		Kit.sign(board, "DEALER MOBIL", BLUE, Enum.NormalId.Right)
		Kit.sign(board, "DEALER MOBIL", BLUE, Enum.NormalId.Left)
	end
	-- petak "ambil mobil" bergaris di depan kanopi
	for i = 0, 4 do
		deco({
			Name = "BayLine",
			Size = Vector3.new(14, 0.05, 0.4),
			Position = Vector3.new(-46, TOP + 0.025, Z0 + 8 + i * 14.5),
			Color = C.white,
			Parent = yard,
		})
	end
	Kit.streetLight(Vector3.new(-46, TOP, Z0 + 1.6), math.pi, yard)
	Kit.streetLight(Vector3.new(-46, TOP, Z1 - 1.6), 0, yard)
	-- pagar tanaman di sisi utara & selatan
	for _, z in { Z0 - 1.5, Z1 + 1.5 } do
		P({
			Name = "Hedge",
			Size = Vector3.new(X1 - X0 - 8, 3, 2.5),
			Position = Vector3.new((X0 + X1) / 2 - 4, 1.5, z),
			Color = Color3.fromRGB(70, 150, 60),
			Material = Enum.Material.Grass,
			Parent = yard,
		})
	end

	print(("[BuildDealer] selesai: %d part"):format(Kit.countParts(zone)))
end
