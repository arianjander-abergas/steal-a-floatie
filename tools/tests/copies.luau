-- Copies (Floatie x size x mutation): odds, rarity, names, income, Index keys. Run: python tools/check.py
local Config = require(node("Shared/Config"))
local Formulas = require(node("Shared/Formulas"))
local fails = 0
local function check(name, cond) if not cond then fails += 1 end print((cond and "PASS " or "FAIL ") .. name) end

print("version", Config.Version, "rarities", table.concat(Config.RarityOrder, ","))
check("12 rarities", #Config.RarityOrder == 12)
check("rarity for 2 = Common", Config.RarityForOdds(2) == "Common")
check("rarity for 200K = Legendary", Config.RarityForOdds(200e3) == "Legendary")
check("rarity for 2e12 = Heavenly", Config.RarityForOdds(2e12) == "Heavenly")
check("rarity for 1e19 = Infinite", Config.RarityForOdds(1e19) == "Infinite")
check("Huge Ruby Pupfloat odds 2M", Formulas.copyOdds("Pupfloat", "Ruby", "Huge") == 2e6)
check("Huge Ruby Pupfloat is Mythic", Formulas.copyRarity("Pupfloat", "Ruby", "Huge") == "Mythic")
check("name", Formulas.copyName("Pupfloat", "Ruby", "Huge") == "Huge Ruby Pupfloat")
check("plain name", Formulas.copyName("Pupfloat", "Normal", nil) == "Pupfloat")
check("odds label", Config.FormatOdds(Formulas.copyOdds("Heliox", "Rainbow", "Titanic")) == "1 in 10Qi")
local f = { id = "Pupfloat", mut = "Rainbow", form = "Titanic", level = 1, grade = "C" }
print("Titanic Rainbow Pupfloat income", Formulas.baseIncome(f), "sell", Formulas.sellValue(f), "lvl cost", Formulas.levelUpCost(f, 1))
check("income x29 x24000", math.abs(Formulas.baseIncome(f) - 1 * 29 * 24000) < 1e-6)
check("old records without form still work", Formulas.baseIncome({ id = "Pupfloat", mut = "Normal", level = 1 }) == 1)
check("index key normal", Formulas.indexKey("Pupfloat", "Ruby", nil) == "Pupfloat|Ruby")
check("index key huge", Formulas.indexKey("Pupfloat", "Ruby", "Huge") == "Pupfloat|Ruby|Huge")
check("rebirth 1 cost", Formulas.rebirthCost(0) == Config.Rebirth.Costs[1])
-- income vs odds: a mutated copy should earn about like a plain Floatie of the same odds
for _, case in ipairs({ { "Pupfloat", "Gold", "Normal" }, { "Duckpuff", "Emerald", "Huge" }, { "Pengloon", "Ruby", "Titanic" } }) do
	local odds = Formulas.copyOdds(case[1], case[2], case[3])
	local inc = Formulas.baseIncome({ id = case[1], mut = case[2], form = case[3], level = 1 })
	print(("  %s: 1 in %s -> %s Air/s (%s)"):format(Formulas.copyName(case[1], case[2], case[3]), Config.Format(odds), Config.Format(inc), Config.RarityForOdds(odds)))
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
