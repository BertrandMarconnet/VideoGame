#!/usr/bin/env python3
"""Compatibility entry point for the CRAWLER-7 generator on Blender 4.x runners."""
from __future__ import annotations

import importlib.util
from pathlib import Path

import bpy


MODULE_PATH = Path(__file__).with_name("generate_crawler7_production_v2.py")
spec = importlib.util.spec_from_file_location("crawler7_v2", MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load generator module: {MODULE_PATH}")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


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
        scene.world = bpy.data.worlds.new("CRAWLER7_World")
    scene.world.color = (0.055, 0.06, 0.065)
    scene.frame_start = 1
    scene.frame_end = 48


module.reset = compatible_reset
module.main()
