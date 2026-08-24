--!strict
--[[
	Popups - floating reward numbers.

	Cold world, warm reward: these are deliberately the one saturated warm colour
	in a blue scene, so they read against any background without an outline
	fighting the art.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Popups = {}

function Popups.show(position: Vector3, text: string, color: Color3?, scale: number?)
	local camera = Workspace.CurrentCamera
	if not camera or (position - camera.CFrame.Position).Magnitude > Feel.POPUP_MAX_DISTANCE then
		return
	end

	local size = scale or 1

	local attachment = Instance.new("Attachment")
	-- Jittered, because two identical "+$1" labels a second land on top of each
	-- other and turn into an unreadable smear.
	attachment.WorldPosition = position
		+ Vector3.new(math.random(-12, 12) / 10, 0.5, math.random(-12, 12) / 10)
	attachment.Parent = Workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120 * size, 40 * size)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	-- BillboardGuis still lay out their text at any distance, so cull them.
	billboard.MaxDistance = Feel.POPUP_MAX_DISTANCE
	billboard.Adornee = attachment
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Feel.MONEY
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextTransparency = 1
	label.Parent = billboard

	TweenService
		:Create(attachment, TweenInfo.new(Feel.POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			WorldPosition = attachment.WorldPosition + Vector3.new(0, Feel.POPUP_RISE, 0),
		})
		:Play()

	TweenService:Create(label, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
	TweenService
		:Create(
			label,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		:Play()

	task.delay(Feel.POPUP_TIME + 0.1, function()
		attachment:Destroy()
	end)
end

return Popups
