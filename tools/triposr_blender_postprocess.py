#!/usr/bin/env python3
"""Blender headless post-process for TripoSR meshes."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--asset-name", required=True)
    parser.add_argument("--target-faces", required=True, type=int)
    parser.add_argument("--target-height-m", required=True, type=float)
    parser.add_argument("--create-collision", action="store_true")
    return parser.parse_args(argv)


def import_mesh(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".obj":
        if hasattr(bpy.ops.wm, "obj_import"):
            bpy.ops.wm.obj_import(filepath=str(path))
        else:
            bpy.ops.import_scene.obj(filepath=str(path))
    else:
        raise RuntimeError(f"Unsupported input format: {suffix}")


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def select_only(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def face_count(objects: list[bpy.types.Object]) -> int:
    return sum(len(obj.data.polygons) for obj in objects)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import_mesh(args.input)
    objects = mesh_objects()
    if not objects:
        raise RuntimeError("No mesh object was imported")

    select_only(objects)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(objects) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    model.name = args.asset_name

    before_faces = face_count([model])
    if before_faces > args.target_faces:
        modifier = model.modifiers.new(name="WebDecimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = max(0.01, min(1.0, args.target_faces / before_faces))
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = model
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    triangulate = model.modifiers.new(name="Triangulate", type="TRIANGULATE")
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.modifier_apply(modifier=triangulate.name)

    minimum, maximum = world_bounds([model])
    height = maximum.z - minimum.z
    if height <= 1e-6:
        raise RuntimeError("Generated mesh has invalid height")
    uniform_scale = args.target_height_m / height
    model.scale = Vector((uniform_scale, uniform_scale, uniform_scale))
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    minimum, maximum = world_bounds([model])
    center_xy = Vector(((minimum.x + maximum.x) * 0.5, (minimum.y + maximum.y) * 0.5, 0.0))
    model.location -= Vector((center_xy.x, center_xy.y, minimum.z))
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    collision = None
    if args.create_collision:
        minimum, maximum = world_bounds([model])
        dimensions = maximum - minimum
        center = (minimum + maximum) * 0.5
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
        collision = bpy.context.active_object
        collision.name = f"{args.asset_name}-colonly"
        collision.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        collision.display_type = "WIRE"

    objects_to_export = [model] + ([collision] if collision else [])
    select_only(objects_to_export)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )

    minimum, maximum = world_bounds([model])
    metrics = {
        "faces_before": before_faces,
        "faces_after": face_count([model]),
        "dimensions_m": [round(value, 5) for value in (maximum - minimum)],
        "collision_generated": bool(collision),
        "output": str(args.output),
    }
    args.metrics.parent.mkdir(parents=True, exist_ok=True)
    args.metrics.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
