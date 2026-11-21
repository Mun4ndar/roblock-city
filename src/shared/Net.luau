--!strict
-- Registri remote. Server membuat instance remote; client menunggu.
-- Semua nama remote dideklarasikan di sini supaya tidak ada string tersebar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Net = {}

Net.Names = table.freeze({
	ClaimDailyReward = "ClaimDailyReward", -- RemoteFunction: client -> server, tanpa argumen
	Notify = "Notify", -- RemoteEvent: server -> client, (message: string)
	VehicleBuy = "VehicleBuy", -- RemoteFunction: (vehicleId: string) -> VehicleResult
	VehicleSpawn = "VehicleSpawn", -- RemoteFunction: (vehicleId: string) -> VehicleResult
	VehicleDespawn = "VehicleDespawn", -- RemoteFunction: () -> VehicleResult
	VehicleFlip = "VehicleFlip", -- RemoteEvent: client -> server, tanpa argumen (balikkan mobil sendiri)
	JobSelect = "JobSelect", -- RemoteFunction: (jobId: string, "" = berhenti) -> JobResult
	JobStep = "JobStep", -- RemoteFunction: (taskId: number, stepIndex: number) -> JobResult
	JobSkip = "JobSkip", -- RemoteFunction: () -> JobResult (minta tugas lain)
	JobTask = "JobTask", -- RemoteEvent: server -> client, (task: JobConfig.TaskView?)
	JobSync = "JobSync", -- RemoteEvent: client -> server, minta kirim ulang tugas aktif
	HouseBuy = "HouseBuy", -- RemoteFunction: (houseId: number) -> HouseResult
	HouseSell = "HouseSell", -- RemoteFunction: () -> HouseResult
	HousePaint = "HousePaint", -- RemoteFunction: (slot: string, colorIndex: number) -> HouseResult
	HouseItem = "HouseItem", -- RemoteFunction: (yardSlot: number, itemId: string, "" = kosongkan) -> HouseResult
	HouseGoHome = "HouseGoHome", -- RemoteFunction: () -> HouseResult (pulang ke depan rumah)
	MissionClaim = "MissionClaim", -- RemoteFunction: (missionId: string) -> { ok, message }
})

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getOrCreate(name: string, className: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return getOrCreate(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return getOrCreate(name, "RemoteFunction") :: RemoteFunction
end

return Net
