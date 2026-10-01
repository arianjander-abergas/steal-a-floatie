--[[
	FloatieModel (ModuleScript in ReplicatedStorage.Shared)
	Builds balloon-animal models out of stretched spheres — no 3D modeling needed.
	Every Floatie is built from its `shape` table in Config, at any inflation scale.

	Model layout:
	  Model.PrimaryPart = "Root" (invisible, at the feet, anchored while on a pedestal)
	  every other part is welded to Root, unanchored, massless, non-colliding
	  "Body" part = the main balloon, parts with attribute Paint = recolorable
	  Root.Label = BillboardGui with name / stage / income
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("Config"))

local FloatieModel = {}

local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 215, 90)
local BEAK = Color3.fromRGB(255, 150, 40)

local function newPart(ctx, name, size, cf, color, paint)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.12
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	if paint then
		p:SetAttribute("Paint", true)
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.model
	ctx.top = math.max(ctx.top, cf.Position.Y + size.Y / 2)
	return p
end

-- a long balloon "segment" between two points (positions in unscaled units)
local function segment(ctx, name, a, b, radius, color, paint)
	local k = ctx.k
	a, b, radius = a * k, b * k, radius * k
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.05 then
		return nil
	end
	local up = if math.abs(dir.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	local p = newPart(ctx, name, V(radius * 2, radius * 2, len + radius), cf, color, paint)
	ctx.top = math.max(ctx.top, math.max(a.Y, b.Y) + radius)
	return p
end

-- a round blob (ellipsoid) at a point
local function blob(ctx, name, center, size, color, paint, rot)
	local k = ctx.k
	return newPart(ctx, name, size * k, CFrame.new(center * k) * (rot or CFrame.identity), color, paint)
end

local function addLabel(model, root, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 74)
	gui.StudsOffsetWorldSpace = V(0, height + 1.4, 0)
	gui.MaxDistance = 75
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = root
	gui.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local function line(name, order, size, color)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.LayoutOrder = order
		t.Size = UDim2.new(1, 0, 0, size)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.2
		t.Text = ""
		t.Parent = gui
		return t
	end
	line("Extra", 1, 16, Color3.fromRGB(255, 240, 140))
	line("Rarity", 2, 14, WHITE)
	line("NameLine", 3, 22, WHITE)
	line("Info", 4, 14, Color3.fromRGB(210, 230, 255))
	line("Income", 5, 16, Color3.fromRGB(120, 255, 140))
end

local function sparkles(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Rate = rate or 8
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.35, 0)
	e.Color = ColorSequence.new(color)
	e.Parent = parent
	return e
end

local function applyMutation(model, mutId)
	local body = model:FindFirstChild("Body")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Paint") then
			if mutId == "Neon" then
				p.Material = Enum.Material.Neon
			elseif mutId == "Foil" then
				p.Material = Enum.Material.Foil
				p.Reflectance = 0.35
			elseif mutId == "Glitter" or mutId == "Rainbow" then
				p.Reflectance = 0.3
			end
		end
	end
	if not body then
		return
	end
	if mutId == "Glitter" then
		sparkles(body, Color3.fromRGB(255, 245, 200), 10)
	elseif mutId == "Rainbow" then
		CollectionService:AddTag(model, "RainbowFloatie") -- the client cycles the colors
		sparkles(body, WHITE, 14)
	elseif mutId == "Thunder" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 240, 120)
		light.Range = 14
		light.Brightness = 2
		light.Parent = body
		sparkles(body, Color3.fromRGB(255, 240, 80), 20)
		for _, p in ipairs(model:GetChildren()) do
			if p.Name == "Eye" then
				p.Color = Color3.fromRGB(255, 240, 80)
				p.Material = Enum.Material.Neon
			end
		end
	end
end

