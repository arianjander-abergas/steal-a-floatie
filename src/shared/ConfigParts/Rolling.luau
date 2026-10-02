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
	AnnounceOrder = 7,       -- Divine and up are announced to the whole server
	HideShowsOrder = 5,      -- with Hide on, Legendary and up still show their reveal
	HideShowsMutations = { Rainbow = true, Thunder = true },

	JackpotLuck = 999,       -- a Jackpot Roll multiplies your Luck by this for one roll

	ConveyorTime = 6,        -- seconds a new Floatie rides your conveyor
	WalkSpeed = 14,          -- studs per second from the conveyor to its slot

	BackpackSize = 170,      -- Floaties that don't fit on a slot wait here...
	BigBackpackSize = 500,   -- ...with the Bigger Backpack pass. Full = auto-sold for Air.
}

---------------------------------------------------------------------
-- Mutations (rolled after the Floatie, rarest first). chance = base
-- chance; Conveyor Luck, Mutation potions and Helium Rain multiply it.
---------------------------------------------------------------------
Rolling.Mutations = {
	{ id = "Normal",  mult = 1,   chance = 0 },
	{ id = "Glitter", mult = 1.5, chance = 0.08,  color = Color3.fromRGB(255, 240, 170) },
	{ id = "Neon",    mult = 2,   chance = 0.035, color = Color3.fromRGB(90, 255, 230) },
	{ id = "Foil",    mult = 3,   chance = 0.012, color = Color3.fromRGB(220, 220, 235) },
	{ id = "Rainbow", mult = 5,   chance = 0.003, color = Color3.fromRGB(255, 120, 200) },
	{ id = "Thunder", mult = 8,   chance = 0,     color = Color3.fromRGB(255, 235, 80), eventOnly = "Thunderstorm", eventChance = 0.03 },
}
Rolling.MaxMutationChance = 0.9 -- no single mutation ever goes above 90%

---------------------------------------------------------------------
-- Pump tiers (the "dice"). Bought with Air at the Pump Shop, in order,
-- owned forever; one is equipped at a time. look = how PumpModel builds it,
-- rarity = the tag the Pump Shop shows next to the name. Luck and prices
-- were tuned with an economy simulation in Stage 15 (see README).
---------------------------------------------------------------------
Rolling.Pumps = {
	{ name = "Hand Pump",        rarity = "Common",          luck = 1, price = 0,             look = "Hand",       color = Color3.fromRGB(230, 60, 60),   desc = "Red plastic hand pump" },
	{ name = "Foot Pump",        rarity = "Common",          luck = 2, price = 250,           look = "Foot",       color = Color3.fromRGB(255, 205, 50),  desc = "Yellow bellows you stomp" },
	{ name = "Bike Pump",        rarity = "Uncommon",        luck = 3, price = 500e3,          look = "Bike",       color = Color3.fromRGB(200, 205, 215), desc = "Tall chrome pump with a gauge" },
	{ name = "Party Pump",       rarity = "Uncommon",       luck = 5, price = 50e6,         look = "Party",      color = Color3.fromRGB(255, 95, 160),  desc = "Striped, streamers fly out" },
	{ name = "Double Barrel",    rarity = "Rare",        luck = 8, price = 5e9,        look = "Double",     color = Color3.fromRGB(70, 205, 95),   desc = "Two cylinders, twice the puff" },
	{ name = "Electric Pump",    rarity = "Rare",        luck = 12, price = 250e9,       look = "Electric",   color = Color3.fromRGB(65, 150, 255),  desc = "Buzzing blue motor, sparks" },
	{ name = "Air Compressor",   rarity = "Epic",       luck = 20, price = 10e12,      look = "Compressor", color = Color3.fromRGB(255, 140, 40),  desc = "Industrial tank with a pressure dial" },
	{ name = "Helium Tank",      rarity = "Epic",          luck = 30, price = 400e12,     look = "Helium",     color = Color3.fromRGB(215, 220, 235), desc = "Silver tank, balloons float up" },
	{ name = "Cloud Maker",      rarity = "Legendary",     luck = 50, price = 15e15,    look = "Cloud",      color = Color3.fromRGB(240, 248, 255), desc = "Fluffy machine puffing clouds" },
	{ name = "Jet Turbine",      rarity = "Legendary",     luck = 80, price = 600e15,   look = "Jet",        color = Color3.fromRGB(120, 130, 150), desc = "Spinning jet engine" },
	{ name = "Storm Engine",     rarity = "Mythic",       luck = 125, price = 25e18,  look = "Storm",      color = Color3.fromRGB(60, 60, 90),    desc = "Thundercloud with lightning coils" },
	{ name = "Aurora Engine",    rarity = "Divine",      luck = 200, price = 1e21, look = "Aurora",     color = Color3.fromRGB(120, 255, 200), desc = "Glowing ribbons of aurora light" },
}

return Rolling
