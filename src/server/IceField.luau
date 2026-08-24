--!strict
--[[
	IceField - one plot's worth of meltable ice (AD-1).

	The authoritative unit is a chunk Part on a 4-stud grid, each carrying HP.
	Terrain Ice fills the same volume as the purely visual layer; the Parts are
	invisible and non-collidable, and exist only to be raycast against and to
	hold HP. Melting a chunk clears its voxel to Air and destroys the Part, so
	progress is just destroyed/total - exact, and cheap enough to read every
	hit without ever inspecting voxels.

	build() is idempotent (AD-3). Running it on a live, half-melted plot
	restores it to fully frozen, so first generation and the re-freeze on
	player leave are the same code path rather than a retrofitted reset.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GridMath = require(Shared:WaitForChild("GridMath"))

export type Chunk = {
	part: BasePart,
	hp: number,
	center: Vector3,
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
	total: number,
	destroyed: number,
}

local IceField = {}

local CHUNK_VECTOR = Vector3.new(Config.CHUNK_SIZE, Config.CHUNK_SIZE, Config.CHUNK_SIZE)

local function fill(center: Vector3, size: Vector3, material: Enum.Material)
	Workspace.Terrain:FillBlock(CFrame.new(center), size, material)
end

-- Build, or rebuild, the plot from scratch. Safe to call at any time.
function IceField.build(field: IceField)
	-- Rock shell -> hollow the chamber -> refill the ice. Running all three
	-- unconditionally is exactly what makes regeneration idempotent: whatever
	-- the player carved out gets overwritten rather than patched.
	local rockCenter, rockSize = GridMath.rockBox(field.origin)
	fill(rockCenter, rockSize, Enum.Material.Rock)

	local chamberCenter, chamberSize = GridMath.chamberBox(field.origin)
	fill(chamberCenter, chamberSize, Enum.Material.Air)

	local iceCenter, iceSize = GridMath.iceBox(field.origin)
	fill(iceCenter, iceSize, Enum.Material.Ice)

	-- Drop any chunks that survived the previous run, then lay a fresh grid.
	field.folder:ClearAllChildren()
	table.clear(field.chunks)

	for gx = 0, Config.GRID_X - 1 do
		for gy = 0, Config.GRID_Y - 1 do
			for gz = 0, Config.GRID_Z - 1 do
				local center = GridMath.chunkCenter(field.origin, gx, gy, gz)

				local part = Instance.new("Part")
				part.Name = string.format("C%d_%d_%d", gx, gy, gz)
				part.Size = CHUNK_VECTOR
				part.CFrame = CFrame.new(center)
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CastShadow = false
				part.Transparency = 1
				part.Parent = field.folder

				field.chunks[part] = { part = part, hp = Config.CHUNK_HP, center = center }
			end
		end
	end

	field.total = GridMath.chunkCount()
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
		total = 0,
		destroyed = 0,
	}

	IceField.build(field)
	return field
end

-- Apply damage to the chunk backing `part`. Returns nil when `part` is not a
-- live chunk of this field; otherwise a result describing what the hit did.
-- `destroyed` is the caller's cue to pay out.
--
-- The caller needs more than a yes/no: the client has to draw a different
-- effect for a chip than for a shatter, and it cannot be trusted to work that
-- out for itself.
function IceField.damage(field: IceField, part: BasePart, amount: number): DamageResult?
	local chunk = field.chunks[part]
	if not chunk then
		return nil
	end

	chunk.hp -= amount
	if chunk.hp > 0 then
		return {
			destroyed = false,
			center = chunk.center,
			hpRatio = chunk.hp / Config.CHUNK_HP,
		}
	end

	-- Visual layer first, then the authoritative one.
	fill(chunk.center, CHUNK_VECTOR, Enum.Material.Air)
	field.chunks[part] = nil
	part:Destroy()
	field.destroyed += 1
	return { destroyed = true, center = chunk.center, hpRatio = 0 }
end

-- Fraction thawed, 0..1.
function IceField.progress(field: IceField): number
	if field.total == 0 then
		return 0
	end
	return field.destroyed / field.total
end

return IceField
