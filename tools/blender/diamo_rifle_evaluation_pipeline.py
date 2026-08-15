"""Build a multi-material, evaluation-only GLB from a Diamo rifle BLEND copy."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--pbr-dir", required=True)
    parser.add_argument("--axis-mode", choices=("positive_x", "negative_z"), required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--height-output", required=True)
    parser.add_argument("--archive-sha256", required=True)
    return parser.parse_args(argv)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def clean_material_name(name):
    return re.sub(r"\.\d{3}$", "", name)


def find_map(pbr_dir, material_name, channel):
    material_name = clean_material_name(material_name).lower()
    suffix = f"_{material_name}_{channel}.png".lower()
    matches = [path for path in Path(pbr_dir).glob("*.png") if path.name.lower().endswith(suffix)]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {channel} map for {material_name!r}; found {matches}")
    return matches[0]


def image_node(nodes, path, label, non_color):
    image = bpy.data.images.load(str(path.resolve()), check_existing=False)
    image.name = label
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    node = nodes.new("ShaderNodeTexImage")
    node.name = label
    node.label = label
    node.image = image
    return node, image


def pbr_material(source_name, pbr_dir, height_output):
    paths = {channel: find_map(pbr_dir, source_name, channel) for channel in (
        "BaseColor", "Normal", "Roughness", "Metallic", "Height"
    )}
    material = bpy.data.materials.new(clean_material_name(source_name) + "_PBR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    base, base_image = image_node(nodes, paths["BaseColor"], "Base Color", False)
    normal, normal_image = image_node(nodes, paths["Normal"], "Normal", True)
    rough, rough_image = image_node(nodes, paths["Roughness"], "Roughness", True)
    metal, metal_image = image_node(nodes, paths["Metallic"], "Metallic", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(base.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    links.new(rough.outputs["Color"], principled.inputs["Roughness"])
    links.new(metal.outputs["Color"], principled.inputs["Metallic"])

    Path(height_output).mkdir(parents=True, exist_ok=True)
    copied_height = Path(height_output) / paths["Height"].name
    shutil.copy2(paths["Height"], copied_height)
    images = {
        "base_color": (paths["BaseColor"], base_image, True),
        "normal": (paths["Normal"], normal_image, True),
        "roughness": (paths["Roughness"], rough_image, True),
        "metallic": (paths["Metallic"], metal_image, True),
        "height": (paths["Height"], None, False),
    }
    return material, {
        channel: {
            "source_file": path.name,
            "sha256": sha256(path),
            "resolution": list(image.size) if image else [4096, 4096],
            "embedded_in_glb": embedded,
        }
        for channel, (path, image, embedded) in images.items()
    }


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
        # +X muzzle/+Z up/+Y across -> -Z muzzle/+Y up/+X across.
        return Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))
    # Already -Z muzzle/+Y up/+X across in authored world space.
    return Matrix.Identity(4)


def main():
    options = args()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects in source BLEND")

    source_materials = sorted({
        slot.material.name for obj in meshes for slot in obj.material_slots if slot.material
    })
    replacements = {}
    material_report = {}
    for name in source_materials:
        replacement, report = pbr_material(name, options.pbr_dir, options.height_output)
        replacements[name] = replacement
        material_report[name] = report
    for obj in meshes:
        for index, slot in enumerate(obj.material_slots):
            if slot.material:
                obj.material_slots[index].material = replacements[slot.material.name]

    minimum, maximum = bounds(meshes)
    center = (minimum + maximum) * 0.5
    root = bpy.data.objects.new("WeaponRoot", None)
    root["asset_id"] = options.asset_id
    root["source_library"] = "Diamo Studio 45 Gun Arsenal - Rifles"
    root["evaluation_only"] = True
    bpy.context.scene.collection.objects.link(root)
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
    root.matrix_world = axis_matrix(options.axis_mode) @ Matrix.Translation(-center)

    Path(options.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(options.output), export_format="GLB", use_selection=True,
        export_apply=False, export_cameras=False, export_lights=False, export_animations=False,
        export_materials="EXPORT"
    )
    report = {
        "asset_id": options.asset_id,
        "source_blend_copy": bpy.data.filepath,
        "source_archive_sha256": options.archive_sha256,
        "source_was_saved": False,
        "blender_version": bpy.app.version_string,
        "axis_mode": options.axis_mode,
        "source_objects_preserved": [obj.name for obj in meshes],
        "material_sets": material_report,
        "height_handling": "Preserved beside the GLB; core glTF has no height channel.",
        "generated_glb": os.path.basename(options.output),
        "generated_glb_bytes": os.path.getsize(options.output),
    }
    Path(options.report).parent.mkdir(parents=True, exist_ok=True)
    Path(options.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("DIAMO_RIFLE_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
