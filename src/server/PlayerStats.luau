--!strict
--[[
	PlayerStats - money and the two swing gates, owned by the server.

	State is mirrored onto Player attributes rather than pushed down a remote.
	Attributes replicate server -> client automatically and cannot be written by
	the client, so this gives server authority and a live HUD in one move, with
	no remote plumbing to keep in sync.

	Two gates, per the design doc: stamina for the physical tools, fuel for the
	fire ones. They are tracked separately because they refill at different
	rates - that difference is what makes the torch a choice rather than a
	strict upgrade.

	Limits are per-player rather than constant, because upgrades move them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tools = require(Shared:WaitForChild("Tools"))

export type Stats = {
	money: number,
	stamina: number,
	staminaMax: number,
	staminaRegen: number,
	fuel: number,
	fuelMax: number,
	fuelRegen: number,
	lastSwing: number,
}

local PlayerStats = {}

local stats: { [Player]: Stats } = {}

function PlayerStats.add(player: Player, money: number?)
	local entry: Stats = {
		money = money or 0,
		stamina = Config.STAMINA_MAX,
		staminaMax = Config.STAMINA_MAX,
		staminaRegen = Config.STAMINA_REGEN,
		fuel = Config.FUEL_MAX,
		fuelMax = Config.FUEL_MAX,
		fuelRegen = Config.FUEL_REGEN,
		lastSwing = 0,
	}
	stats[player] = entry

	player:SetAttribute("Money", entry.money)
	player:SetAttribute("Stamina", entry.stamina)
	player:SetAttribute("StaminaMax", entry.staminaMax)
	player:SetAttribute("Fuel", entry.fuel)
	player:SetAttribute("FuelMax", entry.fuelMax)
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

-- Spend if affordable. The single place money leaves a player.
function PlayerStats.spendMoney(player: Player, amount: number): boolean
	local entry = stats[player]
	if not entry or entry.money < amount then
		return false
	end
	entry.money -= amount
	player:SetAttribute("Money", entry.money)
	return true
end

function PlayerStats.setFinds(player: Player, found: number, total: number)
	player:SetAttribute("Found", found)
	player:SetAttribute("FoundTotal", total)
end

function PlayerStats.setThawed(player: Player, fraction: number)
	player:SetAttribute("ThawedPct", fraction)
end

-- Upgrades moved the ceiling. Existing stamina is carried up with it rather
-- than left behind, so buying Endurance mid-swing feels like a gain now.
function PlayerStats.setStaminaLimits(player: Player, maximum: number, regen: number)
	local entry = stats[player]
	if not entry then
		return
	end
	local gained = maximum - entry.staminaMax
	entry.staminaMax = maximum
	entry.staminaRegen = regen
	if gained > 0 then
		entry.stamina = math.min(maximum, entry.stamina + gained)
	else
		entry.stamina = math.min(entry.stamina, maximum)
	end
	player:SetAttribute("StaminaMax", maximum)
	player:SetAttribute("Stamina", entry.stamina)
end

function PlayerStats.setFuelLimits(player: Player, maximum: number, regen: number)
	local entry = stats[player]
	if not entry then
		return
	end
	local gained = maximum - entry.fuelMax
	entry.fuelMax = maximum
	entry.fuelRegen = regen
	if gained > 0 then
		entry.fuel = math.min(maximum, entry.fuel + gained)
	else
		entry.fuel = math.min(entry.fuel, maximum)
	end
	player:SetAttribute("FuelMax", maximum)
	player:SetAttribute("Fuel", entry.fuel)
end

-- Spend from whichever gate the tool uses. False means the swing is refused.
function PlayerStats.trySpendGate(player: Player, gate: Tools.Gate, cost: number): boolean
	local entry = stats[player]
	if not entry then
		return false
	end

	if gate == "fuel" then
		if entry.fuel < cost then
			return false
		end
		entry.fuel -= cost
		player:SetAttribute("Fuel", entry.fuel)
		return true
	end

	if entry.stamina < cost then
		return false
	end
	entry.stamina -= cost
	player:SetAttribute("Stamina", entry.stamina)
	return true
end

-- Called on a throttled loop rather than per-frame; see Bootstrap.
function PlayerStats.regen(dt: number)
	for player, entry in stats do
		if entry.stamina < entry.staminaMax then
			entry.stamina = math.min(entry.staminaMax, entry.stamina + entry.staminaRegen * dt)
			player:SetAttribute("Stamina", entry.stamina)
		end
		if entry.fuel < entry.fuelMax then
			entry.fuel = math.min(entry.fuelMax, entry.fuel + entry.fuelRegen * dt)
			player:SetAttribute("Fuel", entry.fuel)
		end
	end
end

return PlayerStats
