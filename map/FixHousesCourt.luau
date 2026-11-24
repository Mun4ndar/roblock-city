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

-- Simpang Jalan Tulip (z = 724) dengan Jalan Lingkar (2026-11-25, place v139): jalan, trotoar, garis tepi, kerb
-- dan zebra Tulip menembus belokan lingkar di sudut barat daya dan timur daya. Semua dipotong tepat di tepi
-- dalam lingkar (dipindai per z), zebra digeser 4 stud ke dalam. Rumah 29/30/36/37 digeser +6, 62/63 +8,
-- 69 +14, 70 +28 stud ke timur dan rumput halaman 69 dipangkas supaya tidak menimpa lingkar. Audit seluruh
-- peta lain (zebra melayang, trotoar menembus aspal, garis di luar aspal, ujung jalan tak sejajar) bersih;
-- hanya transisi lebar 32 -> 48/64 di ujung kota kecil, boulevard, dan penghubung yang disengaja.

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

--[[
	2026-11-25 (place v145): semak balok diganti mesh Creator Store gratis "Realistic Bush" (asset 12728953454,
	EvilSwrd, 2 MeshPart tanpa skrip) = ServerStorage.AsetPihakKetiga.SemakBulat. 258 balok (Bush 3,5 di Houses,
	SemakKiri/SemakKanan 4 x 2,2 x 4 di HouseLandscaping) diganti skala 0,34-0,38; part "Bush" disimpan transparan
	karena StyleHouses menggesernya. Dua pagar hidup "Hedge" dealer (54 x 3 x 2,5) diganti deretan semak skala 0,5.
	ModernDealer.luau baris "Hedge" (z ~326) sebaiknya membuat deretan SemakBulat juga, bukan balok.
	Ditolak: aset 14161520172 / 9187118377 (bentuk jelek). Jangan dijalankan ulang tanpa mengecek balok yang tersisa.
]]

--[[
	2026-11-25 (place v147): taman tidak lagi bulat-bulat seperti Minecraft.
	- Bunga: aset gratis Creator Store 9454164504 (4 bunga, 3 MeshPart tiap bunga) dan 16071638063 (aster) =
	  ServerStorage.AsetPihakKetiga.BungaToko (Bunga1-4, BungaDaisy); rumput 252805406 (RumputTuft, 18 Part+SpecialMesh).
	  Semua tanpa skrip. 175 BungaKelopak RealisticFlowers + BungaKelopak ParkRefresh/RoundaboutGardens + 355 balok
	  Scenery.Bunga diganti gerombol bunga -> Workspace.Map.BungaToko; 70 rumpun rumput di tiga TamanNatural dan Lawn.
	- Pohon bola (KanopiPohon + BatangPohon, pohon TamanBermain) -> klon PohonRindang (mesh) di Map.PenggantiBulat.
	- SemakOval (78) dan Rumpun bola Scenery (219) -> SemakBulat (mesh).
	Ditolak (berskrip atau partikel): 115131518556387, 128322951871227, 134149653672057, 88196712273495, 1353190583.
]]

--[[
	2026-11-25: sambungan lebar jalan diberi taper (potongan miring), dibuat lewat execute_luau.
	Empat simpang: Boulevard 64 -> NS2_1 32 di (100, 14) taper 24 stud; KeTimur 48 -> EW2_4 32 di (300, 214),
	KeBarat 48 -> EW2_1 32 di (-100, 214), KeSelatan 48 -> NS2_4 32 di (100, 414), taper 12 stud. Tiap simpang:
	slab lebar dipendekkan sepanjang taper, "TaperTengah" (lebar 32), dua "TaperBaji" (WedgePart rebah, tebal
	0,4) dan dua "TaperGaris" diagonal; garis tepi penghubung dipotong, median Boulevard berakhir di z = -8.
]]

