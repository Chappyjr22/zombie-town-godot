"""Render a labeled contact sheet for semantic M1911 loose-part identification.

This diagnostic consumes the generated evaluation GLB and never opens or saves
the purchased/original source. Each tile shows the complete pistol in gray with
one separated component highlighted in red.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Metallic"].default_value = 0.15
        shader.inputs["Roughness"].default_value = 0.48
    return result


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    return minimum, maximum


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--names", default="")
    args = parser.parse_args(script_args())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.input).resolve()))
    source_parts = sorted(
        [obj for obj in bpy.context.scene.objects if obj.type == "MESH"],
        key=lambda obj: obj.name,
    )
    if not source_parts:
        raise RuntimeError("No M1911 mesh components found")

    gray = material("Context", (0.18, 0.22, 0.28, 1.0))
    red = material("Selected", (0.95, 0.06, 0.035, 1.0))
    text_material = material("Labels", (0.95, 0.95, 0.95, 1.0))
    minimum, maximum = world_bounds(source_parts)
    dimensions = maximum - minimum
    center = (minimum + maximum) * 0.5
    highlighted_parts = source_parts
    if args.names:
        requested = {name.strip() for name in args.names.split(",") if name.strip()}
        highlighted_parts = [obj for obj in source_parts if obj.name in requested]
    columns = min(3 if args.names else 5, max(1, len(highlighted_parts)))
    rows = math.ceil(len(highlighted_parts) / columns)
    tile_width = max(dimensions.z * 1.30, 0.28)
    tile_height = max(dimensions.y * 1.65, 0.25)

    for index, highlighted in enumerate(highlighted_parts):
        column = index % columns
        row = index // columns
        offset = Vector((0.0, (rows - 1 - row) * tile_height, column * tile_width))
        for source in source_parts:
            duplicate = source.copy()
            duplicate.data = source.data.copy()
            duplicate.parent = None
            duplicate.matrix_world = source.matrix_world.copy()
            duplicate.location += offset - center
            duplicate.data.materials.clear()
            duplicate.data.materials.append(red if source == highlighted else gray)
            bpy.context.scene.collection.objects.link(duplicate)
        label_data = bpy.data.curves.new(f"Label_{index:02d}", "FONT")
        label_data.body = highlighted.name
        label_data.align_x = "CENTER"
        label_data.size = 0.025
        label_data.extrude = 0.0002
        label_data.materials.append(text_material)
        label = bpy.data.objects.new(f"Label_{index:02d}", label_data)
        label.location = Vector((-0.035, offset.y - dimensions.y * 0.70, offset.z))
        label.rotation_euler = (math.radians(90.0), 0.0, math.radians(90.0))
        bpy.context.scene.collection.objects.link(label)

    for obj in list(source_parts):
        bpy.data.objects.remove(obj, do_unlink=True)

    world = bpy.data.worlds.new("DiagnosticWorld")
    world.color = (0.015, 0.018, 0.024)
    bpy.context.scene.world = world
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(rows * tile_height * 1.10, columns * tile_width * 0.85)
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = Vector((-3.0, (rows - 1) * tile_height * 0.5, (columns - 1) * tile_width * 0.5))
    bpy.context.scene.collection.objects.link(camera)
    look_at(camera, Vector((0.0, camera.location.y, camera.location.z)))
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("Key", "AREA")
    key_data.energy = 800.0
    key_data.size = 4.0
    key = bpy.data.objects.new("Key", key_data)
    key.location = camera.location + Vector((1.0, 1.5, -1.0))
    bpy.context.scene.collection.objects.link(key)
    look_at(key, Vector((0.0, camera.location.y, camera.location.z)))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 2400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(Path(args.output).resolve())
    scene.view_settings.look = "AgX - Medium High Contrast"
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"M1911_CONTACT_SHEET={args.output};parts={len(highlighted_parts)}")


if __name__ == "__main__":
    main()
