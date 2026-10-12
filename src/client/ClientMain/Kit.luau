--[[
	Floatie Farm — Kit (ModuleScript child of the ClientMain LocalScript)
	The UI toolkit every screen and panel is built with:
	  • screens with one responsive "Canvas": lay out in virtual px, Kit scales it for phones
	  • chunky white text with a thick dark outline (UIStroke, never the old text stroke)
	  • rounded gradient buttons that grow on hover, squish on click and play the click sound
	  • dark HUD plates, panels with a bright header bar and a big red X
	  • red "!" badges that wiggle, rainbow borders, shine sweeps
	  • rarity colors, number formatting, and 3D Floatie previews (used from Stage 4)
	Kit only needs Config and FloatieModel, and builds nothing when it is required:
	the modules that own the UI call these functions from their mount/start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FloatieModel = require(Shared:WaitForChild("FloatieModel"))

local Kit = {}

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------
Kit.FONT = Enum.Font.FredokaOne
Kit.C = Config.UI                    -- theme colors (edit them in Config.UI)
Kit.REF_SIZE = Vector2.new(800, 400) -- the smallest virtual canvas (see createScreen)
Kit.MAX_SCALE = 1.4                  -- never draw the UI bigger than 140%

local C = Kit.C
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

---------------------------------------------------------------------
-- Internal state. Keys are weak, so a destroyed button / panel /
-- preview is simply forgotten. (An Instance's Lua object can be
-- collected while the Instance still exists, so a weak key only stays
-- put while something else holds it: here the key's own connection
-- closures do.)
---------------------------------------------------------------------
local buttons = setmetatable({}, { __mode = "k" })          -- hitbox -> button state
local pressedButtons = setmetatable({}, { __mode = "k" })   -- hitbox -> true while held down
local panels = setmetatable({}, { __mode = "k" })           -- Panel -> true
local previews = setmetatable({}, { __mode = "k" })         -- ViewportFrame -> Preview
-- Nothing else holds a rainbow gradient (callers may drop the return value),
-- so this one is a plain table; the rainbow loop removes destroyed ones.
local rainbowGradients = {}                                  -- UIGradient -> true
-- Floatie preview models, one per "floatieId|mutId" (false = failed to build).
-- String keys are never collected, so this one is a plain table.
local templates = {}

local warned = {}
local function warnOnce(key, message)
	if not warned[key] then
		warned[key] = true
		warn("[Kit] " .. message)
	end
end

-- Builders take (parent, props, opts). As a safety net they also accept the
-- short form (props, opts) with no parent, and option keys mixed into props:
-- Instance properties are always PascalCase and options never are, so a
-- known lowercase option key found in props is moved over to opts.
-- Returns fresh tables, so the caller's tables are never changed.
local function splitArgs(parent, props, opts, optionKeys)
	if parent ~= nil and typeof(parent) ~= "Instance" then
		parent, props, opts = nil, parent, props
	end
	local cleanProps, cleanOpts = {}, {}
	if opts then
		for k, v in pairs(opts) do
			cleanOpts[k] = v
		end
	end
	if props then
		for k, v in pairs(props) do
			if optionKeys[k] then
				if cleanOpts[k] == nil then
					cleanOpts[k] = v -- opts wins when both are given
				end
			else
				cleanProps[k] = v
			end
		end
	end
	return parent, cleanProps, cleanOpts
end

---------------------------------------------------------------------
-- Basic builders
---------------------------------------------------------------------

-- Kit.make(className, props?, parent?) -> Instance
-- Same as the old make(): sets every prop, then sets Parent last.
function Kit.make(className, props, parent)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		parent = parent or props.Parent
	end
	inst.Parent = parent
	return inst
end

-- Kit.round(inst, radius?) -> inst   (adds a UICorner, default 12)
function Kit.round(inst, radius)
	Kit.make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, inst)
	return inst
end

-- Kit.stroke(inst, color?, thickness?) -> UIStroke
-- A border-mode stroke named "Border". NOTE: returns the stroke, not inst.
function Kit.stroke(inst, color, thickness)
	return Kit.make("UIStroke", {
		Name = "Border", Color = color or C.Outline, Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
	}, inst)
end

-- Kit.gradient(inst, top, bottom, rotation?) -> UIGradient named "Gradient"
-- rotation 90 (the default) runs top to bottom.
function Kit.gradient(inst, top, bottom, rotation)
	return Kit.make("UIGradient", {
		Name = "Gradient", Color = ColorSequence.new(top, bottom), Rotation = rotation or 90,
	}, inst)
end

-- Kit.shade(color, amount) -> Color3
-- amount > 0 moves toward white, amount < 0 toward black (0.3 = 30% of the way).
function Kit.shade(color, amount)
	if amount > 0 then
		return color:Lerp(WHITE, math.min(amount, 1))
	elseif amount < 0 then
		return color:Lerp(BLACK, math.min(-amount, 1))
	end
	return color
end

-- Kit.tween(inst, seconds, props, style?, direction?) -> Tween (already playing)
function Kit.tween(inst, seconds, props, style, direction)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

-- the light-to-dark look every button, plate and header uses
local function faceColors(color)
	return ColorSequence.new(Kit.shade(color, 0.3), Kit.shade(color, -0.2))
end

---------------------------------------------------------------------
-- Screens and responsive scale.
-- Everything is laid out in virtual px on a Canvas of at least 800x400
-- (exactly that in the tighter direction), then scaled by one UIScale.
---------------------------------------------------------------------
local scaleEvent = Instance.new("BindableEvent")
-- Kit.ScaleChanged:Connect(function(scale) ... end)
-- Fires when the scale changes, and also when the real screen size changes
-- (layout such as the HUD's touch lift depends on both).
Kit.ScaleChanged = scaleEvent.Event

local primaryGui = nil -- the first screen created: getScale and friends read it
local currentScale = 1

-- Kit.createScreen(name, displayOrder) -> (ScreenGui, Canvas Frame)
function Kit.createScreen(name, displayOrder)
	local gui = Kit.make("ScreenGui", {
		Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = displayOrder,
	})
	local canvas = Kit.make("Frame", {
		Name = "Canvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, gui)
	local uiScale = Kit.make("UIScale", { Name = "CanvasScale" }, canvas)

	local isPrimary = primaryGui == nil
	if isPrimary then
		primaryGui = gui
	end
	local lastSize = nil

	local function rescale()
		local abs = gui.AbsoluteSize
		local s = 1
		if abs.X > 0 and abs.Y > 0 then
			s = math.clamp(math.min(abs.X / Kit.REF_SIZE.X, abs.Y / Kit.REF_SIZE.Y), 0.3, Kit.MAX_SCALE)
		end
		uiScale.Scale = s
		-- the canvas is 1/s of the screen, so after scaling it fills the screen exactly
		canvas.Size = UDim2.fromScale(1 / s, 1 / s)
		if isPrimary then
			local changed = s ~= currentScale or abs ~= lastSize
			currentScale = s
			lastSize = abs
			if changed then
				scaleEvent:Fire(s)
			end
		end
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	rescale()
	return gui, canvas
end

-- Kit.getScale() -> number (1 until the first screen exists)
function Kit.getScale()
	return currentScale
end

-- Kit.getScreenSize() -> Vector2 (real px of the first screen)
function Kit.getScreenSize()
	if primaryGui then
		return primaryGui.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Kit.REF_SIZE
end

-- Kit.getCanvasSize() -> Vector2 (virtual px of the first screen's canvas)
function Kit.getCanvasSize()
	return Kit.getScreenSize() / currentScale
end

---------------------------------------------------------------------
-- Sound hook (init registers Sounds.play, so Kit never requires Sounds)
---------------------------------------------------------------------
local soundPlayer = nil

-- Kit.setSoundPlayer(fn: (name) -> ())
function Kit.setSoundPlayer(fn)
	soundPlayer = fn
end

-- Kit.playSound(name) — safe no-op until a sound player is registered
function Kit.playSound(name)
	if not soundPlayer then
		return
	end
	local ok, err = pcall(soundPlayer, name)
	if not ok then
		warnOnce("sound", "sound player failed: " .. tostring(err))
	end
end

---------------------------------------------------------------------
-- Outlined text
---------------------------------------------------------------------
local LABEL_OPTS = { outline = true, outlineColor = true, maxTextSize = true }

-- Kit.label(parent?, props?, opts?) -> TextLabel
-- opts = { outline = 2 (0 = none), outlineColor = C.Outline, maxTextSize = nil }
function Kit.label(parent, props, opts)
	parent, props, opts = splitArgs(parent, props, opts, LABEL_OPTS)
	local base = {
		BackgroundTransparency = 1, Font = Kit.FONT, TextScaled = true, TextColor3 = C.Text,
		Text = "",
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	base.TextStrokeTransparency = 1 -- the outline is the UIStroke below, never the old text stroke
	local lbl = Kit.make("TextLabel", base)

	local outline = opts.outline or 2
	if outline > 0 then
		Kit.make("UIStroke", {
			Name = "Outline", ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = opts.outlineColor or C.Outline, Thickness = outline, LineJoinMode = Enum.LineJoinMode.Round,
		}, lbl)
	end
	if opts.maxTextSize then
		Kit.make("UITextSizeConstraint", { MaxTextSize = opts.maxTextSize }, lbl)
	end
	if parent then
		lbl.Parent = parent
	end
	return lbl
end

---------------------------------------------------------------------
-- Chunky buttons.
-- The returned TextButton is an invisible hitbox; the look lives in
-- hitbox.Face (gradient + border) and hitbox.Face.Label. Animations
-- only resize the Face, so layouts never move.
---------------------------------------------------------------------
local BUTTON_OPTS = {
	text = true, color = true, textColor = true, maxTextSize = true,
	radius = true, border = true, sound = true, animate = true,
}
-- look props that belong on the Face, not the hitbox (safety net)
local BUTTON_LOOK_PROPS = { Text = "text", TextColor3 = "textColor", BackgroundColor3 = "color" }

local HOVER_SCALE = 1.08
local PRESS_SCALE = 0.9

local function lastInputWasTouch()
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

-- repaint the Face gradient (skipped when the color is already showing)
local function paint(st, color)
	if st.painted ~= color then
		st.painted = color
		st.gradient.Color = faceColors(color)
	end
end

local function sizeFace(st, scale, seconds, style)
	st.tween = Kit.tween(st.face, seconds, { Size = UDim2.fromScale(scale, scale) }, style)
end

-- lift a hovered button above its neighbours (and put it back)
local function raise(button, st, up)
	if up and not st.raised then
		st.raised = true
		button.ZIndex += 1
	elseif not up and st.raised then
		st.raised = false
		button.ZIndex -= 1
	end
end

-- snap a button back to its resting look (not hovered, not pressed)
local function resetButton(button)
	local st = buttons[button]
	if not st then
		return
	end
	st.hovered = false
	pressedButtons[button] = nil
	if st.tween then
		st.tween:Cancel()
		st.tween = nil
	end
	st.face.Size = UDim2.fromScale(1, 1)
	raise(button, st, false)
end

-- the press ended: spring back (safe to call twice)
local function release(button)
	if not pressedButtons[button] then
		return
	end
	pressedButtons[button] = nil
	local st = buttons[button]
	if st and st.animate and st.enabled then
		sizeFace(st, if st.hovered then HOVER_SCALE else 1, 0.35, Enum.EasingStyle.Back)
	end
end

-- MouseButton1Up doesn't fire when the finger/mouse slides off a button
-- before letting go, so one shared listener releases any held button.
local releaseConn = nil
local function watchReleases()
	if releaseConn then
		return
	end
	releaseConn = UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			for button in pairs(pressedButtons) do
				release(button)
			end
		end
	end)
end

-- Kit.button(parent?, props?, opts?) -> TextButton
-- props: layout only (Name, Position, Size, AnchorPoint, LayoutOrder, ZIndex, Visible)
-- opts = { text = "", color = C.Green, textColor = C.Text, maxTextSize = 28,
--          radius = 12, border = 3, sound = "Click" (false = silent), animate = true }
function Kit.button(parent, props, opts)
	parent, props, opts = splitArgs(parent, props, opts, BUTTON_OPTS)
	for prop, opt in pairs(BUTTON_LOOK_PROPS) do
		if props[prop] ~= nil then
			if opts[opt] == nil then
				opts[opt] = props[prop]
			end
			props[prop] = nil
		end
	end
	local color = opts.color or C.Green
	local border = opts.border or 3

	local base = { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(120, 44) }
	for k, v in pairs(props) do
		base[k] = v
	end
	local hitbox = Kit.make("TextButton", base)

	local face = Kit.make("Frame", {
		Name = "Face", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1,
	}, hitbox)
	Kit.round(face, opts.radius or 12)
	local gradient = Kit.gradient(face, Kit.shade(color, 0.3), Kit.shade(color, -0.2), 90)
	local borderStroke = Kit.stroke(face, C.Outline, border)
	borderStroke.Enabled = border > 0
	local label = Kit.label(face, {
		Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -6), ZIndex = 3, Text = opts.text or "", TextColor3 = opts.textColor or C.Text,
	}, { outline = 2, maxTextSize = opts.maxTextSize or 28 })

	local st = {
		face = face, label = label, gradient = gradient, border = borderStroke,
		color = color, painted = color, enabled = true,
		animate = opts.animate ~= false,
		sound = if opts.sound == false then false else (opts.sound or "Click"),
		hovered = false, raised = false, tween = nil,
	}
	buttons[hitbox] = st

	hitbox.MouseEnter:Connect(function()
		if lastInputWasTouch() then
			return -- touch screens have no hover (a tap would leave it stuck big)
		end
		st.hovered = true
		if st.animate and st.enabled then
			raise(hitbox, st, true)
			if not pressedButtons[hitbox] then
				sizeFace(st, HOVER_SCALE, 0.12)
			end
		end
	end)
	hitbox.MouseLeave:Connect(function()
		st.hovered = false
		pressedButtons[hitbox] = nil
		if st.animate and st.enabled then
			raise(hitbox, st, false)
			sizeFace(st, 1, 0.12)
		end
	end)
	hitbox.MouseButton1Down:Connect(function()
		if st.animate and st.enabled then
			pressedButtons[hitbox] = true
			watchReleases()
			sizeFace(st, PRESS_SCALE, 0.07)
		end
	end)
	hitbox.MouseButton1Up:Connect(function()
		release(hitbox)
	end)
	-- the global click sound: every Kit button clicks, including later ones
	hitbox.Activated:Connect(function()
		if st.enabled and st.sound then
			Kit.playSound(st.sound)
		end
	end)

	if parent then
		hitbox.Parent = parent
	end
	return hitbox
end

-- Kit.onClick(button, fn) -> RBXScriptConnection
-- Use this instead of button.Activated: fn only runs while the button is enabled.
function Kit.onClick(button, fn)
	return button.Activated:Connect(function()
		if Kit.isEnabled(button) then
			fn()
		end
	end)
end

-- Kit.setButtonText(button, text) — sets button.Face.Label.Text
function Kit.setButtonText(button, text)
	local st = buttons[button]
	local label = st and st.label
	if not label then
		local face = button:FindFirstChild("Face")
		label = face and face:FindFirstChild("Label")
	end
	if label then
		label.Text = text
	elseif button:IsA("TextButton") then
		button.Text = text -- a plain, non-Kit button
	end
end

-- Kit.setButtonColor(button, color) — remembers it; repaints unless disabled
function Kit.setButtonColor(button, color)
	local st = buttons[button]
	if not st then
		button.BackgroundColor3 = color -- a plain, non-Kit button
		return
	end
	st.color = color
	if st.enabled then
		paint(st, color)
	end
end

-- Kit.setEnabled(button, enabled)
-- Disabled = not clickable, grey gradient, faded text, no animations.
function Kit.setEnabled(button, enabled)
	enabled = enabled and true or false
	button.Interactable = enabled
	local st = buttons[button]
	if not st then
		return
	end
	st.enabled = enabled
	if enabled then
		paint(st, st.color)
		st.label.TextTransparency = 0
	else
		resetButton(button)
		paint(st, C.Grey)
		st.label.TextTransparency = 0.25
	end
end

-- Kit.isEnabled(button) -> boolean (true for unknown / non-Kit buttons)
function Kit.isEnabled(button)
	local st = buttons[button]
	if st == nil then
		return true
	end
	return st.enabled
end

---------------------------------------------------------------------
-- Plates (dark HUD backgrounds and colored boxes)
---------------------------------------------------------------------
local PLATE_OPTS = { color = true, transparency = true, gradient = true, radius = true, border = true }

-- Kit.plate(parent?, props?, opts?) -> Frame
-- opts = { color = C.HudBg, transparency = 0.15 (0 with gradient), gradient = false,
--          radius = 14, border = 3 (0 = no stroke) }
function Kit.plate(parent, props, opts)
	parent, props, opts = splitArgs(parent, props, opts, PLATE_OPTS)
	local color = opts.color or C.HudBg
	local border = opts.border or 3
	local base = { BorderSizePixel = 0, Active = false }
	if opts.gradient then
		base.BackgroundColor3 = WHITE -- the "Gradient" below supplies the color
		base.BackgroundTransparency = opts.transparency or 0
	else
		base.BackgroundColor3 = color
		base.BackgroundTransparency = opts.transparency or 0.15
	end
	for k, v in pairs(props) do
		base[k] = v
	end
	local plate = Kit.make("Frame", base)
	Kit.round(plate, opts.radius or 14)
	if opts.gradient then
		Kit.gradient(plate, Kit.shade(color, 0.3), Kit.shade(color, -0.2))
	end
	if border > 0 then
		Kit.stroke(plate, C.Outline, border)
	end
	if parent then
		plate.Parent = parent
	end
	return plate
end

---------------------------------------------------------------------
-- Studs: the LEGO-style dots on panel headers (like the reference games)
---------------------------------------------------------------------

-- Kit.studs(frame, opts?) -> Frame "Studs" (fills `frame`, clipped)
-- opts = { stud = 10, gap = 7, transparency = 0.78, zIndex = 2, width = 900, height = 64 }
function Kit.studs(frame, opts)
	opts = opts or {}
	local stud = opts.stud or 10
	local gap = opts.gap or 7
	local holder = Kit.make("Frame", {
		Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = opts.zIndex or 2, Active = false,
	}, frame)
	Kit.make("UIPadding", { PaddingLeft = UDim.new(0, gap / 2), PaddingTop = UDim.new(0, gap / 2) }, holder)
	Kit.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(stud, stud), CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal,
	}, holder)
	local cols = math.ceil((opts.width or 900) / (stud + gap))
	local rows = math.ceil((opts.height or 64) / (stud + gap))
	for _ = 1, cols * rows do
		local s = Kit.make("Frame", {
			Name = "Stud", BackgroundColor3 = WHITE, BackgroundTransparency = opts.transparency or 0.78,
			BorderSizePixel = 0, ZIndex = opts.zIndex or 2,
		}, holder)
		Kit.round(s, 3)
	end
	return holder
end

---------------------------------------------------------------------
-- Panels (Shop / Rebirth / Codes / ...). Only one is open at a time:
-- opening one closes the others, like the old toggle(). A "stack" panel
-- (opts.stack = true, e.g. the Floatie card or a confirm box) opens ON TOP
-- of the open panel and only closes other stack panels.
---------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

local HEADER_HEIGHT = 48
local FILLER_HEIGHT = 18

-- run a panel callback without letting its errors break the caller
local function runCallback(fn)
	if fn then
		task.spawn(fn)
	end
end

-- hide at once, no animation (another panel is opening)
function Panel:_hideNow()
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end
	local wasOpen = self._open
	self._open = false
	self.frame.Visible = false
	self._pop.Scale = 1
	if wasOpen then
		runCallback(self._onClose)
	end
end

-- panel:open() — closes every other panel instantly (a stack panel only
-- closes other stack panels), then pops this one in
function Panel:open()
	for other in pairs(panels) do
		if other ~= self and (other._open or other.frame.Visible) and (not self._stack or other._stack) then
			other:_hideNow()
		end
	end
	if self._open then
		return
	end
	if self._tween then
		self._tween:Cancel() -- stop a close that is still playing
	end
	-- the X can be left in its hover size if the panel closed under the mouse
	resetButton(self.closeButton)
	self._open = true
	self.frame.Visible = true
	self._pop.Scale = 0.6
	self._tween = Kit.tween(self._pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	runCallback(self._onOpen)
end

-- panel:close() — quick shrink, then hide
function Panel:close()
	if not self._open then
		return
	end
	self._open = false
	if self._tween then
		self._tween:Cancel()
	end
	local tween = Kit.tween(self._pop, 0.1, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	self._tween = tween
	tween.Completed:Connect(function(state)
		-- skipped when open() cancelled this close
		if state == Enum.PlaybackState.Completed and self._tween == tween then
			self._tween = nil
			self.frame.Visible = false
			self._pop.Scale = 1
		end
	end)
	runCallback(self._onClose)
end

function Panel:toggle()
	if self._open then
		self:close()
	else
		self:open()
	end
end

function Panel:isOpen()
	return self._open
end

-- Kit.panel(parent, opts) -> Panel { frame, header, body, closeButton, open, close, toggle, isOpen }
-- opts = { title, icon?, color = C.Blue, size = Vector2.new(460, 330), name = title .. "Panel",
--          onOpen?, onClose?, stack = false }
-- Put all content in panel.body (436x262 virtual px at the default size).
function Kit.panel(parent, opts)
	if opts == nil and parent ~= nil and typeof(parent) ~= "Instance" then
		parent, opts = nil, parent
	end
	opts = opts or {}
	local title = opts.title or ""
	local color = opts.color or C.Blue
	local size = opts.size or Vector2.new(460, 330)
	local top, bottom = Kit.shade(color, 0.3), Kit.shade(color, -0.2)

	local frame = Kit.make("Frame", {
		Name = opts.name or (title .. "Panel"),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20),
		Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Visible = false, ZIndex = if opts.stack then 10 else 1,
		Active = true, -- clicks on a panel must not reach the world behind it
	})
	Kit.round(frame, 18)
	Kit.gradient(frame, C.PanelTop, C.PanelBottom)
	Kit.stroke(frame, C.Outline, 4)
	local pop = Kit.make("UIScale", { Name = "PopScale" }, frame)

	-- bright header bar: rounded on top, square at the bottom
	local header = Kit.make("Frame", {
		Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, frame)
	Kit.round(header, 18)
	Kit.gradient(header, top, bottom)
	-- the filler covers the header's lower rounded corners; its gradient matches
	-- the header's bottom part exactly, so there is no seam
	local filler = Kit.make("Frame", {
		Name = "Filler", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FILLER_HEIGHT), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1,
	}, header)
	Kit.gradient(filler, top:Lerp(bottom, (HEADER_HEIGHT - FILLER_HEIGHT) / HEADER_HEIGHT), bottom)
	-- LEGO studs across the bar
	Kit.studs(header, { width = size.X, height = HEADER_HEIGHT, zIndex = 2 })
	-- a dark line under the bar, like the button borders
	Kit.make("Frame", {
		Name = "Divider", Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = C.Outline, BorderSizePixel = 0, ZIndex = 3,
	}, header)
	Kit.label(header, {
		Name = "Title", Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -80, 1, -8), ZIndex = 4,
		Text = (if opts.icon then opts.icon .. " " else "") .. title, TextXAlignment = Enum.TextXAlignment.Left,
	}, { outline = 3, maxTextSize = 32 })

	-- the big red X, sticking out of the top-right corner
	local closeButton = Kit.button(frame, {
		Name = "Close", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(46, 46), ZIndex = 5,
	}, { text = "X", color = C.Red, maxTextSize = 30 })

	local body = Kit.make("Frame", {
		Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -68),
	}, frame)

	local panel = setmetatable({
		frame = frame, header = header, body = body, closeButton = closeButton,
		_open = false, _pop = pop, _tween = nil, _onOpen = opts.onOpen, _onClose = opts.onClose,
		_stack = opts.stack == true,
	}, Panel)
	Kit.onClick(closeButton, function()
		panel:close()
	end)
	panels[panel] = true
	frame.Destroying:Connect(function()
		panels[panel] = nil
	end)

	if parent then
		frame.Parent = parent
	end
	return panel
end

-- Kit.closeAllPanels()
function Kit.closeAllPanels()
	for panel in pairs(panels) do
		if panel._open then
			panel:close()
		end
	end
end

-- Kit.anyPanelOpen() -> boolean (so popups can wait instead of closing what you're using)
function Kit.anyPanelOpen()
	for panel in pairs(panels) do
		if panel._open then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
-- Badge: the red "!" / number circle on a button
---------------------------------------------------------------------
local WIGGLE = { -14, 12, -8, 0 }

-- Kit.badge(target, opts?) -> Badge { frame, set(self, value) }
-- opts = { color = C.Red, size = 26 }. Pass the button hitbox (not its Face),
-- so the badge doesn't grow with the hover animation.
function Kit.badge(target, opts)
	opts = opts or {}
	local size = opts.size or 26
	local frame = Kit.make("Frame", {
		Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(size, size), BackgroundColor3 = opts.color or C.Red, BorderSizePixel = 0,
		ZIndex = 5, Visible = false, Active = false,
	})
	Kit.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame) -- a circle (a pill when wider)
	Kit.stroke(frame, C.Outline, 2)
	local text = Kit.label(frame, {
		Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6), ZIndex = 6,
	}, { outline = 2 })
	frame.Parent = target

	-- wiggle now, then every 2.5 s while visible; ends when hidden or removed
	local wiggling = false
	local function startWiggle()
		if wiggling then
			return
		end
		wiggling = true
		task.spawn(function()
			while frame.Parent and frame.Visible do
				for _, angle in ipairs(WIGGLE) do
					if not frame.Parent then
						break
					end
					Kit.tween(frame, 0.08, { Rotation = angle })
					task.wait(0.08)
				end
				task.wait(2.5)
			end
			wiggling = false
		end)
	end

	local badge = { frame = frame }
	-- badge:set(nil | false | 0) hides it, true shows "!", a number shows it (99+ above 99),
	-- a string shows as-is
	function badge:set(value)
		local shown
		if value == nil or value == false or value == 0 then
			shown = nil
		elseif value == true then
			shown = "!"
		elseif type(value) == "number" then
			shown = if value > 99 then "99+" else tostring(value)
		else
			shown = tostring(value)
		end
		if shown == nil then
			frame.Visible = false
			return
		end
		text.Text = shown
		-- widen into a pill for 3+ characters
		local extra = math.max(0, (utf8.len(shown) or #shown) - 2)
		frame.Size = UDim2.fromOffset(size + extra * math.floor(size * 0.35), size)
		frame.Visible = true
		startWiggle()
	end
	return badge
end

---------------------------------------------------------------------
-- Rainbow border: one shared RenderStepped spins every rainbow gradient
---------------------------------------------------------------------
local rainbowConn = nil
local function startRainbowLoop()
	if rainbowConn then
		return
	end
	rainbowConn = RunService.RenderStepped:Connect(function()
		local rotation = (os.clock() * 120) % 360
		local any = false
		for g in pairs(rainbowGradients) do
			if g.Parent == nil then
				rainbowGradients[g] = nil -- destroyed (or replaced by a newer rainbowBorder)
			else
				g.Rotation = rotation
				any = true
			end
		end
		if not any then
			rainbowConn:Disconnect()
			rainbowConn = nil
		end
	end)
end

-- Kit.rainbowBorder(target, thickness?) -> UIGradient
-- Works on a Kit button (uses its Face border) or any GuiObject.
function Kit.rainbowBorder(target, thickness)
	local st = buttons[target]
	local border = st and st.border
	if not border then
		border = target:FindFirstChild("Border")
		if not (border and border:IsA("UIStroke")) then
			border = Kit.stroke(target)
		end
	end
	border.Color = WHITE -- the gradient tints white; any other color would darken it
	border.Thickness = thickness or 4
	border.Enabled = true
	local old = border:FindFirstChild("Rainbow")
	if old then
		old:Destroy()
	end
	local keypoints = {}
	for i = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.85, 1)))
	end
	local g = Kit.make("UIGradient", { Name = "Rainbow", Color = ColorSequence.new(keypoints) }, border)
	rainbowGradients[g] = true
	startRainbowLoop()
	return g