--[[
	2026-11-25: delapan putaran jalan buntu (RoadFixes.PutarBalik1-8) dirapikan lewat execute_luau.
	Warna dan material cakram disamakan dengan jalan yang menyambung; garis tengah kuning yang masuk
	lingkaran dihapus; per putaran dibuat folder PutarBalikTepiN berisi garis tepi putih melingkar
	(radius cakram - 1,5, terbuka di mulut jalan), trotoar melingkar 6 stud (radius + 3, warna trotoar
	Neighborhoods) dan kerb beton di sekeliling pulau rumput.
]]

--[[
	2026-11-25: jalan pegunungan rata dengan tanah. Audit semua 322 slab aspal terhadap tanah (raycast ke Terrain,
	5 titik melintang tiap 16 stud): JalanDesa, KeCountryside, JalanPasarTani berada di parit potongan terrain
	(permukaan -2) sehingga jalan melayang 2,4 stud dari dasar. 18 slab diisi Terrain:FillBlock Grass (lebar jalan
	+ 30, tinggi atas -2 = permukaan 0, lihat catatan "permukaan terlihat 2 stud di atas FillBlock") di bawah jalan.
	Dilewati: yang dekat jembatan (Dek). Sisa selisih 1 stud di tepi lereng parit dan lantai parkir ParkirUmum
	(sengaja panggung 1,3 stud).
]]

--[[
	2026-11-25: pohon pegunungan (235 "Pohon" di Countryside.Hutan) diganti cemara mesh gratis: aset 5392132809
	(spruce 3 MeshPart, ServerStorage.AsetPihakKetiga.CemaraSpruce) dan 8528830197 (pinus, CemaraPinus, 20%),
	skala tinggi 20-34, tanpa tabrakan -> Map.Countryside.HutanCemara. Ditolak (berskrip): 76172906742533.

	2026-11-25: simpang akses bandara (JalanTerminal x -712 dengan KeBandara z 614) dibangun ulang di RoadFixes.SimpangBandara:
	tambalan miring SambungBandara dihapus; sudut luar membulat (persegi 14x12 + cakram R12 pusat (-714,626)); sudut dalam
	chamfer 8 stud di (-698,590); garis tepi luar melengkung R10,5, garis tepi dalam dipotong, garis kuning ganda
	melengkung R12 pusat (-700,602); dekorasi liar di sudut dibuang. Dek jembatan tidak disentuh. Audit garis marka
	Airport/Countryside/Highway/RoadFixes: nol ujung di luar aspal.
]]

--[[
	2026-11-25 (place v161): halaman belakang 78 rumah dihias -> Workspace.Map.HalamanHiasan/HiasanN: satu pohon
	(klon PohonRindang tinggi 8-12, digeser ke samping supaya tidak menimpa sayap garasi), tiga semak (SemakBulat),
	gerombol 4 bunga (BungaToko), satu rumpun rumput, bangku (BangkuTaman, 35%). Posisi dalam bingkai lokal rumah
	(depan = -Z lokal, belakang +Z), menghindari slot YARD_SLOTS HouseConfig (z 12 di belakang, samping x -13,5) dan
	titik yang di dalam 5 stud dari aspal. Rumah mewah dan lahan kosong besar belum dihias.
]]

--[[
	2026-11-25: (1) Toko.Warung dan PelataranWarung digeser +14,5 z (z -94,9..-76,2) karena barang depannya masuk
	JalanKenangaTimur; teras Startduck dipersempit (x 195..204) supaya pagar tidak masuk NS3_2, meja digeser 0,8 ke barat.
	Audit seluruh bangunan/kios terhadap aspal (titik sudut + tengah di dalam slab): hanya dua itu yang bermasalah;
	sisanya lantai dealer, bundaran, jalan setapak (aspal sah). (2) Dekorasi melayang: tanaman hasil penggantian di pulau
	putar balik (RoundaboutGardens.Taman_PulauPutar berada ~7 stud di atas pulau) diturunkan dengan raycast ke bawah:
	60 pohon/semak PenggantiBulat, 237 bunga BungaToko, 8 bedeng oval, dan 19 bunga/semak Scenery.Countryside di atas terrain.
	Audit ulang 3.964 dekorasi: nol melayang > 1,2 stud.
]]
