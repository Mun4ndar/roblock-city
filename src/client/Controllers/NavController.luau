--!strict
-- NavController: GPS. Menyimpan tujuan, mencari rute LEWAT JALAN (RoadRouter), menghitung sisa jarak,
-- menghitung ulang kalau pemain keluar jalur, dan menggambar jalur di dunia: deretan panah biru di atas
-- jalan di depan pemain (hanya terlihat di layar sendiri) plus tiang cahaya di tujuan.
-- Peta kecil, peta penuh, dan HP membaca keadaan GPS dari sini (getTarget/getRoute/onChanged).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RoadRouter = require(Shared:WaitForChild("RoadRouter"))
local DestinationConfig = require(Shared:WaitForChild("DestinationConfig"))

local HudController = require(script.Parent:WaitForChild("HudController"))

export type Target = {
	id: string?,
	name: string,
	icon: string,
	position: Vector3,
	arrive: number,
}

local player = Players.LocalPlayer

local NavController = {}

local COLOR = Color3.fromRGB(46, 150, 255)
local UPDATE_SECONDS = 0.12
local TILE_STEP = 8 -- jarak antar panah (stud)
local TILE_AHEAD = 256 -- panjang jalur yang digambar di depan pemain
local OFF_ROUTE = 45 -- lebih jauh dari ini dari rute = hitung ulang
local RECOMPUTE_GAP = 2.5
local WALK_SPEED = 16

local target: Target? = nil
local route: RoadRouter.Route? = nil
local routeIsRoad = false
local routeIndex = 1
local progressS = 0
local remaining = 0
local version = 0
local computing = false
local lastCompute = 0
local speed = WALK_SPEED
local listeners: { () -> () } = {}

local folder: Folder? = nil
local beam: Part? = nil
type Tile = { a: Part, b: Part, s: number }
local tiles: { [number]: Tile } = {}
local groundY: { [number]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local GROUND = {
	[Enum.Material.Asphalt] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Pavement] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Sandstone] = true,
	[Enum.Material.WoodPlanks] = true,
}

local function fire()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

local function rootPart(): BasePart?
	local character = player.Character
	return if character then character.PrimaryPart else nil
end

-- ---------------------------------------------------------------- jalur di dunia

local function clearWorld()
	for _, tile in tiles do
		tile.a:Destroy()
		tile.b:Destroy()
	end
	table.clear(tiles)
	table.clear(groundY)
	if beam then
		beam:Destroy()
		beam = nil
	end
end

