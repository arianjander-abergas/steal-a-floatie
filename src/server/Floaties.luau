--[[
	Floaties (ModuleScript in ServerScriptService.Server)
	Everything that adds, moves, changes or removes a player's Floaties.
	The client only asks (Remotes below); every rule is checked here.

	  Floaties.add(player, spec, opts) -> f | nil, dest, soldFor
	      spec = { id, mut?, form?, level?, grade?, trait? }   (form = "Huge" / "Titanic")
	      dest = "slot" | "backpack" | "sold" (no room anywhere, or the copy's own rarity
	             is below your Auto Sell rarity)
	      opts.arriving = true: reserve the slot but let Rolling place the model when the
	                      conveyor ride ends;  opts.noAutoSell = true: never auto-sell it;
	      opts.force = true: never sold, even with a full Backpack (trades check room first)
	  Floaties.find(player, uid) -> f, index
	  Floaties.remove(player, uid)
	  Floaties.discover(player, id, mut, form) marks an Index entry
	  Floaties.indexKey(id, mut, form)         "Pupfloat|Ruby" / "Pupfloat|Ruby|Huge"

	Remotes: Equip, Unequip, EquipBest, SetLocked, LevelUp (fn), SellFloaties (fn)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)
local Bases = require(script.Parent.Bases)
local Sync = require(script.Parent.Sync)

local Floaties = {}

-- fired with (player, id, mut, form) the first time an Index entry is found
Floaties.Discovered = Core.signal()

---------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------
function Floaties.find(player, uid)
	local prof = Core.profiles[player]
	if not prof or type(uid) ~= "number" then
		return nil, nil
	end
	for i, f in ipairs(prof.data.floaties) do
		if f.uid == uid then
			return f, i
		end
	end
	return nil, nil
end

function Floaties.backpackCount(player)
	local prof = Core.profiles[player]
	local n = 0
	for _, f in ipairs(prof.data.floaties) do
		if not f.slot then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------
-- Index
---------------------------------------------------------------------
Floaties.indexKey = Formulas.indexKey

function Floaties.discover(player, id, mut, form)
	local prof = Core.profiles[player]
	local key = Floaties.indexKey(id, mut, form)
	if prof and not prof.data.index[key] then
		prof.data.index[key] = true
		Sync.field(player, "index")
		Floaties.Discovered:Fire(player, id, mut or "Normal", form or "Normal")
	end
end

---------------------------------------------------------------------
-- Adding / removing
---------------------------------------------------------------------
function Floaties.add(player, spec, opts)
	opts = opts or {}
	local prof = Core.profiles[player]
	local def = spec and Config.FloatieById[spec.id]
	if not prof or not def then
		return nil, nil, 0
	end
	local f = {
		uid = prof.data.nextUid,
		id = def.id,
		mut = if Config.MutationById[spec.mut or ""] then spec.mut else "Normal",
		form = if spec.form ~= "Normal" and Config.FormById[spec.form or ""] then spec.form else nil,
		level = math.clamp(spec.level or 1, 1, Config.Levels.Max),
		grade = if Config.GradeById[spec.grade or ""] then spec.grade else "C",
		trait = if spec.trait and Config.TraitById[spec.trait] then spec.trait else nil,
		locked = false,
		slot = nil,
	}
	Floaties.discover(player, f.id, f.mut, f.form) -- counts for the Index even if it is sold right away

	-- Auto Sell: anything below the chosen rarity (the copy's own rarity) turns into Air at once
	local autoSell = prof.data.settings.autoSell or 0
	local rarityOrder = Config.Rarities[Formulas.rarityOf(f)].order
	local sell = not opts.noAutoSell and not opts.force and autoSell > 0 and rarityOrder < autoSell
	if not sell then
		local slot = Bases.freeSlot(player)
		if slot then
			f.slot = slot
		elseif not opts.force and Floaties.backpackCount(player) >= Economy.backpackSize(player) then
			sell = true -- Backpack full
		end
	end
	if sell then
		local value = Formulas.sellValue(f)
		Economy.addAir(player, value)
		return nil, "sold", value
	end

	prof.data.nextUid += 1
	table.insert(prof.data.floaties, f)
	if f.slot and opts.arriving then
		prof.arriving = prof.arriving or {}
		prof.arriving[f.uid] = true
	elseif f.slot then
		Bases.place(player, f)
	end
	Sync.floatie(player, f)
	Core.FloatiesChanged:Fire(player)
	return f, if f.slot then "slot" else "backpack", 0
end

function Floaties.remove(player, uid)
	local prof = Core.profiles[player]
	local f, i = Floaties.find(player, uid)
	if not f then
		return nil
	end
	table.remove(prof.data.floaties, i)
	if prof.arriving then
		prof.arriving[uid] = nil
	end
	Bases.unplace(player, uid)
	Sync.removeFloatie(player, uid)
	Core.FloatiesChanged:Fire(player)
	return f
end

-- a riding Floatie reached its slot (or it was cancelled): put its model down
function Floaties.arrive(player, uid)
	local prof = Core.profiles[player]
	if not prof or not prof.arriving or not prof.arriving[uid] then
		return
	end
	prof.arriving[uid] = nil
	local f = Floaties.find(player, uid)
	if f then
		Bases.place(player, f)
		Core.FloatiesChanged:Fire(player)
	end
end

---------------------------------------------------------------------
-- Equip / unequip / Equip Best / lock
---------------------------------------------------------------------
function Floaties.equip(player, uid)
	local f = Floaties.find(player, uid)
	if not f or f.slot then
		return false, "Already on your base"
	end
	local slot = Bases.freeSlot(player)
	if not slot then
		return false, "No free slot! Unequip one or buy More Slots."
	end
	f.slot = slot
	Bases.place(player, f)
	Sync.floatie(player, f)
	Core.FloatiesChanged:Fire(player)
	return true
end

function Floaties.unequip(player, uid)
	local f = Floaties.find(player, uid)
	if not f or not f.slot then
		return false, "It's already in your Backpack"
	end
	if Floaties.backpackCount(player) >= Economy.backpackSize(player) then
		return false, "Your Backpack is full!"
	end
	local prof = Core.profiles[player]
	if prof.arriving then
		prof.arriving[uid] = nil
	end
	f.slot = nil
	Bases.unplace(player, uid)
	Sync.floatie(player, f)
	Core.FloatiesChanged:Fire(player)
	return true
end

-- the best Floaties (by Air/s) go on your slots, the rest into the Backpack
function Floaties.equipBest(player)
	local prof = Core.profiles[player]
	local count = Economy.slotCount(player)
	local list = table.clone(prof.data.floaties)
	table.sort(list, function(a, b)
		local ia, ib = Formulas.baseIncome(a), Formulas.baseIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a.uid < b.uid
	end)
	local best = {}
	for i = 1, math.min(count, #list) do
		best[list[i].uid] = true
	end
	-- off the base: placed Floaties that didn't make the cut
	local used = {}
	for _, f in ipairs(prof.data.floaties) do
		if f.slot and (not best[f.uid] or f.slot > count) then
			f.slot = nil
			if prof.arriving then
				prof.arriving[f.uid] = nil
			end
			Sync.floatie(player, f)
		elseif f.slot then
			used[f.slot] = true
		end
	end
	-- on the base: the best ones that were in the Backpack
	local nextSlot = 1
	for i = 1, math.min(count, #list) do
		local f = list[i]
		if not f.slot then
			while used[nextSlot] do
				nextSlot += 1
			end
			f.slot = nextSlot
			used[nextSlot] = true
			Sync.floatie(player, f)
		end
	end
	Bases.refresh(player)
	Core.FloatiesChanged:Fire(player)
	return true
end

function Floaties.setLocked(player, uid, locked)
	local f = Floaties.find(player, uid)
	if not f then
		return false
	end
	f.locked = locked == true
	Sync.floatie(player, f)
	return true
end

---------------------------------------------------------------------
-- Level Up
---------------------------------------------------------------------
-- count = how many levels (1, 10, or 100 for "Max": as many as you can afford)
function Floaties.levelUp(player, uid, count)
	local f = Floaties.find(player, uid)
	local prof = Core.getProfile(player)
	if not f or not prof then
		return false, "Floatie not found"
	end
	if f.level >= Config.Levels.Max then
		return false, "Already at the max level!"
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, Config.Levels.Max)
	local levels, cost = Formulas.affordableLevels(f, prof.data.air, count)
	if levels < 1 then
		return false, "Not enough Air! You need " .. Config.Format(Formulas.levelCost(f, 1)) .. "."
	end
	if not Economy.spend(player, cost) then
		return false, "Not enough Air!"
	end
	local oldSize = Formulas.sizeIndex(f.level)
	f.level += levels
	local newSize = Formulas.sizeIndex(f.level)
	local def = Config.FloatieById[f.id]
	if newSize ~= oldSize then
		-- a size milestone: rebuild bigger, with the inflate pop
		local model = Bases.model(player, f.uid)
		local pos = model and model:GetPivot().Position
		local newModel = Bases.place(player, f)
		if newModel then
			newModel:SetAttribute("GrewAt", workspace:GetServerTimeNow())
		end
		if pos then
			FloatieModel.PopEffect(pos + Vector3.new(0, 3, 0), def.color)
		end
		Core.notify(player, "🎈 Your " .. Formulas.nameOf(f) .. " inflated to " .. Config.Sizes[newSize].name .. "!", "success")
	else
		Bases.label(player, f, Bases.model(player, f.uid))
	end
	Sync.floatie(player, f)
	Core.FloatiesChanged:Fire(player)
	return true, "Level " .. f.level .. "!", f.level
end

---------------------------------------------------------------------
-- Selling
---------------------------------------------------------------------
-- sells every listed (unlocked) Floatie; returns sold count, Air earned
function Floaties.sell(player, uids)
	local total, count = 0, 0
	for _, uid in ipairs(uids) do
		local f = Floaties.find(player, uid)
		if f and not f.locked then
			total += Formulas.sellValue(f)
			count += 1
			Floaties.remove(player, uid)
		end
	end
	if total > 0 then
		Economy.addAir(player, total)
	end
	return count, total
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local function loadedCall(fn)
	return function(player, ...)
		if not Core.getProfile(player) or not Core.throttle(player, "floaties", 0.08) then
			return false, "Slow down!"
		end
		return fn(player, ...)
	end
end

Core.remote("Equip").OnServerEvent:Connect(loadedCall(function(player, uid)
	local ok, msg = Floaties.equip(player, uid)
	if not ok then
		Core.notify(player, msg, "error")
	end
end))

Core.remote("Unequip").OnServerEvent:Connect(loadedCall(function(player, uid)
	local ok, msg = Floaties.unequip(player, uid)
	if not ok then
		Core.notify(player, msg, "error")
	end
end))

Core.remote("EquipBest").OnServerEvent:Connect(loadedCall(function(player)
	Floaties.equipBest(player)
	Core.notify(player, "Equipped your best Floaties! ⭐", "success")
end))

Core.remote("SetLocked").OnServerEvent:Connect(loadedCall(function(player, uid, locked)
	Floaties.setLocked(player, uid, locked)
end))

Core.remote("LevelUp", "RemoteFunction").OnServerInvoke = loadedCall(function(player, uid, count)
	return Floaties.levelUp(player, uid, count)
end)

Core.remote("SellFloaties", "RemoteFunction").OnServerInvoke = loadedCall(function(player, uids)
	if type(uids) ~= "table" or #uids > 600 then
		return false, "Try again"
	end
	local clean = {}
	for _, uid in ipairs(uids) do
		if type(uid) == "number" then
			table.insert(clean, uid)
		end
	end
	local count, total = Floaties.sell(player, clean)
	if count == 0 then
		return false, "Nothing to sell (locked Floaties are skipped)"
	end
	Core.notify(player, ("Sold %d Floatie%s for %s Air 💰"):format(count, if count == 1 then "" else "s", Config.Format(total)), "success")
	return true, total, count
end)

return Floaties
