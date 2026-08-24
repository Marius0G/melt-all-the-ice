"""
Tool models for Melt All The Ice.

Built from the same primitive kit as the finds (see props.py), and exported
through build.py so the whole game ships as one uploaded asset.

Two conventions everything here follows, and both matter:

  * The grip sits at the Blender origin. join() sets each object's origin to the
    world origin, so authoring around (0, 0, 0) is what lets Roblox weld the
    mesh into the hand without a correction offset.
  * Tools point along -Y. Blender is Z-up and Roblox is Y-up, so the exporter
    maps Blender (x, y, z) to Roblox (x, z, y) - which makes Blender -Y the
    Roblox -Z the Part-built tools already pointed down.

Most tools are two objects, a body and a head, deliberately: skins recolour by
part name, so keeping the haft and the blade separate is what allows a wooden
handle with a stone edge rather than a single flat colour. build.py lays a
tool's objects out together so their relative positions survive the export.
"""

import bpy
import math

from props import blade, box, cone, cylinder, frustum, join, sphere


def torus(name, major, minor, location=(0, 0, 0), rotation=None, major_segments=8, minor_segments=5):
    """A ring. Chain links are the one shape the box-and-cylinder kit cannot fake."""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    if rotation:
        obj.rotation_euler = [math.radians(a) for a in rotation]
    return obj


# ---------------------------------------------------------------------------
# stone
# ---------------------------------------------------------------------------

def build_stone_body():
    """A chipped hand stone, about 1.6 studs.

    A low-subdivision icosphere is already a faceted rock; the extra chips just
    break the silhouette so it does not read as a ball.
    """
    parts = [sphere("core", radius=0.8, location=(0, 0, 0), scale=(1.0, 0.85, 0.7), subdiv=1)]
    chips = [
        (0.55, -0.35, 0.2, 0.3),
        (-0.5, 0.3, -0.15, 0.26),
        (0.1, 0.55, 0.25, 0.22),
        (-0.25, -0.5, -0.25, 0.24),
    ]
    for index, (x, y, z, size) in enumerate(chips):
        parts.append(box("chip%d" % index, scale=(size, size, size * 0.7),
                         location=(x, y, z),
                         rotation=(index * 27, index * 41, index * 33)))
    return join("Tool_Stone_Body", parts)


# ---------------------------------------------------------------------------
# axe
# ---------------------------------------------------------------------------

def build_axe_body():
    """Haft, about 3.2 studs, with the lashing that holds the head on."""
    parts = [cylinder("haft", radius=0.15, depth=3.2, location=(0, 0, 0),
                      rotation=(90, 0, 0), verts=8)]
    # Slight swell at the butt so it does not slide out of the hand.
    parts.append(cylinder("butt", radius=0.2, depth=0.3, location=(0, 1.5, 0),
                          rotation=(90, 0, 0), verts=8))
    # Rings, not plates. Square boxes 0.40 across a 0.30 haft stood proud of it
    # on all four sides, and three of them in a row read as fins.
    for index in range(3):
        parts.append(torus("lash%d" % index, major=0.185, minor=0.05,
                           location=(0, -1.16 + index * 0.20, 0),
                           rotation=(90, 0, 0),
                           major_segments=8, minor_segments=4))
    return join("Tool_Axe_Body", parts)


def build_axe_head():
    """Knapped stone blade: thick and short at the haft, thin and tall at the edge."""
    parts = [box("poll", scale=(0.14, 0.20, 0.30), location=(0, -1.16, -0.05))]
    parts.append(box("cheek", scale=(0.17, 0.26, 0.42), location=(0, -1.48, 0)))
    # One honest taper. This was three stacked slabs, each thinner and wider
    # than the last, and every step caught the light - it read as a stack of
    # fins rather than an edge. See props.blade for why a frustum cannot do it.
    parts.append(blade("edge", near=(0.16, 0.44, -1.62), far=(0.05, 0.78, -2.44)))
    return join("Tool_Axe_Head", parts)


# ---------------------------------------------------------------------------
# torch
# ---------------------------------------------------------------------------

def build_torch_body():
    """Shaft with a pitch-soaked wrap at the business end."""
    parts = [cylinder("shaft", radius=0.13, depth=2.8, location=(0, 0, 0),
                      rotation=(90, 0, 0), verts=8)]
    # The wrap flares toward the flame, so the head has a direction to it.
    parts.append(frustum("wrap", radius1=0.20, radius2=0.34, depth=0.95,
                         location=(0, -1.15, 0), rotation=(90, 0, 0), verts=8))
    # Binding sized to the wrap where it actually sits. The old bands were
    # squares wider than the cylinder they were meant to be tied around, spaced
    # further apart than they were thick, so they hung off it as loose plates.
    for index, (y, major) in enumerate(((-0.80, 0.235), (-1.35, 0.315))):
        parts.append(torus("band%d" % index, major=major, minor=0.055,
                           location=(0, y, 0), rotation=(90, 0, 0),
                           major_segments=8, minor_segments=4))
    return join("Tool_Torch_Body", parts)


# ---------------------------------------------------------------------------
# campfire
# ---------------------------------------------------------------------------

def build_campfire_body():
    """A bundle of kindling carried under the arm, about 2.6 studs."""
    parts = []
    for index in range(5):
        angle = index * (math.pi * 2 / 5)
        parts.append(cylinder("log%d" % index, radius=0.15, depth=2.4,
                              location=(math.cos(angle) * 0.26, 0, math.sin(angle) * 0.26),
                              rotation=(90, 0, math.degrees(angle) * 0.06),
                              verts=6))
    # Two ties, which is what makes it read as a bundle rather than a mess.
    for index, y in enumerate((0.55, -0.55)):
        parts.append(torus("tie%d" % index, major=0.44, minor=0.07,
                           location=(0, y, 0), rotation=(90, 0, 0),
                           major_segments=8, minor_segments=4))
    return join("Tool_Campfire_Body", parts)


