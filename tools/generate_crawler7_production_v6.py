#!/usr/bin/env python3
"""Reference-fitted CRAWLER-7 generator.

The validated v5 hard-surface model remains the topology/rig foundation. This entry point now
reads the submitted image pack and uses it for three production-safe operations:

1. fit the quadruped width, length and low stance from orthographic silhouettes and requested size;
2. extract a compact industrial palette and rebuild the packed PS1 wear atlas;
3. record exactly which references were used so validation can reject an ignored image pack.

This deliberately avoids monocular mesh reconstruction: rigid pivots, named limbs, animation clips
and local damage zones remain deterministic and suitable for Godot/Jolt/Web.
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from collections import Counter
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector

SOURCE = Path(__file__).with_name("generate_crawler7_production_v5.py")
text = SOURCE.read_text(encoding="utf-8")
marker = "core.main()"
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
namespace: dict[str, Any] = {"__file__": str(SOURCE), "__name__": "crawler7_v5_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)

core = namespace["core"]
previous_build = core.build
previous_report = core.report
REQUEST: dict[str, Any] = {}
REFERENCE_PROFILE: dict[str, Any] = {}


def parse_args() -> argparse.Namespace:
    global REQUEST
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    parser.add_argument("--quality", choices=("web", "high"), default="web")
    options = parser.parse_args(values)
    REQUEST = json.loads(options.request.read_text(encoding="utf-8"))
    return options


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def view_role(path: Path, index: int, count: int) -> str:
    name = path.stem.lower().replace("-", "_").replace(" ", "_")
    rules = {
        "front": ("front", "avant", "face"),
        "right": ("right", "droit", "side", "profile", "profil"),
        "back": ("back", "rear", "arriere", "arrière", "dos"),
        "three_quarter": ("three_quarter", "threequarter", "3_4", "34", "quarter", "trois_quart"),
        "top": ("top", "dessus", "overhead"),
    }
    for role, keywords in rules.items():
        if any(keyword in name for keyword in keywords):
            return role
    if count >= 4:
        return ("front", "right", "back", "three_quarter")[min(index, 3)]
    return "reference_%d" % (index + 1)


def analyze_image(path: Path, role: str) -> dict[str, Any]:
    image = bpy.data.images.load(str(path), check_existing=True)
    width, height = int(image.size[0]), int(image.size[1])
    if width < 4 or height < 4:
        raise ValueError(f"Reference image is too small: {path}")
    pixels = image.pixels

    def rgb_at(x: int, y: int) -> tuple[float, float, float, float]:
        offset = (y * width + x) * 4
        return tuple(float(pixels[offset + channel]) for channel in range(4))  # type: ignore[return-value]

    corners = [rgb_at(0, 0), rgb_at(width - 1, 0), rgb_at(0, height - 1), rgb_at(width - 1, height - 1)]
    background = tuple(sum(c[channel] for c in corners) / 4.0 for channel in range(3))
    step_x = max(1, width // 112)
    step_y = max(1, height // 112)
    min_x, min_y, max_x, max_y = width, height, 0, 0
    foreground: list[tuple[float, float, float]] = []

    for y in range(0, height, step_y):
        for x in range(0, width, step_x):
            red, green, blue, alpha = rgb_at(x, y)
            difference = abs(red - background[0]) + abs(green - background[1]) + abs(blue - background[2])
            if alpha < 0.12 or difference < 0.16:
                continue
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
            brightness = max(red, green, blue)
            saturation = brightness - min(red, green, blue)
            # Keep body/armour samples; strongly emissive red sensors are handled separately.
            if 0.025 < brightness < 0.82 and not (red > green * 1.65 and red > blue * 1.65 and saturation > 0.18):
                foreground.append((red, green, blue))

    if max_x <= min_x or max_y <= min_y:
        min_x, min_y, max_x, max_y = 0, 0, width - 1, height - 1
    box_width = max(1, max_x - min_x + 1)
    box_height = max(1, max_y - min_y + 1)
    return {
        "path": str(path),
        "role": role,
        "source_size": [width, height],
        "bbox": [min_x, min_y, max_x, max_y],
        "silhouette_ratio": round(box_width / box_height, 5),
        "foreground_samples": foreground,
    }


def quantized_palette(samples: list[tuple[float, float, float]], limit: int = 8) -> list[tuple[float, float, float]]:
    if not samples:
        return []
    counts: Counter[tuple[int, int, int]] = Counter()
    for red, green, blue in samples:
        counts[(int(clamp(red, 0.0, 1.0) * 15), int(clamp(green, 0.0, 1.0) * 15), int(clamp(blue, 0.0, 1.0) * 15))] += 1
    return [(r / 15.0, g / 15.0, b / 15.0) for (r, g, b), _count in counts.most_common(limit)]


def choose_material_colors(palette: list[tuple[float, float, float]]) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    if not palette:
        return (0.20, 0.125, 0.065), (0.055, 0.045, 0.038)
    ordered = sorted(palette, key=lambda color: sum(color))
    dark_source = ordered[max(0, len(ordered) // 4 - 1)]
    warm = [color for color in palette if color[0] >= color[1] * 1.03 and color[1] >= color[2] * 0.78]
    armor_source = max(warm or palette, key=lambda color: sum(color))
    dark = tuple(clamp(channel * 0.48, 0.018, 0.16) for channel in dark_source)
    armor = (
        clamp(armor_source[0] * 0.78, 0.10, 0.34),
        clamp(armor_source[1] * 0.72, 0.065, 0.25),
        clamp(armor_source[2] * 0.66, 0.035, 0.18),
    )
    return armor, dark


def rebuild_reference_atlas(armor: tuple[float, float, float], dark: tuple[float, float, float]) -> None:
    image = bpy.data.images.get("CRAWLER7_WearAtlas")
    if image is None:
        return
    width, height = int(image.size[0]), int(image.size[1])
    values: list[float] = []
    for y in range(height):
        for x in range(width):
            selector = ((x // 8) + (y // 8) * 3 + (x * 17 + y * 29) // 41) % 7
            base = armor if selector in {0, 1, 3, 5} else dark
            wear = 0.78 + ((x * 13 + y * 31) % 17) * 0.018
            scratch = 0.12 if ((x * 23 + y * 37) % 193) < 2 else 0.0
            values.extend((
                clamp(base[0] * wear + scratch, 0.01, 0.72),
                clamp(base[1] * wear + scratch * 0.78, 0.01, 0.62),
                clamp(base[2] * wear + scratch * 0.55, 0.01, 0.52),
                1.0,
            ))
    try:
        image.pixels.foreach_set(values)
    except Exception:
        image.pixels = values
    image.update()
    image.pack()


def analyze_references() -> dict[str, Any]:
    image_paths = [Path(value) for value in REQUEST.get("reference_images", []) if Path(value).is_file()]
    analyses: list[dict[str, Any]] = []
    all_samples: list[tuple[float, float, float]] = []
    for index, path in enumerate(image_paths[:6]):
        try:
            result = analyze_image(path, view_role(path, index, len(image_paths)))
            all_samples.extend(result.pop("foreground_samples"))
            analyses.append(result)
        except Exception as exc:
            print(f"Reference analysis skipped for {path}: {exc}")
    if not analyses:
        raise RuntimeError("CRAWLER-7 reference fitting could not read any submitted image")

    by_role = {entry["role"]: entry for entry in analyses}
    observed = [float(entry["silhouette_ratio"]) for entry in analyses]
    front_ratio = statistics.mean([
        float(by_role[role]["silhouette_ratio"])
        for role in ("front", "back") if role in by_role
    ]) if any(role in by_role for role in ("front", "back")) else statistics.median(observed)
    side_ratio = float(by_role["right"]["silhouette_ratio"]) if "right" in by_role else max(observed)

    dimensions = REQUEST.get("dimensions_m", {})
    width = max(float(dimensions.get("width", 1.45)), 0.1)
    height = max(float(dimensions.get("height", 0.72)), 0.1)
    depth = max(float(dimensions.get("depth", 1.75)), 0.1)
    requested_front = width / height
    requested_side = depth / height

    # Canonical detailed v5 silhouette ratios. Blend image evidence with metric dimensions,
    # then keep deformations conservative so the validated rigid rig remains stable.
    target_front = requested_front * 0.68 + front_ratio * 0.32
    target_side = requested_side * 0.72 + side_ratio * 0.28
    scale_x = clamp(target_front / 1.94, 0.78, 1.38)
    scale_y = clamp(target_side / 1.66, 0.82, 1.55)
    scale_z = clamp(1.0 - max(0.0, target_side - 2.0) * 0.045, 0.88, 1.05)

    palette = quantized_palette(all_samples)
    armor, dark = choose_material_colors(palette)
    return {
        "engine": "crawler_reference_fit_v2",
        "images_used": len(analyses),
        "views": analyses,
        "requested_ratios": {"front": round(requested_front, 5), "side": round(requested_side, 5)},
        "observed_ratios": {"front": round(front_ratio, 5), "side": round(side_ratio, 5)},
        "axis_scale": [round(scale_x, 5), round(scale_y, 5), round(scale_z, 5)],
        "palette": [[round(channel, 5) for channel in color] for color in palette],
        "armor_color": [round(channel, 5) for channel in armor],
        "dark_color": [round(channel, 5) for channel in dark],
    }


def fitted_build(quality: str):
    global REFERENCE_PROFILE
    rig, clips, collisions = previous_build(quality)
    REFERENCE_PROFILE = analyze_references()
    scale_x, scale_y, scale_z = (float(value) for value in REFERENCE_PROFILE["axis_scale"])
    rig.scale = Vector((scale_x, scale_y, scale_z))
    rig["reference_fit_engine"] = REFERENCE_PROFILE["engine"]
    rig["reference_images_used"] = int(REFERENCE_PROFILE["images_used"])

    armor = tuple(float(value) for value in REFERENCE_PROFILE["armor_color"])
    dark = tuple(float(value) for value in REFERENCE_PROFILE["dark_color"])
    namespace["tune_material"]("CRAWLER7_BrownArmor", (*armor, 1.0), 0.72)
    namespace["tune_material"]("CRAWLER7_DarkMetal", (*dark, 1.0), 0.76)
    black = tuple(clamp(channel * 0.34, 0.008, 0.055) for channel in dark)
    namespace["tune_material"]("CRAWLER7_Black", (*black, 1.0), 0.66)
    rebuild_reference_atlas(armor, dark)
    return rig, clips, collisions


def fitted_report(path: Path, output: Path, rig, clips, collisions: int) -> None:
    previous_report(path, output, rig, clips, collisions)
    data = json.loads(path.read_text(encoding="utf-8"))
    data["generator"] = "Blender deterministic hard-surface v6 reference-fitted"
    data["reference_images_used"] = int(REFERENCE_PROFILE.get("images_used", 0))
    data["reference_usage"] = REFERENCE_PROFILE
    data["visual_fidelity"] = "orthographic silhouette fit + reference-derived PS1 palette atlas"
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    reference_path = path.with_name(path.name.replace(".metrics.json", ".reference.json"))
    reference_path.write_text(json.dumps(REFERENCE_PROFILE, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


core.args = parse_args
core.build = fitted_build
core.report = fitted_report
core.main()
