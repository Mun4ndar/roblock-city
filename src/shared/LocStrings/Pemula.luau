--!strict
-- LocStrings.Pemula: panduan pemain baru (OnboardingController, OnboardingService, OnboardingConfig).

local exact: { [string]: string } = {
	["Ambil pekerjaan pertamamu"] = "Get your first job",
	["Selesaikan 1 tugas"] = "Finish 1 task",
	["Belanja atau naik kendaraan"] = "Shop or ride a vehicle",
	["◀ Mulai di sini!"] = "◀ Start here!",
	["💼 Ambil pekerjaan pertamamu"] = "💼 Get your first job",
	["⭐ Selesaikan 1 tugas"] = "⭐ Finish 1 task",
	["🛒 Belanja atau naik kendaraan"] = "🛒 Shop or ride a vehicle",
	["Tekan tombol Pekerjaan di kiri, lalu tekan Mulai."] = "Tap the Jobs button on the left, then tap Start.",
	["🎉 Misi Pemula selesai!"] = "🎉 Starter Missions complete!",
	["Lanjut main!"] = "Keep playing!",
	["🎁 Ambil hadiah login hari ini"] = "🎁 Claim today's login reward",
	["🎁 Bonus sedang dikirim..."] = "🎁 Sending your bonus...",
	["🚀 Teleport Cepat"] = "🚀 Quick Teleport",
	["Teleport"] = "Teleport",
	["Pergi"] = "Go",
	["Pasar Malam"] = "Night Market",
	["Pantai"] = "Beach",
	["Bandara"] = "Airport",
	["Perkemahan"] = "Campground",
	["Jajan dan wahana, ramai saat sore"] = "Snacks and rides, busy in the evening",
	["Jet ski, voli, dan kafe pantai"] = "Jet skis, volleyball and the beach cafe",
	["Lihat pesawat lepas landas"] = "Watch planes take off",
	["Pusat kota dan toko costume"] = "Downtown and the costume shop",
	["Api unggun dan air terjun"] = "Campfire and waterfall",
	["GPS menuju tugasmu. Ikuti panah biru di jalan!"] = "GPS to your task. Follow the blue arrows on the road!",
	["Jaket Warga Baru"] = "New Citizen Jacket",
	["Tempat itu tidak dikenal."] = "Unknown place.",
	["Belum bisa teleport sekarang, coba lagi sebentar."] = "Can't teleport right now, try again in a moment.",
	["📅 Kembali besok untuk hadiah login!"] = "📅 Come back tomorrow for a login reward!",
}

local patterns: { { string } } = {
	{ "⭐ Misi Pemula {}/{}", "⭐ Starter Mission {}/{}" },
	{ "Tekan tombol Pekerjaan di kiri, lalu tekan Mulai. Hadiah {}", "Tap the Jobs button on the left, then tap Start. Reward {}" },
	{ "Ikuti panah biru di jalan sampai penanda kuning. Hadiah {}", "Follow the blue arrows on the road to the yellow marker. Reward {}" },
	{ "Beli sesuatu di toko, atau naik kendaraan mana saja. Hadiah {}", "Buy something at a shop, or ride any vehicle. Reward {}" },
	{ "🎁 Bonus {} dalam {}", "🎁 {} bonus in {}" },
	{ "📅 Hari ke-{} menunggumu! Login besok: hadiah {}", "📅 Day {} is waiting! Log in tomorrow: reward {}" },
	{ "Hadiahmu: {} dan setelan gratis Jaket Warga Baru. Setelan terlihat saat kamu tidak sedang bekerja.", "Your reward: {} and the free New Citizen Jacket outfit. It shows when you're not working." },
	{ "Misi Pemula {}/{} selesai! Hadiah {}.", "Starter Mission {}/{} complete! Reward {}." },
	{ "Misi Pemula selesai! Hadiah {} dan setelan gratis.", "Starter Missions complete! Reward {} and a free outfit." },
	{ "Bonus main {} menit: {}! Besok ada lagi!", "{}-minute play bonus: {}! More tomorrow!" },
	{ "Bonus main {} menit: {}!", "{}-minute play bonus: {}!" },
	{ "Tunggu {} detik lagi sebelum teleport.", "Wait {} more seconds before teleporting." },
	{ "Selamat datang di {}!", "Welcome to {}!" },
}

return { exact = exact, patterns = patterns }
