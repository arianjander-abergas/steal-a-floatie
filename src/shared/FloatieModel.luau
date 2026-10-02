--[[
	FloatieModel (ModuleScript in ReplicatedStorage.Shared)
	Builds the balloon-animal Floaties out of stretched spheres: no 3D
	modeling needed. Every Floatie is built from its `shape` table in Config
	(ConfigParts/Floaties), at any size.

	Model layout:
	  Model.PrimaryPart = "Root" (invisible, at the feet, anchored while on a slot)
	  every other part is welded to Root, unanchored, massless, non-colliding
	  "Body" part = the main balloon, parts with attribute Paint = recolorable
	  Root.Label = BillboardGui with name / level / income
	  The head points along +X.

	Shape keys (all optional; lengths are studs at size 1):
	  body, r            body length and radius          upright = true   body stands up (owls, roos)
	  leg, legs          leg length; legs = N spreads N legs in a circle (octopus)
	  oneLeg, biped      flamingo stance / two legs only  float = 1.2       hovers above the ground
	  neck, neckCurve    neck length; S-shaped neck       heads = 3         several necks + heads
	  head               head size (0 = eyes on the body)  eyes = "big"     white eyes with pupils
	  ear, ears          ear size; ears = "pointy" | "round" | "disc" | "flop" | "tuft"
	  snout, snoutStyle  beak / snout length; "disc" = pig nose; snoutColor
	  trunk, tusks, teeth, antennae, eyestalks, claws, horn, antlers, spikes, spout
	  tail, tailStyle    "thin" | "curl" | "tuft" | "flames" | "comet" | "fin"
	  shell, dome, bumps shell size; dome = turtle shell; bumps = little balloons on it
	  temple             a tiny temple riding on the shell
	  fins, sideFins     dorsal fin / side fins
	  wings, wingStyle   size; "bird" | "feather" | "insect" | "moth"; wingPairs = N
	  mane               { count, size, style = "balls" | "rays", color }
	  furRing            { count, size } shaggy ring around the shoulders
	  halo, crown        a ring of gold beads above the head / a crown of knots
	  belly, stripes, spots   belly color / { count, color } rings / { count, color } dots
	  pouch, beam        kangaroo pouch / a beam of light shooting up from it
	  whiskers           koi whiskers;  yaw = 0.5 turns the whole Floatie a little (fish look like balls head-on)
	  moon               a crescent-moon balloon under the body
	  cloudHooves        little clouds on the feet
	  rings              { { radius, tilt, color }, ... } planet rings
	  orbit              { count, radius, size, colors, height } mini balloons circling it
	  color2, two        second color, and which parts use it: two = { "Ear", "Tail", ... }
	  material, transparency, crystal = true (faceted glass)
	  glow = Color3      a soft light;  particles = "embers" | "stardust" | "lightdust" | "sparkle"
	  style = "constellation" | "jelly" | "spirit"   special builders
	  tags = { "Glitch", "Supernova", "Prism", "Flicker", "AuroraCycle" } client effects
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("Config"))

local FloatieModel = {}

local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 215, 90)
local BEAK = Color3.fromRGB(255, 150, 40)
local EYE = Color3.fromRGB(20, 20, 30)

