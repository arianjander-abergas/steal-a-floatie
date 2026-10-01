--[[
	PumpModel (ModuleScript in ReplicatedStorage.Shared)
	Builds the 12 pump tiers (our "dice") out of plain parts, so the same
	model stands on your base's Pump Machine platform and spins in the Pump
	Shop preview. Config.Pumps[tier].look picks the design.

	  PumpModel.Build(tier) -> Model
	    PrimaryPart "Root" sits at the bottom center; the front (where the hose
	    points) is -Z. About 10 x 10 studs, 8-14 studs tall.

	Tags for the client's idle animations (see ClientMain/Effects):
	  "Spin"        the part turns around its own X axis (fan blades)
	  "Flicker"     its PointLight flickers (storm lightning)
	  "AuroraCycle" the part's color drifts through aurora colors
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PumpModel = {}

local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(35, 35, 45)
local CHROME = Color3.fromRGB(205, 210, 220)

---------------------------------------------------------------------
-- Builder helpers (positions are in model space, Root at the origin)
---------------------------------------------------------------------
local function newCtx(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	return { model = model, root = root }
end

local function add(ctx, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = ctx.model
	return p
end

-- upright cylinder with its bottom at `pos`
local function cyl(ctx, name, pos, height, diameter, color, props)
	local p = add(ctx, name, V(height, diameter, diameter), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- cylinder lying along X, centered at `pos`
local function cylX(ctx, name, pos, length, diameter, color, props)
	local p = add(ctx, name, V(length, diameter, diameter), CFrame.new(pos), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- cylinder facing -Z (a dial / disc), centered at `pos`
local function disc(ctx, name, pos, thickness, diameter, color, props)
	local p = add(ctx, name, V(thickness, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(ctx, name, pos, diameter, color, props)
	local p = add(ctx, name, V(diameter, diameter, diameter), CFrame.new(pos), color, props)
	p.Shape = Enum.PartType.Ball
	p.Reflectance = 0.12
	return p
end

-- a thin rod between two points
local function rod(ctx, name, a, b, thickness, color, props)
	local len = (b - a).Magnitude
	return add(ctx, name, V(thickness, thickness, len), CFrame.lookAt((a + b) / 2, b), color, props)
end

-- a bendy hose from `a` (on the pump) towards the front, as a few segments
local function hose(ctx, a, color)
	local points = { a, a + V(0, -1.5, -1.5), a + V(0, -2.5, -3.5), a + V(0, -2.2, -5.2) }
	for i = 1, #points - 1 do
		rod(ctx, "Hose", points[i], points[i + 1], 0.55, color or BLACK)
	end
	ball(ctx, "HoseTip", points[#points], 0.75, color or BLACK)
end

local function baseplate(ctx, color, size)
	size = size or 7
	add(ctx, "Plate", V(size, 0.6, size), CFrame.new(0, 0.3, 0), color or Color3.fromRGB(70, 70, 90), { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs })
end

local function sparkleEmitter(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Rate = rate or 6
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 0.35, 0)
	e.Color = ColorSequence.new(color)
	e.Parent = parent
	return e
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 10
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

-- a little balloon on a string, tied at `anchor`
local function tiedBalloon(ctx, anchor, offset, color)
	local top = anchor + offset
	ball(ctx, "Balloon", top, 1.6, color)
	rod(ctx, "String", anchor, top - V(0, 0.8, 0), 0.06, WHITE)
end

---------------------------------------------------------------------
-- The 12 looks
---------------------------------------------------------------------
local LOOKS = {}

LOOKS.Hand = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 5)
	add(ctx, "Foot", V(3.6, 0.5, 1.4), CFrame.new(0, 0.85, 0), BLACK)
	cyl(ctx, "Barrel", V(0, 1.1, 0), 6.2, 2.2, c)
	cyl(ctx, "Cap", V(0, 7.3, 0), 0.5, 2.5, BLACK)
	rod(ctx, "Shaft", V(0, 7.6, 0), V(0, 9.6, 0), 0.45, CHROME, { Material = Enum.Material.Metal })
	add(ctx, "Handle", V(4.2, 0.7, 0.8), CFrame.new(0, 9.9, 0), BLACK)
	hose(ctx, V(0, 2.2, -1.1))
end

LOOKS.Foot = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 7)
	add(ctx, "Bottom", V(5.5, 0.8, 4), CFrame.new(0, 1, 0), Color3.fromRGB(90, 90, 100))
	-- the bellows: pleats between the bottom and the tilted top plate
	for i = 1, 3 do
		add(ctx, "Pleat", V(5.2 - i * 0.3, 0.45, 3.6), CFrame.new(0, 1.3 + i * 0.5, 0.3 * i) * CFrame.Angles(math.rad(6 * i), 0, 0), BLACK)
	end
	add(ctx, "Top", V(5.6, 0.7, 4.2), CFrame.new(0, 3.3, 1.1) * CFrame.Angles(math.rad(22), 0, 0), c, { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs })
	add(ctx, "Pedal", V(3, 0.4, 1.4), CFrame.new(0, 4.3, 2.3) * CFrame.Angles(math.rad(22), 0, 0), BLACK)
	hose(ctx, V(0, 1.6, -2))
end

LOOKS.Bike = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 6)
	add(ctx, "Foot", V(4.4, 0.5, 1.6), CFrame.new(0, 0.85, 0.6), BLACK)
	cyl(ctx, "Barrel", V(0, 1.1, 0.6), 8.6, 1.7, c, { Material = Enum.Material.Metal, Reflectance = 0.3 })
	disc(ctx, "Gauge", V(0, 2.4, -0.45), 0.4, 2.3, WHITE)
	disc(ctx, "GaugeRim", V(0, 2.4, -0.4), 0.3, 2.6, Color3.fromRGB(230, 60, 60))
	add(ctx, "Needle", V(0.15, 0.9, 0.1), CFrame.new(0.25, 2.6, -0.7) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(230, 60, 60))
	rod(ctx, "Shaft", V(0, 9.7, 0.6), V(0, 11.6, 0.6), 0.4, CHROME, { Material = Enum.Material.Metal })
	add(ctx, "Handle", V(4.6, 0.6, 0.8), CFrame.new(0, 11.9, 0.6), BLACK)
	hose(ctx, V(0, 1.8, -0.3))
end

LOOKS.Party = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 6)
	local stripes = { c, WHITE, Color3.fromRGB(255, 220, 70), WHITE, c, WHITE }
	for i, col in ipairs(stripes) do
		cyl(ctx, "Stripe", V(0, 0.6 + (i - 1) * 1.2, 0), 1.2, 2.8, col)
	end
	cyl(ctx, "Cap", V(0, 7.8, 0), 0.6, 3.1, BLACK)
	rod(ctx, "Shaft", V(0, 8.4, 0), V(0, 10.2, 0), 0.45, CHROME)
	add(ctx, "Handle", V(4.4, 0.7, 0.8), CFrame.new(0, 10.5, 0), c)
	-- streamers flying out of the top
	local colors = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 220, 70), Color3.fromRGB(120, 220, 120), c }
	for i = 1, 4 do
		local ang = i * math.pi / 2 + 0.4
		rod(ctx, "Streamer", V(0, 8.2, 0), V(math.cos(ang) * 3.2, 10.8 + (i % 2), math.sin(ang) * 3.2), 0.18, colors[i], { Material = Enum.Material.Neon })
	end
	tiedBalloon(ctx, V(-1.6, 10.6, 0), V(-0.6, 2.4, 0), Color3.fromRGB(255, 220, 70))
	tiedBalloon(ctx, V(1.6, 10.6, 0), V(0.6, 2.8, 0), Color3.fromRGB(90, 170, 255))
	hose(ctx, V(0, 2, -1.4))
end

LOOKS.Double = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 8)
	for _, x in ipairs({ -1.7, 1.7 }) do
		cyl(ctx, "Barrel", V(x, 0.6, 0), 7.4, 2.2, c)
		cyl(ctx, "Cap", V(x, 8, 0), 0.5, 2.5, BLACK)
		rod(ctx, "Shaft", V(x, 8.5, 0), V(x, 10.2, 0), 0.42, CHROME, { Material = Enum.Material.Metal })
		hose(ctx, V(x, 2, -1.1))
	end
	add(ctx, "Handle", V(6.2, 0.8, 0.9), CFrame.new(0, 10.5, 0), BLACK)
	add(ctx, "Brace", V(3.4, 1, 0.8), CFrame.new(0, 4.5, 0), Color3.fromRGB(230, 230, 235))
end

LOOKS.Electric = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 8)
	add(ctx, "Body", V(6.4, 4.4, 4.6), CFrame.new(0, 2.8, 0.4), c, { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs })
	cylX(ctx, "Motor", V(0, 6.1, 0.4), 5.4, 2.6, Color3.fromRGB(70, 75, 95), { Material = Enum.Material.Metal })
	for i = -2, 2 do
		cylX(ctx, "Coil", V(i * 1.0, 6.1, 0.4), 0.35, 2.8, Color3.fromRGB(230, 140, 40), { Material = Enum.Material.Metal })
	end
	for i, col in ipairs({ Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 80, 80) }) do
		add(ctx, "Indicator", V(0.7, 0.7, 0.2), CFrame.new(-2 + i * 1.0, 3.8, -1.95), col, { Material = Enum.Material.Neon })
	end
	add(ctx, "Grill", V(3.6, 1.6, 0.2), CFrame.new(0, 2.2, -1.95), BLACK)
	local spark = add(ctx, "SparkPoint", V(0.4, 0.4, 0.4), CFrame.new(0, 7.6, 0.4), WHITE, { Transparency = 1 })
	local e = sparkleEmitter(spark, Color3.fromRGB(140, 220, 255), 10, 0.5)
	e.Speed = NumberRange.new(3, 7)
	light(spark, Color3.fromRGB(140, 220, 255), 10, 1.2)
	hose(ctx, V(0, 1.6, -1.9))
end

LOOKS.Compressor = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 9)
	cylX(ctx, "Tank", V(0, 3.4, 0.6), 7.6, 4.2, c, { Material = Enum.Material.Metal, Reflectance = 0.15 })
	for _, x in ipairs({ -3.9, 3.9 }) do
		ball(ctx, "TankEnd", V(x, 3.4, 0.6), 4.2, c, { Material = Enum.Material.Metal })
	end
	for _, x in ipairs({ -2.8, 2.8 }) do
		for _, z in ipairs({ -0.8, 2 }) do
			disc(ctx, "Wheel", V(x, 1.1, z), 0.6, 1.6, BLACK)
		end
	end
	add(ctx, "MotorBox", V(3, 2, 2.4), CFrame.new(0, 6.4, 0.6), Color3.fromRGB(70, 75, 95), { Material = Enum.Material.Metal })
	disc(ctx, "Dial", V(-1.6, 4.2, -1.55), 0.3, 1.8, WHITE)
	add(ctx, "Needle", V(0.12, 0.7, 0.1), CFrame.new(-1.45, 4.35, -1.75) * CFrame.Angles(0, 0, math.rad(40)), Color3.fromRGB(230, 60, 60))
	hose(ctx, V(1.6, 3.4, -1.5))
