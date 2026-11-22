--[[
	ROBLOCK CITY: rumah modern (jalankan setelah BuildResidential dan StyleWorld; aman diulang).

	Mengganti TAMPILAN 89 rumah perumahan dengan rumah modern buatan sendiri (Blender, sumbernya
	assets/blender/rumah_*.fbx dan roblock_houses.blend). Part rumah lama tidak dihapus, hanya
	disembunyikan: tabrakan, pintu (tombol beli/masuk), dan sistem rumah (HouseService) tetap memakainya.

	Templat ada di ServerStorage.AsetRumah: rumah_a (1 lantai), rumah_b (2 lantai), rumah_garasi.
	Tiap templat berisi MeshPart ShellWall, ShellRoof, ShellTrim, ShellGlass, ShellDoor dan ShellRef
	(titik acuan = tengah rumah di tanah). Warna dinding/atap/pintu diambil dari rumah lama, jadi
	keragaman warna perumahan tetap; HouseService mengecat part Shell* saat pemain mengganti cat.

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

return function(): number
	local folder = ServerStorage:FindFirstChild("AsetRumah")
	local a = folder and folder:FindFirstChild("rumah_a")
	local b = folder and folder:FindFirstChild("rumah_b")
	local g = folder and folder:FindFirstChild("rumah_garasi")
	local map = workspace:FindFirstChild("Map")
	local zone = map and map:FindFirstChild("Neighborhoods")
	local houses = zone and zone:FindFirstChild("Houses")
	if not (a and b and g and houses) then
		warn(
			"[StyleHouses] templat ServerStorage.AsetRumah atau Map.Neighborhoods.Houses tidak ditemukan; dilewati"
		)
		return 0
	end
	local count = 0
	for _, house in houses:GetChildren() do
		local body = house:FindFirstChild("Body")
		local door = house:FindFirstChild("Door")
		local roof = house:FindFirstChild("RoofFront")
		if
			not (house:IsA("Model") and house.Name:match("^Rumah%d+$") and body and door and roof)
		then
			continue
		end
		for _, child in house:GetChildren() do
			if child:GetAttribute(ATTR) then
				child:Destroy()
			elseif child:IsA("BasePart") and HIDE[child.Name] then
				child.Transparency = 1
				child.CastShadow = false
				CollectionService:RemoveTag(child, "NightWindow")
			end
		end
		local colors = { wall = body.Color, roof = roof.Color, door = door.Color }
		local base = body.CFrame * CFrame.new(0, -body.Size.Y / 2 - FOUNDATION, 0)
		place(if body.Size.Y > 12 then b else a, base, house, colors, false)
		local garage = house:FindFirstChild("Garage")
		if garage and garage:IsA("BasePart") then
			place(
				g,
				garage.CFrame * CFrame.new(0, -garage.Size.Y / 2 - FOUNDATION, 0),
				house,
				colors,
				true
			)
		end
		count += 1
		if count % 15 == 0 then
			task.wait()
		end
	end
	return count
end
