--!strict
-- DebugService: alat uji, HANYA aktif di Roblox Studio (tidak pernah di server asli).
-- Membuat BindableFunction ServerStorage.Debug yang hanya bisa dipanggil dari
-- sisi server (command bar / alat uji), tidak ada remote ke client.
--   Debug:Invoke("money", player, jumlah)   -- tambah (+) atau kurangi (-) uang
--   Debug:Invoke("clock", jam)              -- setel jam dunia (0-24)
--   Debug:Invoke("costume", player, "naga_api") -- pakai costume tanpa membeli (uji tampilan)
--   Debug:Invoke("clear", player, "business") -- kosongkan satu bagian data (terisi ulang saat masuk lagi)

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local TimeService = require(script.Parent:WaitForChild("TimeService"))
local UniformService = require(script.Parent:WaitForChild("UniformService"))

local DebugService = {}

local function handle(command: any, a: any, b: any): any
	if
		command == "money"
		and typeof(a) == "Instance"
		and a:IsA("Player")
		and type(b) == "number"
	then
		if b > 0 then
			return EconomyService.addMoney(a, math.floor(b), "debug")
		elseif b < 0 then
			return EconomyService.trySpend(a, math.floor(-b), "debug")
		end
		return false
	elseif
		command == "costume"
		and typeof(a) == "Instance"
		and a:IsA("Player")
		and type(b) == "string"
	then
		local data: any = DataService.getData(a)
		if data == nil then
			return false
		end
		local fashion: any = data.fashion
		if type(fashion) ~= "table" or type(fashion.owned) ~= "table" then
			fashion = { owned = {}, active = "" }
			data.fashion = fashion
		end
		fashion.owned[b] = true
		fashion.active = b
		a:SetAttribute(
			"Fashion",
			game:GetService("HttpService"):JSONEncode({ owned = fashion.owned, active = b })
		)
		UniformService.refresh(a)
		return true
	elseif command == "clock" and type(a) == "number" then
		TimeService.setClock(a)
		return true
	elseif
		command == "clear"
		and typeof(a) == "Instance"
		and a:IsA("Player")
		and type(b) == "string"
		and b ~= "money"
		and b ~= "version"
	then
		local data: any = DataService.getData(a)
		if data == nil or data[b] == nil then
			return false
		end
		data[b] = nil
		return true
	end
	return "perintah tidak dikenal"
end

function DebugService.init()
	if not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "Debug"
	bindable.OnInvoke = handle
	bindable.Parent = ServerStorage
end

return DebugService
