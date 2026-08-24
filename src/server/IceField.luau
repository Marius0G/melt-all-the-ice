--!strict
--[[
	IceField - the meltable ice on a single plot (AD-1), for whichever map that
	plot is currently hosting (AD-4, AD-5).

	The authoritative unit is a chunk Part on the map's grid, each carrying HP.
	Those Parts are also what the player sees: flat SmoothPlastic in the map's
	ice colour, near-opaque, with a little Reflectance. Terrain no longer skins
	the ice at all - it only carves the shell and chamber around it.

	Terrain Ice is smooth and organic, but its PBR texture is the single thing
	that fights a cartoony look hardest, and it can only vanish a voxel at a
	time, so a melt read as a hole appearing. Discrete Parts crack, frost, shrink
	and shatter, and it takes terrain writes off the melt path entirely: breaking
	a chunk is now just destroying a Part.

	Two costs come with it, both handled here:

	  * Overdraw. A thousand part-transparent parts stacked is a lot of fill, so
	    only chunks with an exposed face are drawn; the rest sit at Transparency
	    1 until a neighbour dies and uncovers them. Roughly half, and it costs
	    nothing visually because the hidden ones are fully occluded anyway.
	  * Collision. The ice is solid, so melting in is the only way through. That
	    is the game, but note one melted row is chunkSize studs and a character
	    is about 5, so a 4-stud map needs two rows to walk into a tunnel.

	build() is idempotent (AD-3). Running it on a live, half-melted plot restores
	it to fully frozen, so first generation, the re-freeze on player leave and
	the swap to a different map are all the same code path.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))

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
	cell: number, -- grid cell, so the caller can ask what was buried there
}

export type IceField = {
	index: number,
	def: MapDefs.MapDef,
	origin: Vector3,
	folder: Folder,
	chunks: { [BasePart]: Chunk },
	grid: { [number]: Chunk }, -- linear cell index -> chunk, for neighbour lookups
	total: number,
	destroyed: number,
}

local IceField = {}

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

local function inBounds(def: MapDefs.MapDef, gx: number, gy: number, gz: number): boolean
	return gx >= 0
		and gx < def.grid.X
		and gy >= 0
		and gy < def.grid.Y
		and gz >= 0
		and gz < def.grid.Z
end

-- A chunk is worth drawing only if one of its six faces touches something that
-- is not ice: the edge of the block, or a hole melted into it.
local function isExposed(field: IceField, gx: number, gy: number, gz: number): boolean
	for _, face in FACES do
		local nx, ny, nz = gx + face.X, gy + face.Y, gz + face.Z
		if not inBounds(field.def, nx, ny, nz) then
			return true
		end
		if field.grid[GridMath.cellIndex(field.def, nx, ny, nz)] == nil then
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

-- Smooth, deterministic per-cell variation, so a flat wall of identical cubes
-- reads as crystal facets rather than one poured surface.
local function facet(gx: number, gy: number, gz: number): number
	return 1 + math.noise(gx * 0.7, gy * 0.7, gz * 0.7) * Feel.ICE_FACET_JITTER
end

local function paint(field: IceField, chunk: Chunk)
	local stage = Feel.ICE_STAGES[chunk.stage]
	-- Hue comes from the map, the frosting progression from the shared stages,
	-- so each map has its own ice while damage reads identically everywhere.
	local base = field.def.iceColor:Lerp(Color3.new(1, 1, 1), stage.frost)
	local tint = facet(chunk.gx, chunk.gy, chunk.gz)
	chunk.part.Color = Color3.new(
		math.clamp(base.R * tint, 0, 1),
		math.clamp(base.G * tint, 0, 1),
		math.clamp(base.B * tint, 0, 1)
	)
	-- Size is deliberately never touched here. These Parts are the raycast
	-- targets, so resizing a damaged one opens a gap against its neighbours and
	-- a ray aimed near the boundary slips through into the chunk behind.
	chunk.part.Transparency = if chunk.visible then stage.transparency else 1
end

local function setVisible(field: IceField, chunk: Chunk, visible: boolean)
	if chunk.visible == visible then
		return
	end
	chunk.visible = visible
	paint(field, chunk)
end

