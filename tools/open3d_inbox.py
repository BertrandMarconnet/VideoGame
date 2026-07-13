#!/usr/bin/env python3
"""Turn images dropped in assets/asset_inbox into Godot-ready GLB candidates.

The default backend is local TripoSR followed by Blender. It uses no API key,
account or paid generation endpoint. Each image may have an optional JSON sidecar
with generation and integration overrides. Without a sidecar, safe Web-oriented
defaults are used. SVG concepts are rasterized locally before inference.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SUPPORTED = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
SLUG_RE = re.compile(r"[^a-z0-9]+")


class InboxError(RuntimeError):
    pass


def slugify(value: str) -> str:
    slug = SLUG_RE.sub("_", value.lower()).strip("_")
    if not slug:
        raise InboxError(f"Invalid asset name: {value!r}")
    return slug


def load_sidecar(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise InboxError(f"Sidecar must contain a JSON object: {path}")
    return data


def infer_category(image: Path, inbox: Path) -> str:
    relative = image.relative_to(inbox)
    first = relative.parts[0].lower() if len(relative.parts) > 1 else "props"
    return first if first in {"props", "modules", "characters", "robots"} else "props"


def inferred_height(slug: str, category: str) -> float:
    if "door" in slug or "wall" in slug or category == "modules":
        return 3.2
    if "console" in slug:
        return 1.35
    if "flashlight" in slug or "lamp" in slug:
        return 0.34
    if "crawler" in slug or "kite" in slug:
        return 0.85
    if "specter" in slug or category in {"characters", "robots"}:
        return 1.9
    return 1.0


def default_faces(category: str) -> int:
    return 12000 if category in {"characters", "robots"} else 7000


def validate_integration_path(
    repo_root: Path,
    requested: str | None,
    production_root: Path,
    category: str,
    slug: str,
) -> Path:
    relative = Path(requested) if requested else production_root / category / f"{slug}.glb"
    if relative.is_absolute() or relative.suffix.lower() != ".glb":
        raise InboxError("integration_path must be a relative .glb path")
    destination = (repo_root / relative).resolve()
    production_base = (repo_root / "assets" / "production").resolve()
    try:
        destination.relative_to(production_base)
    except ValueError as exc:
        raise InboxError("integration_path must stay below assets/production/") from exc
    return destination


def prepare_image(repo_root: Path, output_root: Path, image: Path) -> Path:
    if image.suffix.lower() != ".svg":
        return image
    try:
        import cairosvg
    except ImportError as exc:
        raise InboxError("CairoSVG is required to rasterize SVG concepts") from exc
    destination = repo_root / output_root / "prepared" / f"{slugify(image.stem)}.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        url=str(image),
        write_to=str(destination),
        output_width=1024,
        output_height=1024,
    )
    return destination


def merge_manifest(
    repo_root: Path,
    inbox: Path,
    source_image: Path,
    prepared_image: Path,
    production_root: Path,
) -> tuple[dict[str, Any], str, str, Path]:
    sidecar = load_sidecar(source_image.with_suffix(".json"))
    asset_name = str(sidecar.get("asset_name", source_image.stem.replace("_", " ").title())).strip()
    slug = slugify(asset_name)
    category = str(sidecar.get("category", infer_category(source_image, inbox))).lower()
    if category not in {"props", "modules", "characters", "robots"}:
        raise InboxError(f"Unsupported category {category!r} for {source_image}")
    generation = {
        "foreground_ratio": 0.86,
        "mc_resolution": 256,
        "texture_resolution": 1024,
        "target_faces": default_faces(category),
        "target_height_m": inferred_height(slug, category),
        "bake_texture": False,
        "create_collision": category not in {"characters", "robots"},
        "device": "cuda:0",
    }
    generation.update(sidecar.get("generation", {}))
    quality = {"max_glb_mb": 20}
    quality.update(sidecar.get("quality", {}))
    provenance = {
        "author": "Bertrand Marconnet / Blackout Protocol",
        "source_license": "project-owned concept",
    }
    provenance.update(sidecar.get("provenance", {}))
    destination = validate_integration_path(
        repo_root,
        str(sidecar["integration_path"]) if "integration_path" in sidecar else None,
        production_root,
        category,
        slug,
    )
    manifest = {
        "asset_name": asset_name,
        "source_image": prepared_image.relative_to(repo_root).as_posix(),
        "generation": generation,
        "quality": quality,
        "provenance": provenance,
    }
    return manifest, slug, category, destination


def discover(inbox: Path) -> list[Path]:
    return sorted(path for path in inbox.rglob("*") if path.is_file() and path.suffix.lower() in SUPPORTED)


def run(command: list[str], cwd: Path) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=str(cwd), check=True)


def copy_candidate(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    metrics = source.parents[1] / "metrics.json"
    if metrics.is_file():
        shutil.copy2(metrics, destination.with_suffix(".metrics.json"))
    provenance = source.parents[1] / "PROVENANCE.md"
    if provenance.is_file():
        shutil.copy2(provenance, destination.with_suffix(".PROVENANCE.md"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inbox", type=Path, default=Path("assets/asset_inbox"))
    parser.add_argument("--output-root", type=Path, default=Path("build/open3d-inbox"))
    parser.add_argument("--production-root", type=Path, default=Path("assets/production/generated"))
    parser.add_argument("--triposr-home", type=Path, default=Path("~/opt/TripoSR").expanduser())
    parser.add_argument("--asset", help="Generate only one image stem or slug")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()

    repo_root = Path.cwd().resolve()
    inbox = (repo_root / args.inbox).resolve()
    if not inbox.is_dir():
        raise InboxError(f"Inbox not found: {inbox}")
    images = discover(inbox)
    if args.asset:
        wanted = slugify(args.asset)
        images = [image for image in images if slugify(image.stem) == wanted]
    if not images:
        raise InboxError("No PNG/JPEG/WebP/SVG concept image was found in the asset inbox")

    manifests_dir = repo_root / args.output_root / "manifests"
    manifests_dir.mkdir(parents=True, exist_ok=True)
    catalog: list[dict[str, Any]] = []
    generator = repo_root / "tools" / "triposr_generate.py"

    for image in images:
        prepared = prepare_image(repo_root, args.output_root, image)
        manifest, slug, category, destination = merge_manifest(
            repo_root,
            inbox,
            image,
            prepared,
            args.production_root,
        )
        manifest_path = manifests_dir / f"{slug}.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        command = [
            sys.executable,
            str(generator),
            "--manifest",
            str(manifest_path),
            "--output-root",
            str(repo_root / args.output_root / "triposr"),
            "--triposr-home",
            str(args.triposr_home),
        ]
        if args.validate_only:
            command.append("--validate-only")
        run(command, repo_root)
        if not args.validate_only:
            source = repo_root / args.output_root / "triposr" / slug / "production" / f"{slug}.glb"
            if not source.is_file():
                raise InboxError(f"Generator did not produce {source}")
            copy_candidate(source, destination)
        catalog.append(
            {
                "asset_name": manifest["asset_name"],
                "slug": slug,
                "category": category,
                "source_image": image.relative_to(repo_root).as_posix(),
                "prepared_image": manifest["source_image"],
                "output": destination.relative_to(repo_root).as_posix(),
                "status": "validated" if args.validate_only else "generated",
            }
        )

    catalog_path = repo_root / args.output_root / "catalog.json"
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not args.validate_only:
        production_catalog = repo_root / "assets" / "production" / "generated-catalog.json"
        production_catalog.parent.mkdir(parents=True, exist_ok=True)
        production_catalog.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(catalog, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (InboxError, json.JSONDecodeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