end

LOOKS.Helium = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 7)
	cyl(ctx, "Tank", V(0, 0.6, 0.4), 9, 3.6, c, { Material = Enum.Material.Foil, Reflectance = 0.25 })
	ball(ctx, "TankTop", V(0, 9.6, 0.4), 3.6, c, { Material = Enum.Material.Foil })
	cyl(ctx, "Valve", V(0, 11, 0.4), 0.9, 1, CHROME, { Material = Enum.Material.Metal })
	cylX(ctx, "ValveWheel", V(0, 12.1, 0.4), 0.3, 1.8, Color3.fromRGB(230, 60, 60))
	add(ctx, "Label", V(2.2, 1.6, 0.2), CFrame.new(0, 5, -1.45), Color3.fromRGB(65, 150, 255))
	local colors = { Color3.fromRGB(255, 90, 150), Color3.fromRGB(255, 220, 70), Color3.fromRGB(120, 220, 120) }
	for i, col in ipairs(colors) do
		tiedBalloon(ctx, V(0, 11.8, 0.4), V((i - 2) * 1.6, 3 + (i % 2) * 0.8, 0.2), col)
	end
	hose(ctx, V(0, 10.4, -0.5))
end

LOOKS.Cloud = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(150, 170, 210), 8)
	cyl(ctx, "Stand", V(0, 0.6, 0), 2.6, 3, Color3.fromRGB(150, 170, 210))
	local puffs = { V(0, 5, 0), V(-2.4, 4.4, 0.4), V(2.4, 4.4, 0.4), V(-1.2, 6.2, 0.6), V(1.3, 6.4, 0.2), V(0, 4.6, 1.8) }
	for i, pos in ipairs(puffs) do
		ball(ctx, "Puff", pos, 3.4 + (i % 2) * 0.8, c, { Material = Enum.Material.SmoothPlastic, Reflectance = 0 })
	end
	cyl(ctx, "Funnel", V(0, 7.4, 0), 2.2, 1.4, Color3.fromRGB(180, 195, 230))
	local top = add(ctx, "PuffPoint", V(0.4, 0.4, 0.4), CFrame.new(0, 9.8, 0), WHITE, { Transparency = 1 })
	local e = sparkleEmitter(top, WHITE, 4, 1.4)
	e.LightEmission = 0.2
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(1, 2)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Transparency = NumberSequence.new(0.3, 1)
	hose(ctx, V(0, 3.8, -1.4), Color3.fromRGB(180, 195, 230))
