--[[
	Steal a Floatie — HUD (ModuleScript child of the ClientMain LocalScript)
	The always-on screen, drawn on the "FloatieHUD" Kit canvas:
	  • TopBar      Sell / Home / Plaza buttons (top-center)
	  • TopStack    empty list the event / carry / tutorial boxes go into
	  • LeftMenu    wide rainbow Shop button + a grid of square tiles
	  • AirPanel    the big rolling Air number (bottom-left) + "+X Air/s"
	  • BoostBadge  "🚀 +0%" pill above the Air number
	  • RightStack  "Luck: 1.00x" / "Cash: 1.00x"
	  • EventTimer  next random event countdown, or the live event (bottom-right)
	  • Version     game name + version under the timer

	Everything is placed in virtual px on the Kit canvas (at least 800x400,
	see Kit.createScreen), so nothing overlaps on phones. Only buttons are
	interactive; plates and labels stay Active = false so they never block
	the mobile thumbstick.

	API:
	  HUD.mount(canvas, actions) -> { topStack = Frame }   -- actions.togglePanel(name) opens panels
	  HUD.update()               -- init calls this every 0.2 s (event timer text)
	  HUD.addTile(def) -> TextButton
	      def = { name = "Rebirth", icon = "🌟", color = Color3, order = 60, onClick = function() end }
	  HUD.setBadge(name, value)  -- name = "Shop" or a tile name; nil / false / 0 hides the badge
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer
local C = Config.UI

local HUD = {}

---------------------------------------------------------------------
-- Sizes (virtual px, see the layout table in the Stage 1 contract)
---------------------------------------------------------------------
local MENU_WIDTH = 136         -- LeftMenu: Shop button + 2 tiles side by side
local SHOP_HEIGHT = 48
local TILE_SIZE = 64
local TILE_GAP = 8
local MAX_TILE_ROWS = 3        -- the final grid is 6 tiles = 3 rows
local HOME_COOLDOWN = Config.HomeCooldown or 3
local NEXT_EVENT_TEXT = "Time remaining before the next random event!"

---------------------------------------------------------------------
-- State (filled in by mount)
---------------------------------------------------------------------
local mounted = nil            -- the table mount returned, so a second mount is a no-op
local leftMenu = nil
local tilesFrame = nil
local tileButtons = {}         -- tile name -> TextButton
local tileCount = 0
local badges = {}              -- "Shop" / tile name -> Kit Badge
local timer = nil              -- EventTimer plate
local timerCaption = nil
local timerTime = nil
local timerGradient = nil      -- purple gradient, only enabled during an event
local timerLive = false        -- true while the plate shows a running event

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
-- recolor a Kit.plate({ gradient = true }) with the same light-to-dark
-- gradient Kit paints it with
local function paintPlate(plate, color)
	local g = plate:FindFirstChild("Gradient")
	if g then
		g.Color = ColorSequence.new(Kit.shade(color, 0.3), Kit.shade(color, -0.2))
	end
end

-- LeftMenu grows UPWARD as tile rows are added (its bottom edge is fixed):
-- h = 48 + 8 + rows*64 + (rows-1)*8, or just 48 with no tiles
local function layoutLeftMenu()
	if not leftMenu then
		return
	end
	local rows = math.min(math.ceil(tileCount / 2), MAX_TILE_ROWS)
	local h = SHOP_HEIGHT
	if rows > 0 then
		h = SHOP_HEIGHT + TILE_GAP + rows * TILE_SIZE + (rows - 1) * TILE_GAP
	end
	leftMenu.Size = UDim2.fromOffset(MENU_WIDTH, h)
end

-- how far to lift the event timer (virtual px) so the touch jump button
-- never covers it. Roblox's TouchJump puts the button's TOP edge 90 real px
-- above the bottom on small screens (min side <= 500: 70 px button at
-- 1,-90) and 210 real px above it on big ones (120 px button at 1,-210);
-- we clear that by ~10 px. The cap keeps the timer below the RightStack
-- (8 px gap): 132 on a 400-high canvas, more on taller ones (tablets).
local function timerLift()
	local lift = 0
	if UserInputService.TouchEnabled then
		local screen = Kit.getScreenSize()
		local liftPx = if math.min(screen.X, screen.Y) <= 500 then 100 else 220
		local cap = math.floor(Kit.getCanvasSize().Y / 2) - 68
		lift = math.max(0, math.min(math.ceil(liftPx / Kit.getScale()), cap))
	end
	return lift
end

-- dark plate normally, purple gradient while an event is running
local function setTimerLive(live)
	if live == timerLive then
		return
	end
	timerLive = live
	if live then
		timer.BackgroundColor3 = Color3.new(1, 1, 1)
		timer.BackgroundTransparency = 0
		timerGradient.Enabled = true
	else
		timer.BackgroundColor3 = C.HudBg
		timer.BackgroundTransparency = 0.15
		timerGradient.Enabled = false
	end
end

---------------------------------------------------------------------
-- Tiles (square buttons under the Shop button)
---------------------------------------------------------------------
function HUD.addTile(def)
	assert(tilesFrame, "HUD.addTile: call HUD.mount first")
	if tileButtons[def.name] then
		return tileButtons[def.name] -- one tile per name
	end

	local tile = Kit.button(tilesFrame, {
		Name = def.name, Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE), LayoutOrder = def.order or 0,
	}, { text = "", color = def.color or C.Blue })
	-- big emoji in the top 62%, small caption in the bottom 32%
	Kit.label(tile.Face, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.new(1, -10, 0.62, -3), Text = def.icon or "", ZIndex = 3,
	}, { outline = 0 })
	Kit.label(tile.Face, {
		Name = "Caption", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0.32, 0), Text = def.name, ZIndex = 3,
	}, { maxTextSize = 14 })

	-- the badge sits on the hitbox (not the Face) so it doesn't grow on hover
	local badge = Kit.badge(tile)
	badge:set(nil)
	badges[def.name] = badge

	Kit.onClick(tile, function()
		if def.onClick then
			def.onClick()
		end
	end)

	tileButtons[def.name] = tile
	tileCount += 1
	layoutLeftMenu()
	return tile
