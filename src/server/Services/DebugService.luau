--!strict
-- DebugService: alat uji, HANYA aktif di Roblox Studio (tidak pernah di server asli).
-- Membuat BindableFunction ServerStorage.Debug yang hanya bisa dipanggil dari
-- sisi server (command bar / alat uji), tidak ada remote ke client.
--   Debug:Invoke("money", player, jumlah)   -- tambah (+) atau kurangi (-) uang
--   Debug:Invoke("clock", jam)              -- setel jam dunia (0-24)

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local TimeService = require(script.Parent:WaitForChild("TimeService"))

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
	elseif command == "clock" and type(a) == "number" then
		TimeService.setClock(a)
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
