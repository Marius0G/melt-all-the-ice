--!strict
--[[
	SetPieces - the architecture each map is built around (AD-7).

	The design doc does not describe three ice blocks. It describes starting in a
	town beside a pyramid and working toward it, and a Parthenon and a horse at
	Troy. Those are the things the maps are *about*, so they are placed on the
	ice footprint and built taller than the ice: the top stands clear from the
	moment you spawn, so there is something to work toward, and the bulk is
	encased, so clearing the map is what uncovers it.

	These are Blender meshes now (assets/blender/structures.py, ids in
	StructureAssets). The Parthenon alone was fifty-four Parts positioned by
	arithmetic and is one mesh with real fluted columns and a proper gable.

	Three rules this module has to obey, all learned from how the rest of the
	plot is wired:

	  * These parts must never be parented into the ice folder. MeltService
	    raycasts with an Include filter scoped to exactly that folder, so
	    anything living there becomes a melt target, fails IceField.cellOf, and
	    silently swallows swings - and IceField.build clears that folder anyway.
	    They get their own, which also means CanQuery cannot bite us. It is set
	    false regardless, matching props, glow anchors and shards.
	  * The folder is cleared at the head of every build and again on release.
	    IceField.clear refills the whole shell solid with terrain, so anything
	    left behind ends up entombed on an idle plot and then reappears inside
	    whatever map the next player loads.
	  * Everything here exists once per plot, so six times over.

	Landmarks report the volume they occupy, so buried finds are not scattered
	inside solid stone where nothing could ever uncover them.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local PropAssets = require(Shared:WaitForChild("PropAssets"))
local StructureAssets = require(Shared:WaitForChild("StructureAssets"))

export type Solid = {
	min: Vector3,
	max: Vector3,
}

export type Field = {
	folder: Folder,
	solids: { Solid },
}

local SetPieces = {}

local BEACON_ATTRIBUTE = "Beacon"

local templates: { [string]: BasePart } = {}

local function loadMesh(meshId: string, fidelity: Enum.CollisionFidelity): BasePart?
	local existing = templates[meshId]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = fidelity,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok or not result then
		warn(string.format("[MeltAllTheIce] could not load structure mesh %s: %s", meshId, tostring(result)))
		return nil
	end
	local mesh = result :: MeshPart
	mesh.Parent = nil
	templates[meshId] = mesh
	return mesh
end

-- Fetch every structure mesh up front, concurrently. Same reason as the props
-- and the tools: lazily, one at a time, this is seconds of dead server start.
function SetPieces.preload()
	local wanted: { { id: string, fidelity: Enum.CollisionFidelity } } = {}
	for key, def in StructureAssets.MODELS do
		-- The pyramid really is convex, so a hull is both correct and cheap.
		-- Everything else is close enough to its own bounding box.
		local fidelity = if key == "pyramid"
			then Enum.CollisionFidelity.Hull
			elseif key == "parthenon" then Enum.CollisionFidelity.Default
			else Enum.CollisionFidelity.Box
		table.insert(wanted, { id = def.meshId, fidelity = fidelity })
	end
	-- The Trojan horse is a find mesh reused at landmark scale.
	local horse = PropAssets.get("TrojanHorse")
	if horse then
		table.insert(wanted, { id = horse.meshId, fidelity = Enum.CollisionFidelity.Hull })
	end
	local spike = PropAssets.get("Stalagmite")
	if spike then
		table.insert(wanted, { id = spike.meshId, fidelity = Enum.CollisionFidelity.Box })
	end

	if #wanted == 0 then
		return
	end
	local completed = 0
	local signal = Instance.new("BindableEvent")
	for _, entry in wanted do
		task.spawn(function()
			loadMesh(entry.id, entry.fidelity)
			completed += 1
			if completed == #wanted then
				signal:Fire()
			end
		end)
	end
	if completed < #wanted then
		signal.Event:Wait()
	end
	signal:Destroy()
end

local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- Place a mesh with its base sitting on `floor`. Every structure is modelled
-- standing on its own base, so this is the only placement rule needed.
local function place(
	field: Field,
	meshId: string,
	name: string,
	size: Vector3,
	footing: Vector3,
	color: Color3,
	material: Enum.Material,
	rotation: number?
): BasePart?
	local template = templates[meshId]
	if not template then
		return nil
	end
	local part = template:Clone()
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(footing + Vector3.new(0, size.Y / 2, 0))
		* CFrame.Angles(0, rotation or 0, 0)
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = field.folder
	return part
end

-- A plain Part, for the few things that cannot be a mesh - chiefly the beacon,
-- which the finale has to swap to Neon and hang a light on.
local function block(
	field: Field,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = field.folder
	return part
end

local function markBeacon(part: BasePart)
	part:SetAttribute(BEACON_ATTRIBUTE, true)
end

local function addSolid(field: Field, centre: Vector3, size: Vector3)
	table.insert(field.solids, { min = centre - size / 2, max = centre + size / 2 })
end

-- The dais the player materialises on, so the spawn is not a bare grey square.
local function placeSpawnPad(field: Field, map: MapDefs.MapDef, origin: Vector3, stone: Color3)
	local def = StructureAssets.get("spawnpad")
	if not def then
		return
	end
	place(
		field,
		def.meshId,
		"SpawnPad",
		def.size,
		GridMath.spawnPosition(map, origin),
		shade(stone, -0.15),
		Enum.Material.Slate
	)
end

-- Small houses along the walkway ring, which is the only floor not under ice.
local function placeHuts(field: Field, map: MapDefs.MapDef, origin: Vector3, count: number, stone: Color3)
	local def = StructureAssets.get("hut")
	if not def then
		return
	end
	local ice = GridMath.iceSize(map)
	for index = 0, count - 1 do
		local t = (index + 0.5) / count
		local z = ice.Z * t
		-- Leave the middle of the strip clear for the spawn pad and its light.
		if math.abs(z - ice.Z / 2) < 16 then
			continue
		end
		local scale = 0.85 + (index % 3) * 0.18
		local x = -map.walkway * (0.34 + (index % 2) * 0.3)
		place(
			field,
			def.meshId,
			"Hut",
			def.size * scale,
			origin + Vector3.new(x, 0, z),
			shade(stone, (index % 2) * 0.08 - 0.04),
			Enum.Material.Sandstone,
			math.rad((index % 4) * 90)
		)
	end
end

-- ---------------------------------------------------------------------------
-- cave
-- ---------------------------------------------------------------------------

local function buildCave(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local stone = map.rockColor

	placeSpawnPad(field, map, origin, stone)

	-- The fire ring from the end-state reference, on the -X strip well clear of
	-- the spawn pad and the fill light directly above it.
	local hearth = origin + Vector3.new(-map.walkway * 0.5, 0, ice.Z * 0.2)
	local fire = StructureAssets.get("campfire")
	if fire then
		place(field, fire.meshId, "Hearth", fire.size, hearth, shade(stone, -0.2), Enum.Material.Slate)
	end

	-- Dark until the finale lights it.
	local embers = block(
		field,
		"Campfire",
		Vector3.new(2.0, 1.1, 2.0),
		hearth + Vector3.new(0, 1.4, 0),
		Color3.fromRGB(58, 44, 36),
		Enum.Material.Slate
	)
	markBeacon(embers)

	-- A stand of stalagmites in the far corner, reusing the find mesh so the
	-- cave has something in it besides the ice.
	local spike = PropAssets.get("Stalagmite")
	if spike then
		local corner = origin + Vector3.new(ice.X + map.walkway * 0.45, 0, ice.Z + map.walkway * 0.45)
		for index = 0, 4 do
			local scale = 0.9 + (index % 3) * 0.55
			local offset = Vector3.new(math.cos(index * 1.3) * 4.0, 0, math.sin(index * 1.3) * 4.0)
			place(
				field,
				spike.meshId,
				"Stalagmite",
				spike.size * scale,
				corner + offset,
				shade(stone, 0.12),
				Enum.Material.Slate,
				index * 1.1
			)
		end
	end
end

-- ---------------------------------------------------------------------------
-- pyramid
-- ---------------------------------------------------------------------------

local function buildPyramid(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local sand = map.rockColor
	local centre = origin + Vector3.new(ice.X / 2, 0, ice.Z / 2)

	placeSpawnPad(field, map, origin, sand)

	local def = StructureAssets.get("pyramid")
	if def then
		place(field, def.meshId, "GreatPyramid", def.size, centre, sand, Enum.Material.Sandstone)

		-- The capstone is the beacon, so it stays a Part the finale can light.
		local apex = def.size.Y
		local capstone = block(
			field,
			"Capstone",
			Vector3.new(8, 8, 8),
			centre + Vector3.new(0, apex + 4, 0),
			shade(sand, 0.25),
			Enum.Material.Sandstone
		)
		markBeacon(capstone)

		-- Finds must not land inside the stonework, where nothing could ever
		-- uncover them.
		addSolid(field, centre + Vector3.new(0, (apex + 8) / 2, 0),
			Vector3.new(def.size.X, apex + 8, def.size.Z))
	end

	-- The approach the reference image is built around, breaking around the
	-- spawn pad rather than running through it - the pad is the town square.
	local road = StructureAssets.get("causeway")
	if road then
		for index = 0, 5 do
			local z = ice.Z / 2 - 45 + index * 18
			if math.abs(z - ice.Z / 2) < 24 then
				continue
			end
			place(
				field,
				road.meshId,
				"Causeway",
				road.size,
				origin + Vector3.new(-map.walkway * 0.5, 0, z),
				shade(sand, -0.12),
				Enum.Material.Sandstone
			)
		end
	end

	placeHuts(field, map, origin, 9, sand)
end

-- ---------------------------------------------------------------------------
-- troy
-- ---------------------------------------------------------------------------

local function buildTroy(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local marble = map.rockColor
	local centre = origin + Vector3.new(ice.X / 2, 0, ice.Z / 2)

	placeSpawnPad(field, map, origin, marble)

	-- The Parthenon sits on the Acropolis, and that is also what lifts it clear
	-- of forty studs of ice without making the building itself absurdly tall.
	-- Squashed to 14: at its authored 18 the roof ornament ended up above the
	-- chamber ceiling and buried in the shell.
	local plinthHeight = 14
	local plinth = StructureAssets.get("acropolis")
	if plinth then
		place(
			field,
			plinth.meshId,
			"Acropolis",
			Vector3.new(plinth.size.X, plinthHeight, plinth.size.Z),
			centre,
			shade(marble, -0.2),
			Enum.Material.Limestone
		)
	end

	local temple = StructureAssets.get("parthenon")
	if temple then
		place(
			field,
			temple.meshId,
			"Parthenon",
			temple.size,
			centre + Vector3.new(0, plinthHeight, 0),
			marble,
			Enum.Material.Marble
		)

		local roof = plinthHeight + temple.size.Y
		local acroterion = block(
			field,
			"Acroterion",
			Vector3.new(5, 5, 5),
			centre + Vector3.new(0, roof + 2.5, 0),
			shade(marble, 0.15),
			Enum.Material.Marble
		)
		markBeacon(acroterion)

		addSolid(field, centre + Vector3.new(0, (roof + 5) / 2, 0),
			Vector3.new(plinth and plinth.size.X or 104, roof + 5, plinth and plinth.size.Z or 104))
	end

	-- The horse itself, at landmark scale rather than the buried find's size.
	local horse = PropAssets.get("TrojanHorse")
	if horse then
		place(
			field,
			horse.meshId,
			"TrojanHorse",
			horse.size * 2.6,
			origin + Vector3.new(-map.walkway * 0.45, 0, ice.Z * 0.28),
			Color3.fromRGB(118, 80, 44),
			Enum.Material.WoodPlanks,
			math.rad(-90)
		)
	end

	placeHuts(field, map, origin, 7, shade(marble, -0.25))
end

-- ---------------------------------------------------------------------------
-- lifecycle
-- ---------------------------------------------------------------------------

local BUILDERS: { [string]: (Field, MapDefs.MapDef, Vector3) -> () } = {
	cave = buildCave,
	pyramid = buildPyramid,
	troy = buildTroy,
}

function SetPieces.new(index: number): Field
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_SetPieces", index)
	folder.Parent = Workspace
	return { folder = folder, solids = {} }
end

function SetPieces.build(field: Field, map: MapDefs.MapDef, origin: Vector3)
	SetPieces.clear(field)
	local builder = BUILDERS[map.id]
	if builder then
		builder(field, map, origin)
	end
end

function SetPieces.clear(field: Field)
	field.folder:ClearAllChildren()
	table.clear(field.solids)
end

-- Is this point inside a landmark? Used to keep buried finds out of solid
-- stonework, where melting the ice around them would reveal nothing.
function SetPieces.blocks(field: Field, position: Vector3): boolean
	for _, solid in field.solids do
		if
			position.X >= solid.min.X
			and position.X <= solid.max.X
			and position.Y >= solid.min.Y
			and position.Y <= solid.max.Y
			and position.Z >= solid.min.Z
			and position.Z <= solid.max.Z
		then
			return true
		end
	end
	return false
end

-- The Part the finale lights, if this map has one.
function SetPieces.beacon(field: Field): BasePart?
	for _, child in field.folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute(BEACON_ATTRIBUTE) == true then
			return child
		end
	end
	return nil
end

return SetPieces
