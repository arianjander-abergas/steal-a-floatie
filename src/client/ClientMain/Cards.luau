--[[
	Floatie Farm — Cards (ModuleScript child of the ClientMain LocalScript)
	The Floatie tile used wherever Floaties are listed (Backpack, Sell,
	Grading, Traits, Trade): a spinning-free 3D preview on a rarity-colored
	card with its level, grade, mutation, lock and an "on base" stripe.

	API:
	  Cards.tile(parent, opts) -> Tile
	      opts = { size = Vector2.new(92, 112), onClick = fn(tile) }
	  tile:set(f)               a Floatie record (nil blanks it)
	  tile:setSelected(bool)    thick white outline
	  tile:setDim(bool)         greyed out (can't be picked here)
	  tile.button, tile.f
	  Cards.sorted(list, how)   -> new sorted table; how = "income" | "rarity" | "level" | "value"
	  Cards.MUTATION_ICONS      Glitter ✨ / Neon 💡 / Foil 🪩 / Rainbow 🌈 / Thunder ⚡
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Kit = require(script.Parent.Kit)

local C = Config.UI

local Cards = {}

Cards.MUTATION_ICONS = { Glitter = "✨", Neon = "💡", Foil = "🪩", Rainbow = "🌈", Thunder = "⚡" }

local DARK = Color3.fromRGB(26, 24, 36)

---------------------------------------------------------------------
-- Tile
---------------------------------------------------------------------
local Tile = {}
Tile.__index = Tile

function Tile:set(f)
	self.f = f
	local def = f and Config.FloatieById[f.id]
	self.button.Visible = def ~= nil
	if not def then
		self.preview:setFloatie(nil)
		return
	end
	local rarity = Config.Rarities[def.rarity]
	Kit.setButtonColor(self.button, rarity.color:Lerp(DARK, 0.55))
	self.preview:setFloatie(def.id, f.mut)
	self.name.Text = def.name
	self.name.TextColor3 = Kit.rarityTextColor(def.rarity):Lerp(Color3.new(1, 1, 1), 0.35)
	self.level.Text = "Lv " .. (f.level or 1)
	self.income.Text = "+" .. Config.Format(Formulas.baseIncome(f))
	local grade = Config.GradeById[f.grade or "C"]
	self.grade.Visible = grade ~= nil and grade.id ~= "C"
	if grade then
		self.grade.Text = grade.id
		self.grade.TextColor3 = grade.color
	end
	local icon = Cards.MUTATION_ICONS[f.mut or "Normal"]
	self.mut.Visible = icon ~= nil
	self.mut.Text = icon or ""
	self.lock.Visible = f.locked == true
	self.onBase.Visible = f.slot ~= nil
end

function Tile:setSelected(selected)
	local border = self.button.Face:FindFirstChild("Border")
	if border then
		border.Color = if selected then Color3.new(1, 1, 1) else C.Outline
		border.Thickness = if selected then 4 else 3
	end
	self.check.Visible = selected
end

function Tile:setDim(dim)
	Kit.setEnabled(self.button, not dim)
end

function Cards.tile(parent, opts)
	opts = opts or {}
	local size = opts.size or Vector2.new(92, 112)
	local button = Kit.button(parent, {
		Name = "Tile", Size = UDim2.fromOffset(size.X, size.Y),
	}, { text = "", color = C.Row, radius = 10, border = 3, sound = "Click" })
	local face = button.Face
	local preview = Kit.viewport(face, {
		Name = "Preview", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -10, 0.56, 0), ZIndex = 2,
	})
	local name = Kit.label(face, {
		Name = "FloatieName", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 0),
		Size = UDim2.new(1, -8, 0.18, 0), ZIndex = 3,
	}, { maxTextSize = 16 })
	local level = Kit.label(face, {
		Name = "Level", Position = UDim2.new(0, 5, 0.79, 0), Size = UDim2.new(0.45, -5, 0.17, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, { maxTextSize = 14 })
	local income = Kit.label(face, {
		Name = "Income", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0.79, 0), Size = UDim2.new(0.55, -5, 0.17, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Income, ZIndex = 3,
	}, { maxTextSize = 14 })
	local grade = Kit.label(face, {
		Name = "Grade", Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(26, 20),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Visible = false,
	}, { outline = 2, maxTextSize = 18 })
	local mut = Kit.label(face, {
		Name = "Mutation", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), Size = UDim2.fromOffset(22, 22),
		ZIndex = 4, Visible = false,
	}, { outline = 0 })
	local lock = Kit.label(face, {
		Name = "Lock", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 0.62, 0), Size = UDim2.fromOffset(20, 20),
		Text = "🔒", ZIndex = 4, Visible = false,
	}, { outline = 0 })
	local onBase = Kit.make("Frame", {
		Name = "OnBase", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.6, 0, 0, 5),
		BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 5, Visible = false,
	}, face)
	Kit.round(onBase, 3)
	local check = Kit.label(face, {
		Name = "Check", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(36, 36),
		Text = "✅", ZIndex = 6, Visible = false,
	}, { outline = 0 })

	local tile = setmetatable({
		button = button, preview = preview, name = name, level = level, income = income,
		grade = grade, mut = mut, lock = lock, onBase = onBase, check = check, f = nil,
	}, Tile)
	if opts.onClick then
		Kit.onClick(button, function()
			opts.onClick(tile)
		end)
	end
	return tile
end

---------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------
function Cards.sorted(list, how)
	local out = table.clone(list)
	local function rarityOrder(f)
		local def = Config.FloatieById[f.id]
		return def and Config.Rarities[def.rarity].order or 0
	end
	table.sort(out, function(a, b)
		local ka, kb
		if how == "rarity" then
			ka, kb = rarityOrder(a) * 1e6 + Formulas.mutationMult(a), rarityOrder(b) * 1e6 + Formulas.mutationMult(b)
		elseif how == "level" then
			ka, kb = a.level or 1, b.level or 1
		elseif how == "value" then
			-- cheapest first
			ka, kb = -Formulas.sellValue(a), -Formulas.sellValue(b)
		else
			ka, kb = Formulas.baseIncome(a), Formulas.baseIncome(b)
		end
		if ka ~= kb then
			return ka > kb
		end
		return a.uid < b.uid
	end)
	return out
end

return Cards
