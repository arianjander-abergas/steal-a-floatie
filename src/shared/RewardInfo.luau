--[[
	RewardInfo (ModuleScript in ReplicatedStorage.Shared)
	Turns a reward table (see the top of ConfigParts/Rewards) into words and
	an icon, for reward tiles, offer cards and toasts. The server's Grant
	module gives the reward; this only describes it.

	  RewardInfo.lines(reward) -> { "10 min of income", "Luck Potion x2", ... }
	  RewardInfo.text(reward)  -> "10 min of income + Luck Potion x2"
	  RewardInfo.icon(reward)  -> "💨"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local RewardInfo = {}

local function times(n)
	return if n and n > 1 then " x" .. n else ""
end

function RewardInfo.lines(reward)
	local lines = {}
	if not reward then
		return lines
	end
	if reward.floatie then
		local spec = reward.floatie
		local what
		if spec.id then
			local def = Config.FloatieById[spec.id]
			what = if def then def.name else spec.id
		elseif spec.upgradeTo then
			what = spec.rarity .. " or " .. spec.upgradeTo .. " Floatie"
		else
			what = spec.rarity .. (if spec.orBetter then "+" else "") .. " Floatie"
		end
		if reward.mutation == "random" then
			what ..= " (mutated)"
		elseif reward.mutation and reward.mutation ~= "Normal" then
			what = reward.mutation .. " " .. what
		end
		table.insert(lines, what)
	end
	if reward.air then
		table.insert(lines, Config.Format(reward.air) .. " Air")
	end
	if reward.incomeMinutes then
		table.insert(lines, reward.incomeMinutes .. " min of income")
	end
	for _, kind in ipairs(Config.PotionOrder) do
		local n = reward.potions and reward.potions[kind]
		if n and n > 0 then
			table.insert(lines, Config.Potions[kind].name .. times(n))
		end
	end
	if reward.gradeTokens then
		table.insert(lines, "Grade Token" .. times(reward.gradeTokens))
	end
	if reward.traitGems then
		table.insert(lines, "Trait Gem" .. times(reward.traitGems))
	end
	if reward.jackpotRolls then
		table.insert(lines, "Jackpot Roll" .. times(reward.jackpotRolls))
	end
	return lines
end

function RewardInfo.text(reward)
	if reward and reward.text then
		return reward.text
	end
	return table.concat(RewardInfo.lines(reward), " + ")
end

-- the icon of the reward's most exciting part
function RewardInfo.icon(reward)
	if not reward then
		return "🎁"
	end
	if reward.floatie then
		return "🎈"
	elseif reward.jackpotRolls then
		return "🎰"
	elseif reward.traitGems then
		return "💎"
	elseif reward.gradeTokens then
		return "🎫"
	elseif reward.potions then
		for _, kind in ipairs(Config.PotionOrder) do
			if (reward.potions[kind] or 0) > 0 then
				return Config.Potions[kind].icon
			end
		end
	end
	return "💨"
end

return RewardInfo
