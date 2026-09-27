--[[
	DataService (ModuleScript in ServerScriptService.Server)
	Loads / saves each player's progress with DataStoreService.

	In Studio: turn on Game Settings > Security > "Enable Studio Access to API Services"
	to test saving. Without it the game still runs, it just won't save.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

local store = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not ok then
	warn("[DataService] DataStore unavailable, progress will NOT save:", err)
end

local function template()
	return {
		v = 1,
		air = Config.StartingAir,
		rebirths = 0,
		floaties = {},      -- { uid, id, mut, stage, growth, slot }
		nextUid = 1,
		lastOnline = os.time(),
		codes = {},         -- [CODE] = true
		receipts = {},      -- last 50 dev product PurchaseIds (prevents double-granting)
		stats = { steals = 0, pops = 0, stolenFrom = 0 },
	}
end

local function reconcile(data, tmpl)
	for k, v in pairs(tmpl) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and k == "stats" then
			reconcile(data[k], v)
		end
	end
	return data
end

-- returns data, canSave   (data = nil means "failed, kick the player so we don't overwrite")
function DataService.Load(player)
	if not store then
		return template(), false
	end
	local key = "p_" .. player.UserId
	for attempt = 1, 4 do
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)
		if success then
			if result == nil then
				return template(), true
			end
			return reconcile(result, template()), true
		end
		warn(("[DataService] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		if RunService:IsStudio() then
			warn("[DataService] Studio: playing WITHOUT saving (enable Studio Access to API Services to test saves)")
			return template(), false
		end
		task.wait(attempt * 1.5)
	end
	return nil, false
end

function DataService.Save(player, profile)
	if not store or not profile or not profile.canSave then
		return false
	end
	profile.data.lastOnline = os.time()
	local key = "p_" .. player.UserId
	for attempt = 1, 3 do
		local success, result = pcall(function()
			store:UpdateAsync(key, function()
				return profile.data
			end)
		end)
		if success then
			return true
		end
		warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end
	return false
end

return DataService
