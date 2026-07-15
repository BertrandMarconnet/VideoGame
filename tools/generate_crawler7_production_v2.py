#!/usr/bin/env python3
"""Generate the rigged and animated CRAWLER-7 production asset in Blender 3.4+.

The script deliberately models a known mechanical robot instead of trying to infer hidden
geometry from one image. It produces separate rigid parts, a quadruped armature, embedded
materials, five animation clips, collision helpers, a preview PNG and a GLB.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    parser.add_argument("--quality", choices=("web", "high"), default="web")
    return parser.parse_args(values)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    engines = {item.identifier for item in scene.bl_rna.properties["render"].fixed_type.properties["engine"].enum_items} if False else set()
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.06, 0.065)
    scene.frame_start = 1
    scene.frame_end = 48


def noise_image(size: int) -> bpy.types.Image:
    random.seed(1987)
    image = bpy.data.images.new("CRAWLER7_WearAtlas", size, size, alpha=True)
    pixels: list[float] = []
    for y in range(size):
        for x in range(size):
            grain = 0.68 + random.random() * 0.24
            scratch = 0.18 if ((x * 23 + y * 37) % 193) < 2 else 0.0
            value = max(0.22, min(1.0, grain + scratch))
            pixels.extend((value, value * 0.94, value * 0.86, 1.0))
    image.pixels = pixels
    image.pack()
    return image


def material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    atlas: bpy.types.Image | None = None,
    emission: tuple[float, float, float, float] | None = None,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if atlas is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = atlas
        tex.interpolation = "Closest"
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 0.28
        mix.inputs[1].default_value = color
        links.new(tex.outputs["Color"], mix.inputs[2])
        links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = emission
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 7.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def finish_mesh(obj: bpy.types.Object, mat: bpy.types.Material, bevel_width: float) -> bpy.types.Object:
    obj.data.materials.append(mat)
    if bevel_width > 0:
        modifier = obj.modifiers.new("LowPolyBevel", "BEVEL")
        modifier.width = bevel_width
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass
    obj.select_set(False)
    return obj


def box(name: str, loc: Vector, dims: Vector, mat: bpy.types.Material, bevel_width: float = 0.025) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel_width)


def cylinder(
    name: str,
    loc: Vector,
    radius: float,
    depth: float,
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    vertices: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat, min(0.02, radius * 0.12))


def beam(name: str, start: Vector, end: Vector, width: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    direction = end - start
    obj = box(name, (start + end) * 0.5, Vector((width, depth, direction.length)), mat, 0.022)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def armature_for(points: dict[str, tuple[Vector, Vector, Vector, Vector]]) -> bpy.types.Object:
    data = bpy.data.armatures.new("CRAWLER7_Rig")
    rig = bpy.data.objects.new("CRAWLER7_Rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    body = data.edit_bones.new("body")
    body.head = Vector((0.0, 0.0, 0.54))
    body.tail = Vector((0.0, 0.0, 1.18))
    for prefix, (hip, knee, ankle, toe) in points.items():
        upper = data.edit_bones.new(prefix + "_upper")
        upper.head, upper.tail, upper.parent = hip, knee, body
        lower = data.edit_bones.new(prefix + "_lower")
        lower.head, lower.tail, lower.parent = knee, ankle, upper
        lower.use_connect = True
        foot = data.edit_bones.new(prefix + "_foot")
        foot.head, foot.tail, foot.parent = ankle, toe, lower
        foot.use_connect = True
    bpy.ops.object.mode_set(mode="POSE")
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def rigid_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def add_collisions(rig: bpy.types.Object, points: dict[str, tuple[Vector, Vector, Vector, Vector]]) -> int:
    count = 0
    body = box("CrawlerBody-colonly", Vector((0.0, 0.0, 0.78)), Vector((1.38, 1.82, 0.66)), bpy.data.materials["CRAWLER7_Black"], 0.0)
    body.hide_render = True
    body.display_type = "WIRE"
    rigid_parent(body, rig, "body")
    count += 1
    for prefix, (_, _, _, toe) in points.items():
        obj = box(prefix + "Foot-colonly", toe, Vector((0.48, 0.60, 0.24)), bpy.data.materials["CRAWLER7_Black"], 0.0)
        obj.hide_render = True
        obj.display_type = "WIRE"
        rigid_parent(obj, rig, prefix + "_foot")
        count += 1
    return count


def full_pose(rig: bpy.types.Object, rotations: dict[str, tuple[float, float, float]], body_offset: tuple[float, float, float]) -> None:
    for bone in rig.pose.bones:
        bone.rotation_euler = rotations.get(bone.name, (0.0, 0.0, 0.0))
        bone.location = body_offset if bone.name == "body" else (0.0, 0.0, 0.0)


def keys(rig: bpy.types.Object, frame: int) -> None:
    for bone in rig.pose.bones:
        bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
        bone.keyframe_insert("location", frame=frame, group=bone.name)


def leg(prefix: str, upper: float, lower: float, foot: float = 0.0) -> dict[str, tuple[float, float, float]]:
    return {
        prefix + "_upper": (upper, 0.0, 0.0),
        prefix + "_lower": (lower, 0.0, 0.0),
        prefix + "_foot": (foot, 0.0, 0.0),
    }


def combine(*parts: dict[str, tuple[float, float, float]]) -> dict[str, tuple[float, float, float]]:
    result: dict[str, tuple[float, float, float]] = {}
    for part in parts:
        result.update(part)
    return result


def action(rig: bpy.types.Object, name: str, frames: list[tuple[int, dict[str, tuple[float, float, float]], tuple[float, float, float]]]) -> None:
    if rig.animation_data is None:
        rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for frame, rotations, offset in frames:
        full_pose(rig, rotations, offset)
        keys(rig, frame)
    for curve in act.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, frames[0][0], act)
    strip.action_frame_start = frames[0][0]
    strip.action_frame_end = frames[-1][0]
    strip.frame_end = frames[-1][0]
    rig.animation_data.action = None


def animate(rig: bpy.types.Object) -> list[str]:
    action(rig, "Idle-loop", [
        (1, {}, (0.0, 0.0, 0.0)),
        (24, {}, (0.0, 0.0, 0.025)),
        (48, {}, (0.0, 0.0, 0.0)),
    ])
    action(rig, "Walk-loop", [
        (1, combine(leg("LF", 0.25, -0.42), leg("RR", 0.25, -0.42), leg("RF", -0.22, 0.34), leg("LR", -0.22, 0.34)), (0.0, 0.0, 0.0)),
        (11, {}, (0.0, 0.0, 0.035)),
        (21, combine(leg("LF", -0.22, 0.34), leg("RR", -0.22, 0.34), leg("RF", 0.25, -0.42), leg("LR", 0.25, -0.42)), (0.0, 0.0, 0.0)),
        (31, {}, (0.0, 0.0, 0.035)),
        (41, combine(leg("LF", 0.25, -0.42), leg("RR", 0.25, -0.42), leg("RF", -0.22, 0.34), leg("LR", -0.22, 0.34)), (0.0, 0.0, 0.0)),
    ])
    action(rig, "Run-loop", [
        (1, combine(leg("LF", 0.42, -0.60), leg("RR", 0.42, -0.60), leg("RF", -0.38, 0.52), leg("LR", -0.38, 0.52)), (0.0, 0.0, -0.01)),
        (7, {}, (0.0, 0.0, 0.06)),
        (13, combine(leg("LF", -0.38, 0.52), leg("RR", -0.38, 0.52), leg("RF", 0.42, -0.60), leg("LR", 0.42, -0.60)), (0.0, 0.0, -0.01)),
        (19, {}, (0.0, 0.0, 0.06)),
        (25, combine(leg("LF", 0.42, -0.60), leg("RR", 0.42, -0.60), leg("RF", -0.38, 0.52), leg("LR", -0.38, 0.52)), (0.0, 0.0, -0.01)),
    ])
    action(rig, "Attack", [
        (1, {}, (0.0, 0.0, 0.0)),
        (10, combine(leg("LF", -0.20, 0.24), leg("RF", -0.20, 0.24), leg("LR", 0.20, -0.26), leg("RR", 0.20, -0.26)), (0.0, -0.10, 0.08)),
        (18, combine(leg("LF", 0.40, -0.54), leg("RF", 0.40, -0.54), leg("LR", -0.18, 0.24), leg("RR", -0.18, 0.24)), (0.0, -0.28, -0.03)),
        (34, {}, (0.0, 0.0, 0.0)),
    ])
    action(rig, "Shutdown", [
        (1, {}, (0.0, 0.0, 0.0)),
        (20, combine(leg("LF", 0.35, -0.64), leg("RF", 0.35, -0.64), leg("LR", -0.12, 0.42), leg("RR", -0.12, 0.42)), (0.0, 0.0, -0.14)),
        (48, combine(leg("LF", 0.62, -1.05), leg("RF", 0.62, -1.05), leg("LR", 0.40, -0.88), leg("RR", 0.40, -0.88)), (0.0, 0.0, -0.32)),
    ])
    return ["Idle-loop", "Walk-loop", "Run-loop", "Attack", "Shutdown"]


def build(quality: str) -> tuple[bpy.types.Object, list[str], int]:
    atlas = noise_image(128 if quality == "web" else 256)
    dark = material("CRAWLER7_DarkMetal", (0.085, 0.075, 0.065, 1.0), 0.85, 0.62, atlas)
    armor = material("CRAWLER7_BrownArmor", (0.29, 0.19, 0.105, 1.0), 0.75, 0.66, atlas)
    black = material("CRAWLER7_Black", (0.018, 0.022, 0.025, 1.0), 0.68, 0.55, atlas)
    joint = material("CRAWLER7_Joints", (0.035, 0.032, 0.028, 1.0), 0.25, 0.88, atlas)
    red = material("CRAWLER7_RedSensors", (0.20, 0.002, 0.001, 1.0), 0.1, 0.24, None, (1.0, 0.0, 0.0, 1.0))

    body_parts = [
        box("BodyCore", Vector((0.0, 0.0, 0.78)), Vector((1.28, 1.65, 0.54)), dark, 0.05),
        box("TopArmor", Vector((0.0, 0.0, 1.08)), Vector((1.02, 1.30, 0.22)), armor, 0.04),
        box("FrontHead", Vector((0.0, -0.98, 0.75)), Vector((0.92, 0.42, 0.48)), black, 0.05),
        box("TopHatch", Vector((0.0, -0.02, 1.22)), Vector((0.48, 0.58, 0.10)), black, 0.025),
        box("RearPack", Vector((0.0, 0.92, 0.82)), Vector((0.90, 0.34, 0.42)), armor, 0.04),
    ]
    for x in (-0.48, 0.48):
        body_parts.append(box("ShoulderArmor" + str(x), Vector((x, -0.10, 1.02)), Vector((0.28, 1.25, 0.25)), armor, 0.035))
        body_parts.append(box("SideModule" + str(x), Vector((x * 1.19, -0.15, 0.78)), Vector((0.24, 0.80, 0.38)), black, 0.03))
    for index, (x, z) in enumerate(((-0.22, 0.15), (0.22, 0.15), (-0.22, -0.15), (0.22, -0.15))):
        body_parts.append(cylinder("Sensor" + str(index), Vector((x, -1.215, 0.77 + z)), 0.10, 0.055, red, (math.pi / 2, 0.0, 0.0), 12))
    body_parts.append(cylinder("SensorCenter", Vector((0.0, -1.22, 0.76)), 0.06, 0.06, red, (math.pi / 2, 0.0, 0.0), 10))

    points = {
        "LF": (Vector((-0.65, -0.60, 0.86)), Vector((-1.02, -0.78, 0.61)), Vector((-1.22, -0.94, 0.23)), Vector((-1.36, -1.16, 0.12))),
        "RF": (Vector((0.65, -0.60, 0.86)), Vector((1.02, -0.78, 0.61)), Vector((1.22, -0.94, 0.23)), Vector((1.36, -1.16, 0.12))),
        "LR": (Vector((-0.65, 0.60, 0.86)), Vector((-1.02, 0.78, 0.61)), Vector((-1.22, 0.94, 0.23)), Vector((-1.36, 1.16, 0.12))),
        "RR": (Vector((0.65, 0.60, 0.86)), Vector((1.02, 0.78, 0.61)), Vector((1.22, 0.94, 0.23)), Vector((1.36, 1.16, 0.12))),
    }
    rig = armature_for(points)
    for obj in body_parts:
        rigid_parent(obj, rig, "body")
    for prefix, (hip, knee, ankle, toe) in points.items():
        parts = [
            (beam(prefix + "_Upper", hip, knee, 0.24, 0.30, armor), prefix + "_upper"),
            (cylinder(prefix + "_Hip", hip, 0.18, 0.20, joint, (0.0, math.pi / 2, 0.0), 12), prefix + "_upper"),
            (beam(prefix + "_Lower", knee, ankle, 0.22, 0.27, dark), prefix + "_lower"),
            (cylinder(prefix + "_Knee", knee, 0.15, 0.18, joint, (0.0, math.pi / 2, 0.0), 12), prefix + "_lower"),
            (beam(prefix + "_FootBeam", ankle, toe, 0.25, 0.32, armor), prefix + "_foot"),
            (cylinder(prefix + "_Ankle", ankle, 0.12, 0.17, joint, (0.0, math.pi / 2, 0.0), 10), prefix + "_foot"),
            (box(prefix + "_FootPad", toe, Vector((0.46, 0.58, 0.20)), black, 0.035), prefix + "_foot"),
        ]
        for obj, bone in parts:
            rigid_parent(obj, rig, bone)
    collision_count = add_collisions(rig, points)
    clips = animate(rig)
    return rig, clips, collision_count


def preview(path: Path) -> None:
    scene = bpy.context.scene
    scene.render.filepath = str(path)
    ground_mat = material("PreviewGround", (0.08, 0.085, 0.09, 1.0), 0.0, 0.94)
    bpy.ops.mesh.primitive_plane_add(size=20.0, location=(0.0, 0.0, -0.01))
    ground = bpy.context.object
    ground.name = "PreviewGroundObject"
    ground.data.materials.append(ground_mat)
    for location, energy, size in (((4.0, -5.0, 6.0), 1150.0, 4.5), ((-4.0, -1.0, 3.5), 700.0, 4.0), ((0.0, 4.0, 4.0), 750.0, 3.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.size = size
    bpy.ops.object.camera_add(location=(4.15, -5.45, 3.05))
    camera = bpy.context.object
    camera.data.lens = 57
    camera.rotation_euler = (Vector((0.0, 0.0, 0.74)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.frame_set(1)
    bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.name == "PreviewGroundObject" or obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def export(path: Path) -> None:
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


def report(path: Path, output: Path, rig: bpy.types.Object, clips: list[str], collisions: int) -> None:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.name.endswith("-colonly")]
    triangles = sum(sum(max(1, len(face.vertices) - 2) for face in obj.data.polygons) for obj in meshes)
    materials = sorted({mat.name for obj in meshes for mat in obj.data.materials if mat})
    data = {
        "asset": "CRAWLER-7",
        "generator": "Blender deterministic hard-surface v2",
        "output": str(output),
        "mesh_objects": len(meshes),
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "triangles": triangles,
        "bones": len(rig.data.bones),
        "animations": clips,
        "materials": materials,
        "collision_helpers": collisions,
        "rig_type": "rigid segmented quadruped",
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    options = args()
    reset()
    rig, clips, collisions = build(options.quality)
    options.preview.parent.mkdir(parents=True, exist_ok=True)
    preview(options.preview)
    export(options.output)
    report(options.metrics, options.output, rig, clips, collisions)
    print(json.dumps({"output": str(options.output), "clips": clips}, indent=2))


if __name__ == "__main__":
    main()
