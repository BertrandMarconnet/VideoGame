#!/usr/bin/env python3
"""Merge one validated asset manifest into the runtime catalog deterministically."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ALIASES = {
    "crawler_07": "crawler_7",
    "crawler7": "crawler_7",
    "specter_05": "specter_5",
    "specter5": "specter_5",
}
TEST_MARKERS = (
    "pipeline_validation",
    "publication_validation",
    "final_pipeline_check",
    "smoke",
    "test_asset",
)


def canonical_id(value: str) -> str:
    return ALIASES.get(value, value)


def is_validation_asset(entry: dict[str, Any]) -> bool:
    combined = (str(entry.get("id", "")) + " " + str(entry.get("name", ""))).lower()
    return any(marker in combined for marker in TEST_MARKERS)


def quality_score(entry: dict[str, Any]) -> tuple[int, int, int, int]:
    return (
        1 if entry.get("integration") == "replace_procedural" else 0,
        1 if entry.get("reference_usage") else 0,
        1 if entry.get("audio_profile") else 0,
        len(entry.get("animations", [])) if isinstance(entry.get("animations"), list) else 0,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--asset", type=Path, required=True)
    args = parser.parse_args()

    asset = json.loads(args.asset.read_text(encoding="utf-8"))
    if asset.get("schema_version") != 1 or not asset.get("id"):
        raise ValueError("invalid asset manifest")
    asset["id"] = canonical_id(str(asset["id"]))

    existing: list[dict[str, Any]] = []
    if args.catalog.exists():
        loaded = json.loads(args.catalog.read_text(encoding="utf-8"))
        if isinstance(loaded, dict) and isinstance(loaded.get("assets"), list):
            existing = [entry for entry in loaded["assets"] if isinstance(entry, dict)]

    by_id: dict[str, dict[str, Any]] = {}
    for entry in existing:
        if is_validation_asset(entry):
            continue
        normalized = dict(entry)
        normalized["id"] = canonical_id(str(normalized.get("id", "")))
        entry_id = str(normalized.get("id", ""))
        if not entry_id or entry_id == asset["id"]:
            continue
        previous = by_id.get(entry_id)
        if previous is None or quality_score(normalized) > quality_score(previous):
            by_id[entry_id] = normalized

    by_id[asset["id"]] = asset
    assets = [by_id[key] for key in sorted(by_id)]
    catalog = {"schema_version": 1, "assets": assets}
    args.catalog.parent.mkdir(parents=True, exist_ok=True)
    args.catalog.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"catalog contains {len(assets)} production assets")


if __name__ == "__main__":
    main()
