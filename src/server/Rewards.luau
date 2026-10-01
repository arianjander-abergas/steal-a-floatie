--[[
	Rewards (ModuleScript in ServerScriptService.Server)
	Daily Rewards, Playtime Rewards and promo codes.

	Daily: one claim every 24 h (Config.Daily); more than 48 h since the last
	  claim restarts at Day 1; after Day 7 it starts over at Day 1.
	Playtime: 12 tiles that unlock during one play session (minutes since you
	  joined); claimed tiles are remembered for the session only. The player
	  attributes JoinedAt (server time), PlaytimeClaimed ("1,2,5") and
	  PlaytimeSkipped let the panel draw the timers.

	Remotes: ClaimDaily (fn), ClaimPlaytime (fn, tile), RedeemCode (fn, code)
	Rewards.skipPlaytime(player)  the Skip All product
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Core = require(script.Parent.Core)
local Grant = require(script.Parent.Grant)
local Sync = require(script.Parent.Sync)

local Rewards = {}

---------------------------------------------------------------------
-- Daily
---------------------------------------------------------------------
-- the day you would claim next (1..7), and whether you can claim it now
function Rewards.dailyState(data)
	local d = data.daily
	local since = os.time() - (d.last or 0)
	local nextDay = if d.day == 0 or since > Config.Daily.StreakReset then 1 else (d.day % #Config.Daily.Days) + 1
	local ready = d.last == 0 or since >= Config.Daily.Cooldown
	return nextDay, ready, math.max(0, Config.Daily.Cooldown - since)
end

function Rewards.claimDaily(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false, "Try again"
	end
	local data = prof.data
	local day, ready, wait = Rewards.dailyState(data)
	if not ready then
		return false, "Come back in " .. Config.FormatTime(wait)
	end
	data.daily.day = day
	data.daily.last = os.time()
	Sync.field(player, "daily")
	local given = Grant.give(player, Config.Daily.Days[day])
	Core.notify(player, "📅 Day " .. day .. ": " .. table.concat(given, " + "), "success")
	return true, given
end

---------------------------------------------------------------------
-- Playtime
---------------------------------------------------------------------
local function publishPlaytime(player, prof)
	local claimed = {}
	for i in pairs(prof.playtimeClaimed) do
		table.insert(claimed, i)
	end
	table.sort(claimed)
	player:SetAttribute("PlaytimeClaimed", table.concat(claimed, ","))
	player:SetAttribute("PlaytimeSkipped", prof.playtimeSkipped == true)
end

function Rewards.startSession(player, prof)
	prof.joinedAt = Core.now()
	prof.playtimeClaimed = {}
	prof.playtimeSkipped = false
	player:SetAttribute("JoinedAt", prof.joinedAt)
	publishPlaytime(player, prof)
end

function Rewards.claimPlaytime(player, tile)
	local prof = Core.getProfile(player)
	local entry = type(tile) == "number" and Config.Playtime[tile]
	if not prof or not entry or not prof.joinedAt then
		return false, "Try again"
	end
	if prof.playtimeClaimed[tile] then
		return false, "Already claimed"
	end
	local minutes = (Core.now() - prof.joinedAt) / 60
	if minutes < entry.minutes and not prof.playtimeSkipped then
		return false, "Unlocks in " .. Config.FormatTime((entry.minutes - minutes) * 60)
	end
	prof.playtimeClaimed[tile] = true
	publishPlaytime(player, prof)
	local given = Grant.give(player, entry.reward)
	Core.notify(player, "⏰ Playtime reward: " .. table.concat(given, " + "), "success")
	return true, given
end

function Rewards.skipPlaytime(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false
	end
	prof.playtimeSkipped = true
	publishPlaytime(player, prof)
	return true
end

---------------------------------------------------------------------
-- Codes
---------------------------------------------------------------------
function Rewards.redeem(player, code)
	local prof = Core.getProfile(player)
	if not prof or typeof(code) ~= "string" or #code > 30 then
		return false, "Try again"
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		return false, "Invalid code"
	end
	if prof.data.codes[code] then
		return false, "Already redeemed"
	end
	prof.data.codes[code] = true
	local given = Grant.give(player, reward)
	return true, "Code redeemed! " .. table.concat(given, " + ") .. " 🎉"
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
Core.remote("ClaimDaily", "RemoteFunction").OnServerInvoke = function(player)
	if not Core.throttle(player, "daily", 1) then
		return false, "Slow down!"
	end
	return Rewards.claimDaily(player)
end

Core.remote("ClaimPlaytime", "RemoteFunction").OnServerInvoke = function(player, tile)
	if not Core.throttle(player, "playtime", 0.3) then
		return false, "Slow down!"
	end
	return Rewards.claimPlaytime(player, tile)
end

Core.remote("RedeemCode", "RemoteFunction").OnServerInvoke = function(player, code)
	if not Core.throttle(player, "code", 1) then
		return false, "Slow down!"
	end
	return Rewards.redeem(player, code)
end

Core.PlayerLoaded:Connect(function(player, prof)
	Rewards.startSession(player, prof)
end)

return Rewards