end

function HUD.setBadge(name, value)
	local badge = badges[name]
	if badge then
		badge:set(value)
	end
end

---------------------------------------------------------------------
-- Event timer (called by init every 0.2 s)
---------------------------------------------------------------------
function HUD.update()
	if not timerTime then -- not mounted (or mount failed before the timer was built)
		return
	end
	local now = workspace:GetServerTimeNow()
	local name = ReplicatedStorage:GetAttribute("Event") or ""
	local endsAt = tonumber(ReplicatedStorage:GetAttribute("EventEndsAt")) or 0
	local ev = Config.Events[name]
	if ev and endsAt - now > 0 then
		setTimerLive(true)
		timerCaption.Text = ev.title
		timerTime.Text = Config.FormatTime(endsAt - now)
	else
		setTimerLive(false)
		timerCaption.Text = NEXT_EVENT_TEXT
		local nextAt = tonumber(ReplicatedStorage:GetAttribute("NextEventAt"))
		if nextAt and nextAt - now > 0 then
			timerTime.Text = Config.FormatTime(nextAt - now)
		else
			timerTime.Text = "Soon!" -- not published yet, or it passed while the server was empty
		end
	end
end

---------------------------------------------------------------------
-- Mount: builds the whole HUD on the given Kit canvas
---------------------------------------------------------------------
function HUD.mount(canvas, actions)
	if mounted then
		return mounted
	end
	actions = actions or {}

	local function togglePanel(name)
		if actions.togglePanel then
			actions.togglePanel(name)
		end
	end

	-----------------------------------------------------------------
	-- TopBar: Sell / Home / Plaza (3 x 96 + 2 x 12 = 312 wide)
	-----------------------------------------------------------------
	local topBar = Kit.make("Frame", {
		Name = "TopBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(312, 46), BackgroundTransparency = 1,
	}, canvas)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, topBar)

	local function topButton(name, text, color, order)
		return Kit.button(topBar, {
			Name = name, Size = UDim2.fromOffset(96, 46), LayoutOrder = order,
		}, { text = text, color = color, maxTextSize = 24 })
	end
	local sell = topButton("Sell", "💰 Sell", C.Green, 1)
	local home = topButton("Home", "🏠 Home", C.Blue, 2)
	local plaza = topButton("Plaza", "🏝️ Plaza", C.Purple, 3)

	-- each button asks the server to teleport us (Home = our base, Plaza =
	-- the middle of the map, Sell = the Sell stall). The server has the real
	-- rate limit; this client-side one just avoids spamming it.
	local lastTeleport = -math.huge
	local warnedNoRemote = false
	local function teleport(target)
		local clock = os.clock()
		if clock - lastTeleport < HOME_COOLDOWN then
			return
		end
		lastTeleport = clock
		-- looked up at click time (never WaitForChild) so an old server can't hang the HUD
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild("Teleport")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(target)
		elseif not warnedNoRemote then
			warnedNoRemote = true
			warn("[HUD] Remotes.Teleport is missing, so the top buttons do nothing")
		end
	end
	Kit.onClick(sell, function()
		teleport("Sell")
	end)
	Kit.onClick(home, function()
		teleport("Home")
	end)
	Kit.onClick(plaza, function()
		teleport("Plaza")
	end)

	-----------------------------------------------------------------
	-- TopStack: init puts the EventBanner / TutorialBox in
	-- here; hidden boxes take no space in the list
	-----------------------------------------------------------------
	local topStack = Kit.make("Frame", {
		Name = "TopStack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(360, 134), BackgroundTransparency = 1,
	}, canvas)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, topStack)

	-----------------------------------------------------------------
	-- LeftMenu: wide Shop button on top, tile grid below. Anchored at
	-- its bottom-left, so extra tile rows grow it upward.
	-----------------------------------------------------------------
	leftMenu = Kit.make("Frame", {
		Name = "LeftMenu", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -106),
		Size = UDim2.fromOffset(MENU_WIDTH, SHOP_HEIGHT), BackgroundTransparency = 1,
	}, canvas)

	local shop = Kit.button(leftMenu, {
		Name = "Shop", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(MENU_WIDTH, SHOP_HEIGHT),
	}, { text = "🛒 SHOP", color = C.Yellow, maxTextSize = 26 })
	Kit.rainbowBorder(shop)
	Kit.shine(shop)
	local shopBadge = Kit.badge(shop)
	shopBadge:set(nil)
	badges.Shop = shopBadge
	Kit.onClick(shop, function()
		togglePanel("Shop")
	end)

	tilesFrame = Kit.make("Frame", {
		Name = "Tiles", Position = UDim2.fromOffset(0, SHOP_HEIGHT + TILE_GAP),
		Size = UDim2.new(1, 0, 1, -(SHOP_HEIGHT + TILE_GAP)), BackgroundTransparency = 1,
	}, leftMenu)
	Kit.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE_SIZE, TILE_SIZE), CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
		FillDirectionMaxCells = 2, SortOrder = Enum.SortOrder.LayoutOrder,
	}, tilesFrame)

	-- Stage 1 tiles (final grid orders: Inventory 10, Index 20, Rewards 30,
	-- Upgrades 40, Items 50, Rebirth 60, Codes 70)
	HUD.addTile({ name = "Rebirth", icon = "🌟", color = C.Orange, order = 60, onClick = function()
		togglePanel("Rebirth")
	end })
	HUD.addTile({ name = "Codes", icon = "🎁", color = C.Blue, order = 70, onClick = function()
		togglePanel("Codes")
	end })

	-----------------------------------------------------------------
	-- AirPanel: cash icon + big rolling Air number + income line
	-----------------------------------------------------------------
	local airPanel = Kit.plate(canvas, {
		Name = "AirPanel", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(210, 62),
	}, { radius = 16 })

	local icon = Kit.plate(airPanel, {
		Name = "Icon", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(50, 50),
	}, { color = C.Yellow, gradient = true, radius = 25, border = 2 })
	Kit.label(icon, {
		Name = "Emoji", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10), Text = "💵",
	}, { outline = 0 })

	-- holder for the pulse UIScale, resting at (62, 2) with size (1-70, 40).
	-- UIScale grows around the AnchorPoint, so anchoring at the left-middle
	-- makes the left-aligned number grow to the right, away from the icon
	local airHolder = Kit.make("Frame", {
		Name = "AirHolder", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 62, 0, 22),
		Size = UDim2.new(1, -70, 0, 40), BackgroundTransparency = 1,
	}, airPanel)
	local airScale = Kit.make("UIScale", { Name = "Pulse", Scale = 1 }, airHolder)
	local airText = Kit.label(airHolder, {
		Name = "AirText", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	}, { outline = 3, maxTextSize = 38 })

	local incomeText = Kit.label(airPanel, {
		Name = "IncomeText", Position = UDim2.fromOffset(62, 42), Size = UDim2.new(1, -70, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Income,
	})
	local function refreshIncome()
		incomeText.Text = "+" .. Config.Format(tonumber(player:GetAttribute("IncomePerSec")) or 0) .. " Air/s"
	end
	player:GetAttributeChangedSignal("IncomePerSec"):Connect(refreshIncome)
	refreshIncome()

	-- pulse: pop up to `peak`, then spring back to 1 (a newer pulse cancels an older one)
	local pulseTween = nil
	local function pulse(peak)
		if pulseTween then
			pulseTween:Cancel()
		end
		local up = Kit.tween(airScale, 0.08, { Scale = peak }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		pulseTween = up
		up.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and pulseTween == up then
				pulseTween = Kit.tween(airScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
		end)
	end

	-- count-up: the server sends Air once a second; the number glides from
	-- what's shown to the new value (quad-out), and drops fast on spending
	local hasAir = player:GetAttribute("Air") ~= nil
	local shown = tonumber(player:GetAttribute("Air")) or 0
	local glideFrom, glideTo, glideStart, glideTime = shown, shown, 0, 1
	local gliding = false
	local lastAirText = nil

	local function showAir()
		local text = Config.Format(shown)
		if text ~= lastAirText then -- only touch .Text when the string changes
			lastAirText = text
			airText.Text = text
		end
	end

	player:GetAttributeChangedSignal("Air"):Connect(function()
		local target = tonumber(player:GetAttribute("Air")) or 0
		if not hasAir then
			-- first value after the save loads: jump straight there (no fake roll-up)
			hasAir = true
			shown = target
			glideTo = target
			gliding = false
			showAir()
			return
		end
		-- the real change since the last server value (glideTo), not the gap to
		-- the partly glided number on screen: a big 1.2 s glide is still ~3%
		-- short at the next 1 s tick, and that leftover must not pulse "big" again
		local gain = target - glideTo
		local seconds
		if target >= shown then
			local income = tonumber(player:GetAttribute("IncomePerSec")) or 0
			local big = gain > 20 * math.max(income, 1)
			seconds = if big then 1.2 else 0.9
			if gain > 0 then
				pulse(if big then 1.2 else 1.06)
			end
		else
			seconds = 0.15 -- spending: fast drop
		end
		glideFrom, glideTo, glideStart, glideTime = shown, target, os.clock(), seconds
		gliding = true
	end)

	RunService.RenderStepped:Connect(function()
		if not gliding then
			return
		end
		local a = math.clamp((os.clock() - glideStart) / glideTime, 0, 1)
		local eased = 1 - (1 - a) ^ 2
		shown = glideFrom + (glideTo - glideFrom) * eased
		if a >= 1 then
			shown = glideTo
			gliding = false
		end
		showAir()
	end)
	showAir()

	-----------------------------------------------------------------
	-- BoostBadge: "🚀 +0%" (grey at 0, orange when boosted)
	-----------------------------------------------------------------
	local boost = Kit.plate(canvas, {
		Name = "BoostBadge", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -74),
		Size = UDim2.fromOffset(84, 22),
	}, { gradient = true, color = C.Grey, radius = 11, border = 2 })
	local boostText = Kit.label(boost, {
		Name = "Label", Position = UDim2.fromOffset(4, 1), Size = UDim2.new(1, -8, 1, -2),
	}, { maxTextSize = 18 })
	local function refreshBoost()
		local p = tonumber(player:GetAttribute("BoostPercent")) or 0
		boostText.Text = "🚀 " .. Kit.formatPercent(p)
		paintPlate(boost, if p > 0 then C.Orange else C.Grey)
	end
	player:GetAttributeChangedSignal("BoostPercent"):Connect(refreshBoost)
	refreshBoost()

	-----------------------------------------------------------------
	-- RightStack: Luck / Cash multipliers (2 x 31 + 6 = 68 tall)
	-----------------------------------------------------------------
	local rightStack = Kit.make("Frame", {
		Name = "RightStack", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, -44),
		Size = UDim2.fromOffset(150, 68), BackgroundTransparency = 1,
	}, canvas)
	Kit.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rightStack)

	local function statPlate(name, order, color, attribute, prefix)
		local plate = Kit.plate(rightStack, {
			Name = name, Size = UDim2.fromOffset(150, 31), LayoutOrder = order,
		}, { radius = 12 })
		local text = Kit.label(plate, {
			Name = "Label", Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -4),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color,
		}, { maxTextSize = 22 })
		local function refresh()
			text.Text = prefix .. Kit.formatMult(tonumber(player:GetAttribute(attribute)) or 1)
		end
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
		refresh()
	end
	statPlate("Luck", 1, C.Luck, "LuckMultiplier", "🍀 Luck: ")
	statPlate("Cash", 2, C.Cash, "CashMultiplier", "💰 Cash: ")

	-----------------------------------------------------------------
	-- EventTimer (text is filled in by HUD.update)
	-----------------------------------------------------------------
	timer = Kit.plate(canvas, {
		Name = "EventTimer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -14),
		Size = UDim2.fromOffset(190, 56),
	})
	timerGradient = Kit.gradient(timer, Kit.shade(C.Purple, 0.3), Kit.shade(C.Purple, -0.2))
	timerGradient.Enabled = false
	timerLive = false
	-- the 44-character caption wraps onto two lines: 30 px tall with a thin
	-- outline so it stays readable at phone scale (~0.8)
	timerCaption = Kit.label(timer, {
		Name = "Caption", Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 30),
		TextWrapped = true, Text = NEXT_EVENT_TEXT,
	}, { outline = 1, maxTextSize = 14 })
	timerTime = Kit.label(timer, {
		Name = "Time", Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 22), Text = "Soon!",
	}, { outline = 3, maxTextSize = 22 })

	-- on touch screens, lift the timer above the jump button
	local function placeTimer()
		timer.Position = UDim2.new(1, -8, 1, -(14 + timerLift()))
	end
	placeTimer()
	Kit.ScaleChanged:Connect(placeTimer)
	-- also on any screen resize: the jump button size rule can change even
	-- when the scale doesn't (e.g. the first layout at scale 1)
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTimer)

	-----------------------------------------------------------------
	-- Version (under the timer)
	-----------------------------------------------------------------
	Kit.label(canvas, {
		Name = "Version", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -2),
		Size = UDim2.fromOffset(150, 10), TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.4,
		Text = Config.GameName .. " v" .. Config.Version,
	}, { outline = 1 })

	HUD.update() -- fill the timer now instead of waiting for init's first loop

	mounted = { topStack = topStack }
	return mounted
end

return HUD
