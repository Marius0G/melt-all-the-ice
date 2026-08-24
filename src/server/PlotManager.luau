--!strict
--[[
	PlotManager - the plot pool (AD-2), and which map each plot is currently
	hosting (AD-5).

	Terrain is a single global singleton in Roblox, so per-player worlds have to
	be done spatially: PLOT_COUNT regions spaced PLOT_SPACING apart, one handed
	to each player on join. Regions never overlap, so terrain writes never
	collide, and StreamingEnabled keeps one player's map off every other
	player's client.

	A plot holds exactly one map at a time. A player is only ever standing in
	one, so holding all three would triple terrain and Part cost for two nobody
	is looking at - and that cost is what caps players per server. Advancing to
	the next map rebuilds the plot in place, which is the same code path as the
	re-freeze on leave (AD-3) rather than a second one bolted alongside it.

	Everything positional is derived from the map definition, so a swap moves the
	spawn pad and the fill lights along with the geometry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Feel"))
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))

local modules = script.Parent
local Discoveries = require(modules:WaitForChild("Discoveries"))
local IceField = require(modules:WaitForChild("IceField"))
local Meltwater = require(modules:WaitForChild("Meltwater"))
local SetPieces = require(modules:WaitForChild("SetPieces"))

export type Plot = {
	index: number,
	def: MapDefs.MapDef,
	field: IceField.IceField,
	finds: Discoveries.Field,
	pieces: SetPieces.Field,
	water: Meltwater.State,
	spawn: SpawnLocation,
	glow: Folder,
	owner: Player?,
}

local PlotManager = {}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function makeSpawn(index: number): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = string.format("Plot%d_Spawn", index)
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	-- Invisible: SetPieces puts a modelled dais in the same spot, and this only
	-- has to be the collision surface and the respawn anchor.
	spawn.Transparency = 1
	spawn.Material = Enum.Material.Slate
	spawn.Color = Feel.ROCK_DARK
	spawn.Parent = Workspace

	-- The only warm light before the player owns a torch, and a legible place to
	-- start from. Kept as a pool rather than area lighting: at a wide range it
	-- becomes the only light in a dark room and everything takes its colour -
	-- grey rock renders brown and the ice goes yellow.
	local glow = Instance.new("PointLight")
	glow.Name = "SpawnGlow"
	glow.Brightness = 2
	glow.Range = 24
	glow.Color = Color3.fromRGB(255, 196, 142)
	glow.Parent = spawn

	return spawn
end

