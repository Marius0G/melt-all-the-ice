--!strict
--[[
	IceField - the meltable ice on a single plot (AD-1).

	The authoritative unit is a chunk Part on a 4-stud grid, each carrying HP.
	Those Parts are now also what the player sees: flat cyan SmoothPlastic,
	part-transparent, with a little Reflectance. Terrain no longer skins the ice
	at all - it only carves the rock chamber around it.

	That swap is worth the note. Terrain Ice is smooth and organic, but its PBR
	texture is the single thing that fights a cartoony look hardest, and it can
	only ever vanish a voxel at a time, so a melt reads as a hole appearing.
	Discrete Parts crack, frost, shrink and shatter, and a shape frozen inside
	the ice can be seen through them. It also takes terrain writes off the melt
	path entirely: breaking a chunk is now just destroying a Part.

	Two costs come with it, both handled here:

	  * Overdraw. A thousand part-transparent parts stacked is a lot of fill, so
	    only chunks with an exposed face are drawn; the rest sit at Transparency
	    1 until a neighbour dies and uncovers them. Roughly 750 drawn instead of
	    1536, and it costs nothing visually because the hidden ones are fully
	    occluded anyway.
	  * Collision. The ice is solid now, so melting in is the only way through.
	    That is the game, but note a melted row is 4 studs and a character is
	    about 5, so it takes two rows to walk into your own tunnel.

	build() is idempotent (AD-3). Running it on a live, half-melted plot restores
	it to fully frozen, so first generation and the re-freeze on player leave are
	the same code path rather than a retrofitted reset.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Feel"))
local GridMath = require(Shared:WaitForChild("GridMath"))

export type Chunk = {
	part: BasePart,
	hp: number,
	center: Vector3,
	gx: number,
	gy: number,
	gz: number,
	visible: boolean,
	stage: number,
}

export type DamageResult = {
	destroyed: boolean,
	center: Vector3,
	hpRatio: number, -- fraction of HP left after the hit; 0 once destroyed
}

export type IceField = {
	index: number,
	origin: Vector3,
	folder: Folder,
	chunks: { [BasePart]: Chunk },
	grid: { [number]: Chunk }, -- linear cell index -> chunk, for neighbour lookups
	total: number,
	destroyed: number,
}

local IceField = {}

local CHUNK_VECTOR = Vector3.new(Config.CHUNK_SIZE, Config.CHUNK_SIZE, Config.CHUNK_SIZE)

local FACES = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local function fill(center: Vector3, size: Vector3, material: Enum.Material)
	Workspace.Terrain:FillBlock(CFrame.new(center), size, material)
end

local function cellIndex(gx: number, gy: number, gz: number): number
	return (gx * Config.GRID_Y + gy) * Config.GRID_Z + gz
end

local function inBounds(gx: number, gy: number, gz: number): boolean
	return gx >= 0
		and gx < Config.GRID_X
		and gy >= 0
		and gy < Config.GRID_Y
		and gz >= 0
		and gz < Config.GRID_Z
end

-- A chunk is worth drawing only if one of its six faces touches something that
-- is not ice: the edge of the block, or a hole melted into it.
local function isExposed(field: IceField, gx: number, gy: number, gz: number): boolean
	for _, face in FACES do
		local nx, ny, nz = gx + face.X, gy + face.Y, gz + face.Z
		if not inBounds(nx, ny, nz) then
			return true
		end
		if field.grid[cellIndex(nx, ny, nz)] == nil then
			return true
		end
	end
	return false
end

local function stageFor(ratio: number): number
	for index, stage in Feel.ICE_STAGES do
		if ratio > stage.above then
			return index
		end
	end
	return #Feel.ICE_STAGES
end

-- Smooth, deterministic per-cell variation in the -1..1 range.
local function facet(gx: number, gy: number, gz: number): number
	return 1 + math.noise(gx * 0.7, gy * 0.7, gz * 0.7) * Feel.ICE_FACET_JITTER
end

local function paint(chunk: Chunk)
	local stage = Feel.ICE_STAGES[chunk.stage]
	local tint = facet(chunk.gx, chunk.gy, chunk.gz)
	chunk.part.Color = Color3.new(
		math.clamp(stage.color.R * tint, 0, 1),
		math.clamp(stage.color.G * tint, 0, 1),
		math.clamp(stage.color.B * tint, 0, 1)
	)
	chunk.part.Size = CHUNK_VECTOR * stage.scale
	chunk.part.Transparency = if chunk.visible then stage.transparency else 1
end

local function setVisible(chunk: Chunk, visible: boolean)
	if chunk.visible == visible then
		return
	end
	chunk.visible = visible
	paint(chunk)
end

-- Build, or rebuild, the plot from scratch. Safe to call at any time.
function IceField.build(field: IceField)
	-- Rock shell -> hollow the chamber. Running both unconditionally is what
	-- makes regeneration idempotent: whatever the player carved out gets
	-- overwritten rather than patched. No ice is filled - the Parts are the ice.
	local rockCenter, rockSize = GridMath.rockBox(field.origin)
	fill(rockCenter, rockSize, Enum.Material.Rock)

	local chamberCenter, chamberSize = GridMath.chamberBox(field.origin)
	fill(chamberCenter, chamberSize, Enum.Material.Air)

	-- Drop any chunks that survived the previous run, then lay a fresh grid.
	field.folder:ClearAllChildren()
	table.clear(field.chunks)
	table.clear(field.grid)

	local built = 0
	for gx = 0, Config.GRID_X - 1 do
		for gz = 0, Config.GRID_Z - 1 do
			-- Columns stop at their own height, which is what gives the block an
			-- uneven top rather than a flat lid.
			for gy = 0, GridMath.columnHeight(gx, gz) - 1 do
				local center = GridMath.chunkCenter(field.origin, gx, gy, gz)

				local part = Instance.new("Part")
				part.Name = string.format("C%d_%d_%d", gx, gy, gz)
				part.Size = CHUNK_VECTOR
				part.CFrame = CFrame.new(center)
				part.Anchored = true
				-- Solid: melting in is the only way through.
				part.CanCollide = true
				part.CanTouch = false
				-- CanQuery stays on; being a raycast target is the whole point.
				part.CastShadow = false
				part.Material = Feel.ICE_MATERIAL
				part.Reflectance = Feel.ICE_REFLECTANCE
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth
				part.Transparency = 1 -- corrected by the visibility pass below
				part.Parent = field.folder

				local chunk: Chunk = {
					part = part,
					hp = Config.CHUNK_HP,
					center = center,
					gx = gx,
					gy = gy,
					gz = gz,
					visible = false,
					stage = 1,
				}
				field.chunks[part] = chunk
				field.grid[cellIndex(gx, gy, gz)] = chunk
				built += 1
			end
		end
	end

	-- Visibility has to be a second pass: whether a cell is exposed depends on
	-- its neighbours, which do not all exist during the first loop.
	for _, chunk in field.chunks do
		chunk.visible = isExposed(field, chunk.gx, chunk.gy, chunk.gz)
		paint(chunk)
	end

	field.total = built
	field.destroyed = 0
end

function IceField.new(index: number): IceField
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_Ice", index)
	folder.Parent = Workspace

	local field: IceField = {
		index = index,
		origin = GridMath.plotOrigin(index),
		folder = folder,
		chunks = {},
		grid = {},
		total = 0,
		destroyed = 0,
	}

	IceField.build(field)
	return field
end

-- Apply damage to the chunk backing the given part. Returns nil when it is not
-- a live chunk of this field; otherwise a result describing what the hit did.
-- A destroyed result is the caller cue to pay out.
function IceField.damage(field: IceField, part: BasePart, amount: number): DamageResult?
	local chunk = field.chunks[part]
	if not chunk then
		return nil
	end

	chunk.hp -= amount
	if chunk.hp > 0 then
		local ratio = chunk.hp / Config.CHUNK_HP
		local stage = stageFor(ratio)
		if stage ~= chunk.stage then
			chunk.stage = stage
			paint(chunk)
		end
		return { destroyed = false, center = chunk.center, hpRatio = ratio }
	end

	field.chunks[part] = nil
	field.grid[cellIndex(chunk.gx, chunk.gy, chunk.gz)] = nil
	part:Destroy()
	field.destroyed += 1

	-- The six cells this one was hiding are surfaces now, so they have to start
	-- drawing. This is what keeps the interior cull honest as the block opens up.
	for _, face in FACES do
		local nx, ny, nz = chunk.gx + face.X, chunk.gy + face.Y, chunk.gz + face.Z
		if inBounds(nx, ny, nz) then
			local neighbour = field.grid[cellIndex(nx, ny, nz)]
			if neighbour then
				setVisible(neighbour, true)
			end
		end
	end

	return { destroyed = true, center = chunk.center, hpRatio = 0 }
end

-- Fraction thawed, 0..1.
function IceField.progress(field: IceField): number
	if field.total == 0 then
		return 0
	end
	return field.destroyed / field.total
end

-- How many chunks are actually being drawn. Diagnostic only.
function IceField.visibleCount(field: IceField): number
	local count = 0
	for _, chunk in field.chunks do
		if chunk.visible then
			count += 1
		end
	end
	return count
end

return IceField
