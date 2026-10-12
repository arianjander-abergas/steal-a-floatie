--[[
	Floatie Farm — TradePanel (ModuleScript child of the ClientMain LocalScript)
	Trading: the 🤝 tile and the Trading Post stall. The rules live on the
	server (Trading.luau); this only shows them. The window has three faces:
	  Locked   under 1,000 rolls: a padlock and "423 / 1,000 rolls"
	  Lobby    Players (everyone in the server, with a Trade button) and
	           History (your last 20 trades)
	  Trade    your offer on the left, theirs on the right: up to 8 Floaties
	           each plus items. Ready -> 5 s countdown -> Confirm. Point at
	           (or tap) one of their Floaties to see everything about it.
	On top of it: the Add Floaties / Add Items pickers. Elsewhere on screen:
	the incoming request box (Accept / Decline) and a "trade in progress"
	pill when the window is closed mid-trade (closing it doesn't cancel the
	trade; the Cancel button does). The tile gets a 🔒 until trading unlocks.

	API:
	  TradePanel.mount(canvas) -> Panel
	  TradePanel.update()   -- init's slow loop (countdown, request timer, lists)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local C = Config.UI
local T = Config.Trade

local TradePanel = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local TILE = Vector2.new(84, 90)
local SIDE_WIDTH = 360

local panel = nil
local lockedView, lobbyView, tradeView = nil, nil, nil
local lobbyTabs, playersList, historyList, emptyPlayers = nil, nil, nil, nil
local progress = nil
local tileLock = nil

local current = nil -- the trade as the server last described it (nil = not trading)
local sides = {}    -- "you" / "them" -> { header, badge, badgeText, tiles, items, value, info }
local readyButton, confirmButton, cancelButton = nil, nil, nil
local addFloatiesButton, addItemsButton, statusLabel = nil, nil, nil

local picker, pickerGrid, pickerCount = nil, nil, nil
local pickerTiles = {}
local itemsPanel = nil
local itemRows = {}   -- key -> { have, amount, minus, plus, all }
local pendingItems = {} -- key -> amount we asked for, until the server answers

local requestBox, requestText, requestBar, pill = nil, nil, nil, nil
local requests = {}   -- incoming { from, name, expires }, oldest first
local sent = {}       -- userId -> os.clock() when we sent them a request
local playerRows = {} -- userId -> { row, status, button }
local lastListRefresh = 0
local shownRequests = 0 -- the request count on the tile badge

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function paintPlate(plate, color)
	local g = plate:FindFirstChild("Gradient")
	if g then
		g.Color = ColorSequence.new(Kit.shade(color, 0.3), Kit.shade(color, -0.2))
	end
end

local function rolls()
	return tonumber(player:GetAttribute("TotalRolls")) or 0
end

-- every detail of a Floatie on one line
local function infoText(f)
	local def = f and Config.FloatieById[f.id]
	if not def then
		return ""
	end
	local parts = { Formulas.nameOf(f), Formulas.rarityOf(f) .. " " .. Config.FormatOdds(Formulas.oddsOf(f)) }
	if f.mut and f.mut ~= "Normal" then
		table.insert(parts, f.mut .. " " .. Config.FormatMult(Config.MutationById[f.mut].mult))
	end
	if f.form and f.form ~= "Normal" then
		table.insert(parts, f.form .. " " .. Config.FormatMult(Config.FormById[f.form].mult))
	end
	table.insert(parts, "Lv " .. (f.level or 1))
	local grade = Config.GradeById[f.grade or "C"]
	if grade then
		table.insert(parts, "Grade " .. grade.id .. (if grade.mult > 1 then " " .. Config.FormatMult(grade.mult) else ""))
	end
	local trait = f.trait and Config.TraitById[f.trait]
	if trait then
		table.insert(parts, trait.name .. (if trait.mult > 1 then " " .. Config.FormatMult(trait.mult) else ""))
	end
	table.insert(parts, "+" .. Config.Format(Formulas.baseIncome(f)) .. " Air/s")
	return table.concat(parts, " · ")
end

local function itemsText(items)
	local parts = {}
	for _, item in ipairs(T.Items) do
		local n = items and items[item.key]
		if n and n > 0 then
			table.insert(parts, item.icon .. " " .. Config.Format(n))
		end
	end
	return if #parts > 0 then table.concat(parts, "   ") else "No items"
end

local function itemOwned(key)
	local items = State.data.items or {}
	for _, item in ipairs(T.Items) do
		if item.key == key then
			if item.potion then
				return (items.potions and items.potions[key]) or 0
			end
			return items[key] or 0
		end
	end
	return 0
end

-- one TradeAction call; shows the server's error, if any
local function act(action, a, b)
	local ok, success, msg = pcall(function()
		return remotes.TradeAction:InvokeServer(action, a, b)
	end)
	if ok and not success and msg then
		Notify.toast(msg, "error")
	end
	return ok and success
end

local function timeAgo(t)
	local s = math.max(0, os.time() - (t or 0))
	if s < 3600 then
		return math.max(1, math.floor(s / 60)) .. "m ago"
	elseif s < 86400 then
		return math.floor(s / 3600) .. "h ago"
	end
	return math.floor(s / 86400) .. "d ago"
end

---------------------------------------------------------------------
-- Locked / lobby
---------------------------------------------------------------------
local function sendRequest(p)
	local ok, success, msg = pcall(function()
		return remotes.TradeRequest:InvokeServer(p.UserId)
	end)
	if ok and msg then
		Notify.toast(msg, if success then "success" else "error")
	end
	if ok and success then
		sent[p.UserId] = os.clock()
	end
end

local function playerRow(p)
	local row = Kit.plate(playersList, {
		Name = "P" .. p.UserId, Size = UDim2.new(1, -8, 0, 54),
	}, { color = C.Row, transparency = 0, radius = 10, border = 2 })
	local face = Kit.make("ImageLabel", {
		Name = "Face", Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.RowAlt,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150",
	}, row)
	Kit.round(face, 22)
	Kit.label(row, {
		Name = "PlayerName", Position = UDim2.fromOffset(58, 4), Size = UDim2.new(1, -206, 0, 24), Text = p.DisplayName,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 20 })
	local status = Kit.label(row, {
		Name = "Status", Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -206, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.TextSoft,
	}, { outline = 0, maxTextSize = 15 })
	local button = Kit.button(row, {
		Name = "Send", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(132, 40),
	}, { text = "🤝 Trade", color = C.Green, maxTextSize = 18 })
	Kit.onClick(button, function()
		sendRequest(p)
		TradePanel.refreshLobby()
	end)
	return { row = row, status = status, button = button }
end

function TradePanel.refreshLobby()
	if not playersList then
		return
	end
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			others[p.UserId] = p
		end
	end
	for userId, entry in pairs(playerRows) do
		if not others[userId] then
			entry.row:Destroy()
			playerRows[userId] = nil
		end
	end
	local count = 0
	for userId, p in pairs(others) do
		count += 1
		local entry = playerRows[userId]
		if not entry then
			entry = playerRow(p)
			playerRows[userId] = entry
		end
		local theirRolls = tonumber(p:GetAttribute("TotalRolls")) or 0
		local wasSent = sent[userId] and os.clock() - sent[userId] < T.RequestTimeout
		if theirRolls < T.UnlockRolls then
			entry.status.Text = ("🔒 %s / %s rolls"):format(Config.Format(theirRolls), Config.Format(T.UnlockRolls))
			Kit.setButtonText(entry.button, "🔒 Locked")
			Kit.setEnabled(entry.button, false)
		else
			entry.status.Text = "✅ Can trade"
			Kit.setButtonText(entry.button, if wasSent then "Sent ✓" else "🤝 Trade")
			Kit.setEnabled(entry.button, not wasSent)
		end
	end
	emptyPlayers.Visible = count == 0
end

local function refreshHistory()
	for _, child in ipairs(historyList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = State.data.trades or {}
	if #list == 0 then
		Kit.label(historyList, {
			Name = "Empty", Size = UDim2.new(1, -8, 0, 40), Text = "No trades yet", TextColor3 = C.TextSoft,
		}, { maxTextSize = 20 })
		return
	end
	for i = #list, 1, -1 do
		local entry = list[i]
		local row = Kit.plate(historyList, {
			Name = "Trade" .. i, Size = UDim2.new(1, -8, 0, 70), LayoutOrder = #list - i,
		}, { color = C.Row, transparency = 0, radius = 10, border = 2 })
		Kit.label(row, {
			Name = "Title", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22),
			Text = "🤝 With " .. tostring(entry.name) .. " · " .. timeAgo(entry.t), TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 18 })
		Kit.label(row, {
			Name = "Gave", Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -20, 0, 18),
			Text = "Gave: " .. (if #(entry.gave or {}) > 0 then table.concat(entry.gave, ", ") else "nothing"),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Bad,
		}, { outline = 1, maxTextSize = 15 })
		Kit.label(row, {
			Name = "Got", Position = UDim2.fromOffset(10, 47), Size = UDim2.new(1, -20, 0, 18),
			Text = "Got: " .. (if #(entry.got or {}) > 0 then table.concat(entry.got, ", ") else "nothing"),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Good,
		}, { outline = 1, maxTextSize = 15 })
	end
end

---------------------------------------------------------------------
-- The trade
---------------------------------------------------------------------
local function fillSide(key, data)
	local s = sides[key]
	s.header.Text = (if key == "you" then "You" else data.name) .. ("  (%d/%d)"):format(#data.floaties, T.MaxFloaties)
	local text, color
	if data.confirmed then
		text, color = "✅ Confirmed", C.Green
	elseif data.ready then
		text, color = "✓ Ready", C.Teal
	else
		text, color = "Not ready", C.Grey
	end
	s.badgeText.Text = text
	paintPlate(s.badge, color)
	local value = 0
	for i, tile in ipairs(s.tiles) do
		local f = data.floaties[i]
		tile:set(f)
		if f then
			value += Formulas.baseIncome(f)
		end
	end
	s.items.Text = itemsText(data.items)
	s.value.Text = "💨 +" .. Config.Format(value) .. "/s"
end

local function refreshButtons()
	if not current then
		return
	end
	local you, them = current.you, current.them
	local now = workspace:GetServerTimeNow()
	local ends = current.countdownEnds
	local counting = ends ~= nil and now < ends
	local canConfirm = ends ~= nil and not counting and not you.confirmed

	Kit.setButtonText(readyButton, if you.ready then "Unready" else "Ready")
	Kit.setButtonColor(readyButton, if you.ready then C.Grey else C.Green)
	Kit.setEnabled(readyButton, not you.confirmed)
	Kit.setEnabled(confirmButton, canConfirm)
	Kit.setButtonText(confirmButton, if you.confirmed then "✅ Done" elseif counting then "Confirm " .. math.ceil(ends - now) else "Confirm")
	Kit.setEnabled(addFloatiesButton, not you.confirmed)
	Kit.setEnabled(addItemsButton, not you.confirmed)

	local status
	if you.confirmed and not them.confirmed then
		status = "Waiting for " .. them.name .. " to confirm..."
	elseif them.confirmed and canConfirm then
		status = them.name .. " confirmed! Your turn."
	elseif counting then
		status = "Check both offers! Confirm opens in " .. math.ceil(ends - now) .. "..."
	elseif ends then
		status = "Press Confirm to trade!"
	elseif you.ready then
		status = "Waiting for " .. them.name .. " to press Ready..."
	elseif them.ready then
		status = them.name .. " is ready!"
	else
		status = "Add Floaties or items, then press Ready"
	end
	statusLabel.Text = status
end

local function refreshPicker()
	if not picker or not picker:isOpen() then
		return
	end
	local offered, count = {}, 0
	if current then
		for _, f in ipairs(current.you.floaties) do
			offered[f.uid] = true
			count += 1
		end
	end
	local list = Cards.sorted(State.list(), "income")
	for i, f in ipairs(list) do
		local tile = pickerTiles[i]
		if not tile then
			tile = Cards.tile(pickerGrid, {
				onClick = function(t)
					if t.f and current then
						act(if offered[t.f.uid] then "remove" else "add", t.f.uid)
					end
				end,
			})
			pickerTiles[i] = tile
		end
		tile.button.LayoutOrder = i
		tile:set(f)
		tile:setSelected(offered[f.uid] == true)
		tile:setDim(f.locked == true)
	end
	for i = #list + 1, #pickerTiles do
		pickerTiles[i]:set(nil)
	end
	pickerCount.Text = ("%d / %d in the trade · tap a Floatie to add or take it out · 🔒 locked ones stay home"):format(count, T.MaxFloaties)
end

local function refreshItems()
	if not itemsPanel or not itemsPanel:isOpen() then
		return
	end
	local offered = current and current.you.items or {}
	for key, row in pairs(itemRows) do
		local have = itemOwned(key)
		local n = pendingItems[key] or offered[key] or 0
		row.have.Text = "You have " .. Config.Format(have)
		row.amount.Text = tostring(n)
		Kit.setEnabled(row.minus, n > 0)
		Kit.setEnabled(row.plus, n < math.min(have, T.MaxItemAmount))
		Kit.setEnabled(row.all, have > 0 and n < math.min(have, T.MaxItemAmount))
	end
end

local function refreshTrade()
	if not current then
		return
	end
	fillSide("you", current.you)
	fillSide("them", current.them)
	refreshButtons()
	refreshPicker()
	refreshItems()
end

local function showView()
	if not panel then
		return
	end
	local open = rolls() >= T.UnlockRolls
	tradeView.Visible = current ~= nil
	lobbyView.Visible = current == nil and open
	lockedView.Visible = current == nil and not open
	panel.header.Title.Text = "🤝 " .. (if current then "Trading with " .. current.them.name else "Trade")
	if lockedView.Visible then
		progress:set(rolls() / T.UnlockRolls, ("%s / %s rolls"):format(Config.Format(rolls()), Config.Format(T.UnlockRolls)))
	elseif lobbyView.Visible then
		if lobbyTabs.selected == "History" then
			refreshHistory()
		else
			TradePanel.refreshLobby()
		end
	else
		refreshTrade()
	end
end

---------------------------------------------------------------------
-- Building
---------------------------------------------------------------------
local function buildSide(parent, key, x)
	local s = { tiles = {} }
	local frame = Kit.make("Frame", {
		Name = if key == "you" then "You" else "Them", Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(SIDE_WIDTH, 256), BackgroundTransparency = 1,
	}, parent)
	s.header = Kit.label(frame, {
		Name = "Header", Size = UDim2.new(1, -112, 0, 24), TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 20 })
	s.badge = Kit.plate(frame, {
		Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(106, 24),
	}, { color = C.Grey, gradient = true, radius = 12, border = 2 })
	s.badgeText = Kit.label(s.badge, {
		Name = "Label", Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 1, -4),
	}, { maxTextSize = 16 })

	local grid = Kit.make("Frame", {
		Name = "Grid", Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(SIDE_WIDTH, TILE.Y * 2 + 6),
		BackgroundTransparency = 1,
	}, frame)
	Kit.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE.X, TILE.Y), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i = 1, T.MaxFloaties do
		local slot = Kit.plate(grid, {
			Name = "Slot" .. i, LayoutOrder = i,
		}, { color = C.RowAlt, transparency = 0, radius = 10, border = 2 })
		if key == "you" then
			-- an empty slot of yours opens the picker
			local add = Kit.make("TextButton", {
				Name = "Add", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "+", Font = Kit.FONT,
				TextColor3 = C.TextSoft, TextTransparency = 0.3, TextSize = 34, ZIndex = 1,
			}, slot)
			add.Activated:Connect(function()
				if picker then
					picker:open()
					refreshPicker()
				end
			end)
		end
		local tile = Cards.tile(slot, {
			size = TILE,
			onClick = function(t)
				if not t.f then
					return
				end
				if key == "you" then
					act("remove", t.f.uid)
				else
					s.info.Text = infoText(t.f)
				end
			end,
		})
		tile.button.ZIndex = 2
		tile.button.MouseEnter:Connect(function()
			if tile.f then
				s.info.Text = infoText(tile.f)
			end
		end)
		tile:set(nil)
		s.tiles[i] = tile
	end

	local y = 28 + TILE.Y * 2 + 10
	s.items = Kit.label(frame, {
		Name = "Items", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -112, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 17 })
	s.value = Kit.label(frame, {
		Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(110, 20),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Income,
	}, { maxTextSize = 17 })
	s.info = Kit.label(frame, {
		Name = "Info", Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.TextSoft, Text = if key == "them" then "Point at a Floatie to see everything about it" else "",
	}, { outline = 0, maxTextSize = 13 })
	sides[key] = s
end

local function buildTradeView(body)
	tradeView = Kit.make("Frame", { Name = "TradeView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	buildSide(tradeView, "you", 0)
	buildSide(tradeView, "them", 376)
	Kit.label(tradeView, {
		Name = "Swap", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.fromOffset(16, 30), Text = "⇄",
	}, { maxTextSize = 24 })

	local bar = Kit.make("Frame", {
		Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, tradeView)
	addFloatiesButton = Kit.button(bar, { Name = "AddFloaties", Size = UDim2.fromOffset(124, 34) }, { text = "🎈 Floaties", color = C.Blue, maxTextSize = 18 })
	Kit.onClick(addFloatiesButton, function()
		picker:open()
		refreshPicker()
	end)
	addItemsButton = Kit.button(bar, {
		Name = "AddItems", Position = UDim2.fromOffset(130, 0), Size = UDim2.fromOffset(104, 34),
	}, { text = "🧪 Items", color = C.Purple, maxTextSize = 18 })
	Kit.onClick(addItemsButton, function()
		pendingItems = {}
		itemsPanel:open()
		refreshItems()
	end)
	statusLabel = Kit.label(bar, {
		Name = "Status", Position = UDim2.fromOffset(242, 0), Size = UDim2.new(1, -242 - 312, 1, 0), TextWrapped = true,
	}, { maxTextSize = 15 })
	readyButton = Kit.button(bar, {
		Name = "Ready", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -204, 0, 0), Size = UDim2.fromOffset(100, 34),
	}, { text = "Ready", color = C.Green, maxTextSize = 18 })
	Kit.onClick(readyButton, function()
		if current then
			act("ready", not current.you.ready)
		end
	end)
	confirmButton = Kit.button(bar, {
		Name = "Confirm", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(102, 34),
	}, { text = "Confirm", color = C.Yellow, maxTextSize = 18 })
	Kit.onClick(confirmButton, function()
		act("confirm")
	end)
	cancelButton = Kit.button(bar, {
		Name = "Cancel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(90, 34),
	}, { text = "Cancel", color = C.Red, maxTextSize = 18 })
	Kit.onClick(cancelButton, function()
		act("cancel")
	end)
end

local function buildLobby(body)
	lobbyView = Kit.make("Frame", { Name = "LobbyView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	lobbyTabs = Kit.tabs(lobbyView, { Size = UDim2.fromOffset(300, 34) }, {
		button = Vector2.new(140, 34), gap = 6, maxTextSize = 18,
		items = {
			{ name = "Players", text = "👥 Players", color = C.Blue },
			{ name = "History", text = "📜 History", color = C.Purple },
		},
		onSelect = function(name)
			playersList.Visible = name == "Players"
			historyList.Visible = name == "History"
			emptyPlayers.Visible = false
			showView()
		end,
	})
	local invite = Kit.button(lobbyView, {
		Name = "Invite", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(170, 34),
	}, { text = "➕ Invite Friends", color = C.Green, maxTextSize = 18 })
	Kit.onClick(invite, function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			Notify.toast("Invites aren't available here", "info")
		end
	end)
	playersList = Kit.scroll(lobbyView, { Name = "Players", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) }, { gap = 6, pad = 3 })
	historyList = Kit.scroll(lobbyView, {
		Name = "History", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), Visible = false,
	}, { gap = 6, pad = 3 })
	emptyPlayers = Kit.label(lobbyView, {
		Name = "Empty", Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 60), Visible = false, TextWrapped = true,
		Text = "Nobody else is in this server yet.\nInvite a friend: you both get +10% Air!", TextColor3 = C.TextSoft,
	}, { maxTextSize = 22 })
	lobbyTabs:select("Players", true)
end

local function buildLocked(body)
	lockedView = Kit.make("Frame", { Name = "LockedView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	Kit.label(lockedView, {
		Name = "Padlock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(90, 90), Text = "🔒",
	}, { outline = 0 })
	Kit.label(lockedView, {
		Name = "Title", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(560, 36),
		Text = "Trading unlocks at " .. Config.Format(T.UnlockRolls) .. " rolls",
	}, { outline = 3, maxTextSize = 32 })
	progress = Kit.progress(lockedView, {
		Name = "Progress", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 156), Size = UDim2.fromOffset(420, 36),
	}, { color = C.Purple, maxTextSize = 22 })
	Kit.label(lockedView, {
		Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 206), Size = UDim2.fromOffset(600, 50),
		TextWrapped = true, TextColor3 = C.TextSoft,
		Text = "Auto Roll counts too! Then trade Floaties, potions, Grade Tokens and Trait Gems with anyone in your server (never Air).",
	}, { outline = 0, maxTextSize = 18 })
