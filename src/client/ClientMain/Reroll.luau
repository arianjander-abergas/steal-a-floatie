--[[
	Floatie Farm — Reroll (ModuleScript child of the ClientMain LocalScript)
	The Grading and Traits stands (one module, two windows):
	  left   your Floaties (best first): tap one to pick it
	  right  its current grade / trait, the odds table, your Grade Tokens /
	         Trait Gems, and REROLL (a slot-machine spin, then the result).
	         Grading also sells one Grade Token for Air (the price climbs).
	Rerolling a grade of S or better, or a trait of Sky King or better,
	asks "are you sure?" first: the new one can be worse.

	API:
	  Reroll.mount(canvas) -> { Grading = Panel, Traits = Panel }
	  Reroll.open(kind, uid?)   -- kind = "grade" | "trait"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer
local C = Config.UI

local Reroll = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MODES = {
	grade = {
		name = "Grading", title = "Grading", icon = "🎫", color = C.Orange, item = "gradeTokens", itemName = "Grade Token",
		remote = "RerollGrade", list = Config.Grades,
	},
	trait = {
		name = "Traits", title = "Traits", icon = "💎", color = C.Purple, item = "traitGems", itemName = "Trait Gem",
		remote = "RerollTrait", list = Config.Traits,
	},
}

local views = {} -- kind -> view state

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function current(kind, f)
	if kind == "grade" then
		return Config.GradeById[f.grade or "C"]
	end
	return f.trait and Config.TraitById[f.trait] or nil
end

local function entryText(kind, entry)
	if not entry then
		return "none"
	end
	if kind == "grade" then
		return entry.id
	end
	return entry.name
end

local function effectText(kind, entry)
	if not entry then
		return "no bonus"
	end
	if kind == "trait" and entry.desc then
		return entry.desc
	end
	return "income " .. Config.FormatMult(entry.mult)
end

local function percent(chance)
	local p = chance * 100
	if p >= 1 then
		return string.format("%g%%", math.floor(p * 10 + 0.5) / 10)
	end
	return string.format("%g%%", math.floor(p * 1000 + 0.5) / 1000)
end

---------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------
local function refresh(kind)
	local v = views[kind]
	if not v or not v.panel:isOpen() then
		return
	end
	local mode = MODES[kind]
	-- the picker
	local list = Cards.sorted(State.list(), "income")
	if v.uid and not State.get(v.uid) then
		v.uid = nil
	end
	if not v.uid and list[1] then
		v.uid = list[1].uid
	end
	for i, f in ipairs(list) do
		local tile = v.tiles[i]
		if not tile then
			tile = Cards.tile(v.grid, {
				onClick = function(t)
					if t.f and not v.spinning then
						v.uid = t.f.uid
						refresh(kind)
					end
				end,
			})
			v.tiles[i] = tile
		end
		tile.button.LayoutOrder = i
		tile:set(f)
		tile:setSelected(f.uid == v.uid)
	end
	for i = #list + 1, #v.tiles do
		v.tiles[i]:set(nil)
	end
	-- the selected one
	local f = v.uid and State.get(v.uid)
	v.empty.Visible = f == nil
	v.detail.Visible = f ~= nil
	local items = State.data.items or {}
	local have = items[mode.item] or 0
	v.count.Text = mode.icon .. " " .. mode.itemName .. "s: " .. have
	if f then
		local def = Config.FloatieById[f.id]
		v.preview:setFloatie(def.id, f.mut)
		v.name.Text = (if f.mut ~= "Normal" then f.mut .. " " else "") .. def.name .. "  •  Lv " .. f.level
		if not v.spinning then
			local entry = current(kind, f)
			v.result.Text = entryText(kind, entry)
			v.result.TextColor3 = if entry and entry.color then entry.color else C.TextSoft
			v.effect.Text = effectText(kind, entry)
		end
	end
	Kit.setButtonColor(v.rollButton, if have > 0 and f then mode.color else C.Grey)
	Kit.setButtonText(v.rollButton, "REROLL (1 " .. mode.icon .. ")")
	if v.buyButton then
		local cost = Formulas.gradeTokenCost(State.data.gradeTokensBought or 0)
		local air = tonumber(player:GetAttribute("Air")) or 0
		Kit.setButtonText(v.buyButton, "Buy 1 🎫 for 💨 " .. Config.Format(cost))
		Kit.setButtonColor(v.buyButton, if air >= cost then C.Green else C.Grey)
	end
	-- highlight the current entry in the odds table
	local entry = f and current(kind, f)
	for id, row in pairs(v.rows) do
		row.BackgroundTransparency = if entry and entry.id == id then 0.2 else 1
	end
end

---------------------------------------------------------------------
-- Reroll (with a slot-machine spin while the server answers)
---------------------------------------------------------------------
local function doReroll(kind)
	local v = views[kind]
	local mode = MODES[kind]
	local uid = v.uid
	if not uid or v.spinning then
		return
	end
	v.spinning = true
	local spinDone = false
	task.spawn(function()
		local list = mode.list
		local start = os.clock()
		while os.clock() - start < 0.9 do
			local e = list[math.random(1, #list)]
			v.result.Text = entryText(kind, e)
			v.result.TextColor3 = e.color or C.Text
			Sounds.play("Click")
			task.wait(0.07 + (os.clock() - start) * 0.08)
		end
		spinDone = true
	end)
	local ok, success, value = pcall(function()
		return remotes[mode.remote]:InvokeServer(uid)
	end)
	while not spinDone do
		task.wait()
	end
	v.spinning = false
	if not ok or not success then
		Notify.toast((ok and value) or "Try again", "error")
		refresh(kind)
		return
	end
	local entry = if kind == "grade" then Config.GradeById[value] else Config.TraitById[value]
	v.result.Text = entryText(kind, entry)
	v.result.TextColor3 = if entry and entry.color then entry.color else C.Text
	v.effect.Text = effectText(kind, entry)
	v.resultScale.Scale = 1.6
	Kit.tween(v.resultScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local best = entry and (entry.index or 0) >= #mode.list - 1
	Sounds.play(if best then "Rare" else "Buy")
	refresh(kind)
end

local function reroll(kind)
	local v = views[kind]
	local mode = MODES[kind]
	local f = v.uid and State.get(v.uid)
	if not f then
		return
	end
	local have = (State.data.items or {})[mode.item] or 0
	if have < 1 then
		Notify.toast("You need a " .. mode.itemName .. (if kind == "grade" then ": buy one below, or get them from rewards" else ": get them from rewards and the Shop"), "error")
		return
	end
	local entry = current(kind, f)
	local precious
	if kind == "grade" then
		precious = entry and entry.index >= Config.GradeById[Config.ConfirmGradeReroll].index
	else
		precious = entry ~= nil and entry.chance <= 0.015
	end
	if precious then
		Kit.confirm({
			title = "Reroll " .. entryText(kind, entry) .. "?",
			text = "This Floatie has " .. entryText(kind, entry) .. ". The new " .. (if kind == "grade" then "grade" else "trait") .. " can be worse. Reroll anyway?",
			yes = "Reroll", no = "Keep it",
		}, function(yes)
			if yes then
				doReroll(kind)
			end
		end)
	else
		doReroll(kind)
	end
end

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
local function build(canvas, kind)
	local mode = MODES[kind]
	local v = { tiles = {}, rows = {}, uid = nil, spinning = false }
	views[kind] = v
	v.panel = Kit.panel(canvas, {
		name = mode.name .. "Panel", title = mode.title, icon = mode.icon, color = mode.color,
		size = Vector2.new(680, 352),
		onOpen = function()
			refresh(kind)
		end,
	})
	local body = v.panel.body -- 656 x 284

	-- left: your Floaties
	v.grid = Kit.scroll(body, { Name = "Pick", Size = UDim2.new(0, 312, 1, 0) }, { cell = Vector2.new(92, 112), gap = 6 })

	-- right: the chosen one
	local right = Kit.make("Frame", { Name = "Right", Position = UDim2.fromOffset(322, 0), Size = UDim2.new(1, -322, 1, 0), BackgroundTransparency = 1 }, body)
	v.empty = Kit.label(right, { Name = "Empty", Size = UDim2.fromScale(1, 1), Text = "Roll a Floatie first!", TextColor3 = C.TextSoft }, { maxTextSize = 22 })
	v.detail = Kit.make("Frame", { Name = "Detail", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, right)
	v.preview = Kit.viewport(v.detail, { Name = "Preview", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(110, 110) }, { spin = true })
	v.name = Kit.label(v.detail, {
		Name = "FloatieName", Position = UDim2.fromOffset(116, 2), Size = UDim2.new(1, -116, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 18 })
	local holder = Kit.make("Frame", {
		Name = "ResultHolder", AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(116, 26), Size = UDim2.new(1, -116, 0, 52), BackgroundTransparency = 1,
	}, v.detail)
	v.resultScale = Kit.make("UIScale", { Name = "Pop" }, holder)
	v.result = Kit.label(holder, { Name = "Result", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left }, { outline = 4, maxTextSize = 46 })
	v.effect = Kit.label(v.detail, {
		Name = "Effect", Position = UDim2.fromOffset(116, 80), Size = UDim2.new(1, -116, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Income,
	}, { maxTextSize = 17 })

	-- the odds table
	local odds = Kit.scroll(v.detail, { Name = "Odds", Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 96) }, { gap = 0, pad = 2 })
	for i, entry in ipairs(mode.list) do
		local row = Kit.make("Frame", {
			Name = entry.id, Size = UDim2.new(1, -8, 0, 18), LayoutOrder = i, BackgroundColor3 = mode.color, BackgroundTransparency = 1, BorderSizePixel = 0,
		}, odds)
		Kit.round(row, 6)
		Kit.label(row, {
			Name = "Entry", Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0.42, -6, 1, 0), Text = entryText(kind, entry),
			TextColor3 = entry.color or C.Text, TextXAlignment = Enum.TextXAlignment.Left,
		}, { maxTextSize = 15 })
		Kit.label(row, {
			Name = "Bonus", Position = UDim2.new(0.42, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0),
			Text = if entry.desc then (if entry.inflateCut then "inflate -10%" else "luck +10%") else Config.FormatMult(entry.mult),
			TextColor3 = C.TextSoft, TextXAlignment = Enum.TextXAlignment.Left,
		}, { outline = 0, maxTextSize = 14 })
		Kit.label(row, {
			Name = "Chance", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.2, 0, 1, 0),
			Text = percent(entry.chance), TextXAlignment = Enum.TextXAlignment.Right,
		}, { maxTextSize = 14 })
		v.rows[entry.id] = row
	end

	v.count = Kit.label(v.detail, {
		Name = "Count", Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left,
	}, { maxTextSize = 17 })
	local buttonWidth = if kind == "grade" then 0.48 else 1
	v.rollButton = Kit.button(v.detail, {
		Name = "Reroll", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(buttonWidth, -4, 0, 46),
	}, { text = "REROLL", color = mode.color, maxTextSize = 22 })
	Kit.onClick(v.rollButton, function()
		reroll(kind)
	end)
	if kind == "grade" then
		v.buyButton = Kit.button(v.detail, {
			Name = "BuyToken", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.new(0.52, -4, 0, 46),
		}, { text = "Buy 1 🎫", color = C.Green, maxTextSize = 17 })
		Kit.onClick(v.buyButton, function()
			local ok, success, msg = pcall(function()
				return remotes.BuyGradeToken:InvokeServer()
			end)
			if ok and msg then
				Notify.toast(msg, if success then "success" else "error")
			end
		end)
	end
	return v.panel
end

function Reroll.mount(canvas)
	local panels = {
		Grading = build(canvas, "grade"),
		Traits = build(canvas, "trait"),
	}
	State.changed:Connect(function()
		task.defer(refresh, "grade")
		task.defer(refresh, "trait")
	end)
	player:GetAttributeChangedSignal("Air"):Connect(function()
		refresh("grade")
	end)
	return panels
end

function Reroll.open(kind, uid)
	local v = views[kind]
	if not v then
		return
	end
	if uid then
		v.uid = uid
	end
	v.panel:open()
	refresh(kind)
end

return Reroll
