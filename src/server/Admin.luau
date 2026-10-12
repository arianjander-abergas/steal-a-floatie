--[[
	Admin (ModuleScript in ServerScriptService.Server)
	Chat commands for testing (Studio, the place owner, or Config.AdminUserIds):

	  ;air 1000000                 add Air
	  ;give Dragonflate Ruby Huge 50  a Floatie (mutation, size and level optional, any order)
	  ;event GoldenHour            start an event (HeliumRain, GoldenHour, Thunderstorm, SecretSkies, LuckyBreeze)
	  ;rolls 1000                  set your total rolls (trading unlocks at 1,000)
	  ;potion Luck 3               add potions (Luck, Cash, Mutation)
	  ;tokens 10  ;gems 10  ;jackpot 2
	  ;level 50                    set every Floatie you own to this level
	  ;rebirths 3                  set your rebirth count
	  ;pump 6                      own every pump up to this tier and equip it
	  ;buy QuadLuck                act as if a pass / product was bought (any GamePasses or
	                               DevProducts name, StarterPack, Offer2..Offer5, Upgrade_luck)
	  ;wipe                        (Studio only) start over as a brand-new player
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Core = require(script.Parent.Core)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Bases = require(script.Parent.Bases)
local Floaties = require(script.Parent.Floaties)
local Events = require(script.Parent.Events)
local Shop = require(script.Parent.Shop)
local Sync = require(script.Parent.Sync)

local Admin = {}

local function number(text, default)
	return math.floor(tonumber(text) or default or 0)
end

local COMMANDS = {}

COMMANDS.air = function(player, prof, args)
	Economy.addAir(player, number(args[2]))
end

COMMANDS.give = function(player, prof, args)
	local id = args[2] or ""
	-- ids are case-sensitive in Config; accept any case here
	for _, def in ipairs(Config.Floaties) do
		if string.lower(def.id) == string.lower(id) then
			id = def.id
		end
	end
	-- the rest (any order): a mutation, a size (Huge / Titanic) and a level
	local mut, form, level = "Normal", "Normal", 1
	for i = 3, #args do
		local word = string.lower(args[i])
		for _, m in ipairs(Config.Mutations) do
			if string.lower(m.id) == word then
				mut = m.id
			end
		end
		for _, size in ipairs(Config.Forms) do
			if string.lower(size.id) == word then
				form = size.id
			end
		end
		if tonumber(args[i]) then
			level = number(args[i], 1)
		end
	end
	local f, dest = Floaties.add(player, { id = id, mut = mut, form = form, level = level }, { noAutoSell = true })
	if f then
		Core.notify(player, "Given! (" .. dest .. ")", "success")
	elseif dest == "sold" then
		Core.notify(player, "No room: it was sold", "error")
	else
		Core.notify(player, "Unknown Floatie id", "error")
	end
end

COMMANDS.event = function(player, prof, args)
	if not Events.start(args[2] or "", "the admin") then
		Core.notify(player, "Unknown event. Try " .. table.concat(Events.names(), ", "), "error")
	end
end

COMMANDS.rolls = function(player, prof, args)
	prof.data.totalRolls = math.max(0, number(args[2]))
	Sync.field(player, "totalRolls")
	Core.StatsChanged:Fire(player)
end

COMMANDS.potion = function(player, prof, args)
	local kind = args[2] or ""
	for name in pairs(Config.Potions) do
		if string.lower(name) == string.lower(kind) then
			prof.data.items.potions[name] += number(args[3], 1)
			Sync.field(player, "items")
			return
		end
	end
	Core.notify(player, "Potions: Luck, Cash, Mutation", "error")
end

local function itemCommand(field)
	return function(player, prof, args)
		prof.data.items[field] += number(args[2], 1)
		Sync.field(player, "items")
	end
end
COMMANDS.tokens = itemCommand("gradeTokens")
COMMANDS.gems = itemCommand("traitGems")
COMMANDS.jackpot = itemCommand("jackpotRolls")

COMMANDS.level = function(player, prof, args)
	local level = math.clamp(number(args[2], 1), 1, Config.Levels.Max)
	for _, f in ipairs(prof.data.floaties) do
		f.level = level
		Sync.floatie(player, f)
	end
	Bases.refresh(player)
	Core.FloatiesChanged:Fire(player)
end

COMMANDS.rebirths = function(player, prof, args)
	prof.data.rebirths = math.max(0, number(args[2]))
	Sync.field(player, "rebirths")
	Bases.refresh(player)
	Core.StatsChanged:Fire(player)
end

COMMANDS.pump = function(player, prof, args)
	local tier = math.clamp(number(args[2], 1), 1, #Config.Pumps)
	prof.data.pumps.owned = math.max(prof.data.pumps.owned, tier)
	prof.data.pumps.equipped = tier
	Sync.field(player, "pumps")
	Core.StatsChanged:Fire(player)
end

COMMANDS.buy = function(player, prof, args)
	local name = args[2] or ""
	if not Shop.simulate(player, name) then
		Core.notify(player, "Try ;buy QuadLuck / JackpotRoll / StarterPack / Offer2 / Upgrade_luck", "error")
	end
end

COMMANDS.wipe = function(player, prof)
	if not RunService:IsStudio() then
		Core.notify(player, ";wipe only works in Studio", "error")
		return
	end
	prof.data = DataService.template()
	Bases.refresh(player)
	Sync.full(player)
	Core.StatsChanged:Fire(player)
	Core.FloatiesChanged:Fire(player)
	player:SetAttribute("ShowTutorial", true)
	Core.notify(player, "Wiped: you are a brand-new player now", "success")
end

local function onChatted(player, msg)
	if string.sub(msg, 1, 1) ~= ";" or not Core.isAdmin(player) then
		return
	end
	local prof = Core.getProfile(player)
	if not prof then
		return
	end
	local args = string.split(string.sub(msg, 2), " ")
	local cmd = COMMANDS[string.lower(args[1] or "")]
	if cmd then
		local ok, problem = pcall(cmd, player, prof, args)
		if not ok then
			Core.notify(player, "Command failed: " .. tostring(problem), "error")
		end
	end
end

-- TextChatService chat also fires Player.Chatted
local function watch(player)
	player.Chatted:Connect(function(msg)
		onChatted(player, msg)
	end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end

-- Studio tests can run a command without chatting:
-- game.ServerStorage.AdminCommand:Invoke(player, ";air 1000")
if RunService:IsStudio() then
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "AdminCommand"
	bindable.OnInvoke = function(player, msg)
		onChatted(player, msg)
		return true
	end
	bindable.Parent = game:GetService("ServerStorage")
end

return Admin
