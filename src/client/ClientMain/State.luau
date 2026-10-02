--[[
	Floatie Farm — State (ModuleScript child of the ClientMain LocalScript)
	This client's copy of its own save, kept up to date by the server
	(Remotes.Sync, see ServerScriptService.Server.Sync). Read-only: every
	change goes through a remote and the server sends the new state back.

	API:
	  State.start()                  -- listens to Remotes.Sync
	  State.floaties                 -- [uid] = { uid, id, mut, level, grade, trait, locked, slot }
	  State.data                     -- the other synced fields: items, pumps, upgrades, index, daily, ...
	  State.get(uid) -> record | nil
	  State.list() -> { record, ... }   every Floatie (a new table each call)
	  State.changed:Connect(fn(what))   what = "floaties" | a field name | "full"
	  State.ready() -> bool             true once the first full copy arrived
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {}

State.floaties = {}
State.data = {}

local changedEvent = Instance.new("BindableEvent")
State.changed = changedEvent.Event

local isReady = false
local started = false

function State.ready()
	return isReady
end

function State.get(uid)
	return State.floaties[uid]
end

function State.list()
	local list = {}
	for _, f in pairs(State.floaties) do
		table.insert(list, f)
	end
	return list
end

local function apply(payload)
	if payload.full then
		State.floaties = {}
		State.data = {}
	end
	local floatiesChanged = false
	for key, f in pairs(payload.floaties or {}) do
		local uid = tonumber(key)
		if uid then
			State.floaties[uid] = if f then f else nil
			floatiesChanged = true
		end
	end
	local fields = {}
	for key, value in pairs(payload.fields or {}) do
		State.data[key] = value
		table.insert(fields, key)
	end
	if payload.full then
		isReady = true
		changedEvent:Fire("full")
		return
	end
	if floatiesChanged then
		changedEvent:Fire("floaties")
	end
	for _, key in ipairs(fields) do
		changedEvent:Fire(key)
	end
end

function State.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Sync").OnClientEvent:Connect(function(payload)
		local ok, problem = pcall(apply, payload)
		if not ok then
			warn("[State] " .. tostring(problem))
		end
	end)
	-- ask for a full copy in case the first one went out before we listened
	remotes:WaitForChild("RequestSync"):FireServer()
end

return State
