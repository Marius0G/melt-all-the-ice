"""
Structure models for Melt All The Ice - the architecture each map is built around.

These replace hand-placed Part assemblies in src/server/SetPieces.luau. The
Parthenon alone was fifty-four Parts positioned by arithmetic; as a mesh it is
one, and it can have a real pediment and fluted columns instead of stacked boxes.

Authored at stud scale, so a mesh's Blender dimensions are the studs it should
occupy in game. Origins sit at the world origin like everything else, and each
structure is built standing on Z = 0 so it can be placed on the chamber floor
without a correction offset.

Beacons stay Parts. The finale lights one Part per map by swapping it to Neon
and attaching a light, so the pyramid's capstone and the temple's acroterion are
deliberately absent from these meshes and added on top in Luau.
"""

import bpy
import math

from props import box, cone, cylinder, join, sphere


def prism(name, radius, depth, location=(0, 0, 0), rotation=None, verts=3):
    """A triangular prism - the honest way to build a pediment or a pitched roof.

    Measured, because guessing at this got it wrong twice. A 3-vertex cylinder
    stands with its axis on Z and its apex at +X, and:

        (0, +-90, 0)  lays it along X but with the apex pointing sideways at +Y,
                      which renders as a vertical slab, not a roof
        (90, 0, 0)    apex up, ridge running along Y
        (90, 0, 90)   apex up, ridge running along X

    With radius r the triangle reaches r above its centre and r/2 below, so a
    roof sits at (wall top + r/2) to have its eaves meet the wall.
    """
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=location
    )
    obj = bpy.context.active_object
    obj.name = name
    if rotation:
        obj.rotation_euler = [math.radians(a) for a in rotation]
    return obj


# ---------------------------------------------------------------------------
# pyramid
# ---------------------------------------------------------------------------

def build_pyramid():
    """Great pyramid, 128 studs at the base and 48 tall.

    Stops short of its own apex on purpose: the capstone is the map's beacon and
    has to stay a Part so the finale can light it.
    """
    parts = []
    base, courses, rise = 128.0, 16, 3.0

    for index in range(courses):
        shrink = index / courses
        width = base * (1.0 - shrink * 0.9)
        parts.append(box("course%d" % index,
                         scale=(width / 2, width / 2, rise / 2),
                         location=(0, 0, index * rise + rise / 2)))

    # Casing stones surviving near the base, which is what real pyramids look
    # like and stops the steps reading as a perfectly regular staircase.
    for index in range(5):
        width = base * (1.0 - (index / courses) * 0.9) + 1.2
        parts.append(box("casing%d" % index,
                         scale=(width / 2, width / 2, rise * 0.44),
                         location=(0, 0, index * rise + rise / 2)))

    # Entrance on the -Y face: a recessed portal with a lintel.
    parts.append(box("jambL", scale=(1.6, 2.0, 5.0), location=(-5.0, -base * 0.44, 5.0)))
    parts.append(box("jambR", scale=(1.6, 2.0, 5.0), location=(5.0, -base * 0.44, 5.0)))
    parts.append(box("lintel", scale=(7.0, 2.2, 1.4), location=(0, -base * 0.44, 11.0)))
    parts.append(box("ramp", scale=(7.0, 5.0, 0.6), location=(0, -base * 0.5 - 3.0, 0.6)))

    return join("Structure_Pyramid", parts)


# ---------------------------------------------------------------------------
# parthenon
# ---------------------------------------------------------------------------

def build_parthenon():
    """Doric temple, about 78 x 36 studs and 34 tall including the pediment."""
    parts = []
    length, depth = 72.0, 32.0

    # Crepidoma: three steps.
    for index in range(3):
        parts.append(box("step%d" % index,
                         scale=((length + 8 - index * 3) / 2, (depth + 8 - index * 3) / 2, 0.9),
                         location=(0, 0, 0.9 + index * 1.8)))

    floor_z = 5.4
    column_height = 17.0

    # Peristyle. Corners are shared, so only the edge positions get a column.
    across, along = 8, 15
    gap_x = (length - 8) / (across - 1)
    gap_y = (depth - 8) / (along - 1)
    for ax in range(across):
        for ay in range(along):
            if not (ax in (0, across - 1) or ay in (0, along - 1)):
                continue
            x = -(length - 8) / 2 + ax * gap_x
            y = -(depth - 8) / 2 + ay * gap_y
            parts.append(cylinder("col%d_%d" % (ax, ay), radius=1.5, depth=column_height,
                                  location=(x, y, floor_z + column_height / 2), verts=10))
            # Capital.
            parts.append(box("cap%d_%d" % (ax, ay), scale=(1.9, 1.9, 0.5),
                             location=(x, y, floor_z + column_height + 0.4)))

    entab_z = floor_z + column_height + 0.9
    parts.append(box("architrave", scale=(length / 2, depth / 2, 1.5),
                     location=(0, 0, entab_z + 1.5)))
    parts.append(box("frieze", scale=(length / 2 + 0.4, depth / 2 + 0.4, 1.2),
                     location=(0, 0, entab_z + 4.2)))
    parts.append(box("cornice", scale=(length / 2 + 1.6, depth / 2 + 1.6, 0.9),
                     location=(0, 0, entab_z + 6.3)))

    # A real gable rather than stacked boxes, running the length of the temple.
    roof_z = entab_z + 7.2
    # Ridge along the long axis, so the gable ends face the short sides - which
    # is where the front of a Greek temple is.
    parts.append(prism("gable", radius=9.0, depth=length,
                       location=(0, 0, roof_z + 4.5), rotation=(90, 0, 90), verts=3))

    # Cella walls inside the colonnade, so it is not hollow when seen through.
    parts.append(box("cella", scale=(length / 2 - 9, depth / 2 - 8, column_height / 2),
                     location=(0, 0, floor_z + column_height / 2)))

    return join("Structure_Parthenon", parts)


