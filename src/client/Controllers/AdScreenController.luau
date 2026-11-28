--!strict
-- AdScreenController: papan iklan digital (videotron) yang berganti slide, hanya tampilan di client.
-- Part bertag "AdScreen" punya SurfaceGui berisi Frame bernama Slide1..SlideN (Slide1 tampil
-- bawaan, jadi papan tetap benar walau controller ini tidak jalan). Atribut opsional:
--   SlideSeconds : lama tiap slide dalam detik (bawaan 6)
-- Slide dihitung dari jam bersama, jadi semua sisi papan dan semua pemain melihat slide yang sama.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AdScreenController = {}

local TAG = "AdScreen"
local DEFAULT_SECONDS = 6
local CHECK_INTERVAL = 0.5
local SLIDE_IN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function slidesOf(gui: SurfaceGui): { Frame }
	local slides: { Frame } = {}
	for _, child in gui:GetChildren() do
		if child:IsA("Frame") and string.match(child.Name, "^Slide%d+$") then
			table.insert(slides, child)
		end
	end
	table.sort(slides, function(a, b)
		return (tonumber(string.match(a.Name, "%d+")) or 0)
			< (tonumber(string.match(b.Name, "%d+")) or 0)
	end)
	return slides
end

local function show(gui: SurfaceGui, index: number)
	local slides = slidesOf(gui)
	if #slides < 2 then
		return
	end
	local target = slides[(index % #slides) + 1]
	if target.Visible then
		return
	end
	for _, slide in slides do
		slide.Visible = slide == target
	end
	target.Position = UDim2.fromScale(0.12, 0)
	TweenService:Create(target, SLIDE_IN, { Position = UDim2.fromScale(0, 0) }):Play()
end

function AdScreenController.start()
	while true do
		local now = Workspace:GetServerTimeNow()
		for _, part in CollectionService:GetTagged(TAG) do
			local seconds = part:GetAttribute("SlideSeconds")
			local period = if type(seconds) == "number" and seconds > 0
				then seconds
				else DEFAULT_SECONDS
			local index = math.floor(now / period)
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceGui") then
					show(child, index)
				end
			end
		end
		task.wait(CHECK_INTERVAL)
	end
end

return AdScreenController
