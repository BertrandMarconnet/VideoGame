#!/usr/bin/env python3
"""Final entry point for the category-aware asset generator.

This layer keeps the deterministic v2 geometry while enforcing the selected animation set,
removing collision/preview proxy geometry and producing synchronized audio metadata.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

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
request = json.loads(request_path.read_text(encoding="utf-8"))
requested_animations = [str(value) for value in request.get("animations", []) if str(value).strip()]
requested_keys = {_animation_key(value) for value in requested_animations}

SOURCE = Path(__file__).with_name("generate_game_asset_v2.py")
text = SOURCE.read_text(encoding="utf-8")
marker = 'namespace["main"]()'
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
module: dict[str, object] = {"__file__": str(SOURCE), "__name__": "generic_asset_v2_module"}
exec(compile(text, str(SOURCE), "exec"), module)

namespace = module["namespace"]
original_add_collision_helpers = namespace["add_collision_helpers"]
original_make_action = namespace["make_action"]
original_build_biped = namespace["build_biped"]
original_build_quadruped = namespace["build_quadruped"]
original_build_static = namespace["build_static"]


def add_collision_helpers(asset_request):
    if asset_request.get("collision_mode", "auto") == "none":
        return 0
    return original_add_collision_helpers(asset_request)


def selected_make_action(rig, name, frames):
    if requested_keys and _animation_key(str(name)) not in requested_keys:
        return None
    return original_make_action(rig, name, frames)


def _filtered_builder(builder):
    def build(asset_request, materials):
        rig, clips, zones = builder(asset_request, materials)
        known = {_animation_key(str(name)): str(name) for name in clips}
        selected = [str(name) for name in clips if not requested_keys or _animation_key(str(name)) in requested_keys]
        if rig is not None:
            height = float(asset_request.get("dimensions_m", {}).get("height", 1.0))
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
                        (24, {}, (0.0, 0.0, height * 0.006)),
                        (48, {}, (0.0, 0.0, 0.0)),
                    ],
                )
                selected.append(display_name)
        return rig, selected, zones
    return build


namespace["add_collision_helpers"] = add_collision_helpers
namespace["make_action"] = selected_make_action
module["make_action"] = selected_make_action
namespace["build_biped"] = _filtered_builder(original_build_biped)
namespace["build_quadruped"] = _filtered_builder(original_build_quadruped)
namespace["build_static"] = _filtered_builder(original_build_static)
namespace["main"]()

slug = request["slug"]
glb_path = output_dir / f"{slug}.glb"
if not glb_path.is_file() or glb_path.stat().st_size == 0:
    raise RuntimeError(f"Generic exporter did not create {glb_path}")
sanitize_glb(glb_path, output_dir / f"{slug}.sanitize.json")
build_audio(request_path, output_dir)
