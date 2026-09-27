--[[
	Steal a Floatie — Darts (ModuleScript child of the ClientMain LocalScript)
	The Dart Blaster: shows the gun cursor while it's equipped, and on click
	plays the "Dart" sound and asks the server to fire at the mouse
	(Remotes.FireDart). The server does the aiming checks and the hits;
	the client cooldown just avoids spamming it.

	API:
	  Darts.start()   -- hooks the blaster in your Character and Backpack (and after respawns)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sounds = require(script.Parent.Sounds)

local FireDartRE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireDart")

local player = Players.LocalPlayer

local Darts = {}

-- Tool -> true once its events are connected. A plain table on purpose: the
-- handlers below don't hold the tool, and an Instance's Lua object can be
-- collected while the tool still exists, so a weak key could vanish and the
-- tool would get hooked twice. Entries are removed when the tool is destroyed.
local hooked = {}
local nextShot = 0
local started = false

-- Darts.start()
function Darts.start()
	if started then
		return
	end
	started = true
	local mouse = player:GetMouse()

	local function hookTool(tool)
		if not tool:IsA("Tool") or tool.Name ~= "Dart Blaster" or hooked[tool] then
			return
		end
		hooked[tool] = true
		tool.Destroying:Connect(function()
			hooked[tool] = nil
		end)
		tool.Equipped:Connect(function()
			mouse.Icon = "rbxasset://textures/GunCursor.png"
		end)
		tool.Unequipped:Connect(function()
			mouse.Icon = ""
		end)
		tool.Activated:Connect(function()
			local clock = os.clock()
			if clock < nextShot then
				return
			end
			nextShot = clock + Config.DartCooldown
			Sounds.play("Dart")
			FireDartRE:FireServer(mouse.Hit.Position)
		end)
	end

	-- the blaster moves between Backpack and Character as you equip it
	local function watchContainer(container)
		for _, child in ipairs(container:GetChildren()) do
			hookTool(child)
		end
		container.ChildAdded:Connect(hookTool)
	end

	player.CharacterAdded:Connect(function(character)
		watchContainer(character)
		watchContainer(player:WaitForChild("Backpack")) -- each respawn gets a new Backpack
	end)
	if player.Character then
		watchContainer(player.Character)
	end
	watchContainer(player:WaitForChild("Backpack"))
end

return Darts
