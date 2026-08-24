--!strict
--[[
	PlayerStats - money and stamina, owned by the server.

	State is mirrored onto Player attributes rather than pushed down a remote.
	Attributes replicate server -> client automatically and cannot be written
	by the client, so this gives server authority and a live HUD in one move,
	with no remote plumbing to keep in sync.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Stats = {
	money: number,
	stamina: number,
	lastSwing: number,
}

local PlayerStats = {}

local stats: { [Player]: Stats } = {}

function PlayerStats.add(player: Player)
	stats[player] = { money = 0, stamina = Config.STAMINA_MAX, lastSwing = 0 }
	player:SetAttribute("Money", 0)
	player:SetAttribute("Stamina", Config.STAMINA_MAX)
	player:SetAttribute("StaminaMax", Config.STAMINA_MAX)
	player:SetAttribute("ThawedPct", 0)
	player:SetAttribute("Found", 0)
	player:SetAttribute("FoundTotal", 0)
end

function PlayerStats.remove(player: Player)
	stats[player] = nil
end

function PlayerStats.get(player: Player): Stats?
	return stats[player]
end

function PlayerStats.addMoney(player: Player, amount: number)
	local entry = stats[player]
	if not entry then
		return
	end
	entry.money += amount
	player:SetAttribute("Money", entry.money)
end

function PlayerStats.setFinds(player: Player, found: number, total: number)
	player:SetAttribute("Found", found)
	player:SetAttribute("FoundTotal", total)
end

function PlayerStats.setThawed(player: Player, fraction: number)
	player:SetAttribute("ThawedPct", fraction)
end

-- Spend stamina if there is enough of it. False means the swing is gated.
function PlayerStats.trySpendStamina(player: Player, cost: number): boolean
	local entry = stats[player]
	if not entry or entry.stamina < cost then
		return false
	end
	entry.stamina -= cost
	player:SetAttribute("Stamina", entry.stamina)
	return true
end

-- Called on a throttled loop rather than per-frame; see Bootstrap.
function PlayerStats.regen(dt: number)
	for player, entry in stats do
		if entry.stamina < Config.STAMINA_MAX then
			entry.stamina = math.min(Config.STAMINA_MAX, entry.stamina + Config.STAMINA_REGEN * dt)
			player:SetAttribute("Stamina", entry.stamina)
		end
	end
end

return PlayerStats
