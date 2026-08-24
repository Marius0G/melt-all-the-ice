--!strict
--[[
	HUD - money, progress, finds, the combo meter, and the two swing gates.

	Reads Player attributes, which the server owns and the client cannot write.
	This file renders numbers and nothing else; it never computes a value it
	displays, which keeps the display honest by construction.

	Styled to match the upgrade tree so the game reads as one thing: gradient
	panels, thick gold borders, one font family, padding on everything.

	The gate bar swaps with the equipped tool rather than showing both. Stamina
	and fuel are never spent at the same time - only one tool is in hand - so two
	bars would mean one of them is always stale decoration.

	The combo meter is the one piece here that is *only* feedback: it shows a
	number the server already applied. It sits top-centre and hides itself at
	zero rather than sitting there greyed out, because a meter that is always on
	screen showing nothing trains you to stop looking at it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local Feel = require(Shared:WaitForChild("Feel"))
local Tools = require(Shared:WaitForChild("Tools"))

local HUD = {}

local GOLD = Color3.fromRGB(255, 200, 38)
local GOLD_LIGHT = Color3.fromRGB(255, 233, 160)
local GOLD_DARK = Color3.fromRGB(184, 134, 11)
local PANEL_TOP = Color3.fromRGB(38, 52, 80)
local PANEL_BOTTOM = Color3.fromRGB(16, 24, 40)
local STAMINA = Color3.fromRGB(120, 200, 255)
local FUEL = Color3.fromRGB(255, 152, 60)
local LOW = Color3.fromRGB(224, 88, 88)

local function corner(parent: GuiObject, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function goldStroke(parent: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = Color3.new(1, 1, 1) -- stroke colour multiplies the gradient
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})
	gradient.Rotation = 90
	gradient.Parent = stroke
end

local function fill(parent: GuiObject)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(PANEL_TOP, PANEL_BOTTOM)
	gradient.Rotation = 90
	gradient.Parent = parent
end

local function toNumber(value: any, fallback: number): number
	return if typeof(value) == "number" then value else fallback
end

-- K/M/B, trailing zeros trimmed, because a six-figure balance in full is noise.
local UNITS: { { scale: number, suffix: string } } = {
	{ scale = 1e9, suffix = "B" },
	{ scale = 1e6, suffix = "M" },
	{ scale = 1e3, suffix = "K" },
}

local function abbreviate(value: number): string
	for _, unit in UNITS do
		if value >= unit.scale then
			local text = string.format("%.1f", value / unit.scale)
			text = string.gsub(text, "%.0$", "")
			return text .. unit.suffix
		end
	end
	return tostring(math.floor(value))
end

function HUD.start()
	local player = assert(Players.LocalPlayer, "HUD requires a LocalPlayer")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MeltHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top-left readout.
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(238, 118)
	panel.Position = UDim2.fromOffset(18, 18)
	panel.BackgroundColor3 = PANEL_TOP
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 14)
	fill(panel)
	goldStroke(panel, 3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = panel

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(1, 0, 0, 40)
	-- Anchored centre so the gain pop scales about itself, not a corner.
	moneyLabel.AnchorPoint = Vector2.new(0, 0.5)
	moneyLabel.Position = UDim2.fromOffset(0, 20)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Font = Enum.Font.FredokaOne
	moneyLabel.TextSize = 32
	moneyLabel.TextColor3 = GOLD
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.Parent = panel

	local thawedLabel = Instance.new("TextLabel")
	thawedLabel.Size = UDim2.new(1, 0, 0, 22)
	thawedLabel.Position = UDim2.fromOffset(0, 44)
	thawedLabel.BackgroundTransparency = 1
	thawedLabel.Font = Enum.Font.GothamBold
	thawedLabel.TextSize = 15
	thawedLabel.TextColor3 = Feel.ICE_MID
	thawedLabel.TextXAlignment = Enum.TextXAlignment.Left
	thawedLabel.Text = "0.0% thawed"
	thawedLabel.Parent = panel

	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, 0, 0, 8)
	progressBack.Position = UDim2.fromOffset(0, 68)
	progressBack.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = panel
	corner(progressBack, 4)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Feel.ICE_MID
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	corner(progressFill, 4)

	local foundLabel = Instance.new("TextLabel")
	foundLabel.Size = UDim2.new(1, 0, 0, 22)
	foundLabel.Position = UDim2.fromOffset(0, 80)
	foundLabel.BackgroundTransparency = 1
	foundLabel.Font = Enum.Font.GothamBold
	foundLabel.TextSize = 15
	foundLabel.TextColor3 = GOLD
	foundLabel.TextXAlignment = Enum.TextXAlignment.Left
	foundLabel.Text = "0 / 0 found"
	foundLabel.Parent = panel

	-- Bottom-centre gate bar.
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.fromOffset(340, 22)
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.new(0.5, 0, 1, -34)
	barBack.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	corner(barBack, 11)
	goldStroke(barBack, 2)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(1, -6, 1, -6)
	barFill.Position = UDim2.fromOffset(3, 3)
	barFill.BackgroundColor3 = STAMINA
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	corner(barFill, 8)

	local barLabel = Instance.new("TextLabel")
	barLabel.Size = UDim2.new(1, 0, 0, 18)
	barLabel.AnchorPoint = Vector2.new(0.5, 1)
	barLabel.Position = UDim2.new(0.5, 0, 0, -3)
	barLabel.BackgroundTransparency = 1
	barLabel.Font = Enum.Font.GothamBold
	barLabel.TextSize = 12
	barLabel.TextColor3 = STAMINA
	barLabel.Text = "STAMINA"
	barLabel.Parent = barBack

	-- Which gate is live depends on what is in hand.
	local function activeGate(): Tools.Gate
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if tool then
			local key = tool:GetAttribute("ToolKey")
			if typeof(key) == "string" then
				local def = Tools.get(key)
				if def then
					return def.gate
				end
			end
		end
		return "stamina"
	end

	local shownMoney = 0
	local function renderMoney()
		local value = toNumber(player:GetAttribute("Money"), 0)
		moneyLabel.Text = "$" .. abbreviate(value)
		if value > shownMoney then
			-- Small pop on gain. Kept modest; an oversized bounce reads as noise
			-- rather than as reward.
			moneyLabel.TextSize = 38
			TweenService:Create(moneyLabel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { TextSize = 32 }):Play()
		end
		shownMoney = value
	end

	local function renderThawed()
		local fraction = math.clamp(toNumber(player:GetAttribute("ThawedPct"), 0), 0, 1)
		thawedLabel.Text = string.format("%.1f%% thawed", fraction * 100)
		TweenService:Create(progressFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(fraction, 1) }):Play()
	end

	-- Combo badge, top centre. Built here rather than in the panel above
	-- because it is not a readout of state - it appears, grows and leaves.
	local comboBadge = Instance.new("Frame")
	comboBadge.Name = "Combo"
	comboBadge.Size = UDim2.fromOffset(190, 66)
	comboBadge.Position = UDim2.new(0.5, 0, 0, 22)
	comboBadge.AnchorPoint = Vector2.new(0.5, 0)
	comboBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	comboBadge.BorderSizePixel = 0
	comboBadge.Visible = false
	comboBadge.Parent = gui
	corner(comboBadge, 16)
	UITheme.outline(comboBadge, 3)

	local comboGradient = Instance.new("UIGradient")
	comboGradient.Rotation = 90
	comboGradient.Parent = comboBadge

	local comboCount = Instance.new("TextLabel")
	comboCount.Size = UDim2.new(1, 0, 0, 38)
	comboCount.Position = UDim2.fromOffset(0, 4)
	comboCount.BackgroundTransparency = 1
	comboCount.Font = Enum.Font.FredokaOne
	comboCount.TextSize = 32
	comboCount.TextColor3 = Color3.new(1, 1, 1)
	comboCount.Text = ""
	comboCount.Parent = comboBadge
	UITheme.outline(comboCount, 3)

	local comboPay = Instance.new("TextLabel")
	comboPay.Size = UDim2.new(1, 0, 0, 20)
	comboPay.Position = UDim2.fromOffset(0, 40)
	comboPay.BackgroundTransparency = 1
	comboPay.Font = Enum.Font.GothamBlack
	comboPay.TextSize = 14
	comboPay.TextColor3 = Color3.fromRGB(24, 20, 12)
	comboPay.Text = ""
	comboPay.Parent = comboBadge

	local comboScale = Instance.new("UIScale")
	comboScale.Parent = comboBadge

	-- Matches Combo.STEP and Combo.CAP on the server. Duplicated rather than
	-- required across the boundary because the client must never be the one
	-- deciding what a streak is worth - this only has to *say* the same thing.
	local COMBO_STEP = 0.02
	local COMBO_CAP = 50

	local function renderCombo()
		local count = toNumber(player:GetAttribute("Combo"), 0)
		if count <= 0 then
			comboBadge.Visible = false
			return
		end

		local heat = math.clamp(count / COMBO_CAP, 0, 1)
		local warm = STAMINA:Lerp(FUEL, heat)
		comboGradient.Color = ColorSequence.new(
			warm:Lerp(Color3.new(1, 1, 1), 0.35),
			warm:Lerp(Color3.new(0, 0, 0), 0.25)
		)
		comboCount.Text = string.format("x%d", count)
		comboPay.Text = string.format(
			"%.2fx PAYOUT",
			1 + math.min(count, COMBO_CAP) * COMBO_STEP
		)

		local wasHidden = not comboBadge.Visible
		comboBadge.Visible = true
		-- A kick on every increment, so the meter feels struck rather than
		-- redrawn. Bigger on the first one, when it has just appeared.
		comboScale.Scale = if wasHidden then 0.6 else 1.16
		TweenService:Create(
			comboScale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	local function renderFinds()
		foundLabel.Text = string.format(
			"%d / %d found",
			toNumber(player:GetAttribute("Found"), 0),
			toNumber(player:GetAttribute("FoundTotal"), 0)
		)
	end

	local function renderGate()
		local gate = activeGate()
		local current, maximum, tint, name
		if gate == "fuel" then
			current = toNumber(player:GetAttribute("Fuel"), 0)
			maximum = toNumber(player:GetAttribute("FuelMax"), 60)
			tint, name = FUEL, "FUEL"
		else
			current = toNumber(player:GetAttribute("Stamina"), 0)
			maximum = toNumber(player:GetAttribute("StaminaMax"), 100)
			tint, name = STAMINA, "STAMINA"
		end

		local ratio = if maximum > 0 then math.clamp(current / maximum, 0, 1) else 0
		barFill.Size = UDim2.new(ratio, -6, 1, -6)
		-- Red while the gate is biting, so the reason a swing did nothing is
		-- visible rather than mysterious.
		barFill.BackgroundColor3 = if ratio < 0.15 then LOW else tint
		barLabel.Text = name
		barLabel.TextColor3 = tint
	end

	for _, name in
		{ "Money", "ThawedPct", "Found", "FoundTotal", "Stamina", "StaminaMax", "Fuel", "FuelMax", "Combo" }
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			if name == "Money" then
				renderMoney()
			elseif name == "ThawedPct" then
				renderThawed()
			elseif name == "Found" or name == "FoundTotal" then
				renderFinds()
			elseif name == "Combo" then
				renderCombo()
			else
				renderGate()
			end
		end)
	end

	-- Equipping a different tool swaps which gate is shown.
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				renderGate()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				renderGate()
			end
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	renderMoney()
	renderThawed()
	renderFinds()
	renderGate()
	renderCombo()
end

return HUD
