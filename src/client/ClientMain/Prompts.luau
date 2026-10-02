--[[
	Floatie Farm — Prompts (ModuleScript child of the ClientMain LocalScript)
	  • Stall prompts (tag "StallPrompt", attribute Panel) open their window
	    right here on the client: no trip to the server needed.
	  • Floatie prompts (tag "FloatiePrompt", attribute Uid) and clicking /
	    tapping your own Floatie open its card.
	  • Owner-only prompts (tag "OwnerPrompt", with an OwnerUserId attribute
	    on the prompt or one of its ancestors) only show for that owner.
	The server checks everything again; this just hides prompts that would
	do nothing for you.

	API:
	  Prompts.start(actions)  -- actions.openPanel(name), actions.openCard(uid); waits for workspace.Map.Bases
	  Prompts.update()        -- init calls this every 0.2 s (does nothing before start)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Prompts = {}

local basesFolder = nil -- workspace.Map.Bases (nil until start finds it)

-- the model of one of YOUR Floaties under the screen point, or nil
local function floatieAt(screenPos)
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local node = hit and hit.Instance
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("Uid") then
			if node:GetAttribute("OwnerUserId") == player.UserId then
				return node
			end
			return nil
		end
		node = node.Parent
	end
	return nil
end

-- Prompts.start(actions) — listens for prompts and clicks, then waits for the map
function Prompts.start(actions)
	actions = actions or {}
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, "StallPrompt") and actions.openPanel then
			actions.openPanel(prompt:GetAttribute("Panel"))
		elseif CollectionService:HasTag(prompt, "FloatiePrompt") and actions.openCard then
			actions.openCard(prompt:GetAttribute("Uid"))
		end
	end)
	-- a quick click / tap on your own Floatie (not a camera drag)
	local downAt, downPos = 0, nil
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			downAt, downPos = os.clock(), Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed or not downPos then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if os.clock() - downAt < 0.35 and (pos - downPos).Magnitude < 12 then
				local model = floatieAt(pos)
				if model and actions.openCard then
					actions.openCard(model:GetAttribute("Uid"))
				end
			end
			downPos = nil
		end
	end)
	basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
end

-- Prompts.update() — owner-only prompts
function Prompts.update()
	if not basesFolder then
		return
	end
	for _, prompt in ipairs(CollectionService:GetTagged("OwnerPrompt")) do
		if prompt:IsA("ProximityPrompt") then
			local node, owner = prompt, nil
			while node and owner == nil do
				owner = node:GetAttribute("OwnerUserId")
				node = node.Parent
			end
			prompt.Enabled = owner == player.UserId
		end
	end
end

return Prompts
