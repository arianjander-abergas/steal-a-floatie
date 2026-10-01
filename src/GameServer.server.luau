--[[
	Floatie Farm — GameServer (Script in ServerScriptService)

	The game in one loop:
	  Roll your pump -> a Floatie inflates and rides your conveyor home -> it
	  stands on a slot and earns Air (even offline) -> spend Air on better
	  pumps, upgrades and Level Ups -> roll again.
	On top: grades and traits, rebirth, the Index, daily + playtime rewards,
	potions, events, trading.

	This script only starts things up and handles players joining / leaving /
	saving. Each system is its own module in ServerScriptService.Server:
	  Core         shared state, remotes, toasts, signals
	  DataService  saving + loading (format v2, session locking)
	  Sync         keeps each client's copy of its save up to date
	  MapBuilder   builds the map
	  Economy      Luck / Cash / income math + the income loop
	  Bases        who owns which base, Floatie models on slots
	  Floaties     add / equip / level up / sell / lock
	  Rolling      the pull: luck, mutations, Auto Roll, the conveyor ride
	  Grant        gives rewards (Air, potions, tokens, Floaties...)
	  Events       random server events
	  Rewards      daily + playtime rewards, codes
	  Rebirth      rebirth
	  Shop         game passes + developer products
	  Plaza        leaderboards, best Floatie in the server, event sign, Tower door
	  Admin        ;chat commands for testing
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ServerFolder = script.Parent:WaitForChild("Server")

local Core = require(ServerFolder:WaitForChild("Core"))
local DataService = require(ServerFolder:WaitForChild("DataService"))
local Sync = require(ServerFolder:WaitForChild("Sync"))
local MapBuilder = require(ServerFolder:WaitForChild("MapBuilder"))
local Economy = require(ServerFolder:WaitForChild("Economy"))
local Bases = require(ServerFolder:WaitForChild("Bases"))
require(ServerFolder:WaitForChild("Floaties"))
require(ServerFolder:WaitForChild("Rolling"))
require(ServerFolder:WaitForChild("Grant"))
local Events = require(ServerFolder:WaitForChild("Events"))
require(ServerFolder:WaitForChild("Rewards"))
require(ServerFolder:WaitForChild("Rebirth"))
local Shop = require(ServerFolder:WaitForChild("Shop"))
local Plaza = require(ServerFolder:WaitForChild("Plaza"))
require(ServerFolder:WaitForChild("Admin"))

---------------------------------------------------------------------
-- The map
---------------------------------------------------------------------
local map = MapBuilder.Build()
Bases.init(map)
Plaza.init(map)

-- Server Luck Boost (Robux): Lucky Breeze for everyone
Shop.handle("ServerLuckBoost", function(player)
	return Events.start("LuckyBreeze", player.DisplayName)
end)

---------------------------------------------------------------------
-- Teleports (top bar: Home / Plaza / Sell)
---------------------------------------------------------------------
local function teleportTarget(player, target)
	local base = Bases.get(player)
	if target == "Home" then
		return base and base.spawn.CFrame * CFrame.new(0, 4, 0)
	end
	local spots = map.teleports or {}
	return spots[target]
end

local function teleport(player, target)
	local prof = Core.getProfile(player)
	if not prof or not Core.throttle(player, "teleport", Config.HomeCooldown - 0.5) then
		return -- rate limit (silent): the HUD waits the full cooldown between clicks
	end
	local cf = teleportTarget(player, target)
	if not cf then
		Core.notify(player, "Coming soon!", "info")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	char:PivotTo(cf)
end

Core.remote("Teleport").OnServerEvent:Connect(function(player, target)
	if target == "Home" or target == "Plaza" or target == "Sell" then
		teleport(player, target)
	end
end)
-- the Stage 1 HUD's Home button
Core.remote("RequestHome").OnServerEvent:Connect(function(player)
	teleport(player, "Home")
end)

---------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum or not Core.profiles[player] then
		return
	end
	hum.WalkSpeed = Economy.walkSpeed(player)
	-- every (re)spawn starts on your own base's spawn pad, facing your Floaties
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local base = Bases.get(player)
	if root and base then
		task.defer(function()
			if character.Parent then
				character:PivotTo(base.spawn.CFrame * CFrame.new(0, 4, 0))
			end
		end)
	end
	if Core.hasPass(player, "VIP") then
		local head = character:WaitForChild("Head", 5)
		if head then
			local gui = Instance.new("BillboardGui")
			gui.Name = "VipTag"
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

---------------------------------------------------------------------
-- Joining
---------------------------------------------------------------------
local function offlineEarnings(player, prof)
	local data = prof.data
	local elapsed = math.max(0, os.time() - (data.lastOnline or os.time()))
	if elapsed < 60 then
		return
	end
	local earned = math.floor(Economy.incomePerSec(player) * Config.OfflineIncomeRate * math.min(elapsed, Config.OfflineIncomeCap))
	if earned <= 0 then
		return
	end
	data.air += earned
	task.delay(3, function()
		if player.Parent then
			Core.notify(player, "💤 While you were away your Floaties earned " .. Config.Format(earned) .. " Air!", "success")
		end
	end)
end

local function makeLeaderstats(player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local air = Instance.new("StringValue")
	air.Name = "Air"
	air.Value = Config.Format(data.air)
	air.Parent = ls
	local rolls = Instance.new("IntValue")
	rolls.Name = "Rolls"
	rolls.Value = data.totalRolls
	rolls.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = ls
	ls.Parent = player
	return { air = air, rolls = rolls, rebirths = rebirths }
end

local function onPlayerAdded(player)
	local data, canSave = DataService.Load(player)
	if not player.Parent then
		if data and canSave then
			DataService.Save(player, { data = data, canSave = true }, true) -- left while loading: free the lock
		end
		return
	end
	if not data then
		player:Kick("We couldn't load your Floaties. Please rejoin in a minute!")
		return
	end
	local baseIndex = Bases.assign(player)
	if not baseIndex then
		player:Kick("This server is full, please join another one!")
		return
	end
	local prof = {
		data = data, canSave = canSave, base = baseIndex, passes = {}, loaded = false,
		incomePerSec = 0, friends = 0, arriving = {},
	}
	Core.profiles[player] = prof
	Shop.loadPasses(player)
	offlineEarnings(player, prof)

	prof.stats = makeLeaderstats(player, data)
	player:SetAttribute("BaseIndex", baseIndex)
	-- brand-new players get the tutorial (see ClientMain/Tutorial)
	player:SetAttribute("ShowTutorial", data.totalRolls == 0 and #data.floaties == 0 and data.rebirths == 0)

	prof.loaded = true
	Bases.refresh(player)
	Sync.full(player)
	Economy.publish(player)
	Core.PlayerLoaded:Fire(player, prof)
	player:SetAttribute("Loaded", true)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
		player.Character:PivotTo(Bases.get(player).spawn.CFrame * CFrame.new(0, 4, 0))
	end

	if not canSave and not RunService:IsStudio() then
		Core.notify(player, "⚠️ Saving is unavailable right now — progress may not save.", "error")
	end
	Core.notify(player, "Welcome to " .. Config.GameName .. "! Press ROLL to pump a Floatie 🎈", "info")
end

local function onPlayerRemoving(player)
	local prof = Core.profiles[player]
	if not prof then
		return
	end
	Core.PlayerLeaving:Fire(player, prof)
	if prof.loaded then
		DataService.Save(player, prof, true)
	end
	Bases.release(prof.base)
	Core.profiles[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

---------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, prof in Core.eachLoaded() do
			task.spawn(function()
				DataService.Save(player, prof)
				if prof.lostLock and player.Parent then
					player:Kick("Your Floaties were loaded in another server. Please rejoin!")
				end
			end)
		end
	end
end)

game:BindToClose(function()
	local threads = 0
	for player, prof in pairs(Core.profiles) do
		if prof.loaded then
			threads += 1
			task.spawn(function()
				DataService.Save(player, prof, true)
				threads -= 1
			end)
		end
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

print(("[%s] server v%s started"):format(Config.GameName, Config.Version))
