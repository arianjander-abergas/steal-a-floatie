--[[
	Config part: Trading (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Player-to-player trades. Merged into Config, so code reads Config.Trade.
]]

local Trading = {}

Trading.Trade = {
	UnlockRolls = 1000,    -- both players need this many total rolls
	MaxFloaties = 8,       -- Floaties per side
	ReadyCountdown = 5,    -- seconds between both pressing Ready and Confirm opening
	Cooldown = 10,         -- seconds between two trades
	RequestTimeout = 30,   -- a trade request expires after this long
	HistorySize = 20,      -- trades kept in each player's save
	MaxItemAmount = 9999,  -- per item per trade
	-- what can go in besides Floaties (no Air: that stops "give me Air first" scams)
	Items = {
		{ key = "gradeTokens", name = "Grade Tokens",     one = "Grade Token",     icon = "🎫" },
		{ key = "traitGems",   name = "Trait Gems",       one = "Trait Gem",       icon = "💎" },
		{ key = "Luck",        name = "Luck Potions",     one = "Luck Potion",     icon = "🍀", potion = true },
		{ key = "Cash",        name = "Cash Potions",     one = "Cash Potion",     icon = "💰", potion = true },
		{ key = "Mutation",    name = "Mutation Potions", one = "Mutation Potion", icon = "🧪", potion = true },
	},
}

return Trading
