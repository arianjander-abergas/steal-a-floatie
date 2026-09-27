--[[
	Steal a Floatie — Config (ModuleScript in ReplicatedStorage.Shared)

	This is the ONE file you edit for most updates:
	  • add a new Floatie        -> Config.Floaties
	  • tune the economy         -> prices / income / Stages / Rebirth
	  • add a new event          -> Config.Events
	  • add a promo code         -> Config.Codes
	  • hook up Robux products   -> Config.GamePasses / Config.DevProducts
	After editing, bump Config.Version so players see the update number.
]]

local Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.GameName = "Steal a Floatie"
Config.Version = "0.1.2"           -- bump every update, shown in the HUD
Config.DataStoreName = "FloatieData_v1" -- NEVER rename after launch (players lose saves)

-- Your Roblox UserId goes here so you can use admin chat commands in live servers
-- (in Studio, and for the place owner, commands always work).
Config.AdminUserIds = {
	-- 123456789,
}

Config.StartingAir = 100
Config.BaseWalkSpeed = 16

Config.BasePedestals = 10
Config.PedestalsPerRebirth = 2
Config.ExtraPedestalsAmount = 5     -- from the "+5 Pedestals" game pass
Config.MaxPedestals = 20            -- the map builds 20 pedestals per base

Config.SellRate = 0.5               -- sell for 50% of (price x size bonus x mutation)

Config.OfflineGrowthCap = 8 * 3600  -- Floaties keep inflating for up to 8h offline
Config.OfflineIncomeCap = 3 * 3600  -- offline Air counts for up to 3h...
Config.OfflineIncomeRate = 0.5      -- ...at 50% speed

Config.LockDuration = 60            -- base shield lasts 60s
Config.LockRecharge = 30            -- after it drops, 30s before you can lock again (raid window!)

Config.CarryTimeout = 90            -- a stolen Floatie floats home if not delivered in time
Config.DartRange = 90
Config.DartCooldown = 0.45
Config.DartKnockback = 45           -- dart hitting a player who is NOT carrying = small shove
Config.PopReward = 20               -- popping someone else's stolen Floatie pays 20s of its income

Config.PumpInterval = 3.5           -- a new Floatie appears on the Pump Line every X sec
Config.PumpTravelTime = 34          -- seconds to ride the whole line

---------------------------------------------------------------------
-- Rarities (weight = chance to appear on the Pump Line)
---------------------------------------------------------------------
Config.Rarities = {
	Common    = { order = 1, weight = 58,   color = Color3.fromRGB(225, 225, 225) },
	Uncommon  = { order = 2, weight = 26,   color = Color3.fromRGB(95, 210, 120) },
	Rare      = { order = 3, weight = 11,   color = Color3.fromRGB(80, 150, 255) },
	Epic      = { order = 4, weight = 4,    color = Color3.fromRGB(175, 95, 255) },
	Legendary = { order = 5, weight = 0.85, color = Color3.fromRGB(255, 195, 45) },
	Mythic    = { order = 6, weight = 0.15, color = Color3.fromRGB(255, 70, 115) },
	Secret    = { order = 7, weight = 0,    color = Color3.fromRGB(20, 20, 20) }, -- events / codes only
}

