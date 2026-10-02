--[[
	Floatie Farm — Sell (ModuleScript child of the ClientMain LocalScript)
	The Sell Units stall (and the 💰 Sell buttons):
	  • Auto Sell: pick a rarity and every new roll at or below it turns into
	    Air at once (mutated Floaties are always kept)
	  • a grid of your unlocked Floaties, cheapest first: tap to pick, then
	    SELL. Quick picks for everything in the Backpack.
	  Selling pays income x 20 x grade x mutation (Config.SellMult).

	API:
	  Sell.mount(canvas) -> Panel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer
local C = Config.UI

local Sell = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Auto Sell choices: sell everything up to (and including) this rarity
local AUTO_CHOICES = { "Off", "Common", "Uncommon", "Rare", "Epic" }

local panel = nil
local grid = nil
local tiles = {}
local picked = {}        -- [uid] = true
local autoTabs = nil
local totalLabel, sellButton, emptyLabel = nil, nil, nil
local busy = false

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function sellable()
	local list = {}
	for _, f in ipairs(State.list()) do
		if not f.locked then
			table.insert(list, f)
		end
	end
	return Cards.sorted(list, "value")
end

local function refreshTotal()
	local total, count = 0, 0
	for uid in pairs(picked) do
		local f = State.get(uid)
		if f and not f.locked then
			total += Formulas.sellValue(f)
			count += 1
		else
			picked[uid] = nil
		end
	end
	totalLabel.Text = ("Picked: %d  →  %s Air"):format(count, Config.Format(total))
	Kit.setButtonColor(sellButton, if count > 0 then C.Green else C.Grey)
	return count, total
end

local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	local list = sellable()
	for i, f in ipairs(list) do
		local tile = tiles[i]
		if not tile then
			tile = Cards.tile(grid, {
				onClick = function(t)
					if t.f then
						picked[t.f.uid] = if picked[t.f.uid] then nil else true
						t:setSelected(picked[t.f.uid] == true)
						refreshTotal()
					end
				end,
			})
			tiles[i] = tile
		end
		tile.button.LayoutOrder = i
		tile:set(f)
		tile:setSelected(picked[f.uid] == true)
	end
	for i = #list + 1, #tiles do
		tiles[i]:set(nil)
	end
	emptyLabel.Visible = #list == 0
	-- Auto Sell chip from the save (autoSell = sell below this rarity order)
	local autoSell = (State.data.settings and State.data.settings.autoSell) or 0
	local choice = if autoSell <= 1 then "Off" else (Config.RarityOrder[autoSell - 1] or "Off")
	if autoTabs.selected ~= choice then
		autoTabs:select(choice, true)
	end
	refreshTotal()
end

local function sellPicked()
	if busy then
		return
	end
	local count, total = refreshTotal()
	if count == 0 then
		Notify.toast("Tap Floaties to pick them first", "info")
		return
	end
	local uids, valuable = {}, false
	for uid in pairs(picked) do
		table.insert(uids, uid)
		local f = State.get(uid)
		local def = f and Config.FloatieById[f.id]
		if f and def and (Config.Rarities[def.rarity].order >= 4 or f.mut ~= "Normal" or (f.level or 1) >= 10) then
			valuable = true
		end
	end
	local function go()
		busy = true
		local ok, success = pcall(function()
			return remotes.SellFloaties:InvokeServer(uids)
		end)
		busy = false
		if ok and success then
			picked = {}
			refresh()
		end
	end
	if valuable then
		Kit.confirm({
			title = "Sell " .. count .. " Floaties?",
			text = "Some of them are rare, mutated or levelled up. Sell them all for " .. Config.Format(total) .. " Air?",
			yes = "Sell", no = "Keep",
		}, function(yes)
			if yes then
				go()
			end
		end)
	else
		go()
	end
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Sell.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "SellPanel", title = "Sell Floaties", icon = "💰", color = C.Green,
		size = Vector2.new(660, 352), onOpen = refresh,
		onClose = function()
			picked = {}
		end,
	})
	local body = panel.body -- 636 x 284

	Kit.label(body, {
		Name = "AutoTitle", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(110, 30), Text = "Auto Sell:",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 20 })
	local items = {}
	for _, name in ipairs(AUTO_CHOICES) do
		local rarity = Config.Rarities[name]
		table.insert(items, { name = name, text = name, color = if rarity then rarity.color else C.Red, width = if name == "Uncommon" then 104 else 86 })
	end
	autoTabs = Kit.tabs(body, { Position = UDim2.fromOffset(104, 0), Size = UDim2.fromOffset(500, 34) }, {
		items = items, button = Vector2.new(86, 32), gap = 6, maxTextSize = 16,
		onSelect = function(name)
			local order = if name == "Off" then 0 else Config.Rarities[name].order + 1
			remotes.SetSetting:FireServer("autoSell", order)
			Notify.toast(if name == "Off" then "Auto Sell is off" else "New " .. name .. " and lower Floaties will turn into Air", "info")
		end,
	})
	Kit.label(body, {
		Name = "Note", Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 18),
		Text = "✨ Mutated Floaties are always kept. Tap Floaties below to pick them, then SELL.", TextColor3 = C.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { outline = 0, maxTextSize = 15 })

	grid = Kit.scroll(body, { Name = "Grid", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -112) }, { cell = Vector2.new(92, 112), gap = 6 })
	emptyLabel = Kit.label(body, {
		Name = "Empty", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -112),
		Text = "Nothing to sell (locked Floaties stay safe)", TextColor3 = C.TextSoft, Visible = false,
	}, { maxTextSize = 22 })

	local bar = Kit.make("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, body)
	local pickBackpack = Kit.button(bar, { Name = "PickBackpack", Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(150, 44) }, { text = "🎒 Pick Backpack", color = C.Blue, maxTextSize = 17 })
	Kit.onClick(pickBackpack, function()
		for _, f in ipairs(sellable()) do
			if not f.slot then
				picked[f.uid] = true
			end
		end
		refresh()
	end)
	local clear = Kit.button(bar, { Name = "Clear", Position = UDim2.fromOffset(158, 1), Size = UDim2.fromOffset(84, 44) }, { text = "Clear", color = C.Grey, maxTextSize = 17 })
	Kit.onClick(clear, function()
		picked = {}
		refresh()
	end)
	totalLabel = Kit.label(bar, {
		Name = "Total", Position = UDim2.fromOffset(250, 1), Size = UDim2.new(1, -420, 0, 44), TextColor3 = C.Gold,
	}, { maxTextSize = 20 })
	sellButton = Kit.button(bar, { Name = "SellPicked", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 1), Size = UDim2.fromOffset(160, 44) }, { text = "💰 SELL", color = C.Grey, maxTextSize = 22 })
	Kit.onClick(sellButton, sellPicked)

	State.changed:Connect(function()
		task.defer(refresh)
	end)
	return panel
end

return Sell
