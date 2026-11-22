--[[
	ROBLOCK CITY: batu mesh (jalankan setelah StyleWorld, karena StyleWorld "scenery" membuat ulang batu kotak).

	Mengganti batu kotak di Workspace.Map.Scenery dengan batu low-poly buatan sendiri (Blender,
	assets/blender/batu.fbx; templat ServerStorage.AsetRumah.batu berisi MeshPart Batu1..Batu3).
	Ukuran, posisi, dan warna mengikuti batu lama. Tetap tanpa tabrakan dan tanpa bayangan.

	Pakai: require(game.ServerStorage.MapBuilders.StyleRocks)()   -- aman diulang
]]

local ServerStorage = game:GetService("ServerStorage")

return function(): number
	local folder = ServerStorage:FindFirstChild("AsetRumah")
	local template = folder and folder:FindFirstChild("batu")
	local map = workspace:FindFirstChild("Map")
	local scenery = map and map:FindFirstChild("Scenery")
	local sources: { MeshPart } = {}
	if template then
		for _, d in template:GetChildren() do
			if d:IsA("MeshPart") then
				table.insert(sources, d)
			end
		end
	end
	if #sources == 0 or not scenery then
		warn("[StyleRocks] templat batu atau Map.Scenery tidak ditemukan; dilewati")
		return 0
	end
	table.sort(sources, function(a, b)
		return a.Name < b.Name
	end)
	local rng = Random.new(404)
	local count = 0
	for _, old in scenery:GetDescendants() do
		if old:IsA("Part") and old.Name == "Batu" then
			local rock = sources[rng:NextInteger(1, #sources)]:Clone()
			rock.Name = "Batu"
			rock.Size = old.Size * Vector3.new(1.35, 1.15, 1.35)
			rock.CFrame = old.CFrame
			rock.Color = old.Color
			rock.Material = Enum.Material.Slate
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanTouch = false
			rock.CanQuery = false
			rock.CastShadow = false
			rock.Parent = old.Parent
			old:Destroy()
			count += 1
			if count % 100 == 0 then
				task.wait()
			end
		end
	end
	return count
end