# ---------------------------------------------------------------------------
# scepter
# ---------------------------------------------------------------------------

def build_scepter_body():
    """A long gold staff, about 4 studs."""
    parts = [cylinder("staff", radius=0.11, depth=3.8, location=(0, 0, 0),
                      rotation=(90, 0, 0), verts=8)]
    parts.append(cylinder("collar", radius=0.18, depth=0.22, location=(0, -1.4, 0),
                          rotation=(90, 0, 0), verts=8))
    parts.append(cylinder("ferrule", radius=0.16, depth=0.3, location=(0, 1.85, 0),
                          rotation=(90, 0, 0), verts=8))
    return join("Tool_Scepter_Body", parts)


def build_scepter_head():
    """The sun disc, rayed. Ra is a sun god; the disc is the whole read."""
    parts = [cylinder("disc", radius=0.62, depth=0.14, location=(0, -2.15, 0),
                      rotation=(90, 0, 0), verts=12)]
    parts.append(torus("rim", major=0.66, minor=0.07, location=(0, -2.15, 0),
                       rotation=(90, 0, 0), major_segments=12, minor_segments=4))
    for index in range(8):
        angle = index * (math.pi * 2 / 8)
        parts.append(box("ray%d" % index, scale=(0.06, 0.05, 0.28),
                         location=(math.cos(angle) * 0.88, -2.15, math.sin(angle) * 0.88),
                         rotation=(0, math.degrees(angle) + 90, 0)))
    return join("Tool_Scepter_Head", parts)


# ---------------------------------------------------------------------------
# greek fire
# ---------------------------------------------------------------------------

def build_greekfire_body():
    """Siphon: a clay vessel slung on a short shaft."""
    parts = [cylinder("shaft", radius=0.13, depth=2.2, location=(0, 0, 0),
                      rotation=(90, 0, 0), verts=8)]
    parts.append(sphere("vessel", radius=0.46, location=(0, -0.75, 0),
                        scale=(1.0, 1.15, 1.0), subdiv=2))
    parts.append(cylinder("collar", radius=0.2, depth=0.3, location=(0, -1.3, 0),
                          rotation=(90, 0, 0), verts=8))
    for index, y in enumerate((-0.45, -0.95)):
        parts.append(torus("hoop%d" % index, major=0.44, minor=0.05,
                           location=(0, y, 0), rotation=(90, 0, 0),
                           major_segments=10, minor_segments=4))
    return join("Tool_Greekfire_Body", parts)


def build_greekfire_head():
    """The bronze nozzle the fire comes out of."""
    parts = [cone("nozzle", radius=0.22, depth=0.7, location=(0, -1.75, 0),
                  rotation=(-90, 0, 0), verts=8)]
    parts.append(cylinder("throat", radius=0.13, depth=0.4, location=(0, -1.45, 0),
                          rotation=(90, 0, 0), verts=8))
    return join("Tool_Greekfire_Head", parts)


# ---------------------------------------------------------------------------
# chains of kratos
# ---------------------------------------------------------------------------

def build_chains_body():
    """Wrapped grip trailing a run of chain links."""
    parts = [cylinder("grip", radius=0.17, depth=1.3, location=(0, 0.5, 0),
                      rotation=(90, 0, 0), verts=8)]
    # Same fix as the axe lashing: rings that grip, not squares that hang off.
    for index in range(3):
        parts.append(torus("wrap%d" % index, major=0.205, minor=0.05,
                           location=(0, 0.95 - index * 0.30, 0),
                           rotation=(90, 0, 0),
                           major_segments=8, minor_segments=4))
    # Links alternate 90 degrees, which is what makes a chain read as a chain.
    for index in range(7):
        parts.append(torus("link%d" % index, major=0.17, minor=0.055,
                           location=(0, -0.3 - index * 0.28, 0),
                           rotation=(90, 0, 90 * (index % 2)),
                           major_segments=8, minor_segments=4))
    return join("Tool_Chains_Body", parts)


def build_chains_head():
    """The blade on the end. Absurd, per the brief."""
    parts = [box("tang", scale=(0.09, 0.2, 0.14), location=(0, -2.4, 0))]
    parts.append(box("blade", scale=(0.07, 0.55, 0.34), location=(0, -3.0, 0.08)))
    parts.append(cone("point", radius=0.3, depth=0.8, location=(0, -3.75, 0.12),
                      rotation=(-90, 0, 0), verts=4))
    # Barbs down the back edge.
    for index in range(3):
        parts.append(cone("barb%d" % index, radius=0.12, depth=0.3,
                          location=(0, -2.8 - index * 0.4, -0.24),
                          rotation=(-120, 0, 0), verts=3))
    return join("Tool_Chains_Head", parts)


# Grouped so build.py lays each tool's objects out together and their relative
# positions survive the export.
TOOL_GROUPS = {
    "stone": [build_stone_body],
    "axe": [build_axe_body, build_axe_head],
    "torch": [build_torch_body],
    "campfire": [build_campfire_body],
    "scepter": [build_scepter_body, build_scepter_head],
    "greekfire": [build_greekfire_body, build_greekfire_head],
    "chains": [build_chains_body, build_chains_head],
}
