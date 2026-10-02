--[[
	Floatie Farm — Backpack (ModuleScript child of the ClientMain LocalScript)
	Every Floatie you own and every item, like the Anime Dice backpack:
	  • side tabs: Units / Items
	  • Units: a grid of Floatie tiles (sorted by income, rarity or level).
	    Click one for its card; with Lock mode on, a click locks / unlocks it.
	    Bottom bar: 🔒 Lock mode, Equip Best, Sell..., and "13/170" (Floaties
	    in the Backpack / its size; Floaties on your base don't count)
	  • Items: potions (Use), Grade Tokens, Trait Gems, Jackpot Rolls (Use)

	API:
	  Backpack.mount(canvas, actions) -> Panel  -- actions.openCard(uid), actions.openPanel(name)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer
local C = Config.UI

local Backpack = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local SORTS = { "income", "rarity", "level" }
local SORT_TEXT = { income = "💨 Income", rarity = "⭐ Rarity", level = "⬆️ Level" }

local panel = nil
local actions = {}
local tabs = nil
local unitsView, itemsView = nil, nil
local grid = nil
local tiles = {}
local sortIndex = 1
local lockMode = false
local lockButton, sortButton, capacityPlate, capacityLabel, emptyLabel = nil, nil, nil, nil, nil
local itemRows = {}

---------------------------------------------------------------------
-- Units
---------------------------------------------------------------------
local function onTileClick(tile)
	local f = tile.f
	if not f then
		return
	end
	if lockMode then
		remotes.SetLocked:FireServer(f.uid, not f.locked)
	elseif actions.openCard then
		actions.openCard(f.uid)
	end
end

local function refreshUnits()
	local list = Cards.sorted(State.list(), SORTS[sortIndex])
	for i, f in ipairs(list) do
		local tile = tiles[i]
		if not tile then
			tile = Cards.tile(grid, { onClick = onTileClick })
			tiles[i] = tile
		end
		tile.button.LayoutOrder = i
		tile:set(f)
		tile:setSelected(false)
	end
	for i = #list + 1, #tiles do
		tiles[i]:set(nil)
	end
	emptyLabel.Visible = #list == 0
	local inBackpack = 0
	for _, f in ipairs(list) do
		if not f.slot then
			inBackpack += 1
		end
	end
	local size = player:GetAttribute("BackpackSize") or Config.Rolling.BackpackSize
	capacityLabel.Text = "🎒 " .. inBackpack .. "/" .. size
	local g = capacityPlate:FindFirstChild("Gradient")
	if g then
		local color = if inBackpack >= size then C.Red else C.Blue
		g.Color = ColorSequence.new(Kit.shade(color, 0.3), Kit.shade(color, -0.2))
	end
end

---------------------------------------------------------------------
-- Items
---------------------------------------------------------------------
local ITEMS = {
	{ key = "Luck", icon = "🍀", potion = true },
	{ key = "Cash", icon = "💰", potion = true },
	{ key = "Mutation", icon = "🧪", potion = true },
	{ key = "jackpotRolls", icon = "🎰", name = "Jackpot Roll", desc = "Your next roll gets x" .. Config.Rolling.JackpotLuck .. " Luck", use = "jackpot" },
	{ key = "gradeTokens", icon = "🎫", name = "Grade Token", desc = "Reroll a grade at the Grading stand", go = "Grading" },
	{ key = "traitGems", icon = "💎", name = "Trait Gem", desc = "Reroll a trait at the Traits stand", go = "Traits" },
}

local function itemCount(item)
	local items = State.data.items or {}
	if item.potion then
		return (items.potions and items.potions[item.key]) or 0
	end
	return items[item.key] or 0
end

local function useItem(item)
	if item.potion then
		local ok, success, msg = pcall(function()
			return remotes.UsePotion:InvokeServer(item.key)
		end)
		if ok and msg then
			Notify.toast(msg, if success then "success" else "error")
		elseif not ok then
			Notify.toast("Coming soon!", "info")
		end
	elseif item.use == "jackpot" then
		local ok, success, msg = pcall(function()
			return remotes.UseJackpot:InvokeServer()
		end)
		if ok and msg then
			Notify.toast(msg, if success then "success" else "error")
		end
	elseif item.go and actions.openPanel then
		actions.openPanel(item.go)
	end
end

local function refreshItems()
	for _, row in ipairs(itemRows) do
		local n = itemCount(row.item)
		row.count.Text = "x" .. Config.Format(n)
		if row.button then
			Kit.setEnabled(row.button, n > 0 or row.item.go ~= nil)
		end
	end
end

local function buildItems(parent)
	local list = Kit.scroll(parent, { Name = "Items" }, { cell = Vector2.new(124, 150), gap = 8 })
	for i, item in ipairs(ITEMS) do
		local potion = item.potion and Config.Potions[item.key]
		local name = if potion then potion.name else item.name
		local desc = if potion then potion.desc .. " for " .. math.floor(potion.duration / 60) .. " min" else item.desc
		local cell = Kit.plate(list, { Name = item.key, LayoutOrder = i }, { color = C.Row, transparency = 0, radius = 12, border = 3 })
		Kit.label(cell, { Name = "Icon", Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 46), Text = item.icon }, { outline = 0 })
		local count = Kit.label(cell, {
			Name = "Count", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(50, 22), TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 20 })
		Kit.label(cell, { Name = "ItemName", Position = UDim2.fromOffset(4, 52), Size = UDim2.new(1, -8, 0, 20), Text = name }, { maxTextSize = 17 })
		Kit.label(cell, {
			Name = "Desc", Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 32), Text = desc,
			TextWrapped = true, TextColor3 = C.TextSoft,
		}, { outline = 0, maxTextSize = 12 })
		local button = Kit.button(cell, {
			Name = "Use", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 34),
		}, { text = if item.go then "Go ▸" else "Use", color = if item.go then C.Blue else C.Green, maxTextSize = 18 })
		Kit.onClick(button, function()
			useItem(item)
		end)
		table.insert(itemRows, { item = item, count = count, button = button })
	end
	return list
