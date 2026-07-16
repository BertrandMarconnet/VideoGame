#!/usr/bin/env python3
"""Extended compatibility entry point for the Blackout category-aware asset generator.

The base generator remains deliberately deterministic. This wrapper adds:
- reference-derived PS1 texture atlases;
- humanoid, FPS viewmodel and articulated-machine profiles;
- segmented props and animated doors;
- richer metadata while preserving Blender/Godot Web compatibility.
"""
from __future__ import annotations

import json
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
namespace: dict[str, object] = {"__file__": str(SOURCE), "__name__": "generic_asset_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)

namespace["MATERIALS"]["technical_fabric"] = ((0.075, 0.065, 0.055, 1.0), 0.02, 0.93)
ORIGINAL_BUILD_STATIC = namespace["build_static"]
ORIGINAL_BUILD_BIPED = namespace["build_biped"]
ORIGINAL_METRICS = namespace["metrics"]
ORIGINAL_WRITE_SIDECARS = namespace["write_sidecars"]

box = namespace["box"]
cylinder = namespace["cylinder"]
beam = namespace["beam"]
parent_bone = namespace["parent_bone"]
make_action = namespace["make_action"]


def compatible_reset() -> None:
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
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BlackoutAssetWorld")
    scene.world.color = (0.025, 0.03, 0.036)
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
    if color[3] < 1.0:
        bsdf.inputs["Alpha"].default_value = color[3]
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
    if texture is not None and Path(texture).exists():
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = bpy.data.images.load(str(texture), check_existing=True)
        image_node.interpolation = "Closest"
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
        alpha_output = image_node.outputs.get("Alpha")
        if alpha_output is not None and bsdf.inputs.get("Alpha") is not None:
            links.new(alpha_output, bsdf.inputs["Alpha"])
    if emission is not None:
        socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if socket is not None:
            socket.default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength is not None:
            strength.default_value = 4.0
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def reference_palette(request) -> list[tuple[float, float, float]]:
    samples: list[tuple[float, float, float]] = []
    for reference in request.get("reference_images", [])[:6]:
        path = Path(reference)
        if not path.exists():
            continue
        try:
            image = bpy.data.images.load(str(path), check_existing=True)
            pixel_count = max(1, int(image.size[0]) * int(image.size[1]))
            step = max(1, pixel_count // 2400)
            pixels = image.pixels
            for pixel_index in range(0, pixel_count, step):
                offset = pixel_index * 4
                red, green, blue, alpha = (float(pixels[offset + index]) for index in range(4))
                brightness = max(red, green, blue)
                saturation = brightness - min(red, green, blue)
                if alpha > 0.45 and 0.025 < brightness < 0.88 and saturation > 0.025:
                    samples.append((red, green, blue))
        except Exception as exc:
            print(f"Reference palette skipped for {path}: {exc}")
    if not samples:
        return []
    # Quantize deterministically into eight luminance/saturation bands.
    samples.sort(key=lambda item: (sum(item), max(item) - min(item), item[0]))
    palette: list[tuple[float, float, float]] = []
    for index in range(8):
        start = int(len(samples) * index / 8)
        end = max(start + 1, int(len(samples) * (index + 1) / 8))
        band = samples[start:end]
        palette.append(tuple(sum(pixel[channel] for pixel in band) / len(band) for channel in range(3)))
    return palette


def create_reference_atlas(request) -> Path | None:
    if request.get("texture_mode", "reference_atlas") != "reference_atlas":
        return None
    palette = reference_palette(request)
    if not palette:
        return None
    size = 64
    image = bpy.data.images.new(f"BP_Atlas_{request['slug']}", width=size, height=size, alpha=True)
    values: list[float] = []
    for y in range(size):
        for x in range(size):
            tile = ((x // 8) + (y // 8) * 3 + (x * 5 + y * 7) // 23) % len(palette)
            base = palette[tile]
            variation = 0.84 + ((x * 17 + y * 29) % 9) * 0.025
            values.extend((
                max(0.01, min(0.92, base[0] * variation)),
                max(0.01, min(0.92, base[1] * variation)),
                max(0.01, min(0.92, base[2] * variation)),
                1.0,
            ))
    image.pixels.foreach_set(values)
    path = Path("/tmp") / f"{request['slug']}_reference_atlas.png"
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return path


def compatible_build_materials(request):
    definitions = namespace["MATERIALS"]
    base = definitions[request["material_id"]]
    palette = reference_palette(request)
    if palette and request.get("texture_mode") != "flat":
        sampled = tuple(sum(color[channel] for color in palette) / len(palette) for channel in range(3))
        original = base[0]
        blend = 0.48
        adapted = tuple(max(0.018, min(0.58, original[index] * (1.0 - blend) + sampled[index] * blend)) for index in range(3)) + (original[3],)
        base = (adapted, base[1], base[2])
    atlas = create_reference_atlas(request)
    return {
        "primary": compatible_material("BP_Primary", base, texture=atlas),
        "dark": compatible_material("BP_DarkMetal", ((0.035, 0.038, 0.04, 1.0), 0.85, 0.72)),
        "joint": compatible_material("BP_Joints", ((0.025, 0.022, 0.02, 1.0), 0.9, 0.86)),
        "red": compatible_material("BP_RedSensor", ((0.15, 0.005, 0.005, 1.0), 0.2, 0.25), emission=(1.0, 0.0, 0.02, 1.0)),
        "fabric": compatible_material("BP_TechnicalFabric", namespace["MATERIALS"]["technical_fabric"]),
    }


def create_rig(name: str, definitions: list[tuple[str, Vector, Vector, str | None]]) -> bpy.types.Object:
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for bone_name, head, tail, parent_name in definitions:
        bone = data.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        if parent_name:
            bone.parent = created[parent_name]
        created[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def build_fps_viewmodel(req, mats):
    d = req["dimensions_m"]
    w, h, dep = d["width"], d["height"], d["depth"]
    scale = max(0.22, min(1.0, max(w, h, dep)))
    rig = create_rig("FPSViewmodelRig", [
        ("root", Vector((0, 0, 0.02)), Vector((0, 0, 0.16)), None),
        ("forearm", Vector((0.18, 0.12, 0.12)), Vector((0.08, -0.12, 0.24)), "root"),
        ("hand", Vector((0.08, -0.12, 0.24)), Vector((0.02, -0.28, 0.30)), "forearm"),
        ("tool", Vector((0.0, -0.20, 0.30)), Vector((0.0, -0.58, 0.30)), "hand"),
    ])
    primary, dark, red, fabric = mats["primary"], mats["dark"], mats["red"], mats["fabric"]
    sleeve = box("FPS_Sleeve", Vector((0.16, 0.05, 0.14)), Vector((0.20, 0.34, 0.18)), fabric, 0.014)
    parent_bone(sleeve, rig, "forearm")
    palm = box("FPS_GlovePalm", Vector((0.06, -0.17, 0.26)), Vector((0.16, 0.22, 0.13)), fabric, 0.014)
    parent_bone(palm, rig, "hand")
    for index in range(4):
        finger = box(f"FPS_Finger_{index}", Vector((-0.045 + index * 0.032, -0.26, 0.28)), Vector((0.027, 0.16, 0.038)), fabric, 0.008)
        parent_bone(finger, rig, "hand")
    thumb = box("FPS_Thumb", Vector((0.13, -0.21, 0.28)), Vector((0.045, 0.13, 0.045)), fabric, 0.008)
    thumb.rotation_euler.z = -0.45
    parent_bone(thumb, rig, "hand")

    # Default held-tool profile is a rugged industrial flashlight, suitable for the generated reference pack.
    tool_length = max(0.34, dep * 0.72)
    body = cylinder("DZ_tool_body", Vector((0.0, -0.40, 0.30)), max(0.035, w * 0.10), tool_length, primary, (math.pi / 2, 0, 0), 10)
    parent_bone(body, rig, "tool")
    head = cylinder("DZ_tool_head", Vector((0.0, -0.62, 0.30)), max(0.065, w * 0.17), max(0.08, dep * 0.16), dark, (math.pi / 2, 0, 0), 8)
    parent_bone(head, rig, "tool")
    lens = cylinder("DZ_tool_lens", Vector((0.0, -0.675, 0.30)), max(0.047, w * 0.125), 0.016, red, (math.pi / 2, 0, 0), 12)
    parent_bone(lens, rig, "tool")
    battery = cylinder("DZ_tool_battery", Vector((0.0, -0.20, 0.30)), max(0.045, w * 0.12), max(0.07, dep * 0.12), dark, (math.pi / 2, 0, 0), 10)
    parent_bone(battery, rig, "tool")

    clips = ["Idle-loop", "Use", "Bash", "Inspect"]
    make_action(rig, "Idle-loop", [(1, {}, (0, 0, 0)), (24, {"hand": (0.015, 0.02, -0.01)}, (0, 0, 0.006)), (48, {}, (0, 0, 0))])
    make_action(rig, "Use", [(1, {}, (0, 0, 0)), (8, {"tool": (0.0, 0.0, 0.08)}, (0, -0.015, 0)), (16, {}, (0, 0, 0))])
    make_action(rig, "Bash", [(1, {}, (0, 0, 0)), (8, {"forearm": (-0.7, 0.15, -0.20), "hand": (-0.35, 0, 0)}, (0, 0.12, 0.05)), (16, {"forearm": (0.45, -0.1, 0.12)}, (0, -0.18, -0.03)), (26, {}, (0, 0, 0))])
    make_action(rig, "Inspect", [(1, {}, (0, 0, 0)), (24, {"hand": (0.25, -0.15, 0.55), "tool": (0, 0.55, 0.0)}, (0, 0, 0.04)), (48, {}, (0, 0, 0))])
    zones = [
        {"id": "tool_body", "material_id": req["material_id"], "max_health": 45, "detachable": True, "node_patterns": ["DZ_tool_body", "DZ_tool_head"], "on_break": "disable_tool"},
        {"id": "lens", "material_id": "glass", "max_health": 12, "detachable": False, "node_patterns": ["DZ_tool_lens"], "on_break": "disable_light"},
        {"id": "battery", "material_id": "technical_plastic", "max_health": 18, "detachable": True, "node_patterns": ["DZ_tool_battery"], "on_break": "disable_power"},
    ]
    return rig, clips, zones


def build_articulated_machine(req, mats):
    d = req["dimensions_m"]
    w, h, dep = d["width"], d["height"], d["depth"]
    rig = create_rig("IndustrialMachineRig", [
        ("root", Vector((0, 0, 0.02)), Vector((0, 0, h * 0.16)), None),
        ("column", Vector((0, 0, h * 0.15)), Vector((0, 0, h * 0.58)), "root"),
        ("shoulder", Vector((0, 0, h * 0.56)), Vector((w * 0.28, 0, h * 0.70)), "column"),
        ("elbow", Vector((w * 0.28, 0, h * 0.70)), Vector((w * 0.50, -dep * 0.12, h * 0.52)), "shoulder"),
        ("wrist", Vector((w * 0.50, -dep * 0.12, h * 0.52)), Vector((w * 0.58, -dep * 0.22, h * 0.34)), "elbow"),
        ("tool", Vector((w * 0.58, -dep * 0.22, h * 0.34)), Vector((w * 0.62, -dep * 0.30, h * 0.22)), "wrist"),
    ])
    primary, dark, joint, red = mats["primary"], mats["dark"], mats["joint"], mats["red"]
    base = cylinder("DZ_machine_base", Vector((0, 0, h * 0.08)), max(w, dep) * 0.20, h * 0.16, dark, vertices=10)
    parent_bone(base, rig, "root")
    column = beam("DZ_machine_column", Vector((0, 0, h * 0.15)), Vector((0, 0, h * 0.58)), max(0.08, w * 0.11), primary)
    parent_bone(column, rig, "column")
    upper = beam("DZ_machine_upper", Vector((0, 0, h * 0.56)), Vector((w * 0.28, 0, h * 0.70)), max(0.07, w * 0.09), primary)
    parent_bone(upper, rig, "shoulder")
    lower = beam("DZ_machine_lower", Vector((w * 0.28, 0, h * 0.70)), Vector((w * 0.50, -dep * 0.12, h * 0.52)), max(0.06, w * 0.075), dark)
    parent_bone(lower, rig, "elbow")
    wrist = cylinder("DZ_machine_wrist", Vector((w * 0.50, -dep * 0.12, h * 0.52)), max(0.06, w * 0.075), max(0.08, dep * 0.18), joint, (math.pi / 2, 0, 0), 10)
    parent_bone(wrist, rig, "wrist")
    tool = box("DZ_machine_tool", Vector((w * 0.58, -dep * 0.24, h * 0.28)), Vector((w * 0.16, dep * 0.22, h * 0.18)), primary)
    parent_bone(tool, rig, "tool")
    sensor = cylinder("DZ_machine_sensor", Vector((w * 0.58, -dep * 0.36, h * 0.30)), max(0.025, w * 0.035), 0.02, red, (math.pi / 2, 0, 0), 10)
    parent_bone(sensor, rig, "tool")
    clips = ["Idle-loop", "Work-loop", "Alarm", "Shutdown"]
    make_action(rig, "Idle-loop", [(1, {}, (0, 0, 0)), (24, {"wrist": (0, 0.08, 0)}, (0, 0, 0)), (48, {}, (0, 0, 0))])
    make_action(rig, "Work-loop", [(1, {"shoulder": (0, -0.25, 0), "elbow": (0.2, 0, 0)}, (0, 0, 0)), (20, {"shoulder": (0, 0.35, 0), "elbow": (-0.45, 0, 0), "wrist": (0, 0, 0.55)}, (0, 0, 0)), (40, {"shoulder": (0, -0.25, 0), "elbow": (0.2, 0, 0)}, (0, 0, 0))])
    make_action(rig, "Alarm", [(1, {}, (0, 0, 0)), (8, {"tool": (0, 0, 0.35)}, (0, 0, 0.03)), (16, {"tool": (0, 0, -0.35)}, (0, 0, 0)), (24, {}, (0, 0, 0.03))])
    make_action(rig, "Shutdown", [(1, {}, (0, 0, 0)), (36, {"shoulder": (0, 0.7, 0), "elbow": (1.1, 0, 0)}, (0, 0, -h * 0.03))])
    zones = [
        {"id": "base", "material_id": "metal_armored", "max_health": 120, "detachable": False, "node_patterns": ["DZ_machine_base", "DZ_machine_column"], "on_break": "shutdown"},
        {"id": "upper_arm", "material_id": req["material_id"], "max_health": 55, "detachable": True, "node_patterns": ["DZ_machine_upper"], "on_break": "disable_arm"},
        {"id": "lower_arm", "material_id": req["material_id"], "max_health": 45, "detachable": True, "node_patterns": ["DZ_machine_lower", "DZ_machine_wrist"], "on_break": "disable_tool"},
        {"id": "tool", "material_id": req["material_id"], "max_health": 35, "detachable": True, "node_patterns": ["DZ_machine_tool"], "on_break": "disable_tool"},
        {"id": "sensor", "material_id": "glass", "max_health": 14, "detachable": False, "node_patterns": ["DZ_machine_sensor"], "on_break": "disable_detection"},
    ]
    return rig, clips, zones


def build_segmented_prop(req, mats):
    parts = list(req.get("segmentation_parts") or [])
    if not parts:
        parts = ["core", "front_module", "rear_module"]
    parts = parts[:8]
    d = req["dimensions_m"]
    w, h, dep = d["width"], d["height"], d["depth"]
    primary, dark = mats["primary"], mats["dark"]
    rig = None
    if req.get("rig") == "rigid_segmented":
        definitions = [("root", Vector((0, 0, 0.02)), Vector((0, 0, max(0.08, h * 0.12))), None)]
        for index, part in enumerate(parts):
            z = h * (index + 0.5) / len(parts)
            definitions.append((part, Vector((0, 0, max(0.01, z - h / len(parts) * 0.45))), Vector((0, 0, z + h / len(parts) * 0.45)), "root"))
        rig = create_rig("SegmentedPropRig", definitions)
    zones = []
    segment_height = h / len(parts)
    for index, part in enumerate(parts):
        z = segment_height * (index + 0.5)
        margin = 0.94 if index not in {0, len(parts) - 1} else 0.98
        obj = box(f"DZ_{part}", Vector((0, 0, z)), Vector((w * margin, dep * margin, segment_height * 0.94)), primary if index % 2 == 0 else dark, min(0.02, min(w, dep) * 0.06))
        if rig is not None:
            parent_bone(obj, rig, part)
        zones.append({"id": part, "material_id": req["material_id"], "max_health": 25 + index * 4, "detachable": req.get("destruction_mode") != "none", "node_patterns": [f"DZ_{part}"], "on_break": "detach_part"})
    clips: list[str] = []
    if rig is not None:
        clips = ["Idle-loop", "Use", "Break"]
        make_action(rig, "Idle-loop", [(1, {}, (0, 0, 0)), (24, {}, (0, 0, h * 0.006)), (48, {}, (0, 0, 0))])
        active = parts[-1]
        make_action(rig, "Use", [(1, {}, (0, 0, 0)), (12, {active: (0.18, 0, 0)}, (0, 0, 0)), (24, {}, (0, 0, 0))])
        make_action(rig, "Break", [(1, {}, (0, 0, 0)), (18, {active: (0.9, 0.2, 0.15)}, (0, 0, -h * 0.02))])
    return rig, clips, zones


def build_animated_door(req, mats):
    d = req["dimensions_m"]
    w, h, dep = d["width"], d["height"], d["depth"]
    primary, dark, red = mats["primary"], mats["dark"], mats["red"]
    rig = create_rig("DoorRig", [
        ("root", Vector((-w * 0.48, 0, 0.02)), Vector((-w * 0.48, 0, h * 0.12)), None),
        ("panel", Vector((-w * 0.44, 0, 0.05)), Vector((-w * 0.44, 0, h * 0.95)), "root"),
    ])
    box("DoorFrameTop", Vector((0, 0, h)), Vector((w + 0.18, dep * 1.3, 0.18)), dark)
    box("DoorFrameL", Vector((-w / 2, 0, h / 2)), Vector((0.18, dep * 1.3, h)), dark)
    box("DoorFrameR", Vector((w / 2, 0, h / 2)), Vector((0.18, dep * 1.3, h)), dark)
    panel = box("DZ_door_panel", Vector((0, 0, h / 2)), Vector((w * 0.88, dep, h * 0.92)), primary)
    parent_bone(panel, rig, "panel")
    lock = box("DZ_door_lock", Vector((w * 0.30, -dep * 0.58, h * 0.54)), Vector((w * 0.10, dep * 0.12, h * 0.13)), dark, 0.008)
    parent_bone(lock, rig, "panel")
    lamp = box("DoorStatus", Vector((w * 0.30, -dep * 0.66, h * 0.60)), Vector((w * 0.035, dep * 0.03, h * 0.035)), red, 0.004)
    parent_bone(lamp, rig, "panel")
    clips = ["Closed", "Open", "Close"]
    make_action(rig, "Closed", [(1, {}, (0, 0, 0)), (24, {}, (0, 0, 0))])
    make_action(rig, "Open", [(1, {"panel": (0, 0, 0)}, (0, 0, 0)), (36, {"panel": (0, 0, -1.35)}, (0, 0, 0))])
    make_action(rig, "Close", [(1, {"panel": (0, 0, -1.35)}, (0, 0, 0)), (36, {"panel": (0, 0, 0)}, (0, 0, 0))])
    zones = [
        {"id": "door_panel", "material_id": req["material_id"], "max_health": 90, "detachable": req.get("destruction_mode") != "none", "node_patterns": ["DZ_door_panel"], "on_break": "unlock"},
        {"id": "door_lock", "material_id": "metal_light", "max_health": 28, "detachable": True, "node_patterns": ["DZ_door_lock"], "on_break": "unlock"},
    ]
    return rig, clips, zones


def enhanced_build_static(req, mats):
    category = req["category"]
    if category == "character_humanoid":
        return ORIGINAL_BUILD_BIPED(req, mats)
    if category == "fps_viewmodel":
        return build_fps_viewmodel(req, mats)
    if category == "articulated_machine":
        return build_articulated_machine(req, mats)
    if category == "door" and req.get("rig") in {"hinge", "rigid_segmented"}:
        return build_animated_door(req, mats)
    if category == "prop" and (req.get("segmentation_parts") or req.get("geometry_template") in {"modular_detachable", "held_tool"} or req.get("rig") == "rigid_segmented"):
        return build_segmented_prop(req, mats)
    return ORIGINAL_BUILD_STATIC(req, mats)


def compatible_export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
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


def enhanced_metrics(req, rig, clips, zones, collisions):
    report = ORIGINAL_METRICS(req, rig, clips, zones, collisions)
    report["texture_mode"] = req.get("texture_mode", "palette_only")
    report["reference_mode"] = req.get("reference_mode", "none")
    report["collision_mode"] = req.get("collision_mode", "auto")
    report["segmentation_parts"] = req.get("segmentation_parts", [])
    return report


def enhanced_write_sidecars(req, out, zones, report):
    ORIGINAL_WRITE_SIDECARS(req, out, zones, report)
    asset_path = out / f"{req['slug']}.asset.json"
    asset = json.loads(asset_path.read_text(encoding="utf-8"))
    asset.update({
        "reference_mode": req.get("reference_mode", "none"),
        "texture_mode": req.get("texture_mode", "palette_only"),
        "collision_mode": req.get("collision_mode", "auto"),
        "geometry_template": req.get("geometry_template", "auto"),
        "segmentation_parts": req.get("segmentation_parts", []),
    })
    asset_path.write_text(json.dumps(asset, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


namespace["reset"] = compatible_reset
namespace["material"] = compatible_material
namespace["build_materials"] = compatible_build_materials
namespace["build_static"] = enhanced_build_static
namespace["export_glb"] = compatible_export_glb
namespace["metrics"] = enhanced_metrics
namespace["write_sidecars"] = enhanced_write_sidecars
namespace["main"]()
