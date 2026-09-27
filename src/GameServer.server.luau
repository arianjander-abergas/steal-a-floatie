--[[
	Steal a Floatie — GameServer (Script in ServerScriptService)

	Core loop:
	  1. Buy Floaties (balloon animals) from the Pump Line with Air.
	  2. They sit on your pedestals, earn Air every second, and INFLATE over time
	     (Deflated -> Puffy -> Round -> Chonky -> MEGA). Bigger = more Air.
	  3. Sneak into other bases and hold E to steal a Floatie. It sits on your head
	     and makes you FLOAT — the bigger it is, the lighter and slower you get.
	  4. Get it home to keep it. Defenders shoot it with the Dart Blaster -> POP,
	     it flies back to its owner.
	  5. Lock your base, rebirth for multipliers, catch mutations and server events.

	Admin chat commands (Studio, the place owner, or Config.AdminUserIds):
	  ;event HeliumRain      ;give Dragonflate Rainbow      ;air 100000      ;grow
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
local ServerFolder = script.Parent:WaitForChild("Server")
local DataService = require(ServerFolder:WaitForChild("DataService"))
local MapBuilder = require(ServerFolder:WaitForChild("MapBuilder"))

local rng = Random.new()

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(name, className)
	local r = Instance.new(className or "RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local NotifyRE = remote("Notify")
local FireDartRE = remote("FireDart")
local KnockbackRE = remote("Knockback")
local RebirthRE = remote("Rebirth")
local RedeemRF = remote("RedeemCode", "RemoteFunction")
local RequestHomeRE = remote("RequestHome") -- HUD Home button (no arguments)
Remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local map = MapBuilder.Build()
local bases = map.bases
for _, base in ipairs(bases) do
	base.owner = nil
	base.models = {}    -- [slot] = Model
	base.slotData = {}  -- [slot] = floatie data table
	base.lockedUntil = 0
	base.lockReadyAt = 0
end

local profiles = {}     -- [Player] = { data, canSave, base, passes, incomePerSec, dartReady, homeReady, loaded }
local carries = {}      -- [thief Player] = carry info
local carriedKeys = {}  -- ["ownerUserId:uid"] = true while that Floatie is on someone's head
local lineItems = {}    -- Floaties riding the Pump Line

local function now()
	return workspace:GetServerTimeNow()
end

local function notify(player, text, kind)
	NotifyRE:FireClient(player, text, kind or "info")
end

local function notifyAll(text, kind)
	NotifyRE:FireAllClients(text, kind or "info")
end

local function carryKey(owner, uid)
	return tostring(owner.UserId) .. ":" .. tostring(uid)
end

local function hasPass(player, name)
	local prof = profiles[player]
	return prof ~= nil and prof.passes[name] == true
end

local function activeEvent()
	local name = ReplicatedStorage:GetAttribute("Event")
	if name and name ~= "" and (ReplicatedStorage:GetAttribute("EventEndsAt") or 0) > now() then
		return Config.Events[name], name
	end
	return nil, nil
end

local function pedestalCount(player)
	local prof = profiles[player]
	if not prof then
		return 0
	end
	local n = Config.BasePedestals + prof.data.rebirths * Config.PedestalsPerRebirth
	if hasPass(player, "ExtraPedestals") then
		n += Config.ExtraPedestalsAmount
	end
	return math.min(n, Config.MaxPedestals)
end

local function incomeMultiplier(player)
	local prof = profiles[player]
	local m = 1 + prof.data.rebirths * Config.RebirthIncomeBonus
	if hasPass(player, "DoubleAir") then
		m *= 2
	end
	if hasPass(player, "VIP") then
		m *= 1.2
	end
	local ev = activeEvent()
	if ev and ev.incomeMult then
		m *= ev.incomeMult
	end
	return m
end

local function growthMultiplier(player)
	return if hasPass(player, "FastInflate") then 1.5 else 1
end

-- Luck shown on the HUD. Stage 2 (Lucky Breeze) makes this real.
local function luckMultiplier(_player)
	return 1
end

-- numbers the HUD reads: Cash = the real income multiplier
-- (rebirths x DoubleAir x VIP x event incomeMult, see incomeMultiplier)
local function publishMultipliers(player)
	local prof = profiles[player]
	if not prof then
		return
	end
	local cash = incomeMultiplier(player)
	player:SetAttribute("CashMultiplier", cash)
	player:SetAttribute("LuckMultiplier", luckMultiplier(player))
	player:SetAttribute("BoostPercent", math.floor((cash - 1) * 100 + 0.5))
end

-- income per second of one Floatie BEFORE the player's multipliers
local function floatieIncome(f)
	local def = Config.FloatieById[f.id]
	if not def then
		return 0
	end
	local st = Config.Stages[f.stage] or Config.Stages[1]
	local mut = Config.MutationById[f.mut] or Config.MutationById.Normal
	return def.income * st.income * mut.mult
end

local function sellValue(f)
	local def = Config.FloatieById[f.id]
	local st = Config.Stages[f.stage] or Config.Stages[1]
	local mut = Config.MutationById[f.mut] or Config.MutationById.Normal
	return math.floor(def.price * Config.SellRate * st.income * mut.mult)
end

local function findFloatie(data, uid)
	for i, f in ipairs(data.floaties) do
		if f.uid == uid then
			return f, i
		end
	end
	return nil, nil
end

local function newUid(prof)
	local uid = prof.data.nextUid
	prof.data.nextUid += 1
	return uid
end

local function freeSlot(player)
	local prof = profiles[player]
	if not prof then
		return nil
	end
	local used = {}
	for _, f in ipairs(prof.data.floaties) do
		if f.slot then
			used[f.slot] = true
		end
	end
	for s = 1, pedestalCount(player) do
		if not used[s] then
			return s
		end
	end
	return nil
end

-- growth: returns true when the Floatie reached a new stage
local function growFloatie(f, seconds)
	local changed = false
	f.growth = (f.growth or 0) + seconds
	while true do
		local st = Config.Stages[f.stage]
		if not st or not st.growTime then
			f.growth = 0
			break
		end
		if f.growth >= st.growTime then
			f.growth -= st.growTime
			f.stage += 1
			changed = true
		else
			break
		end
	end
	return changed
end

local function timeToNextStage(player, f)
	local st = Config.Stages[f.stage]
	if not st or not st.growTime then
		return nil
	end
	return (st.growTime - (f.growth or 0)) / growthMultiplier(player)
end

---------------------------------------------------------------------
-- Pedestals
---------------------------------------------------------------------
local function pedestalTopCF(base, slot)
	local ped = base.pedestals[slot]
	return ped.CFrame * CFrame.new(0, ped.Size.Y / 2, 0)
end

local function updatePedestal(base, slot)
	local ped = base.pedestals[slot]
	local f = base.slotData[slot]
	local unlocked = base.owner ~= nil and slot <= pedestalCount(base.owner)
	ped:SetAttribute("HasFloatie", f ~= nil)
	ped:SetAttribute("Unlocked", unlocked)
	ped.Color = if unlocked then base.color else Color3.fromRGB(95, 95, 105)
	ped.Material = if unlocked then Enum.Material.SmoothPlastic else Enum.Material.Slate
	if f then
		local def = Config.FloatieById[f.id]
		local st = Config.Stages[f.stage] or Config.Stages[1]
		ped.StealPrompt.ObjectText = def.name .. " (" .. st.name .. ")"
		ped.StealPrompt.HoldDuration = st.stealTime
		ped.SellPrompt.ObjectText = def.name
		ped.SellPrompt.ActionText = "Sell for " .. Config.Format(sellValue(f))
	end
end

local function refreshLabel(player, f, model)
	local def = Config.FloatieById[f.id]
	local extra = nil
	local t = timeToNextStage(player, f)
	if t then
		local nextStage = Config.Stages[f.stage + 1]
		extra = "→ " .. nextStage.name .. " in " .. Config.FormatTime(t)
	else
		extra = "🎈 FULLY INFLATED"
	end
	FloatieModel.SetLabel(model, def, f.mut, f.stage, floatieIncome(f) * incomeMultiplier(player), extra)
end

local function removeFromPedestal(base, slot)
	if base.models[slot] then
		base.models[slot]:Destroy()
	end
	base.models[slot] = nil
	base.slotData[slot] = nil
	updatePedestal(base, slot)
end

local function placeFloatie(player, f)
	local prof = profiles[player]
	if not prof then
		return
	end
	local base = bases[prof.base]
	if not f.slot or f.slot > pedestalCount(player) then
		return -- stored, but no pedestal for it right now
	end
	local def = Config.FloatieById[f.id]
	if not def then
		return
	end
	if base.models[f.slot] then
		base.models[f.slot]:Destroy()
	end
	local st = Config.Stages[f.stage] or Config.Stages[1]
	local model = FloatieModel.Build(def, f.mut, st.scale)
	FloatieModel.SetAnchored(model, true)
	model:PivotTo(pedestalTopCF(base, f.slot))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", f.uid)
	model.Parent = base.floatieFolder
	base.models[f.slot] = model
	base.slotData[f.slot] = f
	refreshLabel(player, f, model)
	updatePedestal(base, f.slot)
end

local function refreshBase(player)
	local prof = profiles[player]
	if not prof then
		return
	end
	local base = bases[prof.base]
	for slot = 1, #base.pedestals do
		removeFromPedestal(base, slot)
	end
	for _, f in ipairs(prof.data.floaties) do
		if not carriedKeys[carryKey(player, f.uid)] then
			placeFloatie(player, f)
		end
	end
	for slot = 1, #base.pedestals do
		updatePedestal(base, slot)
	end
end

-- make sure every Floatie has its own slot (fixes old/corrupt saves)
local function normalizeSlots(player)
	local data = profiles[player].data
	local used = {}
	for _, f in ipairs(data.floaties) do
		if f.slot and not used[f.slot] then
			used[f.slot] = true
		else
			f.slot = nil
		end
	end
	for _, f in ipairs(data.floaties) do
		if not f.slot then
			for s = 1, Config.MaxPedestals do
				if not used[s] then
					f.slot = s
					used[s] = true
					break
				end
			end
		end
	end
end

local function giveFloatie(player, id, mut, stage)
	local prof = profiles[player]
	local slot = freeSlot(player)
	if not prof or not slot or not Config.FloatieById[id] then
		return nil
	end
	local f = { uid = newUid(prof), id = id, mut = mut or "Normal", stage = stage or 1, growth = 0, slot = slot }
	table.insert(prof.data.floaties, f)
	placeFloatie(player, f)
	return f
end

---------------------------------------------------------------------
-- Base lock
---------------------------------------------------------------------
local function lockBase(player, force)
	local prof = profiles[player]
	if not prof then
		return false
	end
	local base = bases[prof.base]
	local t = now()
	if base.lockedUntil > t then
		notify(player, "Your base is already locked!", "info")
		return false
	end
	if not force and t < base.lockReadyAt then
		notify(player, "Lock recharging: " .. math.ceil(base.lockReadyAt - t) .. "s", "error")
		return false
	end
	base.lockedUntil = t + Config.LockDuration
	base.lockReadyAt = base.lockedUntil + Config.LockRecharge
	base.folder:SetAttribute("LockedUntil", base.lockedUntil)
	base.barrier.Transparency = 0.55
	notify(player, "🛡️ Base locked for " .. Config.LockDuration .. "s!", "success")
	return true
end

---------------------------------------------------------------------
-- Carrying (stealing)
---------------------------------------------------------------------
local function clearCarryAttributes(thief)
	thief:SetAttribute("CarryEndsAt", nil)
	thief:SetAttribute("CarryName", nil)
	thief:SetAttribute("CarryHits", nil)
	thief:SetAttribute("CarryPopHits", nil)
end

-- outcome: "delivered" | "popped" | "returned"
local function endCarry(thief, outcome)
	local c = carries[thief]
	if not c then
		return
	end
	carries[thief] = nil
	carriedKeys[carryKey(c.owner, c.f.uid)] = nil
	if c.vf then
		c.vf:Destroy()
	end
	if c.att then
		c.att:Destroy()
	end
	local hum = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.BaseWalkSpeed
	end
	clearCarryAttributes(thief)

	local ownerProf = profiles[c.owner]
	local def = Config.FloatieById[c.f.id]

	if outcome == "delivered" and ownerProf and profiles[thief] then
		local _, idx = findFloatie(ownerProf.data, c.f.uid)
		local slot = freeSlot(thief)
		if idx and slot then
			table.remove(ownerProf.data.floaties, idx)
			local tp = profiles[thief]
			local nf = { uid = newUid(tp), id = c.f.id, mut = c.f.mut, stage = c.f.stage, growth = c.f.growth, slot = slot }
			table.insert(tp.data.floaties, nf)
			if c.model then
				c.model:Destroy()
			end
			placeFloatie(thief, nf)
			tp.data.stats.steals += 1
			ownerProf.data.stats.stolenFrom += 1
			local stageName = Config.Stages[nf.stage].name
			notify(thief, "💰 You stole " .. def.name .. " (" .. stageName .. ")!", "success")
			notify(c.owner, "😭 " .. thief.DisplayName .. " stole your " .. def.name .. "!", "alert")
			local rarityOrder = Config.Rarities[def.rarity].order
			if rarityOrder >= 5 or nf.stage >= 4 or nf.mut ~= "Normal" then
				notifyAll("🚨 " .. thief.DisplayName .. " stole " .. c.owner.DisplayName .. "'s " .. stageName .. " " .. def.name .. "!", "event")
			end
			return
		end
		outcome = "returned"
	end

	-- popped / returned / failed delivery: back to the owner's pedestal
	if c.model then
		c.model:Destroy()
	end
	if ownerProf then
		placeFloatie(c.owner, c.f)
	end
	if outcome == "returned" and thief.Parent then
		notify(thief, "The " .. def.name .. " floated back home.", "info")
	end
end

local function startCarry(thief, base, slot)
	local owner = base.owner
	local f = base.slotData[slot]
	local model = base.models[slot]
	local char = thief.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (owner and f and model and hum and hum.Health > 0 and head and hrp) then
		return
	end
	local def = Config.FloatieById[f.id]
	local st = Config.Stages[f.stage] or Config.Stages[1]

	-- take it off the pedestal (it stays in the owner's save until delivered)
	base.models[slot] = nil
	base.slotData[slot] = nil
	updatePedestal(base, slot)
	carriedKeys[carryKey(owner, f.uid)] = true

	-- put it on the thief's head
	FloatieModel.SetAnchored(model, false)
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.3, 0) * CFrame.Angles(0, math.pi / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model:SetAttribute("CarriedBy", thief.UserId)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(255, 60, 60)
	hl.Parent = model
	model.Parent = map.carried

	-- the twist: bigger balloon = you float + move slower
	local att = Instance.new("Attachment")
	att.Name = "FloatLift"
	att.Parent = hrp
	local vf = Instance.new("VectorForce")
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Force = Vector3.new(0, hrp.AssemblyMass * workspace.Gravity * st.lift, 0)
	vf.Parent = hrp
	hum.WalkSpeed = math.max(6, Config.BaseWalkSpeed - st.slow)

	carries[thief] = {
		model = model, owner = owner, f = f, hits = 0, popHits = st.popHits,
		endsAt = now() + Config.CarryTimeout, att = att, vf = vf,
	}
	thief:SetAttribute("CarryEndsAt", now() + Config.CarryTimeout)
	thief:SetAttribute("CarryName", st.name .. " " .. def.name)
	thief:SetAttribute("CarryHits", 0)
	thief:SetAttribute("CarryPopHits", st.popHits)

	notify(owner, "🚨 " .. thief.DisplayName .. " is stealing your " .. def.name .. "! Pop it with your Dart Blaster!", "alert")
	notify(thief, "Got it! Get home before it gets popped!", "success")
end

local function onSteal(thief, base, slot)
	local prof = profiles[thief]
	local owner = base.owner
	if not prof or not prof.loaded or not owner or owner == thief then
		return
	end
	if not base.slotData[slot] or carries[thief] then
		return
	end
	if base.lockedUntil > now() then
		notify(thief, "This base is locked! 🛡️", "error")
		return
	end
	if not freeSlot(thief) then
		notify(thief, "Your base is full! Sell a Floatie first.", "error")
		return
	end
	startCarry(thief, base, slot)
end

local function onSell(player, base, slot)
	if base.owner ~= player then
		return
	end
	local prof = profiles[player]
	local f = base.slotData[slot]
	if not prof or not f then
		return
	end
	local _, idx = findFloatie(prof.data, f.uid)
	if not idx then
		return
	end
	local value = sellValue(f)
	table.remove(prof.data.floaties, idx)
	removeFromPedestal(base, slot)
	prof.data.air += value
	notify(player, "Sold " .. Config.FloatieById[f.id].name .. " for " .. Config.Format(value) .. " Air", "success")
end

local function popCarry(thief, shooter)
	local c = carries[thief]
	if not c then
		return
	end
	local def = Config.FloatieById[c.f.id]
	local pos = if c.model and c.model.PrimaryPart then c.model:GetPivot().Position + Vector3.new(0, 3, 0) else Vector3.zero
	FloatieModel.PopEffect(pos, def.color)
	local owner = c.owner
	local reward = floatieIncome(c.f) * Config.PopReward
	endCarry(thief, "popped")
	KnockbackRE:FireClient(thief, Vector3.new(0, 55, 0))
	notify(thief, "💥 POP! Your stolen " .. def.name .. " flew back home.", "error")
	local sp = profiles[shooter]
	if sp then
		sp.data.stats.pops += 1
		if shooter ~= owner then
			sp.data.air += reward
			notify(shooter, "🦸 Hero pop! +" .. Config.Format(reward) .. " Air", "success")
		else
			notify(shooter, "💥 You popped the thief! " .. def.name .. " is safe.", "success")
		end
	end
	if owner ~= shooter and owner.Parent then
		notify(owner, "🦸 " .. shooter.DisplayName .. " popped the thief! Your " .. def.name .. " is safe.", "success")
	end
end

---------------------------------------------------------------------
-- Dart Blaster
---------------------------------------------------------------------
local function playerFromPart(inst)
	local node = inst
	while node and node ~= workspace do
		local carriedBy = node:GetAttribute("CarriedBy")
		if carriedBy then
			return Players:GetPlayerByUserId(carriedBy), true
		end
		local p = Players:GetPlayerFromCharacter(node)
		if p then
			return p, false
		end
		node = node.Parent
	end
	return nil, false
end

local function dartVisual(from, to)
	local dist = (to - from).Magnitude
	local dart = Instance.new("Part")
	dart.Name = "Dart"
	dart.Anchored = true
	dart.CanCollide = false
	dart.CanQuery = false
	dart.CanTouch = false
	dart.Material = Enum.Material.Neon
	dart.Color = Color3.fromRGB(255, 240, 90)
	dart.Size = Vector3.new(0.25, 0.25, 1.4)
	dart.CFrame = CFrame.lookAt(from, to)
	dart.Parent = workspace
	TweenService:Create(dart, TweenInfo.new(math.clamp(dist / 220, 0.05, 0.5), Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) }):Play()
	Debris:AddItem(dart, 0.6)
end

FireDartRE.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Vector3" then
		return
	end
	local prof = profiles[player]
	if not prof or carries[player] then
		return
	end
	local clock = os.clock()
	if clock < prof.dartReady then
		return
	end
	prof.dartReady = clock + Config.DartCooldown
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head or not char:FindFirstChild("Dart Blaster") then
		return
	end
	local origin = head.Position
	local dir = target - origin
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit * Config.DartRange
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(origin, dir, params)
	dartVisual(origin, if result then result.Position else origin + dir)
	if not result then
		return
	end
	local victim, hitBalloon = playerFromPart(result.Instance)
	if not victim or victim == player then
		return
	end
	local c = carries[victim]
	if c then
		c.hits += 1
		victim:SetAttribute("CarryHits", c.hits)
		if c.hits >= c.popHits then
			popCarry(victim, player)
		end
	elseif not hitBalloon then
		KnockbackRE:FireClient(victim, dir.Unit * Config.DartKnockback + Vector3.new(0, 18, 0))
	end
end)

---------------------------------------------------------------------
-- Pump Line
---------------------------------------------------------------------
local lineDir = (map.line.endPos - map.line.startPos).Unit
local function lineCF(t)
	local pos = map.line.startPos:Lerp(map.line.endPos, t)
	return CFrame.lookAt(pos, pos + lineDir) * CFrame.Angles(0, math.pi / 2, 0)
end

local function rollFloatie()
	local ev, evName = activeEvent()
	if evName == "SecretSkies" and rng:NextNumber() < ev.secretChance then
		return Config.FloatieById.Stormserpent
	end
	local total = 0
	for _, r in pairs(Config.Rarities) do
		total += r.weight
	end
	local roll = rng:NextNumber() * total
	local rarity = "Common"
	for name, r in pairs(Config.Rarities) do
		if r.weight > 0 then
			roll -= r.weight
			if roll <= 0 then
				rarity = name
				break
			end
		end
	end
	local pool = {}
	for _, f in ipairs(Config.Floaties) do
		if f.rarity == rarity then
			table.insert(pool, f)
		end
	end
	if #pool == 0 then
		return Config.Floaties[1]
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function rollMutation()
	local ev, evName = activeEvent()
	local mult = if ev and ev.mutationMult then ev.mutationMult else 1
	for i = #Config.Mutations, 2, -1 do
		local m = Config.Mutations[i]
		local chance
		if m.eventOnly then
			chance = if evName == m.eventOnly then m.eventChance else 0
		else
			chance = m.chance * mult
		end
		if rng:NextNumber() < chance then
			return m.id
		end
	end
	return "Normal"
end

local function onBuy(player, item)
	if item.bought then
		return
	end
	local prof = profiles[player]
	if not prof or not prof.loaded then
		return
	end
	if carries[player] then
		notify(player, "You can't buy while carrying a Floatie!", "error")
		return
	end
	local price = item.def.price
	if prof.data.air < price then
		notify(player, "Not enough Air! You need " .. Config.Format(price) .. ".", "error")
		return
	end
	if not freeSlot(player) then
		notify(player, "Your base is full! Sell a Floatie or Rebirth.", "error")
		return
	end
	item.bought = true
	prof.data.air -= price
	player:SetAttribute("Air", prof.data.air) -- now, so the HUD drops at once (not at the next 1 s tick)
	local pos = item.model:GetPivot().Position
	item.model:Destroy()
	local idx = table.find(lineItems, item)
	if idx then
		table.remove(lineItems, idx)
	end
	FloatieModel.PopEffect(pos + Vector3.new(0, 2, 0), item.def.color)
	giveFloatie(player, item.def.id, item.mut, 1)
	local label = if item.mut ~= "Normal" then item.mut .. " " .. item.def.name else item.def.name
	notify(player, "🎈 You got " .. label .. "!", "success")
end

local function spawnLineFloatie()
	local def = rollFloatie()
	local mut = rollMutation()
	local model = FloatieModel.Build(def, mut, 1)
	FloatieModel.SetAnchored(model, true)
	model:PivotTo(lineCF(0))
	local f = { id = def.id, mut = mut, stage = 1 }
	FloatieModel.SetLabel(model, def, mut, 1, floatieIncome(f), "💰 " .. Config.Format(def.price) .. " Air")
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Buy"
	pr.ObjectText = def.name .. " — " .. Config.Format(def.price) .. " Air"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = model:FindFirstChild("Body") or model.PrimaryPart
	model.Parent = map.line.folder

	local item = { model = model, def = def, mut = mut, t = 0, bought = false }
	pr.Triggered:Connect(function(player)
		onBuy(player, item)
	end)
	table.insert(lineItems, item)

	if Config.Rarities[def.rarity].order >= 5 or mut == "Rainbow" or mut == "Thunder" then
		local label = if mut ~= "Normal" then mut .. " " .. def.name else def.name
		notifyAll("👀 A " .. string.upper(def.rarity) .. " " .. label .. " is on the Pump Line!", "event")
	end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
-- nextEventAt is mirrored to ReplicatedStorage "NextEventAt" (server time)
-- every time it is assigned, so the HUD event timer can count down to it.
local nextEventAt = now() + Config.EventInterval
ReplicatedStorage:SetAttribute("NextEventAt", nextEventAt)

local function startEvent(name, by)
	local ev = Config.Events[name]
	if not ev then
		return false
	end
	ReplicatedStorage:SetAttribute("Event", name)
	ReplicatedStorage:SetAttribute("EventEndsAt", now() + ev.duration)
	-- event income (Golden Hour) changes Cash / boost % right away
	for p, prof in pairs(profiles) do
		if prof.loaded then
			publishMultipliers(p)
		end
	end
	local thanks = if by then " (thanks " .. by .. "!)" else ""
	notifyAll(ev.title .. " — " .. ev.desc .. thanks, "event")
	nextEventAt = now() + ev.duration + Config.EventInterval
	ReplicatedStorage:SetAttribute("NextEventAt", nextEventAt)
	return true
end

local function randomEvent()
	local names = {}
	for name in pairs(Config.Events) do
		table.insert(names, name)
	end
	table.sort(names)
	startEvent(names[rng:NextInteger(1, #names)])
end

---------------------------------------------------------------------
-- Monetization
---------------------------------------------------------------------
local function loadPasses(player)
	local prof = profiles[player]
	for name, info in pairs(Config.GamePasses) do
		if RunService:IsStudio() and Config.TestPassesInStudio then
			prof.passes[name] = true
		elseif info.id ~= 0 then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
			end)
			if success and owns then
				prof.passes[name] = true
			end
		end
		player:SetAttribute("Pass_" .. name, prof.passes[name] == true)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local prof = profiles[player]
	if not prof then
		return
	end
	for name, info in pairs(Config.GamePasses) do
		if info.id == passId then
			prof.passes[name] = true
			player:SetAttribute("Pass_" .. name, true)
			publishMultipliers(player) -- DoubleAir / VIP change Cash right away
			notify(player, "Thanks for buying " .. info.title .. "! 💖", "success")
			if name == "ExtraPedestals" then
				refreshBase(player)
			end
		end
	end
end)

local function grantProduct(player, name)
	local prof = profiles[player]
	if name == "AirPackSmall" then
		prof.data.air += math.max(500, prof.incomePerSec * 300)
	elseif name == "AirPackLarge" then
		prof.data.air += math.max(3000, prof.incomePerSec * 1800)
	elseif name == "InstantLock" then
		local base = bases[prof.base]
		base.lockedUntil = 0
		lockBase(player, true)
	elseif name == "ServerHeliumRain" then
		startEvent("HeliumRain", player.DisplayName)
	else
		return false
	end
	notify(player, "Purchase complete: " .. Config.DevProducts[name].title .. " 💖", "success")
	return true
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local prof = player and profiles[player]
	if not prof or not prof.loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(prof.data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local productName = nil
	for name, info in pairs(Config.DevProducts) do
		if info.id == receipt.ProductId then
			productName = name
		end
	end
	if not productName or not grantProduct(player, productName) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(prof.data.receipts, receipt.PurchaseId)
	while #prof.data.receipts > 50 do
		table.remove(prof.data.receipts, 1)
	end
	DataService.Save(player, prof)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------
-- Rebirth + codes
---------------------------------------------------------------------
RebirthRE.OnServerEvent:Connect(function(player)
	local prof = profiles[player]
	if not prof or not prof.loaded or carries[player] then
		return
	end
	local cost = Config.RebirthCost(prof.data.rebirths)
	if prof.data.air < cost then
		notify(player, "You need " .. Config.Format(cost) .. " Air to rebirth.", "error")
		return
	end
	for thief, c in pairs(carries) do
		if c.owner == player then
			endCarry(thief, "returned")
		end
	end
	local best, bestIncome = nil, -1
	for _, f in ipairs(prof.data.floaties) do
		local inc = floatieIncome(f)
		if inc > bestIncome then
			best, bestIncome = f, inc
		end
	end
	prof.data.rebirths += 1
	prof.data.air = Config.StartingAir
	player:SetAttribute("Air", prof.data.air) -- the HUD drops at once
	prof.data.floaties = {}
	if best then
		best.slot = 1
		table.insert(prof.data.floaties, best)
	end
	refreshBase(player)
	player:SetAttribute("Rebirths", prof.data.rebirths)
	publishMultipliers(player)
	notifyAll("🌟 " .. player.DisplayName .. " reached Rebirth " .. prof.data.rebirths .. "!", "event")
end)

RedeemRF.OnServerInvoke = function(player, code)
	local prof = profiles[player]
	if not prof or not prof.loaded or typeof(code) ~= "string" or #code > 30 then
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
	if reward.floatie and not freeSlot(player) then
		return false, "Base full — sell a Floatie first"
	end
	prof.data.codes[code] = true
	if reward.air then
		prof.data.air += reward.air
	end
	if reward.floatie then
		giveFloatie(player, reward.floatie, reward.mutation, 1)
	end
	return true, "Code redeemed! 🎉"
end

---------------------------------------------------------------------
-- Home button: teleport to your base spawn. Later stages add more
-- reasons to refuse inside canGoHome.
---------------------------------------------------------------------
local function canGoHome(player)
	if carries[player] then
		return false, "You can't go Home while carrying a Floatie!"
	end
	return true, nil
end

RequestHomeRE.OnServerEvent:Connect(function(player)
	local prof = profiles[player]
	if not prof or not prof.loaded then
		return
	end
	local clock = os.clock()
	if clock < prof.homeReady then
		return -- rate limit (silent)
	end
	-- 0.5 s of slack: the HUD waits the full cooldown between clicks, but lag
	-- can bring two requests here a little closer together than that
	prof.homeReady = clock + Config.HomeCooldown - 0.5
	local ok, reason = canGoHome(player)
	if not ok then
		notify(player, reason, "error")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	char:PivotTo(bases[prof.base].spawn.CFrame * CFrame.new(0, 4, 0)) -- same as the join teleport (onPlayerAdded)
end)

---------------------------------------------------------------------
-- Admin commands
---------------------------------------------------------------------
local function isAdmin(player)
	if RunService:IsStudio() or table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

local function onChatted(player, msg)
	if not isAdmin(player) or string.sub(msg, 1, 1) ~= ";" then
		return
	end
	local args = string.split(string.sub(msg, 2), " ")
	local cmd = string.lower(args[1] or "")
	local prof = profiles[player]
	if not prof then
		return
	end
	if cmd == "event" then
		if not startEvent(args[2] or "", "the admin") then
			notify(player, "Unknown event. Try HeliumRain, GoldenHour, WindyDay, Thunderstorm, SecretSkies", "error")
		end
	elseif cmd == "give" then
		local f = giveFloatie(player, args[2] or "", args[3] or "Normal", tonumber(args[4]) or 1)
		notify(player, if f then "Given!" else "Unknown Floatie id or base full", if f then "success" else "error")
	elseif cmd == "air" then
		prof.data.air += tonumber(args[2]) or 0
	elseif cmd == "grow" then
		for _, f in ipairs(prof.data.floaties) do
			f.stage = math.min(#Config.Stages, f.stage + 1)
			f.growth = 0
		end
		refreshBase(player)
	end
end

---------------------------------------------------------------------
-- Players
---------------------------------------------------------------------
local function assignBase(player)
	for i, base in ipairs(bases) do
		if not base.owner then
			base.owner = player
			base.lockedUntil = 0
			base.lockReadyAt = 0
			base.folder:SetAttribute("OwnerUserId", player.UserId)
			base.folder:SetAttribute("LockedUntil", 0)
			base.signLabel.Text = player.DisplayName .. "'s Base"
			return i
		end
	end
	return nil
end

local function releaseBase(index)
	local base = bases[index]
	for slot = 1, #base.pedestals do
		removeFromPedestal(base, slot)
	end
	base.owner = nil
	base.folder:SetAttribute("OwnerUserId", 0)
	base.folder:SetAttribute("LockedUntil", 0)
	base.barrier.Transparency = 1
	base.signLabel.Text = "Empty Base"
	for slot = 1, #base.pedestals do
		updatePedestal(base, slot)
	end
end

local function onCharacterAdded(player, character)
	local prof = profiles[player]
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum or not prof then
		return
	end
	hum.WalkSpeed = Config.BaseWalkSpeed
	hum.Died:Connect(function()
		endCarry(player, "returned")
	end)
	if prof.passes.VIP then
		local head = character:WaitForChild("Head", 5)
		if head then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(90, 26)
			gui.StudsOffset = Vector3.new(0, 2.6, 0)
			gui.MaxDistance = 80
			gui.Parent = head
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = "⭐ VIP"
			t.TextColor3 = Color3.fromRGB(255, 210, 60)
			t.TextStrokeTransparency = 0
			t.Parent = gui
		end
	end
end

local function onPlayerAdded(player)
	local data, canSave = DataService.Load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("We couldn't load your Floaties. Please rejoin in a minute!")
		return
	end
	local baseIndex = assignBase(player)
	if not baseIndex then
		player:Kick("This server is full, please join another one!")
		return
	end
	local prof = { data = data, canSave = canSave, base = baseIndex, passes = {}, incomePerSec = 0, dartReady = 0, homeReady = 0, loaded = false }
	profiles[player] = prof
	loadPasses(player)
	normalizeSlots(player)

	-- offline progress: Floaties kept inflating + some Air while you were away
	local elapsed = math.max(0, os.time() - (data.lastOnline or os.time()))
	if elapsed > 60 and #data.floaties > 0 then
		local growSec = math.min(elapsed, Config.OfflineGrowthCap) * growthMultiplier(player)
		local count = pedestalCount(player)
		local total = 0
		for _, f in ipairs(data.floaties) do
			growFloatie(f, growSec)
			if f.slot and f.slot <= count then
				total += floatieIncome(f)
			end
		end
		local earned = math.floor(total * incomeMultiplier(player) * Config.OfflineIncomeRate * math.min(elapsed, Config.OfflineIncomeCap))
		data.air += earned
		task.delay(3, function()
			if player.Parent then
				notify(player, "💤 While you were away your Floaties inflated and earned " .. Config.Format(earned) .. " Air!", "success")
			end
		end)
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local airStat = Instance.new("StringValue")
	airStat.Name = "Air"
	airStat.Value = Config.Format(data.air)
	airStat.Parent = ls
	local rebirthStat = Instance.new("IntValue")
	rebirthStat.Name = "Rebirths"
	rebirthStat.Value = data.rebirths
	rebirthStat.Parent = ls
	local stealStat = Instance.new("IntValue")
	stealStat.Name = "Steals"
	stealStat.Value = data.stats.steals
	stealStat.Parent = ls
	ls.Parent = player
	prof.stats = { air = airStat, rebirths = rebirthStat, steals = stealStat }

	player:SetAttribute("BaseIndex", baseIndex)
	player:SetAttribute("Air", data.air)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("IncomePerSec", 0)
	publishMultipliers(player) -- CashMultiplier / LuckMultiplier / BoostPercent for the HUD
	-- brand-new players get the tutorial (see ClientMain/Tutorial)
	player:SetAttribute("ShowTutorial", #data.floaties == 0 and data.rebirths == 0 and data.stats.steals == 0)
	player.RespawnLocation = bases[baseIndex].spawn
	refreshBase(player)
	prof.loaded = true

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
		player.Character:PivotTo(bases[baseIndex].spawn.CFrame * CFrame.new(0, 4, 0))
	end
	player.Chatted:Connect(function(msg)
		onChatted(player, msg)
	end)

	if not canSave and not RunService:IsStudio() then
		notify(player, "⚠️ Saving is unavailable right now — progress may not save.", "error")
	end
	notify(player, "Welcome to " .. Config.GameName .. "! Buy Floaties on the Pump Line 🎈", "info")
end

local function onPlayerRemoving(player)
	endCarry(player, "returned")
	for thief, c in pairs(carries) do
		if c.owner == player then
			endCarry(thief, "returned")
		end
	end
	local prof = profiles[player]
	if not prof then
		return
	end
	DataService.Save(player, prof)
	releaseBase(prof.base)
	profiles[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- pedestal + lock prompts
for _, base in ipairs(bases) do
	for slot, ped in ipairs(base.pedestals) do
		ped.StealPrompt.Triggered:Connect(function(player)
			onSteal(player, base, slot)
		end)
		ped.SellPrompt.Triggered:Connect(function(player)
			onSell(player, base, slot)
		end)
	end
	base.lockPrompt.Triggered:Connect(function(player)
		if base.owner == player then
			lockBase(player, false)
		end
	end)
end

game:BindToClose(function()
	for thief in pairs(carries) do
		endCarry(thief, "returned")
	end
	local threads = 0
	for player, prof in pairs(profiles) do
		threads += 1
		task.spawn(function()
			DataService.Save(player, prof)
			threads -= 1
		end)
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------
-- Pump Line movement + spawning
local spawnTimer = 0
local lineAccum = 0
RunService.Heartbeat:Connect(function(dt)
	spawnTimer += dt
	if spawnTimer >= Config.PumpInterval then
		spawnTimer = 0
		spawnLineFloatie()
	end
	lineAccum += dt
	if lineAccum < 1 / 20 then
		return
	end
	local step = lineAccum / Config.PumpTravelTime
	lineAccum = 0
	for i = #lineItems, 1, -1 do
		local item = lineItems[i]
		item.t += step
		if item.t >= 1 then
			item.model:Destroy()
			table.remove(lineItems, i)
		else
			item.model:PivotTo(lineCF(item.t))
		end
	end
end)

-- carries: delivery, timeouts, locked-base shoves (5x per second)
local function insideBase(base, pos)
	local rel = base.cf:PointToObjectSpace(pos)
	return math.abs(rel.X) <= base.size.X / 2 and math.abs(rel.Z) <= base.size.Z / 2 and rel.Y < 40
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local t = now()
		for thief, c in pairs(carries) do
			if not thief.Parent or t >= c.endsAt then
				endCarry(thief, "returned")
			else
				local prof = profiles[thief]
				local hrp = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
				if prof and hrp and insideBase(bases[prof.base], hrp.Position) then
					endCarry(thief, "delivered")
				end
			end
		end
		for _, base in ipairs(bases) do
			if base.owner and base.lockedUntil > t then
				for _, p in ipairs(Players:GetPlayers()) do
					local hrp = p ~= base.owner and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if hrp and insideBase(base, hrp.Position) then
						local out = hrp.Position - base.cf.Position
						out = Vector3.new(out.X, 0, out.Z)
						if out.Magnitude < 1 then
							out = base.cf.LookVector
						end
						KnockbackRE:FireClient(p, out.Unit * 90 + Vector3.new(0, 30, 0))
					end
				end
			end
		end
	end
end)

-- income, growth, labels, lock status, events, wind, autosave (1x per second)
task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		local t = now()

		for player, prof in pairs(profiles) do
			if prof.loaded then
				local base = bases[prof.base]
				local gm = growthMultiplier(player)
				local count = pedestalCount(player)
				local total = 0
				for _, f in ipairs(prof.data.floaties) do
					if f.slot and f.slot <= count and not carriedKeys[carryKey(player, f.uid)] then
						local changed = growFloatie(f, gm)
						total += floatieIncome(f)
						if changed then
							local def = Config.FloatieById[f.id]
							local model = base.models[f.slot]
							local pos = if model then model:GetPivot().Position else pedestalTopCF(base, f.slot).Position
							placeFloatie(player, f) -- rebuild at the new size
							FloatieModel.PopEffect(pos + Vector3.new(0, 3, 0), def.color)
							notify(player, "🎈 Your " .. def.name .. " inflated to " .. Config.Stages[f.stage].name .. "!", "success")
						elseif tick % 3 == 0 and base.models[f.slot] then
							refreshLabel(player, f, base.models[f.slot])
						end
					end
				end
				local income = total * incomeMultiplier(player)
				prof.incomePerSec = income
				prof.data.air += income
				player:SetAttribute("Air", prof.data.air)
				player:SetAttribute("IncomePerSec", income)
				player:SetAttribute("Rebirths", prof.data.rebirths)
				publishMultipliers(player) -- also catches an event ending
				prof.stats.air.Value = Config.Format(prof.data.air)
				prof.stats.rebirths.Value = prof.data.rebirths
				prof.stats.steals.Value = prof.data.stats.steals
			end
		end

		-- lock buttons
		for _, base in ipairs(bases) do
			if base.owner then
				if base.lockedUntil > t then
					base.lockStatus.Text = "🛡️ LOCKED " .. math.ceil(base.lockedUntil - t) .. "s"
				else
					base.barrier.Transparency = 1
					if base.lockReadyAt > t then
						base.lockStatus.Text = "Recharging " .. math.ceil(base.lockReadyAt - t) .. "s"
					else
						base.lockStatus.Text = "LOCK READY"
					end
				end
			else
				base.lockStatus.Text = ""
			end
		end

		-- events
		local ev, evName = activeEvent()
		if not ev and (ReplicatedStorage:GetAttribute("Event") or "") ~= "" then
			ReplicatedStorage:SetAttribute("Event", "")
		end
		if not ev and t >= nextEventAt and #Players:GetPlayers() > 0 then
			randomEvent()
		end
		if evName == "WindyDay" and tick % 2 == 0 then
			for thief in pairs(carries) do
				local a = rng:NextNumber() * math.pi * 2
				KnockbackRE:FireClient(thief, Vector3.new(math.cos(a), 0, math.sin(a)) * 40 + Vector3.new(0, 10, 0))
			end
		end

		-- autosave every 2 minutes
		if tick % 120 == 0 then
			for player, prof in pairs(profiles) do
				task.spawn(DataService.Save, player, prof)
			end
		end
	end
end)

print(("[%s] server v%s started"):format(Config.GameName, Config.Version))
