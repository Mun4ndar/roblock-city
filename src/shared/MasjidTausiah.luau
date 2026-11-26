--!strict
--[[
	MasjidTausiah: kumpulan tausiah tambahan untuk Masjid Al Munawaroh (MasjidConfig.tausiahPool menggabungkannya
	dengan lima tausiah awal). Tiap topik 6 baris pendek, lembut, cocok untuk anak-anak, dengan balasan jamaah.
	Teks Indonesia = sumber; padanan Inggris ikut di sini dan didaftarkan ke Loc oleh LocStrings/MasjidTausiah.
	Menambah topik = satu entri topic(...) di bawah.
]]

local MasjidTausiah = {}

export type Line = { text: string, en: string, replyBy: string?, reply: string?, replyEn: string? }
export type Topic = { title: string, titleEn: string, lines: { Line } }

local function L(text: string, en: string, by: string?, reply: string?, replyEn: string?): Line
	return { text = text, en = en, replyBy = by, reply = reply, replyEn = replyEn }
end

local function topic(title: string, titleEn: string, lines: { Line }): Topic
	return { title = title, titleEn = titleEn, lines = lines }
end

local AMIN = "Aamiin. 🤲"
local AMIN_EN = "Aameen. 🤲"

MasjidTausiah.TOPICS = {
	topic("Menjaga Kebersihan", "Keeping Things Clean", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar tentang menjaga kebersihan.",
			"Assalamu'alaikum. Today we learn about keeping things clean."
		),
		L(
			"Mandi, cuci tangan, dan merapikan pakaian membuat badan sehat dan nyaman dipandang.",
			"Bathing, washing hands, and tidying clothes keep us healthy and pleasant to be around.",
			"Dimas",
			"Aku cuci tangan sebelum makan, Ustadz!",
			"I wash my hands before eating, Ustadz!"
		),
		L(
			"Masjid, sekolah, dan rumah juga perlu dijaga bersih. Buang sampah pada tempatnya, ya.",
			"Mosques, schools, and homes need to be kept clean too. Please throw trash in the bin."
		),
		L(
			"Lihatlah masjid kita yang bersih. Itu berkat Pak Jaka yang rajin menyapu setiap hari.",
			"Look how clean our mosque is. That is thanks to Pak Jaka, who sweeps diligently every day.",
			"PakHaji",
			"Terima kasih, Pak Jaka, sudah merawat masjid kita.",
			"Thank you, Pak Jaka, for caring for our mosque."
		),
		L(
			"Kebersihan bukan hanya tugas satu orang. Kalau kita menjaga bersama, hasilnya terasa sampai ke semua.",
			"Cleanliness is not one person's job. When we all take care of it, everyone feels the benefit."
		),
		L(
			"Semoga kita menjadi orang yang bersih badan, bersih tempat, dan bersih hati. Aamiin.",
			"May we be clean in body, in our surroundings, and in heart. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Sabar Itu Kuat", "Patience Is Strength", {
		L(
			"Assalamu'alaikum. Kali ini kita bicara tentang sabar.",
			"Assalamu'alaikum. This time we talk about patience."
		),
		L(
			"Sabar bukan berarti lemah. Sabar berarti mampu menahan diri saat kesal atau harus menunggu.",
			"Patience does not mean weakness. It means holding ourselves back when we are upset or have to wait.",
			"Dimas",
			"Kadang aku kesal kalau antre lama, Ustadz.",
			"Sometimes I get upset when the line is long, Ustadz."
		),
		L(
			"Wajar, Nak. Tarik napas dalam-dalam, hitung sampai sepuluh, lalu hatimu akan lebih tenang. 😊",
			"That's natural, dear. Take a deep breath, count to ten, and your heart will feel calmer. 😊"
		),
		L(
			"Petani menanam benih lalu menunggu berbulan-bulan sebelum panen. Hasil baik butuh kesabaran.",
			"A farmer plants seeds and waits for months before the harvest. Good results take patience.",
			"PakJoko",
			"Benar, Ustadz. Padi tidak bisa dipaksa cepat tumbuh.",
			"That's right, Ustadz. Rice cannot be rushed to grow."
		),
		L(
			"Saat belajar hal baru, wajar kalau belum bisa. Teruslah mencoba dan jangan cepat menyerah.",
			"When we learn something new, it is normal not to get it right away. Keep trying and don't give up easily."
		),
		L(
			"Semoga Allah menjadikan kita orang yang sabar dan tenang hatinya. Aamiin.",
			"May Allah make us patient and calm of heart. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menghormati Guru", "Respecting Our Teachers", {
		L(
			"Assalamu'alaikum. Hari ini kita membahas tentang menghormati guru.",
			"Assalamu'alaikum. Today we talk about respecting our teachers."
		),
		L(
			"Guru mengajarkan huruf, angka, dan sopan santun. Karena guru, kita bisa membaca dan berhitung.",
			"Teachers teach us letters, numbers, and good manners. Because of them, we can read and count.",
			"KakNurul",
			"Guruku sabar sekali mengajariku membaca.",
			"My teacher is so patient in teaching me to read."
		),
		L(
			"Cara menghormati guru itu mudah: mengucap salam, mendengarkan saat dijelaskan, dan tidak mengobrol di kelas.",
			"Respecting teachers is easy: say hello, listen when they explain, and don't chat during class."
		),
		L(
			"Kalau belum paham, bertanyalah dengan sopan. Guru senang pada murid yang mau belajar. 📖",
			"If you don't understand, ask politely. Teachers are happy with students who want to learn. 📖",
			"Dimas",
			"Aku berani bertanya kalau tidak mengerti!",
			"I dare to ask when I don't understand!"
		),
		L(
			"Doakan guru-guru kita agar sehat dan ilmunya bermanfaat bagi banyak orang.",
			"Pray for our teachers to stay healthy and for their knowledge to benefit many people."
		),
		L(
			"Semoga kita menjadi murid yang sopan dan rajin. Aamiin.",
			"May we become polite and diligent students. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menyayangi Hewan", "Being Kind to Animals", {
		L(
			"Assalamu'alaikum. Pagi ini kita belajar menyayangi hewan.",
			"Assalamu'alaikum. Today we learn about being kind to animals."
		),
		L(
			"Kucing, burung, dan ayam juga makhluk ciptaan Allah. Mereka bisa lapar, haus, dan merasa sakit.",
			"Cats, birds, and chickens are also creatures made by Allah. They can feel hungry, thirsty, and in pain.",
			"KakNurul",
			"Di rumah aku punya kucing, Ustadz!",
			"I have a cat at home, Ustadz!"
		),
		L(
			"Wah, bagus! Beri makan dan minum secukupnya, dan jangan menyakiti atau mengganggunya. 🐱",
			"Wonderful! Give it enough food and water, and never hurt or bother it. 🐱"
		),
		L(
			"Kalau melihat hewan kehausan, tolonglah dengan memberinya air. Perbuatan kecil itu sangat mulia.",
			"If you see a thirsty animal, help it with some water. Such a small act is truly noble.",
			"PakBudi",
			"Betul, Ustadz. Hewan juga perlu dikasihani.",
			"That's right, Ustadz. Animals deserve compassion too."
		),
		L(
			"Hewan peliharaan butuh dirawat: kandangnya dibersihkan dan kesehatannya diperhatikan.",
			"Pets need care: keep their homes clean and watch over their health."
		),
		L(
			"Semoga hati kita lembut kepada semua makhluk. Aamiin.",
			"May our hearts be gentle toward all creatures. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menjaga Alam", "Caring for Nature", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar menjaga alam.",
			"Assalamu'alaikum. Today we learn about caring for nature."
		),
		L(
			"Pohon memberi udara segar dan tempat berteduh. Sungai dan laut memberi air dan ikan.",
			"Trees give fresh air and shade. Rivers and seas give water and fish.",
			"PakJoko",
			"Di kebun, pohon-pohon menaungi kami dari panas.",
			"In the garden, the trees shelter us from the heat."
		),
		L(
			"Karena itu, jangan mencabut tanaman sembarangan dan jangan membuang sampah ke sungai atau laut. 🌳",
			"So don't pull up plants carelessly and don't throw trash into rivers or the sea. 🌳"
		),
		L(
			"Hemat air dan listrik juga cara menjaga alam. Matikan lampu dan keran kalau sudah tidak dipakai.",
			"Saving water and electricity is also a way to care for nature. Turn off lights and taps when not in use.",
			"Dimas",
			"Aku selalu mematikan keran, Ustadz!",
			"I always turn off the tap, Ustadz!"
		),
		L(
			"Menanam satu pohon hari ini bisa menjadi tempat berteduh banyak orang di masa depan.",
			"Planting one tree today can become shade for many people in the future."
		),
		L(
			"Semoga kita menjadi penjaga bumi yang baik. Aamiin.",
			"May we be good guardians of the earth. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Membantu Tetangga", "Helping Our Neighbors", {
		L(
			"Assalamu'alaikum. Malam ini kita bicara tentang tetangga.",
			"Assalamu'alaikum. Tonight we talk about our neighbors."
		),
		L(
			"Tetangga adalah orang yang pertama menolong kita saat ada kesulitan. Karena itu kita perlu menjaga hubungan baik.",
			"Neighbors are the first to help us in hard times. That's why we should keep good relations.",
			"BuAisyah",
			"Tetanggaku sering mengantar kue untuk kami.",
			"My neighbor often brings us cake."
		),
		L(
			"Alhamdulillah. Kita juga bisa membalas dengan senyum, sapaan, dan berbagi makanan.",
			"Alhamdulillah. We can return the kindness with smiles, greetings, and sharing food."
		),
		L(
			"Jangan membuat bising di waktu istirahat, dan jaga agar halaman tidak mengganggu mereka.",
			"Don't make noise during rest times, and keep our yards from bothering them.",
			"PakDedi",
			"Benar, Ustadz. Tetangga yang rukun membuat hidup tenteram.",
			"That's right, Ustadz. Peaceful neighbors make life calm."
		),
		L(
			"Kalau tetangga sakit atau sedang kesusahan, datanglah menjenguk dan tawarkan bantuan.",
			"If a neighbor is sick or in trouble, visit and offer help."
		),
		L(
			"Semoga lingkungan kita rukun dan penuh kasih sayang. Aamiin.",
			"May our neighborhood be peaceful and full of care. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Rajin Belajar", "Studying Diligently", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar tentang rajin belajar.",
			"Assalamu'alaikum. Today we learn about studying diligently."
		),
		L(
			"Mencari ilmu itu sangat mulia. Dengan ilmu kita bisa membantu diri sendiri dan orang lain.",
			"Seeking knowledge is very noble. With knowledge we can help ourselves and others.",
			"Dimas",
			"Aku mau jadi dokter supaya bisa menolong orang!",
			"I want to be a doctor so I can help people!"
		),
		L(
			"MasyaAllah, cita-cita yang indah. Untuk sampai ke sana, belajarlah sedikit demi sedikit setiap hari. 😊",
			"MashaAllah, a beautiful dream. To get there, study little by little every day. 😊"
		),
		L(
			"Belajar bisa dari buku, guru, dan pengalaman. Jangan lupa membaca dan bertanya.",
			"We can learn from books, teachers, and experience. Don't forget to read and ask questions.",
			"PakRudi",
			"Perpustakaan kota kita bagus untuk belajar, Ustadz.",
			"Our city's library is a great place to study, Ustadz."
		),
		L(
			"Kurangi bermain berlebihan dan atur waktu. Belajar dan istirahat harus seimbang.",
			"Don't overdo playing, and manage your time. Study and rest should be balanced."
		),
		L(
			"Semoga kita diberi kemudahan dalam belajar. Aamiin.",
			"May we be given ease in learning. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Meminta Maaf dan Memaafkan", "Saying Sorry and Forgiving", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar meminta maaf dan memaafkan.",
			"Assalamu'alaikum. Today we learn about saying sorry and forgiving."
		),
		L(
			"Semua orang pernah berbuat salah. Orang yang baik berani mengucap 'maaf' dengan tulus.",
			"Everyone makes mistakes. A good person dares to say 'sorry' sincerely.",
			"Dimas",
			"Kemarin aku sudah minta maaf ke temanku.",
			"Yesterday I said sorry to my friend."
		),
		L(
			"Alhamdulillah, itu perbuatan yang berani dan mulia. Lalu bagaimana perasaanmu?",
			"Alhamdulillah, that was brave and noble. How did it make you feel?"
		),
		L(
			"Memaafkan juga tidak mudah, tetapi hati yang memaafkan akan terasa lapang dan ringan.",
			"Forgiving is not easy either, but a forgiving heart feels wide and light.",
			"PakAndi",
			"Memang lega rasanya kalau tidak menyimpan marah.",
			"It really feels like a relief when we don't hold on to anger."
		),
		L(
			"Jangan menunggu orang lain minta maaf lebih dulu. Siapa yang memulai berdamai, ia lebih mulia.",
			"Don't wait for the other person to apologize first. Whoever starts making peace is the nobler one."
		),
		L(
			"Semoga hati kita bersih dari dendam. Aamiin.",
			"May our hearts be free of grudges. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Tolong-Menolong", "Helping One Another", {
		L(
			"Assalamu'alaikum. Hari ini kita bicara tentang tolong-menolong.",
			"Assalamu'alaikum. Today we talk about helping one another."
		),
		L(
			"Manusia tidak bisa hidup sendiri. Kita saling membutuhkan, dan karena itu kita perlu saling menolong.",
			"People cannot live alone. We need each other, so we should help each other.",
			"PakBudi",
			"Kemarin saya dibantu tetangga memperbaiki atap.",
			"Yesterday a neighbor helped me fix my roof."
		),
		L(
			"Alhamdulillah. Tolong-menolong membuat pekerjaan berat jadi ringan.",
			"Alhamdulillah. Helping each other makes heavy work light."
		),
		L(
			"Menolong tidak harus dengan uang. Membantu membawa barang, menyeberangkan orang tua, atau menunjukkan jalan sudah sangat baik.",
			"Helping doesn't have to involve money. Carrying things, helping an elder cross the road, or showing directions is already very good.",
			"KakNurul",
			"Aku pernah membantu nenek membawa belanjaan.",
			"I once helped a grandmother carry her groceries."
		),
		L(
			"Menolong dengan ikhlas membuat hati bahagia dan membuat orang lain tidak merasa sendirian.",
			"Helping sincerely makes our hearts happy and keeps others from feeling alone."
		),
		L(
			"Semoga kita selalu ringan tangan menolong sesama. Aamiin.",
			"May we always be quick to help one another. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menepati Janji", "Keeping Promises", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar menepati janji.",
			"Assalamu'alaikum. Today we learn about keeping promises."
		),
		L(
			"Janji adalah tanggung jawab. Kalau berkata akan datang jam lima, usahakan datang jam lima.",
			"A promise is a responsibility. If you say you'll come at five, try to be there at five.",
			"Dimas",
			"Aku berjanji membantu ibu menyapu setiap sore!",
			"I promised to help Mom sweep every afternoon!"
		),
		L(
			"Bagus sekali, Nak. Teruskan, dan ibumu akan semakin percaya padamu. 😊",
			"Very good, dear. Keep it up and your mother will trust you even more. 😊"
		),
		L(
			"Kalau ada halangan, kabari dengan sopan dan minta maaf. Jangan membiarkan orang menunggu tanpa kabar.",
			"If something comes up, let them know politely and apologize. Don't leave people waiting without news.",
			"PakJoko",
			"Orang yang menepati janji mudah dipercaya, ya, Ustadz.",
			"People who keep promises are easy to trust, right, Ustadz?"
		),
		L(
			"Berhati-hatilah berjanji. Janjilah hanya yang sanggup kita lakukan.",
			"Be careful when promising. Only promise what we are able to do."
		),
		L(
			"Semoga kita menjadi orang yang dapat dipercaya. Aamiin.",
			"May we become people who can be trusted. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Berkata yang Baik", "Speaking Kindly", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar berkata yang baik.",
			"Assalamu'alaikum. Today we learn about speaking kindly."
		),
		L(
			"Kata-kata bisa menyenangkan hati, tetapi juga bisa melukai. Karena itu pilihlah kata dengan hati-hati.",
			"Words can please the heart, but they can also hurt. So choose them carefully.",
			"KakNurul",
			"Aku sedih kalau diejek, Ustadz.",
			"I feel sad when I'm teased, Ustadz."
		),
		L(
			"Terima kasih sudah jujur, Nak. Karena itu kita tidak boleh mengejek teman. Rasanya sakit.",
			"Thank you for being honest, dear. That's why we must never tease friends. It hurts."
		),
		L(
			"Ucapan seperti 'tolong', 'terima kasih', dan 'maaf' itu kecil, tetapi sangat indah didengar.",
			"Words like 'please', 'thank you', and 'sorry' are small but lovely to hear.",
			"PakDedi",
			"Dan salam juga, Ustadz. Menyapa itu menyenangkan.",
			"And greetings too, Ustadz. Greeting someone feels nice."
		),
		L(
			"Kalau sedang marah, diam sebentar lebih baik daripada mengucapkan kata yang akan disesali.",
			"When we're angry, staying quiet for a moment is better than saying words we'll regret."
		),
		L(
			"Semoga lisan kita selalu mengucap yang baik. Aamiin.",
			"May our tongues always speak what is good. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Berterima Kasih", "Saying Thank You", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar berterima kasih.",
			"Assalamu'alaikum. Today we learn about saying thank you."
		),
		L(
			"Setiap kali ada yang membantu, ucapkan terima kasih. Kata sederhana itu membuat orang merasa dihargai.",
			"Whenever someone helps us, say thank you. That simple phrase makes people feel appreciated.",
			"Dimas",
			"Aku bilang terima kasih ke penjual es krim!",
			"I said thank you to the ice cream seller!"
		),
		L(
			"Bagus! Penjual itu pasti senang. Hal kecil seperti itu membuat dunia lebih ramah. 😊",
			"Great! The seller must have been happy. Little things like that make the world friendlier. 😊"
		),
		L(
			"Berterima kasih juga kepada orang tua, guru, dan petugas kebersihan yang bekerja untuk kita.",
			"Thank our parents, teachers, and the cleaners who work for us, too.",
			"BuSiti",
			"Betul, Ustadz. Kita jarang mengucapkannya.",
			"That's right, Ustadz. We rarely say it."
		),
		L(
			"Dan yang terpenting, bersyukur kepada Allah yang memberi kita nikmat setiap hari.",
			"And most importantly, be grateful to Allah, who gives us blessings every day."
		),
		L(
			"Semoga kita menjadi orang yang pandai berterima kasih. Aamiin.",
			"May we be people who know how to say thank you. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Hemat dan Tidak Boros", "Being Thrifty", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar hidup hemat.",
			"Assalamu'alaikum. Today we learn about living thriftily."
		),
		L(
			"Hemat artinya memakai secukupnya, bukan pelit. Kita membeli yang dibutuhkan dan tidak menghambur-hamburkan.",
			"Being thrifty means using what we need, not being stingy. We buy what we need and don't waste.",
			"Dimas",
			"Aku menabung di celengan, Ustadz!",
			"I save in my piggy bank, Ustadz!"
		),
		L(
			"MasyaAllah, kebiasaan yang bagus. Menabung melatih kita bersabar dan merencanakan sesuatu.",
			"MashaAllah, a good habit. Saving teaches us patience and planning."
		),
		L(
			"Makanan, air, dan listrik juga jangan dibuang percuma. Ambil secukupnya, habiskan.",
			"Don't waste food, water, or electricity either. Take just enough and finish it.",
			"PakAndi",
			"Nasi yang tersisa sebaiknya dihabiskan.",
			"Leftover rice should be finished."
		),
		L(
			"Sisihkan sedikit uang jajan untuk berbagi dengan yang membutuhkan.",
			"Set aside a bit of pocket money to share with those in need."
		),
		L(
			"Semoga Allah mencukupkan rezeki kita. Aamiin.",
			"May Allah provide for our needs. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Disiplin Waktu", "Using Time Wisely", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar menghargai waktu.",
			"Assalamu'alaikum. Today we learn to value our time."
		),
		L(
			"Waktu seperti air yang mengalir. Yang sudah lewat tidak bisa diulang, jadi pakailah untuk hal baik.",
			"Time is like flowing water. What has passed cannot be repeated, so use it for good things.",
			"PakRudi",
			"Betul. Kalau tidur kesiangan, banyak yang terlewat.",
			"True. If we oversleep, we miss so much."
		),
		L(
			"Karena itu, tidurlah tepat waktu supaya bangun segar untuk sholat Subuh dan berangkat sekolah.",
			"So sleep on time so you wake up fresh for the Fajr prayer and school."
		),
		L(
			"Buat jadwal sederhana: waktu belajar, bermain, membantu orang tua, dan beristirahat.",
			"Make a simple schedule: time for study, play, helping parents, and rest.",
			"KakNurul",
			"Aku punya jadwal di dinding kamar!",
			"I have a schedule on my bedroom wall!"
		),
		L(
			"Tepat waktu juga tanda menghargai orang lain, karena kita tidak membuat mereka menunggu.",
			"Being on time also shows respect for others, because we don't keep them waiting."
		),
		L(
			"Semoga waktu kita penuh kebaikan dan manfaat. Aamiin.",
			"May our time be full of goodness and benefit. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Rendah Hati", "Staying Humble", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar rendah hati.",
			"Assalamu'alaikum. Today we learn about being humble."
		),
		L(
			"Rendah hati artinya tidak sombong. Walaupun pintar atau punya banyak, kita tetap bersikap sopan.",
			"Being humble means not being proud. Even if we are smart or have a lot, we stay polite.",
			"PakHaji",
			"Padi yang berisi semakin merunduk, ya, Ustadz.",
			"The fuller the rice stalk, the lower it bows, right, Ustadz?"
		),
		L(
			"Benar sekali, Pak Haji. Semakin berilmu, semakin rendah hati.",
			"Exactly, Pak Haji. The more knowledge we have, the more humble we become."
		),
		L(
			"Kalau menang lomba, bersyukurlah dan jangan meremehkan yang kalah. Kalau kalah, belajar dan coba lagi.",
			"If you win a contest, be thankful and don't look down on the loser. If you lose, learn and try again.",
			"Dimas",
			"Aku kalah lomba lari, tapi senang sekali bisa ikut!",
			"I lost the race, but I'm so happy I joined!"
		),
		L(
			"Orang yang rendah hati disayangi banyak teman karena enak diajak berbicara.",
			"Humble people are loved by many friends because they are pleasant to talk with."
		),
		L(
			"Semoga Allah menjauhkan kita dari sifat sombong. Aamiin.",
			"May Allah keep us away from arrogance. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menghargai Perbedaan", "Respecting Differences", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar menghargai perbedaan.",
			"Assalamu'alaikum. Today we learn about respecting differences."
		),
		L(
			"Negeri kita punya banyak suku, bahasa, dan kebiasaan. Perbedaan itu seperti warna-warna pada pelangi.",
			"Our country has many tribes, languages, and customs. Differences are like the colors of a rainbow.",
			"KakNurul",
			"Temanku berasal dari daerah lain, dan dia baik sekali.",
			"My friend comes from another region, and she is so kind."
		),
		L(
			"Alhamdulillah. Bertemanlah dengan siapa saja, tanpa memandang asal atau penampilan.",
			"Alhamdulillah. Befriend anyone, regardless of origin or appearance."
		),
		L(
			"Kalau ada yang berbeda pendapat, dengarkan dulu dengan tenang. Berbeda tidak harus bertengkar.",
			"If someone has a different opinion, listen calmly first. Disagreeing does not have to mean quarreling.",
			"PakDedi",
			"Dengan saling menghargai, hidup jadi rukun.",
			"By respecting each other, life becomes harmonious."
		),
		L(
			"Kita bisa belajar banyak hal baru dari orang yang berbeda dari kita.",
			"We can learn many new things from people who are different from us."
		),
		L(
			"Semoga kita hidup rukun dengan siapa pun. Aamiin.",
			"May we live in harmony with everyone. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Berani Mengakui Kesalahan", "Admitting Mistakes", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar berani mengakui kesalahan.",
			"Assalamu'alaikum. Today we learn to admit our mistakes."
		),
		L(
			"Kalau tidak sengaja memecahkan gelas atau salah bicara, jujurlah dan akui. Itu tanda pemberani.",
			"If you accidentally break a glass or say the wrong thing, be honest and admit it. That is a sign of courage.",
			"Dimas",
			"Aku pernah memecahkan vas, lalu aku bilang ke ibu.",
			"I once broke a vase, and then I told Mom."
		),
		L(
			"Bagus sekali, Nak. Pasti ibu menghargai kejujuranmu. 😊",
			"Very good, dear. Your mother surely appreciated your honesty. 😊"
		),
		L(
			"Menutupi kesalahan hanya membuat hati tidak tenang. Mengakuinya membuat hati lega dan masalah lebih mudah selesai.",
			"Covering up a mistake only unsettles the heart. Admitting it brings relief and makes the problem easier to solve.",
			"PakJoko",
			"Benar. Kalau sudah mengaku, beban terasa hilang.",
			"True. Once we confess, the burden feels gone."
		),
		L(
			"Setelah mengaku, perbaiki kesalahan itu dan berusahalah tidak mengulanginya.",
			"After admitting it, fix the mistake and try not to repeat it."
		),
		L(
			"Semoga kita berani jujur dan mau memperbaiki diri. Aamiin.",
			"May we be brave in honesty and willing to improve ourselves. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Menjaga Kesehatan", "Taking Care of Our Health", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar menjaga kesehatan.",
			"Assalamu'alaikum. Today we learn about taking care of our health."
		),
		L(
			"Badan yang sehat adalah nikmat dari Allah. Dengan badan sehat kita bisa belajar, bermain, dan beribadah dengan nyaman.",
			"A healthy body is a blessing from Allah. With a healthy body we can study, play, and worship comfortably.",
			"PakAndi",
			"Saya rutin jalan pagi supaya badan segar.",
			"I take a morning walk regularly to stay fresh."
		),
		L(
			"Bagus, Pak. Berolahraga ringan setiap hari sangat baik untuk badan.",
			"Good, sir. Light exercise every day is very good for the body."
		),
		L(
			"Makanlah makanan bergizi seperti sayur, buah, dan nasi, serta minum air putih yang cukup.",
			"Eat nutritious food like vegetables, fruit, and rice, and drink enough water.",
			"KakNurul",
			"Aku suka makan buah, Ustadz!",
			"I like eating fruit, Ustadz!"
		),
		L(
			"Istirahat yang cukup juga penting. Jangan begadang terlalu sering.",
			"Getting enough rest is important too. Don't stay up late too often."
		),
		L(
			"Semoga kita selalu diberi kesehatan. Aamiin.",
			"May we always be blessed with good health. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Tertib di Jalan", "Being Orderly on the Road", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar tertib di jalan.",
			"Assalamu'alaikum. Today we learn about being orderly on the road."
		),
		L(
			"Di jalan, kita berbagi tempat dengan banyak orang. Karena itu patuhi aturan supaya semua selamat.",
			"On the road, we share space with many people. So follow the rules so everyone stays safe.",
			"PakDedi",
			"Kalau naik motor, saya selalu memakai helm.",
			"When I ride a motorbike, I always wear a helmet."
		),
		L(
			"Bagus, Pak. Pakai helm, jangan ngebut, dan berhenti saat lampu merah.",
			"Good, sir. Wear a helmet, don't speed, and stop at red lights."
		),
		L(
			"Menyeberanglah di tempat yang aman, lihat kanan dan kiri, dan jangan sambil bermain ponsel.",
			"Cross at safe places, look left and right, and don't use your phone while crossing.",
			"Dimas",
			"Aku menyeberang di zebra cross, Ustadz.",
			"I cross at the zebra crossing, Ustadz."
		),
		L(
			"Memberi jalan kepada orang lain adalah akhlak yang baik. Tertib itu menyelamatkan.",
			"Giving way to others is good character. Orderliness saves lives."
		),
		L(
			"Semoga kita selalu selamat di perjalanan. Aamiin.",
			"May we always be safe on our journeys. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
	topic("Peduli pada yang Sakit", "Caring for the Sick", {
		L(
			"Assalamu'alaikum. Hari ini kita belajar peduli pada orang yang sakit.",
			"Assalamu'alaikum. Today we learn about caring for people who are sick."
		),
		L(
			"Orang yang sakit membutuhkan semangat. Menjenguk dan mendoakan mereka sangat berarti.",
			"People who are ill need encouragement. Visiting and praying for them means a lot.",
			"BuAisyah",
			"Waktu aku sakit, kunjungan teman-teman membuatku senang.",
			"When I was sick, my friends' visits made me happy."
		),
		L(
			"Alhamdulillah. Saat menjenguk, bicaralah dengan lembut dan jangan membuat mereka lelah.",
			"Alhamdulillah. When visiting, speak gently and don't tire them out."
		),
		L(
			"Kita juga bisa membantu keluarganya, misalnya mengantar makanan atau menjaga adik-adiknya.",
			"We can also help their family, for example by bringing food or looking after the younger children.",
			"PakBudi",
			"Rumah sakit kota kita membantu banyak orang sembuh.",
			"Our city's hospital helps many people recover."
		),
		L(
			"Jangan lupa, kalau kita sehat, bersyukurlah dan jaga diri agar tidak mudah sakit.",
			"And remember, when we are healthy, be thankful and take care of ourselves so we don't fall ill easily."
		),
		L(
			"Semoga yang sakit segera diberi kesembuhan. Aamiin.",
			"May those who are sick soon be healed. Aamiin.",
			"Semua",
			AMIN,
			AMIN_EN
		),
	}),
}

return MasjidTausiah
