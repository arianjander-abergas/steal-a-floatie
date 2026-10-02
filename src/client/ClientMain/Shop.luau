--[[
	Floatie Farm — Shop (ModuleScript child of the ClientMain LocalScript)
	The Shop window (the rainbow SHOP button), three tabs:
	  Offers  the Starter Pack (one time) and the offer ladder: five offers
	          unlocked in order, the first one FREE
	  Passes  game passes (forever); owned ones turn into "Owned ✓"
	  Boosts  developer products: Jackpot Roll, potions, tokens, gems, Air
	          packs, Server Luck Boost (Config.BoostOrder)
	Prices and ids live in Config (ConfigParts/Robux). While an id is 0 the
	button says "Coming soon!".

	API:
	  Shop.mount(canvas) -> Panel
	  Shop.open(tab)            -- "Offers" / "Passes" / "Boosts"
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local Offers = require(script.Parent.Offers)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local C = Config.UI

local Shop = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local panel = nil
local tabs = nil
local views = {}
local starterButton = nil
local ladderRows = {}
local passButtons = {}
local claiming = false

---------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------
-- one dark row: icon, title + description, yellow Robux button on the right
local function itemRow(list, order, name, item, onBuy)
	local row = Kit.plate(list, {
		Name = name, Size = UDim2.new(1, -8, 0, 58), LayoutOrder = order,
	}, { color = C.Row, transparency = 0, radius = 10, border = 2 })
	Kit.label(row, {
		Name = "Icon", Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(44, 44), Text = item.icon or "",
	}, { outline = 0 })
	Kit.label(row, {
		Name = "Title", Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -184, 0, 26), Text = item.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 22 })
	Kit.label(row, {
		Name = "Desc", Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -184, 0, 20), Text = item.desc,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.TextSoft,
	}, { outline = 0, maxTextSize = 16 })
	local b = Kit.button(row, {
		Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(112, 42),
	}, { text = "R$ " .. item.price, color = C.Yellow, maxTextSize = 22 })
	Kit.onClick(b, function()
		if item.id == 0 then
			Notify.toast(item.title .. " is coming soon! (Developer: paste its ID into Config)", "info")
			return
		end
		onBuy(item.id)
	end)
	return b
end

---------------------------------------------------------------------
-- Offers tab: Starter Pack card + the offer ladder
---------------------------------------------------------------------
local function refreshOffers()
	local have = State.data.starterPack == true
	if starterButton then
		Kit.setButtonText(starterButton, if have then "Owned ✓" else "R$ " .. Config.StarterPack.price)
		Kit.setEnabled(starterButton, not have)
	end
	local claimed = State.data.offerLadder or 0
	for step, row in ipairs(ladderRows) do
		local offer = Config.OfferLadder[step]
		local text, color, enabled
		if step <= claimed then
			text, color, enabled = "✓ Claimed", C.Grey, false
		elseif step == claimed + 1 then
			if offer.price == 0 then
				text, color, enabled = "FREE!", C.Green, true
			else
				text, color, enabled = "R$ " .. offer.price, C.Yellow, true
			end
		else
			text, color, enabled = "🔒 Locked", C.Grey, false
		end
		Kit.setButtonColor(row.button, color)
		Kit.setButtonText(row.button, text)
		Kit.setEnabled(row.button, enabled)
		row.plate.BackgroundColor3 = if step == claimed + 1 then C.Row else C.RowAlt
	end
end

local function claimStep(step)
	local offer = Config.OfferLadder[step]
	if offer.price ~= 0 then
		if offer.id == 0 then
			Notify.toast("This offer is coming soon! (Developer: paste its ID into Config)", "info")
		else
			MarketplaceService:PromptProductPurchase(player, offer.id)
		end
		return
	end
	if claiming then
		return
	end
	claiming = true
	local ok, success, msg = pcall(function()
		return remotes.ClaimOffer:InvokeServer(step)
	end)
	claiming = false
	if ok and not success and msg then
		Notify.toast(msg, "error")
	end
	refreshOffers()
end

