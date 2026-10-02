--[[
	Steal a Floatie — Tutorial (ModuleScript child of the ClientMain LocalScript)
	For brand-new players (the server sets ShowTutorial): a yellow hint box
	under the top bar, plus a yellow line and a "⬇" arrow in the world
	pointing where to go.
	Steps: buy -> steal -> run home -> defend.

	API:
	  Tutorial.mount(topStack)   -- adds the "TutorialBox" (LayoutOrder 3) to the HUD's TopStack,
	                             -- then waits for workspace.Map.Bases
	  Tutorial.update()          -- init calls this every 0.2 s
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)

local player = Players.LocalPlayer
local C = Config.UI

local STEP_TEXT = {
	"Step 1/4: Follow the yellow line to the Pump Line and press E to BUY a Floatie!",
	"Step 2/4: Your Floaties earn Air and inflate. Now sneak into another base and HOLD E to STEAL one!",
	"Step 3/4: RUN back to your base before they POP it with darts!",
	"Step 4/4: Defend! Press 1 for your Dart Blaster and click thieves. Press E on your red button to LOCK your base.",
}

local Tutorial = {}

local basesFolder = nil -- workspace.Map.Bases (nil until mount finds it)
local tutorialBox, tutorialText = nil, nil
local targetPart, beam = nil, nil
local tutorialStep = 0  -- 0 = not started, #STEP_TEXT + 1 = done
local stepStarted = 0

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function setStep(n)
	tutorialStep = n
	stepStarted = os.clock()
	if n > #STEP_TEXT then
		tutorialBox.Visible = false
		targetPart.Parent = nil
		Notify.toast("Tutorial done! Catch rare Floaties and let them grow to MEGA 🎈", "success")
	end
end

local function baseFolderOf(index)
	return basesFolder:FindFirstChild("Base" .. tostring(index))
end

-- the floor of the closest base someone else owns (nil if you're alone)
local function nearestOtherBase(fromPos)
	local best, bestDist = nil, math.huge
	for _, b in ipairs(basesFolder:GetChildren()) do
		local owner = b:GetAttribute("OwnerUserId") or 0
		local floor = b:FindFirstChild("Floor")
		if owner ~= 0 and owner ~= player.UserId and floor then
			local d = (floor.Position - fromPos).Magnitude
			if d < bestDist then
				best, bestDist = floor.Position, d
			end
		end
	end
	return best
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------

-- Tutorial.mount(topStack) — builds the (hidden) box and the world
-- marker, then waits for the map, so init calls it last
function Tutorial.mount(topStack)
	if tutorialBox then
		return
	end
	tutorialBox = Kit.plate(topStack, {
		Name = "TutorialBox", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 50), Visible = false,
	}, { color = C.TutorialBox, transparency = 0, radius = 12 })
	tutorialText = Kit.label(tutorialBox, {
		Name = "Text", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8),
		TextColor3 = C.TextDark, TextWrapped = true,
	}, { outline = 0, maxTextSize = 18 })

	-- the world marker: an invisible part with the arrow above it; the beam
	-- runs from your HumanoidRootPart to it. Parented to workspace only
	-- while there is somewhere to point.
	targetPart = Kit.make("Part", {
		Name = "TutorialTarget", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(1, 1, 1),
	}, nil)
	local targetAtt = Kit.make("Attachment", { Name = "Target" }, targetPart)
	local arrowGui = Kit.make("BillboardGui", {
		Size = UDim2.fromOffset(80, 80), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true,
	}, targetPart)
	Kit.label(arrowGui, { Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = C.TutorialArrow }, { outline = 3 })
	beam = Kit.make("Beam", {
		Attachment1 = targetAtt, Color = ColorSequence.new(C.TutorialArrow),
		Width0 = 0.5, Width1 = 0.5, FaceCamera = true, LightEmission = 1, Segments = 1,
		Transparency = NumberSequence.new(0.25),
	}, targetPart)

	basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
end

---------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------

-- Tutorial.update() — moves through the steps and points the line
function Tutorial.update()
	if not basesFolder then
		return
	end
	if tutorialStep == 0 then
		if player:GetAttribute("ShowTutorial") then
			setStep(1)
		else
			return
		end
	end
	if tutorialStep > #STEP_TEXT then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local elapsed = os.clock() - stepStarted
	local carrying = player:GetAttribute("CarryEndsAt") ~= nil
	local myBase = baseFolderOf(player:GetAttribute("BaseIndex"))
	local target = nil
	local text = STEP_TEXT[tutorialStep]

	if tutorialStep == 1 then
		-- done once you own a Floatie that earns Air
		if (player:GetAttribute("IncomePerSec") or 0) > 0 then
			setStep(2)
			return
		end
		-- the Pump Line runs along Z at X = 0: point at the spot beside you
		target = Vector3.new(0, 2, math.clamp(hrp.Position.Z, -140, 140))
	elseif tutorialStep == 2 then
		if carrying then
			setStep(3)
			return
		end
		if elapsed > 45 then
			setStep(4)
			return
		end
		target = nearestOtherBase(hrp.Position)
		if not target then
			text ..= " (Nobody else here yet — skipping soon.)"
		end
	elseif tutorialStep == 3 then
		if not carrying then
			setStep(4)
			return
		end
		local floor = myBase and myBase:FindFirstChild("Floor")
		target = floor and floor.Position
	elseif tutorialStep == 4 then
		if elapsed > 14 then
			setStep(5)
			return
		end
		local btn = myBase and myBase:FindFirstChild("LockButton")
		target = btn and btn.Position
	end

	tutorialBox.Visible = true
	tutorialText.Text = text
	if target then
		targetPart.Position = target
		targetPart.Parent = workspace
		local att = hrp:FindFirstChild("TutorialAtt") or Kit.make("Attachment", { Name = "TutorialAtt" }, hrp)
		beam.Attachment0 = att
	else
		targetPart.Parent = nil
	end
end

return Tutorial
