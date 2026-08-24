--!strict
--[[
	CaveLight - the lighting arc, and the reason it lives on the client.

	Lighting is a global service, exactly like Terrain. There is one of it per
	place and the server cannot give each player their own. But a LocalScript
	changing Lighting only changes that client copy - so the arc is driven here,
	from the player own ThawedPct attribute (AD-6).

	The arc itself comes straight from the design doc. The cave starts with no
	light source at all and ends blown open to daylight with a fire lit, and the
	capstone of its skill tree is learning to make fire. So lighting is not
	decoration on top of progress - it *is* the progress bar, and the player
	should be able to tell roughly how far in they are by how the room looks
	before they ever glance at a number.

	Style is deliberate too. Flat-shaded lighting (Brightness 0, ambient white,
	no shadows) is one popular way to look cartoony, and it is the wrong one
	here: flat-shading an ice block turns it into a coloured rectangle with no
	read of volume, and looking at ice is the entire game. Instead: real shadows
	kept hard (low ShadowSoftness is what reads as illustrated rather than
	photographic), saturation pushed, contrast pushed.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local CaveLight = {}

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
local FROZEN: Preset = {
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
local THAWED: Preset = {
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

local function apply(t: number)
	local atmosphere = ensure("Atmosphere") :: Atmosphere
	local bloom = ensure("BloomEffect") :: BloomEffect
	local grade = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect

	Lighting.Ambient = FROZEN.ambient:Lerp(THAWED.ambient, t)
	Lighting.OutdoorAmbient = FROZEN.outdoorAmbient:Lerp(THAWED.outdoorAmbient, t)
	Lighting.Brightness = lerpNumber(FROZEN.brightness, THAWED.brightness, t)
	Lighting.ColorShift_Top = FROZEN.colorShiftTop:Lerp(THAWED.colorShiftTop, t)
	Lighting.FogColor = FROZEN.fogColor:Lerp(THAWED.fogColor, t)
	Lighting.FogEnd = lerpNumber(FROZEN.fogEnd, THAWED.fogEnd, t)

	atmosphere.Color = FROZEN.atmosphereColor:Lerp(THAWED.atmosphereColor, t)
	atmosphere.Decay = FROZEN.atmosphereDecay:Lerp(THAWED.atmosphereDecay, t)
	atmosphere.Density = lerpNumber(FROZEN.atmosphereDensity, THAWED.atmosphereDensity, t)
	atmosphere.Haze = lerpNumber(FROZEN.atmosphereHaze, THAWED.atmosphereHaze, t)

	bloom.Intensity = lerpNumber(FROZEN.bloomIntensity, THAWED.bloomIntensity, t)
	bloom.Threshold = lerpNumber(FROZEN.bloomThreshold, THAWED.bloomThreshold, t)
	bloom.Size = 24

	Lighting.EnvironmentDiffuseScale = lerpNumber(FROZEN.envDiffuse, THAWED.envDiffuse, t)
	Lighting.EnvironmentSpecularScale = lerpNumber(FROZEN.envSpecular, THAWED.envSpecular, t)

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Intensity = lerpNumber(FROZEN.sunRays, THAWED.sunRays, t)
		rays.Spread = 0.8
		-- Pointless while the cave is sealed, and it only adds glare.
		rays.Enabled = rays.Intensity > 0.01
	end

	grade.Saturation = lerpNumber(FROZEN.saturation, THAWED.saturation, t)
	grade.Contrast = lerpNumber(FROZEN.contrast, THAWED.contrast, t)
	grade.TintColor = FROZEN.tint:Lerp(THAWED.tint, t)
	grade.Brightness = 0
end

function CaveLight.start()
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
		apply(if typeof(value) == "number" then math.clamp(value, 0, 1) else 0)
	end

	player:GetAttributeChangedSignal("ThawedPct"):Connect(refresh)
	refresh()
end

-- Exposed so the finale can force the arc to its end independently of the
-- chunk count, and so tuning can be eyeballed without melting a whole map.
function CaveLight.preview(t: number)
	apply(math.clamp(t, 0, 1))
end

return CaveLight
