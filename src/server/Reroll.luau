--[[
	Reroll (ModuleScript in ServerScriptService.Server)
	The Grading and Traits stands.
	  Grade: 1 Grade Token rerolls a Floatie's grade (C ... UR, Config.Grades).
	         The new grade can be lower than the old one.
	  Trait: 1 Trait Gem rerolls its trait (Config.Traits).
	  One Grade Token can be bought for Air at the Grading stand; the price
	  climbs with every token bought (Config.GradeTokenAir).

	Remotes: RerollGrade (fn, uid) -> ok, gradeId | msg
	         RerollTrait (fn, uid) -> ok, traitId | msg
	         BuyGradeToken (fn) -> ok, msg
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)
local Bases = require(script.Parent.Bases)
local Floaties = require(script.Parent.Floaties)
local Sync = require(script.Parent.Sync)

local Reroll = {}

-- weighted pick from a list of { chance = ... }
local function pick(list)
	local total = 0
	for _, entry in ipairs(list) do
		total += entry.chance
	end
	local roll = Core.rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry.chance
		if roll <= 0 then
			return entry
		end
	end
	return list[1]
end

local function changed(player, f)
	Sync.floatie(player, f)
	Bases.label(player, f, Bases.model(player, f.uid))
	Core.FloatiesChanged:Fire(player) -- income, Lucky / Breezy traits
end

function Reroll.grade(player, uid)
	local prof = Core.getProfile(player)
	local f = prof and Floaties.find(player, uid)
	if not f then
		return false, "Floatie not found"
	end
	if prof.data.items.gradeTokens < 1 then
		return false, "You need a Grade Token"
	end
	prof.data.items.gradeTokens -= 1
	Sync.field(player, "items")
	local grade = pick(Config.Grades)
	f.grade = grade.id
	changed(player, f)
	if grade.index >= #Config.Grades then
		local def = Config.FloatieById[f.id]
		Core.notifyAll("🎫 " .. player.DisplayName .. " graded a " .. def.name .. " to " .. grade.id .. "!", "event")
	end
	return true, grade.id
end

function Reroll.trait(player, uid)
	local prof = Core.getProfile(player)
	local f = prof and Floaties.find(player, uid)
	if not f then
		return false, "Floatie not found"
	end
	if prof.data.items.traitGems < 1 then
		return false, "You need a Trait Gem"
	end
	prof.data.items.traitGems -= 1
	Sync.field(player, "items")
	local trait = pick(Config.Traits)
	f.trait = trait.id
	changed(player, f)
	if trait.chance <= 0.004 then
		local def = Config.FloatieById[f.id]
		Core.notifyAll("💎 " .. player.DisplayName .. " rolled the " .. trait.name .. " trait on a " .. def.name .. "!", "event")
	end
	return true, trait.id
end

function Reroll.buyToken(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false, "Try again"
	end
	local cost = Formulas.gradeTokenCost(prof.data.gradeTokensBought)
	if not Economy.spend(player, cost) then
		return false, "Not enough Air! A Grade Token costs " .. Config.Format(cost) .. "."
	end
	prof.data.gradeTokensBought += 1
	prof.data.items.gradeTokens += 1
	Sync.field(player, "items")
	Sync.field(player, "gradeTokensBought")
	return true, "+1 Grade Token 🎫"
end

Core.remote("RerollGrade", "RemoteFunction").OnServerInvoke = function(player, uid)
	if not Core.throttle(player, "reroll", 0.25) then
		return false, "Slow down!"
	end
	return Reroll.grade(player, uid)
end

Core.remote("RerollTrait", "RemoteFunction").OnServerInvoke = function(player, uid)
	if not Core.throttle(player, "reroll", 0.25) then
		return false, "Slow down!"
	end
	return Reroll.trait(player, uid)
end

Core.remote("BuyGradeToken", "RemoteFunction").OnServerInvoke = function(player)
	if not Core.throttle(player, "buyToken", 0.2) then
		return false, "Slow down!"
	end
	return Reroll.buyToken(player)
end

return Reroll
