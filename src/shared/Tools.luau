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
	-- Radius in chunks affected around the one struck. 0 is a single chunk.
	-- This is how the later tools escalate: the design doc has campfires
	-- thawing "o anumita zona" and Ra's scepter melting "super mult", which is
	-- an area, not a bigger number.
	aoe: number,
	-- How many times the strike repeats. Greek fire "arde incontinuu pt o
	-- juma de minut", so it keeps burning after the swing rather than landing
	-- once.
	burnTicks: number,
	burnInterval: number,
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
		aoe = 0,
		burnTicks = 1,
		burnInterval = 0,
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
		aoe = 0,
		burnTicks = 1,
		burnInterval = 0,
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
		aoe = 0,
		burnTicks = 1,
		burnInterval = 0,
	},

	-- Pyramid. "incepi sa faci focuri de tabara care dezgheata o anumita zona
	-- (e o abilitate gen) ... ultima arma o sa fie scpetrul lui [Ra] cu care
	-- poti sa dezgheti super mult".
	{
		key = "campfire",
		label = "Campfire",
		tooltip = "Sets a blaze that thaws everything around it.",
		damage = 45,
		gate = "fuel",
		cost = 18,
		cooldown = 0.55,
		reach = 26,
		order = 4,
		light = true,
		aoe = 1,
		burnTicks = 2,
		burnInterval = 0.35,
	},
	{
		key = "scepter",
		label = "Ra's Scepter",
		tooltip = "The sun god's own. Melts a huge span at once.",
		damage = 70,
		gate = "fuel",
		cost = 30,
		cooldown = 0.7,
		reach = 34,
		order = 5,
		light = true,
		aoe = 2,
		burnTicks = 2,
		burnInterval = 0.3,
	},

	-- Troy. "greek fire care e un foc care arde incontinuu pt o juma de minut
	-- si e verde ... si dupa ai lanturile lui kratos care o sa fie si mai
	-- broken".
	{
		key = "greekfire",
		label = "Greek Fire",
		tooltip = "Green fire that will not go out. Keeps burning where it lands.",
		damage = 40,
		gate = "fuel",
		cost = 26,
		cooldown = 0.8,
		reach = 30,
		order = 6,
		light = true,
		aoe = 2,
		burnTicks = 6,
		burnInterval = 0.45,
	},
	{
		key = "chains",
		label = "Chains of Kratos",
		tooltip = "Absurd. Rips a crater out of the ice.",
		damage = 110,
		gate = "fuel",
		cost = 34,
		cooldown = 0.75,
		reach = 38,
		order = 7,
		light = true,
		aoe = 3,
		burnTicks = 3,
		burnInterval = 0.3,
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
	campfire = "campfire",
	scepter = "scepter",
	greekfire = "greekfire",
	chains = "chains",
}
Tools.GRANTED_BY = GRANTED_BY

return Tools
