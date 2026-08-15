"""Convert an untouched-copy Diamo SMG .blend into an evaluation-only GLB.

The opened source is modified only in Blender memory. Separate authored mesh
objects remain separate so magazine/trigger/bolt animation potential survives.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--base-color", required=True)
    parser.add_argument("--normal", required=True)
    parser.add_argument("--roughness", required=True)
    parser.add_argument("--metallic", required=True)
    parser.add_argument("--height", required=True)
    parser.add_argument("--archive-sha256", required=True)
    return parser.parse_args(argv)


def sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def bounds_for_objects(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            minimum = Vector(tuple(min(minimum[index], point[index]) for index in range(3)))
            maximum = Vector(tuple(max(maximum[index], point[index]) for index in range(3)))
    return minimum, maximum


def image_node(nodes, image_path: str, name: str, non_color: bool):
    image = bpy.data.images.load(os.path.abspath(image_path), check_existing=False)
    image.name = name
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    node = nodes.new("ShaderNodeTexImage")
    node.name = name
    node.label = name
    node.image = image
    return node, image


def build_pbr_material(args: argparse.Namespace) -> tuple[bpy.types.Material, dict[str, object]]:
    material = bpy.data.materials.new(f"{args.asset_id}_PBR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])

    base_node, base_image = image_node(nodes, args.base_color, "Base Color", False)
    normal_node, normal_image = image_node(nodes, args.normal, "Normal", True)
    rough_node, rough_image = image_node(nodes, args.roughness, "Roughness", True)
    metal_node, metal_image = image_node(nodes, args.metallic, "Metallic", True)
    height_node, height_image = image_node(nodes, args.height, "Height (preserved, GLB unsupported)", True)

    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 1.0
    links.new(base_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    links.new(rough_node.outputs["Color"], principled.inputs["Roughness"])
    links.new(metal_node.outputs["Color"], principled.inputs["Metallic"])

    # glTF/GLB has no standard height channel. Keep the source image loaded and
    # copy it next to the GLB, but do not create a misleading non-portable link.
    height_node.hide = True
    principled.inputs["Roughness"].default_value = 0.5
    principled.inputs["Metallic"].default_value = 0.0

    images = {
        "base_color": (args.base_color, base_image),
        "normal": (args.normal, normal_image),
        "roughness": (args.roughness, rough_image),
        "metallic": (args.metallic, metal_image),
        "height": (args.height, height_image),
    }
    image_report = {}
    for channel, (path, image) in images.items():
        image_report[channel] = {
            "source_file": os.path.basename(path),
            "sha256": sha256(path),
            "resolution": list(image.size),
            "colorspace": image.colorspace_settings.name,
            "embedded_in_glb": channel != "height",
        }
    return material, image_report


def normalize_hierarchy(mesh_objects: list[bpy.types.Object], asset_id: str) -> bpy.types.Object:
    minimum, maximum = bounds_for_objects(mesh_objects)
    center = (minimum + maximum) * 0.5

    root = bpy.data.objects.new("WeaponRoot", None)
    root["asset_id"] = asset_id
    root["source_library"] = "Diamo Studio 45 Gun Arsenal - SMGs"
    root["evaluation_only"] = True
    bpy.context.scene.collection.objects.link(root)

    for obj in mesh_objects:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world

    # Diamo's authored world axes are -Z muzzle, +X up, and +Y across. Map them
    # to Godot -Z muzzle, +Y up, and +X across with a right-handed transform.
    correction = Matrix(
        (
            (0.0, -1.0, 0.0, 0.0),
            (1.0, 0.0, 0.0, 0.0),
            (0.0, 0.0, 1.0, 0.0),
            (0.0, 0.0, 0.0, 1.0),
        )
    )
    root.matrix_world = correction @ Matrix.Translation(-center)
    return root


def main() -> None:
    args = parse_args()
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise RuntimeError("Diamo source contains no mesh objects")

    source_object_names = [obj.name for obj in mesh_objects]
    material, image_report = build_pbr_material(args)
    for obj in mesh_objects:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.hide_render = False

    root = normalize_hierarchy(mesh_objects, args.asset_id)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_materials="EXPORT",
    )

    report = {
        "asset_id": args.asset_id,
        "source_blend_copy": bpy.data.filepath,
        "source_archive_sha256": args.archive_sha256,
        "blender_version": bpy.app.version_string,
        "source_objects_preserved": source_object_names,
        "mesh_object_count": len(mesh_objects),
        "pbr_textures": image_report,
        "height_handling": "Preserved next to the GLB; not connected because core glTF/GLB has no height-map channel.",
        "axis_conversion": "Diamo -Z muzzle/+X up/+Y across to Godot -Z muzzle/+Y up/+X across.",
        "generated_glb": os.path.basename(args.output),
        "generated_glb_bytes": os.path.getsize(args.output),
        "source_was_saved": False,
    }
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("DIAMO_EVALUATION_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