-- Build, or rebuild, the plot from scratch. Safe to call at any time, including
-- to swap the plot onto a different map.
function IceField.build(field: IceField, def: MapDefs.MapDef?)
	if def then
		field.def = def
	end
	local map = field.def
	local origin = field.origin

	-- Shell -> hollow the chamber. Running both unconditionally is what makes
	-- regeneration idempotent: whatever the player carved out gets overwritten
	-- rather than patched. No ice is filled - the Parts are the ice.
	local shellCenter, shellSize = GridMath.shellBox(map, origin)
	fill(shellCenter, shellSize, map.shellMaterial)

	local chamberCenter, chamberSize = GridMath.chamberBox(map, origin)
	fill(chamberCenter, chamberSize, Enum.Material.Air)

	-- Drop anything that survived the previous run, then lay a fresh grid.
	field.folder:ClearAllChildren()
	table.clear(field.chunks)
	table.clear(field.grid)

	local chunkVector = Vector3.new(map.chunkSize, map.chunkSize, map.chunkSize)
	local built = 0

	for gx = 0, map.grid.X - 1 do
		for gz = 0, map.grid.Z - 1 do
			-- Columns stop at their own height, which gives the block an uneven
			-- top rather than a flat lid.
			for gy = 0, GridMath.columnHeight(map, gx, gz) - 1 do
				local center = GridMath.chunkCenter(map, origin, gx, gy, gz)

				local part = Instance.new("Part")
				part.Name = string.format("C%d_%d_%d", gx, gy, gz)
				part.Size = chunkVector
				part.CFrame = CFrame.new(center)
				part.Anchored = true
				part.CanCollide = true -- melting in is the only way through
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
					hp = map.chunkHp,
					center = center,
					gx = gx,
					gy = gy,
					gz = gz,
					visible = false,
					stage = 1,
				}
				field.chunks[part] = chunk
				field.grid[GridMath.cellIndex(map, gx, gy, gz)] = chunk
				built += 1
			end
		end
	end

	-- Visibility has to be a second pass: whether a cell is exposed depends on
	-- its neighbours, which do not all exist during the first loop.
	for _, chunk in field.chunks do
		chunk.visible = isExposed(field, chunk.gx, chunk.gy, chunk.gz)
		paint(field, chunk)
	end

	field.total = built
	field.destroyed = 0
end

-- Tear the map down and seal the region solid. An unoccupied plot should cost
-- nothing but a folder: with three maps of very different sizes, an idle plot
-- holding a built map is thousands of Parts nobody can see.
function IceField.clear(field: IceField)
	field.folder:ClearAllChildren()
	table.clear(field.chunks)
	table.clear(field.grid)
	field.total = 0
	field.destroyed = 0

	local shellCenter, shellSize = GridMath.shellBox(field.def, field.origin)
	fill(shellCenter, shellSize, field.def.shellMaterial)
end

-- `build` is optional so a plot can exist before it is worth building.
function IceField.new(index: number, def: MapDefs.MapDef, build: boolean?): IceField
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_Ice", index)
	folder.Parent = Workspace

	local field: IceField = {
		index = index,
		def = def,
		origin = GridMath.plotOrigin(index),
		folder = folder,
		chunks = {},
		grid = {},
		total = 0,
		destroyed = 0,
	}

	if build ~= false then
		IceField.build(field)
	end
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

	local map = field.def
	chunk.hp -= amount
	if chunk.hp > 0 then
		local ratio = chunk.hp / map.chunkHp
		local stage = stageFor(ratio)
		if stage ~= chunk.stage then
			chunk.stage = stage
			paint(field, chunk)
		end
		return {
			destroyed = false,
			center = chunk.center,
			hpRatio = ratio,
			cell = GridMath.cellIndex(map, chunk.gx, chunk.gy, chunk.gz),
		}
	end

	local cell = GridMath.cellIndex(map, chunk.gx, chunk.gy, chunk.gz)
	field.chunks[part] = nil
	field.grid[cell] = nil
	part:Destroy()
	field.destroyed += 1

	-- The six cells this one was hiding are surfaces now, so they have to start
	-- drawing. This is what keeps the interior cull honest as the block opens up.
	for _, face in FACES do
		local nx, ny, nz = chunk.gx + face.X, chunk.gy + face.Y, chunk.gz + face.Z
		if inBounds(map, nx, ny, nz) then
			local neighbour = field.grid[GridMath.cellIndex(map, nx, ny, nz)]
			if neighbour then
				setVisible(field, neighbour, true)
			end
		end
	end

	return { destroyed = true, center = chunk.center, hpRatio = 0, cell = cell }
end

-- Which cell a Part belongs to, without touching it. The melt path needs this
-- because an area strike has to be resolved as a whole: damaging the struck
-- chunk first and the area second would break the centre outside the payout
-- path, so it would vanish without being paid for.
function IceField.cellOf(field: IceField, part: BasePart): number?
	local chunk = field.chunks[part]
	if not chunk then
		return nil
	end
	return GridMath.cellIndex(field.def, chunk.gx, chunk.gy, chunk.gz)
end

-- Same as damage(), addressed by grid cell instead of by Part. Area tools work
-- outward from a cell, and only the struck chunk is known as a Part.
function IceField.damageCell(field: IceField, cell: number, amount: number): DamageResult?
	local chunk = field.grid[cell]
	if not chunk then
		return nil
	end
	return IceField.damage(field, chunk.part, amount)
end

-- Is this cell solid ice right now? Used when scattering finds, which may only
-- claim cells that actually exist.
function IceField.occupied(field: IceField, cell: number): boolean
	return field.grid[cell] ~= nil
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
