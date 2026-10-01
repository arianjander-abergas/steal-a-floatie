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

	Models have attributes OwnerUserId and Uid; the client uses them to open
	the Floatie card when you click / press E on your own Floatie.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))
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

-- unlocked pads take the base color, locked ones go grey
function Bases.paintPads(player)
	local base = Bases.get(player)
	if not base then
		return
	end
	local count = Economy.slotCount(player)
	for slot, pad in ipairs(base.slots) do
		local unlocked = slot <= count
		pad.Color = if unlocked then base.color else LOCKED_COLOR
		pad.Material = if unlocked then Enum.Material.SmoothPlastic else Enum.Material.Slate
		pad:SetAttribute("Unlocked", unlocked)
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
-- Owners
---------------------------------------------------------------------
function Bases.assign(player)
	for i, base in ipairs(bases) do
		if not base.owner then
			base.owner = player
			base.folder:SetAttribute("OwnerUserId", player.UserId)
			base.signLabel.Text = player.DisplayName .. "'s Base"
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
	base.owner = nil
	base.folder:SetAttribute("OwnerUserId", 0)
	base.signLabel.Text = "Empty Base"
	for _, pad in ipairs(base.slots) do
		pad.Color = LOCKED_COLOR
		pad.Material = Enum.Material.Slate
		pad:SetAttribute("Unlocked", false)
	end
end

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
