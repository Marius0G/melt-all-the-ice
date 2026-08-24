--!strict
--[[
	StructureAssets - the architecture meshes.

	Authored in assets/blender/structures.py and uploaded with everything else as
	one asset. These replace hand-placed Part assemblies: the Parthenon alone was
	fifty-four Parts positioned by arithmetic and is now one mesh with real
	fluted columns and a proper gable.

	Sizes are the authored dimensions, in studs, in Roblox axes. They are not
	derived from what the importer reports - see ToolAssets for why that would
	break on the next upload.

	Every structure is modelled standing on its own base, so placing one means
	putting its centre at (floor + size.Y / 2).
]]

export type StructureDef = {
	meshId: string,
	size: Vector3,
}

local StructureAssets = {}

local MODELS: { [string]: StructureDef } = {
	acropolis = {
		meshId = "rbxassetid://100349064213884",
		size = Vector3.new(104.000, 18.000, 115.200),
	},
	boulder = {
		meshId = "rbxassetid://115535085724856",
		size = Vector3.new(4.884, 3.175, 3.573),
	},
	brazier = {
		meshId = "rbxassetid://129207344684821",
		size = Vector3.new(2.240, 3.031, 2.130),
	},
	campfire = {
		meshId = "rbxassetid://117520455416288",
		size = Vector3.new(5.958, 1.446, 5.979),
	},
	causeway = {
		meshId = "rbxassetid://119212885550345",
		size = Vector3.new(14.400, 1.900, 18.000),
	},
	hut = {
		meshId = "rbxassetid://108635275617789",
		size = Vector3.new(8.950, 10.800, 9.600),
	},
	palm = {
		meshId = "rbxassetid://113602670998211",
		size = Vector3.new(12.140, 12.258, 12.452),
	},
	parthenon = {
		meshId = "rbxassetid://120447867815477",
		size = Vector3.new(80.000, 44.000, 40.000),
	},
	pyramid = {
		meshId = "rbxassetid://88681912974953",
		size = Vector3.new(129.200, 48.000, 136.600),
	},
	spawnpad = {
		meshId = "rbxassetid://90078146166774",
		size = Vector3.new(8.600, 1.205, 8.600),
	},
	timber = {
		meshId = "rbxassetid://96041284861257",
		size = Vector3.new(9.200, 9.060, 0.920),
	},
	walltorch = {
		meshId = "rbxassetid://103541046928360",
		size = Vector3.new(0.880, 2.575, 1.592),
	},
}

StructureAssets.MODELS = MODELS

function StructureAssets.get(key: string): StructureDef?
	return MODELS[key]
end

return StructureAssets
