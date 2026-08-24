--!strict
--[[
	Client entry point. Input and presentation only - every rule lives on the
	server.
]]

local modules = script.Parent

local HUD = require(modules:WaitForChild("HUD"))
local SwingInput = require(modules:WaitForChild("SwingInput"))

HUD.start()
SwingInput.start()

print("[MeltAllTheIce] client ready")
