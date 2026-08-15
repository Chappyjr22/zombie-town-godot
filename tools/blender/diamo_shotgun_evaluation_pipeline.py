"""Build an evaluation-only GLB from a copied Diamo shotgun BLEND source.

The script repairs PBR materials in memory, preserves authored mesh objects,
normalizes the source axis to Godot camera-forward, exports a GLB, and never
saves the opened BLEND file.
"""

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


CHANNELS = ("BaseColor", "Normal", "Roughness", "Metallic", "Height")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--pbr-dir", required=True)
    parser.add_argument("--axis-mode", choices=("positive_x", "negative_x", "positive_y", "negative_y"), required=True)
    parser.add_argument("--source-library", default="Diamo Studio 45 Gun Arsenal - Shotguns")
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


def texture_sets(pbr_dir):
    sets = {}
    suffix = re.compile(r"_(BaseColor|Normal|Roughness|Metallic|Height)$", re.IGNORECASE)
    for path in Path(pbr_dir).glob("*.png"):
        match = suffix.search(path.stem)
        if not match:
            continue
        key = path.stem[: match.start()]
        channel = next(value for value in CHANNELS if value.lower() == match.group(1).lower())
        sets.setdefault(key, {})[channel] = path
    incomplete = {key: sorted(set(CHANNELS) - set(value)) for key, value in sets.items() if set(value) != set(CHANNELS)}
    if incomplete:
        raise RuntimeError(f"Incomplete PBR texture sets: {incomplete}")
    return sets


def texture_key_for_material(material_name, sets):
    normalized = re.sub(r"\.\d{3}$", "", material_name).lower()
    matches = [key for key in sets if key.lower().endswith("_" + normalized) or key.lower() == normalized]
    if len(matches) == 1:
        return matches[0]
    if len(sets) == 1:
        return next(iter(sets))
    raise RuntimeError(f"Cannot map material {material_name!r} to texture sets {sorted(sets)}")


def image_node(nodes, path, label, non_color):
    image = bpy.data.images.load(str(path.resolve()), check_existing=True)
    image.name = label
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    node = nodes.new("ShaderNodeTexImage")
    node.name = label
    node.label = label
    node.image = image
    return node, image


def build_material(texture_key, paths):
    material = bpy.data.materials.new(texture_key + "_PBR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    base, base_image = image_node(nodes, paths["BaseColor"], texture_key + " Base Color", False)
    normal, normal_image = image_node(nodes, paths["Normal"], texture_key + " Normal", True)
    rough, rough_image = image_node(nodes, paths["Roughness"], texture_key + " Roughness", True)
    metal, metal_image = image_node(nodes, paths["Metallic"], texture_key + " Metallic", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(base.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    links.new(rough.outputs["Color"], principled.inputs["Roughness"])
    links.new(metal.outputs["Color"], principled.inputs["Metallic"])
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
        return Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))
    if mode == "negative_x":
        return Matrix(((0, -1, 0, 0), (0, 0, 1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
    if mode == "positive_y":
        # +Y muzzle/+Z up/+X across -> -Z muzzle/+Y up/+X across.
        return Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
    # -Y muzzle/+Z up/+X across -> -Z muzzle/+Y up/-X across.
    return Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def main():
    args = parse_args()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects in source BLEND")

    sets = texture_sets(args.pbr_dir)
    source_materials = sorted({
        slot.material.name for obj in meshes for slot in obj.material_slots if slot.material
    })
    material_cache = {}
    material_reports = {}
    material_mapping = {}
    for source_name in source_materials:
        key = texture_key_for_material(source_name, sets)
        if key not in material_cache:
            material_cache[key], material_reports[key] = build_material(key, sets[key])
        material_mapping[source_name] = key
    for obj in meshes:
        for slot in obj.material_slots:
            if slot.material:
                slot.material = material_cache[material_mapping[slot.material.name]]

    height_dir = Path(args.height_output) / args.asset_id
    height_dir.mkdir(parents=True, exist_ok=True)
    for paths in sets.values():
        shutil.copy2(paths["Height"], height_dir / paths["Height"].name)

    minimum, maximum = bounds(meshes)
    center = (minimum + maximum) * 0.5
    root = bpy.data.objects.new("WeaponRoot", None)
    root["asset_id"] = args.asset_id
    root["source_library"] = args.source_library
    root["evaluation_only"] = True
    bpy.context.scene.collection.objects.link(root)
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
        obj.hide_render = False
    root.matrix_world = axis_matrix(args.axis_mode) @ Matrix.Translation(-center)

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output), export_format="GLB", use_selection=True,
        export_apply=False, export_cameras=False, export_lights=False,
        export_animations=False, export_materials="EXPORT"
    )
    report = {
        "asset_id": args.asset_id,
        "source_blend_copy": bpy.data.filepath,
        "source_archive_sha256": args.archive_sha256,
        "source_was_saved": False,
        "blender_version": bpy.app.version_string,
        "axis_mode": args.axis_mode,
        "source_objects_preserved": [obj.name for obj in meshes],
        "source_material_to_pbr_set": material_mapping,
        "material_sets": material_reports,
        "height_handling": "Preserved beside the GLB; core glTF has no height channel.",
        "generated_glb": os.path.basename(args.output),
        "generated_glb_bytes": os.path.getsize(args.output),
    }
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("DIAMO_SHOTGUN_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
