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

	-- Plots (AD-2). PLOT_COUNT caps players per server.
	PLOT_COUNT = 6,
	PLOT_SPACING = 512,

	-- Cave shell, in studs. All multiples of CHUNK_SIZE to stay voxel-aligned.
	WALKWAY = 12, -- air ring around the ice, at floor level
	CEILING_GAP = 8, -- air above the ice
	SHELL = 8, -- rock thickness around the chamber

	-- Melting economy.
	CHUNK_HP = 20,
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
