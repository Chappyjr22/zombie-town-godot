"""Audit and export one OBUR Games weapon as an isolated evaluation GLB.

The input is an untouched combined FBX from an authenticated Sketchfab
download. Only the named weapon mesh is retained. Source object placement is
discarded because OBUR's pack FBXs arrange ten independently-authored weapon
meshes around a showcase scene.

Example:

    blender --background --factory-startup \
        --python tools/blender/obur_evaluation_pipeline.py -- \
        --source 20_100.fbx --palette BerkPalet.png \
        --object Colt_M16A2 --asset-id colt_m16a2 \
        --target-length 1.006 --output colt_m16a2.glb \
        --report colt_m16a2.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


CREATOR = "OBUR Games"
LICENSE = "CC-BY-4.0"


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--palette", required=True)
    parser.add_argument("--object", required=True, dest="object_name")
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--target-length", required=True, type=float)
    parser.add_argument("--source-page", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(argv)


def rounded_vector(value: Vector) -> list[float]:
    return [round(float(component), 6) for component in value]


def local_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(point[index] for point in points) for index in range(3))),
        Vector(tuple(max(point[index] for point in points) for index in range(3))),
    )


def audit_topology(mesh: bpy.types.Mesh) -> dict[str, object]:
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    boundary_edges = sum(1 for edge in bm.edges if edge.is_boundary)
    non_manifold_edges = sum(
        1 for edge in bm.edges if not edge.is_manifold and not edge.is_boundary
    )
    loose_edges = sum(1 for edge in bm.edges if len(edge.link_faces) == 0)
    loose_vertices = sum(1 for vertex in bm.verts if len(vertex.link_edges) == 0)
    bm.free()
    return {
        "vertices": len(mesh.vertices),
        "edges": len(mesh.edges),
        "polygons": len(mesh.polygons),
        "triangles": len(mesh.loop_triangles),
        "ngons": sum(1 for polygon in mesh.polygons if len(polygon.vertices) > 4),
        "degenerate_polygons": sum(1 for polygon in mesh.polygons if polygon.area <= 1e-10),
        "zero_length_polygon_normals": sum(
            1 for polygon in mesh.polygons if polygon.normal.length_squared <= 1e-12
        ),
        "boundary_edges": boundary_edges,
        "non_manifold_edges": non_manifold_edges,
        "loose_edges": loose_edges,
        "loose_vertices": loose_vertices,
        "uv_layers": [layer.name for layer in mesh.uv_layers],
        "color_attributes": [attribute.name for attribute in mesh.color_attributes],
    }


def material_audit(obj: bpy.types.Object) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for material in obj.data.materials:
        if material is None:
            continue
        images: list[dict[str, object]] = []
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type != "TEX_IMAGE" or node.image is None:
                    continue
                images.append(
                    {
                        "name": node.image.name,
                        "path": node.image.filepath,
                        "loaded_size": list(node.image.size[:]),
                        "available_before_repair": bool(node.image.size[0] and node.image.size[1]),
                    }
                )
        principled = (
            next(
                (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
                None,
            )
            if material.use_nodes
            else None
        )
        result.append(
            {
                "name": material.name,
                "roughness": round(float(principled.inputs["Roughness"].default_value), 6)
                if principled
                else None,
                "metallic": round(float(principled.inputs["Metallic"].default_value), 6)
                if principled
                else None,
                "images": images,
            }
        )
    return result


def repair_palette_materials(obj: bpy.types.Object, palette_path: str) -> None:
    palette = bpy.data.images.load(palette_path, check_existing=False)
    palette.name = f"{obj.name}_OBUR_Palette"
    for material in obj.data.materials:
        if material is None:
            continue
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        principled = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            principled = nodes.new("ShaderNodeBsdfPrincipled")
        output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL"), None)
        if output is None:
            output = nodes.new("ShaderNodeOutputMaterial")
        authored_roughness = float(principled.inputs["Roughness"].default_value)
        authored_metallic = float(principled.inputs["Metallic"].default_value)
        for node in list(nodes):
            if node.type == "TEX_IMAGE":
                nodes.remove(node)
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.name = "OBUR Palette"
        image_node.image = palette
        image_node.interpolation = "Closest"
        links.new(image_node.outputs["Color"], principled.inputs["Base Color"])
        if not any(link.to_node == output and link.to_socket.name == "Surface" for link in links):
            links.new(principled.outputs["BSDF"], output.inputs["Surface"])
        principled.inputs["Roughness"].default_value = authored_roughness
        principled.inputs["Metallic"].default_value = authored_metallic


def isolate_and_normalize(obj: bpy.types.Object, target_length: float, asset_id: str) -> bpy.types.Object:
    for other in list(bpy.data.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)

    # Discard the showcase placement while preserving the weapon's local mesh.
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    minimum, maximum = local_bounds(obj)
    source_length = max(maximum.x - minimum.x, 1e-8)

    # OBUR local axes: +X muzzle, +Z up. Godot viewmodel axes: -Z muzzle,
    # +Y up, +X across. This is a handedness-preserving rotation.
    correction = Matrix(
        (
            (0.0, -1.0, 0.0),
            (0.0, 0.0, 1.0),
            (-1.0, 0.0, 0.0),
        )
    ).to_4x4()
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = correction.to_euler()
    uniform_scale = target_length / source_length
    obj.scale = Vector((uniform_scale,) * 3)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)

    root = bpy.data.objects.new("WeaponRoot", None)
    root["asset_id"] = asset_id
    root["creator"] = CREATOR
    root["license"] = LICENSE
    bpy.context.scene.collection.objects.link(root)
    obj.name = asset_id
    obj.parent = root

    corrected_minimum, corrected_maximum = local_bounds(obj)
    center = (corrected_minimum + corrected_maximum) * 0.5
    obj.location = -center
    return root


def export_glb(root: bpy.types.Object, obj: bpy.types.Object, output_path: str) -> None:
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )


def main() -> None:
    args = parse_args()
    bpy.ops.wm.fbx_import(filepath=os.path.abspath(args.source))
    obj = bpy.data.objects.get(args.object_name)
    if obj is None or obj.type != "MESH":
        available = sorted(item.name for item in bpy.data.objects if item.type == "MESH")
        raise RuntimeError(f"Mesh {args.object_name!r} not found; available: {available}")

    minimum, maximum = local_bounds(obj)
    report = {
        "asset_id": args.asset_id,
        "source_object": args.object_name,
        "source_fbx": os.path.basename(args.source),
        "source_page": args.source_page,
        "creator": CREATOR,
        "license": LICENSE,
        "blender_version": bpy.app.version_string,
        "source_object_count": len(bpy.data.objects),
        "weapon_mesh_object_count": 1,
        "important_moving_components_separate": False,
        "source_transform": {
            "location": rounded_vector(obj.location),
            "rotation_degrees": rounded_vector(Vector(tuple(value * 57.295779513 for value in obj.rotation_euler))),
            "scale": rounded_vector(obj.scale),
        },
        "source_local_bounds": {
            "minimum": rounded_vector(minimum),
            "maximum": rounded_vector(maximum),
            "size": rounded_vector(maximum - minimum),
        },
        "topology": audit_topology(obj.data),
        "materials_before_repair": material_audit(obj),
        "material_repair": "Relinked the supplied shared palette texture while preserving each authored material's metallic and roughness values.",
        "target_length_meters": args.target_length,
        "axis_conversion": "OBUR +X muzzle/+Z up to Godot -Z muzzle/+Y up",
    }

    repair_palette_materials(obj, os.path.abspath(args.palette))
    root = isolate_and_normalize(obj, args.target_length, args.asset_id)
    export_glb(root, obj, os.path.abspath(args.output))
    report["generated_glb"] = os.path.basename(args.output)
    report["generated_glb_bytes"] = os.path.getsize(args.output)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    with open(args.report, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print("OBUR_EVALUATION_EXPORT: " + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
