--!strict
--[[
	UITheme - one place the whole interface gets its look from.

	Every panel used to build its own corners, strokes and gradients inline, and
	they had drifted: three different golds, two corner radii, a stroke that was
	2px in one file and 3px in another. Small differences, but they are exactly
	what makes an interface read as assembled rather than designed.

	The look is deliberately cartoon rather than flat-modern:

	  * Heavy dark outlines on everything. This is the single strongest cartoon
	    signal available in a UI, the same way hard shadow edges are in 3D, and
	    it costs one UIStroke.
	  * Big corner radii. Nothing is square.
	  * A vertical gradient on every surface, so nothing is a flat colour.
	  * Rounded display faces. FredokaOne for anything the player reads as a
	    title, Gotham Black for numbers - numerals need to line up in a changing
	    counter and Fredoka's do not.
	  * Buttons physically move when pressed. A button that only changes colour
	    reads as a link.

	No image assets. Drop shadows here would mean an uploaded 9-slice, and an
	asset that gets moderated or mis-ids takes the whole interface with it; a
	thick dark stroke does the same job with nothing to fetch.
]]

local TweenService = game:GetService("TweenService")

local UITheme = {}

-- ---------------------------------------------------------------------------
-- palette
-- ---------------------------------------------------------------------------

UITheme.INK = Color3.fromRGB(12, 16, 28) -- the outline colour, near black
UITheme.PANEL_TOP = Color3.fromRGB(44, 60, 92)
UITheme.PANEL_BOTTOM = Color3.fromRGB(18, 26, 44)
UITheme.PANEL_LIGHT_TOP = Color3.fromRGB(62, 82, 120)
UITheme.PANEL_LIGHT_BOTTOM = Color3.fromRGB(34, 46, 72)

UITheme.GOLD = Color3.fromRGB(255, 200, 38)
UITheme.GOLD_LIGHT = Color3.fromRGB(255, 235, 168)
UITheme.GOLD_DARK = Color3.fromRGB(184, 134, 11)

UITheme.TEXT = Color3.fromRGB(240, 246, 255)
UITheme.TEXT_DIM = Color3.fromRGB(150, 164, 188)
UITheme.TEXT_OFF = Color3.fromRGB(96, 108, 132)

UITheme.GOOD = Color3.fromRGB(108, 214, 120)
UITheme.BAD = Color3.fromRGB(224, 88, 88)
UITheme.COLD = Color3.fromRGB(120, 200, 255)
UITheme.HOT = Color3.fromRGB(255, 152, 60)

UITheme.DISPLAY = Enum.Font.FredokaOne
UITheme.NUMBER = Enum.Font.GothamBlack
UITheme.BODY = Enum.Font.GothamBold

-- ---------------------------------------------------------------------------
-- primitives
-- ---------------------------------------------------------------------------

function UITheme.corner(gui: GuiObject, radius: number): UICorner
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = gui
	return instance
end

function UITheme.pad(gui: GuiObject, amount: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = gui
	return padding
end

-- The outline. Border mode rather than Contextual so it hugs the corner radius
-- instead of tracing the text inside.
function UITheme.outline(gui: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 3
	stroke.Color = color or UITheme.INK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
	return stroke
end

-- A gold rim. The stroke colour multiplies the gradient, so it is left white.
function UITheme.goldStroke(gui: GuiObject, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UITheme.GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, UITheme.GOLD),
		ColorSequenceKeypoint.new(1, UITheme.GOLD_DARK),
	})
	gradient.Rotation = 90
	gradient.Parent = stroke
	return stroke
end

function UITheme.gradient(gui: GuiObject, top: Color3, bottom: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = gui
	return gradient
end

-- ---------------------------------------------------------------------------
-- surfaces
-- ---------------------------------------------------------------------------

-- A panel: gradient fill, big radius, heavy outline, optional gold rim.
function UITheme.panel(parent: Instance, name: string, light: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	UITheme.gradient(
		frame,
		if light then UITheme.PANEL_LIGHT_TOP else UITheme.PANEL_TOP,
		if light then UITheme.PANEL_LIGHT_BOTTOM else UITheme.PANEL_BOTTOM
	)
	UITheme.corner(frame, 14)
	UITheme.outline(frame, 3)
	frame.Parent = parent
	return frame
end

function UITheme.label(parent: Instance, text: string, size: number, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font or UITheme.BODY
	label.Text = text
	label.TextSize = size
	label.TextColor3 = UITheme.TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	-- Text gets the same dark outline as the surfaces, which is what keeps it
	-- readable over a bright ice field or a lit brazier.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = UITheme.INK
	stroke.Transparency = 0.25
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A button that moves when pressed. Returns the button; callers connect their
-- own MouseButton1Click.
function UITheme.button(parent: Instance, name: string, text: string, accent: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.Font = UITheme.DISPLAY
	button.Text = text
	button.TextSize = 18
	button.TextColor3 = UITheme.TEXT

	local tint = accent or UITheme.GOLD
	UITheme.gradient(button, tint:Lerp(Color3.new(1, 1, 1), 0.25), tint:Lerp(Color3.new(0, 0, 0), 0.35))
	UITheme.corner(button, 12)
	UITheme.outline(button, 3)

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 2
	labelStroke.Color = UITheme.INK
	labelStroke.Parent = button

	local base = UDim2.new()
	button:GetPropertyChangedSignal("Size"):Connect(function()
		base = button.Size
	end)

	local function press(down: boolean)
		local scale = if down then 0.94 else 1
		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
			Size = UDim2.new(
				base.X.Scale * scale, base.X.Offset * scale,
				base.Y.Scale * scale, base.Y.Offset * scale
			),
		}):Play()
	end

	button.MouseButton1Down:Connect(function()
		base = if base == UDim2.new() then button.Size else base
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)
	button.MouseLeave:Connect(function()
		press(false)
	end)

	button.Parent = parent
	return button
end

-- A progress bar. Returns the fill, which is the only part callers animate.
function UITheme.bar(parent: Instance, name: string, tint: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = Color3.fromRGB(14, 20, 34)
	track.BorderSizePixel = 0
	UITheme.corner(track, 8)
	UITheme.outline(track, 2)
	track.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	UITheme.gradient(fill, tint:Lerp(Color3.new(1, 1, 1), 0.35), tint)
	UITheme.corner(fill, 8)
	fill.Parent = track

	return track, fill
end

-- ---------------------------------------------------------------------------
-- motion
-- ---------------------------------------------------------------------------

-- A short overshoot, for anything that has just appeared or just changed. Back
-- easing is what makes it read as bouncy rather than as a fade.
function UITheme.pop(gui: GuiObject, from: number?)
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	scale.Scale = from or 0.7
	TweenService:Create(
		scale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

UITheme.TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return UITheme
