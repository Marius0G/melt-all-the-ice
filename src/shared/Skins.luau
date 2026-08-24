--!strict
--[[
	Skins - "la arme vreau sa facem chestia de a-ti selecta tu cum vrei sa fie
	arma, gen ca pe jocurile de genu".

	Strictly cosmetic. A skin can change colour, material and - for the fire
	tools - the colour of the flame, and nothing else. That is not a limitation
	to work around later; it is what makes the whole feature cheap and safe. The
	server has to validate ownership and nothing more, because there is no
	number here that could affect a swing.

	Skins are applied by part name after a tool is built (see ToolService), so
	adding one never means touching a builder:

	    Handle          the shaft or body      -> body
	    Head/Blade/Disc/Ray/Vessel/Wrap/Log    -> accent
	    Flame           the fire ball + light + emitter -> flame

	Every tool has a free default that is always owned, so the shop can never
	leave a player with nothing to equip.
]]

export type Skin = {
	key: string,
	tool: string,
	label: string,
	body: Color3,
	accent: Color3,
	flame: Color3?, -- fire tools only
	material: Enum.Material,
	cost: number, -- 0 means always owned
}

local Skins = {}

local WOOD = Color3.fromRGB(122, 84, 48)
local STONE = Color3.fromRGB(104, 108, 116)

local DEFS: { Skin } = {
	-- Stone.
	{ key = "stone_granite", tool = "stone", label = "Granite", body = STONE, accent = STONE, material = Enum.Material.Slate, cost = 0 },
	{ key = "stone_obsidian", tool = "stone", label = "Obsidian", body = Color3.fromRGB(38, 36, 48), accent = Color3.fromRGB(64, 58, 82), material = Enum.Material.Glass, cost = 150 },
	{ key = "stone_bone", tool = "stone", label = "Bone", body = Color3.fromRGB(232, 224, 196), accent = Color3.fromRGB(206, 196, 166), material = Enum.Material.Sandstone, cost = 260 },

	-- Axe.
	{ key = "axe_flint", tool = "axe", label = "Flint", body = WOOD, accent = STONE, material = Enum.Material.Wood, cost = 0 },
	{ key = "axe_bronze", tool = "axe", label = "Bronze", body = Color3.fromRGB(96, 66, 38), accent = Color3.fromRGB(190, 130, 58), material = Enum.Material.Metal, cost = 400 },
	{ key = "axe_iron", tool = "axe", label = "Iron", body = Color3.fromRGB(58, 48, 42), accent = Color3.fromRGB(176, 182, 190), material = Enum.Material.Metal, cost = 700 },

	-- Torch.
	{ key = "torch_pitch", tool = "torch", label = "Pitch", body = WOOD, accent = Color3.fromRGB(64, 50, 36), flame = Color3.fromRGB(255, 158, 52), material = Enum.Material.Wood, cost = 0 },
	{ key = "torch_ember", tool = "torch", label = "Emberwood", body = Color3.fromRGB(78, 44, 30), accent = Color3.fromRGB(120, 52, 30), flame = Color3.fromRGB(255, 108, 40), material = Enum.Material.Wood, cost = 900 },
	{ key = "torch_cold", tool = "torch", label = "Coldfire", body = Color3.fromRGB(72, 84, 104), accent = Color3.fromRGB(96, 118, 150), flame = Color3.fromRGB(112, 196, 255), material = Enum.Material.Slate, cost = 1400 },

	-- Campfire.
	{ key = "campfire_kindling", tool = "campfire", label = "Kindling", body = WOOD, accent = Color3.fromRGB(96, 66, 38), flame = Color3.fromRGB(255, 150, 46), material = Enum.Material.Wood, cost = 0 },
	{ key = "campfire_verdant", tool = "campfire", label = "Verdant", body = Color3.fromRGB(72, 92, 54), accent = Color3.fromRGB(104, 132, 72), flame = Color3.fromRGB(150, 240, 120), material = Enum.Material.Grass, cost = 3200 },

	-- Ra's scepter.
	{ key = "scepter_gold", tool = "scepter", label = "Gold of Ra", body = Color3.fromRGB(214, 168, 58), accent = Color3.fromRGB(255, 216, 118), flame = Color3.fromRGB(255, 206, 74), material = Enum.Material.Metal, cost = 0 },
	{ key = "scepter_lapis", tool = "scepter", label = "Lapis", body = Color3.fromRGB(46, 68, 148), accent = Color3.fromRGB(120, 154, 232), flame = Color3.fromRGB(150, 190, 255), material = Enum.Material.Marble, cost = 9000 },

	-- Greek fire.
	{ key = "greekfire_green", tool = "greekfire", label = "Greek Fire", body = WOOD, accent = Color3.fromRGB(168, 116, 78), flame = Color3.fromRGB(96, 240, 120), material = Enum.Material.Wood, cost = 0 },
	{ key = "greekfire_violet", tool = "greekfire", label = "Violet Fire", body = Color3.fromRGB(64, 48, 78), accent = Color3.fromRGB(126, 94, 156), flame = Color3.fromRGB(196, 120, 255), material = Enum.Material.Slate, cost = 24000 },

	-- Chains of Kratos.
	{ key = "chains_blood", tool = "chains", label = "Blood Iron", body = Color3.fromRGB(72, 54, 40), accent = Color3.fromRGB(198, 74, 42), flame = Color3.fromRGB(255, 96, 48), material = Enum.Material.Fabric, cost = 0 },
	{ key = "chains_frost", tool = "chains", label = "Frostbound", body = Color3.fromRGB(60, 74, 92), accent = Color3.fromRGB(150, 205, 255), flame = Color3.fromRGB(160, 226, 255), material = Enum.Material.Metal, cost = 70000 },
}

Skins.DEFS = DEFS

local byKey: { [string]: Skin } = {}
local byTool: { [string]: { Skin } } = {}
local defaults: { [string]: string } = {}

for _, skin in DEFS do
	byKey[skin.key] = skin
	local list = byTool[skin.tool]
	if not list then
		list = {}
		byTool[skin.tool] = list
	end
	table.insert(list, skin)
	if skin.cost == 0 and not defaults[skin.tool] then
		defaults[skin.tool] = skin.key
	end
end

function Skins.get(key: string): Skin?
	return byKey[key]
end

function Skins.forTool(tool: string): { Skin }
	return byTool[tool] or {}
end

-- The free skin every player starts with. Never nil for a real tool.
function Skins.defaultFor(tool: string): string?
	return defaults[tool]
end

function Skins.isFree(key: string): boolean
	local skin = byKey[key]
	return skin ~= nil and skin.cost == 0
end

return Skins
