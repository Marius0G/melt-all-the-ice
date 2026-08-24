--!strict
--[[
	Progression - upgrade levels, tool ownership, and the derived numbers.

	Purchases are checked and applied here and nowhere else. The client sends a
	key and nothing more: it cannot say what a thing costs, what level it is
	buying, or what it is worth. All of that is read from the shared Upgrades
	table on the server side of the wire.

	Levels are mirrored onto Player attributes so the shop can render them
	without a request. Attributes replicate server -> client automatically and
	are not client-writable, which is the same trick the HUD already uses for
	money and stamina - it keeps the display honest by construction.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local Tools = require(Shared:WaitForChild("Tools"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))

export type Record = {
	levels: { [string]: number },
	maps: { [string]: boolean }, -- unlocked
	current: string,
}

local Progression = {}

local records: { [Player]: Record } = {}

local ATTRIBUTE_PREFIX = "Upg_"

local function push(player: Player, key: string, level: number)
	player:SetAttribute(ATTRIBUTE_PREFIX .. key, level)
end

function Progression.add(
	player: Player,
	restored: { [string]: number }?,
	restoredMaps: { [string]: boolean }?
)
	local levels: { [string]: number } = {}
	for _, def in Upgrades.DEFS do
		local level = 0
		if restored and typeof(restored[def.key]) == "number" then
			level = math.clamp(math.floor(restored[def.key]), 0, def.maxLevel)
		end
		levels[def.key] = level
		push(player, def.key, level)
	end
	-- The first map is always unlocked; the rest are earned by clearing the one
	-- before them.
	local maps: { [string]: boolean } = { [MapDefs.FIRST.id] = true }
	if restoredMaps then
		for id, unlocked in restoredMaps do
			if unlocked == true and MapDefs.get(id) then
				maps[id] = true
			end
		end
	end

	records[player] = { levels = levels, maps = maps, current = MapDefs.FIRST.id }
	player:SetAttribute("CurrentMap", MapDefs.FIRST.id)
	player:SetAttribute("MapLabel", MapDefs.FIRST.label)
end

function Progression.unlockedMaps(player: Player): { [string]: boolean }
	local record = records[player]
	return if record then record.maps else { [MapDefs.FIRST.id] = true }
end

function Progression.unlock(player: Player, id: string)
	local record = records[player]
	if record and MapDefs.get(id) then
		record.maps[id] = true
	end
end

function Progression.currentMap(player: Player): MapDefs.MapDef
	local record = records[player]
	local def = record and MapDefs.get(record.current)
	return def or MapDefs.FIRST
end

-- Only allows a map the player has actually unlocked.
function Progression.setCurrentMap(player: Player, id: string): boolean
	local record = records[player]
	if not record or not record.maps[id] then
		return false
	end
	local def = MapDefs.get(id)
	if not def then
		return false
	end
	record.current = id
	player:SetAttribute("CurrentMap", id)
	player:SetAttribute("MapLabel", def.label)
	return true
end

function Progression.remove(player: Player)
	records[player] = nil
end

function Progression.levels(player: Player): { [string]: number }
	local record = records[player]
	return if record then record.levels else {}
end

function Progression.levelOf(player: Player, key: string): number
	local record = records[player]
	if not record then
		return 0
	end
	return record.levels[key] or 0
end

-- Which tools the player has unlocked. The stone is always available.
function Progression.ownedTools(player: Player): { [string]: boolean }
	local owned: { [string]: boolean } = { stone = true }
	for toolKey, upgradeKey in Tools.GRANTED_BY do
		if Progression.levelOf(player, upgradeKey) > 0 then
			owned[toolKey] = true
		end
	end
	return owned
end

-- The best tool the player owns, which is what a fresh spawn should equip.
function Progression.bestTool(player: Player): string
	local owned = Progression.ownedTools(player)
	local best, bestOrder = "stone", -1
	for _, def in Tools.DEFS do
		if owned[def.key] and def.order > bestOrder then
			best, bestOrder = def.key, def.order
		end
	end
	return best
end

-- Attempt a purchase. Returns ok plus a reason when refused, so the shop can
-- say why rather than just failing silently.
function Progression.tryPurchase(
	player: Player,
	key: string,
	balance: number,
	spend: (number) -> boolean
): (boolean, string)
	local record = records[player]
	if not record then
		return false, "no record"
	end

	local def = Upgrades.get(key)
	if not def then
		return false, "unknown upgrade"
	end

	local level = record.levels[key] or 0
	if level >= def.maxLevel then
		return false, "already maxed"
	end

	if def.requires then
		local needed = def.requiresLevel or 1
		if (record.levels[def.requires] or 0) < needed then
			return false, "locked"
		end
	end

	local cost = Upgrades.costOf(def, level)
	if not cost then
		return false, "already maxed"
	end
	if balance < cost then
		return false, "too expensive"
	end
	if not spend(cost) then
		return false, "too expensive"
	end

	record.levels[key] = level + 1
	push(player, key, level + 1)
	return true, "ok"
end

-- Derived numbers. Read straight off the shared definitions so the shop preview
-- and the actual effect can never disagree.

function Progression.breakMultiplier(player: Player): number
	return Upgrades.breakMultiplier(Progression.levelOf(player, "break1"))
end

function Progression.incomeMultiplier(player: Player): number
	return Upgrades.incomeMultiplier(Progression.levelOf(player, "income1"))
end

function Progression.staminaMax(player: Player): number
	return Upgrades.staminaMax(Config.STAMINA_MAX, Progression.levelOf(player, "stamina1"))
end

function Progression.staminaRegen(player: Player): number
	return Upgrades.staminaRegen(Config.STAMINA_REGEN, Progression.levelOf(player, "stamina1"))
end

function Progression.fuelMax(player: Player): number
	return Upgrades.fuelMax(Config.FUEL_MAX, Progression.levelOf(player, "fuel1"))
end

function Progression.fuelRegen(player: Player): number
	return Upgrades.fuelRegen(Config.FUEL_REGEN, Progression.levelOf(player, "fuel1"))
end

return Progression
