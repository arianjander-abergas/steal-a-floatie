-- The pull (Formulas.pickCopy): luck floor, sizes, mutations, boosts, events. Run: python tools/check.py
local Config = require(node("Shared/Config"))
local Formulas = require(node("Shared/Formulas"))
local fails = 0
local function check(name, cond) if not cond then fails += 1 end print((cond and "PASS " or "FAIL ") .. name) end
local seed = 12345
local function random() -- simple LCG so runs repeat
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
print("copies", #Formulas.allCopies())
check("1200 copies", #Formulas.allCopies() == 1200)
local function run(luck, boosts, n)
	local ratios, forms, muts, tiers = {}, {}, {}, {}
	local thunder = 0
	for _ = 1, n do
		local c = Formulas.pickCopy(luck, boosts, random)
		table.insert(ratios, c.odds / luck)
		forms[c.form] = (forms[c.form] or 0) + 1
		muts[c.mut] = (muts[c.mut] or 0) + 1
		local t = Config.RarityForOdds(c.odds)
		tiers[t] = (tiers[t] or 0) + 1
		if c.mut == "Thunder" then thunder += 1 end
	end
	table.sort(ratios)
	local over100 = 0
	for _, r in ipairs(ratios) do if r >= 100 then over100 += 1 end end
	local below = 0
	for _, r in ipairs(ratios) do if r < 1 then below += 1 end end
	return { median = ratios[n // 2], p90 = ratios[math.floor(n * 0.9)], over100 = over100 / n, below = below, forms = forms, muts = muts, tiers = tiers, thunder = thunder }
end
for _, luck in ipairs({ 1, 10, 1000, 1e6 }) do
	local r = run(luck, {}, 20000)
	print(("luck x%s: median %.2fx luck, 90%% under %.1fx, %.2f%% at 100x+, Huge %d Titanic %d, Silver %d Gold %d Emerald %d Diamond %d Ruby %d Rainbow %d"):format(
		Config.Format(luck), r.median, r.p90, r.over100 * 100, r.forms.Huge or 0, r.forms.Titanic or 0,
		r.muts.Silver or 0, r.muts.Gold or 0, r.muts.Emerald or 0, r.muts.Diamond or 0, r.muts.Ruby or 0, r.muts.Rainbow or 0))
	check("luck x" .. luck .. ": never below Luck", r.below == 0 or luck == 1)
	check("luck x" .. luck .. ": a few % at most at 100x+", r.over100 > 0.004 and r.over100 < 0.07)
	-- big reveals: 100x rarer than Luck AND Rare+
	local big = 0
	for _ = 1, 20000 do
		local c = Formulas.pickCopy(luck, {}, random)
		if c.odds >= luck * 100 and Config.Rarities[Config.RarityForOdds(c.odds)].order >= 3 then big += 1 end
	end
	print(("  big reveals at x%s: %.2f%% of pulls"):format(Config.Format(luck), big / 200))
	check("luck x" .. luck .. ": no Thunder outside a storm", r.thunder == 0)
end
local r1 = run(1, {}, 50000)
check("at x1 about 9% Huge (10x rarer)", (r1.forms.Huge or 0) / 50000 > 0.07 and (r1.forms.Huge or 0) / 50000 < 0.11)
check("at x1 about 0.9% Titanic", (r1.forms.Titanic or 0) / 50000 > 0.005 and (r1.forms.Titanic or 0) / 50000 < 0.013)
local storm = run(10, { event = "Thunderstorm" }, 20000)
print("Thunder during a storm at x10:", storm.thunder)
check("Thunder appears during a storm", storm.thunder > 0)
local boosted = run(1000, { mutation = 12 }, 20000)
local plain = run(1000, {}, 20000)
local function rare(r) return (r.muts.Ruby or 0) + (r.muts.Rainbow or 0) + (r.muts.Diamond or 0) end
print("Diamond/Ruby/Rainbow at x1000: plain", rare(plain), "with a x12 Mutation boost", rare(boosted))
check("Mutation boost gives many more rare mutations", rare(boosted) > rare(plain) * 3)
local sec = run(1e6, { secret = 5 }, 20000)
print("Secret Skies run ok")
local top = Formulas.pickCopy(1e30, {}, random)
check("Luck beyond everything gives the rarest copy", top.odds == 1e11 * 100 * 1e6)
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
