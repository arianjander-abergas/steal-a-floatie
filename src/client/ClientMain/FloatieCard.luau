--[[
	Floatie Farm — FloatieCard (ModuleScript child of the ClientMain LocalScript)
	The card for ONE Floatie, opened by clicking it on your base (or pressing
	E next to it) or in the Backpack. It opens on top of other panels.
	  • big spinning preview, rarity, "1 in X", mutation, grade, trait
	  • level bar with the next size milestone, Air per second, sell value
	  • Level Up (+1 / +10 / MAX, the manual upgrade), Equip / Unequip, Lock, Sell
	  • shortcuts to the Grading and Traits stands for this Floatie

	API:
	  FloatieCard.mount(canvas, actions)   -- actions.openReroll(kind, uid) (kind = "grade" | "trait")
	  FloatieCard.open(uid)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer
local C = Config.UI

local FloatieCard = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local panel = nil
local actions = {}
local uid = nil
local ui = {}
local busy = false

---------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------
local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	local f = uid and State.get(uid)
	if not f then
		panel:close() -- sold / traded away
		return
	end
	local def = Config.FloatieById[f.id]
	local rarity = Config.Rarities[def.rarity]
	local mut = Config.MutationById[f.mut or "Normal"]
	local grade = Config.GradeById[f.grade or "C"]
	local trait = f.trait and Config.TraitById[f.trait]
	local cash = tonumber(player:GetAttribute("CashMultiplier")) or 1
	local air = tonumber(player:GetAttribute("Air")) or 0

	panel.header.Title.Text = (Cards.MUTATION_ICONS[f.mut] or "🎈") .. " " .. (if f.mut ~= "Normal" then f.mut .. " " else "") .. def.name
	ui.preview:setFloatie(def.id, f.mut)
	ui.glow.BackgroundColor3 = rarity.color
	ui.rarity.Text = string.upper(def.rarity) .. "  •  " .. Config.FormatOdds(Formulas.copyOdds(def.id, f.mut))
	ui.rarity.TextColor3 = Kit.rarityTextColor(def.rarity)
	ui.mutation.Text = "Mutation: " .. f.mut .. "  " .. Config.FormatMult(mut.mult)
	ui.mutation.TextColor3 = if mut.color then mut.color else C.TextSoft
	ui.grade.Text = "Grade: " .. grade.id .. "  " .. Config.FormatMult(grade.mult)
	ui.grade.TextColor3 = grade.color
	ui.trait.Text = "Trait: " .. (if trait then trait.name .. "  " .. (trait.desc or Config.FormatMult(trait.mult)) else "none")
	ui.trait.TextColor3 = if trait then trait.color else C.TextSoft

	local size = Formulas.size(f.level)
	local nextSize = Formulas.nextSize(f.level)
	local maxLevel = Config.Levels.Max
	ui.levelBar:set(f.level / maxLevel, ("Lv %d / %d  •  %s%s"):format(f.level, maxLevel, size.name,
		if nextSize then "  (" .. nextSize.name .. " at " .. nextSize.level .. ")" else ""))
	ui.income.Text = "+" .. Config.Format(Formulas.baseIncome(f) * cash) .. " Air/s" .. (if f.slot then "" else "  (in Backpack)")
	ui.value.Text = "Sell value: " .. Config.Format(Formulas.sellValue(f)) .. " Air"

	-- level up buttons: price + affordability
	local maxed = f.level >= maxLevel
	local cost1 = Formulas.levelCost(f, 1)
	local cost10, n10 = Formulas.levelCost(f, 10)
	local nMax = Formulas.affordableLevels(f, air, maxLevel)
	Kit.setButtonText(ui.up1, if maxed then "MAX LEVEL" else "+1  " .. Config.Format(cost1))
	Kit.setButtonColor(ui.up1, if not maxed and air >= cost1 then C.Green else C.Grey)
	Kit.setButtonText(ui.up10, if maxed then "-" else "+" .. n10 .. "  " .. Config.Format(cost10))
	Kit.setButtonColor(ui.up10, if not maxed and air >= cost10 then C.Green else C.Grey)
	Kit.setButtonText(ui.upMax, if nMax > 0 then "MAX +" .. nMax else "MAX")
	Kit.setButtonColor(ui.upMax, if nMax > 0 then C.Orange else C.Grey)

	Kit.setButtonText(ui.equip, if f.slot then "📤 Unequip" else "📥 Equip")
	Kit.setButtonColor(ui.equip, if f.slot then C.Blue else C.Green)
	Kit.setButtonText(ui.lock, if f.locked then "🔓 Unlock" else "🔒 Lock")
	Kit.setButtonText(ui.sell, "💰 Sell")
	Kit.setButtonColor(ui.sell, if f.locked then C.Grey else C.Red)
end

---------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------
local function levelUp(count)
	if busy or not uid then
		return
	end
	busy = true
	local ok, success, msg = pcall(function()
		return remotes.LevelUp:InvokeServer(uid, count)
	end)
	busy = false
	if ok and not success and msg then
		Notify.toast(msg, "error")
	end
end

local function sell()
	local f = uid and State.get(uid)
	if not f or busy then
		return
	end
	if f.locked then
		Notify.toast("Unlock it first 🔒", "error")
		return
	end
	local def = Config.FloatieById[f.id]
	local rarityOrder = Config.Rarities[def.rarity].order
	local function doSell()
		busy = true
		pcall(function()
			remotes.SellFloaties:InvokeServer({ uid })
		end)
		busy = false
	end
	if rarityOrder >= 4 or f.mut ~= "Normal" or (f.level or 1) >= 10 then
		Kit.confirm({
			title = "Sell " .. def.name .. "?",
			text = ("Sell your %s%s (Lv %d) for %s Air? This can't be undone."):format(
				if f.mut ~= "Normal" then f.mut .. " " else "", def.name, f.level or 1, Config.Format(Formulas.sellValue(f))),
			yes = "Sell", no = "Keep",
		}, function(yes)
			if yes then
				doSell()
			end
		end)
	else
		doSell()
	end
end

---------------------------------------------------------------------
-- Mount / open
---------------------------------------------------------------------
function FloatieCard.mount(canvas, acts)
	if panel then
		return panel
	end
	actions = acts or {}
	panel = Kit.panel(canvas, {
		name = "FloatieCardPanel", title = "Floatie", icon = "🎈", color = C.Purple,
		size = Vector2.new(560, 336), stack = true, onOpen = refresh,
	})
	local body = panel.body -- 536 x 268

	-- left: the preview on a glowing rarity circle
	ui.glow = Kit.make("Frame", {
		Name = "Glow", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = C.Blue, BackgroundTransparency = 0.55, BorderSizePixel = 0,
	}, body)
	Kit.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ui.glow)
	ui.preview = Kit.viewport(body, {
		Name = "Preview", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(198, 198), ZIndex = 2,
	}, { spin = true })
	ui.value = Kit.label(body, {
		Name = "Value", Position = UDim2.fromOffset(0, 202), Size = UDim2.fromOffset(198, 20), TextColor3 = C.Gold,
	}, { maxTextSize = 17 })
	ui.gradeButton = Kit.button(body, {
		Name = "GradeShortcut", Position = UDim2.fromOffset(0, 228), Size = UDim2.fromOffset(95, 36),
	}, { text = "🎫 Grade", color = C.Orange, maxTextSize = 17, radius = 10 })
	ui.traitButton = Kit.button(body, {
		Name = "TraitShortcut", Position = UDim2.fromOffset(103, 228), Size = UDim2.fromOffset(95, 36),
	}, { text = "💎 Trait", color = C.Purple, maxTextSize = 17, radius = 10 })

	-- right: the numbers
	local x = 212
	local w = -x
	local function line(name, y, h, maxSize, color)
		return Kit.label(body, {
			Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, w, 0, h),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or C.Text,
		}, { maxTextSize = maxSize })
	end
	ui.rarity = line("Rarity", 0, 24, 22)
	ui.mutation = line("Mutation", 28, 20, 18)
	ui.grade = line("Grade", 50, 20, 18)
	ui.trait = line("Trait", 72, 20, 18)
	ui.levelBar = Kit.progress(body, {
		Name = "LevelBar", Position = UDim2.fromOffset(x, 98), Size = UDim2.new(1, w, 0, 26),
	}, { color = C.Blue, maxTextSize = 16 })
	ui.income = line("Income", 128, 24, 22, C.Income)

	-- level up row
	local bw = (536 - x - 16) / 3
	ui.up1 = Kit.button(body, { Name = "Up1", Position = UDim2.fromOffset(x, 158), Size = UDim2.fromOffset(bw, 44) }, { text = "+1", color = C.Green, maxTextSize = 18 })
	ui.up10 = Kit.button(body, { Name = "Up10", Position = UDim2.fromOffset(x + bw + 8, 158), Size = UDim2.fromOffset(bw, 44) }, { text = "+10", color = C.Green, maxTextSize = 18 })
	ui.upMax = Kit.button(body, { Name = "UpMax", Position = UDim2.fromOffset(x + (bw + 8) * 2, 158), Size = UDim2.fromOffset(bw, 44) }, { text = "MAX", color = C.Orange, maxTextSize = 18 })
	Kit.onClick(ui.up1, function()
		levelUp(1)
	end)
	Kit.onClick(ui.up10, function()
		levelUp(10)
	end)
	Kit.onClick(ui.upMax, function()
		levelUp(Config.Levels.Max)
	end)

	-- equip / lock / sell row
	ui.equip = Kit.button(body, { Name = "Equip", Position = UDim2.fromOffset(x, 214), Size = UDim2.fromOffset(bw, 46) }, { text = "Equip", color = C.Green, maxTextSize = 18 })
	ui.lock = Kit.button(body, { Name = "Lock", Position = UDim2.fromOffset(x + bw + 8, 214), Size = UDim2.fromOffset(bw, 46) }, { text = "Lock", color = C.Yellow, maxTextSize = 18 })
	ui.sell = Kit.button(body, { Name = "Sell", Position = UDim2.fromOffset(x + (bw + 8) * 2, 214), Size = UDim2.fromOffset(bw, 46) }, { text = "Sell", color = C.Red, maxTextSize = 18 })
	Kit.onClick(ui.equip, function()
		local f = uid and State.get(uid)
		if f then
			remotes[if f.slot then "Unequip" else "Equip"]:FireServer(uid)
		end
	end)
	Kit.onClick(ui.lock, function()
		local f = uid and State.get(uid)
		if f then
			remotes.SetLocked:FireServer(uid, not f.locked)
		end
	end)
	Kit.onClick(ui.sell, sell)
	Kit.onClick(ui.gradeButton, function()
		if actions.openReroll and uid then
			actions.openReroll("grade", uid)
		else
			Notify.toast("Coming soon!", "info")
		end
	end)
	Kit.onClick(ui.traitButton, function()
		if actions.openReroll and uid then
			actions.openReroll("trait", uid)
		else
			Notify.toast("Coming soon!", "info")
		end
	end)

	State.changed:Connect(refresh)
	player:GetAttributeChangedSignal("Air"):Connect(refresh)
	player:GetAttributeChangedSignal("CashMultiplier"):Connect(refresh)
	return panel
end

function FloatieCard.open(id)
	if not panel or not State.get(id) then
		return
	end
	uid = id
	if panel:isOpen() then
		refresh()
	else
		panel:open()
	end
end

return FloatieCard
