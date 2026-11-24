--!strict
--[[
	ROBLOCK CITY: merapikan arah rumah dan lapangan basket sesudah pemadatan peta (2026-11-24/25).
	Dijalankan SEKALI di mode Edit pada peta koordinat BARU (lihat CompactMap).
	Pakai: require(game.ServerStorage.MapBuilders.FixHousesCourt)()

	Depan rumah = LookVector pivot (pintu di -Z lokal). Aturan: pintu menghadap jalan terdekat,
	pusat rumah 36 stud dari garis tengah jalan perumahan (lebar 28 + trotoar).

	1. Neighborhoods.Houses: delapan rumah yang bergeser akibat pemadatan dikembalikan ke lajurnya
	   (Rumah9 juga diputar menghadap Jalan Kenanga). Halaman_RumahN ikut bergerak dengan transform
	   yang sama, jadi pagar dan jalan setapak tetap di sisi depan.
	2. Rumah kota kecil (Residential.Buildings.Houses) sudah benar (menghadap Jalan EW3 di z = 334): tidak diubah.
	3. Lapangan basket dibangun ulang dengan BasketCourt di (-390, 0, -18).
]]

local HOUSE_FIXES: { { n: number, x: number, z: number, yaw: number? } } = {
	{ n = 7, x = -435, z = -80 },
	{ n = 8, x = -385, z = -80 },
	{ n = 9, x = -335, z = -80, yaw = 0 }, -- menghadap -Z, ke Jalan Kenanga
	{ n = 10, x = -316, z = 7 },
	{ n = 11, x = -316, z = 64 },
	{ n = 12, x = -316, z = 119 },
	{ n = 40, x = -104, z = 580 },
	{ n = 59, x = 735, z = 580 },
}

-- Sesudah pemadatan beberapa rumah bergeser sehingga berdempetan/menimpa. Kisi aslinya (langkah 55 stud)
-- dari BuildResidential.buildHouses; tiap rumah dikembalikan ke slotnya (Rumah9-12 = lajur x -316, z -46..119).
-- Dijalankan 2026-11-25 lewat execute_luau (24 rumah dipindah, Halaman_Rumah ikut), place v134.

-- Halaman_RumahN (pagar, rumput, jalan setapak) dibangun menyamping (pagar depan di sisi +X rumah) dan
-- terlalu dalam, jadi pagar masuk ke trotoar. 2026-11-25 (place v135): tiap halaman diputar di sekitar
-- pusat rumahnya supaya pagar depan ada di sisi depan rumah, lalu digeser ke belakang sampai pagar 15,2
-- stud dari pusat rumah (22 stud dari garis tengah jalan = tepi luar trotoar). Halaman 40 disalin dari 41,
-- rumput Halaman 1 dipangkas di sisi Jalan Melati, batu/bedeng yang masih di trotoar dimundurkan.

local COURT_CENTER = CFrame.new(-390, 0, -18)
local OLD_COURT_PARTS = { "LapanganBasket", "Area", "TiangRing", "Papan", "Ring", "BolaBasket" }

return function()
	local map = workspace:FindFirstChild("Map") :: Instance
	local nb = map:FindFirstChild("Neighborhoods") :: Instance
	local houses = nb:FindFirstChild("Houses") :: Instance
	local yards = nb:FindFirstChild("HouseLandscaping")

	for _, fix in HOUSE_FIXES do
		local h = houses:FindFirstChild("Rumah" .. fix.n) :: Model?
		if h then
			local old = h:GetPivot()
			local pos = Vector3.new(fix.x, old.Position.Y, fix.z)
			local new = if fix.yaw then CFrame.new(pos) * CFrame.Angles(0, fix.yaw, 0) else CFrame.new(pos) * (old - old.Position)
			local transform = new * old:Inverse()
			h:PivotTo(new)
			local yard = if yards then yards:FindFirstChild("Halaman_Rumah" .. fix.n) else nil
			if yard and yard:IsA("Model") then
				yard:PivotTo(transform * yard:GetPivot())
			end
		end
	end

	local taman = nb:FindFirstChild("Taman") :: Instance
	for _, c in taman:GetChildren() do
		if c:IsA("BasePart") and table.find(OLD_COURT_PARTS, c.Name) then
			c:Destroy()
		end
	end
	local old = taman:FindFirstChild("LapanganBasket")
	if old then
		old:Destroy()
	end
	local Court = require(script.Parent.BasketCourt)
	Court.build(COURT_CENTER, taman)
end
