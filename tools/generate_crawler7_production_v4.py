#!/usr/bin/env python3
"""Detailed CRAWLER-7 production generator built on the validated rigid quadruped core.

Adds layered armour, mechanical joint housings, piston details, split feet, sensor bezels,
industrial vents and darker PS1 materials while preserving the 13-bone rig and five clips.
"""
from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Vector


BASE = Path(__file__).with_name("generate_crawler7_production_v2.py")
spec = importlib.util.spec_from_file_location("crawler7_core", BASE)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load {BASE}")
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("CRAWLER7_World")
    scene.world.color = (0.012, 0.015, 0.019)
    scene.frame_start = 1
    scene.frame_end = 48


def tune_material(name: str, color: tuple[float, float, float, float], roughness: float) -> None:
    mat = bpy.data.materials.get(name)
    if mat is None or not mat.use_nodes:
        return
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Base Color"].default_value = color
            node.inputs["Roughness"].default_value = roughness
        elif node.type == "MIX_RGB":
            node.inputs[1].default_value = color


def body_parent(obj: bpy.types.Object, rig: bpy.types.Object) -> bpy.types.Object:
    core.rigid_parent(obj, rig, "body")
    return obj


def bone_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone: str) -> bpy.types.Object:
    core.rigid_parent(obj, rig, bone)
    return obj


def add_body_details(rig: bpy.types.Object) -> None:
    dark = bpy.data.materials["CRAWLER7_DarkMetal"]
    armor = bpy.data.materials["CRAWLER7_BrownArmor"]
    black = bpy.data.materials["CRAWLER7_Black"]
    joint = bpy.data.materials["CRAWLER7_Joints"]

    # Layered top armour and central maintenance spine.
    for x in (-0.43, 0.43):
        body_parent(core.box(f"TopRail_{x:+.2f}", Vector((x, 0.02, 1.30)), Vector((0.24, 1.36, 0.12)), armor, 0.025), rig)
        body_parent(core.box(f"TopRailInset_{x:+.2f}", Vector((x, -0.03, 1.37)), Vector((0.15, 0.80, 0.055)), black, 0.015), rig)
    body_parent(core.box("CentralSpine", Vector((0.0, 0.10, 1.31)), Vector((0.30, 1.45, 0.10)), black, 0.025), rig)
    body_parent(core.box("FrontForehead", Vector((0.0, -1.10, 1.02)), Vector((0.82, 0.20, 0.18)), armor, 0.025), rig)
    body_parent(core.box("LowerJaw", Vector((0.0, -1.17, 0.50)), Vector((0.78, 0.18, 0.15)), dark, 0.022), rig)

    # Sensor bezels and a recessed face plate.
    for index, (x, z) in enumerate(((-0.22, 0.15), (0.22, 0.15), (-0.22, -0.15), (0.22, -0.15))):
        body_parent(core.cylinder(f"SensorBezel_{index}", Vector((x, -1.245, 0.77 + z)), 0.145, 0.045, joint, (math.pi / 2, 0.0, 0.0), 12), rig)
    body_parent(core.box("SensorFaceInset", Vector((0.0, -1.235, 0.76)), Vector((0.72, 0.045, 0.43)), black, 0.015), rig)

    # Rear cooling pack and side armour pods.
    body_parent(core.box("RearVentFrame", Vector((0.0, 1.115, 0.81)), Vector((0.74, 0.08, 0.34)), black, 0.02), rig)
    for x in (-0.26, -0.13, 0.0, 0.13, 0.26):
        body_parent(core.box(f"RearVent_{x:+.2f}", Vector((x, 1.17, 0.81)), Vector((0.065, 0.04, 0.25)), dark, 0.008), rig)
    for x in (-0.73, 0.73):
        body_parent(core.box(f"SidePod_{x:+.2f}", Vector((x, 0.20, 0.86)), Vector((0.32, 0.78, 0.42)), armor, 0.04), rig)
        body_parent(core.box(f"SidePodInset_{x:+.2f}", Vector((x * 1.03, 0.14, 0.87)), Vector((0.08, 0.48, 0.23)), black, 0.015), rig)

    # Low-poly bolts on the top and front plates.
    bolt_positions = [
        (-0.48, -0.48, 1.38), (0.48, -0.48, 1.38), (-0.48, 0.48, 1.38), (0.48, 0.48, 1.38),
        (-0.36, -1.25, 1.02), (0.36, -1.25, 1.02), (-0.36, -1.25, 0.51), (0.36, -1.25, 0.51),
    ]
    for index, position in enumerate(bolt_positions):
        rotation = (0.0, 0.0, 0.0) if position[1] > -1.2 else (math.pi / 2, 0.0, 0.0)
        body_parent(core.cylinder(f"BodyBolt_{index}", Vector(position), 0.035, 0.025, joint, rotation, 8), rig)


def leg_points() -> dict[str, tuple[Vector, Vector, Vector, Vector]]:
    return {
        "LF": (Vector((-0.65, -0.60, 0.86)), Vector((-1.02, -0.78, 0.61)), Vector((-1.22, -0.94, 0.23)), Vector((-1.36, -1.16, 0.12))),
        "RF": (Vector((0.65, -0.60, 0.86)), Vector((1.02, -0.78, 0.61)), Vector((1.22, -0.94, 0.23)), Vector((1.36, -1.16, 0.12))),
        "LR": (Vector((-0.65, 0.60, 0.86)), Vector((-1.02, 0.78, 0.61)), Vector((-1.22, 0.94, 0.23)), Vector((-1.36, 1.16, 0.12))),
        "RR": (Vector((0.65, 0.60, 0.86)), Vector((1.02, 0.78, 0.61)), Vector((1.22, 0.94, 0.23)), Vector((1.36, 1.16, 0.12))),
    }


