--!strict
--[[
	SaveService - progress that survives leaving.

	Deliberately built to degrade rather than fail. DataStores do not work in an
	unpublished place, and in Studio they need "Enable Studio Access to API
	Services" ticked; if either is missing every call throws. So the very first
	call decides whether saving is available at all, and when it is not the game
	runs exactly as before with saving quietly off. Nothing here is allowed to
	stop a player joining or playing.

	What persists: money and upgrade levels, which is to say everything the
	player worked for. What does not: how far through a map they were. That is
	deliberate and follows AD-3 - plots re-freeze when released, so a map is
	always started from frozen. Carrying half a melted cave across sessions would
	need the whole grid state saved and would contradict the reset the design
	already asks for.

	Saves are throttled and de-duplicated. DataStore write limits are per key and
	generous but not unlimited, and a player who buys five upgrades in ten
	seconds should not spend five writes.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SaveService = {}

local STORE_NAME = "MeltAllTheIce"
local SCHEMA_VERSION = 1
local AUTOSAVE_SECONDS = 120
local RETRIES = 3

export type Save = {
	version: number,
	money: number,
	upgrades: { [string]: number },
	unlockedMaps: { [string]: boolean },
	skins: { [string]: boolean },
	equippedSkins: { [string]: string },
}

local store: DataStore? = nil
local available: boolean? = nil -- nil until the first call decides
local lastSaved: { [Player]: string } = {}
local pending: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return string.format("p_%d", player.UserId)
end

local function emptySave(): Save
	return {
		version = SCHEMA_VERSION,
		money = 0,
		upgrades = {},
		unlockedMaps = { cave = true },
		skins = {},
		equippedSkins = {},
	}
end

-- One attempt to reach the store. Everything downstream treats nil as "saving
-- is off" rather than as an error worth surfacing repeatedly.
local function ensureStore(): DataStore?
	if available ~= nil then
		return store
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if ok and result then
		store = result
		available = true
		return store
	end

	available = false
	warn(
		"[MeltAllTheIce] saving is off: DataStores are unavailable. "
			.. "Publish the place once and tick Game Settings -> Security -> "
			.. "Enable Studio Access to API Services. The game runs fine without it."
	)
	return nil
end

local function withRetries<T>(label: string, work: () -> T): (boolean, T?)
	for attempt = 1, RETRIES do
		local ok, result = pcall(work)
		if ok then
			return true, result
		end
		if attempt == RETRIES then
			warn(string.format("[MeltAllTheIce] %s failed after %d attempts: %s", label, RETRIES, tostring(result)))
		else
			task.wait(attempt * 0.5)
		end
	end
	return false, nil
end

-- Never returns nil: a player whose data cannot be read starts fresh and plays.
-- Handing them an error screen would be worse than handing them a new save.
function SaveService.load(player: Player): Save
	local dataStore = ensureStore()
	if not dataStore then
		return emptySave()
	end

	local ok, raw = withRetries("load " .. player.Name, function()
		return (dataStore :: DataStore):GetAsync(keyFor(player))
	end)

	if not ok or typeof(raw) ~= "table" then
		return emptySave()
	end

	local data = raw :: any
	local save = emptySave()
	if typeof(data.money) == "number" then
		save.money = math.max(0, math.floor(data.money))
	end
	if typeof(data.upgrades) == "table" then
		for key, level in data.upgrades do
			if typeof(key) == "string" and typeof(level) == "number" then
				save.upgrades[key] = math.max(0, math.floor(level))
			end
		end
	end
	if typeof(data.unlockedMaps) == "table" then
		for key, unlocked in data.unlockedMaps do
			if typeof(key) == "string" then
				save.unlockedMaps[key] = unlocked == true
			end
		end
	end
	if typeof(data.skins) == "table" then
		for key, owned in data.skins do
			if typeof(key) == "string" then
				save.skins[key] = owned == true
			end
		end
	end
	if typeof(data.equippedSkins) == "table" then
		for tool, key in data.equippedSkins do
			if typeof(tool) == "string" and typeof(key) == "string" then
				save.equippedSkins[tool] = key
			end
		end
	end
	return save
end

-- Cheap change detection, so repeated saves of identical data cost nothing.
local function fingerprint(save: Save): string
	local parts = { tostring(save.money) }
	local keys = {}
	for key in save.upgrades do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		table.insert(parts, key .. "=" .. tostring(save.upgrades[key]))
	end
	local maps = {}
	for key, unlocked in save.unlockedMaps do
		if unlocked then
			table.insert(maps, key)
		end
	end
	table.sort(maps)
	table.insert(parts, "maps:" .. table.concat(maps, ","))

	local owned = {}
	for key, has in save.skins do
		if has then
			table.insert(owned, key)
		end
	end
	table.sort(owned)
	table.insert(parts, "skins:" .. table.concat(owned, ","))

	local worn = {}
	for tool, key in save.equippedSkins do
		table.insert(worn, tool .. "=" .. key)
	end
	table.sort(worn)
	table.insert(parts, "worn:" .. table.concat(worn, ","))
	return table.concat(parts, "|")
end

function SaveService.save(player: Player, save: Save, force: boolean?): boolean
	local dataStore = ensureStore()
	if not dataStore then
		return false
	end

	local stamp = fingerprint(save)
	if not force and lastSaved[player] == stamp then
		return true -- nothing changed since the last write
	end

	save.version = SCHEMA_VERSION
	local ok = withRetries("save " .. player.Name, function()
		(dataStore :: DataStore):SetAsync(keyFor(player), save)
		return true
	end)

	if ok then
		lastSaved[player] = stamp
	end
	return ok
end

function SaveService.forget(player: Player)
	lastSaved[player] = nil
	pending[player] = nil
end

-- Autosave plus a flush on shutdown. collect() is supplied by Bootstrap so this
-- module never has to know how progression is stored.
function SaveService.start(collect: (Player) -> Save)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				if not pending[player] then
					pending[player] = true
					task.spawn(function()
						SaveService.save(player, collect(player))
						pending[player] = nil
					end)
				end
			end
		end
	end)

	-- BindToClose gets roughly 30 seconds; saving everyone in parallel matters
	-- when a full server shuts down at once.
	game:BindToClose(function()
		if RunService:IsStudio() and available ~= true then
			return
		end
		local players = Players:GetPlayers()
		local remaining = #players
		if remaining == 0 then
			return
		end
		for _, player in players do
			task.spawn(function()
				SaveService.save(player, collect(player), true)
				remaining -= 1
			end)
		end
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function SaveService.isAvailable(): boolean
	return ensureStore() ~= nil
end

return SaveService
