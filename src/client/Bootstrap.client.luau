--!strict
--[[
	Client entry point. Input and presentation only - every rule lives on the
	server.
]]

local modules = script.Parent

local CaveLight = require(modules:WaitForChild("CaveLight"))
local Crosshair = require(modules:WaitForChild("Crosshair"))
local HUD = require(modules:WaitForChild("HUD"))
local MeltEffects = require(modules:WaitForChild("MeltEffects"))
local SkillTree = require(modules:WaitForChild("SkillTree"))
local SwingInput = require(modules:WaitForChild("SwingInput"))
local Toast = require(modules:WaitForChild("Toast"))

CaveLight.start()
HUD.start()
Toast.start()
SkillTree.start()
Crosshair.start()
MeltEffects.start()
SwingInput.start()

print("[MeltAllTheIce] client ready")
