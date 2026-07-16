#!/usr/bin/env python3
"""Final entry point for the category-aware asset generator.

This layer keeps the tested v2 generators while enforcing the requested Godot collision profile.
In particular, FPS viewmodels and GUI-only assets can be exported without unintended collision
helpers, while robots, props, doors, machines and environment modules retain simple gameplay-safe
collision proxies.
"""
from __future__ import annotations

from pathlib import Path

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


namespace["add_collision_helpers"] = add_collision_helpers
namespace["main"]()
