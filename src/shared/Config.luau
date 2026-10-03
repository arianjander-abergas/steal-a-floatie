--[[
	Floatie Farm — Config (ModuleScript in ReplicatedStorage.Shared)

	Every number in the game lives in Config. Most of it is split into small
	files, one per system, in ReplicatedStorage > Shared > ConfigParts:
	  UI           HUD + panel colors, sounds, how Floaties wobble
	  Floaties     rarities and every Floatie (name, odds, income, shape)
	  Rolling      inflate time, mutations, pump tiers, conveyor, Backpack
	  Progression  levels + sizes, grades, traits, slots, upgrades, rebirth, Index
	  Rewards      potions, daily + playtime rewards, events, promo codes
	  Robux        game passes, developer products, Starter Pack, offers
	  Map          base / plaza / tower sizes
	  Trading      trade rules
	require(Shared.Config) returns ONE table with all of them merged in, so
	code just reads Config.Floaties, Config.Pumps, Config.UI, ...
	After editing anything, bump Config.Version so players see the update number.
]]

local Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.GameName = "Floatie Farm"
Config.Version = "1.1.0"                -- bump every update, shown in the HUD
Config.DataStoreName = "FloatieData_v1" -- NEVER rename after launch (players lose saves)
Config.SaveVersion = 2                  -- the save format; DataService converts older saves

-- Your Roblox UserId goes here so you can use admin chat commands in live servers
-- (in Studio, and for the place owner, commands always work).
Config.AdminUserIds = {
	-- 123456789,
}

Config.MaxPlayers = 8                   -- one base each
Config.StartingAir = 100
Config.BaseWalkSpeed = 16

Config.OfflineIncomeCap = 3 * 3600      -- offline Air counts for up to 3h...
Config.OfflineIncomeRate = 0.5          -- ...at 50% speed
Config.AutosaveInterval = 60            -- seconds between saves of each player

Config.HomeCooldown = 3                 -- seconds between teleports (server rate limit; the HUD uses it too).
                                        -- The server lets requests through 0.5 s early so network lag never eats a click.
Config.SellMult = 20                    -- selling pays income x 20 x grade x mutation

---------------------------------------------------------------------
-- The system files (ConfigParts), merged in
---------------------------------------------------------------------
local PARTS = { "UI", "Floaties", "Rolling", "Progression", "Rewards", "Robux", "Map", "Trading" }
local partsFolder = script.Parent:WaitForChild("ConfigParts")
for _, name in ipairs(PARTS) do
	local part = require(partsFolder:WaitForChild(name))
	for key, value in pairs(part) do
		assert(Config[key] == nil, "Config." .. key .. " is set in two places")
		Config[key] = value
	end
end

---------------------------------------------------------------------
-- Lookups (no need to edit below)
---------------------------------------------------------------------
Config.FloatieById = {}
for i, f in ipairs(Config.Floaties) do
	f.index = i
	Config.FloatieById[f.id] = f
end
Config.MutationById = {}
for i, m in ipairs(Config.Mutations) do
	m.index = i
	Config.MutationById[m.id] = m
end
Config.GradeById = {}
for i, g in ipairs(Config.Grades) do
	g.index = i
	Config.GradeById[g.id] = g
end
Config.TraitById = {}
for i, t in ipairs(Config.Traits) do
	t.index = i
	Config.TraitById[t.id] = t
end
Config.UpgradeById = {}
for i, u in ipairs(Config.Upgrades) do
	u.index = i
	Config.UpgradeById[u.id] = u
end
-- rarity names from Common to Secret
Config.RarityOrder = {}
for name in pairs(Config.Rarities) do
	table.insert(Config.RarityOrder, name)
end
table.sort(Config.RarityOrder, function(a, b)
	return Config.Rarities[a].order < Config.Rarities[b].order
end)

---------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Config.Format(12345) -> "12.3K"
function Config.Format(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0" -- NaN
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		if n > 0 and n < 10 and n ~= math.floor(n) then
			return sign .. string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", "")
		end
		return sign .. tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	-- round down, so 999.99K never shows as "1000K"; "24.0K" -> "24K", "1.50K" -> "1.5K".
	-- (+1e-7: dividing by 1000 can leave 9.2B as 9.1999999..., which must still show "9.2B")
	local digits
	if n < 10 then
		digits = string.format("%.2f", math.floor(n * 100 + 1e-7) / 100)
	elseif n < 100 then
		digits = string.format("%.1f", math.floor(n * 10 + 1e-7) / 10)
	else
		digits = tostring(math.floor(n + 1e-7))
	end
	if string.find(digits, ".", 1, true) then
		digits = string.gsub(string.gsub(digits, "0+$", ""), "%.$", "")
	end
	return sign .. digits .. SUFFIXES[i]
end

-- Config.FormatTime(75) -> "1:15", 4000 -> "1h 06m"
function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return string.format("%dh %02dm", math.floor(m / 60), m % 60)
	end
	return string.format("%d:%02d", m, s)
end

-- Config.FormatOdds(24000) -> "1 in 24K"
function Config.FormatOdds(odds)
	return "1 in " .. Config.Format(odds)
end

-- Config.FormatMult(1.5) -> "x1.5"
function Config.FormatMult(x)
	x = tonumber(x) or 1
	if x == math.floor(x) then
		return "x" .. Config.Format(x)
	end
	return "x" .. string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
end

return Config
