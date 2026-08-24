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
local PropAssets = require(Shared:WaitForChild("PropAssets"))
local Quests = require(Shared:WaitForChild("Quests"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Skins = require(Shared:WaitForChild("Skins"))
local Tools = require(Shared:WaitForChild("Tools"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))

export type Record = {
	levels: { [string]: number },
	maps: { [string]: boolean }, -- unlocked
	current: string,
	skins: { [string]: boolean }, -- owned
	equipped: { [string]: string }, -- tool key -> skin key
	rebirths: number,
	finished: boolean, -- has cleared the final map since the last rebirth
	collection: { [string]: number }, -- prop key -> how many ever uncovered
	questDay: number,
	questProgress: { [string]: number },
	questClaimed: { [string]: boolean },
}

-- What a save hands back. A table rather than a run of positional arguments:
-- there are nine of them now, and `add(player, a, b, c, d, e, f, g, h)` is a
-- bug waiting to happen the first time two of them are the same type.
export type Restored = {
	upgrades: { [string]: number }?,
	maps: { [string]: boolean }?,
	skins: { [string]: boolean }?,
	equipped: { [string]: string }?,
	rebirths: number?,
	finished: boolean?,
	collection: { [string]: number }?,
	questDay: number?,
	questProgress: { [string]: number }?,
	questClaimed: { [string]: boolean }?,
}

local Progression = {}

local records: { [Player]: Record } = {}

local ATTRIBUTE_PREFIX = "Upg_"

local function push(player: Player, key: string, level: number)
	player:SetAttribute(ATTRIBUTE_PREFIX .. key, level)
end

-- Serialised onto one attribute each rather than one per entry. Sixteen finds
-- and three quests would be nineteen attributes changing on every swing, and
-- each is a replication message; as a single string it is one.
local function pushCollection(player: Player)
	local record = records[player]
	if not record then
		return
	end
	local parts = {}
	for key, count in record.collection do
		table.insert(parts, string.format("%s=%d", key, count))
	end
	table.sort(parts)
	player:SetAttribute("Collection", table.concat(parts, ","))
end

local function pushQuests(player: Player)
	local record = records[player]
	if not record then
		return
	end
	local parts = {}
	for _, def in Quests.active(record.questDay) do
		table.insert(parts, string.format(
			"%s=%d%s",
			def.key,
			record.questProgress[def.key] or 0,
			if record.questClaimed[def.key] then "!" else ""
		))
	end
	player:SetAttribute("Quests", table.concat(parts, ","))
	player:SetAttribute("QuestDay", record.questDay)
end

local function pushRebirths(player: Player)
	local record = records[player]
	player:SetAttribute("Rebirths", if record then record.rebirths else 0)
	player:SetAttribute("Finished", if record then record.finished else false)
end

function Progression.add(player: Player, saved: Restored?)
	local restored = saved and saved.upgrades
	local restoredMaps = saved and saved.maps
	local restoredSkins = saved and saved.skins
	local restoredEquipped = saved and saved.equipped

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

	-- Free skins are always owned, so the shop can never leave a tool with
	-- nothing to equip.
	local skins: { [string]: boolean } = {}
	for _, skin in Skins.DEFS do
		if skin.cost == 0 then
			skins[skin.key] = true
		end
	end
	if restoredSkins then
		for key, owned in restoredSkins do
			if owned == true and Skins.get(key) then
				skins[key] = true
			end
		end
	end

	local equipped: { [string]: string } = {}
	for _, tool in Tools.DEFS do
		local chosen = restoredEquipped and restoredEquipped[tool.key]
		local def = if typeof(chosen) == "string" then Skins.get(chosen) else nil
		-- Fall back to the free skin if the saved one is unknown or unowned.
		if def and def.tool == tool.key and skins[chosen :: string] then
			equipped[tool.key] = chosen :: string
		else
			equipped[tool.key] = Skins.defaultFor(tool.key) or ""
		end
	end

	-- Only counts for props that still exist, so retiring a find cannot leave a
	-- collection log with a row nothing can render.
	local collection: { [string]: number } = {}
	local savedCollection = saved and saved.collection
	if savedCollection then
		for key, count in savedCollection do
			if typeof(count) == "number" and PropAssets.get(key) then
				collection[key] = math.max(0, math.floor(count))
			end
		end
	end

	-- Quest progress is only meaningful for the day it was earned on. Anything
	-- older is dropped here rather than at read time, which is what makes the
	-- daily rotation nothing more than a stored day number.
	local today = Quests.today()
	local questDay = if saved and typeof(saved.questDay) == "number" then saved.questDay else today
	local questProgress: { [string]: number } = {}
	local questClaimed: { [string]: boolean } = {}
	if questDay == today and saved then
		-- Bound through typed locals rather than iterated as `x or {}`: that
		-- expression has a union type and Luau will not walk it.
		local savedProgress: { [string]: number } = saved.questProgress or {}
		local savedClaimed: { [string]: boolean } = saved.questClaimed or {}
		for key, value in savedProgress do
			if typeof(value) == "number" and Quests.get(key) then
				questProgress[key] = math.max(0, math.floor(value))
			end
		end
		for key, claimed in savedClaimed do
			if claimed == true and Quests.get(key) then
				questClaimed[key] = true
			end
		end
	end

	records[player] = {
		levels = levels,
		maps = maps,
		current = MapDefs.FIRST.id,
		skins = skins,
		equipped = equipped,
		rebirths = math.max(0, math.floor((saved and saved.rebirths) or 0)),
		finished = (saved and saved.finished) == true,
		collection = collection,
		questDay = today,
		questProgress = questProgress,
		questClaimed = questClaimed,
	}

	for key, owned in skins do
		player:SetAttribute("SkinOwned_" .. key, owned)
	end
	for tool, key in equipped do
		player:SetAttribute("Skin_" .. tool, key)
	end
	player:SetAttribute("CurrentMap", MapDefs.FIRST.id)
	player:SetAttribute("MapLabel", MapDefs.FIRST.label)
	pushCollection(player)
	pushQuests(player)
	pushRebirths(player)
end

function Progression.ownedSkins(player: Player): { [string]: boolean }
	local record = records[player]
	return if record then record.skins else {}
end

function Progression.equippedSkins(player: Player): { [string]: string }
	local record = records[player]
	return if record then record.equipped else {}
end

function Progression.equippedSkin(player: Player, tool: string): string?
	local record = records[player]
	if not record then
		return Skins.defaultFor(tool)
	end
	return record.equipped[tool] or Skins.defaultFor(tool)
end

-- Buying and equipping are separate: owning a look and wearing it are different
-- states, and the shop needs to show both.
function Progression.buySkin(
	player: Player,
	key: string,
	balance: number,
	spend: (number) -> boolean
): (boolean, string)
	local record = records[player]
	if not record then
		return false, "no record"
	end
	local skin = Skins.get(key)
	if not skin then
		return false, "unknown skin"
	end
	if record.skins[key] then
		return false, "already owned"
	end
	if balance < skin.cost or not spend(skin.cost) then
		return false, "too expensive"
	end
	record.skins[key] = true
	player:SetAttribute("SkinOwned_" .. key, true)
	return true, "ok"
end

function Progression.selectSkin(player: Player, key: string): (boolean, string)
	local record = records[player]
	if not record then
		return false, "no record"
	end
	local skin = Skins.get(key)
	if not skin then
		return false, "unknown skin"
	end
	if not record.skins[key] then
		return false, "not owned"
	end
	record.equipped[skin.tool] = key
	player:SetAttribute("Skin_" .. skin.tool, key)
	return true, "ok"
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

-- ---------------------------------------------------------------------------
-- collection, quests and rebirth
-- ---------------------------------------------------------------------------

-- All three of these mirror onto attributes rather than going through a remote.
-- They change rarely and are read constantly by the UI, which is exactly the
-- shape attributes are good at, and it keeps the panels honest: the client can
-- read them and cannot write them.

function Progression.finished(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.finished
end

function Progression.rebirths(player: Player): number
	local record = records[player]
	return if record then record.rebirths else 0
end

-- Each rebirth is worth a flat 25% more income, forever. Additive rather than
-- compounding, so the tenth is still meaningful without the fortieth breaking
-- the economy.
function Progression.rebirthMultiplier(player: Player): number
	return 1 + Progression.rebirths(player) * 0.25
end

-- Set when the final map is cleared. It needs its own flag rather than reading
-- the unlock set: clearing a map unlocks the *next* one, so the last map being
-- unlocked only means the one before it was finished. Checking `maps[last]`
-- would have handed out a rebirth for clearing the pyramid.
function Progression.markFinished(player: Player)
	local record = records[player]
	if not record or record.finished then
		return
	end
	record.finished = true
	player:SetAttribute("Finished", true)
end

-- Checked here rather than trusted from the client, like every other purchase.
function Progression.canRebirth(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.finished
end

-- Wipes upgrades, tools, map unlocks and the current map; keeps skins, the
-- collection log and the rebirth count. Money is the caller's to reset, because
-- PlayerStats owns it.
function Progression.rebirth(player: Player): (boolean, string)
	local record = records[player]
	if not record then
		return false, "No record"
	end
	if not Progression.canRebirth(player) then
		return false, "Clear every map first"
	end

	record.rebirths += 1
	record.finished = false
	player:SetAttribute("Finished", false)
	for _, def in Upgrades.DEFS do
		record.levels[def.key] = 0
		push(player, def.key, 0)
	end
	record.maps = { [MapDefs.FIRST.id] = true }
	record.current = MapDefs.FIRST.id
	player:SetAttribute("CurrentMap", MapDefs.FIRST.id)
	player:SetAttribute("MapLabel", MapDefs.FIRST.label)
	pushRebirths(player)

	return true, string.format("Rebirth %d", record.rebirths)
end

function Progression.collection(player: Player): { [string]: number }
	local record = records[player]
	return if record then record.collection else {}
end

-- How many distinct finds the player has ever uncovered, and how many exist.
function Progression.collectionProgress(player: Player): (number, number)
	local record = records[player]
	local total = #PropAssets.DEFS
	if not record then
		return 0, total
	end
	local seen = 0
	for _, count in record.collection do
		if count > 0 then
			seen += 1
		end
	end
	return seen, total
end

function Progression.questState(player: Player): ({ [string]: number }, { [string]: boolean })
	local record = records[player]
	if not record then
		return {}, {}
	end
	return record.questProgress, record.questClaimed
end

-- Roll the day over if the record has been sitting since yesterday. Called
-- before anything reads or writes quest progress, so a session that spans
-- midnight rotates without needing a timer.
local function refreshDay(record: Record, player: Player)
	local today = Quests.today()
	if record.questDay == today then
		return
	end
	record.questDay = today
	table.clear(record.questProgress)
	table.clear(record.questClaimed)
	pushQuests(player)
end

local function bump(record: Record, kind: Quests.Kind, amount: number, tier: Rarity.Tier?)
	for _, def in Quests.active(record.questDay) do
		if def.kind ~= kind then
			continue
		end
		if def.kind == "rarity" then
			local floor = def.rarity and Rarity.get(def.rarity)
			if not floor or not tier or tier.order < floor.order then
				continue
			end
		end
		local at = (record.questProgress[def.key] or 0) + amount
		record.questProgress[def.key] = math.min(at, def.target)
	end
end

-- Called from the melt path. `chunks` is how many broke on this swing.
function Progression.recordChunks(player: Player, chunks: number)
	local record = records[player]
	if not record or chunks <= 0 then
		return
	end
	refreshDay(record, player)
	bump(record, "chunks", chunks)
	pushQuests(player)
end

-- Called when a find is uncovered. Feeds both the log and the quest counters.
function Progression.recordFind(player: Player, key: string, tier: Rarity.Tier)
	local record = records[player]
	if not record then
		return
	end
	refreshDay(record, player)
	record.collection[key] = (record.collection[key] or 0) + 1
	bump(record, "finds", 1)
	bump(record, "rarity", 1, tier)
	pushCollection(player)
	pushQuests(player)
end

function Progression.recordMapCleared(player: Player)
	local record = records[player]
	if not record then
		return
	end
	refreshDay(record, player)
	bump(record, "clear", 1)
	pushQuests(player)
end

-- Claiming is separate from completing, so the reward lands when the player is
-- looking at the panel rather than silently mid-swing.
function Progression.claimQuest(player: Player, key: string): (boolean, number, string)
	local record = records[player]
	if not record then
		return false, 0, "No record"
	end
	refreshDay(record, player)

	local def = Quests.get(key)
	if not def then
		return false, 0, "Unknown quest"
	end
	local active = false
	for _, candidate in Quests.active(record.questDay) do
		if candidate.key == key then
			active = true
			break
		end
	end
	if not active then
		return false, 0, "Not today's quest"
	end
	if record.questClaimed[key] then
		return false, 0, "Already claimed"
	end
	if (record.questProgress[key] or 0) < def.target then
		return false, 0, "Not finished"
	end

	record.questClaimed[key] = true
	pushQuests(player)
	return true, def.reward, def.label
end

function Progression.breakMultiplier(player: Player): number
	return Upgrades.breakMultiplier(Progression.levelOf(player, "break1"))
end

-- Upgrades and rebirths stack. Rebirths are the only multiplier that survives
-- one, which is the entire reason to do it.
function Progression.incomeMultiplier(player: Player): number
	return Upgrades.incomeMultiplier(Progression.levelOf(player, "income1"))
		* Progression.rebirthMultiplier(player)
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