-- Cold fill light for the chamber, so the ice reads as a luminous mass rather
-- than a black silhouette on its unlit faces.
--
-- Placed in the air around the block, never inside it: lights buried in the ice
-- lit every face by the same amount and flattened the whole thing into one slab,
-- and form comes from faces catching different amounts.
--
-- The count scales with the map. Three lights sized for a 72-stud cave left the
-- 240-stud pyramid chamber almost black - the pyramid was a silhouette against
-- nothing - so bigger maps get a grid instead of a fixed trio.
local function makeGlow(index: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_Glow", index)
	folder.Parent = Workspace
	return folder
end

local function fillPositions(def: MapDefs.MapDef, origin: Vector3): { Vector3 }
	local ice = GridMath.iceSize(def)
	local spots = {}

	-- A grid above the ice, high enough to clear whatever landmark stands on it.
	local across = math.clamp(math.ceil(ice.X / 80), 1, 3)
	local height = ice.Y + def.ceilingGap * 0.75
	for ax = 1, across do
		for az = 1, across do
			table.insert(spots, origin + Vector3.new(
				ice.X * (ax - 0.5) / across,
				height,
				ice.Z * (az - 0.5) / across
			))
		end
	end

	-- Two low lights on the walkway, throwing light up the working face.
	table.insert(spots, origin + Vector3.new(-def.walkway * 0.5, ice.Y * 0.25, ice.Z * 0.3))
	table.insert(spots, origin + Vector3.new(-def.walkway * 0.5, ice.Y * 0.25, ice.Z * 0.7))
	return spots
end

-- Move the spawn pad and rebuild the fill lights to suit the map now on this
-- plot. The light count is map-dependent, so they are remade rather than moved.
local function placeFurniture(plot: Plot)
	local def = plot.def
	local origin = plot.field.origin
	local ice = GridMath.iceSize(def)

	plot.spawn.CFrame = CFrame.new(GridMath.spawnPosition(def, origin) + Vector3.new(0, 0.5, 0))

	plot.glow:ClearAllChildren()

	-- Fill lights exist because a sealed chamber has no light of its own. An
	-- open map has a sun, and dropping blue point lights into daylight only
	-- flattens it - so outdoors gets none, and the spawn lantern with it.
	local outdoors = def.setting == "open"
	local spawnGlow = plot.spawn:FindFirstChild("SpawnGlow")
	if spawnGlow and spawnGlow:IsA("PointLight") then
		spawnGlow.Enabled = not outdoors
	end
	if outdoors then
		return
	end

	local spots = fillPositions(def, origin)
	local across = math.clamp(math.ceil(ice.X / 80), 1, 3)
	-- Each light only has to cover its own cell of the grid, plus overlap.
	local range = math.max(52, (ice.X / across) * 1.15)

	for index, position in spots do
		local anchor = Instance.new("Part")
		anchor.Name = string.format("Glow%d", index)
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(position)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false -- must never eat a melt raycast
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Parent = plot.glow

		local light = Instance.new("PointLight")
		-- Dimmer than it was. These used to be the cave's only light; now the
		-- wall torches do that job and these just stop the far corners reading
		-- as a void rather than as unlit blue ice.
		light.Brightness = 0.3
		light.Range = range
		light.Color = Color3.fromRGB(150, 205, 255)
		light.Shadows = false
		light.Parent = anchor
	end
end

-- Freeze the map and scatter a fresh set of finds through it. The two have to
-- happen in this order: placement may only claim cells that exist, so the grid
-- has to be laid before anything can be buried in it.
function PlotManager.rebuild(plot: Plot, def: MapDefs.MapDef?)
	if def then
		plot.def = def
	end
	IceField.build(plot.field, plot.def)
	Meltwater.setMap(plot.water, plot.def)
	placeFurniture(plot)
	-- Architecture before finds, because placement has to know which cells the
	-- landmark already fills.
	SetPieces.build(plot.pieces, plot.def, plot.field.origin)

	local map = plot.def
	local origin = plot.field.origin
	Discoveries.populate(plot.finds, map, origin, function(cell)
		if not IceField.occupied(plot.field, cell) then
			return false
		end
		-- A find buried inside the pyramid could never be uncovered: melting the
		-- ice around it just exposes stone.
		local gx, gy, gz = GridMath.cellCoords(map, cell)
		return not SetPieces.blocks(plot.pieces, GridMath.chunkCenter(map, origin, gx, gy, gz))
	end)
end

function PlotManager.init()
	local first = MapDefs.FIRST
	for index = 0, Config.PLOT_COUNT - 1 do
		-- Not built yet. Which map a plot should hold depends on who ends up on
		-- it, and building six of the largest map for an empty server is tens of
		-- thousands of Parts nobody is looking at.
		local field = IceField.new(index, first, false)
		local plot: Plot = {
			index = index,
			def = first,
			field = field,
			finds = Discoveries.new(index),
			pieces = SetPieces.new(index),
			water = Meltwater.new(field.origin, first),
			spawn = makeSpawn(index),
			glow = makeGlow(index),
			owner = nil,
		}
		placeFurniture(plot)
		table.insert(plots, plot)
	end
end

-- Reserve a free plot and set it to the map the player should be on, or nil
-- when the server is full.
function PlotManager.allocate(player: Player, def: MapDefs.MapDef): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			-- Always built here, never at startup: this is the first moment the
			-- right map for this plot is actually known.
			PlotManager.rebuild(plot, def)
			return plot
		end
	end
	return nil
end

-- Move this plot onto a different map in place.
function PlotManager.setMap(plot: Plot, def: MapDefs.MapDef)
	PlotManager.rebuild(plot, def)
end

function PlotManager.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	byPlayer[player] = nil
	plot.owner = nil
	-- Torn down rather than re-frozen. AD-3 asks that a recycled plot never hand
	-- the next player a half-melted map, and allocate() always builds fresh, so
	-- rebuilding here would be work thrown away the moment someone joins.
	plot.def = MapDefs.FIRST
	Discoveries.clear(plot.finds)
	-- Must happen: IceField.clear refills the whole shell solid, so anything left
	-- here would be entombed on an idle plot and then reappear inside whatever
	-- map the next player loads.
	SetPieces.clear(plot.pieces)
	Meltwater.setMap(plot.water, plot.def)
	IceField.clear(plot.field)
end

function PlotManager.get(player: Player): Plot?
	return byPlayer[player]
end

return PlotManager
