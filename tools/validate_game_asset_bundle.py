#!/usr/bin/env python3
"""Validate a generated asset bundle before it can be committed or exposed to Godot."""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

VALID_CATEGORIES = {"robot_biped", "robot_quadruped", "prop", "wall", "door", "environment", "gui_panel"}
VALID_MODES = {"none", "localized", "detachable", "segmented_wall", "material_advanced"}


def read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def validate_glb(path: Path, max_mb: int) -> dict[str, int]:
    payload = path.read_bytes()
    if len(payload) < 20 or payload[:4] != b"glTF":
        raise ValueError(f"{path} is not a binary glTF file")
    version, total_length = struct.unpack_from("<II", payload, 4)
    if version != 2 or total_length != len(payload):
        raise ValueError(f"{path} has an invalid glTF header")
    if len(payload) > max_mb * 1024 * 1024:
        raise ValueError(f"{path} exceeds {max_mb} MB")
    return {"bytes": len(payload), "version": version}


def validate_asset(asset: dict[str, Any], slug: str) -> None:
    required = {"schema_version", "id", "name", "category", "glb", "damage_profile", "dimensions_m", "rig", "animations"}
    missing = sorted(required - asset.keys())
    if missing:
        raise ValueError(f"asset manifest missing: {', '.join(missing)}")
    if asset["schema_version"] != 1 or asset["id"] != slug:
        raise ValueError("asset schema version or id mismatch")
    if asset["category"] not in VALID_CATEGORIES:
        raise ValueError("unsupported asset category")
    dims = asset["dimensions_m"]
    if not isinstance(dims, dict) or any(float(dims.get(axis, 0)) <= 0 for axis in ("width", "height", "depth")):
        raise ValueError("invalid metric dimensions")
    if not isinstance(asset["animations"], list):
        raise ValueError("animations must be an array")


def validate_damage(damage: dict[str, Any], slug: str, category: str) -> None:
    if damage.get("schema_version") != 1 or damage.get("asset_id") != slug:
        raise ValueError("damage schema version or asset id mismatch")
    if damage.get("mode") not in VALID_MODES:
        raise ValueError("unsupported destruction mode")
    zones = damage.get("zones")
    if not isinstance(zones, list):
        raise ValueError("damage zones must be an array")
    ids: set[str] = set()
    for zone in zones:
        if not isinstance(zone, dict):
            raise ValueError("each damage zone must be an object")
        zone_id = str(zone.get("id", ""))
        if not zone_id or zone_id in ids:
            raise ValueError("damage zone ids must be unique and non-empty")
        ids.add(zone_id)
        if float(zone.get("max_health", 0)) <= 0:
            raise ValueError(f"zone {zone_id} has invalid health")
        if not isinstance(zone.get("node_patterns"), list):
            raise ValueError(f"zone {zone_id} has no node patterns")
    if category.startswith("robot_") and damage.get("mode") != "none" and len(zones) < 3:
        raise ValueError("a destructible robot requires at least three localized zones")
    if category == "wall" and damage.get("mode") in {"segmented_wall", "material_advanced"} and len(zones) < 2:
        raise ValueError("a segmented wall requires multiple cells")
    rules = damage.get("tool_rules")
    if not isinstance(rules, dict) or "flashlight_bash" not in rules or "crowbar" not in rules:
        raise ValueError("tool rules must include flashlight_bash and crowbar")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--max-mb", type=int, default=24)
    args = parser.parse_args()

    base = args.bundle
    paths = {
        "glb": base / f"{args.slug}.glb",
        "preview": base / f"{args.slug}.png",
        "asset": base / f"{args.slug}.asset.json",
        "damage": base / f"{args.slug}.damage.json",
        "metrics": base / f"{args.slug}.metrics.json",
    }
    for name, path in paths.items():
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"missing generated {name}: {path}")

    glb_info = validate_glb(paths["glb"], args.max_mb)
    asset = read_json(paths["asset"])
    damage = read_json(paths["damage"])
    metrics = read_json(paths["metrics"])
    validate_asset(asset, args.slug)
    validate_damage(damage, args.slug, asset["category"])
    triangles = int(metrics.get("triangles", 0))
    if triangles <= 0 or triangles > 60000:
        raise ValueError(f"invalid triangle count: {triangles}")
    if asset["category"].startswith("robot_"):
        if int(metrics.get("bones", 0)) < 10:
            raise ValueError("robot bundle does not contain a usable rig")
        if len(metrics.get("animations", [])) < 3:
            raise ValueError("robot bundle does not contain enough animations")

    report = {
        "valid": True,
        "slug": args.slug,
        "category": asset["category"],
        "triangles": triangles,
        "bones": int(metrics.get("bones", 0)),
        "animations": metrics.get("animations", []),
        "damage_zones": len(damage.get("zones", [])),
        "glb": glb_info,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