end

---------------------------------------------------------------------
-- Shine: a soft white band that sweeps across every few seconds
---------------------------------------------------------------------

-- Kit.shine(target, interval?) -> Frame (the "Shine" overlay)
function Kit.shine(target, interval)
	local st = buttons[target]
	local host = if st then st.face else target
	local overlay = Kit.make("Frame", {
		Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		ZIndex = 2, Active = false, -- under the button Label (ZIndex 3)
	})
	local corner = host:FindFirstChildOfClass("UICorner")
	if corner then
		Kit.make("UICorner", { CornerRadius = corner.CornerRadius }, overlay)
	end
	local g = Kit.make("UIGradient", {
		Name = "Gradient", Rotation = 20, Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, overlay)
	overlay.Parent = host

	task.spawn(function()
		while overlay.Parent do
			g.Offset = Vector2.new(-1, 0)
			Kit.tween(g, 0.6, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear)
			task.wait(0.6)
			task.wait(interval or 3)
		end
	end)
	return overlay
end

---------------------------------------------------------------------
-- Rarity colors and number formatting
---------------------------------------------------------------------

-- Kit.rarityColor(rarity) -> Color3 (falls back to Common)
function Kit.rarityColor(rarity)
	local info = Config.Rarities[rarity] or Config.Rarities.Common
	return info.color
end

-- Kit.rarityTextColor(rarity) -> Color3 (Secret is black, so its text is white)
function Kit.rarityTextColor(rarity)
	if rarity == "Secret" then
		return WHITE
	end
	return Kit.rarityColor(rarity)
end

Kit.format = Config.Format         -- 12345 -> "12.3K"
Kit.formatTime = Config.FormatTime -- 75 -> "1:15"

-- Kit.formatMult(1) -> "1.00x", 250 -> "250x", 24000 -> "24Kx" (Luck gets big, like Anime Dice's)
function Kit.formatMult(x)
	x = tonumber(x) or 1
	if x >= 1000 then
		return Config.Format(x) .. "x"
	elseif x >= 100 then
		return string.format("%dx", math.floor(x))
	end
	return string.format("%.2fx", x)
end

-- Kit.formatPercent(100) -> "+100%"
function Kit.formatPercent(p)
	return string.format("+%d%%", math.floor((tonumber(p) or 0) + 0.5))
end

---------------------------------------------------------------------
-- 3D Floatie previews (ViewportFrames). Built for Stage 4's lists:
-- a model is only cloned while its preview is actually on screen, and
-- every Floatie + mutation is built once and cloned from then on.
---------------------------------------------------------------------
local VIEWPORT_OPTS = { spin = true }
local VIEW_DIR = Vector3.new(0.9, 0.45, 0.9).Unit -- camera sits front-right-above (head points +X)
local SPIN_SPEED = 0.6 -- radians per second when opts.spin is on

local Preview = {}
Preview.__index = Preview

local function overlaps(pos, size, otherPos, otherSize)
	return pos.X < otherPos.X + otherSize.X and otherPos.X < pos.X + size.X
		and pos.Y < otherPos.Y + otherSize.Y and otherPos.Y < pos.Y + size.Y
end

-- visible, big enough, inside every clipping ancestor, and its ScreenGui is on
local function isOnScreen(frame)
	if not frame.Visible then
		return false
	end
	local size = frame.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return false
	end
	local pos = frame.AbsolutePosition
	local node = frame.Parent
	while node do
		if node:IsA("LayerCollector") then
			return node.Enabled and node:IsDescendantOf(game)
		end
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
			if node:IsA("ScrollingFrame") or node.ClipsDescendants then
				if not overlaps(pos, size, node.AbsolutePosition, node.AbsoluteSize) then
					return false
				end
			end
		end
		node = node.Parent
	end
	return false -- not inside any ScreenGui / BillboardGui / SurfaceGui
end

-- the shared template for a preview's Floatie (built on first use)
local function getTemplate(preview)
	local key = preview._key
	local template = templates[key]
	if template == nil then
		local ok, result = pcall(function()
			if preview._build then
				return preview._build() -- a custom model (see preview:setModel)
			end
			local model = FloatieModel.Build(Config.FloatieById[preview._id], preview._mut, 1)
			FloatieModel.SetAnchored(model, true)
			local label = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Label")
			if label then
				label:Destroy()
			end
			model:RemoveTag("Floatie") -- so the bob/squish loop ignores previews
			-- ("RainbowFloatie" stays, so rainbow previews still cycle colors)
			return model
		end)
		if ok then
			template = result
		else
			template = false
			warnOnce("build " .. key, "could not build preview " .. key .. ": " .. tostring(result))
		end
		templates[key] = template
	end
	return template or nil
end

local function aimCamera(preview, angle)
	local dir = VIEW_DIR
	if angle ~= 0 then
		dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(VIEW_DIR)
	end
	preview._camera.CFrame = CFrame.lookAt(preview._center + dir * preview._dist, preview._center)
end

-- fit the whole model in view (FieldOfView 40 = 20 degrees each side)
local function frameCamera(preview, model)
	local boxCf, size = model:GetBoundingBox()
	local dist = (size.Magnitude / 2) / math.tan(math.rad(20)) * 1.1
	-- FieldOfView is vertical: a tall, narrow frame needs the camera further back
	local abs = preview.frame.AbsoluteSize
	if abs.X > 0 and abs.X < abs.Y then
		dist *= abs.Y / abs.X
	end
	preview._center = boxCf.Position
	preview._dist = dist
	aimCamera(preview, if preview._spin then os.clock() * SPIN_SPEED else 0)
end

local function updatePreview(preview)
	local frame = preview.frame
	if previews[frame] ~= preview then
		return -- destroyed
	end
	if preview._key and isOnScreen(frame) then
		if not preview._clone then
			local template = getTemplate(preview)
			if not template then
				return
			end
			preview._clone = template:Clone()
		end
		if preview._clone.Parent ~= frame then
			frameCamera(preview, preview._clone)
			preview._clone.Parent = frame
		end
	elseif preview._clone and preview._clone.Parent then
		preview._clone.Parent = nil -- off screen: keep the clone for when it comes back
	end
end

-- one shared loop checks every preview 4 times a second
local previewLoopRunning = false
local function startPreviewLoop()
	if previewLoopRunning then
		return
	end
	previewLoopRunning = true
	task.spawn(function()
		while next(previews) ~= nil do
			local list = {}
			for _, preview in pairs(previews) do
				table.insert(list, preview)
			end
			for _, preview in ipairs(list) do
				local ok, err = pcall(updatePreview, preview)
				if not ok then
					warnOnce("preview", "preview update failed: " .. tostring(err))
				end
			end
			task.wait(0.25)
		end
		previewLoopRunning = false
	end)
end

-- slow camera orbit for previews made with { spin = true }
local spinConn = nil
local function startSpinLoop()
	if spinConn then
		return
	end
	spinConn = RunService.RenderStepped:Connect(function()
		local angle = os.clock() * SPIN_SPEED
		local any = false
		for _, preview in pairs(previews) do
			if preview._spin then
				any = true
				if preview._clone and preview._clone.Parent then
					aimCamera(preview, angle)
				end
			end
		end
		if not any then
			spinConn:Disconnect()
			spinConn = nil
		end
	end)
end

local function forget(preview)
	previews[preview.frame] = nil
	if preview._clone then
		preview._clone:Destroy()
		preview._clone = nil
	end
end

-- preview:setFloatie(floatieId?, mutId?) — nil clears the preview
function Preview:setFloatie(floatieId, mutId)
	local def = floatieId and Config.FloatieById[floatieId]
	if floatieId ~= nil and not def then
		warnOnce("id " .. tostring(floatieId), "viewport: unknown Floatie id " .. tostring(floatieId))
	end
	local mut = mutId or "Normal"
	local key = if def then floatieId .. "|" .. mut else nil
	if key == self._key then
		return -- already showing it
	end
	if self._clone then
		self._clone:Destroy()
		self._clone = nil
	end
	self._key = key
	self._id = if def then floatieId else nil
	self._mut = if def then mut else nil
	self._build = nil
	if key then
		-- show it right away if it is already on screen (else the loop will)
		local ok, err = pcall(updatePreview, self)
		if not ok then
			warnOnce("preview", "preview update failed: " .. tostring(err))
		end
	end
end

-- preview:setModel(key, build) — show any model: build() -> Model is called once per key
-- (e.g. "pump|3", function() return PumpModel.Build(3) end)
function Preview:setModel(key, build)
	if key == self._key then
		return
	end
	if self._clone then
		self._clone:Destroy()
		self._clone = nil
	end
	self._key = key
	self._id = nil
	self._mut = nil
	self._build = build
	if key then
		local ok, err = pcall(updatePreview, self)
		if not ok then
			warnOnce("preview", "preview update failed: " .. tostring(err))
		end
	end
end

-- preview:destroy() — removes the preview and its ViewportFrame
function Preview:destroy()
	forget(self)
	self._key = nil
	self.frame:Destroy()
end

-- Kit.viewport(parent, props?, opts?) -> Preview { frame, setFloatie, destroy }
-- opts = { spin = false }
function Kit.viewport(parent, props, opts)
	parent, props, opts = splitArgs(parent, props, opts, VIEWPORT_OPTS)
	local base = {
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 200), LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local frame = Kit.make("ViewportFrame", base)
	local camera = Kit.make("Camera", { Name = "PreviewCamera", FieldOfView = 40 }, frame)
	frame.CurrentCamera = camera

	local preview = setmetatable({
		frame = frame, _camera = camera, _spin = opts.spin == true,
		_key = nil, _id = nil, _mut = nil, _clone = nil, _center = Vector3.zero, _dist = 10,
	}, Preview)
	previews[frame] = preview
	frame.Destroying:Connect(function()
		forget(preview)
	end)

	if parent then
		frame.Parent = parent
	end
	startPreviewLoop()
	if preview._spin then
		startSpinLoop()
	end
	return preview
end

---------------------------------------------------------------------
-- Scrolling lists and grids
---------------------------------------------------------------------

-- Kit.scroll(parent, props?, opts?) -> ScrollingFrame
-- opts = { cell = Vector2 (a grid of cells; omit for a vertical list), gap = 8, pad = 4 }
function Kit.scroll(parent, props, opts)
	props = props or {}
	opts = opts or {}
	local base = {
		Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = C.TextSoft or WHITE, ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local list = Kit.make("ScrollingFrame", base, parent)
	local gap = opts.gap or 8
	local pad = opts.pad or 4
	Kit.make("UIPadding", {
		PaddingTop = UDim.new(0, pad), PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad), PaddingRight = UDim.new(0, pad),
	}, list)
	if opts.cell then
		Kit.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(opts.cell.X, opts.cell.Y), CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}, list)
	else
		Kit.make("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	end
	return list
end

---------------------------------------------------------------------
-- Tabs: a row (or column) of buttons where one is selected
---------------------------------------------------------------------
local Tabs = {}
Tabs.__index = Tabs

function Tabs:select(name, silent)
	if not self.buttons[name] then
		return
	end
	self.selected = name
	for itemName, button in pairs(self.buttons) do
		local item = self.items[itemName]
		Kit.setButtonColor(button, if itemName == name then (item.color or C.Blue) else C.RowAlt)
	end
	if not silent and self.onSelect then
		self.onSelect(name)
	end
end

-- Kit.tabs(parent, props, opts) -> Tabs { frame, buttons, selected, select(name) }
-- opts = { items = { { name = "Units", text = "Units", color = C.Blue }, ... },
--          vertical = false, button = Vector2.new(110, 34), gap = 6, maxTextSize = 20, onSelect = fn(name) }
function Kit.tabs(parent, props, opts)
	opts = opts or {}
	local frame = Kit.make("Frame", { Name = "Tabs", BackgroundTransparency = 1 }, nil)
	for k, v in pairs(props or {}) do
		frame[k] = v
	end
	Kit.make("UIListLayout", {
		FillDirection = if opts.vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, opts.gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	local tabs = setmetatable({ frame = frame, buttons = {}, items = {}, selected = nil, onSelect = opts.onSelect }, Tabs)
	local size = opts.button or Vector2.new(110, 34)
	for i, item in ipairs(opts.items or {}) do
		local button = Kit.button(frame, {
			Name = item.name, Size = UDim2.fromOffset(item.width or size.X, size.Y), LayoutOrder = i,
		}, { text = item.text or item.name, color = C.RowAlt, maxTextSize = opts.maxTextSize or 20, radius = 10 })
		tabs.buttons[item.name] = button
		tabs.items[item.name] = item
		Kit.onClick(button, function()
			tabs:select(item.name)
		end)
	end
	frame.Parent = parent
	return tabs
end

---------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------

-- Kit.progress(parent, props, opts) -> { frame, fill, label, set(self, fraction, text?) }
-- opts = { color = C.Green, radius = 10, maxTextSize = 18 }
function Kit.progress(parent, props, opts)
	opts = opts or {}
	local frame = Kit.plate(parent, props, { color = C.RowBorder or C.HudBg, transparency = 0.1, radius = opts.radius or 10, border = 2 })
	local fill = Kit.make("Frame", {
		Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, frame)
	Kit.round(fill, opts.radius or 10)
	Kit.gradient(fill, Kit.shade(opts.color or C.Green, 0.3), Kit.shade(opts.color or C.Green, -0.2))
	local label = Kit.label(frame, {
		Name = "Label", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 3,
	}, { maxTextSize = opts.maxTextSize or 18 })
	local bar = { frame = frame, fill = fill, label = label }
	function bar:set(fraction, text)
		self.fill.Size = UDim2.fromScale(math.clamp(fraction or 0, 0, 1), 1)
		self.fill.Visible = (fraction or 0) > 0.001
		if text then
			self.label.Text = text
		end
	end
	return bar
end

---------------------------------------------------------------------
-- Confirm box: "Are you sure?" with Yes / No (a stack panel, reused)
---------------------------------------------------------------------
local dialogCanvas = nil
local dialog = nil

-- init calls this with the panel canvas so Kit.confirm has somewhere to draw
function Kit.setDialogCanvas(canvas)
	dialogCanvas = canvas
end

-- Kit.confirm({ title, text, yes = "Yes", no = "Cancel", color = C.Orange }, fn(ok))
function Kit.confirm(opts, fn)
	if not dialogCanvas then
		fn(true) -- nowhere to ask: assume yes
		return
	end
	if not dialog then
		local panel = Kit.panel(dialogCanvas, { name = "ConfirmPanel", title = "Are you sure?", icon = "❓", color = C.Orange, size = Vector2.new(400, 220), stack = true })
		local text = Kit.label(panel.body, {
			Name = "Text", Size = UDim2.new(1, 0, 1, -64), TextWrapped = true,
		}, { maxTextSize = 22 })
		local yes = Kit.button(panel.body, {
			Name = "Yes", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -6, 1, -4), Size = UDim2.fromOffset(150, 50),
		}, { text = "Yes", color = C.Green })
		local no = Kit.button(panel.body, {
			Name = "No", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 6, 1, -4), Size = UDim2.fromOffset(150, 50),
		}, { text = "Cancel", color = C.Red })
		dialog = { panel = panel, text = text, yes = yes, no = no, fn = nil }
		Kit.onClick(yes, function()
			local cb = dialog.fn
			dialog.fn = nil
			panel:close()
			if cb then
				cb(true)
			end
		end)
		Kit.onClick(no, function()
			local cb = dialog.fn
			dialog.fn = nil
			panel:close()
			if cb then
				cb(false)
			end
		end)
	end
	dialog.fn = fn
	dialog.panel.header.Title.Text = "❓ " .. (opts.title or "Are you sure?")
	dialog.text.Text = opts.text or ""
	Kit.setButtonText(dialog.yes, opts.yes or "Yes")
	Kit.setButtonText(dialog.no, opts.no or "Cancel")
	dialog.panel:open()
end

return Kit
