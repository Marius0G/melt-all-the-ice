--!strict
--[[
	Discoveries - the things frozen inside the ice, and uncovering them.

	This is the hook the design doc is actually built around: "in timp ce o
	dezgheti, vor [aparea] diferite chestii in gheata gen oase de dinozauri,
	mamuti, oameni inghetati". Melting is the verb; finding is the reason.

	How it works: each prop claims the block of grid cells its bounding box
	covers, and every claimed cell points back at it. When a chunk is destroyed
	the prop it belonged to loses one, and the chunk that takes the count to zero
	is the one that uncovers it. So the reveal lands on the exact swing that
	frees the last of the ice over it, rather than on a proximity check that
	would fire early or a sweep that would fire late.

	Placement is re-rolled on every build rather than being fixed. AD-3 asks that
	a cleared plot can be rebuilt into a playable frozen one, not that it be
	byte-identical - and a map that hides its finds somewhere new is worth
	replaying, while one that does not is a checklist.

	Two properties on the prop parts are load-bearing:

	  * CanQuery = false, or a buried prop swallows the melt raycast and the
	    chunks in front of it become unbreakable.
	  * CanCollide = false until revealed, so a prop encased in ice cannot trap
	    a player who melts a tunnel alongside it.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local PropAssets = require(Shared:WaitForChild("PropAssets"))

export type Buried = {
	def: PropAssets.PropDef,
	part: BasePart,
	hint: Attachment?,
	remaining: number,
	revealed: boolean,
}

export type Field = {
	folder: Folder,
	byCell: { [number]: Buried },
	all: { Buried },
	found: number,
}

local Discoveries = {}

local PLACEMENT_ATTEMPTS = 60

-- Meshes are fetched once and cloned per placement. CreateMeshPartAsync yields
-- and hits the asset service, so calling it per prop per plot would stall the
-- build for six plots worth of network round trips.
local templates: { [string]: BasePart } = {}

local function template(def: PropAssets.PropDef): BasePart?
	local existing = templates[def.key]
	if existing then
		return existing
	end

	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(def.meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Performance,
		})
	end)
	if not ok or not part then
		warn(string.format("[MeltAllTheIce] could not load prop %s: %s", def.key, tostring(part)))
		return nil
	end

	local mesh = part :: MeshPart
	-- FBX arrives in centimetres, so every mesh is 100x too big. Size is
	-- writable and rescales the mesh, so the authored dimensions win.
	mesh.Size = def.size
	mesh.Color = def.color
	mesh.Material = def.material
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	mesh.Parent = nil

	templates[def.key] = mesh
	return mesh
end

-- How many cells the prop spans on each axis, at least one. Depends on the
-- map, since a prop that fills two cells on a 4-stud grid fills one on an
-- 8-stud grid.
local function footprint(prop: PropAssets.PropDef, map: MapDefs.MapDef): (number, number, number)
	local size = prop.size
	return math.max(1, math.ceil(size.X / map.chunkSize)),
		math.max(1, math.ceil(size.Y / map.chunkSize)),
		math.max(1, math.ceil(size.Z / map.chunkSize))
end

local function makeHint(position: Vector3, parent: Instance): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = parent

	-- Slow and sparse. This says "something is under here" without saying what,
	-- and has to stay readable against blue ice, hence the warm colour.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Feel.TEXTURES.SPARKLE
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, 2.5, 0)
	emitter.LightEmission = 0.9
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(PropAssets.HINT_COLOR)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return attachment
end

-- Fetch every prop mesh up front, concurrently.
--
-- CreateMeshPartAsync yields on a network round trip. Doing them lazily, one at
-- a time, during the first plot build cost four seconds of dead server start -
-- all of it spent waiting rather than working. Fired together it is one round
-- trip deep instead of seven.
function Discoveries.preload()
	local total = #PropAssets.DEFS
	if total == 0 then
		return
	end
	local completed = 0
	local signal = Instance.new("BindableEvent")
	for _, def in PropAssets.DEFS do
		task.spawn(function()
			template(def)
			completed += 1
			if completed == total then
				signal:Fire()
			end
		end)
	end
	if completed < total then
		signal.Event:Wait()
	end
	signal:Destroy()
end

