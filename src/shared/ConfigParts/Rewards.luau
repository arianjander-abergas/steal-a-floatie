--[[
	Config part: Rewards (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Daily and Playtime rewards, potions, server events and promo codes.
	Merged into Config, so code reads Config.Daily / Config.Events / ...

	A reward is a table with any of these keys (all optional):
	  air = 500                          fixed Air
	  incomeMinutes = 10, minAir = 500   that many minutes of your current income (at least minAir)
	  gradeTokens = 3, traitGems = 3, jackpotRolls = 1
	  potions = { Luck = 2, Cash = 1, Mutation = 1 }
	  floatie = { id = "Kittiloon" } or { rarity = "Epic" }, plus mutation = "Glitter" or "random"
	  text = "..."                       what the reward tile says (made up from the above if missing)
]]

local Rewards = {}

---------------------------------------------------------------------
-- Potions (kept in the Backpack's Items tab). Drinking another of the
-- same kind adds time, not strength.
---------------------------------------------------------------------
Rewards.Potions = {
	Luck     = { name = "Luck Potion",     icon = "🍀", mult = 2, duration = 600, color = Color3.fromRGB(110, 235, 110), desc = "Luck x2" },
	Cash     = { name = "Cash Potion",     icon = "💰", mult = 2, duration = 600, color = Color3.fromRGB(255, 210, 60),  desc = "Air income x2" },
	Mutation = { name = "Mutation Potion", icon = "🧪", mult = 3, duration = 600, color = Color3.fromRGB(190, 110, 255), desc = "Mutation chances x3" },
}
Rewards.PotionOrder = { "Luck", "Cash", "Mutation" }

---------------------------------------------------------------------
-- Daily Rewards: one claim per day (24 h cooldown); missing a day by
-- more than 48 h restarts the streak at Day 1.
---------------------------------------------------------------------
Rewards.Daily = {
	Cooldown = 24 * 3600,
	StreakReset = 48 * 3600,
	Days = {
		{ incomeMinutes = 10, minAir = 500 },
		{ potions = { Luck = 2 } },
		{ incomeMinutes = 30, minAir = 1500 },
		{ gradeTokens = 3 },
		{ potions = { Cash = 2, Mutation = 1 } },
		{ traitGems = 3 },
		{ floatie = { rarity = "Epic" }, mutation = "random", jackpotRolls = 1, text = "Epic Floatie + Jackpot Roll" },
	},
}

---------------------------------------------------------------------
-- Playtime Rewards: 12 tiles that unlock during ONE play session
-- (minutes since you joined). Skip All (Robux) unlocks every tile.
---------------------------------------------------------------------
Rewards.Playtime = {
	{ minutes = 1,  reward = { incomeMinutes = 5, minAir = 200 } },
	{ minutes = 3,  reward = { potions = { Luck = 1 } } },
	{ minutes = 5,  reward = { gradeTokens = 1 } },
	{ minutes = 8,  reward = { incomeMinutes = 10, minAir = 500 } },
	{ minutes = 12, reward = { potions = { Cash = 1 } } },
	{ minutes = 16, reward = { traitGems = 1 } },
	{ minutes = 20, reward = { potions = { Mutation = 1 } } },
	{ minutes = 25, reward = { incomeMinutes = 20, minAir = 1000 } },
	{ minutes = 30, reward = { gradeTokens = 2 } },
	{ minutes = 40, reward = { potions = { Luck = 2 } } },
	{ minutes = 50, reward = { traitGems = 2 } },
	{ minutes = 60, reward = { jackpotRolls = 1 } },
}

---------------------------------------------------------------------
-- Automatic server events (one every EventInterval seconds)
---------------------------------------------------------------------
Rewards.EventInterval = 15 * 60
Rewards.Events = {
	HeliumRain   = { title = "🎈 HELIUM RAIN",  desc = "Mutation chance x4!",               duration = 180, mutationMult = 4 },
	GoldenHour   = { title = "✨ GOLDEN HOUR",  desc = "All Floaties earn 2x Air!",         duration = 180, incomeMult = 2 },
	Thunderstorm = { title = "⛈️ THUNDERSTORM", desc = "Thunder Floaties (x8) can appear!", duration = 150 },
	SecretSkies  = { title = "🌌 SECRET SKIES", desc = "Secret odds x5!",                   duration = 120, secretLuck = 5 },
	LuckyBreeze  = { title = "🍀 LUCKY BREEZE", desc = "Everyone's Luck x2!",               duration = 180, luckMult = 2 },
}

---------------------------------------------------------------------
-- Promo codes (post these on TikTok / Discord / the game description).
-- Each code is a reward (see the top of this file).
---------------------------------------------------------------------
Rewards.Codes = {
	RELEASE = { incomeMinutes = 10, minAir = 1000 },
	FLOATIE = { floatie = { id = "Kittiloon" }, mutation = "Glitter" },
	LUCKY = { potions = { Luck = 1 } },
	-- LIKES1K = { air = 5000 },   -- example: add when the game hits 1,000 likes
}

return Rewards
