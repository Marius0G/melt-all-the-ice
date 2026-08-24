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

local IceField = require(script.Parent:WaitForChild("IceField"))

export type Plot = {
	index: number,
	field: IceField.IceField,
	spawn: SpawnLocation,
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
	local glow = Instance.new("PointLight")
	glow.Name = "SpawnGlow"
	glow.Brightness = 1.4
	glow.Range = 34
	glow.Color = Color3.fromRGB(255, 176, 104)
	glow.Parent = spawn

	return spawn
end

function PlotManager.init()
	for index = 0, Config.PLOT_COUNT - 1 do
		local field = IceField.new(index)
		table.insert(plots, {
			index = index,
			field = field,
			spawn = makeSpawn(index, field.origin),
			owner = nil,
		})
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
	-- Re-freeze before it goes back in the pool (AD-3).
	IceField.build(plot.field)
end

function PlotManager.get(player: Player): Plot?
	return byPlayer[player]
end

return PlotManager
