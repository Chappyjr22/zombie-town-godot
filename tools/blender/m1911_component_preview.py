"""Render a color-coded loose-part diagnostic from the temporary M1911 FBX copy."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args_after_separator() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def material(index: int) -> bpy.types.Material:
    hue = (index * 0.61803398875) % 1.0
    color = __import__("colorsys").hsv_to_rgb(hue, 0.68, 0.92)
    mat = bpy.data.materials.new(f"Part_{index:02d}")
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = (*color, 1.0)
        principled.inputs["Metallic"].default_value = 0.15
        principled.inputs["Roughness"].default_value = 0.42
    mat.metallic = 0.15
    mat.roughness = 0.42
    return mat


def look_at(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fbx", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--source-object", default="M1911A1_lowPoly")
    args = parser.parse_args(args_after_separator())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(Path(args.fbx).resolve()), use_anim=False)
    source = bpy.data.objects.get(args.source_object)
    if source is None or source.type != "MESH":
        raise RuntimeError(f"Missing mesh object {args.source_object}")

    for obj in list(bpy.context.scene.objects):
        if obj != source:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.context.view_layer.objects.active = source
    source.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]

    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for index, obj in enumerate(sorted(parts, key=lambda item: item.name)):
        obj.name = f"Part_{index:02d}"
        obj.data.materials.clear()
        obj.data.materials.append(material(index))
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    center = (minimum + maximum) * 0.5

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("DiagnosticWorld")
        bpy.context.scene.world = world
    world.color = (0.018, 0.022, 0.030)
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = center + Vector((0.0, 0.0, -0.85))
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(maximum.x - minimum.x, maximum.y - minimum.y) * 1.22
    look_at(camera, center)
    bpy.context.scene.camera = camera

    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 12.0
    key.shape = "DISK"
    key.size = 0.6
    key_obj = bpy.data.objects.new("Key", key)
    key_obj.location = center + Vector((-0.35, -0.45, 0.35))
    bpy.context.scene.collection.objects.link(key_obj)
    look_at(key_obj, center)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 7.0
    fill.size = 0.45
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.location = center + Vector((0.35, -0.25, -0.25))
    bpy.context.scene.collection.objects.link(fill_obj)
    look_at(fill_obj, center)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(Path(args.output).resolve())
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"M1911_COMPONENT_PREVIEW={args.output};parts={len(parts)}")


if __name__ == "__main__":
    main()
