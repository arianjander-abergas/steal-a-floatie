--[[
	Potions (ModuleScript in ServerScriptService.Server)
	Drinking a potion from the Backpack's Items tab. Each kind (Luck, Cash,
	Mutation; Config.Potions) runs on its own timer; drinking another of the
	same kind adds its time instead of making it stronger. Timers only tick
	while you play (Economy's 1-second loop) and show on the HUD through the
	PotionEnds_<kind> player attributes.

	Remote: UsePotion (fn, kind) -> ok, msg
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Core = require(script.Parent.Core)
local Sync = require(script.Parent.Sync)

local Potions = {}

local MAX_STACK = 6 * 3600 -- at most 6 hours of one potion queued up

function Potions.use(player, kind)
	local prof = Core.getProfile(player)
	local info = type(kind) == "string" and Config.Potions[kind]
	if not prof or not info then
		return false, "Try again"
	end
	local items = prof.data.items
	if (items.potions[kind] or 0) < 1 then
		return false, "You have no " .. info.name .. "s"
	end
	local left = prof.data.activePotions[kind] or 0
	if left + info.duration > MAX_STACK then
		return false, "That's plenty of " .. info.name .. " for now!"
	end
	items.potions[kind] -= 1
	prof.data.activePotions[kind] = left + info.duration
	Sync.field(player, "items")
	Sync.field(player, "activePotions")
	Core.StatsChanged:Fire(player)
	local total = prof.data.activePotions[kind]
	return true, ("%s %s active: %s for %s"):format(info.icon, info.name, info.desc, Config.FormatTime(total))
end

Core.remote("UsePotion", "RemoteFunction").OnServerInvoke = function(player, kind)
	if not Core.throttle(player, "potion", 0.3) then
		return false, "Slow down!"
	end
	return Potions.use(player, kind)
end

return Potions
