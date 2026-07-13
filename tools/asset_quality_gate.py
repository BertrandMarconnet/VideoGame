#!/usr/bin/env python3
"""Validate concept images and generated GLB files against Web/mobile budgets."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from PIL import Image


class QualityError(RuntimeError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise QualityError(f"Expected JSON object: {path}")
    return value


def validate_image(path: Path, minimum: int = 512, maximum_mb: float = 8.0) -> dict[str, Any]:
    if not path.is_file():
        raise QualityError(f"Missing concept image: {path}")
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > maximum_mb:
        raise QualityError(f"Concept image {path} is {size_mb:.2f} MB; maximum is {maximum_mb:.2f} MB")
    with Image.open(path) as image:
        width, height = image.size
        image.verify()
    if width < minimum or height < minimum:
        raise QualityError(f"Concept image {path} must be at least {minimum}x{minimum}; got {width}x{height}")
    aspect = width / height
    if aspect < 0.55 or aspect > 1.8:
        raise QualityError(f"Concept image {path} has an unsuitable aspect ratio: {aspect:.3f}")
    return {
        "path": str(path),
        "width": width,
        "height": height,
        "size_mb": round(size_mb, 4),
    }


def validate_glb(path: Path, max_mb: float, max_triangles: int) -> dict[str, Any]:
    if not path.is_file():
        raise QualityError(f"Missing GLB: {path}")
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > max_mb:
        raise QualityError(f"GLB {path} is {size_mb:.2f} MB; maximum is {max_mb:.2f} MB")
    try:
        import trimesh
    except ImportError as exc:
        raise QualityError("trimesh is required to inspect GLB files") from exc
    loaded = trimesh.load(path, force="scene")
    geometries = list(loaded.geometry.values()) if hasattr(loaded, "geometry") else [loaded]
    if not geometries:
        raise QualityError(f"GLB {path} contains no geometry")
    triangles = sum(int(len(geometry.faces)) for geometry in geometries if hasattr(geometry, "faces"))
    vertices = sum(int(len(geometry.vertices)) for geometry in geometries if hasattr(geometry, "vertices"))
    if triangles <= 0:
        raise QualityError(f"GLB {path} contains no triangles")
    if triangles > max_triangles:
        raise QualityError(f"GLB {path} has {triangles} triangles; maximum is {max_triangles}")
    bounds = loaded.bounds.tolist() if getattr(loaded, "bounds", None) is not None else None
    return {
        "path": str(path),
        "size_mb": round(size_mb, 4),
        "geometry_count": len(geometries),
        "vertices": vertices,
        "triangles": triangles,
        "bounds": bounds,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--glb", type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()

    manifest = load_json(args.manifest)
    source = Path(str(manifest.get("source_image", "")))
    if not source:
        raise QualityError("Manifest source_image is required")
    quality = manifest.get("quality", {})
    if not isinstance(quality, dict):
        raise QualityError("Manifest quality must be an object")
    report: dict[str, Any] = {
        "asset_id": manifest.get("asset_id"),
        "concept": validate_image(source),
        "model": None,
        "status": "concept_validated",
    }
    if args.glb:
        report["model"] = validate_glb(
            args.glb,
            float(quality.get("max_download_mb", 50.0)),
            int(quality.get("max_triangles", 20000)),
        )
        report["status"] = "model_validated"
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (QualityError, json.JSONDecodeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
