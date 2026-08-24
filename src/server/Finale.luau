--!strict
--[[
	Finale - what happens when the last of the ice goes.

	The design doc gives the cave an explicit end state, and the reference image
	for it is unambiguous: the cave mouth blown open to daylight, a fire lit,
	warm light, a few blue pillars left standing. So clearing the map physically
	opens the chamber rather than just printing "100%".

	The lighting half needs no work here. The client already drives its whole
	arc from ThawedPct (AD-6), so reaching 1.0 walks it to the warm end on its
	own; this only has to make the geometry agree by cutting a skylight through
	the rock shell so there is somewhere for the daylight to be coming from.

	The plot then re-freezes (AD-3), which is also what makes the map replayable
	rather than a one-way door.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SetPieces = require(script.Parent:WaitForChild("SetPieces"))

local Finale = {}

-- Long enough to look at what you did, short enough not to strand the player in
-- an empty room.
local RESET_DELAY = 14

local celebrating: { [number]: boolean } = {}

-- What each map's beacon looks like when it catches. The doc is explicit for
-- the pyramid - "sa se aprinda varful priamidei" - and the cave's is the
-- campfire from its end-state reference.
local BEACON_COLOR: { [string]: Color3 } = {
	cave = Color3.fromRGB(255, 158, 52),
	pyramid = Color3.fromRGB(255, 208, 84),
	troy = Color3.fromRGB(255, 244, 214),
}

-- Light the one Part the map's builder tagged. Nothing happens if a map has no
-- beacon, which is a legitimate state rather than an error.
local function lightBeacon(pieces: SetPieces.Field, map: MapDefs.MapDef)
	local beacon = SetPieces.beacon(pieces)
	if not beacon then
		return
	end

	local tint = BEACON_COLOR[map.id] or Color3.fromRGB(255, 200, 38)

	beacon.Material = Enum.Material.Neon
	-- Tweened rather than snapped: this is the last beat of the map, and it
	-- should read as catching rather than as a light switch.
	TweenService:Create(beacon, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Color = tint }):Play()

	local light = Instance.new("PointLight")
	light.Name = "BeaconLight"
	light.Color = tint
	light.Range = 0
	light.Brightness = 0
	light.Shadows = false
	light.Parent = beacon
	TweenService:Create(light, TweenInfo.new(2.2, Enum.EasingStyle.Quad), {
		Range = 120,
		Brightness = 6,
	}):Play()

	local attachment = Instance.new("Attachment")
	attachment.Parent = beacon

	local embers = Instance.new("ParticleEmitter")
	embers.Texture = Feel.TEXTURES.GLOW
	embers.Rate = 26
	embers.Lifetime = NumberRange.new(1.2, 2.4)
	embers.Speed = NumberRange.new(4, 10)
	embers.SpreadAngle = Vector2.new(26, 26)
	embers.Acceleration = Vector3.new(0, 9, 0)
	embers.Drag = 1.2
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 214)),
		ColorSequenceKeypoint.new(0.5, tint),
		ColorSequenceKeypoint.new(1, tint:Lerp(Color3.new(0, 0, 0), 0.7)),
	})
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Parent = attachment
end

-- Cut a shaft through the ceiling so daylight has a path in. Centred on the
-- chamber and deliberately smaller than it, so the room stays a cave with a
-- hole in it rather than becoming an open pit.
local function openSkylight(map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local _, chamberSize = GridMath.chamberBox(map, origin)

	local width = ice.X * 0.45
	local depth = ice.Z * 0.45
	-- From just under the ceiling up through the shell, plus margin so the cut
	-- clears the rock entirely rather than leaving a thin lid.
	local floor = origin.Y + chamberSize.Y - map.chunkSize
	local height = map.shell + map.chunkSize * 3

	Workspace.Terrain:FillBlock(
		CFrame.new(origin + Vector3.new(ice.X / 2, floor + height / 2, ice.Z / 2)),
		Vector3.new(width, height, depth),
		Enum.Material.Air
	)
end

-- Fire once per clearing. Returns true if this call was the one that triggered.
function Finale.trigger(
	player: Player,
	plotIndex: number,
	map: MapDefs.MapDef,
	origin: Vector3,
	pieces: SetPieces.Field,
	found: number,
	total: number
): boolean
	if celebrating[plotIndex] then
		return false
	end
	celebrating[plotIndex] = true

	openSkylight(map, origin)
	-- Convenient accident of the existing geometry: the skylight is cut at 45%
	-- of the ice span dead centre, which is exactly where the landmark stands -
	-- so the daylight column lands on the thing that just lit up.
	lightBeacon(pieces, map)
	Remotes.finale():FireClient(player, map.label, found, total, RESET_DELAY)
	return true
end

function Finale.clear(plotIndex: number)
	celebrating[plotIndex] = nil
end

function Finale.resetDelay(): number
	return RESET_DELAY
end

return Finale
