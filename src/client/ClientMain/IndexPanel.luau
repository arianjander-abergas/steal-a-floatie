--[[
	Floatie Farm — IndexPanel (ModuleScript child of the ClientMain LocalScript)
	The Index (Anime Dice's size + mutation filters, Anime Card Farm's look):
	  • size buttons across the top (Normal / Huge / Titanic) and mutation tabs
	    down the left (Normal, Silver ... Rainbow, Thunder); together they pick
	    one version of every Floatie: 50 x 3 x 8 = 1,200 entries
	  • each entry shows the odds of that exact copy (Floatie x size x mutation)
	    and is framed in the rarity those odds make it, so the rare tabs are the
	    long grind (a Titanic Rainbow Pupfloat is 1 in 200M: Celestial)
	  • "3% Completed · 41/1200 Collected" in the header
	  • found entries show their 3D model, the rest a padlock, "???" and their odds
	  • the next milestone, its reward (+2% Luck forever each) and CLAIM

	API:
	  IndexPanel.mount(canvas) -> Panel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local RewardInfo = require(Shared:WaitForChild("RewardInfo"))
local Kit = require(script.Parent.Kit)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer
local C = Config.UI

local IndexPanel = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local DARK = Color3.fromRGB(26, 24, 36)
local TOTAL = #Config.Floaties * #Config.Forms * #Config.Mutations

local panel = nil
local tabs = nil         -- mutation tabs (left)
local sizeTabs = nil     -- Normal / Huge / Titanic (top)
local entries = {}       -- [i] = { def, frame, border, preview, name, odds, lock }
local completion = nil
local milestoneBar, claimButton = nil, nil
local mutation = "Normal"
local size = "Normal"

-- every Floatie, by rarity then odds
local ordered = table.clone(Config.Floaties)
table.sort(ordered, function(a, b)
	local ra, rb = Config.Rarities[a.rarity].order, Config.Rarities[b.rarity].order
	if ra ~= rb then
		return ra < rb
	end
	return a.odds < b.odds
end)

local function found(id, mut, form)
	local index = State.data.index or {}
	return index[Formulas.indexKey(id, mut, form)] == true
end

-- how many entries are found; mut / form = nil counts every one
local function countFound(mut, form)
	local n = 0
	for _, def in ipairs(Config.Floaties) do
		for _, f in ipairs(Config.Forms) do
			for _, m in ipairs(Config.Mutations) do
				if (mut == nil or mut == m.id) and (form == nil or form == f.id) and found(def.id, m.id, f.id) then
					n += 1
				end
			end
		end
	end
	return n
end

local function refresh()
	if not panel or not panel:isOpen() then
		return
	end
	local total = countFound(nil, nil)
	completion.Text = ("%d%% Completed\n%d/%d Collected"):format(math.floor(total / TOTAL * 100), total, TOTAL)
	for _, e in ipairs(entries) do
		local has = found(e.def.id, mutation, size)
		local odds = Formulas.copyOdds(e.def.id, mutation, size)
		local rarityName = Config.RarityForOdds(odds) -- this version's own rarity
		local rarityColor = Config.Rarities[rarityName].color
		e.preview:setFloatie(if has then e.def.id else nil, mutation)
		e.preview.frame.Visible = has
		e.lock.Visible = not has
		e.name.Text = if has then e.def.name else "???"
		e.name.TextColor3 = if has then Kit.rarityTextColor(rarityName):Lerp(Color3.new(1, 1, 1), 0.35) else C.TextSoft
		e.odds.Text = Config.FormatOdds(odds)
		e.odds.TextColor3 = rarityColor:Lerp(Color3.new(1, 1, 1), 0.3)
		if e.border then
			e.border.Color = rarityColor:Lerp(Color3.new(0, 0, 0), 0.25)
		end
		e.frame.BackgroundColor3 = if has then rarityColor:Lerp(DARK, 0.55) else DARK
	end
	for name, button in pairs(tabs.buttons) do
		Kit.setButtonText(button, (Cards.MUTATION_ICONS[name] or "🎈") .. " " .. name .. "  " .. countFound(name, size) .. "/" .. #Config.Floaties)
	end
	for name, button in pairs(sizeTabs.buttons) do
		Kit.setButtonText(button, name .. "  " .. countFound(nil, name) .. "/" .. (#Config.Floaties * #Config.Mutations))
	end
	-- the next milestone
	local claimed = State.data.indexClaimed or 0
	local nextMilestone = Config.IndexMilestones[claimed + 1]
	if nextMilestone then
		local ready = total >= nextMilestone.count
		milestoneBar:set(total / nextMilestone.count, ("%d/%d  •  %s  •  +%d%% Luck"):format(
			math.min(total, nextMilestone.count), nextMilestone.count, RewardInfo.text(nextMilestone.reward), math.floor(Config.IndexLuckPerMilestone * 100 + 0.5)))
		Kit.setButtonColor(claimButton, if ready then C.Green else C.Grey)
		Kit.setButtonText(claimButton, if ready then "🎁 CLAIM" else "🔒 " .. (nextMilestone.count - total) .. " more")
	else
		milestoneBar:set(1, "Every milestone claimed! +" .. math.floor(#Config.IndexMilestones * Config.IndexLuckPerMilestone * 100 + 0.5) .. "% Luck 🏆")
		Kit.setButtonColor(claimButton, C.Grey)
		Kit.setButtonText(claimButton, "DONE ✓")
	end
end

function IndexPanel.mount(canvas)
	if panel then
		return panel
	end
	panel = Kit.panel(canvas, {
		name = "IndexPanel", title = "Index", icon = "📖", color = C.Teal,
		size = Vector2.new(720, 360), onOpen = refresh,
	})
	completion = Kit.label(panel.header, {
		Name = "Completion", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(220, 40),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 255, 150), ZIndex = 4,
	}, { outline = 3, maxTextSize = 18 })
	local body = panel.body -- 696 x 292

	local items = {}
	for _, m in ipairs(Config.Mutations) do
		table.insert(items, { name = m.id, text = m.id, color = if m.color then m.color:Lerp(Color3.new(0, 0, 0), 0.25) else C.Blue })
	end
	tabs = Kit.tabs(body, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(150, 292) }, {
		vertical = true, button = Vector2.new(150, 31), gap = 4, maxTextSize = 15, items = items, -- 8 tabs fit 292 px
		onSelect = function(name)
			mutation = name
			refresh()
		end,
	})

	-- sizes across the top of the grid (Anime Dice's None / Huge / Titanic)
	local sizeItems = {}
	for _, form in ipairs(Config.Forms) do
		table.insert(sizeItems, { name = form.id, text = form.id, color = if form.color then form.color:Lerp(Color3.new(0, 0, 0), 0.3) else C.Blue })
	end
	sizeTabs = Kit.tabs(body, { Position = UDim2.fromOffset(160, 0), Size = UDim2.new(1, -160, 0, 32) }, {
		button = Vector2.new(170, 30), gap = 6, maxTextSize = 15, items = sizeItems,
		onSelect = function(name)
			size = name
			refresh()
		end,
	})

	local grid = Kit.scroll(body, { Name = "Entries", Position = UDim2.fromOffset(160, 38), Size = UDim2.new(1, -160, 1, -92) }, { cell = Vector2.new(84, 104), gap = 6 })
	for i, def in ipairs(ordered) do
		local frame = Kit.plate(grid, { Name = def.id, LayoutOrder = i }, { color = DARK, transparency = 0, radius = 10, border = 3 })
		local border = frame:FindFirstChild("Border")
		if border then
			border.Color = Config.Rarities[def.rarity].color:Lerp(Color3.new(0, 0, 0), 0.25)
		end
		local preview = Kit.viewport(frame, { Name = "Preview", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -8, 0.58, 0) })
		local lock = Kit.label(frame, { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, -24, 0.48, 0), Text = "🔒" }, { outline = 0 })
		local name = Kit.label(frame, { Name = "FloatieName", Position = UDim2.new(0, 4, 0.62, 0), Size = UDim2.new(1, -8, 0.18, 0) }, { maxTextSize = 15 })
		local odds = Kit.label(frame, {
			Name = "Odds", Position = UDim2.new(0, 4, 0.8, 0), Size = UDim2.new(1, -8, 0.16, 0),
			Text = Config.FormatOdds(def.odds), TextColor3 = Config.Rarities[def.rarity].color:Lerp(Color3.new(1, 1, 1), 0.3),
		}, { maxTextSize = 13 })
		table.insert(entries, { def = def, frame = frame, border = border, preview = preview, name = name, odds = odds, lock = lock })
	end

	milestoneBar = Kit.progress(body, {
		Name = "Milestone", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 160, 1, -4), Size = UDim2.new(1, -330, 0, 40),
	}, { color = C.Teal, maxTextSize = 15 })
	claimButton = Kit.button(body, {
		Name = "Claim", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -2), Size = UDim2.fromOffset(160, 44),
	}, { text = "CLAIM", color = C.Grey, maxTextSize = 20 })
	Kit.onClick(claimButton, function()
		local ok, success, msg = pcall(function()
			return remotes.ClaimIndex:InvokeServer()
		end)
		if ok and not success and msg then
			Notify.toast(msg, "error")
		end
	end)

	tabs:select("Normal", true)
	sizeTabs:select("Normal", true)
	State.changed:Connect(function(what)
		if what == "index" or what == "indexClaimed" or what == "full" then
			refresh()
		end
	end)
	return panel
end

return IndexPanel
