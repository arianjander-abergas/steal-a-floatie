--[[
	MapBuilder (ModuleScript in ServerScriptService.Server)
	Builds the whole map from code when the server starts:
	  • the Pump Line (conveyor down the middle where Floaties are sold)
	  • 8 player bases (4 per side), each with 20 pedestals, a lock button, a spawn
	  • the Dart Blaster tool (put into StarterPack)

	Want a prettier map later? Build it by hand in Studio and keep the same
	names/attributes — or keep this and just add decorations around it.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local StarterPack = game:GetService("StarterPack")

local MapBuilder = {}

local V = Vector3.new
MapBuilder.BASE_SIZE = 48
MapBuilder.LINE_LENGTH = 290

local BASE_COLORS = {
	Color3.fromRGB(255, 140, 170), Color3.fromRGB(140, 200, 255), Color3.fromRGB(170, 235, 140), Color3.fromRGB(255, 205, 110),
	Color3.fromRGB(200, 160, 255), Color3.fromRGB(120, 230, 215), Color3.fromRGB(255, 160, 120), Color3.fromRGB(235, 235, 150),
}

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function billboard(adornee, text, size, maxDistance, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.1
	t.Text = text
	t.Parent = gui
	return t
end

local function prompt(parent, name, action, key, hold)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name
	pr.ActionText = action
	pr.KeyboardKeyCode = key
	pr.HoldDuration = hold
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Enabled = true -- the client hides prompts that aren't for you; the server re-checks everything
	pr.Parent = parent
	return pr
end

local function buildTool()
	local tool = Instance.new("Tool")
	tool.Name = "Dart Blaster"
	tool.ToolTip = "Pop Floaties that are being stolen!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = part({
		Name = "Handle", Anchored = false, CanCollide = false, Massless = true,
		Size = V(0.6, 0.8, 2.2), Color = Color3.fromRGB(255, 90, 170), Material = Enum.Material.SmoothPlastic,
	})
	local tip = part({
		Name = "Tip", Anchored = false, CanCollide = false, Massless = true,
		Size = V(0.5, 0.5, 0.5), Color = Color3.fromRGB(255, 240, 90), Material = Enum.Material.Neon,
		CFrame = handle.CFrame * CFrame.new(0, 0, -1.2),
	})
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = tip
	w.Parent = tip
	tip.Parent = tool
	handle.Parent = tool
	tool.Parent = StarterPack
end

-- Decoration only (trees, clouds, balloon bunches). Safe to delete or move anything
-- made here — no script depends on it. Uses a fixed seed so the map looks the same every time.
function MapBuilder.Decorate(map, bases)
	local deco = Instance.new("Folder")
	deco.Name = "Decoration"
	deco.Parent = map
	local rng = Random.new(42)
	local BALLOON_COLORS = {
		Color3.fromRGB(255, 90, 150), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 220, 70),
		Color3.fromRGB(120, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 150, 70),
	}

	local function tree(pos)
		local h = rng:NextNumber(7, 12)
		part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = V(h, 1.6, 1.6),
			CFrame = CFrame.new(pos + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(130, 90, 60), Material = Enum.Material.Wood, Parent = deco })
		local green = Color3.fromRGB(70, 170, 80):Lerp(Color3.fromRGB(140, 210, 90), rng:NextNumber())
		for i = 1, 3 do
			local s = rng:NextNumber(5, 8)
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = V(s, s, s),
				Position = pos + V(rng:NextNumber(-1.5, 1.5), h + i * 1.2, rng:NextNumber(-1.5, 1.5)),
				Color = green, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = deco })
		end
	end

	local function balloonBunch(pos, count)
		part({ Name = "Post", Size = V(0.4, 4, 0.4), Position = pos + V(0, 2, 0), Color = Color3.fromRGB(240, 240, 240), Parent = deco })
		for i = 1, count do
			local off = V(rng:NextNumber(-1.2, 1.2), 7 + rng:NextNumber(0, 2.5), rng:NextNumber(-1.2, 1.2))
			part({ Name = "Balloon", Shape = Enum.PartType.Ball, Size = V(2.2, 2.2, 2.2), Position = pos + off,
				Color = BALLOON_COLORS[rng:NextInteger(1, #BALLOON_COLORS)], Reflectance = 0.15,
				CanCollide = false, CanQuery = false, Parent = deco })
			local a = V(0, 4, 0)
			local strand = part({ Name = "String", Size = V(0.08, (off - a).Magnitude, 0.08),
				CFrame = CFrame.lookAt(pos + (a + off) / 2, pos + off) * CFrame.Angles(math.pi / 2, 0, 0),
				Color = Color3.fromRGB(250, 250, 250), CanCollide = false, CanQuery = false, Parent = deco })
			local _ = strand
		end
	end

	local function cloud(pos)
		for _ = 1, rng:NextInteger(3, 5) do
			local s = rng:NextNumber(8, 16)
			part({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = V(s, s * 0.7, s),
				Position = pos + V(rng:NextNumber(-10, 10), rng:NextNumber(-2, 2), rng:NextNumber(-6, 6)),
				Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Transparency = 0.1,
				CanCollide = false, CanQuery = false, CastShadow = false, Parent = deco })
		end
	end

	-- trees outside the play area (bases sit between x = 40..88 and z = -129..129)
	for _ = 1, 45 do
		local x = rng:NextNumber(96, 205) * (if rng:NextNumber() < 0.5 then -1 else 1)
		tree(V(x, 0, rng:NextNumber(-205, 205)))
	end
	for _ = 1, 20 do
		local z = rng:NextNumber(165, 205) * (if rng:NextNumber() < 0.5 then -1 else 1)
		tree(V(rng:NextNumber(-90, 90), 0, z))
	end
	-- a few trees in the gaps between bases, away from the paths
	for _, z in ipairs({ -70, 0, 70 }) do
		tree(V(-92, 0, z))
		tree(V(92, 0, z))
	end

	-- balloon bunches at every base entrance and along the Pump Line
	for _, base in ipairs(bases) do
		for _, sz in ipairs({ 1, -1 }) do
			balloonBunch((base.cf * CFrame.new(23.5, 0, sz * 9)).Position, 3)
		end
	end
	for z = -120, 120, 40 do
		balloonBunch(V(-8, 0, z), 2)
		balloonBunch(V(8, 0, z), 2)
	end

	for _ = 1, 14 do
		cloud(V(rng:NextNumber(-200, 200), rng:NextNumber(70, 100), rng:NextNumber(-200, 200)))
	end
end

function MapBuilder.Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local carried = Instance.new("Folder")
	carried.Name = "Carried"
	carried.Parent = workspace

	part({ Name = "Ground", Size = V(440, 2, 440), Position = V(0, -1, 0), Color = Color3.fromRGB(110, 190, 95), Material = Enum.Material.Grass, Parent = map })

	-------------------------------------------------------------------
	-- Pump Line
	-------------------------------------------------------------------
	local L = MapBuilder.LINE_LENGTH
	local lineFolder = Instance.new("Folder")
	lineFolder.Name = "PumpLine"
	lineFolder.Parent = map
	part({ Name = "Conveyor", Size = V(10, 1, L), Position = V(0, 0.5, 0), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.SmoothPlastic, Parent = lineFolder })
	for _, x in ipairs({ -5.3, 5.3 }) do
		part({ Name = "Rail", Size = V(0.6, 1.6, L), Position = V(x, 0.8, 0), Color = Color3.fromRGB(255, 100, 190), Material = Enum.Material.Neon, Parent = lineFolder })
	end
	local tank = part({
		Name = "PumpStation", Shape = Enum.PartType.Cylinder, Size = V(10, 14, 14),
		CFrame = CFrame.new(0, 5, -L / 2 - 8) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 240, 255), Material = Enum.Material.SmoothPlastic, Parent = lineFolder,
	})
	local bigBalloon = part({
		Name = "BigBalloon", Shape = Enum.PartType.Ball, Size = V(12, 12, 12), Position = V(0, 17, -L / 2 - 8),
		Color = Color3.fromRGB(255, 90, 150), Reflectance = 0.15, Parent = lineFolder,
	})
	billboard(bigBalloon, "🎈 PUMP LINE\nBuy Floaties here!", UDim2.fromOffset(320, 110), 400)
	part({ Name = "PopBin", Size = V(12, 4, 6), Position = V(0, 2, L / 2 + 4), Color = Color3.fromRGB(90, 90, 110), Parent = lineFolder })
	local _ = tank

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = lineFolder

	local line = {
		folder = items,
		startPos = V(0, 1, -L / 2 + 3),
		endPos = V(0, 1, L / 2 - 3),
	}

	-------------------------------------------------------------------
	-- Bases
	-------------------------------------------------------------------
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = map

	local S = MapBuilder.BASE_SIZE
	local H = S / 2
	local bases = {}
	for i = 1, 8 do
		local side = if i <= 4 then -1 else 1
		local row = (i - 1) % 4
		local x, z = side * 64, -105 + row * 70
		local yaw = if side == -1 then 0 else math.pi
		-- cf = top-center of the floor; local +X points toward the Pump Line (the entrance)
		local cf = CFrame.new(x, 1, z) * CFrame.Angles(0, yaw, 0)
		local color = BASE_COLORS[i]

		local folder = Instance.new("Folder")
		folder.Name = "Base" .. i
		folder:SetAttribute("BaseIndex", i)
		folder:SetAttribute("OwnerUserId", 0)
		folder:SetAttribute("LockedUntil", 0)
		folder.Parent = basesFolder

		part({ Name = "Floor", Size = V(S, 1, S), CFrame = cf * CFrame.new(0, -0.5, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = folder })
		-- low curbs, with a 16-stud entrance facing the line
		part({ Name = "Curb", Size = V(1, 1.5, S), CFrame = cf * CFrame.new(-H + 0.5, 0.75, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
		for _, sz in ipairs({ 1, -1 }) do
			part({ Name = "Curb", Size = V(S, 1.5, 1), CFrame = cf * CFrame.new(0, 0.75, sz * (H - 0.5)), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
			part({ Name = "Curb", Size = V(1, 1.5, 16), CFrame = cf * CFrame.new(H - 0.5, 0.75, sz * 16), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
		end

		-- 20 pedestals: 4 rows x 5 columns. Slot 1 = back-left.
		local pedFolder = Instance.new("Folder")
		pedFolder.Name = "Pedestals"
		pedFolder.Parent = folder
		local pedestals = {}
		for r = 1, 4 do
			for c = 1, 5 do
				local slot = (r - 1) * 5 + c
				local ped = part({
					Name = "Pedestal" .. slot, Size = V(5, 1, 5),
					CFrame = cf * CFrame.new(-18 + (r - 1) * 9, 0.5, -18 + (c - 1) * 9),
					Color = color, Material = Enum.Material.SmoothPlastic, Parent = pedFolder,
				})
				ped:SetAttribute("BaseIndex", i)
				ped:SetAttribute("Slot", slot)
				ped:SetAttribute("HasFloatie", false)
				ped:SetAttribute("Unlocked", false)
				prompt(ped, "StealPrompt", "Steal", Enum.KeyCode.E, 2)
				prompt(ped, "SellPrompt", "Sell", Enum.KeyCode.F, 0.6)
				CollectionService:AddTag(ped, "Pedestal")
				pedestals[slot] = ped
			end
		end

		-- lock button
		local lockButton = part({
			Name = "LockButton", Size = V(3, 1, 3), CFrame = cf * CFrame.new(19, 0.5, -19),
			Color = Color3.fromRGB(255, 70, 70), Material = Enum.Material.Neon, Parent = folder,
		})
		local lockPrompt = prompt(lockButton, "LockPrompt", "Lock Base", Enum.KeyCode.E, 0)
		lockPrompt.ObjectText = "Shield for " .. 60 .. "s"
		CollectionService:AddTag(lockButton, "LockButton")
		lockButton:SetAttribute("BaseIndex", i)
		local lockStatus = billboard(lockButton, "LOCK READY", UDim2.fromOffset(160, 40), 60, Color3.fromRGB(255, 230, 230))
		lockStatus.Parent.StudsOffset = V(0, 3, 0)

		-- barrier (visible while locked)
		local barrier = part({
			Name = "Barrier", Size = V(S, 26, S), CFrame = cf * CFrame.new(0, 13, 0),
			Material = Enum.Material.ForceField, Color = color, Transparency = 1,
			CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder,
		})

		-- spawn
		local spawn = part({
			ClassName = "SpawnLocation", Name = "Spawn", Size = V(6, 1, 6), CFrame = cf * CFrame.new(18, 0, 0),
			Color = Color3.new(1, 1, 1), Transparency = 0.4, Neutral = true, Duration = 0, Parent = folder,
		})

		-- floating owner sign
		local signAnchor = part({
			Name = "Sign", Size = V(1, 1, 1), CFrame = cf * CFrame.new(-18, 22, 0), Transparency = 1,
			CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder,
		})
		local signLabel = billboard(signAnchor, "Empty Base", UDim2.fromOffset(340, 64), 350)

		local floatieFolder = Instance.new("Folder")
		floatieFolder.Name = "Floaties"
		floatieFolder.Parent = folder

		bases[i] = {
			index = i, folder = folder, cf = cf, size = V(S, 0, S), color = color,
			pedestals = pedestals, lockButton = lockButton, lockPrompt = lockPrompt, lockStatus = lockStatus,
			barrier = barrier, spawn = spawn, signLabel = signLabel, floatieFolder = floatieFolder,
		}
	end

	MapBuilder.Decorate(map, bases)
	buildTool()
	return { bases = bases, line = line, carried = carried }
end

return MapBuilder
