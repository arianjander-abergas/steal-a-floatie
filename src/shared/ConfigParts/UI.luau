--[[
	Config part: UI (ModuleScript in ReplicatedStorage.Shared.ConfigParts)
	HUD + panel colors, sounds, and how Floaties wobble. Merged into Config,
	so code reads Config.UI / Config.Sounds / Config.Feel.
]]

local UI = {}

---------------------------------------------------------------------
-- Game feel (client-side visuals only — safe to tweak any time)
---------------------------------------------------------------------
UI.Feel = {
	BobHeight = 0.35,     -- studs a Floatie floats up and down
	BobSpeed = 1.6,       -- bob cycles speed
	SquishAmount = 0.06,  -- 0.06 = stretches 6% taller / squats 3% wider
	SquishSpeed = 3.2,
	AnimDistance = 140,   -- only animate Floaties this close to the camera (performance)
}

---------------------------------------------------------------------
-- UI colors (client HUD + panels). Kit builds light-to-dark button
-- gradients from these automatically.
---------------------------------------------------------------------
UI.UI = {
	-- Text
	Text          = Color3.fromRGB(255, 255, 255), -- chunky white text
	TextDark      = Color3.fromRGB(55, 48, 85),    -- small text on light panels (no outline)
	Outline       = Color3.fromRGB(28, 22, 45),    -- text outlines, button + panel borders
	-- Surfaces
	PanelTop      = Color3.fromRGB(250, 248, 255), -- panel body gradient (top)
	PanelBottom   = Color3.fromRGB(205, 214, 245), -- panel body gradient (bottom)
	Row           = Color3.fromRGB(255, 255, 255), -- list rows inside panels
	RowAlt        = Color3.fromRGB(236, 240, 252), -- every other row / empty slots
	Input         = Color3.fromRGB(255, 255, 255), -- text boxes
	HudBg         = Color3.fromRGB(30, 28, 48),    -- dark HUD plates (drawn ~15% transparent)
	-- Button / header colors
	Green         = Color3.fromRGB(70, 205, 95),
	Blue          = Color3.fromRGB(65, 150, 255),
	Orange        = Color3.fromRGB(255, 160, 40),
	Yellow        = Color3.fromRGB(255, 205, 50),
	Pink          = Color3.fromRGB(255, 95, 160),
	Purple        = Color3.fromRGB(150, 85, 245),
	Teal          = Color3.fromRGB(40, 200, 190),
	Red           = Color3.fromRGB(235, 55, 65),   -- the big X and badges
	Grey          = Color3.fromRGB(135, 135, 155), -- disabled / owned
	-- HUD values
	Income        = Color3.fromRGB(120, 255, 140), -- "+12 Air/s"
	Luck          = Color3.fromRGB(110, 235, 110),
	Cash          = Color3.fromRGB(255, 210, 60),
	Gold          = Color3.fromRGB(255, 210, 90),  -- shop section headers
	Good          = Color3.fromRGB(120, 255, 140), -- code redeemed
	Bad           = Color3.fromRGB(255, 120, 120), -- code error
	-- Boxes under the top bar
	EventBanner   = Color3.fromRGB(120, 60, 210),
	EventDesc     = Color3.fromRGB(230, 220, 255),
	TutorialBox   = Color3.fromRGB(255, 225, 90),
	TutorialArrow = Color3.fromRGB(255, 230, 60),
	-- Toasts by kind
	Toast = {
		info    = Color3.fromRGB(45, 45, 70),
		success = Color3.fromRGB(40, 150, 90),
		error   = Color3.fromRGB(190, 60, 70),
		alert   = Color3.fromRGB(230, 70, 40),
		event   = Color3.fromRGB(140, 70, 220),
	},
}

---------------------------------------------------------------------
-- Sounds. The defaults are Roblox's built-in sounds so the game isn't silent.
-- To use better ones: Studio > Toolbox > Audio, search (e.g. "balloon pop"),
-- right-click a sound > Copy Asset ID, and paste it here as "rbxassetid://123456".
-- "" = no sound.
---------------------------------------------------------------------
UI.Sounds = {
	Pop     = { id = "rbxasset://sounds/snap.mp3",               volume = 0.8 },  -- a Floatie pops out of its balloon
	Buy     = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 }, -- success toasts (buy, sell, claim)
	Alert   = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.6 },
	Error   = { id = "rbxasset://sounds/button.wav",              volume = 0.5, pitch = 0.7 },
	Click   = { id = "rbxasset://sounds/button.wav",              volume = 0.4 },
	Event   = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.3 },
	Inflate = { id = "rbxasset://sounds/action_jump.mp3",         volume = 0.3, pitch = 1.5 },  -- the pump starts
	Rare    = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 1.6 },  -- Rare+ reveal
	Music   = { id = "", volume = 0.25 },  -- paste a music asset id to add looping background music
}

return UI