def add_leg_details(rig: bpy.types.Object) -> None:
    armor = bpy.data.materials["CRAWLER7_BrownArmor"]
    dark = bpy.data.materials["CRAWLER7_DarkMetal"]
    black = bpy.data.materials["CRAWLER7_Black"]
    joint = bpy.data.materials["CRAWLER7_Joints"]

    for prefix, (hip, knee, ankle, toe) in leg_points().items():
        side = -1.0 if prefix.startswith("L") else 1.0
        front = -1.0 if prefix.endswith("F") else 1.0
        upper_bone = prefix + "_upper"
        lower_bone = prefix + "_lower"
        foot_bone = prefix + "_foot"

        # Concentric joint armour gives the mechanical silhouette of the storyboard.
        bone_parent(core.cylinder(prefix + "_HipCover", hip + Vector((side * 0.035, 0.0, 0.0)), 0.235, 0.16, armor, (0.0, math.pi / 2, 0.0), 12), rig, upper_bone)
        bone_parent(core.cylinder(prefix + "_HipHub", hip + Vector((side * 0.11, 0.0, 0.0)), 0.13, 0.07, black, (0.0, math.pi / 2, 0.0), 10), rig, upper_bone)
        bone_parent(core.cylinder(prefix + "_KneeCover", knee + Vector((side * 0.03, 0.0, 0.0)), 0.195, 0.15, armor, (0.0, math.pi / 2, 0.0), 12), rig, lower_bone)
        bone_parent(core.cylinder(prefix + "_KneeHub", knee + Vector((side * 0.10, 0.0, 0.0)), 0.105, 0.06, black, (0.0, math.pi / 2, 0.0), 10), rig, lower_bone)

        # Armour caps and exposed actuator rods.
        upper_mid = (hip + knee) * 0.5 + Vector((side * 0.055, 0.0, 0.035))
        lower_mid = (knee + ankle) * 0.5 + Vector((side * 0.05, 0.0, 0.025))
        bone_parent(core.box(prefix + "_UpperCap", upper_mid, Vector((0.18, 0.25, 0.34)), dark, 0.025), rig, upper_bone)
        bone_parent(core.box(prefix + "_LowerCap", lower_mid, Vector((0.17, 0.22, 0.31)), armor, 0.023), rig, lower_bone)
        bone_parent(core.beam(prefix + "_UpperPiston", hip + Vector((0.0, front * 0.08, -0.04)), knee + Vector((0.0, front * 0.08, 0.05)), 0.055, 0.055, joint), rig, upper_bone)
        bone_parent(core.beam(prefix + "_LowerPiston", knee + Vector((0.0, front * 0.07, -0.03)), ankle + Vector((0.0, front * 0.07, 0.05)), 0.045, 0.045, joint), rig, lower_bone)

        # Split foot and toe guards improve ground contact and segmentation.
        toe_offset_x = 0.13
        for toe_index, x_offset in enumerate((-toe_offset_x, toe_offset_x)):
            foot_loc = toe + Vector((x_offset, front * 0.10, 0.035))
            bone_parent(core.box(f"{prefix}_Toe_{toe_index}", foot_loc, Vector((0.19, 0.43, 0.17)), black, 0.03), rig, foot_bone)
            guard_loc = foot_loc + Vector((0.0, front * 0.17, 0.055))
            bone_parent(core.box(f"{prefix}_ToeGuard_{toe_index}", guard_loc, Vector((0.17, 0.19, 0.13)), armor, 0.025), rig, foot_bone)
        bone_parent(core.box(prefix + "_AnkleShield", ankle + Vector((0.0, front * 0.035, 0.06)), Vector((0.30, 0.22, 0.25)), armor, 0.028), rig, foot_bone)


def detailed_build(quality: str):
    rig, clips, collisions = original_build(quality)
    tune_material("CRAWLER7_DarkMetal", (0.055, 0.045, 0.038, 1.0), 0.72)
    tune_material("CRAWLER7_BrownArmor", (0.20, 0.125, 0.065, 1.0), 0.70)
    tune_material("CRAWLER7_Black", (0.010, 0.013, 0.016, 1.0), 0.60)
    tune_material("CRAWLER7_Joints", (0.022, 0.020, 0.018, 1.0), 0.88)
    add_body_details(rig)
    add_leg_details(rig)
    return rig, clips, collisions


def preview(path: Path) -> None:
    scene = bpy.context.scene
    scene.render.filepath = str(path)
    ground_mat = core.material("PreviewGround", (0.025, 0.029, 0.033, 1.0), 0.0, 0.96)
    bpy.ops.mesh.primitive_plane_add(size=20.0, location=(0.0, 0.0, -0.01))
    ground = bpy.context.object
    ground.name = "PreviewGroundObject"
    ground.data.materials.append(ground_mat)
    for location, energy, size in (((4.2, -5.0, 5.5), 700.0, 4.0), ((-4.0, -1.5, 3.0), 340.0, 3.5), ((0.0, 4.0, 4.0), 420.0, 3.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.size = size
    bpy.ops.object.camera_add(location=(4.6, -6.2, 3.25))
    camera = bpy.context.object
    camera.data.lens = 62
    camera.rotation_euler = (Vector((0.0, 0.0, 0.72)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.frame_set(1)
    bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.name == "PreviewGroundObject" or obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)


original_build = core.build
core.reset = reset
core.build = detailed_build
core.preview = preview
core.main()
