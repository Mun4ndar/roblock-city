# ROBLOCK CITY

Game roleplay kota open-world yang ramah anak (tanpa senjata/kekerasan/kriminal).
Dibangun dengan [Rojo](https://rojo.space): kode ada di folder `src/`, lalu disinkronkan ke Roblox Studio.

## Mulai develop

1. Pasang toolchain lewat [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`
   (membaca versi dari `rokit.toml`: Rojo, Wally, Selene, StyLua).
2. Pasang plugin Rojo di Studio: `rojo plugin install`
3. Jalankan `rojo serve`, lalu di Studio klik **Rojo > Connect**.

## Struktur

| Folder | Di Studio | Isi |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage/Shared | Config, Types, Net (remote), Format, VehicleConfig, VehicleBuilder |
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
```

Setiap skrip hanya mengganti foldernya sendiri di `Workspace.Map`. Modul bantu: `MapKit` (part, jalan, pohon,
lampu), `Buildings` (gedung tinggi, toko, lampu lalu lintas, parkir), `Homes` (rumah, rumah mewah, taman bermain),
`Streets` (grid jalan bertrotoar).

Dunia (utara = -Z, sekitar 8.500 part, semua anchored, StreamingEnabled aktif):

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

## Cek kode

- Format: `stylua src map`
- Lint: `selene src map`
