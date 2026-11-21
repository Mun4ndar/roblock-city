--!strict
-- VehicleService: kepemilikan, pembelian, dan spawn kendaraan.
--   * server-authoritative: client hanya mengirim `id`; harga, kepemilikan,
--     jarak ke dealer, cooldown, dan batas spawn semuanya dicek di sini
--   * daftar kendaraan milik pemain direplikasi lewat atribut Player "OwnedVehicles"
--   * naik kendaraan hanya lewat ProximityPrompt yang ditangani server
--     (kursi pengemudi khusus pemilik, kursi penumpang untuk siapa saja)
--   * fisika dijalankan client pengemudi (network ownership) supaya responsif;
--     server mengawasi kecepatan dan menarik mobil yang melaju tidak wajar

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Format"))
local VehicleConfig = require(Shared:WaitForChild("VehicleConfig"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))
local JobConfig = require(Shared:WaitForChild("JobConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

type VehicleResult = Types.VehicleResult
type VehicleDef = VehicleConfig.VehicleDef

local VehicleService = {}

local vehicleFolder: Folder
local spawned: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}
local lastCall: { [Player]: number } = {}
local lastFlip: { [Player]: number } = {}
local speedStrikes: { [Player]: number } = {}

-- ---------------------------------------------------------------- util

local function result(ok: boolean, message: string): VehicleResult
	return { ok = ok, message = message }
end

local function allowCall(player: Player): boolean
	local now = os.clock()
	local last = lastCall[player]
	if last and now - last < VehicleConfig.REMOTE_COOLDOWN then
		return false
	end
	lastCall[player] = now
	return true
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, humanoid
end

local function publishOwned(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local ids = {}
	for id in data.vehicles do
		if VehicleConfig.get(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	player:SetAttribute(VehicleConfig.ATTR_OWNED, table.concat(ids, ","))
end

local function isNearDealer(root: BasePart): boolean
	for _, marker in CollectionService:GetTagged(VehicleConfig.TAG_DEALER) do
		if marker:IsA("BasePart") and marker:IsDescendantOf(Workspace) then
			if (marker.Position - root.Position).Magnitude <= VehicleConfig.DEALER_RANGE then
				return true
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------- API server

function VehicleService.owns(player: Player, vehicleId: string): boolean
	local data = DataService.getData(player)
	return data ~= nil and data.vehicles[vehicleId] ~= nil
end

function VehicleService.getSpawned(player: Player): Model?
	return spawned[player]
end

function VehicleService.despawn(player: Player)
	local model = spawned[player]
	spawned[player] = nil
	speedStrikes[player] = nil
	if model then
		model:Destroy()
	end
end

-- Dipanggil JobService saat pekerjaan pemain berubah: kendaraan dinas dari
-- pekerjaan lama dikembalikan.
function VehicleService.onJobChanged(player: Player, jobId: string)
	local model = spawned[player]
	if model == nil then
		return
	end
	local def = VehicleConfig.get(model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
	if def and def.job and def.job ~= jobId then
		VehicleService.despawn(player)
		EconomyService.notify(player, `{def.name} dikembalikan ke kantor.`)
	end
end

-- ---------------------------------------------------------------- kursi

-- Kursi yang dipakai saat pemain menekan prompt di `triggered`.
-- Pemilik selalu ke kursi pengemudi jika kosong (prompt mana pun yang terdekat);
-- pemain lain hanya ke kursi penumpang.
local function pickSeat(
	model: Model,
	triggered: Seat | VehicleSeat,
	isOwner: boolean
): (Seat | VehicleSeat)?
	local driveSeat = model:FindFirstChild("DriveSeat")
	if isOwner and driveSeat and driveSeat:IsA("VehicleSeat") and driveSeat.Occupant == nil then
		return driveSeat
	end
	if triggered:IsA("Seat") and triggered.Occupant == nil then
		return triggered
	end
	for _, child in model:GetChildren() do
		if child:IsA("Seat") and child.Occupant == nil then
			return child
		end
	end
	return nil
end

local function hookSeats(model: Model, owner: Player, def: VehicleDef)
	local chassis = model.PrimaryPart
	for _, child in model:GetChildren() do
		if not (child:IsA("Seat") or child:IsA("VehicleSeat")) then
			continue
		end
		local seat = child :: Seat | VehicleSeat
		local isDriver = seat:IsA("VehicleSeat")
		local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			continue
		end

		prompt.Triggered:Connect(function(who: Player)
			local root, humanoid = getRoot(who)
			if root == nil or humanoid == nil or humanoid.SeatPart ~= nil then
				return
			end
			if (root.Position - seat.Position).Magnitude > prompt.MaxActivationDistance + 8 then
				return
			end
			local target = pickSeat(model, seat, who == owner)
			if target == nil then
				EconomyService.notify(who, `{def.name} sudah penuh.`)
				return
			end
			target:Sit(humanoid)
		end)

		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occupant = seat.Occupant
			prompt.Enabled = occupant == nil
			if not isDriver or chassis == nil or not chassis:IsDescendantOf(Workspace) then
				return
			end
			-- Pengemudi mensimulasikan fisika mobilnya sendiri (tanpa jeda input).
			local driver = if occupant then Players:GetPlayerFromCharacter(occupant.Parent) else nil
			if driver ~= nil and driver ~= owner then
				-- jalur lain untuk duduk (mis. exploit): keluarkan
				occupant.Sit = false
				return
			end
			pcall(function()
				if driver then
					chassis:SetNetworkOwner(driver)
				else
					chassis:SetNetworkOwnershipAuto()
				end
			end)
		end)
	end
end

-- ---------------------------------------------------------------- spawn

-- Mencari tempat kosong di dekat pemain. Mengembalikan CFrame titik tanah
-- (depan = arah hadap pemain) atau nil + alasan.
local function findSpawnCFrame(root: BasePart, def: VehicleDef): (CFrame?, string?)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance, vehicleFolder }

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { root.Parent :: Instance }

	local body = def.body
	local height = body.lowerHeight + body.cabinHeight
	local distance = VehicleConfig.SPAWN_DISTANCE
	local reason = "Tempatnya terlalu sempit. Cari tempat yang lapang ya!"

	for _, offset in { look * distance, right * distance, -right * distance, -look * distance } do
		local origin = root.Position + offset + Vector3.new(0, 5, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -40, 0), rayParams)
		if hit == nil then
			continue
		end
		if hit.Material == Enum.Material.Water then
			reason = "Mobil tidak bisa dikeluarkan di atas air."
			continue
		end
		if hit.Normal.Y < 0.85 then
			reason = "Tanahnya terlalu miring. Cari tempat yang datar ya!"
			continue
		end
		local ground = CFrame.lookAt(hit.Position, hit.Position + look)
		local box = ground * CFrame.new(0, body.clearance + height / 2 + 0.6, 0)
		local blocked = false
		for _, other in
			Workspace:GetPartBoundsInBox(box, Vector3.new(body.width, height, body.length), overlap)
		do
			if other.CanCollide then
				blocked = true
				break
			end
		end
		if not blocked then
			return ground * CFrame.new(0, 0.4, 0), nil
		end
	end
	return nil, reason
end

local function spawnVehicle(player: Player, vehicleId: any): VehicleResult
	local def = VehicleConfig.get(vehicleId)
	if def == nil then
		return result(false, "Kendaraan tidak dikenal.")
	end
	if not DataService.isLoaded(player) then
		return result(false, "Data kamu masih dimuat...")
	end
	if def.job then
		-- Kendaraan dinas: gratis, tapi hanya selama menjalani pekerjaannya.
		local data = DataService.getData(player)
		if data == nil or data.jobs.current ~= def.job then
			local job = JobConfig.get(def.job)
			local jobName = if job then job.name else "petugas"
			return result(false, `{def.name} hanya untuk {jobName} yang sedang bertugas.`)
		end
	elseif not VehicleService.owns(player, def.id) then
		return result(false, `Kamu belum punya {def.name}. Beli dulu di Dealer Mobil ya!`)
	end
	local root, humanoid = getRoot(player)
	if root == nil or humanoid == nil then
		return result(false, "Tunggu sampai karaktermu muncul ya.")
	end
	if humanoid.SeatPart ~= nil then
		return result(false, "Turun dulu dari kursi sebelum mengeluarkan mobil.")
	end
	local now = os.clock()
	local last = lastSpawn[player]
	if last and now - last < VehicleConfig.SPAWN_COOLDOWN then
		return result(false, "Sebentar ya, mobilnya sedang disiapkan.")
	end

	local cframe, reason = findSpawnCFrame(root, def)
	if cframe == nil then
		return result(false, reason or "Tidak bisa mengeluarkan mobil di sini.")
	end

	lastSpawn[player] = now
	-- Batas spawn: satu kendaraan per pemain; yang lama disimpan otomatis.
	VehicleService.despawn(player)

	local model = VehicleBuilder.build(def)
	model:SetAttribute(VehicleConfig.ATTR_OWNER, player.UserId)
	model:PivotTo(cframe)
	hookSeats(model, player, def)
	model.Parent = vehicleFolder
	CollectionService:AddTag(model, VehicleConfig.TAG_VEHICLE)
	spawned[player] = model

	return result(true, `{def.name} siap! Dekati pintunya lalu tekan "Kemudikan".`)
end

-- ---------------------------------------------------------------- beli

local function buyVehicle(player: Player, vehicleId: any): VehicleResult
	local def = VehicleConfig.get(vehicleId)
	if def == nil then
		return result(false, "Kendaraan tidak dikenal.")
	end
	if def.job then
		return result(false, `{def.name} adalah kendaraan dinas dan tidak dijual.`)
	end
	local data = DataService.getData(player)
	if data == nil then
		return result(false, "Data kamu masih dimuat...")
	end
	if data.vehicles[def.id] ~= nil then
		return result(false, `Kamu sudah punya {def.name}.`)
	end
	local root = getRoot(player)
	if root == nil or not isNearDealer(root) then
		return result(false, "Datang ke Dealer Mobil untuk membeli ya!")
	end
	if data.money < def.price then
		return result(
			false,
			`Uangmu belum cukup. Kurang {Format.money(def.price - data.money)} lagi.`
		)
	end
	if not EconomyService.trySpend(player, def.price, "vehicle:" .. def.id) then
		return result(false, "Pembelian gagal, coba lagi.")
	end
	data.vehicles[def.id] = { boughtAt = os.time() }
	publishOwned(player)
	return result(true, `Selamat! {def.name} sekarang milikmu.`)
end

-- ---------------------------------------------------------------- balikkan mobil

local function flipVehicle(player: Player)
	local now = os.clock()
	local last = lastFlip[player]
	if last and now - last < 2 then
		return
	end
	local model = spawned[player]
	if model == nil or model.PrimaryPart == nil then
		return
	end
	local pivot = model:GetPivot()
	if pivot.UpVector.Y > 0.6 then
		return -- tidak terbalik
	end
	local root = getRoot(player)
	if root == nil or (root.Position - pivot.Position).Magnitude > 40 then
		return
	end
	lastFlip[player] = now
	local look = pivot.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local position = pivot.Position + Vector3.new(0, 3, 0)
	model:PivotTo(CFrame.lookAt(position, position + look.Unit))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- ---------------------------------------------------------------- dealer

local function buildDealerDisplays()
	local slots: { BasePart } = {}
	for _, slot in CollectionService:GetTagged(VehicleConfig.TAG_DISPLAY_SLOT) do
		if slot:IsA("BasePart") and slot:IsDescendantOf(Workspace) then
			table.insert(slots, slot)
		end
	end
	if #slots == 0 then
		warn("[Vehicle] Tidak ada slot pajangan dealer di peta (jalankan map/BuildDealer).")
		return
	end
	table.sort(slots, function(a, b)
		return ((a:GetAttribute("Order") :: number?) or 0)
			< ((b:GetAttribute("Order") :: number?) or 0)
	end)

	local displays = Instance.new("Folder")
	displays.Name = "DealerDisplays"
	for index, def in VehicleConfig.LIST do
		local slot = slots[index]
		if slot == nil then
			warn(`[Vehicle] Slot pajangan kurang untuk {def.id}`)
			break
		end
		local model = VehicleBuilder.build(def, { static = true })
		model.Name = "Display_" .. def.id
		model:PivotTo(slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0))
		local anchor = model.PrimaryPart :: BasePart

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DealerPrompt"
		prompt.ActionText = "Lihat"
		prompt.ObjectText = `{def.name} · {Format.money(def.price)}`
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute(VehicleConfig.ATTR_DEALER_PROMPT, def.id)
		prompt.Parent = anchor

		local board = Instance.new("BillboardGui")
		board.Name = "PriceTag"
		board.Size = UDim2.fromScale(9, 2.6)
		board.StudsOffsetWorldSpace =
			Vector3.new(0, def.body.lowerHeight + def.body.cabinHeight + 3, 0)
		board.MaxDistance = 90
		board.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		label.BackgroundTransparency = 0.1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(40, 48, 60)
		label.Text = `{def.name}\n{Format.money(def.price)}`
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = label
		label.Parent = board
		board.Parent = anchor

		model.Parent = displays
	end
	displays.Parent = Workspace