local function buildOffers(view)
	local sp = Config.StarterPack
	-- Starter Pack card (left)
	local card = Kit.plate(view, {
		Name = "StarterCard", Size = UDim2.fromOffset(196, 256),
	}, { color = C.Pink, gradient = true, radius = 14, border = 3 })
	Kit.label(card, {
		Name = "Title", Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 30), Text = "🎁 " .. sp.title,
	}, { outline = 3, maxTextSize = 26 })
	Kit.label(card, {
		Name = "OP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -10), Size = UDim2.fromOffset(52, 28),
		Rotation = 14, Text = "OP!", TextColor3 = C.Yellow, ZIndex = 4,
	}, { outline = 3, maxTextSize = 26 })
	local lines = Kit.make("Frame", {
		Name = "Lines", Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 140), BackgroundTransparency = 1,
	}, card)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, lines)
	for i, line in ipairs(sp.lines) do
		Kit.label(lines, {
			Name = "Line" .. i, Size = UDim2.new(1, 0, 0, 33), Text = "• " .. line, LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		}, { maxTextSize = 15 })
	end
	Kit.label(card, {
		Name = "Once", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -58), Size = UDim2.new(1, -16, 0, 18),
		Text = "ONE TIME ONLY!", TextColor3 = C.Yellow,
	}, { outline = 2, maxTextSize = 16 })
	starterButton = Kit.button(card, {
		Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 46),
	}, { text = "R$ " .. sp.price, color = C.Yellow, maxTextSize = 26 })
	Kit.onClick(starterButton, function()
		Offers.openStarter()
	end)

	-- the ladder (right)
	local right = Kit.make("Frame", {
		Name = "Ladder", Position = UDim2.fromOffset(206, 0), Size = UDim2.new(1, -206, 1, 0), BackgroundTransparency = 1,
	}, view)
	Kit.label(right, {
		Name = "Header", Size = UDim2.new(1, 0, 0, 22), Text = "🔥 Offer Ladder: claim each one to unlock the next!",
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold,
	}, { maxTextSize = 18 })
	local list = Kit.make("Frame", {
		Name = "Steps", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), BackgroundTransparency = 1,
	}, right)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for step, offer in ipairs(Config.OfferLadder) do
		local plate = Kit.plate(list, {
			Name = "Step" .. step, Size = UDim2.new(1, 0, 0, 41), LayoutOrder = step,
		}, { color = C.Row, transparency = 0, radius = 10, border = 2 })
		local num = Kit.plate(plate, {
			Name = "Number", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(30, 30),
		}, { color = if offer.price == 0 then C.Green else C.Purple, gradient = true, radius = 15, border = 2 })
		Kit.label(num, {
			Name = "Label", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Text = tostring(step),
		}, { outline = 2 })
		Kit.label(plate, {
			Name = "Text", Position = UDim2.fromOffset(44, 4), Size = UDim2.new(1, -168, 1, -8), Text = offer.text,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		}, { maxTextSize = 16 })
		local button = Kit.button(plate, {
			Name = "Get", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(112, 33),
		}, { text = "", color = C.Grey, maxTextSize = 20, radius = 10 })
		Kit.onClick(button, function()
			claimStep(step)
		end)
		ladderRows[step] = { plate = plate, button = button }
	end
end

---------------------------------------------------------------------
-- Passes / Boosts tabs
---------------------------------------------------------------------
local function refreshPasses()
	for name, b in pairs(passButtons) do
		if player:GetAttribute("Pass_" .. name) then
			Kit.setButtonText(b, "Owned ✓")
			Kit.setEnabled(b, false)
		end
	end
end

local function buildPasses(view)
	local list = Kit.scroll(view, { Name = "List" }, { gap = 6, pad = 3 })
	for i, name in ipairs(Config.PassOrder) do
		passButtons[name] = itemRow(list, i, "Pass_" .. name, Config.GamePasses[name], function(id)
			MarketplaceService:PromptGamePassPurchase(player, id)
		end)
		player:GetAttributeChangedSignal("Pass_" .. name):Connect(refreshPasses)
	end
	refreshPasses()
end

local function buildBoosts(view)
	local list = Kit.scroll(view, { Name = "List" }, { gap = 6, pad = 3 })
	for i, name in ipairs(Config.BoostOrder) do
		itemRow(list, i, "Product_" .. name, Config.DevProducts[name], function(id)
			MarketplaceService:PromptProductPurchase(player, id)
		end)
	end
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Shop.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "ShopPanel", title = "Shop", icon = "🛒", color = C.Green, size = Vector2.new(640, 366),
		onOpen = refreshOffers,
	})
	local body = panel.body -- 616 x 298
	tabs = Kit.tabs(body, { Size = UDim2.fromOffset(400, 34) }, {
		button = Vector2.new(124, 34), gap = 6, maxTextSize = 18,
		items = {
			{ name = "Offers", text = "🎁 Offers", color = C.Pink },
			{ name = "Passes", text = "⭐ Passes", color = C.Blue },
			{ name = "Boosts", text = "🚀 Boosts", color = C.Purple },
		},
		onSelect = function(name)
			for viewName, view in pairs(views) do
				view.Visible = viewName == name
			end
		end,
	})
	for _, name in ipairs({ "Offers", "Passes", "Boosts" }) do
		views[name] = Kit.make("Frame", {
			Name = name .. "View", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42),
			BackgroundTransparency = 1, Visible = false,
		}, body)
	end
	buildOffers(views.Offers)
	buildPasses(views.Passes)
	buildBoosts(views.Boosts)
	tabs:select("Offers")
	refreshOffers()

	State.changed:Connect(function(what)
		if what == "offerLadder" or what == "starterPack" or what == "full" then
			refreshOffers()
		end
	end)
	return panel
end

function Shop.open(tab)
	if panel then
		panel:open()
		if tab then
			tabs:select(tab)
		end
	end
end

return Shop