end

local function buildPicker(canvas)
	picker = Kit.panel(canvas, {
		name = "TradePicker", title = "Add Floaties", icon = "🎈", color = C.Blue, size = Vector2.new(640, 352), stack = true,
		onOpen = refreshPicker,
	})
	local body = picker.body -- 616 x 284
	pickerGrid = Kit.scroll(body, { Name = "Grid", Size = UDim2.new(1, 0, 1, -42) }, { cell = Vector2.new(92, 112), gap = 6 })
	pickerCount = Kit.label(body, {
		Name = "Count", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, -130, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, { maxTextSize = 16 })
	local done = Kit.button(body, {
		Name = "Done", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(120, 36),
	}, { text = "Done", color = C.Green, maxTextSize = 20 })
	Kit.onClick(done, function()
		picker:close()
	end)
end

local function sendItem(key, n)
	pendingItems[key] = n
	refreshItems()
	-- wait for the clicks to stop, then send the final amount once
	task.delay(0.3, function()
		if pendingItems[key] == n and current then
			act("item", key, n)
			pendingItems[key] = nil
			refreshItems()
		end
	end)
end

local function buildItemsPanel(canvas)
	itemsPanel = Kit.panel(canvas, {
		name = "TradeItems", title = "Add Items", icon = "🧪", color = C.Purple, size = Vector2.new(470, 340), stack = true,
		onOpen = refreshItems,
	})
	local body = itemsPanel.body -- 446 x 272
	local list = Kit.make("Frame", { Name = "Rows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, body)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i, item in ipairs(T.Items) do
		local row = Kit.plate(list, {
			Name = item.key, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = i,
		}, { color = C.Row, transparency = 0, radius = 10, border = 2 })
		Kit.label(row, { Name = "Icon", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(36, 36), Text = item.icon }, { outline = 0 })
		Kit.label(row, {
			Name = "ItemName", Position = UDim2.fromOffset(48, 3), Size = UDim2.new(1, -250, 0, 22), Text = item.name,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 18 })
		local have = Kit.label(row, {
			Name = "Have", Position = UDim2.fromOffset(48, 25), Size = UDim2.new(1, -250, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.TextSoft,
		}, { outline = 0, maxTextSize = 14 })
		local minus = Kit.button(row, {
			Name = "Minus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(36, 36),
		}, { text = "-", color = C.Red, maxTextSize = 24, radius = 10 })
		local amount = Kit.label(row, {
			Name = "Amount", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(50, 30), Text = "0",
		}, { maxTextSize = 22 })
		local plus = Kit.button(row, {
			Name = "Plus", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -56, 0.5, 0), Size = UDim2.fromOffset(36, 36),
		}, { text = "+", color = C.Green, maxTextSize = 24, radius = 10 })
		local all = Kit.button(row, {
			Name = "All", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(46, 36),
		}, { text = "All", color = C.Blue, maxTextSize = 16, radius = 10 })
		local function currentAmount()
			return pendingItems[item.key] or (current and current.you.items[item.key]) or 0
		end
		local function cap()
			return math.min(itemOwned(item.key), T.MaxItemAmount)
		end
		Kit.onClick(minus, function()
			sendItem(item.key, math.max(0, currentAmount() - 1))
		end)
		Kit.onClick(plus, function()
			sendItem(item.key, math.min(cap(), currentAmount() + 1))
		end)
		Kit.onClick(all, function()
			sendItem(item.key, cap())
		end)
		itemRows[item.key] = { have = have, amount = amount, minus = minus, plus = plus, all = all }
	end
end

local function buildAlerts(canvas)
	local alerts = Kit.make("Frame", {
		Name = "TradeAlerts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 30,
	}, canvas)
	Kit.make("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, alerts)

	requestBox = Kit.plate(alerts, {
		Name = "Request", Size = UDim2.fromOffset(340, 76), LayoutOrder = 1, Visible = false,
	}, { color = C.Purple, gradient = true, radius = 14, border = 3 })
	requestText = Kit.label(requestBox, {
		Name = "Text", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26),
	}, { maxTextSize = 20 })
	local accept = Kit.button(requestBox, {
		Name = "Accept", Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(150, 32),
	}, { text = "✅ Accept", color = C.Green, maxTextSize = 18 })
	local decline = Kit.button(requestBox, {
		Name = "Decline", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 32), Size = UDim2.fromOffset(150, 32),
	}, { text = "❌ Decline", color = C.Red, maxTextSize = 18 })
	requestBar = Kit.make("Frame", {
		Name = "Timer", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, 4),
		BackgroundColor3 = C.Yellow, BorderSizePixel = 0,
	}, requestBox)
	Kit.round(requestBar, 2)
	local function respond(accepted)
		local req = table.remove(requests, 1)
		if not req then
			return
		end
		local ok, success, msg = pcall(function()
			return remotes.TradeRespond:InvokeServer(req.from, accepted)
		end)
		if ok and not success and msg then
			Notify.toast(msg, "error")
		end
	end
	Kit.onClick(accept, function()
		respond(true)
	end)
	Kit.onClick(decline, function()
		respond(false)
	end)

	pill = Kit.button(alerts, {
		Name = "InProgress", Size = UDim2.fromOffset(320, 36), LayoutOrder = 2, Visible = false,
	}, { text = "🤝 Trade in progress: tap to open", color = C.Purple, maxTextSize = 18 })
	Kit.onClick(pill, function()
		panel:open()
	end)
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function TradePanel.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "TradePanel", title = "Trade", icon = "🤝", color = C.Purple, size = Vector2.new(760, 360),
		onOpen = showView,
	})
	local body = panel.body -- 736 x 292
	buildLocked(body)
	buildLobby(body)
	buildTradeView(body)
	buildPicker(canvas)
	buildItemsPanel(canvas)
	buildAlerts(canvas)

	-- a padlock on the HUD tile until trading unlocks
	local tile = HUD.getTile("Trade")
	if tile then
		tileLock = Kit.label(tile, {
			Name = "Padlock", AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(24, 24),
			Text = "🔒", ZIndex = 6,
		}, { outline = 0 })
	end

	remotes:WaitForChild("TradeEvent").OnClientEvent:Connect(function(kind, payload)
		if kind == "request" then
			table.insert(requests, payload)
			Kit.playSound("Alert")
		elseif kind == "state" then
			local isNew = current == nil or current.id ~= payload.id
			current = payload
			if isNew then
				-- requests from before don't matter now
				table.clear(requests)
				pendingItems = {}
				panel:open()
			end
			showView()
		elseif kind == "closed" then
			current = nil
			pendingItems = {}
			picker:close()
			itemsPanel:close()
			if not payload.done then
				Notify.toast(payload.reason or "Trade cancelled", "info")
			end
			showView()
		end
	end)
	State.changed:Connect(function(what)
		if current and (what == "floaties" or what == "items" or what == "full") then
			refreshPicker()
			refreshItems()
		elseif what == "trades" and lobbyView.Visible and lobbyTabs.selected == "History" then
			refreshHistory()
		end
	end)
	player:GetAttributeChangedSignal("TotalRolls"):Connect(function()
		if panel:isOpen() and current == nil then
			showView()
		end
	end)
	return panel
end

function TradePanel.update()
	if not panel then
		return
	end
	local now = workspace:GetServerTimeNow()
	while requests[1] and requests[1].expires <= now do
		table.remove(requests, 1)
	end
	local req = requests[1]
	requestBox.Visible = req ~= nil
	if req then
		requestText.Text = "🤝 " .. req.name .. " wants to trade!"
		requestBar.Size = UDim2.new(math.clamp((req.expires - now) / T.RequestTimeout, 0, 1), -20, 0, 4)
	end
	if #requests ~= shownRequests then
		shownRequests = #requests
		HUD.setBadge("Trade", if shownRequests > 0 then shownRequests else nil)
	end
	pill.Visible = current ~= nil and not panel:isOpen()
	if tileLock then
		tileLock.Visible = rolls() < T.UnlockRolls
	end
	if current and panel:isOpen() then
		refreshButtons()
	elseif panel:isOpen() and lobbyView.Visible and lobbyTabs.selected == "Players" and os.clock() - lastListRefresh > 1 then
		lastListRefresh = os.clock()
		TradePanel.refreshLobby()
	end
end

return TradePanel
