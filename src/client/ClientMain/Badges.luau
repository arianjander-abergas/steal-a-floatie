--[[
	Floatie Farm — Badges (ModuleScript child of the ClientMain LocalScript)
	The red "!" / number circles on the HUD tiles, so players see when
	something is waiting for them:
	  Rewards   how many Daily + Playtime rewards are ready to claim
	  Index     an Index milestone is ready to claim
	  Upgrades  you can afford an upgrade
	  Rebirth   you can afford the next rebirth
	  Shop      the free gift (step 1 of the offer ladder) is unclaimed

	API:
	  Badges.update()   -- init's slow loop (cheap: a few attribute reads)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.State)
local RewardsPanel = require(script.Parent.RewardsPanel)

local player = Players.LocalPlayer

local Badges = {}

local shown = {} -- name -> last value set, so unchanged badges are left alone

local function set(name, value)
	if value == false or value == 0 then
		value = nil
	end
	if shown[name] ~= value then
		shown[name] = value
		HUD.setBadge(name, value)
	end
end

local function canAffordUpgrade(air)
	local levels = State.data.upgrades
	if not levels then
		return false
	end
	for _, up in ipairs(Config.Upgrades) do
		local cost = Formulas.upgradeCost(up.id, levels[up.id] or 0)
		if cost and cost <= air then
			return true
		end
	end
	return false
end

function Badges.update()
	if not State.ready() then
		return
	end
	local air = tonumber(player:GetAttribute("Air")) or 0
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
	set("Rewards", RewardsPanel.claimable())
	set("Index", player:GetAttribute("IndexReady") == true)
	set("Upgrades", canAffordUpgrade(air))
	set("Rebirth", air >= Formulas.rebirthCost(rebirths))
	local ladder = Config.OfferLadder[1]
	set("Shop", ladder ~= nil and ladder.price == 0 and (State.data.offerLadder or 0) < 1)
end

return Badges
