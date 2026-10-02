--[[
	Steal a Floatie — CarryBox (ModuleScript child of the ClientMain LocalScript)
	The red box under the top bar while YOU carry a stolen Floatie:
	"🎈 Pupfloat — RUN HOME!" plus the time left and darts taken.

	API:
	  CarryBox.mount(topStack)   -- adds the "CarryBox" box (LayoutOrder 2) to the HUD's TopStack
	  CarryBox.update()          -- init calls this every 0.2 s
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer
local C = Config.UI

local CarryBox = {}

local box, titleLabel, infoLabel = nil, nil, nil

-- CarryBox.mount(topStack) — same layout as the EventBanner, in red
function CarryBox.mount(topStack)
	if box then
		return
	end
	box = Kit.plate(topStack, {
		Name = "CarryBox", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 38), Visible = false,
	}, { gradient = true, color = C.CarryBox, radius = 12 })
	titleLabel = Kit.label(box, {
		Name = "Title", Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 22),
	}, { maxTextSize = 22 })
	-- white like v0.1.2 (the event's lilac would look muddy on red)
	infoLabel = Kit.label(box, {
		Name = "Desc", Position = UDim2.fromOffset(10, 23), Size = UDim2.new(1, -20, 0, 13),
	}, { outline = 1 })
end

-- CarryBox.update() — the server sets CarryEndsAt while you carry one
function CarryBox.update()
	if not box then
		return
	end
	local endsAt = player:GetAttribute("CarryEndsAt")
	if not endsAt then
		box.Visible = false
		return
	end
	box.Visible = true
	titleLabel.Text = "🎈 " .. (player:GetAttribute("CarryName") or "Floatie") .. " — RUN HOME!"
	local hits = player:GetAttribute("CarryHits") or 0
	local popHits = player:GetAttribute("CarryPopHits") or 1
	infoLabel.Text = "⏱ " .. math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) .. "s   💥 " .. hits .. "/" .. popHits .. " darts"
end

return CarryBox