end

-- ---------------------------------------------------------------- pengawas kecepatan

local function watchSpeeds()
	while true do
		task.wait(1)
		for player, model in spawned do
			local chassis = model.PrimaryPart
			local def = VehicleConfig.get(model:GetAttribute(VehicleConfig.ATTR_VEHICLE_ID))
			if chassis == nil or def == nil then
				continue
			end
			if chassis.Position.Y < -200 then
				VehicleService.despawn(player) -- jatuh keluar dunia
				continue
			end
			local velocity = chassis.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			if velocity.Magnitude > def.maxSpeed * VehicleConfig.SPEED_TOLERANCE then
				local strikes = (speedStrikes[player] or 0) + 1
				speedStrikes[player] = strikes
				if strikes >= 4 then
					VehicleService.despawn(player)
					EconomyService.notify(
						player,
						"Mobilmu dikembalikan ke garasi. Keluarkan lagi dari menu Kendaraan."
					)
				end
			else
				speedStrikes[player] = nil
			end
		end
	end
end

-- ---------------------------------------------------------------- bootstrap

local function wrap(
	label: string,
	handler: (Player, any) -> VehicleResult
): (Player, any) -> VehicleResult
	return function(player: Player, arg: any): VehicleResult
		if not allowCall(player) then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		local ok, value = pcall(handler, player, arg)
		if ok then
			return value
		end
		warn(`[Vehicle] {label} error: {tostring(value)}`)
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
end

