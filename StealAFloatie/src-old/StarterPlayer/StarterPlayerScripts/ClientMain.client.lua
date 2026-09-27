--[[
	Steal a Floatie — ClientMain (LocalScript in StarterPlayer.StarterPlayerScripts)
	Builds the HUD, shows notifications, fires the Dart Blaster, hides prompts
	that aren't meant for you, and plays client-side effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRE = Remotes:WaitForChild("Notify")
local FireDartRE = Remotes:WaitForChild("FireDart")
local KnockbackRE = Remotes:WaitForChild("Knockback")
local RebirthRE = Remotes:WaitForChild("Rebirth")
local RedeemRF = Remotes:WaitForChild("RedeemCode")

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne
local PINK = Color3.fromRGB(255, 95, 160)
local DARK = Color3.fromRGB(30, 28, 48)
local WHITE = Color3.new(1, 1, 1)

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, inst)
	return inst
end

local function stroke(inst, color, thickness)
	make("UIStroke", { Color = color or WHITE, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
	return inst
end

local function label(parent, props)
	local base = {
		BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE,
		TextStrokeTransparency = 0.4, Text = "",
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return make("TextLabel", base, parent)
end

local function button(parent, props)
	local base = {
		BackgroundColor3 = PINK, Font = FONT, TextScaled = true, TextColor3 = WHITE,
		AutoButtonColor = true, Text = "",
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local b = make("TextButton", base, parent)
	round(b, 10)
	make("UITextSizeConstraint", { MaxTextSize = 28 }, b)
	return b
end

local gui = make("ScreenGui", { Name = "FloatieHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------
-- Sounds (edit the ids in Config.Sounds)
---------------------------------------------------------------------
local SoundService = game:GetService("SoundService")
local soundTemplates = {}
for name, info in pairs(Config.Sounds) do
	if info.id ~= "" then
		soundTemplates[name] = make("Sound", {
			Name = name, SoundId = info.id, Volume = info.volume or 0.5,
			PlaybackSpeed = info.pitch or 1, Looped = name == "Music",
		}, SoundService)
	end
end
local function playSound(name, atPart)
	local s = soundTemplates[name]
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
if soundTemplates.Music then
	soundTemplates.Music:Play()
end
-- pops happen on the server as a Part named "PopEffect": play the sound where it happens
workspace.ChildAdded:Connect(function(child)
	if child.Name == "PopEffect" and child:IsA("BasePart") then
		playSound("Pop", child)
	end
end)

---------------------------------------------------------------------
-- Air display (top-left)
---------------------------------------------------------------------
local airFrame = round(make("Frame", {
	Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(250, 70),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.15,
}, gui), 14)
stroke(airFrame, PINK, 3)
local airLabel = label(airFrame, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, Text = "🎈 0 Air" })
local incomeLabel = label(airFrame, { Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 255, 140), Text = "+0 Air/s" })

local function refreshAir()
	airLabel.Text = "🎈 " .. Config.Format(player:GetAttribute("Air") or 0) .. " Air"
	incomeLabel.Text = "+" .. Config.Format(player:GetAttribute("IncomePerSec") or 0) .. " Air/s"
end
player:GetAttributeChangedSignal("Air"):Connect(refreshAir)
player:GetAttributeChangedSignal("IncomePerSec"):Connect(refreshAir)
refreshAir()

label(gui, {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -6), Size = UDim2.fromOffset(160, 16),
	TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.4, Text = Config.GameName .. " v" .. Config.Version,
})

---------------------------------------------------------------------
-- Notifications (bottom-center toasts)
---------------------------------------------------------------------
local toastHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(520, 260), BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 260) }, toastHolder)

local TOAST_COLORS = {
	info = Color3.fromRGB(45, 45, 70),
	success = Color3.fromRGB(40, 150, 90),
	error = Color3.fromRGB(190, 60, 70),
	alert = Color3.fromRGB(230, 70, 40),
	event = Color3.fromRGB(140, 70, 220),
}
local toastOrder = 0
local TOAST_SOUNDS = { success = "Buy", error = "Error", alert = "Alert", event = "Event" }
local function toast(text, kind)
	toastOrder += 1
	if TOAST_SOUNDS[kind] then
		playSound(TOAST_SOUNDS[kind])
	end
	local f = round(make("Frame", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		BackgroundTransparency = 0.1, LayoutOrder = toastOrder,
	}, toastHolder), 10)
	local t = label(f, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = text })
	make("UITextSizeConstraint", { MaxTextSize = 22 }, t)
	if #toastHolder:GetChildren() > 7 then
		for _, child in ipairs(toastHolder:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
	task.delay(if kind == "alert" then 6 else 4, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.45)
			f:Destroy()
		end
	end)
