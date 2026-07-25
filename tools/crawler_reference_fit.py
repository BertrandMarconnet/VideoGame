#!/usr/bin/env python3
"""Reference analysis and conservative visual fitting for CRAWLER-7.

The fitter only enables geometry deformation when a complete orthographic pack is
available (front, right, back and three-quarter). Incomplete packs deliberately
fall back to the validated deterministic crawler generator.
"""
from __future__ import annotations

import statistics
from collections import Counter
from pathlib import Path
from typing import Any, Callable

import bpy
from mathutils import Vector

REQUIRED_ROLES = ("front", "right", "back", "three_quarter")


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
        return REQUIRED_ROLES[min(index, 3)]
    return f"reference_{index + 1}"


def analyze_image(path: Path, role: str) -> dict[str, Any]:
    image = bpy.data.images.load(str(path), check_existing=True)
    width, height = int(image.size[0]), int(image.size[1])
    if width < 4 or height < 4:
        raise ValueError(f"Reference image is too small: {path}")
    pixels = image.pixels

    def rgba_at(x: int, y: int) -> tuple[float, float, float, float]:
        offset = (y * width + x) * 4
        return tuple(float(pixels[offset + channel]) for channel in range(4))  # type: ignore[return-value]

    corners = [rgba_at(0, 0), rgba_at(width - 1, 0), rgba_at(0, height - 1), rgba_at(width - 1, height - 1)]
    background = tuple(sum(c[channel] for c in corners) / 4.0 for channel in range(3))
    step_x = max(1, width // 112)
    step_y = max(1, height // 112)
    min_x, min_y, max_x, max_y = width, height, 0, 0
    foreground: list[tuple[float, float, float]] = []

    for y in range(0, height, step_y):
        for x in range(0, width, step_x):
            red, green, blue, alpha = rgba_at(x, y)
            difference = abs(red - background[0]) + abs(green - background[1]) + abs(blue - background[2])
            if alpha < 0.12 or difference < 0.16:
                continue
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
            brightness = max(red, green, blue)
            saturation = brightness - min(red, green, blue)
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
    return [(red / 15.0, green / 15.0, blue / 15.0) for (red, green, blue), _count in counts.most_common(limit)]


def choose_material_colors(palette: list[tuple[float, float, float]]) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    if not palette:
        return (0.20, 0.125, 0.065), (0.055, 0.045, 0.038)
    ordered = sorted(palette, key=sum)
    dark_source = ordered[max(0, len(ordered) // 4 - 1)]
    warm = [color for color in palette if color[0] >= color[1] * 1.03 and color[1] >= color[2] * 0.78]
    armor_source = max(warm or palette, key=sum)
    dark = tuple(clamp(channel * 0.48, 0.018, 0.16) for channel in dark_source)
    armor = (
        clamp(armor_source[0] * 0.78, 0.10, 0.34),
        clamp(armor_source[1] * 0.72, 0.065, 0.25),
        clamp(armor_source[2] * 0.66, 0.035, 0.18),
    )
    return armor, dark


def _fit_parameters(front_ratio: float, side_ratio: float, requested_front: float, requested_side: float) -> dict[str, float]:
    front_delta = front_ratio / max(requested_front, 0.1)
    side_delta = side_ratio / max(requested_side, 0.1)
    return {
        "body_length_factor": round(clamp(side_delta ** 0.34, 0.92, 1.12), 5),
        "body_height_factor": round(clamp((1.0 / max(side_delta, 0.1)) ** 0.16, 0.95, 1.06), 5),
        "leg_length_factor": round(clamp(1.0 + (front_ratio - 2.0) * 0.025, 0.96, 1.06), 5),
        "stance_width_factor": round(clamp(front_delta ** 0.30, 0.92, 1.10), 5),
        "sensor_block_scale": round(clamp(1.04 + (front_ratio - 2.0) * 0.025, 1.02, 1.10), 5),
        "rear_mass_scale": round(clamp(1.0 + (side_ratio - 2.35) * 0.03, 0.98, 1.06), 5),
    }


def analyze_reference_pack(request: dict[str, Any]) -> dict[str, Any]:
    image_paths = [Path(value) for value in request.get("reference_images", []) if Path(value).is_file()]
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
    views_used = [role for role in REQUIRED_ROLES if role in by_role]
    enabled = len(views_used) == len(REQUIRED_ROLES)
    observed = [float(entry["silhouette_ratio"]) for entry in analyses]
    front_ratio = statistics.mean([
        float(by_role[role]["silhouette_ratio"])
        for role in ("front", "back") if role in by_role
    ]) if any(role in by_role for role in ("front", "back")) else statistics.median(observed)
    side_ratio = float(by_role["right"]["silhouette_ratio"]) if "right" in by_role else max(observed)

    dimensions = request.get("dimensions_m", {})
    width = max(float(dimensions.get("width", 1.45)), 0.1)
    height = max(float(dimensions.get("height", 0.72)), 0.1)
    depth = max(float(dimensions.get("depth", 1.75)), 0.1)
    requested_front = width / height
    requested_side = depth / height
    fit = _fit_parameters(front_ratio, side_ratio, requested_front, requested_side)

    target_front = requested_front * 0.68 + front_ratio * 0.32
    target_side = requested_side * 0.72 + side_ratio * 0.28
    base_x = clamp(target_front / 1.94, 0.78, 1.38)
    base_y = clamp(target_side / 1.66, 0.82, 1.55)
    base_z = clamp(1.0 - max(0.0, target_side - 2.0) * 0.045, 0.88, 1.05)
    axis_scale = [
        clamp(base_x * fit["stance_width_factor"], 0.78, 1.42),
        clamp(base_y * fit["body_length_factor"], 0.82, 1.58),
        clamp(base_z * fit["body_height_factor"] * fit["leg_length_factor"], 0.86, 1.08),
    ] if enabled else [1.0, 1.0, 1.0]

    palette = quantized_palette(all_samples)
    armor, dark = choose_material_colors(palette)
    return {
        "engine": "crawler_reference_fit_v2",
        "fit_profile": "crawler_reference_fit_v3",
        "enabled": enabled,
        "images_used": len(analyses),
        "views_used": views_used,
        "required_views": list(REQUIRED_ROLES),
        "fallback_reason": "" if enabled else "complete front/right/back/three_quarter pack required",
        "views": analyses,
        "requested_ratios": {"front": round(requested_front, 5), "side": round(requested_side, 5)},
        "observed_ratios": {"front": round(front_ratio, 5), "side": round(side_ratio, 5)},
        "fit": fit,
        "axis_scale": [round(value, 5) for value in axis_scale],
        "palette": [[round(channel, 5) for channel in color] for color in palette],
        "armor_color": [round(channel, 5) for channel in armor],
        "dark_color": [round(channel, 5) for channel in dark],
    }


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


def _scale_named_details(profile: dict[str, Any]) -> None:
    fit = profile.get("fit", {})
    sensor_scale = float(fit.get("sensor_block_scale", 1.0))
    rear_scale = float(fit.get("rear_mass_scale", 1.0))
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        name = obj.name.lower()
        if any(token in name for token in ("sensor", "forehead", "lowerjaw")):
            obj.scale.x *= sensor_scale
            obj.scale.z *= sensor_scale
        if "rearvent" in name or "rear_pack" in name:
            obj.scale.y *= rear_scale
            obj.scale.z *= clamp(rear_scale, 0.99, 1.04)


def apply_reference_fit(rig: bpy.types.Object, profile: dict[str, Any], tune_material: Callable[..., None]) -> None:
    if not bool(profile.get("enabled", False)):
        return
    scale_x, scale_y, scale_z = (float(value) for value in profile["axis_scale"])
    rig.scale = Vector((scale_x, scale_y, scale_z))
    armor = tuple(float(value) for value in profile["armor_color"])
    dark = tuple(float(value) for value in profile["dark_color"])
    tune_material("CRAWLER7_BrownArmor", (*armor, 1.0), 0.72)
    tune_material("CRAWLER7_DarkMetal", (*dark, 1.0), 0.76)
    black = tuple(clamp(channel * 0.34, 0.008, 0.055) for channel in dark)
    tune_material("CRAWLER7_Black", (*black, 1.0), 0.66)
    rebuild_reference_atlas(armor, dark)
    _scale_named_details(profile)
