--!strict
-- SholatPose: pose tubuh R15 lewat Motor6D.Transform untuk gerakan sholat, duduk bersila, azan, dan menyapu.
-- Dipakai client (MasjidController) pada NPC dan pemain yang berada di masjid; server tidak menyentuh sendi.
-- Pose = tabel { [namaSendi] = CFrame }. Sendi yang tidak disebut = lurus (CFrame identitas).
-- Pandangan karakter: menghadap -Z, tangan kanan di +X. Rotasi X positif pada bahu/siku/paha = ke depan;
-- rotasi X negatif pada pinggang = membungkuk ke depan.

local SholatPose = {}

export type Pose = { [string]: CFrame }
-- Sendi bisa Motor6D (karakter pemain) atau AnimationConstraint (rig baru); keduanya punya properti Transform.
export type Rig = { [string]: any }

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

SholatPose.JOINTS = table.freeze({
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"LeftShoulder",
	"RightElbow",
	"LeftElbow",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
	"RightAnkle",
	"LeftAnkle",
})

-- Turunan tinggi pinggul (stud) saat duduk/sujud; dihitung dari proporsi R15 standar lalu disetel lewat uji visual.
local POSES: { [string]: Pose } = {
	berdiri = {},

	-- Takbiratul ihram: kedua tangan diangkat setinggi telinga. Juga dipakai muazin saat azan.
	takbir = {
		RightShoulder = R(10, 0, 12),
		LeftShoulder = R(10, 0, -12),
		RightElbow = R(125, 0, 0),
		LeftElbow = R(125, 0, 0),
	},

	-- Bersedekap: tangan bersilang di dada saat berdiri.
	qiyam = {
		RightShoulder = R(28, 0, -22),
		LeftShoulder = R(28, 0, 22),
		RightElbow = R(78, 0, 0),
		LeftElbow = R(78, 0, 0),
		Neck = R(14, 0, 0),
	},

	ruku = {
		Waist = R(-96, 0, 0),
		Neck = R(52, 0, 0),
		RightShoulder = R(62, 0, 0),
		LeftShoulder = R(62, 0, 0),
		RightElbow = R(8, 0, 0),
		LeftElbow = R(8, 0, 0),
	},

	-- Sujud: lutut, telapak tangan, dan dahi menyentuh lantai.
	sujud = {
		Root = CFrame.new(0, -1.55, 0.3),
		RightHip = R(48, 0, 4),
		LeftHip = R(48, 0, -4),
		RightKnee = R(-138, 0, 0),
		LeftKnee = R(-138, 0, 0),
		RightAnkle = R(-30, 0, 0),
		LeftAnkle = R(-30, 0, 0),
		Waist = R(-100, 0, 0),
		Neck = R(60, 0, 0),
		RightShoulder = R(118, 0, 8),
		LeftShoulder = R(118, 0, -8),
		RightElbow = R(-40, 0, 0),
		LeftElbow = R(-40, 0, 0),
	},

	-- Duduk iftirasy (di antara dua sujud dan tasyahud): duduk di atas tumit kiri, tangan di paha.
	duduk = {
		Root = CFrame.new(0, -1.45, 0.45),
		RightHip = R(86, 0, 3),
		LeftHip = R(86, 0, -3),
		RightKnee = R(-150, 0, 0),
		LeftKnee = R(-150, 0, 0),
		RightAnkle = R(-35, 0, 0),
		LeftAnkle = R(-35, 0, 0),
		RightShoulder = R(18, 0, -6),
		LeftShoulder = R(18, 0, 6),
		RightElbow = R(52, 0, 0),
		LeftElbow = R(52, 0, 0),
	},

	salamKanan = {
		Root = CFrame.new(0, -1.45, 0.45),
		RightHip = R(86, 0, 3),
		LeftHip = R(86, 0, -3),
		RightKnee = R(-150, 0, 0),
		LeftKnee = R(-150, 0, 0),
		RightAnkle = R(-35, 0, 0),
		LeftAnkle = R(-35, 0, 0),
		RightShoulder = R(18, 0, -6),
		LeftShoulder = R(18, 0, 6),
		RightElbow = R(52, 0, 0),
		LeftElbow = R(52, 0, 0),
		Neck = R(0, -72, 0),
	},

	salamKiri = {
		Root = CFrame.new(0, -1.45, 0.45),
		RightHip = R(86, 0, 3),
		LeftHip = R(86, 0, -3),
		RightKnee = R(-150, 0, 0),
		LeftKnee = R(-150, 0, 0),
		RightAnkle = R(-35, 0, 0),
		LeftAnkle = R(-35, 0, 0),
		RightShoulder = R(18, 0, -6),
		LeftShoulder = R(18, 0, 6),
		RightElbow = R(52, 0, 0),
		LeftElbow = R(52, 0, 0),
		Neck = R(0, 72, 0),
	},

	-- Duduk bersila untuk mendengarkan tausiah atau menunggu.
	bersila = {
		Root = CFrame.new(0, -2.0, 0),
		RightHip = R(80, 0, 38),
		LeftHip = R(80, 0, -38),
		RightKnee = R(-118, 0, 0),
		LeftKnee = R(-118, 0, 0),
		RightAnkle = R(-10, 0, 20),
		LeftAnkle = R(-10, 0, -20),
		RightShoulder = R(14, 0, -4),
		LeftShoulder = R(14, 0, 4),
		RightElbow = R(48, 0, 0),
		LeftElbow = R(48, 0, 0),
	},

	-- Menyapu: dasar pose; MasjidController menambahkan ayunan.
	menyapu = {
		Waist = R(-16, 0, 0),
		Neck = R(12, 0, 0),
		RightShoulder = R(52, 0, -6),
		LeftShoulder = R(40, 0, 10),
		RightElbow = R(24, 0, 0),
		LeftElbow = R(30, 0, 0),
	},
}

