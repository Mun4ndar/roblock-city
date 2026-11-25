--!strict
-- LocStrings.Progress: koleksi langka, peringkat, kode tukar, grup Roblox, seragam bertingkat.
-- (Satu berkas per fitur besar supaya beberapa orang bisa menambah kamus tanpa bentrok.)

local exact: { [string]: string } = {
	["Koleksi"] = "Collection",
	["Peringkat"] = "Leaderboard",
	["Kode"] = "Codes",
	["Kode Tukar"] = "Redeem Code",
	["🎁 Kode Tukar"] = "🎁 Redeem Code",
	["🏆 Koleksi & Peringkat"] = "🏆 Collection & Leaderboards",
	["Belum ada data peringkat."] = "No leaderboard data yet.",
	["💰 Terkaya"] = "💰 Richest",
	["🛠️ Pekerja Terbaik"] = "🛠️ Top Workers",
	["Peringkat diperbarui beberapa menit sekali."] = "Leaderboards update every few minutes.",
	["Masukkan kode"] = "Enter code",
	["Tukar"] = "Redeem",
	["Kode dibagikan lewat acara dan media sosial resmi ROBLOCK CITY. Tiap kode hanya sekali pakai per pemain."] = "Codes are shared through official ROBLOCK CITY events and social media. Each code can be used once per player.",
	["👥 Grup Roblox"] = "👥 Roblox Group",
	["Grup resmi akan segera dibuka. Nantikan ya!"] = "The official group will open soon. Stay tuned!",
	["Klaim hadiah grup"] = "Claim group reward",
	["Grup resmi belum diatur oleh pembuat game."] = "The official group has not been set up by the game creator yet.",
	["Hadiah grup sudah kamu ambil. Bonus gaji tetap aktif!"] = "You already claimed the group reward. Your pay bonus is still active!",
	["Kode tidak dikenal atau sudah kedaluwarsa."] = "Unknown or expired code.",
	["Kode itu sudah kamu pakai."] = "You already used that code.",
	["Kamu sudah punya hadiah kode ini."] = "You already own this code's reward.",
	["Langka"] = "Rare",
	["Epik"] = "Epic",
	["Legenda"] = "Legendary",
	["Mobil Klasik Biru"] = "Blue Classic Car",
	["Kucing Emas"] = "Golden Cat",
	["Rubah Senja"] = "Dusk Fox",
	["Kancil Emas"] = "Golden Kancil",
	["Motor Pelangi"] = "Rainbow Motorbike",
	["Panda Kristal"] = "Crystal Panda",
	["Bus Tingkat Mini"] = "Mini Double-Decker Bus",
	["Naga Mungil"] = "Tiny Dragon",
	["Mobil"] = "Car",
	["Emas Senior"] = "Senior Gold",
	["Emas"] = "Gold",
	["Perak"] = "Silver",
	["Pemain"] = "Player",
}

local patterns: { { string } } = {
	{
		"Koleksi langka: {}/{}. Dapatkan dari tugas pekerjaan (makin tinggi level, makin sering) atau kode tukar. Lengkap = hadiah {}!",
		"Rare collection: {}/{}. Get them from job tasks (the higher your level, the more often) or redeem codes. Complete set = {} reward!",
	},
	{ "???\n{} · {}", "???\n{} · {}" },
	{ "{}\n{} · {}", "{}\n{} · {}" },
	{ "Kamu: {}", "You: {}" },
	{
		'Gabung grup "{}" di Roblox dulu, lalu coba lagi.',
		'Join the "{}" group on Roblox first, then try again.',
	},
	{ "Terima kasih sudah bergabung! Hadiah ${}.", "Thanks for joining! Reward ${}." },
	{
		"Terlalu banyak salah. Coba lagi {} detik lagi.",
		"Too many wrong tries. Try again in {} seconds.",
	},
	{ "🎁 Kode berhasil! Kamu dapat ${}.", "🎁 Code redeemed! You got ${}." },
	{ "🎁 Kode berhasil!", "🎁 Code redeemed!" },
	{ "✨ Koleksi {}! {} ({}). Bonus ${}.", "✨ {} collectible! {} ({}). Bonus ${}." },
	{ "🏆 Koleksi lengkap! Hadiah ${}.", "🏆 Collection complete! Reward ${}." },
	{ "🎖️ Seragam baru: tingkat {}!", "🎖️ New uniform: {} tier!" },
}

return {
	exact = exact,
	patterns = patterns,
}
