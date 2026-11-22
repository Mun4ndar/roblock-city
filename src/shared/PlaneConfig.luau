--!strict
-- Pesawat kecil untuk pekerjaan Pilot (lihat PlaneService). Semua angka diatur di sini.
-- Arah depan pesawat = sumbu -Z, titik asal model = tanah di bawah tengah badan pesawat.
--
-- Cara terbang dibuat mudah untuk anak-anak: W menambah kecepatan, S mengurangi, A/D belok.
-- Tinggi terbang mengikuti kecepatan: di bawah TAKEOFF_SPEED pesawat di darat, makin kencang
-- makin tinggi sampai CRUISE_HEIGHT. Untuk mendarat cukup pelankan pesawat.

local PlaneConfig = {}

PlaneConfig.JOB = "pilot" -- hanya pemain dengan pekerjaan ini yang bisa mengambil pesawat
PlaneConfig.HANGAR_POSITION = Vector3.new(-1262, 0, 1036) -- papan "PESAWAT PILOT" di tepi landasan
PlaneConfig.HANGAR_RANGE = 34
PlaneConfig.SPAWN_COOLDOWN = 5

-- Ujung barat landasan, menghadap timur. Pemain berikutnya digeser ke belakang garis start.
PlaneConfig.SPAWN = CFrame.new(-1270, 0.4, 1080) * CFrame.Angles(0, -math.pi / 2, 0)
PlaneConfig.GROUND_Y = 0.4

PlaneConfig.MAX_SPEED = 100 -- stud/detik
PlaneConfig.TAKEOFF_SPEED = 50
PlaneConfig.REVERSE_SPEED = 8 -- hanya di darat
PlaneConfig.THROTTLE_RATE = 28 -- seberapa cepat W/S mengubah kecepatan tujuan (stud/detik per detik)
PlaneConfig.ACCELERATION = 16
PlaneConfig.CRUISE_HEIGHT = 200 -- tinggi terbang pada kecepatan penuh
PlaneConfig.CLIMB_SPEED = 22
PlaneConfig.DESCENT_SPEED = 18
PlaneConfig.TURN_RATE = 0.6 -- radian/detik
PlaneConfig.IDLE_SECONDS = 180 -- pesawat kosong selama ini dikembalikan

-- Batas peta: di luar kotak ini pesawat berbelok sendiri kembali ke kota.
PlaneConfig.BOUNDS_MIN = Vector3.new(-2300, 0, -2300)
PlaneConfig.BOUNDS_MAX = Vector3.new(3000, 0, 2300)

PlaneConfig.PROPELLER_NAME = "Baling" -- nama mesh baling-baling di templat (porosnya sumbu Z part)
PlaneConfig.TAG_PLANE = "Plane"
PlaneConfig.ATTR_OWNER = "OwnerUserId"
PlaneConfig.ATTR_SPEED = "Speed" -- atribut model: kecepatan saat ini (untuk tampilan client)

return table.freeze(PlaneConfig)
