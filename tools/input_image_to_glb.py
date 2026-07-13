#!/usr/bin/env python3
"""Generate GLB files from images placed in assets/Input image.

Backends:
- Meshy Multi-Image: 1 to 4 views, runs on a GitHub-hosted runner, requires
  the MESHY_API_KEY repository secret and consumes Meshy credits.
- Local TripoSR: no paid API, runs on a self-hosted GPU runner and reconstructs
  from one primary image; extra views are retained in the catalog for QA.
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

SUPPORTED = {".png", ".jpg", ".jpeg", ".webp"}
VIEW_ORDER = {
    "front": 0,
    "right": 1,
    "side": 1,
    "back": 2,
    "rear": 2,
    "three_quarter": 3,
    "three-quarter": 3,
    "threequarter": 3,
    "3_4": 3,
}
PRIMARY_STEMS = (
    "three_quarter",
    "three-quarter",
    "threequarter",
    "3_4",
    "front_3_4",
    "front",
)
SLUG_RE = re.compile(r"[^a-z0-9]+")
MESHY_ENDPOINT = "https://api.meshy.ai/openapi/v1/multi-image-to-3d"


class InputPipelineError(RuntimeError):
    pass


def slugify(value: str) -> str:
    slug = SLUG_RE.sub("_", value.strip().lower()).strip("_")
    if not slug:
        raise InputPipelineError(f"Invalid asset name: {value!r}")
    return slug


def load_json(path: Path | None) -> dict[str, Any]:
    if path is None or not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise InputPipelineError(f"Expected a JSON object in {path}")
    return data


def image_files(folder: Path) -> list[Path]:
    images = [
        path
        for path in folder.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED
    ]
    return sorted(
        images,
        key=lambda path: (
            VIEW_ORDER.get(path.stem.lower(), 99),
            path.name.lower(),
        ),
    )


def discover_assets(
    input_root: Path,
) -> list[tuple[str, Path, list[Path], Path | None]]:
    assets: list[tuple[str, Path, list[Path], Path | None]] = []

    for folder in sorted(path for path in input_root.iterdir() if path.is_dir()):
        images = image_files(folder)
        if images:
            assets.append((folder.name, folder, images, folder / "asset.json"))

    for image in image_files(input_root):
        assets.append((image.stem, input_root, [image], image.with_suffix(".json")))
    return assets


def choose_primary(images: list[Path], config: dict[str, Any]) -> Path:
    requested = str(config.get("primary_image", "")).strip()
    if requested:
        candidate = images[0].parent / requested
        if candidate not in images:
            available = ", ".join(path.name for path in images)
            raise InputPipelineError(
                f"primary_image {requested!r} was not found. Available: {available}"
            )
        return candidate

    by_stem = {path.stem.lower(): path for path in images}
    for stem in PRIMARY_STEMS:
        if stem in by_stem:
            return by_stem[stem]
    return images[0]


def generation_settings(config: dict[str, Any]) -> dict[str, Any]:
    generation = {
        "foreground_ratio": 0.86,
        "mc_resolution": 256,
        "texture_resolution": 1024,
        "target_faces": 12000,
        "target_height_m": 1.0,
        "bake_texture": False,
        "create_collision": False,
        "device": "cuda:0",
        "ai_model": "latest",
        "should_texture": True,
        "enable_pbr": False,
        "pose_mode": "",
        "image_enhancement": False,
        "remove_lighting": True,
        "auto_size": True,
        "origin_at": "bottom",
    }
    overrides = config.get("generation", {})
    if overrides:
        if not isinstance(overrides, dict):
            raise InputPipelineError("generation must be a JSON object")
        generation.update(overrides)
    return generation


def quality_settings(config: dict[str, Any]) -> dict[str, Any]:
    quality = {"max_glb_mb": 25}
    overrides = config.get("quality", {})
    if overrides:
        if not isinstance(overrides, dict):
            raise InputPipelineError("quality must be a JSON object")
        quality.update(overrides)
    return quality


def run(command: list[str], cwd: Path) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=str(cwd), check=True)


def copy_optional(source: Path, destination: Path) -> None:
    if source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0]
    if mime not in {"image/png", "image/jpeg", "image/webp"}:
        raise InputPipelineError(f"Unsupported Meshy image type: {path}")
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def http_json(
    url: str,
    api_key: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    timeout: int = 120,
) -> dict[str, Any]:
    body = None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            parsed = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise InputPipelineError(
            f"Meshy HTTP {exc.code} for {url}: {detail}"
        ) from exc
    except urllib.error.URLError as exc:
        raise InputPipelineError(f"Meshy request failed: {exc}") from exc
    if not isinstance(parsed, dict):
        raise InputPipelineError(f"Unexpected Meshy response from {url}")
    return parsed


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Blackout-Protocol/1.0"})
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            with destination.open("wb") as handle:
                shutil.copyfileobj(response, handle)
    except urllib.error.URLError as exc:
        raise InputPipelineError(f"Unable to download generated GLB: {exc}") from exc
    if not destination.is_file() or destination.stat().st_size == 0:
        raise InputPipelineError(f"Downloaded GLB is empty: {destination}")


def generate_meshy(
    images: list[Path],
    generation: dict[str, Any],
    destination: Path,
    api_key: str,
    timeout_minutes: int,
) -> dict[str, Any]:
    if not api_key:
        raise InputPipelineError(
            "MESHY_API_KEY is missing. Add it in Settings > Secrets and variables "
            "> Actions > New repository secret."
        )
    selected = images[:4]
    payload: dict[str, Any] = {
        "image_urls": [data_uri(path) for path in selected],
        "ai_model": str(generation["ai_model"]),
        "should_texture": bool(generation["should_texture"]),
        "enable_pbr": bool(generation["enable_pbr"]),
        "should_remesh": True,
        "topology": "triangle",
        "target_polycount": int(generation["target_faces"]),
        "pose_mode": str(generation["pose_mode"]),
        "image_enhancement": bool(generation["image_enhancement"]),
        "remove_lighting": bool(generation["remove_lighting"]),
        "target_formats": ["glb"],
        "auto_size": bool(generation["auto_size"]),
        "origin_at": str(generation["origin_at"]),
    }
    texture_prompt = str(generation.get("texture_prompt", "")).strip()
    if texture_prompt:
        payload["texture_prompt"] = texture_prompt

    created = http_json(
        MESHY_ENDPOINT,
        api_key,
        method="POST",
        payload=payload,
    )
    task_id = str(created.get("result", "")).strip()
    if not task_id:
        raise InputPipelineError(f"Meshy did not return a task id: {created}")

    deadline = time.monotonic() + timeout_minutes * 60
    task: dict[str, Any] = {}
    while time.monotonic() < deadline:
        task = http_json(f"{MESHY_ENDPOINT}/{task_id}", api_key)
        status = str(task.get("status", "")).upper()
        progress = task.get("progress", 0)
        print(f"Meshy task {task_id}: {status} ({progress}%)", flush=True)
        if status == "SUCCEEDED":
            break
        if status in {"FAILED", "CANCELED", "CANCELLED", "EXPIRED"}:
            error = task.get("task_error", {})
            raise InputPipelineError(
                f"Meshy task {task_id} ended with {status}: {error}"
            )
        time.sleep(15)
    else:
        raise InputPipelineError(
            f"Meshy task {task_id} exceeded {timeout_minutes} minutes"
        )

    model_urls = task.get("model_urls", {})
    glb_url = model_urls.get("glb") if isinstance(model_urls, dict) else None
    if not isinstance(glb_url, str) or not glb_url:
        raise InputPipelineError(f"Meshy task has no GLB URL: {task}")
    download(glb_url, destination)
    return {
        "task_id": task_id,
        "status": task.get("status"),
        "progress": task.get("progress"),
        "consumed_credits": task.get("consumed_credits"),
        "input_images": [path.name for path in selected],
    }


def generate_triposr(
    repo_root: Path,
    work_root: Path,
    asset_name: str,
    slug: str,
    primary: Path,
    generation: dict[str, Any],
    quality: dict[str, Any],
    destination: Path,
    triposr_home: Path,
    validate_only: bool,
) -> dict[str, Any]:
    manifest = {
        "asset_name": asset_name,
        "source_image": primary.relative_to(repo_root).as_posix(),
        "generation": {
            key: generation[key]
            for key in (
                "foreground_ratio",
                "mc_resolution",
                "texture_resolution",
                "target_faces",
                "target_height_m",
                "bake_texture",
                "create_collision",
                "device",
            )
        },
        "quality": quality,
        "provenance": {
            "author": "Bertrand Marconnet / Blackout Protocol",
            "source_license": "project-owned concept",
        },
    }
    manifests_dir = work_root / "manifests"
    manifests_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = manifests_dir / f"{slug}.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    generator = repo_root / "tools" / "triposr_generate.py"
    command = [
        sys.executable,
        str(generator),
        "--manifest",
        str(manifest_path),
        "--output-root",
        str(work_root / "triposr"),
        "--triposr-home",
        str(triposr_home),
    ]
    if validate_only:
        command.append("--validate-only")
    run(command, repo_root)

    if not validate_only:
        generated_root = work_root / "triposr" / slug
        candidate = generated_root / "production" / f"{slug}.glb"
        if not candidate.is_file() or candidate.stat().st_size == 0:
            raise InputPipelineError(f"Expected GLB was not found: {candidate}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(candidate, destination)
        copy_optional(
            generated_root / "metrics.json",
            destination.with_suffix(".metrics.json"),
        )
        copy_optional(
            generated_root / "PROVENANCE.md",
            destination.with_suffix(".PROVENANCE.md"),
        )
    return {"primary_image": primary.name}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-root", type=Path, default=Path("assets/Input image"))
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("assets/output 3d model"),
    )
    parser.add_argument(
        "--work-root",
        type=Path,
        default=Path("build/input-image-to-glb"),
    )
    parser.add_argument(
        "--triposr-home",
        type=Path,
        default=Path("~/opt/TripoSR").expanduser(),
    )
    parser.add_argument("--backend", choices=("meshy", "triposr"), required=True)
    parser.add_argument("--asset", help="Optional asset folder, image stem or slug")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--meshy-timeout-minutes", type=int, default=60)
    args = parser.parse_args()

    repo_root = Path.cwd().resolve()
    input_root = (repo_root / args.input_root).resolve()
    output_root = (repo_root / args.output_root).resolve()
    work_root = (repo_root / args.work_root).resolve()
    if not input_root.is_dir():
        raise InputPipelineError(f"Input folder not found: {input_root}")

    discovered = discover_assets(input_root)
    if args.asset:
        requested = slugify(args.asset)
        discovered = [
            item for item in discovered if slugify(item[0]) == requested
        ]
    if not discovered:
        raise InputPipelineError(
            "No PNG, JPEG or WebP image was found. Put images directly in "
            "'assets/Input image' or create one subfolder per asset."
        )

    output_root.mkdir(parents=True, exist_ok=True)
    catalog: list[dict[str, Any]] = []
    for fallback_name, folder, images, config_path in discovered:
        config = load_json(config_path)
        asset_name = str(config.get("asset_name", fallback_name)).strip()
        slug = slugify(asset_name)
        primary = choose_primary(images, config)
        generation = generation_settings(config)
        quality = quality_settings(config)
        destination = output_root / f"{slug}.glb"

        if args.validate_only:
            result = generate_triposr(
                repo_root,
                work_root,
                asset_name,
                slug,
                primary,
                generation,
                quality,
                destination,
                args.triposr_home,
                validate_only=True,
            )
        elif args.backend == "meshy":
            result = generate_meshy(
                images,
                generation,
                destination,
                os.environ.get("MESHY_API_KEY", ""),
                args.meshy_timeout_minutes,
            )
            max_bytes = float(quality["max_glb_mb"]) * 1024 * 1024
            if destination.stat().st_size > max_bytes:
                raise InputPipelineError(
                    f"{destination.name} exceeds quality.max_glb_mb"
                )
            destination.with_suffix(".metrics.json").write_text(
                json.dumps(result, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
        else:
            result = generate_triposr(
                repo_root,
                work_root,
                asset_name,
                slug,
                primary,
                generation,
                quality,
                destination,
                args.triposr_home,
                validate_only=False,
            )

        catalog.append(
            {
                "asset_name": asset_name,
                "slug": slug,
                "asset_folder": folder.relative_to(repo_root).as_posix(),
                "reference_images": [
                    path.relative_to(repo_root).as_posix() for path in images
                ],
                "primary_image": primary.relative_to(repo_root).as_posix(),
                "backend": args.backend,
                "output": destination.relative_to(repo_root).as_posix(),
                "status": "validated" if args.validate_only else "generated",
                "result": result,
            }
        )

    catalog_path = (
        work_root / "catalog.json"
        if args.validate_only
        else output_root / "catalog.json"
    )
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(catalog, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        InputPipelineError,
        json.JSONDecodeError,
        OSError,
        subprocess.CalledProcessError,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
