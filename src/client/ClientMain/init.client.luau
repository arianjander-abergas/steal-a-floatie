--[[
	Floatie Farm — ClientMain (LocalScript in StarterPlayer.StarterPlayerScripts)
	Boots the client: builds the screens, mounts the HUD, the roll buttons,
	panels and toasts, starts the world effects, and runs the slow UI loop.
	Each feature lives in its own ModuleScript child of this script.

	Screens (all Kit canvases, see Kit.createScreen):
	  FloatieHUD     DisplayOrder 1    HUD, roll buttons, the boxes under the top bar
	  FloatiePanels  DisplayOrder 5    Shop / Rebirth / Codes / ...
	  FloatieReveal  DisplayOrder 8    the big reveal of a rare pull
	  FloatieToasts  DisplayOrder 10   toasts (above everything)
]]

local StarterGui = game:GetService("StarterGui")

local Kit = require(script:WaitForChild("Kit"))
local Sounds = require(script:WaitForChild("Sounds"))
local Notify = require(script:WaitForChild("Notify"))
local State = require(script:WaitForChild("State"))
local HUD = require(script:WaitForChild("HUD"))
local RollUI = require(script:WaitForChild("RollUI"))
local Shop = require(script:WaitForChild("Shop"))
local Rebirth = require(script:WaitForChild("Rebirth"))
local Codes = require(script:WaitForChild("Codes"))
local Backpack = require(script:WaitForChild("Backpack"))
local Sell = require(script:WaitForChild("Sell"))
local FloatieCard = require(script:WaitForChild("FloatieCard"))
local PumpShop = require(script:WaitForChild("PumpShop"))
local Upgrades = require(script:WaitForChild("Upgrades"))
local Reroll = require(script:WaitForChild("Reroll"))
local EventBanner = require(script:WaitForChild("EventBanner"))
local Tutorial = require(script:WaitForChild("Tutorial"))
local Prompts = require(script:WaitForChild("Prompts"))
local Effects = require(script:WaitForChild("Effects"))
local Conveyor = require(script:WaitForChild("Conveyor"))

-- run a step; a broken module warns once instead of stopping the rest
local warned = {}
local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not warned[name] then
		warned[name] = true
		warn(("[ClientMain] %s failed: %s"):format(name, tostring(err)))
	end
end

-- no tools in this game: hide the hotbar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

---------------------------------------------------------------------
-- 1. sounds first so every Kit button can click
---------------------------------------------------------------------
safe("Sounds.init", Sounds.init)
Kit.setSoundPlayer(Sounds.play)

---------------------------------------------------------------------
-- 2. screens
---------------------------------------------------------------------
local _, hudCanvas = Kit.createScreen("FloatieHUD", 1)
local _, panelCanvas = Kit.createScreen("FloatiePanels", 5)
local _, revealCanvas = Kit.createScreen("FloatieReveal", 8)
local _, toastCanvas = Kit.createScreen("FloatieToasts", 10)

---------------------------------------------------------------------
-- 3. toasts, your save's copy, panels, HUD
---------------------------------------------------------------------
safe("Notify.mount", Notify.mount, toastCanvas)
safe("State.start", State.start)
Kit.setDialogCanvas(panelCanvas)

local panels = {}

-- the HUD opens panels by name through this (it never requires a panel module)
local function togglePanel(name)
	local panel = panels[name]
	if panel then
		panel:toggle()
	else
		Notify.toast("Coming soon!", "info")
	end
end

-- stalls and buttons that should always open (never close) their panel
local function openPanel(name)
	local panel = panels[name]
	if panel then
		panel:open()
	else
		Notify.toast("Coming soon!", "info")
	end
end

local function openCard(uid)
	FloatieCard.open(uid)
end

-- the Floatie card's Grade / Trait shortcuts
local function openReroll(kind, uid)
	Reroll.open(kind, uid)
end

local actions = { togglePanel = togglePanel, openPanel = openPanel, openCard = openCard, openReroll = openReroll }

safe("Shop.mount", function()
	panels.Shop = Shop.mount(panelCanvas)
end)
safe("Rebirth.mount", function()
	panels.Rebirth = Rebirth.mount(panelCanvas)
end)
safe("Codes.mount", function()
	panels.Codes = Codes.mount(panelCanvas)
end)
safe("Backpack.mount", function()
	panels.Backpack = Backpack.mount(panelCanvas, actions)
end)
safe("Sell.mount", function()
	panels.Sell = Sell.mount(panelCanvas)
end)
safe("PumpShop.mount", function()
	panels.PumpShop = PumpShop.mount(panelCanvas)
end)
safe("Upgrades.mount", function()
	panels.Upgrades = Upgrades.mount(panelCanvas)
end)
safe("Reroll.mount", function()
	local stands = Reroll.mount(panelCanvas)
	panels.Grading = stands.Grading
	panels.Traits = stands.Traits
end)
safe("FloatieCard.mount", FloatieCard.mount, panelCanvas, actions)

local topStack = hudCanvas -- fallback if the HUD fails to mount
safe("HUD.mount", function()
	topStack = HUD.mount(hudCanvas, { togglePanel = togglePanel }).topStack
end)
safe("Notify.follow", Notify.follow, topStack)
safe("RollUI.mount", RollUI.mount, hudCanvas, revealCanvas, { openPanel = openPanel })

---------------------------------------------------------------------
-- 4. boxes under the top bar, world effects
---------------------------------------------------------------------
safe("EventBanner.mount", EventBanner.mount, topStack)
safe("Effects.start", Effects.start)
safe("Conveyor.start", Conveyor.start)

-- what the tutorial arrow can point at
local function findTarget(name)
	local area = RollUI.area()
	if name == "RollArea" then
		return area
	end
	if area and area:FindFirstChild(name) then
		return area[name]
	end
	return HUD.getTile(name)
end

---------------------------------------------------------------------
-- 5. these wait for workspace.Map.Bases, so they go last
---------------------------------------------------------------------
safe("Prompts.start", Prompts.start, actions)
safe("Tutorial.mount", Tutorial.mount, hudCanvas, findTarget)

---------------------------------------------------------------------
-- 6. slow UI loop (every 0.2 s)
---------------------------------------------------------------------
local STEPS = {
	{ "Tutorial.update", Tutorial.update },
	{ "Prompts.update", Prompts.update },
	{ "EventBanner.update", EventBanner.update },
	{ "Rebirth.update", Rebirth.update },
	{ "HUD.update", HUD.update },
}
task.spawn(function()
	while true do
		for _, step in ipairs(STEPS) do
			safe(step[1], step[2])
		end
		task.wait(0.2)
	end
end)
