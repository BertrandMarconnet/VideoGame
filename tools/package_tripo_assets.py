#!/usr/bin/env python3
"""Copy validated Tripo outputs into a Godot-ready integration overlay."""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any


class PackageError(RuntimeError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise PackageError(f"Expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--generated-root", required=True, type=Path)
    parser.add_argument("--overlay-root", required=True, type=Path)
    args = parser.parse_args()

    manifest = load_json(args.manifest)
    asset_id = str(manifest.get("asset_id", "")).strip()
    integration_path = str(manifest.get("integration_path", "")).strip()
    if not asset_id:
        raise PackageError("asset_id is required")
    if not integration_path.startswith("assets/production/") or not integration_path.endswith(".glb"):
        raise PackageError("integration_path must be a GLB below assets/production/")

    asset_dir = args.generated_root / asset_id
    candidates = sorted(asset_dir.glob("*.glb"))
    if not candidates:
        raise PackageError(f"No GLB found for {asset_id} below {asset_dir}")
    source = candidates[0]
    destination = args.overlay_root / integration_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

    provenance_source = asset_dir / "generation.json"
    if provenance_source.is_file():
        provenance_destination = destination.with_suffix(".generation.json")
        shutil.copy2(provenance_source, provenance_destination)

    report = {
        "asset_id": asset_id,
        "source": str(source),
        "destination": str(destination),
        "bytes": destination.stat().st_size,
    }
    report_path = destination.with_suffix(".package.json")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (PackageError, json.JSONDecodeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
