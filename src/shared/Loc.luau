--!strict
-- Loc: penerjemah Indonesia -> Inggris untuk seluruh game.
--
-- CARA KERJA
--   * Bahasa sumber = Indonesia. Semua kode/server/papan di dunia tetap menulis teks Indonesia.
--   * Di client, LocalizeController menerjemahkan teks yang tampil (TextLabel, TextButton, ProximityPrompt,
--     papan di dunia) ke Inggris kalau bahasa pemain "en". Pemain berbahasa Indonesia tidak berubah apa pun.
--   * Kamus ada di LocStrings/ (Ui, World, Game). Tidak perlu mengubah kode fitur: cukup tambah kamusnya.
--
-- MENAMBAH TEKS BARU UNTUK FITUR BARU
--   1. Tulis teks Indonesia di kode seperti biasa.
--   2. Tambah padanannya di salah satu berkas LocStrings:
--        exact    : ["Teks Indonesia persis"] = "English text"
--        patterns : { "Indonesia dengan {} untuk bagian berubah", "English with {}" }
--      Bagian {} juga ikut diterjemahkan (mis. nama tempat atau barang yang sudah ada di kamus).
--   3. Teks KAPITAL otomatis cocok dengan kunci berhuruf biasa ("Balai Kota" cukup untuk "BALAI KOTA").
--   4. Mau mengecualikan satu elemen UI dari terjemahan: beri Attribute NoLoc = true.
--
-- Kamus tambahan juga bisa didaftarkan dari kode lewat Loc.register({ exact = ..., patterns = ... }).

local Loc = {}

export type Lang = "id" | "en"
export type Dictionary = {
	exact: { [string]: string }?,
	patterns: { { string } }?,
}

type Pattern = {
	prefix: string,
	lua: string,
	template: string,
	caps: number,
	order: number,
}

local EXACT: { [string]: string } = {}
local LOWER_KEYS: { [string]: string } = {} -- huruf kecil -> kunci aslinya
local PATTERNS: { Pattern } = {}

local MAX_DEPTH = 3
local CACHE_LIMIT = 4000
local cache: { [string]: string } = {}
local cacheCount = 0

local current: Lang = "id"
local changedEvent = Instance.new("BindableEvent")
Loc.Changed = changedEvent.Event :: RBXScriptSignal

-- ---------------------------------------------------------------- kamus

local function escapeLua(text: string): string
	local escaped = string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return escaped
end

local function addPattern(idText: string, enText: string)
	local parts = string.split(idText, "{}")
	if #parts < 2 then
		return
	end
	local prefix = parts[1]
	for index, part in parts do
		parts[index] = escapeLua(part)
	end
	table.insert(PATTERNS, {
		prefix = prefix,
		lua = "^" .. table.concat(parts, "(.-)") .. "$",
		template = enText,
		caps = #parts - 1,
		order = #PATTERNS + 1,
	})
end

-- Daftarkan kamus tambahan (dipakai LocStrings dan bisa dipanggil fitur lain).
function Loc.register(dictionary: Dictionary)
	if dictionary.exact then
		for key, value in dictionary.exact do
			if EXACT[key] == nil then
				EXACT[key] = value
			end
			local lowered = string.lower(key)
			if LOWER_KEYS[lowered] == nil then
				LOWER_KEYS[lowered] = key
			end
		end
	end
	if dictionary.patterns then
		for _, pair in dictionary.patterns do
			if type(pair[1]) == "string" and type(pair[2]) == "string" then
				addPattern(pair[1], pair[2])
			end
		end
	end
	-- Awalan literal lebih panjang diperiksa dulu, supaya "Beli bakso {}" menang atas "Beli {}".
	table.sort(PATTERNS, function(a, b)
		if #a.prefix ~= #b.prefix then
			return #a.prefix > #b.prefix
		end
		return a.order < b.order
	end)
	table.clear(cache)
	cacheCount = 0
end

-- ---------------------------------------------------------------- penerjemahan

local translateCore: (string, number) -> string?
local translateCapture: (string, number) -> string?

local function isAllCaps(text: string): boolean
	return text == string.upper(text) and text ~= string.lower(text)
end

local function lookupExact(text: string): string?
	local direct = EXACT[text]
	if direct then
		return direct
	end
	local key = LOWER_KEYS[string.lower(text)]
	if key then
		local value = EXACT[key]
		if isAllCaps(text) then
			return string.upper(value)
		end
		return value
	end
	return nil
end

local function renderTemplate(template: string, caps: { string }, depth: number): string
	local nextIndex = 0
	local rendered = string.gsub(template, "{(%d*)}", function(number: string): string
		local index
		if number == "" then
			nextIndex += 1
			index = nextIndex
		else
			index = tonumber(number) or 0
		end
		local value = caps[index]
		if value == nil then
			return ""
		end
		if depth >= MAX_DEPTH then
			return value
		end
		local pre, core, post = string.match(value, "^(%s*)(.-)(%s*)$")
		if core == nil or core == "" then
			return value
		end
		local translated = translateCapture(core, depth + 1)
		return if translated then (pre :: string) .. translated .. (post :: string) else value
	end)
	return rendered
end

