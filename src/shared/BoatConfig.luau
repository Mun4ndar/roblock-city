--!strict
-- Perahu motor sewaan di pantai (lihat BoatService). Semua angka diatur di sini.
-- Arah depan perahu = sumbu -Z, titik asal model = lunas (dasar lambung) di tengah perahu.

local BoatConfig = {}

BoatConfig.RENT_POSITION = Vector3.new(2108, 0, -150) -- papan sewa di tepi pantai resor
BoatConfig.RENT_RANGE = 30
BoatConfig.RENT_PRICE = 30
BoatConfig.RENT_COOLDOWN = 5 -- detik antar sewa

-- Tempat perahu muncul (menghadap ke laut). Tiap pemain mendapat petak sendiri di sepanjang Z.
BoatConfig.SPAWN = CFrame.new(2162, -2, -150) * CFrame.Angles(0, -math.pi / 2, 0)
BoatConfig.SPAWN_SPACING = 14
BoatConfig.SPAWN_SLOTS = 6
BoatConfig.WATER_Y = -2

BoatConfig.MAX_SPEED = 44 -- stud/detik
BoatConfig.REVERSE_SPEED = 12
BoatConfig.ACCELERATION = 16 -- stud/detik^2
BoatConfig.TURN_RATE = 1.0 -- radian/detik pada kecepatan penuh
BoatConfig.IDLE_SECONDS = 180 -- perahu kosong selama ini dikembalikan
BoatConfig.SEATS = 4

BoatConfig.TAG_BOAT = "Boat"
BoatConfig.ATTR_OWNER = "OwnerUserId"

return table.freeze(BoatConfig)
