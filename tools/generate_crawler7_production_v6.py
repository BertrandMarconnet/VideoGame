#!/usr/bin/env python3
"""Reference-fitted CRAWLER-7 generator with deterministic four-view fallback."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

SOURCE = Path(__file__).with_name("generate_crawler7_production_v5.py")
text = SOURCE.read_text(encoding="utf-8")
marker = "core.main()"
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
namespace: dict[str, Any] = {"__file__": str(SOURCE), "__name__": "crawler7_v5_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)

FIT_SOURCE = Path(__file__).with_name("crawler_reference_fit.py")
spec = importlib.util.spec_from_file_location("crawler_reference_fit", FIT_SOURCE)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load {FIT_SOURCE}")
fit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fit_module)

# Compatibility export used by the v7 part-aware fitting layer.
view_role = fit_module.view_role

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


def fitted_build(quality: str):
    global REFERENCE_PROFILE
    rig, clips, collisions = previous_build(quality)
    REFERENCE_PROFILE = fit_module.analyze_reference_pack(REQUEST)
    if bool(REFERENCE_PROFILE.get("enabled", False)):
        fit_module.apply_reference_fit(rig, REFERENCE_PROFILE, namespace["tune_material"])
        print("CRAWLER-7 four-view reference fit enabled")
    else:
        print("CRAWLER-7 reference fit fallback: " + str(REFERENCE_PROFILE.get("fallback_reason", "incomplete pack")))
    rig["reference_fit_engine"] = REFERENCE_PROFILE.get("engine", "")
    rig["reference_fit_profile"] = REFERENCE_PROFILE.get("fit_profile", "")
    rig["reference_fit_enabled"] = bool(REFERENCE_PROFILE.get("enabled", False))
    rig["reference_images_used"] = int(REFERENCE_PROFILE.get("images_used", 0))
    return rig, clips, collisions


def fitted_report(path: Path, output: Path, rig, clips, collisions: int) -> None:
    previous_report(path, output, rig, clips, collisions)
    data = json.loads(path.read_text(encoding="utf-8"))
    data["generator"] = "Blender deterministic hard-surface v6 four-view reference-fitted"
    data["reference_images_used"] = int(REFERENCE_PROFILE.get("images_used", 0))
    data["reference_usage"] = REFERENCE_PROFILE
    if bool(REFERENCE_PROFILE.get("enabled", False)):
        data["visual_fidelity"] = "orthographic four-view silhouette fit + component emphasis + reference-derived PS1 palette atlas"
    else:
        data["visual_fidelity"] = "validated deterministic crawler fallback; four orthographic views required for geometric fitting"
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    reference_path = path.with_name(path.name.replace(".metrics.json", ".reference.json"))
    reference_path.write_text(json.dumps(REFERENCE_PROFILE, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


core.args = parse_args
core.build = fitted_build
core.report = fitted_report
core.main()
