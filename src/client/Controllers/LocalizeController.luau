--!strict
-- LocalizeController: menerjemahkan semua teks yang tampil ke bahasa pemain (Indonesia/Inggris).
--   * Bahasa awal dari locale Roblox pemain (id-* = Indonesia, selain itu Inggris). Pilihan pemain
--     (tombol di menu HP) disimpan server di atribut Player "Lang" dan dipakai lagi saat login berikutnya.
--   * Teks sumber selalu Indonesia. Saat bahasa "en", tiap TextLabel/TextButton/TextBox.PlaceholderText di
--     PlayerGui, serta TextLabel papan di dunia (BillboardGui/SurfaceGui) dan ProximityPrompt, diterjemahkan lewat
--     Loc (kamus di shared/LocStrings). Saat bahasa "id" semuanya dikembalikan ke teks asli.
--   * Hemat: berbasis event (DescendantAdded + perubahan properti), tanpa loop per frame.
--   * Mengecualikan elemen: Attribute NoLoc = true.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Loc = require(Shared:WaitForChild("Loc"))

local LocalizeController = {}

local player = Players.LocalPlayer
local ATTR_LANG = "Lang"
local SCAN_CHUNK = 4000
local SET_COOLDOWN = 1

-- Properti teks per kelas.
local PROPS_BY_CLASS: { [string]: { string } } = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	TextBox = { "PlaceholderText" }, -- isi TextBox adalah ketikan pemain; jangan disentuh
	ProximityPrompt = { "ActionText", "ObjectText" },
}

type Record = { src: string, out: string }

-- tracked[instance][properti] = { src, out }; kunci lemah supaya instance yang dihapus ikut terbuang.
local tracked: { [Instance]: { [string]: Record } } = setmetatable({}, { __mode = "k" }) :: any
local connections: { [Instance]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any

local function isEnglish(): boolean
	return Loc.getLanguage() == "en"
end

-- Pemain berbahasa Indonesia tidak perlu apa pun: pengamatan baru dipasang saat bahasa pertama kali "en".
local active = false
local roots: { Instance } = {}

local function applyProperty(instance: Instance, prop: string)
	local current = (instance :: any)[prop]
	if type(current) ~= "string" then
		return
	end
	local records = tracked[instance]
	if records == nil then
		records = {}
		tracked[instance] = records
	end
	local record = records[prop]
	if record and current == record.out and record.out ~= record.src then
		return -- perubahan ini hasil terjemahan kita sendiri
	end
	if record == nil then
		record = { src = current, out = current }
		records[prop] = record
	end
	record.src = current
	if isEnglish() and instance:GetAttribute("NoLoc") ~= true then
		local translated = Loc.translate(current)
		record.out = translated
		if translated ~= current then
			(instance :: any)[prop] = translated
		end
	else
		record.out = current
	end
end

local function watch(instance: Instance)
	local props = PROPS_BY_CLASS[instance.ClassName]
	if props == nil or connections[instance] ~= nil then
		return
	end
	local list: { RBXScriptConnection } = {}
	connections[instance] = list
	for _, prop in props do
		applyProperty(instance, prop)
		table.insert(
			list,
			instance:GetPropertyChangedSignal(prop):Connect(function()
				applyProperty(instance, prop)
			end)
		)
	end
end

-- Pasang pengamat pada semua turunan root (dipotong-potong supaya tidak menahan frame).
local function scan(root: Instance)
	local count = 0
	for _, descendant in root:GetDescendants() do
		if PROPS_BY_CLASS[descendant.ClassName] then
			watch(descendant)
		end
		count += 1
		if count % SCAN_CHUNK == 0 then
			task.wait()
		end
	end
end

local function observe(root: Instance)
	table.insert(roots, root)
	root.DescendantAdded:Connect(function(descendant: Instance)
		if active and PROPS_BY_CLASS[descendant.ClassName] then
			watch(descendant)
		end
	end)
	if active then
		task.spawn(scan, root)
	end
end

local function activate()
	if active then
		return
	end
	active = true
	for _, root in roots do
		task.spawn(scan, root)
	end
end

-- Terjemahkan ulang (atau kembalikan) semua teks yang sudah dikenal setelah bahasa berganti.
local function refreshAll()
	for instance, records in tracked do
		for prop, record in records do
			local current = (instance :: any)[prop]
			if type(current) == "string" then
				if current ~= record.out then
					record.src = current -- diubah skrip lain selagi kita tidak melihat
				end
				local target = record.src
				if isEnglish() and instance:GetAttribute("NoLoc") ~= true then
					target = Loc.translate(record.src)
				end
				record.out = target
				if current ~= target then
					(instance :: any)[prop] = target
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- bahasa pemain

local function setFromAttribute()
	local value = player:GetAttribute(ATTR_LANG)
	if value == "id" or value == "en" then
		Loc.setLanguage(value :: any)
	end
end

-- Dipanggil tombol bahasa di HP: ganti seketika di client, lalu minta server menyimpan.
local lastRequest = 0
function LocalizeController.setLanguage(lang: Loc.Lang)
	Loc.setLanguage(lang)
	local now = os.clock()
	if now - lastRequest >= SET_COOLDOWN then
		lastRequest = now
		Net.event(Net.Names.SetLanguage):FireServer(lang)
	else
		task.delay(SET_COOLDOWN, function()
			Net.event(Net.Names.SetLanguage):FireServer(Loc.getLanguage())
		end)
	end
end

function LocalizeController.toggle()
	LocalizeController.setLanguage(if Loc.getLanguage() == "id" then "en" else "id")
end

function LocalizeController.init()
	Loc.setLanguage(Loc.detect(player.LocaleId))
	setFromAttribute() -- kalau server sudah sempat mengisi pilihan tersimpan
	Loc.Changed:Connect(function()
		if isEnglish() then
			activate()
		end
		refreshAll()
	end)
	player:GetAttributeChangedSignal(ATTR_LANG):Connect(setFromAttribute)

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		observe(playerGui)
	else
		task.spawn(function()
			observe(player:WaitForChild("PlayerGui"))
		end)
	end
	observe(Workspace)
	if isEnglish() then
		activate()
	end
end

return LocalizeController
