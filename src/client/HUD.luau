--!strict
--[[
	HUD - money, % thawed, stamina.

	Reads Player attributes, which the server owns and the client cannot write.
	This file renders numbers and nothing else; it never computes a value it
	displays, which keeps the display honest by construction.
]]

local Players = game:GetService("Players")

local HUD = {}

local BACKGROUND = Color3.fromRGB(12, 18, 28)
local ICE = Color3.fromRGB(150, 214, 255)
local MONEY = Color3.fromRGB(126, 217, 87)

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function toNumber(value: any, fallback: number): number
	return if typeof(value) == "number" then value else fallback
end

function HUD.start()
	local player = assert(Players.LocalPlayer, "HUD requires a LocalPlayer")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MeltHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top-left readout: money over progress.
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(230, 86)
	panel.Position = UDim2.fromOffset(16, 16)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 10)

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Size = UDim2.new(1, -24, 0, 40)
	moneyLabel.Position = UDim2.fromOffset(12, 8)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.TextSize = 30
	moneyLabel.TextColor3 = MONEY
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.Parent = panel

	local thawedLabel = Instance.new("TextLabel")
	thawedLabel.Size = UDim2.new(1, -24, 0, 26)
	thawedLabel.Position = UDim2.fromOffset(12, 50)
	thawedLabel.BackgroundTransparency = 1
	thawedLabel.Font = Enum.Font.Gotham
	thawedLabel.TextSize = 17
	thawedLabel.TextColor3 = ICE
	thawedLabel.TextXAlignment = Enum.TextXAlignment.Left
	thawedLabel.Text = "0.0% thawed"
	thawedLabel.Parent = panel

	-- Bottom-centre stamina bar.
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.fromOffset(320, 20)
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.new(0.5, 0, 1, -28)
	barBack.BackgroundColor3 = BACKGROUND
	barBack.BackgroundTransparency = 0.25
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	corner(barBack, 10)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(1, -6, 1, -6)
	barFill.Position = UDim2.fromOffset(3, 3)
	barFill.BackgroundColor3 = ICE
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	corner(barFill, 7)

	local staminaLabel = Instance.new("TextLabel")
	staminaLabel.Size = UDim2.new(1, 0, 0, 18)
	staminaLabel.AnchorPoint = Vector2.new(0.5, 1)
	staminaLabel.Position = UDim2.new(0.5, 0, 0, -2)
	staminaLabel.BackgroundTransparency = 1
	staminaLabel.Font = Enum.Font.Gotham
	staminaLabel.TextSize = 13
	staminaLabel.TextColor3 = ICE
	staminaLabel.Text = "STAMINA"
	staminaLabel.Parent = barBack

	local function renderMoney()
		moneyLabel.Text = string.format("$%d", toNumber(player:GetAttribute("Money"), 0))
	end

	local function renderThawed()
		local fraction = toNumber(player:GetAttribute("ThawedPct"), 0)
		thawedLabel.Text = string.format("%.1f%% thawed", fraction * 100)
	end

	local function renderStamina()
		local maximum = toNumber(player:GetAttribute("StaminaMax"), 100)
		local current = toNumber(player:GetAttribute("Stamina"), maximum)
		local ratio = if maximum > 0 then math.clamp(current / maximum, 0, 1) else 0
		barFill.Size = UDim2.new(ratio, -6, 1, -6)
		-- Red while the gate is biting, so the reason a swing did nothing is
		-- visible rather than mysterious.
		barFill.BackgroundColor3 = if ratio < 0.15 then Color3.fromRGB(220, 96, 96) else ICE
	end

	player:GetAttributeChangedSignal("Money"):Connect(renderMoney)
	player:GetAttributeChangedSignal("ThawedPct"):Connect(renderThawed)
	player:GetAttributeChangedSignal("Stamina"):Connect(renderStamina)
	player:GetAttributeChangedSignal("StaminaMax"):Connect(renderStamina)

	renderMoney()
	renderThawed()
	renderStamina()
end

return HUD
