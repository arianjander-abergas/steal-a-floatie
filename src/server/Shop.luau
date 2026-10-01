--[[
	Shop (ModuleScript in ServerScriptService.Server)
	Robux: game passes, developer products (ProcessReceipt), the Starter Pack
	and the offer ladder. Every id lives in Config (ConfigParts/Robux);
	id 0 = not set up yet (the client shows "Coming soon").

	Products are granted by:
	  • their `grant` reward table (Config.DevProducts[...].grant), or
	  • a handler another module registered: Shop.handle(name, fn(player) -> ok)
	    (Server Luck Boost, Skip All, "Upgrade_<id>" for one upgrade level)
	Receipts are remembered in the save, so a purchase is never granted twice.

	Remote: ClaimOffer (fn, step) — the free first step of the offer ladder
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Core = require(script.Parent.Core)
local DataService = require(script.Parent.DataService)
local Grant = require(script.Parent.Grant)
local Sync = require(script.Parent.Sync)

local Shop = {}

local handlers = {} -- product name -> fn(player) -> ok

function Shop.handle(name, fn)
	handlers[name] = fn
end

---------------------------------------------------------------------
-- Game passes
---------------------------------------------------------------------
function Shop.loadPasses(player)
	local prof = Core.profiles[player]
	for name, info in pairs(Config.GamePasses) do
		if RunService:IsStudio() and Config.TestPassesInStudio then
			prof.passes[name] = true
		elseif info.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
			end)
			if ok and owns then
				prof.passes[name] = true
			end
		end
		player:SetAttribute("Pass_" .. name, prof.passes[name] == true)
	end
end

-- fired with (player, passName) when a pass is bought in-game
Shop.PassBought = Core.signal()

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local prof = Core.profiles[player]
	if not purchased or not prof then
		return
	end
	for name, info in pairs(Config.GamePasses) do
		if info.id == passId and info.id ~= 0 then
			prof.passes[name] = true
			player:SetAttribute("Pass_" .. name, true)
			Core.notify(player, "Thanks for buying " .. info.title .. "! 💖", "success")
			Shop.PassBought:Fire(player, name)
			Core.StatsChanged:Fire(player)
		end
	end
end)

---------------------------------------------------------------------
-- Developer products
---------------------------------------------------------------------
-- product id -> { kind = "product" | "upgrade" | "starter" | "offer", key }
local function lookup(productId)
	if productId == 0 then
		return nil
	end
	for name, info in pairs(Config.DevProducts) do
		if info.id == productId then
			return { kind = "product", key = name }
		end
	end
	for name, id in pairs(Config.UpgradeProducts) do
		if id == productId then
			return { kind = "upgrade", key = name }
		end
	end
	if Config.StarterPack.id == productId then
		return { kind = "starter" }
	end
	for step, offer in ipairs(Config.OfferLadder) do
		if offer.id == productId then
			return { kind = "offer", key = step }
		end
	end
	return nil
end

local function grantProduct(player, found)
	local prof = Core.getProfile(player)
	local data = prof.data
	if found.kind == "product" then
		local handler = handlers[found.key]
		if handler then
			if not handler(player) then
				return false
			end
		else
			Grant.give(player, Config.DevProducts[found.key].grant)
		end
		Core.notify(player, "Purchase complete: " .. Config.DevProducts[found.key].title .. " 💖", "success")
		return true
	elseif found.kind == "upgrade" then
		local handler = handlers["Upgrade_" .. found.key]
		return handler ~= nil and handler(player) == true
	elseif found.kind == "starter" then
		data.starterPack = true
		Sync.field(player, "starterPack")
		local given = Grant.give(player, Config.StarterPack.grant)
		Core.notify(player, "🎁 Starter Pack: " .. table.concat(given, " + "), "success")
		return true
	elseif found.kind == "offer" then
		data.offerLadder = math.max(data.offerLadder, found.key)
		Sync.field(player, "offerLadder")
		local given = Grant.give(player, Config.OfferLadder[found.key].grant)
		Core.notify(player, "🎁 Offer " .. found.key .. ": " .. table.concat(given, " + "), "success")
		return true
	end
	return false
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local prof = player and Core.getProfile(player)
	if not prof then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(prof.data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local found = lookup(receipt.ProductId)
	if not found then
		warn("[Shop] unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, found)
	if not ok or not granted then
		warn("[Shop] could not grant product " .. tostring(receipt.ProductId) .. ": " .. tostring(granted))
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
-- The free first step of the offer ladder
---------------------------------------------------------------------
Core.remote("ClaimOffer", "RemoteFunction").OnServerInvoke = function(player, step)
	local prof = Core.getProfile(player)
	if not prof or not Core.throttle(player, "offer", 1) then
		return false, "Try again"
	end
	local offer = Config.OfferLadder[step]
	if not offer or offer.price ~= 0 then
		return false, "That one isn't free"
	end
	if prof.data.offerLadder >= step then
		return false, "Already claimed"
	end
	if prof.data.offerLadder ~= step - 1 then
		return false, "Claim the earlier offers first"
	end
	prof.data.offerLadder = step
	Sync.field(player, "offerLadder")
	local given = Grant.give(player, offer.grant)
	Core.notify(player, "🎁 Free gift: " .. table.concat(given, " + "), "success")
	return true
end

return Shop
