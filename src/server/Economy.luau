--[[
	Economy (ModuleScript in ServerScriptService.Server)
	Every multiplier in one place, computed from the save, passes, potions,
	the running event, traits on your slots and friends in the server:

	  Luck  = pump x Luck upgrade x rebirths x Luck potion x 4x Luck pass x event x Index x Lucky traits
	  Cash  = Cash upgrade x rebirths x 2x Cash pass x VIP x Cash potion x event x Friend Boost
	  Air/s of a Floatie = Formulas.baseIncome(f) x Cash   (only while it sits on a slot)

	It also publishes the numbers the HUD shows as player attributes
	(Air, IncomePerSec, LuckMultiplier, CashMultiplier, BoostPercent,
	FriendBoost, InflateTime, SlotCount, BackpackSize, PotionEnds_<kind>, ...)
	and runs the once-a-second income + potion timer loop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Sync = require(script.Parent.Sync)

local Economy = {}

---------------------------------------------------------------------
-- Events (the Events module starts them; anyone can read them here)
---------------------------------------------------------------------
-- returns (event config, name) while an event runs, else nil
function Economy.activeEvent()
	local name = ReplicatedStorage:GetAttribute("Event")
	if name and name ~= "" and (ReplicatedStorage:GetAttribute("EventEndsAt") or 0) > Core.now() then
		return Config.Events[name], name
	end
	return nil, nil
end

---------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------
function Economy.potionActive(prof, kind)
	return (prof.data.activePotions[kind] or 0) > 0
end

function Economy.slotCount(player)
	local prof = Core.profiles[player]
	if not prof then
		return 0
	end
	return Formulas.slotCount(prof.data, Core.hasPass(player, "ExtraSlots"))
end

function Economy.backpackSize(player)
	return if Core.hasPass(player, "BigBackpack") then Config.Rolling.BigBackpackSize else Config.Rolling.BackpackSize
end

-- is this Floatie on a slot right now (counted for income, Lucky, Breezy)?
function Economy.isPlaced(player, f)
	local prof = Core.profiles[player]
	if not prof or not f.slot or f.slot > Economy.slotCount(player) then
		return false
	end
	return not (prof.arriving and prof.arriving[f.uid])
end

-- sum of a trait's bonus over your placed Floaties, capped
local function traitBonus(player, field, capField)
	local prof = Core.profiles[player]
	local total, cap = 0, 0
	for _, f in ipairs(prof.data.floaties) do
		local trait = f.trait and Config.TraitById[f.trait]
		if trait and trait[field] and Economy.isPlaced(player, f) then
			total += trait[field]
			cap = trait[capField]
		end
	end
	return math.min(total, cap)
end

---------------------------------------------------------------------
-- The multipliers
---------------------------------------------------------------------
-- your Luck (Secret Skies and Mutation boosts are applied per copy in Rolling.pickCopy)
function Economy.luck(player)
	local prof = Core.profiles[player]
	if not prof then
		return 1
	end
	local data = prof.data
	local pump = Config.Pumps[data.pumps.equipped] or Config.Pumps[1]
	local luck = pump.luck
	luck *= 1 + data.upgrades.luck * Config.UpgradeById.luck.per
	luck *= 1 + data.rebirths * Config.Rebirth.LuckBonus
	luck *= 1 + (data.indexClaimed or 0) * Config.IndexLuckPerMilestone
	luck *= 1 + traitBonus(player, "luckBonus", "luckCap")
	if Economy.potionActive(prof, "Luck") then
		luck *= Config.Potions.Luck.mult
	end
	if Core.hasPass(player, "QuadLuck") then
		luck *= 4
	end
	local ev = Economy.activeEvent()
	if ev and ev.luckMult then
		luck *= ev.luckMult
	end
	return luck
end

function Economy.friendBoost(player)
	local prof = Core.profiles[player]
	local fb = Config.FriendBoost
	return math.min((prof and prof.friends or 0) * fb.each, fb.max)
end

function Economy.cash(player)
	local prof = Core.profiles[player]
	if not prof then
		return 1
	end
	local data = prof.data
	local cash = 1 + data.upgrades.cash * Config.UpgradeById.cash.per
	cash *= 1 + data.rebirths * Config.Rebirth.CashBonus
	if Core.hasPass(player, "DoubleCash") then
		cash *= 2
	end
	if Core.hasPass(player, "VIP") then
		cash *= Config.VipCash
	end
	if Economy.potionActive(prof, "Cash") then
		cash *= Config.Potions.Cash.mult
	end
	local ev = Economy.activeEvent()
	if ev and ev.incomeMult then
		cash *= ev.incomeMult
	end
	cash *= 1 + Economy.friendBoost(player)
	return cash
end

-- Mutation potions x Helium Rain: mutated copies count as this many times
-- less rare when your pull is picked (Rolling.pickCopy)
function Economy.mutationMult(player)
	local prof = Core.profiles[player]
	if not prof then
		return 1
	end
	local m = 1
	if Economy.potionActive(prof, "Mutation") then
		m *= Config.Potions.Mutation.mult
	end
	local ev = Economy.activeEvent()
	if ev and ev.mutationMult then
		m *= ev.mutationMult
	end
	return m
end

-- seconds between rolls (the pump inflating)
function Economy.inflateTime(player)
	local prof = Core.profiles[player]
	local R = Config.Rolling
	if not prof then
		return R.InflateTime
	end
	if (prof.data.totalRolls or 0) < R.StarterRolls then
		return R.StarterInflateTime
	end
	local t = R.InflateTime
	t *= 1 - prof.data.upgrades.time * Config.UpgradeById.time.per
	t *= 1 - traitBonus(player, "inflateCut", "inflateCap")
	if Core.hasPass(player, "FastRoll") then
		t *= 1 - R.FastRollCut
	end
	return math.max(R.MinInflateTime, t)
end

function Economy.walkSpeed(player)
	local prof = Core.profiles[player]
	if not prof then
		return Config.BaseWalkSpeed
	end
	return Config.BaseWalkSpeed + prof.data.upgrades.walk * Config.UpgradeById.walk.per
end

-- one Floatie's Air per second with your Cash (0 when not on a slot)
function Economy.floatieIncome(player, f, cash)
	if not Economy.isPlaced(player, f) then
		return 0
	end
	return Formulas.baseIncome(f) * (cash or Economy.cash(player))
end

function Economy.incomePerSec(player)
	local prof = Core.profiles[player]
	if not prof then
		return 0
	end
	local cash = Economy.cash(player)
	local total = 0
	for _, f in ipairs(prof.data.floaties) do
		total += Economy.floatieIncome(player, f, cash)
	end
	return total
end

---------------------------------------------------------------------
-- Air
---------------------------------------------------------------------
function Economy.addAir(player, amount)
	local prof = Core.profiles[player]
	if not prof or amount ~= amount then
		return
	end
	prof.data.air = math.max(0, prof.data.air + amount)
	player:SetAttribute("Air", prof.data.air)
end

-- spends if you can afford it; returns true when it did
function Economy.spend(player, amount)
	local prof = Core.getProfile(player)
	if not prof or amount ~= amount or amount < 0 or prof.data.air < amount then
		return false
	end
	prof.data.air -= amount
	player:SetAttribute("Air", prof.data.air) -- now, so the HUD drops at once (not at the next 1 s tick)
	return true
end

---------------------------------------------------------------------
-- What the HUD reads
---------------------------------------------------------------------
-- income = the already computed Air/s (the 1-second loop passes it)
function Economy.publish(player, income)
	local prof = Core.getProfile(player)
	if not prof then
		return
	end
	local data = prof.data
	local cash = Economy.cash(player)
	income = income or Economy.incomePerSec(player)
	prof.incomePerSec = income
	player:SetAttribute("Air", data.air)
	player:SetAttribute("IncomePerSec", income)
	player:SetAttribute("CashMultiplier", cash)
	player:SetAttribute("LuckMultiplier", Economy.luck(player))
	player:SetAttribute("BoostPercent", math.floor((cash - 1) * 100 + 0.5))
	player:SetAttribute("FriendBoost", math.floor(Economy.friendBoost(player) * 100 + 0.5))
	player:SetAttribute("InflateTime", Economy.inflateTime(player))
	player:SetAttribute("SlotCount", Economy.slotCount(player))
	player:SetAttribute("BackpackSize", Economy.backpackSize(player))
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("TotalRolls", data.totalRolls)
	local pump = Config.Pumps[data.pumps.equipped] or Config.Pumps[1]
	player:SetAttribute("PumpName", pump.name)
	player:SetAttribute("PumpLuck", pump.luck)
	-- potion end times (server clock); only re-sent when they really move,
	-- since "now + seconds left" stays the same while a potion ticks
	local now = Core.now()
	for kind in pairs(Config.Potions) do
		local left = data.activePotions[kind] or 0
		local endsAt = if left > 0 then now + left else 0
		local shown = player:GetAttribute("PotionEnds_" .. kind) or 0
		if (endsAt == 0) ~= (shown == 0) or math.abs(endsAt - shown) > 1.5 then
			player:SetAttribute("PotionEnds_" .. kind, endsAt)
		end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Economy.walkSpeed(player)
	end
	if prof.stats then
		prof.stats.air.Value = Config.Format(data.air)
		prof.stats.rolls.Value = data.totalRolls
		prof.stats.rebirths.Value = data.rebirths
	end
end

Core.StatsChanged:Connect(function(player)
	if player.Parent then
		Economy.publish(player)
	end
end)
Core.FloatiesChanged:Connect(function(player)
	if player.Parent then
		Economy.publish(player) -- placed Floaties change income, Lucky and Breezy
	end
end)

---------------------------------------------------------------------
-- Friend Boost: +10% per friend in the server (up to +40%)
---------------------------------------------------------------------
local friendCache = {} -- ["a:b"] = true / false

local function areFriends(a, b)
	local key = if a.UserId < b.UserId then a.UserId .. ":" .. b.UserId else b.UserId .. ":" .. a.UserId
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

function Economy.refreshFriends()
	local list = Players:GetPlayers()
	for _, p in ipairs(list) do
		local prof = Core.profiles[p]
		if prof then
			local n = 0
			for _, other in ipairs(list) do
				if other ~= p and areFriends(p, other) then
					n += 1
				end
			end
			if prof.friends ~= n then
				prof.friends = n
				Core.StatsChanged:Fire(p)
			end
		end
	end
end

Players.PlayerAdded:Connect(function()
	task.delay(2, Economy.refreshFriends)
end)
Players.PlayerRemoving:Connect(function()
	task.defer(Economy.refreshFriends)
end)

---------------------------------------------------------------------
-- The 1-second loop: income, potion timers, HUD numbers
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for player, prof in Core.eachLoaded() do
			local data = prof.data
			-- potions only tick while you play
			local ranOut = false
			for kind, left in pairs(data.activePotions) do
				if left > 0 then
					data.activePotions[kind] = math.max(0, left - 1)
					if data.activePotions[kind] == 0 then
						ranOut = true
						Core.notify(player, Config.Potions[kind].name .. " ran out", "info")
					end
				end
			end
			if ranOut then
				Sync.field(player, "activePotions")
			end
			local income = Economy.incomePerSec(player)
			data.air += income
			Economy.publish(player, income)
		end
	end
end)

return Economy
