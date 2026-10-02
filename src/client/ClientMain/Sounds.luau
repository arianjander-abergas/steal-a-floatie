--[[
	Floatie Farm — Sounds (ModuleScript child of the ClientMain LocalScript)
	Builds one Sound template per entry in Config.Sounds (edit the ids there)
	and plays them: flat UI sounds through SoundService, or 3D at a part.
	Kit buttons play "Click" through Kit.setSoundPlayer(Sounds.play), which
	init sets up, so Kit never has to require this module.

	API:
	  Sounds.init()                -- builds the templates, starts Music; safe to call twice
	  Sounds.play(name, atPart?)   -- no-op for unknown names or "" ids
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local templates = {} -- name -> Sound (in SoundService)
local started = false

-- same as Kit.make (this module may not require Kit): props first, Parent last
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

---------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------

-- Sounds.init() — builds the templates and starts the looping Music
function Sounds.init()
	if started then
		return
	end
	started = true
	for name, info in pairs(Config.Sounds) do
		if info.id ~= "" then
			templates[name] = make("Sound", {
				Name = name, SoundId = info.id, Volume = info.volume or 0.5,
				PlaybackSpeed = info.pitch or 1, Looped = name == "Music",
			}, SoundService)
		end
	end
	if templates.Music then
		templates.Music:Play()
	end
end

---------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------

-- Sounds.play(name, atPart?) — atPart plays it in 3D where it happens
-- (a copy that cleans itself up); otherwise it plays flat for this player.
function Sounds.play(name, atPart)
	local s = templates[name]
	if not s then
		return
	end
	if atPart then
		local copy = s:Clone()
		copy.RollOffMaxDistance = 150
		copy.Parent = atPart
		copy:Play()
		copy.Ended:Connect(function()
			copy:Destroy()
		end)
	else
		SoundService:PlayLocalSound(s)
	end
end

return Sounds
