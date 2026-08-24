--!strict
--[[
	PropAssets - the things frozen inside the ice.

	Geometry is authored in assets/blender/props.py, exported as a single FBX and
	uploaded once through Open Cloud (tools/upload_assets.py). One upload covers
	every prop across all three maps, because Roblox turns each mesh object in an
	FBX into its own MeshPart inside one Model asset. The mesh ids were read back
	out of that import and committed here, so nothing about the pipeline has to
	run again to build the game - the ids are just text in the repo like
	everything else.

	Three things about this that are easy to get wrong:

	  * Sizes are stored explicitly rather than trusted. Blender exports FBX in
	    centimetres, so every mesh arrives 100x too big - a 9-stud mammoth
	    imports at 934 studs. MeshPart.Size is writable and rescales the mesh, so
	    the authored dimensions are recorded here and applied on creation. That
	    also makes the props immune to the importer changing its scaling.
	  * No textures are exported, on purpose. MeshPart.Color only applies while a
	    mesh carries no texture, so colour lives here with the rest of the
	    palette instead of being baked into an uploaded image.
	  * Rewards are cave-equivalent and get multiplied by the map's chunk value.
	    Several props appear on more than one map, and a flat 75 dollar chest
	    that is a real find in the cave is loose change in Troy - scaling keeps
	    a find worth roughly the same number of swings wherever it turns up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

export type PropDef = {
	key: string,
	label: string, -- shown when it is uncovered
	meshId: string,
	size: Vector3, -- studs, as authored in Blender
	color: Color3,
	material: Enum.Material,
	reward: number, -- cave-equivalent; scaled by the map
	hero: boolean, -- hero finds get the louder reveal
}

local PropAssets = {}

-- The Model asset the meshes came from. Kept for provenance and for re-reading
-- the ids if the props are ever re-exported.
PropAssets.MODEL_ASSET_ID = 109085208443056

local DEFS: { PropDef } = {
	-- Cave.
	{
		key = "Mammoth",
		label = "Frozen Mammoth",
		meshId = "rbxassetid://115818303878731",
		size = Vector3.new(9.341, 5.725, 4.400),
		color = Color3.fromRGB(124, 82, 54),
		material = Enum.Material.Sand,
		reward = 120,
		hero = true,
	},
	{
		key = "FrozenPerson",
		label = "Frozen Wanderer",
		meshId = "rbxassetid://139500942334998",
		size = Vector3.new(1.779, 4.349, 2.438),
		color = Color3.fromRGB(188, 160, 134),
		material = Enum.Material.Sand,
		reward = 90,
		hero = true,
	},
	{
		key = "BonePile",
		label = "Dinosaur Bones",
		meshId = "rbxassetid://96196409970088",
		size = Vector3.new(6.552, 3.053, 5.559),
		color = Color3.fromRGB(232, 224, 196),
		material = Enum.Material.Sandstone,
		reward = 45,
		hero = false,
	},
	{
		key = "FrozenWolf",
		label = "Frozen Wolf",
		meshId = "rbxassetid://122832741637221",
		size = Vector3.new(7.316, 3.500, 1.785),
		color = Color3.fromRGB(128, 122, 116),
		material = Enum.Material.Sand,
		reward = 70,
		hero = false,
	},
	{
		key = "SpearCache",
		label = "Spear Cache",
		meshId = "rbxassetid://106339546647834",
		size = Vector3.new(3.147, 5.111, 3.148),
		color = Color3.fromRGB(132, 94, 58),
		material = Enum.Material.Wood,
		reward = 55,
		hero = false,
	},
	{
		key = "Stalagmite",
		label = "Stalagmites",
		meshId = "rbxassetid://71684085221683",
		size = Vector3.new(2.797, 5.000, 2.670),
		color = Color3.fromRGB(118, 122, 132),
		material = Enum.Material.Slate,
		reward = 10,
		hero = false,
	},

	-- Shared across maps.
	{
		key = "Chest",
		label = "Buried Chest",
		meshId = "rbxassetid://114728916569626",
		size = Vector3.new(2.360, 1.720, 1.520),
		color = Color3.fromRGB(138, 92, 48),
		material = Enum.Material.Wood,
		reward = 75,
		hero = false,
	},
	{
		key = "Pot",
		label = "Ancient Pot",
		meshId = "rbxassetid://116770429464162",
		size = Vector3.new(1.617, 2.525, 2.000),
		color = Color3.fromRGB(176, 118, 80),
		material = Enum.Material.Slate,
		reward = 35,
		hero = false,
	},
	{
		key = "CrystalCluster",
		label = "Ice Crystals",
		meshId = "rbxassetid://127197933813236",
		size = Vector3.new(2.716, 3.292, 2.274),
		color = Color3.fromRGB(120, 226, 240),
		material = Enum.Material.Glass,
		reward = 25,
		hero = false,
	},

	-- Pyramid.
	{
		key = "Sarcophagus",
		label = "Golden Sarcophagus",
		meshId = "rbxassetid://106275965443585",
		size = Vector3.new(5.810, 2.062, 2.000),
		color = Color3.fromRGB(218, 176, 72),
		material = Enum.Material.Metal,
		reward = 120,
		hero = true,
	},
	{
		key = "Obelisk",
		label = "Fallen Obelisk",
		meshId = "rbxassetid://133106340630992",
		size = Vector3.new(1.900, 9.600, 1.900),
		color = Color3.fromRGB(208, 180, 124),
		material = Enum.Material.Sandstone,
		reward = 65,
		hero = false,
	},
	{
		key = "CanopicJar",
		label = "Canopic Jar",
		meshId = "rbxassetid://76417625969698",
		size = Vector3.new(1.600, 3.150, 1.360),
		color = Color3.fromRGB(226, 208, 168),
		material = Enum.Material.Marble,
		reward = 30,
		hero = false,
	},

	-- Troy.
	{
		key = "TrojanHorse",
		label = "The Trojan Horse",
		meshId = "rbxassetid://98917478843223",
		size = Vector3.new(9.881, 8.670, 3.040),
		color = Color3.fromRGB(118, 80, 44),
		material = Enum.Material.WoodPlanks,
		reward = 150,
		hero = true,
	},
	{
		key = "Statue",
		label = "Marble Statue",
		meshId = "rbxassetid://113200567606633",
		size = Vector3.new(1.700, 5.307, 2.042),
		color = Color3.fromRGB(224, 220, 206),
		material = Enum.Material.Marble,
		reward = 70,
		hero = false,
	},
	{
		key = "Column",
		label = "Toppled Column",
		meshId = "rbxassetid://137663547927295",
		size = Vector3.new(1.900, 7.820, 1.900),
		color = Color3.fromRGB(232, 228, 214),
		material = Enum.Material.Marble,
		reward = 40,
		hero = false,
	},
	{
		key = "Shield",
		label = "Bronze Shield",
		meshId = "rbxassetid://90028714794896",
		size = Vector3.new(3.000, 2.896, 1.060),
		color = Color3.fromRGB(176, 124, 58),
		material = Enum.Material.Metal,
		reward = 35,
		hero = false,
	},
}

PropAssets.DEFS = DEFS

local byKey: { [string]: PropDef } = {}
for _, def in DEFS do
	byKey[def.key] = def
end

function PropAssets.get(key: string): PropDef?
	return byKey[key]
end

-- Colour used for the sparkle that hints at something buried. Deliberately the
-- warm reward colour rather than the prop colour: it has to read against ice at
-- a distance, and it should mean "something is here" rather than give away what.
PropAssets.HINT_COLOR = Feel.MONEY

return PropAssets
