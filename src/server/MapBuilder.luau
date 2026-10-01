--[[
	MapBuilder (ModuleScript in ServerScriptService.Server)
	Builds the whole map from code when the server starts (sizes in Config.Map):
	  • a round plaza in the middle: the Tower (12 material bands, a giant
	    balloon on top), 8 striped stalls, two leaderboards, the server's best
	    Floatie, the event sign, lamps and benches
	  • 8 bases in a ring, all the same distance from the Tower. Each has 42
	    slot pads, its own glowing conveyor down the middle, a Pump Machine
	    spot at the back, an entrance arch with the owner's name, a best-Floatie
	    pedestal and a spawn pad
	  • paths, trees, balloon bunches, clouds and invisible edge walls

	Everything is plain parts with classic studs (no uploaded meshes).

	Build() returns
	  { bases = { base, ... }, teleports = { Plaza = CFrame, Sell = CFrame }, plaza = { ... } }
	base = { index, folder, cf, size, color, slots = { pad, ... }, spawn, signLabel,
	         archLabels, floatieFolder, pumpSpot, nozzle, bestSpot, bestLabel, lockLabels }
	Slot pads have +X pointing at the base entrance, so a Floatie standing on one faces out.
	The client finds a base's conveyor through its "ConveyorStart" / "ConveyorEnd" parts.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local V = Vector3.new
local M = Config.Map
local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(28, 22, 45)

---------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------
local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

-- part({ ..., Studs = "top" | "all" })  — classic plastic with studs where asked
local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	for _, face in ipairs(STUD_FACES) do
		p[face] = Enum.SurfaceType.Smooth
	end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "ClassName" and k ~= "Studs" then
			p[k] = v
		end
	end
	if props.Studs == "top" then
		p.TopSurface = Enum.SurfaceType.Studs
	elseif props.Studs == "all" then
		for _, face in ipairs(STUD_FACES) do
			p[face] = Enum.SurfaceType.Studs
		end
	end
	p.Parent = props.Parent
	return p
end

-- an upright cylinder whose bottom center is at `cf`
local function cylinder(parent, name, cf, height, diameter, color, material, studs)
	return part({
		Name = name, Shape = Enum.PartType.Cylinder, Size = V(height, diameter, diameter),
		CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color, Material = material or Enum.Material.Plastic, Studs = studs, Parent = parent,
	})
end

local function ball(parent, name, pos, diameter, color, props)
	local p = part({
		Name = name, Shape = Enum.PartType.Ball, Size = V(diameter, diameter, diameter), Position = pos,
		Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.15, Parent = parent,
	})
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- chunky white text with a dark outline, filling `gui`
local function bigText(gui, text, color, props)
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or WHITE
	t.Text = text
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = t
	t.Parent = gui
	return t
end

local function billboard(adornee, text, size, maxDistance, color, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.StudsOffsetWorldSpace = offset or Vector3.zero
	gui.Parent = adornee
	return bigText(gui, text, color)
end

-- a SurfaceGui sign on one face of `p` with a colored background
local function surfaceSign(p, face, text, background, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.MaxDistance = 800
	gui.Parent = p
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background or OUTLINE
	frame.BackgroundTransparency = if background then 0 else 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = frame
	return bigText(frame, text, textColor)
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------------
-- Decoration pieces
---------------------------------------------------------------------
local BALLOON_COLORS = {
	Color3.fromRGB(255, 90, 150), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(120, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 150, 70),
}

local function tree(parent, rng, pos)
	local h = rng:NextNumber(8, 13)
	part({ Name = "Trunk", Size = V(2, h, 2), Position = pos + V(0, h / 2, 0), Color = Color3.fromRGB(125, 85, 55), Studs = "all", Parent = parent })
	local green = Color3.fromRGB(60, 160, 75):Lerp(Color3.fromRGB(130, 205, 85), rng:NextNumber())
	-- blocky LEGO-style leaves: three stacked layers
	for i, s in ipairs({ 9, 7, 4.5 }) do
		part({
			Name = "Leaves", Size = V(s, 3, s), Position = pos + V(0, h + i * 2.6 - 1, 0),
			Color = green, Studs = "all", CanCollide = false, Parent = parent,
		})
	end
end

local function balloonBunch(parent, rng, pos, count)
	part({ Name = "Post", Size = V(0.5, 4, 0.5), Position = pos + V(0, 2, 0), Color = WHITE, Studs = "top", Parent = parent })
	for _ = 1, count do
		local off = V(rng:NextNumber(-1.4, 1.4), 7.5 + rng:NextNumber(0, 2.5), rng:NextNumber(-1.4, 1.4))
		ball(parent, "Balloon", pos + off, 2.4, BALLOON_COLORS[rng:NextInteger(1, #BALLOON_COLORS)], { CanCollide = false, CanQuery = false })
		local a = V(0, 4, 0)
		part({
			Name = "String", Size = V(0.08, (off - a).Magnitude, 0.08),
			CFrame = CFrame.lookAt(pos + (a + off) / 2, pos + off) * CFrame.Angles(math.pi / 2, 0, 0),
			Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = parent,
		})
	end
end

local function cloud(parent, rng, pos)
	for _ = 1, rng:NextInteger(3, 5) do
		local s = rng:NextNumber(10, 18)
		part({
			Name = "Cloud", Shape = Enum.PartType.Ball, Size = V(s, s * 0.7, s),
			Position = pos + V(rng:NextNumber(-12, 12), rng:NextNumber(-2, 2), rng:NextNumber(-7, 7)),
			Color = WHITE, Material = Enum.Material.SmoothPlastic, Transparency = 0.1,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = parent,
		})
	end
end

-- a lamp post with a glowing balloon on top
local function lamp(parent, cf, color)
	part({ Name = "LampBase", Size = V(2, 1, 2), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(70, 70, 90), Studs = "top", Parent = parent })
	part({ Name = "LampPost", Size = V(0.7, 11, 0.7), CFrame = cf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(70, 70, 90), Parent = parent })
	local glow = ball(parent, "LampBalloon", (cf * CFrame.new(0, 13, 0)).Position, 3.2, color, { Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = glow
end

local function bench(parent, cf)
	local wood = Color3.fromRGB(165, 110, 60)
	part({ Name = "BenchSeat", Size = V(7, 0.6, 2.2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = wood, Studs = "top", Parent = parent })
	part({ Name = "BenchBack", Size = V(7, 2, 0.5), CFrame = cf * CFrame.new(0, 2.9, 0.9), Color = wood, Parent = parent })
	for _, x in ipairs({ -3, 3 }) do
		part({ Name = "BenchLeg", Size = V(0.6, 1.3, 2), CFrame = cf * CFrame.new(x, 0.65, 0), Color = Color3.fromRGB(70, 70, 90), Parent = parent })
	end
end

---------------------------------------------------------------------
-- One base
---------------------------------------------------------------------
local function buildBase(parent, i, rng)
	local a = (i - 1) * math.pi * 2 / Config.MaxPlayers
	local center = V(math.sin(a) * M.BaseRadius, 1, math.cos(a) * M.BaseRadius)
	-- cf = top-center of the floor; -Z (LookVector) points at the plaza = the entrance
	local cf = CFrame.lookAt(center, V(0, 1, 0))
	local color = M.BaseColors[i] or M.BaseColors[1]
	local W, D = M.BaseWidth, M.BaseDepth
	local hw, hd = W / 2, D / 2

	local f = folder("Base" .. i, parent)
	f:SetAttribute("BaseIndex", i)
	f:SetAttribute("OwnerUserId", 0)

	-- floor + low white walls, with the entrance gap at the front
	part({ Name = "Floor", Size = V(W, 1, D), CFrame = cf * CFrame.new(0, -0.5, 0), Color = color:Lerp(WHITE, 0.45), Studs = "top", Parent = f })
	local wallColor = Color3.fromRGB(245, 245, 250)
	local function wall(size, offset)
		part({ Name = "Wall", Size = size, CFrame = cf * CFrame.new(offset), Color = wallColor, Studs = "all", Parent = f })
		part({ Name = "WallCap", Size = V(size.X + 0.2, 0.6, size.Z + 0.2), CFrame = cf * CFrame.new(offset + V(0, size.Y / 2 + 0.3, 0)), Color = color, Studs = "top", Parent = f })
	end
	wall(V(W, 3, 1.6), V(0, 1.5, hd - 0.8))                    -- back
	wall(V(1.6, 3, D), V(-hw + 0.8, 1.5, 0))                   -- left
	wall(V(1.6, 3, D), V(hw - 0.8, 1.5, 0))                    -- right
	local gap = 22
	local seg = (W - gap) / 2
	wall(V(seg, 3, 1.6), V(-(gap / 2 + seg / 2), 1.5, -hd + 0.8)) -- front left
	wall(V(seg, 3, 1.6), V(gap / 2 + seg / 2, 1.5, -hd + 0.8))    -- front right

	-- entrance arch with the owner's name on both sides
	for _, x in ipairs({ -gap / 2 - 1, gap / 2 + 1 }) do
		part({ Name = "ArchPillar", Size = V(2.6, 15, 2.6), CFrame = cf * CFrame.new(x, 7.5, -hd + 0.8), Color = color, Studs = "all", Parent = f })
		ball(f, "ArchBalloon", (cf * CFrame.new(x, 19.5, -hd + 0.8)).Position, 3, BALLOON_COLORS[(i + (if x < 0 then 0 else 2)) % #BALLOON_COLORS + 1], { CanCollide = false })
	end
	local beam = part({ Name = "ArchSign", Size = V(gap + 5.2, 4, 2.6), CFrame = cf * CFrame.new(0, 16.5, -hd + 0.8), Color = wallColor, Studs = "top", Parent = f })
	local archLabels = {
		surfaceSign(beam, Enum.NormalId.Front, "Empty Base", color:Lerp(OUTLINE, 0.25)),
		surfaceSign(beam, Enum.NormalId.Back, "Empty Base", color:Lerp(OUTLINE, 0.25)),
	}

	-- the conveyor down the middle: dark belt, white rails, glowing chevrons
	local cw = M.ConveyorWidth
	local z0, z1 = M.ConveyorStartZ, M.ConveyorEndZ
	local len = z0 - z1
	local conv = folder("Conveyor", f)
	part({ Name = "Belt", Size = V(cw, 0.6, len), CFrame = cf * CFrame.new(0, 0.3, (z0 + z1) / 2), Color = Color3.fromRGB(32, 38, 70), Material = Enum.Material.SmoothPlastic, Parent = conv })
	for _, x in ipairs({ -cw / 2 - 0.4, cw / 2 + 0.4 }) do
		part({ Name = "Rail", Size = V(0.8, 1.4, len), CFrame = cf * CFrame.new(x, 0.7, (z0 + z1) / 2), Color = wallColor, Studs = "top", Parent = conv })
	end
	local step = 0
	for z = z0 - 2, z1 + 2, -4 do
		step += 1
		local tip = V(0, 0.66, z - 1)
		for _, side in ipairs({ -1, 1 }) do
			local back = V(side * (cw / 2 - 1.3), 0.66, z + 0.7)
			local mid = (tip + back) / 2
			local arm = part({
				Name = "Chevron", Size = V(0.45, 0.12, (tip - back).Magnitude + 0.3),
				CFrame = cf * CFrame.lookAt(mid, tip), Color = Color3.fromRGB(120, 210, 255),
				Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = conv,
			})
			arm:SetAttribute("Step", step)
			CollectionService:AddTag(arm, "Chevron")
		end
	end
	-- invisible markers the client uses to animate Floaties riding the belt
	part({ Name = "ConveyorStart", Size = V(1, 1, 1), CFrame = cf * CFrame.new(0, 0.6, z0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = f })
	part({ Name = "ConveyorEnd", Size = V(1, 1, 1), CFrame = cf * CFrame.new(0, 0.6, z1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = f })

	-- slot pads: front row first; in each row inner, middle, outer, left before right
	local slotFolder = folder("Slots", f)
	local slots, lockLabels = {}, {}
	local S = M.SlotSize
	for r, z in ipairs(M.SlotRowsZ) do
		for c, x in ipairs(M.SlotColumnsX) do
			for side = 1, 2 do
				local sx = if side == 1 then -x else x
				local slot = (r - 1) * 6 + (c - 1) * 2 + side
				part({ Name = "SlotFrame" .. slot, Size = V(S, 0.8, S), CFrame = cf * CFrame.new(sx, 0.4, z), Color = wallColor, Studs = "top", Parent = slotFolder })
				local pad = part({
					Name = "Slot" .. slot, Size = V(S - 1.6, 0.3, S - 1.6),
					CFrame = cf * CFrame.new(sx, 0.95, z) * CFrame.Angles(0, math.pi / 2, 0),
					Color = color, Studs = "top", Parent = slotFolder,
				})
				pad:SetAttribute("BaseIndex", i)
				pad:SetAttribute("Slot", slot)
				pad:SetAttribute("Unlocked", false)
				local lockGui = Instance.new("SurfaceGui")
				lockGui.Name = "Lock"
				lockGui.Face = Enum.NormalId.Top
				lockGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				lockGui.PixelsPerStud = 20
				lockGui.LightInfluence = 0
				lockGui.Parent = pad
				lockLabels[slot] = bigText(lockGui, "🔒", WHITE, { Rotation = 0 })
				slots[slot] = pad
			end
		end
	end

	-- the Pump Machine stands on this platform at the back; balloons inflate at the nozzle
	cylinder(f, "PumpPlatform", cf * CFrame.new(0, 0, 54), 1.2, 14, Color3.fromRGB(60, 60, 80), nil, "top")
	local pumpSpot = cf * CFrame.new(0, 1.2, 54)
	local nozzle = cf * CFrame.new(0, 7, z0 - 1)
	part({ Name = "Nozzle", Size = V(1, 1, 1), CFrame = nozzle, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = f })
	local pumpFolder = folder("Pump", f)

	-- owner sign floating above the pump
	local signAnchor = part({
		Name = "OwnerSign", Size = V(1, 1, 1), CFrame = cf * CFrame.new(0, 28, 54), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false, Parent = f,
	})
	local signLabel = billboard(signAnchor, "Empty Base", UDim2.fromScale(40, 6.5), 600)

	-- best Floatie pedestal, just inside the entrance on the left
	local bestBase = cf * CFrame.new(-22, 0, -hd + 7)
	cylinder(f, "BestPedestal", bestBase, 2.4, 8, Color3.fromRGB(255, 205, 80), nil, "top")
	cylinder(f, "BestPedestalRim", bestBase * CFrame.new(0, 2.4, 0), 0.4, 8.8, wallColor)
	local bestSpot = bestBase * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local bestAnchor = part({
		Name = "BestSign", Size = V(1, 1, 1), CFrame = bestBase * CFrame.new(0, 12, 0), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false, Parent = f,
	})
	local bestLabel = billboard(bestAnchor, "⭐ BEST FLOATIE", UDim2.fromScale(18, 3.2), 200, Color3.fromRGB(255, 225, 120))

	-- the spawn pad, in front of the conveyor end (players face into the base)
	local spawnCf = cf * CFrame.new(0, 0, -hd + 6) * CFrame.Angles(0, math.pi, 0)
	local spawn = part({ Name = "Spawn", Size = V(8, 0.4, 8), CFrame = spawnCf * CFrame.new(0, 0.2, 0), Color = WHITE, Transparency = 0.2, Studs = "top", Parent = f })

	-- a few balloon bunches in the back corners
	for _, x in ipairs({ -hw + 5, hw - 5 }) do
		balloonBunch(f, rng, (cf * CFrame.new(x, 0, hd - 5)).Position, 4)
	end

	local floatieFolder = folder("Floaties", f)

	return {
		index = i, folder = f, cf = cf, size = V(W, 0, D), color = color,
		slots = slots, lockLabels = lockLabels, spawn = spawn, signLabel = signLabel, archLabels = archLabels,
		floatieFolder = floatieFolder, pumpSpot = pumpSpot, pumpFolder = pumpFolder, nozzle = nozzle,
		bestSpot = bestSpot, bestLabel = bestLabel,
	}
end

---------------------------------------------------------------------
-- One stall (front = -Z, faces the Tower)
---------------------------------------------------------------------
local function buildStall(parent, info, cf)
	local f = folder(info.name, parent)
	local wood = Color3.fromRGB(170, 115, 65)
	local light = info.color:Lerp(WHITE, 0.35)
	part({ Name = "Floor", Size = V(22, 1, 14), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(235, 235, 240), Studs = "top", Parent = f })
	part({ Name = "BackWall", Size = V(22, 12, 1), CFrame = cf * CFrame.new(0, 7, 6.5), Color = info.color, Studs = "all", Parent = f })
	for _, x in ipairs({ -10.5, 10.5 }) do
		part({ Name = "SideWall", Size = V(1, 6, 12), CFrame = cf * CFrame.new(x, 4, 0.5), Color = light, Studs = "all", Parent = f })
		part({ Name = "Post", Size = V(1, 11.5, 1), CFrame = cf * CFrame.new(x, 6.75, -6.5), Color = WHITE, Studs = "all", Parent = f })
	end
	local counter = part({ Name = "Counter", Size = V(18, 3.6, 2.6), CFrame = cf * CFrame.new(0, 2.8, -4.4), Color = wood, Studs = "all", Parent = f })
	part({ Name = "CounterTop", Size = V(19, 0.5, 3.2), CFrame = cf * CFrame.new(0, 4.85, -4.4), Color = WHITE, Studs = "top", Parent = f })

	-- striped awning sloping down to the front, with a scalloped edge
	local stripes = 8
	local sw = 23 / stripes
	for j = 1, stripes do
		local x = -11.5 + sw * (j - 0.5)
		local c = if j % 2 == 0 then WHITE else info.color
		part({
			Name = "Awning", Size = V(sw, 0.4, 10),
			CFrame = cf * CFrame.new(x, 13, -2.5) * CFrame.Angles(-math.rad(18), 0, 0),
			Color = c, Studs = "top", Parent = f,
		})
		ball(f, "AwningEdge", (cf * CFrame.new(x, 11.1, -7.3)).Position, sw * 0.95, c, { CanCollide = false })
	end

	-- the sign on top + a big floating icon you can see from far away
	local board = part({ Name = "SignBoard", Size = V(20, 4.5, 0.8), CFrame = cf * CFrame.new(0, 17, 6), Color = OUTLINE, Parent = f })
	surfaceSign(board, Enum.NormalId.Front, info.icon .. " " .. info.title, info.color)
	surfaceSign(board, Enum.NormalId.Back, info.icon .. " " .. info.title, info.color)
	-- floating icon + title (billboards stay readable from across the plaza)
	local iconAnchor = part({ Name = "Icon", Size = V(1, 1, 1), CFrame = cf * CFrame.new(0, 25, 3), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = f })
	local iconGui = Instance.new("BillboardGui")
	iconGui.Size = UDim2.fromScale(16, 10)
	iconGui.MaxDistance = 500
	iconGui.LightInfluence = 0
	iconGui.Parent = iconAnchor
	bigText(iconGui, info.icon, WHITE, { Size = UDim2.fromScale(1, 0.62) })
	bigText(iconGui, info.title, info.color:Lerp(WHITE, 0.25), { Size = UDim2.fromScale(1, 0.36), Position = UDim2.fromScale(0, 0.64) })

	local pr = Instance.new("ProximityPrompt")
	pr.Name = "StallPrompt"
	pr.ActionText = "Open"
	pr.ObjectText = info.title
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Panel", info.panel)
	pr.Parent = counter
	CollectionService:AddTag(pr, "StallPrompt")
	return f
end

---------------------------------------------------------------------
-- The Tower (looks only for now: its door says "Coming soon")
---------------------------------------------------------------------
local function buildTower(parent)
	local f = folder("Tower", parent)
	local y = 0.4
	cylinder(f, "Plinth", CFrame.new(0, y, 0), 1.2, (M.TowerBaseRadius + 6) * 2, Color3.fromRGB(220, 220, 230), nil, "top")
	y += 1.2
	local radius = M.TowerBaseRadius
	local h = M.TowerBandHeight
	for k, band in ipairs(M.TowerBands) do
		local material = Enum.Material[band[1]]
		local color = band[2]
		local r = radius - (k - 1) * M.TowerStep
		local b = cylinder(f, "Band" .. k, CFrame.new(0, y, 0), h, r * 2, color, material)
		if band[1] == "Glass" then
			b.Transparency = 0.25
		elseif band[1] == "Ice" then
			b.Transparency = 0.1
		end
		-- ledge on top of each band
		cylinder(f, "Ledge" .. k, CFrame.new(0, y + h - 0.6, 0), 0.8, r * 2 + 2, color:Lerp(WHITE, 0.4), material)
		-- windows on every band but the first (the door is there)
		if k > 1 then
			for j = 0, 3 do
				local ang = math.pi / 4 + j * math.pi / 2 + (k % 2) * math.pi / 4
				local pos = V(math.sin(ang) * (r - 0.05), y + h / 2, math.cos(ang) * (r - 0.05))
				part({
					Name = "Window", Size = V(2.6, 4.2, 0.6), CFrame = CFrame.lookAt(pos, V(0, pos.Y, 0)),
					Color = Color3.fromRGB(40, 55, 95), Material = Enum.Material.Glass, Reflectance = 0.25, Parent = f,
				})
			end
		end
		y += h
	end
	-- the door (faces +Z, the Plaza teleport spot)
	local doorZ = radius - 0.1
	local door = part({ Name = "Door", Size = V(7, 8.5, 1), CFrame = CFrame.new(0, 1.6 + 4.25, doorZ), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "DoorArch", Shape = Enum.PartType.Cylinder, Size = V(1, 7, 7), CFrame = CFrame.new(0, 1.6 + 8.5, doorZ) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks, Parent = f })
	local soon = part({ Name = "SoonSign", Size = V(1, 1, 1), CFrame = CFrame.new(0, 17, doorZ + 3), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = f })
	billboard(soon, "🔒 TOWER: COMING SOON", UDim2.fromScale(26, 3.6), 300, Color3.fromRGB(255, 225, 120))
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "TowerPrompt"
	pr.ActionText = "Enter"
	pr.ObjectText = "The Tower"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = door

	-- top platform and the giant balloon
	cylinder(f, "Top", CFrame.new(0, y, 0), 1, (radius - (#M.TowerBands - 1) * M.TowerStep) * 2 + 4, WHITE, nil, "top")
	local topY = y + 1
	local balloonPos = V(0, topY + 24, 0)
	local balloon = ball(f, "GiantBalloon", balloonPos, 26, Color3.fromRGB(255, 70, 120), { CanCollide = false, Reflectance = 0.2 })
	CollectionService:AddTag(balloon, "BobPart")
	local knot = ball(f, "GiantKnot", balloonPos - V(0, 13.5, 0), 2.6, Color3.fromRGB(200, 40, 90), { CanCollide = false })
	CollectionService:AddTag(knot, "BobPart")
	local stringLen = balloonPos.Y - 13.5 - topY
	local str = part({
		Name = "GiantString", Size = V(0.25, stringLen, 0.25), CFrame = CFrame.new(0, topY + stringLen / 2, 0),
		Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f,
	})
	CollectionService:AddTag(str, "BobPart")
	return f, pr, topY
end

---------------------------------------------------------------------
-- Leaderboard board (the Leaderboards module fills in the rows)
---------------------------------------------------------------------
local function buildBoard(parent, name, title, cf, color)
	local f = folder(name, parent)
	for _, x in ipairs({ -6.5, 6.5 }) do
		part({ Name = "Post", Size = V(1, 14, 1), CFrame = cf * CFrame.new(x, 7, 0), Color = Color3.fromRGB(70, 70, 90), Studs = "all", Parent = f })
	end
	local board = part({ Name = "Board", Size = V(14, 11, 0.8), CFrame = cf * CFrame.new(0, 8.5, 0), Color = OUTLINE, Parent = f })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front -- cf looks away from the Tower, so this side faces the stalls
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = board
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.16, 0)
	header.BackgroundColor3 = color
	header.BorderSizePixel = 0
	header.Parent = gui
	bigText(header, title)
	local rows = {}
	for r = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. r
		row.Position = UDim2.new(0, 0, 0.17 + (r - 1) * 0.083, 0)
		row.Size = UDim2.new(1, 0, 0.08, 0)
		row.BackgroundTransparency = 1
		row.Parent = gui
		local left = bigText(row, "", WHITE, { Size = UDim2.new(0.68, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Left })
		local right = bigText(row, "", Color3.fromRGB(120, 255, 140), { Size = UDim2.new(0.32, -10, 1, 0), Position = UDim2.new(0.68, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
		rows[r] = { left = left, right = right }
	end
	return rows
end

---------------------------------------------------------------------
-- Build everything
---------------------------------------------------------------------
function MapBuilder.Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 0.6
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Decay = Color3.fromRGB(140, 170, 220)
		atmosphere.Parent = Lighting
	end

	local rng = Random.new(42) -- the same decoration every time
	local map = folder("Map", workspace)
	local G = M.GroundSize

	-- ground: a big studded green baseplate, with invisible walls at the edge
	part({ Name = "Ground", Size = V(G, 2, G), Position = V(0, -1, 0), Color = Color3.fromRGB(95, 190, 85), Studs = "top", Parent = map })
	for _, d in ipairs({ { V(G, 80, 2), V(0, 40, G / 2) }, { V(G, 80, 2), V(0, 40, -G / 2) }, { V(2, 80, G), V(G / 2, 40, 0) }, { V(2, 80, G), V(-G / 2, 40, 0) } }) do
		part({ Name = "EdgeWall", Size = d[1], Position = d[2], Transparency = 1, CanQuery = false, Parent = map })
	end
	local fallback = part({
		ClassName = "SpawnLocation", Name = "PlazaSpawn", Size = V(10, 0.4, 10), CFrame = CFrame.new(0, 0.6, 52),
		Color = WHITE, Transparency = 0.3, Neutral = true, Duration = 0, Studs = "top", Parent = map,
	})

	-- plaza
	local plaza = folder("Plaza", map)
	cylinder(plaza, "PlazaFloor", CFrame.new(0, -0.6, 0), 1, M.PlazaRadius * 2, Color3.fromRGB(244, 227, 181), nil, "top")
	cylinder(plaza, "PlazaRing", CFrame.new(0, -0.5, 0), 1, 132, Color3.fromRGB(236, 214, 160), nil, "top")
	local _, towerPrompt = buildTower(plaza)

	-- stalls between the paths, facing the Tower
	local stallsFolder = folder("Stalls", plaza)
	local stallCframes = {}
	for k, info in ipairs(Config.Stalls) do
		local ang = math.pi / 8 + (k - 1) * math.pi / 4
		local pos = V(math.sin(ang) * M.StallRadius, 0.4, math.cos(ang) * M.StallRadius)
		local cf = CFrame.lookAt(pos, V(0, 0.4, 0))
		buildStall(stallsFolder, info, cf)
		stallCframes[info.name] = cf
	end

	-- lamps + benches at the plaza edge, between the paths
	local decoPlaza = folder("Decoration", plaza)
	for k = 0, 7 do
		local ang = math.pi / 8 + k * math.pi / 4
		local pos = V(math.sin(ang) * (M.PlazaRadius - 8), 0, math.cos(ang) * (M.PlazaRadius - 8))
		lamp(decoPlaza, CFrame.lookAt(pos, V(0, 0, 0)), BALLOON_COLORS[k % #BALLOON_COLORS + 1])
		for _, side in ipairs({ -1, 1 }) do
			local bpos = (CFrame.lookAt(pos, V(0, 0, 0)) * CFrame.new(side * 7, 0, 0)).Position
			bench(decoPlaza, CFrame.lookAt(bpos, V(0, 0, 0)) * CFrame.Angles(0, math.pi, 0))
		end
	end

	-- around the Tower: leaderboards, the server's best Floatie, the event sign
	local towerRing = M.TowerBaseRadius + 16
	local rollsRows = buildBoard(plaza, "RollsBoard", "🎲 MOST ROLLS", CFrame.lookAt(V(0, 0.4, -towerRing), V(0, 0.4, -towerRing * 2)), Color3.fromRGB(65, 150, 255))
	local rebirthRows = buildBoard(plaza, "RebirthsBoard", "🌟 MOST REBIRTHS", CFrame.lookAt(V(-towerRing, 0.4, 0), V(-towerRing * 2, 0.4, 0)), Color3.fromRGB(255, 160, 40))
	local serverBestBase = CFrame.lookAt(V(towerRing, 0.4, 0), V(towerRing * 2, 0.4, 0))
	cylinder(plaza, "ServerBestPedestal", serverBestBase, 3, 10, Color3.fromRGB(255, 205, 80), nil, "top")
	cylinder(plaza, "ServerBestRim", serverBestBase * CFrame.new(0, 3, 0), 0.5, 11, WHITE)
	local serverBestAnchor = part({ Name = "ServerBestSign", Size = V(1, 1, 1), CFrame = serverBestBase * CFrame.new(0, 20, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plaza })
	local serverBestLabel = billboard(serverBestAnchor, "🏆 BEST FLOATIE IN THE SERVER", UDim2.fromScale(28, 6), 400, Color3.fromRGB(255, 225, 120))
	local serverBestFolder = folder("ServerBest", plaza)
	local eventAnchor = part({ Name = "EventSign", Size = V(1, 1, 1), CFrame = CFrame.new(0, 26, M.TowerBaseRadius + 2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plaza })
	local eventLabel = billboard(eventAnchor, "", UDim2.fromScale(30, 4.2), 500, Color3.fromRGB(230, 220, 255))

	-- bases + the paths to them
	local basesFolder = folder("Bases", map)
	local pathsFolder = folder("Paths", map)
	local deco = folder("Decoration", map)
	local bases = {}
	for i = 1, Config.MaxPlayers do
		bases[i] = buildBase(basesFolder, i, rng)
		local a = (i - 1) * math.pi * 2 / Config.MaxPlayers
		local inner = M.PlazaRadius - 4
		local outer = M.BaseRadius - M.BaseDepth / 2 + 2
		local mid = (inner + outer) / 2
		local pos = V(math.sin(a) * mid, 0.05, math.cos(a) * mid)
		part({
			Name = "Path" .. i, Size = V(M.PathWidth, 0.3, outer - inner), CFrame = CFrame.lookAt(pos, V(0, 0.05, 0)),
			Color = Color3.fromRGB(235, 235, 240), Studs = "top", Parent = pathsFolder,
		})
		-- balloon bunches where each path meets the plaza
		for _, side in ipairs({ -1, 1 }) do
			local p = (CFrame.lookAt(V(math.sin(a) * (inner + 6), 0, math.cos(a) * (inner + 6)), V(0, 0, 0)) * CFrame.new(side * (M.PathWidth / 2 + 2), 0, 0)).Position
			balloonBunch(deco, rng, p, 3)
		end
	end

	-- trees between and behind the bases (never on a base or a path)
	local function clearOfBases(pos)
		for _, base in ipairs(bases) do
			local rel = base.cf:PointToObjectSpace(pos)
			if math.abs(rel.X) < M.BaseWidth / 2 + 8 and math.abs(rel.Z) < M.BaseDepth / 2 + 8 then
				return false
			end
		end
		return pos.Magnitude > M.PlazaRadius + 12
	end
	local placed = 0
	for _ = 1, 400 do
		if placed >= 70 then
			break
		end
		local ang = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(M.PlazaRadius + 20, G / 2 - 12)
		local pos = V(math.sin(ang) * r, 0, math.cos(ang) * r)
		-- stay off the paths (they run along the 8 base angles)
		local onPath = false
		for i = 1, Config.MaxPlayers do
			local a = (i - 1) * math.pi * 2 / Config.MaxPlayers
			local dir = V(math.sin(a), 0, math.cos(a))
			local along = pos:Dot(dir)
			local across = (pos - dir * along).Magnitude
			if along > 0 and along < M.BaseRadius and across < M.PathWidth then
				onPath = true
			end
		end
		if not onPath and clearOfBases(pos) then
			tree(deco, rng, pos)
			placed += 1
		end
	end
	for _ = 1, 16 do
		local ang = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(60, G / 2)
		cloud(deco, rng, V(math.sin(ang) * r, rng:NextNumber(95, 135), math.cos(ang) * r))
	end

	-- teleport spots for the top bar
	local sellCf = stallCframes.Sell
	local teleports = {
		Plaza = CFrame.lookAt(V(0, 4, M.TowerBaseRadius + 22), V(0, 4, 0)),
		Sell = if sellCf then CFrame.lookAt((sellCf * CFrame.new(0, 4, -16)).Position, (sellCf * CFrame.new(0, 4, 0)).Position) else nil,
	}

	return {
		bases = bases,
		teleports = teleports,
		spawn = fallback,
		plaza = {
			towerPrompt = towerPrompt,
			rollsRows = rollsRows,
			rebirthRows = rebirthRows,
			serverBestSpot = serverBestBase * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
			serverBestLabel = serverBestLabel,
			serverBestFolder = serverBestFolder,
			eventLabel = eventLabel,
		},
	}
end

return MapBuilder
