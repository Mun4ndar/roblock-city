--!strict
-- PasarMalamConfig: penjual dan pembeli NPC di Pasar Malam Taman Kota (dipakai PasarMalamService di server
-- dan LocStrings/PasarMalam untuk terjemahan Inggris). Kunci penjual = nama papan lapak (StallName di map/BuildPasarMalam).

local PasarMalamConfig = {}

export type Look = {
	skin: Color3,
	top: Color3,
	bottom: Color3,
	hair: Color3,
	hairStyle: string, -- "pendek" | "sanggul" | "kuncir"
	hat: string?, -- "peci" | "topiKoki" | "bandana" | "hijab" | "caping"
	apron: Color3?,
}

export type Vendor = {
	name: string,
	title: string,
	look: Look,
	-- sapaan: {Indonesia, English}; selalu memanggil pemain "Kak"
	lines: { { string } },
}

local rgb = Color3.fromRGB

local function look(
	skin: Color3,
	top: Color3,
	bottom: Color3,
	hair: Color3,
	hairStyle: string,
	hat: string?,
	apron: Color3?
): Look
	return {
		skin = skin,
		top = top,
		bottom = bottom,
		hair = hair,
		hairStyle = hairStyle,
		hat = hat,
		apron = apron,
	}
end

local SK1, SK2, SK3, SK4 =
	rgb(224, 172, 120), rgb(204, 150, 106), rgb(236, 190, 144), rgb(190, 138, 96)
local BLACK, DARK, BROWN = rgb(28, 24, 24), rgb(44, 32, 28), rgb(70, 44, 30)
local WHITE, DENIM = rgb(246, 244, 238), rgb(52, 70, 110)

