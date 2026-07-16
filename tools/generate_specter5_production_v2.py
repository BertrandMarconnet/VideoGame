#!/usr/bin/env python3
"""Reference-aware SPECTER-5 production entry point."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import bpy

from build_asset_audio_v2 import build as build_audio
from sanitize_generated_glb import sanitize as sanitize_glb


def _arg_path(flag: str) -> Path:
    if flag not in sys.argv:
        raise RuntimeError(f"Missing generator argument: {flag}")
    return Path(sys.argv[sys.argv.index(flag) + 1])


def _animation_key(value: str) -> str:
    value = value.lower().replace("-loop", "").replace("_loop", "")
    return re.sub(r"[^a-z0-9]+", "_", value).strip("_")


request_path = _arg_path("--request")
output_dir = _arg_path("--output-dir")
request_data = json.loads(request_path.read_text(encoding="utf-8"))
requested_animations = [str(value) for value in request_data.get("animations", []) if str(value).strip()]
requested_keys = {_animation_key(value) for value in requested_animations}

SOURCE = Path(__file__).with_name("generate_specter5_production.py")
text = SOURCE.read_text(encoding="utf-8")
marker = 'ns["main"]()'
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
scope: dict[str, object] = {"__file__": str(SOURCE), "__name__": "specter_reference_module"}
exec(compile(text, str(SOURCE), "exec"), scope)
module_ns = scope["ns"]
material = scope["compatible_material"]
original_make_action = module_ns["make_action"]
original_build_biped = module_ns["build_biped"]


def reference_color(request) -> tuple[float, float, float] | None:
    samples: list[tuple[float, float, float]] = []
    for reference in request.get("reference_images", [])[:4]:
        path = Path(reference)
        if not path.exists():
            continue
        try:
            image = bpy.data.images.load(str(path), check_existing=True)
            pixel_count = max(1, int(image.size[0]) * int(image.size[1]))
            step = max(1, pixel_count // 2200)
            pixels = image.pixels
            for pixel_index in range(0, pixel_count, step):
                offset = pixel_index * 4
                red, green, blue, alpha = (float(pixels[offset + channel]) for channel in range(4))
                brightness = max(red, green, blue)
                saturation = max(red, green, blue) - min(red, green, blue)
                if alpha > 0.45 and 0.035 < brightness < 0.78 and saturation > 0.05:
                    samples.append((red, green, blue))
        except Exception as exc:
            print(f"SPECTER reference palette skipped for {path}: {exc}")
    if not samples:
        return None
    return tuple(sum(sample[channel] for sample in samples) / len(samples) for channel in range(3))


def reference_build_materials(request):
    base = module_ns["MATERIALS"][request["material_id"]]
    sampled = reference_color(request)
    if sampled is not None:
        original = base[0]
        blend = 0.58
        adapted = tuple(max(0.018, min(0.46, original[index] * (1.0 - blend) + sampled[index] * blend)) for index in range(3)) + (1.0,)
        base = (adapted, base[1], base[2])
    return {
        "primary": material("BP_Primary", base),
        "dark": material("BP_DarkMetal", ((0.032, 0.034, 0.036, 1.0), 0.9, 0.72)),
        "joint": material("BP_Joints", ((0.022, 0.020, 0.018, 1.0), 0.92, 0.86)),
        "red": material("BP_RedSensor", ((0.15, 0.004, 0.004, 1.0), 0.2, 0.22), emission=(1.0, 0.0, 0.02, 1.0)),
    }


def selected_make_action(rig, name, frames):
    if requested_keys and _animation_key(str(name)) not in requested_keys:
        return None
    return original_make_action(rig, name, frames)


def _selected_damage_zones(req, defaults):
    selected = {_animation_key(str(value)) for value in req.get("segmentation_parts", [])}
    if not selected:
        return defaults
    material_id = str(req.get("material_id", "metal_light"))
    definitions = {
        "tete": {"id":"head","material_id":material_id,"max_health":34,"detachable":True,"node_patterns":["DZ_sensor_head"],"on_break":"disable_detection"},
        "capteur": {"id":"sensor","material_id":"glass","max_health":16,"detachable":False,"node_patterns":["DZ_sensor_lens"],"on_break":"disable_detection"},
        "torse_corps_central": {"id":"torso","material_id":"metal_armored","max_health":100,"detachable":False,"node_patterns":["DZ_torso_*"],"on_break":"shutdown"},
        "corps_central": {"id":"torso","material_id":"metal_armored","max_health":100,"detachable":False,"node_patterns":["DZ_torso_*"],"on_break":"shutdown"},
        "bras_gauche": {"id":"left_arm","material_id":material_id,"max_health":32,"detachable":True,"node_patterns":["DZ_l_arm_*"],"on_break":"disable_left_arm"},
        "bras_droit": {"id":"right_arm","material_id":material_id,"max_health":32,"detachable":True,"node_patterns":["DZ_r_arm_*"],"on_break":"disable_right_arm"},
        "jambe_gauche": {"id":"left_leg","material_id":material_id,"max_health":35,"detachable":True,"node_patterns":["DZ_l_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
        "jambe_droite": {"id":"right_leg","material_id":material_id,"max_health":35,"detachable":True,"node_patterns":["DZ_r_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
    }
    result = []
    ids = set()
    for part in req.get("segmentation_parts", []):
        definition = definitions.get(_animation_key(str(part)))
        if definition is not None and definition["id"] not in ids:
            result.append(definition)
            ids.add(definition["id"])
    return result if len(result) >= 3 else defaults


def selected_build_biped(req, mats):
    rig, clips, zones = original_build_biped(req, mats)
    known = {_animation_key(str(name)): str(name) for name in clips}
    selected_clips = [str(name) for name in clips if not requested_keys or _animation_key(str(name)) in requested_keys]
    for custom_name in requested_animations:
        key = _animation_key(custom_name)
        if key in known:
            continue
        display_name = custom_name.strip().replace("_", "-")[:48]
        original_make_action(
            rig,
            display_name,
            [
                (1, {}, (0.0, 0.0, 0.0)),
                (24, {"head": (0.0, 0.18, 0.0)}, (0.0, 0.0, float(req["dimensions_m"]["height"]) * 0.004)),
                (48, {}, (0.0, 0.0, 0.0)),
            ],
        )
        selected_clips.append(display_name)
    return rig, selected_clips, _selected_damage_zones(req, zones)


def export_without_helpers(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for obj in bpy.context.scene.objects:
        helper = obj.name.lower().endswith("-colonly") or obj.name.lower().endswith("_colonly") or obj.name.lower().startswith("preview")
        if obj.type in {"MESH", "ARMATURE"} and not helper:
            obj.select_set(True)
            selected.append(obj)
    if not selected:
        raise RuntimeError("No visible mesh or armature selected for SPECTER GLB export")
    bpy.context.view_layer.objects.active = next((obj for obj in selected if obj.type == "ARMATURE"), selected[0])
    wanted = {
        "filepath": str(path),
        "export_format": "GLB",
        "use_selection": True,
        "export_selected": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": True,
        "export_nla_strips": True,
        "export_force_sampling": True,
        "export_materials": "EXPORT",
    }
    supported = {item.identifier for item in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{key: value for key, value in wanted.items() if key in supported})
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"SPECTER exporter did not create {path}")


module_ns["build_materials"] = reference_build_materials
module_ns["make_action"] = selected_make_action
module_ns["build_biped"] = selected_build_biped
module_ns["export_glb"] = export_without_helpers
module_ns["main"]()

glb_path = output_dir / f"{request_data['slug']}.glb"
sanitize_glb(glb_path, output_dir / f"{request_data['slug']}.sanitize.json")
build_audio(request_path, output_dir)
