--!strict
--[[
	MeltService - the one place a swing turns into melted ice.

	Server-authoritative end to end. The client sends a single thing: the
	direction it is aiming. Everything that decides an outcome happens here:

	  * the ray starts from the server's own copy of the character's head,
	    never from a client-supplied origin, so reach cannot be extended
	  * which tool is swinging is read from the tool the server can see equipped,
	    not from anything the client claims, so a stone cannot hit like a torch
	  * cooldown and the gate resource are checked and spent server-side
	  * the raycast is whitelisted to the swinging player's own plot folder,
	    so a spoofed direction can at worst aim badly - it can never touch
	    another player's cave
	  * money is paid out from the melt result, not from anything the client said

	The client never decides what melted or what it earned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Tools = require(Shared:WaitForChild("Tools"))

local modules = script.Parent
local Discoveries = require(modules:WaitForChild("Discoveries"))
local IceField = require(modules:WaitForChild("IceField"))
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

	local damage = tool.damage * Progression.breakMultiplier(player)
	local outcome = IceField.damage(plot.field, hit, damage)
	if not outcome then
		return
	end

	if outcome.destroyed then
		local payout = math.max(1, math.floor(Config.MONEY_PER_CHUNK * Progression.incomeMultiplier(player) + 0.5))
		PlayerStats.addMoney(player, payout)
		PlayerStats.setThawed(player, IceField.progress(plot.field))

		-- Was that the last of the ice over something?
		local found = Discoveries.onCellCleared(plot.finds, outcome.cell)
		if found then
			PlayerStats.addMoney(player, found.def.reward)
			PlayerStats.setFinds(player, plot.finds.found, Discoveries.total(plot.finds))
			Remotes.discovery():FireClient(
				player,
				found.part.Position,
				found.def.label,
				found.def.reward,
				found.def.hero
			)
		end
	end

	-- Cosmetics are the client's job, but it is told what happened rather than
	-- asked. Everything that decided an outcome is already settled above.
	Remotes.swingResult():FireClient(
		player,
		result.Position,
		result.Normal,
		outcome.destroyed,
		outcome.hpRatio
	)
end

function MeltService.init()
	Remotes.swing().OnServerEvent:Connect(onSwing)
end

return MeltService
