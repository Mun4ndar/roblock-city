--!strict
-- LocStrings.MasjidTausiah: terjemahan Inggris untuk semua topik di shared/MasjidTausiah (dibangun otomatis dari datanya).

local Data = require(script.Parent.Parent:WaitForChild("MasjidTausiah"))

local exact: { [string]: string } = {}
for _, topic in Data.TOPICS do
	exact[topic.title] = topic.titleEn
	for _, line in topic.lines do
		exact[line.text] = line.en
		if line.reply and line.replyEn then
			exact[line.reply] = line.replyEn
		end
	end
end

return { exact = exact, patterns = {} }
