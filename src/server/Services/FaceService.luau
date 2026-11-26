--!strict
--[[
	FaceService: semua NPC (model berHumanoid yang bukan karakter pemain) yang kepalanya masih polos
	diberi wajah ramah (mata, pipi, mulut tersenyum) digambar sebagai SurfaceGui "Wajah" di sisi depan kepala.
	Sama dengan gambar wajah klinik (ClinicService.addFace): kepala yang sudah punya "Wajah" atau Decal dilewati.
	Berlaku juga untuk NPC yang dibuat belakangan (staf Balai Kota, resor, templat yang di-clone).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FaceService = {}

local INK = Color3.fromRGB(35, 30, 32)
local BLUSH = Color3.fromRGB(255, 130, 140)

local function addFace(head: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Wajah"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0
	local function dot(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		transparency: number?
	)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency or 0
		f.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = gui
	end
	dot(68, 84, 26, 38, INK) -- mata
	dot(132, 84, 26, 38, INK)
	dot(73, 76, 9, 12, Color3.new(1, 1, 1)) -- kilau mata
	dot(137, 76, 9, 12, Color3.new(1, 1, 1))
	dot(44, 124, 30, 18, BLUSH, 0.55) -- pipi
	dot(156, 124, 30, 18, BLUSH, 0.55)
	for index = 0, 6 do -- mulut senyum: ujung lebih tinggi dari tengah
		local t = (index - 3) / 3
		dot(100 + t * 38, 152 - t * t * 22, 15, 13, INK)
	end
	gui.Parent = head
end

local function consider(head: Instance)
	if head.Name ~= "Head" or not head:IsA("BasePart") then
		return
	end
	local model = head.Parent
	if model == nil or not model:IsA("Model") or model:FindFirstChildOfClass("Humanoid") == nil then
		return
	end
	if Players:GetPlayerFromCharacter(model) then
		return
	end
	if head:FindFirstChild("Wajah") or head:FindFirstChildWhichIsA("Decal") then
		return
	end
	-- jangan gambar wajah di model yang sengaja tanpa wajah atau yang sedang dalam templat tak terlihat
	if model:GetAttribute("TanpaWajah") then
		return
	end
	addFace(head)
end

function FaceService.init() end

function FaceService.start()
	local function scan(root: Instance)
		for _, d in root:GetDescendants() do
			consider(d)
		end
	end
	scan(Workspace)
	Workspace.DescendantAdded:Connect(function(d)
		if d.Name == "Head" then
			-- Humanoid dan bagian lain mungkin baru menyusul masuk: tunggu satu frame
			task.defer(consider, d)
		end
	end)
	-- NPC dibuat belakangan lewat CreateHumanoidModelFromDescription lalu diberi Parent: tertangani DescendantAdded.
	-- Sapu ulang berkala untuk kepala yang Humanoid-nya masuk terlambat.
	task.spawn(function()
		while true do
			task.wait(20)
			scan(Workspace)
		end
	end)
	local _ = CollectionService
end

return FaceService
