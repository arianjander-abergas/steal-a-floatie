--[[
	Steal a Floatie — Effects (ModuleScript child of the ClientMain LocalScript)
	Client-side visuals that never touch gameplay:
	  • the "Pop" sound where a Floatie pops
	  • Rainbow Floaties cycling their colors (runs on each client, saves bandwidth)
	  • every Floatie bobbing and squishing like a real balloon (Config.Feel)
	  • the conveyor chevrons' light wave and the Tower's bobbing giant balloon

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
-- Floatie feel: every Floatie bobs and squishes like a real balloon.
-- Purely visual: it only changes each part's SpecialMesh Offset/Scale, so it
-- never fights the server over where a Floatie is. Tune it in Config.Feel.
-- (Custom FloatieMeshes models have no SpecialMesh, so they stay still.)
---------------------------------------------------------------------
local Feel = Config.Feel
local feelCache = {} -- model -> { phase, active, parts = { { mesh, rel } } }

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
			table.insert(parts, { mesh = mesh, rel = rootCF:ToObjectSpace(part.CFrame) })
		end
	end
	local pos = rootCF.Position
	return { phase = (pos.X * 0.37 + pos.Z * 0.61) % (math.pi * 2), active = false, parts = parts }
end

-- how much a part's local axis v stretches when the model is scaled (sxz, sy, sxz)
local function axisScale(v, sy, sxz)
	return math.sqrt((sxz * v.X) ^ 2 + (sy * v.Y) ^ 2 + (sxz * v.Z) ^ 2)
end

-- stretch the model around its feet: sy = height factor, sxz = width factor, lift = bob
local function applyFeel(info, sy, sxz, lift)
	for _, pt in ipairs(info.parts) do
		local rel = pt.rel
		local p = rel.Position
		local delta = Vector3.new(p.X * (sxz - 1), p.Y * (sy - 1) + lift, p.Z * (sxz - 1))
		pt.mesh.Offset = rel:VectorToObjectSpace(delta)
		pt.mesh.Scale = Vector3.new(axisScale(rel.XVector, sy, sxz), axisScale(rel.YVector, sy, sxz), axisScale(rel.ZVector, sy, sxz))
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
						applyFeel(info, 1 + s, 1 - s * 0.5, lift)
						info.active = true
					elseif info.active then
						applyFeel(info, 1, 1, 0)
						info.active = false
					end
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
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
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
		local camPos = workspace.CurrentCamera.CFrame.Position
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
