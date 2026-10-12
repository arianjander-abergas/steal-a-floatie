--[[
	Stage 18 test (Anime Dice rarity system: sizes, mutations, copy odds).
	NOT part of the game: copy this file into src/server/ while Rojo is syncing,
	press Play, read the [T18] lines in Output, then delete it from src/server/.
]]
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Formulas = require(RS.Shared.Formulas)
local Core = require(SSS.Server.Core)
local DataService = require(SSS.Server.DataService)
local Floaties = require(SSS.Server.Floaties)
local Index = require(SSS.Server.Index)
local Rolling = require(SSS.Server.Rolling)
local Bases = require(SSS.Server.Bases)

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local prof
repeat
	task.wait(0.5)
	prof = Core.getProfile(p)
until prof
task.wait(6)
local d = prof.data
local fails = 0
local function check(name, cond)
	if not cond then
		fails += 1
	end
	print((if cond then "[T18] PASS " else "[T18] FAIL ") .. name)
end

print("[T18] version", Config.Version, "| rarities", table.concat(Config.RarityOrder, ", "))
check("1,200 copies", #Formulas.allCopies() == 1200)
check("Huge Ruby Pupfloat is 1 in 2M (Mythic)", Formulas.copyOdds("Pupfloat", "Ruby", "Huge") == 2e6
	and Formulas.copyRarity("Pupfloat", "Ruby", "Huge") == "Mythic")

-- real pulls through the server with this player's Luck
local counts = { Huge = 0, Titanic = 0 }
local mutated = 0
for _ = 1, 3000 do
	local def, mut, form = Rolling.pickCopy(p)
	if form ~= "Normal" then
		counts[form] += 1
	end
	if mut ~= "Normal" then
		mutated += 1
	end
	assert(def and mut and form, "pickCopy returned nil")
end
print(("[T18] 3,000 pulls at x%s Luck: Huge %d, Titanic %d, mutated %d"):format(Config.Format(p:GetAttribute("LuckMultiplier") or 1), counts.Huge, counts.Titanic, mutated))
check("Huge about 1 in 10", counts.Huge > 180 and counts.Huge < 420)
check("Titanic about 1 in 100", counts.Titanic > 10 and counts.Titanic < 70)

-- a Titanic Floatie: saved with its size, bigger on the base, its own Index entry
local before = Index.count(d)
local f = Floaties.add(p, { id = "Dragonflate", mut = "Gold", form = "Titanic" }, { noAutoSell = true })
check("Titanic record keeps its size", f ~= nil and f.form == "Titanic")
check("Titanic Index entry", d.index["Dragonflate|Gold|Titanic"] == true and Index.count(d) == before + 1)
local _, total = Index.count(d)
check("Index total 1,200", total == 1200)
local plain = Floaties.add(p, { id = "Dragonflate", mut = "Gold" }, { noAutoSell = true })
check("Normal size is stored as nil", plain ~= nil and plain.form == nil)
task.wait(0.5)
local mt, mp = f and f.slot and Bases.model(p, f.uid), plain and plain.slot and Bases.model(p, plain.uid)
if mt and mp then
	local _, st = mt:GetBoundingBox()
	local _, sp = mp:GetBoundingBox()
	print(("[T18] model sizes: Titanic %.1f, Normal %.1f studs"):format(st.Magnitude, sp.Magnitude))
	check("Titanic model is bigger", st.Magnitude > sp.Magnitude * 1.3)
	local label = mt.PrimaryPart:FindFirstChild("Label")
	print("[T18] Titanic label:", label and label.Extra.Text, "/", label and label.NameLine.Text, "/", label and label.Rarity.Text)
	check("label shows the copy", label ~= nil and label.NameLine.Text == "Titanic Dragonflate" and label.Extra.Text == "Gold")
else
	print("[T18] (no free slots for the model check)")
end
check("income x29 x29 (size x Gold)", math.abs(Formulas.baseIncome(f) - 2000 * 29 * 29) < 1)

-- saves: bad / Normal sizes are cleaned up, old mutation names renamed
local old = DataService.template()
old.floaties = {
	{ uid = 1, id = "Pupfloat", mut = "Glitter", form = "Huge" },
	{ uid = 2, id = "Bunbob", mut = "Ruby", form = "Gigantic" },
	{ uid = 3, id = "Bunbob", mut = "Normal", form = "Normal" },
}
DataService.migrate(old)
check("save: Huge kept, Glitter -> Silver", old.floaties[1].form == "Huge" and old.floaties[1].mut == "Silver")
check("save: unknown size dropped", old.floaties[2].form == nil)
check("save: Normal size stored as nil", old.floaties[3].form == nil)

-- a forced very rare pull: chat line with the copy's rarity and odds (watch the chat)
local real = Rolling.pickCopy
Rolling.pickCopy = function()
	return Config.FloatieById.Pupfloat, "Rainbow", "Titanic"
end
prof.nextRollAt = 0
d.totalRolls = math.max(d.totalRolls, Config.Rolling.StarterRolls) -- past the scripted starter rolls
print("[T18] forced Titanic Rainbow Pupfloat roll:", Rolling.roll(p))
Rolling.pickCopy = real

print(fails == 0 and "[T18] ALL PASS" or ("[T18] " .. fails .. " FAILED"))
