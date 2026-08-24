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

-- Quarter turns only, but on all three axes: a cube stays axis-aligned under any
-- multiple of 90 degrees, so this is free variety. Three variants spun about one
-- axis gave twelve looks and the repeat was visible across a wall; three about
-- all three axes gives seventy-two.
--
-- Any angle that is not a multiple of 90 would rotate the bounding box off the
-- grid and reopen the seam the corners exist to close.
function IceAssets.spin(cell: number): CFrame
	local x = cell % 4
	local y = (cell // 4) % 4
	local z = (cell // 16) % 4
	return CFrame.Angles(math.rad(90 * x), math.rad(90 * y), math.rad(90 * z))
end

return IceAssets
