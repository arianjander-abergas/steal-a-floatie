--[[
	DataService (ModuleScript in ServerScriptService.Server)
	Loads / saves each player's progress with DataStoreService.

	Save format v2 (see the template below). Older saves convert themselves
	on load: every old Floatie keeps its id and mutation, gets grade C, no
	trait, and a level from its old size (Deflated 1, Puffy 10, Round 25,
	Chonky 50, MEGA 100).

	Session locking: while a server has your save loaded it writes its own
	id into the save. Another server that loads you waits for that lock to
	be released (or to go stale), and a server that finds someone else's
	lock when saving does NOT overwrite it. That is what stops two servers
	both saving the same player (the classic trade duplication trick).

	In Studio: turn on Game Settings > Security > "Enable Studio Access to API Services"
	to test saving. Without it the game still runs, it just won't save.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

-- this server's id in session locks
DataService.SessionId = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))

local LOCK_STALE = 600     -- a lock not refreshed for 10 minutes belongs to a dead server
local LOCK_RETRIES = 6     -- load attempts while someone else holds the lock (then we take it)
local LOCK_WAIT = 4        -- seconds between those attempts

local store = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not ok then
	warn("[DataService] DataStore unavailable, progress will NOT save:", err)
end

---------------------------------------------------------------------
-- The save
---------------------------------------------------------------------
function DataService.template()
	return {
		v = Config.SaveVersion,
		air = Config.StartingAir,
		rebirths = 0,
		totalRolls = 0,
		floaties = {},      -- { uid, id, mut, level, grade, trait, locked, slot } (slot nil = Backpack)
		nextUid = 1,
		pumps = { owned = 1, equipped = 1 }, -- pump tiers are bought in order: owned = best tier owned
		upgrades = { slots = 0, luck = 0, cash = 0, time = 0, walk = 0 },
		items = {
			gradeTokens = 0,
			traitGems = 0,
			jackpotRolls = 0,
			potions = { Luck = 0, Cash = 0, Mutation = 0 },
		},
		activePotions = { Luck = 0, Cash = 0, Mutation = 0 }, -- seconds left (they only tick while you play)
		index = {},         -- ["Pupfloat|Silver"] = true
		indexClaimed = 0,   -- Index milestones claimed
		daily = { day = 0, last = 0 },  -- last Daily Reward day claimed (1..7) and when
		offerLadder = 0,    -- offer ladder steps claimed
		starterPack = false,
		settings = { hide = false, autoSell = 0 }, -- autoSell = sell anything below this rarity order (0 = off)
		gradeTokensBought = 0,
		trades = {},        -- the last 20 trades
		codes = {},         -- [CODE] = true
		receipts = {},      -- last 50 dev product PurchaseIds (prevents double-granting)
		lastOnline = os.time(),
	}
end

-- fill in anything missing (new fields added by an update) without touching what is there
local function reconcile(data, tmpl)
	for k, v in pairs(tmpl) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v) -- a table with named fields (not a list): fill its fields too
		end
	end
	return data
end

-- mutations that were renamed: old id -> new id
local OLD_MUTATIONS = { Glitter = "Silver", Neon = "Gold", Foil = "Emerald" }

