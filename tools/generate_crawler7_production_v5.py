#!/usr/bin/env python3
"""Final CRAWLER-7 production entry point.

Loads the validated v4 detailed generator without executing its entry point, then adds
unoccluded emissive sensor lenses and records the correct generator version.
"""
from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE = Path(__file__).with_name("generate_crawler7_production_v4.py")
text = SOURCE.read_text(encoding="utf-8")
marker = "core.main()"
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
namespace: dict[str, object] = {"__file__": str(SOURCE), "__name__": "crawler7_v4_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)

core = namespace["core"]
detailed_build = namespace["detailed_build"]
# v6 executes this module dynamically and expects this helper at the v5 level.
# Export the validated v4 implementation instead of duplicating material logic.
tune_material = namespace["tune_material"]
base_report = core.report


def final_build(quality: str):
    rig, clips, collisions = detailed_build(quality)
    red = bpy.data.materials["CRAWLER7_RedSensors"]
    black = bpy.data.materials["CRAWLER7_Black"]

    # Put a dark recessed face behind the lenses, not in front of them.
    face = bpy.data.objects.get("SensorFaceInset")
    if face is not None:
        world = face.matrix_world.copy()
        world.translation.y = -1.185
        face.matrix_world = world

    # Add explicit front-facing emissive lenses so the red sensor cluster remains
    # visible in Blender, Godot and the generated preview.
    for index, (x, z) in enumerate(((-0.22, 0.15), (0.22, 0.15), (-0.22, -0.15), (0.22, -0.15))):
        bezel = core.cylinder(
            f"FinalSensorBezel_{index}",
            Vector((x, -1.285, 0.77 + z)),
            0.118,
            0.035,
            black,
            (1.57079632679, 0.0, 0.0),
            12,
        )
        namespace["body_parent"](bezel, rig)
        lens = core.cylinder(
            f"FinalSensorLens_{index}",
            Vector((x, -1.315, 0.77 + z)),
            0.078,
            0.028,
            red,
            (1.57079632679, 0.0, 0.0),
            12,
        )
        namespace["body_parent"](lens, rig)

    center = core.cylinder(
        "FinalSensorCenter",
        Vector((0.0, -1.32, 0.76)),
        0.052,
        0.028,
        red,
        (1.57079632679, 0.0, 0.0),
        10,
    )
    namespace["body_parent"](center, rig)
    return rig, clips, collisions


def final_report(path: Path, output: Path, rig, clips, collisions: int) -> None:
    base_report(path, output, rig, clips, collisions)
    data = json.loads(path.read_text(encoding="utf-8"))
    data["generator"] = "Blender deterministic hard-surface v5"
    data["design_target"] = "CRAWLER-7 PS1 industrial low-poly storyboard"
    data["sensor_cluster"] = "four red lenses plus central indicator"
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


core.build = final_build
core.report = final_report
core.main()
