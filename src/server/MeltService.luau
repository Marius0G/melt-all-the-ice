--!strict
--[[
	MeltService - the one place a swing turns into melted ice.

	Server-authoritative end to end. The client sends a single thing: the
	direction it is aiming. Everything that decides an outcome happens here:

	  * the ray starts from the server's own copy of the character's head,
	    never from a client-supplied origin, so reach cannot be extended
	  * which tool is swinging is read from the tool the server can see equipped,
	    not from anything the client claims, so a stone cannot hit like a scepter
	  * cooldown and the gate resource are checked and spent server-side
	  * the raycast is whitelisted to the swinging player's own plot folder,
	    so a spoofed direction can at worst aim badly - it can never touch
	    another player's map
	  * money is paid out from the melt result, not from anything the client said

	A strike is not always one chunk. The later tools have an area, and the fire
	tools keep burning after the swing lands, so one swing can resolve into
	several strikes over a couple of seconds. All of them run through the same
	routine, which is what keeps discoveries, payouts and the finale correct no
	matter which tool caused them - there is no second path that could forget to
	check whether something was buried.

	The client never decides what melted or what it earned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridMath = require(Shared:WaitForChild("GridMath"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Tools = require(Shared:WaitForChild("Tools"))

local modules = script.Parent
local Combo = require(modules:WaitForChild("Combo"))
local Discoveries = require(modules:WaitForChild("Discoveries"))
local Finale = require(modules:WaitForChild("Finale"))
local IceField = require(modules:WaitForChild("IceField"))
local Meltwater = require(modules:WaitForChild("Meltwater"))
local PlayerStats = require(modules:WaitForChild("PlayerStats"))
local PlotManager = require(modules:WaitForChild("PlotManager"))
local Progression = require(modules:WaitForChild("Progression"))

local MeltService = {}

-- Whatever the server sees held, which is the only version that counts.
local function equippedTool(character: Model): Tools.ToolDef
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local key = tool:GetAttribute("ToolKey")
		if typeof(key) == "string" then
			local def = Tools.get(key)
			if def then
				return def
			end
		end
	end
	return Tools.get("stone") :: Tools.ToolDef
end

-- Cells within `radius` of a centre cell, roughly spherical rather than a cube
-- so an area tool carves a crater instead of a box.
local function cellsInRange(map: MapDefs.MapDef, cell: number, radius: number): { number }
	if radius <= 0 then
		return { cell }
	end
	local gx, gy, gz = GridMath.cellCoords(map, cell)
	local reach = radius * radius + radius
	local cells = {}
	for dx = -radius, radius do
		for dy = -radius, radius do
			for dz = -radius, radius do
				if dx * dx + dy * dy + dz * dz <= reach then
					local nx, ny, nz = gx + dx, gy + dy, gz + dz
					if
						nx >= 0
						and nx < map.grid.X
						and ny >= 0
						and ny < map.grid.Y
						and nz >= 0
						and nz < map.grid.Z
					then
						table.insert(cells, GridMath.cellIndex(map, nx, ny, nz))
					end
				end
			end
		end
	end
	return cells
end

-- Resolve one strike: damage everything in range, pay for what broke, uncover
-- anything that was under it, and end the map if that was the last of the ice.
-- Returns how many chunks broke, what they were worth, and the remaining HP
-- fraction of the chunk actually struck (for the client's crack feedback).
local function resolveStrike(
	player: Player,
	plot: PlotManager.Plot,
	tool: Tools.ToolDef,
	cell: number,
	damage: number,
	swung: boolean -- a real swing, as opposed to a burn tick
): (number, number, number)
	local map = plot.def
	local destroyed, earned, centreRatio = 0, 0, 0

	-- Taken once, up front, for the whole strike.
	--
	-- Extended by any swing that connects with ice, not only one that breaks a
	-- chunk. Measured: the stone costs 24 stamina against a 100 bar regenerating
	-- at 12/s, so it swings about every two seconds and breaks a 30 HP chunk
	-- about every six - well outside any sane window. Keyed to breaks, the
	-- streak was mathematically unreachable with the starting tool, which is
	-- exactly when a player most needs the encouragement.
	--
	-- Burn ticks do not extend it. They are the tool working on its own after
	-- the swing, and counting them would let a torch hold a streak indefinitely
	-- for one click.
	local streak = if swung then Combo.hit(player) else Combo.multiplierFor(Combo.get(player))

	for _, target in cellsInRange(map, cell, tool.aoe) do
		local outcome = IceField.damageCell(plot.field, target, damage)
		if outcome and target == cell then
			centreRatio = outcome.hpRatio
		end
		if outcome and outcome.destroyed then
			destroyed += 1

			local payout = math.max(
				1,
				math.floor(map.moneyPerChunk * Progression.incomeMultiplier(player) * streak + 0.5)
			)
			earned += payout
			PlayerStats.addMoney(player, payout)

			local found = Discoveries.onCellCleared(plot.finds, target)
			if found then
				-- Prop rewards are stored cave-equivalent and scaled by the map,
				-- so a chest that is a real find in the cave is not loose change
				-- in Troy where a single chunk pays twenty.
				local tier = Rarity.forReward(found.def.reward, found.def.hero)
				local bounty = Rarity.payout(
					math.max(1, math.floor(found.def.reward * map.moneyPerChunk + 0.5)),
					tier
				)
				earned += bounty
				PlayerStats.addMoney(player, bounty)
				PlayerStats.setFinds(player, plot.finds.found, Discoveries.total(plot.finds))
				Progression.recordFind(player, found.def.key, tier)
				Remotes.discovery():FireClient(
					player,
					found.part.Position,
					found.def.label,
					bounty,
					found.def.hero,
					tier.key
				)
			end
		end
	end

	if destroyed == 0 then
		return 0, 0, centreRatio
	end

	Progression.recordChunks(player, destroyed)

	local progress = IceField.progress(plot.field)
	PlayerStats.setThawed(player, progress)
	-- Only writes terrain when the level crosses a whole stud.
	Meltwater.update(plot.water, progress)

	if progress >= 1 then
		local index = plot.index
		local cleared = map
		local following = MapDefs.next(cleared)

		local fired = Finale.trigger(
			player,
			index,
			cleared,
			plot.field.origin,
			plot.pieces,
			plot.finds.found,
			Discoveries.total(plot.finds)
		)
		if fired then
			Progression.recordMapCleared(player)
			-- Clearing a map is what unlocks the next one. Clearing the *last*
			-- one unlocks nothing, so it has to be recorded on its own or there
			-- would be no way to tell it had happened.
			if following then
				Progression.unlock(player, following.id)
			else
				Progression.markFinished(player)
			end

			task.delay(Finale.resetDelay(), function()
				-- The plot may have changed hands while the finale played.
				local current = PlotManager.get(player)
				local target = cleared
				if current == plot and player.Parent and following then
					if Progression.setCurrentMap(player, following.id) then
						target = following
					end
				end

				PlotManager.rebuild(plot, target)
				Finale.clear(index)

				if current == plot and player.Parent then
					PlayerStats.setThawed(player, 0)
					PlayerStats.setFinds(player, plot.finds.found, Discoveries.total(plot.finds))
				end
			end)
		end
	end

	return destroyed, earned, centreRatio
end

local function onSwing(player: Player, direction: unknown)
	-- Never trust the payload's shape; it arrives straight off the wire.
	if typeof(direction) ~= "Vector3" then
		return
	end
	local aim = direction :: Vector3
	local magnitude = aim.Magnitude
	if magnitude < 0.1 or magnitude ~= magnitude then -- also rejects NaN
		return
	end

	local stats = PlayerStats.get(player)
	local plot = PlotManager.get(player)
	if not stats or not plot then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local tool = equippedTool(character)

	-- Rate-limit before anything else, so spam costs the attacker the cooldown
	-- whether or not the swing goes through.
	local now = os.clock()
	if now - stats.lastSwing < tool.cooldown then
		return
	end
	stats.lastSwing = now

	if not PlayerStats.trySpendGate(player, tool.gate, tool.cost) then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot.field.folder }
	params.IgnoreWater = true

	local result = Workspace:Raycast(head.Position, aim.Unit * tool.reach, params)
	if not result then
		return
	end

	local hit = result.Instance
	if not hit or not hit:IsA("BasePart") then
		return
	end

	-- Look the cell up without damaging it, so the whole strike - centre
	-- included - resolves through one path that pays out and checks for finds.
	local cell = IceField.cellOf(plot.field, hit)
	if not cell then
		return
	end

	local damage = tool.damage * Progression.breakMultiplier(player)
	local destroyed, earned, centreRatio = resolveStrike(player, plot, tool, cell, damage, true)

	Remotes.swingResult():FireClient(
		player,
		result.Position,
		result.Normal,
		destroyed,
		centreRatio,
		earned
	)

	-- Fire tools keep burning where they landed.
	if tool.burnTicks > 1 then
		task.spawn(function()
			for _ = 2, tool.burnTicks do
				task.wait(tool.burnInterval)
				if not player.Parent or PlotManager.get(player) ~= plot then
					return
				end
				local burned, paid = resolveStrike(player, plot, tool, cell, damage, false)
				if burned > 0 then
					Remotes.swingResult():FireClient(
						player,
						result.Position,
						result.Normal,
						burned,
						0,
						paid
					)
				end
			end
		end)
	end
end

function MeltService.init()
	Remotes.swing().OnServerEvent:Connect(onSwing)
end

return MeltService
