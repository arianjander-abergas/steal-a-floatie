--[[
	Steal a Floatie — Knockback (ModuleScript child of the ClientMain LocalScript)
	The server sends a velocity through Remotes.Knockback (darts, pops, wind,
	locked bases); your character owns its own physics, so the client
	applies the shove.

	API:
	  Knockback.start()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnockbackRE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knockback")

local player = Players.LocalPlayer

local Knockback = {}

local started = false

-- Knockback.start()
function Knockback.start()
	if started then
		return
	end
	started = true
	KnockbackRE.OnClientEvent:Connect(function(velocity)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or typeof(velocity) ~= "Vector3" then
			return
		end
		-- jump first so the ground doesn't eat the push
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		hrp.AssemblyLinearVelocity = velocity
	end)
end

return Knockback
