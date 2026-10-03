--[[
	Config part: Rolling (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Rolling a Floatie: inflate time, how luck picks the result, mutations,
	the pump tiers (our "dice"), the conveyor ride and the Backpack. Merged
	into Config, so code reads Config.Rolling / Config.Mutations / Config.Pumps.

	How a roll is decided (on the server):
	  1. Luck = pump x Luck upgrade x rebirths x potion x 4x Luck pass x event x Index x Lucky traits
	  2. Floaties are checked rarest first; each hits with chance (1 / odds) x Luck.
	  3. Floaties whose chance reaches 100% stop being checked one by one: if nothing
	     rarer hit, you get one from the best rarity they cover (so luck pushes
	     Commons out). With low luck, a miss on everything gives a Common.
	  4. Then a mutation is rolled (rarest first).
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

	BigRevealOrder = 3,      -- Rare and up get the big reveal (Config.Rarities order)
	AnnounceOrder = 6,       -- Mythic and up: always the big reveal, and a line in the server chat
	BigRevealMutations = { Diamond = true, Ruby = true, Rainbow = true, Thunder = true }, -- always the big reveal too
	AnnounceMutations = { Ruby = true, Rainbow = true }, -- a chat line too, whatever the rarity
	-- (with Hide on, no reveal pops up at all)

	JackpotLuck = 999,       -- a Jackpot Roll multiplies your Luck by this for one roll

	ConveyorTime = 6,        -- seconds a new Floatie rides your conveyor
	WalkSpeed = 14,          -- studs per second from the conveyor to its slot

	BackpackSize = 170,      -- Floaties that don't fit on a slot wait here...
	BigBackpackSize = 500,   -- ...with the Bigger Backpack pass. Full = auto-sold for Air.
}

---------------------------------------------------------------------
-- Mutations (rolled after the Floatie, rarest first), like Anime Dice:
-- the better the mutation, the rarer it is. chance = 1 / "1 in X".
-- Your Luck helps a little (x1.5 at x10 Luck, x2 at x100, x2.5 at x1000:
-- MutationLuckPerTenfold), and Mutation potions and Helium Rain multiply it.
-- A copy's odds ("1 in 300K" for a Rainbow Pupfloat) = Floatie odds x
-- mutation odds (Formulas.copyOdds). Old saves: Glitter -> Silver,
-- Neon -> Gold, Foil -> Emerald (DataService).
---------------------------------------------------------------------
Rolling.Mutations = {
	{ id = "Normal",  mult = 1,   chance = 0 },
	{ id = "Silver",  mult = 1.5, chance = 1 / 20,     icon = "🥈", color = Color3.fromRGB(205, 212, 226) },
	{ id = "Gold",    mult = 2,   chance = 1 / 100,    icon = "🥇", color = Color3.fromRGB(255, 196, 50) },
	{ id = "Emerald", mult = 3,   chance = 1 / 500,    icon = "❇️", color = Color3.fromRGB(45, 205, 110) },
	{ id = "Diamond", mult = 5,   chance = 1 / 3000,   icon = "💠", color = Color3.fromRGB(160, 230, 255) },
	{ id = "Ruby",    mult = 8,   chance = 1 / 20000,  icon = "♦️", color = Color3.fromRGB(235, 35, 75) },
	{ id = "Rainbow", mult = 12,  chance = 1 / 150000, icon = "🌈", color = Color3.fromRGB(255, 120, 200) },
	-- only while a Thunderstorm event runs
	{ id = "Thunder", mult = 6,   chance = 0,          icon = "⚡", color = Color3.fromRGB(255, 235, 80), eventOnly = "Thunderstorm", eventChance = 1 / 150 },
}
Rolling.MaxMutationChance = 0.9     -- no single mutation ever goes above 90%
Rolling.MutationLuckPerTenfold = 0.5 -- mutation chances x(1 + 0.5 x log10(Luck))

---------------------------------------------------------------------
-- Pump tiers (the "dice"). Bought with Air at the Pump Shop, in order,
-- owned forever; one is equipped at a time. look = how PumpModel builds it,
-- rarity = the tag the Pump Shop shows next to the name. Luck and prices
-- were re-tuned with the play simulation in Stage 16 (see README).
---------------------------------------------------------------------
Rolling.Pumps = {
	{ name = "Hand Pump",        rarity = "Common",          luck = 1, price = 0,             look = "Hand",       color = Color3.fromRGB(230, 60, 60),   desc = "Red plastic hand pump" },
	{ name = "Foot Pump",        rarity = "Common",          luck = 2, price = 250,           look = "Foot",       color = Color3.fromRGB(255, 205, 50),  desc = "Yellow bellows you stomp" },
	{ name = "Bike Pump",        rarity = "Uncommon",        luck = 3, price = 2.2e6,          look = "Bike",       color = Color3.fromRGB(200, 205, 215), desc = "Tall chrome pump with a gauge" },
	{ name = "Party Pump",       rarity = "Uncommon",       luck = 5, price = 130e6,         look = "Party",      color = Color3.fromRGB(255, 95, 160),  desc = "Striped, streamers fly out" },
	{ name = "Double Barrel",    rarity = "Rare",        luck = 8, price = 9.2e9,        look = "Double",     color = Color3.fromRGB(70, 205, 95),   desc = "Two cylinders, twice the puff" },
	{ name = "Electric Pump",    rarity = "Rare",        luck = 12, price = 360e9,       look = "Electric",   color = Color3.fromRGB(65, 150, 255),  desc = "Buzzing blue motor, sparks" },
	{ name = "Air Compressor",   rarity = "Epic",       luck = 20, price = 4.8e12,      look = "Compressor", color = Color3.fromRGB(255, 140, 40),  desc = "Industrial tank with a pressure dial" },
	{ name = "Helium Tank",      rarity = "Epic",          luck = 30, price = 48e12,     look = "Helium",     color = Color3.fromRGB(215, 220, 235), desc = "Silver tank, balloons float up" },
	{ name = "Cloud Maker",      rarity = "Legendary",     luck = 50, price = 300e12,    look = "Cloud",      color = Color3.fromRGB(240, 248, 255), desc = "Fluffy machine puffing clouds" },
	{ name = "Jet Turbine",      rarity = "Legendary",     luck = 80, price = 2e15,   look = "Jet",        color = Color3.fromRGB(120, 130, 150), desc = "Spinning jet engine" },
	{ name = "Storm Engine",     rarity = "Mythic",       luck = 125, price = 7.6e15,  look = "Storm",      color = Color3.fromRGB(60, 60, 90),    desc = "Thundercloud with lightning coils" },
	{ name = "Aurora Engine",    rarity = "Divine",      luck = 200, price = 23e15, look = "Aurora",     color = Color3.fromRGB(120, 255, 200), desc = "Glowing ribbons of aurora light" },
}

return Rolling
