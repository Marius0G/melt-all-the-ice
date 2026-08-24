--!strict
--[[
	WorldLight - the lighting arc, and the reason it lives on the client.

	Lighting is a global service, exactly like Terrain. There is one of it per
	place and the server cannot give each player their own. But a LocalScript
	changing Lighting only changes that client copy - so the arc is driven here,
	from the player own ThawedPct attribute (AD-6).

	The cave's arc comes straight from the design doc: it starts with no light
	source at all and ends blown open to daylight with a fire lit, and the
	capstone of its skill tree is learning to make fire. So lighting is not
	decoration on top of progress - it *is* the progress bar, and the player
	should be able to tell roughly how far in they are by how the room looks
	before they ever glance at a number.

	The pyramid and Troy are not caves - one is a thing that stands in a desert
	and the other is a city - so they get their own pair of presets and their own
	arc: a cold, hazy, overcast frozen waste warming into clear daylight. Same
	idea, same progress-as-lighting, different direction to travel. Which pair is
	used comes off the player's CurrentMap attribute.

	Style is deliberate too. Flat-shaded lighting (Brightness 0, ambient white,
	no shadows) is one popular way to look cartoony, and it is the wrong one
	here: flat-shading an ice block turns it into a coloured rectangle with no
	read of volume, and looking at ice is the entire game. Instead: real shadows
	kept hard (low ShadowSoftness is what reads as illustrated rather than
	photographic), saturation pushed, contrast pushed.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapDefs"))

local WorldLight = {}

type Preset = {
	ambient: Color3,
	outdoorAmbient: Color3,
	brightness: number,
	colorShiftTop: Color3,
	fogColor: Color3,
	fogEnd: number,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	atmosphereDensity: number,
	atmosphereHaze: number,
	bloomIntensity: number,
	bloomThreshold: number,
	envDiffuse: number,
	envSpecular: number,
	sunRays: number,
	saturation: number,
	contrast: number,
	tint: Color3,
}

-- Sealed in rock, everything cold and close. Dark, but deliberately not black:
-- with the lantern as the only real light source, too low an ambient stops the
-- unlit two thirds of the chamber reading as blue ice and makes it read as an
-- empty void, which is unplayable rather than atmospheric.
local CAVE_FROZEN: Preset = {
	ambient = Color3.fromRGB(28, 40, 60),
	outdoorAmbient = Color3.fromRGB(34, 48, 70),
	brightness = 1.0,
	colorShiftTop = Color3.fromRGB(60, 92, 132),
	fogColor = Color3.fromRGB(14, 22, 36),
	fogEnd = 260,
	atmosphereColor = Color3.fromRGB(96, 124, 158),
	atmosphereDecay = Color3.fromRGB(40, 56, 78),
	atmosphereDensity = 0.30,
	atmosphereHaze = 0.35,
	bloomIntensity = 0.5,
	bloomThreshold = 1.6,
	-- Near zero while the cave is sealed. EnvironmentDiffuseScale is a global,
	-- unoccluded ambient term: it does not care that there are eight studs of
	-- rock overhead, so leaving it up floods a sealed chamber with sky light and
	-- washes the whole palette out. Rising as the map opens is the point.
	envDiffuse = 0.05,
	envSpecular = 0.08,
	sunRays = 0,
	saturation = 0.08,
	contrast = 0.16,
	tint = Color3.fromRGB(226, 238, 255),
}

-- Open to daylight, fire lit, the room finally readable.
local CAVE_THAWED: Preset = {
	ambient = Color3.fromRGB(122, 116, 108),
	outdoorAmbient = Color3.fromRGB(168, 158, 140),
	brightness = 2.5,
	colorShiftTop = Color3.fromRGB(255, 220, 172),
	fogColor = Color3.fromRGB(150, 154, 150),
	fogEnd = 900,
	atmosphereColor = Color3.fromRGB(212, 206, 190),
	atmosphereDecay = Color3.fromRGB(150, 140, 122),
	atmosphereDensity = 0.18,
	atmosphereHaze = 0.45,
	bloomIntensity = 1.2,
	bloomThreshold = 1.15,
	envDiffuse = 0.55,
	envSpecular = 0.45,
	sunRays = 0.16,
	saturation = 0.3,
	contrast = 0.2,
	tint = Color3.fromRGB(255, 246, 232),
}

local function ensure(className: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = Lighting
	return created
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Outdoors, frozen. Bright but drained: an overcast white sky over a frozen
-- plain. EnvironmentDiffuseScale can run high here precisely because there is
-- no roof for it to ignore - the problem it causes in a sealed cave does not
-- exist under an open sky.
local OPEN_FROZEN: Preset = {
	ambient = Color3.fromRGB(96, 110, 130),
	outdoorAmbient = Color3.fromRGB(120, 138, 160),
	brightness = 2.0,
	colorShiftTop = Color3.fromRGB(170, 200, 235),
	fogColor = Color3.fromRGB(186, 204, 222),
	fogEnd = 700,
	atmosphereColor = Color3.fromRGB(200, 215, 232),
	atmosphereDecay = Color3.fromRGB(130, 150, 175),
	atmosphereDensity = 0.42,
	atmosphereHaze = 1.2,
	bloomIntensity = 0.9,
	bloomThreshold = 1.3,
	envDiffuse = 0.85,
	envSpecular = 0.60,
	sunRays = 0.08,
	saturation = 0.02,
	contrast = 0.14,
	tint = Color3.fromRGB(232, 242, 255),
}

-- Outdoors, thawed. The haze burns off and the desert comes up warm.
local OPEN_THAWED: Preset = {
	ambient = Color3.fromRGB(140, 126, 102),
	outdoorAmbient = Color3.fromRGB(185, 168, 138),
	brightness = 3.0,
	colorShiftTop = Color3.fromRGB(255, 226, 176),
	fogColor = Color3.fromRGB(226, 208, 176),
	fogEnd = 1400,
	atmosphereColor = Color3.fromRGB(240, 226, 198),
	atmosphereDecay = Color3.fromRGB(186, 164, 128),
	atmosphereDensity = 0.22,
	atmosphereHaze = 0.50,
	bloomIntensity = 1.4,
	bloomThreshold = 1.10,
	envDiffuse = 1.0,
	envSpecular = 0.70,
	sunRays = 0.22,
	saturation = 0.32,
	contrast = 0.20,
	tint = Color3.fromRGB(255, 247, 230),
}

local function pairFor(setting: MapDefs.MapSetting): (Preset, Preset)
	if setting == "open" then
		return OPEN_FROZEN, OPEN_THAWED
	end
	return CAVE_FROZEN, CAVE_THAWED
end

local function apply(t: number, frozen: Preset, thawed: Preset)
	local atmosphere = ensure("Atmosphere") :: Atmosphere
	local bloom = ensure("BloomEffect") :: BloomEffect
	local grade = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect

	Lighting.Ambient = frozen.ambient:Lerp(thawed.ambient, t)
	Lighting.OutdoorAmbient = frozen.outdoorAmbient:Lerp(thawed.outdoorAmbient, t)
	Lighting.Brightness = lerpNumber(frozen.brightness, thawed.brightness, t)
	Lighting.ColorShift_Top = frozen.colorShiftTop:Lerp(thawed.colorShiftTop, t)
	Lighting.FogColor = frozen.fogColor:Lerp(thawed.fogColor, t)
	Lighting.FogEnd = lerpNumber(frozen.fogEnd, thawed.fogEnd, t)

	atmosphere.Color = frozen.atmosphereColor:Lerp(thawed.atmosphereColor, t)
	atmosphere.Decay = frozen.atmosphereDecay:Lerp(thawed.atmosphereDecay, t)
	atmosphere.Density = lerpNumber(frozen.atmosphereDensity, thawed.atmosphereDensity, t)
	atmosphere.Haze = lerpNumber(frozen.atmosphereHaze, thawed.atmosphereHaze, t)

	bloom.Intensity = lerpNumber(frozen.bloomIntensity, thawed.bloomIntensity, t)
	bloom.Threshold = lerpNumber(frozen.bloomThreshold, thawed.bloomThreshold, t)
	bloom.Size = 24

	Lighting.EnvironmentDiffuseScale = lerpNumber(frozen.envDiffuse, thawed.envDiffuse, t)
	Lighting.EnvironmentSpecularScale = lerpNumber(frozen.envSpecular, thawed.envSpecular, t)

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Intensity = lerpNumber(frozen.sunRays, thawed.sunRays, t)
		rays.Spread = 0.8
		-- Pointless while the cave is sealed, and it only adds glare.
		rays.Enabled = rays.Intensity > 0.01
	end

	grade.Saturation = lerpNumber(frozen.saturation, thawed.saturation, t)
	grade.Contrast = lerpNumber(frozen.contrast, thawed.contrast, t)
	grade.TintColor = frozen.tint:Lerp(thawed.tint, t)
	grade.Brightness = 0
end

function WorldLight.start()
	local player = assert(Players.LocalPlayer, "CaveLight requires a LocalPlayer")

	-- Constant regardless of progress. Hard shadow edges are the single
	-- strongest cartoon lever available; softening them reads photographic.
	Lighting.ShadowSoftness = 0.06
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 9
	Lighting.GeographicLatitude = 78 -- a low raking sun, so shapes read as solid
	Lighting.FogStart = 0

	-- Roblox seeds new places with a DepthOfField, and it is wrong for gameplay
	-- at any setting - it blurs precisely the thing the player is aiming at.
	-- Blur is worse still on the phones most of the audience plays on.
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("DepthOfFieldEffect") or effect:IsA("BlurEffect") then
			effect.Enabled = false
		end
	end

	local function refresh()
		local value = player:GetAttribute("ThawedPct")
		local mapId = player:GetAttribute("CurrentMap")
		local def = if typeof(mapId) == "string" then MapDefs.get(mapId) else nil
		local frozen, thawed = pairFor(if def then def.setting else "cave")
		apply(if typeof(value) == "number" then math.clamp(value, 0, 1) else 0, frozen, thawed)
	end

	player:GetAttributeChangedSignal("ThawedPct"):Connect(refresh)
	-- Changing map changes which arc is being travelled, not just how far along
	-- it the player is, so this has to listen to both.
	player:GetAttributeChangedSignal("CurrentMap"):Connect(refresh)
	refresh()
end

-- Exposed so the finale can force the arc to its end independently of the
-- chunk count, and so tuning can be eyeballed without melting a whole map.
function WorldLight.preview(t: number, setting: MapDefs.MapSetting?)
	local frozen, thawed = pairFor(setting or "cave")
	apply(math.clamp(t, 0, 1), frozen, thawed)
end

return WorldLight
