--[[
	Formulas (ModuleScript in ReplicatedStorage.Shared)
	The game's math in one place, so the server (which decides everything)
	and the client (which only shows numbers) always agree. Pure functions:
	they read Config and the values you pass in, nothing else.

	A Floatie record (from the save) looks like:
	  { uid = 7, id = "Pupfloat", mut = "Glitter", level = 12, grade = "S", trait = "Helium", locked = false, slot = 3 }
	slot = nil means it is in the Backpack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Formulas = {}

local Levels = Config.Levels

---------------------------------------------------------------------
-- Levels and sizes
---------------------------------------------------------------------

-- income multiplier from the level: Lv 1 = x1, Lv 100 = x15.85
function Formulas.levelMult(level)
	return 1 + Levels.IncomePerLevel * (math.clamp(level or 1, 1, Levels.Max) - 1)
end

-- index into Config.Sizes for this level (1 = Deflated ... 5 = MEGA)
function Formulas.sizeIndex(level)
	level = level or 1
	local index = 1
	for i, size in ipairs(Config.Sizes) do
		if level >= size.level then
			index = i
		end
	end
	return index
end

function Formulas.size(level)
	return Config.Sizes[Formulas.sizeIndex(level)]
end

-- the next size milestone above this level (nil at MEGA)
function Formulas.nextSize(level)
	return Config.Sizes[Formulas.sizeIndex(level) + 1]
end

---------------------------------------------------------------------
-- One Floatie
---------------------------------------------------------------------
function Formulas.gradeMult(f)
	local grade = Config.GradeById[f.grade or "C"]
	return if grade then grade.mult else 1
end

function Formulas.traitMult(f)
	local trait = f.trait and Config.TraitById[f.trait]
	return if trait then trait.mult else 1
end

function Formulas.mutationMult(f)
	local mut = Config.MutationById[f.mut or "Normal"]
	return if mut then mut.mult else 1
end

-- Air per second BEFORE your Cash multiplier
function Formulas.baseIncome(f)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0
	end
	return def.income * Formulas.levelMult(f.level) * Formulas.gradeMult(f) * Formulas.traitMult(f) * Formulas.mutationMult(f)
end

-- what selling pays: income x 20 x grade x mutation (levels and traits don't count)
function Formulas.sellValue(f)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0
	end
	return math.floor(def.income * Config.SellMult * Formulas.gradeMult(f) * Formulas.mutationMult(f))
end

-- Air to go from `level` to `level + 1`. Priced on this Floatie's own
-- income (rarity x grade x trait x mutation), so every Level Up pays back
-- in the same time no matter how fancy the Floatie is.
function Formulas.levelUpCost(f, level)
	local def = Config.FloatieById[f.id]
	local base = def.income * Formulas.gradeMult(f) * Formulas.traitMult(f) * Formulas.mutationMult(f)
	return math.floor(base * Levels.CostMult * Levels.CostGrowth ^ (level - 1))
end

-- total Air for `count` more levels (stops at the max level); returns cost, levels
function Formulas.levelCost(f, count)
	local def = Config.FloatieById[f.id]
	if not def then
		return math.huge, 0
	end
	local level = f.level or 1
	local total, n = 0, 0
	while n < count and level + n < Levels.Max do
		total += Formulas.levelUpCost(f, level + n)
		n += 1
	end
	return total, n
end

-- how many levels `air` buys right now (up to `limit`); returns levels, cost
function Formulas.affordableLevels(f, air, limit)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0, 0
	end
	local level = f.level or 1
	local total, n = 0, 0
	limit = limit or Levels.Max
	while n < limit and level + n < Levels.Max do
		local nextCost = Formulas.levelUpCost(f, level + n)
		if total + nextCost > air then
			break
		end
		total += nextCost
		n += 1
	end
	return n, total
end

---------------------------------------------------------------------
-- You
---------------------------------------------------------------------

-- Air for the next level of an upgrade (nil when it is maxed)
function Formulas.upgradeCost(id, level)
	local up = Config.UpgradeById[id]
	if not up or level >= up.max then
		return nil
	end
	return math.floor(up.costBase * up.costGrowth ^ level)
end

function Formulas.rebirthCost(rebirths)
	local r = Config.Rebirth
	return r.CostBase * r.CostGrowth ^ rebirths
end

-- Air price of the next Grade Token at the Grading stand
function Formulas.gradeTokenCost(bought)
	local g = Config.GradeTokenAir
	return math.floor(g.base * g.growth ^ (bought or 0))
end

-- how many slots you can use
function Formulas.slotCount(data, hasSlotsPass)
	local r = Config.Rebirth
	local n = Config.Slots.Start
		+ (data.upgrades and data.upgrades.slots or 0)
		+ math.min((data.rebirths or 0) * r.SlotsEach, r.SlotsMax)
	if hasSlotsPass then
		n += Config.Slots.PassBonus
	end
	return math.min(n, Config.Slots.GridSize)
end

-- "+1.2K" style text for one Floatie's income with your Cash multiplier
function Formulas.incomeText(f, cash)
	return "+" .. Config.Format(Formulas.baseIncome(f) * (cash or 1)) .. "/s"
end

return Formulas
