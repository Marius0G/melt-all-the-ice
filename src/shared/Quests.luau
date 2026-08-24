--!strict
--[[
	Quests - a few things to be aiming at between the big landmarks.

	Clearing a map takes a long time, and for most of that the only feedback is
	a percentage creeping up. These are the short arcs inside it: melt two
	hundred chunks, turn up three rare finds, uncover a legendary. They give the
	next ten minutes a shape.

	Three are active at a time and they rotate daily. The rotation is derived
	from the day number rather than stored, so every server and every client
	agrees on today's set without anyone having to replicate it, and a player
	who joins at one minute to midnight sees the same three as everyone else.

	Progress is counted server-side and lives in the player's Progression record
	(and so in their save). The day is stored with it: when the stored day is not
	today, progress and claims reset, which is the whole of the rotation logic.

	Rewards are flat money rather than map-scaled. A quest is meant to be worth
	doing early, when money is tight, and to fade into irrelevance by Troy - that
	is what keeps them from becoming the optimal way to earn.
]]

local Quests = {}

export type Kind = "chunks" | "finds" | "rarity" | "clear"

export type QuestDef = {
	key: string,
	label: string,
	kind: Kind,
	target: number,
	rarity: string?, -- minimum tier, for kind == "rarity"
	reward: number,
}

-- Three at a time, out of this pool.
local DEFS: { QuestDef } = {
	{ key = "chunks120", label = "Melt 120 chunks", kind = "chunks", target = 120, reward = 90 },
	{ key = "chunks300", label = "Melt 300 chunks", kind = "chunks", target = 300, reward = 220 },
	{ key = "chunks600", label = "Melt 600 chunks", kind = "chunks", target = 600, reward = 480 },
	{ key = "finds3", label = "Uncover 3 finds", kind = "finds", target = 3, reward = 110 },
	{ key = "finds8", label = "Uncover 8 finds", kind = "finds", target = 8, reward = 300 },
	{ key = "rare2", label = "Uncover 2 rare finds", kind = "rarity", rarity = "rare", target = 2, reward = 260 },
	{ key = "rare5", label = "Uncover 5 rare finds", kind = "rarity", rarity = "rare", target = 5, reward = 620 },
	{ key = "epic1", label = "Uncover an epic find", kind = "rarity", rarity = "epic", target = 1, reward = 340 },
	{ key = "legendary1", label = "Uncover a legendary find", kind = "rarity", rarity = "legendary", target = 1, reward = 700 },
	{ key = "clear1", label = "Clear a map", kind = "clear", target = 1, reward = 900 },
}

Quests.DEFS = DEFS
Quests.ACTIVE_COUNT = 3

local byKey: { [string]: QuestDef } = {}
for _, def in DEFS do
	byKey[def.key] = def
end

function Quests.get(key: string): QuestDef?
	return byKey[key]
end

-- Whole days since the epoch. The unit the rotation turns on.
function Quests.today(): number
	return math.floor(os.time() / 86400)
end

-- Today's three, same everywhere, no replication needed.
--
-- A plain multiply-shift hash rather than Random.new(seed): Random's sequence is
-- not contractually stable across engine versions, and a rotation that silently
-- changes under players is worse than a slightly worse shuffle.
function Quests.active(day: number?): { QuestDef }
	local seed = day or Quests.today()
	local pool = table.clone(DEFS)
	local picked: { QuestDef } = {}

	for index = 1, math.min(Quests.ACTIVE_COUNT, #pool) do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local at = seed % #pool + 1
		table.insert(picked, pool[at])
		table.remove(pool, at)
	end

	return picked
end

return Quests
