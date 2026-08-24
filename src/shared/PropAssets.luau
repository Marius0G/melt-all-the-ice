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
PropAssets.MODEL_ASSET_ID = 108643143098587

local DEFS: { PropDef } = {
	-- Cave.
	{
		key = "Mammoth",
		label = "Frozen Mammoth",
		meshId = "rbxassetid://112156951831271",
		size = Vector3.new(9.34, 5.73, 4.40),
		color = Color3.fromRGB(124, 82, 54),
		material = Enum.Material.Sand,
		reward = 120,
		hero = true,
	},
	{
		key = "FrozenPerson",
		label = "Frozen Wanderer",
		meshId = "rbxassetid://95739496467956",
		size = Vector3.new(1.78, 4.35, 2.44),
		color = Color3.fromRGB(188, 160, 134),
		material = Enum.Material.Sand,
		reward = 90,
		hero = true,
	},
	{
		key = "BonePile",
		label = "Dinosaur Bones",
		meshId = "rbxassetid://134769465694223",
		size = Vector3.new(6.55, 3.05, 5.56),
		color = Color3.fromRGB(232, 224, 196),
		material = Enum.Material.Sandstone,
		reward = 45,
		hero = false,
	},
	{
		key = "FrozenWolf",
		label = "Frozen Wolf",
		meshId = "rbxassetid://128062392776150",
		size = Vector3.new(7.32, 3.50, 1.78),
		color = Color3.fromRGB(128, 122, 116),
		material = Enum.Material.Sand,
		reward = 70,
		hero = false,
	},
	{
		key = "SpearCache",
		label = "Spear Cache",
		meshId = "rbxassetid://140252457980207",
		size = Vector3.new(3.15, 5.11, 3.15),
		color = Color3.fromRGB(132, 94, 58),
		material = Enum.Material.Wood,
		reward = 55,
		hero = false,
	},
	{
		key = "Stalagmite",
		label = "Stalagmites",
		meshId = "rbxassetid://132779876266850",
		size = Vector3.new(2.80, 5.00, 2.67),
		color = Color3.fromRGB(118, 122, 132),
		material = Enum.Material.Slate,
		reward = 10,
		hero = false,
	},

	-- Shared across maps.
	{
		key = "Chest",
		label = "Buried Chest",
		meshId = "rbxassetid://91243391632500",
		size = Vector3.new(2.36, 1.72, 1.52),
		color = Color3.fromRGB(138, 92, 48),
		material = Enum.Material.Wood,
		reward = 75,
		hero = false,
	},
	{
		key = "Pot",
		label = "Ancient Pot",
		meshId = "rbxassetid://85065274722830",
		size = Vector3.new(1.62, 2.53, 2.00),
		color = Color3.fromRGB(176, 118, 80),
		material = Enum.Material.Slate,
		reward = 35,
		hero = false,
	},
	{
		key = "CrystalCluster",
		label = "Ice Crystals",
		meshId = "rbxassetid://138630431161362",
		size = Vector3.new(2.72, 3.29, 2.27),
		color = Color3.fromRGB(120, 226, 240),
		material = Enum.Material.Glass,
		reward = 25,
		hero = false,
	},

	-- Pyramid.
	{
		key = "Sarcophagus",
		label = "Golden Sarcophagus",
		meshId = "rbxassetid://106340451719108",
		size = Vector3.new(5.81, 2.06, 2.00),
		color = Color3.fromRGB(218, 176, 72),
		material = Enum.Material.Metal,
		reward = 120,
		hero = true,
	},
	{
		key = "Obelisk",
		label = "Fallen Obelisk",
		meshId = "rbxassetid://130292373189861",
		size = Vector3.new(1.90, 9.60, 1.90),
		color = Color3.fromRGB(208, 180, 124),
		material = Enum.Material.Sandstone,
		reward = 65,
		hero = false,
	},
	{
		key = "CanopicJar",
		label = "Canopic Jar",
		meshId = "rbxassetid://100464808102640",
		size = Vector3.new(1.60, 3.15, 1.36),
		color = Color3.fromRGB(226, 208, 168),
		material = Enum.Material.Marble,
		reward = 30,
		hero = false,
	},

	-- Troy.
	{
		key = "TrojanHorse",
		label = "The Trojan Horse",
		meshId = "rbxassetid://128969031432607",
		size = Vector3.new(9.88, 8.67, 3.04),
		color = Color3.fromRGB(118, 80, 44),
		material = Enum.Material.WoodPlanks,
		reward = 150,
		hero = true,
	},
	{
		key = "Statue",
		label = "Marble Statue",
		meshId = "rbxassetid://114786289770752",
		size = Vector3.new(1.70, 5.31, 2.04),
		color = Color3.fromRGB(224, 220, 206),
		material = Enum.Material.Marble,
		reward = 70,
		hero = false,
	},
	{
		key = "Column",
		label = "Toppled Column",
		meshId = "rbxassetid://79584606817366",
		size = Vector3.new(1.90, 7.82, 1.90),
		color = Color3.fromRGB(232, 228, 214),
		material = Enum.Material.Marble,
		reward = 40,
		hero = false,
	},
	{
		key = "Shield",
		label = "Bronze Shield",
		meshId = "rbxassetid://115152831185359",
		size = Vector3.new(3.00, 2.90, 1.06),
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
