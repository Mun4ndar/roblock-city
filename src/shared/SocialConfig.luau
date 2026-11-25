--!strict
-- SocialConfig: data bersama fitur sosial (kunjungan rumah, kru, emote, mode foto).

export type Emote = { id: string, icon: string, name: string, anim: number, loop: boolean }
export type Pose = { id: string, icon: string, name: string, anim: number, at: number }

local SocialConfig = {}

SocialConfig.ATTR_ACCESS = "HouseAccess" -- atribut Player: "open" | "friends" | "crew" | "locked"
SocialConfig.ATTR_CREW_ID = "CrewId"
SocialConfig.ATTR_CREW_NAME = "CrewName"
SocialConfig.ATTR_CREW_LEADER = "CrewLeader" -- true kalau ketua kru

SocialConfig.CREW_MAX = 6
SocialConfig.CREW_NAME_MIN = 3
SocialConfig.CREW_NAME_MAX = 16
SocialConfig.INVITE_SECONDS = 30
SocialConfig.INVITE_RANGE = 80 -- stud; undangan hanya untuk pemain di dekat
SocialConfig.DEFAULT_ACCESS = "friends"

SocialConfig.ACCESS = {
	{ id = "open", icon = "🌍", name = "Terbuka", note = "Siapa saja boleh masuk." },
	{
		id = "friends",
		icon = "🤝",
		name = "Teman & kru",
		note = "Hanya teman Roblox dan anggota kru.",
	},
	{
		id = "crew",
		icon = "👨‍👩‍👧",
		name = "Kru saja",
		note = "Hanya anggota kru kamu.",
	},
	{ id = "locked", icon = "🔒", name = "Terkunci", note = "Hanya kamu sendiri." },
}

-- Animasi emote resmi Roblox (R15).
SocialConfig.EMOTES = table.freeze({
	{ id = "lambai", icon = "👋", name = "Lambai", anim = 507770239, loop = false },
	{ id = "tunjuk", icon = "👉", name = "Tunjuk", anim = 507770453, loop = false },
	{ id = "hore", icon = "🙌", name = "Hore", anim = 507770677, loop = false },
	{ id = "tawa", icon = "😂", name = "Tertawa", anim = 507770818, loop = false },
	{ id = "joget1", icon = "💃", name = "Joget 1", anim = 507771019, loop = true },
	{ id = "joget2", icon = "🕺", name = "Joget 2", anim = 507776043, loop = true },
	{ id = "joget3", icon = "🎉", name = "Joget 3", anim = 507777268, loop = true },
}) :: { Emote }

-- Pose foto = animasi emote yang dibekukan pada pecahan waktu `at` (0..1 dari panjangnya).
SocialConfig.POSES = table.freeze({
	{ id = "poseLambai", icon = "🖐️", name = "Lambai Foto", anim = 507770239, at = 0.35 },
	{ id = "poseHore", icon = "✌️", name = "Hore Foto", anim = 507770677, at = 0.5 },
	{ id = "poseTunjuk", icon = "☝️", name = "Tunjuk Foto", anim = 507770453, at = 0.5 },
	{ id = "poseJoget", icon = "🤸", name = "Gaya Joget", anim = 507771019, at = 0.3 },
}) :: { Pose }

SocialConfig.FILTERS = table.freeze({
	{
		name = "Asli",
		brightness = 0,
		contrast = 0,
		saturation = 0,
		tint = Color3.fromRGB(255, 255, 255),
	},
	{
		name = "Hangat",
		brightness = 0.03,
		contrast = 0.08,
		saturation = 0.15,
		tint = Color3.fromRGB(255, 232, 205),
	},
	{
		name = "Sejuk",
		brightness = 0,
		contrast = 0.06,
		saturation = 0.05,
		tint = Color3.fromRGB(210, 230, 255),
	},
	{
		name = "Cerah",
		brightness = 0.06,
		contrast = 0.1,
		saturation = 0.4,
		tint = Color3.fromRGB(255, 255, 255),
	},
	{
		name = "Hitam Putih",
		brightness = 0,
		contrast = 0.15,
		saturation = -1,
		tint = Color3.fromRGB(255, 255, 255),
	},
})

function SocialConfig.emote(id: string): Emote?
	for _, e in SocialConfig.EMOTES do
		if e.id == id then
			return e
		end
	end
	return nil
end

function SocialConfig.pose(id: string): Pose?
	for _, p in SocialConfig.POSES do
		if p.id == id then
			return p
		end
	end
	return nil
end

function SocialConfig.validAccess(id: any): boolean
	for _, a in SocialConfig.ACCESS do
		if a.id == id then
			return true
		end
	end
	return false
end

return SocialConfig