end
NotifyRE.OnClientEvent:Connect(toast)

---------------------------------------------------------------------
-- Event banner (top-center)
---------------------------------------------------------------------
local banner = round(make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(440, 60),
	BackgroundColor3 = Color3.fromRGB(120, 60, 210), BackgroundTransparency = 0.1, Visible = false,
}, gui), 14)
stroke(banner, WHITE, 2)
local bannerTitle = label(banner, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 30) })
local bannerDesc = label(banner, { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 20), TextColor3 = Color3.fromRGB(230, 220, 255) })

local EVENT_CLOCK = { Thunderstorm = 18.6, SecretSkies = 0 }
local currentEvent = ""
local function updateEvent()
	local name = ReplicatedStorage:GetAttribute("Event") or ""
	local endsAt = ReplicatedStorage:GetAttribute("EventEndsAt") or 0
	local left = endsAt - workspace:GetServerTimeNow()
	local ev = Config.Events[name]
	if ev and left > 0 then
		banner.Visible = true
		bannerTitle.Text = ev.title .. "  " .. Config.FormatTime(left)
		bannerDesc.Text = ev.desc
	else
		banner.Visible = false
		name = ""
	end
	if name ~= currentEvent then
		currentEvent = name
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = EVENT_CLOCK[name] or 14 }):Play()
	end
end

---------------------------------------------------------------------
-- Carry indicator (when YOU are carrying a stolen Floatie)
---------------------------------------------------------------------
local carryFrame = round(make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(400, 58),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60), BackgroundTransparency = 0.1, Visible = false,
}, gui), 12)
local carryTitle = label(carryFrame, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 30) })
local carryInfo = label(carryFrame, { Position = UDim2.fromOffset(10, 33), Size = UDim2.new(1, -20, 0, 20) })

local function updateCarry()
	local endsAt = player:GetAttribute("CarryEndsAt")
	if not endsAt then
		carryFrame.Visible = false
		return
	end
	carryFrame.Visible = true
	carryTitle.Text = "🎈 " .. (player:GetAttribute("CarryName") or "Floatie") .. " — RUN HOME!"
	local hits = player:GetAttribute("CarryHits") or 0
	local popHits = player:GetAttribute("CarryPopHits") or 1
	carryInfo.Text = "⏱ " .. math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) .. "s   💥 " .. hits .. "/" .. popHits .. " darts"
end

---------------------------------------------------------------------
-- Panels (Shop / Rebirth / Codes)
---------------------------------------------------------------------
local panels = {}
local function makePanel(title)
	local p = round(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.85),
		BackgroundColor3 = DARK, Visible = false,
	}, gui), 16)
	stroke(p, PINK, 3)
	make("UISizeConstraint", { MaxSize = Vector2.new(440, 380) }, p)
	make("UIAspectRatioConstraint", { AspectRatio = 440 / 380 }, p)
	label(p, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 40), Text = title, TextXAlignment = Enum.TextXAlignment.Left })
	local close = button(p, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36), Text = "X", BackgroundColor3 = Color3.fromRGB(200, 60, 70) })
	close.Activated:Connect(function()
		p.Visible = false
	end)
	table.insert(panels, p)
	return p
end
local function toggle(p)
	local show = not p.Visible
	for _, other in ipairs(panels) do
		other.Visible = false
	end
	p.Visible = show
end

-- Shop
local shop = makePanel("🛒 Shop")
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -68), BackgroundTransparency = 1,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, shop)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local passButtons = {}
local function shopRow(order, info, onBuy)
	local row = round(make("Frame", { Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = Color3.fromRGB(50, 46, 78), LayoutOrder = order }, list), 10)
	label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -130, 0, 28), Text = info.title, TextXAlignment = Enum.TextXAlignment.Left })
	label(row, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -130, 0, 22), Text = info.desc, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 230), TextStrokeTransparency = 1 })
	local b = button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(104, 42), Text = "R$ " .. info.price, BackgroundColor3 = Color3.fromRGB(40, 170, 90) })
	b.Activated:Connect(function()
		if info.id == 0 then
			toast("Coming soon! (Developer: paste the ID into Config)", "info")
			return
		end
		onBuy(info.id)
	end)
	return b
