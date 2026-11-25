--!strict
-- FerrisService: bianglala dermaga pantai (model dibangun map/BuildBianglala: Workspace.Map.Beach.Dermaga.Bianglala).
-- Roda berputar lewat HingeConstraint motor (tag "FerrisMotor"), dikendalikan di sini: berputar 45 derajat
-- (satu posisi kabin), berhenti beberapa detik supaya pemain sempat naik/turun, lalu berputar lagi.
-- Kabin tergantung bebas di sendi dan dijaga tegak oleh AlignOrientation; kursi (Seat) menempel di kabin.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local GROUP = "Ferris"
local TAG_MOTOR = "FerrisMotor"
local STEP_DEGREES = 45 -- 8 kabin
local SPEED = 0.16 -- rad/detik saat berputar (kabin bawah bergerak sekitar 5,8 stud/detik)
local ACCELERATION = 0.35 -- rad/detik^2: mulai dan berhenti halus
local PAUSE_SECONDS = 12 -- waktu berhenti tiap kabin untuk naik/turun
local STUCK_SECONDS = 25 -- jika satu langkah macet selama ini, lanjut ke langkah berikut

local FerrisService = {}

local function runMotor(motor: HingeConstraint)
	local brake = math.deg(SPEED * SPEED / (2 * ACCELERATION)) -- sudut yang ditempuh saat mengerem
	motor.MotorMaxAcceleration = ACCELERATION
	motor.AngularVelocity = 0
	local accumulated = 0 -- derajat total sejak mulai (tanpa putaran balik)
	local last = motor.CurrentAngle
	local target = 0
	while motor.Parent do
		target += STEP_DEGREES
		motor.AngularVelocity = SPEED
		local began = os.clock()
		while motor.Parent and accumulated < target - brake do
			RunService.Heartbeat:Wait()
			local now = motor.CurrentAngle
			local delta = now - last
			if delta < -180 then
				delta += 360
			elseif delta > 180 then
				delta -= 360
			end
			accumulated += delta
			last = now
			if os.clock() - began > STUCK_SECONDS then
				break
			end
		end
		motor.AngularVelocity = 0
		task.wait(PAUSE_SECONDS)
		-- koreksi sisa sudut selama berhenti (setelah roda diam)
		local now = motor.CurrentAngle
		local delta = now - last
		if delta < -180 then
			delta += 360
		elseif delta > 180 then
			delta -= 360
		end
		accumulated += delta
		last = now
	end
end

local function hook(motor: Instance)
	if motor:IsA("HingeConstraint") then
		task.spawn(runMotor, motor)
	end
end

function FerrisService.init()
	local ok = pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		-- kabin tidak bertabrakan satu sama lain, tetap menabrak pemain (grup Default)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
	if not ok then
		warn("[Ferris] gagal mendaftarkan grup tabrakan")
	end
end

function FerrisService.start()
	for _, motor in CollectionService:GetTagged(TAG_MOTOR) do
		hook(motor)
		-- fisika roda dipegang server supaya gerakannya halus di semua pemain
		local hub = motor.Attachment1 and motor.Attachment1.Parent
		if hub and hub:IsA("BasePart") then
			pcall(function()
				hub:SetNetworkOwner(nil)
			end)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG_MOTOR):Connect(hook)
end

return FerrisService
