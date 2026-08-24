--!strict
--[[
	Meltwater - the ice you removed has to go somewhere.

	The mid-state reference image shows water pooled across the cave floor, and
	it is the one progress cue that needs no UI: the room physically fills as you
	work. It also costs almost nothing, because it is a single terrain fill whose
	height is a function of how much has been cleared.

	Two things keep it cheap and well-behaved:

	  * The level only moves in whole studs, and a fill only happens when it
	    changes. Filling on every melt would mean a terrain write twice a second
	    per player; this is at most four writes across an entire map.

	    It was quantised to whole 4-stud voxels first, which was wrong: with a
	    one-chunk cap that left exactly one step, so the pool snapped from
	    nothing to full at 60% and read as a bug rather than as progress.
	    Terrain water renders partial occupancy, so a sub-voxel height is fine.
	  * It fills the ice footprint only, never the walkway ring. Remaining ice is
	    solid and opaque, so water inside the block is hidden until that ice is
	    gone - which means the pool appears exactly where the player has dug,
	    with no need to track the cleared region.

	Depth is capped at one chunk. Deeper looks better in stills and plays worse:
	Roblox switches the character to swimming once it is submerged enough, and a
	player who has to swim across their own excavation to keep mining is being
	punished for progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))

local Meltwater = {}

export type State = {
	origin: Vector3,
	def: MapDefs.MapDef,
	depth: number,
}

function Meltwater.new(origin: Vector3, def: MapDefs.MapDef): State
	return { origin = origin, def = def, depth = 0 }
end

function Meltwater.setMap(state: State, def: MapDefs.MapDef)
	state.def = def
	state.depth = 0
end

-- Set the pool from progress. Returns true when the level actually moved.
function Meltwater.update(state: State, fraction: number): boolean
	local target = math.floor(math.clamp(fraction, 0, 1) * state.def.waterDepth + 0.5)
	if target == state.depth then
		return false
	end
	state.depth = target
	if target <= 0 then
		return true
	end

	local ice = GridMath.iceSize(state.def)
	local size = Vector3.new(ice.X, target, ice.Z)
	local centre = state.origin + Vector3.new(ice.X / 2, target / 2, ice.Z / 2)
	Workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Water)
	return true
end

-- Clear it out. Called when a plot re-freezes, since IceField refills the whole
-- chamber with air anyway - this just keeps the tracked depth honest.
function Meltwater.reset(state: State)
	state.depth = 0
end

return Meltwater
