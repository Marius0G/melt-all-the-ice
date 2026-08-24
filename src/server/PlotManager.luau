--!strict
--[[
	PlotManager - the plot pool (AD-2).

	Terrain is a single global singleton in Roblox, so per-player worlds have
	to be done spatially: PLOT_COUNT regions spaced PLOT_SPACING apart, one
	handed to each player on join. Regions never overlap, so terrain writes
	never collide, and StreamingEnabled keeps one player's cave off every other
	player's client.

	Releasing a plot re-freezes it immediately (AD-3) so a recycled plot never
	hands the next player a half-melted cave.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GridMath = require(Shared:WaitForChild("GridMath"))

local Discoveries = require(script.Parent:WaitForChild("Discoveries"))
local IceField = require(script.Parent:WaitForChild("IceField"))

export type Plot = {
	index: number,
	field: IceField.IceField,
	finds: Discoveries.Field,
	spawn: SpawnLocation,
	glow: Folder,
	owner: Player?,
}

local PlotManager = {}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function makeSpawn(index: number, origin: Vector3): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = string.format("Plot%d_Spawn", index)
	spawn.Size = Vector3.new(8, 1, 8)
	-- Sits on the chamber floor: bottom flush with y = origin.Y.
	spawn.CFrame = CFrame.new(GridMath.spawnPosition(origin) + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Material = Enum.Material.Slate
	spawn.BrickColor = BrickColor.new("Dark stone grey")
	spawn.Parent = Workspace

	-- The only warm light in a sealed rock chamber, standing in for the lantern
	-- in docs/reference/cave-mid-state.png. Gives the player somewhere legible
	-- to start from before any light-bearing tool exists.
	-- Kept as a pool rather than area lighting. At range 34 this was the only
	-- light in a black cave, so it lit the whole floor orange and every surface
	-- in the room took its colour - grey rock rendered brown and the ice went
	-- yellow. Tighter and slightly cooler, it reads as a lantern again and lets
	-- the cold ambient own everything outside its reach.
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
-- Placed in the air around the block, never inside it. Lights buried in the ice
-- lit every face by the same amount and flattened the whole thing into one
-- cyan slab with no edges - form comes from faces catching different amounts,
-- which needs the light to be somewhere the block is not.
local function makeGlacierGlow(index: number, origin: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = string.format("Plot%d_Glow", index)
	folder.Parent = Workspace

	local ice = GridMath.iceSize()
	local spots = {
		-- Two high in the ceiling gap, offset so the top and the two near faces
		-- each take a different value.
		origin + Vector3.new(ice.X * 0.25, ice.Y + Config.CEILING_GAP * 0.6, ice.Z * 0.3),
		origin + Vector3.new(ice.X * 0.75, ice.Y + Config.CEILING_GAP * 0.6, ice.Z * 0.75),
		-- One low on the walkway, throwing light up the working face.
		origin + Vector3.new(-Config.WALKWAY * 0.5, ice.Y * 0.25, ice.Z * 0.5),
	}

	for spotIndex, position in spots do
		local anchor = Instance.new("Part")
		anchor.Name = string.format("Glow%d", spotIndex)
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(position)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false -- must never eat a melt raycast
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Parent = folder

		local light = Instance.new("PointLight")
		light.Brightness = 0.55
		light.Range = 44
		light.Color = Color3.fromRGB(150, 205, 255)
		light.Shadows = false
		light.Parent = anchor
	end

	return folder
end

-- Freeze the ice and scatter a fresh set of finds through it. The two have to
-- happen together and in this order: placement may only claim cells that exist,
-- so the grid has to be laid before anything can be buried in it.
function PlotManager.rebuild(plot: Plot)
	IceField.build(plot.field)
	Discoveries.populate(plot.finds, plot.field.origin, function(cell)
		return IceField.occupied(plot.field, cell)
	end)
end

function PlotManager.init()
	for index = 0, Config.PLOT_COUNT - 1 do
		local field = IceField.new(index)
		local plot: Plot = {
			index = index,
			field = field,
			finds = Discoveries.new(index),
			spawn = makeSpawn(index, field.origin),
			glow = makeGlacierGlow(index, field.origin),
			owner = nil,
		}
		Discoveries.populate(plot.finds, field.origin, function(cell)
			return IceField.occupied(field, cell)
		end)
		table.insert(plots, plot)
	end
end

-- Reserve a free plot, or nil when the server is full.
function PlotManager.allocate(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			return plot
		end
	end
	return nil
end

function PlotManager.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	byPlayer[player] = nil
	plot.owner = nil
	-- Re-freeze before it goes back in the pool (AD-3), finds included, so the
	-- next player never inherits a half-looted cave.
	PlotManager.rebuild(plot)
end

function PlotManager.get(player: Player): Plot?
	return byPlayer[player]
end

return PlotManager
