--!strict
-- LocStrings.Feri: feri pelabuhan yang bisa dinaiki (FerryService).

local exact: { [string]: string } = {
	["Naik Feri"] = "Board the Ferry",
	["Feri Pelabuhan"] = "Harbour Ferry",
	["Feri penuh. Tunggu putaran berikutnya ya!"] = "The ferry is full. Wait for the next trip!",
	["Selamat naik feri! Duduk manis, kita segera berangkat."] = "Welcome aboard! Sit tight, we depart soon.",
}

local patterns: { { string } } = {
	{ "Feri sedang berlayar. Kembali dalam {} detik.", "The ferry is at sea. Back in {} seconds." },
}

return { exact = exact, patterns = patterns }
