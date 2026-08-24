--!strict
--[[
	Crosshair - aim dot, and the cheapest responsiveness win available.

	The size pulse fires on click, before the server has answered; the colour
	flash fires on confirmation. So the player gets feedback in one frame even on
	a bad connection, and still learns whether they actually connected.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Crosshair = {}

local RESTING = 22

local dot: Frame? = nil

function Crosshair.start()
	local player = assert(Players.LocalPlayer, "Crosshair requires a LocalPlayer")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MeltCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Dot"
	frame.AnchorPoint = Vector2.new(0.5, 0.5) -- or it scales from a corner
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(RESTING, RESTING)
	frame.BackgroundColor3 = Feel.ICE_BRIGHT
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.55
	stroke.Parent = frame

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = frame

	dot = frame
end

function Crosshair.pulse()
	local frame = dot
	if not frame then
		return
	end
	frame.Size = UDim2.fromOffset(RESTING + 12, RESTING + 12)
	TweenService
		:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(RESTING, RESTING),
		})
		:Play()
end

-- Refused because stamina is gone. Answers "why did nothing happen" at the
-- point the player is actually looking.
function Crosshair.deny()
	local frame = dot
	if not frame then
		return
	end
	frame.BackgroundColor3 = Color3.fromRGB(220, 96, 96)
	TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundColor3 = Feel.ICE_BRIGHT }):Play()
end

function Crosshair.confirm(destroyed: boolean)
	local frame = dot
	if not frame then
		return
	end
	frame.BackgroundColor3 = if destroyed then Feel.MONEY else Color3.new(1, 1, 1)
	TweenService:Create(frame, TweenInfo.new(0.22), { BackgroundColor3 = Feel.ICE_BRIGHT }):Play()
end

return Crosshair
