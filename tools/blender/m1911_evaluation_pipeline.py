"""Convert a temporary copy of DavidFalke's M1911A1 FBX to an evaluation-only GLB."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def make_opengl_normal(source: str, output: str) -> bpy.types.Image:
    source_image = bpy.data.images.load(str(Path(source).resolve()), check_existing=False)
    width, height = source_image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    source_image.pixels.foreach_get(pixels)
    pixels[1::4] = 1.0 - pixels[1::4]
    generated = bpy.data.images.new("M1911_Normal_OpenGL", width=width, height=height, alpha=True)
    generated.colorspace_settings.name = "Non-Color"
    generated.pixels.foreach_set(pixels)
    generated.filepath_raw = str(Path(output).resolve())
    generated.file_format = "PNG"
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    generated.save()
    bpy.data.images.remove(source_image)
    return generated


def image_node(nodes, path: str, name: str, non_color: bool) -> tuple[bpy.types.Node, bpy.types.Image]:
    image = bpy.data.images.load(str(Path(path).resolve()), check_existing=False)
    image.name = name
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    node = nodes.new("ShaderNodeTexImage")
    node.name = name
    node.image = image
    return node, image


def build_material(args: argparse.Namespace) -> tuple[bpy.types.Material, dict[str, object]]:
    normal_image = make_opengl_normal(args.normal_directx, args.generated_normal)
    material = bpy.data.materials.new("DavidFalke_M1911A1_PBR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    base_node, base_image = image_node(nodes, args.base_color, "Base Color", False)
    rough_node, rough_image = image_node(nodes, args.roughness, "Roughness", True)
    metal_node, metal_image = image_node(nodes, args.metallic, "Metallic", True)
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.name = "Normal OpenGL"
    normal_node.image = normal_image
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 1.0
    links.new(base_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(rough_node.outputs["Color"], principled.inputs["Roughness"])
    links.new(metal_node.outputs["Color"], principled.inputs["Metallic"])
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    return material, {
        "base_color": {"source": os.path.basename(args.base_color), "sha256": sha256(args.base_color), "resolution": list(base_image.size)},
        "normal": {"source": os.path.basename(args.normal_directx), "source_sha256": sha256(args.normal_directx), "generated": os.path.basename(args.generated_normal), "generated_sha256": sha256(args.generated_normal), "resolution": list(normal_image.size), "conversion": "DirectX green channel inverted for glTF/OpenGL"},
        "roughness": {"source": os.path.basename(args.roughness), "sha256": sha256(args.roughness), "resolution": list(rough_image.size)},
        "metallic": {"source": os.path.basename(args.metallic), "sha256": sha256(args.metallic), "resolution": list(metal_image.size)},
    }


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
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
    parser.add_argument("--fbx", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--base-color", required=True)
    parser.add_argument("--normal-directx", required=True)
    parser.add_argument("--roughness", required=True)
    parser.add_argument("--metallic", required=True)
    parser.add_argument("--generated-normal", required=True)
    parser.add_argument("--archive-sha256", required=True)
    args = parser.parse_args(script_args())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(Path(args.fbx).resolve()), use_anim=False)
    source = bpy.data.objects.get("M1911A1_lowPoly")
    if source is None or source.type != "MESH":
        raise RuntimeError("Expected M1911A1_lowPoly mesh is absent")
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
    parts.sort(key=lambda obj: len(obj.data.vertices), reverse=True)
    semantic_by_rank = {0: "Slide", 1: "Frame", 2: "Magazine", 3: "Barrel"}
    component_rows = []
    for index, obj in enumerate(parts):
        obj.data.calc_loop_triangles()
        obj.name = semantic_by_rank.get(index, f"MechanicalPart_{index:02d}")
        obj.data.name = obj.name + "Mesh"
        component_rows.append({
            "name": obj.name,
            "vertices": len(obj.data.vertices),
            "triangles": len(obj.data.loop_triangles),
            "source_origin": list(obj.matrix_world.translation),
            "pivot_status": "Inherited FBX/shared origin; production pivot preparation required",
        })

    material, textures = build_material(args)
    for obj in parts:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.hide_render = False

    minimum, maximum = bounds(parts)
    center = (minimum + maximum) * 0.5
    root = bpy.data.objects.new("WeaponRoot", None)
    root["asset_id"] = "eval_davidfalke_m1911a1"
    root["creator"] = "DavidFalke"
    root["source_page"] = "https://sketchfab.com/3d-models/vr-ready-m1911a1-421749c3fa1744a884a340f81ab45e3c"
    root["license"] = "CC Attribution"
    root["evaluation_only"] = True
    bpy.context.scene.collection.objects.link(root)
    for obj in parts:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world

    # Imported FBX: -X muzzle, +Y points toward the grip, +Z across the pistol.
    # Godot viewmodels: -Z muzzle, +Y up, +X across. Flip the authored vertical
    # so the grip points down and retain a right-handed transform.
    correction = Matrix(((0.0, 0.0, 1.0, 0.0), (0.0, -1.0, 0.0, 0.0), (1.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    root.matrix_world = correction @ Matrix.Translation(-center)

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(Path(args.output).resolve()), export_format="GLB", use_selection=True,
        export_apply=False, export_cameras=False, export_lights=False,
        export_animations=False, export_materials="EXPORT",
    )
    report = {
        "asset_id": "eval_davidfalke_m1911a1",
        "source_fbx_copy": str(Path(args.fbx).resolve()),
        "source_archive_sha256": args.archive_sha256,
        "source_was_saved": False,
        "blender_version": bpy.app.version_string,
        "selected_source_object": "M1911A1_lowPoly",
        "excluded_showcase_content": "Mirrored second pistol, loose showcase cartridges/shells, and ammunition display cluster",
        "separated_component_count": len(parts),
        "components": component_rows,
        "pbr_textures": textures,
        "generated_glb": os.path.basename(args.output),
        "generated_glb_bytes": os.path.getsize(args.output),
        "axis_conversion": "FBX -X muzzle/+Y grip/+Z across to Godot -Z muzzle/+Y up/+X across",
        "component_naming_note": "Four largest components named Slide/Frame/Magazine/Barrel by audited geometry; remaining loose mechanical pieces preserved generically for manual production identification and pivot setup.",
    }
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("M1911_EVALUATION_EXPORT=" + str(output))


if __name__ == "__main__":
    main()
