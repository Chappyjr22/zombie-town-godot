"""Export one cartridge and one casing from a temporary M1911 source copy.

The original archive remains untouched. Outputs are small modular production
derivatives for future chamber/reload/ejection animation work.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def image(path: Path, name: str, non_color: bool, size: int) -> bpy.types.Image:
    result = bpy.data.images.load(str(path.resolve()), check_existing=False)
    result.name = name
    if non_color:
        result.colorspace_settings.name = "Non-Color"
    longest = max(result.size)
    if longest > size:
        scale = size / float(longest)
        result.scale(round(result.size[0] * scale), round(result.size[1] * scale))
    return result


def material(args: argparse.Namespace) -> bpy.types.Material:
    base = image(Path(args.base_color), "Ballistics_BaseColor", False, args.texture_size)
    roughness = image(Path(args.roughness), "Ballistics_Roughness", True, args.texture_size)
    metallic = image(Path(args.metallic), "Ballistics_Metallic", True, args.texture_size)
    source_normal = image(Path(args.normal_directx), "Ballistics_Normal_DirectX", True, args.texture_size)
    pixels = np.empty(source_normal.size[0] * source_normal.size[1] * 4, dtype=np.float32)
    source_normal.pixels.foreach_get(pixels)
    pixels[1::4] = 1.0 - pixels[1::4]
    normal = bpy.data.images.new("Ballistics_Normal_OpenGL", source_normal.size[0], source_normal.size[1], alpha=True)
    normal.colorspace_settings.name = "Non-Color"
    normal.pixels.foreach_set(pixels)

    result = bpy.data.materials.new("DavidFalke_M1911_Ballistics_PBR")
    result.use_nodes = True
    nodes = result.node_tree.nodes
    links = result.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for channel, source, input_name in (
        ("BaseColor", base, "Base Color"),
        ("Roughness", roughness, "Roughness"),
        ("Metallic", metallic, "Metallic"),
    ):
        node = nodes.new("ShaderNodeTexImage")
        node.name = channel
        node.image = source
        links.new(node.outputs["Color"], shader.inputs[input_name])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.name = "Normal OpenGL"
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    return result


def center_and_scale(obj: bpy.types.Object, target_length: float) -> None:
    dimensions = obj.dimensions
    longest_axis = max(range(3), key=lambda axis: dimensions[axis])
    if longest_axis == 0:
        obj.matrix_world = Matrix.Rotation(math.radians(90.0), 4, "Y") @ obj.matrix_world
    elif longest_axis == 1:
        obj.matrix_world = Matrix.Rotation(math.radians(90.0), 4, "X") @ obj.matrix_world
    obj.scale *= target_length / max(obj.dimensions.z, 0.000001)
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    center = sum(points, Vector()) / len(points)
    obj.matrix_world = Matrix.Translation(-center) @ obj.matrix_world


def export_component(source: bpy.types.Object, name: str, output: Path, target_length: float, mat: bpy.types.Material) -> dict[str, object]:
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.parent = None
    obj.matrix_world = source.matrix_world.copy()
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    center_and_scale(obj, target_length)
    root = bpy.data.objects.new(name + "Root", None)
    root["production_component"] = True
    root["creator"] = "DavidFalke"
    root["license"] = "Creative Commons Attribution"
    root["component_role"] = name.lower()
    bpy.context.scene.collection.objects.link(root)
    world = obj.matrix_world.copy()
    obj.parent = root
    obj.matrix_world = world
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(output.resolve()), export_format="GLB", use_selection=True,
        export_apply=False, export_cameras=False, export_lights=False,
        export_animations=False, export_materials="EXPORT", export_extras=True,
    )
    obj.data.calc_loop_triangles()
    row = {"name": name, "triangles": len(obj.data.loop_triangles), "target_length_meters": target_length,
           "output": output.name, "bytes": output.stat().st_size, "sha256": sha256(output)}
    bpy.data.objects.remove(root, do_unlink=True)
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fbx", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--base-color", required=True)
    parser.add_argument("--normal-directx", required=True)
    parser.add_argument("--roughness", required=True)
    parser.add_argument("--metallic", required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--texture-size", type=int, default=1024)
    args = parser.parse_args(script_args())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(Path(args.fbx).resolve()), use_anim=False)
    cartridge = bpy.data.objects.get("bullet_2_low1")
    casing = bpy.data.objects.get("bullet_shell_2_low1")
    if cartridge is None or casing is None:
        raise RuntimeError("Expected source cartridge/casing objects are missing")
    mat = material(args)
    output_dir = Path(args.output_directory)
    rows = [
        export_component(cartridge, "Cartridge", output_dir / "m1911_cartridge.glb", 0.032, mat),
        export_component(casing, "Casing", output_dir / "m1911_casing.glb", 0.023, mat),
    ]
    report = {"source_archive_sha256": args.archive_sha256.upper(), "source_was_modified": False,
              "blender_version": bpy.app.version_string, "texture_size": args.texture_size, "components": rows}
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("M1911_BALLISTICS_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
