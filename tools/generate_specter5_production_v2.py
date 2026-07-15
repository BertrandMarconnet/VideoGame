#!/usr/bin/env python3
"""Reference-aware SPECTER-5 production entry point."""
from __future__ import annotations

from pathlib import Path

import bpy

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


module_ns["build_materials"] = reference_build_materials
module_ns["main"]()
