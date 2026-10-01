--[[
	Events (ModuleScript in ServerScriptService.Server)
	Server-wide events: one random event every Config.EventInterval seconds
	(only while someone is playing), or started by the admin / the Server
	Luck Boost product.

	The running event is published on ReplicatedStorage so everyone can read it:
	  Event        name ("" when none)      EventEndsAt   server time it ends
	  NextEventAt  server time the next random event starts
	Economy.activeEvent() reads them; Luck / Cash / mutation chances follow.

	  Events.start(name, byName?) -> true when the name exists
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Core = require(script.Parent.Core)
local Economy = require(script.Parent.Economy)

local Events = {}

local nextEventAt = Core.now() + Config.EventInterval
ReplicatedStorage:SetAttribute("Event", "")
ReplicatedStorage:SetAttribute("EventEndsAt", 0)
ReplicatedStorage:SetAttribute("NextEventAt", nextEventAt)

local function everyoneChanged()
	for player in Core.eachLoaded() do
		Core.StatsChanged:Fire(player)
	end
end

function Events.start(name, byName)
	local ev = Config.Events[name]
	if not ev then
		return false
	end
	ReplicatedStorage:SetAttribute("Event", name)
	ReplicatedStorage:SetAttribute("EventEndsAt", Core.now() + ev.duration)
	nextEventAt = Core.now() + ev.duration + Config.EventInterval
	ReplicatedStorage:SetAttribute("NextEventAt", nextEventAt)
	local thanks = if byName then " (thanks " .. byName .. "!)" else ""
	Core.notifyAll(ev.title .. " — " .. ev.desc .. thanks, "event")
	everyoneChanged() -- Luck / Cash / income change right away
	return true
end

function Events.names()
	local names = {}
	for name in pairs(Config.Events) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

task.spawn(function()
	while true do
		task.wait(1)
		local running = (ReplicatedStorage:GetAttribute("Event") or "") ~= ""
		local ev = Economy.activeEvent()
		if running and not ev then
			ReplicatedStorage:SetAttribute("Event", "")
			everyoneChanged()
		end
		if not ev and Core.now() >= nextEventAt and #Players:GetPlayers() > 0 then
			local names = Events.names()
			Events.start(names[Core.rng:NextInteger(1, #names)])
		end
	end
end)

return Events
