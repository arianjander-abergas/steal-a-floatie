--[[
	Sync (ModuleScript in ServerScriptService.Server)
	Keeps each player's client copy of their own save up to date, so panels
	(Backpack, Index, Upgrades, ...) can show it. The client never sends any
	of it back: the server's copy is the only one that counts.

	  Sync.full(player)                send everything (after the save loads)
	  Sync.floatie(player, f)          one Floatie was added or changed
	  Sync.removeFloatie(player, uid)  one Floatie is gone
	  Sync.field(player, key)          a top-level save field changed ("items", "pumps", ...)

	Changes are batched and sent 5 times a second through Remotes.Sync as
	{ full = bool, floaties = { ["uid"] = record | false }, fields = { key = value } }.
	Air is not in here: it changes every second, so it is the "Air" player attribute.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Core = require(script.Parent.Core)

local Sync = {}

-- the save fields the client may see (receipts, the session lock and codes stay private)
Sync.FIELDS = {
	"rebirths", "totalRolls", "pumps", "upgrades", "items", "activePotions", "index",
	"indexClaimed", "daily", "offerLadder", "starterPack", "settings", "gradeTokensBought", "trades",
}

local SyncRE = Core.remote("Sync")
local pending = {} -- [player] = { full, floaties, fields }

local function entry(player)
	local p = pending[player]
	if not p then
		p = { full = false, floaties = {}, fields = {} }
		pending[player] = p
	end
	return p
end

-- a plain copy that survives the trip through a RemoteEvent
local function copyFloatie(f)
	return {
		uid = f.uid, id = f.id, mut = f.mut, form = f.form, level = f.level, grade = f.grade,
		trait = f.trait, locked = f.locked == true, slot = f.slot,
	}
end

function Sync.full(player)
	entry(player).full = true
end

function Sync.floatie(player, f)
	entry(player).floaties[tostring(f.uid)] = f
end

function Sync.removeFloatie(player, uid)
	entry(player).floaties[tostring(uid)] = false
end

function Sync.field(player, key)
	entry(player).fields[key] = true
end

local function flush(player, p)
	local prof = Core.getProfile(player)
	if not prof then
		return
	end
	local data = prof.data
	local payload = { full = p.full, floaties = {}, fields = {} }
	if p.full then
		for _, f in ipairs(data.floaties) do
			payload.floaties[tostring(f.uid)] = copyFloatie(f)
		end
		for _, key in ipairs(Sync.FIELDS) do
			payload.fields[key] = data[key]
		end
	else
		for uid, f in pairs(p.floaties) do
			payload.floaties[uid] = if f then copyFloatie(f) else false
		end
		for key in pairs(p.fields) do
			payload.fields[key] = data[key]
		end
	end
	SyncRE:FireClient(player, payload)
end

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.2 then
		return
	end
	accum = 0
	if next(pending) == nil then
		return
	end
	local batch = pending
	pending = {}
	for player, p in pairs(batch) do
		if player.Parent then
			local ok, problem = pcall(flush, player, p)
			if not ok then
				warn("[Sync] " .. tostring(problem))
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

-- the client asks for a full copy when its State module starts
Core.remote("RequestSync").OnServerEvent:Connect(function(player)
	if Core.throttle(player, "requestSync", 2) then
		Sync.full(player)
	end
end)

return Sync
