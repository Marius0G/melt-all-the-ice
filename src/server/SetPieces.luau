--!strict
--[[
	SetPieces - the architecture each map is built around (AD-7).

	The design doc does not describe three ice blocks. It describes starting in a
	town beside a pyramid and working toward it, and a Parthenon and a horse at
	Troy. Those are the things the maps are *about*, so they are built here as
	static Parts and placed on the ice footprint, taller than the ice: the top
	stands clear from the moment you spawn, so there is something to work toward,
	and the bulk is encased, so clearing the map is what uncovers it.

	Three rules this module has to obey, all of them learned the hard way from
	how the rest of the plot is wired:

	  * These Parts must never be parented into the ice folder. MeltService
	    raycasts with an Include filter scoped to exactly that folder, so anything
	    living there becomes a melt target, fails IceField.cellOf, and silently
	    swallows swings - and IceField.build clears that folder anyway. They get
	    their own, which also means CanQuery cannot bite us. It is set false
	    regardless, matching props, glow anchors and shards.
	  * The folder is cleared at the head of every build and again on release.
	    IceField.clear refills the whole shell solid with terrain, so anything
	    left behind ends up entombed on an idle plot and then reappears inside
	    whatever map the next player loads.
	  * Every Part here exists once per plot, so six times over. The budgets are
	    deliberately small: tens of Parts per map, not hundreds.

	Landmarks also report the volume they occupy, so buried finds can avoid being
	scattered inside solid stone where nothing could ever uncover them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))

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

