--[[
	Steal a Floatie — Codes (ModuleScript child of the ClientMain LocalScript)
	The Codes panel: type a code, press REDEEM, and the server's answer shows
	below the box in green (redeemed) or red (error). The codes themselves
	live in Config.Codes on the server side.

	API:
	  Codes.mount(canvas) -> Panel   -- builds the panel on the "FloatiePanels" Kit canvas
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent.Kit)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RedeemRF = Remotes:WaitForChild("RedeemCode")

local C = Config.UI

local Codes = {}

local panel = nil -- the Kit Panel, once mounted

---------------------------------------------------------------------
-- Mount
---------------------------------------------------------------------
function Codes.mount(canvas)
	if panel then
		return panel -- already built
	end

	panel = Kit.panel(canvas, {
		name = "CodesPanel",
		title = "Codes",
		icon = "🎁",
		color = C.Blue,
	})
	local body = panel.body

	Kit.label(body, {
		Name = "Subtitle",
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 0, 26),
		Text = "Follow us for new codes!",
		TextColor3 = C.TextSoft,
	}, { outline = 0 })

	-- white text box with a dark border
	local codeBox = Kit.make("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(18, 34),
		Size = UDim2.new(1, -36, 0, 56),
		BackgroundColor3 = C.Input,
		BorderSizePixel = 0,
		Font = Kit.FONT,
		TextScaled = true,
		TextColor3 = C.TextDark,
		PlaceholderText = "Enter code",
		Text = "",
		ClearTextOnFocus = false,
	}, body)
	Kit.round(codeBox, 10)
	Kit.stroke(codeBox, C.Outline, 3)
	-- keep the typed text off the rounded edges
	Kit.make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}, codeBox)

	local codeResult = Kit.label(body, {
		Name = "Result",
		Position = UDim2.fromOffset(18, 100),
		Size = UDim2.new(1, -36, 0, 34),
	})

	local redeem = Kit.button(body, {
		Name = "Redeem",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(220, 56),
	}, { text = "REDEEM", color = C.Pink })

	-- one request at a time; the server replies (success, message)
	local redeeming = false
	Kit.onClick(redeem, function()
		if redeeming then
			return
		end
		redeeming = true
		local ok, success, msg = pcall(RedeemRF.InvokeServer, RedeemRF, codeBox.Text)
		if ok then
			codeResult.Text = msg or ""
			codeResult.TextColor3 = if success then C.Good else C.Bad
		end
		redeeming = false
	end)

	return panel
end

return Codes
