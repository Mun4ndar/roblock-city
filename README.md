# ROBLOCK CITY

Game roleplay kota open-world yang ramah anak (tanpa senjata/kekerasan/kriminal).
Dibangun dengan [Rojo](https://rojo.space): kode ada di folder `src/`, lalu disinkronkan ke Roblox Studio.

## Mulai develop

1. Pasang toolchain lewat [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
   (membaca versi dari `rokit.toml`: Rojo, Wally, Selene, StyLua).
2. Pasang plugin Rojo di Studio: `rojo plugin install`
3. Jalankan `rojo serve`, lalu di Studio klik **Rojo > Connect**.

Tanpa Rojo tersambung, skrip yang diubah langsung di Studio bisa ditarik ke folder ini dengan
`tools/studio_pull.py` (petunjuk ada di dalam berkasnya). Model Blender ada di `assets/blender/`.

## Struktur

| Folder | Di Studio | Isi |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage/Shared | Config, Types, Net (remote), Format, VehicleConfig, VehicleBuilder, JobConfig |
| `src/server` | ServerScriptService/Server | `Services/`: logika server-authoritative |
| `src/client` | StarterPlayerScripts/Client | `Controllers/`: UI, input, tampilan |

Bootstrap dua fase: setiap Service/Controller boleh punya `init()` (tanpa yield) dan `start()`.
Urutan load ada di `ORDER` pada `init.server.luau` / `init.client.luau`; tambahkan modul baru di sana.

### Service saat ini

- **DataService**: load/simpan data pemain. Retry + backoff, session lock (UpdateAsync),
  autosave tiap 60 dtk, simpan saat keluar, BindToClose, versi skema + migrasi.
  Di Studio tanpa akses API, berjalan dalam mode offline (tidak menyimpan).
- **EconomyService**: satu-satunya tempat uang berubah (`addMoney`, `trySpend`, `getMoney`).
  Saldo dikirim ke client lewat atribut Player `Money`. Remote `ClaimDailyReward` dengan rate limit + cooldown.

- **VehicleService**: kepemilikan, pembelian, dan spawn kendaraan. Client hanya mengirim `id`; harga, saldo,
  jarak ke dealer, cooldown, dan batas spawn (1 mobil per pemain) dicek di server. Kendaraan yang dimiliki
  tersimpan di data pemain (`vehicles`) dan dikirim ke client lewat atribut Player `OwnedVehicles`.

- **JobService**: pekerjaan pemain. Server menyusun tugas dan menghitung gaji; client hanya melapor "langkah ke-n
  selesai". Setiap langkah dicek jaraknya (pemain harus di dekat penanda) dan waktu tempuhnya (harus wajar untuk
  kendaraan tercepat milik pemain). Ada pengawas perpindahan mendadak, rate limit, dan batas gaji per 5 menit.
  Kemajuan tersimpan di data pemain (`jobs`) dan dikirim ke client lewat atribut Player `Job` dan `JobStats`.

- **TimeService**: jam dunia (siang 16 menit, malam 6 menit; angkanya di `src/shared/DayNightConfig.luau`).
  `DayNightController` (client) memudarkan pencahayaan ke suasana malam, menyalakan lampu jalan, sebagian jendela,
  dan lampu depan mobil.
- **HouseService**: rumah pemain di perumahan (`Workspace.Map.Neighborhoods.Houses`, Rumah No. 1 sampai 89).
  Beli/jual, cat dinding/atap/pintu, hiasan halaman, dan tombol Pulang. Tipe, harga, warna, dan hiasan ada di
  `src/shared/HouseConfig.luau` (**menambah hiasan = menambah entri di `ITEMS`**). Tersimpan di data pemain
  (`house`), dikirim ke client lewat atribut Player `House`. Kalau rumah pemain sedang ditempati orang lain di
  server itu, ia mendapat rumah pengganti setipe.
- **MissionService**: misi harian (berganti pukul 00.00 WIB). Daftar misi dan tempat di peta HP ada di
  `src/shared/MissionConfig.luau`. Kemajuan dihitung server dari tugas pekerjaan dan kunjungan tempat; hadiah
  diambil lewat remote `MissionClaim`. `PhoneController` (client) berisi HP: peta skema, GPS, dan daftar misi.
- **PortalService**: pintu masuk/keluar ruang dalam. Ruang dalam dibangun tepat di atas bangunannya (y = 2000,
  tidak terlihat dari tanah) supaya posisi mendatar pemain tetap. Lobi Rumah Sakit dan ruang tunggu Bandara
  dibangun `map/BuildInteriors.luau`; isi rumah pemain dirakit HouseService dari `HouseConfig.INTERIOR`.
  Lampu ruang dalam harus redup (Brightness sekitar 0,3) dan dindingnya tebal, kalau tidak ruangan jadi silau.
- `VehicleEffectsController` (client): asap knalpot, bekas ban, dan debu; setelannya di tabel `TUNING`.
- Tugas pemadam memakai prop `kios` (kios terbakar) dari `src/client/Util/JobProps.luau`; menahan tombol
  menyemburkan air, dan api yang padam mengepulkan uap dulu.
- Bodi mobil mesh: `VehicleBuilder` memakai templat `ReplicatedStorage.Assets.CarShells.<id>` (berisi MeshPart
  `ShellBody` dan `ShellGlass`) kalau ada; saat ini Serasi dan Kilat. Sumbernya `assets/blender/*.fbx`
  (dibuat dengan skrip di `roblock_cars.blend`), diunggah sebagai aset Model lalu disisipkan ke folder itu.
  Templat tersimpan di place, bukan di repo; tanpa templat mobil tampil dengan bodi kotak.
- **NpcService**: warga kota (rig R15 buatan sendiri dengan baju, rambut/topi, ransel dari part) yang berjalan
  acak antar tempat lewat PathfindingService. Kelompok dan jumlahnya ada di tabel `GROUPS`. Warga tidak
  bertabrakan dengan kendaraan.
- **FarmService**: perkebunan. Beli bibit dan jual hasil panen di Pasar Tani, tanam dan panen di 8 petak pribadi
  Kebun Warga (dibangun `map/BuildFarm.luau`). Tanaman dan harganya di `src/shared/FarmConfig.luau`
  (**menambah tanaman = menambah entri di `CROPS`**). Waktu tumbuh memakai jam server, jadi tanaman tetap
  tumbuh saat pemain keluar. Tersimpan di data pemain (`farm`); tanaman digambar `FarmController` di client.
- Mobil **Elegan** memakai templat `CarShells.elegan` beratribut `Preserve`, dibuat dari model resmi Roblox "Car"
  (Creator Store, gratis, aset 14215126016; skripnya tidak dipakai, hanya mesh bodi dan roda).
- Modifikasi kendaraan: cat dan velg di Halaman Bengkel (`VehicleConfig.PAINTS`, `RIMS`, remote `VehicleMod`,
  `VehicleModController`). Tersimpan per mobil di `vehicles[id].paint` / `.rim`.
- **ShopService**: pembelian Robux (Developer Product koin + Game Pass VIP) dengan `ProcessReceipt` yang mencatat
  ID pembelian di `receipts` supaya koin tidak diberikan dua kali. **Belum aktif**: semua ID di
  `src/shared/ShopConfig.luau` masih 0; cara mengaktifkannya tertulis di berkas itu. Belum ada tampilan toko.
- **PetService**: hewan peliharaan. Beli di Toko Hewan (depan ROBLOCK Mall), satu hewan mengikuti pemilik
  (AlignPosition, tanpa tabrakan), beri makan supaya senang. Daftar hewan di `src/shared/PetConfig.luau`
  (**menambah hewan = menambah entri di `PETS`**). Tersimpan di `pets`; panelnya `PetController`.
- **FashionService**: Toko Baju (depan ROBLOCK Mall). Setelan = topi + jaket yang dirakit UniformService dan
  tampil saat pemain tidak sedang bekerja. Daftar setelan di `src/shared/FashionConfig.luau` (`OUTFITS`).
  Tersimpan di `fashion`; panelnya `FashionController`.
- **BoatService**: perahu motor sewaan di pantai resor (papan "SEWA PERAHU"). Perahu mengapung di air
  Terrain, fisikanya milik server, arah dibaca dari VehicleSeat. Perahu berhenti sendiri di pantai,
  dermaga, dan tepi laut peta. Angka di `src/shared/BoatConfig.luau`; bentuknya mesh Blender di
  `ServerStorage.AsetKapal.perahu` (`assets/blender/perahu.fbx`).
- **PlaneService**: pesawat kecil untuk pekerjaan Pilot (papan "PESAWAT PILOT" di tepi landasan bandara).
  Terbang dibuat mudah: W/S menambah/mengurangi kecepatan, A/D belok, tinggi mengikuti kecepatan; fisika
  milik server. Angka di `src/shared/PlaneConfig.luau`; mesh di `ServerStorage.AsetPesawat.pesawat`
  (`assets/blender/pesawat.fbx`). Tugas pilot memakai langkah `fly` di JobConfig (selesai sendiri saat
  pesawat lewat; `landed` = harus sudah mendarat), diperiksa JobService.
- **Toko Koin**: ID produk dan Game Pass di `src/shared/ShopConfig.luau`. Panelnya `ShopController`
  (menu HP "Toko Koin" dan kios di atrium mall); harga yang tampil dibaca dari Roblox.
- **Motor**: kendaraan dengan `body.bike = true` di VehicleConfig (skuter "lincah"): jok berurutan, dua roda
  tampak, roda fisika tetap empat dan tersembunyi. Templatnya `ReplicatedStorage.Assets.CarShells.lincah`.
- **BusinessService**: usaha Kafe di kasir Kafe Mall (dalam ROBLOCK Mega Mall). Buka kafe, naik tingkat,
  layani pelanggan (bonus, ada jeda), ambil hasil. Pemasukan tiap menit hanya selama pemilik bermain dan
  ditampung sampai batas laci. Angka di `src/shared/BusinessConfig.luau` (`LEVELS`). Tersimpan di
  `business`; panelnya `BusinessController` (juga dari HP: "Kafeku").
- **DebugService**: alat uji, hanya aktif di Studio. Dari command bar server:
  `game.ServerStorage.Debug:Invoke("money", pemain, 5000)` atau `game.ServerStorage.Debug:Invoke("clock", 21)`.
- `src/client/Util/UiScale.luau` mengecilkan HUD di layar kecil; elemen HUD baru cukup memanggil `UiScale.attach`.

### Pekerjaan

- Semua pekerjaan didefinisikan di `src/shared/JobConfig.luau`: `PLACES` (titik di peta), `POOLS` (kelompok tempat),
  dan `LIST` (pekerjaan + templat tugas). **Menambah pekerjaan atau tugas baru = menambah entri**; menu dan server
  mengikuti otomatis. Saat ini: Kurir, Mekanik, Polisi, Pemadam Kebakaran, Dokter.
- Satu tugas = beberapa langkah. Tiap langkah punya tempat (tetap, acak dari pool, atau sama dengan langkah lain),
  teks tombol, lama menahan tombol, dan hiasan opsional (`package`, `car`, `fire`, `person`, `cat`, `cone`).
- Gaji = (`basePay` + `payPerStud` x jarak antar langkah) x bonus level. Level naik menurut jumlah tugas selesai
  (`LEVELS`), +5% gaji per level. Kisaran saat ini sekitar $100 sampai $200 per menit bermain aktif.
- `JobController` (client) menggambar penanda kuning, tiang cahaya, tombol tahan (ProximityPrompt), dan hiasan
  tugas hanya di layar pemain yang bertugas. `JobUiController` berisi menu Pekerjaan dan panel tugas (judul, gaji,
  langkah, jarak, panah arah).
- Koordinat di `PLACES` mengikuti peta di `map/`. Jika bangunan dipindah, perbarui posisinya di sana.

### Seragam dan kendaraan dinas

- **UniformService**: selama bekerja, pemain memakai topi dan rompi sederhana dari Part yang menempel di karakter
  (R15 maupun R6). Bentuk dan warnanya ada di `uniform` pada tiap pekerjaan di `JobConfig`. Topi bawaan avatar
  disembunyikan sementara dan dikembalikan saat berhenti bekerja.
- Kendaraan dinas ada di `VehicleConfig.SERVICE` (Ambulans untuk Dokter, Mobil Pemadam, Mobil Patroli). Gratis,
  tidak dijual di dealer, dan hanya bisa dikeluarkan dari menu Pekerjaan selama menjalani pekerjaannya; saat ganti
  atau berhenti bekerja kendaraan itu dikembalikan. **Menambah kendaraan dinas = menambah satu entri** dengan `job`.
- `VehicleBuilder` mengenal perlengkapan tambahan di `body`: `lightBar` (lampu atap), `band` (pita warna),
  `sideText` (tulisan di sisi), `box` (boks belakang), dan `ladder`. `BeaconController` (client) mengedipkan lampu
  atap selama kursi pengemudi terisi.

### Kendaraan

- Semua kendaraan didefinisikan di `src/shared/VehicleConfig.luau` (`LIST`). **Menambah mobil baru = menambah
  satu entri** (nama, harga, kecepatan, ukuran bodi, warna); menu, dealer, dan fisika mengikuti otomatis.
- `VehicleBuilder` merakit model dari Part secara parametris: chassis bermassa, bodi tanpa massa, empat roda
  silinder dengan `HingeConstraint` motor (penggerak 4 roda). Roda depan dibelokkan dengan memutar attachment
  `SteerFL/SteerFR` di chassis.
- `VehicleController` (client) membaca `VehicleSeat.ThrottleFloat/SteerFloat`, yang diisi skrip kontrol bawaan
  Roblox untuk keyboard, gamepad, dan thumbstick sentuh. Pengemudi memegang network ownership mobilnya.
- Naik mobil lewat ProximityPrompt (ditangani server): pemilik selalu ke kursi pengemudi, pemain lain ke kursi
  penumpang. Lompat untuk turun. Mobil terbalik dibalikkan otomatis.
- Dealer ada di `Workspace.Map.Dealer` (dibangun `map/BuildDealer.luau`). Server menaruh mobil pajangan di part
  bertag `VehicleDisplaySlot`; pembelian hanya bisa di dekat part bertag `VehicleDealer`.

### Mengubah skema data

1. Naikkan `SCHEMA_VERSION` di `src/shared/Config.luau`.
2. Tambah `MIGRATIONS[versiLama] = function(data) ... return data end` di `DataService.luau`.
   Field baru yang cuma butuh nilai default terisi otomatis.

## Peta

Peta disimpan sebagai **kode** di folder `map/` (bukan file .rbxm), jadi setiap perubahan terlihat di git.
Rojo menyinkronkan folder itu ke `ServerStorage/MapBuilders`. Untuk membangun ulang, jalankan di Command Bar
Studio (mode Edit), lalu simpan place:

```lua
local MB = game.ServerStorage.MapBuilders
require(MB.BuildWorld)()       -- Terrain (pulau, laut, gunung) + jalan lingkar. Menghapus Terrain!
require(MB.BuildCountryside)() -- harus setelah BuildWorld (mengukir sungai di Terrain)
require(MB.BuildTown)()
require(MB.BuildDowntown)()
require(MB.BuildResidential)()
require(MB.BuildBeach)()
require(MB.BuildAirport)()
require(MB.BuildDealer)()
require(MB.FixRoads)()         -- penyambung jalan, jembatan ke Pasar Tani, bundaran putar balik di ujung jalan
require(MB.StyleWorld)()       -- rias tampilan; setelah semua pembangun (lihat "Tampilan")
require(MB.StyleTrees)()       -- pohon mesh di taman; setelah StyleWorld
require(MB.BuildInteriors)()   -- lobi Rumah Sakit dan ruang tunggu Bandara (kapan saja)
require(MB.BuildFarm)()        -- Pasar Tani dan Kebun Warga (setelah BuildCountryside)
require(MB.StyleBeach)()       -- kursi pantai (paket gratis Tidewalk Sampler) dan perahu nelayan
require(MB.StyleHouses)()      -- rumah modern (mesh Blender) menggantikan tampilan 89 rumah perumahan
require(MB.StyleRocks)()       -- batu mesh menggantikan batu kotak di Map.Scenery (setelah StyleWorld)
require(MB.StyleRound)()       -- bangunan bersudut bulat + gedung kaca bersirip (pusat kota, kota kecil, pantai, bandara)
require(MB.StyleNature)()      -- PALING AKHIR: tekstur rumput/kayu dan pohon rindang bergaya templat desa resmi Roblox
```

Setiap skrip hanya mengganti foldernya sendiri di `Workspace.Map`. Modul bantu: `MapKit` (part, jalan, pohon,
lampu), `Buildings` (gedung tinggi, toko, lampu lalu lintas, parkir), `Homes` (rumah, rumah mewah, taman bermain),
`Streets` (grid jalan bertrotoar).

Dunia (utara = -Z, sekitar 10.800 part termasuk hiasan alam, semua anchored, StreamingEnabled aktif):

| Kawasan | Folder `Workspace.Map` | Lokasi | Isi |
| --- | --- | --- | --- |
| Jalan lingkar | `Highway` | x -480..900, z -1100..1080 | 4 lajur, penghubung ke tiap kawasan, jembatan ke Beach Island |
| Downtown City | `Downtown` | tengah-utara | Boulevard berpalem, bundaran monumen, 23 gedung tinggi (Menara ROBLOCK 260 stud), mal, hotel, bioskop, SPBU, taman kota |
| Perumahan | `Residential`, `Neighborhoods` | selatan | Kota kecil (RS, damkar, bengkel, toko, kafe, balai kota, taman + spawn), sekolah, taman bermain, ±95 rumah, 6 rumah mewah |
| Beach Island | `Beach` | pulau timur | Jalan pantai, promenade, resor & kolam, dermaga + bianglala, pelabuhan & kapal, mercusuar, sewa jet ski |
| Countryside | `Countryside` | barat | Sungai & air terjun, hutan, ladang, lumbung, kincir angin, sapi & domba, perkemahan |
| Dealer Mobil | `Dealer` | seberang barat taman kota | Showroom, kanopi dengan 6 alas pajangan, halaman untuk mengeluarkan mobil |
| Bandara | `Airport` | barat daya | Landasan pacu, taxiway, terminal, garbarata, menara kontrol, hangar, pesawat |

Catatan Terrain: permukaan terrain tampil sekitar 2 stud di atas batas isi `FillBlock`, jadi rumput diisi sampai
y = -2 agar permukaannya pas di y = 0 (sejajar jalan part). `FillCylinder` membulatkan tinggi ke grid 4 stud,
jadi bentuk bulat digambar sebagai jalur-jalur `FillBlock`.

### Tampilan (StyleWorld)

`map/StyleWorld.luau` merias dunia tanpa mengubah bentuk bangunan, dan menggantikan plugin tampilan yang
biasanya diklik manual. Jalankan setelah semua pembangun, dan ulangi setiap kali ada kawasan yang dibangun ulang
(aman diulang). Bisa juga satu bagian saja, misalnya `require(MB.StyleWorld)("lighting")`.

| Bagian | Isi | Yang diubah untuk menyetel |
| --- | --- | --- |
| `lighting` | Langit bawaan Roblox + awan dinamis, sudut matahari, kabut, bloom, warna, sinar matahari, air | tabel `LOOK` |
| `materials` | Material per nama part: paving di trotoar/blok kota/jalan masuk, plester di dinding rumah, genteng di atap, kaca memantul | tabel `RULES` dan `VARIANTS` |
| `lights` | Semua lampu jalan disetel serentak (jangkauan, terang, warna; tanpa bayangan) | tabel `LIGHTS` |
| `scenery` | Semak, batu, dan bunga disebar acak di rumput kosong, lebih rapat di dekat jalan dan bangunan, ke `Workspace.Map.Scenery` | `REGIONS` (`parts` = batas part per kawasan) dan `SEED` |

- Objek rias di `Lighting` dan `Terrain` ditandai atribut `RoblockStyle`. Sky, Atmosphere, atau efek lain yang
  tidak bertanda (misalnya dari Toolbox) dipindahkan ke `ServerStorage.LightingLama`, tidak dihapus.
- `PavingKota` adalah satu-satunya MaterialVariant bertekstur sendiri (dibuat dengan generator material Studio);
  sisanya material bawaan Roblox, jadi tidak menambah beban tekstur. Jika hilang dari `MaterialService`, skrip
  membuatnya lagi dari ID di `VARIANTS`.
- Bagian `lights` juga memasang tag `NightLight` (part berlampu) dan `NightWindow` (jendela) yang dipakai
  siklus siang/malam di client (`src/shared/DayNightConfig.luau`).
- `map/StyleTrees.luau` juga mengganti semua pohon kelapa pantai dengan "Low-Poly Palm Trees Asset Pack" karya
  Cliosow (aset 8556183988, gratis, hanya MeshPart). Daftar tempat dan paketnya ada di tabel `TARGETS`.
- `map/StyleTrees.luau` mengganti sebagian pohon bola di taman, kota, dan perumahan dengan pohon mesh bercabang dari
  "Low-Poly Oak Trees Asset Pack" karya Cliosow (Creator Store, gratis, aset 8556375773; hanya MeshPart, tanpa
  skrip). Paketnya disimpan di `ServerStorage.AsetPihakKetiga` di dalam place, bukan di repo ini.
- Hiasan alam tanpa tabrakan dan tanpa bayangan. Sebaran selalu sama selama `SEED` tidak diubah.

## Cek kode

- Format: `stylua src map`
- Lint: `selene src map`
