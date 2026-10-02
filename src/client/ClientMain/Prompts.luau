--[[
	Steal a Floatie — Prompts (ModuleScript child of the ClientMain LocalScript)
	Prompt visibility: you only see Steal on other players' bases, and
	Sell / Lock on your own. The server checks everything again; this just
	hides prompts that would do nothing for you.

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

-- Prompts.update() — enables / disables every Steal, Sell and Lock prompt
function Prompts.update()
	if not basesFolder then
		return
	end
	local t = workspace:GetServerTimeNow()
	local carrying = player:GetAttribute("CarryEndsAt") ~= nil
	for _, ped in ipairs(CollectionService:GetTagged("Pedestal")) do
		local baseFolder = basesFolder:FindFirstChild("Base" .. tostring(ped:GetAttribute("BaseIndex")))
		local steal = ped:FindFirstChild("StealPrompt")
		local sell = ped:FindFirstChild("SellPrompt")
		if baseFolder and steal and sell then
			local owner = baseFolder:GetAttribute("OwnerUserId") or 0
			local has = ped:GetAttribute("HasFloatie") == true and ped:GetAttribute("Unlocked") == true
			local mine = owner == player.UserId
			local locked = (baseFolder:GetAttribute("LockedUntil") or 0) > t
			steal.Enabled = has and not mine and owner ~= 0 and not locked and not carrying
			sell.Enabled = has and mine
		end
	end
	for _, btn in ipairs(CollectionService:GetTagged("LockButton")) do
		local baseFolder = basesFolder:FindFirstChild("Base" .. tostring(btn:GetAttribute("BaseIndex")))
		local pr = btn:FindFirstChild("LockPrompt")
		if baseFolder and pr then
			pr.Enabled = baseFolder:GetAttribute("OwnerUserId") == player.UserId
		end
	end
end

return Prompts
