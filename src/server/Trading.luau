--[[
	Trading (ModuleScript in ServerScriptService.Server)
	Player-to-player trades (rules in Config.Trade). Both players need
	1,000 total rolls.
	  1. TradeRequest(userId)               ask someone in the server (expires in 30 s)
	  2. TradeRespond(fromUserId, accept)   accepting opens the trade window for both
	  3. TradeAction(action, ...)           "add" uid / "remove" uid / "item" key amount /
	                                        "ready" true|false / "confirm" / "cancel"
	Any change to either offer takes back both Readys. Both Ready -> a 5 s
	countdown -> both Confirm -> the swap.

	The swap trusts only the server's own records: every Floatie is looked
	up by its uid in its owner's save and must be unchanged since it was
	offered and not locked, the items must still be there, and both sides
	need room. Both sides then swap in one step (nothing yields in between),
	both players are saved right away, and the trade goes into both
	histories (last 20). Leaving the game cancels the trade; there is a
	10 s cooldown between trades.

	Client <- TradeEvent(kind, payload):
	  "request"  { from = userId, name = display name, expires = server time }
	  "state"    the trade as this player sees it (see view())
	  "closed"   { reason = text, done = true when the swap happened }

	Module API (the remotes call these; so can tests and other modules):
	  Trading.request(player, target) -> ok, msg
	  Trading.respond(player, fromUserId, accept) -> ok, msg
	  Trading.action(player, action, ...) -> ok, msg
	  Trading.get(player) -> the trade table or nil (read-only)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Formulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Floaties = require(script.Parent.Floaties)
local Sync = require(script.Parent.Sync)

local T = Config.Trade

local Trading = {}

local TradeEventRE = Core.remote("TradeEvent")

local trades = {}    -- player -> trade (both players point at the same table)
local requests = {}  -- target player -> { [from player] = expires (server time) }
local lastEnded = {} -- player -> os.clock() when their last trade ended
local nextId = 0

local ITEM = {}
for _, item in ipairs(T.Items) do
	ITEM[item.key] = item
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function unlocked(player)
	local prof = Core.getProfile(player)
	return prof ~= nil and (prof.data.totalRolls or 0) >= T.UnlockRolls
end

local function onCooldown(player)
	return os.clock() - (lastEnded[player] or -math.huge) < T.Cooldown
end

local function itemCount(prof, key)
	local items = prof.data.items
	if ITEM[key].potion then
		return items.potions[key] or 0
	end
	return items[key] or 0
end

local function addItem(prof, key, n)
	local items = prof.data.items
	if ITEM[key].potion then
		items.potions[key] = (items.potions[key] or 0) + n
	else
		items[key] = (items[key] or 0) + n
	end
end

-- everything that makes a Floatie worth something: "did it change since it was offered?"
local function signature(f)
	return table.concat({ f.id, f.mut, tostring(f.form), f.level, f.grade, tostring(f.trait) }, "|")
end

local function describe(f)
	return ("%s Lv %d (%s)"):format(Formulas.nameOf(f), f.level, f.grade)
end

local function other(trade, player)
	return if trade.a == player then trade.b else trade.a
end

---------------------------------------------------------------------
-- What each client sees
---------------------------------------------------------------------
local function side(trade, player)
	local offer = trade.offers[player]
	local list = {}
	for _, uid in ipairs(offer.uids) do
		local f = Floaties.find(player, uid)
		if f then
			table.insert(list, { uid = f.uid, id = f.id, mut = f.mut, form = f.form, level = f.level, grade = f.grade, trait = f.trait })
		end
	end
	return {
		userId = player.UserId,
		name = player.DisplayName,
		floaties = list,
		items = table.clone(offer.items),
		ready = trade.ready[player] == true,
		confirmed = trade.confirmed[player] == true,
	}
end

local function view(trade, player)
	return {
		id = trade.id,
		you = side(trade, player),
		them = side(trade, other(trade, player)),
		countdownEnds = trade.countdownEnds,
	}
end

-- send a TradeEvent (only real players still in the game have a client;
-- Studio tests trade with a stand-in table)
local function tell(p, kind, payload)
	if typeof(p) == "Instance" and p.Parent then
		TradeEventRE:FireClient(p, kind, payload)
	end
end

local function push(trade)
	for _, p in ipairs({ trade.a, trade.b }) do
		tell(p, "state", view(trade, p))
	end
end

local function close(trade, reason, done)
	if trade.closed then
		return
	end
	trade.closed = true
	for _, p in ipairs({ trade.a, trade.b }) do
		if trades[p] == trade then
			trades[p] = nil
		end
		lastEnded[p] = os.clock()
		tell(p, "closed", { reason = reason, done = done == true })
	end
end

-- an offer changed: both Readys (and Confirms) are taken back
local function changed(trade)
	trade.ready[trade.a], trade.ready[trade.b] = false, false
	trade.confirmed[trade.a], trade.confirmed[trade.b] = false, false
	trade.countdownEnds = nil
end

---------------------------------------------------------------------
-- The swap
---------------------------------------------------------------------
local function fail(trade, reason)
	close(trade, reason)
	return false, reason
end

local function execute(trade)
	local a, b = trade.a, trade.b
	local profs = { [a] = Core.getProfile(a), [b] = Core.getProfile(b) }
	if not profs[a] or not profs[b] or not a.Parent or not b.Parent then
		return fail(trade, "The other player left")
	end
	-- 1. everything offered is still there, unchanged and not locked
	for _, p in ipairs({ a, b }) do
		local offer = trade.offers[p]
		for _, uid in ipairs(offer.uids) do
			local f = Floaties.find(p, uid)
			if not f or f.locked or signature(f) ~= offer.sigs[uid] then
				return fail(trade, "An offered Floatie changed, so the trade was cancelled. Try again!")
			end
		end
		for key, n in pairs(offer.items) do
			if n > itemCount(profs[p], key) then
				return fail(trade, p.DisplayName .. " no longer has the items they offered")
			end
		end
	end
	-- 2. room on both sides (slots + Backpack)
	for _, p in ipairs({ a, b }) do
		local q = other(trade, p)
		local after = #profs[p].data.floaties - #trade.offers[p].uids + #trade.offers[q].uids
		if after > Economy.slotCount(p) + Economy.backpackSize(p) then
			return fail(trade, p.DisplayName .. " doesn't have room for those Floaties")
		end
	end
	-- 3. the swap: nothing below yields, so nothing can change halfway
	local moved = { [a] = {}, [b] = {} }
	for _, p in ipairs({ a, b }) do
		for _, uid in ipairs(trade.offers[p].uids) do
			table.insert(moved[p], Floaties.remove(p, uid))
		end
	end
	local log = { [a] = { gave = {}, got = {} }, [b] = { gave = {}, got = {} } }
	for _, p in ipairs({ a, b }) do
		local q = other(trade, p)
		for _, f in ipairs(moved[p]) do
			Floaties.add(q, { id = f.id, mut = f.mut, form = f.form, level = f.level, grade = f.grade, trait = f.trait }, { force = true })
			table.insert(log[p].gave, describe(f))
			table.insert(log[q].got, describe(f))
		end
		for key, n in pairs(trade.offers[p].items) do
			addItem(profs[p], key, -n)
			addItem(profs[q], key, n)
			local line = n .. " " .. (if n == 1 then ITEM[key].one else ITEM[key].name)
			table.insert(log[p].gave, line)
			table.insert(log[q].got, line)
		end
	end
	-- 4. both histories, then save both right away
	for _, p in ipairs({ a, b }) do
		local q = other(trade, p)
		local history = profs[p].data.trades
		table.insert(history, { t = os.time(), with = q.UserId, name = q.DisplayName, gave = log[p].gave, got = log[p].got })
		while #history > T.HistorySize do
			table.remove(history, 1)
		end
		Sync.field(p, "items")
		Sync.field(p, "trades")
		Core.StatsChanged:Fire(p)
	end
	close(trade, "Trade complete! 🤝", true)
	for _, p in ipairs({ a, b }) do
		Core.notify(p, "🤝 Trade with " .. other(trade, p).DisplayName .. " complete!", "success")
		task.spawn(DataService.Save, p, profs[p])
	end
	return true
end

---------------------------------------------------------------------
-- Offer actions
---------------------------------------------------------------------
local function addFloatie(trade, player, uid)
	local offer = trade.offers[player]
	if #offer.uids >= T.MaxFloaties then
		return false, "Up to " .. T.MaxFloaties .. " Floaties per trade"
	end
	if type(uid) ~= "number" or table.find(offer.uids, uid) then
		return false, "It's already in the trade"
	end
	local f = Floaties.find(player, uid)
	if not f then
		return false, "Floatie not found"
	end
	if f.locked then
		return false, "Locked Floaties can't be traded (unlock it in your Backpack first)"
	end
	table.insert(offer.uids, uid)
	offer.sigs[uid] = signature(f)
	return true
end

local function removeFloatie(trade, player, uid)
	local offer = trade.offers[player]
	local i = table.find(offer.uids, uid)
	if not i then
		return false, "It's not in the trade"
	end
	table.remove(offer.uids, i)
	offer.sigs[uid] = nil
	return true
end

local function setItem(trade, player, key, amount)
	if type(key) ~= "string" or not ITEM[key] or type(amount) ~= "number" or amount ~= amount then
		return false, "Try again"
	end
	local prof = Core.getProfile(player)
	local n = math.clamp(math.floor(amount), 0, math.min(itemCount(prof, key), T.MaxItemAmount))
	trade.offers[player].items[key] = if n > 0 then n else nil
	return true
end

-- an offered Floatie was levelled, rerolled, sold...: update the offer so the
-- other player sees it, and take back both Readys
Core.FloatiesChanged:Connect(function(player)
	local trade = trades[player]
	if not trade or trade.closed or trade.busy then
		return
	end
	local offer = trade.offers[player]
	local dirty = false
	for i = #offer.uids, 1, -1 do
		local uid = offer.uids[i]
		local f = Floaties.find(player, uid)
		if not f or f.locked then
			table.remove(offer.uids, i)
			offer.sigs[uid] = nil
			dirty = true
		elseif signature(f) ~= offer.sigs[uid] then
			offer.sigs[uid] = signature(f)
			dirty = true
		end
	end
	if dirty then
		changed(trade)
		push(trade)
	end
end)

---------------------------------------------------------------------
-- Requests, answers and actions (the remotes below call these)
---------------------------------------------------------------------
-- player asks target for a trade -> ok, message
function Trading.request(player, target)
	if not target or target == player or not Core.getProfile(target) then
		return false, "That player isn't here"
	end
	if not unlocked(player) then
		return false, "Trading unlocks at " .. Config.Format(T.UnlockRolls) .. " rolls"
	end
	if not unlocked(target) then
		return false, target.DisplayName .. " hasn't unlocked trading yet"
	end
	if trades[player] then
		return false, "Finish your current trade first"
	end
	if trades[target] then
		return false, target.DisplayName .. " is already trading"
	end
	if onCooldown(player) then
		return false, "Wait a few seconds between trades"
	end
	requests[target] = requests[target] or {}
	local expires = Core.now() + T.RequestTimeout
	requests[target][player] = expires
	tell(target, "request", { from = player.UserId, name = player.DisplayName, expires = expires })
	return true, "Trade request sent to " .. target.DisplayName
end

-- player answers the request from fromUserId -> ok, message
function Trading.respond(player, fromUserId, accept)
	-- the request remembers who sent it
	local from, expires = nil, nil
	for p, t in pairs(requests[player] or {}) do
		if p.UserId == fromUserId then
			from, expires = p, t
		end
	end
	if from then
		requests[player][from] = nil
	end
	if not from or Core.now() > expires then
		return false, "That request expired"
	end
	if accept ~= true then
		Core.notify(from, player.DisplayName .. " declined your trade", "info")
		return true
	end
	if not Core.getProfile(from) then
		return false, "They left"
	end
	if trades[player] or trades[from] then
		return false, "Someone is already trading"
	end
	if onCooldown(player) or onCooldown(from) then
		return false, "Wait a few seconds between trades"
	end
	if not unlocked(player) or not unlocked(from) then
		return false, "Trading is locked"
	end
	nextId += 1
	local trade = {
		id = nextId,
		a = from,
		b = player,
		offers = {
			[from] = { uids = {}, sigs = {}, items = {} },
			[player] = { uids = {}, sigs = {}, items = {} },
		},
		ready = {},
		confirmed = {},
		countdownEnds = nil,
		busy = false,
		closed = false,
	}
	trades[from], trades[player] = trade, trade
	push(trade)
	return true
end

-- action = "add" uid | "remove" uid | "item" key amount | "ready" bool | "confirm" | "cancel"
function Trading.action(player, action, arg1, arg2)
	local trade = trades[player]
	if not trade or trade.closed or trade.busy then
		return false, "You're not in a trade"
	end
	if action == "cancel" then
		close(trade, player.DisplayName .. " cancelled the trade")
		return true
	elseif action == "ready" then
		trade.ready[player] = arg1 == true
		trade.confirmed[trade.a], trade.confirmed[trade.b] = false, false
		trade.countdownEnds = if trade.ready[trade.a] and trade.ready[trade.b] then Core.now() + T.ReadyCountdown else nil
		push(trade)
		return true
	elseif action == "confirm" then
		-- a little slack for clocks: the button opens when the countdown hits 0
		if not trade.countdownEnds or Core.now() < trade.countdownEnds - 0.3 then
			return false, "Wait for the countdown"
		end
		trade.confirmed[player] = true
		if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
			trade.busy = true
			return execute(trade)
		end
		push(trade)
		return true
	end
	local ok, msg
	if action == "add" then
		ok, msg = addFloatie(trade, player, arg1)
	elseif action == "remove" then
		ok, msg = removeFloatie(trade, player, arg1)
	elseif action == "item" then
		ok, msg = setItem(trade, player, arg1, arg2)
	else
		return false, "Try again"
	end
	if ok then
		changed(trade)
		push(trade)
	end
	return ok, msg
end

-- the trade this player is in (nil when not trading); read-only for other modules
function Trading.get(player)
	return trades[player]
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
Core.remote("TradeRequest", "RemoteFunction").OnServerInvoke = function(player, userId)
	if not Core.getProfile(player) or not Core.throttle(player, "tradeRequest", 1) then
		return false, "Slow down!"
	end
	return Trading.request(player, type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil)
end

Core.remote("TradeRespond", "RemoteFunction").OnServerInvoke = function(player, userId, accept)
	if not Core.getProfile(player) or not Core.throttle(player, "tradeRespond", 0.3) then
		return false, "Slow down!"
	end
	return Trading.respond(player, userId, accept)
end

Core.remote("TradeAction", "RemoteFunction").OnServerInvoke = function(player, action, arg1, arg2)
	if not Core.getProfile(player) or not Core.throttle(player, "tradeAction", 0.1) then
		return false, "Slow down!"
	end
	return Trading.action(player, action, arg1, arg2)
end

Players.PlayerRemoving:Connect(function(player)
	local trade = trades[player]
	if trade then
		close(trade, player.DisplayName .. " left the game")
	end
	requests[player] = nil
	for _, pending in pairs(requests) do
		pending[player] = nil
	end
	lastEnded[player] = nil
end)

return Trading
