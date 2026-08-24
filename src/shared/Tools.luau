--!strict
--[[
	Tools - the three cave tools and what separates them.

	Straight from the design doc: you start with a bare stone, find a stick and
	tie it on to make an axe, and the capstone of the map is learning to make
	fire, so the last tool is the torch.

	Damage is set against CHUNK_HP (30) so each tool lands on a clean hit count:
	stone three, axe two, torch one. Whole numbers matter here - a tool that
	takes 2.2 hits per chunk reads as inconsistent, because some chunks go in two
	and some in three for no reason the player can see.

	The two-resource split is the doc's too - "fiind conditionat de oboseala (la
	piatra si topor) si dupa la armele de foc o sa aibe gen un anumit
	combustibil". Physical tools spend stamina, fire tools spend fuel. That is
	what stops the torch simply being a bigger stone: it is stronger per swing
	and faster, but its gate refills far more slowly, so it rewards picking
	targets over flailing.
]]

export type Gate = "stamina" | "fuel"

export type ToolDef = {
	key: string,
	label: string,
	tooltip: string,
	damage: number,
	gate: Gate,
	cost: number, -- of the gate resource, per swing
	cooldown: number,
	reach: number,
	order: number, -- higher is better; used to pick what to equip
	light: boolean, -- does carrying it light the cave
}

local Tools = {}

-- Annotated through a local so `gate` narrows to the Gate union rather than
-- widening to `string`.
local DEFS: { ToolDef } = {
	{
		key = "stone",
		label = "Stone",
		tooltip = "Swing at the ice",
		damage = 10,
		gate = "stamina",
		cost = 8,
		cooldown = 0.45,
		reach = 24,
		order = 1,
		light = false,
	},
	{
		key = "axe",
		label = "Stone Axe",
		tooltip = "A stone lashed to a stick. Bites deeper.",
		damage = 20,
		gate = "stamina",
		cost = 9,
		cooldown = 0.40,
		reach = 26,
		order = 2,
		light = false,
	},
	{
		key = "torch",
		label = "Torch",
		tooltip = "Fire. Melts ice fast - and you can finally see.",
		damage = 30,
		gate = "fuel",
		cost = 9,
		cooldown = 0.35,
		reach = 22,
		order = 3,
		light = true,
	},
}

Tools.DEFS = DEFS

local byKey: { [string]: ToolDef } = {}
for _, def in DEFS do
	byKey[def.key] = def
end

function Tools.get(key: string): ToolDef?
	return byKey[key]
end

-- Which upgrade grants which tool. The stone is free.
local GRANTED_BY: { [string]: string } = {
	axe = "axe",
	torch = "torch",
}
Tools.GRANTED_BY = GRANTED_BY

return Tools
