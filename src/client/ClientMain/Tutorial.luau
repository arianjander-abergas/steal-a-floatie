--[[
	Floatie Farm — Tutorial (ModuleScript child of the ClientMain LocalScript)
	For brand-new players (the server sets ShowTutorial): a big
	"[Tutorial]: ..." line above the roll buttons (like the reference games)
	and a bouncing arrow over the button to press.

	Steps: roll once -> roll 4 more -> turn on Auto -> get the Foot Pump ->
	open Upgrades. Each step also moves on by itself after a while, so
	nobody gets stuck.

	API:
	  Tutorial.mount(canvas, findTarget)  -- findTarget(name) -> GuiObject | nil
	                                      -- names: "Roll", "Auto", "Pump", "Upgrades"
	  Tutorial.update()                   -- init calls this every 0.2 s
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)

local player = Players.LocalPlayer
local C = Config.UI

local Tutorial = {}

local STEPS = {
	{ text = "PRESS ROLL TO PUMP YOUR FIRST FLOATIE!", target = "Roll", timeout = nil,
		done = function() return (player:GetAttribute("TotalRolls") or 0) >= 1 end },
	{ text = "IT RIDES YOUR CONVEYOR TO A SLOT! ROLL 4 MORE", target = "Roll", timeout = 90,
		done = function() return (player:GetAttribute("TotalRolls") or 0) >= 5 end },
	{ text = "TURN ON AUTO TO KEEP ROLLING BY ITSELF", target = "Auto", timeout = 60,
		done = function() return player:GetAttribute("AutoRoll") == true end },
	{ text = "FLOATIES EARN AIR! GET THE FOOT PUMP FOR 2x LUCK", target = "Pump", timeout = 150,
		done = function() return (player:GetAttribute("PumpLuck") or 1) >= 2 end },
	{ text = "OPEN UPGRADES FOR MORE SLOTS AND LUCK", target = "Upgrades", timeout = 25,
		done = function() return false end },
}

local canvas = nil
local findTarget = nil
local line = nil
local arrow = nil
local step = 0          -- 0 = not started, #STEPS + 1 = finished
local stepStarted = 0

local function setStep(n)
	step = n
	stepStarted = os.clock()
	if n > #STEPS then
		line.Visible = false
		arrow.Visible = false
		Notify.toast("Tutorial done! Chase rarer Floaties and fill your Index 🎈", "success")
		return
	end
	line.Text = '<font color="#78ff8c">[Tutorial]:</font> ' .. STEPS[n].text
end

function Tutorial.mount(hudCanvas, finder)
	if line then
		return
	end
	canvas = hudCanvas
	findTarget = finder
	line = Kit.label(hudCanvas, {
		Name = "TutorialLine", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(560, 30), RichText = true, Visible = false,
	}, { outline = 3, maxTextSize = 26 })
	arrow = Kit.label(hudCanvas, {
		Name = "TutorialArrow", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(44, 44),
		Text = "⬇", TextColor3 = C.TutorialArrow, Visible = false, ZIndex = 20,
	}, { outline = 3 })
end

-- canvas position just above `target`, in the canvas's own (unscaled) px
local function pointAt(target)
	local scale = Kit.getScale()
	local origin = canvas.AbsolutePosition
	local pos = (target.AbsolutePosition - origin) / scale
	local size = target.AbsoluteSize / scale
	local bounce = math.abs(math.sin(os.clock() * 5)) * 8
	return UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 2 - bounce)
end

function Tutorial.update()
	if not line then
		return
	end
	if step == 0 then
		if player:GetAttribute("ShowTutorial") and player:GetAttribute("Loaded") then
			setStep(1)
		else
			return
		end
	end
	if step > #STEPS then
		return
	end
	local s = STEPS[step]
	if s.done() or (s.timeout and os.clock() - stepStarted > s.timeout) then
		setStep(step + 1)
		return
	end
	line.Visible = true
	local target = findTarget and findTarget(s.target)
	if target and target.Visible and target.AbsoluteSize.X > 0 then
		arrow.Visible = true
		arrow.Position = pointAt(target)
	else
		arrow.Visible = false
	end
end

-- the arrow bounces smoothly between the slow loop's updates
task.spawn(function()
	while true do
		task.wait(1 / 30)
		if arrow and arrow.Visible and step >= 1 and step <= #STEPS then
			local target = findTarget and findTarget(STEPS[step].target)
			if target then
				arrow.Position = pointAt(target)
			end
		end
	end
end)

return Tutorial
