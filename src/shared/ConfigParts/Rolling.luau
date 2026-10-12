--[[
	Config part: Rolling (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Rolling a Floatie: inflate time, how luck picks the result, sizes and
	mutations, the pump tiers (our "dice"), the conveyor ride and the Backpack.
	Merged into Config, so code reads Config.Rolling / Config.Forms /
	Config.Mutations / Config.Pumps.

	How a roll is decided (on the server), the Anime Dice way:
	  1. Every pull is a COPY: a Floatie in a size (Normal / Huge / Titanic) with
	     a mutation (Normal / Silver ... Rainbow). Its odds = Floatie odds x size
	     odds x mutation odds: a Huge Ruby Pupfloat is 1 in 2 x 10 x 100K = 1 in 2M.
	  2. Luck = pump x Luck upgrade x rebirths x potion x 4x Luck pass x event x Index x Lucky traits
	  3. Luck removes every copy more common than "1 in Luck"; you get one of the
	     rest, each weighted by 1 / its odds. So pulls land at about 1-10x your
	     Luck (x1,000 Luck mostly gives copies between 1 in 1K and 1 in 10K), and
	     about 1 pull in 100 is 100x rarer than your Luck.
	  4. A copy's rarity (Common ... Infinite, Config.RarityForOdds) and its
	     income follow its odds: income x (size odds x mutation odds)^0.73.
	     Mutation potions and Helium Rain make mutated copies count as rarer-luck
	     targets (their odds / boost), Secret Skies does the same for Secret ones.
]]

local Rolling = {}

Rolling.Rolling = {
	InflateTime = 2.0,       -- seconds the pump inflates before the reveal (= time between rolls)
	MinInflateTime = 0.5,    -- Time upgrade + Breezy + Fast Roll never go below this
	FastRollCut = 0.30,      -- Fast Roll pass: inflate time -30%

	-- the first rolls of a brand-new player are quick and friendly
	StarterRolls = 10,       -- rolls 1..10...
	StarterInflateTime = 0.7,
	StarterUncommonAt = 7,   -- ...roll 7 is a sure Uncommon, the others are Commons

	-- the big reveal: Jackpot Rolls, and Rare-or-better pulls at least this much rarer
	-- than your Luck (about 1 pull in 100); with Hide on, no reveal pops up at all
	BigRevealLuckRatio = 100,
	BigRevealMinOrder = 3,
	-- a line in the server chat: Mythic or rarer AND at least this much rarer than your Luck
	-- (so a late-game player doesn't fill the chat), or Legendary+ from a Jackpot Roll
	AnnounceOrder = 6,
	AnnounceLuckRatio = 1000,

	JackpotLuck = 999,       -- a Jackpot Roll multiplies your Luck by this for one roll

	ConveyorTime = 6,        -- seconds a new Floatie rides your conveyor
	WalkSpeed = 14,          -- studs per second from the conveyor to its slot

	BackpackSize = 170,      -- Floaties that don't fit on a slot wait here...
	BigBackpackSize = 500,   -- ...with the Bigger Backpack pass. Full = auto-sold for Air.
}

---------------------------------------------------------------------
-- Sizes and mutations, copied from Anime Dice. odds = how much rarer the
-- copy is ("1 in X" multiplier); mult = its income multiplier, which follows
-- the odds (odds ^ 0.73: x10 rarer pays about x5.4, x100 about x29).
-- scale = how much bigger a Huge / Titanic Floatie is on your base.
-- Index: every Floatie x size x mutation is its own entry (50 x 3 x 8).
-- Old saves: Glitter -> Silver, Neon -> Gold, Foil -> Emerald (DataService).
---------------------------------------------------------------------
Rolling.Forms = {
	{ id = "Normal",  odds = 1,   mult = 1,   scale = 1 },
	{ id = "Huge",    odds = 10,  mult = 5.4, scale = 1.25, icon = "🔺", color = Color3.fromRGB(120, 200, 255) },
	{ id = "Titanic", odds = 100, mult = 29,  scale = 1.55, icon = "🔶", color = Color3.fromRGB(255, 90, 70) },
}

Rolling.Mutations = {
	{ id = "Normal",  odds = 1,   mult = 1 },
	{ id = "Silver",  odds = 10,  mult = 5.4,   icon = "🥈", color = Color3.fromRGB(205, 212, 226) },
	{ id = "Gold",    odds = 100, mult = 29,    icon = "🥇", color = Color3.fromRGB(255, 196, 50) },
	{ id = "Emerald", odds = 1e3, mult = 155,   icon = "❇️", color = Color3.fromRGB(45, 205, 110) },
	{ id = "Diamond", odds = 1e4, mult = 830,   icon = "💠", color = Color3.fromRGB(160, 230, 255) },
	{ id = "Ruby",    odds = 1e5, mult = 4500,  icon = "♦️", color = Color3.fromRGB(235, 35, 75) },
	{ id = "Rainbow", odds = 1e6, mult = 24000, icon = "🌈", color = Color3.fromRGB(255, 120, 200) },
	-- only while a Thunderstorm event runs
	{ id = "Thunder", odds = 1e3, mult = 155,   icon = "⚡", color = Color3.fromRGB(255, 235, 80), eventOnly = "Thunderstorm" },
}

---------------------------------------------------------------------
-- Pump tiers (the "dice"). Bought with Air at the Pump Shop, in order,
-- owned forever; one is equipped at a time. look = how PumpModel builds it,
-- rarity = the tag the Pump Shop shows next to the name. Luck climbs about
-- x1.6 per pump (Anime Dice's dice double, but every Floatie here comes in
-- 24 sizes/mutations, so doubling made rare pulls come far too soon). Prices
-- were fitted with the play simulation in v1.2 (tools/econ_sim.py, see README).
---------------------------------------------------------------------
Rolling.Pumps = {
	{ name = "Hand Pump",        rarity = "Common",          luck = 1, price = 0,             look = "Hand",       color = Color3.fromRGB(230, 60, 60),   desc = "Red plastic hand pump" },
	{ name = "Foot Pump",        rarity = "Common",          luck = 2, price = 250,           look = "Foot",       color = Color3.fromRGB(255, 205, 50),  desc = "Yellow bellows you stomp" },
	{ name = "Bike Pump",        rarity = "Uncommon",        luck = 3, price = 54e6,          look = "Bike",       color = Color3.fromRGB(200, 205, 215), desc = "Tall chrome pump with a gauge" },
	{ name = "Party Pump",       rarity = "Uncommon",       luck = 5, price = 1.1e9,         look = "Party",      color = Color3.fromRGB(255, 95, 160),  desc = "Striped, streamers fly out" },
	{ name = "Double Barrel",    rarity = "Rare",        luck = 8, price = 36e9,        look = "Double",     color = Color3.fromRGB(70, 205, 95),   desc = "Two cylinders, twice the puff" },
	{ name = "Electric Pump",    rarity = "Rare",        luck = 12, price = 850e9,       look = "Electric",   color = Color3.fromRGB(65, 150, 255),  desc = "Buzzing blue motor, sparks" },
	{ name = "Air Compressor",   rarity = "Epic",       luck = 20, price = 7.4e12,      look = "Compressor", color = Color3.fromRGB(255, 140, 40),  desc = "Industrial tank with a pressure dial" },
	{ name = "Helium Tank",      rarity = "Epic",          luck = 30, price = 79e12,     look = "Helium",     color = Color3.fromRGB(215, 220, 235), desc = "Silver tank, balloons float up" },
	{ name = "Cloud Maker",      rarity = "Legendary",     luck = 50, price = 380e12,    look = "Cloud",      color = Color3.fromRGB(240, 248, 255), desc = "Fluffy machine puffing clouds" },
	{ name = "Jet Turbine",      rarity = "Legendary",     luck = 80, price = 2.2e15,   look = "Jet",        color = Color3.fromRGB(120, 130, 150), desc = "Spinning jet engine" },
	{ name = "Storm Engine",     rarity = "Mythic",       luck = 125, price = 11e15,  look = "Storm",      color = Color3.fromRGB(60, 60, 90),    desc = "Thundercloud with lightning coils" },
	{ name = "Aurora Engine",    rarity = "Divine",      luck = 200, price = 20e15, look = "Aurora",     color = Color3.fromRGB(120, 255, 200), desc = "Glowing ribbons of aurora light" },
}

return Rolling
