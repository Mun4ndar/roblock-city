--!strict
-- BeachLifeConfig: angka untuk dua pemain voli pantai (lapangan di Map.Beach.Hiasan.LapanganVoli) dan
-- penjual pantai: pelayan Kafe Pantai (bar bambu di Map.Beach.KafePantai) dan penjaga Kios Es Krim
-- (Map.Beach.Pantai.KiosEsKrim). Dipakai server (BeachLifeService) dan client
-- (BeachLifeController). Bola voli hanya digambar di client; posisinya dihitung dari waktu server (ballAt),
-- jadi semua pemain melihat bola yang sama tanpa lalu lintas jaringan.

local StoreConfig = require(script.Parent:WaitForChild("StoreConfig"))

local Config = {}

Config.FOLDER = "PantaiHidup" -- Workspace: pemain voli, pelayan, dan atribut Epoch

-- Lapangan voli: jaring membentang sepanjang X di z = COURT_CENTER.Z; lantai pasir di y = COURT_CENTER.Y.
Config.COURT_CENTER = Vector3.new(1529, 2.53, -475.4)
Config.SIDE_DISTANCE = 11 -- jarak pemain dari jaring (sumbu Z)
Config.SIDE_X = 4 -- pemain kiri/kanan sedikit bergeser supaya bola melintas diagonal
Config.HAND_HEIGHT = 5.4 -- tinggi tangan standar (di atas lantai)
Config.BALL_SIZE = 1.7
Config.PLAYER_SCALE = 1.35
Config.RENDER_RANGE = 230 -- bola hanya digambar bila kamera dekat lapangan

-- Penjual di pantai (pelayan Kafe Pantai dan penjaga Kios Es Krim). Satu sistem menu untuk semua penjual:
-- server mengirim OPEN_EVENT(vendorId), client menampilkan MENU penjual itu, lalu memesan lewat
-- ORDER_FUNC(itemId, vendorId). Menambah penjual = menambah satu entri di VENDORS.
Config.OPEN_EVENT = "CafeMenuOpen" -- RemoteEvent server -> client (vendorId)
Config.ORDER_FUNC = "CafeOrder" -- RemoteFunction client -> server (itemId, vendorId) -> { ok, message }
Config.ORDER_DISTANCE = 26
Config.MARKUP = 1.5 -- harga penjual pantai = harga toko x MARKUP

export type Vendor = {
	id: string,
	title: string, -- judul jendela menu
	npcName: string, -- nama Model penjaga di Workspace.PantaiHidup
	objectText: string, -- nama penjaga pada ProximityPrompt
	position: Vector3, -- tempat penjaga berdiri (y = perkiraan lantai)
	facing: Vector3, -- arah hadap penjaga (ke pelanggan)
	menu: { string }, -- id barang dari StoreConfig (animasi makan/minum sama dengan toko)
}

Config.VENDORS = table.freeze({
	cafe = table.freeze({
		id = "cafe",
		title = "🍹 Menu Kafe Pantai",
		npcName = "PelayanKafe",
		objectText = "Pelayan Kafe",
		position = Vector3.new(1622, 0.1, -300),
		facing = Vector3.new(0, 0, -1),
		menu = table.freeze({
			"es_teh",
			"kopi_susu",
			"air_mineral",
			"susu_kotak",
			"es_krim",
			"roti",
			"onigiri",
			"cilok",
		}),
	}),
	eskrim = table.freeze({
		id = "eskrim",
		title = "🍦 Kios Es Krim",
		npcName = "PenjagaEsKrim",
		objectText = "Penjaga Kios Es Krim",
		position = Vector3.new(1419, 0.6, -300),
		facing = Vector3.new(-1, 0, 0),
		menu = table.freeze({
			"es_krim",
			"permen",
			"air_mineral",
			"susu_kotak",
		}),
	}),
}) :: { [string]: Vendor }

function Config.vendor(id: any): Vendor?
	if type(id) ~= "string" then
		return nil
	end
	return Config.VENDORS[id]
end

function Config.price(id: string): number
	local item = StoreConfig.get(id)
	return if item then math.ceil(item.price * Config.MARKUP) else 0
end

-- Lima variasi gerakan, bergilir tiap pukulan (pukulan ke-n memakai variasi n % 5). hand = tinggi tangan
-- saat kontak dengan bola; flight = lama bola melayang sesudah pukulan itu.
Config.VARIATIONS = table.freeze({
	table.freeze({ name = "bump", hand = 4.5, flight = 2.4 }), -- pukulan bawah dua tangan
	table.freeze({ name = "set", hand = 8.0, flight = 2.9 }), -- umpan atas, lambung tinggi
	table.freeze({ name = "spike", hand = 9.6, flight = 1.7 }), -- loncat memukul, bola melesat cepat
	table.freeze({ name = "dive", hand = 2.0, flight = 2.3 }), -- menyelam menjangkau bola rendah
	table.freeze({ name = "celebrate", hand = 5.4, flight = 2.4 }), -- pukulan lalu bersorak
})
Config.NET_CLEAR_HEIGHT = 13.4 -- bola selalu melewati jaring (puncak 12.3) di atas ini

local VAR_COUNT = #Config.VARIATIONS
local CYCLE = 0
for _, v in Config.VARIATIONS do
	CYCLE += v.flight
end
Config.CYCLE_SECONDS = CYCLE

function Config.variationOf(n: number): any
	return Config.VARIATIONS[n % VAR_COUNT + 1]
end

-- Detik (sejak Epoch) saat pukulan ke-n mengenai bola.
function Config.hitTime(n: number): number
	local cycles = n // VAR_COUNT
	local time = cycles * CYCLE
	for i = 1, n % VAR_COUNT do
		time += Config.VARIATIONS[i].flight
	end
	return time
end

-- Titik tangan pemain sisi 0 (z lebih kecil) atau 1 (z lebih besar) saat pukulan ke-n.
function Config.hitPoint(side: number, n: number?): Vector3
	local c = Config.COURT_CENTER
	local dx = if side == 0 then -Config.SIDE_X else Config.SIDE_X
	local dz = if side == 0 then -(Config.SIDE_DISTANCE - 1.4) else Config.SIDE_DISTANCE - 1.4
	local hand = if n then Config.variationOf(n).hand else Config.HAND_HEIGHT
	return Vector3.new(c.X + dx, c.Y + hand, c.Z + dz)
end

-- Posisi bola pada detik t sejak Epoch, dan nomor pukulan. Pukulan ke-n dilakukan sisi n % 2.
function Config.ballAt(t: number): (Vector3, number)
	local cycles = math.floor(t / CYCLE)
	local rest = t - cycles * CYCLE
	local n = cycles * VAR_COUNT
	local f = 0
	for i = 1, VAR_COUNT do
		local flight = Config.VARIATIONS[i].flight
		if rest < flight or i == VAR_COUNT then
			f = math.clamp(rest / flight, 0, 1)
			n += i - 1
			break
		end
		rest -= flight
	end
	local side = n % 2
	local a = Config.hitPoint(side, n)
	local b = Config.hitPoint(1 - side, n + 1)
	local flat = a:Lerp(b, f)
	local extra = math.max(0, Config.NET_CLEAR_HEIGHT - (a.Y + b.Y) / 2)
	return Vector3.new(flat.X, flat.Y + 4 * extra * f * (1 - f), flat.Z), n
end

return table.freeze(Config)
