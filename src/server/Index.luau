--[[
	Index (ModuleScript in ServerScriptService.Server)
	50 Floaties x 3 sizes x 8 mutations = 1,200 entries, like Anime Dice's
	size + mutation tabs. An entry counts the moment you roll it (even if it
	is sold right away; see Floaties.discover). Milestones (Config.IndexMilestones) give a reward
	and +2% Luck forever each (Economy reads data.indexClaimed).

	  Index.count(data) -> found, total
	Remote: ClaimIndex (fn) -> ok, msg   claims the next milestone you've reached
	Player attribute IndexReady = true while a milestone is waiting to be claimed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Floaties = require(script.Parent.Floaties)
local Grant = require(script.Parent.Grant)
local Sync = require(script.Parent.Sync)

local Index = {}

local TOTAL = #Config.Floaties * #Config.Forms * #Config.Mutations

function Index.count(data)
	local found = 0
	for _, def in ipairs(Config.Floaties) do
		for _, form in ipairs(Config.Forms) do
			for _, m in ipairs(Config.Mutations) do
				if data.index[Formulas.indexKey(def.id, m.id, form.id)] then
					found += 1
				end
			end
		end
	end
	return found, TOTAL
end

local function publish(player, prof)
	local found = Index.count(prof.data)
	local nextMilestone = Config.IndexMilestones[prof.data.indexClaimed + 1]
	player:SetAttribute("IndexFound", found)
	player:SetAttribute("IndexReady", nextMilestone ~= nil and found >= nextMilestone.count)
end

function Index.claim(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false, "Try again"
	end
	local data = prof.data
	local milestone = Config.IndexMilestones[data.indexClaimed + 1]
	if not milestone then
		return false, "You claimed every milestone! 🏆"
	end
	local found = Index.count(data)
	if found < milestone.count then
		return false, ("Find %d more to claim this one"):format(milestone.count - found)
	end
	data.indexClaimed += 1
	Sync.field(player, "indexClaimed")
	local given = Grant.give(player, milestone.reward)
	table.insert(given, ("+%d%% Luck forever"):format(math.floor(Config.IndexLuckPerMilestone * 100 + 0.5)))
	Core.StatsChanged:Fire(player) -- the Luck bonus
	publish(player, prof)
	Core.notify(player, "📖 Index " .. milestone.count .. ": " .. table.concat(given, " + "), "success")
	return true, table.concat(given, " + ")
end

Core.remote("ClaimIndex", "RemoteFunction").OnServerInvoke = function(player)
	if not Core.throttle(player, "claimIndex", 0.5) then
		return false, "Slow down!"
	end
	return Index.claim(player)
end

Floaties.Discovered:Connect(function(player)
	local prof = Core.getProfile(player)
	if prof then
		publish(player, prof)
	end
end)

Core.PlayerLoaded:Connect(function(player, prof)
	publish(player, prof)
end)

return Index