def build_acropolis():
    """The plinth the temple stands on: 104 studs square, 18 tall, three tiers."""
    parts = []
    for index in range(3):
        width = 104.0 - index * 9
        parts.append(box("tier%d" % index, scale=(width / 2, width / 2, 3.0),
                         location=(0, 0, index * 6.0 + 3.0)))
    # A stair up the -Y face.
    for index in range(9):
        parts.append(box("stair%d" % index, scale=(9.0, 1.4, 1.0),
                         location=(0, -52.0 - index * 1.4 + 1.4, 18.0 - index * 2.0 - 1.0)))
    return join("Structure_Acropolis", parts)


# ---------------------------------------------------------------------------
# town
# ---------------------------------------------------------------------------

def build_hut():
    """Mud-brick house, about 8 studs square and 9 tall with the roof."""
    parts = [box("walls", scale=(4.0, 4.0, 3.0), location=(0, 0, 3.0))]

    # Ridge along Y, so the gable end faces the door on -Y.
    parts.append(prism("roof", radius=3.4, depth=9.0,
                       location=(0, 0, 7.4), rotation=(90, 0, 0), verts=3))

    # Doorway on -Y, recessed by sitting the frame proud of the wall.
    parts.append(box("lintel", scale=(1.3, 0.4, 0.35), location=(0, -4.1, 3.6)))
    parts.append(box("jambL", scale=(0.3, 0.4, 1.6), location=(-1.1, -4.1, 1.6)))
    parts.append(box("jambR", scale=(0.3, 0.4, 1.6), location=(1.1, -4.1, 1.6)))

    # Roof beams poking through the gable, and a window.
    for index in range(3):
        parts.append(cylinder("beam%d" % index, radius=0.16, depth=9.6,
                              location=(-2.2 + index * 2.2, 0, 5.4),
                              rotation=(90, 0, 0), verts=6))
    parts.append(box("sill", scale=(0.9, 0.3, 0.2), location=(4.05, 1.0, 3.6)))

    return join("Structure_Hut", parts)


def build_causeway():
    """A paved road slab, 14 x 18 studs, with visible joints."""
    parts = [box("bed", scale=(7.0, 9.0, 0.5), location=(0, 0, 0.5))]
    for row in range(3):
        for col in range(2):
            parts.append(box("slab%d_%d" % (row, col), scale=(3.2, 2.7, 0.35),
                             location=(-3.4 + col * 6.8, -5.6 + row * 5.6, 1.15)))
    # Kerbs.
    for side in (-1, 1):
        parts.append(box("kerb%d" % side, scale=(0.6, 9.0, 0.7),
                         location=(side * 6.6, 0, 1.2)))
    return join("Structure_Causeway", parts)


# ---------------------------------------------------------------------------
# cave dressing
# ---------------------------------------------------------------------------

def build_campfire():
    """Fire ring and log pile, about 6 studs across.

    The flame itself is the map's beacon and stays a Part, so this is the cold
    hearth it lights.
    """
    parts = []
    for index in range(9):
        angle = index * (math.pi * 2 / 9)
        parts.append(sphere("ring%d" % index, radius=0.62,
                            location=(math.cos(angle) * 2.5, math.sin(angle) * 2.5, 0.4),
                            scale=(1.0, 1.0, 0.7), subdiv=1))
    for index in range(4):
        angle = index * (math.pi / 4) + 0.3
        parts.append(cylinder("log%d" % index, radius=0.34, depth=3.6,
                              location=(0, 0, 0.75),
                              rotation=(0, 78, math.degrees(angle)), verts=6))
    parts.append(box("ash", scale=(1.5, 1.5, 0.16), location=(0, 0, 0.16)))
    return join("Structure_Campfire", parts)


def build_spawn_pad():
    """Stone dais, 8 studs across, that the player materialises on."""
    parts = [cylinder("dais", radius=4.0, depth=0.9, location=(0, 0, 0.45), verts=12)]
    parts.append(cylinder("rim", radius=4.3, depth=0.45, location=(0, 0, 0.22), verts=12))
    # Radial paving, so it reads as built rather than poured.
    for index in range(8):
        angle = index * (math.pi * 2 / 8)
        parts.append(box("spoke%d" % index, scale=(0.16, 3.4, 0.1),
                         location=(math.cos(angle) * 0, math.sin(angle) * 0, 0.95),
                         rotation=(0, 0, math.degrees(angle))))
    parts.append(cylinder("boss", radius=1.1, depth=0.3, location=(0, 0, 1.05), verts=10))
    return join("Structure_SpawnPad", parts)


STRUCTURE_GROUPS = {
    "pyramid": [build_pyramid],
    "parthenon": [build_parthenon],
    "acropolis": [build_acropolis],
    "hut": [build_hut],
    "causeway": [build_causeway],
    "campfire": [build_campfire],
    "spawnpad": [build_spawn_pad],
}
