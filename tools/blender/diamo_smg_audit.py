"""Read-only structural audit for a Diamo Studio weapon .blend file.

Run with Blender's ``--background source.blend --python``. The script writes
only the requested JSON report and never saves the opened source file.
"""

import argparse
import json
import math
import os
from pathlib import Path

import bpy


COMPONENT_KEYWORDS = {
    "magazine": ("mag", "magazine", "clip", "drum"),
    "trigger": ("trigger",),
    "bolt": ("bolt", "breech"),
    "charging_handle": ("charging", "charge", "cocking", "handle"),
    "fire_selector": ("selector", "safety", "switch", "fire mode"),
    "stock": ("stock", "butt"),
    "sights": ("sight", "iron", "rear sight", "front sight"),
    "muzzle": ("muzzle", "flash", "compensator", "brake", "suppressor", "barrel"),
    "moving_other": ("slide", "hammer", "lever", "release", "eject", "dust cover", "cover"),
}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--source-label", default="")
    return parser.parse_args(bpy.app.driver_namespace.get("argv", []))


def script_args():
    import sys

    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def connected_components(mesh):
    vertex_count = len(mesh.vertices)
    if vertex_count == 0:
        return 0
    parent = list(range(vertex_count))

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
    return len({find(index) for index in range(vertex_count)})


def material_report(material):
    images = []
    if material and material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            image = node.image
            images.append(
                {
                    "node": node.name,
                    "image": image.name,
                    "filepath": bpy.path.abspath(image.filepath) if image.filepath else "",
                    "packed": image.packed_file is not None,
                    "size": list(image.size),
                    "colorspace": image.colorspace_settings.name,
                }
            )
    return {
        "name": material.name if material else "",
        "use_nodes": bool(material and material.use_nodes),
        "blend_method": getattr(material, "surface_render_method", "") if material else "",
        "images": images,
    }


def matches_component(name, keywords):
    normalized = name.lower().replace("_", " ").replace("-", " ")
    return any(keyword in normalized for keyword in keywords)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--source-label", default="")
    args = parser.parse_args(script_args())

    object_rows = []
    total_triangles = 0
    total_vertices = 0
    total_polygons = 0
    total_islands = 0
    component_matches = {key: [] for key in COMPONENT_KEYWORDS}

    for obj in bpy.context.scene.objects:
        row = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else "",
            "collection_names": [collection.name for collection in obj.users_collection],
            "location": list(obj.location),
            "rotation_degrees": [math.degrees(value) for value in obj.rotation_euler],
            "scale": list(obj.scale),
            "dimensions": list(obj.dimensions),
            "hidden_render": obj.hide_render,
            "modifier_types": [modifier.type for modifier in obj.modifiers],
        }
        if obj.type == "MESH":
            mesh = obj.data
            mesh.calc_loop_triangles()
            triangles = len(mesh.loop_triangles)
            islands = connected_components(mesh)
            row.update(
                {
                    "vertices": len(mesh.vertices),
                    "edges": len(mesh.edges),
                    "polygons": len(mesh.polygons),
                    "triangles": triangles,
                    "connected_islands": islands,
                    "material_slots": [slot.material.name if slot.material else "" for slot in obj.material_slots],
                    "shape_keys": [key.name for key in mesh.shape_keys.key_blocks] if mesh.shape_keys else [],
                }
            )
            total_triangles += triangles
            total_vertices += len(mesh.vertices)
            total_polygons += len(mesh.polygons)
            total_islands += islands
        object_rows.append(row)
        for component, keywords in COMPONENT_KEYWORDS.items():
            if matches_component(obj.name, keywords):
                component_matches[component].append(obj.name)

    materials = [material_report(material) for material in bpy.data.materials]
    report = {
        "source_label": args.source_label,
        "source_blend": bpy.data.filepath,
        "source_blender_version": list(bpy.data.version),
        "audited_with_blender_version": bpy.app.version_string,
        "scene_object_count": len(bpy.context.scene.objects),
        "mesh_object_count": sum(1 for obj in bpy.context.scene.objects if obj.type == "MESH"),
        "material_count": len(bpy.data.materials),
        "image_count": len(bpy.data.images),
        "total_vertices": total_vertices,
        "total_polygons": total_polygons,
        "total_triangles": total_triangles,
        "total_connected_mesh_islands": total_islands,
        "objects": object_rows,
        "materials": materials,
        "named_component_matches": component_matches,
        "source_was_saved": False,
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("DIAMO_AUDIT_REPORT=" + str(report_path))


if __name__ == "__main__":
    main()
