--[[
	Formulas (ModuleScript in ReplicatedStorage.Shared)
	The game's math in one place, so the server (which decides everything)
	and the client (which only shows numbers) always agree. Pure functions:
	they read Config and the values you pass in, nothing else.

	A Floatie record (from the save) looks like:
	  { uid = 7, id = "Pupfloat", mut = "Silver", form = "Huge", level = 12, grade = "S", trait = "Helium", locked = false, slot = 3 }
	slot = nil means it is in the Backpack; form = nil means Normal size.

	A "copy" is a Floatie + size (form) + mutation, like an Anime Dice unit:
	its odds, rarity, name and income multiplier all come from that combination.
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

---------------------------------------------------------------------
-- Copies (Floatie x size x mutation)
---------------------------------------------------------------------
local function mutationOf(mutId)
	return Config.MutationById[mutId or "Normal"] or Config.MutationById.Normal
end

local function formOf(formId)
	return Config.FormById[formId or "Normal"] or Config.FormById.Normal
end

-- "1 in X" for this exact copy, the way Anime Dice shows it:
-- Floatie odds x size odds x mutation odds (Huge Ruby Pupfloat = 2 x 10 x 100K = 2M)
function Formulas.copyOdds(id, mutId, formId)
	local def = Config.FloatieById[id]
	return (def and def.odds or 1) * formOf(formId).odds * mutationOf(mutId).odds
end

-- the rarity this copy counts as (a Ruby Pupfloat, 1 in 200K, is Legendary)
function Formulas.copyRarity(id, mutId, formId)
	return Config.RarityForOdds(Formulas.copyOdds(id, mutId, formId))
end

-- "Huge Ruby Pupfloat" / "Pupfloat"
function Formulas.copyName(id, mutId, formId)
	local def = Config.FloatieById[id]
	local name = if def then def.name else tostring(id)
	if mutId and mutId ~= "Normal" then
		name = mutId .. " " .. name
	end
	if formId and formId ~= "Normal" then
		name = formId .. " " .. name
	end
	return name
end

-- Index keys: "id|mutation" for Normal size (the old format), "id|mutation|size" for Huge / Titanic
function Formulas.indexKey(id, mutId, formId)
	local key = id .. "|" .. (mutId or "Normal")
	if formId and formId ~= "Normal" then
		key ..= "|" .. formId
	end
	return key
end

---------------------------------------------------------------------
-- The pull, the Anime Dice way (pure: the server passes its own random)
---------------------------------------------------------------------
local copies = nil

-- every copy there is: { id, mut, form, odds, mutated, secret, event }
-- (50 Floaties x 3 sizes x 8 mutations; event = the event an event-only mutation needs)
function Formulas.allCopies()
	if not copies then
		copies = {}
		for _, def in ipairs(Config.Floaties) do
			for _, form in ipairs(Config.Forms) do
				for _, m in ipairs(Config.Mutations) do
					table.insert(copies, {
						id = def.id, mut = m.id, form = form.id, odds = def.odds * form.odds * m.odds,
						mutated = m.id ~= "Normal", secret = def.rarity == "Secret", event = m.eventOnly,
					})
				end
			end
		end
	end
	return copies
end

-- Luck removes every copy more common than "1 in Luck"; you get one of the
-- rest, each weighted by 1 / its odds, so pulls land at about 1-10x your Luck
-- and 1 pull in N is about N times rarer than it.
--   boosts.mutation  divides a mutated copy's odds (Mutation potions x Helium Rain)
--   boosts.secret    divides a Secret Floatie's odds (Secret Skies)
--   boosts.event     the running event (event-only mutations need it)
--   random()         a number in [0, 1)
-- When Luck beats every copy there is, you get the rarest one.
function Formulas.pickCopy(luck, boosts, random)
	local mutBoost = boosts.mutation or 1
	local secretBoost = boosts.secret or 1
	local function effectiveOdds(c)
		if c.event and c.event ~= boosts.event then
			return nil
		end
		local odds = c.odds
		if c.mutated then
			odds /= mutBoost
		end
		if c.secret then
			odds /= secretBoost
		end
		return odds
	end
	local list = Formulas.allCopies()
	local total, rarest, rarestOdds = 0, nil, 0
	for _, c in ipairs(list) do
		local odds = effectiveOdds(c)
		if odds then
			if odds >= luck then
				total += 1 / odds
			end
			if odds > rarestOdds then
				rarest, rarestOdds = c, odds
			end
		end
	end
	if total <= 0 then
		return rarest
	end
	local roll = random() * total
	local last = nil
	for _, c in ipairs(list) do
		local odds = effectiveOdds(c)
		if odds and odds >= luck then
			last = c
			roll -= 1 / odds
			if roll <= 0 then
				return c
			end
		end
	end
	return last -- rounding left a sliver over: the last candidate
end

-- the same three for a Floatie record
function Formulas.oddsOf(f)
	return Formulas.copyOdds(f.id, f.mut, f.form)
end

function Formulas.rarityOf(f)
	return Formulas.copyRarity(f.id, f.mut, f.form)
end

function Formulas.nameOf(f)
	return Formulas.copyName(f.id, f.mut, f.form)
end

function Formulas.mutationMult(f)
	return mutationOf(f.mut).mult
end

function Formulas.formMult(f)
	return formOf(f.form).mult
end

-- how much bigger the model is (Huge x1.25, Titanic x1.55), on top of the level size
function Formulas.formScale(f)
	return formOf(f.form).scale
end

-- Air per second BEFORE your Cash multiplier
function Formulas.baseIncome(f)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0
	end
	return def.income * Formulas.levelMult(f.level) * Formulas.gradeMult(f) * Formulas.traitMult(f)
		* Formulas.mutationMult(f) * Formulas.formMult(f)
end

-- what selling pays: income x 20 x grade x mutation x size (levels and traits don't count)
function Formulas.sellValue(f)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0
	end
	return math.floor(def.income * Config.SellMult * Formulas.gradeMult(f) * Formulas.mutationMult(f) * Formulas.formMult(f))
end

-- Air to go from `level` to `level + 1`. Priced on this Floatie's own
-- income (rarity x grade x trait x mutation x size), so every Level Up pays
-- back in the same time no matter how fancy the Floatie is.
function Formulas.levelUpCost(f, level)
	local def = Config.FloatieById[f.id]
	local base = def.income * Formulas.gradeMult(f) * Formulas.traitMult(f) * Formulas.mutationMult(f) * Formulas.formMult(f)
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

-- Air for your next rebirth: the Costs list, then x CostGrowth for each one after it
function Formulas.rebirthCost(rebirths)
	local r = Config.Rebirth
	local costs = r.Costs
	if rebirths < #costs then
		return costs[rebirths + 1]
	end
	return costs[#costs] * r.CostGrowth ^ (rebirths - #costs + 1)
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
