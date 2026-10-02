--[[
	Floatie Farm — Offers (ModuleScript child of the ClientMain LocalScript)
	Robux offers on the HUD, like the reference games:
	  • Two offer bubbles in the RightStack (under Luck / Cash): a bouncing
	    circle with an "OP!" tag, a tilted name and the price under it. The
	    Starter Pack keeps the first spot until it is bought; the other spot
	    cycles through Config.OfferBubbles every Config.OfferRotate seconds,
	    skipping passes you own.
	  • The Starter Pack window: opened by its bubble or from the Shop, and
	    once by itself after your 10th roll (Config.StarterPack.popupAfterRolls)
	    while you don't have it. It waits until no other window is open.

	API:
	  Offers.mount(rightStack, panelCanvas) -> the Starter Pack Panel
	  Offers.update()          -- init's slow loop (rotation, bounce, the popup)
	  Offers.openStarter()
	  Offers.buy(offer)        -- an entry of Config.OfferBubbles
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local C = Config.UI

local Offers = {}

local CELL = Vector2.new(72, 74)
local BUBBLE = 52
local BOUNCE_EVERY = 3
local POPUP_DELAY = 2.5 -- after the 10th roll's reveal

local mounted = false
local slots = {}
local starterPanel = nil
local starterBuy = nil
local rotateIndex = 0
local rotateAt = 0
local bounceAt = 0
local popupAt = nil -- os.clock() time the Starter Pack popup is due

---------------------------------------------------------------------
-- Offer info
---------------------------------------------------------------------
-- title, icon, price, id of an OfferBubbles entry
local function info(offer)
	if offer.kind == "starter" then
		local sp = Config.StarterPack
		return sp.title, "🎁", sp.price, sp.id
	end
	local item = if offer.kind == "pass" then Config.GamePasses[offer.key] else Config.DevProducts[offer.key]
	return item.title, item.icon, item.price, item.id
end

local function owned(offer)
	if offer.kind == "starter" then
		return State.data.starterPack == true
	elseif offer.kind == "pass" then
		return player:GetAttribute("Pass_" .. offer.key) == true
	end
	return false -- products can be bought again and again
end

function Offers.buy(offer)
	local title, _, _, id = info(offer)
	if id == 0 then
		Notify.toast(title .. " is coming soon! (Developer: paste its ID into Config)", "info")
		return
	end
	if offer.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

---------------------------------------------------------------------
-- The Starter Pack window
---------------------------------------------------------------------
local function refreshStarter()
	if not starterBuy then
		return
	end
	local have = State.data.starterPack == true
	Kit.setButtonText(starterBuy, if have then "Owned ✓" else "R$ " .. Config.StarterPack.price)
	Kit.setEnabled(starterBuy, not have)
end

local function mountStarter(canvas)
	local sp = Config.StarterPack
	starterPanel = Kit.panel(canvas, {
		name = "StarterPanel", title = sp.title, icon = "🎁", color = C.Pink, size = Vector2.new(520, 330),
		onOpen = refreshStarter,
	})
	local body = starterPanel.body -- 496 x 262

	-- left: the gift and what Floatie it holds
	local art = Kit.plate(body, {
		Name = "Art", Size = UDim2.fromOffset(176, 262),
	}, { color = C.HudBg, gradient = true, radius = 14, border = 3 })
	Kit.label(art, {
		Name = "Gift", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(120, 120), Text = "🎁",
	}, { outline = 0 })
	local rare, epic = Config.Rarities.Rare.color, Config.Rarities.Epic.color
	Kit.label(art, {
		Name = "Rarity", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176),
		Size = UDim2.fromOffset(164, 30), RichText = true,
		Text = ('<font color="#%s">RARE</font> or <font color="#%s">EPIC</font>'):format(rare:ToHex(), epic:ToHex()),
	}, { outline = 3, maxTextSize = 26 })
	Kit.label(art, {
		Name = "Once", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(164, 24), Text = "ONE TIME ONLY!", TextColor3 = C.Yellow,
	}, { outline = 3, maxTextSize = 20 })
	Kit.label(art, {
		Name = "OP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -10),
		Size = UDim2.fromOffset(58, 30), Rotation = 14, Text = "OP!", TextColor3 = C.Yellow, ZIndex = 4,
	}, { outline = 3, maxTextSize = 28 })

	-- right: what's inside and the price
	local list = Kit.make("Frame", {
		Name = "Lines", Position = UDim2.fromOffset(190, 4), Size = UDim2.new(1, -190, 0, 186), BackgroundTransparency = 1,
	}, body)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i, line in ipairs(sp.lines) do
		Kit.label(list, {
			Name = "Line" .. i, Size = UDim2.new(1, 0, 0, 40), Text = "✅ " .. line, LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		}, { maxTextSize = 20 })
	end
	starterBuy = Kit.button(body, {
		Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 190 + 153, 1, -2),
		Size = UDim2.fromOffset(230, 58),
	}, { text = "R$ " .. sp.price, color = C.Yellow, maxTextSize = 32 })
	Kit.shine(starterBuy)
	Kit.onClick(starterBuy, function()
		Offers.buy({ kind = "starter" })
	end)
	refreshStarter()
end

function Offers.openStarter()
	if starterPanel then
		starterPanel:open()
	end
end

