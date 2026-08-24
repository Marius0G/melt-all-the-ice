--!strict
--[[
	ToolAssets - the mesh each tool is made of.

	Authored in assets/blender/tools.py and uploaded with everything else as one
	asset (see PropAssets for the pipeline). Sizes and offsets come from the
	manifest Blender writes, never from what the importer reports: Roblox
	normalises a whole model on import and the factor depends on what else is in
	the file - adding the pyramid changed it from 100x to about 15x - so anything
	derived from the imported dimensions would silently break on the next upload.

	Most tools are two meshes. Skins recolour by part name, so keeping the haft
	and the head separate is what allows a wooden handle with a stone edge rather
	than one flat colour. They were authored around a shared origin, and `offset`
	is the difference between their geometry centres - which is exactly what the
	engine needs to place one against the other.

	Tools point along -Z, so a fire tool's flame sits at a negative flameAt.
]]

export type Piece = {
	meshId: string,
	size: Vector3,
	offset: Vector3,
}

export type ToolModel = {
	body: Piece,
	head: Piece?,
	flameAt: number?,
	flameSize: number?,
}

local ToolAssets = {}

local MODELS: { [string]: ToolModel } = {
	stone = {
		body = {
			meshId = "rbxassetid://131882264236404",
			size = Vector3.new(1.710, 1.155, 1.690),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
	},
	axe = {
		body = {
			meshId = "rbxassetid://97151578950517",
			size = Vector3.new(0.436, 0.400, 3.250),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		head = {
			meshId = "rbxassetid://130083521107059",
			size = Vector3.new(0.340, 1.160, 1.420),
			offset = Vector3.new(0.000, 0.040, -1.695),
		},
	},
	torch = {
		body = {
			meshId = "rbxassetid://87212374785746",
			size = Vector3.new(0.580, 0.580, 3.141),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		flameAt = -1.75,
		flameSize = 0.72,
	},
	campfire = {
		body = {
			meshId = "rbxassetid://105291060449299",
			size = Vector3.new(1.167, 1.020, 2.413),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		flameAt = -1.55,
		flameSize = 1.05,
	},
	scepter = {
		body = {
			meshId = "rbxassetid://84573430805623",
			size = Vector3.new(0.360, 0.360, 3.900),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		head = {
			meshId = "rbxassetid://77529088388003",
			size = Vector3.new(2.320, 2.320, 0.140),
			offset = Vector3.new(0.000, 0.000, -2.200),
		},
		flameAt = -2.20,
		flameSize = 0.95,
	},
	greekfire = {
		body = {
			meshId = "rbxassetid://100075282893026",
			size = Vector3.new(0.980, 0.932, 2.550),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		head = {
			meshId = "rbxassetid://94625433258830",
			size = Vector3.new(0.440, 0.440, 0.850),
			offset = Vector3.new(0.000, 0.000, -1.500),
		},
		flameAt = -2.05,
		flameSize = 0.85,
	},
	chains = {
		body = {
			meshId = "rbxassetid://133989476789197",
			size = Vector3.new(0.450, 0.450, 3.185),
			offset = Vector3.new(0.000, 0.000, 0.000),
		},
		head = {
			meshId = "rbxassetid://110946927550976",
			size = Vector3.new(0.600, 0.735, 1.950),
			offset = Vector3.new(0.000, 0.052, -2.732),
		},
		flameAt = -3.20,
		flameSize = 1.00,
	},
}

ToolAssets.MODELS = MODELS

function ToolAssets.get(key: string): ToolModel?
	return MODELS[key]
end

return ToolAssets
