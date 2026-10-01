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
local HUD = require(script:WaitForChild("HUD"))
local RollUI = require(script:WaitForChild("RollUI"))
local Shop = require(script:WaitForChild("Shop"))
local Rebirth = require(script:WaitForChild("Rebirth"))
local Codes = require(script:WaitForChild("Codes"))
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
-- 3. toasts, panels, HUD
---------------------------------------------------------------------
safe("Notify.mount", Notify.mount, toastCanvas)
local panels = {}
safe("Shop.mount", function()
	panels.Shop = Shop.mount(panelCanvas)
end)
safe("Rebirth.mount", function()
	panels.Rebirth = Rebirth.mount(panelCanvas)
end)
safe("Codes.mount", function()
	panels.Codes = Codes.mount(panelCanvas)
end)

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
	if area and area:FindFirstChild(name) then
		return area[name]
	end
	return HUD.getTile(name)
end

---------------------------------------------------------------------
-- 5. these wait for workspace.Map.Bases, so they go last
---------------------------------------------------------------------
safe("Prompts.start", Prompts.start, { openPanel = openPanel })
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
