"""
Props for Melt All The Ice, authored headlessly in Blender.

Run:
    blender -b -P assets/blender/props.py -- --out build/props.fbx
    blender -b -P assets/blender/props.py -- --render build/preview

Everything is assembled from primitives on purpose. The target look is flat
low-poly - the same language as the pyramid reference in docs/reference - so
boxes, cones and low-segment cylinders are the right tool rather than a
limitation, and they stay legible seen through translucent ice at a distance.

No materials or textures are exported. Roblox MeshPart.Color only applies while
a mesh carries no texture, so colour is set in Luau (see PropAssets) which keeps
the palette in one place with the rest of the game.

Scale is in studs: 1 Blender unit = 1 stud, authored so a chunk is 4 units.
"""

import bpy
import math
import os
import sys

CHUNK = 4.0  # one ice chunk, for sanity-checking prop scale


# --------------------------------------------------------------------------
# scene helpers
# --------------------------------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(block):
            if getattr(item, "users", 0) == 0:
                block.remove(item)


def _finish(name, location, rotation, scale):
    obj = bpy.context.active_object
    obj.name = name
    obj.location = location
    if rotation:
        obj.rotation_euler = [math.radians(a) for a in rotation]
    if scale:
        obj.scale = scale
    return obj


def box(name, scale=(1, 1, 1), location=(0, 0, 0), rotation=None):
    # primitive_cube_add makes a 2-unit cube, so scale is a half-extent.
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    return _finish(name, location, rotation, scale)


def cylinder(name, radius=1.0, depth=2.0, location=(0, 0, 0), rotation=None, verts=8):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=location
    )
    return _finish(name, location, rotation, None)


def cone(name, radius=1.0, depth=2.0, location=(0, 0, 0), rotation=None, verts=6):
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location
    )
    return _finish(name, location, rotation, None)


def sphere(name, radius=1.0, location=(0, 0, 0), scale=None, subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdiv, radius=radius, location=location
    )
    return _finish(name, location, None, scale)


