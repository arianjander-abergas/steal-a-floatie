--[[
	Config part: Map (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	Sizes of the map MapBuilder builds. Merged into Config, so code reads
	Config.Map. Change a number, press Play, and the map is rebuilt.

	Layout (top-down): 8 bases in a ring around a round plaza; the Tower
	stands in the middle of the plaza, the 8 stalls around it.
	Each base faces the plaza: its entrance (front) points at the Tower,
	its Pump Machine is at the back, and its own conveyor runs from the
	pump to the front, with the slot pads on both sides.
]]

local Map = {}

Map.Map = {
	GroundSize = 780,          -- the grass square
	BaseRadius = 262,          -- plaza centre -> base centre (the same for all 8 bases)
	BaseWidth = 96,            -- across the base
	BaseDepth = 124,           -- front (entrance) to back (pump)

	-- slot pads: 3 columns each side of the conveyor x 7 rows = 42
	SlotColumnsX = { 14, 26, 38 }, -- distance from the conveyor centre line
	SlotRowsZ = { -44, -31, -18, -5, 8, 21, 34 }, -- front row first (-Z = towards the plaza)
	SlotSize = 9,

	ConveyorWidth = 8,
	ConveyorStartZ = 46,       -- just in front of the Pump Machine
	ConveyorEndZ = -50,        -- the front end

	PlazaRadius = 118,
	StallRadius = 84,
	PathWidth = 16,

	TowerBaseRadius = 26,      -- the bottom band; every band steps in a little
	TowerStep = 1,             -- studs narrower per band
	TowerBandHeight = 10,
	-- bottom to top: material, color
	TowerBands = {
		{ "WoodPlanks",   Color3.fromRGB(163, 116, 61) },
		{ "Cobblestone",  Color3.fromRGB(143, 143, 143) },
		{ "Brick",        Color3.fromRGB(181, 83, 60) },
		{ "Sandstone",    Color3.fromRGB(227, 201, 143) },
		{ "Slate",        Color3.fromRGB(78, 85, 99) },
		{ "Marble",       Color3.fromRGB(237, 237, 237) },
		{ "Granite",      Color3.fromRGB(123, 123, 132) },
		{ "Ice",          Color3.fromRGB(207, 239, 255) },
		{ "Glass",        Color3.fromRGB(168, 221, 245) },
		{ "DiamondPlate", Color3.fromRGB(154, 167, 184) },
		{ "Neon",         Color3.fromRGB(255, 79, 168) },
		{ "Foil",         Color3.fromRGB(233, 224, 247) },
	},

	BaseColors = {
		Color3.fromRGB(255, 140, 170), Color3.fromRGB(120, 185, 255), Color3.fromRGB(150, 225, 120), Color3.fromRGB(255, 200, 100),
		Color3.fromRGB(190, 150, 255), Color3.fromRGB(100, 220, 205), Color3.fromRGB(255, 155, 110), Color3.fromRGB(235, 225, 120),
	},
}

-- the 8 stalls around the Tower, clockwise from the Tower door.
-- panel = the window the stall opens (the same one the HUD opens)
Map.Stalls = {
	{ name = "Upgrades",     title = "UPGRADES",      icon = "⬆️", color = Color3.fromRGB(70, 205, 95),   panel = "Upgrades" },
	{ name = "Sell",         title = "SELL UNITS",    icon = "💰", color = Color3.fromRGB(255, 205, 50),  panel = "Sell" },
	{ name = "PumpShop",     title = "PUMP SHOP",     icon = "🎈", color = Color3.fromRGB(255, 95, 160),  panel = "PumpShop" },
	{ name = "Grading",      title = "GRADING",       icon = "🎫", color = Color3.fromRGB(255, 160, 40),  panel = "Grading" },
	{ name = "Traits",       title = "TRAITS",        icon = "💎", color = Color3.fromRGB(150, 85, 245),  panel = "Traits" },
	{ name = "TradingPost",  title = "TRADING POST",  icon = "🤝", color = Color3.fromRGB(65, 150, 255),  panel = "Trade" },
	{ name = "IndexBook",    title = "INDEX",         icon = "📖", color = Color3.fromRGB(40, 200, 190),  panel = "Index" },
	{ name = "RebirthAltar", title = "REBIRTH",       icon = "🌟", color = Color3.fromRGB(235, 55, 65),   panel = "Rebirth" },
}

return Map
