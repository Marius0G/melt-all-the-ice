--!strict
--[[
	Toast - the banner that announces a find.

	Styled after docs/reference/skilltree-ui-ref.png: chunky bevelled panel, thick
	gold border, heavy rounded type. The gold border is a UIGradient nested inside
	a UIStroke, which needs the stroke's own Color left white - the stroke colour
	multiplies the gradient, so any other value muddies the ramp.

	UIShadow is recent enough that it may not exist in every client, so it is
	created defensively and the panel still reads without it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Toast = {}

local GOLD_LIGHT = Color3.fromRGB(255, 233, 160)
local GOLD = Color3.fromRGB(255, 200, 38)
local GOLD_DARK = Color3.fromRGB(184, 134, 11)
local PANEL_TOP = Color3.fromRGB(46, 62, 92)
local PANEL_BOTTOM = Color3.fromRGB(22, 32, 52)

local gui: ScreenGui? = nil
local queue: { { label: string, reward: number, hero: boolean } } = {}
local showing = false

local function addShadow(parent: GuiObject, offset: number, blur: number, transparency: number)
	local ok, shadow = pcall(function()
		return Instance.new("UIShadow")
	end)
	if not ok or not shadow then
		return
	end
	local instance = shadow :: any
	instance.Offset = UDim2.fromOffset(0, offset)
	instance.BlurRadius = UDim.new(0, blur)
	instance.Color = Color3.new(0, 0, 0)
	instance.Transparency = transparency
	instance.Parent = parent
end

local function build(): ScreenGui
	local player = assert(Players.LocalPlayer, "Toast requires a LocalPlayer")
	local screen = Instance.new("ScreenGui")
	screen.Name = "MeltToast"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

local function present(entry: { label: string, reward: number, hero: boolean })
	local screen = gui
	if not screen then
		return
	end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.29)
	panel.Size = UDim2.fromOffset(if entry.hero then 420 else 360, if entry.hero then 108 else 92)
	panel.BackgroundColor3 = PANEL_TOP
	panel.BorderSizePixel = 0
	panel.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(PANEL_TOP, PANEL_BOTTOM)
	fill.Rotation = 90
	fill.Parent = panel

	-- Thick bevelled gold border: stroke left white so the gradient rules.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if entry.hero then 6 else 4
	stroke.Color = Color3.new(1, 1, 1)
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel

	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})
	strokeGradient.Rotation = 90
	strokeGradient.Parent = stroke

	-- Two shadows: a tight one for the bevel, a wide one for lift.
	addShadow(panel, 3, 6, 0.3)
	addShadow(panel, 10, 26, 0.55)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 20)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 14
	heading.TextColor3 = if entry.hero then GOLD else Feel.ICE_MID
	heading.Text = if entry.hero then "RARE FIND" else "UNCOVERED"
	heading.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = if entry.hero then 32 else 27
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = entry.label
	title.Parent = panel

	local reward = Instance.new("TextLabel")
	reward.Size = UDim2.new(1, 0, 0, 22)
	reward.Position = UDim2.fromOffset(0, if entry.hero then 60 else 54)
	reward.BackgroundTransparency = 1
	reward.Font = Enum.Font.GothamBold
	reward.TextSize = 19
	reward.TextColor3 = GOLD
	reward.Text = string.format("+$%d", entry.reward)
	reward.Parent = panel

	-- Small overshoot rather than a big bounce: an oversized pop reads as noise.
	local resting = panel.Size
	panel.Size = UDim2.fromOffset(resting.X.Offset * 0.82, resting.Y.Offset * 0.82)
	TweenService
		:Create(panel, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = resting,
		})
		:Play()

	local hold = if entry.hero then 2.6 else 1.9
	task.delay(hold, function()
		if not panel.Parent then
			return
		end
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(panel, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		for _, label in { heading, title, reward } do
			TweenService:Create(label, out, { TextTransparency = 1 }):Play()
		end
		task.delay(0.32, function()
			panel:Destroy()
		end)
	end)

	task.wait(hold * 0.55)
end

-- Serialised, so two finds in quick succession stack in time rather than on top
-- of each other.
local function pump()
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1)
			if entry then
				present(entry)
			end
		end
		showing = false
	end)
end

function Toast.start()
	gui = build()
end

function Toast.show(label: string, reward: number, hero: boolean)
	table.insert(queue, { label = label, reward = reward, hero = hero })
	pump()
end

return Toast
