--!strict
--[[
	Server entry point. Builds the plots, then wires join/leave to them.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Tools = require(Shared:WaitForChild("Tools"))

local modules = script.Parent
local Ambience = require(modules:WaitForChild("Ambience"))
local Discoveries = require(modules:WaitForChild("Discoveries"))
local Finale = require(modules:WaitForChild("Finale"))
local IceField = require(modules:WaitForChild("IceField"))
local MeltService = require(modules:WaitForChild("MeltService"))
local PlayerStats = require(modules:WaitForChild("PlayerStats"))
local PlotManager = require(modules:WaitForChild("PlotManager"))
local Progression = require(modules:WaitForChild("Progression"))
local SaveService = require(modules:WaitForChild("SaveService"))
local ShopService = require(modules:WaitForChild("ShopService"))

-- Characters load only once a plot is reserved, so nobody spawns adrift at the
-- world origin while allocation is still in flight.
Players.CharacterAutoLoads = false

-- Before anything else: clients block on WaitForChild for these.
Remotes.initServer()

-- Cosmetic setup must never be able to take the server down with it. An
-- unsupported enum in here once aborted Bootstrap before a single plot was
-- built, which presents as an empty world rather than as a lighting bug.
xpcall(Ambience.apply, function(err)
	warn("[MeltAllTheIce] ambience failed: " .. tostring(err))
end)

-- Cave acoustics, one line. Applies to every 3D sound in the place.
SoundService.AmbientReverb = Enum.ReverbType.Cave

-- Ice fragments are spawned client-side for feedback, but collision groups can
-- only be registered on the server. Shards bounce off the world and ignore each
-- other and the player: fragment-vs-fragment is the expensive half of the
-- physics, and shards shoving the player around would be a bug, not a feature.
local SHARD_GROUP = "Shards"
if not PhysicsService:IsCollisionGroupRegistered(SHARD_GROUP) then
	PhysicsService:RegisterCollisionGroup(SHARD_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(SHARD_GROUP, SHARD_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(SHARD_GROUP, "Default", true)

-- Prop meshes first, together, so plot building is not serialised behind seven
-- separate asset fetches.
local meshStart = os.clock()
Discoveries.preload()
print(string.format("[MeltAllTheIce] loaded prop meshes in %.2fs", os.clock() - meshStart))

local buildStart = os.clock()
PlotManager.init()
print(string.format("[MeltAllTheIce] built plots in %.2fs", os.clock() - buildStart))

MeltService.init()
ShopService.init()

local function onCharacterAdded(player: Player, character: Model)
	local plot = PlotManager.get(player)
	if not plot then
		return
	end

	-- Placing the character explicitly rather than trusting SpawnLocation
	-- selection keeps a player pinned to their own plot even if respawn
	-- assignment races. Facing +X puts the ice face dead ahead.
	local position = GridMath.spawnPosition(plot.def, plot.field.origin) + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))

	-- Hand back everything they own, and put the best of it in their hands.
	ShopService.apply(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid0 = character:FindFirstChildOfClass("Humanoid")
	if backpack and humanoid0 then
		local best = Progression.bestTool(player)
		local def = Tools.get(best)
		local tool = def and backpack:FindFirstChild(def.label)
		if tool and tool:IsA("Tool") then
			humanoid0:EquipTool(tool)
		end
	end

	-- CharacterAutoLoads is off so the first spawn can wait for a plot, but
	-- that switch also turns off Roblox's automatic respawn, so death would
	-- otherwise be permanent. Own the respawn explicitly.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(Players.RespawnTime)
			-- Player.Parent goes nil when they leave mid-respawn.
			if player.Parent and PlotManager.get(player) then
				player:LoadCharacterAsync()
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	-- Load before allocating: which map the plot should be built as depends on
	-- what this player has unlocked, so the save has to be read first.
	local save = SaveService.load(player)
	Progression.add(player, save.upgrades, save.unlockedMaps, save.skins, save.equippedSkins)
	PlayerStats.add(player, save.money)

	local plot = PlotManager.allocate(player, Progression.currentMap(player))
	if not plot then
		PlayerStats.remove(player)
		Progression.remove(player)
		player:Kick("All plots on this server are taken - please rejoin for another server.")
		return
	end
	PlayerStats.setThawed(player, IceField.progress(plot.field))
	PlayerStats.setFinds(player, plot.finds.found, Discoveries.total(plot.finds))
	player.RespawnLocation = plot.spawn

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacterAsync()

	print(string.format("[MeltAllTheIce] %s -> plot %d", player.Name, plot.index))
end

-- What a save is made of, gathered from whoever owns each piece.
local function collect(player: Player): SaveService.Save
	local stats = PlayerStats.get(player)
	return {
		version = 1,
		money = if stats then stats.money else 0,
		upgrades = Progression.levels(player),
		-- Which maps are unlocked persists; how far through one you were does
		-- not. Plots re-freeze on release (AD-3), so a map always begins frozen.
		unlockedMaps = Progression.unlockedMaps(player),
		skins = Progression.ownedSkins(player),
		equippedSkins = Progression.equippedSkins(player),
	}
end

local function onPlayerRemoving(player: Player)
	-- Save before tearing the record down, or there is nothing left to save.
	SaveService.save(player, collect(player), true)
	SaveService.forget(player)
	local plot = PlotManager.get(player)
	if plot then
		Finale.clear(plot.index)
	end
	PlayerStats.remove(player)
	Progression.remove(player)
	PlotManager.release(player)
end

SaveService.start(collect)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Anyone already in before this script ran - which is what Studio's play-solo
-- does - still needs a plot.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Stamina regen, throttled to ~10 Hz. Fast enough to read as a smooth bar,
-- cheap enough not to spam attribute replication 60 times a second per player.
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		PlayerStats.regen(now - last)
		last = now
	end
end)

print("[MeltAllTheIce] server ready")
