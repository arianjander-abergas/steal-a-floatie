--[[
	Config part: Progression (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Everything that makes a Floatie (or you) stronger over time: levels and
	sizes, grades, traits, slots, upgrades, rebirth and the Index. Merged into
	Config, so code reads Config.Levels / Config.Grades / Config.Upgrades / ...

	A Floatie earns:
	  Air/s = income x level x grade x trait x mutation x your Cash
]]

local Progression = {}

---------------------------------------------------------------------
-- Level Up (manual, costs Air). Income x (1 + 0.15 x (level - 1)),
-- so Lv 100 earns about x15.9.
-- Cost of the next level = income x 30 x 1.08^(level - 1)
---------------------------------------------------------------------
Progression.Levels = {
	Max = 100,
	IncomePerLevel = 0.15,
	CostMult = 100,     -- Lv 1->2 pays back in ~11 min before Cash (tuned in Stage 15)
	CostGrowth = 1.08,
}

-- The old inflate stages are now level milestones: at these levels a
-- Floatie grows one size, with the inflate animation.
Progression.Sizes = {
	{ name = "Deflated", level = 1,   scale = 1.00 },
	{ name = "Puffy",    level = 10,  scale = 1.15 },
	{ name = "Round",    level = 25,  scale = 1.30 },
	{ name = "Chonky",   level = 50,  scale = 1.45 },
	{ name = "MEGA",     level = 100, scale = 1.60 },
}
-- old saves: inflate stage 1..5 -> this level
Progression.LevelFromOldStage = { 1, 10, 25, 50, 100 }

---------------------------------------------------------------------
-- Grades: every new Floatie starts at C. 1 Grade Token rerolls it at
-- the Grading stand (the new grade can be lower!).
---------------------------------------------------------------------
Progression.Grades = {
	{ id = "C",  mult = 1,   chance = 0.45,  color = Color3.fromRGB(170, 175, 190) },
	{ id = "B",  mult = 1.5, chance = 0.30,  color = Color3.fromRGB(90, 210, 110) },
	{ id = "A",  mult = 2.5, chance = 0.15,  color = Color3.fromRGB(80, 160, 255) },
	{ id = "S",  mult = 5,   chance = 0.07,  color = Color3.fromRGB(255, 200, 50) },
	{ id = "SS", mult = 10,  chance = 0.025, color = Color3.fromRGB(255, 90, 170) },
	{ id = "UR", mult = 25,  chance = 0.005, color = Color3.fromRGB(255, 70, 70), rainbow = true },
}
Progression.ConfirmGradeReroll = "S" -- ask "are you sure?" before rerolling this grade or better
-- One Grade Token for Air at the Grading stand; the price climbs with every one bought.
Progression.GradeTokenAir = { base = 100000, growth = 1.3 }

---------------------------------------------------------------------
-- Traits: new Floaties have none. 1 Trait Gem rerolls it at the Traits
-- stand. Breezy and Lucky only count while the Floatie sits on a slot.
---------------------------------------------------------------------
Progression.Traits = {
	{ id = "Bouncy",       name = "Bouncy",        mult = 1.2, chance = 0.40,   color = Color3.fromRGB(255, 150, 200) },
	{ id = "Glossy",       name = "Glossy",        mult = 1.5, chance = 0.25,   color = Color3.fromRGB(200, 230, 255) },
	{ id = "Breezy",       name = "Breezy",        mult = 1,   chance = 0.15,   color = Color3.fromRGB(150, 240, 220),
		inflateCut = 0.10, inflateCap = 0.30, desc = "Your inflate time -10% (stacks to -30%)" },
	{ id = "Helium",       name = "Helium",        mult = 2,   chance = 0.10,   color = Color3.fromRGB(190, 170, 255) },
	{ id = "Jetstream",    name = "Jetstream",     mult = 3,   chance = 0.05,   color = Color3.fromRGB(110, 190, 255) },
	{ id = "Lucky",        name = "Lucky",         mult = 1,   chance = 0.03,   color = Color3.fromRGB(110, 235, 110),
		luckBonus = 0.10, luckCap = 0.50, desc = "Your Luck +10% (stacks to +50%)" },
	{ id = "SkyKing",      name = "Sky King",      mult = 5,   chance = 0.015,  color = Color3.fromRGB(255, 210, 80) },
	{ id = "Stratosphere", name = "Stratosphere",  mult = 8,   chance = 0.004,  color = Color3.fromRGB(80, 120, 255) },
	{ id = "Aurora",       name = "Aurora",        mult = 15,  chance = 0.0009, color = Color3.fromRGB(120, 255, 200), rainbow = true },
	{ id = "EternalFloat", name = "Eternal Float", mult = 25,  chance = 0.0001, color = Color3.fromRGB(255, 255, 255), rainbow = true },
}

---------------------------------------------------------------------
-- Slots on your base: 10 to start, up to +20 from the More Slots
-- upgrade, up to +6 from Rebirth and +5 from the +5 Slots pass = 41.
-- The base is built with room for 42.
---------------------------------------------------------------------
Progression.Slots = {
	Start = 10,
	PassBonus = 5,
	GridSize = 42,
}

---------------------------------------------------------------------
-- Upgrades window. Air cost of the next level = costBase x costGrowth^level.
-- robux = price of ONE level (a developer product, see Config.UpgradeProducts).
---------------------------------------------------------------------
Progression.Upgrades = {
	{ id = "slots",    name = "More Slots",    icon = "🧩", desc = "+1 slot for a Floatie",      per = 1,    max = 20, costBase = 5000,  costGrowth = 2.6, robux = 39 },
	{ id = "luck",     name = "Luck",          icon = "🍀", desc = "+5% luck on every roll",      per = 0.05, max = 40, costBase = 10000, costGrowth = 2.3, robux = 12 },
	{ id = "cash",     name = "Cash",          icon = "💰", desc = "+10% Air from every Floatie", per = 0.10, max = 50, costBase = 5000,  costGrowth = 2.2, robux = 14 },
	{ id = "time",     name = "Time",          icon = "⏱️", desc = "-4% inflate time",            per = 0.04, max = 12, costBase = 25000, costGrowth = 3.0, robux = 10 },
	{ id = "walk",     name = "Walk Speed",    icon = "👟", desc = "+1 walk speed",               per = 1,    max = 16, costBase = 300,   costGrowth = 1.8, robux = 9 },
}

---------------------------------------------------------------------
-- Rebirth: costs ALL your Air (you need at least the cost). Floaties,
-- pumps and upgrades stay. The first rebirths cost Costs[1], Costs[2], ...;
-- after the list every rebirth costs CostGrowth times the one before.
-- Tuned with the play simulation in v1.2 (free player, play-hours):
-- about 3 h, 10 h, 30 h, 75 h, 150 h, 300 h, 500 h, 800 h.
---------------------------------------------------------------------
Progression.Rebirth = {
	Costs = { 9.6e9, 330e9, 6.4e12, 65e12, 430e12, 1.9e15, 9e15, 21e15 },
	CostGrowth = 3,
	CashBonus = 0.50,   -- +50% Cash per rebirth
	LuckBonus = 0.10,   -- +10% Luck per rebirth
	SlotsEach = 2,      -- +2 slots per rebirth...
	SlotsMax = 6,       -- ...up to +6
	GradeTokens = 5,
}

---------------------------------------------------------------------
-- Index: 50 Floaties x 3 sizes x 8 mutations = 1,200 entries (Anime Dice style).
-- Each milestone also gives +2% Luck forever. Reward keys: see
-- Config.Rewards at the top of the Rewards part.
---------------------------------------------------------------------
Progression.IndexLuckPerMilestone = 0.02
Progression.IndexMilestones = {
	{ count = 10,  reward = { incomeMinutes = 10, minAir = 1000, gradeTokens = 1 } },
	{ count = 25,  reward = { incomeMinutes = 15, minAir = 5000, potions = { Luck = 2 } } },
	{ count = 50,  reward = { incomeMinutes = 20, minAir = 20000, gradeTokens = 3, traitGems = 2 } },
	{ count = 100, reward = { incomeMinutes = 30, minAir = 100000, potions = { Luck = 2, Cash = 2 }, traitGems = 3 } },
	{ count = 150, reward = { incomeMinutes = 45, minAir = 500000, gradeTokens = 5, potions = { Mutation = 2 } } },
	{ count = 200, reward = { incomeMinutes = 60, minAir = 1000000, gradeTokens = 5, traitGems = 5 } },
	{ count = 250, reward = { incomeMinutes = 90, minAir = 5000000, gradeTokens = 10, traitGems = 10 } },
	{ count = 300, reward = { incomeMinutes = 120, minAir = 10000000, gradeTokens = 25, traitGems = 25, jackpotRolls = 3 } },
	-- the long grind: Huge / Titanic and rare-mutation entries (all 1,200 is out of reach)
	{ count = 400, reward = { incomeMinutes = 150, minAir = 50e6, gradeTokens = 25, traitGems = 25, jackpotRolls = 2 } },
	{ count = 500, reward = { incomeMinutes = 180, minAir = 500e6, gradeTokens = 40, traitGems = 40, jackpotRolls = 3 } },
	{ count = 650, reward = { incomeMinutes = 240, minAir = 5e9, gradeTokens = 60, traitGems = 60, jackpotRolls = 5 } },
	{ count = 800, reward = { incomeMinutes = 300, minAir = 50e9, gradeTokens = 100, traitGems = 100, jackpotRolls = 10 } },
	{ count = 1000, reward = { incomeMinutes = 360, minAir = 500e9, gradeTokens = 200, traitGems = 200, jackpotRolls = 25 } },
}

return Progression
