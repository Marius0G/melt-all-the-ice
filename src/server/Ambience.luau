--!strict
--[[
	Ambience - the parts of the look that are genuinely global.

	Terrain material colours are one setting shared by every player, so they
	belong on the server. Everything else about lighting moved to the client
	(see CaveLight): Lighting is a global service in the same way Terrain is,
	and the cave has to look different to each player depending on how far
	through their own map they are, which the server cannot express.

	Idempotent, so a rebuild and a fresh place end in the same state.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Ambience = {}

function Ambience.apply()
	local terrain = Workspace.Terrain

	-- Roblox ships Rock warm enough to read as sandstone, which fights the ice.
	-- Cooled toward slate so the cave sits behind the ice rather than competing.
	terrain:SetMaterialColor(Enum.Material.Rock, Feel.ROCK)
	terrain:SetMaterialColor(Enum.Material.Slate, Feel.ROCK_DARK)

	-- Water is not part of the SetMaterialColor palette - it carries its own
	-- properties, and passing it there throws "Unsupported terrain material".
	terrain.WaterColor = Feel.MELTWATER

	terrain.WaterWaveSize = 0.05
	terrain.WaterWaveSpeed = 6
	terrain.WaterReflectance = 0.25
	terrain.WaterTransparency = 0.5
end

return Ambience
