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
| `src/shared` | ReplicatedStorage/Shared | Config, Types, Net (remote), Format |
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

### Mengubah skema data

1. Naikkan `SCHEMA_VERSION` di `src/shared/Config.luau`.
2. Tambah `MIGRATIONS[versiLama] = function(data) ... return data end` di `DataService.luau`.
   Field baru yang cuma butuh nilai default terisi otomatis.

## Peta

Peta disimpan sebagai kode di `map/BuildTown.luau` (bukan file .rbxm), jadi perubahannya bisa dilihat di git.
Skrip itu menghapus lalu membangun ulang `Workspace.Map`: jalankan di Studio mode Edit lewat Command Bar
(tempel isinya) atau lewat Studio MCP. Setelah itu simpan place (Ctrl+S).

Kota kecil saat ini (`Workspace.Map`, sekitar 700 part, semuanya anchored):

| Folder | Isi |
| --- | --- |
| `Ground` | Tanah rumput 560x560 |
| `Roads` | Grid jalan 3x3 (lebar 32, 2 lajur): segmen, persimpangan, marka kuning/putih, zebra cross |
| `Sidewalks` | Pelat trotoar tiap blok + trotoar perumahan |
| `Buildings/Downtown` | Toko, Kafe, Balai Kota, Rumah Sakit, Pemadam Kebakaran, Bengkel (masih placeholder) |
| `Buildings/Houses` | 6 rumah di sisi utara jalan z = 120 |
| `Park` | Taman dengan air mancur, bangku (bisa diduduki), petak bunga |
| `Props` | Pohon, lampu jalan, tempat sampah, hidran |
| `Spawns` | 4 SpawnLocation di jalan setapak taman (tanpa force field) |

## Cek kode

- Format: `stylua src`
- Lint: `selene src`
