"""
Build every model in the game and export them as one FBX.

    blender -b -P assets/blender/build.py -- --out build/models.fbx
    blender -b -P assets/blender/build.py -- --render build/preview

Roblox turns each mesh object in an FBX into its own MeshPart inside a single
Model asset, so the whole game - finds, tools and architecture - costs one
upload and one asset id to keep track of.

Objects are laid out in groups. A group is one thing that may be made of several
meshes, like an axe that is a haft and a head: everything in a group keeps its
authored position relative to the rest, so the offsets survive the export and can
be read back in engine. Groups are spaced apart from each other so nothing
overlaps, with the spacing derived from each group's own size - the pyramid is
128 studs across and the stone is under two.
"""

import bpy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import props  # noqa: E402
import structures  # noqa: E402
import tools  # noqa: E402

GAP = 10.0
CHUNK = 4.0


def build_groups():
    props.clear_scene()
    groups = []

    for name, builder in sorted(props.PROPS.items()):
        groups.append(("find:" + name, [builder()]))
    for name, builders in sorted(tools.TOOL_GROUPS.items()):
        groups.append(("tool:" + name, [builder() for builder in builders]))
    for name, builders in sorted(structures.STRUCTURE_GROUPS.items()):
        groups.append(("structure:" + name, [builder() for builder in builders]))

    # March along X, spacing by each group's own footprint.
    cursor = 0.0
    for _, objects in groups:
        width = max(obj.dimensions.x for obj in objects)
        cursor += width / 2 + GAP
        for obj in objects:
            obj.location.x += cursor
        cursor += width / 2 + GAP

    return groups


def report(groups):
    print("\n--- models ---")
    total, worst = 0, 0
    for name, objects in groups:
        for obj in objects:
            tris = sum(max(0, len(p.vertices) - 2) for p in obj.data.polygons)
            total += tris
            worst = max(worst, tris)
            dims = obj.dimensions
            print(
                "  %-28s %-24s %6d tris   %.1f x %.1f x %.1f studs"
                % (name, obj.name, tris, dims.x, dims.y, dims.z)
            )
    meshes = sum(len(objects) for _, objects in groups)
    print("  %d meshes in %d groups, %d tris total, worst single mesh %d"
          % (meshes, len(groups), total, worst))
    if worst > 20000:
        print("  WARNING: a mesh exceeds Roblox's 20000 triangle limit")
    else:
        print("  all clear of Roblox's 20000 triangle per-mesh limit")


def dump(path, groups):
    """Write exact authored dimensions and within-group offsets as JSON.

    Roblox normalises a whole model on import, and the factor depends on what
    else is in the file - adding a 128-stud pyramid changed it from 100x to
    about 15x. So nothing downstream should derive real sizes from what the
    importer reports. These are the authored numbers, in Roblox axes.

    Blender is Z-up and Roblox is Y-up, so (x, y, z) maps to (x, z, y).

    Offsets are geometry-centre differences within a group. Every object has its
    origin at the world origin after join(), so a head and its haft share an
    origin and only their bounding-box centres differ - which is exactly the
    offset the engine needs to place one against the other.
    """
    import json

    def centre(obj):
        local = [obj.matrix_world @ v.co for v in obj.data.vertices]
        xs = [v.x for v in local]
        ys = [v.y for v in local]
        zs = [v.z for v in local]
        return (
            (min(xs) + max(xs)) / 2,
            (min(ys) + max(ys)) / 2,
            (min(zs) + max(zs)) / 2,
        )

    out = {}
    for name, objects in groups:
        anchor = centre(objects[0])
        entries = []
        for obj in objects:
            here = centre(obj)
            dims = obj.dimensions
            entries.append({
                "mesh": obj.name,
                # Blender (x, y, z) -> Roblox (x, z, y)
                "size": [round(dims.x, 4), round(dims.z, 4), round(dims.y, 4)],
                "offset": [
                    round(here[0] - anchor[0], 4),
                    round(here[2] - anchor[2], 4),
                    round(here[1] - anchor[1], 4),
                ],
            })
        out[name] = entries

    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2)
    print("dumped: %s (%d groups)" % (path, len(out)))


def export(path):
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path,
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
    print("exported: %s (%d bytes)" % (path, os.path.getsize(path)))


def render_previews(directory, groups):
    """One framed render per group, so the shapes can actually be looked at."""
    directory = os.path.abspath(directory)
    os.makedirs(directory, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 520
    scene.render.resolution_y = 520

    bpy.ops.object.camera_add(location=(0, 0, 0))
    camera = bpy.context.active_object
    scene.camera = camera

    for name, objects in groups:
        centre = objects[0].matrix_world.translation.copy()
        span = max(max(obj.dimensions) for obj in objects)
        centre.z += span * 0.3
        reach = span * 2.0 + 4.0
        camera.location = centre + type(centre)((reach * 0.75, -reach, reach * 0.5))
        direction = centre - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(directory, name.replace(":", "_") + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered: %s" % scene.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out, render, manifest = None, None, None
    for index, arg in enumerate(argv):
        if arg == "--out" and index + 1 < len(argv):
            out = argv[index + 1]
        if arg == "--render" and index + 1 < len(argv):
            render = argv[index + 1]
        if arg == "--dump" and index + 1 < len(argv):
            manifest = argv[index + 1]

    groups = build_groups()
    report(groups)
    if manifest:
        dump(manifest, groups)
    if out:
        export(out)
    if render:
        render_previews(render, groups)


main()