-- older save formats -> the current one
function DataService.migrate(data)
	local fromV1 = (data.v or 1) < 2
	if fromV1 then
		for _, f in ipairs(data.floaties or {}) do
			f.level = Config.LevelFromOldStage[f.stage or 1] or 1
			f.grade = "C"
			f.trait = nil
			f.locked = false
			f.stage = nil
			f.growth = nil
		end
		data.stats = nil -- steals / pops / stolenFrom belonged to the stealing game
		data.v = 2
	end
	reconcile(data, DataService.template())
	-- v1.1.0 renamed the mutations (Anime Dice style ladder)
	for _, f in ipairs(data.floaties) do
		f.mut = OLD_MUTATIONS[f.mut] or f.mut
	end
	for key in pairs(table.clone(data.index)) do
		local id, mut = string.match(key, "^(.-)|(.+)$")
		if id and OLD_MUTATIONS[mut] then
			data.index[key] = nil
			data.index[id .. "|" .. OLD_MUTATIONS[mut]] = true
		end
	end
	-- upgrade levels above a (lowered) max come down to that max; removed upgrades go
	for id, level in pairs(data.upgrades) do
		local up = Config.UpgradeById[id]
		data.upgrades[id] = if up then math.clamp(math.floor(tonumber(level) or 0), 0, up.max) else nil
	end
	-- drop Floaties whose id no longer exists, and make every slot and uid unique
	local valid, usedSlots, usedUids = {}, {}, {}
	for _, f in ipairs(data.floaties) do
		if type(f.uid) == "number" then
			data.nextUid = math.max(data.nextUid, f.uid + 1)
		end
	end
	for _, f in ipairs(data.floaties) do
		if Config.FloatieById[f.id] then
			if type(f.uid) ~= "number" or usedUids[f.uid] then
				f.uid = data.nextUid
				data.nextUid += 1
			end
			usedUids[f.uid] = true
			f.mut = if Config.MutationById[f.mut or ""] then f.mut else "Normal"
			f.level = math.clamp(math.floor(tonumber(f.level) or 1), 1, Config.Levels.Max)
			f.grade = if Config.GradeById[f.grade or ""] then f.grade else "C"
			if f.trait and not Config.TraitById[f.trait] then
				f.trait = nil
			end
			if f.slot ~= nil then
				if usedSlots[f.slot] or type(f.slot) ~= "number" then
					f.slot = nil
				else
					usedSlots[f.slot] = true
				end
			end
			table.insert(valid, f)
		end
	end
	data.floaties = valid
	if fromV1 then
		-- every Floatie an old save still has counts as found in the Index
		for _, f in ipairs(valid) do
			data.index[f.id .. "|" .. f.mut] = true
		end
	end
	return data
end

---------------------------------------------------------------------
-- Load / save
---------------------------------------------------------------------
local function lockedByOther(saved)
	local lock = saved and saved.lock
	return lock ~= nil and lock.id ~= DataService.SessionId and os.time() - (lock.t or 0) < LOCK_STALE
end

-- returns data, canSave   (data = nil means "failed, kick the player so we don't overwrite")
function DataService.Load(player)
	if not store then
		return DataService.template(), false
	end
	local key = "p_" .. player.UserId
	for attempt = 1, LOCK_RETRIES do
		local result, status = nil, nil
		local success, problem = pcall(function()
			store:UpdateAsync(key, function(saved)
				if lockedByOther(saved) and attempt < LOCK_RETRIES then
					status = "locked"
					return nil -- leave it alone, try again in a moment
				end
				local data = if saved then DataService.migrate(saved) else DataService.template()
				data.lock = { id = DataService.SessionId, t = os.time() }
				result = data
				status = "ok"
				return data
			end)
		end)
		if success and status == "ok" then
			return result, true
		end
		if not player.Parent then
			return nil, false
		end
		if success then
			-- still in use by another server (they are probably saving right now)
			task.wait(LOCK_WAIT)
		else
			warn(("[DataService] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(problem)))
			if RunService:IsStudio() then
				warn("[DataService] Studio: playing WITHOUT saving (enable Studio Access to API Services to test saves)")
				return DataService.template(), false
			end
			task.wait(attempt * 1.5)
		end
	end
	return nil, false
end

-- release = true on leaving (frees the lock for the next server).
-- Returns false when the save failed or another server owns it now
-- (profile.lostLock is set: that profile must stop saving).
function DataService.Save(player, profile, release)
	if not store or not profile or not profile.canSave or profile.lostLock then
		return false
	end
	local data = profile.data
	data.lastOnline = os.time()
	local key = "p_" .. player.UserId
	for attempt = 1, 3 do
		local lost = false
		local success, problem = pcall(function()
			store:UpdateAsync(key, function(saved)
				if saved and saved.lock and saved.lock.id ~= DataService.SessionId then
					lost = true
					return nil -- someone else loaded this player: never overwrite their save
				end
				data.lock = if release then nil else { id = DataService.SessionId, t = os.time() }
				return data
			end)
		end)
		if success then
			if lost then
				profile.lostLock = true
				warn(("[DataService] %s's save is locked by another server; this server stops saving them"):format(player.Name))
				return false
			end
			return true
		end
		warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(problem)))
		task.wait(attempt)
	end
	return false
end

return DataService
