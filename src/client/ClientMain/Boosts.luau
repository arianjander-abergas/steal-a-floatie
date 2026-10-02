--[[
	Floatie Farm — Boosts (ModuleScript child of the ClientMain LocalScript)
	Small HUD pieces about what is boosting you right now:
	  • FriendBoost  "👥 +10%" next to the 🚀 badge, with a + button that opens
	                 Roblox's invite prompt (+10% Air per friend in the
	                 server, up to +40%; Config.FriendBoost)
	  • Potions      one bubble per running potion with its time left. Right
	                 side, under Luck / Cash; above them on touch screens,
	                 where the event timer moves up out of the jump button's way.
	                 Tap a bubble to see what it does.

	API:
	  Boosts.mount(canvas)
	  Boosts.update()   -- init's 0.2 s loop (the potion timers)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)

local player = Players.LocalPlayer
local C = Config.UI

local Boosts = {}

local BUBBLE = 40
local CELL = Vector2.new(46, 56)

local mounted = false
local potionRow = nil
local bubbles = {} -- kind -> { cell, time }

---------------------------------------------------------------------
-- Friend Boost
---------------------------------------------------------------------
local function invite()
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		Notify.toast("Invites aren't available here. Play with friends for +10% Air each!", "info")
	end
end

local function mountFriendBoost(canvas)
	local plate = Kit.plate(canvas, {
		Name = "FriendBoost", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 98, 1, -74),
		Size = UDim2.fromOffset(84, 22),
	}, { gradient = true, color = C.Grey, radius = 11, border = 2 })
	local text = Kit.label(plate, {
		Name = "Label", Position = UDim2.fromOffset(4, 1), Size = UDim2.new(1, -8, 1, -2),
	}, { maxTextSize = 18 })
	local add = Kit.button(canvas, {
		Name = "InviteFriends", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 186, 1, -73),
		Size = UDim2.fromOffset(24, 24),
	}, { text = "+", color = C.Green, maxTextSize = 20, radius = 8, border = 2 })
	Kit.onClick(add, invite)

	local function refresh()
		local p = tonumber(player:GetAttribute("FriendBoost")) or 0
		text.Text = "👥 +" .. p .. "%"
		local g = plate:FindFirstChild("Gradient")
		if g then
			local color = if p > 0 then C.Teal else C.Grey
			g.Color = ColorSequence.new(Kit.shade(color, 0.3), Kit.shade(color, -0.2))
		end
	end
	player:GetAttributeChangedSignal("FriendBoost"):Connect(refresh)
	refresh()
end

---------------------------------------------------------------------
-- Potion bubbles
---------------------------------------------------------------------
local function placeRow()
	if UserInputService.TouchEnabled then
		-- above Luck / Cash (the RightStack is 68 tall around y = 0.5 - 44)
		potionRow.AnchorPoint = Vector2.new(1, 1)
		potionRow.Position = UDim2.new(1, -8, 0.5, -84)
	else
		-- under Luck / Cash
		potionRow.AnchorPoint = Vector2.new(1, 0)
		potionRow.Position = UDim2.new(1, -8, 0.5, -4)
	end
end

local function mountPotions(canvas)
	potionRow = Kit.make("Frame", {
		Name = "Potions", Size = UDim2.fromOffset(150, CELL.Y), BackgroundTransparency = 1,
	}, canvas)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, potionRow)
	placeRow()

	for i, kind in ipairs(Config.PotionOrder) do
		local info = Config.Potions[kind]
		local cell = Kit.make("Frame", {
			Name = kind, Size = UDim2.fromOffset(CELL.X, CELL.Y), BackgroundTransparency = 1, LayoutOrder = i, Visible = false,
		}, potionRow)
		local bubble = Kit.button(cell, {
			Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(BUBBLE, BUBBLE),
		}, { text = "", color = info.color, radius = BUBBLE / 2, border = 2, sound = false })
		Kit.label(bubble.Face, {
			Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.68, 0.68), Text = info.icon, ZIndex = 3,
		}, { outline = 0 })
		Kit.label(bubble, {
			Name = "Mult", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -4),
			Size = UDim2.fromOffset(26, 16), Text = Config.FormatMult(info.mult), ZIndex = 4, Rotation = 10,
			TextColor3 = C.Yellow,
		}, { outline = 2, maxTextSize = 15 })
		local time = Kit.label(cell, {
			Name = "Time", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 4, 0, 16),
		}, { outline = 2, maxTextSize = 15 })
		Kit.onClick(bubble, function()
			local endsAt = tonumber(player:GetAttribute("PotionEnds_" .. kind)) or 0
			local left = endsAt - workspace:GetServerTimeNow()
			Notify.toast(("%s %s: %s (%s left)"):format(info.icon, info.name, info.desc, Config.FormatTime(left)), "info")
		end)
		bubbles[kind] = { cell = cell, time = time }
	end
end

function Boosts.mount(canvas)
	if mounted then
		return
	end
	mounted = true
	mountFriendBoost(canvas)
	mountPotions(canvas)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(placeRow)
	Boosts.update()
end

function Boosts.update()
	if not mounted then
		return
	end
	local now = workspace:GetServerTimeNow()
	for kind, b in pairs(bubbles) do
		local endsAt = tonumber(player:GetAttribute("PotionEnds_" .. kind)) or 0
		local left = endsAt - now
		local show = left > 0
		if b.cell.Visible ~= show then
			b.cell.Visible = show
		end
		if show then
			b.time.Text = Config.FormatTime(left)
			b.time.TextColor3 = if left < 60 then C.Bad else C.Text
		end
	end
end

return Boosts
