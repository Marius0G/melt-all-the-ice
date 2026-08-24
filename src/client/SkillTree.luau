--!strict
--[[
	SkillTree - where money goes.

	Built to the language of docs/reference/skilltree-ui-ref.png: chunky bevelled
	square nodes, thick gold borders, colour-coded branches, heavy rounded type.

	Two details that are easy to get wrong and very visible when you do:

	  * The gold border is a UIGradient nested inside a UIStroke, and the
	    stroke's own Color has to stay white. The stroke colour multiplies the
	    gradient, so anything else muddies the whole ramp.
	  * Sizing is Scale for the panel and Offset only for things that must not
	    grow - strokes, padding, node size. Mixing the two on one axis is what
	    makes Roblox UI that works on the author's monitor and nowhere else.

	It renders from the shared Upgrades table and the player's own attributes,
	and computes nothing it displays. Clicking sends a key; the server decides
	everything else and answers with ok plus a reason.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))

local SkillTree = {}

local GOLD_LIGHT = Color3.fromRGB(255, 233, 160)
local GOLD = Color3.fromRGB(255, 200, 38)
local GOLD_DARK = Color3.fromRGB(184, 134, 11)
local PANEL_TOP = Color3.fromRGB(38, 52, 80)
local PANEL_BOTTOM = Color3.fromRGB(18, 26, 44)
local LOCKED = Color3.fromRGB(74, 80, 92)

local BRANCH_ICON = {
	might = "\u{1F4AA}",
	fortune = "\u{1F4B0}",
	vigour = "\u{26A1}",
	craft = "\u{1F525}",
}

local player: Player
local screen: ScreenGui
local panel: Frame
local open = false
local nodes: { [string]: () -> () } = {}

