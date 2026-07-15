#!/usr/bin/env python3
"""Detailed SPECTER-5 low-poly hard-surface generator.

Builds a segmented industrial biped with a rigid rig, named localized-damage parts and six gameplay
clips. It reuses the generic asset request/sidecar pipeline but replaces the generic biped geometry
with a storyboard-oriented silhouette.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).with_name("generate_game_asset.py")
text = SOURCE.read_text(encoding="utf-8")
marker = 'if __name__=="__main__":\n    main()'
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
ns: dict[str, object] = {"__file__": str(SOURCE), "__name__": "specter_asset_module"}
exec(compile(text, str(SOURCE), "exec"), ns)


def compatible_reset() -> None:
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
        scene.world = bpy.data.worlds.new("SPECTER5_World")
    scene.world.color = (0.018, 0.022, 0.028)
    scene.frame_start = 1
    scene.frame_end = 48


def compatible_material(name, definition, emission=None, texture=None):
    color, metallic, roughness = definition
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if texture is not None and Path(texture).exists():
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = bpy.data.images.load(str(texture), check_existing=True)
        image_node.interpolation = "Closest"
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
    if emission is not None:
        socket = bsdf.inputs.get("Emission Color")
        if socket is None:
            socket = bsdf.inputs.get("Emission")
        if socket is not None:
            socket.default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength is not None:
            strength.default_value = 5.0
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def compatible_export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    wanted = {
        "filepath": str(path),
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": True,
        "export_nla_strips": True,
        "export_force_sampling": True,
        "export_materials": "EXPORT",
    }
    supported = {item.identifier for item in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{key: value for key, value in wanted.items() if key in supported})


def build_specter(req, mats):
    h = float(req["dimensions_m"]["height"])
    rig = ns["biped_rig"](h)
    box = ns["box"]
    cylinder = ns["cylinder"]
    beam = ns["beam"]
    parent_bone = ns["parent_bone"]
    make_action = ns["make_action"]
    armor = mats["primary"]
    dark = mats["dark"]
    joint = mats["joint"]
    red = mats["red"]

    def attach(obj, bone):
        parent_bone(obj, rig, bone)
        return obj

    # Pelvis, layered torso and exposed central spine.
    attach(box("DZ_torso_pelvis", Vector((0.0, 0.0, h * 0.405)), Vector((h * 0.28, h * 0.20, h * 0.16)), dark, 0.025), "pelvis")
    attach(cylinder("PelvisHub", Vector((0.0, 0.0, h * 0.42)), h * 0.105, h * 0.13, joint, (math.pi / 2, 0.0, 0.0), 12), "pelvis")
    attach(box("DZ_torso_core", Vector((0.0, 0.015, h * 0.61)), Vector((h * 0.31, h * 0.22, h * 0.31)), dark, 0.026), "spine")
    attach(box("ChestArmorLeft", Vector((-h * 0.092, -h * 0.105, h * 0.64)), Vector((h * 0.145, h * 0.055, h * 0.24)), armor, 0.018), "spine")
    attach(box("ChestArmorRight", Vector((h * 0.092, -h * 0.105, h * 0.64)), Vector((h * 0.145, h * 0.055, h * 0.24)), armor, 0.018), "spine")
    attach(box("ChestCenterInset", Vector((0.0, -h * 0.139, h * 0.62)), Vector((h * 0.07, h * 0.026, h * 0.17)), joint, 0.007), "spine")
    attach(box("BackPowerPack", Vector((0.0, h * 0.13, h * 0.62)), Vector((h * 0.23, h * 0.09, h * 0.23)), armor, 0.018), "spine")
    for z in (0.50, 0.57, 0.71):
        attach(cylinder(f"SpineServo_{z}", Vector((0.0, h * 0.125, h * z)), h * 0.035, h * 0.05, joint, (math.pi / 2, 0.0, 0.0), 8), "spine")

    # Sensor head with protective brow and side actuators.
    attach(box("DZ_sensor_head", Vector((0.0, 0.0, h * 0.815)), Vector((h * 0.21, h * 0.19, h * 0.17)), dark, 0.026), "head")
    attach(box("SensorBrow", Vector((0.0, -h * 0.105, h * 0.855)), Vector((h * 0.20, h * 0.035, h * 0.055)), armor, 0.010), "head")
    attach(cylinder("DZ_sensor_lens", Vector((0.0, -h * 0.112, h * 0.817)), h * 0.050, h * 0.032, red, (math.pi / 2, 0.0, 0.0), 12), "head")
    attach(cylinder("SensorBezel", Vector((0.0, -h * 0.105, h * 0.817)), h * 0.070, h * 0.025, joint, (math.pi / 2, 0.0, 0.0), 12), "head")
    for side in (-1.0, 1.0):
        attach(cylinder(f"HeadServo_{side:+.0f}", Vector((side * h * 0.115, 0.0, h * 0.815)), h * 0.045, h * 0.045, joint, (0.0, math.pi / 2, 0.0), 10), "head")

    # Shoulder armor, segmented arms, elbows and three-prong hands.
    for side_name, side in (("L", -1.0), ("R", 1.0)):
        shoulder = Vector((side * h * 0.175, 0.0, h * 0.685))
        elbow = Vector((side * h * 0.275, 0.0, h * 0.49))
        wrist = Vector((side * h * 0.295, -h * 0.015, h * 0.315))
        attach(cylinder(f"{side_name}_ShoulderHub", shoulder, h * 0.075, h * 0.075, joint, (0.0, math.pi / 2, 0.0), 12), f"{side_name}_upper_arm")
        attach(box(f"{side_name}_ShoulderArmor", shoulder + Vector((side * h * 0.02, 0.0, h * 0.015)), Vector((h * 0.14, h * 0.15, h * 0.12)), armor, 0.018), f"{side_name}_upper_arm")
        attach(beam(f"DZ_{side_name.lower()}_arm_upper", shoulder, elbow, h * 0.070, dark), f"{side_name}_upper_arm")
        attach(box(f"{side_name}_UpperArmPlate", (shoulder + elbow) * 0.5 + Vector((side * h * 0.018, -h * 0.015, 0.0)), Vector((h * 0.10, h * 0.075, h * 0.17)), armor, 0.012), f"{side_name}_upper_arm")
        attach(cylinder(f"{side_name}_ElbowHub", elbow, h * 0.060, h * 0.070, joint, (0.0, math.pi / 2, 0.0), 10), f"{side_name}_forearm")
        attach(beam(f"DZ_{side_name.lower()}_arm_lower", elbow, wrist, h * 0.058, dark), f"{side_name}_forearm")
        attach(box(f"{side_name}_ForearmArmor", (elbow + wrist) * 0.5 + Vector((side * h * 0.016, -h * 0.018, 0.0)), Vector((h * 0.085, h * 0.075, h * 0.15)), armor, 0.011), f"{side_name}_forearm")
        palm = wrist + Vector((0.0, -h * 0.025, -h * 0.035))
        attach(box(f"{side_name}_Palm", palm, Vector((h * 0.085, h * 0.07, h * 0.095)), joint, 0.010), f"{side_name}_forearm")
        for finger_index, offset in enumerate((-0.030, 0.0, 0.030)):
            attach(box(f"{side_name}_Finger_{finger_index}", palm + Vector((side * offset * h, -h * 0.045, -h * 0.075)), Vector((h * 0.018, h * 0.025, h * 0.075)), dark, 0.004), f"{side_name}_forearm")

    # Articulated legs, exposed pistons and broad stabilizer feet.
    for side_name, side in (("L", -1.0), ("R", 1.0)):
        hip = Vector((side * h * 0.105, 0.0, h * 0.405))
        knee = Vector((side * h * 0.112, -h * 0.01, h * 0.225))
        ankle = Vector((side * h * 0.112, 0.0, h * 0.060))
        attach(cylinder(f"{side_name}_HipHub", hip, h * 0.070, h * 0.080, joint, (0.0, math.pi / 2, 0.0), 12), f"{side_name}_thigh")
        attach(beam(f"DZ_{side_name.lower()}_leg_upper", hip, knee, h * 0.085, dark), f"{side_name}_thigh")
        attach(box(f"DZ_{side_name.lower()}_leg_thigh_armor", (hip + knee) * 0.5 + Vector((side * h * 0.018, -h * 0.025, 0.0)), Vector((h * 0.115, h * 0.10, h * 0.17)), armor, 0.015), f"{side_name}_thigh")
        attach(cylinder(f"DZ_{side_name.lower()}_leg_knee", knee, h * 0.070, h * 0.085, joint, (0.0, math.pi / 2, 0.0), 12), f"{side_name}_shin")
        attach(beam(f"DZ_{side_name.lower()}_leg_lower", knee, ankle, h * 0.076, dark), f"{side_name}_shin")
        attach(box(f"DZ_{side_name.lower()}_leg_shin_armor", (knee + ankle) * 0.5 + Vector((side * h * 0.018, -h * 0.032, 0.0)), Vector((h * 0.105, h * 0.10, h * 0.15)), armor, 0.014), f"{side_name}_shin")
        attach(beam(f"{side_name}_LegPiston", hip + Vector((0.0, h * 0.05, -h * 0.025)), ankle + Vector((0.0, h * 0.05, h * 0.04)), h * 0.022, joint), f"{side_name}_shin")
        attach(cylinder(f"{side_name}_AnkleHub", ankle, h * 0.050, h * 0.070, joint, (0.0, math.pi / 2, 0.0), 10), f"{side_name}_foot")
        foot_center = Vector((side * h * 0.112, -h * 0.055, h * 0.032))
        attach(box(f"DZ_{side_name.lower()}_leg_foot", foot_center, Vector((h * 0.145, h * 0.23, h * 0.064)), dark, 0.012), f"{side_name}_foot")
        attach(box(f"{side_name}_ToeArmor", foot_center + Vector((0.0, -h * 0.082, h * 0.018)), Vector((h * 0.14, h * 0.075, h * 0.055)), armor, 0.010), f"{side_name}_foot")

    clips = ["Idle-loop", "Walk-loop", "Run-loop", "Attack", "Crawl-loop", "Shutdown"]
    make_action(rig, "Idle-loop", [(1, {}, (0, 0, 0)), (24, {"head": (0.0, 0.12, 0.0)}, (0, 0, h * 0.004)), (48, {}, (0, 0, 0))])
    make_action(rig, "Walk-loop", [(1, {"L_thigh": (0.35,0,0), "R_thigh": (-0.35,0,0), "L_upper_arm": (-0.25,0,0), "R_upper_arm": (0.25,0,0)}, (0,0,0)), (21, {"L_thigh": (-0.35,0,0), "R_thigh": (0.35,0,0), "L_upper_arm": (0.25,0,0), "R_upper_arm": (-0.25,0,0)}, (0,0,h*0.012)), (41, {"L_thigh": (0.35,0,0), "R_thigh": (-0.35,0,0)}, (0,0,0))])
    make_action(rig, "Run-loop", [(1, {"L_thigh": (0.62,0,0), "R_thigh": (-0.62,0,0)}, (0,0,0)), (13, {"L_thigh": (-0.62,0,0), "R_thigh": (0.62,0,0)}, (0,0,h*0.025)), (25, {"L_thigh": (0.62,0,0), "R_thigh": (-0.62,0,0)}, (0,0,0))])
    make_action(rig, "Attack", [(1, {}, (0,0,0)), (10, {"L_upper_arm": (-1.05,0,0), "R_upper_arm": (-1.05,0,0), "spine": (-0.18,0,0)}, (0,-h*0.045,0)), (20, {}, (0,0,0))])
    make_action(rig, "Crawl-loop", [(1, {"L_thigh": (1.2,0,0), "R_thigh": (1.2,0,0), "L_upper_arm": (-0.55,0,0), "R_upper_arm": (0.55,0,0)}, (0,0,-h*0.28)), (20, {"L_upper_arm": (0.55,0,0), "R_upper_arm": (-0.55,0,0)}, (0,0,-h*0.28)), (40, {"L_upper_arm": (-0.55,0,0), "R_upper_arm": (0.55,0,0)}, (0,0,-h*0.28))])
    make_action(rig, "Shutdown", [(1, {}, (0,0,0)), (36, {"spine": (1.25,0,0), "head": (0.65,0,0), "L_thigh": (0.55,0,0), "R_thigh": (0.55,0,0)}, (0,0,-h*0.22))])

    zones = [
        {"id":"left_leg","material_id":"metal_light","max_health":35,"detachable":True,"node_patterns":["DZ_l_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
        {"id":"right_leg","material_id":"metal_light","max_health":35,"detachable":True,"node_patterns":["DZ_r_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
        {"id":"sensor","material_id":"glass","max_health":18,"detachable":False,"node_patterns":["DZ_sensor_*"],"on_break":"disable_detection"},
        {"id":"torso","material_id":"metal_armored","max_health":100,"detachable":False,"node_patterns":["DZ_torso_*"],"on_break":"shutdown"},
    ]
    return rig, clips, zones


ns["reset"] = compatible_reset
ns["material"] = compatible_material
ns["export_glb"] = compatible_export_glb
ns["build_biped"] = build_specter
ns["main"]()
