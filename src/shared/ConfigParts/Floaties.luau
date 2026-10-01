--[[
	Config part: Floaties (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Rarities and every Floatie. Merged into Config, so code reads
	Config.Rarities / Config.Floaties.

	Each Floatie:
	  id / name   never change an id after launch (saves store it)
	  rarity      one of Config.Rarities
	  odds        "1 in X": the chance to roll it is (1 / odds) x your Luck
	  income      Air per second at Lv 1, grade C, no trait, no mutation
	  color       main balloon color (color2 = second color for two-tone parts)
	  shape       how the balloon animal is twisted together, see FloatieModel
]]

local Floaties = {}

---------------------------------------------------------------------
-- Rarities, from Common (order 1) to Secret (order 10)
---------------------------------------------------------------------
Floaties.Rarities = {
	Common    = { order = 1,  color = Color3.fromRGB(154, 163, 174) },
	Uncommon  = { order = 2,  color = Color3.fromRGB(63, 174, 90) },
	Rare      = { order = 3,  color = Color3.fromRGB(47, 127, 224) },
	Epic      = { order = 4,  color = Color3.fromRGB(155, 77, 224) },
	Legendary = { order = 5,  color = Color3.fromRGB(240, 138, 36) },
	Mythic    = { order = 6,  color = Color3.fromRGB(226, 61, 107) },
	Divine    = { order = 7,  color = Color3.fromRGB(217, 178, 48) },
	Celestial = { order = 8,  color = Color3.fromRGB(47, 184, 216) },
	Cosmic    = { order = 9,  color = Color3.fromRGB(91, 63, 208) },
	Secret    = { order = 10, color = Color3.fromRGB(27, 27, 31) },
}

---------------------------------------------------------------------
-- Floaties
---------------------------------------------------------------------
Floaties.Floaties = {
	-- Common
	{ id = "Pupfloat", name = "Pupfloat", rarity = "Common", odds = 2, income = 1,
		color = Color3.fromRGB(255, 125, 160), shape = { body = 3, r = 0.8, leg = 1.6, neck = 1.2, head = 1.5, ear = 1.4, tail = 1.2 } },
	{ id = "Kittiloon", name = "Kittiloon", rarity = "Common", odds = 3, income = 2,
		color = Color3.fromRGB(255, 170, 70), shape = { body = 2.6, r = 0.75, leg = 1.3, neck = 0.8, head = 1.6, ear = 0.8, tail = 2 } },
	{ id = "Bunbob", name = "Bunbob", rarity = "Common", odds = 5, income = 3,
		color = Color3.fromRGB(245, 245, 255), shape = { body = 2, r = 0.9, leg = 1, neck = 0.6, head = 1.5, ear = 2.4, tail = 0.4 } },

	-- Uncommon
	{ id = "Duckpuff", name = "Duckpuff", rarity = "Uncommon", odds = 15, income = 8,
		color = Color3.fromRGB(255, 230, 60), shape = { body = 2.4, r = 1, leg = 0.9, neck = 1.2, head = 1.4, tail = 0.6, snout = 1.2 } },
	{ id = "Froggle", name = "Froggle", rarity = "Uncommon", odds = 20, income = 11,
		color = Color3.fromRGB(60, 190, 90), shape = { body = 2.2, r = 1.1, leg = 1.2, neck = 0.3, head = 1.9, ear = 0.6 } },
	{ id = "Snailoon", name = "Snailoon", rarity = "Uncommon", odds = 25, income = 14,
		color = Color3.fromRGB(150, 220, 90), shape = { body = 3.4, r = 0.7, leg = 0, neck = 1.6, head = 1.1, ear = 1, shell = 2.4 } },

	-- Rare
	{ id = "Pengloon", name = "Pengloon", rarity = "Rare", odds = 60, income = 40,
		color = Color3.fromRGB(45, 55, 80), shape = { body = 2, r = 1.2, leg = 0.8, neck = 0.6, head = 1.5, tail = 0.5, snout = 0.8 } },
	{ id = "Giraffloat", name = "Giraffloat", rarity = "Rare", odds = 90, income = 55,
		color = Color3.fromRGB(240, 190, 90), shape = { body = 3, r = 0.8, leg = 2.6, neck = 4.2, head = 1.3, ear = 0.7, tail = 1 } },
	{ id = "Octopuff", name = "Octopuff", rarity = "Rare", odds = 130, income = 75,
		color = Color3.fromRGB(190, 90, 255), shape = { body = 1.2, r = 1.6, leg = 2.4, legs = 8, head = 2.4 } },

	-- Epic
	{ id = "Dinoloon", name = "Dinoloon", rarity = "Epic", odds = 400, income = 250,
		color = Color3.fromRGB(80, 200, 170), shape = { body = 3.6, r = 1, leg = 1.8, neck = 2.4, head = 1.7, tail = 3.2, spikes = true } },
	{ id = "Unipuff", name = "Unipuff", rarity = "Epic", odds = 600, income = 340,
		color = Color3.fromRGB(255, 200, 240), shape = { body = 3.2, r = 0.9, leg = 2.2, neck = 1.8, head = 1.5, ear = 0.8, tail = 1.6, horn = 1.6 } },

	-- Legendary
	{ id = "Whaleloon", name = "Whaleloon", rarity = "Legendary", odds = 3000, income = 1500,
		color = Color3.fromRGB(70, 130, 230), shape = { body = 5, r = 1.9, leg = 0, tail = 2.4, spout = true } },
	{ id = "Dragonflate", name = "Dragonflate", rarity = "Legendary", odds = 5000, income = 2000,
		color = Color3.fromRGB(230, 60, 60), shape = { body = 3.8, r = 1.1, leg = 1.8, neck = 2.2, head = 1.9, ear = 1, tail = 3, wings = 3.4, horn = 0.9 } },

	-- Mythic
	{ id = "Cosmoose", name = "Cosmoose", rarity = "Mythic", odds = 30000, income = 10000,
		color = Color3.fromRGB(60, 35, 130), shape = { body = 4, r = 1.3, leg = 2.8, neck = 1.8, head = 2, tail = 0.8, antlers = 3 } },

	-- Secret
	{ id = "Stormserpent", name = "Stormserpent", rarity = "Secret", odds = 6000000000, income = 100000000,
		color = Color3.fromRGB(35, 40, 60), shape = { body = 7, r = 1, leg = 0, neck = 2.4, head = 2, tail = 4, horn = 1.4, wings = 2.4 } },
}

return Floaties
