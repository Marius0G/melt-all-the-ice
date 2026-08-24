--!strict
--[[
	Upgrades - what money is for.

	The design doc lists the axes directly: how much money you get, how strong
	the fire is, how much ice you can break, and the stamina that gates the
	physical tools. Fire power and fuel arrive with the torch, so the cave tree
	is three stat branches plus the crafting line that ends in fire - which is
	the map capstone the doc names ("cel mai mare skill e sa inveti sa faci foc
	si practic ultima arma e torta").

	Shared rather than server-only on purpose: the shop has to show costs and
	effects, and there must be exactly one definition of what a level does. The
	client reads this to draw the tree; the server reads it to decide what a
	purchase costs and what it grants. Nothing here is authoritative on its own -
	the server still checks the balance and owns the levels.
]]

export type Branch = "might" | "fortune" | "vigour" | "craft"

export type UpgradeDef = {
	key: string,
	branch: Branch,
	label: string,
	blurb: string,
	maxLevel: number,
	baseCost: number,
	costGrowth: number,
	requires: string?, -- another upgrade that must be owned first
	requiresLevel: number?,
}

local Upgrades = {}

-- Annotated through a local: Luau does not accept a type on a table-field
-- assignment, and without the annotation the string literals widen to `string`
-- and stop satisfying the Branch union.
local BRANCH_ORDER: { Branch } = { "might", "fortune", "vigour", "craft" }
Upgrades.BRANCH_ORDER = BRANCH_ORDER

Upgrades.BRANCH_LABEL = {
	might = "MIGHT",
	fortune = "FORTUNE",
	vigour = "VIGOUR",
	craft = "CRAFT",
}

-- Colour-coded branches, as in the reference tree.
Upgrades.BRANCH_COLOR = {
	might = Color3.fromRGB(228, 96, 72),
	fortune = Color3.fromRGB(126, 217, 87),
	vigour = Color3.fromRGB(86, 168, 240),
	craft = Color3.fromRGB(196, 122, 232),
}

local DEFS: { UpgradeDef } = {
	{
		key = "break1",
		branch = "might",
		label = "Strong Arm",
		blurb = "+35% ice broken per swing",
		maxLevel = 5,
		baseCost = 40,
		costGrowth = 1.75,
	},
	{
		key = "income1",
		branch = "fortune",
		label = "Prospector",
		blurb = "+50% money per chunk",
		maxLevel = 5,
		baseCost = 55,
		costGrowth = 1.8,
	},
	{
		key = "stamina1",
		branch = "vigour",
		label = "Endurance",
		blurb = "+20 stamina, +3 regen",
		maxLevel = 5,
		baseCost = 35,
		costGrowth = 1.7,
	},
	{
		-- Locked behind the torch because it does nothing before it. Without a
		-- fuel axis the torch plateaus at one hit per chunk while break power
		-- keeps halving the axe's cost, and a maxed axe ends up outperforming
		-- the map's capstone tool - which inverts the whole progression.
		key = "fuel1",
		branch = "vigour",
		label = "Deep Reserves",
		blurb = "+12 fuel, +3 regen",
		maxLevel = 3,
		baseCost = 260,
		costGrowth = 1.8,
		requires = "torch",
		requiresLevel = 1,
	},
	{
		key = "axe",
		branch = "craft",
		label = "Stone Axe",
		blurb = "Tie the stone to a stick. Hits far harder.",
		maxLevel = 1,
		baseCost = 220,
		costGrowth = 1,
	},
	{
		key = "torch",
		branch = "craft",
		label = "Torch",
		blurb = "Learn to make fire. Melts ice, and lights the cave.",
		maxLevel = 1,
		baseCost = 900,
		costGrowth = 1,
		requires = "axe",
		requiresLevel = 1,
	},
}

Upgrades.DEFS = DEFS

local byKey: { [string]: UpgradeDef } = {}
for _, def in DEFS do
	byKey[def.key] = def
end

function Upgrades.get(key: string): UpgradeDef?
	return byKey[key]
end

-- Cost of moving from `level` to `level + 1`. Returns nil when maxed.
function Upgrades.costOf(def: UpgradeDef, level: number): number?
	if level >= def.maxLevel then
		return nil
	end
	return math.floor(def.baseCost * def.costGrowth ^ level + 0.5)
end

-- Effects. Kept as plain functions of level so both sides agree on the numbers
-- and the shop can preview them without duplicating the maths.

function Upgrades.breakMultiplier(level: number): number
	return 1 + 0.35 * level
end

function Upgrades.incomeMultiplier(level: number): number
	return 1 + 0.5 * level
end

function Upgrades.staminaMax(base: number, level: number): number
	return base + 20 * level
end

function Upgrades.staminaRegen(base: number, level: number): number
	return base + 3 * level
end

function Upgrades.fuelMax(base: number, level: number): number
	return base + 12 * level
end

function Upgrades.fuelRegen(base: number, level: number): number
	return base + 3 * level
end

return Upgrades
