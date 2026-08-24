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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Finale = {}

-- Long enough to look at what you did, short enough not to strand the player in
-- an empty room.
local RESET_DELAY = 14

local celebrating: { [number]: boolean } = {}

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
	found: number,
	total: number
): boolean
	if celebrating[plotIndex] then
		return false
	end
	celebrating[plotIndex] = true

	openSkylight(map, origin)
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
