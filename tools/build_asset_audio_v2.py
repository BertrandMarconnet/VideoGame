#!/usr/bin/env python3
"""Policy wrapper around :mod:`build_asset_audio` with explicit no-audio handling."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import build_asset_audio as base


def build(request_path: Path, bundle: Path) -> dict[str, Any]:
    request = json.loads(request_path.read_text(encoding="utf-8"))
    if str(request.get("sound_mode", "procedural")).lower() != "none":
        return base.build(request_path, bundle)
    slug = request["slug"]
    asset_path = bundle / f"{slug}.asset.json"
    asset = json.loads(asset_path.read_text(encoding="utf-8"))
    profile = {
        "schema_version": 1,
        "asset_id": slug,
        "mode": "none",
        "spatial": str(request.get("category", "")) != "fps_viewmodel",
        "streams": {},
        "events": [],
        "notes": str(request.get("sound_sync_description", ""))[:2000],
    }
    profile_path = bundle / f"{slug}.audio.json"
    profile_path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    asset["audio_profile"] = f"res://assets/generated/{slug}/{slug}.audio.json"
    asset["sound_mode"] = "none"
    asset_path.write_text(json.dumps(asset, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return profile
