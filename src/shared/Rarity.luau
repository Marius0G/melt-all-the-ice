--!strict
--[[
	Rarity - how big a deal a find is.

	Derived from the find's reward rather than stored alongside it. Reward is
	already the "how valuable is this" axis, so a second hand-maintained field
	would only be a chance for the two to disagree - a legendary worth less than
	a common is the kind of thing nobody notices until a player screenshots it.

	The `hero` flag still counts: it marks the finds a map is *about*, and those
	are floored at Epic no matter what the arithmetic says.

	Tiers do three jobs:

	  * they multiply the payout, which is what makes uncovering a mammoth feel
	    different from uncovering a pot;
	  * they set how loud the reveal is - shards, shake, how long the label
	    hangs around;
	  * they colour everything downstream, so the popup, the collection log and
	    the quest list all agree on what purple means without passing colours
	    around.

	Thresholds are in cave-equivalent money, the same units PropAssets.reward
	uses, so they do not need rescaling per map.
]]

local Rarity = {}

export type Tier = {
	key: string,
	label: string,
	order: number, -- 1 = commonest
	color: Color3,
	glow: Color3,
	multiplier: number, -- applied on top of the base reward
	shards: number, -- reveal burst size
	shake: number, -- camera shake scale
	hold: number, -- seconds the label stays up
}

local TIERS: { Tier } = {
	{
		key = "common",
		label = "Common",
		order = 1,
		color = Color3.fromRGB(206, 214, 224),
		glow = Color3.fromRGB(236, 242, 250),
		multiplier = 1.0,
		shards = 10,
		shake = 0.6,
		hold = 1.6,
	},
	{
		key = "uncommon",
		label = "Uncommon",
		order = 2,
		color = Color3.fromRGB(108, 214, 120),
		glow = Color3.fromRGB(170, 246, 178),
		multiplier = 1.15,
		shards = 14,
		shake = 0.8,
		hold = 1.9,
	},
	{
		key = "rare",
		label = "Rare",
		order = 3,
		color = Color3.fromRGB(86, 162, 255),
		glow = Color3.fromRGB(158, 206, 255),
		multiplier = 1.35,
		shards = 20,
		shake = 1.0,
		hold = 2.2,
	},
	{
		key = "epic",
		label = "Epic",
		order = 4,
		color = Color3.fromRGB(186, 116, 255),
		glow = Color3.fromRGB(220, 180, 255),
		multiplier = 1.6,
		shards = 28,
		shake = 1.3,
		hold = 2.6,
	},
	{
		key = "legendary",
		label = "LEGENDARY",
		order = 5,
		color = Color3.fromRGB(255, 186, 64),
		glow = Color3.fromRGB(255, 226, 150),
		multiplier = 2.0,
		shards = 40,
		shake = 1.8,
		hold = 3.4,
	},
}

Rarity.TIERS = TIERS

local byKey: { [string]: Tier } = {}
for _, tier in TIERS do
	byKey[tier.key] = tier
end

Rarity.COMMON = TIERS[1]
Rarity.LEGENDARY = TIERS[#TIERS]

-- Lower bound of each tier, in cave-equivalent money. Index matches TIERS.
local FLOORS = { 0, 30, 50, 80, 120 }

function Rarity.get(key: string): Tier?
	return byKey[key]
end

-- The tier a find of this value sits in. `hero` marks the finds a map is built
-- around and floors them at Epic.
function Rarity.forReward(reward: number, hero: boolean?): Tier
	local index = 1
	for at = #FLOORS, 1, -1 do
		if reward >= FLOORS[at] then
			index = at
			break
		end
	end
	if hero and index < 4 then
		index = 4
	end
	return TIERS[index]
end

-- Rounded, because money is whole numbers everywhere else.
function Rarity.payout(base: number, tier: Tier): number
	return math.max(1, math.floor(base * tier.multiplier + 0.5))
end

return Rarity
