--!strict
-- LocStrings.Feri: feri pelabuhan yang bisa dinaiki (FerryService).

local exact: { [string]: string } = {
	["Naik Feri"] = "Board the Ferry",
	["Feri Pelabuhan"] = "Harbour Ferry",
	["Feri penuh. Tunggu putaran berikutnya ya!"] = "The ferry is full. Wait for the next trip!",
	["Naik Ferry di belakang kak, sebentar lagi mau berangkat."] = "Board the ferry behind me, miss! We leave very soon.",
	["Ferinya sedang berlayar kak, sebentar lagi kembali ya."] = "The ferry is out at sea, it will be back soon!",
	["LOKET FERI"] = "FERRY TICKET BOOTH",
	["Selamat naik feri! Duduk manis, kita segera berangkat."] = "Welcome aboard! Sit tight, we depart soon.",
}

local patterns: { { string } } = {
	{ "Feri sedang berlayar. Kembali dalam {} detik.", "The ferry is at sea. Back in {} seconds." },
}

return { exact = exact, patterns = patterns }
