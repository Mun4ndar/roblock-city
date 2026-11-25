--!strict
-- PortalService: pintu masuk/keluar ruang dalam (isi rumah, rumah sakit, bandara).
-- Ruang dalam dibangun tepat DI ATAS bangunannya (jauh di langit, tidak terlihat dari
-- tanah), jadi posisi mendatar pemain tidak berubah: GPS, misi, dan pengawas pekerjaan tetap benar.
--
-- Portal = Part bertag "Portal" dengan atribut:
--   PortalId     : nama unik portal ini
--   PortalTarget : PortalId tujuan
--   PortalText   : teks tombol (mis. "Masuk", "Keluar")
-- Pemain muncul 5 stud di depan (sisi Front) part tujuan. Portal peta dipasang oleh
-- map/BuildInteriors.luau; portal rumah dipasang HouseService lewat addPortal().

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local PortalService = {}

local TAG = "Portal"
local ATTR_ID = "PortalId"
local ATTR_TARGET = "PortalTarget"
local ATTR_TEXT = "PortalText"
local PROMPT_NAME = "PortalPrompt"
local COOLDOWN = 1.5
local ARRIVE_OFFSET = CFrame.new(0, 0, -5)

local portals: { [string]: BasePart } = {}
local guards: { (Player, BasePart) -> (boolean, string?) } = {}
local lastUse: { [Player]: number } = {}

-- Pindahkan pemain dengan aman: turun dari kursi dulu, muat area tujuan, baru pindah.
function PortalService.teleport(player: Player, destination: CFrame): boolean
	local now = os.clock()
	local last = lastUse[player]
	if last and now - last < COOLDOWN then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	lastUse[player] = now
	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.15)
	end
	pcall(function()
		player:RequestStreamAroundAsync(destination.Position, 3)
	end)
	if character.Parent == nil then
		return false
	end
	character:PivotTo(destination + Vector3.new(0, 1, 0))
	return true
end

local function onTriggered(part: BasePart, player: Player)
	local targetId = part:GetAttribute(ATTR_TARGET)
	local target = if type(targetId) == "string" then portals[targetId] else nil
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if target == nil or target.Parent == nil or root == nil then
		return
	end
	-- Tombol hanya sah kalau pemain memang di dekat portalnya.
	if (root.Position - part.Position).Magnitude > 24 then
		return
	end
	for _, guard in guards do
		local allowed, reason = guard(player, part)
		if not allowed then
			local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
			Net.event(Net.Names.Notify):FireClient(player, reason or "Pintu ini tidak bisa dimasuki.")
			return
		end
	end
	PortalService.teleport(player, target.CFrame * ARRIVE_OFFSET)
end

-- Penjaga pintu: fn(pemain, part portal) -> (boleh, alasan). Dipakai SocialService untuk akses rumah.
function PortalService.addGuard(guard: (Player, BasePart) -> (boolean, string?))
	table.insert(guards, guard)
end

local function register(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local id = inst:GetAttribute(ATTR_ID)
	if type(id) ~= "string" or id == "" then
		return
	end
	portals[id] = inst
	if inst:FindFirstChild(PROMPT_NAME) then
		return
	end
	local text = inst:GetAttribute(ATTR_TEXT)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = if type(text) == "string" then text else "Masuk"
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- E dipakai tombol lain (tugas, lihat rumah)
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -70)
	prompt.Triggered:Connect(function(player: Player)
		onTriggered(inst, player)
	end)
	prompt.Parent = inst
end

local function unregister(inst: Instance)
	local id = inst:GetAttribute(ATTR_ID)
	if type(id) == "string" and portals[id] == inst then
		portals[id] = nil
	end
	local prompt = inst:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
end

-- Jadikan sebuah part portal saat permainan berjalan (dipakai pintu rumah pemain).
function PortalService.addPortal(part: BasePart, id: string, targetId: string, text: string)
	part:SetAttribute(ATTR_ID, id)
	part:SetAttribute(ATTR_TARGET, targetId)
	part:SetAttribute(ATTR_TEXT, text)
	CollectionService:AddTag(part, TAG)
end

function PortalService.removePortal(part: BasePart)
	CollectionService:RemoveTag(part, TAG)
	unregister(part)
end

function PortalService.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
	for _, inst in CollectionService:GetTagged(TAG) do
		register(inst)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
	end)
end

return PortalService
