--!strict
--[[
	GridMath - pure coordinate math shared by the generator and the melt path.

	No Instances, no side effects. The cave is three nested boxes sharing a
	centre: a solid rock block, a chamber hollowed out of it, and the meltable
	ice volume sitting inside the chamber with a walkway ring around it.

	    rock      outermost, SHELL studs thick on every side
	    chamber   air; ice volume + WALKWAY on X/Z + CEILING_GAP on top
	    ice       GRID_X x GRID_Y x GRID_Z chunks of CHUNK_SIZE studs

	A plot's origin is the minimum corner of its ice volume.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GridMath = {}

-- Full size of the meltable ice volume, in studs.
function GridMath.iceSize(): Vector3
	return Vector3.new(
		Config.GRID_X * Config.CHUNK_SIZE,
		Config.GRID_Y * Config.CHUNK_SIZE,
		Config.GRID_Z * Config.CHUNK_SIZE
	)
end

-- Height in chunks of the ice column at (gx, gz). Uneven, so the top of the
-- block undulates instead of being a flat lid. Pure noise, so it is identical
-- every rebuild and the same on server and client.
function GridMath.columnHeight(gx: number, gz: number): number
	local n = math.noise(gx * 0.17, gz * 0.17, 0.5) -- roughly -0.5 .. 0.5
	local relief = (n + 0.5) * Config.ICE_RELIEF
	return math.clamp(Config.GRID_Y - math.floor(relief + 0.5), 1, Config.GRID_Y)
end

-- Upper bound only. The real total is counted while building, because the
-- columns are not all full height.
function GridMath.maxChunkCount(): number
	return Config.GRID_X * Config.GRID_Y * Config.GRID_Z
end

-- Origin of plot `index` (0-based). Plots march along +X, far enough apart
-- that StreamingEnabled never sends one player's cave to another client.
function GridMath.plotOrigin(index: number): Vector3
	return Vector3.new(index * Config.PLOT_SPACING, 0, 0)
end

-- World-space centre of chunk (gx, gy, gz), all 0-based.
function GridMath.chunkCenter(origin: Vector3, gx: number, gy: number, gz: number): Vector3
	local s = Config.CHUNK_SIZE
	return origin + Vector3.new((gx + 0.5) * s, (gy + 0.5) * s, (gz + 0.5) * s)
end

-- Each box below returns (centre, size), the form Terrain:FillBlock wants.

function GridMath.iceBox(origin: Vector3): (Vector3, Vector3)
	local size = GridMath.iceSize()
	return origin + size / 2, size
end

function GridMath.chamberBox(origin: Vector3): (Vector3, Vector3)
	local ice = GridMath.iceSize()
	local w = Config.WALKWAY
	local size = Vector3.new(ice.X + w * 2, ice.Y + Config.CEILING_GAP, ice.Z + w * 2)
	local min = origin - Vector3.new(w, 0, w)
	return min + size / 2, size
end

function GridMath.rockBox(origin: Vector3): (Vector3, Vector3)
	-- Same centre as the chamber, grown by SHELL on all six faces.
	local center, size = GridMath.chamberBox(origin)
	local s = Config.SHELL * 2
	return center, size + Vector3.new(s, s, s)
end

-- Standing spot on the -X walkway strip, level with the chamber floor and
-- looking straight at the ice face.
function GridMath.spawnPosition(origin: Vector3): Vector3
	local ice = GridMath.iceSize()
	return origin + Vector3.new(-Config.WALKWAY / 2, 0, ice.Z / 2)
end

return GridMath
