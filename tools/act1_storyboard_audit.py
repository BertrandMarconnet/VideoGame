#!/usr/bin/env python3
"""Audit the Act I startup against the validated storyboard constraints."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REQUIRED_MARKERS = {
    "external_spawn": "player.global_position = Vector3(0.0, 1.15, 35.0)",
    "service_access": "SERVICE ACCESS",
    "sealed_central_gate": "CentralGateSealedV18",
    "airlock_builder": "func _build_act1_airlock_v18",
    "lateral_vestibule": "VestibuleLateralV18",
    "outer_door": "ServiceDoorOuterV18",
    "inner_door": "BlastDoorInnerV18",
    "interface_pass": "func _apply_act1_interface_v18",
    "authored_asset_fallback": "assets/production/act1/service_access.glb",
    "mobile_look": "func _update_mobile_look_v17",
}
FORBIDDEN_COMBINATIONS = (
    ("player.global_position = Vector3(0.0, 1.15, 35.0)", "objective_label.text = \"OBJECTIF : entrer directement dans S-01"),
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()

    source = args.source.read_text(encoding="utf-8")
    checks = {name: marker in source for name, marker in REQUIRED_MARKERS.items()}
    forbidden = []
    for left, right in FORBIDDEN_COMBINATIONS:
        if left in source and right in source:
            forbidden.append(f"Forbidden combination: {left!r} + {right!r}")
    report = {
        "checks": checks,
        "forbidden": forbidden,
        "passed": all(checks.values()) and not forbidden,
        "principles": [
            "The player starts outside ToyGuard in the rain.",
            "The central opening is sealed and cannot lead directly into S-01.",
            "The path is exterior -> service door -> airlock -> blast door -> lateral vestibule -> bunker.",
            "The lateral arrival does not face the central supervision screen.",
            "Authored GLB assets have procedural Web-safe fallbacks.",
        ],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if not report["passed"]:
        missing = [name for name, passed in checks.items() if not passed]
        print(f"ERROR: missing storyboard markers: {', '.join(missing)}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
