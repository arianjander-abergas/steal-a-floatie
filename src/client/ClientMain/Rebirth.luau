--[[
	Floatie Farm — Rebirth (ModuleScript child of the ClientMain LocalScript)
	The Rebirth window: exactly what you lose, keep and get before you
	confirm, a progress bar towards the cost, and a big REBIRTH button
	(orange when you can afford it). The server checks the cost again.

	Rebirth costs ALL your Air (at least the cost); Floaties, pumps and
	upgrades stay. Each one: +50% Cash, +25% Luck, +2 slots (up to +6),
	5 Grade Tokens (Config.Rebirth).

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

local panel = nil
local ui = {}
local busy = false

local function slotsFrom(n)
	return math.min(n * R.SlotsEach, R.SlotsMax)
end

local function refresh()
	if not panel then
		return
	end
	local n = player:GetAttribute("Rebirths") or 0
	local air = tonumber(player:GetAttribute("Air")) or 0
	local cost = Formulas.rebirthCost(n)
	ui.title.Text = ("Rebirth %d  →  %d"):format(n, n + 1)
	ui.lose.Text = "❌ YOU LOSE\nAll your Air (" .. Config.Format(math.max(air, cost)) .. ")"
	ui.cash.Text = ("💰 Cash  x%s  →  x%s"):format(Config.FormatMult(1 + n * R.CashBonus):sub(2), Config.FormatMult(1 + (n + 1) * R.CashBonus):sub(2))
	ui.luck.Text = ("🍀 Luck  x%s  →  x%s"):format(Config.FormatMult(1 + n * R.LuckBonus):sub(2), Config.FormatMult(1 + (n + 1) * R.LuckBonus):sub(2))
	local slotsNow, slotsNext = slotsFrom(n), slotsFrom(n + 1)
	ui.slots.Text = if slotsNext > slotsNow then ("🧩 Slots  +%d  →  +%d"):format(slotsNow, slotsNext) else ("🧩 Slots  +%d (max)"):format(slotsNow)
	ui.tokens.Text = "🎫 +" .. R.GradeTokens .. " Grade Tokens"
	ui.bar:set(air / cost, Config.Format(air) .. " / " .. Config.Format(cost) .. " Air")
	local canAfford = air >= cost
	Kit.setButtonColor(ui.button, if canAfford then C.Orange else C.Grey)
	Kit.setButtonText(ui.button, if canAfford then "🌟 REBIRTH" else "Need " .. Config.Format(cost - air) .. " more Air")
end

local function doRebirth()
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
end

function Rebirth.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "RebirthPanel", title = "Rebirth", icon = "🌟", color = C.Orange,
		size = Vector2.new(560, 346), onOpen = refresh,
	})
	local body = panel.body -- 536 x 278

	ui.title = Kit.label(body, { Name = "Step", Size = UDim2.new(1, 0, 0, 34) }, { outline = 3, maxTextSize = 32 })

	-- lose / keep
	local lose = Kit.plate(body, { Name = "Lose", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.5, -4, 0, 64) },
		{ color = Color3.fromRGB(110, 40, 50), transparency = 0, radius = 12, border = 3 })
	ui.lose = Kit.label(lose, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), TextWrapped = true }, { maxTextSize = 18 })
	local keep = Kit.plate(body, { Name = "Keep", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 40), Size = UDim2.new(0.5, -4, 0, 64) },
		{ color = Color3.fromRGB(40, 95, 60), transparency = 0, radius = 12, border = 3 })
	Kit.label(keep, {
		Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), TextWrapped = true,
		Text = "✅ YOU KEEP\nFloaties (levels, grades, traits), pumps, upgrades",
	}, { maxTextSize = 18 })

	-- what you get
	local get = Kit.plate(body, { Name = "Get", Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 92) },
		{ color = C.Row, transparency = 0, radius = 12, border = 3 })
	Kit.label(get, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Text = "⭐ YOU GET (forever)", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left }, { maxTextSize = 18 })
	local function line(x, y)
		return Kit.label(get, { Position = UDim2.new(x, 10, 0, y), Size = UDim2.new(0.5, -20, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }, { maxTextSize = 20 })
	end
	ui.cash = line(0, 28)
	ui.luck = line(0.5, 28)
	ui.slots = line(0, 58)
	ui.tokens = line(0.5, 58)
	ui.cash.TextColor3 = C.Cash
	ui.luck.TextColor3 = C.Luck

	ui.bar = Kit.progress(body, { Name = "Cost", Position = UDim2.fromOffset(0, 210), Size = UDim2.new(1, 0, 0, 22) }, { color = C.Orange, maxTextSize = 16 })
	ui.button = Kit.button(body, {
		Name = "RebirthButton", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(300, 42),
	}, { text = "REBIRTH", color = C.Grey, maxTextSize = 24 })
	Kit.onClick(ui.button, function()
		local n = player:GetAttribute("Rebirths") or 0
		local air = tonumber(player:GetAttribute("Air")) or 0
		local cost = Formulas.rebirthCost(n)
		if air < cost then
			Notify.toast("You need " .. Config.Format(cost) .. " Air to rebirth", "error")
			return
		end
		Kit.confirm({
			title = "Rebirth now?",
			text = "You lose all " .. Config.Format(air) .. " Air and keep your Floaties, pumps and upgrades. Ready?",
			yes = "🌟 Rebirth", no = "Not yet",
		}, function(yes)
			if yes then
				doRebirth()
			end
		end)
	end)

	refresh()
	return panel
end

function Rebirth.update()
	if panel and panel:isOpen() then
		refresh()
	end
end

return Rebirth
