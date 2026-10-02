--[[
	Floatie Farm — RewardsPanel (ModuleScript child of the ClientMain LocalScript)
	The Rewards window (the 🎁 tile), with three tabs:
	  Daily     Days 1-6 in a grid and a big Day 7 (like the Anime Card Farm
	            one): CLAIM! / Claimed / Not Ready!, "OP!" on the best days,
	            and when the next one is ready. One claim per 24 h; more than
	            48 h away restarts at Day 1.
	  Playtime  12 tiles that unlock while you play this session, Claim All,
	            and Skip All (Robux) to unlock every tile now.
	  Codes     promo codes (see Codes.luau)

	API:
	  RewardsPanel.mount(canvas) -> Panel
	  RewardsPanel.update()          -- init's slow loop; timers tick while open
	  RewardsPanel.claimable() -> n  -- rewards ready right now (for the tile badge)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RewardInfo = require(Shared:WaitForChild("RewardInfo"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Codes = require(script.Parent.Codes)

local player = Players.LocalPlayer
local C = Config.UI

local RewardsPanel = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local OP_DAYS = { [2] = true, [4] = true, [6] = true, [7] = true }

local panel = nil
local tabs = nil
local views = {}
local status = nil
local dayTiles = {}
local playTiles = {}
local skipButton, claimAllButton = nil, nil
local busy = false
local lastTick = 0

---------------------------------------------------------------------
-- State helpers (the same rules the server uses)
---------------------------------------------------------------------
local function dailyState()
	local d = State.data.daily or { day = 0, last = 0 }
	local now = workspace:GetServerTimeNow()
	local since = now - (d.last or 0)
	local nextDay = if (d.day or 0) == 0 or since > Config.Daily.StreakReset then 1 else ((d.day or 0) % #Config.Daily.Days) + 1
	local ready = (d.last or 0) == 0 or since >= Config.Daily.Cooldown
	return nextDay, ready, math.max(0, Config.Daily.Cooldown - since)
end

local function playtimeClaimed()
	local set = {}
	for n in string.gmatch(player:GetAttribute("PlaytimeClaimed") or "", "%d+") do
		set[tonumber(n)] = true
	end
	return set
end

-- seconds until tile i unlocks (0 = ready)
local function playtimeLeft(i)
	if player:GetAttribute("PlaytimeSkipped") then
		return 0
	end
	local joined = player:GetAttribute("JoinedAt") or workspace:GetServerTimeNow()
	local played = workspace:GetServerTimeNow() - joined
	return math.max(0, Config.Playtime[i].minutes * 60 - played)
end

function RewardsPanel.claimable()
	local n = 0
	local _, ready = dailyState()
	if ready and State.ready() then
		n += 1
	end
	local claimed = playtimeClaimed()
	for i in ipairs(Config.Playtime) do
		if not claimed[i] and playtimeLeft(i) <= 0 then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------
local function refreshDaily()
	local nextDay, ready, wait = dailyState()
	for day, tile in ipairs(dayTiles) do
		local state
		if day < nextDay then
			state = "claimed"
		elseif day == nextDay then
			state = if ready then "ready" else "next"
		else
			state = "later"
		end
		tile.state.Text = if state == "ready" then "CLAIM!" elseif state == "claimed" then "✓ Claimed" elseif state == "next" then Config.FormatTime(wait) else "Not Ready!"
		tile.state.TextColor3 = if state == "ready" then C.Income elseif state == "claimed" then C.TextSoft elseif state == "next" then C.Gold else C.Bad
		Kit.setButtonColor(tile.button, if state == "ready" then C.Green elseif state == "claimed" then C.Grey else C.Row)
	end
	status.Text = if ready then "🎁 Your Day " .. nextDay .. " reward is ready!" else "Next reward in " .. Config.FormatTime(wait)
	status.TextColor3 = if ready then C.Income else C.Gold
end

local function refreshPlaytime()
	local claimed = playtimeClaimed()
	local anyReady = false
	for i, tile in ipairs(playTiles) do
		local left = playtimeLeft(i)
		if claimed[i] then
			tile.state.Text = "✓"
			tile.state.TextColor3 = C.TextSoft
			Kit.setButtonColor(tile.button, C.Grey)
		elseif left <= 0 then
			anyReady = true
			tile.state.Text = "Claim!"
			tile.state.TextColor3 = C.Income
			Kit.setButtonColor(tile.button, C.Green)
		else
			tile.state.Text = Config.FormatTime(left)
			tile.state.TextColor3 = C.Text
			Kit.setButtonColor(tile.button, C.Row)
		end
	end
	Kit.setButtonColor(claimAllButton, if anyReady then C.Green else C.Grey)
	local skipped = player:GetAttribute("PlaytimeSkipped") == true
	Kit.setEnabled(skipButton, not skipped)
	Kit.setButtonText(skipButton, if skipped then "⏩ Skipped ✓" else "⏩ Skip All  R$ " .. Config.DevProducts.SkipPlaytime.price)
	if tabs.selected == "Playtime" then
		status.Text = "Rewards unlock while you play this session"
		status.TextColor3 = C.TextSoft
	end
end

local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	if tabs.selected == "Daily" then
		refreshDaily()
	elseif tabs.selected == "Playtime" then
		refreshPlaytime()
	else
		status.Text = ""
	end
end

---------------------------------------------------------------------
-- Claiming
---------------------------------------------------------------------
local function claimDaily()
	if busy then
		return
	end
	busy = true
	local ok, success, result = pcall(function()
		return remotes.ClaimDaily:InvokeServer()
	end)
	busy = false
	if ok and not success and result then
		Notify.toast(result, "error")
	end
	refresh()
end

local function claimPlaytime(i)
	local ok, success, result = pcall(function()
		return remotes.ClaimPlaytime:InvokeServer(i)
	end)
	if ok and not success and result then
		Notify.toast(result, "error")
	end
	return ok and success
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
local function buildDaily(parent)
	local grid = Kit.make("Frame", { Name = "Days", Size = UDim2.fromOffset(436, 252), BackgroundTransparency = 1 }, parent)
	Kit.make("UIGridLayout", { CellSize = UDim2.fromOffset(140, 122), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for day, reward in ipairs(Config.Daily.Days) do
		local big = day == #Config.Daily.Days
		local button = Kit.button(if big then parent else grid, {
			Name = "Day" .. day, LayoutOrder = day,
			Position = if big then UDim2.fromOffset(446, 0) else nil, Size = if big then UDim2.fromOffset(170, 252) else UDim2.fromOffset(140, 122),
		}, { text = "", color = C.Row, radius = 12 })
		local face = button.Face
		Kit.label(face, { Name = "DayTitle", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, if big then 36 else 24), Text = "Day " .. day, ZIndex = 3 },
			{ outline = 3, maxTextSize = if big then 34 else 22 })
		Kit.label(face, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, if big then 0.4 else 0.45), Size = UDim2.fromOffset(if big then 90 else 46, if big then 90 else 46), Text = RewardInfo.icon(reward), ZIndex = 3 }, { outline = 0 })
		Kit.label(face, {
			Name = "Reward", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if big then -46 else -24), Size = UDim2.new(1, -10, 0, if big then 46 else 22),
			Text = RewardInfo.text(reward), TextWrapped = true, ZIndex = 3,
		}, { maxTextSize = if big then 20 else 14 })
		local state = Kit.label(face, {
			Name = "State", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -10, 0, if big then 36 else 20), ZIndex = 3,
		}, { outline = 3, maxTextSize = if big then 30 else 18 })
		if OP_DAYS[day] then
			local tag = Kit.label(button, {
				Name = "OP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -6), Size = UDim2.fromOffset(44, 24), Rotation = 12,
				Text = "OP!", TextColor3 = C.Yellow, ZIndex = 6,
			}, { outline = 3, maxTextSize = 22 })
			local _ = tag
		end
		Kit.onClick(button, function()
			local nextDay, ready = dailyState()
			if day == nextDay and ready then
				claimDaily()
			end
		end)
		dayTiles[day] = { button = button, state = state }
	end
end

local function buildPlaytime(parent)
	local grid = Kit.make("Frame", { Name = "Tiles", Size = UDim2.new(1, 0, 0, 206), BackgroundTransparency = 1 }, parent)
	Kit.make("UIGridLayout", { CellSize = UDim2.fromOffset(148, 64), CellPadding = UDim2.fromOffset(8, 7), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, entry in ipairs(Config.Playtime) do
		local button = Kit.button(grid, { Name = "Tile" .. i, LayoutOrder = i }, { text = "", color = C.Row, radius = 10 })
		local face = button.Face
		Kit.label(face, { Name = "Icon", Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(44, 52), Text = RewardInfo.icon(entry.reward), ZIndex = 3 }, { outline = 0 })
		Kit.label(face, {
			Name = "Reward", Position = UDim2.fromOffset(50, 4), Size = UDim2.new(1, -54, 0, 30), Text = RewardInfo.text(entry.reward),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
		}, { maxTextSize = 14 })
		local state = Kit.label(face, {
			Name = "State", Position = UDim2.fromOffset(50, 34), Size = UDim2.new(1, -54, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
		}, { outline = 3, maxTextSize = 20 })
		Kit.onClick(button, function()
			if not playtimeClaimed()[i] and playtimeLeft(i) <= 0 then
				claimPlaytime(i)
				refresh()
			end
		end)
		playTiles[i] = { button = button, state = state }
	end
	claimAllButton = Kit.button(parent, {
		Name = "ClaimAll", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(200, 42),
	}, { text = "🎁 Claim All", color = C.Green, maxTextSize = 20 })
	Kit.onClick(claimAllButton, function()
		local claimed = playtimeClaimed()
		for i in ipairs(Config.Playtime) do
			if not claimed[i] and playtimeLeft(i) <= 0 then
				claimPlaytime(i)
				task.wait(0.35) -- the server's rate limit
			end
		end
		refresh()
	end)
	skipButton = Kit.button(parent, {
		Name = "SkipAll", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(220, 42),
	}, { text = "⏩ Skip All", color = C.Yellow, maxTextSize = 20 })
	Kit.onClick(skipButton, function()
		local id = Config.DevProducts.SkipPlaytime.id
		if id == 0 then
			Notify.toast("Coming soon! (Developer: paste the product ID into Config)", "info")
			return
		end
		MarketplaceService:PromptProductPurchase(player, id)
	end)
end

function RewardsPanel.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "RewardsPanel", title = "Rewards", icon = "🎁", color = C.Pink,
		size = Vector2.new(640, 366), onOpen = refresh,
	})
	local body = panel.body -- 616 x 298
	tabs = Kit.tabs(body, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(400, 34) }, {
		button = Vector2.new(124, 34), gap = 6, maxTextSize = 18,
		items = {
			{ name = "Daily", text = "📅 Daily", color = C.Blue },
			{ name = "Playtime", text = "⏰ Playtime", color = C.Purple },
			{ name = "Codes", text = "🎁 Codes", color = C.Pink },
		},
		onSelect = function(name)
			for viewName, view in pairs(views) do
				view.Visible = viewName == name
			end
			refresh()
		end,
	})
	status = Kit.label(body, {
		Name = "Status", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(220, 30),
		TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true,
	}, { maxTextSize = 16 })
	for _, name in ipairs({ "Daily", "Playtime", "Codes" }) do
		views[name] = Kit.make("Frame", { Name = name .. "View", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1, Visible = false }, body)
	end
	buildDaily(views.Daily)
	buildPlaytime(views.Playtime)
	Codes.build(views.Codes)
	tabs:select("Daily")

	State.changed:Connect(function(what)
		if what == "daily" or what == "full" then
			refresh()
		end
	end)
	for _, attr in ipairs({ "PlaytimeClaimed", "PlaytimeSkipped" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	return panel
end

-- RewardsPanel.showTab("Codes") — open straight on a tab
function RewardsPanel.showTab(name)
	if panel then
		panel:open()
		tabs:select(name)
	end
end

function RewardsPanel.update()
	local now = os.clock()
	if panel and panel:isOpen() and now - lastTick >= 1 then
		lastTick = now
		refresh()
	end
end

return RewardsPanel
