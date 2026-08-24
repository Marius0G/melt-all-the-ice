--!strict
--[[
	Client entry point. Input and presentation only - every rule lives on the
	server.
]]

local modules = script.Parent

local Crosshair = require(modules:WaitForChild("Crosshair"))
local HUD = require(modules:WaitForChild("HUD"))
local MeltEffects = require(modules:WaitForChild("MeltEffects"))
local SwingInput = require(modules:WaitForChild("SwingInput"))

HUD.start()
Crosshair.start()
MeltEffects.start()
SwingInput.start()

print("[MeltAllTheIce] client ready")
