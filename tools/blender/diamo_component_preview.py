"""Render a color-coded, evaluation-only preview of authored mesh objects."""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


COLORS = (
    (0.95, 0.12, 0.08, 1.0),
    (0.10, 0.75, 0.20, 1.0),
    (0.08, 0.30, 1.00, 1.0),
    (1.00, 0.75, 0.05, 1.0),
    (0.75, 0.12, 0.90, 1.0),
)


def args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--axis-mode", choices=("positive_x", "negative_x", "positive_y", "negative_y"), required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(argv)


def bounds(objects):
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for index in range(3):
                minimum[index] = min(minimum[index], point[index])
                maximum[index] = max(maximum[index], point[index])
    return minimum, maximum


def axis_matrix(mode):
    if mode == "positive_x":
        return Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))
    if mode == "negative_x":
        return Matrix(((0, -1, 0, 0), (0, 0, 1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
    if mode == "positive_y":
        return Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
    return Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def color_material(index):
    color = COLORS[index % len(COLORS)]
    material = bpy.data.materials.new(f"Component_{index}")
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = 0.65
    principled.inputs["Metallic"].default_value = 0.0
    return material, color


def main():
    options = args()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    minimum, maximum = bounds(meshes)
    center = (minimum + maximum) * 0.5
    source_length = max((maximum - minimum))
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.scene.collection.objects.link(root)
    mapping = []
    for index, obj in enumerate(meshes):
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
        material, color = color_material(index)
        obj.data.materials.clear()
        obj.data.materials.append(material)
        mapping.append({"object": obj.name, "mesh_data": obj.data.name, "rgba": list(color)})
    root.matrix_world = axis_matrix(options.axis_mode) @ Matrix.Scale(2.0 / source_length, 4) @ Matrix.Translation(-center)

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.65
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = Vector((2.35, 1.55, 2.7))
    camera.rotation_euler = ((Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler())

    key_data = bpy.data.lights.new("Key", "AREA")
    key_data.energy = 1100
    key_data.shape = "DISK"
    key_data.size = 5.0
    key = bpy.data.objects.new("Key", key_data)
    key.location = Vector((2.5, 4.0, 1.5))
    bpy.context.scene.collection.objects.link(key)

    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.abspath(options.output)
    scene.world.color = (0.018, 0.022, 0.03)
    Path(options.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    Path(options.report).write_text(json.dumps({
        "source_blend": bpy.data.filepath,
        "source_was_saved": False,
        "axis_mode": options.axis_mode,
        "color_mapping": mapping,
    }, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
