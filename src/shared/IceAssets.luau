--!strict
--[[
	IceAssets - the chunk meshes.

	Authored in assets/blender/ice.py and uploaded with everything else. Each is
	a cut-gemstone block: a cube whose face centres are recessed so every facet
	takes the light at its own angle, while all eight corners stay out at the
	full extent of the cell.

	The corners are the load-bearing part. Chunks tile edge to edge, and interior
	ones are hidden by going to Transparency 1 rather than being destroyed, so a
	mesh that pulled its corners in would let you see through the seam, past the
	invisible chunk behind it, and out into the chamber. Every variant is
	asserted to be an exact unit cube when this file is generated, for that
	reason.

	Shaping a chunk at all is only safe because raycasts read a MeshPart's
	*collision* geometry: loaded with CollisionFidelity.Box, every ray still hits
	a perfect cube no matter what the mesh looks like. An earlier attempt at
	changing chunk geometry - shrinking damaged ones - had no such protection and
	let rays slip between chunks into the one behind, which silently broke mining.

	IceField sets Size to the map's chunk size.
]]

local IceAssets = {}

local VARIANTS: { string } = {
	"rbxassetid://81271805074865",
	"rbxassetid://129013270441006",
	"rbxassetid://118784576824086",
}

IceAssets.VARIANTS = VARIANTS

-- Deterministic, so server and client agree on which block sits where and a
-- rebuild reproduces the same field exactly (AD-3).
function IceAssets.pick(cell: number): string
	return VARIANTS[(cell % #VARIANTS) + 1]
end

-- Quarter turns only. Any other angle rotates the bounding box off the grid and
-- reopens the seam the corners exist to close.
function IceAssets.spin(cell: number): CFrame
	local quarter = (cell // #VARIANTS) % 4
	return CFrame.Angles(0, math.rad(90 * quarter), 0)
end

return IceAssets
