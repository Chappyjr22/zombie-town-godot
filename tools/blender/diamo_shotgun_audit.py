"""Read-only structural/PBR audit for a Diamo Studio shotgun BLEND file.

Run with Blender's ``--background source.blend --python``. The script writes
only the requested JSON report and never saves or modifies the opened source.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


COMPONENT_KEYWORDS = {
    "shells": ("shell", "cartridge", "round", "ammo"),
    "magazine_or_tube": ("mag", "magazine", "tube", "drum", "cylinder", "carrier"),
    "pump_or_fore_end": ("pump", "foreend", "fore end", "foregrip", "handguard", "slide"),
    "bolt": ("bolt", "breech"),
    "charging_handle": ("charging", "charge", "cocking", "handle"),
    "trigger": ("trigger",),
    "break_action_barrels": ("barrel", "barrels"),
    "hinge_or_action": ("hinge", "action", "break", "latch", "receiver"),
    "sights": ("sight", "iron", "bead"),
    "stock": ("stock", "butt"),
    "muzzle": ("muzzle", "choke", "compensator", "brake"),
    "moving_other": ("hammer", "lever", "release", "eject", "cover", "selector", "safety"),
}

MAP_CHANNELS = ("basecolor", "normal", "roughness", "metallic", "height")


def script_args():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


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
        root_a = find(a)
        root_b = find(b)
        if root_a != root_b:
            parent[root_b] = root_a

    for edge in mesh.edges:
        union(edge.vertices[0], edge.vertices[1])
    return len({find(index) for index in range(len(mesh.vertices))})


def bounds_world(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def topology_report(mesh):
    edge_face_counts = {tuple(sorted(edge.vertices)): 0 for edge in mesh.edges}
    for polygon in mesh.polygons:
        for edge_key in polygon.edge_keys:
            edge_face_counts[tuple(sorted(edge_key))] = edge_face_counts.get(tuple(sorted(edge_key)), 0) + 1
    return {
        "boundary_edges": sum(1 for count in edge_face_counts.values() if count == 1),
        "non_manifold_edges": sum(1 for count in edge_face_counts.values() if count != 2),
        "edges_with_more_than_two_faces": sum(1 for count in edge_face_counts.values() if count > 2),
        "zero_area_polygons": sum(1 for polygon in mesh.polygons if polygon.area <= 1.0e-12),
        "zero_length_polygon_normals": sum(1 for polygon in mesh.polygons if polygon.normal.length_squared <= 1.0e-12),
    }


def normalized(name):
    return name.lower().replace("_", " ").replace("-", " ").replace(".", " ")


def matches(name, keywords):
    value = normalized(name)
    return any(keyword in value for keyword in keywords)


def material_report(material):
    images = []
    if material and material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            image = node.image
            images.append({
                "node": node.name,
                "image": image.name,
                "filepath": bpy.path.abspath(image.filepath) if image.filepath else "",
                "packed": image.packed_file is not None,
                "size": list(image.size),
                "colorspace": image.colorspace_settings.name,
            })
    return {
        "name": material.name if material else "",
        "use_nodes": bool(material and material.use_nodes),
        "images": images,
    }


def supplied_texture_report(asset_dir):
    rows = []
    pbr_dir = Path(asset_dir) / "PBR Textures"
    for path in sorted(pbr_dir.glob("*.png")):
        image = bpy.data.images.load(str(path.resolve()), check_existing=False)
        lower_name = path.stem.lower()
        channel = next((value for value in MAP_CHANNELS if lower_name.endswith("_" + value)), "other")
        rows.append({
            "file": path.name,
            "channel": channel,
            "size": list(image.size),
            "bytes": path.stat().st_size,
        })
        bpy.data.images.remove(image)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--source-label", required=True)
    parser.add_argument("--asset-dir", required=True)
    args = parser.parse_args(script_args())

    object_rows = []
    component_matches = {key: [] for key in COMPONENT_KEYWORDS}
    totals = {"vertices": 0, "polygons": 0, "triangles": 0, "connected_islands": 0}
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
            "hidden_render": obj.hide_render,
            "modifier_types": [modifier.type for modifier in obj.modifiers],
        }
        if obj.type == "MESH":
            mesh = obj.data
            mesh.calc_loop_triangles()
            islands = connected_components(mesh)
            minimum, maximum = bounds_world(obj)
            bounds_center = (minimum + maximum) * 0.5
            row.update({
                "mesh_data_name": mesh.name,
                "vertices": len(mesh.vertices),
                "edges": len(mesh.edges),
                "polygons": len(mesh.polygons),
                "triangles": len(mesh.loop_triangles),
                "connected_islands": islands,
                "material_slots": [slot.material.name if slot.material else "" for slot in obj.material_slots],
                "bounds_min_world": list(minimum),
                "bounds_max_world": list(maximum),
                "origin_to_bounds_center": list(bounds_center - obj.matrix_world.translation),
                "topology": topology_report(mesh),
            })
            totals["vertices"] += len(mesh.vertices)
            totals["polygons"] += len(mesh.polygons)
            totals["triangles"] += len(mesh.loop_triangles)
            totals["connected_islands"] += islands
        object_rows.append(row)
        for component, keywords in COMPONENT_KEYWORDS.items():
            if matches(obj.name, keywords):
                component_matches[component].append(obj.name)

    asset_dir = Path(args.asset_dir)
    report = {
        "source_label": args.source_label,
        "source_blend": bpy.data.filepath,
        "source_blender_version": list(bpy.data.version),
        "audited_with_blender_version": bpy.app.version_string,
        "source_was_saved": False,
        "source_formats": {
            extension[1:]: sorted(path.name for path in asset_dir.glob("*" + extension))
            for extension in (".blend", ".fbx", ".obj")
        },
        "scene_object_count": len(bpy.context.scene.objects),
        "mesh_object_count": sum(1 for obj in bpy.context.scene.objects if obj.type == "MESH"),
        "material_count": len(bpy.data.materials),
        "image_count_in_blend": len(bpy.data.images),
        "total_vertices": totals["vertices"],
        "total_polygons": totals["polygons"],
        "total_triangles": totals["triangles"],
        "total_connected_mesh_islands": totals["connected_islands"],
        "objects": object_rows,
        "materials_in_blend": [material_report(material) for material in bpy.data.materials],
        "supplied_pbr_textures": supplied_texture_report(asset_dir),
        "named_component_matches": component_matches,
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("DIAMO_SHOTGUN_AUDIT=" + str(report_path))


if __name__ == "__main__":
    main()