function translateCore(text: string, depth: number): string?
	local found = lookupExact(text)
	if found then
		return found
	end
	for _, pattern in PATTERNS do
		local prefix = pattern.prefix
		if prefix == "" or string.sub(text, 1, #prefix) == prefix then
			local caps = { string.match(text, pattern.lua) }
			if #caps == pattern.caps then
				return renderTemplate(pattern.template, caps, depth)
			end
		end
	end
	return nil
end

-- Satu baris: coba utuh, lalu tanpa ikon/angka di awal dan ikon/spasi di akhir, lalu pecah di "·".
local function translateLine(text: string, depth: number): string?
	if depth < MAX_DEPTH and string.find(text, " Mulai di: ", 1, true) then
		local head, tail = string.match(text, "^(.-) Mulai di: (.*)$")
		if head and tail then
			local first = translateLine(head, depth + 1)
			local second = translateLine(tail, depth + 1)
			if first or second then
				return (first or head) .. " Start at: " .. (second or tail)
			end
		end
	end
	local direct = translateCore(text, depth)
	if direct then
		return direct
	end

	local lead = string.match(text, "^[%s%p\128-\255%d/]*") or ""
	local rest = string.sub(text, #lead + 1)
	local trail = string.match(rest, "[%s\128-\255]*$") or ""
	local core = string.sub(rest, 1, #rest - #trail)
	if core ~= "" and (lead ~= "" or trail ~= "") then
		local result = translateCore(core, depth)
		if result then
			return lead .. result .. trail
		end
	end

	local stem, punct = string.match(text, "^(.-)([%.!]+)$")
	if stem ~= nil and stem ~= "" and punct ~= nil then
		local result = translateCore(stem, depth)
		if result then
			return result .. punct
		end
	end

	if string.find(text, "·", 1, true) then
		local pieces = string.split(text, "·")
		local changed = false
		for index, piece in pieces do
			local pre, core2, post = string.match(piece, "^(%s*)(.-)(%s*)$")
			local translated = if core2 ~= nil and core2 ~= ""
				then translateLine(core2, depth + 1)
				else nil
			if translated then
				pieces[index] = (pre :: string) .. translated .. (post :: string)
				changed = true
			end
		end
		if changed then
			return table.concat(pieces, "·")
		end
	end
	return nil
end

translateCapture = translateLine

-- Pasca-proses khusus bahasa Inggris: satuan, durasi, dan pemisah ribuan uang.
local POST_RULES: { { string } } = {
	{ "(%d+)j (%d+)m", "%1h %2m" },
	{ "(%d+)m (%d+)d", "%1m %2s" },
	{ "km/j", "km/h" },
	{ "< 1 mnt", "< 1 min" },
	{ "(%d+) mnt", "%1 min" },
	{ "(%d+) dtk", "%1 s" },
	{ "(%d+) detik", "%1 seconds" },
	{ "(%d+) menit", "%1 minutes" },
}

local function fixMoney(number: string): string
	local trailing = ""
	if string.sub(number, -1) == "." then
		number = string.sub(number, 1, -2)
		trailing = "."
	end
	local first, tail = string.match(number, "^(%d+)(.*)$")
	if first ~= nil and tail ~= nil and #first <= 3 and tail ~= "" then
		local leftover = string.gsub(tail, "%.%d%d%d", "")
		if leftover == "" then
			local commas = string.gsub(tail, "%.", ",")
			return first .. commas .. trailing
		end
	end
	return number .. trailing
end

local function postProcess(text: string): string
	if not string.find(text, "%d") then
		return text
	end
	for _, rule in POST_RULES do
		text = string.gsub(text, rule[1], rule[2])
	end
	if string.find(text, "$", 1, true) then
		text = string.gsub(text, "%$(%d[%d%.]*)", function(number: string): string
			return "$" .. fixMoney(number)
		end)
	end
	return text
end

local function worthTranslating(text: string): boolean
	return string.find(text, "%a%a%a") ~= nil
		or string.find(text, "$", 1, true) ~= nil
		or string.find(text, "km/j", 1, true) ~= nil
end

-- Terjemahkan teks Indonesia ke Inggris. Kalau tidak ada padanannya, teks dikembalikan apa adanya.
function Loc.translate(text: string): string
	if text == "" or not worthTranslating(text) then
		return text
	end
	local hit = cache[text]
	if hit then
		return hit
	end

	local result = translateLine(text, 0)
	if result == nil and string.find(text, "\n", 1, true) then
		local lines = string.split(text, "\n")
		local changed = false
		for index, line in lines do
			local translated = translateLine(line, 0)
			if translated then
				lines[index] = translated
				changed = true
			end
		end
		if changed then
			result = table.concat(lines, "\n")
		end
	end
	local output = postProcess(result or text)

	if cacheCount >= CACHE_LIMIT then
		table.clear(cache)
		cacheCount = 0
	end
	cache[text] = output
	cacheCount += 1
	return output
end

-- ---------------------------------------------------------------- bahasa aktif

function Loc.getLanguage(): Lang
	return current
end

function Loc.setLanguage(lang: Lang)
	if (lang == "id" or lang == "en") and lang ~= current then
		current = lang
		changedEvent:Fire(lang)
	end
end

-- Bahasa awal dari locale Roblox pemain: "id-id" -> Indonesia, selain itu Inggris.
function Loc.detect(localeId: string?): Lang
	if localeId ~= nil and string.sub(string.lower(localeId), 1, 2) == "id" then
		return "id"
	end
	return "en"
end

-- Teks dalam bahasa aktif (untuk kode yang membuat teks sendiri dan ingin langsung memakai Loc).
function Loc.t(text: string): string
	if current == "en" then
		return Loc.translate(text)
	end
	return text
end

-- ---------------------------------------------------------------- muat kamus

local function loadDictionaries()
	local folder = script.Parent:FindFirstChild("LocStrings")
	if folder == nil then
		warn("[Loc] folder LocStrings tidak ditemukan")
		return
	end
	local modules = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	for _, moduleScript in modules do
		local ok, dictionary = pcall(require, moduleScript)
		if ok and type(dictionary) == "table" then
			Loc.register(dictionary :: Dictionary)
		else
			warn(`[Loc] gagal memuat {moduleScript.Name}: {tostring(dictionary)}`)
		end
	end
end

loadDictionaries()

return Loc
