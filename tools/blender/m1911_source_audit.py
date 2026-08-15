"""Read-only FBX, hierarchy, topology, UV, pivot, and PBR audit for DavidFalke's M1911A1."""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import deque
from pathlib import Path

import bpy
from mathutils import Vector


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def topology(mesh: bpy.types.Mesh) -> dict[str, int]:
    face_counts = {tuple(sorted(edge.vertices)): 0 for edge in mesh.edges}
    for polygon in mesh.polygons:
        for edge_key in polygon.edge_keys:
            key = tuple(sorted(edge_key))
            face_counts[key] = face_counts.get(key, 0) + 1
    return {
        "boundary_edges": sum(count == 1 for count in face_counts.values()),
        "non_manifold_edges": sum(count != 2 for count in face_counts.values()),
        "edges_with_more_than_two_faces": sum(count > 2 for count in face_counts.values()),
        "zero_area_polygons": sum(poly.area <= 1.0e-12 for poly in mesh.polygons),
        "zero_length_polygon_normals": sum(poly.normal.length_squared <= 1.0e-12 for poly in mesh.polygons),
    }


def loose_parts(mesh: bpy.types.Mesh) -> list[dict[str, object]]:
    adjacency: list[list[int]] = [[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    unseen = set(range(len(mesh.vertices)))
    components: list[list[int]] = []
    while unseen:
        start = unseen.pop()
        queue = deque([start])
        component = [start]
        while queue:
            current = queue.popleft()
            for neighbor in adjacency[current]:
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    component.append(neighbor)
                    queue.append(neighbor)
        components.append(component)
    rows = []
    for index, vertices in enumerate(sorted(components, key=len, reverse=True)):
        points = [mesh.vertices[vertex].co for vertex in vertices]
        minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
        maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
        rows.append({
            "index_by_size": index,
            "vertex_count": len(vertices),
            "bounds_min_local": list(minimum),
            "bounds_max_local": list(maximum),
            "center_local": list((minimum + maximum) * 0.5),
            "dimensions_local": list(maximum - minimum),
        })
    return rows


def bounds_world(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return minimum, maximum


def image_metadata(path: Path) -> dict[str, object]:
    image = bpy.data.images.load(str(path.resolve()), check_existing=False)
    row = {
        "file": path.name,
        "bytes": path.stat().st_size,
        "resolution": list(image.size),
        "channels": image.channels,
        "colorspace": image.colorspace_settings.name,
    }
    bpy.data.images.remove(image)
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fbx", required=True)
    parser.add_argument("--textures", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--archive-sha256", required=True)
    args = parser.parse_args(script_args())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(Path(args.fbx).resolve()), use_anim=False)

    objects: list[dict[str, object]] = []
    totals = {"vertices": 0, "polygons": 0, "triangles": 0, "loose_parts": 0}
    for obj in bpy.context.scene.objects:
        row: dict[str, object] = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else "",
            "children": [child.name for child in obj.children],
            "location": list(obj.location),
            "world_origin": list(obj.matrix_world.translation),
            "rotation_degrees": [math.degrees(value) for value in obj.rotation_euler],
            "scale": list(obj.scale),
            "dimensions": list(obj.dimensions),
        }
        if obj.type == "MESH":
            mesh = obj.data
            mesh.calc_loop_triangles()
            minimum, maximum = bounds_world(obj)
            parts = loose_parts(mesh)
            uv_covered_vertices = {loop.vertex_index for loop in mesh.loops} if mesh.uv_layers.active else set()
            row.update({
                "mesh_data_name": mesh.name,
                "vertices": len(mesh.vertices),
                "edges": len(mesh.edges),
                "polygons": len(mesh.polygons),
                "triangles": len(mesh.loop_triangles),
                "loose_part_count": len(parts),
                "loose_parts": parts,
                "uv_layers": [layer.name for layer in mesh.uv_layers],
                "active_uv_layer": mesh.uv_layers.active.name if mesh.uv_layers.active else "",
                "vertices_without_uv": len(mesh.vertices) - len(uv_covered_vertices),
                "color_attributes": [attribute.name for attribute in mesh.color_attributes],
                "material_slots": [slot.material.name if slot.material else "" for slot in obj.material_slots],
                "bounds_min_world": list(minimum),
                "bounds_max_world": list(maximum),
                "origin_to_bounds_center": list((minimum + maximum) * 0.5 - obj.matrix_world.translation),
                "topology": topology(mesh),
            })
            totals["vertices"] += len(mesh.vertices)
            totals["polygons"] += len(mesh.polygons)
            totals["triangles"] += len(mesh.loop_triangles)
            totals["loose_parts"] += len(parts)
        objects.append(row)

    texture_dir = Path(args.textures)
    textures = [image_metadata(path) for path in sorted(texture_dir.iterdir()) if path.is_file()]
    report = {
        "asset": "VR Ready: M1911A1",
        "creator": "DavidFalke",
        "source_page": "https://sketchfab.com/3d-models/vr-ready-m1911a1-421749c3fa1744a884a340f81ab45e3c",
        "license": "Creative Commons Attribution (CC BY)",
        "archive_sha256": args.archive_sha256,
        "source_fbx_copy": str(Path(args.fbx).resolve()),
        "source_was_saved": False,
        "blender_version": bpy.app.version_string,
        "scene_object_count": len(bpy.context.scene.objects),
        "mesh_object_count": sum(obj.type == "MESH" for obj in bpy.context.scene.objects),
        "empty_object_count": sum(obj.type == "EMPTY" for obj in bpy.context.scene.objects),
        "material_count": len(bpy.data.materials),
        "totals": totals,
        "objects": objects,
        "materials": [
            {
                "name": material.name,
                "use_nodes": material.use_nodes,
                "blend_method": str(material.surface_render_method),
                "custom_properties": {key: material[key] for key in material.keys()},
            }
            for material in bpy.data.materials
        ],
        "supplied_textures": textures,
    }
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("M1911_SOURCE_AUDIT=" + str(output))


if __name__ == "__main__":
    main()
