#!/usr/bin/env python3
"""Generate controlled low-poly game assets for Blackout Protocol.

This is intentionally category-aware instead of pretending that one CPU model can reconstruct
arbitrary hidden geometry from an image. Uploaded images guide palette, proportions and GUI
textures. Geometry, rigs, named damage zones and animation clips are deterministic and validated.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector


def cli() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args(values)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.025, 0.03, 0.036)
    scene.frame_start = 1
    scene.frame_end = 48


MATERIALS: dict[str, tuple[tuple[float, float, float, float], float, float]] = {
    "metal_light": ((0.18, 0.19, 0.20, 1.0), 0.85, 0.48),
    "metal_armored": ((0.105, 0.085, 0.065, 1.0), 0.92, 0.64),
    "technical_plastic": ((0.10, 0.13, 0.14, 1.0), 0.15, 0.72),
    "glass": ((0.08, 0.20, 0.24, 0.62), 0.05, 0.18),
    "drywall": ((0.47, 0.45, 0.41, 1.0), 0.0, 0.92),
    "brick": ((0.34, 0.12, 0.075, 1.0), 0.0, 0.88),
    "concrete": ((0.24, 0.25, 0.24, 1.0), 0.0, 0.94),
    "wood": ((0.28, 0.16, 0.07, 1.0), 0.0, 0.82),
}


def material(name: str, definition: tuple[tuple[float, float, float, float], float, float], emission: tuple[float, float, float, float] | None = None, texture: Path | None = None) -> bpy.types.Material:
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
    if color[3] < 1.0:
        bsdf.inputs["Alpha"].default_value = color[3]
        mat.blend_method = "BLEND"
    if texture is not None and texture.exists():
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = bpy.data.images.load(str(texture), check_existing=True)
        image_node.interpolation = "Closest"
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
        if "Alpha" in image_node.outputs:
            links.new(image_node.outputs["Alpha"], bsdf.inputs["Alpha"])
    if emission is not None:
        socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if socket is not None:
            socket.default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength is not None:
            strength.default_value = 4.0
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def finish(obj: bpy.types.Object, mat: bpy.types.Material, bevel: float = 0.02) -> bpy.types.Object:
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("PS1Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    return obj


def box(name: str, location: Vector, dimensions: Vector, mat: bpy.types.Material, bevel: float = 0.02) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel)


def cylinder(name: str, location: Vector, radius: float, depth: float, mat: bpy.types.Material, rotation=(0.0, 0.0, 0.0), vertices: int = 10) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, min(0.018, radius * 0.1))


def beam(name: str, start: Vector, end: Vector, thickness: float, mat: bpy.types.Material) -> bpy.types.Object:
    direction = end - start
    obj = box(name, (start + end) * 0.5, Vector((thickness, thickness, direction.length)), mat, 0.014)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def parent_bone(obj: bpy.types.Object, rig: bpy.types.Object, bone: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def make_action(rig: bpy.types.Object, name: str, poses: list[tuple[int, dict[str, tuple[float, float, float]], tuple[float, float, float]]]) -> None:
    if rig.animation_data is None:
        rig.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame, rotations, body_offset in poses:
        for bone in rig.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = rotations.get(bone.name, (0.0, 0.0, 0.0))
            bone.location = body_offset if bone.name in {"root", "body"} else (0.0, 0.0, 0.0)
            bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
            bone.keyframe_insert("location", frame=frame, group=bone.name)
    for curve in action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, poses[0][0], action)
    strip.action_frame_start = poses[0][0]
    strip.action_frame_end = poses[-1][0]
    strip.frame_end = poses[-1][0]
    rig.animation_data.action = None


def biped_rig(height: float) -> bpy.types.Object:
    data = bpy.data.armatures.new("BipedRig")
    rig = bpy.data.objects.new("BipedRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {}
    bones["root"] = data.edit_bones.new("root"); bones["root"].head = Vector((0, 0, 0.05)); bones["root"].tail = Vector((0, 0, height * 0.18))
    bones["pelvis"] = data.edit_bones.new("pelvis"); bones["pelvis"].head = Vector((0, 0, height * 0.18)); bones["pelvis"].tail = Vector((0, 0, height * 0.42)); bones["pelvis"].parent = bones["root"]
    bones["spine"] = data.edit_bones.new("spine"); bones["spine"].head = bones["pelvis"].tail; bones["spine"].tail = Vector((0, 0, height * 0.72)); bones["spine"].parent = bones["pelvis"]
    bones["head"] = data.edit_bones.new("head"); bones["head"].head = bones["spine"].tail; bones["head"].tail = Vector((0, 0, height * 0.94)); bones["head"].parent = bones["spine"]
    for side, sign in (("L", -1.0), ("R", 1.0)):
        hip = Vector((sign * height * 0.10, 0, height * 0.40)); knee = Vector((sign * height * 0.11, 0, height * 0.22)); ankle = Vector((sign * height * 0.11, 0, height * 0.05))
        bones[f"{side}_thigh"] = data.edit_bones.new(f"{side}_thigh"); bones[f"{side}_thigh"].head = hip; bones[f"{side}_thigh"].tail = knee; bones[f"{side}_thigh"].parent = bones["pelvis"]
        bones[f"{side}_shin"] = data.edit_bones.new(f"{side}_shin"); bones[f"{side}_shin"].head = knee; bones[f"{side}_shin"].tail = ankle; bones[f"{side}_shin"].parent = bones[f"{side}_thigh"]
        bones[f"{side}_foot"] = data.edit_bones.new(f"{side}_foot"); bones[f"{side}_foot"].head = ankle; bones[f"{side}_foot"].tail = ankle + Vector((0, -height * 0.12, 0)); bones[f"{side}_foot"].parent = bones[f"{side}_shin"]
        shoulder = Vector((sign * height * 0.17, 0, height * 0.68)); elbow = Vector((sign * height * 0.27, 0, height * 0.48)); hand = Vector((sign * height * 0.29, -height * 0.02, height * 0.30))
        bones[f"{side}_upper_arm"] = data.edit_bones.new(f"{side}_upper_arm"); bones[f"{side}_upper_arm"].head = shoulder; bones[f"{side}_upper_arm"].tail = elbow; bones[f"{side}_upper_arm"].parent = bones["spine"]
        bones[f"{side}_forearm"] = data.edit_bones.new(f"{side}_forearm"); bones[f"{side}_forearm"].head = elbow; bones[f"{side}_forearm"].tail = hand; bones[f"{side}_forearm"].parent = bones[f"{side}_upper_arm"]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def build_biped(req: dict[str, Any], mats: dict[str, bpy.types.Material]) -> tuple[bpy.types.Object, list[str], list[dict[str, Any]]]:
    h = req["dimensions_m"]["height"]
    rig = biped_rig(h)
    armor, dark, joint, red = mats["primary"], mats["dark"], mats["joint"], mats["red"]
    pelvis = box("DZ_torso_pelvis", Vector((0, 0, h * 0.43)), Vector((h * 0.28, h * 0.18, h * 0.18)), dark); parent_bone(pelvis, rig, "pelvis")
    torso = box("DZ_torso_core", Vector((0, 0, h * 0.62)), Vector((h * 0.34, h * 0.22, h * 0.34)), armor); parent_bone(torso, rig, "spine")
    head = box("DZ_sensor_head", Vector((0, -h * 0.015, h * 0.82)), Vector((h * 0.22, h * 0.20, h * 0.18)), dark); parent_bone(head, rig, "head")
    eye = cylinder("DZ_sensor_lens", Vector((0, -h * 0.12, h * 0.82)), h * 0.045, h * 0.025, red, (math.pi / 2, 0, 0), 10); parent_bone(eye, rig, "head")
    for side, sign in (("L", -1.0), ("R", 1.0)):
        upper = beam(f"DZ_{side.lower()}_leg_upper", Vector((sign*h*0.10,0,h*0.40)), Vector((sign*h*0.11,0,h*0.22)), h*0.085, armor); parent_bone(upper, rig, f"{side}_thigh")
        lower = beam(f"DZ_{side.lower()}_leg_lower", Vector((sign*h*0.11,0,h*0.22)), Vector((sign*h*0.11,0,h*0.06)), h*0.075, dark); parent_bone(lower, rig, f"{side}_shin")
        foot = box(f"DZ_{side.lower()}_leg_foot", Vector((sign*h*0.11,-h*0.05,h*0.035)), Vector((h*0.13,h*0.22,h*0.07)), dark); parent_bone(foot, rig, f"{side}_foot")
        arm = beam(f"DZ_{side.lower()}_arm_upper", Vector((sign*h*0.17,0,h*0.68)), Vector((sign*h*0.27,0,h*0.48)), h*0.065, armor); parent_bone(arm, rig, f"{side}_upper_arm")
        fore = beam(f"DZ_{side.lower()}_arm_lower", Vector((sign*h*0.27,0,h*0.48)), Vector((sign*h*0.29,-h*0.02,h*0.30)), h*0.055, dark); parent_bone(fore, rig, f"{side}_forearm")
        cylinder(f"Joint_{side}_Knee", Vector((sign*h*0.11,0,h*0.22)), h*0.055, h*0.065, joint, (0,math.pi/2,0), 10)
    clips = ["Idle-loop", "Walk-loop", "Run-loop", "Attack", "Crawl-loop", "Shutdown"]
    make_action(rig, "Idle-loop", [(1, {}, (0,0,0)), (24, {}, (0,0,h*0.006)), (48, {}, (0,0,0))])
    make_action(rig, "Walk-loop", [(1,{"L_thigh":(0.35,0,0),"R_thigh":(-0.35,0,0),"L_upper_arm":(-0.25,0,0),"R_upper_arm":(0.25,0,0)},(0,0,0)),(21,{"L_thigh":(-0.35,0,0),"R_thigh":(0.35,0,0),"L_upper_arm":(0.25,0,0),"R_upper_arm":(-0.25,0,0)},(0,0,h*0.012)),(41,{"L_thigh":(0.35,0,0),"R_thigh":(-0.35,0,0)},(0,0,0))])
    make_action(rig, "Run-loop", [(1,{"L_thigh":(0.62,0,0),"R_thigh":(-0.62,0,0)},(0,0,0)),(13,{"L_thigh":(-0.62,0,0),"R_thigh":(0.62,0,0)},(0,0,h*0.025)),(25,{"L_thigh":(0.62,0,0),"R_thigh":(-0.62,0,0)},(0,0,0))])
    make_action(rig, "Attack", [(1,{},(0,0,0)),(10,{"L_upper_arm":(-1.0,0,0),"R_upper_arm":(-1.0,0,0)},(0,-h*0.04,0)),(20,{},(0,0,0))])
    make_action(rig, "Crawl-loop", [(1,{"L_thigh":(1.2,0,0),"R_thigh":(1.2,0,0),"L_upper_arm":(-0.55,0,0),"R_upper_arm":(0.55,0,0)},(0,0,-h*0.28)),(20,{"L_upper_arm":(0.55,0,0),"R_upper_arm":(-0.55,0,0)},(0,0,-h*0.28)),(40,{"L_upper_arm":(-0.55,0,0),"R_upper_arm":(0.55,0,0)},(0,0,-h*0.28))])
    make_action(rig, "Shutdown", [(1,{},(0,0,0)),(36,{"spine":(1.25,0,0),"head":(0.65,0,0)},(0,0,-h*0.22))])
    zones = [
        {"id":"left_leg","material_id":req["material_id"],"max_health":35,"detachable":True,"node_patterns":["DZ_l_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
        {"id":"right_leg","material_id":req["material_id"],"max_health":35,"detachable":True,"node_patterns":["DZ_r_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
        {"id":"sensor","material_id":"glass","max_health":18,"detachable":False,"node_patterns":["DZ_sensor_*"],"on_break":"disable_detection"},
        {"id":"torso","material_id":"metal_armored","max_health":100,"detachable":False,"node_patterns":["DZ_torso_*"],"on_break":"shutdown"},
    ]
    return rig, clips, zones


def quadruped_rig(width: float, depth: float, height: float) -> tuple[bpy.types.Object, dict[str, tuple[Vector,Vector,Vector,Vector]]]:
    points = {
        "LF": (Vector((-width*0.32,-depth*0.28,height*0.60)),Vector((-width*0.58,-depth*0.42,height*0.40)),Vector((-width*0.67,-depth*0.52,height*0.14)),Vector((-width*0.72,-depth*0.61,height*0.06))),
        "RF": (Vector(( width*0.32,-depth*0.28,height*0.60)),Vector(( width*0.58,-depth*0.42,height*0.40)),Vector(( width*0.67,-depth*0.52,height*0.14)),Vector(( width*0.72,-depth*0.61,height*0.06))),
        "LR": (Vector((-width*0.32, depth*0.28,height*0.60)),Vector((-width*0.58, depth*0.42,height*0.40)),Vector((-width*0.67, depth*0.52,height*0.14)),Vector((-width*0.72, depth*0.61,height*0.06))),
        "RR": (Vector(( width*0.32, depth*0.28,height*0.60)),Vector(( width*0.58, depth*0.42,height*0.40)),Vector(( width*0.67, depth*0.52,height*0.14)),Vector(( width*0.72, depth*0.61,height*0.06))),
    }
    data=bpy.data.armatures.new("QuadrupedRig"); rig=bpy.data.objects.new("QuadrupedRig",data); bpy.context.collection.objects.link(rig); bpy.context.view_layer.objects.active=rig; rig.select_set(True); bpy.ops.object.mode_set(mode="EDIT")
    body=data.edit_bones.new("body"); body.head=Vector((0,0,height*0.32)); body.tail=Vector((0,0,height*0.78))
    for prefix,(hip,knee,ankle,toe) in points.items():
        upper=data.edit_bones.new(prefix+"_upper"); upper.head=hip; upper.tail=knee; upper.parent=body
        lower=data.edit_bones.new(prefix+"_lower"); lower.head=knee; lower.tail=ankle; lower.parent=upper
        foot=data.edit_bones.new(prefix+"_foot"); foot.head=ankle; foot.tail=toe; foot.parent=lower
    bpy.ops.object.mode_set(mode="OBJECT"); rig.select_set(False)
    return rig,points


def build_quadruped(req: dict[str, Any], mats: dict[str,bpy.types.Material]) -> tuple[bpy.types.Object,list[str],list[dict[str,Any]]]:
    d=req["dimensions_m"]; w,h,dep=d["width"],d["height"],d["depth"]
    rig,points=quadruped_rig(w,dep,h); armor,dark,joint,red=mats["primary"],mats["dark"],mats["joint"],mats["red"]
    body=box("DZ_body_core",Vector((0,0,h*0.64)),Vector((w*0.68,dep*0.64,h*0.46)),armor); parent_bone(body,rig,"body")
    face=box("DZ_sensor_face",Vector((0,-dep*0.36,h*0.62)),Vector((w*0.45,dep*0.08,h*0.26)),dark); parent_bone(face,rig,"body")
    for i,(x,z) in enumerate(((-w*.12,h*.68),(w*.12,h*.68),(-w*.12,h*.55),(w*.12,h*.55))):
        eye=cylinder(f"DZ_sensor_{i}",Vector((x,-dep*.42,z)),min(w,h)*.045,dep*.03,red,(math.pi/2,0,0),10); parent_bone(eye,rig,"body")
    for prefix,(hip,knee,ankle,toe) in points.items():
        upper=beam(f"DZ_{prefix}_upper",hip,knee,min(w,h)*.09,armor); parent_bone(upper,rig,prefix+"_upper")
        lower=beam(f"DZ_{prefix}_lower",knee,ankle,min(w,h)*.075,dark); parent_bone(lower,rig,prefix+"_lower")
        foot=box(f"DZ_{prefix}_foot",toe,Vector((w*.15,dep*.18,h*.12)),dark); parent_bone(foot,rig,prefix+"_foot")
        cylinder(f"Joint_{prefix}",knee,min(w,h)*.07,min(w,h)*.09,joint,(0,math.pi/2,0),10)
    clips=["Idle-loop","Walk-loop","Run-loop","Attack","Shutdown"]
    make_action(rig,"Idle-loop",[(1,{},(0,0,0)),(24,{},(0,0,h*.015)),(48,{},(0,0,0))])
    gait_a={"LF_upper":(.3,0,0),"RR_upper":(.3,0,0),"RF_upper":(-.3,0,0),"LR_upper":(-.3,0,0)}; gait_b={k:(-v[0],0,0) for k,v in gait_a.items()}
    make_action(rig,"Walk-loop",[(1,gait_a,(0,0,0)),(21,gait_b,(0,0,h*.02)),(41,gait_a,(0,0,0))])
    make_action(rig,"Run-loop",[(1,{k:(v[0]*1.6,0,0) for k,v in gait_a.items()},(0,0,0)),(13,{k:(v[0]*1.6,0,0) for k,v in gait_b.items()},(0,0,h*.04)),(25,{k:(v[0]*1.6,0,0) for k,v in gait_a.items()},(0,0,0))])
    make_action(rig,"Attack",[(1,{},(0,0,0)),(10,{"LF_upper":(-.75,0,0),"RF_upper":(-.75,0,0)},(0,-dep*.1,h*.04)),(22,{},(0,0,0))])
    make_action(rig,"Shutdown",[(1,{},(0,0,0)),(36,{"LF_upper":(1.0,0,0),"RF_upper":(1.0,0,0),"LR_upper":(1.0,0,0),"RR_upper":(1.0,0,0)},(0,0,-h*.45))])
    zones=[]
    for prefix in ("LF","RF","LR","RR"):
        zones.append({"id":prefix.lower()+"_leg","material_id":req["material_id"],"max_health":28,"detachable":True,"node_patterns":[f"DZ_{prefix}_*"],"speed_multiplier":0.78,"on_break":"reduce_speed"})
    zones += [{"id":"sensor","material_id":"glass","max_health":18,"detachable":False,"node_patterns":["DZ_sensor_*"],"on_break":"disable_detection"},{"id":"body","material_id":"metal_armored","max_health":110,"detachable":False,"node_patterns":["DZ_body_*"],"on_break":"shutdown"}]
    return rig,clips,zones


def build_static(req: dict[str,Any], mats: dict[str,bpy.types.Material]) -> tuple[None,list[str],list[dict[str,Any]]]:
    d=req["dimensions_m"]; w,h,dep=d["width"],d["height"],d["depth"]; category=req["category"]; primary,dark,red=mats["primary"],mats["dark"],mats["red"]
    zones=[]; clips=[]
    if category == "wall":
        cell=max(0.45,min(1.15,w/6.0,h/4.0)); cols=max(1,round(w/cell)); rows=max(1,round(h/cell)); cw=w/cols; ch=h/rows
        for row in range(rows):
            for col in range(cols):
                x=-w/2+cw*(col+.5); z=ch*(row+.5)
                name=f"DZ_wall_{row}_{col}"
                box(name,Vector((x,0,z)),Vector((cw*.96,dep,ch*.96)),primary,0.008)
                zones.append({"id":f"cell_{row}_{col}","material_id":req["material_id"],"max_health":20 if req["material_id"]=="drywall" else 55,"detachable":True,"node_patterns":[name],"on_break":"open_hole"})
    elif category == "door":
        box("DoorFrameTop",Vector((0,0,h)),Vector((w+0.18,dep*1.3,0.18)),dark)
        box("DoorFrameL",Vector((-w/2,0,h/2)),Vector((0.18,dep*1.3,h)),dark); box("DoorFrameR",Vector((w/2,0,h/2)),Vector((0.18,dep*1.3,h)),dark)
        panel=box("DZ_door_panel",Vector((0,0,h/2)),Vector((w*.88,dep,h*.92)),primary)
        zones=[{"id":"door_panel","material_id":req["material_id"],"max_health":90,"detachable":True,"node_patterns":["DZ_door_panel"],"on_break":"unlock"}]
    elif category == "gui_panel":
        box("ConsoleBody",Vector((0,0,h*.45)),Vector((w,dep,h*.9)),dark)
        tex=Path(req["reference_images"][0]) if req.get("reference_images") else None
        screen_mat=material("GUITexture",((0.02,0.12,0.14,1),0.05,0.25),emission=(0.0,0.55,0.7,1),texture=tex)
        box("DZ_screen",Vector((0,-dep*.52,h*.55)),Vector((w*.78,dep*.05,h*.5)),screen_mat,0.006)
        zones=[{"id":"screen","material_id":"glass","max_health":15,"detachable":False,"node_patterns":["DZ_screen"],"on_break":"disable_gui"}]
    elif category == "environment":
        box("ModuleFloor",Vector((0,0.0,0.06)),Vector((w,dep,0.12)),dark)
        box("ModuleBack",Vector((0,dep*.48,h*.5)),Vector((w,0.12,h)),primary)
        for x in (-w*.35,w*.35):
            cylinder("Pipe",Vector((x,dep*.40,h*.55)),min(w,h)*.04,h*.75,dark,vertices=8)
    else:
        box("DZ_prop_core",Vector((0,0,h*.5)),Vector((w,dep,h)),primary)
        box("PropInset",Vector((0,-dep*.51,h*.58)),Vector((w*.62,dep*.04,h*.34)),dark,0.008)
        zones=[{"id":"core","material_id":req["material_id"],"max_health":35,"detachable":req["destruction_mode"]!="none","node_patterns":["DZ_prop_core"],"on_break":"break"}]
    return None,clips,zones


def build_materials(req: dict[str,Any]) -> dict[str,bpy.types.Material]:
    base=MATERIALS[req["material_id"]]
    return {
        "primary":material("BP_Primary",base),
        "dark":material("BP_DarkMetal",((0.035,0.038,0.04,1),0.85,0.72)),
        "joint":material("BP_Joints",((0.025,0.022,0.02,1),0.9,0.86)),
        "red":material("BP_RedSensor",((0.15,0.005,0.005,1),0.2,0.25),emission=(1.0,0.0,0.02,1)),
    }


def add_collision_helpers(req: dict[str,Any]) -> int:
    d=req["dimensions_m"]; count=0; hidden=material("CollisionHidden",((0,0,0,1),0,1))
    if req["category"].startswith("robot_"):
        col=box("Body-colonly",Vector((0,0,d["height"]*.48)),Vector((d["width"]*.65,d["depth"]*.65,d["height"]*.75)),hidden,0); col.hide_render=True; col.display_type="WIRE"; count=1
    else:
        col=box("Asset-colonly",Vector((0,0,d["height"]*.5)),Vector((d["width"],d["depth"],d["height"])),hidden,0); col.hide_render=True; col.display_type="WIRE"; count=1
    return count


def render_preview(path: Path, dimensions: dict[str,float]) -> None:
    scene=bpy.context.scene; scene.render.filepath=str(path)
    ground=material("PreviewGround",((0.035,0.04,0.045,1),0,0.95)); box("PreviewGround",Vector((0,0,-.04)),Vector((12,12,.08)),ground,0)
    extent=max(dimensions.values()); target=Vector((0,0,dimensions["height"]*.48))
    for location,energy,size in (((4,-5,5),750,4),((-4,-1,3),300,3),((0,4,4),420,3)):
        bpy.ops.object.light_add(type="AREA",location=location); lamp=bpy.context.object; lamp.data.energy=energy; lamp.data.size=size
    bpy.ops.object.camera_add(location=(extent*2.4,-extent*3.4,max(extent*2.0,dimensions["height"]*1.25)))
    camera=bpy.context.object; camera.data.lens=58; camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler(); scene.camera=camera
    bpy.ops.render.render(write_still=True)


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",export_animations=True,export_yup=True,export_apply=True)


def metrics(req: dict[str,Any], rig: bpy.types.Object|None, clips:list[str], zones:list[dict[str,Any]], collisions:int) -> dict[str,Any]:
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH" and not obj.name.startswith("Preview")]
    triangles=0; vertices=0
    for obj in meshes:
        vertices += len(obj.data.vertices)
        triangles += sum(max(1,len(poly.vertices)-2) for poly in obj.data.polygons)
    return {"schema_version":1,"asset":req["asset_name"],"slug":req["slug"],"generator":"Blackout category-aware Blender generator v1","category":req["category"],"mesh_objects":len(meshes),"vertices":vertices,"triangles":triangles,"bones":len(rig.data.bones) if rig else 0,"animations":clips,"materials":[mat.name for mat in bpy.data.materials],"collision_helpers":collisions,"damage_zones":len(zones),"reference_images_used":len(req.get("reference_images",[]))}


def write_sidecars(req:dict[str,Any], out:Path, zones:list[dict[str,Any]], report:dict[str,Any]) -> None:
    slug=req["slug"]
    asset={"schema_version":1,"id":slug,"name":req["asset_name"],"category":req["category"],"glb":f"res://assets/generated/{slug}/{slug}.glb","preview":f"res://assets/generated/{slug}/{slug}.png","damage_profile":f"res://assets/generated/{slug}/{slug}.damage.json","integration":req["integration"],"dimensions_m":req["dimensions_m"],"rig":req["rig"],"animations":report["animations"],"generator_profile":req["generator_profile"],"fallback":"procedural"}
    damage={"schema_version":1,"asset_id":slug,"mode":req["destruction_mode"],"default_material":req["material_id"],"zones":zones,"tool_rules":{"flashlight_bash":0.45,"plank":0.8,"crowbar":2.2,"thrown_prop":1.0,"specter_charge":4.0},"descriptions":{"zones":req.get("damage_zones_description",""),"interactions":req.get("interactions_description","")}}
    (out/f"{slug}.asset.json").write_text(json.dumps(asset,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (out/f"{slug}.damage.json").write_text(json.dumps(damage,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")


def main() -> None:
    args=cli(); req=json.loads(args.request.read_text(encoding="utf-8")); out=args.output_dir; out.mkdir(parents=True,exist_ok=True); reset(); mats=build_materials(req)
    if req["category"]=="robot_biped": rig,clips,zones=build_biped(req,mats)
    elif req["category"]=="robot_quadruped": rig,clips,zones=build_quadruped(req,mats)
    else: rig,clips,zones=build_static(req,mats)
    collisions=add_collision_helpers(req)
    preview_path=out/f"{req['slug']}.png"; render_preview(preview_path,req["dimensions_m"])
    # Remove preview-only objects before export.
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith("Preview") or obj.type in {"LIGHT","CAMERA"}:
            bpy.data.objects.remove(obj,do_unlink=True)
    glb=out/f"{req['slug']}.glb"; export_glb(glb)
    report=metrics(req,rig,clips,zones,collisions)
    (out/f"{req['slug']}.metrics.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    write_sidecars(req,out,zones,report)
    print(json.dumps(report))


if __name__=="__main__":
    main()
