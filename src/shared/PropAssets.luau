--!strict
--[[
	PropAssets - the things frozen inside the ice.

	Geometry is authored in assets/blender/cave_props.py, exported as a single
	FBX and uploaded once through Open Cloud (tools/upload_assets.py). One upload
	covers every prop, because Roblox turns each mesh object in an FBX into its
	own MeshPart inside one Model asset. The mesh ids below were read back out of
	that import and committed here, so nothing about the pipeline has to run
	again to build the game - the ids are just text in the repo like everything
	else.

	Two things about this that are easy to get wrong:

	  * Sizes are stored explicitly rather than trusted. Blender exports FBX in
	    centimetres, so every mesh arrives 100x too big - a 9-stud mammoth
	    imports at 934 studs. MeshPart.Size is writable and rescales the mesh, so
	    the authored dimensions are recorded here and applied on creation. That
	    also makes the props immune to the importer changing its scaling.
	  * No textures are exported, on purpose. MeshPart.Color only applies while a
	    mesh carries no texture, so colour lives here with the rest of the
	    palette instead of being baked into an uploaded image.
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
	reward: number, -- money paid on discovery
	hero: boolean, -- hero finds get the louder reveal
}

local PropAssets = {}

-- The Model asset the meshes came from. Kept for provenance and for re-reading
-- the ids if the props are ever re-exported.
PropAssets.MODEL_ASSET_ID = 130651218528429

PropAssets.DEFS = {
	{
		key = "Mammoth",
		label = "Frozen Mammoth",
		meshId = "rbxassetid://71375918586099",
		size = Vector3.new(9.34, 5.73, 4.40),
		color = Color3.fromRGB(124, 82, 54),
		material = Enum.Material.Sand,
		reward = 120,
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
		key = "CrystalCluster",
		label = "Ice Crystals",
		meshId = "rbxassetid://137808528159586",
		size = Vector3.new(2.72, 3.29, 2.27),
		color = Color3.fromRGB(120, 226, 240),
		material = Enum.Material.Glass,
		reward = 25,
		hero = false,
	},
	{
		key = "Pot",
		label = "Ancient Pot",
		meshId = "rbxassetid://109913268605436",
		size = Vector3.new(1.62, 2.53, 2.00),
		color = Color3.fromRGB(176, 118, 80),
		material = Enum.Material.Slate,
		reward = 35,
		hero = false,
	},
	{
		key = "Stalagmite",
		label = "Stalagmites",
		meshId = "rbxassetid://73429654182459",
		size = Vector3.new(2.80, 5.00, 2.67),
		color = Color3.fromRGB(118, 122, 132),
		material = Enum.Material.Slate,
		reward = 10,
		hero = false,
	},
}

local byKey: { [string]: PropDef } = {}
for _, def in PropAssets.DEFS do
	byKey[def.key] = def
end

function PropAssets.get(key: string): PropDef?
	return byKey[key]
end

-- Colour used for the sparkle that hints at something buried. Deliberately the
-- warm reward colour rather than the prop colour: it has to read against blue
-- ice at a distance, and it should mean "something is here" rather than
-- give away what.
PropAssets.HINT_COLOR = Feel.MONEY

return PropAssets