end

label(list, { Size = UDim2.new(1, -8, 0, 26), Text = "Game Passes (forever)", LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 210, 90) })
local order = 1
local passNames = {}
for name in pairs(Config.GamePasses) do
	table.insert(passNames, name)
end
table.sort(passNames)
for _, name in ipairs(passNames) do
	passButtons[name] = shopRow(order, Config.GamePasses[name], function(id)
		MarketplaceService:PromptGamePassPurchase(player, id)
	end)
	order += 1
end
label(list, { Size = UDim2.new(1, -8, 0, 26), Text = "Boosts", LayoutOrder = 100, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 210, 90) })
order = 101
local productNames = {}
for name in pairs(Config.DevProducts) do
	table.insert(productNames, name)
end
table.sort(productNames)
for _, name in ipairs(productNames) do
	shopRow(order, Config.DevProducts[name], function(id)
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	order += 1
end

local function refreshPasses()
	for name, b in pairs(passButtons) do
		if player:GetAttribute("Pass_" .. name) then
			b.Text = "Owned ✓"
			b.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
			b.Active = false
			b.AutoButtonColor = false
		end
	end
end
for name in pairs(Config.GamePasses) do
	player:GetAttributeChangedSignal("Pass_" .. name):Connect(refreshPasses)
end
refreshPasses()

-- Rebirth
local rebirth = makePanel("🌟 Rebirth")
local rebirthInfo = label(rebirth, { Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -40, 0, 170), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
make("UITextSizeConstraint", { MaxTextSize = 24 }, rebirthInfo)
local rebirthButton = button(rebirth, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(240, 60), Text = "REBIRTH" })
rebirthButton.Activated:Connect(function()
	RebirthRE:FireServer()
	rebirth.Visible = false
end)
local function refreshRebirth()
	local n = player:GetAttribute("Rebirths") or 0
	local cost = Config.RebirthCost(n)
	rebirthInfo.Text = ("Rebirths: %d\nCost: %s Air\n\nReward: +%d%% Air forever, +%d pedestals\n\nResets your Air and Floaties — you KEEP your best Floatie.")
		:format(n, Config.Format(cost), math.floor(Config.RebirthIncomeBonus * 100), Config.PedestalsPerRebirth)
	local canAfford = (player:GetAttribute("Air") or 0) >= cost
	rebirthButton.BackgroundColor3 = if canAfford then Color3.fromRGB(255, 170, 40) else Color3.fromRGB(90, 90, 110)
end

-- Codes
local codes = makePanel("🎁 Codes")
local codeBox = round(make("TextBox", {
	Position = UDim2.fromOffset(30, 90), Size = UDim2.new(1, -60, 0, 56), BackgroundColor3 = WHITE,
	Font = FONT, TextScaled = true, TextColor3 = DARK, PlaceholderText = "Enter code", Text = "", ClearTextOnFocus = false,
}, codes), 10)
local codeResult = label(codes, { Position = UDim2.fromOffset(30, 160), Size = UDim2.new(1, -60, 0, 34) })
local redeem = button(codes, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(220, 58), Text = "REDEEM" })
local redeeming = false
redeem.Activated:Connect(function()
	if redeeming then
		return
	end
	redeeming = true
	local ok, success, msg = pcall(function()
		return RedeemRF:InvokeServer(codeBox.Text)
	end)
	if ok then
		codeResult.Text = msg or ""
		codeResult.TextColor3 = if success then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120)
	end
	redeeming = false
end)
label(codes, { Position = UDim2.fromOffset(30, 56), Size = UDim2.new(1, -60, 0, 26), Text = "Follow us for new codes!", TextColor3 = Color3.fromRGB(200, 200, 230) })

-- Side buttons
local side = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(84, 270), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, side)
local function sideButton(text, color, order2, panel)
	local b = button(side, { Size = UDim2.fromOffset(84, 80), Text = text, BackgroundColor3 = color, LayoutOrder = order2 })
	stroke(b, WHITE, 2)
	b.Activated:Connect(function()
		toggle(panel)
		if panel == rebirth then
			refreshRebirth()
		end
	end)
end
sideButton("🛒\nShop", Color3.fromRGB(40, 170, 90), 1, shop)
sideButton("🌟\nRebirth", Color3.fromRGB(255, 170, 40), 2, rebirth)
sideButton("🎁\nCodes", Color3.fromRGB(80, 140, 255), 3, codes)

