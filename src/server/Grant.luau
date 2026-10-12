--[[
	Grant (ModuleScript in ServerScriptService.Server)
	Gives a reward table (see the top of ConfigParts/Rewards) to a player:
	Air, minutes of income, tokens, gems, Jackpot Rolls, potions and Floaties.
	Daily / Playtime rewards, codes, Index milestones, offers and Robux
	products all go through here.

	  Grant.give(player, reward) -> { "what was given", ... }
	  Grant.pickFloatie(spec) -> Floatie def   (spec = { id } or { rarity, orBetter?, upgradeChance?, upgradeTo? })
	  Grant.randomMutation() -> "Silver" / "Gold" / ... (weighted: Silver is by far the most likely)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RewardInfo = require(Shared:WaitForChild("RewardInfo"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)
local Floaties = require(script.Parent.Floaties)
local Sync = require(script.Parent.Sync)

local Grant = {}

-- a random Floatie of one rarity, commoner ones more likely (weight 1 / odds)
local function randomOfRarity(rarity)
	local pool, total = {}, 0
	for _, def in ipairs(Config.Floaties) do
		if def.rarity == rarity then
			table.insert(pool, def)
			total += 1 / def.odds
		end
	end
	if #pool == 0 then
		return nil
	end
	local roll = Core.rng:NextNumber() * total
	for _, def in ipairs(pool) do
		roll -= 1 / def.odds
		if roll <= 0 then
			return def
		end
	end
	return pool[#pool]
end

-- the next rarity up that has Floaties in it (nil at the top)
local function rarityAbove(rarity)
	local order = Config.Rarities[rarity].order
	for i = order + 1, #Config.RarityOrder do
		local name = Config.RarityOrder[i]
		for _, def in ipairs(Config.Floaties) do
			if def.rarity == name then
				return name
			end
		end
	end
	return nil
end

function Grant.pickFloatie(spec)
	if spec.id then
		return Config.FloatieById[spec.id]
	end
	local rarity = spec.rarity
	if spec.upgradeTo and Core.rng:NextNumber() < (spec.upgradeChance or 0) then
		rarity = spec.upgradeTo
	elseif spec.orBetter then
		-- "Rare+": 25% chance to step up a rarity, then 20% for another step
		local above = rarityAbove(rarity)
		if above and Core.rng:NextNumber() < 0.25 then
			rarity = above
			local twoUp = rarityAbove(rarity)
			if twoUp and Core.rng:NextNumber() < 0.20 then
				rarity = twoUp
			end
		end
	end
	return randomOfRarity(rarity) or randomOfRarity(spec.rarity)
end

-- a guaranteed mutation (never Normal or event-only), rarer ones less likely (weight 1 / odds)
function Grant.randomMutation()
	local pool, total = {}, 0
	for _, m in ipairs(Config.Mutations) do
		if m.id ~= "Normal" and not m.eventOnly then
			table.insert(pool, m)
			total += 1 / m.odds
		end
	end
	local roll = Core.rng:NextNumber() * total
	for _, m in ipairs(pool) do
		roll -= 1 / m.odds
		if roll <= 0 then
			return m.id
		end
	end
	return pool[1].id
end

function Grant.give(player, reward)
	local prof = Core.getProfile(player)
	if not prof or not reward then
		return {}
	end
	local data = prof.data
	local given = {}
	local air = reward.air or 0
	if reward.incomeMinutes then
		air += math.max(reward.minAir or 0, (prof.incomePerSec or 0) * 60 * reward.incomeMinutes)
	end
	if air > 0 then
		Economy.addAir(player, math.floor(air))
		table.insert(given, Config.Format(air) .. " Air")
	end
	local items = data.items
	if reward.gradeTokens then
		items.gradeTokens += reward.gradeTokens
	end
	if reward.traitGems then
		items.traitGems += reward.traitGems
	end
	if reward.jackpotRolls then
		items.jackpotRolls += reward.jackpotRolls
	end
	if reward.potions then
		for kind, n in pairs(reward.potions) do
			if items.potions[kind] then
				items.potions[kind] += n
			end
		end
	end
	if reward.gradeTokens or reward.traitGems or reward.jackpotRolls or reward.potions then
		Sync.field(player, "items")
		for _, line in ipairs(RewardInfo.lines({
			gradeTokens = reward.gradeTokens, traitGems = reward.traitGems,
			jackpotRolls = reward.jackpotRolls, potions = reward.potions,
		})) do
			table.insert(given, line)
		end
	end
	if reward.floatie then
		local def = Grant.pickFloatie(reward.floatie)
		if def then
			local mut = reward.mutation
			if mut == "random" then
				mut = Grant.randomMutation()
			end
			local f, dest = Floaties.add(player, { id = def.id, mut = mut }, { noAutoSell = true })
			local label = (if mut and mut ~= "Normal" then mut .. " " else "") .. def.name
			if f then
				table.insert(given, label .. (if dest == "backpack" then " (in your Backpack)" else ""))
			else
				table.insert(given, label .. " (no room: sold for Air)")
			end
		end
	end
	return given
end

return Grant
