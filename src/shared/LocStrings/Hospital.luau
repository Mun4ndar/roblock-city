--!strict
-- LocStrings.Hospital: Rumah Sakit (alur Dokter, pasien, apotek, antrean) dan status kerja.

local exact: { [string]: string } = {
	["Demam"] = "Fever",
	["Ukur suhu"] = "Take temperature",
	["Periksa dengan stetoskop"] = "Examine with stethoscope",
	["Suhunya agak tinggi. Sekarang dengarkan napasnya dengan stetoskop."] = "The temperature is a bit high. Now listen to the breathing with the stethoscope.",
	["Selesai diperiksa. Tunggu apoteker membawa obat penurun panas ke Meja Dokter."] = "Exam done. Wait for the pharmacist to bring the fever medicine to the Doctor's Desk.",
	["Beri obat demam"] = "Give fever medicine",
	["Selesai diperiksa. Tunggu apoteker membawa sirup ke Meja Dokter."] = "Exam done. Wait for the pharmacist to bring the syrup to the Doctor's Desk.",
	["Beri sirup batuk"] = "Give cough syrup",
	["Luka kecil"] = "Small wound",
	["Bersihkan luka"] = "Clean the wound",
	["Lukanya sudah bersih. Tunggu apoteker membawa plester ke Meja Dokter."] = "The wound is clean. Wait for the pharmacist to bring a bandage to the Doctor's Desk.",
	["Pasang plester"] = "Apply bandage",
	["Menunggu obat"] = "Waiting for medicine",
	["Panggil ke ranjang"] = "Call to the bed",
	["Ranjang tindakan penuh. Tunggu sebentar ya!"] = "The treatment beds are full. Wait a moment!",
	["Obat pasien ini ada di dokter lain. Ambil obatmu di Meja Dokter ya!"] = "This patient's medicine belongs to another doctor. Get your own at the Doctor's Desk!",
	["Meja ini khusus Dokter yang sedang bertugas."] = "This desk is only for Doctors on duty.",
	["Kamu masih membawa obat. Berikan dulu ke pasiennya!"] = "You are still carrying medicine. Give it to the patient first!",
	["Obat sudah di Meja Dokter ya!"] = "The medicine is at the Doctor's Desk!",
	[" → Ranjang"] = " → Bed",
	["Tidak ada antrean"] = "No queue",
	["Petugas Registrasi"] = "Registration Clerk",
	["Meja Dokter"] = "Doctor's Desk",
	["ANTREAN PASIEN"] = "PATIENT QUEUE",
	["Apoteker"] = "Pharmacist",
	["Sembuh!"] = "Healed!",
	-- Status kerja (JobUiController)
	["Berhenti kerja"] = "Quit job",
	["Kamu berhenti kerja. Silakan berkeliling bebas!"] = "You quit your job. Feel free to roam around!",
	["Status"] = "Status",
}

local patterns: { { string } } = {
	{ "Pasien {} ({})", "Patient {} ({})" },
	{ "Obat untuk {}", "Medicine for {}" },
	{ "Antrean {}: {} ({}). Silakan duduk ya!", "Queue {}: {} ({}). Please have a seat!" },
	{
		"Antrean {}: {}. Duduk dan tunggu dokter ya!",
		"Queue {}: {}. Sit down and wait for the doctor!",
	},
	{
		"Kamu sudah terdaftar dengan antrean {}. Tunggu dokter ya!",
		"You are already registered with queue number {}. Wait for the doctor!",
	},
	{ "{} Sembuh!", "{} Healed!" },
	{ "{} ({} dtk)", "{} ({} s)" },
	{ "Kamu sudah sembuh! {} Terima kasih, dokter {}.", "You are healed! {} Thank you, Dr. {}." },
	{ "{} → Ranjang", "{} → Bed" },
	{ "🟢 Sedang bekerja: {} · Lv {}", "🟢 Working as: {} · Lv {}" },
}

return { exact = exact, patterns = patterns }
