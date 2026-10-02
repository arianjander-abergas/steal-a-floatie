--[[
	Bases (ModuleScript in ServerScriptService.Server)
	Owns the 8 bases: who has which one, and the Floatie models standing on
	their slots. The save decides where every Floatie is (f.slot); this module
	only makes the world match it.

	  Bases.init(map)              the map MapBuilder built
	  Bases.assign(player) -> i    gives a free base (nil when all 8 are taken)
	  Bases.release(i)
	  Bases.refresh(player)        rebuild every model on the player's base
	  Bases.place(player, f)       (re)build one Floatie's model on its slot
	  Bases.unplace(player, uid)   take one model away
	  Bases.freeSlot(player)       the first empty slot you may use, or nil
	  Bases.slotPart(player, slot) the slot pad part
	  Bases.model(player, uid)     the model of a placed Floatie
	  Bases.refreshLabels(player)  income text on every model (Cash changed)
	  Bases.refreshBest(player)    the best-Floatie pedestal at the entrance

	Models have attributes OwnerUserId and Uid; the client uses them to open
	the Floatie card when you click / press E on your own Floatie.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
local PumpModel = require(Shared:WaitForChild("PumpModel"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)

local Bases = {}

local bases = {}  -- MapBuilder's base tables, plus owner / models
Bases.list = bases

local LOCKED_COLOR = Color3.fromRGB(110, 110, 125)

function Bases.init(map)
	for i, base in ipairs(map.bases) do
		base.owner = nil
		base.models = {} -- [uid] = Model
		bases[i] = base
		Bases.release(i) -- empty base look: grey pads with padlocks
	end
end

function Bases.get(player)
	local prof = Core.profiles[player]
	return prof and prof.base and bases[prof.base]
end

---------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------
function Bases.slotPart(player, slot)
	local base = Bases.get(player)
	return base and base.slots[slot]
end

-- top of a slot pad; models stand here (their head points along the pad's +X)
local function slotTop(pad)
	return pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0)
end

function Bases.freeSlot(player)
	local prof = Core.profiles[player]
	if not prof then
		return nil
	end
	local used = {}
	for _, f in ipairs(prof.data.floaties) do
		if f.slot then
			used[f.slot] = true
		end
	end
	for s = 1, Economy.slotCount(player) do
		if not used[s] then
			return s
		end
	end
	return nil
end

local function paintPad(base, slot, unlocked)
	local pad = base.slots[slot]
	pad.Color = if unlocked then base.color else LOCKED_COLOR
	pad:SetAttribute("Unlocked", unlocked)
	local lock = base.lockLabels and base.lockLabels[slot]
	if lock then
		lock.Parent.Enabled = not unlocked -- the 🔒 label's SurfaceGui
	end
end

-- unlocked pads take the base color, locked ones go grey with a padlock
function Bases.paintPads(player)
	local base = Bases.get(player)
	if not base then
		return
	end
	local count = Economy.slotCount(player)
	for slot in ipairs(base.slots) do
		paintPad(base, slot, slot <= count)
	end
end

---------------------------------------------------------------------
-- Models
---------------------------------------------------------------------
function Bases.label(player, f, model)
	local def = Config.FloatieById[f.id]
	if def and model then
		FloatieModel.SetLabel(model, f, Economy.floatieIncome(player, f))
	end
end

function Bases.model(player, uid)
	local base = Bases.get(player)
	return base and base.models[uid]
end

function Bases.unplace(player, uid)
	local base = Bases.get(player)
	if not base then
		return
	end
	local model = base.models[uid]
	if model then
		model:Destroy()
		base.models[uid] = nil
	end
end

-- (re)builds f's model on its slot; removes it when f is not on a usable slot
function Bases.place(player, f)
	local base = Bases.get(player)
	local prof = Core.profiles[player]
	if not base or not prof then
		return nil
	end
	Bases.unplace(player, f.uid)
	if not Economy.isPlaced(player, f) then
		return nil
	end
	local def = Config.FloatieById[f.id]
	local pad = base.slots[f.slot]
	if not def or not pad then
		return nil
	end
	local model = FloatieModel.Build(def, f.mut, Formulas.size(f.level).scale)
	FloatieModel.SetAnchored(model, true)
	model:PivotTo(slotTop(pad))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", f.uid)
	model:SetAttribute("Slot", f.slot)
	-- E next to your own Floatie opens its card (the client only shows this to the owner)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ManagePrompt"
	prompt.ActionText = "Manage"
	prompt.ObjectText = def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("Uid", f.uid)
	prompt.Parent = model:FindFirstChild("Body") or model.PrimaryPart
	CollectionService:AddTag(prompt, "OwnerPrompt")
	CollectionService:AddTag(prompt, "FloatiePrompt")
	model.Parent = base.floatieFolder
	base.models[f.uid] = model
	Bases.label(player, f, model)
	return model
end

function Bases.refresh(player)
	local base = Bases.get(player)
	local prof = Core.profiles[player]
	if not base or not prof then
		return
	end
	for uid in pairs(base.models) do
		Bases.unplace(player, uid)
	end
	for _, f in ipairs(prof.data.floaties) do
		Bases.place(player, f)
	end
	Bases.paintPads(player)
end

function Bases.refreshLabels(player)
	local prof = Core.profiles[player]
	local base = Bases.get(player)
	if not prof or not base then
		return
	end
	for _, f in ipairs(prof.data.floaties) do
		local model = base.models[f.uid]
		if model then
			Bases.label(player, f, model)
		end
	end
end

---------------------------------------------------------------------
-- The best-Floatie pedestal at the entrance
---------------------------------------------------------------------
-- the Floatie earning the most (on a slot or not), or nil
function Bases.bestFloatie(player)
	local prof = Core.profiles[player]
	if not prof then
		return nil
	end
	local best, bestIncome = nil, -1
	for _, f in ipairs(prof.data.floaties) do
		local income = Formulas.baseIncome(f)
		if income > bestIncome then
			best, bestIncome = f, income
		end
	end
	return best
end

function Bases.refreshBest(player)
	local base = Bases.get(player)
	if not base or not base.bestSpot then
		return
	end
	local f = Bases.bestFloatie(player)
	local key = f and (f.uid .. "|" .. f.level .. "|" .. f.mut) or ""
	if base.bestKey == key then
		return
	end
	base.bestKey = key
	if base.bestModel then
		base.bestModel:Destroy()
		base.bestModel = nil
	end
	if not f then
		base.bestLabel.Text = "⭐ BEST FLOATIE"
		return
	end
	local def = Config.FloatieById[f.id]
	local model = FloatieModel.Build(def, f.mut, 1.15)
	FloatieModel.SetAnchored(model, true)
	model:PivotTo(base.bestSpot)
	local label = model.PrimaryPart:FindFirstChild("Label")
	if label then
		label:Destroy() -- the pedestal has its own sign
	end
	model.Parent = base.floatieFolder
	base.bestModel = model
	base.bestLabel.Text = "⭐ BEST: " .. (if f.mut ~= "Normal" then f.mut .. " " else "") .. def.name
end

---------------------------------------------------------------------
-- The Pump Machine: the equipped pump stands on the platform at the back
---------------------------------------------------------------------
function Bases.refreshPump(player)
	local base = Bases.get(player)
	local prof = Core.profiles[player]
	if not base or not prof or not base.pumpFolder then
		return
	end
	local tier = prof.data.pumps.equipped
	if base.pumpTier == tier then
		return
	end
	base.pumpTier = tier
	base.pumpFolder:ClearAllChildren()
	local model = PumpModel.Build(tier)
	model:PivotTo(base.pumpSpot)
	model.Parent = base.pumpFolder
end

---------------------------------------------------------------------
-- Owners
---------------------------------------------------------------------
local function setOwnerText(base, text)
	base.signLabel.Text = text
	for _, label in ipairs(base.archLabels or {}) do
		label.Text = text
	end
end

function Bases.assign(player)
	for i, base in ipairs(bases) do
		if not base.owner then
			base.owner = player
			base.folder:SetAttribute("OwnerUserId", player.UserId)
			setOwnerText(base, player.DisplayName .. "'s Base")
			return i
		end
	end
	return nil
end

function Bases.release(index)
	local base = bases[index]
	if not base then
		return
	end
	for _, model in pairs(base.models) do
		model:Destroy()
	end
	base.models = {}
	if base.bestModel then
		base.bestModel:Destroy()
		base.bestModel = nil
	end
	base.bestKey = nil
	if base.bestLabel then
		base.bestLabel.Text = "⭐ BEST FLOATIE"
	end
	base.owner = nil
	base.folder:SetAttribute("OwnerUserId", 0)
	setOwnerText(base, "Empty Base")
	for slot in ipairs(base.slots) do
		paintPad(base, slot, false)
	end
	-- an empty base shows the basic Hand Pump
	if base.pumpFolder and base.pumpTier ~= 1 then
		base.pumpTier = 1
		base.pumpFolder:ClearAllChildren()
		local model = PumpModel.Build(1)
		model:PivotTo(base.pumpSpot)
		model.Parent = base.pumpFolder
	end
end

-- the pedestal follows your Floaties; the pump follows the one you equip
Core.FloatiesChanged:Connect(function(player)
	if player.Parent then
		Bases.refreshBest(player)
	end
end)
Core.StatsChanged:Connect(function(player)
	if player.Parent then
		Bases.refreshPump(player)
	end
end)
Core.PlayerLoaded:Connect(function(player)
	Bases.refreshPump(player)
	Bases.refreshBest(player)
end)

-- labels show Air/s with your Cash: refresh them every few seconds
task.spawn(function()
	while true do
		task.wait(3)
		for player in Core.eachLoaded() do
			Bases.refreshLabels(player)
		end
	end
end)

return Bases