local function ensureFolder(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "GpsJalur"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function newBar(parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = COLOR
	p.Size = Vector3.new(1.1, 0.15, 4.4)
	p.Transparency = 0.2
	p.Parent = parent
	return p
end

-- Titik dan arah pada jarak s dari awal rute.
local function pointAt(r: RoadRouter.Route, s: number): (Vector3, Vector3)
	local pts = r.points
	for i = 1, #pts - 1 do
		if s <= r.cumulative[i + 1] or i == #pts - 1 then
			local len = r.cumulative[i + 1] - r.cumulative[i]
			local t = if len > 0 then math.clamp((s - r.cumulative[i]) / len, 0, 1) else 0
			local dir = pts[i + 1] - pts[i]
			return pts[i]:Lerp(pts[i + 1], t),
				if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, -1)
		end
	end
	return pts[1], Vector3.new(0, 0, -1)
end

local function findGround(x: number, z: number, baseY: number): number
	local hit = Workspace:Raycast(Vector3.new(x, baseY + 12, z), Vector3.new(0, -70, 0), rayParams)
	if hit and (hit.Instance:IsA("Terrain") or GROUND[hit.Material]) then
		return hit.Position.Y
	end
	return baseY
end

local function placeTile(tile: Tile, position: Vector3, dir: Vector3, y: number)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	if flatDir.Magnitude < 0.01 then
		return
	end
	flatDir = flatDir.Unit
	local perp = Vector3.new(-flatDir.Z, 0, flatDir.X)
	local angle = math.rad(40)
	local apex = Vector3.new(position.X, y + 0.14, position.Z) + flatDir * 2.2
	for index, bar in { tile.a, tile.b } do
		local side = if index == 1 then 1 else -1
		local back = -flatDir * math.cos(angle) + perp * math.sin(angle) * side
		local center = apex + back * 2.2
		bar.CFrame = CFrame.lookAt(center, center + back)
	end
end

local function updateWorld(root: BasePart, now: number)
	local r = route
	local t = target
	if r == nil or t == nil then
		return
	end
	local parent = ensureFolder()
	local character = player.Character
	rayParams.FilterDescendantsInstances = if character then { character, parent } else { parent }
	local feetY = root.Position.Y - 3
	local first = math.max(1, math.ceil((progressS - 6) / TILE_STEP))
	local last = math.floor(math.min(r.length - 4, progressS + TILE_AHEAD) / TILE_STEP)
	for k, tile in tiles do
		if k < first or k > last then
			tile.a:Destroy()
			tile.b:Destroy()
			tiles[k] = nil
			groundY[k] = nil
		end
	end
	local lastY = feetY
	for k = first, last do
		local tile = tiles[k]
		if tile == nil then
			local position, dir = pointAt(r, k * TILE_STEP)
			local prev = groundY[k - 1] or lastY
			local y = findGround(position.X, position.Z, prev)
			groundY[k] = y
			tile = { a = newBar(parent), b = newBar(parent), s = k * TILE_STEP }
			tiles[k] = tile
			placeTile(tile, position, dir, y)
		end
		lastY = groundY[k] or lastY
		-- denyut: gelombang terang berjalan ke arah tujuan
		local wave = 0.5 + 0.5 * math.sin(now * 5 - tile.s * 0.09)
		local transparency = 0.12 + 0.55 * (1 - wave)
		tile.a.Transparency = transparency
		tile.b.Transparency = transparency
	end
end

local function updateWorldPulse(now: number)
	for _, tile in tiles do
		local wave = 0.5 + 0.5 * math.sin(now * 5 - tile.s * 0.09)
		local transparency = 0.12 + 0.55 * (1 - wave)
		tile.a.Transparency = transparency
		tile.b.Transparency = transparency
	end
end

local function updateBeam()
	local t = target
	if t == nil then
		return
	end
	if beam == nil or beam.Parent == nil then
		local part = Instance.new("Part")
		part.Name = "GpsTiang"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(400, 2.6, 2.6)
		part.CFrame = CFrame.new(t.position + Vector3.new(0, 200, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		part.Material = Enum.Material.Neon
		part.Color = COLOR
		part.Transparency = 0.5
		part.Parent = ensureFolder()
		beam = part
	end
end

-- ---------------------------------------------------------------- rute

local function compute()
	local t = target
	local root = rootPart()
	if t == nil or root == nil or computing then
		return
	end
	computing = true
	lastCompute = os.clock()
	local from = root.Position
	task.spawn(function()
		local result = RoadRouter.route(from, t.position, function()
			task.wait()
		end)
		computing = false
		if target ~= t then
			return -- tujuan sudah diganti selama menghitung
		end
		routeIsRoad = result ~= nil
		if result == nil then
			local a = Vector3.new(from.X, 0, from.Z)
			local b = Vector3.new(t.position.X, 0, t.position.Z)
			result = {
				points = { a, b },
				cumulative = { 0, (b - a).Magnitude },
				length = (b - a).Magnitude,
			}
		end
		route = result
		routeIndex = 1
		progressS = 0
		remaining = (result :: RoadRouter.Route).length
		version += 1
		for _, tile in tiles do
			tile.a:Destroy()
			tile.b:Destroy()
		end
		table.clear(tiles)
		table.clear(groundY)
		fire()
	end)
end

function NavController.setTarget(newTarget: Target)
	NavController.clear(true)
	target = newTarget
	route = nil
	version += 1
	compute()
	updateBeam()
	HudController.toast("GPS menuju " .. newTarget.name .. ". Ikuti panah biru di jalan!")
	fire()
end

function NavController.setDestination(name: string, icon: string, position: Vector3)
	NavController.setTarget({
		id = nil,
		name = name,
		icon = icon,
		position = position,
		arrive = DestinationConfig.DEFAULT_ARRIVE,
	})
end

function NavController.clear(silent: boolean?)
	if target == nil and route == nil then
		return
	end
	target = nil
	route = nil
	remaining = 0
	version += 1
	clearWorld()
	if silent ~= true then
		fire()
	end
end

function NavController.getTarget(): Target?
	return target
end

function NavController.getTargetPosition(): Vector3?
	return if target then target.position else nil
end

function NavController.getRoute(): RoadRouter.Route?
	return route
end

function NavController.getRouteIndex(): number
	return routeIndex
end

function NavController.isRoadRoute(): boolean
	return routeIsRoad
end

function NavController.getVersion(): number
	return version
end

function NavController.getRemaining(): number
	return remaining
end

-- Perkiraan waktu tempuh (detik) dengan kecepatan pemain saat ini.
function NavController.getEta(): number
	return remaining / math.max(speed, 8)
end

-- Arah (vektor dunia mendatar) menuju titik 40 stud di depan menurut rute; nil kalau tak ada GPS.
function NavController.getHeading(): Vector3?
	local root = rootPart()
	local r = route
	if root == nil or r == nil then
		return nil
	end
	local here = Vector3.new(root.Position.X, 0, root.Position.Z)
	local ahead = RoadRouter.pointAhead(r, routeIndex, here, 40)
	local d = ahead - here
	return if d.Magnitude > 0.5 then d.Unit else nil
end

function NavController.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

function NavController.formatDistance(studs: number): string
	if studs >= 1000 then
		return string.format("%.1f km", studs / 1000)
	end
	return tostring(math.floor(studs / 5 + 0.5) * 5) .. " m"
end

function NavController.formatEta(seconds: number): string
	local minutes = math.ceil(seconds / 60)
	if minutes <= 1 then
		return "< 1 mnt"
	end
	return tostring(minutes) .. " mnt"
end

-- ---------------------------------------------------------------- loop

function NavController.init() end

function NavController.start()
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		local t = target
		if t == nil then
			return
		end
		local root = rootPart()
		if root == nil then
			return
		end
		local now = os.clock()
		if accumulated >= UPDATE_SECONDS then
			accumulated = 0
			local v = root.AssemblyLinearVelocity
			local flatSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
			speed = speed + (math.max(flatSpeed, WALK_SPEED) - speed) * 0.1
			local offset = t.position - root.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= t.arrive then
				HudController.toast("Kamu sudah sampai di " .. t.name .. "!")
				NavController.clear()
				return
			end
			local r = route
			if r then
				local index, closest, distance, left =
					RoadRouter.progress(r, root.Position, routeIndex)
				routeIndex = index
				remaining = left
				progressS = r.cumulative[index] + (closest - r.points[index]).Magnitude
				if routeIsRoad and distance > OFF_ROUTE and now - lastCompute > RECOMPUTE_GAP then
					compute()
				end
				updateWorld(root, now)
			end
			updateBeam()
		elseif route then
			updateWorldPulse(now)
		end
	end)
end

return NavController
