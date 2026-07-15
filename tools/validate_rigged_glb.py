#!/usr/bin/env python3
"""Validate that a GLB contains production-critical robot data."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--min-bones", type=int, default=13)
    parser.add_argument("--min-animations", type=int, default=5)
    parser.add_argument("--min-materials", type=int, default=4)
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    materials = {material.name for mesh in meshes for material in mesh.data.materials if material}
    actions = sorted(action.name for action in bpy.data.actions)
    bones = sum(len(armature.data.bones) for armature in armatures)
    triangles = sum(
        sum(max(1, len(polygon.vertices) - 2) for polygon in mesh.data.polygons)
        for mesh in meshes
    )

    errors: list[str] = []
    if not meshes:
        errors.append("No mesh imported")
    if not armatures:
        errors.append("No armature imported")
    if bones < args.min_bones:
        errors.append(f"Expected at least {args.min_bones} bones, got {bones}")
    if len(actions) < args.min_animations:
        errors.append(f"Expected at least {args.min_animations} animations, got {len(actions)}: {actions}")
    if len(materials) < args.min_materials:
        errors.append(f"Expected at least {args.min_materials} materials, got {len(materials)}")
    if triangles <= 0:
        errors.append("No triangles imported")

    report = {
        "input": str(args.input),
        "meshes": len(meshes),
        "armatures": len(armatures),
        "bones": bones,
        "animations": actions,
        "materials": sorted(materials),
        "triangles": triangles,
        "errors": errors,
        "valid": not errors,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
