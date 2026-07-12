#!/usr/bin/env python3
"""Generate one Meshy 3D asset from a repository manifest.

The script deliberately uses only Python's standard library so it can run on a
stock GitHub-hosted runner. It never prints the API key and never commits files.
Generated assets are written to an output directory for review as a workflow
artifact.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

API_ROOT = "https://api.meshy.ai/openapi/v1"
TERMINAL_STATUSES = {"SUCCEEDED", "FAILED", "CANCELED"}
IMAGE_MIME_BY_SUFFIX = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
}
MAX_LOCAL_IMAGE_BYTES = 12 * 1024 * 1024
COMMON_GENERATION_KEYS = {
    "ai_model",
    "should_texture",
    "enable_pbr",
    "hd_texture",
    "texture_prompt",
    "should_remesh",
    "topology",
    "target_polycount",
    "decimation_mode",
    "save_pre_remeshed_model",
    "pose_mode",
    "image_enhancement",
    "remove_lighting",
    "moderation",
    "target_formats",
    "auto_size",
    "alpha_thumbnail",
    "multi_view_thumbnails",
    "origin_at",
}
SINGLE_IMAGE_ONLY_KEYS = {"model_type"}


class PipelineError(RuntimeError):
    """Raised for a user-actionable pipeline failure."""


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def json_dump(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    if not slug:
        raise PipelineError("asset_name must contain at least one letter or digit")
    return slug


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PipelineError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Manifest is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise PipelineError("Manifest root must be a JSON object")
    return payload


def ensure_inside_repo(repo_root: Path, candidate: Path) -> Path:
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise PipelineError(f"Path escapes repository root: {candidate}") from exc
    return resolved


def encode_local_image(repo_root: Path, source: str) -> tuple[str, dict[str, Any]]:
    local_path = ensure_inside_repo(repo_root, repo_root / source)
    suffix = local_path.suffix.lower()
    if suffix not in IMAGE_MIME_BY_SUFFIX:
        raise PipelineError(f"Unsupported local image format for {source}; use PNG or JPEG")
    if not local_path.is_file():
        raise PipelineError(f"Source image does not exist: {source}")
    size = local_path.stat().st_size
    if size <= 0:
        raise PipelineError(f"Source image is empty: {source}")
    if size > MAX_LOCAL_IMAGE_BYTES:
        raise PipelineError(
            f"Source image is too large ({size / 1024 / 1024:.1f} MiB): {source}; "
            "compress it before calling Meshy"
        )
    encoded = base64.b64encode(local_path.read_bytes()).decode("ascii")
    mime = IMAGE_MIME_BY_SUFFIX[suffix]
    metadata = {
        "source": source,
        "kind": "repository_file",
        "size_bytes": size,
        "sha256": sha256_file(local_path),
        "mime_type": mime,
    }
    return f"data:{mime};base64,{encoded}", metadata


def resolve_image_source(repo_root: Path, source: str) -> tuple[str, dict[str, Any]]:
    if source.startswith("https://") or source.startswith("http://"):
        return source, {"source": source, "kind": "public_url"}
    if source.startswith("data:image/"):
        return source, {"source": "inline_data_uri", "kind": "data_uri"}
    return encode_local_image(repo_root, source)


def validate_generation_options(image_count: int, raw: Any) -> dict[str, Any]:
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        raise PipelineError("generation must be a JSON object")
    allowed = set(COMMON_GENERATION_KEYS)
    if image_count == 1:
        allowed.update(SINGLE_IMAGE_ONLY_KEYS)
    unknown = sorted(set(raw) - allowed)
    if unknown:
        raise PipelineError(f"Unsupported generation option(s): {', '.join(unknown)}")

    options: dict[str, Any] = {
        "ai_model": "latest",
        "should_texture": True,
        "enable_pbr": False,
        "hd_texture": False,
        "should_remesh": True,
        "topology": "triangle",
        "target_polycount": 8000,
        "save_pre_remeshed_model": False,
        "pose_mode": "",
        "image_enhancement": True,
        "remove_lighting": True,
        "moderation": True,
        "target_formats": ["glb"],
        "auto_size": True,
        "alpha_thumbnail": True,
        "multi_view_thumbnails": True,
        "origin_at": "bottom",
    }
    options.update(raw)

    if options["ai_model"] not in {"latest", "meshy-5", "meshy-6"}:
        raise PipelineError("generation.ai_model must be latest, meshy-5 or meshy-6")
    if options["topology"] not in {"triangle", "quad"}:
        raise PipelineError("generation.topology must be triangle or quad")
    if options["origin_at"] not in {"bottom", "center"}:
        raise PipelineError("generation.origin_at must be bottom or center")
    if options["pose_mode"] not in {"", "a-pose", "t-pose"}:
        raise PipelineError("generation.pose_mode must be empty, a-pose or t-pose")
    target_polycount = int(options.get("target_polycount", 8000))
    if not 100 <= target_polycount <= 300_000:
        raise PipelineError("generation.target_polycount must be between 100 and 300000")
    options["target_polycount"] = target_polycount
    formats = options.get("target_formats")
    if not isinstance(formats, list) or "glb" not in formats:
        raise PipelineError("generation.target_formats must be a list containing glb")
    if options.get("texture_prompt") and len(str(options["texture_prompt"])) > 600:
        raise PipelineError("generation.texture_prompt is limited to 600 characters")
    if image_count == 1 and "model_type" in options:
        if options["model_type"] not in {"standard", "lowpoly"}:
            raise PipelineError("generation.model_type must be standard or lowpoly")
    return options


def prepare_job(repo_root: Path, manifest_path: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    asset_name = str(manifest.get("asset_name", "")).strip()
    slug = slugify(asset_name)
    images = manifest.get("images")
    if not isinstance(images, list) or not 1 <= len(images) <= 4:
        raise PipelineError("images must contain between 1 and 4 repository paths, URLs or data URIs")
    resolved_images: list[str] = []
    source_metadata: list[dict[str, Any]] = []
    for item in images:
        if not isinstance(item, str) or not item.strip():
            raise PipelineError("Each images entry must be a non-empty string")
        resolved, metadata = resolve_image_source(repo_root, item.strip())
        resolved_images.append(resolved)
        source_metadata.append(metadata)

    generation = validate_generation_options(len(resolved_images), manifest.get("generation"))
    if len(resolved_images) == 1:
        endpoint_kind = "image-to-3d"
        payload: dict[str, Any] = {"image_url": resolved_images[0], **generation}
    else:
        endpoint_kind = "multi-image-to-3d"
        generation.pop("model_type", None)
        payload = {"image_urls": resolved_images, **generation}

    quality = manifest.get("quality") or {}
    if not isinstance(quality, dict):
        raise PipelineError("quality must be a JSON object")
    max_glb_mb = float(quality.get("max_glb_mb", 25.0))
    if max_glb_mb <= 0:
        raise PipelineError("quality.max_glb_mb must be greater than zero")

    return {
        "asset_name": asset_name,
        "slug": slug,
        "endpoint_kind": endpoint_kind,
        "payload": payload,
        "source_metadata": source_metadata,
        "quality": {
            "max_glb_mb": max_glb_mb,
            "require_glb": bool(quality.get("require_glb", True)),
        },
        "provenance": manifest.get("provenance") or {},
        "manifest_path": str(manifest_path),
    }


def request_json(method: str, url: str, api_key: str, payload: dict[str, Any] | None = None) -> Any:
    body = None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
        "User-Agent": "BlackoutProtocol-GitHubActions/1.0",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=90) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise PipelineError(f"Meshy API returned HTTP {exc.code}: {detail[:1200]}") from exc
    except URLError as exc:
        raise PipelineError(f"Meshy API request failed: {exc.reason}") from exc


def download_file(url: str, destination: Path) -> None:
    request = Request(url, headers={"User-Agent": "BlackoutProtocol-GitHubActions/1.0"})
    try:
        with urlopen(request, timeout=180) as response, destination.open("wb") as handle:
            shutil.copyfileobj(response, handle)
    except (HTTPError, URLError) as exc:
        raise PipelineError(f"Failed to download {destination.name}: {exc}") from exc


def wait_for_task(api_key: str, endpoint_kind: str, task_id: str, timeout_seconds: int, poll_seconds: int) -> dict[str, Any]:
    status_url = f"{API_ROOT}/{endpoint_kind}/{task_id}"
    deadline = time.monotonic() + timeout_seconds
    last_progress = -1
    while True:
        task = request_json("GET", status_url, api_key)
        status = str(task.get("status", "UNKNOWN"))
        progress = int(task.get("progress") or 0)
        if progress != last_progress:
            print(f"Meshy task {task_id}: {status} ({progress}%)", flush=True)
            last_progress = progress
        if status in TERMINAL_STATUSES:
            return task
        if time.monotonic() >= deadline:
            raise PipelineError(f"Meshy task timed out after {timeout_seconds // 60} minutes: {task_id}")
        time.sleep(poll_seconds)


def write_provenance(output_dir: Path, job: dict[str, Any], task: dict[str, Any] | None) -> None:
    provenance = job.get("provenance") or {}
    task_id = task.get("id", "not-created") if task else "not-created"
    status = task.get("status", "VALIDATED_ONLY") if task else "VALIDATED_ONLY"
    credits = task.get("consumed_credits", "unknown") if task else "not-consumed"
    lines = [
        f"# Provenance — {job['asset_name']}",
        "",
        f"- Generated/validated at: {utc_now()}",
        f"- Meshy task ID: `{task_id}`",
        f"- Meshy status: `{status}`",
        f"- Meshy credits reported: `{credits}`",
        f"- Manifest: `{job['manifest_path']}`",
        f"- Declared author/operator: {provenance.get('author', 'not specified')}",
        f"- Licence review: {provenance.get('license_review', 'pending')}",
        "",
        "## Source images",
        "",
    ]
    for source in job["source_metadata"]:
        if source["kind"] == "repository_file":
            lines.append(
                f"- `{source['source']}` — {source['size_bytes']} bytes — SHA-256 `{source['sha256']}`"
            )
        else:
            lines.append(f"- {source['source']} ({source['kind']})")
    lines.extend(
        [
            "",
            "## Rights warning",
            "",
            "This file records technical provenance only. Before shipping the asset, verify the Meshy plan terms,",
            "the rights to every source image, and the intended commercial licence. Do not move the asset into",
            "`assets/production/validated/` until that review is complete.",
            "",
        ]
    )
    (output_dir / "PROVENANCE.md").write_text("\n".join(lines), encoding="utf-8")


def sanitize_payload(payload: dict[str, Any]) -> dict[str, Any]:
    sanitized = dict(payload)
    for key in ("image_url", "image_urls", "texture_image_url"):
        if key in sanitized:
            value = sanitized[key]
            if isinstance(value, list):
                sanitized[key] = ["<repository image or public URL>" for _ in value]
            else:
                sanitized[key] = "<repository image or public URL>"
    return sanitized


def run(args: argparse.Namespace) -> int:
    repo_root = Path(args.repo_root).resolve()
    manifest_path = ensure_inside_repo(repo_root, repo_root / args.manifest)
    manifest = load_manifest(manifest_path)
    job = prepare_job(repo_root, manifest_path.relative_to(repo_root), manifest)
    output_dir = Path(args.output_root).resolve() / job["slug"]
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    validation = {
        "validated_at": utc_now(),
        "asset_name": job["asset_name"],
        "slug": job["slug"],
        "endpoint": job["endpoint_kind"],
        "image_count": len(job["source_metadata"]),
        "sources": job["source_metadata"],
        "generation": sanitize_payload(job["payload"]),
        "quality": job["quality"],
    }
    json_dump(output_dir / "validation.json", validation)
    shutil.copy2(manifest_path, output_dir / "manifest.json")

    if args.validate_only:
        write_provenance(output_dir, job, None)
        (output_dir / "github-summary.md").write_text(
            f"## Meshy manifest validated\n\n- Asset: `{job['slug']}`\n- Endpoint: `{job['endpoint_kind']}`\n"
            f"- Images: {len(job['source_metadata'])}\n- API call: not executed\n",
            encoding="utf-8",
        )
        print(f"Manifest validated: {args.manifest}")
        return 0

    api_key = os.environ.get("MESHY_API_KEY", "").strip()
    if not api_key:
        raise PipelineError(
            "MESHY_API_KEY is not configured. Add it in GitHub Settings > Secrets and variables > Actions."
        )

    create_url = f"{API_ROOT}/{job['endpoint_kind']}"
    create_response = request_json("POST", create_url, api_key, job["payload"])
    task_id = str(create_response.get("result", "")).strip()
    if not task_id:
        raise PipelineError(f"Meshy did not return a task ID: {create_response}")
    print(f"Created Meshy task: {task_id}")

    task = wait_for_task(
        api_key,
        job["endpoint_kind"],
        task_id,
        timeout_seconds=args.timeout_minutes * 60,
        poll_seconds=args.poll_seconds,
    )
    json_dump(output_dir / "task.json", task)
    write_provenance(output_dir, job, task)

    if task.get("status") != "SUCCEEDED":
        error_message = (task.get("task_error") or {}).get("message", "unknown Meshy error")
        raise PipelineError(f"Meshy task ended with {task.get('status')}: {error_message}")

    model_urls = task.get("model_urls") or {}
    glb_url = model_urls.get("glb")
    if not glb_url and job["quality"]["require_glb"]:
        raise PipelineError("Meshy task succeeded but did not return a GLB URL")

    downloaded: dict[str, Any] = {}
    if glb_url:
        glb_path = output_dir / f"{job['slug']}.glb"
        download_file(glb_url, glb_path)
        if glb_path.read_bytes()[:4] != b"glTF":
            raise PipelineError("Downloaded GLB does not have a valid glTF binary header")
        downloaded[glb_path.name] = {
            "size_bytes": glb_path.stat().st_size,
            "sha256": sha256_file(glb_path),
        }

    thumbnail_url = task.get("thumbnail_url")
    if thumbnail_url:
        thumbnail_path = output_dir / "preview.png"
        download_file(thumbnail_url, thumbnail_path)
        downloaded[thumbnail_path.name] = {
            "size_bytes": thumbnail_path.stat().st_size,
            "sha256": sha256_file(thumbnail_path),
        }

    for view_name, view_url in (task.get("thumbnail_urls") or {}).items():
        if not view_url:
            continue
        view_path = output_dir / f"preview_{view_name}.png"
        download_file(view_url, view_path)
        downloaded[view_path.name] = {
            "size_bytes": view_path.stat().st_size,
            "sha256": sha256_file(view_path),
        }

    glb_size = downloaded.get(f"{job['slug']}.glb", {}).get("size_bytes", 0)
    max_bytes = int(job["quality"]["max_glb_mb"] * 1024 * 1024)
    quality_passed = glb_size <= max_bytes if glb_size else not job["quality"]["require_glb"]
    result_summary = {
        "completed_at": utc_now(),
        "asset_name": job["asset_name"],
        "task_id": task_id,
        "status": task.get("status"),
        "consumed_credits": task.get("consumed_credits"),
        "downloaded": downloaded,
        "quality": {
            **job["quality"],
            "glb_size_bytes": glb_size,
            "passed": quality_passed,
        },
    }
    json_dump(output_dir / "summary.json", result_summary)
    (output_dir / "github-summary.md").write_text(
        "\n".join(
            [
                "## Meshy asset generated",
                "",
                f"- Asset: `{job['slug']}`",
                f"- Task: `{task_id}`",
                f"- Status: `{task.get('status')}`",
                f"- Credits reported: `{task.get('consumed_credits', 'unknown')}`",
                f"- GLB size: `{glb_size / 1024 / 1024:.2f} MiB`",
                f"- Web size gate: `{'passed' if quality_passed else 'failed'}`",
                "- Result is an artifact only; it was not committed to the repository.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    if not quality_passed:
        raise PipelineError(
            f"Generated GLB is {glb_size / 1024 / 1024:.2f} MiB, above the configured "
            f"limit of {job['quality']['max_glb_mb']:.2f} MiB"
        )
    print(f"Meshy asset ready in {output_dir}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Manifest path relative to the repository root")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--output-root", default="build/meshy", help="Artifact output directory")
    parser.add_argument("--validate-only", action="store_true", help="Validate inputs without spending Meshy credits")
    parser.add_argument("--timeout-minutes", type=int, default=45, help="Maximum Meshy wait time")
    parser.add_argument("--poll-seconds", type=int, default=10, help="Task polling interval")
    args = parser.parse_args()
    if not 1 <= args.timeout_minutes <= 120:
        parser.error("--timeout-minutes must be between 1 and 120")
    if not 5 <= args.poll_seconds <= 60:
        parser.error("--poll-seconds must be between 5 and 60")
    return args


def main() -> None:
    try:
        raise SystemExit(run(parse_args()))
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


if __name__ == "__main__":
    main()
