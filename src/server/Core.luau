--[[
	Core (ModuleScript in ServerScriptService.Server)
	The shared server state and helpers every gameplay module uses, so the
	modules never have to require each other just to talk:

	  Core.profiles[player]   { data, canSave, base, passes, loaded, ... } (see GameServer)
	  Core.getProfile(player) the profile once the save has loaded, else nil
	  Core.remote(name, kind) a RemoteEvent / RemoteFunction in ReplicatedStorage.Remotes
	  Core.notify(...)        toasts (Remotes.Notify)
	  Core.chatAll(text, r)   a line in everyone's chat window (Remotes.ChatMessage)
	  Core.signal()           a tiny event: :Connect(fn), :Fire(...)
	  Core.hasPass(player, n) owns the game pass (Config.GamePasses key)
	  Core.rng                the server's Random

	Signals other modules listen to:
	  Core.FloatiesChanged(player)        a Floatie was added / removed / changed
	  Core.StatsChanged(player)           something that changes Luck / Cash / slots happened
	  Core.PlayerLoaded(player, profile)  the save is loaded and the base assigned
	  Core.PlayerLeaving(player, profile) right before the final save
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Core = {}

Core.profiles = {}
Core.rng = Random.new()

---------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal:Connect(fn)
	table.insert(self._fns, fn)
	return {
		Disconnect = function()
			local i = table.find(self._fns, fn)
			if i then
				table.remove(self._fns, i)
			end
		end,
	}
end

-- every listener runs in its own thread, so one broken listener never stops the others
function Signal:Fire(...)
	for _, fn in ipairs(table.clone(self._fns)) do
		task.spawn(fn, ...)
	end
end

function Core.signal()
	return setmetatable({ _fns = {} }, Signal)
end

Core.FloatiesChanged = Core.signal()
Core.StatsChanged = Core.signal()
Core.PlayerLoaded = Core.signal()
Core.PlayerLeaving = Core.signal()

---------------------------------------------------------------------
-- Remotes (all in ReplicatedStorage.Remotes)
---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

-- Core.remote("Roll") -> RemoteEvent, Core.remote("Sell", "RemoteFunction") -> RemoteFunction
function Core.remote(name, className)
	className = className or "RemoteEvent"
	local existing = remotes:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local NotifyRE = Core.remote("Notify")

-- kind = "info" | "success" | "error" | "alert" | "event"
function Core.notify(player, text, kind)
	NotifyRE:FireClient(player, text, kind or "info")
end

function Core.notifyAll(text, kind)
	NotifyRE:FireAllClients(text, kind or "info")
end

local ChatRE = Core.remote("ChatMessage")

-- a line in everyone's chat window (nothing on screen); rarity (optional)
-- colors it like that rarity
function Core.chatAll(text, rarity)
	ChatRE:FireAllClients(text, rarity)
end

---------------------------------------------------------------------
-- Players
---------------------------------------------------------------------
function Core.getProfile(player)
	local prof = Core.profiles[player]
	if prof and prof.loaded then
		return prof
	end
	return nil
end

function Core.hasPass(player, name)
	local prof = Core.profiles[player]
	return prof ~= nil and prof.passes[name] == true
end

function Core.now()
	return workspace:GetServerTimeNow()
end

-- Studio, the place owner, or Config.AdminUserIds
function Core.isAdmin(player)
	if RunService:IsStudio() or table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

-- a per-player rate limit: returns true when the action may run now
function Core.throttle(player, key, seconds)
	local prof = Core.profiles[player]
	if not prof then
		return false
	end
	prof.throttle = prof.throttle or {}
	local clock = os.clock()
	if (prof.throttle[key] or 0) > clock then
		return false
	end
	prof.throttle[key] = clock + seconds
	return true
end

-- every loaded player
function Core.eachLoaded()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = Core.getProfile(p)
		if prof then
			table.insert(list, { p, prof })
		end
	end
	local i = 0
	return function()
		i += 1
		local entry = list[i]
		if entry then
			return entry[1], entry[2]
		end
		return nil
	end
end

return Core
