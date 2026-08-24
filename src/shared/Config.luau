--!strict
--[[
	Config - the tuning that is genuinely global.

	Most of what used to live here moved out when maps became data (AD-4), and
	the split is worth stating so things get added back in the right place:

	    MapDefs   anything that differs per map - grid size, chunk size, shell
	              material, palette, what is buried in it, what a chunk pays
	    Tools     anything that differs per tool - damage, reach, cooldown,
	              which gate it spends and how much of it
	    Feel      anything about presentation - shake, particles, sound, timing
	    here      the rest: the plot pool, and the baseline for the two gates

	The gate values here are baselines, not limits. Upgrades move them per
	player (see Progression), so nothing should read these expecting the number
	a given player actually has.
]]

local Config = {
	-- Plots (AD-2). PLOT_COUNT caps players per server, because terrain and
	-- Part cost scale with plots x map size.
	--
	-- PLOT_SPACING must stay above Workspace.StreamingTargetRadius (512, set in
	-- default.project.json) or clients stream in their neighbours' plots -
	-- thousands of parts nobody can see. It also has to clear the largest map:
	-- Troy is 304 studs across including its shell.
	PLOT_COUNT = 6,
	PLOT_SPACING = 1024,

	-- Stamina gate, for the physical tools. Baseline only.
	STAMINA_MAX = 100,
	STAMINA_REGEN = 12, -- per second

	-- Fuel gate, for the fire tools. Baseline only.
	--
	-- Tuned against sustained throughput, not burst. At regen 4 the torch was
	-- 0.44 chunks/second against the stone's 0.62 - it felt stronger per swing
	-- and was strictly worse to actually play, which inverts the progression the
	-- design doc describes. At 9 it sustains about 1.0, comfortably ahead, and
	-- the full bar still empties in eight fast swings so the gate is real.
	FUEL_MAX = 72,
	FUEL_REGEN = 9, -- per second
}

return table.freeze(Config)
