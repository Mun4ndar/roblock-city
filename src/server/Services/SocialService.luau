--!strict
-- SocialService: kunjungan rumah teman, kru/keluarga, dan pengaturan akses rumah.
--   * akses rumah (terbuka / teman & kru / kru saja / terkunci) dicek server di pintu rumah
--   * kru disimpan di DataStore "RoblockCrews_v1" (nama, ketua, anggota); pemain hanya
--     menyimpan id kru di PlayerData.social
--   * semua aksi lewat remote SocialAction; client hanya meminta, server memvalidasi

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local HouseService = require(script.Parent:WaitForChild("HouseService"))
local PortalService = require(script.Parent:WaitForChild("PortalService"))

type Result = { ok: boolean, message: string, members: { any }?, crewName: string? }
type Crew = { name: string, leader: number, members: { [string]: string } }

local SocialService = {}

local CALL_COOLDOWN = 0.4
local FRIEND_CACHE_SECONDS = 120

local store = DataStoreService:GetDataStore("RoblockCrews_v1")
local crews: { [string]: Crew } = {}
local invites: { [Player]: { crewId: string, from: Player, expires: number } } = {}
local lastCall: { [Player]: number } = {}
local friendCache: { [string]: { value: boolean, at: number } } = {}
local inviteRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function result(ok: boolean, message: string): Result
	return { ok = ok, message = message }
end

local function notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

local function social(player: Player): any?
	local data: any = DataService.getData(player)
	if data == nil then
		return nil
	end
	if type(data.social) ~= "table" then
		data.social = {}
	end
	if type(data.social.crew) ~= "string" then
		data.social.crew = ""
	end
	if not SocialConfig.validAccess(data.social.access) then
		data.social.access = SocialConfig.DEFAULT_ACCESS
	end
	return data.social
end

-- ---------------------------------------------------------------- DataStore kru

