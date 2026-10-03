--[[
	Floatie Farm — RollUI (ModuleScript child of the ClientMain LocalScript)
	The pull, on screen (bottom center of the HUD):
	  • the pump name button (opens the Pump Shop)
	  • AUTO | ROLL | HIDE. While Auto Roll is on, ROLL turns into STOP.
	    R on the keyboard rolls too.
	  • while the pump inflates, a balloon above the buttons grows, then pops
	  • the reveal: a small card for everyday pulls. The big reveal in the
	    middle of the screen ("1 in 24K", rays, wings) is for pulls that are
	    rare for YOUR luck, Mythic and up, Diamond / Ruby / Rainbow / Thunder, new Rare+
	    Index entries. With Hide on, nothing pops up at all (no balloon, card
	    or big reveal); Mythic+ pulls still get their line in the chat.
	The server decides every result (Remotes.RollResult); this only shows them.

	API:
	  RollUI.mount(hudCanvas, revealCanvas, actions)  -- actions.openPanel(name)
	  RollUI.area() -> Frame   (the roll buttons, for the tutorial arrow)
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Sounds = require(script.Parent.Sounds)

local player = Players.LocalPlayer
local C = Config.UI
local R = Config.Rolling

local RollUI = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollRE = remotes:WaitForChild("Roll")
local SetSettingRE = remotes:WaitForChild("SetSetting")
local RollResultRE = remotes:WaitForChild("RollResult")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local mounted = false
local area = nil
local rollButton, autoButton, hideButton, pumpButton = nil, nil, nil, nil
local fill = nil              -- progress fill inside the ROLL button
local balloon, balloonScale = nil, nil
local card = nil              -- the small reveal card
local cardPreview = nil
local cardRarity, cardName, cardInfo, cardNew = nil, nil, nil, nil
local jackpotPill = nil
local inflateStart, inflateTime = 0, 0
local inflating = false
local cardToken = 0

-- big reveal
local overlay = nil
local bigPreview = nil
local bigOdds, bigRarity, bigName, bigNew = nil, nil, nil, nil
local rays = nil
local bigQueue = {}
local bigShowing = false

local function label(def, mut)
	return (if mut and mut ~= "Normal" then mut .. " " else "") .. def.name
end

-- is this pull worth the big reveal?
local function isBig(def, mut, isNew)
	local rarity = Config.Rarities[def.rarity]
	if rarity.order >= R.AnnounceOrder or R.BigRevealMutations[mut] then
		return true
	end
	if rarity.order < R.BigRevealOrder then
		return false
	end
	local luck = math.max(1, tonumber(player:GetAttribute("LuckMultiplier")) or 1)
	return isNew or def.odds / luck >= 60
end

---------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------
local function refreshButtons()
	if not mounted then
		return
	end
	local auto = player:GetAttribute("AutoRoll") == true
	local hide = player:GetAttribute("Hide") == true
	Kit.setButtonColor(autoButton, if auto then C.Green else C.Grey)
	Kit.setButtonText(autoButton, if auto then "🔁 ON" else "🔁 AUTO")
	Kit.setButtonColor(hideButton, if hide then C.Purple else C.Grey)
	Kit.setButtonText(hideButton, if hide then "🙈 ON" else "🙈 HIDE")
	Kit.setButtonText(rollButton, if auto then "⏹ STOP" else "🎈 ROLL")
	Kit.setButtonColor(rollButton, if auto then C.Red else C.Pink)
	local pumpName = player:GetAttribute("PumpName") or "Hand Pump"
	local pumpLuck = player:GetAttribute("PumpLuck") or 1
	Kit.setButtonText(pumpButton, "🎈 " .. pumpName .. "  🍀x" .. Config.Format(pumpLuck) .. "  ▸")
	jackpotPill.Visible = player:GetAttribute("JackpotReady") == true
end

local function roll()
	if player:GetAttribute("AutoRoll") then
		SetSettingRE:FireServer("autoRoll", false)
	else
		RollRE:FireServer()
	end
end

---------------------------------------------------------------------
-- Inflate balloon + small card
---------------------------------------------------------------------
local function hideCard(token)
	if token ~= cardToken or not card.Visible then
		return
	end
	local tween = Kit.tween(card.Pop, 0.18, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween.Completed:Connect(function()
		if token == cardToken then
			card.Visible = false
			cardPreview:setFloatie(nil)
		end
	end)
end

local function showCard(result)
	local def = Config.FloatieById[result.id]
	if not def then
		return
	end
	cardToken += 1
	local token = cardToken
	local rarity = Config.Rarities[def.rarity]
	cardPreview:setFloatie(def.id, result.mut)
	cardRarity.Text = string.upper(def.rarity)
	cardRarity.TextColor3 = Kit.rarityTextColor(def.rarity)
	cardName.Text = label(def, result.mut)
	local where
	if result.dest == "sold" then
		where = "sold for " .. Config.Format(result.soldFor or 0) .. " Air"
	elseif result.dest == "backpack" then
		where = "→ Backpack"
	else
		where = "→ Slot " .. tostring(result.slot or "?")
	end
	cardInfo.Text = Config.FormatOdds(Formulas.copyOdds(def.id, result.mut)) .. "  •  " .. where
	cardNew.Visible = result.new == true
	card.Border.Color = rarity.color
	card.Visible = true
	card.Pop.Scale = 0.5
	Kit.tween(card.Pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(1.9, hideCard, token)
end

---------------------------------------------------------------------
-- Big reveal
---------------------------------------------------------------------
local function closeBig()
	if not bigShowing then
		return
	end
	bigShowing = false
	Kit.tween(overlay, 0.2, { BackgroundTransparency = 1 })
	Kit.tween(overlay.Content.Pop, 0.2, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		if not bigShowing then
			overlay.Visible = false
			bigPreview:setFloatie(nil)
			local nextOne = table.remove(bigQueue, 1)
			if nextOne then
				task.defer(RollUI._showBig, nextOne)
			end
		end
	end)
end

function RollUI._showBig(result)
	local def = Config.FloatieById[result.id]
	if not def then
		return
	end
	if bigShowing then
		if #bigQueue < 3 then
			table.insert(bigQueue, result)
		end
		return
	end
	bigShowing = true
	local rarity = Config.Rarities[def.rarity]
	local color = Kit.rarityTextColor(def.rarity)
	bigOdds.Text = Config.FormatOdds(Formulas.copyOdds(def.id, result.mut))
	bigOdds.TextColor3 = color
	bigRarity.Text = string.upper(def.rarity) .. (if result.jackpot then "  •  🎰 JACKPOT" else "")
	bigRarity.TextColor3 = color
	bigName.Text = label(def, result.mut)
	local mut = Config.MutationById[result.mut or "Normal"]
	bigName.TextColor3 = if mut and mut.color then mut.color else Color3.new(1, 1, 1)
	bigNew.Visible = result.new == true
	for _, ray in ipairs(rays:GetChildren()) do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.35)
		end
	end
	bigPreview:setFloatie(def.id, result.mut)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	Kit.tween(overlay, 0.25, { BackgroundTransparency = 0.45 })
	overlay.Content.Pop.Scale = 0.4
	Kit.tween(overlay.Content.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Sounds.play("Rare")
	local token = os.clock()
	overlay:SetAttribute("Token", token)
	task.delay(if rarity.order >= R.AnnounceOrder then 3.4 else 2.6, function()
		if overlay:GetAttribute("Token") == token then
			closeBig()
		end
	end)
end

---------------------------------------------------------------------
-- A result arrived
---------------------------------------------------------------------
local function onResult(result)
	local def = Config.FloatieById[result.id]
	if not def or not mounted then
		return
	end
	local hidden = player:GetAttribute("Hide") == true
	local big = isBig(def, result.mut, result.new and Config.Rarities[def.rarity].order >= R.BigRevealOrder)
	inflateStart = os.clock()
	inflateTime = math.max(0.1, result.inflateTime or R.InflateTime)
	inflating = true
	balloon.Visible = not hidden
	balloon.BackgroundColor3 = Color3.fromHSV(math.random(), 0.55, 1)
	if not hidden then
		Sounds.play("Inflate")
	end
	task.delay(inflateTime, function()
		inflating = false
		balloon.Visible = false
		fill.Size = UDim2.fromScale(0, 1)
		if not hidden then
			Sounds.play("Pop")
			showCard(result)
		end
		if big and not hidden then
			RollUI._showBig(result)
		end
	end)
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
local function buildBigReveal(revealCanvas)
	overlay = Kit.make("TextButton", {
		Name = "BigReveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false,
	}, revealCanvas)
	overlay.Activated:Connect(closeBig)
	local content = Kit.make("Frame", {
		Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 380), BackgroundTransparency = 1,
	}, overlay)
	Kit.make("UIScale", { Name = "Pop" }, content)

	-- spinning rays behind the Floatie
	rays = Kit.make("Frame", {
		Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = 1,
	}, content)
	for i = 0, 11 do
		local ray = Kit.make("Frame", {
			Name = "Ray", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34, 250), Rotation = i * 30, BorderSizePixel = 0, ZIndex = 1,
		}, rays)
		Kit.make("UIGradient", {
			Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.65), NumberSequenceKeypoint.new(1, 0.35),
			}),
		}, ray)
	end
	-- the white "wings" either side
	for _, side in ipairs({ -1, 1 }) do
		local wing = Kit.make("Frame", {
			Name = "Wing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * 175, 0.5, -30),
			Size = UDim2.fromOffset(150, 34), Rotation = side * 12, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
		}, content)
		Kit.round(wing, 17)
		Kit.make("UIGradient", {
			Rotation = if side < 0 then 0 else 180,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 0) }),
		}, wing)
	end

	bigOdds = Kit.label(content, {
		Name = "Odds", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(440, 58), ZIndex = 4,
	}, { outline = 4, maxTextSize = 54 })
	bigRarity = Kit.label(content, {
		Name = "Rarity", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(440, 30), ZIndex = 4,
	}, { outline = 3, maxTextSize = 28 })
	local view = Kit.viewport(content, {
		Name = "Preview", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(230, 210), ZIndex = 3,
	}, { spin = true })
	bigPreview = view
	bigName = Kit.label(content, {
		Name = "Name", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.fromOffset(440, 44), ZIndex = 4,
	}, { outline = 4, maxTextSize = 42 })
	bigNew = Kit.plate(content, {
		Name = "New", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 120, 0.5, -80), Size = UDim2.fromOffset(84, 30),
		Rotation = 12, ZIndex = 5, Visible = false,
	}, { color = C.Red, gradient = true, radius = 10, border = 3 })
	Kit.label(bigNew, { Size = UDim2.fromScale(1, 1), Text = "NEW!", ZIndex = 6 }, { maxTextSize = 22 })
	Kit.label(content, {
		Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(300, 18),
		Text = "tap to continue", TextTransparency = 0.3, ZIndex = 4,
	}, { outline = 2, maxTextSize = 16 })

	RunService.RenderStepped:Connect(function(dt)
		if overlay.Visible then
			rays.Rotation = (rays.Rotation + dt * 25) % 360
		end
	end)
