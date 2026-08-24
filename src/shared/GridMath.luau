--!strict
--[[
	GridMath - pure coordinate math shared by the generator and the melt path.

	No Instances, no side effects. A map is three nested boxes sharing a centre:
	a solid shell, a chamber hollowed out of it, and the meltable ice volume
	sitting inside the chamber with a walkway ring around it.

	    shell     outermost, def.shell studs thick on every side
	    chamber   air; ice volume + walkway on X/Z + ceilingGap on top
	    ice       grid.X x grid.Y x grid.Z chunks of def.chunkSize studs

	A plot's origin is the minimum corner of its ice volume.

	Every function takes the map definition rather than reading globals (AD-4),
	because a plot hosts whichever map its owner is on (AD-5) and two plots on
	the same server can be on different ones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))

local GridMath = {}

-- Full size of the meltable ice volume, in studs.
function GridMath.iceSize(def: MapDefs.MapDef): Vector3
	return def.grid * def.chunkSize
end

-- Height in chunks of the ice column at (gx, gz). Uneven, so the top of the
-- block undulates instead of being a flat lid. Pure noise, so it is identical
-- every rebuild and the same on server and client.
function GridMath.columnHeight(def: MapDefs.MapDef, gx: number, gz: number): number
	local n = math.noise(gx * 0.17, gz * 0.17, def.order * 4.5)
	local relief = (n + 0.5) * def.relief
	return math.clamp(def.grid.Y - math.floor(relief + 0.5), 1, def.grid.Y)
end

-- Upper bound only. The real total is counted while building, because the
-- columns are not all full height.
function GridMath.maxChunkCount(def: MapDefs.MapDef): number
	return MapDefs.maxChunks(def)
end

-- Linear index for grid cell (gx, gy, gz). Lives here rather than in IceField
-- because Discoveries keys its claims by the same number - two copies of this
-- formula that drift apart would silently mismatch props to chunks.
function GridMath.cellIndex(def: MapDefs.MapDef, gx: number, gy: number, gz: number): number
	return (gx * def.grid.Y + gy) * def.grid.Z + gz
end

-- Inverse of cellIndex. Needed to expand outward from a struck chunk, which is
-- how the area tools work.
function GridMath.cellCoords(def: MapDefs.MapDef, cell: number): (number, number, number)
	local gz = cell % def.grid.Z
	local rest = (cell - gz) / def.grid.Z
	local gy = rest % def.grid.Y
	local gx = (rest - gy) / def.grid.Y
	return gx, gy, gz
end

-- Origin of plot `index` (0-based). Plots march along +X, far enough apart
-- that StreamingEnabled never sends one player's map to another client.
function GridMath.plotOrigin(index: number): Vector3
	return Vector3.new(index * Config.PLOT_SPACING, 0, 0)
end

-- World-space centre of chunk (gx, gy, gz), all 0-based.
function GridMath.chunkCenter(def: MapDefs.MapDef, origin: Vector3, gx: number, gy: number, gz: number): Vector3
	local s = def.chunkSize
	return origin + Vector3.new((gx + 0.5) * s, (gy + 0.5) * s, (gz + 0.5) * s)
end

-- Each box below returns (centre, size), the form Terrain:FillBlock wants.

function GridMath.iceBox(def: MapDefs.MapDef, origin: Vector3): (Vector3, Vector3)
	local size = GridMath.iceSize(def)
	return origin + size / 2, size
end

function GridMath.chamberBox(def: MapDefs.MapDef, origin: Vector3): (Vector3, Vector3)
	local ice = GridMath.iceSize(def)
	local w = def.walkway
	local size = Vector3.new(ice.X + w * 2, ice.Y + def.ceilingGap, ice.Z + w * 2)
	local min = origin - Vector3.new(w, 0, w)
	return min + size / 2, size
end

function GridMath.shellBox(def: MapDefs.MapDef, origin: Vector3): (Vector3, Vector3)
	-- Same centre as the chamber, grown by shell on all six faces.
	local center, size = GridMath.chamberBox(def, origin)
	local s = def.shell * 2
	return center, size + Vector3.new(s, s, s)
end

-- Standing spot on the -X walkway strip, level with the chamber floor and
-- looking straight at the ice face.
function GridMath.spawnPosition(def: MapDefs.MapDef, origin: Vector3): Vector3
	local ice = GridMath.iceSize(def)
	return origin + Vector3.new(-def.walkway / 2, 0, ice.Z / 2)
end

return GridMath