---------------------------------------------------------------------
-- Floaties — original balloon-animal characters.
-- shape = how the balloon animal is twisted together (all optional):
--   body, r (body length / radius), leg, legs (count, default 4),
--   neck, head, ear, tail, snout, shell, horn, wings, antlers, spikes, spout
---------------------------------------------------------------------
Config.Floaties = {
	-- Common
	{ id = "Pupfloat",   name = "Pupfloat",   rarity = "Common",   price = 25,     income = 1,
		color = Color3.fromRGB(255, 125, 160), shape = { body = 3, r = 0.8, leg = 1.6, neck = 1.2, head = 1.5, ear = 1.4, tail = 1.2 } },
	{ id = "Kittiloon",  name = "Kittiloon",  rarity = "Common",   price = 50,     income = 2,
		color = Color3.fromRGB(255, 170, 70), shape = { body = 2.6, r = 0.75, leg = 1.3, neck = 0.8, head = 1.6, ear = 0.8, tail = 2 } },
	{ id = "Bunbob",     name = "Bunbob",     rarity = "Common",   price = 90,     income = 3,
		color = Color3.fromRGB(245, 245, 255), shape = { body = 2, r = 0.9, leg = 1, neck = 0.6, head = 1.5, ear = 2.4, tail = 0.4 } },
	-- Uncommon
	{ id = "Snailoon",   name = "Snailoon",   rarity = "Uncommon", price = 300,    income = 9,
		color = Color3.fromRGB(150, 220, 90), shape = { body = 3.4, r = 0.7, leg = 0, neck = 1.6, head = 1.1, ear = 1, shell = 2.4 } },
	{ id = "Duckpuff",   name = "Duckpuff",   rarity = "Uncommon", price = 500,    income = 14,
		color = Color3.fromRGB(255, 230, 60), shape = { body = 2.4, r = 1, leg = 0.9, neck = 1.2, head = 1.4, tail = 0.6, snout = 1.2 } },
	{ id = "Froggle",    name = "Froggle",    rarity = "Uncommon", price = 800,    income = 21,
		color = Color3.fromRGB(60, 190, 90), shape = { body = 2.2, r = 1.1, leg = 1.2, neck = 0.3, head = 1.9, ear = 0.6 } },
	-- Rare
	{ id = "Giraffloat", name = "Giraffloat", rarity = "Rare",     price = 3000,   income = 70,
		color = Color3.fromRGB(240, 190, 90), shape = { body = 3, r = 0.8, leg = 2.6, neck = 4.2, head = 1.3, ear = 0.7, tail = 1 } },
	{ id = "Octopuff",   name = "Octopuff",   rarity = "Rare",     price = 5000,   income = 110,
		color = Color3.fromRGB(190, 90, 255), shape = { body = 1.2, r = 1.6, leg = 2.4, legs = 8, head = 2.4 } },
	{ id = "Pengloon",   name = "Pengloon",   rarity = "Rare",     price = 8000,   income = 160,
		color = Color3.fromRGB(45, 55, 80), shape = { body = 2, r = 1.2, leg = 0.8, neck = 0.6, head = 1.5, tail = 0.5, snout = 0.8 } },
	-- Epic
	{ id = "Dinoloon",   name = "Dinoloon",   rarity = "Epic",     price = 30000,  income = 550,
		color = Color3.fromRGB(80, 200, 170), shape = { body = 3.6, r = 1, leg = 1.8, neck = 2.4, head = 1.7, tail = 3.2, spikes = true } },
	{ id = "Unipuff",    name = "Unipuff",    rarity = "Epic",     price = 50000,  income = 850,
		color = Color3.fromRGB(255, 200, 240), shape = { body = 3.2, r = 0.9, leg = 2.2, neck = 1.8, head = 1.5, ear = 0.8, tail = 1.6, horn = 1.6 } },
	-- Legendary
	{ id = "Dragonflate", name = "Dragonflate", rarity = "Legendary", price = 200000, income = 2800,
		color = Color3.fromRGB(230, 60, 60), shape = { body = 3.8, r = 1.1, leg = 1.8, neck = 2.2, head = 1.9, ear = 1, tail = 3, wings = 3.4, horn = 0.9 } },
	{ id = "Whaleloon",  name = "Whaleloon",  rarity = "Legendary", price = 320000, income = 4400,
		color = Color3.fromRGB(70, 130, 230), shape = { body = 5, r = 1.9, leg = 0, tail = 2.4, spout = true } },
	-- Mythic
	{ id = "Cosmoose",   name = "Cosmoose",   rarity = "Mythic",   price = 1500000, income = 17000,
		color = Color3.fromRGB(60, 35, 130), shape = { body = 4, r = 1.3, leg = 2.8, neck = 1.8, head = 2, tail = 0.8, antlers = 3 } },
	-- Secret (never on the Pump Line normally — events, codes and admin only)
	{ id = "Stormserpent", name = "Stormserpent", rarity = "Secret", price = 5000000, income = 60000,
		color = Color3.fromRGB(35, 40, 60), shape = { body = 7, r = 1, leg = 0, neck = 2.4, head = 2, tail = 4, horn = 1.4, wings = 2.4 } },
}

---------------------------------------------------------------------
-- Inflation stages — THE core twist.
-- Floaties inflate on your base over time (even offline).
-- Bigger = more income, BUT whoever steals it floats higher (lift),
-- walks slower (slow), needs longer to grab it (stealTime),
-- and it takes more darts to pop it (popHits).
---------------------------------------------------------------------
Config.Stages = {
	{ name = "Deflated", scale = 1.00, income = 1.0, growTime = 90,   lift = 0.15, slow = 0, stealTime = 1.5, popHits = 2 },
	{ name = "Puffy",    scale = 1.35, income = 1.7, growTime = 300,  lift = 0.30, slow = 2, stealTime = 2.0, popHits = 3 },
	{ name = "Round",    scale = 1.70, income = 2.8, growTime = 900,  lift = 0.45, slow = 4, stealTime = 2.5, popHits = 3 },
	{ name = "Chonky",   scale = 2.10, income = 4.5, growTime = 2400, lift = 0.60, slow = 6, stealTime = 3.0, popHits = 4 },
	{ name = "MEGA",     scale = 2.60, income = 7.0, growTime = nil,  lift = 0.75, slow = 8, stealTime = 4.0, popHits = 5 },
}

---------------------------------------------------------------------
-- Mutations (rolled when a Floatie appears on the Pump Line).
-- Checked rarest-first (bottom of the list first).
---------------------------------------------------------------------
Config.Mutations = {
	{ id = "Normal",  mult = 1,   chance = 0 },
	{ id = "Glitter", mult = 1.5, chance = 0.08 },
	{ id = "Neon",    mult = 2,   chance = 0.035 },
	{ id = "Foil",    mult = 3,   chance = 0.012 },
	{ id = "Rainbow", mult = 5,   chance = 0.003 },
	{ id = "Thunder", mult = 8,   chance = 0, eventOnly = "Thunderstorm", eventChance = 0.03 },
}