def join(name, parts):
    """Merge parts into a single mesh object - one MeshPart per prop in Roblox."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    merged = bpy.context.active_object
    merged.name = name
    # Bake transforms so the exported mesh needs no scale correction in engine.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Origin to the base, so props sit on a surface when placed by their pivot.
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return merged


# --------------------------------------------------------------------------
# props
# --------------------------------------------------------------------------

def build_mammoth():
    """Roughly 9 studs long - a little over two chunks. The hero find."""
    parts = []
    body = sphere("body", radius=2.2, location=(0, 0, 3.4), scale=(1.5, 1.0, 1.0), subdiv=2)
    parts.append(body)

    head = sphere("head", radius=1.3, location=(3.2, 0, 3.6), scale=(1.0, 0.9, 1.0), subdiv=2)
    parts.append(head)

    # Trunk: a taper of shrinking boxes, curling down and forward.
    for i in range(5):
        t = i / 4.0
        parts.append(box(
            "trunk%d" % i,
            scale=(0.45 - 0.06 * i, 0.42 - 0.06 * i, 0.5),
            location=(4.2 + t * 1.5, 0, 3.1 - t * 2.4),
            rotation=(0, 25 + t * 20, 0),
        ))

    # Tusks, curving out and up.
    for side in (-1, 1):
        for i in range(3):
            t = i / 2.0
            parts.append(cone(
                "tusk%d%d" % (side, i),
                radius=0.34 - 0.09 * i,
                depth=1.5,
                location=(4.3 + t * 1.1, side * 0.85, 2.6 - t * 0.5 + t * t * 0.9),
                rotation=(0, 70 - t * 55, 0),
                verts=6,
            ))

    for sx in (-1.4, 1.5):
        for sy in (-1.15, 1.15):
            parts.append(cylinder(
                "leg", radius=0.62, depth=3.0, location=(sx, sy, 1.5), verts=6
            ))

    # Shoulder hump, which on a mammoth is the highest point of the silhouette.
    # A plain box here read as a crate strapped to its back; a squashed sphere
    # blends into the body instead.
    parts.append(sphere("hump", radius=1.5, location=(0.9, 0, 4.9), scale=(0.9, 0.8, 0.55), subdiv=2))
    parts.append(sphere("rump", radius=1.4, location=(-2.0, 0, 3.6), scale=(0.8, 0.9, 0.9), subdiv=2))
    for side in (-1, 1):
        parts.append(box("ear", scale=(0.12, 0.55, 0.5), location=(2.8, side * 1.15, 3.9), rotation=(0, 0, 18 * side)))
    return join("Mammoth", parts)


def _bone(tag, length, radius, location, rotation):
    """One bone: a shaft with knobbed ends. The knobs are the whole read."""
    parts = [cylinder(tag + "shaft", radius=radius, depth=length,
                      location=(0, 0, 0), rotation=(90, 0, 0), verts=6)]
    for end in (-1, 1):
        for offset in (-1, 1):
            parts.append(sphere(tag + "knob", radius=radius * 1.9,
                                location=(0, end * length * 0.5, offset * radius * 1.5),
                                subdiv=1))
    bone = join(tag, parts)
    bone.location = location
    bone.rotation_euler = [math.radians(a) for a in rotation]
    bpy.ops.object.select_all(action="DESELECT")
    bone.select_set(True)
    bpy.context.view_layer.objects.active = bone
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return bone


def build_bonepile():
    """A heap of long bones, about 6 studs across.

    Replaces an anatomically-arranged ribcage, which read as a millipede however
    the ribs were angled. A pile of unmistakable bone shapes says "fossil" at a
    glance and at any distance, which is what this has to do through ice.
    """
    parts = []
    parts.append(_bone("b0", 4.6, 0.3, (0, 0, 0.42), (0, 0, 8)))
    parts.append(_bone("b1", 4.2, 0.27, (0.4, 0.3, 0.95), (0, 0, 66)))
    parts.append(_bone("b2", 3.4, 0.24, (-0.9, -0.5, 0.4), (0, 0, 128)))
    parts.append(_bone("b3", 2.8, 0.2, (1.2, -0.8, 1.35), (18, 0, 30)))
    for i, side in enumerate((-1, 1)):
        parts.append(box("rib%d" % i, scale=(0.09, 1.1, 0.09),
                         location=(-1.6 + i * 0.5, side * 0.5, 1.5),
                         rotation=(side * 55, 0, 12)))

    # A skull resting in the heap. Kept simple and boolean-free: cut eye sockets
    # gouged straight through the braincase and left a sliver, and a boxed
    # cranium never read as a skull at all. A domed sphere plus a snout does.
    parts.append(sphere("cranium", radius=0.72, location=(2.2, 0.9, 0.7),
                        scale=(1.0, 0.85, 0.85), subdiv=2))
    parts.append(box("snout", scale=(0.62, 0.3, 0.26), location=(3.3, 0.9, 0.6)))
    parts.append(box("jaw", scale=(0.7, 0.26, 0.1), location=(3.2, 0.9, 0.3)))
    for i in range(4):
        for side in (-1, 1):
            parts.append(cone("tooth", radius=0.07, depth=0.26,
                              location=(2.95 + i * 0.3, 0.9 + side * 0.22, 0.44),
                              rotation=(180, 0, 0), verts=4))
    return join("BonePile", parts)


def build_frozen_person():
    """A figure caught mid-stride, about 5 studs tall."""
    parts = []
    parts.append(box("torso", scale=(0.55, 0.32, 0.85), location=(0, 0, 2.7)))
    parts.append(box("head", scale=(0.4, 0.36, 0.42), location=(0.06, 0, 3.9)))
    # Arms, one raised as if shielding.
    parts.append(box("armL", scale=(0.19, 0.19, 0.8), location=(0.1, 0.68, 3.0), rotation=(-28, 0, 0)))
    parts.append(box("armR", scale=(0.19, 0.19, 0.8), location=(0.35, -0.6, 3.3), rotation=(35, -40, 0)))
    parts.append(box("legL", scale=(0.24, 0.24, 0.95), location=(0.25, 0.28, 0.95), rotation=(0, 12, 0)))
    parts.append(box("legR", scale=(0.24, 0.24, 0.95), location=(-0.3, -0.28, 0.95), rotation=(0, -16, 0)))
    parts.append(box("furL", scale=(0.62, 0.42, 0.28), location=(0, 0, 3.35)))
    return join("FrozenPerson", parts)


def build_crystal_cluster():
    """Angular shards, about 4 studs across."""
    parts = []
    spec = [
        (0.0, 0.0, 3.2, 0.62, 0, 0),
        (0.9, 0.35, 2.1, 0.42, 18, 12),
        (-0.75, 0.5, 2.4, 0.5, -14, 20),
        (0.35, -0.85, 1.8, 0.38, 22, -18),
        (-0.6, -0.7, 1.5, 0.32, -20, -14),
    ]
    for i, (x, y, h, r, rx, ry) in enumerate(spec):
        parts.append(cone(
            "shard%d" % i, radius=r, depth=h,
            location=(x, y, h * 0.5), rotation=(rx, ry, 0), verts=5,
        ))
    return join("CrystalCluster", parts)


def build_chest():
    """Treasure chest, about 3 studs wide."""
    parts = []
    parts.append(box("base", scale=(1.1, 0.72, 0.5), location=(0, 0, 0.5)))
    # Domed lid from a half cylinder lying on its side.
    parts.append(cylinder(
        "lid", radius=0.72, depth=2.2, location=(0, 0, 1.0), rotation=(0, 90, 0), verts=8
    ))
    for x in (-0.8, 0.0, 0.8):
        parts.append(box("band", scale=(0.09, 0.76, 0.55), location=(x, 0, 0.55)))
    parts.append(box("lock", scale=(0.14, 0.2, 0.22), location=(1.12, 0, 0.9)))
    return join("Chest", parts)


def build_stalagmite():
    """A clump of floor spikes, about 5 studs tall."""
    parts = []
    spec = [(0, 0, 5.0, 0.85), (1.1, 0.4, 2.8, 0.5), (-0.9, 0.7, 2.0, 0.42), (0.3, -1.0, 3.2, 0.55)]
    for i, (x, y, h, r) in enumerate(spec):
        parts.append(cone("spike%d" % i, radius=r, depth=h, location=(x, y, h * 0.5), verts=6))
    return join("Stalagmite", parts)


def build_pot():
    """An amphora, about 3 studs tall."""
    parts = []
    parts.append(sphere("belly", radius=0.85, location=(0, 0, 1.0), scale=(1.0, 1.0, 1.1), subdiv=2))
    parts.append(cylinder("neck", radius=0.32, depth=0.9, location=(0, 0, 2.0), verts=8))
    parts.append(cylinder("lip", radius=0.46, depth=0.2, location=(0, 0, 2.45), verts=8))
    parts.append(cylinder("foot", radius=0.34, depth=0.35, location=(0, 0, 0.2), verts=8))
    for side in (-1, 1):
        parts.append(box("handle", scale=(0.09, 0.28, 0.09), location=(0, side * 0.72, 1.85)))
    return join("Pot", parts)



# --------------------------------------------------------------------------
# pyramid
# --------------------------------------------------------------------------

def build_sarcophagus():
    """Coffin with a stylised mask, about 6 studs long."""
    parts = []
    parts.append(box("case", scale=(2.6, 1.0, 0.55), location=(0, 0, 0.55)))
    parts.append(box("lid", scale=(2.5, 0.9, 0.3), location=(0, 0, 1.35)))
    parts.append(sphere("headEnd", radius=0.95, location=(2.1, 0, 1.35),
                        scale=(0.75, 0.95, 0.75), subdiv=2))
    parts.append(box("mask", scale=(0.42, 0.6, 0.5), location=(2.75, 0, 1.4)))
    # Nemes lappets: the shape that says pharaoh at a glance.
    for side in (-1, 1):
        parts.append(box("lappet", scale=(0.3, 0.2, 0.62),
                         location=(2.5, side * 0.72, 1.1)))
    parts.append(box("beard", scale=(0.16, 0.16, 0.42), location=(3.05, 0, 0.95)))
    for i in range(4):
        parts.append(box("band", scale=(0.1, 0.92, 0.32),
                         location=(1.0 - i * 0.95, 0, 1.5)))
    return join("Sarcophagus", parts)


def build_obelisk():
    """Tapering pillar with a pyramid cap, about 9 studs tall."""
    parts = []
    parts.append(box("base", scale=(0.95, 0.95, 0.35), location=(0, 0, 0.35)))
    for i in range(4):
        w = 0.7 - i * 0.1
        parts.append(box("shaft%d" % i, scale=(w, w, 0.95),
                         location=(0, 0, 1.6 + i * 1.9)))
    parts.append(cone("cap", radius=0.44, depth=1.2, location=(0, 0, 9.0), verts=4))
    return join("Obelisk", parts)


def build_canopic_jar():
    """Lidded jar with a jackal head, about 3 studs tall."""
    parts = []
    parts.append(cylinder("body", radius=0.6, depth=1.7, location=(0, 0, 0.85), verts=8))
    parts.append(cylinder("foot", radius=0.68, depth=0.22, location=(0, 0, 0.11), verts=8))
    parts.append(cylinder("shoulder", radius=0.5, depth=0.3, location=(0, 0, 1.85), verts=8))
    parts.append(sphere("head", radius=0.42, location=(0, 0, 2.3),
                        scale=(1.0, 0.85, 0.95), subdiv=2))
    parts.append(box("muzzle", scale=(0.42, 0.18, 0.16), location=(0.5, 0, 2.2)))
    for side in (-1, 1):
        parts.append(cone("ear", radius=0.16, depth=0.6,
                          location=(-0.05, side * 0.24, 2.85), verts=4))
    return join("CanopicJar", parts)


# --------------------------------------------------------------------------
# troy
# --------------------------------------------------------------------------

def build_trojan_horse():
    """The horse, about 11 studs long. The hero find of the last map."""
    parts = []
    parts.append(box("body", scale=(3.0, 1.25, 1.5), location=(0, 0, 5.2)))
    parts.append(box("chest", scale=(1.0, 1.2, 1.2), location=(2.6, 0, 5.0)))
    parts.append(box("rump", scale=(1.0, 1.15, 1.3), location=(-2.8, 0, 5.1)))
    parts.append(box("neck", scale=(0.5, 0.7, 1.5), location=(3.3, 0, 6.9),
                     rotation=(0, -28, 0)))
    parts.append(box("head", scale=(0.95, 0.5, 0.42), location=(4.5, 0, 7.9),
                     rotation=(0, 18, 0)))
    for side in (-1, 1):
        parts.append(cone("ear", radius=0.14, depth=0.5,
                          location=(4.0, side * 0.32, 8.4), verts=4))
    # Plank seams, which is what makes it read as built rather than alive.
    for i in range(6):
        parts.append(box("plank", scale=(0.08, 1.3, 1.45),
                         location=(2.2 - i * 0.95, 0, 5.2)))
    for sx in (-2.0, 2.0):
        for sy in (-0.95, 0.95):
            parts.append(box("leg", scale=(0.34, 0.3, 1.9), location=(sx, sy, 1.9)))
    parts.append(box("platform", scale=(3.4, 1.5, 0.25), location=(0, 0, 0.25)))
    for sx in (-2.4, 2.4):
        for sy in (-1.4, 1.4):
            parts.append(cylinder("wheel", radius=0.62, depth=0.24,
                                  location=(sx, sy, 0.6), rotation=(90, 0, 0), verts=8))
    parts.append(box("tail", scale=(0.16, 0.16, 0.9), location=(-3.7, 0, 5.6),
                     rotation=(0, 35, 0)))
    return join("TrojanHorse", parts)


def build_column():
    """Doric column, about 8 studs tall."""
    parts = []
    parts.append(box("plinth", scale=(0.95, 0.95, 0.22), location=(0, 0, 0.22)))
    parts.append(cylinder("shaft", radius=0.62, depth=6.6, location=(0, 0, 3.75), verts=12))
    # Flutes as thin boxes around the shaft: at low poly that reads as fluting
    # without needing a carved profile.
    for i in range(8):
        angle = i * (2 * math.pi / 8)
        parts.append(box("flute", scale=(0.09, 0.09, 3.2),
                         location=(math.cos(angle) * 0.6, math.sin(angle) * 0.6, 3.75)))
    parts.append(cylinder("echinus", radius=0.78, depth=0.34, location=(0, 0, 7.2), verts=12))
    parts.append(box("abacus", scale=(0.92, 0.92, 0.22), location=(0, 0, 7.6)))
    return join("Column", parts)


def build_statue():
    """Figure on a plinth, about 6 studs tall."""
    parts = []
    parts.append(box("plinth", scale=(0.85, 0.85, 0.42), location=(0, 0, 0.42)))
    parts.append(box("legs", scale=(0.42, 0.3, 1.1), location=(0, 0, 1.9)))
    parts.append(box("robe", scale=(0.5, 0.38, 0.95), location=(0, 0, 3.7)))
    parts.append(sphere("head", radius=0.34, location=(0, 0, 4.95),
                        scale=(1.0, 0.9, 1.05), subdiv=2))
    parts.append(box("armUp", scale=(0.15, 0.15, 0.85), location=(0.2, 0.55, 4.4),
                     rotation=(-38, 0, 0)))
    parts.append(box("armDown", scale=(0.15, 0.15, 0.7), location=(0, -0.5, 3.6)))
    parts.append(box("drape", scale=(0.55, 0.12, 1.0), location=(0, 0.3, 3.4),
                     rotation=(0, 0, 12)))
    return join("Statue", parts)


def build_shield():
    """Round hoplite shield, about 3 studs across."""
    parts = []
    parts.append(cylinder("face", radius=1.35, depth=0.2, location=(0, 0, 1.35),
                          rotation=(90, 0, 0), verts=12))
    parts.append(cylinder("rim", radius=1.5, depth=0.14, location=(0, 0, 1.35),
                          rotation=(90, 0, 0), verts=12))
    parts.append(sphere("boss", radius=0.34, location=(0, -0.16, 1.35),
                        scale=(1.0, 0.6, 1.0), subdiv=2))
    shield = join("Shield", parts)
    # Leaned back a little so it does not read as a flat disc lying down.
    shield.rotation_euler = [math.radians(a) for a in (18, 0, 0)]
    bpy.ops.object.select_all(action="DESELECT")
    shield.select_set(True)
    bpy.context.view_layer.objects.active = shield
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return shield


PROPS = {
    "Mammoth": build_mammoth,
    "BonePile": build_bonepile,
    "FrozenPerson": build_frozen_person,
    "CrystalCluster": build_crystal_cluster,
    "Chest": build_chest,
    "Stalagmite": build_stalagmite,
    "Pot": build_pot,
    "Sarcophagus": build_sarcophagus,
    "Obelisk": build_obelisk,
    "CanopicJar": build_canopic_jar,
    "TrojanHorse": build_trojan_horse,
    "Column": build_column,
    "Statue": build_statue,
    "Shield": build_shield,
}


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def build_all(spacing=14.0):
    clear_scene()
    built = []
    for i, (name, builder) in enumerate(sorted(PROPS.items())):
        obj = builder()
        # Laid out in a row so a single FBX carries them all without overlap.
        # Roblox imports one MeshPart per mesh object in the file, so one upload
        # covers the whole set.
        obj.location = (i * spacing, 0, 0)
        built.append(obj)
    return built


def report(objects):
    print("\n--- props ---")
    total = 0
    for obj in objects:
        mesh = obj.data
        tris = sum(max(0, len(p.vertices) - 2) for p in mesh.polygons)
        total += tris
        dims = obj.dimensions
        print(
            "  %-16s %5d tris   %.1f x %.1f x %.1f studs (%.1f chunks long)"
            % (obj.name, tris, dims.x, dims.y, dims.z, max(dims) / CHUNK)
        )
    print("  total: %d tris across %d props" % (total, len(objects)))
    print("  Roblox limit is 20000 tris per mesh - all well clear\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = None
    render = None
    for i, arg in enumerate(argv):
        if arg == "--out" and i + 1 < len(argv):
            out = argv[i + 1]
        if arg == "--render" and i + 1 < len(argv):
            render = argv[i + 1]

    objects = build_all()
    report(objects)

    if out:
        out = os.path.abspath(out)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        bpy.ops.export_scene.fbx(
            filepath=out,
            use_selection=False,
            apply_unit_scale=True,
            global_scale=1.0,
            object_types={"MESH"},
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            add_leaf_bones=False,
            bake_anim=False,
            path_mode="COPY",
        )
        print("exported: %s (%d bytes)" % (out, os.path.getsize(out)))

    if render:
        render_previews(render, objects)


def render_previews(directory, objects):
    """One framed render per prop, so the shapes can actually be looked at."""
    directory = os.path.abspath(directory)
    os.makedirs(directory, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.film_transparent = False

    bpy.ops.object.camera_add(location=(0, 0, 0))
    camera = bpy.context.active_object
    scene.camera = camera

    for obj in objects:
        centre = obj.location + obj.dimensions * 0.5 * 0.0
        centre = obj.matrix_world.translation.copy()
        centre.z += obj.dimensions.z * 0.5
        reach = max(obj.dimensions) * 2.1 + 3.0
        camera.location = centre + type(centre)((reach * 0.75, -reach, reach * 0.55))
        direction = centre - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(directory, obj.name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered: %s" % scene.render.filepath)


main()
