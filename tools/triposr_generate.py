#!/usr/bin/env python3
"""Validate and run the local TripoSR asset-generation pipeline.

The script uses no proprietary API and does not require an external account.
Generation expects a local TripoSR checkout and, for the production GLB pass,
Blender available on the execution runner.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

DATA_URI_RE = re.compile(r"^data:image/(png|jpeg|jpg|webp);base64,(.+)$", re.I | re.S)
SLUG_RE = re.compile(r"[^a-z0-9]+")


class PipelineError(RuntimeError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PipelineError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Invalid JSON in {path}: {exc}") from exc


def slugify(value: str) -> str:
    slug = SLUG_RE.sub("_", value.strip().lower()).strip("_")
    if not slug:
        raise PipelineError("asset_name must contain at least one letter or digit")
    return slug


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_number(data: dict[str, Any], key: str, minimum: float, maximum: float) -> float:
    value = data.get(key)
    if not isinstance(value, (int, float)):
        raise PipelineError(f"generation.{key} must be numeric")
    numeric = float(value)
    if numeric < minimum or numeric > maximum:
        raise PipelineError(f"generation.{key} must be between {minimum} and {maximum}")
    return numeric


def validate_manifest(manifest: dict[str, Any], repo_root: Path) -> dict[str, Any]:
    asset_name = manifest.get("asset_name")
    if not isinstance(asset_name, str) or not asset_name.strip():
        raise PipelineError("asset_name is required")
    slug = slugify(asset_name)

    source_image = manifest.get("source_image")
    if not isinstance(source_image, str) or not source_image.strip():
        raise PipelineError("source_image is required")
    data_match = DATA_URI_RE.match(source_image)
    if data_match:
        try:
            base64.b64decode(data_match.group(2), validate=True)
        except Exception as exc:
            raise PipelineError("source_image contains an invalid base64 data URI") from exc
        source_kind = "data_uri"
        resolved_source = None
    else:
        resolved_source = (repo_root / source_image).resolve()
        try:
            resolved_source.relative_to(repo_root.resolve())
        except ValueError as exc:
            raise PipelineError("source_image must stay inside the repository") from exc
        if not resolved_source.is_file():
            raise PipelineError(f"Source image not found: {source_image}")
        if resolved_source.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
            raise PipelineError("source_image must be PNG, JPEG or WebP")
        source_kind = "repository_file"

    generation = manifest.get("generation", {})
    if not isinstance(generation, dict):
        raise PipelineError("generation must be an object")
    foreground_ratio = require_number(generation, "foreground_ratio", 0.50, 0.98)
    mc_resolution = int(require_number(generation, "mc_resolution", 128, 512))
    texture_resolution = int(require_number(generation, "texture_resolution", 256, 2048))
    target_faces = int(require_number(generation, "target_faces", 500, 100000))
    target_height_m = require_number(generation, "target_height_m", 0.05, 20.0)
    bake_texture = bool(generation.get("bake_texture", False))
    create_collision = bool(generation.get("create_collision", True))
    device = str(generation.get("device", "cuda:0"))
    if device != "cpu" and not device.startswith("cuda"):
        raise PipelineError("generation.device must be cpu or cuda[:index]")

    quality = manifest.get("quality", {})
    if not isinstance(quality, dict):
        raise PipelineError("quality must be an object")
    max_glb_mb = float(quality.get("max_glb_mb", 25))
    if max_glb_mb <= 0 or max_glb_mb > 250:
        raise PipelineError("quality.max_glb_mb must be in ]0, 250]")

    provenance = manifest.get("provenance", {})
    if not isinstance(provenance, dict):
        raise PipelineError("provenance must be an object")
    author = str(provenance.get("author", "Blackout Protocol project"))
    source_license = str(provenance.get("source_license", "project-owned concept"))

    return {
        "asset_name": asset_name.strip(),
        "slug": slug,
        "source_image": source_image,
        "resolved_source": str(resolved_source) if resolved_source else None,
        "source_kind": source_kind,
        "generation": {
            "foreground_ratio": foreground_ratio,
            "mc_resolution": mc_resolution,
            "texture_resolution": texture_resolution,
            "target_faces": target_faces,
            "target_height_m": target_height_m,
            "bake_texture": bake_texture,
            "create_collision": create_collision,
            "device": device,
        },
        "quality": {"max_glb_mb": max_glb_mb},
        "provenance": {"author": author, "source_license": source_license},
    }


def materialize_source(validated: dict[str, Any], destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if validated["source_kind"] == "repository_file":
        shutil.copy2(validated["resolved_source"], destination)
        return
    match = DATA_URI_RE.match(validated["source_image"])
    if not match:
        raise PipelineError("Unable to decode source image")
    destination.write_bytes(base64.b64decode(match.group(2)))


def run_checked(command: list[str], cwd: Path | None = None) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=str(cwd) if cwd else None, check=True)


def find_raw_mesh(raw_root: Path, baked: bool) -> Path:
    candidates = list(raw_root.rglob("mesh.obj" if baked else "mesh.glb"))
    if not candidates:
        candidates = list(raw_root.rglob("mesh.glb")) + list(raw_root.rglob("mesh.obj"))
    if not candidates:
        raise PipelineError(f"TripoSR did not produce a mesh below {raw_root}")
    return sorted(candidates)[0]


def write_reports(output_dir: Path, validated: dict[str, Any], result: dict[str, Any]) -> None:
    summary = {"manifest": validated, "result": result}
    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    provenance = f"""# Provenance — {validated['asset_name']}

