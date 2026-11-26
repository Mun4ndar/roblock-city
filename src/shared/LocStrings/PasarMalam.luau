--!strict
-- LocStrings.PasarMalam: sapaan penjual, celoteh pembeli, dan jabatan NPC Pasar Malam (PasarMalamService).
-- Terjemahan Inggris disusun dari PasarMalamConfig supaya data dan kamus tidak pernah berbeda.

local Config = require(script.Parent.Parent:WaitForChild("PasarMalamConfig"))

local exact: { [string]: string } = {
	["Penjual Bakso"] = "Meatball Seller",
	["Penjual Sate"] = "Satay Seller",
	["Penjual Gorengan"] = "Fritter Seller",
	["Penjual Es Cendol"] = "Cendol Ice Seller",
	["Penjual Martabak"] = "Martabak Seller",
	["Penjual Jagung Bakar"] = "Grilled Corn Seller",
	["Penjual Nasi Goreng"] = "Fried Rice Seller",
	["Penjual Gado-gado"] = "Gado-gado Seller",
	["Penjual Es Campur"] = "Mixed Ice Seller",
	["Penjual Kopi dan Roti Bakar"] = "Coffee and Toast Seller",
	["Penjual Sate Lilit"] = "Satay Lilit Seller",
	["Penjual Kerak Telor"] = "Kerak Telor Seller",
	["Penjual Soto dan Bakso"] = "Soto and Meatball Seller",
	["Penjual Jajan Pasar"] = "Market Snack Seller",
	["Penjual Es Kelapa"] = "Coconut Ice Seller",
	["Penjual Terang Bulan"] = "Terang Bulan Seller",
	["Pembeli"] = "Shopper",
}

for _, vendor in Config.VENDORS do
	for _, line in vendor.lines do
		exact[line[1]] = line[2]
	end
end
for _, line in Config.THANKS do
	exact[line[1]] = line[2]
end
for _, line in Config.SHOPPER_LINES do
	exact[line[1]] = line[2]
end

return { exact = exact, patterns = {} :: { { string } } }
