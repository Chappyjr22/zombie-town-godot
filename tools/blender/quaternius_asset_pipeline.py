"""Normalize Quaternius Ultimate Guns Pack assets for Zombie Town.

Run with Blender's bundled Python, for example:

    blender --background --python tools/blender/quaternius_asset_pipeline.py -- \
        --source SubmachineGun_3.blend --output mp7.glb \
        --asset-id mp7 --kind weapon --grip-fraction 0.42

The source .blend is opened read-only. Only the requested GLB is written.
Weapon meshes are converted from the pack's +X barrel axis to Godot's -Z
forward convention at a consistent pack scale. A grip-relative root and named
attachment sockets are authored into the generated GLB. Accessories use the
same scale and receive a mounting-point root suitable for later socket use.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Iterable

import bpy
from mathutils import Matrix, Vector


PACK_METERS_PER_UNIT = 0.15
LICENSE_NAME = "CC0-1.0"
SOURCE_URL = "https://quaternius.com/packs/ultimategun.html"


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--kind", choices=("weapon", "attachment"), required=True)
    parser.add_argument("--slot", default="")
    parser.add_argument("--grip-fraction", type=float, default=0.45)
    parser.add_argument("--meters-per-unit", type=float, default=PACK_METERS_PER_UNIT)
    return parser.parse_args(argv)


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def world_bounds(objects: Iterable[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    if not points:
        raise RuntimeError("Source contains no measurable mesh objects")
    minimum = Vector(
        (
            min(point.x for point in points),
            min(point.y for point in points),
            min(point.z for point in points),
        )
    )
    maximum = Vector(
        (
            max(point.x for point in points),
            max(point.y for point in points),
            max(point.z for point in points),
        )
    )
    return minimum, maximum


def remove_non_mesh_source_objects() -> None:
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def apply_pack_correction(objects: list[bpy.types.Object], meters_per_unit: float) -> None:
    # Source axes: +X muzzle, +Z up, +Y across the weapon. Godot viewmodels:
    # -Z muzzle, +Y up, +X across the weapon. The -Y -> +X mapping preserves
    # handedness instead of reflecting the mesh.
    correction = Matrix(
        (
            (0.0, -1.0, 0.0),
            (0.0, 0.0, 1.0),
            (-1.0, 0.0, 0.0),
        )
    ).to_4x4()
    for obj in objects:
        obj.parent = None
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = correction.to_euler()
        obj.scale = Vector((meters_per_unit,) * 3)
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        obj.select_set(False)


def make_root(name: str, metadata: dict[str, object]) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.05
    for key, value in metadata.items():
        root[key] = value
    bpy.context.scene.collection.objects.link(root)
    return root


def make_marker(name: str, position: Vector, parent: bpy.types.Object) -> None:
    marker = bpy.data.objects.new(name, None)
    marker.empty_display_type = "ARROWS"
    marker.empty_display_size = 0.025
    marker.location = position
    marker.parent = parent
    bpy.context.scene.collection.objects.link(marker)


def parent_meshes(objects: list[bpy.types.Object], root: bpy.types.Object, pivot: Vector) -> None:
    for obj in objects:
        obj.location -= pivot
        obj.parent = root


def weapon_pivot(minimum: Vector, maximum: Vector, grip_fraction: float) -> Vector:
    size = maximum - minimum
    back_z = maximum.z
    return Vector(
        (
            (minimum.x + maximum.x) * 0.5,
            minimum.y + size.y * 0.48,
            back_z - size.z * grip_fraction,
        )
    )


def add_weapon_sockets(root: bpy.types.Object, minimum: Vector, maximum: Vector, pivot: Vector) -> None:
    size = maximum - minimum
    center_x = (minimum.x + maximum.x) * 0.5
    back_z = maximum.z
    front_z = minimum.z

    def local(x: float, y: float, z: float) -> Vector:
        return Vector((x, y, z)) - pivot

    sockets = {
        "Socket_PrimaryGrip": Vector((0.0, 0.0, 0.0)),
        "Socket_SupportGrip": local(center_x, minimum.y + size.y * 0.48, back_z - size.z * 0.68),
        "Socket_Muzzle": local(center_x, maximum.y - size.y * 0.31, front_z),
        "Socket_Optic": local(center_x, maximum.y, back_z - size.z * 0.50),
        "Socket_Underbarrel": local(center_x, minimum.y + size.y * 0.52, back_z - size.z * 0.69),
        "Socket_Magazine": local(center_x, minimum.y + size.y * 0.43, back_z - size.z * 0.53),
        "Socket_Stock": local(center_x, maximum.y - size.y * 0.38, back_z),
        "Socket_Side": local(maximum.x, maximum.y - size.y * 0.42, back_z - size.z * 0.58),
        "Socket_Bayonet": local(center_x, maximum.y - size.y * 0.43, front_z + size.z * 0.06),
    }
    for name, position in sockets.items():
        make_marker(name, position, root)


def attachment_pivot(slot: str, minimum: Vector, maximum: Vector) -> Vector:
    center = (minimum + maximum) * 0.5
    if slot == "optic":
        return Vector((center.x, minimum.y, center.z))
    if slot in {"underbarrel", "support"}:
        return Vector((center.x, maximum.y, center.z))
    if slot == "stock":
        return Vector((center.x, center.y, minimum.z))
    if slot in {"muzzle", "bayonet"}:
        return Vector((center.x, center.y, maximum.z))
    if slot == "side":
        return Vector((minimum.x, center.y, center.z))
    return center


def prepare_materials() -> None:
    """Convert legacy dual-output graphs to one glTF-compatible PBR graph."""
    for material in bpy.data.materials:
        authored_color = tuple(material.diffuse_color)
        material.use_nodes = True
        material.node_tree.nodes.clear()
        principled = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        principled.name = "Principled BSDF"
        output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
        output.name = "Material Output"
        output.is_active_output = True
        material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])

        base_color = principled.inputs.get("Base Color")
        if base_color is not None:
            base_color.default_value = authored_color
        roughness = principled.inputs.get("Roughness")
        if roughness is not None:
            if "Glass" in material.name:
                roughness.default_value = 0.16
            else:
                roughness.default_value = 0.38 if "Metal" in material.name else 0.52
        metallic = principled.inputs.get("Metallic IOR Level") or principled.inputs.get("Metallic")
        if metallic is not None:
            metallic.default_value = 0.55 if "Metal" in material.name else 0.0


def export_glb(output_path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(output_path),
        export_format="GLB",
        export_apply=False,
        export_extras=True,
        export_yup=True,
    )


def main() -> None:
    args = parse_args()
    source_path = os.path.abspath(args.source)
    if not os.path.isfile(source_path):
        raise FileNotFoundError(source_path)

    bpy.ops.wm.open_mainfile(filepath=source_path)
    remove_non_mesh_source_objects()
    objects = mesh_objects()
    if not objects:
        raise RuntimeError(f"No mesh objects found in {source_path}")
    if any(obj.find_armature() is not None for obj in objects):
        raise RuntimeError("This static pipeline will not flatten an armature-backed asset")

    apply_pack_correction(objects, args.meters_per_unit)
    prepare_materials()
    minimum, maximum = world_bounds(objects)
    metadata = {
        "asset_id": args.asset_id,
        "asset_kind": args.kind,
        "source_file": os.path.basename(source_path),
        "source_url": SOURCE_URL,
        "license": LICENSE_NAME,
        "pack_meters_per_unit": args.meters_per_unit,
    }

    if args.kind == "weapon":
        pivot = weapon_pivot(minimum, maximum, args.grip_fraction)
        root = make_root("WeaponRoot", metadata)
        parent_meshes(objects, root, pivot)
        add_weapon_sockets(root, minimum, maximum, pivot)
    else:
        metadata["attachment_slot"] = args.slot
        pivot = attachment_pivot(args.slot, minimum, maximum)
        root = make_root("AttachmentRoot", metadata)
        parent_meshes(objects, root, pivot)
        make_marker("MountPoint", Vector((0.0, 0.0, 0.0)), root)

    export_glb(args.output)
    final_minimum, final_maximum = world_bounds(objects)
    print(
        "ZT_QUATERNIUS_EXPORT="
        + json.dumps(
            {
                "asset_id": args.asset_id,
                "kind": args.kind,
                "source": source_path,
                "output": os.path.abspath(args.output),
                "mesh_objects": len(objects),
                "materials": [material.name for material in bpy.data.materials],
                "bounds_min": [round(value, 6) for value in final_minimum],
                "bounds_max": [round(value, 6) for value in final_maximum],
                "animations": len(bpy.data.actions),
                "armatures": len(bpy.data.armatures),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
