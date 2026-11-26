--!strict
-- LocStrings.Toko: isi TOKO minimarket (StoreService / StoreController).

local exact: { [string]: string } = {
	["Belanja"] = "Shop",
	["Toko"] = "Store",
	["🛒 Toko"] = "🛒 Store",
	["Belanjaan masuk ke hotbar di bawah layar. Klik barangnya untuk makan, minum, atau bermain."] = "Your purchases go to the hotbar at the bottom of the screen. Click an item to eat, drink, or play.",
	["Penuh"] = "Full",
	["Sudah dimiliki ✔"] = "Owned ✔",
	["Pelan-pelan ya."] = "Slow down a bit.",
	["Barang itu tidak dijual di sini."] = "That item isn't sold here.",
	["Dekati kasir toko dulu ya."] = "Walk up to the store counter first.",
	["Uangmu belum cukup."] = "You don't have enough money yet.",
	["Air Mineral"] = "Bottled Water",
	["Teh Botol"] = "Bottled Tea",
	["Kopi Susu"] = "Milk Coffee",
	["Susu Kotak"] = "Milk Carton",
	["Roti Manis"] = "Sweet Bun",
	["Nasi Kepal"] = "Rice Ball",
	["Keripik Renyah"] = "Crispy Chips",
	["Es Krim"] = "Ice Cream",
	["Cilok"] = "Cilok (chewy snack)",
	["Permen Lolipop"] = "Lollipop",
	["Payung"] = "Umbrella",
	["Bola Karet"] = "Rubber Ball",
	["Mobil Mainan"] = "Toy Car",
	["Boneka Beruang"] = "Teddy Bear",
	["Segar dan menyehatkan."] = "Fresh and healthy.",
	["Dingin, manis, bikin semangat."] = "Cold, sweet, and energizing.",
	["Kopi susu dingin kekinian."] = "Trendy iced milk coffee.",
	["Susu kotak dengan sedotan."] = "A milk carton with a straw.",
	["Roti empuk bertabur wijen."] = "Soft bun sprinkled with sesame.",
	["Nasi kepal segitiga dibalut nori."] = "Triangle rice ball wrapped in nori.",
	["Kriuk-kriuk gurih."] = "Crunchy and savory.",
	["Dua scoop, dingin dan manis."] = "Two scoops, cold and sweet.",
	["Bola-bola kenyal dengan saus."] = "Chewy balls with sauce.",
	["Manis berwarna-warni."] = "Sweet and colorful.",
	["Klik untuk membuka dan menutup payung."] = "Click to open and close the umbrella.",
	["Klik untuk memantulkan bola."] = "Click to bounce the ball.",
	["Klik untuk membunyikan klakson mainan."] = "Click to honk the toy horn.",
	["Klik untuk memeluk dan menebar hati."] = "Click to hug it and spread hearts.",
	["Mau tebus diskon murahnya kak, ada Teh Botol sama Rotinya kak 😊"] = "Want to grab our cheap discounts, sis? We have bottled tea and bread!",
}

local patterns: { { string } } = {
	{ "Kamu punya {}", "You have {}" },
	{
		"{} dibeli! Cek hotbar di bawah, klik untuk memakainya.",
		"{} bought! Check the hotbar below and click to use it.",
	},
	{ "{} dibeli! Cek hotbar di bawah.", "{} bought! Check the hotbar below." },
	{ "Kamu sudah punya {}.", "You already have {}." },
	{ "Tasmu penuh untuk {} (maksimal {}).", "Your bag is full for {} (max {})." },
	{ "Segar! {} habis. Kamu merasa semangat.", "Refreshing! {} is gone. You feel energized." },
	{ "Enak! {} habis. Kamu merasa semangat.", "Yummy! {} is gone. You feel energized." },
}

return { exact = exact, patterns = patterns }
