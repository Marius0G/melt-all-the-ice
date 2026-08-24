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
local Skins = require(Shared:WaitForChild("Skins"))
local Tools = require(Shared:WaitForChild("Tools"))
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
local skinRows: { () -> () } = {}

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
	for _, refresh in skinRows do
		refresh()
	end
end

local function ownsSkin(key: string): boolean
	return player:GetAttribute("SkinOwned_" .. key) == true
end

local function wornSkin(tool: string): string?
	local value = player:GetAttribute("Skin_" .. tool)
	return if typeof(value) == "string" then value else nil
end

-- One row per tool: the tool's name, then a button per look. Owning a look and
-- wearing it are separate states, so the button says which.
local function buildSkinRow(parent: GuiObject, tool: Tools.ToolDef, order: number)
	local options = Skins.forTool(tool.key)
	if #options == 0 then
		return
	end

	local row = Instance.new("Frame")
	row.Name = tool.key
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 76)
	row.BackgroundColor3 = PANEL_TOP
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 12)
	verticalFill(row, PANEL_TOP, PANEL_BOTTOM)
	goldStroke(row, 3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = row

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 150, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = tool.label
	title.Parent = row

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, -158, 1, 0)
	strip.Position = UDim2.fromOffset(158, 0)
	strip.BackgroundTransparency = 1
	strip.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	local refreshers: { () -> () } = {}

	for index, skin in options do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(112, 60)
		button.BackgroundColor3 = skin.body
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = ""
		button.Parent = strip
		corner(button, 10)
		local stroke = goldStroke(button, 3)

		-- The accent colour is the actual difference between most looks, so it
		-- gets a swatch rather than being described in words.
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(1, -16, 0, 8)
		swatch.Position = UDim2.fromOffset(8, 8)
		swatch.BackgroundColor3 = skin.flame or skin.accent
		swatch.BorderSizePixel = 0
		swatch.Parent = button
		corner(swatch, 4)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -12, 0, 18)
		name.Position = UDim2.fromOffset(6, 20)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Text = skin.label
		name.Parent = button

		local state = Instance.new("TextLabel")
		state.Size = UDim2.new(1, -12, 0, 16)
		state.Position = UDim2.new(0, 6, 1, -22)
		state.BackgroundTransparency = 1
		state.Font = Enum.Font.GothamBold
		state.TextSize = 12
		state.TextStrokeTransparency = 0.4
		state.Parent = button

		local function refresh()
			local owned = ownsSkin(skin.key)
			local worn = wornSkin(tool.key) == skin.key
			if worn then
				state.Text = "WORN"
				state.TextColor3 = GOLD
				stroke.Transparency = 0
			elseif owned then
				state.Text = "WEAR"
				state.TextColor3 = Color3.new(1, 1, 1)
				stroke.Transparency = 0.45
			else
				local affordable = money() >= skin.cost
				state.Text = string.format("$%d", skin.cost)
				state.TextColor3 = if affordable then GOLD else Color3.fromRGB(196, 96, 96)
				stroke.Transparency = if affordable then 0.3 else 0.7
			end
		end

		button.MouseButton1Click:Connect(function()
			local action = if ownsSkin(skin.key) then "equip" else "buy"
			button.Size = UDim2.fromOffset(108, 56)
			TweenService
				:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(112, 60),
				})
				:Play()
			Remotes.skin():FireServer(action, skin.key)
		end)

		table.insert(refreshers, refresh)
	end

	table.insert(skinRows, function()
		-- Only show a tool the player actually owns.
		row.Visible = tool.key == "stone" or player:GetAttribute("Upg_" .. tool.key) ~= nil
			and (player:GetAttribute("Upg_" .. tool.key) :: number) > 0
		for _, refresh in refreshers do
			refresh()
		end
	end)
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

	-- Two tabs rather than two screens: buying power and choosing how the tool
	-- looks are both "spend money on your kit", so they belong in one place.
	local tabs: { [string]: TextButton } = {}
	local function makeTab(name: string, label: string, offset: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(offset, 0)
		button.Size = UDim2.fromOffset(168, 38)
		button.BackgroundColor3 = PANEL_TOP
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 22
		button.TextColor3 = GOLD
		button.Text = label
		button.Parent = panel
		corner(button, 10)
		verticalFill(button, PANEL_TOP, PANEL_BOTTOM)
		goldStroke(button, 3)
		tabs[name] = button
		return button
	end

	makeTab("upgrades", "UPGRADES", 0)
	makeTab("skins", "WEAPONS", 178)

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

	-- Skins view, occupying the same space as the columns.
	local skinsView = Instance.new("ScrollingFrame")
	skinsView.Name = "Skins"
	skinsView.Size = UDim2.new(1, 0, 1, -52)
	skinsView.Position = UDim2.fromOffset(0, 52)
	skinsView.BackgroundTransparency = 1
	skinsView.BorderSizePixel = 0
	skinsView.ScrollBarThickness = 4
	skinsView.ScrollBarImageColor3 = GOLD_DARK
	skinsView.CanvasSize = UDim2.new()
	skinsView.AutomaticCanvasSize = Enum.AutomaticSize.Y
	skinsView.ScrollingDirection = Enum.ScrollingDirection.Y
	skinsView.Visible = false
	skinsView.Parent = panel

	local skinLayout = Instance.new("UIListLayout")
	skinLayout.FillDirection = Enum.FillDirection.Vertical
	skinLayout.Padding = UDim.new(0, 10)
	skinLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skinLayout.Parent = skinsView

	for order, tool in Tools.DEFS do
		buildSkinRow(skinsView, tool, order)
	end

	local function setTab(name: string)
		columns.Visible = name == "upgrades"
		skinsView.Visible = name == "skins"
		for key, button in tabs do
			-- The active tab is the bright one; the other reads as available.
			button.TextColor3 = if key == name then GOLD else Color3.fromRGB(150, 164, 188)
			button.BackgroundTransparency = if key == name then 0 else 0.4
		end
		refreshAll()
	end

	for name, button in tabs do
		local which = name
		button.MouseButton1Click:Connect(function()
			setTab(which)
		end)
	end
	setTab("upgrades")

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

	for _, tool in Tools.DEFS do
		player:GetAttributeChangedSignal("Skin_" .. tool.key):Connect(refreshAll)
	end
	for _, skin in Skins.DEFS do
		player:GetAttributeChangedSignal("SkinOwned_" .. skin.key):Connect(refreshAll)
	end

	Remotes.purchaseResult().OnClientEvent:Connect(function(_key, ok, _reason)
		if ok then
			refreshAll()
		end
	end)
	Remotes.skinResult().OnClientEvent:Connect(function(_key, ok, _reason)
		if ok then
			refreshAll()
		end
	end)
end

return SkillTree