PasarMalamConfig.VENDORS = {
	["Bakso Pak Slamet"] = {
		name = "Pak Slamet",
		title = "Penjual Bakso",
		look = look(SK2, WHITE, DENIM, BLACK, "pendek", "peci", rgb(200, 60, 50)),
		lines = {
			{
				"Halo, Kak! Bakso anget, kuahnya mantap!",
				"Hi, Kak! Hot meatball soup, the broth is great!",
			},
			{ "Mampir, Kak! Baksonya kenyal lho!", "Come on over, Kak! The meatballs are bouncy!" },
		},
	},
	["Sate Madura"] = {
		name = "Pak Madi",
		title = "Penjual Sate",
		look = look(SK4, rgb(200, 70, 60), rgb(40, 40, 48), BLACK, "pendek", "peci"),
		lines = {
			{
				"Sate Madura, Kak! Dibakar langsung, wangi!",
				"Madura satay, Kak! Grilled fresh, smells great!",
			},
			{
				"Silakan, Kak! Bumbu kacangnya kental!",
				"Please, Kak! The peanut sauce is thick and rich!",
			},
		},
	},
	["Gorengan Bu Tini"] = {
		name = "Bu Tini",
		title = "Penjual Gorengan",
		look = look(
			SK1,
			rgb(236, 140, 170),
			rgb(90, 60, 110),
			DARK,
			"sanggul",
			"hijab",
			rgb(250, 230, 120)
		),
		lines = {
			{
				"Gorengan panas, Kak! Baru angkat dari wajan!",
				"Hot fritters, Kak! Fresh out of the wok!",
			},
			{
				"Pisang goreng dan tahu isi, Kak. Cobain ya!",
				"Fried banana and stuffed tofu, Kak. Give it a try!",
			},
		},
	},
	["Es Cendol Segar"] = {
		name = "Mas Dedi",
		title = "Penjual Es Cendol",
		look = look(SK3, rgb(90, 170, 110), rgb(48, 50, 56), BLACK, "pendek", nil, WHITE),
		lines = {
			{
				"Es cendol segar, Kak! Gula merahnya asli!",
				"Fresh cendol ice, Kak! Real palm sugar!",
			},
			{ "Panas-panas enaknya es cendol, Kak!", "Nothing beats cendol on a hot night, Kak!" },
		},
	},
	["Martabak Manis"] = {
		name = "Koh Aming",
		title = "Penjual Martabak",
		look = look(
			SK3,
			rgb(250, 200, 70),
			rgb(48, 50, 56),
			BLACK,
			"pendek",
			"bandana",
			rgb(220, 90, 60)
		),
		lines = {
			{
				"Martabak manis, Kak! Cokelat keju melimpah!",
				"Sweet martabak, Kak! Loads of chocolate and cheese!",
			},
			{
				"Tebal dan lembut, Kak! Mau berapa loyang?",
				"Thick and fluffy, Kak! How many would you like?",
			},
		},
	},
	["Jagung Bakar"] = {
		name = "Pak Joko",
		title = "Penjual Jagung Bakar",
		look = look(SK2, rgb(120, 160, 90), rgb(80, 66, 50), BLACK, "pendek", "caping"),
		lines = {
			{
				"Jagung bakar, Kak! Manis, pedas, atau keju?",
				"Grilled corn, Kak! Sweet, spicy, or cheese?",
			},
			{ "Hangat-hangat, Kak! Dibakar arang!", "Nice and warm, Kak! Charcoal grilled!" },
		},
	},
	["Nasi Goreng Gerobak"] = {
		name = "Bang Udin",
		title = "Penjual Nasi Goreng",
		look = look(
			SK4,
			rgb(60, 60, 66),
			rgb(40, 40, 48),
			BLACK,
			"pendek",
			"bandana",
			rgb(240, 240, 235)
		),
		lines = {
			{
				"Nasi goreng spesial, Kak! Telurnya dua!",
				"Special fried rice, Kak! Two eggs on top!",
			},
			{ "Pedas atau nggak, Kak? Bilang aja!", "Spicy or not, Kak? Just tell me!" },
		},
	},
	["Gado-gado Bu Sri"] = {
		name = "Bu Sri",
		title = "Penjual Gado-gado",
		look = look(
			SK1,
			rgb(110, 170, 150),
			rgb(100, 70, 50),
			DARK,
			"sanggul",
			"hijab",
			rgb(250, 250, 245)
		),
		lines = {
			{
				"Gado-gado segar, Kak! Sayurnya baru dipetik!",
				"Fresh gado-gado, Kak! The veggies were just picked!",
			},
			{
				"Bumbu kacang buatan sendiri, Kak. Enak lho!",
				"Homemade peanut sauce, Kak. So tasty!",
			},
		},
	},
	["Es Campur Segar"] = {
		name = "Mbak Rina",
		title = "Penjual Es Campur",
		look = look(
			SK3,
			rgb(255, 150, 180),
			rgb(60, 60, 80),
			rgb(60, 36, 28),
			"kuncir",
			nil,
			WHITE
		),
		lines = {
			{
				"Es campur, Kak! Buahnya warna-warni!",
				"Mixed fruit ice, Kak! Colorful fruits inside!",
			},
			{ "Segar banget, Kak! Tambah susu ya?", "So refreshing, Kak! Want some milk on top?" },
		},
	},
	["Kopi & Roti Bakar"] = {
		name = "Mas Bayu",
		title = "Penjual Kopi dan Roti Bakar",
		look = look(SK2, rgb(150, 100, 70), rgb(44, 44, 50), DARK, "pendek", nil, rgb(60, 50, 44)),
		lines = {
			{
				"Kopi hangat dan roti bakar, Kak! Cocok buat ngobrol!",
				"Warm coffee and toast, Kak! Perfect for a chat!",
			},
			{
				"Roti bakar cokelat keju, Kak! Yuk dicoba!",
				"Chocolate cheese toast, Kak! Give it a try!",
			},
		},
	},
	["Festival: Sate Lilit"] = {
		name = "Pak Wayan",
		title = "Penjual Sate Lilit",
		look = look(SK4, rgb(240, 240, 235), rgb(190, 70, 60), BLACK, "pendek", "bandana"),
		lines = {
			{
				"Sate lilit khas Bali, Kak! Wangi serai!",
				"Balinese satay, Kak! Smells of lemongrass!",
			},
			{
				"Selamat datang di festival, Kak! Cicipi dulu!",
				"Welcome to the festival, Kak! Have a taste first!",
			},
		},
	},
	["Festival: Kerak Telor"] = {
		name = "Bang Jali",
		title = "Penjual Kerak Telor",
		look = look(
			SK2,
			rgb(220, 60, 60),
			rgb(40, 40, 48),
			BLACK,
			"pendek",
			"peci",
			rgb(250, 240, 200)
		),
		lines = {
			{
				"Kerak telor Betawi, Kak! Asli dari arang!",
				"Betawi kerak telor, Kak! Real charcoal cooked!",
			},
			{
				"Mari, Kak! Telurnya bebek, gurih banget!",
				"Come, Kak! Made with duck egg, so savory!",
			},
		},
	},
	["Festival: Soto & Bakso"] = {
		name = "Pak Karto",
		title = "Penjual Soto dan Bakso",
		look = look(
			SK1,
			WHITE,
			rgb(60, 60, 70),
			rgb(70, 66, 66),
			"pendek",
			"peci",
			rgb(70, 120, 190)
		),
		lines = {
			{
				"Soto ayam kuah kuning, Kak! Hangat di badan!",
				"Yellow chicken soto, Kak! Warms you right up!",
			},
			{ "Soto atau bakso, Kak? Dua-duanya enak!", "Soto or meatballs, Kak? Both are great!" },
		},
	},
	["Festival: Jajan Pasar"] = {
		name = "Mbok Yem",
		title = "Penjual Jajan Pasar",
		look = look(
			SK1,
			rgb(180, 90, 60),
			rgb(90, 60, 50),
			rgb(210, 210, 210),
			"sanggul",
			nil,
			rgb(250, 230, 160)
		),
		lines = {
			{
				"Jajan pasar, Kak! Klepon, cenil, getuk, ada semua!",
				"Traditional snacks, Kak! Klepon, cenil, getuk, we have it all!",
			},
			{
				"Manisnya pas, Kak! Dicicipi dulu ya!",
				"Just the right sweetness, Kak! Taste one first!",
			},
		},
	},
	["Festival: Es Segar"] = {
		name = "Bli Komang",
		title = "Penjual Es Kelapa",
		look = look(SK4, rgb(70, 160, 200), rgb(240, 240, 235), BLACK, "pendek", "bandana"),
		lines = {
			{
				"Es kelapa muda, Kak! Langsung dari buahnya!",
				"Young coconut ice, Kak! Straight from the fruit!",
			},
			{
				"Segar, Kak! Dagingnya tebal dan manis!",
				"So fresh, Kak! The flesh is thick and sweet!",
			},
		},
	},
	["Festival: Martabak"] = {
		name = "Mas Dimas",
		title = "Penjual Terang Bulan",
		look = look(
			SK3,
			rgb(240, 130, 60),
			rgb(48, 50, 56),
			BLACK,
			"pendek",
			"bandana",
			rgb(250, 250, 245)
		),
		lines = {
			{
				"Terang bulan, Kak! Renyah di pinggir, lembut di tengah!",
				"Terang bulan pancake, Kak! Crisp edges, soft middle!",
			},
			{ "Kacang, cokelat, atau keju, Kak?", "Peanut, chocolate, or cheese, Kak?" },
		},
	},
} :: { [string]: Vendor }

