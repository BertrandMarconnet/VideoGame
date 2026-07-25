#!/usr/bin/env python3
"""Part-aware reference-fitted CRAWLER-7 generator.

Version 7 keeps the validated v6 topology, rigid quadruped rig, animations and damage-compatible
part names. It adds a second, conservative silhouette pass that distinguishes the upper body from
the lower leg/foot band. The pass changes body width/length, sensor spread, armour thickness and
foot contact without moving the articulation pivots, so animation stability is preserved.
"""
from __future__ import annotations

import json
import statistics
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix

SOURCE = Path(__file__).with_name("generate_crawler7_production_v6.py")
text = SOURCE.read_text(encoding="utf-8")
marker = "core.main()"
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
namespace: dict[str, Any] = {"__file__": str(SOURCE), "__name__": "crawler7_v6_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)

core = namespace["core"]
previous_build = core.build
previous_report = core.report
PART_PROFILE: dict[str, Any] = {}


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _median_color(values: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    if not values:
        return (0.5, 0.5, 0.5)
    return tuple(float(statistics.median(sample[channel] for sample in values)) for channel in range(3))


def silhouette_bands(path: Path, role: str) -> dict[str, Any]:
    image = bpy.data.images.load(str(path), check_existing=True)
    width, height = int(image.size[0]), int(image.size[1])
    pixels = image.pixels

    def rgba(x: int, y: int) -> tuple[float, float, float, float]:
        offset = (y * width + x) * 4
        return tuple(float(pixels[offset + index]) for index in range(4))  # type: ignore[return-value]

    border: list[tuple[float, float, float]] = []
    border_step = max(1, min(width, height) // 96)
    for x in range(0, width, border_step):
        border.append(rgba(x, 0)[:3])
        border.append(rgba(x, height - 1)[:3])
    for y in range(0, height, border_step):
        border.append(rgba(0, y)[:3])
        border.append(rgba(width - 1, y)[:3])
    background = _median_color(border)
    border_noise = statistics.median(
        abs(color[0] - background[0]) + abs(color[1] - background[1]) + abs(color[2] - background[2])
        for color in border
    ) if border else 0.0
    threshold = clamp(0.085 + border_noise * 3.5, 0.10, 0.24)

    grid_w = min(176, width)
    grid_h = min(176, height)
    step_x = max(1, width // grid_w)
    step_y = max(1, height // grid_h)
    rows: dict[int, list[int]] = {}
    min_x, min_y, max_x, max_y = width, height, 0, 0
    for y in range(0, height, step_y):
        row: list[int] = []
        for x in range(0, width, step_x):
            red, green, blue, alpha = rgba(x, y)
            difference = abs(red - background[0]) + abs(green - background[1]) + abs(blue - background[2])
            if alpha < 0.12 or difference < threshold:
                continue
            # Ignore isolated very bright background reflections but keep small metal highlights.
            if max(red, green, blue) > 0.97 and difference < threshold * 1.8:
                continue
            row.append(x)
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
        if row:
            rows[y] = row

    if max_x <= min_x or max_y <= min_y:
        return {
            "role": role,
            "body_span": 0.64,
            "lower_span": 0.88,
            "upper_span": 0.58,
            "vertical_fill": 0.52,
        }

    object_width = max(1, max_x - min_x)
    object_height = max(1, max_y - min_y)

    def band_span(start: float, finish: float) -> float:
        spans: list[float] = []
        y0 = min_y + object_height * start
        y1 = min_y + object_height * finish
        for y, xs in rows.items():
            if y0 <= y <= y1 and len(xs) >= 2:
                spans.append((max(xs) - min(xs)) / object_width)
        return float(statistics.median(spans)) if spans else 0.0

    occupied_rows = len([y for y in rows if min_y <= y <= max_y])
    sampled_rows = max(1, int(object_height / step_y) + 1)
    return {
        "role": role,
        "body_span": round(band_span(0.30, 0.62), 5),
        "lower_span": round(band_span(0.66, 0.96), 5),
        "upper_span": round(band_span(0.08, 0.30), 5),
        "vertical_fill": round(occupied_rows / sampled_rows, 5),
        "background": [round(channel, 5) for channel in background],
        "threshold": round(threshold, 5),
    }


def analyze_part_profile() -> dict[str, Any]:
    request = namespace["REQUEST"]
    image_paths = [Path(value) for value in request.get("reference_images", []) if Path(value).is_file()]
    profiles: list[dict[str, Any]] = []
    for index, path in enumerate(image_paths[:6]):
        role = namespace["view_role"](path, index, len(image_paths))
        profiles.append(silhouette_bands(path, role))

    front_profiles = [entry for entry in profiles if entry["role"] in {"front", "back"}]
    side_profiles = [entry for entry in profiles if entry["role"] == "right"]
    front = front_profiles or profiles
    side = side_profiles or profiles

    def median(entries: list[dict[str, Any]], key: str, fallback: float) -> float:
        values = [float(entry.get(key, 0.0)) for entry in entries if float(entry.get(key, 0.0)) > 0.0]
        return float(statistics.median(values)) if values else fallback

    front_body = median(front, "body_span", 0.64)
    front_lower = median(front, "lower_span", 0.88)
    front_upper = median(front, "upper_span", 0.58)
    side_body = median(side, "body_span", 0.72)
    side_lower = median(side, "lower_span", 0.82)

    body_width = clamp(front_body / 0.64, 0.88, 1.16)
    body_length = clamp(side_body / 0.72, 0.88, 1.18)
    sensor_spread = clamp(front_upper / 0.58, 0.90, 1.14)
    foot_width = clamp((front_lower / max(front_body, 0.2)) / 1.38, 0.90, 1.16)
    foot_length = clamp((side_lower / max(side_body, 0.2)) / 1.14, 0.90, 1.16)
    armour_thickness = clamp((body_width + body_length) * 0.5, 0.92, 1.10)

    return {
        "engine": "crawler_part_fit_v1",
        "views": profiles,
        "factors": {
            "body_width": round(body_width, 5),
            "body_length": round(body_length, 5),
            "sensor_spread": round(sensor_spread, 5),
            "foot_width": round(foot_width, 5),
            "foot_length": round(foot_length, 5),
            "armour_thickness": round(armour_thickness, 5),
        },
    }


def _scale_world_axes(obj: bpy.types.Object, x: float, y: float, z: float) -> None:
    obj.matrix_world = Matrix.Diagonal((x, y, z, 1.0)) @ obj.matrix_world


def apply_part_fit(profile: dict[str, Any]) -> None:
    factors = profile["factors"]
    body_width = float(factors["body_width"])
    body_length = float(factors["body_length"])
    sensor_spread = float(factors["sensor_spread"])
    foot_width = float(factors["foot_width"])
    foot_length = float(factors["foot_length"])
    armour_thickness = float(factors["armour_thickness"])

    body_keywords = (
        "bodycore", "toparmor", "fronthead", "tophatch", "rearpack", "shoulderarmor",
        "sidemodule", "toprail", "centralspine", "frontforehead", "lowerjaw", "sensorface",
        "rearvent", "sidepod", "bodybolt",
    )
    sensor_keywords = ("sensorbezel", "sensorlens", "sensorcenter", "finalsensor")
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or obj.name.endswith("-colonly"):
            continue
        lower_name = obj.name.lower()
        if any(keyword in lower_name for keyword in body_keywords):
            _scale_world_axes(obj, body_width, body_length, armour_thickness)
        if any(keyword in lower_name for keyword in sensor_keywords):
            world = obj.matrix_world.copy()
            world.translation.x *= sensor_spread
            obj.matrix_world = world
        if "toe" in lower_name or "footpad" in lower_name or "footbeam" in lower_name:
            # Local scaling preserves the animated ankle pivot while improving ground contact.
            obj.scale.x *= foot_width
            obj.scale.y *= foot_length
        elif any(token in lower_name for token in ("uppercap", "lowercap", "hipcover", "kneecover")):
            obj.scale.x *= armour_thickness
            obj.scale.y *= armour_thickness


def fitted_build(quality: str):
    global PART_PROFILE
    rig, clips, collisions = previous_build(quality)
    PART_PROFILE = analyze_part_profile()
    apply_part_fit(PART_PROFILE)
    rig["part_fit_engine"] = PART_PROFILE["engine"]
    return rig, clips, collisions


def fitted_report(path: Path, output: Path, rig, clips, collisions: int) -> None:
    previous_report(path, output, rig, clips, collisions)
    data = json.loads(path.read_text(encoding="utf-8"))
    usage = data.setdefault("reference_usage", {})
    usage["part_fit"] = PART_PROFILE
    data["generator"] = "Blender deterministic hard-surface v7 part-aware reference-fitted"
    data["visual_fidelity"] = "orthographic silhouette + body/leg band fit + reference-derived PS1 palette atlas"
    data["part_fit_engine"] = PART_PROFILE.get("engine", "none")
    data["part_fit_factors"] = PART_PROFILE.get("factors", {})
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    fit_path = path.with_name(path.name.replace(".metrics.json", ".fit.json"))
    fit_path.write_text(json.dumps(PART_PROFILE, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


core.build = fitted_build
core.report = fitted_report
core.main()
