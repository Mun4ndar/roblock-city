--!strict
-- LanguageService: menyimpan pilihan bahasa pemain (Indonesia "id" / Inggris "en").
-- Server tidak menerjemahkan apa pun: semua pesan tetap Indonesia dan diterjemahkan di client
-- (LocalizeController + shared/Loc). Service ini hanya
--   * menyimpan pilihan pemain di data profil (field `lang`, tanpa perubahan skema), dan
--   * mengisinya ke atribut Player "Lang" supaya client memakainya saat login berikutnya.
-- Pemain yang belum pernah memilih tidak punya atribut: client memakai locale Roblox-nya.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local LanguageService = {}

local ATTR_LANG = "Lang"
local COOLDOWN = 0.5
local lastCall: { [Player]: number } = {}

local function isLang(value: any): boolean
	return value == "id" or value == "en"
end

local function publish(player: Player, data: any)
	if isLang(data.lang) then
		player:SetAttribute(ATTR_LANG, data.lang)
	end
end

function LanguageService.init()
	local remote = Net.event(Net.Names.SetLanguage)
	remote.OnServerEvent:Connect(function(player: Player, lang: any)
		if not isLang(lang) then
			return
		end
		local now = os.clock()
		if now - (lastCall[player] or 0) < COOLDOWN then
			return
		end
		lastCall[player] = now
		local data: any = DataService.getData(player)
		if data == nil then
			return
		end
		data.lang = lang
		player:SetAttribute(ATTR_LANG, lang)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCall[player] = nil
	end)
end

function LanguageService.start()
	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		publish(player, data)
	end)
	for _, player in Players:GetPlayers() do
		local data: any = DataService.getData(player)
		if data and player:GetAttribute(ATTR_LANG) == nil then
			publish(player, data)
		end
	end
end

return LanguageService
