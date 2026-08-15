"""Promote an approved evaluation GLB into a clean production-candidate GLB.

The script works only on generated evaluation derivatives. Purchased/original
archives and source files are never opened or saved. It preserves useful moving
components, adds stable hierarchy/socket names, embeds optimized PBR textures,
and writes a machine-readable production report.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector


M1911_NAMES = {
    "Slide": "SlideBody",
    "Frame": "FrameBody",
    "Magazine": "MagazineBody",
    "Barrel": "Barrel",
    "MechanicalPart_07": "GripPanelLeft",
    "MechanicalPart_08": "GripPanelRight",
    "MechanicalPart_09": "Hammer",
    "MechanicalPart_11": "RearSight",
    "MechanicalPart_12": "BarrelBushing",
    "MechanicalPart_14": "Trigger",
    "MechanicalPart_25": "SlideStop",
    "MechanicalPart_26": "MagazineRelease",
    "MechanicalPart_28": "GripSafety",
    "MechanicalPart_34": "MagazineBaseplate",
    "MechanicalPart_35": "ThumbSafety",
    "MechanicalPart_36": "FrontSight",
}

M1911_FRAME_PARTS = {
    "FrameBody", "GripPanelLeft", "GripPanelRight", "GripSafety",
    "MagazineRelease", "FrameHardware_04", "FrameHardware_05",
    "FrameHardware_06", "FrameHardware_10", "FrameHardware_13",
    "FrameHardware_15", "FrameHardware_16", "FrameHardware_17",
    "FrameHardware_18", "FrameHardware_19", "FrameHardware_20",
    "FrameHardware_21", "FrameHardware_22", "FrameHardware_23",
    "FrameHardware_24", "FrameHardware_27", "FrameHardware_29",
    "FrameHardware_30", "FrameHardware_31", "FrameHardware_32",
}

PRODUCTION_ASSET_CORRECTIONS = {
    # Evaluation derivatives point their muzzles toward +Z. Production
    # viewmodels use Godot camera-forward (-Z), so bake the forward-axis fix
    # into the asset instead of compensating in presentation poses.
    # Godot's GLB mesh import flips the exported Z direction. The DavidFalke
    # M1911 therefore uses +90 degrees around X plus a canonical-space roll:
    # exported mesh-forward +Z becomes runtime viewmodel-forward -Z, while +Y
    # remains upright. Socket nodes are authored directly in Godot coordinates.
    "m1911": {"long_axis_degrees": 90.0, "roll_degrees": 180.0, "yaw_degrees": 0.0},
    "mp7": {"long_axis_degrees": None, "roll_degrees": 180.0, "yaw_degrees": 180.0},
    "ump": {"long_axis_degrees": None, "roll_degrees": 180.0, "yaw_degrees": 180.0},
    # These evaluation derivatives are already authored in the project's
    # canonical -Z-forward/+Y-up convention.
    "hk416": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
    "m16": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
    "rpd": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
    "benelli_m4": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
    "aa12": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
    # The M200 evaluation derivative's long axis is normalized, but its muzzle
    # faces +Z. Bake the 180-degree yaw here so presentation profiles never
    # need a model-specific backwards correction.
    "cheytac_m200": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 180.0},
    "rpg7": {"long_axis_degrees": None, "roll_degrees": 0.0, "yaw_degrees": 0.0},
}


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--asset-id",
        choices=(
            "m1911", "mp7", "ump", "hk416", "m16", "rpd",
            "benelli_m4", "aa12", "cheytac_m200", "rpg7",
        ),
        required=True,
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--source-archive-sha256", required=True)
    parser.add_argument("--texture-size", type=int, default=2048)
    return parser.parse_args(script_args())


def sha256(path: str | Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    return minimum, maximum


def object_center(obj: bpy.types.Object) -> Vector:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return sum(points, Vector()) / len(points)


def normalize_mesh_transforms(
    meshes: list[bpy.types.Object],
    target_length: float,
    canonical_roll_degrees: float = 0.0,
    canonical_yaw_degrees: float = 0.0,
    long_axis_degrees: float | None = None,
) -> dict[str, object]:
    """Bake axis, metric scale, and centered origin into imported mesh transforms."""
    minimum, maximum = world_bounds(meshes)
    size = maximum - minimum
    correction = Matrix.Identity(4)
    source_long_axis = "Z"
    applied_long_axis_degrees = 0.0
    if size.y > size.z and size.y >= size.x:
        applied_long_axis_degrees = 90.0 if long_axis_degrees is None else long_axis_degrees
        correction = Matrix.Rotation(math.radians(applied_long_axis_degrees), 4, "X")
        source_long_axis = "Y"
    elif size.x > size.z and size.x >= size.y:
        applied_long_axis_degrees = 90.0 if long_axis_degrees is None else long_axis_degrees
        correction = Matrix.Rotation(math.radians(applied_long_axis_degrees), 4, "Y")
        source_long_axis = "X"
    if canonical_roll_degrees:
        correction = Matrix.Rotation(math.radians(canonical_roll_degrees), 4, "Z") @ correction
    if canonical_yaw_degrees:
        correction = Matrix.Rotation(math.radians(canonical_yaw_degrees), 4, "Y") @ correction
    for obj in meshes:
        obj.matrix_world = correction @ obj.matrix_world
    minimum, maximum = world_bounds(meshes)
    current_length = max(maximum.z - minimum.z, 0.000001)
    uniform_scale = target_length / current_length
    scale_matrix = Matrix.Scale(uniform_scale, 4)
    for obj in meshes:
        obj.matrix_world = scale_matrix @ obj.matrix_world
    minimum, maximum = world_bounds(meshes)
    center = (minimum + maximum) * 0.5
    translation = Matrix.Translation(-center)
    for obj in meshes:
        obj.matrix_world = translation @ obj.matrix_world
    return {
        "source_long_axis": source_long_axis,
        "long_axis_rotation_degrees": applied_long_axis_degrees,
        "target_length_meters": target_length,
        "uniform_scale": uniform_scale,
        "centered_origin": True,
        "canonical_roll_degrees": canonical_roll_degrees,
        "canonical_yaw_degrees": canonical_yaw_degrees,
    }


def bake_mesh_world_transforms(meshes: list[bpy.types.Object]) -> None:
    """Bake corrected world transforms into mesh data before adding pivots."""
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.data.transform(world)
        obj.data.update()
        obj.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()


def new_empty(name: str, parent: bpy.types.Object | None = None, location: Vector | None = None) -> bpy.types.Object:
    result = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(result)
    result.location = location if location is not None else Vector()
    if parent is not None:
        result.parent = parent
    return result


def parent_preserve(obj: bpy.types.Object, parent: bpy.types.Object) -> None:
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def optimize_images(target_size: int) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for image in bpy.data.images:
        if image.type != "IMAGE" or image.size[0] < 1 or image.size[1] < 1:
            continue
        before = [int(image.size[0]), int(image.size[1])]
        longest = max(before)
        if longest > target_size:
            scale = target_size / float(longest)
            image.scale(max(1, round(before[0] * scale)), max(1, round(before[1] * scale)))
        rows.append({"name": image.name, "before": before, "runtime": [int(image.size[0]), int(image.size[1])]})
    return rows


def add_socket(root: bpy.types.Object, name: str, location: Vector) -> bpy.types.Object:
    socket = new_empty(name, root, location)
    socket["socket"] = True
    return socket


def add_standard_sockets(root: bpy.types.Object, meshes: list[bpy.types.Object], magazine: bpy.types.Object | None) -> list[str]:
    minimum, maximum = world_bounds(meshes)
    center = (minimum + maximum) * 0.5
    size = maximum - minimum
    # Production candidates are authored toward Godot camera-forward (-Z).
    locations = {
        "Socket_Optic": Vector((center.x, maximum.y, center.z - size.z * 0.08)),
        "Socket_Muzzle": Vector((center.x, center.y + size.y * 0.12, minimum.z)),
        "Socket_Underbarrel": Vector((center.x, minimum.y, center.z - size.z * 0.18)),
        "Socket_Side": Vector((maximum.x, center.y, center.z - size.z * 0.10)),
        "Socket_Stock": Vector((center.x, center.y, maximum.z)),
        "Socket_Bayonet": Vector((center.x, center.y - size.y * 0.08, minimum.z + size.z * 0.08)),
        "Socket_Magazine": object_center(magazine) if magazine is not None else center,
        "Socket_PrimaryGrip": Vector((center.x + size.x * 0.10, minimum.y + size.y * 0.18, center.z + size.z * 0.18)),
        "Socket_SupportGrip": Vector((center.x, minimum.y + size.y * 0.10, center.z - size.z * 0.18)),
    }
    for name, location in locations.items():
        add_socket(root, name, location)
    return list(locations.keys())


def pivot_group(name: str, mesh: bpy.types.Object, root: bpy.types.Object, axis: str, motion: str) -> bpy.types.Object:
    pivot = new_empty(name, root, object_center(mesh))
    pivot["animation_axis"] = axis
    pivot["animation_role"] = motion
    pivot["drives_component"] = mesh.name
    mesh["animation_pivot"] = name
    mesh["animation_axis"] = axis
    mesh["animation_role"] = motion
    # Keep the visible mesh assembled under Frame. Blender's GLTF exporter
    # doubles non-zero parent-pivot translations for these separated source
    # islands. The sibling pivot remains an exact animation-authoring marker.
    parent_preserve(mesh, root)
    return pivot


def remove_zero_area_faces(meshes: list[bpy.types.Object]) -> dict[str, object]:
    """Remove only mathematically degenerate faces from generated derivatives."""
    rows: list[dict[str, object]] = []
    total = 0
    for obj in meshes:
        mesh = obj.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        degenerate = [face for face in bm.faces if face.calc_area() <= 1.0e-16]
        removed = len(degenerate)
        if degenerate:
            bmesh.ops.delete(bm, geom=degenerate, context="FACES")
            bm.to_mesh(mesh)
            mesh.update()
        bm.free()
        rows.append({"object": obj.name, "zero_area_faces_removed": removed})
        total += removed
    return {"zero_area_faces_removed": total, "objects": rows}


def set_origin_to_geometry_center(obj: bpy.types.Object) -> dict[str, object]:
    before = obj.matrix_world.translation.copy()
    center = object_center(obj)
    old_world = obj.matrix_world.copy()
    new_world = old_world.copy()
    new_world.translation = center
    obj.data.transform(new_world.inverted() @ old_world)
    obj.data.update()
    obj.matrix_world = new_world
    return {
        "before": list(before),
        "after": list(center),
        "correction_distance_meters": (center - before).length,
    }


def add_mechanical_marker(
    root: bpy.types.Object,
    name: str,
    position: Vector,
    role: str,
    reference_only: bool = False,
) -> bpy.types.Object:
    marker = new_empty(name, root, position)
    marker["mechanical_state"] = role
    marker["reference_only_until_mesh_separation"] = reference_only
    return marker


def prepare_m1911(root: bpy.types.Object, meshes: list[bpy.types.Object]) -> dict[str, object]:
    by_name = {obj.name: obj for obj in meshes}
    renamed: dict[str, str] = {}
    for old_name, obj in list(by_name.items()):
        new_name = M1911_NAMES.get(old_name)
        if new_name is None and old_name.startswith("MechanicalPart_"):
            new_name = "FrameHardware_" + old_name.rsplit("_", 1)[-1]
        if new_name is not None:
            renamed[old_name] = new_name
            obj.name = new_name
            obj.data.name = new_name + "Mesh"
    by_name = {obj.name: obj for obj in meshes}

    frame = new_empty("Frame", root)
    frame["mechanism_role"] = "stationary_receiver"
    slide = new_empty("Slide", root)
    slide["mechanism_role"] = "reciprocating_slide"
    slide["translation_axis"] = "local +Z (rearward)"
    slide["travel_meters"] = 0.028
    short_recoil = new_empty("ShortRecoil", root)
    short_recoil["mechanism_role"] = "barrel_and_recoil_action"
    magazine_group = new_empty("Magazine", root)
    magazine_group["mechanism_role"] = "removable_magazine"
    magazine_group["removal_axis"] = "local -Y"

    for name in M1911_FRAME_PARTS:
        if name in by_name:
            parent_preserve(by_name[name], frame)
    for name in ("SlideBody", "FrontSight", "RearSight", "FrameHardware_33"):
        if name in by_name:
            parent_preserve(by_name[name], slide)
    for name in ("Barrel", "BarrelBushing"):
        if name in by_name:
            parent_preserve(by_name[name], short_recoil)
    for name in ("MagazineBody", "MagazineBaseplate"):
        if name in by_name:
            parent_preserve(by_name[name], magazine_group)

    pivot_rows = []
    for component, pivot_name, axis, motion in (
        ("Trigger", "TriggerPivot", "local X", "trigger_press"),
        ("Hammer", "HammerPivot", "local X", "hammer_cock_release"),
        ("SlideStop", "SlideStopPivot", "local X", "slide_lock_release"),
        ("ThumbSafety", "ThumbSafetyPivot", "local X", "safety_toggle"),
    ):
        mesh = by_name.get(component)
        if mesh is not None:
            pivot_group(pivot_name, mesh, frame, axis, motion)
            pivot_rows.append({"component": component, "pivot": pivot_name, "axis": axis})
    release = by_name.get("MagazineRelease")
    if release is not None:
        release["translation_axis"] = "local X"
        release["animation_role"] = "magazine_release_press"

    markers = {
        "Marker_SlideForward": {"position": Vector(), "state": "slide_forward"},
        "Marker_SlideRearward": {"position": Vector((0.0, 0.0, 0.028)), "state": "slide_rearward"},
        "Marker_SlideLocked": {"position": Vector((0.0, 0.0, 0.025)), "state": "slide_locked"},
        "Marker_MagazineSeated": {"position": Vector(), "state": "magazine_seated"},
        "Marker_MagazineRemoved": {"position": Vector((0.0, -0.115, 0.025)), "state": "magazine_removed"},
        "Marker_HammerCocked": {"position": Vector(), "state": "hammer_cocked", "rotation_x_degrees": -28.0},
    }
    for name, values in markers.items():
        marker = new_empty(name, root, values["position"])
        marker["mechanical_state"] = values["state"]
        if "rotation_x_degrees" in values:
            marker["rotation_x_degrees"] = values["rotation_x_degrees"]

    for obj in meshes:
        if obj.parent is None or obj.parent == root:
            parent_preserve(obj, frame)
    return {
        "renamed_components": renamed,
        "pivots": pivot_rows,
        "markers": list(markers.keys()),
        "slide_travel_meters": 0.028,
        "magazine_removal_axis": "local -Y",
    }


def validate_m1911_orientation(meshes: list[bpy.types.Object]) -> dict[str, object]:
    by_name = {obj.name: obj for obj in meshes}
    required = ("FrontSight", "RearSight", "SlideBody", "MagazineBody")
    missing = [name for name in required if name not in by_name]
    if missing:
        raise RuntimeError("M1911 orientation validation is missing: " + ", ".join(missing))

    centers = {name: object_center(by_name[name]) for name in required}
    checks = {
        "front_sight_is_export_forward_positive_z": centers["FrontSight"].z > centers["RearSight"].z,
        "sights_are_above_slide_positive_y": min(
            centers["FrontSight"].y,
            centers["RearSight"].y,
        ) > centers["SlideBody"].y,
        "magazine_is_below_slide_negative_y": centers["MagazineBody"].y < centers["SlideBody"].y,
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise RuntimeError("M1911 canonical orientation failed: " + ", ".join(failed))
    return {
        "checks": checks,
        "component_centers": {name: list(center) for name, center in centers.items()},
        "all_component_centers_before_export": {
            obj.name: list(object_center(obj)) for obj in meshes
        },
    }


def prepare_diamo(asset_id: str, root: bpy.types.Object, meshes: list[bpy.types.Object]) -> tuple[list[bpy.types.Object], dict[str, object]]:
    excluded: list[str] = []
    active: list[bpy.types.Object] = []
    semantic: dict[str, str] = {}
    for obj in meshes:
        lower = obj.name.lower()
        if asset_id == "ump" and any(token in lower for token in ("scope", "silencer", "grip")):
            excluded.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        role = "Base"
        if "mag" in lower:
            role = "Magazine"
        elif "trigger" in lower:
            role = "Trigger"
        elif "bolt" in lower:
            role = "Bolt"
        obj.name = role
        obj.data.name = role + "Mesh"
        obj["component_role"] = role.lower()
        semantic[role] = obj.name
        parent_preserve(obj, root)
        active.append(obj)
    by_name = {obj.name: obj for obj in active}
    if "Magazine" in by_name:
        by_name["Magazine"]["removal_axis"] = "local -Y"
    if "Bolt" in by_name:
        by_name["Bolt"]["translation_axis"] = "local +Z (rearward)"
    if "Trigger" in by_name:
        pivot_group("TriggerPivot", by_name["Trigger"], root, "local X", "trigger_press")
    return active, {
        "semantic_components": list(semantic.keys()),
        "excluded_modular_source_components": excluded,
        "exclusion_reason": "Authored UMP optic, suppressor, and grip remain modular in the private source/evaluation derivative and are not merged into the production base weapon.",
    }


def prepare_diamo_batch2(
    asset_id: str,
    root: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> tuple[list[bpy.types.Object], dict[str, object]]:
    """Build stable production hierarchy from the useful authored pieces.

    Diamo's Batch 2 sources provide separate magazines and triggers. HK416 also
    supplies a separate stock assembly plus showcase optics. Bolt/action meshes
    remain embedded in the receiver artwork, so this pass records honest
    animation markers without fabricating destructive mesh separation.
    """
    excluded: list[str] = []
    active: list[bpy.types.Object] = []
    receiver_meshes: list[bpy.types.Object] = []
    stock_mesh: bpy.types.Object | None = None
    magazine_mesh: bpy.types.Object | None = None
    trigger_mesh: bpy.types.Object | None = None

    for obj in meshes:
        source_name = obj.name
        lower = source_name.lower()
        if asset_id == "hk416" and "scope" in lower:
            excluded.append(source_name)
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        if "mag" in lower:
            obj.name = "MagazineBody"
            magazine_mesh = obj
        elif "trigger" in lower:
            obj.name = "Trigger"
            trigger_mesh = obj
        elif asset_id == "hk416" and ("base 2" in lower or "base_2" in lower):
            obj.name = "StockBody"
            stock_mesh = obj
        else:
            obj.name = "ReceiverBody" if not receiver_meshes else "ReceiverBody_%02d" % (len(receiver_meshes) + 1)
            receiver_meshes.append(obj)
        obj.data.name = obj.name + "Mesh"
        obj["component_role"] = obj.name.lower()
        active.append(obj)

    receiver = new_empty("Receiver", root)
    receiver["mechanism_role"] = "stationary_receiver"
    action = new_empty("Action", root)
    action["mechanism_role"] = "future_bolt_and_charging_handle_animation"
    action["mesh_separation_required"] = True
    magazine = new_empty("Magazine", root)
    magazine["mechanism_role"] = "removable_magazine"
    magazine["removal_axis"] = "local -Y"

    for obj in receiver_meshes:
        parent_preserve(obj, receiver)
    if magazine_mesh is not None:
        magazine_mesh["removal_axis"] = "local -Y"
        parent_preserve(magazine_mesh, magazine)
    if trigger_mesh is not None:
        pivot_group("TriggerPivot", trigger_mesh, receiver, "local X", "trigger_press")
    if stock_mesh is not None:
        stock = new_empty("Stock", root)
        stock["mechanism_role"] = "stock_assembly"
        parent_preserve(stock_mesh, stock)

    minimum, maximum = world_bounds(active)
    center = (minimum + maximum) * 0.5
    size = maximum - minimum
    magazine_center = object_center(magazine_mesh) if magazine_mesh is not None else center
    marker_specs = {
        "Marker_MagazineSeated": (magazine_center, "magazine_seated"),
        "Marker_MagazineRemoved": (magazine_center + Vector((0.0, -max(size.y * 0.9, 0.16), 0.04)), "magazine_removed"),
        "Marker_BoltForward": (center + Vector((size.x * 0.18, size.y * 0.12, size.z * 0.03)), "bolt_forward_reference"),
        "Marker_BoltRearward": (center + Vector((size.x * 0.18, size.y * 0.12, size.z * 0.07)), "bolt_rearward_reference"),
        "Marker_ChargingHandleForward": (center + Vector((size.x * 0.28, size.y * 0.18, size.z * 0.06)), "charging_handle_forward_reference"),
        "Marker_ChargingHandleRearward": (center + Vector((size.x * 0.28, size.y * 0.18, size.z * 0.11)), "charging_handle_rearward_reference"),
    }
    if asset_id == "rpd":
        marker_specs.update({
            "Marker_FeedCoverPivot": (center + Vector((0.0, size.y * 0.48, size.z * 0.03)), "feed_cover_pivot_reference"),
            "Marker_BipodPivot": (center + Vector((0.0, -size.y * 0.30, -size.z * 0.28)), "bipod_pivot_reference"),
        })
    for marker_name, (position, role) in marker_specs.items():
        marker = new_empty(marker_name, root, position)
        marker["mechanical_state"] = role
        marker["reference_only_until_mesh_separation"] = "Magazine" not in marker_name

    return active, {
        "semantic_components": [obj.name for obj in active],
        "hierarchy": [child.name for child in root.children],
        "markers": list(marker_specs.keys()),
        "separate_animation_ready": [
            name for name, value in (
                ("magazine", magazine_mesh),
                ("trigger", trigger_mesh),
                ("stock", stock_mesh),
            ) if value is not None
        ],
        "embedded_components_requiring_future_mesh_separation": ["bolt", "charging_handle"] + (["feed_cover", "bipod"] if asset_id == "rpd" else []),
        "excluded_modular_source_components": excluded,
        "exclusion_reason": (
            "HK416 showcase optics remain available in the private source/evaluation material and are not merged into the production base weapon."
            if excluded else ""
        ),
    }


def prepare_diamo_batch3(
    asset_id: str,
    root: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> tuple[list[bpy.types.Object], dict[str, object]]:
    active = list(meshes)
    by_role: dict[str, bpy.types.Object] = {}
    source_names: dict[str, str] = {}

    for obj in active:
        source_name = obj.name
        lower = source_name.lower()
        role = "ReceiverBody"
        if asset_id == "benelli_m4":
            if "bolt" in lower:
                role = "BoltBody"
            elif "trigger" in lower:
                role = "Trigger"
        elif asset_id == "aa12":
            if "bolt" in lower:
                role = "BoltBody"
            elif "trigger" in lower:
                role = "Trigger"
            elif "mag" in lower:
                role = "SideShellCarrier"
        elif asset_id == "cheytac_m200":
            if "bolthandle" in lower or "bolt" in lower:
                role = "BoltHandleBody"
            elif "magazine" in lower or "mag" in lower:
                role = "MagazineBody"
            elif "trigger" in lower:
                role = "Trigger"
            elif "scope" in lower:
                role = "ScopeBody"
            elif "bipod" in lower:
                role = "BipodBody"
        elif asset_id == "rpg7":
            role = "RocketBody" if "rocket" in lower else "LauncherBody"
        obj.name = role
        obj.data.name = role + "Mesh"
        obj["component_role"] = role.lower()
        by_role[role] = obj
        source_names[source_name] = role

    minimum, maximum = world_bounds(active)
    center = (minimum + maximum) * 0.5
    size = maximum - minimum
    marker_names: list[str] = []
    separate_ready: list[str] = []
    embedded: list[str] = []
    notes: list[str] = []
    pivot_rows: list[dict[str, object]] = []
    origin_corrections: dict[str, object] = {}

    receiver = new_empty("Receiver" if asset_id != "rpg7" else "Launcher", root)
    receiver["mechanism_role"] = "stationary_receiver" if asset_id != "rpg7" else "launcher_tube_and_controls"
    receiver_body = by_role.get("ReceiverBody") or by_role.get("LauncherBody")
    if receiver_body is not None:
        parent_preserve(receiver_body, receiver)

    trigger = by_role.get("Trigger")
    if trigger is not None:
        pivot_group("TriggerPivot", trigger, receiver, "local X", "trigger_press")
        separate_ready.append("trigger")
        pivot_rows.append({"component": "Trigger", "pivot": "TriggerPivot", "axis": "local X"})

    if asset_id in ("benelli_m4", "aa12"):
        bolt = by_role.get("BoltBody")
        action = new_empty("BoltAction", root)
        action["mechanism_role"] = "reciprocating_bolt_and_charging_handle"
        action["translation_axis"] = "local +Z (rearward)"
        if bolt is not None:
            parent_preserve(bolt, action)
            bolt_center = object_center(bolt)
            pivot = add_mechanical_marker(root, "BoltPivot", bolt_center, "bolt_translation_origin")
            pivot["drives_component"] = "BoltAction"
            pivot["translation_axis"] = "local +Z"
            pivot_rows.append({"component": "BoltAction", "pivot": "BoltPivot", "axis": "local +Z"})
            separate_ready.append("bolt_and_charging_handle")
        else:
            bolt_center = center
        for name, position, role in (
            ("Marker_BoltForward", bolt_center, "bolt_forward"),
            ("Marker_BoltRearward", bolt_center + Vector((0.0, 0.0, max(size.z * 0.035, 0.035))), "bolt_rearward"),
        ):
            add_mechanical_marker(root, name, position, role)
            marker_names.append(name)

    if asset_id == "benelli_m4":
        tube = new_empty("MagazineTubePreparation", root)
        tube["mechanism_role"] = "embedded_tube_magazine_relationship"
        tube["mesh_separation_required"] = True
        embedded.extend(["loading_gate", "magazine_tube"])
        notes.append("Loading gate and magazine tube remain embedded in the 42-island receiver source; non-destructive reference markers are prepared for the animation pass.")
        shell_inserted = center + Vector((0.0, -size.y * 0.34, size.z * 0.08))
        shell_insert_start = shell_inserted + Vector((0.0, -max(size.y * 0.35, 0.12), 0.05))
        ejection_port = object_center(by_role["BoltBody"]) + Vector((size.x * 0.62, size.y * 0.05, 0.0))
        marker_specs = (
            ("Marker_LoadingGatePivot", shell_inserted, "loading_gate_pivot_reference", True),
            ("Marker_ShellInsertStart", shell_insert_start, "shell_insertion_start", False),
            ("Marker_ShellInserted", shell_inserted, "shell_seated_in_tube", False),
            ("Marker_ShellEjectionPort", ejection_port, "shell_ejection_port", False),
            ("Marker_ShellEjected", ejection_port + Vector((size.x * 0.9, size.y * 0.2, 0.02)), "shell_ejected", False),
        )
        for name, position, role, reference in marker_specs:
            add_mechanical_marker(root, name, position, role, reference)
            marker_names.append(name)

    elif asset_id == "aa12":
        carrier = by_role.get("SideShellCarrier")
        if carrier is not None:
            parent_preserve(carrier, receiver)
            separate_ready.append("side_shell_carrier")
        magazine_prep = new_empty("MagazinePreparation", root)
        magazine_prep["mechanism_role"] = "embedded_box_magazine_pending_manual_extraction"
        magazine_prep["source_named_mag_is_side_shell_carrier"] = True
        magazine_prep["mesh_separation_required"] = True
        embedded.extend(["actual_box_magazine", "charging_action_details"])
        notes.append("The source-named Mag object is a side shell carrier. The actual box magazine is embedded in the 253-island receiver and was not destructively auto-separated.")
        magazine_center = center + Vector((0.0, -size.y * 0.26, size.z * 0.10))
        for name, position, role in (
            ("Marker_MagazineSeated", magazine_center, "embedded_magazine_seated_reference"),
            ("Marker_MagazineRemoved", magazine_center + Vector((0.0, -max(size.y * 0.85, 0.22), 0.05)), "magazine_removed_reference"),
        ):
            add_mechanical_marker(root, name, position, role, True)
            marker_names.append(name)

    elif asset_id == "cheytac_m200":
        bolt = by_role.get("BoltHandleBody")
        bolt_action = new_empty("BoltAction", root)
        bolt_action["mechanism_role"] = "bolt_handle_lock_rotate_and_reciprocate"
        bolt_action["translation_axis"] = "local +Z (rearward)"
        bolt_action["rotation_axis"] = "local Z"
        if bolt is not None:
            parent_preserve(bolt, bolt_action)
            bolt_center = object_center(bolt)
            pivot = add_mechanical_marker(root, "BoltPivot", bolt_center, "bolt_lock_and_translation_origin")
            pivot["drives_component"] = "BoltAction"
            pivot["translation_axis"] = "local +Z"
            pivot["rotation_axis"] = "local Z"
            pivot_rows.append({"component": "BoltAction", "pivot": "BoltPivot", "translation_axis": "local +Z", "rotation_axis": "local Z"})
            separate_ready.append("bolt_handle_action")
        else:
            bolt_center = center
        magazine_body = by_role.get("MagazineBody")
        magazine = new_empty("Magazine", root)
        magazine["mechanism_role"] = "removable_box_magazine"
        magazine["removal_axis"] = "local -Y"
        if magazine_body is not None:
            parent_preserve(magazine_body, magazine)
            magazine_center = object_center(magazine_body)
            mag_pivot = add_mechanical_marker(root, "MagazinePivot", magazine_center, "magazine_translation_origin")
            mag_pivot["drives_component"] = "Magazine"
            mag_pivot["translation_axis"] = "local -Y"
            pivot_rows.append({"component": "Magazine", "pivot": "MagazinePivot", "axis": "local -Y"})
            separate_ready.append("magazine")
        else:
            magazine_center = center
        for role, group_name in (("ScopeBody", "Scope"), ("BipodBody", "Bipod")):
            component = by_role.get(role)
            if component is not None:
                group = new_empty(group_name, root)
                group["mechanism_role"] = "physical_optic" if group_name == "Scope" else "folding_bipod"
                parent_preserve(component, group)
                separate_ready.append(group_name.lower())
                if group_name == "Bipod":
                    add_mechanical_marker(root, "BipodPivot", object_center(component), "bipod_fold_origin")
                    pivot_rows.append({"component": "Bipod", "pivot": "BipodPivot", "axis": "local X"})
        marker_specs = (
            ("Marker_BoltLocked", bolt_center, "bolt_locked"),
            ("Marker_BoltUnlocked", bolt_center, "bolt_unlocked_rotation_reference"),
            ("Marker_BoltRearward", bolt_center + Vector((0.0, 0.0, max(size.z * 0.07, 0.07))), "bolt_rearward"),
            ("Marker_MagazineSeated", magazine_center, "magazine_seated"),
            ("Marker_MagazineRemoved", magazine_center + Vector((0.0, -max(size.y * 0.9, 0.24), 0.05)), "magazine_removed"),
        )
        for name, position, role in marker_specs:
            add_mechanical_marker(root, name, position, role)
            marker_names.append(name)

    elif asset_id == "rpg7":
        rocket = by_role.get("RocketBody")
        rocket_group = new_empty("Rocket", root)
        rocket_group["mechanism_role"] = "removable_projectile"
        rocket_group["removal_axis"] = "local -Z (forward out of tube)"
        if rocket is not None:
            origin_corrections["RocketBody"] = set_origin_to_geometry_center(rocket)
            parent_preserve(rocket, rocket_group)
            rocket_center = object_center(rocket)
            pivot = add_mechanical_marker(root, "RocketPivot", rocket_center, "rocket_translation_origin")
            pivot["drives_component"] = "Rocket"
            pivot["translation_axis"] = "local -Z"
            pivot_rows.append({"component": "Rocket", "pivot": "RocketPivot", "axis": "local -Z"})
            separate_ready.append("rocket")
        else:
            rocket_center = center
        for name, position, role in (
            ("Marker_RocketSeated", rocket_center, "rocket_seated"),
            ("Marker_RocketRemoved", rocket_center + Vector((0.0, size.y * 0.15, -max(size.z * 0.48, 0.42))), "rocket_removed"),
        ):
            add_mechanical_marker(root, name, position, role)
            marker_names.append(name)
        add_socket(root, "Socket_Projectile", rocket_center)
        embedded.extend(["trigger", "iron_sights", "grips"])
        notes.append("The source provides a clean separate rocket; launcher trigger and sight controls remain embedded in the base body.")

    for obj in active:
        if obj.parent is None or obj.parent == root:
            parent_preserve(obj, receiver)

    return active, {
        "source_to_production_names": source_names,
        "semantic_components": [obj.name for obj in active],
        "hierarchy": [child.name for child in root.children],
        "markers": marker_names,
        "pivots": pivot_rows,
        "origin_corrections": origin_corrections,
        "separate_animation_ready": separate_ready,
        "embedded_components_requiring_future_mesh_separation": embedded,
        "notes": notes,
    }


def remove_non_mesh_import_nodes(keep_root: bpy.types.Object, meshes: list[bpy.types.Object]) -> None:
    keep: set[bpy.types.Object] = {keep_root, *meshes}
    keep.update(keep_root.children_recursive)
    keep.update(obj.parent for obj in meshes if obj.parent is not None)
    changed = True
    while changed:
        changed = False
        for obj in list(keep):
            if obj is not None and obj.parent is not None and obj.parent not in keep:
                keep.add(obj.parent)
                changed = True
    for obj in list(bpy.context.scene.objects):
        if obj not in keep and obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    report_path = Path(args.report).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    imported_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not imported_meshes:
        raise RuntimeError("Evaluation GLB contains no mesh objects")

    # Preserve evaluated transforms while replacing the evaluation hierarchy.
    for obj in imported_meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
    root = new_empty("WeaponRoot")
    root["asset_id"] = args.asset_id
    root["production_candidate"] = True
    root["developer_only_until_approved"] = True
    root["source_archive_sha256"] = args.source_archive_sha256.upper()
    root["source_derivative"] = input_path.name
    for obj in imported_meshes:
        parent_preserve(obj, root)
    target_length = {
        "m1911": 0.22,
        "mp7": 0.638,
        "ump": 0.695,
        "hk416": 0.86,
        "m16": 1.00,
        "rpd": 1.04,
        "benelli_m4": 1.01,
        "aa12": 0.98,
        "cheytac_m200": 1.40,
        "rpg7": 0.98,
    }[args.asset_id]
    corrections = PRODUCTION_ASSET_CORRECTIONS[args.asset_id]
    canonical_roll_degrees = corrections["roll_degrees"]
    canonical_yaw_degrees = corrections["yaw_degrees"]
    normalization: dict[str, object] = normalize_mesh_transforms(
        imported_meshes,
        target_length,
        canonical_roll_degrees,
        canonical_yaw_degrees,
        corrections["long_axis_degrees"],
    )
    root["axis_convention"] = "Godot viewmodel: -Z muzzle, +Y up, +X across"
    root["canonical_forward_axis"] = "-Z"
    topology_cleanup: dict[str, object] = {"zero_area_faces_removed": 0, "objects": []}
    if args.asset_id == "m1911":
        bake_mesh_world_transforms(imported_meshes)
        normalization["mesh_world_transforms_baked"] = True
        root["creator"] = "DavidFalke"
        root["license"] = "Creative Commons Attribution"
        root["source_page"] = "https://sketchfab.com/3d-models/vr-ready-m1911a1-421749c3fa1744a884a340f81ab45e3c"
        mechanism = prepare_m1911(root, imported_meshes)
        active_meshes = imported_meshes
        orientation_validation = validate_m1911_orientation(active_meshes)
    elif args.asset_id in ("mp7", "ump"):
        root["creator"] = "Diamo Studio"
        root["license"] = "Purchased Diamo Studio 45 Gun Arsenal license"
        root["private_source_archive"] = True
        active_meshes, mechanism = prepare_diamo(args.asset_id, root, imported_meshes)
        if args.asset_id == "ump":
            normalization = normalize_mesh_transforms(active_meshes, target_length)
            normalization["canonical_roll_degrees"] = canonical_roll_degrees
            normalization["canonical_yaw_degrees"] = canonical_yaw_degrees
        orientation_validation = {}
    elif args.asset_id in ("hk416", "m16", "rpd"):
        root["creator"] = "Diamo Studio"
        root["license"] = "Purchased Diamo Studio 45 Gun Arsenal license"
        root["private_source_archive"] = True
        root["source_library"] = (
            "Diamo Studio 45 Gun Arsenal - LMGs"
            if args.asset_id == "rpd"
            else "Diamo Studio 45 Gun Arsenal - Rifles"
        )
        active_meshes, mechanism = prepare_diamo_batch2(args.asset_id, root, imported_meshes)
        orientation_validation = {
            "canonical_forward_axis": "-Z",
            "canonical_up_axis": "+Y",
            "source_evaluation_orientation_preserved": True,
        }
    else:
        root["creator"] = "Diamo Studio"
        root["license"] = "Purchased Diamo Studio 45 Gun Arsenal license"
        root["private_source_archive"] = True
        root["source_library"] = (
            "Diamo Studio 45 Gun Arsenal - Shotguns"
            if args.asset_id in ("benelli_m4", "aa12")
            else (
                "Diamo Studio 45 Gun Arsenal - Snipers"
                if args.asset_id == "cheytac_m200"
                else "Diamo Studio 45 Gun Arsenal - Launchers"
            )
        )
        topology_cleanup = remove_zero_area_faces(imported_meshes)
        active_meshes, mechanism = prepare_diamo_batch3(args.asset_id, root, imported_meshes)
        orientation_validation = {
            "canonical_forward_axis": "-Z",
            "canonical_up_axis": "+Y",
            "source_evaluation_orientation_preserved": canonical_yaw_degrees == 0.0,
            "asset_yaw_correction_degrees": canonical_yaw_degrees,
        }

    magazine = next((obj for obj in active_meshes if "magazine" in obj.name.lower()), None)
    sockets = add_standard_sockets(root, active_meshes, magazine)
    special_socket_markers = {
        "benelli_m4": {
            "Socket_Magazine": "Marker_ShellInserted",
            "Socket_ShellLoad": "Marker_ShellInserted",
            "Socket_ShellEject": "Marker_ShellEjectionPort",
        },
        "aa12": {"Socket_Magazine": "Marker_MagazineSeated"},
        "rpg7": {"Socket_Projectile": "Marker_RocketSeated"},
    }
    for socket_name, marker_name in special_socket_markers.get(args.asset_id, {}).items():
        marker = next((obj for obj in root.children_recursive if obj.name == marker_name), None)
        if marker is None:
            continue
        socket = next((obj for obj in root.children_recursive if obj.name == socket_name), None)
        if socket is None:
            socket = add_socket(root, socket_name, marker.matrix_world.translation)
            sockets.append(socket_name)
        else:
            socket.location = marker.matrix_world.translation
        socket["driven_by_marker"] = marker_name
        if socket_name not in sockets:
            sockets.append(socket_name)
    texture_rows = optimize_images(args.texture_size)
    remove_non_mesh_import_nodes(root, active_meshes)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_materials="EXPORT",
        export_extras=True,
    )

    minimum, maximum = world_bounds(active_meshes)
    triangles = 0
    for obj in active_meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    report = {
        "asset_id": args.asset_id,
        "production_candidate": True,
        "developer_only_until_approved": True,
        "input_evaluation_derivative": str(input_path),
        "input_sha256": sha256(input_path),
        "source_archive_sha256": args.source_archive_sha256.upper(),
        "source_was_modified": False,
        "blender_version": bpy.app.version_string,
        "output": output_path.name,
        "output_bytes": output_path.stat().st_size,
        "output_sha256": sha256(output_path),
        "mesh_object_count": len(active_meshes),
        "triangle_count": triangles,
        "bounds_meters": {"minimum": list(minimum), "maximum": list(maximum), "size": list(maximum - minimum)},
        "texture_optimization": {"maximum_runtime_dimension": args.texture_size, "images": texture_rows},
        "normalization": normalization,
        "topology_cleanup": topology_cleanup,
        "orientation_validation": orientation_validation,
        "mechanism": mechanism,
        "sockets": sockets,
        "axis_convention": "Godot viewmodel: -Z muzzle, +Y up, +X across",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PRODUCTION_CANDIDATE_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
