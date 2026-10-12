--[[
	Rolling (ModuleScript in ServerScriptService.Server)
	The pull: press Roll (or turn on Auto Roll) and your pump inflates a
	balloon for the inflate time, then it pops and reveals a Floatie that
	rides your conveyor and walks to its slot.

	The server decides the result the moment you roll (so it can't be
	cheated) and reserves the slot; the model appears when the ride ends.
	See ConfigParts/Rolling for how Luck picks the copy (Floatie x size x mutation).

	Remotes
	  Roll (event)                 roll now (ignored until the last roll's inflate time is over)
	  SetSetting (event)           ("autoRoll" | "hide", bool) or ("autoSell", rarity order 0..#RarityOrder)
	  UseJackpot (fn) -> ok, msg   spend a Jackpot Roll: your next roll gets x999 Luck
	  RollResult (to you)          { id, mut, form, dest, soldFor, uid, slot, inflateTime, jackpot, rollNumber, new }
	  PumpPuff (to players nearby) (baseIndex, inflateTime) a balloon inflates at that base's pump
	  ConveyorRide (to nearby)     { base, id, mut, form, slot, dest, soldFor, ride, walk } after the pop
	  ChatMessage (to everyone)    very rare pulls are announced in the chat (Core.chatAll)
	Player attributes: AutoRoll, Hide, AutoSell, JackpotReady
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)
local Bases = require(script.Parent.Bases)
local Floaties = require(script.Parent.Floaties)
local Sync = require(script.Parent.Sync)

local Rolling = {}

local R = Config.Rolling
local M = Config.Map

local RollResultRE = Core.remote("RollResult")
local PumpPuffRE = Core.remote("PumpPuff")
local ConveyorRideRE = Core.remote("ConveyorRide")

---------------------------------------------------------------------
-- Picking the copy (Floatie x size x mutation), the Anime Dice way
---------------------------------------------------------------------
-- a random one of `list` (Floaties), commoner ones more likely (weight 1 / odds)
local function weightedPick(list)
	local total = 0
	for _, def in ipairs(list) do
		total += 1 / def.odds
	end
	local roll = Core.rng:NextNumber() * total
	for _, def in ipairs(list) do
		roll -= 1 / def.odds
		if roll <= 0 then
			return def
		end
	end
	return list[#list]
end

local function ofRarity(rarity)
	local list = {}
	for _, def in ipairs(Config.Floaties) do
		if def.rarity == rarity then
			table.insert(list, def)
		end
	end
	return list
end

-- the pull: Formulas.pickCopy with this player's Luck and boosts (see ConfigParts/Rolling).
-- luckMult = 999 for a Jackpot Roll. Returns def, mutation id, size id.
local function random()
	return Core.rng:NextNumber()
end

function Rolling.pickCopy(player, luckMult)
	local ev, evName = Economy.activeEvent()
	local c = Formulas.pickCopy(Economy.luck(player) * (luckMult or 1), {
		mutation = Economy.mutationMult(player),
		secret = ev and ev.secretLuck or 1,
		event = evName,
	}, random)
	return Config.FloatieById[c.id], c.mut, c.form
end

---------------------------------------------------------------------
-- The conveyor ride (how long the visuals take, so the model appears on time)
---------------------------------------------------------------------
local BELT_SPEED = (M.ConveyorStartZ - M.ConveyorEndZ) / R.ConveyorTime

-- seconds on the belt, seconds walking to the slot
local function rideTimes(base, slot)
	local pad = slot and base.slots[slot]
	if not pad then
		return R.ConveyorTime, 0 -- to the end of the belt (Backpack / sold)
	end
	local rel = base.cf:PointToObjectSpace(pad.Position)
	return math.abs(M.ConveyorStartZ - rel.Z) / BELT_SPEED, math.abs(rel.X) / R.WalkSpeed
end

-- pump puffs and conveyor rides are only worth sending to players who can
-- see that base (its owner always gets them); bases are ~200 studs apart
local VIEW_RANGE = 320
local function fireNear(remote, owner, base, ...)
	local pos = base and base.cf.Position
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p == owner or not pos or not root or (root.Position - pos).Magnitude <= VIEW_RANGE then
			remote:FireClient(p, ...)
		end
	end
end

---------------------------------------------------------------------
-- Roll
---------------------------------------------------------------------
function Rolling.roll(player)
	local prof = Core.getProfile(player)
	if not prof then
		return false
	end
	local clock = os.clock()
	if clock < (prof.nextRollAt or 0) - 0.05 then
		return false -- the pump is still inflating
	end
	local data = prof.data
	local inflate = Economy.inflateTime(player)
	prof.nextRollAt = clock + inflate

	local n = data.totalRolls + 1
	local jackpot = prof.jackpotNext == true
	if jackpot then
		prof.jackpotNext = false
		player:SetAttribute("JackpotReady", false)
	end
	local def, mut, form
	if n <= R.StarterRolls and not jackpot then
		def, mut, form = weightedPick(ofRarity(if n == R.StarterUncommonAt then "Uncommon" else "Common")), "Normal", "Normal"
	else
		def, mut, form = Rolling.pickCopy(player, if jackpot then R.JackpotLuck else 1)
	end
	data.totalRolls = n
	Sync.field(player, "totalRolls")

	local isNew = not data.index[Floaties.indexKey(def.id, mut, form)]
	local f, dest, soldFor = Floaties.add(player, { id = def.id, mut = mut, form = form }, { arriving = true })
	local base = Bases.get(player)
	local showRide = base ~= nil and not data.settings.hide
	local ride, walk = 0, 0
	if showRide then
		ride, walk = rideTimes(base, f and f.slot)
	end

	RollResultRE:FireClient(player, {
		id = def.id, mut = mut, form = form, dest = dest, soldFor = soldFor, uid = f and f.uid, slot = f and f.slot,
		inflateTime = inflate, jackpot = jackpot, rollNumber = n, new = isNew,
	})
	fireNear(PumpPuffRE, player, base, prof.base, inflate)

	task.delay(inflate, function()
		if not player.Parent or not Core.profiles[player] then
			return
		end
		if showRide then
			fireNear(ConveyorRideRE, player, base, {
				base = prof.base, id = def.id, mut = mut, form = form, slot = f and f.slot, dest = dest,
				soldFor = soldFor, ride = ride, walk = walk,
			})
			if f then
				task.delay(ride + walk, Floaties.arrive, player, f.uid)
			end
		elseif f then
			Floaties.arrive(player, f.uid)
		end
		-- very rare pulls go in the server chat (not on everyone's screen): Mythic or rarer
		-- AND rare for this player's Luck, or Legendary+ from a Jackpot Roll
		local odds = Formulas.copyOdds(def.id, mut, form)
		local rarityName = Config.RarityForOdds(odds)
		local order = Config.Rarities[rarityName].order
		if (order >= R.AnnounceOrder and odds >= Economy.luck(player) * R.AnnounceLuckRatio) or (jackpot and order >= 5) then
			Core.chatAll(("🌟 %s pulled a %s %s (%s)!"):format(player.DisplayName, string.upper(rarityName),
				Formulas.copyName(def.id, mut, form), Config.FormatOdds(odds)), rarityName)
		end
	end)
	Core.StatsChanged:Fire(player) -- TotalRolls on the HUD (and the quick starter rolls end)
	return true
end

---------------------------------------------------------------------
-- Settings + Jackpot Roll
---------------------------------------------------------------------
local function publishSettings(player, prof)
	player:SetAttribute("AutoRoll", prof.autoRoll == true)
	player:SetAttribute("Hide", prof.data.settings.hide == true)
	player:SetAttribute("AutoSell", prof.data.settings.autoSell or 0)
	player:SetAttribute("JackpotReady", prof.jackpotNext == true)
end

Core.remote("Roll").OnServerEvent:Connect(function(player)
	Rolling.roll(player)
end)

Core.remote("SetSetting").OnServerEvent:Connect(function(player, key, value)
	local prof = Core.getProfile(player)
	if not prof or type(key) ~= "string" or not Core.throttle(player, "setting_" .. key, 0.1) then
		return
	end
	if key == "autoRoll" then
		prof.autoRoll = value == true
	elseif key == "hide" then
		prof.data.settings.hide = value == true
		Sync.field(player, "settings")
	elseif key == "autoSell" then
		local order = math.floor(tonumber(value) or -1)
		if order >= 0 and order <= #Config.RarityOrder then
			prof.data.settings.autoSell = order
			Sync.field(player, "settings")
		end
	end
	publishSettings(player, prof)
end)

Core.remote("UseJackpot", "RemoteFunction").OnServerInvoke = function(player)
	local prof = Core.getProfile(player)
	if not prof or not Core.throttle(player, "jackpot", 0.5) then
		return false, "Try again"
	end
	if prof.jackpotNext then
		return false, "Your next roll is already a Jackpot Roll!"
	end
	if prof.data.items.jackpotRolls < 1 then
		return false, "You have no Jackpot Rolls"
	end
	prof.data.items.jackpotRolls -= 1
	prof.jackpotNext = true
	Sync.field(player, "items")
	publishSettings(player, prof)
	return true, "🎰 Jackpot Roll ready: your next roll has x" .. R.JackpotLuck .. " Luck!"
end

Core.PlayerLoaded:Connect(function(player, prof)
	prof.autoRoll = false
	prof.nextRollAt = 0
	publishSettings(player, prof)
end)

-- Auto Roll: 10 checks a second
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.1 then
		return
	end
	accum = 0
	local clock = os.clock()
	for player, prof in Core.eachLoaded() do
		if prof.autoRoll and clock >= (prof.nextRollAt or 0) then
			local ok, problem = pcall(Rolling.roll, player)
			if not ok then
				warn("[Rolling] " .. tostring(problem))
				prof.autoRoll = false
				publishSettings(player, prof)
			end
		end
	end
end)

return Rolling
