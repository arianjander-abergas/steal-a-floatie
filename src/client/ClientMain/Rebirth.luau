--[[
	Floatie Farm — Rebirth (ModuleScript child of the ClientMain LocalScript)
	The Rebirth panel: your rebirth count, the cost, what you keep and what
	you get, plus a big REBIRTH button. The server checks the cost; the button
	only turns orange when you can afford it and grey when you can't.

	API:
	  Rebirth.mount(canvas) -> Panel   -- builds the panel on the "FloatiePanels" Kit canvas
	  Rebirth.update()                 -- init calls this every 0.2 s; refreshes while open
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local RebirthRF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")

local player = Players.LocalPlayer
local C = Config.UI
local R = Config.Rebirth

local Rebirth = {}

---------------------------------------------------------------------
-- State (filled in by mount)
---------------------------------------------------------------------
local panel = nil      -- the Kit Panel
local infoLabel = nil  -- the rebirth count / cost / reward text
local rebirthButton = nil
local busy = false

---------------------------------------------------------------------
-- Refresh: text + button color from the Rebirths and Air attributes
---------------------------------------------------------------------
local function refresh()
	if not infoLabel then
		return -- not mounted yet
	end
	local n = player:GetAttribute("Rebirths") or 0
	local cost = Formulas.rebirthCost(n)
	local slots = math.min(R.SlotsEach, math.max(0, R.SlotsMax - n * R.SlotsEach))
	infoLabel.Text = ("Rebirths: %d\nCost: ALL your Air (at least %s)\n\nReward: +%d%% Cash, +%d%% Luck%s, %d Grade Tokens\nYou keep your Floaties, pumps and upgrades.")
		:format(n, Config.Format(cost), math.floor(R.CashBonus * 100), math.floor(R.LuckBonus * 100),
			if slots > 0 then ", +" .. slots .. " slots" else "", R.GradeTokens)
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
	}, { maxTextSize = 22 })

	rebirthButton = Kit.button(body, {
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(240, 56),
	}, { text = "REBIRTH", color = C.Grey })

	Kit.onClick(rebirthButton, function()
		if busy then
			return
		end
		busy = true
		local ok, success, msg = pcall(RebirthRF.InvokeServer, RebirthRF)
		busy = false
		if ok then
			Notify.toast(msg or "", if success then "success" else "error")
			if success then
				panel:close()
			end
		end
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