-- Static architecture wants different defaults from tool parts: anchored and
-- solid, never a query target, never casting shadows (nothing else in the
-- chamber does, and these are the largest things in it).
local function piece(
	folder: Folder,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

-- The one Part the finale lights. Exactly one per map.
local function markBeacon(part: Part)
	part:SetAttribute(BEACON_ATTRIBUTE, true)
end

local function addSolid(field: Field, centre: Vector3, size: Vector3)
	table.insert(field.solids, {
		min = centre - size / 2,
		max = centre + size / 2,
	})
end

local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- ---------------------------------------------------------------------------
-- shared dressing
-- ---------------------------------------------------------------------------

-- A cluster of small huts, used for the town beside the pyramid and the agora
-- at Troy. Placed in the walkway ring, which is the only floor not under ice.
local function buildHuts(field: Field, map: MapDefs.MapDef, origin: Vector3, count: number, stone: Color3)
	local ice = GridMath.iceSize(map)
	local strip = map.walkway
	local roof = shade(stone, -0.35)

	for index = 0, count - 1 do
		-- Spread along the -X strip, skipping the middle where the spawn pad and
		-- its light sit.
		local t = (index + 0.5) / count
		local z = ice.Z * t
		local nearSpawn = math.abs(z - ice.Z / 2) < 14
		if nearSpawn then
			continue
		end

		local width = 7 + (index % 3) * 2
		local height = 6 + (index % 2) * 2
		local x = -strip * (0.35 + (index % 2) * 0.28)
		local base = origin + Vector3.new(x, 0, z)

		piece(
			field.folder,
			"Hut",
			Vector3.new(width, height, width),
			CFrame.new(base + Vector3.new(0, height / 2, 0)),
			stone,
			Enum.Material.Sandstone
		)
		piece(
			field.folder,
			"HutRoof",
			Vector3.new(width + 1.5, 1.2, width + 1.5),
			CFrame.new(base + Vector3.new(0, height + 0.6, 0)),
			roof,
			Enum.Material.WoodPlanks
		)
	end
end

-- ---------------------------------------------------------------------------
-- cave
-- ---------------------------------------------------------------------------

-- No landmark - it is a cave. What it gets is the dressing from the real end
-- state reference: a fire ring on the floor and a stand of stalagmites. The
-- campfire is the map's beacon, unlit until the ice is gone.
local function buildCave(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local stone = map.rockColor

	-- The cave walkway is only 12 studs and the spawn pad already occupies the
	-- middle of the -X strip, so the fire goes along the same strip well clear
	-- of the pad and of the fill light directly above it.
	local hearth = origin + Vector3.new(-map.walkway * 0.5, 0, ice.Z * 0.18)

	for index = 0, 7 do
		local angle = index * (math.pi * 2 / 8)
		piece(
			field.folder,
			"FireStone",
			Vector3.new(1.6, 1.1, 1.6),
			CFrame.new(hearth + Vector3.new(math.cos(angle) * 2.6, 0.55, math.sin(angle) * 2.6))
				* CFrame.Angles(0, angle, 0),
			shade(stone, -0.2),
			Enum.Material.Slate
		)
	end

	for index = 0, 3 do
		local angle = index * (math.pi / 2) + 0.4
		piece(
			field.folder,
			"Log",
			Vector3.new(3.4, 0.7, 0.7),
			CFrame.new(hearth + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, angle, math.rad(14)),
			Color3.fromRGB(96, 66, 38),
			Enum.Material.Wood
		)
	end

	-- Dark until the finale lights it.
	local embers = piece(
		field.folder,
		"Campfire",
		Vector3.new(2.2, 1.2, 2.2),
		CFrame.new(hearth + Vector3.new(0, 1.3, 0)),
		Color3.fromRGB(58, 44, 36),
		Enum.Material.Slate
	)
	markBeacon(embers)

	-- A stand of stalagmites in the far corner, so the room has something in it
	-- other than the ice.
	local corner = origin + Vector3.new(ice.X + map.walkway * 0.5, 0, ice.Z + map.walkway * 0.5)
	for index = 0, 4 do
		local height = 6 + (index % 3) * 3
		local offset = Vector3.new(math.cos(index * 1.3) * 3.5, height / 2, math.sin(index * 1.3) * 3.5)
		piece(
			field.folder,
			"Stalagmite",
			Vector3.new(2.2 - (index % 2) * 0.6, height, 2.2 - (index % 2) * 0.6),
			CFrame.new(corner + offset),
			shade(stone, 0.1),
			Enum.Material.Slate
		)
	end
end

-- ---------------------------------------------------------------------------
-- pyramid
-- ---------------------------------------------------------------------------

local function buildPyramid(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local sand = map.rockColor
	local centre = origin + Vector3.new(ice.X / 2, 0, ice.Z / 2)

	-- Has to clear the ice (top 40) and stay under the chamber ceiling (64), or
	-- the apex ends up buried in the shell where nobody can see it. Courses
	-- reach 48 and the capstone tops out at 56: sixteen studs of pyramid above
	-- the ice, eight studs of air above that.
	local base = 128
	local steps = 12
	local stepHeight = 4

	for index = 0, steps - 1 do
		local shrink = index / steps
		local width = base * (1 - shrink * 0.92)
		piece(
			field.folder,
			string.format("Course%d", index),
			Vector3.new(width, stepHeight, width),
			CFrame.new(centre + Vector3.new(0, index * stepHeight + stepHeight / 2, 0)),
			shade(sand, (index % 2) * 0.06),
			Enum.Material.Sandstone
		)
	end

	local apexY = steps * stepHeight
	local capstone = piece(
		field.folder,
		"Capstone",
		Vector3.new(8, 8, 8),
		CFrame.new(centre + Vector3.new(0, apexY + 4, 0)),
		shade(sand, 0.25),
		Enum.Material.Sandstone
	)
	markBeacon(capstone)

	-- Finds must not be scattered inside the stonework, where nothing could ever
	-- uncover them.
	addSolid(field, centre + Vector3.new(0, apexY / 2, 0), Vector3.new(base, apexY + 8, base))

	-- A causeway running the length of the town, which is the approach the
	-- reference image is built around. It breaks around the spawn pad rather
	-- than through it - the pad is the town square.
	for index = 0, 5 do
		local z = ice.Z / 2 - 45 + index * 18
		if math.abs(z - ice.Z / 2) < 22 then
			continue
		end
		piece(
			field.folder,
			"Causeway",
			Vector3.new(14, 1.5, 18),
			CFrame.new(origin + Vector3.new(-map.walkway * 0.5, 0.75, z)),
			shade(sand, -0.1),
			Enum.Material.Sandstone
		)
	end

	buildHuts(field, map, origin, 9, sand)
end

-- ---------------------------------------------------------------------------
-- troy
-- ---------------------------------------------------------------------------

local function buildTroy(field: Field, map: MapDefs.MapDef, origin: Vector3)
	local ice = GridMath.iceSize(map)
	local marble = map.rockColor
	local centre = origin + Vector3.new(ice.X / 2, 0, ice.Z / 2)

	-- The Parthenon sits on the Acropolis, and that is also what lifts it clear
	-- of 40 studs of ice without making the building itself absurdly tall.
	--
	-- 18, not 26: at 26 the acroterion topped out at 69 against a 68 ceiling and
	-- the roof was buried in the shell. This puts the apex around 61 - twenty
	-- studs of temple above the ice, with headroom to spare.
	local plinthTop = 18
	for index = 0, 2 do
		local width = 104 - index * 8
		piece(
			field.folder,
			string.format("Acropolis%d", index),
			Vector3.new(width, plinthTop / 3, width),
			CFrame.new(centre + Vector3.new(0, index * (plinthTop / 3) + plinthTop / 6, 0)),
			shade(marble, -0.18 + index * 0.05),
			Enum.Material.Limestone
		)
	end

	-- Stepped crepidoma.
	local length, depth = 72, 34
	for index = 0, 2 do
		piece(
			field.folder,
			string.format("Step%d", index),
			Vector3.new(length + 6 - index * 3, 1.6, depth + 6 - index * 3),
			CFrame.new(centre + Vector3.new(0, plinthTop + index * 1.6 + 0.8, 0)),
			marble,
			Enum.Material.Marble
		)
	end

	local floorY = plinthTop + 4.8
	local columnHeight = 17

	-- Peristyle: a colonnade all the way round, corners shared.
	local acrossCount, alongCount = 6, 11
	local acrossGap = (length - 10) / (acrossCount - 1)
	local alongGap = (depth - 10) / (alongCount - 1)
	for ax = 0, acrossCount - 1 do
		for az = 0, alongCount - 1 do
			local edge = ax == 0 or ax == acrossCount - 1 or az == 0 or az == alongCount - 1
			if not edge then
				continue
			end
			local x = -(length - 10) / 2 + ax * acrossGap
			local z = -(depth - 10) / 2 + az * alongGap
			piece(
				field.folder,
				"Column",
				Vector3.new(3.4, columnHeight, 3.4),
				CFrame.new(centre + Vector3.new(x, floorY + columnHeight / 2, z)),
				marble,
				Enum.Material.Marble
			)
		end
	end

	local entabY = floorY + columnHeight
	piece(
		field.folder,
		"Architrave",
		Vector3.new(length, 3, depth),
		CFrame.new(centre + Vector3.new(0, entabY + 1.5, 0)),
		marble,
		Enum.Material.Marble
	)
	-- The painted frieze is the one bit of colour on the whole building.
	piece(
		field.folder,
		"Frieze",
		Vector3.new(length + 1, 2.4, depth + 1),
		CFrame.new(centre + Vector3.new(0, entabY + 4.2, 0)),
		Color3.fromRGB(72, 96, 150),
		Enum.Material.Marble
	)

	-- Stepped gable rather than a wedge: it reads as a pediment at this scale
	-- and cannot be mis-oriented.
	for index = 0, 2 do
		piece(
			field.folder,
			string.format("Pediment%d", index),
			Vector3.new(length - index * 18, 2.6, depth + 1),
			CFrame.new(centre + Vector3.new(0, entabY + 6.7 + index * 2.6, 0)),
			shade(marble, 0.05),
			Enum.Material.Marble
		)
	end

	local roofY = entabY + 6.7 + 3 * 2.6
	local beacon = piece(
		field.folder,
		"Acroterion",
		Vector3.new(7, 7, 7),
		CFrame.new(centre + Vector3.new(0, roofY + 3.5, 0)),
		shade(marble, 0.15),
		Enum.Material.Marble
	)
	markBeacon(beacon)

	addSolid(field, centre + Vector3.new(0, (roofY + 7) / 2, 0), Vector3.new(110, roofY + 7, 110))

	buildHuts(field, map, origin, 7, shade(marble, -0.25))
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