-- Ucapan terima kasih setelah pemain membeli. {Indonesia, English}
PasarMalamConfig.THANKS = {
	{ "Terima kasih, Kak! Selamat menikmati!", "Thank you, Kak! Enjoy!" },
	{ "Makasih ya, Kak! Datang lagi!", "Thanks, Kak! Come again!" },
	{ "Silakan, Kak! Semoga suka!", "Here you go, Kak! Hope you like it!" },
}

-- Pembeli NPC yang berkeliling melihat-lihat lapak.
PasarMalamConfig.SHOPPERS = {
	{ name = "Dina", look = look(SK1, rgb(255, 170, 200), DENIM, DARK, "kuncir") },
	{ name = "Rafi", look = look(SK3, rgb(90, 150, 220), rgb(60, 60, 70), BLACK, "pendek") },
	{
		name = "Ibu Ratna",
		look = look(SK2, rgb(120, 190, 160), rgb(90, 60, 110), DARK, "sanggul", "hijab"),
	},
	{
		name = "Pak Agus",
		look = look(SK4, rgb(200, 190, 160), rgb(70, 60, 50), rgb(90, 86, 86), "pendek", "peci"),
	},
	{ name = "Putri", look = look(SK3, rgb(250, 220, 90), rgb(60, 80, 130), BROWN, "kuncir") },
	{ name = "Bimo", look = look(SK2, rgb(220, 90, 80), rgb(44, 44, 50), BLACK, "pendek") },
	{
		name = "Nenek Sumi",
		look = look(SK1, rgb(180, 120, 160), rgb(80, 60, 70), rgb(220, 220, 220), "sanggul"),
	},
	{
		name = "Kak Tika",
		look = look(SK1, rgb(110, 200, 190), rgb(240, 240, 235), BLACK, "kuncir"),
	},
	{ name = "Andi", look = look(SK4, rgb(240, 160, 60), rgb(52, 70, 110), BLACK, "pendek") },
}

-- Celoteh pembeli sesekali. {Indonesia, English}
PasarMalamConfig.SHOPPER_LINES = {
	{ "Wah, harum banget!", "Wow, smells so good!" },
	{ "Mau jajan apa ya?", "What should I get?" },
	{ "Seru ya pasar malamnya!", "The night market is so much fun!" },
	{ "Lampunya cantik!", "The lights are so pretty!" },
	{ "Aku mau yang itu!", "I want that one!" },
}

PasarMalamConfig.SHOPPERS_NIGHT = 6 -- pembeli saat pasar malam biasa
PasarMalamConfig.SHOPPERS_FESTIVAL = 9 -- saat festival kuliner
PasarMalamConfig.SPAWN_RANGE = 140 -- stud dari pusat pasar: NPC dibuat
PasarMalamConfig.DESPAWN_RANGE = 200 -- semua pemain lebih jauh: NPC dihapus (hemat HP)
PasarMalamConfig.GREET_RANGE = 15
PasarMalamConfig.GREET_COOLDOWN = 14

return PasarMalamConfig
