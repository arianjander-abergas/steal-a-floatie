--[[
	Floatie Farm — Tutorial (ModuleScript child of the ClientMain LocalScript)
	For brand-new players (the server sets ShowTutorial): a yellow hint box
	under the top bar. The rolling tutorial arrives with rolling (Stage 4);
	until then it only says where your Floaties live.

	API:
	  Tutorial.mount(topStack)   -- adds the "TutorialBox" (LayoutOrder 3) to the HUD's TopStack
	  Tutorial.update()          -- init calls this every 0.2 s
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer
local C = Config.UI

local Tutorial = {}

local tutorialBox, tutorialText = nil, nil
local shownAt = nil

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
		Text = "Your Floaties stand on your base and earn Air every second, even while you're away!",
	}, { outline = 0, maxTextSize = 18 })
end

function Tutorial.update()
	if not tutorialBox then
		return
	end
	if player:GetAttribute("ShowTutorial") and not shownAt then
		shownAt = os.clock()
	end
	tutorialBox.Visible = shownAt ~= nil and os.clock() - shownAt < 12
end

return Tutorial
