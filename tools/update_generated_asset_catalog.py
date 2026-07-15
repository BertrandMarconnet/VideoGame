#!/usr/bin/env python3
"""Merge one validated asset manifest into the runtime catalog deterministically."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--asset", type=Path, required=True)
    args = parser.parse_args()

    asset = json.loads(args.asset.read_text(encoding="utf-8"))
    if asset.get("schema_version") != 1 or not asset.get("id"):
        raise ValueError("invalid asset manifest")
    catalog = {"schema_version": 1, "assets": []}
    if args.catalog.exists():
        loaded = json.loads(args.catalog.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            catalog = loaded
    existing = catalog.get("assets")
    if not isinstance(existing, list):
        existing = []
    filtered = [entry for entry in existing if isinstance(entry, dict) and entry.get("id") != asset["id"]]
    filtered.append(asset)
    filtered.sort(key=lambda entry: str(entry.get("id", "")))
    catalog = {"schema_version": 1, "assets": filtered}
    args.catalog.parent.mkdir(parents=True, exist_ok=True)
    args.catalog.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"catalog contains {len(filtered)} assets")


if __name__ == "__main__":
    main()