function VehicleService.init()
	PhysicsService:RegisterCollisionGroup(VehicleBuilder.GROUP_BODY)
	PhysicsService:RegisterCollisionGroup(VehicleBuilder.GROUP_WHEEL)
	-- roda tidak menabrak bodi (roda berada di dalam kotak bodi)
	PhysicsService:CollisionGroupSetCollidable(
		VehicleBuilder.GROUP_BODY,
		VehicleBuilder.GROUP_WHEEL,
		false
	)

	local existing = Workspace:FindFirstChild("Vehicles")
	if existing and existing:IsA("Folder") then
		vehicleFolder = existing
	else
		vehicleFolder = Instance.new("Folder")
		vehicleFolder.Name = "Vehicles"
		vehicleFolder.Parent = Workspace
	end

	Net.func(Net.Names.VehicleBuy).OnServerInvoke = wrap("Buy", buyVehicle)
	Net.func(Net.Names.VehicleSpawn).OnServerInvoke = wrap("Spawn", spawnVehicle)
	Net.func(Net.Names.VehicleDespawn).OnServerInvoke = wrap(
		"Despawn",
		function(player: Player): VehicleResult
			if spawned[player] == nil then
				return result(false, "Tidak ada mobil yang sedang dikeluarkan.")
			end
			VehicleService.despawn(player)
			return result(true, "Mobil disimpan ke garasi.")
		end
	)
	Net.event(Net.Names.VehicleFlip).OnServerEvent:Connect(function(player: Player)
		local ok, err = pcall(flipVehicle, player)
		if not ok then
			warn("[Vehicle] Flip error: " .. tostring(err))
		end
	end)
end

function VehicleService.start()
	DataService.ProfileLoaded:Connect(function(player: Player)
		publishOwned(player)
	end)
	for _, player in Players:GetPlayers() do
		publishOwned(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		VehicleService.despawn(player)
		lastSpawn[player] = nil
		lastCall[player] = nil
		lastFlip[player] = nil
	end)

	buildDealerDisplays()
	task.spawn(watchSpeeds)
end

return VehicleService
