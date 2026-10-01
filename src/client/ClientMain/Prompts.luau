--[[
	Floatie Farm — Prompts (ModuleScript child of the ClientMain LocalScript)
	  • Stall prompts (tag "StallPrompt", attribute Panel) open their window
	    right here on the client: no trip to the server needed.
	  • Owner-only prompts (tag "OwnerPrompt", with an OwnerUserId attribute
	    on the prompt or one of its ancestors) only show for that owner.
	The server checks everything again; this just hides prompts that would
	do nothing for you.

	API:
	  Prompts.start(actions)  -- actions.openPanel(name); waits for workspace.Map.Bases
	  Prompts.update()        -- init calls this every 0.2 s (does nothing before start)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local Prompts = {}

local basesFolder = nil -- workspace.Map.Bases (nil until start finds it)

-- Prompts.start(actions) — listens for stall prompts, then waits for the map
function Prompts.start(actions)
	actions = actions or {}
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, "StallPrompt") and actions.openPanel then
			actions.openPanel(prompt:GetAttribute("Panel"))
		end
	end)
	basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
end

-- Prompts.update() — owner-only prompts
function Prompts.update()
	if not basesFolder then
		return
	end
	for _, prompt in ipairs(CollectionService:GetTagged("OwnerPrompt")) do
		if prompt:IsA("ProximityPrompt") then
			local node, owner = prompt, nil
			while node and owner == nil do
				owner = node:GetAttribute("OwnerUserId")
				node = node.Parent
			end
			prompt.Enabled = owner == player.UserId
		end
	end
end

return Prompts
