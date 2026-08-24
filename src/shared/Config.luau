--!strict
--[[
	Config - every tuning knob for the cave vertical slice.

	Grid resolution and plot count are settled design calls (docs/GDD.md AD-1,
	AD-2). The economy and stamina numbers are opening guesses meant to be
	felt out in playtest.

	CHUNK_SIZE must stay a multiple of 4. Roblox terrain voxels are 4x4x4
	studs, so any other value makes Terrain:FillBlock bleed into neighbouring
	chunks' voxels and leaves ragged edges behind every melt.
]]

local Config = {
	-- Ice grid (AD-1). 4 studs is exactly one terrain voxel.
	CHUNK_SIZE = 4,
	GRID_X = 16,
	GRID_Y = 6,
	GRID_Z = 16,
	-- How many chunk layers the top surface may be eaten away by, so the ice
	-- reads as a glacier rather than a spawned cuboid. Deterministic from grid
	-- position, so a rebuild reproduces the same shape (AD-3).
	ICE_RELIEF = 3,

	-- Plots (AD-2). PLOT_COUNT caps players per server.
	-- PLOT_SPACING must stay above Workspace.StreamingTargetRadius (512, set in
	-- default.project.json) or clients stream in their neighbours' plots -
	-- thousands of parts nobody can see. It also has to leave room for the
	-- largest map, not just the cave.
	PLOT_COUNT = 6,
	PLOT_SPACING = 1024,

	-- Cave shell, in studs. All multiples of CHUNK_SIZE to stay voxel-aligned.
	WALKWAY = 12, -- air ring around the ice, at floor level
	CEILING_GAP = 8, -- air above the ice
	SHELL = 8, -- rock thickness around the chamber

	-- Melting economy. CHUNK_HP/STONE_DAMAGE decides how many hits a chunk
	-- takes, and that count is what the player actually feels. Three is the
	-- floor for legible progress - at two there is only one intermediate state
	-- to see, which reads as a chunk flicking between "fine" and "gone".
	CHUNK_HP = 30,
	STONE_DAMAGE = 10,
	MONEY_PER_CHUNK = 1,

	-- Stamina gate.
	STAMINA_MAX = 100,
	STAMINA_PER_SWING = 8,
	STAMINA_REGEN = 12, -- per second
	SWING_COOLDOWN = 0.45,
	MAX_REACH = 24,
}

return table.freeze(Config)
