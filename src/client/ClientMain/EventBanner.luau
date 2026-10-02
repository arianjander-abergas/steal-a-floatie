--[[
	Floatie Farm — EventBanner (ModuleScript child of the ClientMain LocalScript)
	The purple box under the top bar while a server event runs
	("✨ GOLDEN HOUR  2:41" + what it does), and the time-of-day change
	that goes with each event (Thunderstorm = dusk, Secret Skies = night).

	API:
	  EventBanner.mount(topStack)   -- adds the "EventBanner" box (LayoutOrder 1) to the HUD's TopStack
	  EventBanner.update()          -- init calls this every 0.2 s
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)

local C = Config.UI

-- Lighting.ClockTime per event (anything else = 14, early afternoon)
local EVENT_CLOCK = { Thunderstorm = 18.6, SecretSkies = 0 }

local EventBanner = {}

local box, titleLabel, descLabel = nil, nil, nil
local currentEvent = ""

-- EventBanner.mount(topStack) — hidden until an event starts
function EventBanner.mount(topStack)
	if box then
		return
	end
	box = Kit.plate(topStack, {
		Name = "EventBanner", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 38), Visible = false,
	}, { gradient = true, color = C.EventBanner, radius = 12 })
	titleLabel = Kit.label(box, {
		Name = "Title", Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 22),
	}, { maxTextSize = 22 })
	descLabel = Kit.label(box, {
		Name = "Desc", Position = UDim2.fromOffset(10, 23), Size = UDim2.new(1, -20, 0, 13), TextColor3 = C.EventDesc,
	}, { outline = 1 })
end

-- EventBanner.update() — shows the running event and its time left, and
-- tweens the sky when the event changes (this part works even if the box
-- failed to build)
function EventBanner.update()
	local name = ReplicatedStorage:GetAttribute("Event") or ""
	local endsAt = ReplicatedStorage:GetAttribute("EventEndsAt") or 0
	local left = endsAt - workspace:GetServerTimeNow()
	local ev = Config.Events[name]
	if ev and left > 0 then
		if box then
			box.Visible = true
			titleLabel.Text = ev.title .. "  " .. Config.FormatTime(left)
			descLabel.Text = ev.desc
		end
	else
		if box then
			box.Visible = false
		end
		name = ""
	end
	if name ~= currentEvent then
		currentEvent = name
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = EVENT_CLOCK[name] or 14 }):Play()
	end
end

return EventBanner
