"""Read-only structure/PBR audit for Diamo launcher and sniper BLEND sources."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


COMPONENT_KEYWORDS = {
    "cylinder_drum_or_magazine": ("cylinder", "drum", "mag", "magazine", "clip"),
    "breech_or_action": ("breech", "action", "bolt", "chamber"),
    "trigger": ("trigger",),
    "launcher_tube_or_barrel": ("tube", "launcher", "barrel"),
    "sights_or_optic": ("sight", "scope", "optic", "front", "rear"),
    "loading_mechanism": ("loading", "loader", "latch", "hinge", "door", "cover"),
    "rocket_or_projectile": ("rocket", "projectile", "missile", "grenade", "warhead"),
    "charging_handle": ("charging", "cocking", "handle"),
    "stock": ("stock",),
    "bipod": ("bipod", "leg"),
}

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".tga", ".tif", ".tiff"}
PBR_CHANNELS = ("basecolor", "normal", "roughness", "metallic", "height", "ao", "opacity", "emissive")


def script_args():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def normalized(name):
    return name.lower().replace("_", " ").replace("-", " ").replace(".", " ")


def connected_components(mesh):
    if not mesh.vertices:
        return 0
    parent = list(range(len(mesh.vertices)))

    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    def union(a, b):
        a, b = find(a), find(b)
        if a != b:
            parent[b] = a

    for edge in mesh.edges:
        union(edge.vertices[0], edge.vertices[1])
    return len({find(index) for index in range(len(mesh.vertices))})


def topology(mesh):
    counts = {tuple(sorted(edge.vertices)): 0 for edge in mesh.edges}
    for polygon in mesh.polygons:
        for edge_key in polygon.edge_keys:
            key = tuple(sorted(edge_key))
            counts[key] = counts.get(key, 0) + 1
    return {
        "boundary_edges": sum(count == 1 for count in counts.values()),
        "non_manifold_edges": sum(count != 2 for count in counts.values()),
        "edges_with_more_than_two_faces": sum(count > 2 for count in counts.values()),
        "zero_area_polygons": sum(polygon.area <= 1.0e-12 for polygon in mesh.polygons),
        "zero_length_polygon_normals": sum(polygon.normal.length_squared <= 1.0e-12 for polygon in mesh.polygons),
    }


def object_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def material_report(material):
    images = []
    if material and material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                images.append({
                    "image": node.image.name,
                    "filepath": bpy.path.abspath(node.image.filepath) if node.image.filepath else "",
                    "packed": node.image.packed_file is not None,
                    "size": list(node.image.size),
                    "colorspace": node.image.colorspace_settings.name,
                })
    return {"name": material.name if material else "", "images": images}


def supplied_pbr(asset_dir):
    directories = [
        path for path in Path(asset_dir).iterdir()
        if path.is_dir() and path.name.lower() in ("pbr", "pbr texture", "pbr textures")
    ]
    rows = []
    for directory in directories:
        for path in sorted(candidate for candidate in directory.iterdir() if candidate.suffix.lower() in IMAGE_EXTENSIONS):
            image = bpy.data.images.load(str(path.resolve()), check_existing=False)
            compact = path.stem.lower().replace(" ", "").replace("-", "").replace("_", "")
            channel = next((value for value in PBR_CHANNELS if compact.endswith(value)), "other")
            rows.append({"file": path.name, "channel": channel, "size": list(image.size), "bytes": path.stat().st_size})
            bpy.data.images.remove(image)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--source-label", required=True)
    parser.add_argument("--asset-dir", required=True)
    parser.add_argument("--category", choices=("launcher", "sniper"), required=True)
    args = parser.parse_args(script_args())
    object_rows = []
    components = {key: [] for key in COMPONENT_KEYWORDS}
    totals = {"vertices": 0, "polygons": 0, "triangles": 0, "islands": 0}
    scene_minimum = Vector((float("inf"),) * 3)
    scene_maximum = Vector((float("-inf"),) * 3)
    for obj in bpy.context.scene.objects:
        row = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else "",
            "location": list(obj.location),
            "world_origin": list(obj.matrix_world.translation),
            "rotation_degrees": [math.degrees(value) for value in obj.rotation_euler],
            "scale": list(obj.scale),
            "dimensions": list(obj.dimensions),
        }
        if obj.type == "MESH":
            mesh = obj.data
            mesh.calc_loop_triangles()
            islands = connected_components(mesh)
            minimum, maximum = object_bounds(obj)
            for index in range(3):
                scene_minimum[index] = min(scene_minimum[index], minimum[index])
                scene_maximum[index] = max(scene_maximum[index], maximum[index])
            row.update({
                "mesh_data_name": mesh.name,
                "vertices": len(mesh.vertices),
                "polygons": len(mesh.polygons),
                "triangles": len(mesh.loop_triangles),
                "connected_islands": islands,
                "material_slots": [slot.material.name if slot.material else "" for slot in obj.material_slots],
                "bounds_min_world": list(minimum),
                "bounds_max_world": list(maximum),
                "origin_to_bounds_center": list((minimum + maximum) * 0.5 - obj.matrix_world.translation),
                "shape_keys": list(mesh.shape_keys.key_blocks.keys()) if mesh.shape_keys else [],
                "topology": topology(mesh),
            })
            totals["vertices"] += len(mesh.vertices)
            totals["polygons"] += len(mesh.polygons)
            totals["triangles"] += len(mesh.loop_triangles)
            totals["islands"] += islands
        object_rows.append(row)
        names = normalized(obj.name + " " + (obj.data.name if obj.type == "MESH" else ""))
        for component, keywords in COMPONENT_KEYWORDS.items():
            if any(keyword in names for keyword in keywords):
                components[component].append(obj.name)
    asset_dir = Path(args.asset_dir)
    report = {
        "source_label": args.source_label,
        "category": args.category,
        "source_blend": bpy.data.filepath,
        "source_blender_version": list(bpy.data.version),
        "audited_with_blender_version": bpy.app.version_string,
        "source_was_saved": False,
        "source_formats": {
            extension[1:]: sorted(path.name for path in asset_dir.glob("*" + extension))
            for extension in (".blend", ".fbx", ".obj")
        },
        "scene_object_count": len(bpy.context.scene.objects),
        "mesh_object_count": sum(obj.type == "MESH" for obj in bpy.context.scene.objects),
        "material_count": len(bpy.data.materials),
        "image_count_in_blend": len(bpy.data.images),
        "total_vertices": totals["vertices"],
        "total_polygons": totals["polygons"],
        "total_triangles": totals["triangles"],
        "total_connected_mesh_islands": totals["islands"],
        "scene_bounds_min_world": list(scene_minimum),
        "scene_bounds_max_world": list(scene_maximum),
        "scene_dimensions_world": list(scene_maximum - scene_minimum),
        "objects": object_rows,
        "materials_in_blend": [material_report(material) for material in bpy.data.materials],
        "supplied_pbr_textures": supplied_pbr(asset_dir),
        "named_component_matches": components,
    }
    path = Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("DIAMO_LAUNCHER_SNIPER_AUDIT=" + str(path))


if __name__ == "__main__":
    main()
