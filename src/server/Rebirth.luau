--[[
	Rebirth (ModuleScript in ServerScriptService.Server)
	Rebirth costs ALL your Air (you need at least the cost). Floaties (with
	their levels, grades, traits and mutations), pumps and upgrades stay.
	Each rebirth: +50% Cash, +25% Luck, +2 slots (up to +6), 5 Grade Tokens
	(numbers in Config.Rebirth).

	Remote: Rebirth (RemoteFunction) -> ok, message
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Bases = require(script.Parent.Bases)
local Sync = require(script.Parent.Sync)

local Rebirth = {}

function Rebirth.rebirth(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false, "Try again"
	end
	local data = prof.data
	local cost = Formulas.rebirthCost(data.rebirths)
	if data.air < cost then
		return false, "You need " .. Config.Format(cost) .. " Air to rebirth."
	end
	data.rebirths += 1
	data.air = 0
	data.items.gradeTokens += Config.Rebirth.GradeTokens
	player:SetAttribute("Air", 0) -- the HUD drops at once
	Sync.field(player, "rebirths")
	Sync.field(player, "items")
	Bases.refresh(player) -- new slots may have opened
	Core.StatsChanged:Fire(player)
	Core.FloatiesChanged:Fire(player)
	Core.notifyAll("🌟 " .. player.DisplayName .. " reached Rebirth " .. data.rebirths .. "!", "event")
	return true, "Rebirth " .. data.rebirths .. "! +" .. Config.Rebirth.GradeTokens .. " Grade Tokens"
end

Core.remote("Rebirth", "RemoteFunction").OnServerInvoke = function(player)
	if not Core.throttle(player, "rebirth", 1) then
		return false, "Slow down!"
	end
	return Rebirth.rebirth(player)
end

return Rebirth
