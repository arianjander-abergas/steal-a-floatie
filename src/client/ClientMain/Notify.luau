--[[
	Floatie Farm — Notify (ModuleScript child of the ClientMain LocalScript)
	Toasts: the short colored messages under the top bar ("Sold 3 Floaties
	for 1.2K Air", "Coming soon!", ...). They live on their own "FloatieToasts"
	screen, so they show above open panels.

	The server sends them through Remotes.Notify (text, kind); client code
	calls Notify.toast directly. kind picks the color (Config.UI.Toast) and
	the sound: info (default), success, error, alert, event.

	Server announcements (very rare pulls) are not toasts: they come through
	Remotes.ChatMessage and go in the chat window only (Notify.chat).

	API:
	  Notify.mount(canvas)        -- builds the "Toasts" holder, listens to Remotes.Notify + ChatMessage
	  Notify.follow(frame)        -- sit just below this frame's content (the HUD's TopStack)
	  Notify.toast(text, kind?)   -- works before mount too (queued, up to 5)
	  Notify.chat(text, rarity?)  -- a system line in the chat window, colored like that rarity
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Sounds = require(script.Parent.Sounds)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRE = remotes:WaitForChild("Notify")
local ChatRE = remotes:WaitForChild("ChatMessage")

local C = Config.UI

local MAX_SHOWN = 4        -- toasts on screen at once; a 5th pushes the oldest out
local MAX_QUEUED = 5       -- toasts kept from before mount
local TOAST_HEIGHT = 26    -- every toast row (long text shrinks to fit instead of growing the row)
local GAP = 4              -- space between toasts (the UIListLayout padding)
local HOLDER_HEIGHT = MAX_SHOWN * TOAST_HEIGHT + (MAX_SHOWN - 1) * GAP -- 116: the "Toasts" box fits exactly 4
local TOAST_SOUNDS = { success = "Buy", error = "Error", alert = "Alert", event = "Event" }

local Notify = {}

local holder = nil  -- the "Toasts" frame (nil until mount)
local live = {}     -- toast frames on screen, oldest first
local queued = {}   -- { { text, kind } } waiting for mount
local toastOrder = 0

---------------------------------------------------------------------
-- Showing a toast
---------------------------------------------------------------------
local function forget(frame)
	local i = table.find(live, frame)
	if i then
		table.remove(live, i)
	end
end

-- fade the plate, its text and every outline/border out, then remove it
local function fadeOut(frame, textLabel)
	Kit.tween(frame, 0.4, { BackgroundTransparency = 1 })
	Kit.tween(textLabel, 0.4, { TextTransparency = 1 })
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("UIStroke") then
			Kit.tween(d, 0.4, { Transparency = 1 })
		end
	end
	task.wait(0.45)
	forget(frame)
	frame:Destroy()
end

local function show(text, kind)
	toastOrder += 1
	if TOAST_SOUNDS[kind] then
		Sounds.play(TOAST_SOUNDS[kind])
	end

	-- make room: with 4 on screen the oldest goes first (all rows are the
	-- same height, so 4 always fit the holder)
	while #live >= MAX_SHOWN do
		table.remove(live, 1):Destroy()
	end

	local frame = Kit.plate(holder, {
		Name = "Toast", Size = UDim2.new(1, 0, 0, TOAST_HEIGHT), LayoutOrder = toastOrder, BackgroundTransparency = 0.1,
	}, { color = C.Toast[kind] or C.Toast.info, radius = 10, border = 2 })
	local textLabel = Kit.label(frame, {
		Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -4), Text = text,
		TextWrapped = true, -- a long server message may wrap onto two lines if that keeps its text bigger
	}, { maxTextSize = 20 })
	table.insert(live, frame)

	task.delay(if kind == "alert" then 6 else 4, function()
		if frame.Parent then -- not already pushed out by newer toasts
			fadeOut(frame, textLabel)
		end
	end)
end

-- Notify.toast(text, kind?) — kind = "info" | "success" | "error" | "alert" | "event"
function Notify.toast(text, kind)
	text = tostring(text or "")
	if not holder then
		-- too early (the screen isn't built yet): keep the newest few for mount
		table.insert(queued, { text, kind })
		if #queued > MAX_QUEUED then
			table.remove(queued, 1)
		end
		return
	end
	show(text, kind)
end

---------------------------------------------------------------------
-- Chat lines
---------------------------------------------------------------------
local CHAT_COLOR = Color3.fromRGB(255, 220, 90) -- lines without a rarity

local function escapeRichText(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;"))
end

-- Notify.chat(text, rarity?) — works with the new chat (TextChatService)
-- and, in places still on it, the legacy chat
function Notify.chat(text, rarity)
	text = tostring(text or "")
	local color = if rarity then Kit.rarityTextColor(rarity) else CHAT_COLOR
	task.spawn(function()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			-- the legacy chat may still be starting: try for a few seconds
			for _ = 1, 10 do
				local ok = pcall(StarterGui.SetCore, StarterGui, "ChatMakeSystemMessage", {
					Text = text, Color = color, Font = Enum.Font.GothamBold, TextSize = 18,
				})
				if ok then
					return
				end
				task.wait(1)
			end
		end
		local channels = TextChatService:FindFirstChild("TextChannels")
		local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
		if channel then
			pcall(channel.DisplaySystemMessage, channel,
				('<font color="#%s"><b>%s</b></font>'):format(color:ToHex(), escapeRichText(text)))
		end
	end)
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------

-- Notify.mount(canvas) — canvas = the FloatieToasts Kit canvas.
-- Top-center, 340x116 virtual px: room for 4 toasts of 26 px. It starts
-- under the top bar; Notify.follow keeps it under the event banner and
-- tutorial boxes, so the bottom of the screen stays free for rolling.
local TOP_Y = 58
function Notify.mount(canvas)
	if holder then
		return
	end
	holder = Kit.make("Frame", {
		Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP_Y),
		Size = UDim2.fromOffset(340, HOLDER_HEIGHT), BackgroundTransparency = 1,
	}, canvas)
	Kit.make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)

	NotifyRE.OnClientEvent:Connect(Notify.toast)
	ChatRE.OnClientEvent:Connect(Notify.chat)

	-- show anything that arrived before the screen existed
	local pending = queued
	queued = {}
	for _, item in ipairs(pending) do
		show(item[1], item[2])
	end
end

-- Notify.follow(frame) — frame has a UIListLayout (the HUD's TopStack): the
-- toasts sit 6 px below whatever it shows right now
function Notify.follow(frame)
	local layout = frame and frame:FindFirstChildOfClass("UIListLayout")
	if not holder or not layout then
		return
	end
	local function place()
		local h = layout.AbsoluteContentSize.Y / math.max(Kit.getScale(), 0.01)
		holder.Position = UDim2.new(0.5, 0, 0, TOP_Y + (if h > 1 then h + 6 else 0))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(place)
	Kit.ScaleChanged:Connect(place)
	place()
end

return Notify
