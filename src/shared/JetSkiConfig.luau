--!strict
-- Sewa Jet Ski + tantangan cincin di laut lepas (lihat JetSkiService). Semua angka diatur di sini.
-- Arah depan jet ski = sumbu -Z, titik asal model = tengah lunas.
-- Nama remote (dibuat server lewat Net.event): JetSkiRun (RemoteEvent, server -> client).

local JetSkiConfig = {}

JetSkiConfig.RENT_POSITION = Vector3.new(1652, 0, -390) -- papan sewa di tepi pantai resor
JetSkiConfig.RENT_RANGE = 30
JetSkiConfig.RENT_PRICE = 40
JetSkiConfig.RENT_COOLDOWN = 5 -- detik antar sewa

-- Tempat jet ski muncul di laut (menghadap ke laut). Tiap pemain mendapat petak sendiri di sepanjang Z.
JetSkiConfig.SPAWN = CFrame.new(1712, -2, -450) * CFrame.Angles(0, -math.pi / 2, 0)
JetSkiConfig.SPAWN_SPACING = 12
JetSkiConfig.SPAWN_SLOTS = 6
JetSkiConfig.WATER_Y = -2
JetSkiConfig.HULL_LIFT = 0.8 -- pusat lambung (kotak tabrakan setinggi 2) di atas permukaan air
JetSkiConfig.LIFT_P = 30 -- pegas penahan tinggi (percepatan per stud selisih)
JetSkiConfig.LIFT_D = 11 -- peredam (percepatan per stud/detik)

JetSkiConfig.MAX_SPEED = 62 -- stud/detik
JetSkiConfig.REVERSE_SPEED = 14
JetSkiConfig.ACCELERATION = 24 -- stud/detik^2
JetSkiConfig.TURN_RATE = 1.2 -- radian/detik pada kecepatan penuh
JetSkiConfig.IDLE_SECONDS = 180 -- jet ski kosong selama ini dikembalikan
JetSkiConfig.SEATS = 2

JetSkiConfig.TAG = "JetSki"
JetSkiConfig.ATTR_OWNER = "OwnerUserId"
JetSkiConfig.REMOTE_RUN = "JetSkiRun"

-- ---------------------------------------------------------------- tantangan cincin
-- Lintasan di laut terbuka sebelah timur pantai. Dasar laut dangkal (landas) ada di z > -400 dekat
-- pantai, jadi lintasan dan tempat sewa muncul di z <= -420 (jet ski kandas di dasar yang lebih tinggi dari -3). Titik dalam koordinat
-- dunia (x, z); cincin melayang dengan pusat di WATER_Y + RING_LIFT. Cincin terakhir = garis finis.
JetSkiConfig.START = Vector2.new(1790, -480) -- pelampung mulai (tombol "Mulai Tantangan")
JetSkiConfig.START_RANGE = 26 -- pemain harus dekat pelampung
JetSkiConfig.COURSE = table.freeze({
	Vector2.new(1890, -540),
	Vector2.new(2000, -610),
	Vector2.new(2120, -690),
	Vector2.new(2250, -740),
	Vector2.new(2370, -690),
	Vector2.new(2340, -570),
	Vector2.new(2220, -490),
	Vector2.new(2090, -450),
	Vector2.new(1960, -440),
	Vector2.new(1850, -450), -- finis
})
JetSkiConfig.RING_RADIUS = 9 -- lubang cincin (stud)
JetSkiConfig.RING_LIFT = 2 -- tinggi pusat cincin di atas permukaan air
JetSkiConfig.RING_SEGMENTS = 16

JetSkiConfig.TIME_LIMIT = 120 -- detik; lewat dari ini tantangan batal
JetSkiConfig.PAR_TIME = 45 -- waktu patokan; lebih cepat dari ini dapat bonus waktu
JetSkiConfig.UNSEATED_GRACE = 8 -- detik boleh turun dari jet ski sebelum batal
JetSkiConfig.RUN_COOLDOWN = 4 -- detik jeda sebelum mulai lagi

-- Hadiah (koin, dibayar server)
JetSkiConfig.REWARD_RING = 5 -- tiap cincin dilewati
JetSkiConfig.REWARD_FINISH = 40
JetSkiConfig.REWARD_PER_SECOND_FASTER = 2 -- bonus tiap detik lebih cepat dari PAR_TIME
JetSkiConfig.REWARD_TIME_BONUS_MAX = 60
JetSkiConfig.REWARD_NEW_BEST = 25

JetSkiConfig.BOARD_ROWS = 5 -- papan skor sesi server: jumlah baris

return table.freeze(JetSkiConfig)