--[[
	BuildFromMesh: uses a hand-made or AI-made 3D model instead of the balloon shapes.
	How to add one:
	  1. Studio > File > Import 3D (or Avatar tab > Import 3D), pick the .glb / .fbx / .obj.
	  2. Rotate it so its HEAD points along the red X arrow.
	  3. Make a Folder named "FloatieMeshes" in ReplicatedStorage and put the model
	     inside it, renamed to the Floatie id (e.g. "Dragonflate").
	The game scales it to the Floatie's size and inflates it like any other Floatie.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function FloatieModel.BuildFromMesh(model, root, def, mutId, scale)
	local folder = ReplicatedStorage:FindFirstChild("FloatieMeshes")
	local source = folder and folder:FindFirstChild(def.id)
	if not source then
		return nil
	end
	local copy = source:Clone()
	local parts = {}
	if copy:IsA("BasePart") then
		table.insert(parts, copy)
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		copy:Destroy()
		return nil
	end

	local boxCf, boxSize
	if copy:IsA("Model") then
		boxCf, boxSize = copy:GetBoundingBox()
	else
		boxCf, boxSize = copy.CFrame, copy.Size
	end
	boxCf = CFrame.new(boxCf.Position) -- keep the rotation you gave it in Studio

	-- target length roughly matches the balloon version of this Floatie
	local s = def.shape
	local targetLen = ((s.body or 3) + (s.head or 0) + (s.tail or 0) * 0.5 + 1) * scale
	local k = targetLen / math.max(boxSize.X, boxSize.Z, 0.1)

	local biggest, biggestVol = nil, -1
	for _, p in ipairs(parts) do
		local offset = boxCf:PointToObjectSpace(p.Position) * k
		local rot = p.CFrame - p.Position
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.Massless = true
		p.Size = p.Size * k
		p.CFrame = CFrame.new(offset + Vector3.new(0, boxSize.Y * k / 2, 0)) * rot
		p:SetAttribute("Paint", true)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		local vol = p.Size.X * p.Size.Y * p.Size.Z
		if vol > biggestVol then
			biggest, biggestVol = p, vol
		end
	end
	biggest.Name = "Body"
	copy:Destroy()

	local top = boxSize.Y * k
	applyMutation(model, mutId)
	model:SetAttribute("Height", top)
	model:SetAttribute("FloatieId", def.id)
	model:SetAttribute("Mutation", mutId)
	addLabel(model, root, top)
	return model
end

--[[
	Build(def, mutationId, scale) -> Model
	def   = an entry from Config.Floaties
	scale = inflation scale (Config.Stages[i].scale)
]]
function FloatieModel.Build(def, mutId, scale)
	scale = scale or 1
	mutId = mutId or "Normal"

	local model = Instance.new("Model")
	model.Name = def.name
	CollectionService:AddTag(model, "Floatie") -- the client animates these (bob / squish)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	-- Custom 3D model? (e.g. a Higgsfield/Meshy mesh imported in Studio and put in
	-- ReplicatedStorage > FloatieMeshes, named exactly like the Floatie's id)
	local custom = FloatieModel.BuildFromMesh(model, root, def, mutId, scale)
	if custom then
		return custom
	end

	local ctx = { model = model, root = root, k = scale, top = 0 }
	local s = def.shape
	local c = def.color
	if mutId == "Thunder" then
		c = Color3.fromRGB(45, 45, 85)
	end
	local accent = c:Lerp(WHITE, 0.35)
	local knotColor = c:Lerp(BLACK, 0.3)
	local eyeColor = Color3.fromRGB(20, 20, 30)

	local r = s.r or 1
	local L = s.body or 3
	local leg = s.leg or 0
	local head = s.head or 0
	local neck = s.neck or 0
	local bodyY = if leg > 0 then leg + r * 0.7 else r

	-- body (the main balloon)
	segment(ctx, "Body", V(-L / 2, bodyY, 0), V(L / 2, bodyY, 0), r, c, true)

	-- legs
	if s.legs then
		for i = 1, s.legs do
			local ang = (i / s.legs) * math.pi * 2
			local dx, dz = math.cos(ang), math.sin(ang)
			local reach = r * 0.6 + leg * 0.7
			segment(ctx, "Leg", V(dx * r * 0.5, bodyY - r * 0.3, dz * r * 0.5), V(dx * reach, 0.25, dz * reach), 0.32, c, true)
		end
	elseif leg > 0 then
		local lx, lz = L / 2 - r * 0.5, r * 0.5
		for _, p in ipairs({ V(lx, 0, lz), V(lx, 0, -lz), V(-lx, 0, lz), V(-lx, 0, -lz) }) do
			segment(ctx, "Leg", V(p.X, bodyY, p.Z), V(p.X, 0.25, p.Z), r * 0.4, c, true)
		end
	end

	-- neck + head
	local headC
	if head > 0 then
		if neck > 0 then
			local a = V(L / 2 - r * 0.2, bodyY + r * 0.3, 0)
			local b = a + V(neck * 0.35, neck, 0)
			segment(ctx, "Neck", a, b, r * 0.45, c, true)
			headC = b + V(head * 0.25, head * 0.3, 0)
		else
			headC = V(L / 2 + head * 0.3, bodyY + r * 0.4, 0)
		end
		blob(ctx, "Head", headC, V(head * 1.15, head, head), c, true)
		for _, z in ipairs({ head * 0.24, -head * 0.24 }) do
			blob(ctx, "Eye", V(headC.X + head * 0.48, headC.Y + head * 0.12, z), V(1, 1, 1) * head * 0.2, eyeColor, false)
		end
	else
		headC = V(L / 2 - r * 0.4, bodyY + r * 0.2, 0)
		for _, z in ipairs({ r * 0.8, -r * 0.8 }) do
			blob(ctx, "Eye", V(L / 2 - r * 0.6, bodyY + r * 0.25, z), V(1, 1, 1) * r * 0.22, eyeColor, false)
		end
	end

	-- ears
	if (s.ear or 0) > 0 and head > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			segment(ctx, "Ear",
				headC + V(-head * 0.1, head * 0.35, sz * head * 0.22),
				headC + V(-head * 0.25, head * 0.35 + s.ear, sz * head * 0.4),
				head * 0.15, c, true)
		end
	end

	-- snout / beak
	if s.snout and head > 0 then
		segment(ctx, "Snout", headC + V(head * 0.4, -head * 0.1, 0), headC + V(head * 0.55 + s.snout, -head * 0.12, 0), head * 0.2, BEAK, false)
	end

	-- tail + the balloon knot (every balloon animal has one!)
	if (s.tail or 0) > 0 then
		local a = V(-L / 2 + r * 0.2, bodyY, 0)
		local b = V(-L / 2 - s.tail * 0.45, bodyY + s.tail * 0.8, 0)
		segment(ctx, "Tail", a, b, r * 0.33, c, true)
		blob(ctx, "Knot", b, V(0.45, 0.45, 0.45), knotColor, false)
	else
		blob(ctx, "Knot", V(-L / 2 - r * 0.05, bodyY, 0), V(0.45, 0.45, 0.45), knotColor, false)
	end

	-- extras
	if s.shell then
		blob(ctx, "Shell", V(-L * 0.05, bodyY + r * 0.6 + s.shell * 0.35, 0), V(s.shell, s.shell, s.shell * 0.75), accent, true)
	end
	if s.horn and head > 0 then
		segment(ctx, "Horn", headC + V(head * 0.15, head * 0.4, 0), headC + V(head * 0.15 + s.horn * 0.35, head * 0.4 + s.horn, 0), 0.22, GOLD, false)
	end
	if s.wings then
		for _, sz in ipairs({ 1, -1 }) do
			blob(ctx, "Wing", V(0, bodyY + r * 0.7, sz * (r * 0.6 + s.wings * 0.45)), V(s.wings * 0.9, 0.35, s.wings), accent, true, CFrame.Angles(-sz * 0.45, 0, 0))
		end
	end
	if s.antlers and head > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			local a = headC + V(-head * 0.1, head * 0.4, sz * head * 0.2)
			local b = a + V(-0.3, s.antlers * 0.7, sz * s.antlers * 0.5)
			segment(ctx, "Antler", a, b, 0.22, GOLD, false)
			local m = a:Lerp(b, 0.55)
			segment(ctx, "Antler", m, m + V(s.antlers * 0.35, s.antlers * 0.3, sz * 0.2), 0.18, GOLD, false)
		end
	end
	if s.spikes then
		for i = -1, 1 do
			blob(ctx, "Spike", V(i * L * 0.25, bodyY + r * 0.95, 0), V(0.7, 1.1, 0.35), accent, true)
		end
	end
	if s.spout then
		for i = -1, 1 do
			segment(ctx, "Spout", V(L * 0.2, bodyY + r * 0.9, 0), V(L * 0.2 + i * 0.8, bodyY + r * 0.9 + 2.2, i * 0.3), 0.18, Color3.fromRGB(160, 220, 255), false)
		end
	end

	applyMutation(model, mutId)
	model:SetAttribute("Height", ctx.top)
	model:SetAttribute("FloatieId", def.id)
	model:SetAttribute("Mutation", mutId)
	addLabel(model, root, ctx.top)
	return model
end

-- Anchored = sits still (pedestal / pump line). Unanchored = can be welded to a player.
function FloatieModel.SetAnchored(model, anchored)
	model.PrimaryPart.Anchored = anchored
end

--[[
	SetLabel(model, f, incomePerSec)
	f = a Floatie record { id, mut, level, grade, trait } (level etc. may be missing)
	Lines: "1 in 24K" (Rare and up) / RARITY / [Mutation] Name / Lv · size · grade · trait / +Air/s
]]
local SIZE_NAMES = { "Deflated", "Puffy", "Round", "Chonky", "MEGA" }
function FloatieModel.SetLabel(model, f, incomePerSec)
	local gui = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Label")
	local def = Config.FloatieById[f.id]
	if not gui or not def then
		return
	end
	local rarity = Config.Rarities[def.rarity]
	local level = f.level or 1
	local sizeName = SIZE_NAMES[1]
	for i, size in ipairs(Config.Sizes) do
		if level >= size.level then
			sizeName = size.name or SIZE_NAMES[i]
		end
	end
	local mut = f.mut or "Normal"
	gui.NameLine.Text = if mut ~= "Normal" then mut .. " " .. def.name else def.name
	gui.Rarity.Text = string.upper(def.rarity)
	gui.Rarity.TextColor3 = if def.rarity == "Secret" then WHITE else rarity.color
	local info = "Lv " .. level .. " • " .. sizeName
	if f.grade and f.grade ~= "C" then
		info ..= " • " .. f.grade
	end
	local trait = f.trait and Config.TraitById[f.trait]
	if trait then
		info ..= " • " .. trait.name
	end
	gui.Info.Text = info
	gui.Income.Text = "+" .. Config.Format(incomePerSec or 0) .. " Air/s"
	gui.Extra.Text = if rarity.order >= 3 then Config.FormatOdds(def.odds) else ""
	gui.Extra.TextColor3 = if def.rarity == "Secret" then WHITE else rarity.color
end

-- Confetti burst + "POP!" text at a position (server-side, replicates to everyone)
function FloatieModel.PopEffect(position, color)
	local p = Instance.new("Part")
	p.Name = "PopEffect"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = V(1, 1, 1)
	p.Position = position
	p.Parent = workspace

	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Speed = NumberRange.new(18, 34)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Size = NumberSequence.new(0.8, 0)
	e.Drag = 3
	e.Rate = 350
	e.Parent = p

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.AlwaysOnTop = true
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "POP!"
	t.TextColor3 = WHITE
	t.TextStrokeTransparency = 0
	t.Parent = gui

	task.delay(0.15, function()
		e.Enabled = false
	end)
	Debris:AddItem(p, 1.5)
end

return FloatieModel
