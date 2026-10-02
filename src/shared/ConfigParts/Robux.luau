--[[
	Config part: Robux (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Game passes, developer products, the Starter Pack, the offer ladder and
	Friend Boost. Merged into Config, so code reads Config.GamePasses / ...

	Create each pass / product on create.roblox.com, then paste its ID here.
	id = 0 means "not set up yet": the button tells the player "Coming soon".
	The prices here are only what the buttons show; the real price is the one
	you set on create.roblox.com.
]]

local Robux = {}

---------------------------------------------------------------------
-- Game passes (forever)
---------------------------------------------------------------------
Robux.GamePasses = {
	DoubleCash  = { id = 0, title = "2x Cash",         icon = "💰", desc = "All Air x2 forever",         price = 199 },
	QuadLuck    = { id = 0, title = "4x Luck",         icon = "🍀", desc = "Luck x4 forever",            price = 249 },
	FastRoll    = { id = 0, title = "Fast Roll",       icon = "⚡", desc = "Inflate time -30%",          price = 179 },
	ExtraSlots  = { id = 0, title = "+5 Slots",        icon = "🧩", desc = "Five more slots on your base", price = 249 },
	VIP         = { id = 0, title = "VIP",             icon = "⭐", desc = "+20% Air and a gold VIP tag", price = 149 },
	BigBackpack = { id = 0, title = "Bigger Backpack", icon = "🎒", desc = "Backpack 170 -> 500",         price = 99 },
}
Robux.PassOrder = { "DoubleCash", "QuadLuck", "FastRoll", "ExtraSlots", "VIP", "BigBackpack" }
Robux.VipCash = 1.2
-- Set true to pretend you own every pass while testing in Studio.
Robux.TestPassesInStudio = false

---------------------------------------------------------------------
-- Developer products (can be bought again and again). grant = a reward
-- (see the Rewards part) unless the server handles the name itself.
---------------------------------------------------------------------
Robux.DevProducts = {
	AirPackSmall    = { id = 0, title = "Air Pack",          icon = "💨", desc = "5 minutes of your income (min 500)",  price = 29,  grant = { incomeMinutes = 5, minAir = 500 } },
	AirPackLarge    = { id = 0, title = "Big Air Pack",      icon = "🌪️", desc = "30 minutes of your income (min 3K)",  price = 129, grant = { incomeMinutes = 30, minAir = 3000 } },
	JackpotRoll     = { id = 0, title = "Jackpot Roll",      icon = "🎰", desc = "One roll at x999 luck",               price = 35,  grant = { jackpotRolls = 1 } },
	LuckPotions     = { id = 0, title = "Luck Potion x3",    icon = "🍀", desc = "Three 10-minute Luck x2 potions",     price = 25,  grant = { potions = { Luck = 3 } } },
	CashPotions     = { id = 0, title = "Cash Potion x3",    icon = "💰", desc = "Three 10-minute Cash x2 potions",     price = 25,  grant = { potions = { Cash = 3 } } },
	MutationPotions = { id = 0, title = "Mutation Potion x3", icon = "🧪", desc = "Three 10-minute Mutation x3 potions", price = 35, grant = { potions = { Mutation = 3 } } },
	GradeTokens     = { id = 0, title = "Grade Token x5",    icon = "🎫", desc = "Reroll grades at the Grading stand",  price = 49,  grant = { gradeTokens = 5 } },
	TraitGems       = { id = 0, title = "Trait Gem x5",      icon = "💎", desc = "Reroll traits at the Traits stand",   price = 49,  grant = { traitGems = 5 } },
	ServerLuckBoost = { id = 0, title = "Server Luck Boost", icon = "🍀", desc = "Lucky Breeze (Luck x2) for EVERYONE", price = 99 },
	SkipPlaytime    = { id = 0, title = "Skip All",          icon = "⏩", desc = "Unlock every playtime reward now",    price = 79 },
}
Robux.BoostOrder = { "JackpotRoll", "LuckPotions", "CashPotions", "MutationPotions", "GradeTokens", "TraitGems", "AirPackSmall", "AirPackLarge", "ServerLuckBoost" }

-- One level of an upgrade for Robux (Config.Upgrades has the button prices)
Robux.UpgradeProducts = {
	slots = 0, luck = 0, cash = 0, time = 0, walk = 0, conveyor = 0,
}

---------------------------------------------------------------------
-- Starter Pack: one time only, shown to new players (and as a popup
-- after their 10th roll) until it is bought.
---------------------------------------------------------------------
Robux.StarterPack = {
	id = 0, price = 49, title = "Starter Pack",
	grant = {
		floatie = { rarity = "Rare", upgradeChance = 0.30, upgradeTo = "Epic" }, mutation = "random",
		incomeMinutes = 30, minAir = 50000, potions = { Luck = 2 }, gradeTokens = 3,
	},
	lines = { "Rare or Epic Floatie (30% Epic) with a mutation", "30 min of income (at least 50K Air)", "Luck Potion x2", "Grade Token x3" },
	popupAfterRolls = 10,
}

---------------------------------------------------------------------
-- Offer ladder: five cards unlocked in order; each must be claimed before
-- the next. Step 1 is free (game passes can't be free, so these are
-- developer products plus one free claim).
---------------------------------------------------------------------
Robux.OfferLadder = {
	{ id = 0, price = 0,   grant = { potions = { Luck = 2 }, gradeTokens = 1 },                                        text = "Luck Potion x2 + Grade Token" },
	{ id = 0, price = 49,  grant = { floatie = { rarity = "Rare", orBetter = true }, potions = { Luck = 1, Cash = 1, Mutation = 1 } }, text = "Rare+ Floatie + 3 potions" },
	{ id = 0, price = 99,  grant = { floatie = { rarity = "Epic" }, gradeTokens = 5 },                                 text = "Epic Floatie + 5 Grade Tokens" },
	{ id = 0, price = 199, grant = { floatie = { rarity = "Legendary" }, traitGems = 10 },                             text = "Legendary Floatie + 10 Trait Gems" },
	{ id = 0, price = 399, grant = { floatie = { rarity = "Mythic" }, mutation = "random", gradeTokens = 25 },          text = "Mythic Floatie (mutated) + 25 Grade Tokens" },
}

---------------------------------------------------------------------
-- Offer bubbles on the right side of the HUD: two at a time. The Starter
-- Pack keeps the first spot until it is bought; the other spot cycles
-- through the rest every OfferRotate seconds (passes you own are skipped).
--   kind = "starter" | "pass" (Config.GamePasses key) | "product" (Config.DevProducts key)
---------------------------------------------------------------------
Robux.OfferBubbles = {
	{ kind = "starter", label = "Starter",  color = Color3.fromRGB(255, 95, 160) },
	{ kind = "pass",    key = "QuadLuck",   label = "4x Luck", color = Color3.fromRGB(80, 210, 90) },
	{ kind = "pass",    key = "DoubleCash", label = "2x Cash", color = Color3.fromRGB(255, 195, 50) },
	{ kind = "product", key = "JackpotRoll", label = "Jackpot", color = Color3.fromRGB(150, 85, 245) },
}
Robux.OfferRotate = 6

---------------------------------------------------------------------
-- Friend Boost (free): +10% Air for each friend in your server
---------------------------------------------------------------------
Robux.FriendBoost = { each = 0.10, max = 0.40 }

return Robux
