--[[
	Floatie Farm — Prompts (ModuleScript child of the ClientMain LocalScript)
	Prompt visibility: prompts that belong to a base (like the one on each of
	your Floaties) only show for that base's owner. The server checks
	everything again; this just hides prompts that would do nothing for you.

	API:
	  Prompts.start()    -- waits for workspace.Map.Bases
	  Prompts.update()   -- init calls this every 0.2 s (does nothing before start)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

local Prompts = {}

local basesFolder = nil -- workspace.Map.Bases (nil until start finds it)

-- Prompts.start() — waits for the map the server builds
function Prompts.start()
	basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
end

-- Prompts.update() — owner-only prompts (tagged "OwnerPrompt", with an
-- OwnerUserId attribute on the prompt or one of its ancestors)
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
