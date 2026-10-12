--[[
	Plaza (ModuleScript in ServerScriptService.Server)
	The things in the middle of the map that show the whole server:
	  • two global leaderboards (Most Rolls, Most Rebirths). They use
	    OrderedDataStores; while those are unavailable (e.g. an unpublished
	    place in Studio) they show the players in this server instead.
	  • the best Floatie in the server, on the gold pedestal by the Tower
	  • the event sign above the Tower door
	  • the Tower door ("coming soon")

	  Plaza.init(map)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)

local Plaza = {}

local BOARD_WRITE_EVERY = 120 -- seconds between writing your numbers to the global boards
local BOARD_READ_EVERY = 60

---------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------
local stores = {}
for _, name in ipairs({ "Rolls", "Rebirths" }) do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("Leaderboard_" .. name .. "_v1")
	end)
	stores[name] = if ok then store else nil
end

local nameCache = {}
local function userName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else ("Player " .. userId)
	return nameCache[userId]
end

local function fillBoard(rows, entries)
	for i, row in ipairs(rows) do
		local e = entries[i]
		row.left.Text = if e then ("#%d  %s"):format(i, e.name) else ""
		row.right.Text = if e then Config.Format(e.value) else ""
	end
end

local globalWorks = false -- true once a global board was read successfully

-- top 10 from the global store, or nil when it can't be read
local function readGlobal(name)
	local store = stores[name]
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	globalWorks = true
	local entries = {}
	for _, item in ipairs(page) do
		table.insert(entries, { name = userName(tonumber(item.key) or 0), value = item.value })
	end
	return entries
end

-- this server's players, best first
local function readLocal(field)
	local entries = {}
	for player, prof in Core.eachLoaded() do
		table.insert(entries, { name = player.DisplayName, value = prof.data[field] or 0 })
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

local function writeGlobal()
	for player, prof in Core.eachLoaded() do
		for name, store in pairs(stores) do
			local value = if name == "Rolls" then prof.data.totalRolls else prof.data.rebirths
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), math.floor(value))
				end)
			end
		end
	end
end

---------------------------------------------------------------------
-- The best Floatie in the server
---------------------------------------------------------------------
local bestKey = nil
local function refreshServerBest(plaza)
	local bestF, bestOwner, bestIncome = nil, nil, -1
	for player, prof in Core.eachLoaded() do
		local cash = Economy.cash(player)
		for _, f in ipairs(prof.data.floaties) do
			local income = Economy.floatieIncome(player, f, cash)
			if income > bestIncome then
				bestF, bestOwner, bestIncome = f, player, income
			end
		end
	end
	local key = bestF and table.concat({ bestOwner.UserId, bestF.uid, bestF.level, bestF.mut, tostring(bestF.form) }, "|") or ""
	if bestF then
		plaza.serverBestLabel.Text = ("🏆 BEST IN THE SERVER\n%s · %s · +%s/s"):format(
			Formulas.nameOf(bestF), bestOwner.DisplayName, Config.Format(bestIncome))
	else
		plaza.serverBestLabel.Text = "🏆 BEST FLOATIE IN THE SERVER"
	end
	if key == bestKey then
		return
	end
	bestKey = key
	plaza.serverBestFolder:ClearAllChildren()
	if bestF then
		local def = Config.FloatieById[bestF.id]
		local model = FloatieModel.Build(def, bestF.mut, 1.4 * Formulas.formScale(bestF))
		FloatieModel.SetAnchored(model, true)
		model:PivotTo(plaza.serverBestSpot)
		local label = model.PrimaryPart:FindFirstChild("Label")
		if label then
			label:Destroy()
		end
		model.Parent = plaza.serverBestFolder
	end
end

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------
function Plaza.init(map)
	local plaza = map.plaza

	plaza.towerPrompt.Triggered:Connect(function(player)
		Core.notify(player, "🗼 The Tower opens in a future update. Stay tuned!", "info")
	end)

	-- event sign: once a second
	task.spawn(function()
		while true do
			local ev = Economy.activeEvent()
			local now = Core.now()
			if ev then
				plaza.eventLabel.Text = ev.title .. "  " .. Config.FormatTime((ReplicatedStorage:GetAttribute("EventEndsAt") or now) - now)
			else
				local nextAt = ReplicatedStorage:GetAttribute("NextEventAt") or now
				plaza.eventLabel.Text = "Next event in " .. Config.FormatTime(nextAt - now)
			end
			task.wait(1)
		end
	end)

	-- best Floatie in the server: every few seconds
	task.spawn(function()
		while true do
			pcall(refreshServerBest, plaza)
			task.wait(8)
		end
	end)

	-- leaderboards
	task.spawn(function()
		local sinceWrite = BOARD_WRITE_EVERY - 20 -- first write 20 s after the server starts
		while true do
			if sinceWrite >= BOARD_WRITE_EVERY then
				sinceWrite = 0
				writeGlobal()
			end
			fillBoard(plaza.rollsRows, readGlobal("Rolls") or readLocal("totalRolls"))
			fillBoard(plaza.rebirthRows, readGlobal("Rebirths") or readLocal("rebirths"))
			task.wait(BOARD_READ_EVERY)
			sinceWrite += BOARD_READ_EVERY
		end
	end)
	-- the local fallback changes as players join: refresh it quickly in that case
	Core.PlayerLoaded:Connect(function()
		if not globalWorks then
			fillBoard(plaza.rollsRows, readLocal("totalRolls"))
			fillBoard(plaza.rebirthRows, readLocal("rebirths"))
		end
	end)
end

return Plaza