- Generator: TripoSR (VAST-AI-Research / Tripo AI / Stability AI)
- Generator license: MIT
- Execution mode: local model execution on a GitHub-hosted or self-hosted runner; no external generation API
- Concept author: {validated['provenance']['author']}
- Concept license: {validated['provenance']['source_license']}
- Generated at: {result.get('generated_at', 'validation only')}
- Source SHA-256: {result.get('source_sha256', 'not materialized')}
- GLB SHA-256: {result.get('glb_sha256', 'not generated')}

The generated mesh is a production candidate only. Review topology, UVs, scale,
license provenance, collision and Web/mobile performance before integration.
"""
    (output_dir / "PROVENANCE.md").write_text(provenance, encoding="utf-8")
    status = "validated" if result.get("mode") == "validate" else "generated"
    github_summary = f"""## TripoSR local pipeline — {validated['asset_name']}

- Status: **{status}**
- Source: `{validated['source_image']}`
- Target faces: `{validated['generation']['target_faces']}`
- Target height: `{validated['generation']['target_height_m']} m`
- Texture bake: `{validated['generation']['bake_texture']}`
- Output GLB: `{result.get('glb_path', 'not generated')}`
- Output size: `{result.get('glb_mb', 'n/a')} MB`

No proprietary API, API key or external generation account was used.
"""
    (output_dir / "github-summary.md").write_text(github_summary, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output-root", default=Path("build/triposr"), type=Path)
    parser.add_argument("--triposr-home", type=Path, default=Path(os.environ.get("TRIPOSR_HOME", "~/opt/TripoSR")).expanduser())
    parser.add_argument("--python", dest="python_bin", default=os.environ.get("TRIPOSR_PYTHON", ""))
    parser.add_argument("--blender", default=os.environ.get("BLENDER_BIN", "blender"))
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()

    repo_root = Path.cwd().resolve()
    manifest_path = args.manifest if args.manifest.is_absolute() else repo_root / args.manifest
    validated = validate_manifest(load_json(manifest_path), repo_root)
    output_dir = args.output_root / validated["slug"]
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "validated-manifest.json").write_text(
        json.dumps(validated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    if args.validate_only:
        result = {"mode": "validate"}
        write_reports(output_dir, validated, result)
        print(f"Validated TripoSR manifest: {manifest_path}")
        return 0

    run_py = args.triposr_home / "run.py"
    if not run_py.is_file():
        raise PipelineError(
            f"TripoSR not found at {args.triposr_home}. Run tools/setup_triposr_cpu.sh first."
        )
    python_bin = args.python_bin or str(args.triposr_home / ".venv" / "bin" / "python")
    if not Path(python_bin).is_file() and shutil.which(python_bin) is None:
        raise PipelineError(f"TripoSR Python not found: {python_bin}")
    blender_bin = shutil.which(args.blender) or (str(Path(args.blender)) if Path(args.blender).is_file() else None)
    if not blender_bin:
        raise PipelineError("Blender is required for decimation, metric scale and Godot collision output")

    source_path = output_dir / "source.png"
    materialize_source(validated, source_path)
    raw_root = output_dir / "raw"
    raw_root.mkdir(parents=True, exist_ok=True)
    gen = validated["generation"]
    triposr_command = [
        python_bin,
        str(run_py),
        str(source_path),
        "--device",
        gen["device"],
        "--foreground-ratio",
        str(gen["foreground_ratio"]),
        "--mc-resolution",
        str(gen["mc_resolution"]),
        "--output-dir",
        str(raw_root),
    ]
    if gen["bake_texture"]:
        triposr_command += [
            "--model-save-format",
            "obj",
            "--bake-texture",
            "--texture-resolution",
            str(gen["texture_resolution"]),
        ]
    else:
        triposr_command += ["--model-save-format", "glb"]

    started = time.time()
    run_checked(triposr_command, cwd=args.triposr_home)
    raw_mesh = find_raw_mesh(raw_root, gen["bake_texture"])
    production_dir = output_dir / "production"
    production_dir.mkdir(parents=True, exist_ok=True)
    final_glb = production_dir / f"{validated['slug']}.glb"
    metrics_path = output_dir / "metrics.json"
    post_script = repo_root / "tools" / "triposr_blender_postprocess.py"
    blender_command = [
        blender_bin,
        "--background",
        "--python",
        str(post_script),
        "--",
        "--input",
        str(raw_mesh),
        "--output",
        str(final_glb),
        "--metrics",
        str(metrics_path),
        "--asset-name",
        validated["slug"],
        "--target-faces",
        str(gen["target_faces"]),
        "--target-height-m",
        str(gen["target_height_m"]),
    ]
    if gen["create_collision"]:
        blender_command.append("--create-collision")
    run_checked(blender_command, cwd=repo_root)

    glb_mb = final_glb.stat().st_size / (1024 * 1024)
    if glb_mb > validated["quality"]["max_glb_mb"]:
        raise PipelineError(
            f"Generated GLB is {glb_mb:.2f} MB, above limit {validated['quality']['max_glb_mb']:.2f} MB"
        )
    result = {
        "mode": "generate",
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "duration_seconds": round(time.time() - started, 2),
        "source_sha256": sha256(source_path),
        "glb_sha256": sha256(final_glb),
        "glb_path": str(final_glb.relative_to(repo_root)),
        "glb_mb": round(glb_mb, 3),
        "raw_mesh": str(raw_mesh.relative_to(repo_root)),
    }
    write_reports(output_dir, validated, result)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