---------------------------------------------------------------------
-- Part helpers. Positions and sizes are in "shape units" (size 1);
-- ctx.k scales them and ctx.lift raises everything (float).
---------------------------------------------------------------------
local function newPart(ctx, name, size, cf, color, paint, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = V(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = if ctx.rot then ctx.rot * cf else cf
	p.Color = color
	p.Material = opts.material or (paint and ctx.material) or Enum.Material.SmoothPlastic
	p.Reflectance = opts.reflectance or (if paint then ctx.reflectance else 0.12)
	p.Transparency = opts.transparency or (paint and ctx.transparency) or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.Anchored = false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = opts.meshType or (if paint and ctx.crystal then Enum.MeshType.Brick else Enum.MeshType.Sphere)
	mesh.Parent = p
	if paint then
		p:SetAttribute("Paint", true)
	end
	for key, value in pairs(opts.attrs or {}) do
		p:SetAttribute(key, value)
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.model
	ctx.top = math.max(ctx.top, cf.Position.Y + p.Size.Y / 2)
	return p
end

local function scaled(ctx, v)
	return (v + ctx.lift) * ctx.k
end

-- a long balloon "segment" between two points
local function segment(ctx, name, a, b, radius, color, paint, opts)
	a, b = scaled(ctx, a), scaled(ctx, b)
	radius *= ctx.k
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.05 then
		return nil
	end
	local up = if math.abs(dir.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	if paint and ctx.crystal then
		cf *= CFrame.Angles(0, 0, math.rad(45)) -- faceted crystal pieces
	end
	return newPart(ctx, name, V(radius * 2, radius * 2, len + radius), cf, color, paint, opts)
end

-- a round blob (ellipsoid) at a point
local function blob(ctx, name, center, size, color, paint, rot, opts)
	return newPart(ctx, name, size * ctx.k, CFrame.new(scaled(ctx, center)) * (rot or CFrame.identity), color, paint, opts)
end

local function ball(ctx, name, center, d, color, paint, opts)
	return blob(ctx, name, center, V(d, d, d), color, paint, nil, opts)
end

-- a flat disc facing along `normal`
local function disc(ctx, name, center, d, thickness, normal, color, paint, opts)
	local c = scaled(ctx, center)
	local cf = CFrame.lookAt(c, c + normal)
	return newPart(ctx, name, V(d, d, thickness) * ctx.k, cf, color, paint, opts)
end

local function emitter(parent, name, color, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = 6
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.35, 0)
	for k, v in pairs(props or {}) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Name = "Glow"
	l.Color = color
	l.Range = range or 8
	l.Brightness = brightness or 0.8
	l.Shadows = false
	l.Parent = parent
	return l
end

-- the color of a part: color2 when the shape lists it in `two`
local function paintColor(ctx, name)
	if ctx.two[name] then
		return ctx.c2
	end
	return ctx.c
end

---------------------------------------------------------------------
-- Faces
---------------------------------------------------------------------
-- frog eyes: two big balloons on top of the head, and a wide grin
local function frogEyes(ctx, headC, head)
	for _, sz in ipairs({ 1, -1 }) do
		local pos = headC + V(head * 0.18, head * 0.48, sz * head * 0.3)
		ball(ctx, "EyeWhite", pos, head * 0.44, WHITE, false)
		ball(ctx, "Eye", pos + V(head * 0.17, 0.02, 0), head * 0.22, EYE, false)
		ball(ctx, "EyeShine", pos + V(head * 0.25, head * 0.07, sz * head * 0.03), head * 0.07, WHITE, false)
	end
	for i = -3, 3 do
		ball(ctx, "Smile", headC + V(head * 0.55 - math.abs(i) * head * 0.03, -head * 0.08 + math.abs(i) * head * 0.025, i * head * 0.1), head * 0.09, EYE, false)
	end
end

-- eyes at headC, looking along +X; big = white eyes with pupils
local function eyes(ctx, headC, head, big)
	local spacing = head * (if big then 0.3 else 0.24)
	for _, z in ipairs({ spacing, -spacing }) do
		local eyePos = V(headC.X + head * 0.46, headC.Y + head * 0.12, z)
		if big then
			disc(ctx, "EyeWhite", eyePos, head * 0.42, head * 0.12, Vector3.xAxis, WHITE, false)
			ball(ctx, "Eye", eyePos + V(head * 0.06, 0, 0), head * 0.24, EYE, false)
			ball(ctx, "EyeShine", eyePos + V(head * 0.14, head * 0.06, z * 0.15), head * 0.08, WHITE, false)
		else
			ball(ctx, "Eye", eyePos, head * 0.2, EYE, false)
			ball(ctx, "EyeShine", eyePos + V(head * 0.08, head * 0.05, z * 0.1), head * 0.07, WHITE, false)
		end
	end
end

local function ears(ctx, s, headC, head)
	local e = s.ear or 0
	if e <= 0 then
		return
	end
	local style = s.ears or "pointy"
	local color = paintColor(ctx, "Ear")
	for _, sz in ipairs({ 1, -1 }) do
		if style == "round" then
			ball(ctx, "Ear", headC + V(-head * 0.1, head * 0.42 + e * 0.3, sz * (head * 0.32 + e * 0.25)), e, color, true)
		elseif style == "disc" then
			local center = headC + V(-head * 0.15, head * 0.05, sz * (head * 0.5 + e * 0.2))
			blob(ctx, "Ear", center, V(e * 0.9, e * 1.15, 0.3), color, true, CFrame.Angles(0, sz * 0.25, 0))
		elseif style == "flop" then
			segment(ctx, "Ear", headC + V(-head * 0.05, head * 0.3, sz * head * 0.38), headC + V(-head * 0.2, head * 0.1 - e * 0.5, sz * (head * 0.55 + e * 0.2)), head * 0.16, color, true)
		else
			local tip = headC + V(-head * 0.25, head * 0.35 + e, sz * head * 0.4)
			segment(ctx, "Ear", headC + V(-head * 0.1, head * 0.35, sz * head * 0.22), tip, head * 0.15, color, true)
			if style == "tuft" then
				ball(ctx, "EarTuft", tip + V(0, 0.15, 0), 0.32, ctx.c2, false, { material = Enum.Material.Neon })
			end
		end
	end
end

local function snout(ctx, s, headC, head)
	local n = s.snout or 0
	if n <= 0 then
		return
	end
	local color = s.snoutColor or BEAK
	if s.snoutStyle == "disc" then
		disc(ctx, "Snout", headC + V(head * 0.55, -head * 0.08, 0), head * 0.5 * n, 0.35, Vector3.xAxis, color, false)
		for _, z in ipairs({ 0.12, -0.12 }) do
			ball(ctx, "Nostril", headC + V(head * 0.62, -head * 0.06, z * head), head * 0.08, color:Lerp(BLACK, 0.4), false)
		end
		return
	end
	segment(ctx, "Snout", headC + V(head * 0.4, -head * 0.1, 0), headC + V(head * 0.55 + n, -head * 0.12, 0), head * 0.2, color, s.snoutColor ~= nil)
end

local function headExtras(ctx, s, headC, head)
	local c = ctx.c
	if (s.trunk or 0) > 0 then
		local t = s.trunk
		local p0 = headC + V(head * 0.45, -head * 0.12, 0)
		local p1 = p0 + V(t * 0.3, -t * 0.4, 0)
		local p2 = p1 + V(t * 0.12, -t * 0.4, 0)
		local p3 = p2 + V(t * 0.25, t * 0.05, 0)
		segment(ctx, "Trunk", p0, p1, head * 0.17, c, true)
		segment(ctx, "Trunk", p1, p2, head * 0.14, c, true)
		segment(ctx, "Trunk", p2, p3, head * 0.12, c, true)
	end
	if (s.tusks or 0) > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			local t0 = headC + V(head * 0.38, -head * 0.3, sz * head * 0.28)
			local t1 = t0 + V(s.tusks * 0.55, -s.tusks * 0.15, sz * 0.1)
			local t2 = t1 + V(s.tusks * 0.3, s.tusks * 0.45, sz * 0.05)
			segment(ctx, "Tusk", t0, t1, 0.16, WHITE, false)
			segment(ctx, "Tusk", t1, t2, 0.13, WHITE, false)
		end
	end
	if s.teeth then
		for i = -2, 2 do
			ball(ctx, "Tooth", headC + V(head * 0.58, -head * 0.22, i * head * 0.12), head * 0.12, WHITE, false)
		end
	end
	if (s.antennae or 0) > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			local tip = headC + V(head * 0.25, head * 0.45 + s.antennae, sz * (head * 0.3 + s.antennae * 0.35))
			segment(ctx, "Antenna", headC + V(head * 0.1, head * 0.4, sz * head * 0.15), tip, 0.08, ctx.c2, false)
			ball(ctx, "AntennaTip", tip, 0.3, ctx.c2, false)
		end
	end
	if s.horn and head > 0 then
		segment(ctx, "Horn", headC + V(head * 0.15, head * 0.4, 0), headC + V(head * 0.15 + s.horn * 0.35, head * 0.4 + s.horn, 0), 0.22, GOLD, false)
	end
	if s.antlers then
		for _, sz in ipairs({ 1, -1 }) do
			local a = headC + V(-head * 0.1, head * 0.4, sz * head * 0.2)
			local b = a + V(-0.3, s.antlers * 0.7, sz * s.antlers * 0.5)
			segment(ctx, "Antler", a, b, 0.22, GOLD, false)
			local m = a:Lerp(b, 0.55)
			segment(ctx, "Antler", m, m + V(s.antlers * 0.35, s.antlers * 0.3, sz * 0.2), 0.18, GOLD, false)
		end
	end
	if s.mane then
		local m = s.mane
		local count = m.count or 12
		local radius = head * 0.62
		local center = headC + V(-head * 0.18, 0, 0)
		local color = m.color or ctx.c2
		for i = 1, count do
			local a = i / count * math.pi * 2
			local dir = V(0, math.cos(a), math.sin(a))
			if m.style == "rays" then
				segment(ctx, "ManeRay", center + dir * radius * 0.8, center + dir * (radius + (m.len or 1.2)), 0.14, color, false, { material = Enum.Material.Neon })
			else
				ball(ctx, "Mane", center + dir * radius, m.size or 0.7, color, true)
			end
		end
	end
	if s.halo then
		local center = headC + V(-head * 0.1, head * 0.62 + 0.5, 0)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			ball(ctx, "Halo", center + V(math.cos(a), 0, math.sin(a)) * head * 0.42, 0.24, GOLD, false, { material = Enum.Material.Neon })
		end
	end
	if s.crown then
		local center = headC + V(-head * 0.05, head * 0.5, 0)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local base = center + V(math.cos(a), 0, math.sin(a)) * head * 0.28
			segment(ctx, "CrownSpike", base, base + V(0, 0.45, 0), 0.1, GOLD, false, { material = Enum.Material.Neon })
			ball(ctx, "CrownKnot", base + V(0, 0.5, 0), 0.26, GOLD, false, { material = Enum.Material.Neon })
		end
	end
end

-- one head (with its neck) attached at neckBase, leaning by zOff
local function headWithNeck(ctx, s, neckBase, zOff)
	local head = s.head or 0
	local neck = s.neck or 0
	local headC
	if neck > 0 then
		local a = neckBase
		local b
		if s.neckCurve then
			local p1 = a + V(neck * 0.3, neck * 0.38, zOff * 0.3)
			local p2 = p1 + V(-neck * 0.22, neck * 0.34, zOff * 0.3)
			b = p2 + V(neck * 0.32, neck * 0.3, zOff * 0.4)
			segment(ctx, "Neck", a, p1, ctx.r * 0.4, paintColor(ctx, "Neck"), true)
			segment(ctx, "Neck", p1, p2, ctx.r * 0.38, paintColor(ctx, "Neck"), true)
			segment(ctx, "Neck", p2, b, ctx.r * 0.36, paintColor(ctx, "Neck"), true)
		else
			b = a + V(neck * 0.35, neck, zOff)
			segment(ctx, "Neck", a, b, ctx.r * 0.45, paintColor(ctx, "Neck"), true)
		end
		headC = b + V(head * 0.25, head * 0.3, 0)
	else
		headC = neckBase + V(head * 0.3 + ctx.r * 0.2, ctx.r * 0.2, zOff)
	end
	blob(ctx, "Head", headC, V(head * 1.15, head, head), paintColor(ctx, "Head"), true)
	if s.eyes == "frog" then
		frogEyes(ctx, headC, head)
	else
		eyes(ctx, headC, head, s.eyes == "big")
	end
	ears(ctx, s, headC, head)
	snout(ctx, s, headC, head)
	headExtras(ctx, s, headC, head)
	return headC
end

---------------------------------------------------------------------
-- Tails
---------------------------------------------------------------------
local function knot(ctx, pos)
	ball(ctx, "Knot", pos, 0.45, ctx.knot, false)
end

local function tail(ctx, s, base)
	local t = s.tail or 0
	local style = s.tailStyle
	local c = paintColor(ctx, "Tail")
	if t <= 0 and style ~= "fin" then
		knot(ctx, base)
		return
	end
	if style == "thin" then
		local p1 = base + V(-t * 0.45, -t * 0.25, 0)
		local p2 = p1 + V(-t * 0.5, t * 0.35, 0)
		segment(ctx, "Tail", base, p1, 0.11, c, true)
		segment(ctx, "Tail", p1, p2, 0.1, c, true)
		knot(ctx, base)
	elseif style == "curl" then
		local prev = base
		for i = 1, 5 do
			local a = i * 1.3
			local nextPos = base + V(-0.15 - i * 0.12, math.sin(a) * 0.35 + i * 0.05, math.cos(a) * 0.35)
			segment(ctx, "Tail", prev, nextPos, 0.12, c, true)
			prev = nextPos
		end
		knot(ctx, base)
	elseif style == "flames" then
		local count = 5
		for i = 1, count do
			local spread = (i - (count + 1) / 2) * 0.32
			local tip = base + V(-t * 0.8, t * 0.55 + math.abs(spread) * 0.4, spread * t * 0.55)
			local mid = base:Lerp(tip, 0.55) + V(0, 0.2, 0)
			local warm = ctx.c:Lerp(ctx.c2, (i % 2) * 0.6)
			segment(ctx, "Flame", base, mid, 0.26, warm, true)
			segment(ctx, "Flame", mid, tip, 0.18, ctx.c2, false, { material = Enum.Material.Neon })
		end
		knot(ctx, base)
	elseif style == "comet" then
		for i = 1, 9 do
			local u = i / 9
			local pos = base + V(-t * u, t * 0.35 * math.sin(u * math.pi * 0.8) + u * 0.4, math.sin(u * 4) * 0.25)
			local color = ctx.c:Lerp(ctx.c2, u)
			ball(ctx, "Comet", pos, 0.9 * (1 - u * 0.75), color, false, { material = Enum.Material.Neon, transparency = u * 0.55 })
		end
		knot(ctx, base)
	elseif style == "fin" then
		knot(ctx, base)
		local f = s.tailFin or 1.4
		for _, sz in ipairs({ 1, -1 }) do
			blob(ctx, "TailFin", base + V(-f * 0.45, sz * f * 0.35, 0), V(f, f * 0.45, 0.25), paintColor(ctx, "TailFin"), true, CFrame.Angles(0, 0, sz * 0.6))
		end
	else
		local tip = base + V(-t * 0.45, t * 0.8, 0)
		segment(ctx, "Tail", base, tip, ctx.r * 0.33, c, true)
		if style == "tuft" then
			ball(ctx, "TailTuft", tip, ctx.r * 0.75, ctx.c2, true)
		else
			knot(ctx, tip)
		end
	end
end

---------------------------------------------------------------------
-- Wings
---------------------------------------------------------------------
local function wingPair(ctx, s, center, size, sideOffset, tiltUp)
	local style = s.wingStyle or "bird"
	local color = paintColor(ctx, "Wing")
	for _, sz in ipairs({ 1, -1 }) do
		local base = center + V(0, 0, sz * sideOffset)
		if style == "feather" then
			for i = 1, 3 do
				local f = size * (1.15 - i * 0.22)
				blob(ctx, "Wing", base + V(-i * 0.25, i * 0.18, sz * (f * 0.45 + i * 0.12)), V(f * 0.85, 0.3, f), if i == 1 then color else color:Lerp(WHITE, 0.25), true,
					CFrame.Angles(-sz * (tiltUp + i * 0.18), 0, 0), { attrs = { AuroraWing = true } })
			end
		elseif style == "insect" then
			blob(ctx, "Wing", base + V(-0.1, 0.25, sz * size * 0.45), V(size * 0.7, 0.12, size), WHITE, false, CFrame.Angles(-sz * tiltUp, 0, 0),
				{ material = Enum.Material.Glass, transparency = 0.45, reflectance = 0.3 })
		elseif style == "moth" then
			for i, part in ipairs({ { 0.2, 1 }, { -0.55, 0.75 } }) do
				local f = size * part[2]
				local wc = base + V(part[1] * size, 0.15, sz * f * 0.5)
				blob(ctx, "Wing", wc, V(f * 0.95, 0.2, f), color, true, CFrame.Angles(-sz * (tiltUp + 0.55), 0, 0))
				ball(ctx, "WingSpot", wc + V(0, 0.15, sz * f * 0.12), f * 0.32, ctx.c2, false, { material = Enum.Material.Neon })
				if i == 1 then
					ball(ctx, "WingSpot", wc + V(f * 0.2, 0.12, sz * f * 0.3), f * 0.16, WHITE, false, { material = Enum.Material.Neon })
				end
			end
		else
			blob(ctx, "Wing", base + V(0, 0, sz * size * 0.45), V(size * 0.9, 0.35, size), color, true, CFrame.Angles(-sz * tiltUp, 0, 0))
		end
	end
end

---------------------------------------------------------------------
-- The standard balloon animal
---------------------------------------------------------------------
local function buildAnimal(ctx, s)
	local r = s.r or 1
	local L = s.body or 3
	local leg = s.leg or 0
	local head = s.head or 0
	ctx.r = r
	local c = ctx.c
	local bodyY, headBase, backTop, tailBase, frontX

	if s.upright then
		local base = (if leg > 0 then leg + r * 0.25 else r * 0.6)
		segment(ctx, "Body", V(0, base, 0), V(0, base + L, 0), r, paintColor(ctx, "Body"), true)
		bodyY = base + L * 0.5
		headBase = V(0, base + L + r * 0.2, 0)
		backTop = V(-r * 0.6, base + L * 0.6, 0)
		tailBase = V(-r * 0.75, base + r * 0.4, 0)
		frontX = r * 0.8
		-- two legs + feet
		if leg > 0 then
			for _, z in ipairs({ r * 0.45, -r * 0.45 }) do
				segment(ctx, "Leg", V(0, base + r * 0.2, z), V(0.1, 0.25, z), r * 0.32, paintColor(ctx, "Leg"), true)
				blob(ctx, "Foot", V(0.35, 0.18, z), V(0.9, 0.3, 0.55) * math.max(1, leg * 0.5), paintColor(ctx, "Leg"), true)
			end
		end
	else
		bodyY = (if leg > 0 then leg + r * 0.7 else r)
		segment(ctx, "Body", V(-L / 2, bodyY, 0), V(L / 2, bodyY, 0), r, paintColor(ctx, "Body"), true)
		headBase = V(L / 2 - r * 0.2, bodyY + r * 0.3, 0)
		backTop = V(0, bodyY + r * 0.7, 0)
		tailBase = V(-L / 2 + r * 0.05, bodyY, 0)
		frontX = L / 2
		-- legs
		local legColor = paintColor(ctx, "Leg")
		if s.legs then
			for i = 1, s.legs do
				local ang = (i / s.legs) * math.pi * 2
				local dx, dz = math.cos(ang), math.sin(ang)
				local reach = r * 0.6 + leg * 0.7
				if s.curlLegs then
					local mid = V(dx * reach * 0.75, bodyY * 0.45, dz * reach * 0.75)
					segment(ctx, "Leg", V(dx * r * 0.5, bodyY - r * 0.3, dz * r * 0.5), mid, 0.34, legColor, true)
					segment(ctx, "Leg", mid, V(dx * reach * 1.15, 0.35, dz * reach * 1.15) + V(0, 0.25, 0), 0.24, legColor, true)
					if s.suckers then
						ball(ctx, "Sucker", mid + V(0, -0.2, 0), 0.22, ctx.c2, false)
					end
				else
					segment(ctx, "Leg", V(dx * r * 0.5, bodyY - r * 0.3, dz * r * 0.5), V(dx * reach, 0.25, dz * reach), 0.32, legColor, true)
				end
			end
		elseif leg > 0 then
			local lx, lz = L / 2 - r * 0.5, r * 0.5
			local spots = { V(lx, 0, lz), V(lx, 0, -lz), V(-lx, 0, lz), V(-lx, 0, -lz) }
			if s.biped then
				spots = { V(-lx * 0.4, 0, lz), V(-lx * 0.4, 0, -lz) }
			end
			for i, p in ipairs(spots) do
				if s.oneLeg and i > 1 then
					if i == 2 then -- the folded leg
						segment(ctx, "Leg", V(p.X, bodyY, p.Z), V(p.X - 0.4, bodyY - leg * 0.35, p.Z), r * 0.28, legColor, true)
					end
				else
					local foot = V(p.X, 0.25, p.Z)
					segment(ctx, "Leg", V(p.X, bodyY, p.Z), foot, r * 0.4 * (if s.biped then 1.3 else 1), legColor, true)
					if s.cloudHooves then
						for j = 0, 2 do
							local a = j * 2.1
							ball(ctx, "Cloud", foot + V(math.cos(a) * 0.25, 0.05, math.sin(a) * 0.25), 0.55, WHITE, false)
						end
					end
				end
			end
			if s.tinyArms then
				for _, z in ipairs({ r * 0.6, -r * 0.6 }) do
					segment(ctx, "Arm", V(L / 2 - r * 0.3, bodyY - r * 0.1, z), V(L / 2 + 0.3, bodyY - r * 0.5, z * 1.1), r * 0.18, legColor, true)
				end
			end
		end
	end

	-- belly, stripes, spots
	if s.belly then
		if s.upright then
			blob(ctx, "Belly", V(r * 0.45, bodyY, 0), V(r * 1.2, L * 0.75, r * 1.5), s.belly, true)
		else
			blob(ctx, "Belly", V(L * 0.1, bodyY - r * 0.35, 0), V(L * 0.8, r * 1.1, r * 1.5), s.belly, true)
		end
	end
	if s.stripes then
		local n = s.stripes.count or 3
		for i = 1, n do
			local u = (i / (n + 1)) - 0.5
			if s.upright then
				blob(ctx, "Stripe", V(0, bodyY + u * L, 0), V(r * 2.06, 0.32, r * 2.06), s.stripes.color or BLACK, false)
			else
				blob(ctx, "Stripe", V(u * L, bodyY, 0), V(0.32, r * 2.06, r * 2.06), s.stripes.color or BLACK, false)
			end
		end
	end
	if s.spots then
		-- flat patches spread around the sides (alternating left / right)
		local rng = Random.new(ctx.seed)
		for i = 1, s.spots.count or 6 do
			local side = if i % 2 == 0 then 1 else -1
			local a = side * rng:NextNumber(0.35, 1.45)
			local along = rng:NextNumber(-0.42, 0.42) * L
			local normal, pos
			if s.upright then
				normal = V(math.cos(a * 1.4), 0, math.sin(a * 1.4))
				pos = V(0, bodyY + along, 0) + normal * r * 0.97
			else
				normal = V(0, math.cos(a), math.sin(a))
				pos = V(along, bodyY, 0) + normal * r * 0.97
			end
			local d = rng:NextNumber(0.4, 0.65) * math.max(r, 0.8)
			disc(ctx, "Spot", pos, d, d * 0.28, normal, s.spots.color or ctx.c2, false)
		end
	end
	if s.furRing then
		local fr = s.furRing
		local count = fr.count or 14
		for i = 1, count do
			local a = i / count * math.pi * 2
			ball(ctx, "Fur", V(L * 0.22, bodyY, 0) + V(0, math.cos(a), math.sin(a)) * r * 1.02, fr.size or 0.85, paintColor(ctx, "Fur"), true)
		end
	end

	-- heads
	if head > 0 then
		local count = s.heads or 1
		for i = 1, count do
			local zOff = (i - (count + 1) / 2) * (s.neck or 1) * 0.55
			headWithNeck(ctx, s, headBase, zOff)
		end
	else
		-- eyes on the body (whale, shark, octopus)
		local eyeX = if s.upright then r * 0.8 else frontX - r * 0.5
		local fake = V(eyeX - r * 0.35, bodyY + r * 0.15, 0)
		eyes(ctx, fake, r * 1.4, s.eyes == "big")
		if s.halo then
			local center = V(frontX - r * 0.6, bodyY + r + 0.7, 0)
			for i = 1, 10 do
				local a = i / 10 * math.pi * 2
				ball(ctx, "Halo", center + V(math.cos(a), 0, math.sin(a)) * r * 0.6, 0.24, GOLD, false, { material = Enum.Material.Neon })
			end
		end
		if s.whiskers then
			for _, sz in ipairs({ 1, -1 }) do
				local base = V(frontX - r * 0.1, bodyY - r * 0.2, sz * r * 0.35)
				local mid = base + V(0.5, -0.35, sz * 0.5)
				segment(ctx, "Whisker", base, mid, 0.07, ctx.c2, false)
				segment(ctx, "Whisker", mid, mid + V(0.4, -0.5, sz * 0.2), 0.06, ctx.c2, false)
			end
		end
		if s.teeth then
			for i = -2, 2 do
				ball(ctx, "Tooth", V(frontX - r * 0.15, bodyY - r * 0.42, i * r * 0.16), r * 0.16, WHITE, false)
			end
		end
	end

	-- eyestalks + claws (crab)
	if (s.eyestalks or 0) > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			local base = V(frontX - r * 0.2, bodyY + r * 0.6, sz * r * 0.35)
			local top = base + V(0.2, s.eyestalks, sz * 0.15)
			segment(ctx, "Eyestalk", base, top, 0.12, ctx.c, true)
			ball(ctx, "EyeWhite", top, 0.55, WHITE, false)
			ball(ctx, "Eye", top + V(0.2, 0, 0), 0.3, EYE, false)
		end
	end
	if (s.claws or 0) > 0 then
		local cl = s.claws
		for _, sz in ipairs({ 1, -1 }) do
			local a = V(frontX - r * 0.3, bodyY, sz * r * 0.7)
			local b = a + V(cl * 0.55, cl * 0.25, sz * cl * 0.45)
			segment(ctx, "Arm", a, b, 0.22, ctx.c, true)
			blob(ctx, "Claw", b + V(cl * 0.35, cl * 0.12, 0), V(cl * 0.75, cl * 0.32, cl * 0.42), ctx.c, true, CFrame.Angles(0, 0, 0.35))
			blob(ctx, "Claw", b + V(cl * 0.3, -cl * 0.12, 0), V(cl * 0.6, cl * 0.25, cl * 0.38), ctx.c, true, CFrame.Angles(0, 0, -0.35))
		end
	end

	-- tail
	tail(ctx, s, tailBase)

	-- on the back
	if s.shell then
		if s.dome then
			local center = V(-L * 0.02, bodyY + r * 0.35, 0)
			blob(ctx, "Shell", center, V(s.shell * 1.2, s.shell * 0.62, s.shell), paintColor(ctx, "Shell"), true)
			local bumps = s.bumps or 0
			local rng = Random.new(ctx.seed + 7)
			for i = 1, bumps do
				local a = i / bumps * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local ring = if i % 2 == 0 then 0.32 else 0.18
				ball(ctx, "Bump", center + V(math.cos(a) * s.shell * ring * 1.2, s.shell * 0.25 + (0.35 - ring) * 0.5, math.sin(a) * s.shell * ring), s.shell * 0.24, ctx.c2:Lerp(WHITE, 0.15), true)
			end
			ctx.shellTop = center + V(0, s.shell * 0.31, 0)
		else
			blob(ctx, "Shell", V(-L * 0.05, bodyY + r * 0.6 + s.shell * 0.35, 0), V(s.shell, s.shell, s.shell * 0.75), paintColor(ctx, "Shell"), true)
			ctx.shellTop = V(-L * 0.05, bodyY + r * 0.6 + s.shell * 0.85, 0)
		end
	end
	if s.temple and ctx.shellTop then
		local t = ctx.shellTop
		local brick = Enum.MeshType.Brick
		blob(ctx, "TempleBase", t + V(0, 0.15, 0), V(1.5, 0.3, 1.3), WHITE, false, nil, { meshType = brick })
		for _, x in ipairs({ -0.55, 0.55 }) do
			for _, z in ipairs({ -0.45, 0.45 }) do
				blob(ctx, "TemplePillar", t + V(x, 0.75, z), V(0.18, 0.9, 0.18), WHITE, false, nil, { meshType = brick })
			end
		end
		for _, sz in ipairs({ 1, -1 }) do
			blob(ctx, "TempleRoof", t + V(0, 1.42, sz * 0.36), V(1.8, 0.12, 0.95), GOLD, false, CFrame.Angles(sz * 0.55, 0, 0), { meshType = brick, material = Enum.Material.Foil })
		end
		ball(ctx, "TempleOrb", t + V(0, 1.85, 0), 0.32, GOLD, false, { material = Enum.Material.Neon })
	end
	if (s.fins or 0) > 0 then
		blob(ctx, "Fin", backTop + V(-0.1, s.fins * 0.4, 0), V(s.fins * 0.9, s.fins, 0.25), paintColor(ctx, "Fin"), true, CFrame.Angles(0, 0, 0.5))
	end
	if (s.sideFins or 0) > 0 then
		for _, sz in ipairs({ 1, -1 }) do
			blob(ctx, "SideFin", V(L * 0.15, bodyY - r * 0.3, sz * (r + s.sideFins * 0.3)), V(s.sideFins * 0.8, 0.22, s.sideFins * 0.6), paintColor(ctx, "Fin"), true, CFrame.Angles(sz * 0.5, 0, -0.3))
		end
	end
	if s.spikes then
		for i = -1, 1 do
			blob(ctx, "Spike", V(i * L * 0.25, bodyY + r * 0.95, 0), V(0.7, 1.1, 0.35), ctx.accent, true)
		end
	end
	if s.spout then
		for i = -1, 1 do
			segment(ctx, "Spout", V(L * 0.2, bodyY + r * 0.9, 0), V(L * 0.2 + i * 0.8, bodyY + r * 0.9 + 2.2, i * 0.3), 0.18, s.spoutColor or Color3.fromRGB(160, 220, 255), false,
				{ material = if s.spoutColor then Enum.Material.Neon else nil })
		end
	end
	if s.wings then
		local pairsCount = s.wingPairs or 1
		for i = 1, pairsCount do
			local along = if pairsCount == 1 then 0 else (0.5 - (i - 1) / (pairsCount - 1)) * L * 0.6
			local size = s.wings * (if pairsCount == 1 then 1 else 0.7 + (i - 1) * 0.15)
			local center
			if s.upright then
				center = V(-r * 0.5, bodyY + along * 0.4 + L * 0.15, 0)
			else
				center = V(along, bodyY + r * 0.7, 0)
			end
			wingPair(ctx, s, center, size, r * 0.6, 0.45 + (i - 1) * 0.25)
		end
	end
	if s.pouch then
		local pouchPos = V(r * 0.75, bodyY - L * 0.15, 0)
		blob(ctx, "Pouch", pouchPos, V(r * 0.7, L * 0.38, r * 1.2), ctx.c2, true)
		if s.beam then
			segment(ctx, "Beam", pouchPos + V(0.2, 0.3, 0), pouchPos + V(0.35, 6.5, 0), 0.32, Color3.fromRGB(255, 255, 210), false,
				{ material = Enum.Material.Neon, transparency = 0.35, shadow = false })
		end
	end
	if s.moon then
		local mr = s.moon
		local center = V(0, -mr * 0.2, 0)
		for i = 0, 10 do
			local a = math.rad(200 + i * 14)
			local d = mr * (0.28 + 0.22 * math.sin(i / 10 * math.pi))
			ball(ctx, "Moon", center + V(math.cos(a) * mr * 0.75, math.sin(a) * mr * 0.55 + mr * 0.75, 0), d, ctx.c2, false, { material = Enum.Material.Neon, reflectance = 0 })
		end
	end
end

---------------------------------------------------------------------
-- Special builders
---------------------------------------------------------------------
-- a lion drawn in stars: glowing points joined by thin light lines
local function buildConstellation(ctx, s)
	local starColor = ctx.c
	local lineColor = ctx.c2
	local points = {
		hip = V(-1.4, 2.0, 0), back = V(-1.2, 2.6, 0), shoulder = V(1.1, 2.7, 0), chest = V(1.3, 2.0, 0),
		fl = V(1.25, 0.15, 0.5), fr = V(1.25, 0.15, -0.5), bl = V(-1.35, 0.15, 0.5), br = V(-1.35, 0.15, -0.5),
		flk = V(1.35, 1.0, 0.5), frk = V(1.1, 1.0, -0.5), blk = V(-1.2, 1.0, 0.5), brk = V(-1.5, 1.0, -0.5),
		head = V(2.25, 3.25, 0), nose = V(2.95, 3.0, 0), jaw = V(2.6, 2.7, 0), earL = V(2.1, 3.95, 0.35), earR = V(2.1, 3.95, -0.35),
		tail1 = V(-2.0, 2.7, 0), tail2 = V(-2.6, 3.3, 0), tail3 = V(-2.95, 3.05, 0),
	}
	local edges = {
		{ "hip", "back" }, { "back", "shoulder" }, { "shoulder", "chest" }, { "chest", "hip" },
		{ "chest", "flk" }, { "flk", "fl" }, { "chest", "frk" }, { "frk", "fr" },
		{ "hip", "blk" }, { "blk", "bl" }, { "hip", "brk" }, { "brk", "br" },
		{ "shoulder", "head" }, { "head", "nose" }, { "nose", "jaw" }, { "jaw", "chest" },
		{ "head", "earL" }, { "head", "earR" },
		{ "back", "tail1" }, { "tail1", "tail2" }, { "tail2", "tail3" },
	}
	for _, e in ipairs(edges) do
		segment(ctx, "StarLine", points[e[1]], points[e[2]], 0.06, lineColor, false, { material = Enum.Material.Neon, transparency = 0.25, shadow = false })
	end
	for name, p in pairs(points) do
		local big = name == "head" or name == "shoulder" or name == "hip"
		ball(ctx, "Star", p, if big then 0.55 else 0.38, starColor, true, { material = Enum.Material.Neon, shadow = false })
	end
	-- the mane: a ring of stars
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		ball(ctx, "Star", points.head + V(-0.2, math.cos(a) * 0.85, math.sin(a) * 0.85), 0.3, starColor, true, { material = Enum.Material.Neon, shadow = false })
	end
	-- a faint glow of a body, so it reads as a lion from far away
	blob(ctx, "Body", V(0, 2.3, 0), V(3.4, 1.4, 1.4), lineColor, true, nil, { material = Enum.Material.ForceField, transparency = 0.2, shadow = false })
	ctx.top = math.max(ctx.top, scaled(ctx, V(0, 4.1, 0)).Y)
end

-- a jellyfish with a dark bell and long thin tentacles, floating
local function buildJelly(ctx, s)
	local bell = s.bell or 2.4
	local y = (s.float or 2.5)
	blob(ctx, "Body", V(0, y, 0), V(bell * 1.1, bell * 0.85, bell * 1.1), paintColor(ctx, "Body"), true, nil, { reflectance = 0.45 })
	blob(ctx, "BellRim", V(0, y - bell * 0.3, 0), V(bell * 1.2, bell * 0.18, bell * 1.2), ctx.c2, false, nil, { material = Enum.Material.Neon, transparency = 0.2 })
	eyes(ctx, V(bell * 0.15, y + bell * 0.05, 0), bell * 0.85, true)
	local count = s.tentacles or 8
	for i = 1, count do
		local a = i / count * math.pi * 2
		local top = V(math.cos(a) * bell * 0.35, y - bell * 0.3, math.sin(a) * bell * 0.35)
		local mid = top + V(math.cos(a) * 0.3, -(y - 0.6) * 0.5, math.sin(a) * 0.3)
		local bottom = mid + V(-math.cos(a) * 0.2, -(y - 0.6) * 0.45, -math.sin(a) * 0.2)
		segment(ctx, "Tentacle", top, mid, 0.13, ctx.c2, false, { material = Enum.Material.Neon, transparency = 0.3 })
		segment(ctx, "Tentacle", mid, bottom, 0.09, ctx.c2, false, { material = Enum.Material.Neon, transparency = 0.45 })
	end
	knot(ctx, V(0, y + bell * 0.45, 0))
end

-- the First Balloon: one big classic balloon with a face, a string, and a crown of knots
local function buildSpirit(ctx, s)
	local y = s.float or 3
	local size = s.balloon or 3.2
	blob(ctx, "Body", V(0, y, 0), V(size, size * 1.18, size), paintColor(ctx, "Body"), true, nil, { reflectance = 0.25 })
	ball(ctx, "Knot", V(0, y - size * 0.62, 0), 0.5, GOLD, false, { material = Enum.Material.Neon })
	segment(ctx, "String", V(0, y - size * 0.66, 0), V(0.25, 0.2, 0), 0.06, WHITE, false)
	eyes(ctx, V(size * 0.12, y + size * 0.05, 0), size * 0.8, true)
	-- a little smile
	for i = -2, 2 do
		ball(ctx, "Smile", V(size * 0.48, y - size * 0.2 - math.cos(i * 0.5) * 0.12 + 0.1, i * 0.14), 0.13, EYE, false)
	end
	-- crown of knots
	local crownC = V(0, y + size * 0.6, 0)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local base = crownC + V(math.cos(a) * size * 0.22, 0, math.sin(a) * size * 0.22)
		segment(ctx, "CrownSpike", base, base + V(0, 0.55, 0), 0.1, GOLD, false, { material = Enum.Material.Neon })
		ball(ctx, "CrownKnot", base + V(0, 0.62, 0), 0.3, GOLD, false, { material = Enum.Material.Neon })
	end
	ctx.r = size * 0.5
end

---------------------------------------------------------------------
-- Rings and orbiting mini balloons
---------------------------------------------------------------------
local function rings(ctx, list, center)
	for _, ring in ipairs(list) do
		local count = 20
		for i = 1, count do
			local a = i / count * math.pi * 2
			local flat = V(math.cos(a) * ring.radius, 0, math.sin(a) * ring.radius)
			local tilted = CFrame.Angles(ring.tilt or 0, 0, 0):VectorToWorldSpace(flat)
			ball(ctx, "Ring", center + tilted, ring.size or 0.32, ring.color or GOLD, false, {
				material = Enum.Material.Neon,
				attrs = if ring.spin then { OrbitRadius = ring.radius * ctx.k, OrbitSpeed = ring.spin, OrbitPhase = a, OrbitTilt = ring.tilt or 0 } else nil,
			})
		end
	end
end

local ORBIT_COLORS = {
	Color3.fromRGB(255, 90, 150), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(120, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 150, 70),
}

local function orbit(ctx, o, center)
	local count = o.count or 3
	for i = 1, count do
		local a = i / count * math.pi * 2
		local colors = o.colors or ORBIT_COLORS
		local color = colors[(i - 1) % #colors + 1]
		local pos = center + V(math.cos(a) * o.radius, (o.height or 0) + math.sin(a * 2) * 0.3, math.sin(a) * o.radius)
		ball(ctx, "Orbit", pos, o.size or 0.7, color, false, {
			material = if o.neon then Enum.Material.Neon else nil, reflectance = 0.2,
			attrs = { OrbitRadius = o.radius * ctx.k, OrbitSpeed = o.speed or 1.2, OrbitPhase = a, OrbitTilt = o.tilt or 0, OrbitTick = o.tick == true },
		})
	end
end

---------------------------------------------------------------------
-- Rarity looks (on top of the shape) and mutations (on top of that)
---------------------------------------------------------------------
local function applyRarity(ctx, def)
	local model = ctx.model
	local body = model:FindFirstChild("Body")
	local order = Config.Rarities[def.rarity].order
	local rarityColor = Config.Rarities[def.rarity].color
	if not body then
		return
	end
	if order >= 3 then -- Rare: extra shine + a soft sparkle
		emitter(body, "RaritySparkle", WHITE, { Rate = 2, Size = NumberSequence.new(0.25, 0) })
	end
	if order == 4 then -- Epic: purple sparkle
		emitter(body, "EpicSparkle", Color3.fromRGB(200, 140, 255), { Rate = 3 })
	end
	if order >= 5 then -- Legendary: gold trim
		for _, p in ipairs(model:GetChildren()) do
			if p.Name == "Knot" then
				p.Color = GOLD
				p.Material = Enum.Material.Foil
			end
		end
		emitter(body, "GoldSparkle", Color3.fromRGB(255, 210, 90), { Rate = 3, Size = NumberSequence.new(0.3, 0) })
	end
	if order >= 6 then -- Mythic: an aura around the body
		emitter(body, "Aura", rarityColor, {
			Rate = 3, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.3, 0.8),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 1.4), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.55, 1), LightEmission = 0.7,
		})
	end
	if order >= 7 then -- Divine and up: a soft light
		light(body, ctx.glow or rarityColor:Lerp(WHITE, 0.4), 9, 0.9)
	end
	if order == 7 then -- Divine: rays
		emitter(body, "Rays", Color3.fromRGB(255, 240, 190), {
			Rate = 2, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2.6), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.5, 1), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Rotation = NumberRange.new(0, 360), LightEmission = 0.8,
		})
	end
	if order == 8 then -- Celestial: see-through, star speckles, a stardust trail
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("Paint") and p.Transparency < 0.25 then
				p.Transparency = 0.25
			end
		end
		emitter(body, "Stars", WHITE, { Rate = 7, Size = NumberSequence.new(0.18, 0), Speed = NumberRange.new(0.2, 0.8) })
		emitter(body, "Stardust", Color3.fromRGB(170, 220, 255), {
			Rate = 5, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25),
			Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1, 1.6), Size = NumberSequence.new(0.22, 0),
		})
	end
	if order == 9 then -- Cosmic: galaxy sparkles
		emitter(body, "Galaxy", Color3.fromRGB(170, 120, 255), { Rate = 6, Size = NumberSequence.new(0.3, 0) })
	end
	if order >= 10 then -- Secret: a dark shimmer (each one also has its own effect)
		emitter(body, "SecretShimmer", Color3.fromRGB(255, 255, 255), {
			Rate = 5, Size = NumberSequence.new(0.22, 0), Speed = NumberRange.new(2, 4),
		})
	end
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
		emitter(body, "Sparkles", Color3.fromRGB(255, 245, 200), { Rate = 10 })
	elseif mutId == "Rainbow" then
		CollectionService:AddTag(model, "RainbowFloatie") -- the client cycles the colors
		emitter(body, "Sparkles", WHITE, { Rate = 14 })
	elseif mutId == "Thunder" then
		light(body, Color3.fromRGB(255, 240, 120), 14, 2)
		emitter(body, "Sparkles", Color3.fromRGB(255, 240, 80), { Rate = 20 })
		for _, p in ipairs(model:GetChildren()) do
			if p.Name == "Eye" then
				p.Color = Color3.fromRGB(255, 240, 80)
				p.Material = Enum.Material.Neon
			end
		end
	end
