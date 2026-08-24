--!strict
--[[
	Ambience - lighting for the frozen cave.

	The chamber is sealed in rock, so no sky light reaches it and the default
	lighting rig renders it unreadably black. These values light it just enough
	to play in while keeping the cold palette of docs/reference/cave-mid-state.png:
	cool ambient doing the work, a warm point light on the spawn pad as the only
	warm accent.

	Placeholder for a real progression beat. The GDD has the cave start with no
	light source and end warm-lit, and the torch is the map's capstone tool, so
	this eventually becomes something the player earns rather than a constant.

	Idempotent: it finds or creates the post-processing instances, so a Rojo
	build with an empty Lighting service and a Studio place that already has
	them both end up in the same state.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Ambience = {}

local function ensure(className: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = Lighting
	return created
end

function Ambience.apply()
	Lighting.Ambient = Color3.fromRGB(104, 122, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 114, 142)
	Lighting.Brightness = 1
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.ClockTime = 3
	Lighting.GeographicLatitude = 0
	Lighting.FogEnd = 420
	Lighting.FogColor = Color3.fromRGB(30, 44, 64)
	Lighting.ColorShift_Top = Color3.fromRGB(90, 130, 170)

	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Threshold = 1.4
	bloom.Size = 24

	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Haze = 0.6
	atmosphere.Color = Color3.fromRGB(150, 176, 204)
	atmosphere.Decay = Color3.fromRGB(80, 100, 128)

	-- Roblox ships Rock warm enough to read as sandstone; cool it toward slate
	-- so the cave does not fight the ice.
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 104, 118))
	terrain:SetMaterialColor(Enum.Material.Ice, Color3.fromRGB(190, 222, 245))
end

return Ambience