end

LOOKS.Jet = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(60, 60, 75), 9)
	add(ctx, "Pylon", V(2, 3.4, 2.4), CFrame.new(0, 2.3, 0.8), Color3.fromRGB(90, 95, 110), { Material = Enum.Material.Metal })
	-- the engine: a ring of short cylinders around the intake, facing -Z
	local center = V(0, 7.2, 0.8)
	local r = 3.1
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local pos = center + V(math.cos(a) * r, math.sin(a) * r, 0)
		add(ctx, "Ring", V(1.35, 1.0, 5), CFrame.new(pos) * CFrame.Angles(0, 0, a), c, { Material = Enum.Material.Metal, Reflectance = 0.2 })
	end
	add(ctx, "Hub", V(0.8, 2.2, 2.2), CFrame.new(center + V(0, 0, -1.6)) * CFrame.Angles(0, math.pi / 2, 0), WHITE, { Shape = Enum.PartType.Ball })
	-- the fan (spins on the client): one part, its X axis pointing out the front
	local fan = add(ctx, "Fan", V(0.3, 5.4, 0.9), CFrame.new(center + V(0, 0, -1.2)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(60, 60, 70), { Material = Enum.Material.Metal })
	CollectionService:AddTag(fan, "Spin")
	local fan2 = add(ctx, "Fan", V(0.3, 0.9, 5.4), CFrame.new(center + V(0, 0, -1.25)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(60, 60, 70), { Material = Enum.Material.Metal })
	CollectionService:AddTag(fan2, "Spin")
	disc(ctx, "Exhaust", center + V(0, 0, 3.2), 0.4, 4.2, Color3.fromRGB(255, 140, 40), { Material = Enum.Material.Neon })
	hose(ctx, V(0, 3.6, -0.4))
end

LOOKS.Storm = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(45, 45, 60), 8)
	cyl(ctx, "Stand", V(0, 0.6, 0), 3.4, 2.4, Color3.fromRGB(50, 50, 70), { Material = Enum.Material.Metal })
	local puffs = { V(0, 6, 0), V(-2.6, 5.4, 0.3), V(2.6, 5.4, 0.3), V(-1.3, 7.2, 0.5), V(1.4, 7.4, 0), V(0, 5.6, 1.9) }
	for i, pos in ipairs(puffs) do
		ball(ctx, "StormPuff", pos, 3.6 + (i % 2) * 0.8, c, { Reflectance = 0 })
	end
	-- lightning coils hanging under the cloud
	local yellow = Color3.fromRGB(255, 235, 80)
	for _, x in ipairs({ -2, 0.4, 2.4 }) do
		local p0 = V(x, 4.4, -0.6)
		local p1 = p0 + V(0.7, -1.2, 0)
		local p2 = p1 + V(-0.9, -1.1, 0)
		local p3 = p2 + V(0.6, -1, 0)
		for _, pair in ipairs({ { p0, p1 }, { p1, p2 }, { p2, p3 } }) do
			rod(ctx, "Bolt", pair[1], pair[2], 0.22, yellow, { Material = Enum.Material.Neon })
		end
	end
	local flash = add(ctx, "FlashPoint", V(0.4, 0.4, 0.4), CFrame.new(0, 5, -1), WHITE, { Transparency = 1 })
	light(flash, Color3.fromRGB(255, 240, 160), 14, 2)
	CollectionService:AddTag(flash, "Flicker")
	local rain = sparkleEmitter(flash, Color3.fromRGB(150, 190, 255), 18, 0.15)
	rain.Name = "Rain"
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(10, 10)
	rain.Speed = NumberRange.new(10, 14)
	rain.Lifetime = NumberRange.new(0.3, 0.5)
	hose(ctx, V(0, 4, -1.4), Color3.fromRGB(60, 60, 80))
end

LOOKS.Aurora = function(ctx, c)
	baseplate(ctx, Color3.fromRGB(30, 35, 60), 9)
	cyl(ctx, "Core", V(0, 0.6, 0.6), 4.2, 2.6, Color3.fromRGB(40, 45, 80), { Material = Enum.Material.Metal })
	ball(ctx, "Orb", V(0, 6, 0.6), 2.8, c, { Material = Enum.Material.Neon })
	-- three glowing ribbon arcs over the core
	local colors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(90, 200, 255), Color3.fromRGB(190, 120, 255) }
	for k, col in ipairs(colors) do
		local tilt = (k - 2) * 0.55
		local prev = nil
		for i = 0, 10 do
			local a = i / 10 * math.pi
			local pos = V(math.cos(a) * 3.8, 1.6 + math.sin(a) * (5.4 + k * 0.6), 0.6 + math.sin(a) * tilt * 2)
			if prev then
				local seg = rod(ctx, "Ribbon", prev, pos, 0.42, col, { Material = Enum.Material.Neon, Transparency = 0.15 })
				CollectionService:AddTag(seg, "AuroraCycle")
				seg:SetAttribute("Phase", k * 0.2 + i * 0.03)
			end
			prev = pos
		end
	end
	local glow = add(ctx, "GlowPoint", V(0.4, 0.4, 0.4), CFrame.new(0, 6, 0.6), WHITE, { Transparency = 1 })
	light(glow, c, 16, 1.5)
	sparkleEmitter(glow, c, 8, 0.4)
	hose(ctx, V(0, 2.4, -0.7), Color3.fromRGB(40, 45, 80))
end

---------------------------------------------------------------------
-- Build
---------------------------------------------------------------------
function PumpModel.Build(tier)
	local info = Config.Pumps[tier] or Config.Pumps[1]
	local ctx = newCtx(info.name)
	local look = LOOKS[info.look] or LOOKS.Hand
	look(ctx, info.color)
	ctx.model:SetAttribute("Tier", tier)
	return ctx.model
end

return PumpModel
