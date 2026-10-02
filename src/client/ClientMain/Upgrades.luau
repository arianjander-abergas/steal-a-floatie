--[[
	Floatie Farm — Upgrades (ModuleScript child of the ClientMain LocalScript)
	The Upgrades window (like the Anime Card Farm one): a row per upgrade
	with its icon, name, what it does, "Current: ...", a green Air button
	and a yellow Robux button (one level each). Numbers: Config.Upgrades.

	API:
	  Upgrades.mount(canvas) -> Panel
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local C = Config.UI

local Upgrades = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local panel = nil
local rows = {}
local busy = false

-- "Current: ..." for each upgrade at `level`
local function currentText(up, level)
	if up.id == "slots" then
		return ("Current: %d slots"):format(tonumber(player:GetAttribute("SlotCount")) or Config.Slots.Start)
	elseif up.id == "walk" then
		return ("Current: %d walk speed"):format(Config.BaseWalkSpeed + level * up.per)
	elseif up.id == "time" then
		return ("Current: -%d%% inflate time"):format(math.floor(level * up.per * 100 + 0.5))
	end
	return ("Current: +%d%%"):format(math.floor(level * up.per * 100 + 0.5))
end

local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	local levels = State.data.upgrades or {}
	local air = tonumber(player:GetAttribute("Air")) or 0
	for _, row in ipairs(rows) do
		local up = row.up
		local level = levels[up.id] or 0
		local cost = Formulas.upgradeCost(up.id, level)
		row.current.Text = currentText(up, level) .. ("   (Lv %d/%d)"):format(level, up.max)
		if cost then
			Kit.setButtonText(row.air, "💨 " .. Config.Format(cost))
			Kit.setButtonColor(row.air, if air >= cost then C.Green else C.Grey)
			Kit.setEnabled(row.robux, true)
			Kit.setButtonText(row.robux, "R$ " .. up.robux)
		else
			Kit.setButtonText(row.air, "MAXED")
			Kit.setButtonColor(row.air, C.Grey)
			Kit.setButtonText(row.robux, "MAXED")
			Kit.setEnabled(row.robux, false)
		end
	end
end

local function buy(up)
	if busy then
		return
	end
	busy = true
	local ok, success, msg = pcall(function()
		return remotes.BuyUpgrade:InvokeServer(up.id)
	end)
	busy = false
	if ok and msg then
		Notify.toast(msg, if success then "success" else "error")
	end
end

local function buyRobux(up)
	local id = Config.UpgradeProducts[up.id] or 0
	if id == 0 then
		Notify.toast("Coming soon! (Developer: paste the product ID into Config.UpgradeProducts)", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

function Upgrades.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "UpgradesPanel", title = "Upgrades", icon = "⬆️", color = C.Green,
		size = Vector2.new(600, 352), onOpen = refresh,
	})
	local list = Kit.scroll(panel.body, { Name = "Upgrades" }, { gap = 8 })
	for i, up in ipairs(Config.Upgrades) do
		local frame = Kit.plate(list, {
			Name = up.id, Size = UDim2.new(1, -12, 0, 96), LayoutOrder = i,
		}, { color = C.Row, transparency = 0, radius = 12, border = 3 })
		Kit.label(frame, { Name = "Icon", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(80, 80), Text = up.icon }, { outline = 0 })
		Kit.label(frame, {
			Name = "UpgradeName", Position = UDim2.fromOffset(96, 6), Size = UDim2.new(1, -260, 0, 32),
			Text = up.name, TextXAlignment = Enum.TextXAlignment.Left,
		}, { outline = 3, maxTextSize = 28 })
		Kit.label(frame, {
			Name = "Desc", Position = UDim2.fromOffset(96, 40), Size = UDim2.new(1, -260, 0, 20),
			Text = up.desc, TextColor3 = C.TextSoft, TextXAlignment = Enum.TextXAlignment.Left,
		}, { outline = 0, maxTextSize = 17 })
		local current = Kit.label(frame, {
			Name = "Current", Position = UDim2.fromOffset(96, 62), Size = UDim2.new(1, -260, 0, 24),
			TextColor3 = C.Income, TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 20 })
		local air = Kit.button(frame, {
			Name = "Air", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(150, 38),
		}, { text = "", color = C.Green, maxTextSize = 22, radius = 8 })
		local robux = Kit.button(frame, {
			Name = "Robux", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(150, 38),
		}, { text = "R$ " .. up.robux, color = C.Yellow, maxTextSize = 22, radius = 8 })
		Kit.onClick(air, function()
			buy(up)
		end)
		Kit.onClick(robux, function()
			buyRobux(up)
		end)
		table.insert(rows, { up = up, current = current, air = air, robux = robux })
	end

	State.changed:Connect(function(what)
		if what == "upgrades" or what == "full" then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Air"):Connect(refresh)
	player:GetAttributeChangedSignal("SlotCount"):Connect(refresh)
	return panel
end

return Upgrades