local function corner(parent: GuiObject, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function goldStroke(parent: GuiObject, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	-- Must stay white; the stroke colour multiplies the gradient below it.
	stroke.Color = Color3.new(1, 1, 1)
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
	return stroke
end

local function verticalFill(parent: GuiObject, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = parent
end

local function money(): number
	local value = player:GetAttribute("Money")
	return if typeof(value) == "number" then value else 0
end

local function levelOf(key: string): number
	local value = player:GetAttribute("Upg_" .. key)
	return if typeof(value) == "number" then value else 0
end

local function buildNode(parent: GuiObject, def: Upgrades.UpgradeDef, row: number)
	local tint = Upgrades.BRANCH_COLOR[def.branch]

	local button = Instance.new("TextButton")
	button.Name = def.key
	button.Size = UDim2.new(1, 0, 0, 96)
	button.Position = UDim2.fromOffset(0, row * 106)
	button.BackgroundColor3 = PANEL_TOP
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	corner(button, 12)
	verticalFill(button, PANEL_TOP, PANEL_BOTTOM)
	local stroke = goldStroke(button, 4)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromOffset(34, 34)
	icon.BackgroundColor3 = tint
	icon.BackgroundTransparency = 0.25
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 20
	icon.Text = BRANCH_ICON[def.branch] or "?"
	icon.Parent = button
	corner(icon, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -42, 0, 20)
	title.Position = UDim2.fromOffset(42, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 17
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = def.label
	title.Parent = button

	local blurb = Instance.new("TextLabel")
	blurb.Size = UDim2.new(1, -42, 0, 30)
	blurb.Position = UDim2.fromOffset(42, 20)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextSize = 12
	blurb.TextColor3 = Color3.fromRGB(176, 190, 214)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	blurb.TextWrapped = true
	blurb.Text = def.blurb
	blurb.Parent = button

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Position = UDim2.new(0, 0, 1, -20)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = button

	local pips = Instance.new("TextLabel")
	pips.Size = UDim2.new(0, 90, 0, 20)
	pips.Position = UDim2.new(1, -90, 1, -20)
	pips.BackgroundTransparency = 1
	pips.Font = Enum.Font.GothamBold
	pips.TextSize = 14
	pips.TextColor3 = tint
	pips.TextXAlignment = Enum.TextXAlignment.Right
	pips.Parent = button

	local function refresh()
		local level = levelOf(def.key)
		local cost = Upgrades.costOf(def, level)
		local prerequisite = def.requires
		local locked = prerequisite ~= nil
			and levelOf(prerequisite) < (def.requiresLevel or 1)

		if def.maxLevel > 1 then
			pips.Text = string.rep("\u{25CF}", level) .. string.rep("\u{25CB}", def.maxLevel - level)
		else
			pips.Text = if level > 0 then "OWNED" else ""
		end

		if not cost then
			status.Text = if def.maxLevel > 1 then "MAXED" else "OWNED"
			status.TextColor3 = tint
			stroke.Transparency = 0.45
			button.Active = false
		elseif locked then
			-- Greyed with a lock is the convention players already read.
			status.Text = string.format("\u{1F512} needs %s", tostring(prerequisite))
			status.TextColor3 = LOCKED
			stroke.Transparency = 0.7
			button.Active = false
		else
			local affordable = money() >= cost
			status.Text = string.format("$%d", cost)
			status.TextColor3 = if affordable then GOLD else Color3.fromRGB(196, 96, 96)
			stroke.Transparency = if affordable then 0 else 0.5
			button.Active = affordable
		end
	end

	button.MouseButton1Click:Connect(function()
		if not button.Active then
			return
		end
		-- Press feedback before the round trip, so the click always registers.
		button.Size = UDim2.new(1, 0, 0, 92)
		TweenService
			:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0, 96),
			})
			:Play()
		Remotes.purchase():FireServer(def.key)
	end)

	nodes[def.key] = refresh
	refresh()
end

local function refreshAll()
	for _, refresh in nodes do
		refresh()
	end
end

local function build()
	screen = Instance.new("ScreenGui")
	screen.Name = "MeltSkillTree"
	screen.ResetOnSpawn = false
	-- CoreUISafeInsets by default keeps interactive UI clear of the top bar and
	-- of phone cutouts.
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -20, 1, -20)
	-- Comfortably above the 44px minimum touch target.
	toggle.Size = UDim2.fromOffset(150, 54)
	toggle.BackgroundColor3 = PANEL_TOP
	toggle.BorderSizePixel = 0
	toggle.AutoButtonColor = false
	toggle.Font = Enum.Font.FredokaOne
	toggle.TextSize = 20
	toggle.TextColor3 = GOLD
	toggle.Text = "UPGRADES"
	toggle.Parent = screen
	corner(toggle, 12)
	verticalFill(toggle, PANEL_TOP, PANEL_BOTTOM)
	goldStroke(toggle, 4)

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.82, 0.76)
	panel.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screen
	corner(panel, 18)
	goldStroke(panel, 5)

	local clamp = Instance.new("UISizeConstraint")
	clamp.MaxSize = Vector2.new(1120, 720)
	clamp.MinSize = Vector2.new(320, 300)
	clamp.Parent = panel

	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 18)
	panelPad.PaddingBottom = UDim.new(0, 18)
	panelPad.PaddingLeft = UDim.new(0, 20)
	panelPad.PaddingRight = UDim.new(0, 20)
	panelPad.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 34)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.FredokaOne
	heading.TextSize = 28
	heading.TextColor3 = GOLD
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = "UPGRADES"
	heading.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(112, 40)
	close.BackgroundColor3 = PANEL_TOP
	close.BorderSizePixel = 0
	close.AutoButtonColor = false
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "DONE"
	close.Parent = panel
	corner(close, 10)
	verticalFill(close, PANEL_TOP, PANEL_BOTTOM)
	goldStroke(close, 3)

	-- One column per branch.
	local columns = Instance.new("Frame")
	columns.Size = UDim2.new(1, 0, 1, -52)
	columns.Position = UDim2.fromOffset(0, 52)
	columns.BackgroundTransparency = 1
	columns.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = columns

	local byBranch: { [string]: GuiObject } = {}
	for order, branch in Upgrades.BRANCH_ORDER do
		local column = Instance.new("Frame")
		column.Name = branch
		column.LayoutOrder = order
		column.Size = UDim2.new(1 / #Upgrades.BRANCH_ORDER, -14, 1, 0)
		column.BackgroundTransparency = 1
		column.Parent = columns

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = Upgrades.BRANCH_COLOR[branch]
		label.Text = Upgrades.BRANCH_LABEL[branch]
		label.Parent = column

		-- Scrolls, because the craft branch runs the length of all three maps
		-- and will not fit a column on a phone.
		local holder = Instance.new("ScrollingFrame")
		holder.Name = "Nodes"
		holder.Size = UDim2.new(1, 0, 1, -26)
		holder.Position = UDim2.fromOffset(0, 26)
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.ScrollBarThickness = 4
		holder.ScrollBarImageColor3 = GOLD_DARK
		holder.CanvasSize = UDim2.new()
		holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
		holder.ScrollingDirection = Enum.ScrollingDirection.Y
		holder.Parent = column

		local holderPad = Instance.new("UIPadding")
		holderPad.PaddingRight = UDim.new(0, 8)
		holderPad.PaddingBottom = UDim.new(0, 8)
		holderPad.Parent = holder

		byBranch[branch] = holder
	end

	local rows: { [string]: number } = {}
	for _, def in Upgrades.DEFS do
		local holder = byBranch[def.branch]
		if holder then
			local row = rows[def.branch] or 0
			buildNode(holder, def, row)
			rows[def.branch] = row + 1
		end
	end

	local function setOpen(value: boolean)
		open = value
		panel.Visible = value
		if value then
			refreshAll()
		end
	end

	toggle.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			setOpen(not open)
		elseif input.KeyCode == Enum.KeyCode.Escape and open then
			setOpen(false)
		end
	end)
end

function SkillTree.start()
	player = assert(Players.LocalPlayer, "SkillTree requires a LocalPlayer")
	build()

	-- Affordability changes as money does, so the tree restyles itself.
	player:GetAttributeChangedSignal("Money"):Connect(refreshAll)
	for _, def in Upgrades.DEFS do
		player:GetAttributeChangedSignal("Upg_" .. def.key):Connect(refreshAll)
	end

	Remotes.purchaseResult().OnClientEvent:Connect(function(_key, ok, _reason)
		if ok then
			refreshAll()
		end
	end)
end

return SkillTree
