"""
The ice chunk itself - the most-seen surface in the game.

A chunk used to be a plain Part cube, which reads as Minecraft rather than as
ice. These are cut-gemstone blocks: every face is four triangles meeting at a
recessed centre, so each facet catches the light at its own angle and a wall of
them sparkles instead of presenting one flat slab.

Two constraints shape the geometry, and both are load-bearing:

  * **The eight corners stay at exactly +-0.5.** Chunks sit edge to edge on the
    grid, and the interior ones are culled to Transparency 1 rather than
    destroyed. If a mesh pulled its corners in, the gap between two neighbours
    would look straight through the invisible chunk behind and out into the
    chamber. Corners at full extent means neighbours meet along their whole
    shared edge, and the recessed faces only ever open a lens-shaped void that
    is sealed on all four sides.

  * **Nothing may protrude past +-0.5.** The bounding box is what MeshPart.Size
    maps onto the cell, so anything sticking out would shrink the rest of the
    block to compensate and reopen the same gap.

Raycasts read a MeshPart's *collision* geometry, so these are loaded with
CollisionFidelity.Box and every ray still hits a perfect cube. That is what
makes a shaped chunk safe at all: an earlier attempt at shrinking damaged chunks
let rays slip between them into the chunk behind, and mining silently stopped
working. Shape is free here only because collision does not follow it.

Authored as a unit cube; IceField sets Size to the map's chunk size.
"""

import bmesh
import bpy

# The eight corners, in the order the face table below indexes them.
CORNERS = [
    (-0.5, -0.5, -0.5),
    (0.5, -0.5, -0.5),
    (0.5, 0.5, -0.5),
    (-0.5, 0.5, -0.5),
    (-0.5, -0.5, 0.5),
    (0.5, -0.5, 0.5),
    (0.5, 0.5, 0.5),
    (-0.5, 0.5, 0.5),
]

# Each face as (corner indices in winding order, axis, sign). The axis is the
# one the face is perpendicular to, and the sign says which end it sits at.
FACES = [
    ((0, 1, 2, 3), 2, -1),  # -Z
    ((4, 5, 6, 7), 2, +1),  # +Z
    ((0, 1, 5, 4), 1, -1),  # -Y
    ((3, 2, 6, 7), 1, +1),  # +Y
    ((0, 3, 7, 4), 0, -1),  # -X
    ((1, 2, 6, 5), 0, +1),  # +X
]


def _mesh_from(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    # from_pydata trusts the winding it is given, and a face wound inward
    # renders black. Six of them by hand is exactly the kind of thing to get
    # wrong once and not notice.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def crystal(name, depth, skew):
    """One faceted block.

    `depth` is how far each face centre sits below the surface, and `skew`
    slides those centres off-middle so the facets are not four identical
    triangles. Both stay well inside the corners, which never move.
    """
    verts = list(CORNERS)
    faces = []

    for index, (corner_ids, axis, sign) in enumerate(FACES):
        centre = [0.0, 0.0, 0.0]
        centre[axis] = sign * (0.5 - depth)
        # Push the centre off-middle in the face's own two axes. Varying it per
        # face stops opposite faces from mirroring each other.
        others = [a for a in (0, 1, 2) if a != axis]
        centre[others[0]] = skew * (1 if index % 2 == 0 else -1)
        centre[others[1]] = skew * (1 if index % 3 == 0 else -1)

        hub = len(verts)
        verts.append(tuple(centre))
        for step in range(4):
            a = corner_ids[step]
            b = corner_ids[(step + 1) % 4]
            faces.append((a, b, hub))

    return _mesh_from(name, verts, faces)


def build_ice_a():
    """The common block - shallow facets, nearly symmetric."""
    return crystal("Ice_Chunk_A", depth=0.07, skew=0.05)


def build_ice_b():
    """Deeper cut, so a field of these does not repeat visibly."""
    return crystal("Ice_Chunk_B", depth=0.11, skew=0.09)


def build_ice_c():
    """Shallowest, for the chunks that want to read as almost smooth."""
    return crystal("Ice_Chunk_C", depth=0.05, skew=0.12)


ICE_GROUPS = {
    "a": [build_ice_a],
    "b": [build_ice_b],
    "c": [build_ice_c],
}