---------------------------------------------------------------------
-- Prompt visibility: you only see Steal on others' bases, Sell/Lock on yours
---------------------------------------------------------------------
local basesFolder = workspace:WaitForChild("Map"):WaitForChild("Bases")
local function updatePrompts()
	local t = workspace:GetServerTimeNow()
	local carrying = player:GetAttribute("CarryEndsAt") ~= nil
	for _, ped in ipairs(CollectionService:GetTagged("Pedestal")) do
		local baseFolder = basesFolder:FindFirstChild("Base" .. tostring(ped:GetAttribute("BaseIndex")))
		local steal = ped:FindFirstChild("StealPrompt")
		local sell = ped:FindFirstChild("SellPrompt")
		if baseFolder and steal and sell then
			local owner = baseFolder:GetAttribute("OwnerUserId") or 0
			local has = ped:GetAttribute("HasFloatie") == true and ped:GetAttribute("Unlocked") == true
			local mine = owner == player.UserId
			local locked = (baseFolder:GetAttribute("LockedUntil") or 0) > t
			steal.Enabled = has and not mine and owner ~= 0 and not locked and not carrying
			sell.Enabled = has and mine
		end
	end
	for _, btn in ipairs(CollectionService:GetTagged("LockButton")) do
		local baseFolder = basesFolder:FindFirstChild("Base" .. tostring(btn:GetAttribute("BaseIndex")))
		local pr = btn:FindFirstChild("LockPrompt")
		if baseFolder and pr then
			pr.Enabled = baseFolder:GetAttribute("OwnerUserId") == player.UserId
		end
	end
end

---------------------------------------------------------------------
-- Dart Blaster
---------------------------------------------------------------------
local mouse = player:GetMouse()
local hooked = {}
local nextShot = 0
local function hookTool(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Dart Blaster" or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Equipped:Connect(function()
		mouse.Icon = "rbxasset://textures/GunCursor.png"
	end)
	tool.Unequipped:Connect(function()
		mouse.Icon = ""
	end)
	tool.Activated:Connect(function()
		local clock = os.clock()
		if clock < nextShot then
			return
		end
		nextShot = clock + Config.DartCooldown
		playSound("Dart")
		FireDartRE:FireServer(mouse.Hit.Position)
	end)
end
local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end
player.CharacterAdded:Connect(function(character)
	watchContainer(character)
	watchContainer(player:WaitForChild("Backpack"))
end)
if player.Character then
	watchContainer(player.Character)
end
watchContainer(player:WaitForChild("Backpack"))

---------------------------------------------------------------------
-- Knockback (darts, pops, wind, locked bases)
---------------------------------------------------------------------
KnockbackRE.OnClientEvent:Connect(function(velocity)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or typeof(velocity) ~= "Vector3" then
		return
	end
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	hrp.AssemblyLinearVelocity = velocity
end)

---------------------------------------------------------------------
-- Rainbow Floaties (color cycling runs on each client, saves bandwidth)
---------------------------------------------------------------------
local rainbowAccum = 0
RunService.RenderStepped:Connect(function(dt)
	rainbowAccum += dt
	if rainbowAccum < 0.1 then
		return
	end
	rainbowAccum = 0
	local hue = (os.clock() * 0.25) % 1
	for _, model in ipairs(CollectionService:GetTagged("RainbowFloatie")) do
		local i = 0
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("Paint") then
				i += 1
				p.Color = Color3.fromHSV((hue + i * 0.07) % 1, 0.7, 1)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Tutorial for brand-new players: a hint box + a yellow line and arrow
-- pointing where to go. Steps: buy -> steal -> run home -> defend.
---------------------------------------------------------------------
local tutorialBox = round(make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 144), Size = UDim2.new(0.9, 0, 0, 66),
	BackgroundColor3 = Color3.fromRGB(255, 225, 90), Visible = false,
}, gui), 12)
stroke(tutorialBox, WHITE, 3)
make("UISizeConstraint", { MaxSize = Vector2.new(480, 66) }, tutorialBox)
local tutorialText = label(tutorialBox, {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12),
	TextColor3 = DARK, TextStrokeTransparency = 1, TextWrapped = true,
})
make("UITextSizeConstraint", { MaxTextSize = 22 }, tutorialText)

