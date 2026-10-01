--[[
	MapBuilder (ModuleScript in ServerScriptService.Server)
	Builds the whole map from code when the server starts:
	  • 8 player bases (4 per side), each with 20 slots and a spawn

	Want a prettier map later? Build it by hand in Studio and keep the same
	names/attributes — or keep this and just add decorations around it.

	Build() returns { bases = { base, ... } }, each base:
	  { index, folder, cf, size, color, slots = { Part, ... }, spawn,
	    signLabel, floatieFolder }
]]

local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local V = Vector3.new
MapBuilder.BASE_SIZE = 48

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

function MapBuilder.Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	part({ Name = "Ground", Size = V(440, 2, 440), Position = V(0, -1, 0), Color = Color3.fromRGB(110, 190, 95), Material = Enum.Material.Grass, Parent = map })

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
		-- cf = top-center of the floor; local +X points to the middle of the map (the entrance)
		local cf = CFrame.new(x, 1, z) * CFrame.Angles(0, yaw, 0)
		local color = BASE_COLORS[i]

		local folder = Instance.new("Folder")
		folder.Name = "Base" .. i
		folder:SetAttribute("BaseIndex", i)
		folder:SetAttribute("OwnerUserId", 0)
		folder.Parent = basesFolder

		part({ Name = "Floor", Size = V(S, 1, S), CFrame = cf * CFrame.new(0, -0.5, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = folder })
		part({ Name = "Curb", Size = V(1, 1.5, S), CFrame = cf * CFrame.new(-H + 0.5, 0.75, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
		for _, sz in ipairs({ 1, -1 }) do
			part({ Name = "Curb", Size = V(S, 1.5, 1), CFrame = cf * CFrame.new(0, 0.75, sz * (H - 0.5)), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
			part({ Name = "Curb", Size = V(1, 1.5, 16), CFrame = cf * CFrame.new(H - 0.5, 0.75, sz * 16), Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Parent = folder })
		end

		-- 20 slots: 4 rows x 5 columns. Slot 1 = back-left.
		local slotFolder = Instance.new("Folder")
		slotFolder.Name = "Slots"
		slotFolder.Parent = folder
		local slots = {}
		for r = 1, 4 do
			for c = 1, 5 do
				local slot = (r - 1) * 5 + c
				local pad = part({
					Name = "Slot" .. slot, Size = V(5, 1, 5),
					CFrame = cf * CFrame.new(-18 + (r - 1) * 9, 0.5, -18 + (c - 1) * 9),
					Color = color, Material = Enum.Material.SmoothPlastic, Parent = slotFolder,
				})
				pad:SetAttribute("BaseIndex", i)
				pad:SetAttribute("Slot", slot)
				slots[slot] = pad
			end
		end

		local spawn = part({
			ClassName = "SpawnLocation", Name = "Spawn", Size = V(6, 1, 6), CFrame = cf * CFrame.new(18, 0, 0),
			Color = Color3.new(1, 1, 1), Transparency = 0.4, Neutral = true, Duration = 0, Parent = folder,
		})

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
			slots = slots, spawn = spawn, signLabel = signLabel, floatieFolder = floatieFolder,
		}
	end

	return { bases = bases }
end

return MapBuilder