SholatPose.POSES = POSES

-- Ambil semua Motor6D sendi R15 dari model.
function SholatPose.bind(model: Model): Rig?
	local function motor(partName: string, jointName: string): any?
		local part = model:FindFirstChild(partName)
		local joint = if part then part:FindFirstChild(jointName) else nil
		return if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint"))
			then joint
			else nil
	end
	local rig: Rig = {}
	local map: { { string } } = {
		{ "Root", "LowerTorso", "Root" },
		{ "Waist", "UpperTorso", "Waist" },
		{ "Neck", "Head", "Neck" },
		{ "RightShoulder", "RightUpperArm", "RightShoulder" },
		{ "LeftShoulder", "LeftUpperArm", "LeftShoulder" },
		{ "RightElbow", "RightLowerArm", "RightElbow" },
		{ "LeftElbow", "LeftLowerArm", "LeftElbow" },
		{ "RightHip", "RightUpperLeg", "RightHip" },
		{ "LeftHip", "LeftUpperLeg", "LeftHip" },
		{ "RightKnee", "RightLowerLeg", "RightKnee" },
		{ "LeftKnee", "LeftLowerLeg", "LeftKnee" },
		{ "RightAnkle", "RightFoot", "RightAnkle" },
		{ "LeftAnkle", "LeftFoot", "LeftAnkle" },
	}
	for _, entry in map do
		local m = motor(entry[2], entry[3])
		if m == nil then
			return nil
		end
		rig[entry[1]] = m
	end
	return rig
end

-- Terapkan campuran pose a -> b (alpha 0..1). extra = tambahan per sendi (mis. ayunan sapu).
function SholatPose.apply(rig: Rig, a: Pose, b: Pose?, alpha: number, extra: Pose?)
	for _, name in SholatPose.JOINTS do
		local motor = rig[name]
		if motor then
			local cf = a[name] or CFrame.identity
			if b and alpha > 0 then
				cf = cf:Lerp(b[name] or CFrame.identity, alpha)
			end
			if extra and extra[name] then
				cf = cf * extra[name]
			end
			motor.Transform = cf
		end
	end
end

-- Kembalikan semua sendi ke lurus.
function SholatPose.reset(rig: Rig)
	for _, motor in rig do
		motor.Transform = CFrame.identity
	end
end

return SholatPose
