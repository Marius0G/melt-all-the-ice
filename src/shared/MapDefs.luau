--!strict
--[[
	MapDefs - the three maps, as data (AD-4).

	Cave, Pyramid and Troy are one engine reading three definitions, not three
	generators. Everything that differs between them lives here: how big the
	volume is, how coarse the grid is, what the shell is made of, what is buried
	in it, which tools it hands out, and what its finale is.

	Chunk size is per-map and is the lever that keeps this affordable. The cave
	is 4 studs, one terrain voxel, because it is small and wants fine detail.
	The later maps are far larger in world space but use 8-stud chunks, so a map
	four times the volume is not four times the Parts. Any chunk size must stay a
	multiple of 4 - terrain voxels are 4x4x4, so anything else makes the shell
	carve ragged.

	Ordering matters: a map is unlocked by clearing the one before it, and
	`order` is what decides "the one before it".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

export type PropEntry = {
	key: string,
	count: number,
}

-- Where a map sits in the world.
--
--   "cave"  hollows a chamber out of solid rock, sealed overhead, and is lit
--           entirely from inside. The lighting arc runs dark to bright.
--   "open"  lays a ground slab under an open sky and has no ceiling and no
--           walls at all. A pyramid buried in a cave was never right - it is a
--           thing that stands in a desert - and Troy is a city. Their arc runs
--           cold and hazy to warm and clear instead.
export type MapSetting = "cave" | "open"

export type MapDef = {
	id: string,
	label: string,
	order: number,

	-- Geometry. grid is a count of chunks per axis, not studs.
	setting: MapSetting,
	chunkSize: number,
	grid: Vector3,
	relief: number, -- how many chunk layers the top may be eaten away by
	walkway: number,
	ceilingGap: number,
	shell: number,
	shellMaterial: Enum.Material,

	-- Look.
	rockColor: Color3,
	iceColor: Color3,
	waterDepth: number,

	-- Content.
	props: { PropEntry },
	tools: { string }, -- which tools this map can hand out
	upgrades: { string }, -- which upgrade keys its tree shows

	-- Payout scaling. Later maps are bigger and harder, so a chunk is worth more.
	moneyPerChunk: number,
	chunkHp: number,
}

local MapDefs = {}

local DEFS: { MapDef } = {
	{
		id = "cave",
		label = "The Cave",
		order = 1,

		-- 12x5x12, not 16x6x16.
		--
		-- The doc calls the cave "cea mai usoara, introductiva si mai mica", and
		-- at the larger size it was not: ~1150 chunks at three stone hits each,
		-- gated by stamina to roughly half a chunk a second, is over half an hour
		-- to clear. This lands nearer fifteen minutes and still reads as a room.
		-- The room grew; the ice did not. "Bigger cave" is about the space
		-- feeling like a place rather than a box - there is now room to walk
		-- right around the block, put torches and braziers on the walls, and
		-- look up at something. Growing the ice instead would have lengthened
		-- the first map every new player meets, which is where they drop off.
		setting = "cave",
		chunkSize = 4,
		grid = Vector3.new(12, 5, 12),
		relief = 3,
		walkway = 28,
		ceilingGap = 28,
		shell = 8,
		shellMaterial = Enum.Material.Rock,

		rockColor = Color3.fromRGB(96, 104, 118),
		iceColor = Feel.ICE_MID,
		waterDepth = 4,

		props = {
			{ key = "Mammoth", count = 1 },
			{ key = "FrozenPerson", count = 1 },
			{ key = "FrozenWolf", count = 1 },
			{ key = "SpearCache", count = 2 },
			{ key = "BonePile", count = 2 },
			{ key = "Chest", count = 2 },
			{ key = "CrystalCluster", count = 2 },
			{ key = "Pot", count = 2 },
			{ key = "Stalagmite", count = 2 },
		},
		tools = { "stone", "axe", "torch" },
		upgrades = { "break1", "income1", "stamina1", "fuel1", "axe", "torch" },

		moneyPerChunk = 1,
		chunkHp = 30,
	},
	{
		id = "pyramid",
		label = "The Pyramid",
		order = 2,

		-- Four times the footprint of the cave, but on an 8-stud grid, so about
		-- the same number of Parts. 24 x 4 x 24 chunks = 192 x 32 x 192 studs.
		--
		-- Four layers deep, not five. The landmark has to read as a landmark
		-- from the spawn, and at 40 studs of ice only the pyramid's very top
		-- cleared it. At 32 nearly half of it stands out. The ceiling gap grows
		-- to match so the capstone still has air above it.
		setting = "open",
		chunkSize = 8,
		grid = Vector3.new(24, 4, 24),
		relief = 2,
		walkway = 24,
		ceilingGap = 32,
		shell = 16,
		shellMaterial = Enum.Material.Sandstone,

		rockColor = Color3.fromRGB(206, 174, 116),
		iceColor = Color3.fromRGB(158, 210, 240),
		waterDepth = 6,

		props = {
			{ key = "Sarcophagus", count = 2 },
			{ key = "Obelisk", count = 2 },
			{ key = "CanopicJar", count = 4 },
			{ key = "Chest", count = 3 },
			{ key = "Pot", count = 3 },
			{ key = "CrystalCluster", count = 2 },
		},
		tools = { "torch", "campfire", "scepter" },
		upgrades = { "break1", "income1", "stamina1", "fuel1", "campfire", "scepter" },

		moneyPerChunk = 6,
		chunkHp = 60,
	},
	{
		id = "troy",
		label = "Troy",
		order = 3,

		-- Shallower than it was, for the same reason as the pyramid: at 40 studs
		-- of ice only the Parthenon's roof showed and it read as a grey lump.
		-- At 32 the top of the colonnade clears the surface, so it is legibly a
		-- temple from the moment you arrive.
		setting = "open",
		chunkSize = 8,
		grid = Vector3.new(28, 4, 28),
		relief = 2,
		walkway = 24,
		ceilingGap = 36,
		shell = 16,
		shellMaterial = Enum.Material.Limestone,

		rockColor = Color3.fromRGB(198, 194, 178),
		iceColor = Color3.fromRGB(150, 200, 235),
		waterDepth = 6,

		props = {
			{ key = "TrojanHorse", count = 1 },
			{ key = "Column", count = 4 },
			{ key = "Statue", count = 2 },
			{ key = "Shield", count = 3 },
			{ key = "Pot", count = 3 },
			{ key = "Chest", count = 2 },
		},
		tools = { "greekfire", "chains" },
		upgrades = { "break1", "income1", "stamina1", "fuel1", "greekfire", "chains" },

		moneyPerChunk = 20,
		chunkHp = 110,
	},
}

MapDefs.DEFS = DEFS

local byId: { [string]: MapDef } = {}
local byOrder: { [number]: MapDef } = {}
for _, def in DEFS do
	byId[def.id] = def
	byOrder[def.order] = def
end

MapDefs.FIRST = DEFS[1]

function MapDefs.get(id: string): MapDef?
	return byId[id]
end

-- The map unlocked by clearing this one, if any.
function MapDefs.next(def: MapDef): MapDef?
	return byOrder[def.order + 1]
end

-- Full size of a map's meltable volume, in studs.
function MapDefs.iceSize(def: MapDef): Vector3
	return def.grid * def.chunkSize
end

function MapDefs.maxChunks(def: MapDef): number
	return def.grid.X * def.grid.Y * def.grid.Z
end

return MapDefs
