--!strict
-- ConsumeAnimController: gerakan lengan kanan saat makan/minum. Server (StoreService.animateUse) mengirim
-- event ConsumeAnim (jenis, durasi) ke pemain yang makan/minum. Di client pemilik karakter dibuat
-- KeyframeSequence sementara (prioritas Action4, menimpa animasi memegang Tool): bahu terangkat dan berayun
-- ke dalam, siku menekuk membawa tangan ke depan mulut, lalu menyesap/menggigit beberapa kali dan kembali
-- ke pose memegang. Pose puncak diukur di rig R15: bahu Angles(-110, -80, 100), siku -100 derajat.
-- Catatan: animasi sementara ini hanya terlihat oleh pemilik; pemain lain melihat barang naik ke mulut
-- (gerakan Grip dari server).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ConsumeAnimController = {}

local rad = math.rad
local APEX_SHOULDER = CFrame.Angles(rad(-110), rad(-80), rad(100))
local APEX_ELBOW = CFrame.Angles(rad(-100), 0, 0)
local SIP_ELBOW = CFrame.Angles(rad(-128), 0, 0) -- kepala tengadah: gelas miring / gigitan

local active = false

local function pose(name: string, weight: number, cf: CFrame, child: Pose?): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.Weight = weight
	p.CFrame = cf
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	if child then
		p:AddSubPose(child)
	end
	return p
end

local function keyframe(sequence: KeyframeSequence, time: number, shoulder: CFrame, elbow: CFrame)
	local kf = Instance.new("Keyframe")
	kf.Time = time
	local lower = pose("RightLowerArm", 1, elbow)
	local upper = pose("RightUpperArm", 1, shoulder, lower)
	local torso = pose("UpperTorso", 0, CFrame.new(), upper)
	local lowerTorso = pose("LowerTorso", 0, CFrame.new(), torso)
	local root = pose("HumanoidRootPart", 0, CFrame.new(), lowerTorso)
	kf:AddPose(root)
	sequence:AddKeyframe(kf)
end

local function buildSequence(kind: string, duration: number, holdShoulder: CFrame, holdElbow: CFrame): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "ConsumeArm"
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action4
	keyframe(sequence, 0, holdShoulder, holdElbow)
	keyframe(sequence, 0.45, APEX_SHOULDER, APEX_ELBOW)
	local bobs = if kind == "drink" then 2 else 3
	local span = duration - 0.45 - 0.45
	for i = 1, bobs do
		local t0 = 0.45 + span * (i - 0.5) / bobs
		keyframe(sequence, t0, APEX_SHOULDER, SIP_ELBOW)
		keyframe(sequence, 0.45 + span * i / bobs, APEX_SHOULDER, APEX_ELBOW)
	end
	keyframe(sequence, duration, holdShoulder, holdElbow)
	return sequence
end

local function play(kind: string, duration: number)
	if active then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	-- Sendi R15 bisa Motor6D atau AnimationConstraint; keduanya punya Transform.
	local shoulder: any = if character then character:FindFirstChild("RightShoulder", true) else nil
	local elbow: any = if character then character:FindFirstChild("RightElbow", true) else nil
	if animator == nil or shoulder == nil or elbow == nil then
		return -- bukan karakter R15: cukup gerakan barang dari server
	end
	active = true
	local okSeq, sequence = pcall(buildSequence, kind, math.max(duration, 1.6), shoulder.Transform, elbow.Transform)
	if not okSeq then
		warn("[ConsumeAnim] gagal membuat animasi: " .. tostring(sequence))
		active = false
		return
	end
	local ok, err = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.15)
		track.Stopped:Once(function()
			animation:Destroy()
			active = false
		end)
		task.delay(duration + 0.3, function()
			if track.IsPlaying then
				track:Stop(0.15)
			end
		end)
	end)
	if not ok then
		warn("[ConsumeAnim] gagal memutar: " .. tostring(err))
		active = false
	end
end

function ConsumeAnimController.init() end

function ConsumeAnimController.start()
	Net.event("ConsumeAnim").OnClientEvent:Connect(function(kind: any, duration: any)
		if type(kind) == "string" and type(duration) == "number" and duration > 0 and duration < 10 then
			play(kind, duration)
		end
	end)
end

return ConsumeAnimController