local function retry(fn: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, 3 do
		local ok, value = pcall(fn)
		if ok then
			return true, value
		end
		lastError = value
		task.wait(attempt)
	end
	warn("[Social] DataStore gagal: " .. tostring(lastError))
	return false, nil
end

-- Kembalikan (kru, berhasil). berhasil=false = DataStore gagal (jangan anggap kru bubar).
local function loadCrew(id: string): (Crew?, boolean)
	local cached = crews[id]
	if cached then
		return cached, true
	end
	local ok, value = retry(function(): any
		return store:GetAsync("c_" .. id)
	end)
	if ok and type(value) == "table" and type(value.members) == "table" then
		crews[id] = value :: Crew
		return value :: Crew, true
	end
	return nil, ok
end

-- fn mengubah salinan data kru; kembalikan nil untuk menghapus kru.
local function updateCrew(id: string, fn: (Crew) -> Crew?): (boolean, Crew?)
	local latest: Crew? = nil
	local ok = retry(function(): any
		return store:UpdateAsync("c_" .. id, function(old: any): any
			if type(old) ~= "table" or type(old.members) ~= "table" then
				latest = nil
				return nil
			end
			latest = fn(old :: Crew)
			return latest
		end)
	end)
	if ok then
		crews[id] = latest :: any
	end
	return ok, latest
end

local function memberCount(crew: Crew): number
	local n = 0
	for _ in crew.members do
		n += 1
	end
	return n
end

local function filterName(raw: string, player: Player): string?
	local text = string.gsub(raw, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if #text < SocialConfig.CREW_NAME_MIN or #text > SocialConfig.CREW_NAME_MAX then
		return nil
	end
	if string.find(text, "[^%w ]") then
		return nil
	end
	local ok, filtered = pcall(function(): string
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
			:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or filtered ~= text then
		return nil
	end
	return text
end

-- ---------------------------------------------------------------- atribut

local function publish(player: Player)
	local s = social(player)
	if s == nil then
		return
	end
	player:SetAttribute(SocialConfig.ATTR_ACCESS, s.access)
	local crew = if s.crew ~= "" then crews[s.crew] else nil
	player:SetAttribute(SocialConfig.ATTR_CREW_ID, if crew then s.crew else "")
	player:SetAttribute(SocialConfig.ATTR_CREW_NAME, if crew then crew.name else "")
	player:SetAttribute(SocialConfig.ATTR_CREW_LEADER, crew ~= nil and crew.leader == player.UserId)
end

local function onProfileLoaded(player: Player)
	local s = social(player)
	if s == nil then
		return
	end
	if s.crew ~= "" then
		local crew, ok = loadCrew(s.crew)
		if ok and (crew == nil or crew.members[tostring(player.UserId)] == nil) then
			s.crew = "" -- kru bubar atau dikeluarkan saat offline
		end
	end
	publish(player)
end

-- ---------------------------------------------------------------- akses rumah

local function areFriends(a: Player, b: Player): boolean
	local lo, hi = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = `{lo}_{hi}`
	local hit = friendCache[key]
	if hit and os.clock() - hit.at < FRIEND_CACHE_SECONDS then
		return hit.value
	end
	local ok, value = pcall(function(): boolean
		return a:IsFriendsWith(b.UserId)
	end)
	local friends = ok and value == true
	friendCache[key] = { value = friends, at = os.clock() }
	return friends
end

local function sameCrew(a: Player, b: Player): boolean
	local id = a:GetAttribute(SocialConfig.ATTR_CREW_ID)
	return type(id) == "string" and id ~= "" and id == b:GetAttribute(SocialConfig.ATTR_CREW_ID)
end

function SocialService.canEnter(visitor: Player, owner: Player): (boolean, string?)
	if visitor == owner then
		return true, nil
	end
	local mode = owner:GetAttribute(SocialConfig.ATTR_ACCESS)
	if mode == "open" then
		return true, nil
	elseif mode == "locked" then
		return false, `Rumah {owner.DisplayName} sedang dikunci.`
	elseif mode == "crew" then
		if sameCrew(visitor, owner) then
			return true, nil
		end
		return false, `Rumah {owner.DisplayName} hanya untuk anggota kru.`
	end
	if sameCrew(visitor, owner) or areFriends(visitor, owner) then
		return true, nil
	end
	return false, `Rumah {owner.DisplayName} hanya untuk teman dan kru.`
end

local function houseGuard(player: Player, part: BasePart): (boolean, string?)
	local id = part:GetAttribute("PortalId")
	local number = if type(id) == "string" then id:match("^rumah(%d+)Luar$") else nil
	if number == nil then
		return true, nil
	end
	local owner = HouseService.ownerOf(tonumber(number) :: number)
	if owner == nil then
		return true, nil
	end
	return SocialService.canEnter(player, owner)
end

-- ---------------------------------------------------------------- aksi

local function setAccess(player: Player, mode: any): Result
	if not SocialConfig.validAccess(mode) then
		return result(false, "Pilihan tidak dikenal.")
	end
	local s = social(player)
	if s == nil then
		return result(false, "Data belum siap.")
	end
	s.access = mode
	publish(player)
	return result(true, "Akses rumah diperbarui.")
end

local function visit(player: Player, userId: any): Result
	local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if target == nil or target == player then
		return result(false, "Pemain tidak ditemukan.")
	end
	local houseId = HouseService.houseIdOf(target)
	local door = if houseId then HouseService.doorFront(houseId) else nil
	if houseId == nil or door == nil then
		return result(false, `{target.DisplayName} belum punya rumah di server ini.`)
	end
	local ok, why = SocialService.canEnter(player, target)
	if not ok then
		return result(false, why or "Tidak boleh masuk.")
	end
	if not PortalService.teleport(player, door * CFrame.new(0, 0, -4)) then
		return result(false, "Belum bisa pindah sekarang.")
	end
	return result(true, `Berkunjung ke rumah {target.DisplayName}!`)
end

local function createCrew(player: Player, rawName: any): Result
	local s = social(player)
	if s == nil then
		return result(false, "Data belum siap.")
	end
	if s.crew ~= "" then
		return result(false, "Kamu sudah punya kru.")
	end
	if type(rawName) ~= "string" then
		return result(false, "Nama kru tidak valid.")
	end
	local name = filterName(rawName, player)
	if name == nil then
		return result(
			false,
			`Nama kru {SocialConfig.CREW_NAME_MIN}-{SocialConfig.CREW_NAME_MAX} huruf/angka, tanpa kata terlarang.`
		)
	end
	local id = HttpService:GenerateGUID(false)
	local crew: Crew = {
		name = name,
		leader = player.UserId,
		members = { [tostring(player.UserId)] = player.DisplayName },
	}
	local ok = retry(function(): any
		return store:SetAsync("c_" .. id, crew)
	end)
	if not ok then
		return result(false, "Gagal membuat kru, coba lagi nanti.")
	end
	crews[id] = crew
	s.crew = id
	publish(player)
	return result(true, `Kru "{name}" berdiri!`)
end

local function invite(player: Player, userId: any): Result
	local s = social(player)
	local crew = if s and s.crew ~= "" then crews[s.crew] else nil
	if s == nil or crew == nil then
		return result(false, "Buat kru dulu.")
	end
	if crew.leader ~= player.UserId then
		return result(false, "Hanya ketua kru yang boleh mengundang.")
	end
	local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if target == nil or target == player then
		return result(false, "Pemain tidak ditemukan.")
	end
	if target:GetAttribute(SocialConfig.ATTR_CREW_ID) ~= "" then
		return result(false, `{target.DisplayName} sudah punya kru.`)
	end
	if memberCount(crew) >= SocialConfig.CREW_MAX then
		return result(false, "Kru sudah penuh.")
	end
	local a = player.Character and player.Character.PrimaryPart
	local b = target.Character and target.Character.PrimaryPart
	if a == nil or b == nil or (a.Position - b.Position).Magnitude > SocialConfig.INVITE_RANGE then
		return result(false, "Pemain itu terlalu jauh, dekati dulu.")
	end
	invites[target] = {
		crewId = player:GetAttribute(SocialConfig.ATTR_CREW_ID) :: string,
		from = player,
		expires = os.clock() + SocialConfig.INVITE_SECONDS,
	}
	inviteRemote:FireClient(target, crew.name, player.DisplayName)
	return result(true, `Undangan dikirim ke {target.DisplayName}.`)
end

local function answerInvite(player: Player, accept: boolean): Result
	local inv = invites[player]
	invites[player] = nil
	if inv == nil or os.clock() > inv.expires then
		return result(false, "Undangan sudah kedaluwarsa.")
	end
	if not accept then
		return result(true, "Undangan ditolak.")
	end
	local s = social(player)
	if s == nil or s.crew ~= "" then
		return result(false, "Kamu sudah punya kru.")
	end
	local ok, crew = updateCrew(inv.crewId, function(c: Crew): Crew?
		if memberCount(c) >= SocialConfig.CREW_MAX then
			return c
		end
		c.members[tostring(player.UserId)] = player.DisplayName
		return c
	end)
	if not ok or crew == nil or crew.members[tostring(player.UserId)] == nil then
		return result(false, "Kru penuh atau sudah bubar.")
	end
	s.crew = inv.crewId
	publish(player)
	notify(inv.from, `{player.DisplayName} bergabung ke kru!`)
	return result(true, `Selamat datang di kru "{crew.name}"!`)
end

local function removeMember(crewId: string, userId: number)
	updateCrew(crewId, function(c: Crew): Crew?
		c.members[tostring(userId)] = nil
		if next(c.members) == nil then
			return nil
		end
		if c.leader == userId then
			local newLeader = next(c.members)
			c.leader = tonumber(newLeader) or 0
		end
		return c
	end)
end

local function leave(player: Player): Result
	local s = social(player)
	if s == nil or s.crew == "" then
		return result(false, "Kamu belum punya kru.")
	end
	local crewId = s.crew
	s.crew = ""
	publish(player)
	removeMember(crewId, player.UserId)
	for _, other in Players:GetPlayers() do
		if other:GetAttribute(SocialConfig.ATTR_CREW_ID) == crewId then
			publish(other)
		end
	end
	return result(true, "Kamu keluar dari kru.")
end

local function kick(player: Player, userId: any): Result
	local s = social(player)
	local crew = if s and s.crew ~= "" then crews[s.crew] else nil
	if s == nil or crew == nil or crew.leader ~= player.UserId then
		return result(false, "Hanya ketua kru yang boleh mengeluarkan anggota.")
	end
	if
		type(userId) ~= "number"
		or userId == player.UserId
		or crew.members[tostring(userId)] == nil
	then
		return result(false, "Anggota tidak ditemukan.")
	end
	removeMember(s.crew, userId)
	local target = Players:GetPlayerByUserId(userId)
	if target then
		local ts = social(target)
		if ts then
			ts.crew = ""
		end
		publish(target)
		notify(target, "Kamu dikeluarkan dari kru.")
	end
	return result(true, "Anggota dikeluarkan.")
end

local function roster(player: Player): Result
	local s = social(player)
	local crew = if s and s.crew ~= "" then loadCrew(s.crew) else nil
	if crew == nil then
		return { ok = true, message = "", members = {}, crewName = "" }
	end
	local list = {}
	for key, name in crew.members do
		local uid = tonumber(key) or 0
		table.insert(list, {
			userId = uid,
			name = name,
			online = Players:GetPlayerByUserId(uid) ~= nil,
			leader = uid == crew.leader,
		})
	end
	table.sort(list, function(a: any, b: any)
		if a.leader ~= b.leader then
			return a.leader
		end
		return a.name < b.name
	end)
	return { ok = true, message = "", members = list, crewName = crew.name }
end

local ACTIONS: { [string]: (Player, any) -> Result } = {
	access = setAccess,
	visit = visit,
	crewCreate = createCrew,
	crewInvite = invite,
	crewAccept = function(player: Player): Result
		return answerInvite(player, true)
	end,
	crewDecline = function(player: Player): Result
		return answerInvite(player, false)
	end,
	crewLeave = leave,
	crewKick = kick,
	roster = roster,
}

function SocialService.init()
	notifyRemote = Net.event(Net.Names.Notify)
	inviteRemote = Net.event("SocialInvite")
	Net.func("SocialAction").OnServerInvoke = function(player: Player, action: any, arg: any): any
		local handler = if type(action) == "string" then ACTIONS[action] else nil
		if handler == nil then
			return result(false, "Aksi tidak dikenal.")
		end
		local now = os.clock()
		local last = lastCall[player]
		if last and now - last < CALL_COOLDOWN then
			return result(false, "Pelan-pelan ya, coba lagi sebentar.")
		end
		lastCall[player] = now
		local ok, value = pcall(handler, player, arg)
		if ok then
			return value
		end
		warn(`[Social] {action} error: {tostring(value)}`)
		return result(false, "Terjadi kesalahan, coba lagi nanti.")
	end
	PortalService.addGuard(function(player: Player, part: BasePart): (boolean, string?)
		return houseGuard(player, part)
	end)
end

function SocialService.start()
	DataService.ProfileLoaded:Connect(function(player: Player)
		onProfileLoaded(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.getData(player) then
			task.spawn(onProfileLoaded, player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
		invites[player] = nil
	end)
end

return SocialService
