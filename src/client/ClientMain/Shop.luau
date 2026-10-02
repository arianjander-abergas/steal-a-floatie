--[[
	Steal a Floatie — Shop (ModuleScript child of the ClientMain LocalScript)
	The Shop panel: one scrolling list with the Game Passes (forever) and the
	Boosts (developer products) from Config. Content and purchase calls are the
	same as v0.1.2; only the look is new (Kit panel, white rows, chunky green
	"R$" buttons).

	To sell something: paste its id into Config.GamePasses / Config.DevProducts.
	While an id is 0 the button just says "Coming soon!".

	API:
	  Shop.mount(canvas) -> Panel   -- builds the panel on the "FloatiePanels" Kit canvas
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)

local player = Players.LocalPlayer
local C = Config.UI

local Shop = {}

local panel = nil -- the Kit Panel, once mounted

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
-- names of a Config table, sorted so the list order never changes
local function sortedNames(tbl)
	local names = {}
	for name in pairs(tbl) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- gold section title ("Game Passes (forever)" / "Boosts")
local function sectionHeader(list, text, order)
	return Kit.label(list, {
		Name = "Header" .. order,
		Size = UDim2.new(1, -10, 0, 26),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		LayoutOrder = order,
	})
end

-- one white row: title + description on the left, buy button on the right.
-- onBuy(id) runs only when the item has a real id (not 0).
local function shopRow(list, order, name, info, onBuy)
	local row = Kit.plate(list, {
		Name = name,
		Size = UDim2.new(1, -10, 0, 62),
		LayoutOrder = order,
	}, { color = C.Row, transparency = 0, radius = 10, border = 2 })

	Kit.label(row, {
		Name = "Title",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -130, 0, 28),
		Text = info.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Kit.label(row, {
		Name = "Desc",
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -130, 0, 22),
		Text = info.desc,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.TextDark,
	}, { outline = 0 })

	local b = Kit.button(row, {
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(104, 42),
	}, { text = "R$ " .. info.price, color = C.Green })

	Kit.onClick(b, function()
		if info.id == 0 then
			Notify.toast("Coming soon! (Developer: paste the ID into Config)", "info")
			return
		end
		onBuy(info.id)
	end)
	return b
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Shop.mount(canvas)
	if panel then
		return panel -- already built
	end

	panel = Kit.panel(canvas, {
		name = "ShopPanel",
		title = "Shop",
		icon = "🛒",
		color = C.Green,
	})

	-- scrolling list that fills the whole panel body
	local list = Kit.make("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Outline,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel.body)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	Kit.make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 3),
	}, list)

	-----------------------------------------------------------------
	-- Game Passes (LayoutOrder 0 header, rows 1, 2, ...)
	-----------------------------------------------------------------
	sectionHeader(list, "Game Passes (forever)", 0)
	local passButtons = {} -- pass name -> buy button
	local passNames = sortedNames(Config.GamePasses)
	for i, name in ipairs(passNames) do
		passButtons[name] = shopRow(list, i, "Pass_" .. name, Config.GamePasses[name], function(id)
			MarketplaceService:PromptGamePassPurchase(player, id)
		end)
	end

	-----------------------------------------------------------------
	-- Boosts (LayoutOrder 100 header, rows 101, 102, ...)
	-----------------------------------------------------------------
	sectionHeader(list, "Boosts", 100)
	for i, name in ipairs(sortedNames(Config.DevProducts)) do
		shopRow(list, 100 + i, "Product_" .. name, Config.DevProducts[name], function(id)
			MarketplaceService:PromptProductPurchase(player, id)
		end)
	end

	-----------------------------------------------------------------
	-- Owned passes: the server sets the "Pass_<name>" attribute, then the
	-- button turns into a grey "Owned ✓" that can't be clicked
	-----------------------------------------------------------------
	local function refreshPasses()
		for name, b in pairs(passButtons) do
			if player:GetAttribute("Pass_" .. name) then
				Kit.setButtonText(b, "Owned ✓")
				Kit.setEnabled(b, false)
			end
		end
	end
	for _, name in ipairs(passNames) do
		player:GetAttributeChangedSignal("Pass_" .. name):Connect(refreshPasses)
	end
	refreshPasses()

	return panel
end

return Shop
