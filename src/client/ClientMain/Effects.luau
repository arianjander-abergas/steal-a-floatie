--[[
	Floatie Farm — Effects (ModuleScript child of the ClientMain LocalScript)
	Client-side visuals that never touch gameplay:
	  • the "Pop" sound where a Floatie pops
	  • Rainbow Floaties cycling their colors (runs on each client, saves bandwidth)
	  • every Floatie bobbing and squishing like a real balloon (Config.Feel)
	  • the conveyor chevrons' light wave and the Tower's bobbing giant balloon
	  • pump machines: spinning fans, flickering storm light, drifting aurora colors
	  • a quick over-inflate wobble when a Floatie grows a size (its GrewAt attribute)
	  • blinking eyes, orbiting mini balloons, and the Secret / Cosmic tricks
	    (Glitch, Supernova, Prism, StormFlash tags from ConfigParts/Floaties)

	API:
	  Effects.start()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sounds = require(script.Parent.Sounds)

local Effects = {}

local started = false

---------------------------------------------------------------------
-- Pops happen on the server as a Part named "PopEffect": play the
-- sound where it happens
---------------------------------------------------------------------
local function startPops()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "PopEffect" and child:IsA("BasePart") then
			Sounds.play("Pop", child)
		end
	end)
end

---------------------------------------------------------------------
-- Rainbow Floaties: every 0.1 s, repaint each "Paint" part of every
-- RainbowFloatie model with a hue that drifts over time
---------------------------------------------------------------------
local function startRainbow()
	local rainbowAccum = 0
	RunService.RenderStepped:Connect(function(dt)
		rainbowAccum += dt
		if rainbowAccum < 0.1 then
			return
		end
		rainbowAccum = 0
		local hue = (os.clock() * 0.25) % 1
		for _, model in ipairs(CollectionService:GetTagged("RainbowFloatie")) do
			local i = 0
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") and p:GetAttribute("Paint") then
					i += 1
					p.Color = Color3.fromHSV((hue + i * 0.07) % 1, 0.7, 1)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Floatie feel: every Floatie bobs and squishes like a real balloon,
-- blinks, and plays its own trick (orbiting mini balloons, Glitchpup's
-- jitter, Supernovasaur's swell). Purely visual: it only changes each
-- part's SpecialMesh Offset/Scale, so it never fights the server over
-- where a Floatie is. Tune it in Config.Feel.
-- (Custom FloatieMeshes models have no SpecialMesh, so they stay still.)
---------------------------------------------------------------------
local Feel = Config.Feel
local feelCache = {} -- model -> { phase, active, nextBlink, glitch, supernova, parts = { { mesh, rel, orbit?, eye? } } }

local SUPERNOVA_EVERY = 4   -- seconds between Supernovasaur's bursts
local SUPERNOVA_TIME = 0.6

local function buildFeel(model)
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local rootCF = root.CFrame
	local parts = {}
	for _, part in ipairs(model:GetChildren()) do
		local mesh = part:IsA("BasePart") and part:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			local entry = { mesh = mesh, rel = rootCF:ToObjectSpace(part.CFrame) }
			local radius = part:GetAttribute("OrbitRadius")
			if radius then
				entry.orbit = {
					radius = radius, speed = part:GetAttribute("OrbitSpeed") or 1, phase = part:GetAttribute("OrbitPhase") or 0,
					tilt = CFrame.Angles(part:GetAttribute("OrbitTilt") or 0, 0, 0), tick = part:GetAttribute("OrbitTick") == true,
				}
			end
			entry.eye = string.sub(part.Name, 1, 3) == "Eye"
			table.insert(parts, entry)
		end
	end
	local pos = rootCF.Position
	return {
		phase = (pos.X * 0.37 + pos.Z * 0.61) % (math.pi * 2), active = false, parts = parts,
		nextBlink = os.clock() + math.random() * 4 + 1,
		glitch = CollectionService:HasTag(model, "Glitch"), supernova = CollectionService:HasTag(model, "Supernova"),
	}
end

-- how much a part's local axis v stretches when the model is scaled (sxz, sy, sxz)
local function axisScale(v, sy, sxz)
	return math.sqrt((sxz * v.X) ^ 2 + (sy * v.Y) ^ 2 + (sxz * v.Z) ^ 2)
end

-- stretch the model around its feet: sy = height factor, sxz = width factor, lift = bob.
-- t = os.clock() (nil = the rest pose: no orbit / blink / jitter)
local function applyFeel(info, sy, sxz, lift, t)
	local blink = 1
	if t then
		if t >= info.nextBlink then
			info.nextBlink = t + 2.2 + math.random() * 3.5
			info.blinkUntil = t + 0.13
		end
		if info.blinkUntil and t < info.blinkUntil then
			blink = 0.12
		end
	end
	for _, pt in ipairs(info.parts) do
		local rel = pt.rel
		local p = rel.Position
		local delta = Vector3.new(p.X * (sxz - 1), p.Y * (sy - 1) + lift, p.Z * (sxz - 1))
		if t and pt.orbit then
			local o = pt.orbit
			local angle = if o.tick then o.phase + math.floor(t * o.speed) * (math.pi / 6) else o.phase + t * o.speed
			local flat = Vector3.new(math.cos(angle) - math.cos(o.phase), 0, math.sin(angle) - math.sin(o.phase)) * o.radius
			delta += o.tilt:VectorToWorldSpace(flat)
		end
		if t and info.glitch and math.random() < 0.08 then
			delta += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.5
		end
		pt.mesh.Offset = rel:VectorToObjectSpace(delta)
		local scale = Vector3.new(axisScale(rel.XVector, sy, sxz), axisScale(rel.YVector, sy, sxz), axisScale(rel.ZVector, sy, sxz))
		if pt.eye and blink < 1 then
			scale = Vector3.new(scale.X, scale.Y * blink, scale.Z)
		end
		pt.mesh.Scale = scale
	end
end

local function watchFloatie(model)
	model.ChildAdded:Connect(function()
		feelCache[model] = nil -- rebuild once its parts finish arriving
	end)
end

local function startFeel()
	for _, model in ipairs(CollectionService:GetTagged("Floatie")) do
		watchFloatie(model)
	end
	CollectionService:GetInstanceAddedSignal("Floatie"):Connect(watchFloatie)
	CollectionService:GetInstanceRemovedSignal("Floatie"):Connect(function(model)
		feelCache[model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local camPos = workspace.CurrentCamera.CFrame.Position
		local t = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		for _, model in ipairs(CollectionService:GetTagged("Floatie")) do
			local root = model.PrimaryPart
			if root and model:IsDescendantOf(workspace) then
				local info = feelCache[model]
				if info == nil then
					info = buildFeel(model)
					feelCache[model] = info
				end
				if info then
					if (root.Position - camPos).Magnitude <= Feel.AnimDistance then
						local s = math.sin(t * Feel.SquishSpeed + info.phase) * Feel.SquishAmount
						local lift = Feel.BobHeight * (0.5 + 0.5 * math.sin(t * Feel.BobSpeed + info.phase))
						local grow = 1
						-- just grew a size (Level Up milestone): a quick over-inflate wobble
						local grewAt = model:GetAttribute("GrewAt")
						local age = if grewAt then serverNow - grewAt else math.huge
						if age >= 0 and age < 0.9 then
							local u = age / 0.9
							s += 0.3 * math.sin(u * math.pi * 2.5) * (1 - u)
						end
						-- Supernovasaur swells in a burst every few seconds
						if info.supernova then
							local u = ((t + info.phase) % SUPERNOVA_EVERY) / SUPERNOVA_TIME
							if u < 1 then
								grow = 1 + 0.22 * math.sin(u * math.pi)
							end
						end
						applyFeel(info, (1 + s) * grow, (1 - s * 0.5) * grow, lift, t)
						info.active = true
					elseif info.active then
						applyFeel(info, 1, 1, 0, nil)
						info.active = false
					end
				end
			end
		end
	end)

	-- lights and colors, 10 times a second: Supernova flash, Prism rainbow,
	-- storm flicker, Glitchpup's color splits
	local glitchColors = {} -- part -> its real color
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = os.clock()
			for _, model in ipairs(CollectionService:GetTagged("Supernova")) do
				local body = model:FindFirstChild("Body")
				local glow = body and body:FindFirstChild("Glow")
				if glow then
					local info = feelCache[model]
					local u = ((t + (if info then info.phase else 0)) % SUPERNOVA_EVERY) / SUPERNOVA_TIME
					glow.Brightness = if u < 1 then 1 + 7 * math.sin(u * math.pi) else 1
					glow.Range = if u < 1 then 18 else 10
				end
			end
			for _, model in ipairs(CollectionService:GetTagged("Prism")) do
				local body = model:FindFirstChild("Body")
				local glow = body and body:FindFirstChild("Glow")
				if glow then
					glow.Color = Color3.fromHSV((t * 0.2) % 1, 0.6, 1)
				end
			end
			for _, model in ipairs(CollectionService:GetTagged("StormFlash")) do
				local body = model:FindFirstChild("Body")
				local glow = body and body:FindFirstChild("Glow")
				if glow then
					local n = math.noise(t * 4, model:GetPivot().Position.X)
					glow.Enabled = n > -0.1
					glow.Brightness = if n > 0.35 then 5 else 1.2
				end
			end
			for _, model in ipairs(CollectionService:GetTagged("Glitch")) do
				for _, p in ipairs(model:GetChildren()) do
					if p:IsA("BasePart") and p:GetAttribute("Paint") then
						if glitchColors[p] == nil then
							glitchColors[p] = p.Color
						end
						if math.random() < 0.12 then
							p.Color = if math.random() < 0.5 then Color3.fromRGB(255, 40, 200) else Color3.fromRGB(40, 255, 240)
						else
							p.Color = glitchColors[p]
						end
					end
				end
			end
			for p in pairs(glitchColors) do
				if not p.Parent then
					glitchColors[p] = nil
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- The map: conveyor chevrons light up in a wave running towards the
-- front of each base, and the giant balloon on the Tower bobs.
-- Client-side only (nothing replicates), and only near the camera.
---------------------------------------------------------------------
local CHEVRON_DISTANCE = 220
local BOB_HEIGHT = 1.6

local function startMap()
	local bobParts = {} -- part -> resting CFrame
	local function trackBob(p)
		if p:IsA("BasePart") then
			bobParts[p] = p.CFrame
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("BobPart")) do
		trackBob(p)
	end
	CollectionService:GetInstanceAddedSignal("BobPart"):Connect(trackBob)
	CollectionService:GetInstanceRemovedSignal("BobPart"):Connect(function(p)
		bobParts[p] = nil
	end)

	local accum = 0
	local aurora = {
		Color3.fromRGB(120, 255, 200), Color3.fromRGB(90, 200, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 255, 200),
	}
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camPos = workspace.CurrentCamera.CFrame.Position
		-- pump machines: jet fans spin, storm light flickers, aurora ribbons drift
		for _, p in ipairs(CollectionService:GetTagged("Spin")) do
			if p:IsA("BasePart") and (p.Position - camPos).Magnitude < CHEVRON_DISTANCE then
				p.CFrame *= CFrame.Angles(dt * 9, 0, 0)
			end
		end
		for _, p in ipairs(CollectionService:GetTagged("Flicker")) do
			local light = p:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = math.noise(t * 6, p.Position.X) > 0.05
			end
		end
		for _, p in ipairs(CollectionService:GetTagged("AuroraCycle")) do
			if p:IsA("BasePart") then
				local x = ((t * 0.15 + (p:GetAttribute("Phase") or 0)) % 1) * 3
				local i = math.floor(x)
				p.Color = aurora[i + 1]:Lerp(aurora[i + 2], x - i)
			end
		end
		for p, rest in pairs(bobParts) do
			if p.Parent then
				p.CFrame = rest * CFrame.new(0, math.sin(t * 0.7) * BOB_HEIGHT, 0) * CFrame.Angles(0, math.sin(t * 0.3) * 0.08, 0)
			else
				bobParts[p] = nil
			end
		end
		accum += dt
		if accum < 1 / 20 then
			return
		end
		accum = 0
		for _, arm in ipairs(CollectionService:GetTagged("Chevron")) do
			if (arm.Position - camPos).Magnitude < CHEVRON_DISTANCE then
				local step = arm:GetAttribute("Step") or 0
				local wave = 0.5 + 0.5 * math.sin(t * 5 - step * 0.75)
				arm.Transparency = 0.75 - wave * 0.7
			end
		end
	end)
end

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------

-- Effects.start()
function Effects.start()
	if started then
		return
	end
	started = true
	startPops()
	startRainbow()
	startFeel()
	startMap()
end

return Effects
