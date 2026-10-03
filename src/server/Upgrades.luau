--[[
	Upgrades (ModuleScript in ServerScriptService.Server)
	The Upgrades window and the Pump Shop.

	Upgrades (Config.Upgrades): each level costs Air (costBase x costGrowth^level)
	or one Robux developer product (Config.UpgradeProducts[id]).
	  slots     more slots on your base       luck     +5% Luck
	  cash      +10% Air                      time     -4% inflate time
	  walk      +1 walk speed

	Pumps (Config.Pumps): bought with Air in order (you need the one before),
	owned forever; equip any pump you own.

	Remotes: BuyUpgrade (fn, id) -> ok, msg   BuyPump (fn, tier) -> ok, msg   EquipPump (event, tier)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)
local Bases = require(script.Parent.Bases)
local Floaties = require(script.Parent.Floaties)
local Shop = require(script.Parent.Shop)
local Sync = require(script.Parent.Sync)

local Upgrades = {}

---------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------
local function applyLevel(player, id)
	local prof = Core.getProfile(player)
	local up = Config.UpgradeById[id]
	if not prof or not up then
		return false
	end
	local level = prof.data.upgrades[id] or 0
	if level >= up.max then
		return false
	end
	prof.data.upgrades[id] = level + 1
	Sync.field(player, "upgrades")
	if id == "slots" then
		Bases.paintPads(player) -- the new pad turns on...
		-- ...and your best Floatie waiting in the Backpack hops onto it
		local best, bestIncome = nil, -1
		for _, f in ipairs(prof.data.floaties) do
			local income = Formulas.baseIncome(f)
			if not f.slot and income > bestIncome then
				best, bestIncome = f, income
			end
		end
		if best then
			Floaties.equip(player, best.uid)
		end
	end
	Core.StatsChanged:Fire(player)
	Core.FloatiesChanged:Fire(player)
	return true
end

function Upgrades.buy(player, id)
	local prof = Core.getProfile(player)
	local up = Config.UpgradeById[id]
	if not prof or not up then
		return false, "Try again"
	end
	local level = prof.data.upgrades[id] or 0
	local cost = Formulas.upgradeCost(id, level)
	if not cost then
		return false, up.name .. " is maxed!"
	end
	if not Economy.spend(player, cost) then
		return false, "Not enough Air! You need " .. Config.Format(cost) .. "."
	end
	applyLevel(player, id)
	return true, up.name .. " " .. (level + 1) .. "/" .. up.max .. "!"
end

-- one level for Robux (developer products "Upgrade_<id>")
for _, up in ipairs(Config.Upgrades) do
	Shop.handle("Upgrade_" .. up.id, function(player)
		local ok = applyLevel(player, up.id)
		if ok then
			Core.notify(player, "⬆️ " .. up.name .. " upgraded! 💖", "success")
		else
			-- already maxed: give the Air the level would have cost instead, so the purchase isn't wasted
			Economy.addAir(player, Formulas.upgradeCost(up.id, up.max - 1) or 0)
			Core.notify(player, up.name .. " was maxed, so you got its Air price instead 💖", "success")
		end
		return true
	end)
end

---------------------------------------------------------------------
-- Pumps
---------------------------------------------------------------------
function Upgrades.buyPump(player, tier)
	local prof = Core.getProfile(player)
	local info = type(tier) == "number" and Config.Pumps[tier]
	if not prof or not info then
		return false, "Try again"
	end
	local pumps = prof.data.pumps
	if tier <= pumps.owned then
		return false, "You already own the " .. info.name
	end
	if tier > pumps.owned + 1 then
		return false, "Buy the " .. Config.Pumps[pumps.owned + 1].name .. " first"
	end
	if not Economy.spend(player, info.price) then
		return false, "Not enough Air! You need " .. Config.Format(info.price) .. "."
	end
	pumps.owned = tier
	pumps.equipped = tier -- new pumps are always better: wear it right away
	Sync.field(player, "pumps")
	Core.StatsChanged:Fire(player)
	Core.notify(player, "🎈 You got the " .. info.name .. "! Luck x" .. Config.Format(info.luck), "success")
	return true, info.name .. " equipped!"
end

function Upgrades.equipPump(player, tier)
	local prof = Core.getProfile(player)
	if not prof or type(tier) ~= "number" or tier < 1 or tier > prof.data.pumps.owned then
		return
	end
	prof.data.pumps.equipped = math.floor(tier)
	Sync.field(player, "pumps")
	Core.StatsChanged:Fire(player)
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
Core.remote("BuyUpgrade", "RemoteFunction").OnServerInvoke = function(player, id)
	if not Core.throttle(player, "upgrade", 0.08) then
		return false, "Slow down!"
	end
	return Upgrades.buy(player, id)
end

Core.remote("BuyPump", "RemoteFunction").OnServerInvoke = function(player, tier)
	if not Core.throttle(player, "pump", 0.2) then
		return false, "Slow down!"
	end
	return Upgrades.buyPump(player, tier)
end

Core.remote("EquipPump").OnServerEvent:Connect(function(player, tier)
	if Core.throttle(player, "equipPump", 0.2) then
		Upgrades.equipPump(player, tier)
	end
end)

return Upgrades
