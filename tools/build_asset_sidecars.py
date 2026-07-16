#!/usr/bin/env python3
"""Build sidecars for specialised generators such as CRAWLER-7."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from build_asset_audio_v2 import build as build_audio
from sanitize_generated_glb import sanitize as sanitize_glb


def crawler_zones(material_id: str) -> list[dict[str, Any]]:
    zones: list[dict[str, Any]] = []
    for prefix in ("LF", "RF", "LR", "RR"):
        zones.append({
            "id": prefix.lower() + "_leg",
            "material_id": material_id,
            "max_health": 28,
            "detachable": True,
            "node_patterns": [f"DZ_{prefix}_*", f"{prefix}_*"],
            "speed_multiplier": 0.78,
            "on_break": "reduce_speed",
        })
    zones.extend([
        {"id":"sensor","material_id":"glass","max_health":18,"detachable":False,"node_patterns":["*Sensor*","*Lens*"],"on_break":"disable_detection"},
        {"id":"body","material_id":"metal_armored","max_health":110,"detachable":False,"node_patterns":["*Body*","*Spine*","*Torso*"],"on_break":"shutdown"},
    ])
    return zones


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--metrics", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    request = json.loads(args.request.read_text(encoding="utf-8"))
    metrics = json.loads(args.metrics.read_text(encoding="utf-8"))
    slug = request["slug"]
    zones = crawler_zones(request["material_id"]) if request["generator_profile"] == "crawler7" else []
    asset = {
        "schema_version":1,"id":slug,"name":request["asset_name"],"category":request["category"],
        "glb":f"res://assets/generated/{slug}/{slug}.glb","preview":f"res://assets/generated/{slug}/{slug}.png",
        "damage_profile":f"res://assets/generated/{slug}/{slug}.damage.json","integration":request["integration"],
        "dimensions_m":request["dimensions_m"],"rig":request["rig"],"animations":metrics.get("animations",[]),
        "generator_profile":request["generator_profile"],"reference_mode":request.get("reference_mode","none"),
        "texture_mode":request.get("texture_mode","palette_only"),"collision_mode":request.get("collision_mode","capsule"),
        "geometry_template":request.get("geometry_template","articulated_quadruped"),
        "segmentation_parts":request.get("segmentation_parts",["lf_leg","rf_leg","lr_leg","rr_leg","sensor","body"]),"fallback":"procedural"}
    damage = {
        "schema_version":1,"asset_id":slug,"mode":request["destruction_mode"],"default_material":request["material_id"],"zones":zones,
        "tool_rules":{"flashlight_bash":0.45,"plank":0.8,"crowbar":2.2,"thrown_prop":1.0,"specter_charge":4.0},
        "descriptions":{"zones":request.get("damage_zones_description",""),"interactions":request.get("interactions_description","")}}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir/f"{slug}.asset.json").write_text(json.dumps(asset,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (args.output_dir/f"{slug}.damage.json").write_text(json.dumps(damage,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    sanitize_glb(args.output_dir/f"{slug}.glb", args.output_dir/f"{slug}.sanitize.json")
    build_audio(args.request, args.output_dir)


if __name__ == "__main__":
    main()