---------------------------------------------------------------------
-- Rebirth: resets Air + Floaties (you KEEP your single best Floatie),
-- gives +50% income forever and +2 pedestals.
---------------------------------------------------------------------
Config.RebirthIncomeBonus = 0.5
function Config.RebirthCost(rebirths)
	return 250000 * (5 ^ rebirths)
end

---------------------------------------------------------------------
-- Automatic server events (every EventInterval seconds)
---------------------------------------------------------------------
Config.EventInterval = 15 * 60
Config.Events = {
	HeliumRain   = { title = "🎈 HELIUM RAIN",  desc = "Mutation chance x4 on the Pump Line!", duration = 180, mutationMult = 4 },
	GoldenHour   = { title = "✨ GOLDEN HOUR",  desc = "All Floaties earn 2x Air!",            duration = 180, incomeMult = 2 },
	WindyDay     = { title = "🌬️ WINDY DAY",    desc = "Gusts shove anyone carrying a Floatie!", duration = 180, wind = true },
	Thunderstorm = { title = "⛈️ THUNDERSTORM", desc = "Thunder Floaties (x8) can appear!",   duration = 150, mutationMult = 1.5 },
	SecretSkies  = { title = "🌌 SECRET SKIES", desc = "A Stormserpent may drift down the Pump Line!", duration = 120, secretChance = 0.01 },
}

---------------------------------------------------------------------
-- Promo codes (post these on TikTok / Discord / the game description)
---------------------------------------------------------------------
Config.Codes = {
	RELEASE = { air = 500 },
	FLOATIE = { floatie = "Kittiloon", mutation = "Glitter" },
	-- LIKES1K = { air = 5000 },   -- example: add when the game hits 1,000 likes
}

---------------------------------------------------------------------
-- Robux products. Create them on create.roblox.com, then paste the IDs.
-- id = 0 means "not set up yet" (the shop button tells the player "coming soon").
---------------------------------------------------------------------
Config.GamePasses = {
	DoubleAir      = { id = 0, title = "2x Air",       desc = "Double all Air forever",         price = 199 },
	VIP            = { id = 0, title = "VIP",          desc = "+20% Air and a gold VIP tag",    price = 149 },
	ExtraPedestals = { id = 0, title = "+5 Pedestals", desc = "Hold 5 more Floaties",           price = 249 },
	FastInflate    = { id = 0, title = "Fast Inflate", desc = "Your Floaties grow 1.5x faster", price = 179 },
}
Config.DevProducts = {
	AirPackSmall     = { id = 0, title = "Air Pack",           desc = "5 minutes of your income (min 500)",   price = 29 },
	AirPackLarge     = { id = 0, title = "Big Air Pack",       desc = "30 minutes of your income (min 3K)",   price = 129 },
	InstantLock      = { id = 0, title = "Instant Lock",       desc = "Lock your base right now",             price = 15 },
	ServerHeliumRain = { id = 0, title = "Server Helium Rain", desc = "Start Helium Rain for EVERYONE",       price = 99 },
}
-- Set true to pretend you own every pass while testing in Studio.
Config.TestPassesInStudio = false

---------------------------------------------------------------------
-- Sounds. The defaults are Roblox's built-in sounds so the game isn't silent.
-- To use better ones: Studio > Toolbox > Audio, search (e.g. "balloon pop"),
-- right-click a sound > Copy Asset ID, and paste it here as "rbxassetid://123456".
-- "" = no sound.
---------------------------------------------------------------------
Config.Sounds = {
	Pop     = { id = "rbxasset://sounds/snap.mp3",               volume = 0.8 },  -- a Floatie pops
	Buy     = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 }, -- success toasts (buy, steal, sell)
	Alert   = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.6 }, -- someone is stealing yours
	Error   = { id = "rbxasset://sounds/button.wav",              volume = 0.5, pitch = 0.7 },
	Dart    = { id = "rbxasset://sounds/swoosh.wav",              volume = 0.4, pitch = 1.6 },
	Click   = { id = "rbxasset://sounds/button.wav",              volume = 0.4 },
	Event   = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.3 },
	Music   = { id = "", volume = 0.25 },  -- paste a music asset id to add looping background music
}

---------------------------------------------------------------------
-- Lookups + helpers (no need to edit below)
---------------------------------------------------------------------
Config.FloatieById = {}
for _, f in ipairs(Config.Floaties) do
	Config.FloatieById[f.id] = f
end
Config.MutationById = {}
for _, m in ipairs(Config.Mutations) do
	Config.MutationById[m.id] = m
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }
function Config.Format(n)
	n = tonumber(n) or 0
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local fmt = "%.0f%s"
	if n < 10 then
		fmt = "%.2f%s"
	elseif n < 100 then
		fmt = "%.1f%s"
	end
	return string.format(fmt, n, SUFFIXES[i])
end

function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return string.format("%dh %02dm", math.floor(m / 60), m % 60)
	end
	return string.format("%d:%02d", m, s)
end

return Config