end

---------------------------------------------------------------------
-- Refresh (only while open; batched)
---------------------------------------------------------------------
local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	if tabs.selected == "Items" then
		refreshItems()
	else
		refreshUnits()
	end
end

local pendingRefresh = false
local function queueRefresh()
	if pendingRefresh then
		return
	end
	pendingRefresh = true
	task.delay(0.15, function()
		pendingRefresh = false
		refresh()
	end)
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Backpack.mount(canvas, acts)
	if panel then
		return panel
	end
	actions = acts or {}
	panel = Kit.panel(canvas, {
		name = "BackpackPanel", title = "Backpack", icon = "🎒", color = C.Blue,
		size = Vector2.new(660, 352), onOpen = refresh,
	})
	local body = panel.body -- 636 x 284

	tabs = Kit.tabs(body, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(96, 120) }, {
		vertical = true, button = Vector2.new(96, 54), gap = 8, maxTextSize = 20,
		items = {
			{ name = "Units", text = "🎈 Units", color = C.Blue },
			{ name = "Items", text = "🧪 Items", color = C.Purple },
		},
		onSelect = function(name)
			unitsView.Visible = name == "Units"
			itemsView.Visible = name == "Items"
			refresh()
		end,
	})

	-- units: the grid + the bottom bar
	unitsView = Kit.make("Frame", { Name = "UnitsView", Position = UDim2.fromOffset(106, 0), Size = UDim2.new(1, -106, 1, 0), BackgroundTransparency = 1 }, body)
	grid = Kit.scroll(unitsView, { Name = "Grid", Size = UDim2.new(1, 0, 1, -54) }, { cell = Vector2.new(92, 112), gap = 6 })
	emptyLabel = Kit.label(unitsView, {
		Name = "Empty", Size = UDim2.new(1, 0, 1, -54), Text = "No Floaties yet: press ROLL!", TextColor3 = C.TextSoft, Visible = false,
	}, { maxTextSize = 24 })
	local bar = Kit.make("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, unitsView)
	Kit.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, bar)

	lockButton = Kit.button(bar, { Name = "LockMode", Size = UDim2.fromOffset(52, 44), LayoutOrder = 1 }, { text = "🔒", color = C.Grey, maxTextSize = 24 })
	Kit.onClick(lockButton, function()
		lockMode = not lockMode
		Kit.setButtonColor(lockButton, if lockMode then C.Yellow else C.Grey)
		Notify.toast(if lockMode then "Lock mode: click Floaties to lock / unlock them" else "Lock mode off", "info")
	end)
	local equipBest = Kit.button(bar, { Name = "EquipBest", Size = UDim2.fromOffset(140, 44), LayoutOrder = 2 }, { text = "⭐ Equip Best", color = C.Green, maxTextSize = 20 })
	Kit.onClick(equipBest, function()
		remotes.EquipBest:FireServer()
	end)
	sortButton = Kit.button(bar, { Name = "Sort", Size = UDim2.fromOffset(118, 44), LayoutOrder = 3 }, { text = SORT_TEXT.income, color = C.Purple, maxTextSize = 18 })
	Kit.onClick(sortButton, function()
		sortIndex = sortIndex % #SORTS + 1
		Kit.setButtonText(sortButton, SORT_TEXT[SORTS[sortIndex]])
		refresh()
	end)
	local sellButton = Kit.button(bar, { Name = "SellMore", Size = UDim2.fromOffset(84, 44), LayoutOrder = 4 }, { text = "💰 Sell", color = C.Yellow, maxTextSize = 18 })
	Kit.onClick(sellButton, function()
		if actions.openPanel then
			actions.openPanel("Sell")
		end
	end)
	capacityPlate = Kit.plate(bar, { Name = "Capacity", Size = UDim2.fromOffset(104, 44), LayoutOrder = 5 }, { color = C.Blue, gradient = true, radius = 12, border = 3 })
	capacityLabel = Kit.label(capacityPlate, { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3) }, { maxTextSize = 20 })

	-- items
	itemsView = Kit.make("Frame", { Name = "ItemsView", Position = UDim2.fromOffset(106, 0), Size = UDim2.new(1, -106, 1, 0), BackgroundTransparency = 1, Visible = false }, body)
	buildItems(itemsView)

	tabs:select("Units", true)
	State.changed:Connect(queueRefresh)
	player:GetAttributeChangedSignal("BackpackSize"):Connect(queueRefresh)
	return panel
end

-- Backpack.showItems() — open straight on the Items tab
function Backpack.showItems()
	if panel then
		tabs:select("Items")
		panel:open()
	end
end

return Backpack