end

---------------------------------------------------------------------
-- Labels
---------------------------------------------------------------------
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

--[[
	BuildFromMesh: uses a hand-made or AI-made 3D model instead of the balloon shapes.
	How to add one:
	  1. Studio > File > Import 3D (or Avatar tab > Import 3D), pick the .glb / .fbx / .obj.
	  2. Rotate it so its HEAD points along the red X arrow.
	  3. Make a Folder named "FloatieMeshes" in ReplicatedStorage and put the model
	     inside it, renamed to the Floatie id (e.g. "Dragonflate").
	The game scales it to the Floatie's size and inflates it like any other Floatie.
]]
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
	scale = the size from its level (Config.Sizes[i].scale)
]]
function FloatieModel.Build(def, mutId, scale)
	scale = scale or 1
	mutId = mutId or "Normal"

	local model = Instance.new("Model")
	model.Name = def.name
	CollectionService:AddTag(model, "Floatie") -- the client animates these (bob / squish / blink)

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

	local s = def.shape or {}
	local c = def.color
	if mutId == "Thunder" then
		c = Color3.fromRGB(45, 45, 85)
	end
	local two = {}
	for _, name in ipairs(s.two or {}) do
		two[name] = true
	end
	local ctx = {
		model = model, root = root, k = scale * (s.size or 1), top = 0,
		lift = V(0, if s.style then 0 else (s.float or 0), 0),
		c = c, c2 = def.color2 or c:Lerp(WHITE, 0.45), two = two,
		accent = c:Lerp(WHITE, 0.35), knot = c:Lerp(BLACK, 0.3),
		material = if s.material then Enum.Material[s.material] else nil,
		transparency = s.transparency, reflectance = s.reflectance or 0.12,
		crystal = s.crystal == true, seed = (def.index or 1) * 977, r = s.r or 1,
		glow = s.glow,
		rot = if s.yaw then CFrame.Angles(0, s.yaw, 0) else nil,
	}

	if s.style == "constellation" then
		buildConstellation(ctx, s)
	elseif s.style == "jelly" then
		buildJelly(ctx, s)
	elseif s.style == "spirit" then
		buildSpirit(ctx, s)
	else
		buildAnimal(ctx, s)
	end

	-- whole-body extras
	local centerY = (if s.style == "spirit" then (s.float or 3) elseif s.style == "jelly" then (s.float or 2.5) else ((s.leg or 0) + (s.r or 1) * 0.7 + (s.float or 0)))
	if s.rings then
		rings(ctx, s.rings, V(0, centerY - (if s.style then 0 else (s.float or 0)), 0))
	end
	if s.orbit then
		orbit(ctx, s.orbit, V(0, centerY - (if s.style then 0 else (s.float or 0)), 0))
	elseif Config.Rarities[def.rarity].order == 9 then
		-- every Cosmic Floatie gets mini balloons circling it
		orbit(ctx, { count = 3, radius = (s.body or 3) * 0.55 + 1.2, size = 0.6, height = 1 }, V(0, centerY - (s.float or 0), 0))
	end

	local body = model:FindFirstChild("Body")
	if body then
		if s.glow then
			light(body, s.glow, 10, 1)
		end
		local kind = s.particles
		if kind == "embers" then
			emitter(body, "Embers", Color3.fromRGB(255, 160, 60), { Rate = 8, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = NumberRange.new(2, 4) })
		elseif kind == "stardust" then
			emitter(body, "Stardust", Color3.fromRGB(190, 220, 255), { Rate = 8, Size = NumberSequence.new(0.2, 0) })
		elseif kind == "lightdust" then
			emitter(body, "LightDust", Color3.fromRGB(255, 235, 170), {
				Rate = 8, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40),
				Speed = NumberRange.new(0.5, 1.2), Lifetime = NumberRange.new(1.2, 2), Size = NumberSequence.new(0.22, 0),
			})
		elseif kind == "sparkle" then
			emitter(body, "Sparkle", ctx.c2, { Rate = 8 })
		elseif kind == "lightning" then
			emitter(body, "Lightning", Color3.fromRGB(255, 240, 120), { Rate = 4, Speed = NumberRange.new(6, 9), Lifetime = NumberRange.new(0.12, 0.2), Size = NumberSequence.new(0.6, 0.1) })
		end
	end
	for _, tag in ipairs(s.tags or {}) do
		CollectionService:AddTag(model, tag)
	end
	if s.tags and table.find(s.tags, "AuroraCycle") then
		for _, p in ipairs(model:GetChildren()) do
			if p:GetAttribute("AuroraWing") then
				CollectionService:AddTag(p, "AuroraCycle")
				p:SetAttribute("Phase", math.random())
			end
		end
	end

	applyRarity(ctx, def)
	applyMutation(model, mutId)
	model:SetAttribute("Height", ctx.top)
	model:SetAttribute("FloatieId", def.id)
	model:SetAttribute("Mutation", mutId)
	addLabel(model, root, ctx.top)
	return model
end

-- Anchored = sits still (slot / conveyor). Unanchored = can be welded to something.
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