end

function RollUI.mount(hudCanvas, revealCanvas, actions)
	if mounted then
		return
	end
	actions = actions or {}

	area = Kit.make("Frame", {
		Name = "RollArea", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(356, 96), BackgroundTransparency = 1,
	}, hudCanvas)

	pumpButton = Kit.button(area, {
		Name = "Pump", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(250, 28),
	}, { text = "🎈 Hand Pump", color = C.Blue, maxTextSize = 18, radius = 10 })
	Kit.onClick(pumpButton, function()
		if actions.openPanel then
			actions.openPanel("PumpShop")
		end
	end)

	autoButton = Kit.button(area, {
		Name = "Auto", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4), Size = UDim2.fromOffset(80, 50),
	}, { text = "🔁 AUTO", color = C.Grey, maxTextSize = 20 })
	Kit.onClick(autoButton, function()
		SetSettingRE:FireServer("autoRoll", not player:GetAttribute("AutoRoll"))
	end)

	hideButton = Kit.button(area, {
		Name = "Hide", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -4), Size = UDim2.fromOffset(80, 50),
	}, { text = "🙈 HIDE", color = C.Grey, maxTextSize = 20 })
	Kit.onClick(hideButton, function()
		SetSettingRE:FireServer("hide", not player:GetAttribute("Hide"))
	end)

	rollButton = Kit.button(area, {
		Name = "Roll", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(182, 62),
	}, { text = "🎈 ROLL", color = C.Pink, maxTextSize = 34 })
	Kit.shine(rollButton, 4)
	-- the inflate progress, inside the button's face
	fill = Kit.make("Frame", {
		Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 2,
	}, rollButton.Face)
	Kit.round(fill, 12)
	Kit.onClick(rollButton, roll)

	-- "next roll is a Jackpot Roll"
	jackpotPill = Kit.plate(area, {
		Name = "Jackpot", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(250, 24), Visible = false,
	}, { color = C.Yellow, gradient = true, radius = 12, border = 2 })
	Kit.label(jackpotPill, { Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Text = "🎰 NEXT ROLL: JACKPOT x" .. R.JackpotLuck .. " LUCK" }, { maxTextSize = 16 })

	-- the balloon that inflates above the buttons
	balloon = Kit.make("Frame", {
		Name = "InflateBalloon", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(74, 84), BackgroundColor3 = C.Pink, BorderSizePixel = 0, Visible = false,
	}, hudCanvas)
	Kit.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, balloon)
	Kit.stroke(balloon, C.Outline, 3)
	Kit.make("UIGradient", {
		Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	}, balloon)
	local shine = Kit.make("Frame", {
		Name = "Shine", Position = UDim2.fromScale(0.2, 0.14), Size = UDim2.fromScale(0.22, 0.26),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, Rotation = -25,
	}, balloon)
	Kit.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	Kit.make("Frame", {
		Name = "Knot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.02),
		Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = C.Outline, BorderSizePixel = 0,
	}, balloon)
	balloonScale = Kit.make("UIScale", { Name = "Inflate", Scale = 0.3 }, balloon)

	-- the small reveal card (same spot as the balloon)
	card = Kit.plate(hudCanvas, {
		Name = "RevealCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(310, 84), Visible = false,
	}, { radius = 14, border = 3 })
	Kit.make("UIScale", { Name = "Pop" }, card)
	cardPreview = Kit.viewport(card, {
		Name = "Preview", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(76, 76),
	}, { spin = true })
	cardRarity = Kit.label(card, {
		Name = "Rarity", Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -96, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 18 })
	cardName = Kit.label(card, {
		Name = "Name", Position = UDim2.fromOffset(86, 24), Size = UDim2.new(1, -96, 0, 30), TextXAlignment = Enum.TextXAlignment.Left,
	}, { outline = 3, maxTextSize = 28 })
	cardInfo = Kit.label(card, {
		Name = "Info", Position = UDim2.fromOffset(86, 56), Size = UDim2.new(1, -96, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 225, 255),
	}, { maxTextSize = 17 })
	cardNew = Kit.plate(card, {
		Name = "New", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, -10), Size = UDim2.fromOffset(56, 22), Rotation = 8, Visible = false,
	}, { color = C.Red, gradient = true, radius = 8, border = 2 })
	Kit.label(cardNew, { Size = UDim2.fromScale(1, 1), Text = "NEW!" }, { maxTextSize = 16 })

	buildBigReveal(revealCanvas)

	-- inflate animation (balloon + ROLL fill)
	RunService.RenderStepped:Connect(function()
		if not inflating then
			return
		end
		local a = math.clamp((os.clock() - inflateStart) / inflateTime, 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		if balloon.Visible then
			local eased = 1 - (1 - a) ^ 2
			balloonScale.Scale = 0.3 + eased * 0.75
			balloon.Rotation = math.sin(os.clock() * 16) * 4 * a
		end
	end)

	for _, attr in ipairs({ "AutoRoll", "Hide", "PumpName", "PumpLuck", "JackpotReady" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshButtons)
	end
	RollResultRE.OnClientEvent:Connect(onResult)

	-- R rolls on a keyboard
	ContextActionService:BindAction("FloatieRoll", function(_, state)
		if state == Enum.UserInputState.Begin then
			roll()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R)

	mounted = true
	refreshButtons()
end

function RollUI.area()
	return area
end

return RollUI
