--[[
	Steal a Floatie — Rebirth (ModuleScript child of the ClientMain LocalScript)
	The Rebirth panel: shows your rebirth count, the next cost and the reward,
	plus a big REBIRTH button. The server checks the cost; the button only
	turns orange when you can afford it and grey when you can't (it stays
	clickable either way, same as v0.1.2).

	API:
	  Rebirth.mount(canvas) -> Panel   -- builds the panel on the "FloatiePanels" Kit canvas
	  Rebirth.update()                 -- init calls this every 0.2 s; refreshes while open
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local RebirthRE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")

local player = Players.LocalPlayer
local C = Config.UI

local Rebirth = {}

---------------------------------------------------------------------
-- State (filled in by mount)
---------------------------------------------------------------------
local panel = nil      -- the Kit Panel
local infoLabel = nil  -- the rebirth count / cost / reward text
local rebirthButton = nil

---------------------------------------------------------------------
-- Refresh: text + button color from the Rebirths and Air attributes
---------------------------------------------------------------------
local function refresh()
	if not infoLabel then
		return -- not mounted yet
	end
	local n = player:GetAttribute("Rebirths") or 0
	local cost = Config.RebirthCost(n)
	infoLabel.Text = ("Rebirths: %d\nCost: %s Air\n\nReward: +%d%% Air forever, +%d pedestals\n\nResets your Air and Floaties — you KEEP your best Floatie.")
		:format(n, Config.Format(cost), math.floor(Config.RebirthIncomeBonus * 100), Config.PedestalsPerRebirth)
	local canAfford = (player:GetAttribute("Air") or 0) >= cost
	Kit.setButtonColor(rebirthButton, canAfford and C.Orange or C.Grey)
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Rebirth.mount(canvas)
	if panel then
		return panel -- already built
	end

	panel = Kit.panel(canvas, {
		name = "RebirthPanel",
		title = "Rebirth",
		icon = "🌟",
		color = C.Orange,
		onOpen = refresh, -- fresh numbers every time the panel pops open
	})
	local body = panel.body

	infoLabel = Kit.label(body, {
		Name = "Info",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 170),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, { maxTextSize = 24 })

	rebirthButton = Kit.button(body, {
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(240, 56),
	}, { text = "REBIRTH", color = C.Grey })

	Kit.onClick(rebirthButton, function()
		RebirthRE:FireServer()
		panel:close()
	end)

	refresh()
	return panel
end

---------------------------------------------------------------------
-- Slow loop hook (init, every 0.2 s)
---------------------------------------------------------------------
function Rebirth.update()
	if panel and panel:isOpen() then
		refresh()
	end
end

return Rebirth
