#!/usr/bin/env python3
"""Final entry point for the category-aware asset generator.

This layer keeps the tested v2 generators while enforcing the requested Godot collision profile,
removing preview/collision proxy geometry from the visible GLB and producing an animation-synchronised
audio profile for direct runtime integration.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from build_asset_audio import build as build_audio
from sanitize_generated_glb import sanitize as sanitize_glb

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


def add_collision_helpers(request):
    mode = request.get("collision_mode", "auto")
    if mode == "none":
        return 0
    return original_add_collision_helpers(request)


def _arg_path(flag: str) -> Path:
    if flag not in sys.argv:
        raise RuntimeError(f"Missing generator argument: {flag}")
    return Path(sys.argv[sys.argv.index(flag) + 1])


namespace["add_collision_helpers"] = add_collision_helpers
namespace["main"]()

request_path = _arg_path("--request")
output_dir = _arg_path("--output-dir")
request = json.loads(request_path.read_text(encoding="utf-8"))
slug = request["slug"]
glb_path = output_dir / f"{slug}.glb"
sanitize_glb(glb_path, output_dir / f"{slug}.sanitize.json")
build_audio(request_path, output_dir)