function Discoveries.new(index: number): Field
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_Finds", index)
	folder.Parent = Workspace
	return { folder = folder, byCell = {}, all = {}, found = 0 }
end

-- Lay out a fresh set of finds. Called from IceField.build, after the grid
-- exists, so placement can check which cells are actually solid ice.
function Discoveries.populate(
	field: Field,
	map: MapDefs.MapDef,
	origin: Vector3,
	occupied: (number) -> boolean
)
	field.folder:ClearAllChildren()
	table.clear(field.byCell)
	table.clear(field.all)
	field.found = 0

	local rng = Random.new()
	local claimed: { [number]: boolean } = {}

	for _, entry in map.props do
		local def = PropAssets.get(entry.key)
		if not def then
			continue
		end
		local source = template(def)
		if not source then
			continue
		end

		local spanX, spanY, spanZ = footprint(def, map)

		for _ = 1, entry.count do
			local placedCells: { number }? = nil
			local originCell: (Vector3)? = nil

			for _ = 1, PLACEMENT_ATTEMPTS do
				local gx = rng:NextInteger(0, map.grid.X - spanX)
				local gz = rng:NextInteger(0, map.grid.Z - spanZ)
				local gy = rng:NextInteger(0, map.grid.Y - spanY)

				local cells = {}
				local ok = true
				for dx = 0, spanX - 1 do
					for dy = 0, spanY - 1 do
						for dz = 0, spanZ - 1 do
							local cell = GridMath.cellIndex(map, gx + dx, gy + dy, gz + dz)
							-- Must be solid ice and not already spoken for, or
							-- two props would share a cell and the second could
							-- never reach zero.
							if claimed[cell] or not occupied(cell) then
								ok = false
								break
							end
							table.insert(cells, cell)
						end
						if not ok then
							break
						end
					end
					if not ok then
						break
					end
				end

				if ok and #cells > 0 then
					placedCells = cells
					originCell = Vector3.new(gx, gy, gz)
					break
				end
			end

			if placedCells and originCell then
				local part = source:Clone()
				part.Name = def.key -- so a plot folder is readable when inspected
				local base = originCell :: Vector3
				-- Centre of the claimed block of cells.
				local centre = GridMath.chunkCenter(map, origin, base.X, base.Y, base.Z)
					+ Vector3.new(spanX - 1, spanY - 1, spanZ - 1) * (map.chunkSize * 0.5)
				part.CFrame = CFrame.new(centre) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
				part.Parent = field.folder

				local buried: Buried = {
					def = def,
					part = part,
					hint = nil,
					remaining = #(placedCells :: { number }),
					revealed = false,
				}

				for _, cell in placedCells :: { number } do
					claimed[cell] = true
					field.byCell[cell] = buried
				end

				-- Hint sits on the ice surface directly above the find, so the
				-- player can spot it before committing a minute to digging.
				local surfaceY = GridMath.columnHeight(map, base.X, base.Z) * map.chunkSize
				buried.hint = makeHint(
					Vector3.new(centre.X, origin.Y + surfaceY + 0.6, centre.Z),
					field.folder
				)

				table.insert(field.all, buried)
			end
		end
	end
end

-- A chunk was destroyed. Returns the find it uncovered, if that was the last
-- piece of ice over it.
function Discoveries.onCellCleared(field: Field, cell: number): Buried?
	local buried = field.byCell[cell]
	if not buried or buried.revealed then
		return nil
	end

	buried.remaining -= 1
	if buried.remaining > 0 then
		return nil
	end

	buried.revealed = true
	field.found += 1

	if buried.hint then
		(buried.hint :: Attachment):Destroy()
		buried.hint = nil
	end

	-- Now that it is free of the ice, it becomes solid and can be stood on.
	buried.part.CanCollide = true

	-- Pop in rather than simply existing. The reveal is a separate beat from the
	-- shatter that caused it, so it needs its own motion.
	local final = buried.def.size
	buried.part.Size = final * 0.55
	TweenService
		:Create(buried.part, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = final,
		})
		:Play()

	return buried
end

function Discoveries.total(field: Field): number
	return #field.all
end

function Discoveries.clear(field: Field)
	field.folder:ClearAllChildren()
	table.clear(field.byCell)
	table.clear(field.all)
	field.found = 0
end

return Discoveries
