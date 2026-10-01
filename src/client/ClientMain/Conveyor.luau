--[[
	Floatie Farm — Conveyor (ModuleScript child of the ClientMain LocalScript)
	The world side of rolling, drawn on each client (nothing here replicates):
	  • PumpPuff: a balloon inflates at a base's nozzle for the inflate time,
	    then pops
	  • ConveyorRide: the new Floatie rides that base's belt to its row, then
	    hops over to its slot (where the server's real model appears as it
	    lands). Floaties for the Backpack ride to the end of the belt and
	    vanish into it; sold ones pop into Air.
	Bases far from the camera are skipped.

	API:
	  Conveyor.start()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
local Sounds = require(script.Parent.Sounds)

local Conveyor = {}

local DRAW_DISTANCE = 260   -- skip rides / puffs further than this from the camera
local HOP_HEIGHT = 3

local started = false
local ridesFolder = nil
local rides = {}            -- active rides
local puffs = {}            -- [baseIndex] = active puff
local templates = {}        -- "id|mut" -> Model (label removed)

local BALLOON_COLORS = {
	Color3.fromRGB(255, 90, 150), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(120, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 150, 70),
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function baseFolder(index)
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	return bases and bases:FindFirstChild("Base" .. tostring(index))
end

local function nearCamera(pos)
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < DRAW_DISTANCE
end

local function template(id, mut)
	local key = id .. "|" .. mut
	local t = templates[key]
	if t == nil then
		local def = Config.FloatieById[id]
		t = false
		if def then
			local ok, model = pcall(FloatieModel.Build, def, mut, 1)
			if ok then
				FloatieModel.SetAnchored(model, true)
				local label = model.PrimaryPart:FindFirstChild("Label")
				if label then
					label:Destroy()
				end
				model:RemoveTag("Floatie") -- rides don't wobble (they hop)
				for _, p in ipairs(model:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanQuery = false
					end
				end
				t = model
			end
		end
		templates[key] = t
	end
	return t or nil
end

-- a short burst of confetti + optional text at `pos` (client only)
local function burst(pos, color, text, textColor)
	local p = Instance.new("Part")
	p.Name = "RideBurst"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = ridesFolder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Speed = NumberRange.new(10, 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Size = NumberSequence.new(0.5, 0)
	e.Drag = 4
	e.Parent = p
	e:Emit(26)
	if text then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = true
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = textColor or Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Parent = gui
		task.spawn(function()
			for i = 1, 20 do
				gui.StudsOffset = Vector3.new(0, 2 + i * 0.12, 0)
				t.TextTransparency = math.max(0, (i - 10) / 10)
				t.TextStrokeTransparency = t.TextTransparency
				task.wait(0.05)
			end
		end)
	end
	Debris:AddItem(p, 1.4)
end

---------------------------------------------------------------------
-- Pump puffs
---------------------------------------------------------------------
local function onPuff(baseIndex, inflateTime)
	local folder = baseFolder(baseIndex)
	local nozzle = folder and folder:FindFirstChild("Nozzle")
	if not nozzle or not nearCamera(nozzle.Position) then
		return
	end
	local old = puffs[baseIndex]
	if old and old.part.Parent then
		old.part:Destroy()
	end
	local color = BALLOON_COLORS[math.random(1, #BALLOON_COLORS)]
	local ball = Instance.new("Part")
	ball.Name = "PumpBalloon"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.SmoothPlastic
	ball.Reflectance = 0.2
	ball.Color = color
	ball.Size = Vector3.new(0.6, 0.6, 0.6)
	ball.CFrame = nozzle.CFrame
	ball.Parent = ridesFolder
	puffs[baseIndex] = { part = ball, start = os.clock(), duration = math.max(0.2, inflateTime), origin = nozzle.CFrame, color = color }
	if (workspace.CurrentCamera.CFrame.Position - nozzle.Position).Magnitude < 70 then
		Sounds.play("Inflate", nozzle)
	end
end

local function stepPuffs(now)
	for index, puff in pairs(puffs) do
		local a = (now - puff.start) / puff.duration
		if a >= 1 or not puff.part.Parent then
			if puff.part.Parent then
				burst(puff.part.Position, puff.color)
				if (workspace.CurrentCamera.CFrame.Position - puff.part.Position).Magnitude < 70 then
					Sounds.play("Pop", puff.part)
				end
				puff.part:Destroy()
			end
			puffs[index] = nil
		else
			-- grows fast, then slows; wobbles a little as it fills
			local eased = 1 - (1 - a) ^ 2
			local d = 0.6 + eased * 4.2
			local wobble = math.sin(now * 18) * 0.08 * d
			puff.part.Size = Vector3.new(d + wobble, d * 1.12 - wobble, d + wobble)
			puff.part.CFrame = puff.origin * CFrame.new(0, d * 0.45, 0)
		end
	end
end

---------------------------------------------------------------------
-- Rides
---------------------------------------------------------------------
-- facing along `dir` (models point their head along +X)
local function facing(pos, dir)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)) * CFrame.Angles(0, math.pi / 2, 0)
end

local function onRide(info)
	local folder = baseFolder(info.base)
	local startPart = folder and folder:FindFirstChild("ConveyorStart")
	local endPart = folder and folder:FindFirstChild("ConveyorEnd")
	if not startPart or not endPart or not nearCamera(startPart.Position) then
		return
	end
	local proto = template(info.id, info.mut or "Normal")
	if not proto then
		return
	end
	local beltStart = startPart.Position + Vector3.new(0, 0.3, 0)
	local beltEnd = endPart.Position + Vector3.new(0, 0.3, 0)
	local dir = (beltEnd - beltStart).Unit
	local stop = beltEnd
	local padTop = nil
	local slots = folder:FindFirstChild("Slots")
	local pad = info.slot and slots and slots:FindFirstChild("Slot" .. tostring(info.slot))
	if pad then
		local along = math.clamp((pad.Position - beltStart):Dot(dir), 0, (beltEnd - beltStart).Magnitude)
		stop = beltStart + dir * along
		padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	end
	local model = proto:Clone()
	model:PivotTo(facing(beltStart, dir))
	model.Parent = ridesFolder
	table.insert(rides, {
		model = model, start = os.clock(), ride = math.max(0.1, info.ride or 1), walk = info.walk or 0,
		beltStart = beltStart, stop = stop, dir = dir, padTop = padTop, dest = info.dest, soldFor = info.soldFor,
		color = Config.FloatieById[info.id] and Config.FloatieById[info.id].color or Color3.new(1, 1, 1),
	})
end

local function finishRide(r)
	local pos = r.model:GetPivot().Position
	if r.dest == "sold" then
		burst(pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 210, 60), "+" .. Config.Format(r.soldFor or 0) .. " Air", Color3.fromRGB(120, 255, 140))
	elseif r.dest == "backpack" then
		burst(pos + Vector3.new(0, 2, 0), r.color, "🎒 Backpack")
	end
	r.model:Destroy()
end

local function stepRides(now)
	for i = #rides, 1, -1 do
		local r = rides[i]
		local t = now - r.start
		if not r.model.Parent then
			table.remove(rides, i)
		elseif t >= r.ride + r.walk then
			finishRide(r)
			table.remove(rides, i)
		elseif t < r.ride then
			-- riding the belt, with a little bounce
			local a = t / r.ride
			local pos = r.beltStart:Lerp(r.stop, a) + Vector3.new(0, math.abs(math.sin(t * 7)) * 0.25, 0)
			r.model:PivotTo(facing(pos, r.dir))
		elseif r.padTop then
			-- hopping off to the slot, then turning to face the entrance
			local a = math.clamp((t - r.ride) / math.max(r.walk, 0.05), 0, 1)
			local flat = r.stop:Lerp(r.padTop, a)
			local hops = math.max(1, math.floor(r.walk * 2.2))
			local height = math.abs(math.sin(a * math.pi * hops)) * HOP_HEIGHT * (1 - a * 0.4)
			local toward = r.padTop - r.stop
			local look = if a > 0.85 then r.dir else toward
			r.model:PivotTo(facing(flat + Vector3.new(0, height, 0), look))
		end
	end
end

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------
function Conveyor.start()
	if started then
		return
	end
	started = true
	ridesFolder = Instance.new("Folder")
	ridesFolder.Name = "ClientRides"
	ridesFolder.Parent = workspace
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("PumpPuff").OnClientEvent:Connect(onPuff)
	remotes:WaitForChild("ConveyorRide").OnClientEvent:Connect(onRide)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		stepPuffs(now)
		stepRides(now)
	end)
end

return Conveyor