local targetPart = make("Part", {
	Name = "TutorialTarget", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	Transparency = 1, Size = Vector3.new(1, 1, 1),
}, nil)
local targetAtt = make("Attachment", { Name = "Target" }, targetPart)
local arrowGui = make("BillboardGui", { Size = UDim2.fromOffset(80, 80), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true }, targetPart)
label(arrowGui, { Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = Color3.fromRGB(255, 230, 60), TextStrokeTransparency = 0 })
local beam = make("Beam", {
	Attachment1 = targetAtt, Color = ColorSequence.new(Color3.fromRGB(255, 230, 60)),
	Width0 = 0.5, Width1 = 0.5, FaceCamera = true, LightEmission = 1, Segments = 1,
	Transparency = NumberSequence.new(0.25),
}, targetPart)

local STEP_TEXT = {
	"Step 1/4: Follow the yellow line to the Pump Line and press E to BUY a Floatie!",
	"Step 2/4: Your Floaties earn Air and inflate. Now sneak into another base and HOLD E to STEAL one!",
	"Step 3/4: RUN back to your base before they POP it with darts!",
	"Step 4/4: Defend! Press 1 for your Dart Blaster and click thieves. Press E on your red button to LOCK your base.",
}
local tutorialStep = 0
local stepStarted = 0
local function setStep(n)
	tutorialStep = n
	stepStarted = os.clock()
	if n > #STEP_TEXT then
		tutorialBox.Visible = false
		targetPart.Parent = nil
		toast("Tutorial done! Catch rare Floaties and let them grow to MEGA 🎈", "success")
	end
end
local function baseFolderOf(index)
	return basesFolder:FindFirstChild("Base" .. tostring(index))
end
local function nearestOtherBase(fromPos)
	local best, bestDist = nil, math.huge
	for _, b in ipairs(basesFolder:GetChildren()) do
		local owner = b:GetAttribute("OwnerUserId") or 0
		local floor = b:FindFirstChild("Floor")
		if owner ~= 0 and owner ~= player.UserId and floor then
			local d = (floor.Position - fromPos).Magnitude
			if d < bestDist then
				best, bestDist = floor.Position, d
			end
		end
	end
	return best
end

local function updateTutorial()
	if tutorialStep == 0 then
		if player:GetAttribute("ShowTutorial") then
			setStep(1)
		else
			return
		end
	end
	if tutorialStep > #STEP_TEXT then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local elapsed = os.clock() - stepStarted
	local carrying = player:GetAttribute("CarryEndsAt") ~= nil
	local myBase = baseFolderOf(player:GetAttribute("BaseIndex"))
	local target = nil
	local text = STEP_TEXT[tutorialStep]

	if tutorialStep == 1 then
		if (player:GetAttribute("IncomePerSec") or 0) > 0 then
			setStep(2)
			return
		end
		target = Vector3.new(0, 2, math.clamp(hrp.Position.Z, -140, 140))
	elseif tutorialStep == 2 then
		if carrying then
			setStep(3)
			return
		end
		if elapsed > 45 then
			setStep(4)
			return
		end
		target = nearestOtherBase(hrp.Position)
		if not target then
			text ..= " (Nobody else here yet — skipping soon.)"
		end
	elseif tutorialStep == 3 then
		if not carrying then
			setStep(4)
			return
		end
		local floor = myBase and myBase:FindFirstChild("Floor")
		target = floor and floor.Position
	elseif tutorialStep == 4 then
		if elapsed > 14 then
			setStep(5)
			return
		end
		local btn = myBase and myBase:FindFirstChild("LockButton")
		target = btn and btn.Position
	end

	tutorialBox.Visible = true
	tutorialText.Text = text
	if target then
		targetPart.Position = target
		targetPart.Parent = workspace
		local att = hrp:FindFirstChild("TutorialAtt") or make("Attachment", { Name = "TutorialAtt" }, hrp)
		beam.Attachment0 = att
	else
		targetPart.Parent = nil
	end
end

-- click sound on every HUD button
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("TextButton") then
		d.Activated:Connect(function()
			playSound("Click")
		end)
	end
end

---------------------------------------------------------------------
-- Slow UI loop
---------------------------------------------------------------------
task.spawn(function()
	while true do
		updateTutorial()
		updatePrompts()
		updateEvent()
		updateCarry()
		if rebirth.Visible then
			refreshRebirth()
		end
		task.wait(0.2)
	end
end)
