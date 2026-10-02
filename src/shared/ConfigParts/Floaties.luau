--[[
	Config part: Floaties (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Rarities and every Floatie. Merged into Config, so code reads
	Config.Rarities / Config.Floaties.

	Each Floatie:
	  id / name   never change an id after launch (saves store it)
	  rarity      one of Config.Rarities
	  odds        "1 in X": the chance to roll it is (1 / odds) x your Luck
	  income      Air per second at Lv 1, grade C, no trait, no mutation
	  color       main balloon color; color2 = second color (two-tone parts, spots, manes...)
	  shape       how the balloon animal is twisted together: see the list at the top
	              of ReplicatedStorage.Shared.FloatieModel
	Every rarity also gets its own look on top (FloatieModel applyRarity):
	  Rare shine + sparkle, Epic purple sparkle, Legendary gold knots + glitter,
	  Mythic aura, Divine light + rays, Celestial see-through + stardust,
	  Cosmic mini balloons in orbit, Secret one-of-a-kind effects.
]]

local Floaties = {}

local C = Color3.fromRGB

---------------------------------------------------------------------
-- Rarities, from Common (order 1) to Secret (order 10)
---------------------------------------------------------------------
Floaties.Rarities = {
	Common    = { order = 1,  color = C(154, 163, 174) },
	Uncommon  = { order = 2,  color = C(63, 174, 90) },
	Rare      = { order = 3,  color = C(47, 127, 224) },
	Epic      = { order = 4,  color = C(155, 77, 224) },
	Legendary = { order = 5,  color = C(240, 138, 36) },
	Mythic    = { order = 6,  color = C(226, 61, 107) },
	Divine    = { order = 7,  color = C(217, 178, 48) },
	Celestial = { order = 8,  color = C(47, 184, 216) },
	Cosmic    = { order = 9,  color = C(91, 63, 208) },
	Secret    = { order = 10, color = C(27, 27, 31) },
}

---------------------------------------------------------------------
-- Floaties: 5 per rarity, 50 in all
---------------------------------------------------------------------
Floaties.Floaties = {
	-- Common: plain glossy latex
	{ id = "Pupfloat", name = "Pupfloat", rarity = "Common", odds = 2, income = 1,
		color = C(255, 125, 160), desc = "Puppy with long floppy ears and a curly tail",
		shape = { body = 3, r = 0.8, leg = 1.6, neck = 1.2, head = 1.5, ear = 1.3, ears = "flop", tail = 1.2, tailStyle = "curl" } },
	{ id = "Kittiloon", name = "Kittiloon", rarity = "Common", odds = 3, income = 2,
		color = C(255, 170, 70), desc = "Cat with pointy ears and a question-mark tail",
		shape = { body = 2.6, r = 0.75, leg = 1.3, neck = 0.8, head = 1.6, ear = 0.8, tail = 2 } },
	{ id = "Bunbob", name = "Bunbob", rarity = "Common", odds = 5, income = 3,
		color = C(245, 245, 255), color2 = C(255, 205, 225), desc = "Bunny with very tall ears and a pom-pom tail",
		shape = { body = 2, r = 0.9, leg = 1, neck = 0.6, head = 1.5, ear = 2.4, tail = 0.5, tailStyle = "tuft" } },
	{ id = "Mousepop", name = "Mousepop", rarity = "Common", odds = 7, income = 4,
		color = C(185, 185, 200), color2 = C(255, 170, 195), desc = "Mouse with two big round ear-balloons and a thin string tail",
		shape = { body = 2.2, r = 0.8, leg = 0.8, neck = 0.3, head = 1.4, ear = 1.1, ears = "round", two = { "Ear" },
			snout = 0.25, snoutColor = C(255, 150, 180), tail = 2.2, tailStyle = "thin" } },
	{ id = "Piggypuff", name = "Piggypuff", rarity = "Common", odds = 10, income = 5,
		color = C(255, 175, 195), desc = "Round piglet with a flat snout and a corkscrew tail",
		shape = { body = 1.9, r = 1.15, leg = 0.7, neck = 0.2, head = 1.5, ear = 0.5, snout = 1, snoutStyle = "disc",
			snoutColor = C(240, 130, 160), tail = 1, tailStyle = "curl" } },

	-- Uncommon: two-tone colors
	{ id = "Duckpuff", name = "Duckpuff", rarity = "Uncommon", odds = 15, income = 8,
		color = C(255, 230, 60), color2 = C(255, 150, 40), desc = "Duck with an orange beak and webbed feet",
		shape = { body = 2.4, r = 1, leg = 0.9, neck = 1.2, head = 1.4, tail = 0.6, snout = 1.2, two = { "Leg" } } },
	{ id = "Froggle", name = "Froggle", rarity = "Uncommon", odds = 20, income = 11,
		color = C(60, 190, 90), color2 = C(220, 250, 160), desc = "Frog with bulging eye balloons on top and a wide grin",
		shape = { body = 2.2, r = 1.1, leg = 1.2, neck = 0.3, head = 1.9, eyes = "frog", belly = C(220, 250, 160) } },
	{ id = "Snailoon", name = "Snailoon", rarity = "Uncommon", odds = 25, income = 14,
		color = C(150, 220, 90), color2 = C(240, 165, 120), desc = "Snail with a spiral shell balloon",
		shape = { body = 3.4, r = 0.7, leg = 0, neck = 1.6, head = 1.1, ear = 1, shell = 2.4, two = { "Shell" } } },
	{ id = "Beeboop", name = "Beeboop", rarity = "Uncommon", odds = 35, income = 19,
		color = C(255, 215, 50), color2 = C(40, 35, 45), desc = "Bee with a striped body, tiny clear wings and a knot stinger",
		shape = { body = 2.4, r = 1, leg = 0.5, neck = 0.2, head = 1.25, antennae = 0.9, stripes = { count = 3, color = C(40, 35, 45) },
			wings = 1.7, wingStyle = "insect", tail = 0.7, two = { "Tail" } } },
	{ id = "Turtloon", name = "Turtloon", rarity = "Uncommon", odds = 50, income = 25,
		color = C(110, 190, 90), color2 = C(165, 120, 70), desc = "Turtle with a dome shell covered in little bump balloons",
		shape = { body = 2.3, r = 0.75, leg = 0.7, neck = 0.8, head = 1.1, tail = 0.4, shell = 2.6, dome = true, bumps = 7, two = { "Shell" } } },

	-- Rare: extra shine, soft sparkle
	{ id = "Pengloon", name = "Pengloon", rarity = "Rare", odds = 60, income = 40,
		color = C(45, 55, 80), desc = "Penguin in a black-and-white tuxedo with flippers",
		shape = { upright = true, body = 2, r = 1.15, leg = 0.5, head = 1.4, snout = 0.6, belly = C(245, 245, 250), wings = 1.2, tail = 0.3 } },
	{ id = "Giraffloat", name = "Giraffloat", rarity = "Rare", odds = 90, income = 55,
		color = C(240, 190, 90), color2 = C(170, 110, 50), desc = "Giraffe with a very long neck and spots",
		shape = { body = 3, r = 0.8, leg = 2.6, neck = 4.2, head = 1.3, ear = 0.7, tail = 1, spots = { count = 8 } } },
	{ id = "Octopuff", name = "Octopuff", rarity = "Rare", odds = 130, income = 75,
		color = C(190, 90, 255), color2 = C(255, 180, 240), desc = "Octopus with eight twisty tentacles",
		shape = { body = 1.2, r = 1.6, leg = 2.4, legs = 8, curlLegs = true, suckers = true, head = 2.4 } },
	{ id = "Flamingloon", name = "Flamingloon", rarity = "Rare", odds = 180, income = 95,
		color = C(255, 130, 180), desc = "Pink flamingo standing on one leg with an S-shaped neck",
		shape = { body = 2.2, r = 0.9, leg = 3, oneLeg = true, neck = 3, neckCurve = true, head = 1, snout = 0.9,
			snoutColor = C(70, 50, 70), wings = 1.6, tail = 0.7 } },
	{ id = "Crabble", name = "Crabble", rarity = "Rare", odds = 250, income = 120,
		color = C(230, 70, 60), color2 = C(255, 200, 190), desc = "Wide red crab with two huge claws and eyes on stalks",
		shape = { body = 1.4, r = 1.3, leg = 1.1, legs = 6, head = 0, claws = 1.7, eyestalks = 1.1 } },

	-- Epic: patterned parts, purple sparkle
	{ id = "Dinoloon", name = "Dinoloon", rarity = "Epic", odds = 400, income = 250,
		color = C(80, 200, 170), color2 = C(40, 140, 120), desc = "Long-necked dinosaur with back spikes",
		shape = { body = 3.6, r = 1, leg = 1.8, neck = 2.4, head = 1.7, tail = 3.2, spikes = true, spots = { count = 6 } } },
	{ id = "Unipuff", name = "Unipuff", rarity = "Epic", odds = 600, income = 340,
		color = C(255, 200, 240), color2 = C(190, 150, 255), desc = "Unicorn with a gold spiral horn",
		shape = { body = 3.2, r = 0.9, leg = 2.2, neck = 1.8, head = 1.5, ear = 0.8, tail = 1.6, tailStyle = "tuft", horn = 1.6 } },
	{ id = "Elephloat", name = "Elephloat", rarity = "Epic", odds = 800, income = 430,
		color = C(150, 170, 215), color2 = C(255, 190, 210), desc = "Elephant with a curling trunk and big disc ears",
		shape = { body = 3, r = 1.3, leg = 1.6, neck = 0.3, head = 1.8, trunk = 2.2, ear = 1.7, ears = "disc", tusks = 0.8, tail = 0.8, two = { "Ear" } } },
	{ id = "Sharkoon", name = "Sharkoon", rarity = "Epic", odds = 1100, income = 560,
		color = C(110, 145, 190), color2 = C(70, 100, 150), desc = "Shark with dorsal and tail fins and a row of white teeth",
		shape = { body = 4.2, r = 1.15, leg = 0, head = 0, float = 0.6, yaw = 0.55, fins = 1.6, sideFins = 1.2, tailStyle = "fin", tailFin = 1.8,
			teeth = true, belly = C(240, 245, 250), two = { "Fin", "TailFin" } } },
	{ id = "Owlbloon", name = "Owlbloon", rarity = "Epic", odds = 1500, income = 700,
		color = C(150, 110, 80), color2 = C(235, 210, 170), desc = "Owl with huge eyes, ear tufts and folded wings",
		shape = { upright = true, body = 1.8, r = 1.25, leg = 0.5, head = 1.9, eyes = "big", ear = 0.6, snout = 0.4, wings = 1.6, belly = C(235, 210, 170) } },

	-- Legendary: gold trim, warm glow
	{ id = "Whaleloon", name = "Whaleloon", rarity = "Legendary", odds = 3000, income = 1500,
		color = C(70, 130, 230), desc = "Blue whale with a water spout",
		shape = { body = 5, r = 1.9, leg = 0, yaw = 0.5, tailStyle = "fin", tailFin = 2.2, spout = true, belly = C(200, 225, 255) } },
	{ id = "Dragonflate", name = "Dragonflate", rarity = "Legendary", odds = 5000, income = 2000,
		color = C(230, 60, 60), color2 = C(255, 190, 120), desc = "Red dragon with wings and small horns",
		shape = { body = 3.8, r = 1.1, leg = 1.8, neck = 2.2, head = 1.9, ear = 1, tail = 3, wings = 3.4, horn = 0.9, belly = C(255, 190, 120) } },
	{ id = "Lionflate", name = "Lionflate", rarity = "Legendary", odds = 7500, income = 2600,
		color = C(240, 190, 80), color2 = C(200, 110, 40), desc = "Lion whose mane is a ring of twelve small balloons",
		shape = { body = 3.2, r = 1.1, leg = 1.6, neck = 0.6, head = 1.8, ear = 0.5, snout = 0.4, snoutColor = C(150, 90, 60),
			mane = { count = 12, size = 0.85 }, tail = 2.2, tailStyle = "tuft" } },
	{ id = "Phoenixpop", name = "Phoenixpop", rarity = "Legendary", odds = 11000, income = 3300,
		color = C(255, 90, 40), color2 = C(255, 215, 70), desc = "Phoenix with flame-tipped tail feathers and ember sparks",
		shape = { body = 2.6, r = 1, leg = 1, neck = 1.2, head = 1.3, snout = 0.7, snoutColor = C(255, 210, 80), wings = 3, wingStyle = "feather",
			tail = 2.6, tailStyle = "flames", particles = "embers" } },
	{ id = "Mammothoon", name = "Mammothoon", rarity = "Legendary", odds = 15000, income = 4000,
		color = C(140, 95, 60), color2 = C(105, 65, 40), desc = "Woolly mammoth with curved tusks and a shaggy fur ring",
		shape = { body = 3.4, r = 1.6, leg = 1.8, neck = 0.3, head = 2, trunk = 2.4, tusks = 2.2, ear = 0.7, ears = "disc",
			furRing = { count = 14, size = 1 }, tail = 0.8, two = { "Fur" } } },

	-- Mythic: aura particles around the body
	{ id = "Cosmoose", name = "Cosmoose", rarity = "Mythic", odds = 30000, income = 10000,
		color = C(60, 35, 130), desc = "Deep-purple moose with giant gold antlers",
		shape = { body = 4, r = 1.3, leg = 2.8, neck = 1.8, head = 2, tail = 0.8, antlers = 3 } },
	{ id = "Pegasoar", name = "Pegasoar", rarity = "Mythic", odds = 50000, income = 14000,
		color = C(250, 250, 255), color2 = C(170, 215, 255), desc = "Winged horse with little cloud hooves",
		shape = { body = 3.2, r = 0.95, leg = 2.2, neck = 1.8, head = 1.5, ear = 0.7, tail = 1.8, tailStyle = "tuft", wings = 3.6,
			wingStyle = "feather", cloudHooves = true, two = { "Wing" } } },
	{ id = "Griffloat", name = "Griffloat", rarity = "Mythic", odds = 75000, income = 18000,
		color = C(215, 165, 90), color2 = C(250, 250, 245), desc = "Griffin: eagle head and wings on a lion body",
		shape = { body = 3.2, r = 1, leg = 1.7, neck = 1, head = 1.6, snout = 0.9, snoutColor = C(255, 200, 60), wings = 3.2, wingStyle = "feather",
			tail = 2, tailStyle = "tuft", two = { "Head", "Neck", "Wing" } } },
	{ id = "Hydrapuff", name = "Hydrapuff", rarity = "Mythic", odds = 110000, income = 24000,
		color = C(60, 180, 150), color2 = C(220, 255, 170), desc = "Three serpent heads sharing one round body",
		shape = { body = 1.8, r = 1.5, leg = 1, heads = 3, neck = 2.6, head = 1.2, tail = 2.2, spikes = true, belly = C(220, 255, 170) } },
	{ id = "Krakenloon", name = "Krakenloon", rarity = "Mythic", odds = 150000, income = 30000,
		color = C(170, 40, 70), color2 = C(255, 170, 190), desc = "Kraken with a huge head, ten tentacles and suction dots",
		shape = { body = 1.4, r = 2, leg = 3, legs = 10, curlLegs = true, suckers = true, head = 0, eyes = "big" } },

	-- Divine: white-gold, halo, light rays
	{ id = "Templetoise", name = "Templetoise", rarity = "Divine", odds = 300000, income = 80000,
		color = C(120, 175, 110), color2 = C(235, 215, 160), desc = "Tortoise carrying a tiny white temple with a gold roof",
		shape = { body = 2.6, r = 0.9, leg = 0.9, neck = 0.9, head = 1.1, tail = 0.4, shell = 2.9, dome = true, temple = true, halo = true, two = { "Shell" } } },
	{ id = "Lumimoth", name = "Lumimoth", rarity = "Divine", odds = 500000, income = 105000,
		color = C(255, 240, 205), color2 = C(255, 190, 90), desc = "Giant moth with glowing patterned wings and falling light dust",
		shape = { body = 2.2, r = 0.7, leg = 0.6, neck = 0.1, head = 1, eyes = "big", antennae = 1.5, wings = 3.4, wingStyle = "moth",
			float = 0.8, halo = true, particles = "lightdust" } },
	{ id = "Koiriel", name = "Koiriel", rarity = "Divine", odds = 750000, income = 135000,
		color = C(255, 195, 70), color2 = C(255, 250, 240), desc = "Golden koi floating in the air with long flowing fins",
		shape = { body = 3.4, r = 0.95, leg = 0, head = 0, float = 1.4, yaw = 0.6, fins = 1.2, sideFins = 1.4, tailStyle = "fin", tailFin = 2.4,
			spots = { count = 5 }, halo = true, whiskers = true, two = { "TailFin" } } },
	{ id = "Solmane", name = "Solmane", rarity = "Divine", odds = 1100000, income = 165000,
		color = C(255, 215, 90), color2 = C(255, 150, 40), desc = "Sun lion whose mane is glowing sun rays",
		shape = { body = 3.2, r = 1.1, leg = 1.7, neck = 0.6, head = 1.8, ear = 0.5, mane = { count = 14, style = "rays", len = 1.3, color = C(255, 200, 60) },
			tail = 2, tailStyle = "tuft", halo = true, glow = C(255, 220, 140) } },
	{ id = "Seraphuff", name = "Seraphuff", rarity = "Divine", odds = 1500000, income = 200000,
		color = C(255, 250, 240), color2 = C(255, 215, 120), desc = "Guardian cat with three pairs of wings and a halo",
		shape = { body = 2.6, r = 0.85, leg = 1.3, neck = 0.8, head = 1.6, ear = 0.8, tail = 2, wings = 2.6, wingPairs = 3, wingStyle = "feather",
			halo = true, two = { "Wing" } } },

	-- Celestial: see-through, star speckles, stardust trail
	{ id = "Lunabun", name = "Lunabun", rarity = "Celestial", odds = 4000000, income = 600000,
		color = C(230, 230, 255), color2 = C(255, 240, 150), desc = "Moon rabbit sitting on a crescent-moon balloon",
		shape = { body = 1.8, r = 0.95, leg = 0.8, neck = 0.5, head = 1.5, ear = 2.4, tail = 0.4, tailStyle = "tuft", moon = 3.4, float = 1.4 } },
	{ id = "Auroraflap", name = "Auroraflap", rarity = "Celestial", odds = 6500000, income = 800000,
		color = C(240, 250, 255), color2 = C(120, 255, 200), desc = "Crane whose wings slowly cycle through aurora colors",
		shape = { body = 2.4, r = 0.85, leg = 2.8, neck = 2.6, neckCurve = true, head = 1, snout = 1.5, snoutColor = C(255, 200, 90),
			wings = 3.6, wingStyle = "feather", tail = 0.9, tags = { "AuroraCycle" }, two = { "Wing" } } },
	{ id = "Cometail", name = "Cometail", rarity = "Celestial", odds = 9000000, income = 1000000,
		color = C(255, 140, 60), color2 = C(255, 245, 220), desc = "Fox with a long blazing comet tail",
		shape = { body = 2.6, r = 0.85, leg = 1.4, neck = 0.8, head = 1.5, ear = 1.1, snout = 0.8, snoutColor = C(255, 140, 60),
			tail = 5, tailStyle = "comet", belly = C(255, 240, 225) } },
	{ id = "Nebuwhale", name = "Nebuwhale", rarity = "Celestial", odds = 13000000, income = 1250000,
		color = C(90, 120, 255), color2 = C(210, 160, 255), desc = "See-through star-speckled whale trailing stardust",
		shape = { body = 5, r = 1.8, leg = 0, float = 1, yaw = 0.5, tailStyle = "fin", tailFin = 2.2, spout = true, spoutColor = C(200, 180, 255),
			spots = { count = 9, color = C(255, 255, 255) }, particles = "stardust", two = { "TailFin" } } },
	{ id = "Constellion", name = "Constellion", rarity = "Celestial", odds = 20000000, income = 1500000,
		color = C(220, 240, 255), color2 = C(120, 180, 255), desc = "Lion made of glowing star points joined by thin light lines",
		shape = { style = "constellation" } },

	-- Cosmic: galaxy colors, orbiting mini balloons
	{ id = "Orbitoad", name = "Orbitoad", rarity = "Cosmic", odds = 60000000, income = 5000000,
		color = C(90, 60, 170), color2 = C(60, 210, 180), desc = "Toad with planet rings orbiting its body",
		shape = { body = 2.2, r = 1.3, leg = 1, neck = 0.2, head = 2, ear = 0.7, ears = "round", belly = C(60, 210, 180),
			rings = { { radius = 3.4, tilt = 0.35, color = C(255, 200, 120) }, { radius = 4, tilt = -0.45, color = C(150, 200, 255), spin = 0.4 } },
			orbit = { count = 2, radius = 2.6, size = 0.55, height = 1.6 } } },
	{ id = "Nebulynx", name = "Nebulynx", rarity = "Cosmic", odds = 100000000, income = 6500000,
		color = C(110, 70, 200), color2 = C(90, 170, 255), desc = "Lynx with galaxy colors and sparkling ear tufts",
		shape = { body = 2.8, r = 0.9, leg = 1.5, neck = 0.8, head = 1.6, ear = 1.3, ears = "tuft", tail = 0.8,
			spots = { count = 9, color = C(255, 255, 255) }, particles = "sparkle", two = { "Leg", "Tail" } } },
	{ id = "Quasaroo", name = "Quasaroo", rarity = "Cosmic", odds = 150000000, income = 8000000,
		color = C(200, 120, 255), color2 = C(255, 240, 200), desc = "Kangaroo whose pouch shoots a beam of light upward",
		shape = { upright = true, body = 2.6, r = 1, leg = 1.8, head = 1.4, ear = 1.4, snout = 0.5, snoutColor = C(200, 120, 255),
			tail = 3, pouch = true, beam = true } },
	{ id = "Voidjelly", name = "Voidjelly", rarity = "Cosmic", odds = 220000000, income = 10000000,
		color = C(25, 20, 45), color2 = C(190, 90, 255), desc = "Jellyfish with a black-hole bell and a swirling light ring",
		shape = { style = "jelly", bell = 2.6, tentacles = 8, float = 2.6,
			rings = { { radius = 2.3, tilt = 0, color = C(190, 120, 255), spin = 1.5, size = 0.28 } } } },
	{ id = "Supernovasaur", name = "Supernovasaur", rarity = "Cosmic", odds = 300000000, income = 12000000,
		color = C(255, 120, 60), color2 = C(255, 220, 120), desc = "T-rex that swells and flashes in a bright burst every few seconds",
		shape = { body = 3.6, r = 1.3, leg = 2.2, biped = true, tinyArms = true, neck = 1, head = 2.2, teeth = true, tail = 3.4, spikes = true,
			belly = C(255, 220, 120), tags = { "Supernova" }, glow = C(255, 180, 90) } },

	-- Secret: one-of-a-kind effect each
	{ id = "Glitchpup", name = "Glitchpup", rarity = "Secret", odds = 1000000000, income = 50000000,
		color = C(40, 240, 220), color2 = C(255, 60, 200), desc = "Puppy that glitches: parts jitter, colors split, pixel bits fall off",
		shape = { body = 3, r = 0.8, leg = 1.6, neck = 1.2, head = 1.5, ear = 1.4, ears = "flop", tail = 1.2, two = { "Ear", "Leg" },
			particles = "sparkle", tags = { "Glitch" } } },
	{ id = "Chronowl", name = "Chronowl", rarity = "Secret", odds = 2000000000, income = 65000000,
		color = C(120, 95, 70), color2 = C(255, 210, 100), desc = "Owl with clock-face eyes, ticking hands and orbiting gears",
		shape = { upright = true, body = 1.8, r = 1.25, leg = 0.5, head = 1.9, eyes = "big", ear = 0.6, snout = 0.4, wings = 1.6,
			belly = C(235, 215, 170), orbit = { count = 4, radius = 2.6, size = 0.6, height = 2.4, tick = true, neon = true,
				colors = { C(255, 210, 100), C(220, 180, 90) } } } },
	{ id = "Prismdrake", name = "Prismdrake", rarity = "Secret", odds = 3500000000, income = 80000000,
		color = C(190, 240, 255), color2 = C(255, 180, 255), desc = "Crystal dragon that throws rainbow light around it",
		shape = { body = 3.8, r = 1.1, leg = 1.8, neck = 2.2, head = 1.9, ear = 1, tail = 3, wings = 3.4, horn = 0.9,
			crystal = true, material = "Glass", transparency = 0.15, reflectance = 0.4, glow = C(220, 240, 255), tags = { "Prism" } } },
	{ id = "Stormserpent", name = "Stormserpent", rarity = "Secret", odds = 6000000000, income = 100000000,
		color = C(35, 40, 60), color2 = C(255, 235, 80), desc = "Dark sky serpent crackling with lightning",
		shape = { body = 7, r = 1, leg = 0, neck = 2.4, head = 2, tail = 4, horn = 1.4, wings = 2.4, particles = "lightning",
			glow = C(255, 240, 160), tags = { "StormFlash" } } },
	{ id = "Heliox", name = "Heliox", rarity = "Secret", odds = 10000000000, income = 120000000,
		color = C(255, 235, 215), color2 = C(255, 205, 90), desc = "The First Balloon: an ancient balloon spirit with a knot crown",
		shape = { style = "spirit", balloon = 3.4, float = 3.2, orbit = { count = 6, radius = 3.3, size = 0.65, height = 0 },
			glow = C(255, 230, 180), particles = "sparkle" } },
}

return Floaties
