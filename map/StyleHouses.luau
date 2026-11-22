--[[
	ROBLOCK CITY: rumah bervariasi (jalankan setelah BuildResidential, BuildTown, dan StyleWorld; aman diulang).

	Mengganti TAMPILAN semua rumah (89 rumah perumahan + rumah di kota kecil) dengan rumah buatan
	sendiri di Blender (assets/blender/rumah_*.fbx). Part rumah lama tidak dihapus, hanya disembunyikan:
	tabrakan, pintu (tombol beli/masuk), dan sistem rumah (HouseService) tetap memakainya.

	Templat di ServerStorage.AsetRumah, dipilih bergiliran menurut nomor rumah supaya tetangga berbeda:
	  satu lantai : rumah_c (limas + teras bertiang), rumah_d (pelana silang + sayap depan),
	                rumah_e (modern, atap miring satu arah)
	  dua lantai  : rumah_f (pelana depan + balkon), rumah_g (atap curam + jendela atap + teras),
	                rumah_h (modern kubus, lantai atas menjorok)
	  (rumah_a dan rumah_b, model kotak lama, hanya cadangan)
	  rumah_garasi: garasi di samping rumah yang punya part Garage
	Tiap templat berisi MeshPart ShellWall, ShellRoof, ShellTrim, ShellGlass, ShellDoor dan ShellRef
	(titik acuan = tengah rumah di tanah; depan rumah = arah -Z; pintu di x = -3). Warna dinding/atap/
	pintu diambil dari rumah lama; HouseService mengecat part Shell* saat pemain mengganti cat.

	Pakai: require(game.ServerStorage.MapBuilders.StyleHouses)()
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local rgb = Color3.fromRGB
local ATTR = "HouseShell"
local FOUNDATION = 0.8
local HIDE = {
	Body = true,
	RoofFront = true,
	RoofBack = true,
	Door = true,
	Porch = true,
	Window1 = true,
	Window2 = true,
	Garage = true,
	GarageRoof = true,
	GarageDoor = true,
	Chimney = true,
	BodyBulat = true,
}
local TRIM = rgb(246, 246, 242)
local GLASS = rgb(150, 205, 235)

local function place(
	template: Model,
	base: CFrame,
	house: Model,
	colors: { [string]: Color3 },
	garage: boolean
)
	local ref = template:FindFirstChild("ShellRef")
	if not ref or not ref:IsA("BasePart") then
		return
	end
	local origin = ref.CFrame * CFrame.new(0, -ref.Size.Y / 2, 0)
	for _, piece in template:GetChildren() do
		if piece:IsA("MeshPart") and piece ~= ref then
			local clone = piece:Clone()
			clone.CFrame = base * origin:ToObjectSpace(piece.CFrame)
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Material = Enum.Material.SmoothPlastic
			clone:SetAttribute(ATTR, true)
			if piece.Name == "ShellWall" then
				clone.Name = if garage then "ShellGarage" else "ShellWall"
				clone.Color = if garage
					then colors.wall:Lerp(Color3.new(1, 1, 1), 0.25)
					else colors.wall
				clone.Material = Enum.Material.Plaster
			elseif piece.Name == "ShellRoof" then
				clone.Color = colors.roof
			elseif piece.Name == "ShellDoor" then
				if garage then
					clone.Name = "ShellGarageDoor"
					clone.Color = rgb(224, 228, 232)
				else
					clone.Color = colors.door
				end
				clone.CastShadow = false
			elseif piece.Name == "ShellGlass" then
				clone.Color = GLASS
				clone.Reflectance = 0.28
				clone.CastShadow = false
				CollectionService:AddTag(clone, "NightWindow") -- menyala saat malam (DayNightController)
			else
				clone.Color = TRIM
				clone.CastShadow = false
			end
			clone.Parent = house
		end
	end
end

-- Templat c-h sudah membawa alas sendiri, jadi alas rumah lama ikut disembunyikan.
local OWN_BASE = {
	rumah_c = true,
	rumah_d = true,
	rumah_e = true,
	rumah_f = true,
	rumah_g = true,
	rumah_h = true,
}
-- Templat yang bagian depannya menjorok: semak di depan jendela digeser maju supaya tidak tertanam.
local FRONT_WING = { rumah_d = 2.8, rumah_g = 3.6, rumah_h = 2.4 }
local DOOR_X = -3 -- letak pintu semua templat (ruang lokal rumah)

local function styleHouse(
	house: Model,
	one: { Model },
	two: { Model },
	garageTemplate: Model?
): boolean
	local body = house:FindFirstChild("Body")
	local door = house:FindFirstChild("Door")
	local roof = house:FindFirstChild("RoofFront")
	local number = tonumber(house.Name:match("^Rumah(%d+)$"))
	if
		not (
			body
			and body:IsA("BasePart")
			and door
			and door:IsA("BasePart")
			and roof
			and roof:IsA("BasePart")
			and number
		)
	then
		return false
	end
	local list = if body.Size.Y > 12 then two else one
	if #list == 0 then
		return false
	end
	local template = list[(number * 3 + (if body.Size.Y > 12 then 1 else 0)) % #list + 1]
	for _, child in house:GetChildren() do
		if child:GetAttribute(ATTR) then
			child:Destroy()
		elseif
			child:IsA("BasePart")
			and (HIDE[child.Name] or (child.Name == "Foundation" and OWN_BASE[template.Name]))
		then
			child.Transparency = 1
			child.CastShadow = false
			CollectionService:RemoveTag(child, "NightWindow")
		elseif child:IsA("BasePart") and child.Name == "Foundation" then
			child.Transparency = 0
		end
	end
	-- Rumah kota kecil berpintu di tengah: pintu (tombol masuk) dan jalan setapaknya digeser ke letak pintu templat.
	local doorX = body.CFrame:PointToObjectSpace(door.Position).X
	if math.abs(doorX - DOOR_X) > 0.5 then
		local shift = body.CFrame:VectorToWorldSpace(Vector3.new(DOOR_X - doorX, 0, 0))
		for _, name in { "Door", "Driveway" } do
			local part = house:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.CFrame += shift
			end
		end
	end
	-- semak: kembalikan ke tempat asal lalu geser sesuai templat
	local bush = house:FindFirstChild("Bush")
	if bush and bush:IsA("BasePart") then
		local moved = bush:GetAttribute("Maju")
		local want = FRONT_WING[template.Name] or 0
		local delta = want - (if type(moved) == "number" then moved else 0)
		if delta ~= 0 then
			bush.CFrame += body.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -delta))
			bush:SetAttribute("Maju", want)
		end
	end
	local colors = { wall = body.Color, roof = roof.Color, door = door.Color }
	local base = body.CFrame * CFrame.new(0, -body.Size.Y / 2 - FOUNDATION, 0)
	place(template, base, house, colors, false)
	local garage = house:FindFirstChild("Garage")
	if garageTemplate and garage and garage:IsA("BasePart") then
		place(
			garageTemplate,
			garage.CFrame * CFrame.new(0, -garage.Size.Y / 2 - FOUNDATION, 0),
			house,
			colors,
			true
		)
	end
	return true
end

return function(): number
	local folder = ServerStorage:FindFirstChild("AsetRumah")
	local map = workspace:FindFirstChild("Map")
	if not (folder and map) then
		warn("[StyleHouses] ServerStorage.AsetRumah atau Workspace.Map tidak ditemukan; dilewati")
		return 0
	end
	local function templates(names: { string }): { Model }
		local list: { Model } = {}
		for _, name in names do
			local t = folder:FindFirstChild(name)
			if t and t:IsA("Model") and t:FindFirstChild("ShellRef") then
				table.insert(list, t)
			end
		end
		return list
	end
	-- rumah_a dan rumah_b (kotak sederhana) tidak dipakai lagi; hanya cadangan bila templat baru tidak ada
	local one = templates({ "rumah_c", "rumah_d", "rumah_e" })
	local two = templates({ "rumah_f", "rumah_g", "rumah_h" })
	if #one == 0 then
		one = templates({ "rumah_a" })
	end
	if #two == 0 then
		two = templates({ "rumah_b" })
	end
	local g = folder:FindFirstChild("rumah_garasi")
	local garageTemplate = if g and g:IsA("Model") then g else nil
	local groups: { Instance } = {}
	local neighborhoods = map:FindFirstChild("Neighborhoods")
	local residential = map:FindFirstChild("Residential")
	local buildings = residential and residential:FindFirstChild("Buildings")
	for _, parent in
		{
			neighborhoods and neighborhoods:FindFirstChild("Houses"),
			buildings and buildings:FindFirstChild("Houses"),
		}
	do
		if parent then
			table.insert(groups, parent)
		end
	end
	local count = 0
	for _, group in groups do
		for _, house in group:GetChildren() do
			if house:IsA("Model") and styleHouse(house, one, two, garageTemplate) then
				count += 1
				if count % 12 == 0 then
					task.wait()
				end
			end
		end
	end
	return count
end