---------------------------------------------------------------------
-- Bubbles
---------------------------------------------------------------------
local function pop(slot)
	slot.scale.Scale = 0.4
	Kit.tween(slot.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function bounce(slot)
	local up = Kit.tween(slot.scale, 0.12, { Scale = 1.14 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			Kit.tween(slot.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)
	Kit.tween(slot.op, 0.12, { Rotation = 2 })
	task.delay(0.12, function()
		Kit.tween(slot.op, 0.3, { Rotation = 14 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end)
end

local function show(slot, offer)
	if slot.offer == offer then
		return
	end
	slot.offer = offer
	slot.cell.Visible = offer ~= nil
	if not offer then
		return
	end
	local title, icon, price = info(offer)
	slot.icon.Text = icon
	slot.name.Text = offer.label or title
	slot.price.Text = "R$ " .. price
	Kit.setButtonColor(slot.button, offer.color or C.Pink)
	pop(slot)
end

-- which offers go in the two spots right now
local function assign()
	local starter, rest = nil, {}
	for _, offer in ipairs(Config.OfferBubbles) do
		if not owned(offer) then
			if offer.kind == "starter" then
				starter = offer
			else
				table.insert(rest, offer)
			end
		end
	end
	local want = {}
	if starter then
		want[1] = starter
		want[2] = if #rest > 0 then rest[rotateIndex % #rest + 1] else nil
	elseif #rest > 0 then
		want[1] = rest[rotateIndex % #rest + 1]
		want[2] = if #rest > 1 then rest[(rotateIndex + 1) % #rest + 1] else nil
	end
	for i, slot in ipairs(slots) do
		show(slot, want[i])
	end
end

local function makeSlot(row, i)
	local cell = Kit.make("Frame", {
		Name = "Offer" .. i, Size = UDim2.fromOffset(CELL.X, CELL.Y), BackgroundTransparency = 1, LayoutOrder = i, Visible = false,
	}, row)
	-- everything sits in a holder so one UIScale bounces the whole bubble
	local holder = Kit.make("Frame", {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	}, cell)
	local scale = Kit.make("UIScale", { Name = "Bounce" }, holder)
	local button = Kit.button(holder, {
		Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(BUBBLE, BUBBLE),
	}, { text = "", color = C.Pink, radius = BUBBLE / 2, border = 3 })
	local icon = Kit.label(button.Face, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.62, 0.62), ZIndex = 3,
	}, { outline = 0 })
	local name = Kit.label(holder, {
		Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(CELL.X + 6, 20), Rotation = -8, ZIndex = 4,
	}, { outline = 3, maxTextSize = 18 })
	local op = Kit.label(holder, {
		Name = "OP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4),
		Size = UDim2.fromOffset(34, 20), Rotation = 14, Text = "OP!", TextColor3 = C.Yellow, ZIndex = 5,
	}, { outline = 3, maxTextSize = 18 })
	local price = Kit.label(holder, {
		Name = "Price", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(CELL.X, 16), TextColor3 = C.Yellow, ZIndex = 4,
	}, { outline = 2, maxTextSize = 16 })
	local slot = { cell = cell, button = button, icon = icon, name = name, op = op, price = price, scale = scale, offer = nil }
	Kit.onClick(button, function()
		local offer = slot.offer
		if not offer then
			return
		end
		if offer.kind == "starter" then
			Offers.openStarter()
		else
			Offers.buy(offer)
		end
	end)
	return slot
end

---------------------------------------------------------------------
-- Mount / update
---------------------------------------------------------------------
function Offers.mount(rightStack, canvas)
	if mounted then
		return starterPanel
	end
	mounted = true
	mountStarter(canvas)

	local row = Kit.make("Frame", {
		Name = "Offers", Size = UDim2.fromOffset(150, CELL.Y), BackgroundTransparency = 1, LayoutOrder = 4,
	}, rightStack)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i = 1, 2 do
		slots[i] = makeSlot(row, i)
	end
	assign()

	State.changed:Connect(function(what)
		if what == "starterPack" or what == "full" then
			assign()
			refreshStarter()
		end
	end)
	for _, offer in ipairs(Config.OfferBubbles) do
		if offer.kind == "pass" then
			player:GetAttributeChangedSignal("Pass_" .. offer.key):Connect(assign)
		end
	end

	-- the Starter Pack pops up once, after the 10th roll
	local lastRolls = tonumber(player:GetAttribute("TotalRolls"))
	player:GetAttributeChangedSignal("TotalRolls"):Connect(function()
		local n = tonumber(player:GetAttribute("TotalRolls")) or 0
		local at = Config.StarterPack.popupAfterRolls
		if lastRolls and lastRolls < at and n >= at and State.data.starterPack ~= true then
			popupAt = os.clock() + POPUP_DELAY
		end
		lastRolls = n
	end)
	return starterPanel
end

function Offers.update()
	if not mounted then
		return
	end
	local now = os.clock()
	if now >= rotateAt then
		rotateAt = now + Config.OfferRotate
		rotateIndex += 1
		assign()
	end
	if now >= bounceAt then
		bounceAt = now + BOUNCE_EVERY
		for i, slot in ipairs(slots) do
			if slot.offer then
				task.delay((i - 1) * 0.15, bounce, slot)
			end
		end
	end
	if popupAt and now >= popupAt and not Kit.anyPanelOpen() then
		popupAt = nil
		if State.data.starterPack ~= true then
			Offers.openStarter()
		end
	end
end

return Offers
