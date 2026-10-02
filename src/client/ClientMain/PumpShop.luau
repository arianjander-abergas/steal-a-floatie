--[[
	Floatie Farm — PumpShop (ModuleScript child of the ClientMain LocalScript)
	The Pump Shop (our "Dice Shop", like Anime Dice): one row per pump tier
	with its 3D model, "Name | Rarity", its Luck, and a button:
	  green "💨 2.5K"  buy it (only the next tier; you need the one before)
	  blue "Equip"     you own it
	  grey "Equipped"  it's on your Pump Machine now
	The list scrolls to your next pump when it opens.

	API:
	  PumpShop.mount(canvas) -> Panel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PumpModel = require(Shared:WaitForChild("PumpModel"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local C = Config.UI

local PumpShop = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local ROW_HEIGHT = 104

local panel = nil
local list = nil
local rows = {}
local busy = false

local function pumps()
	return State.data.pumps or { owned = 1, equipped = 1 }
end

local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	local p = pumps()
	local air = tonumber(player:GetAttribute("Air")) or 0
	for tier, row in ipairs(rows) do
		local info = Config.Pumps[tier]
		if tier == p.equipped then
			Kit.setButtonText(row.button, "Equipped ✓")
			Kit.setButtonColor(row.button, C.Grey)
		elseif tier <= p.owned then
			Kit.setButtonText(row.button, "Equip")
			Kit.setButtonColor(row.button, C.Blue)
		elseif tier == p.owned + 1 then
			Kit.setButtonText(row.button, "💨 " .. Config.Format(info.price))
			Kit.setButtonColor(row.button, if air >= info.price then C.Green else C.Grey)
		else
			Kit.setButtonText(row.button, "🔒 " .. Config.Format(info.price))
			Kit.setButtonColor(row.button, C.RowAlt)
		end
		row.frame.BackgroundColor3 = if tier == p.equipped then Color3.fromRGB(46, 70, 54) else C.Row
	end
end

local function onButton(tier)
	if busy then
		return
	end
	local p = pumps()
	if tier == p.equipped then
		return
	elseif tier <= p.owned then
		remotes.EquipPump:FireServer(tier)
		return
	elseif tier > p.owned + 1 then
		Notify.toast("Buy the " .. Config.Pumps[p.owned + 1].name .. " first", "info")
		return
	end
	busy = true
	local ok, success, msg = pcall(function()
		return remotes.BuyPump:InvokeServer(tier)
	end)
	busy = false
	if ok and not success and msg then
		Notify.toast(msg, "error")
	end
end

function PumpShop.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "PumpShopPanel", title = "Pump Shop", icon = "🎈", color = C.Pink,
		size = Vector2.new(600, 352),
		onOpen = function()
			refresh()
			-- scroll so the next pump to buy is in view
			local nextTier = math.min(pumps().owned + 1, #Config.Pumps)
			list.CanvasPosition = Vector2.new(0, math.max(0, (nextTier - 2) * (ROW_HEIGHT + 8)))
		end,
	})
	list = Kit.scroll(panel.body, { Name = "Pumps" }, { gap = 8 })

	for tier, info in ipairs(Config.Pumps) do
		local rarity = Config.Rarities[info.rarity or "Common"]
		local frame = Kit.plate(list, {
			Name = "Pump" .. tier, Size = UDim2.new(1, -12, 0, ROW_HEIGHT), LayoutOrder = tier,
		}, { color = C.Row, transparency = 0, radius = 12, border = 3 })
		local preview = Kit.viewport(frame, {
			Name = "Preview", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(110, ROW_HEIGHT - 8),
		}, { spin = true })
		preview:setModel("pump|" .. tier, function()
			return PumpModel.Build(tier)
		end)
		Kit.label(frame, {
			Name = "PumpName", Position = UDim2.fromOffset(124, 8), Size = UDim2.new(1, -300, 0, 30),
			RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
			Text = ('%s <font color="#%s">| %s</font>'):format(info.name, (if rarity then rarity.color else C.Grey):ToHex(), info.rarity or "Common"),
		}, { outline = 3, maxTextSize = 26 })
		Kit.label(frame, {
			Name = "Luck", Position = UDim2.fromOffset(124, 40), Size = UDim2.new(1, -300, 0, 26),
			Text = "🍀 " .. Config.Format(info.luck) .. "x Luck", TextColor3 = C.Luck, TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 24 })
		Kit.label(frame, {
			Name = "Desc", Position = UDim2.fromOffset(124, 70), Size = UDim2.new(1, -300, 0, 22),
			Text = info.desc, TextColor3 = C.TextSoft, TextXAlignment = Enum.TextXAlignment.Left,
		}, { outline = 0, maxTextSize = 16 })
		local button = Kit.button(frame, {
			Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 50),
		}, { text = "", color = C.Green, maxTextSize = 22 })
		Kit.onClick(button, function()
			onButton(tier)
		end)
		rows[tier] = { frame = frame, button = button }
	end

	State.changed:Connect(function(what)
		if what == "pumps" or what == "full" then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Air"):Connect(refresh)
	return panel
end

return PumpShop
