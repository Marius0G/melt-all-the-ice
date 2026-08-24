--!strict
--[[
	Client entry point. Input and presentation only - every rule lives on the
	server.
]]

local modules = script.Parent

local WorldLight = require(modules:WaitForChild("WorldLight"))
local Codex = require(modules:WaitForChild("Codex"))
local Crosshair = require(modules:WaitForChild("Crosshair"))
local HUD = require(modules:WaitForChild("HUD"))
local MeltEffects = require(modules:WaitForChild("MeltEffects"))
local SkillTree = require(modules:WaitForChild("SkillTree"))
local SwingInput = require(modules:WaitForChild("SwingInput"))
local Toast = require(modules:WaitForChild("Toast"))

WorldLight.start()
HUD.start()
Toast.start()
SkillTree.start()
Codex.start()
Crosshair.start()
MeltEffects.start()
SwingInput.start()

print("[MeltAllTheIce] client ready")
