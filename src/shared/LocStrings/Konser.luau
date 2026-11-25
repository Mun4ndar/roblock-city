--!strict
-- LocStrings.Konser: Panggung Konser Taman Kota (ConcertController, map/BuildPanggung, ConcertConfig).

local exact: { [string]: string } = {
	["KONSER TAMAN KOTA"] = "CITY PARK CONCERT",
	["KONSER MALAM INI • MULAI 17.00"] = "TONIGHT'S CONCERT • STARTS 5 PM",
	["Joget bareng di depan panggung!"] = "Dance together in front of the stage!",
	["Joget!"] = "Dance!",
	["Lantai Dansa"] = "Dance Floor",
	["Panggung Konser (malam)"] = "Concert Stage (evenings)",
}

return { exact = exact, patterns = {} }
