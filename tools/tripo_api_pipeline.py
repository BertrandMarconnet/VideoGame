#!/usr/bin/env python3
"""Generate Blackout Protocol assets through the official Tripo API.

The client is intentionally manifest-driven because Tripo evolves task payloads
independently from the game repository. It implements the stable upload/task/poll
flow and supports optional follow-up tasks for rigging or animation without
hard-coding experimental task names.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse

import requests

DEFAULT_BASE_URL = "https://api.tripo3d.ai/v2/openapi"
SUCCESS_STATES = {"success", "succeeded", "completed", "finished"}
FAILURE_STATES = {"failed", "failure", "cancelled", "canceled", "expired"}
TOKEN_KEYS = ("file_token", "image_token", "token")
TASK_KEYS = ("task_id", "id")
URL_SUFFIX_PRIORITY = (".glb", ".gltf", ".fbx", ".zip", ".obj")
PLACEHOLDER_RE = re.compile(r"\$\{([A-Z0-9_]+)\}")


class TripoPipelineError(RuntimeError):
    """Raised when a Tripo request or quality gate cannot continue safely."""


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise TripoPipelineError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise TripoPipelineError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise TripoPipelineError("The manifest root must be a JSON object")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def walk_values(value: Any) -> Iterable[tuple[str, Any]]:
    if isinstance(value, dict):
        for key, child in value.items():
            yield key, child
            yield from walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_values(child)


def find_first_key(payload: Any, keys: tuple[str, ...]) -> str | None:
    for key, value in walk_values(payload):
        if key in keys and isinstance(value, (str, int)) and str(value):
            return str(value)
    return None


def find_status(payload: Any) -> str:
    for key, value in walk_values(payload):
        if key in {"status", "state"} and isinstance(value, str):
            return value.strip().lower()
    return "unknown"


def find_download_urls(payload: Any) -> list[str]:
    urls: list[str] = []
    for _key, value in walk_values(payload):
        if not isinstance(value, str) or not value.startswith(("https://", "http://")):
            continue
        path = urlparse(value).path.lower()
        if any(path.endswith(suffix) for suffix in URL_SUFFIX_PRIORITY):
            urls.append(value)
    def priority(url: str) -> tuple[int, str]:
        path = urlparse(url).path.lower()
        for index, suffix in enumerate(URL_SUFFIX_PRIORITY):
            if path.endswith(suffix):
                return index, url
        return len(URL_SUFFIX_PRIORITY), url
    return sorted(set(urls), key=priority)


def substitute(value: Any, variables: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {key: substitute(child, variables) for key, child in value.items()}
    if isinstance(value, list):
        return [substitute(child, variables) for child in value]
    if not isinstance(value, str):
        return value
    return PLACEHOLDER_RE.sub(lambda match: variables.get(match.group(1), match.group(0)), value)


def api_request(
    session: requests.Session,
    method: str,
    url: str,
    *,
    timeout: float,
    **kwargs: Any,
) -> dict[str, Any]:
    response = session.request(method, url, timeout=timeout, **kwargs)
    if response.status_code >= 400:
        body = response.text[:1200]
        raise TripoPipelineError(f"Tripo HTTP {response.status_code} for {url}: {body}")
    try:
        payload = response.json()
    except ValueError as exc:
        raise TripoPipelineError(f"Tripo returned non-JSON data for {url}") from exc
    if not isinstance(payload, dict):
        raise TripoPipelineError(f"Unexpected Tripo response type for {url}")
    code = payload.get("code")
    if isinstance(code, int) and code not in {0, 200}:
        raise TripoPipelineError(f"Tripo API error {code}: {payload.get('message', payload)}")
    return payload


def upload_source(
    session: requests.Session,
    base_url: str,
    source: Path,
    timeout: float,
) -> tuple[str, dict[str, Any]]:
    mime_type = mimetypes.guess_type(source.name)[0] or "application/octet-stream"
    with source.open("rb") as handle:
        payload = api_request(
            session,
            "POST",
            f"{base_url}/upload",
            timeout=timeout,
            files={"file": (source.name, handle, mime_type)},
        )
    token = find_first_key(payload, TOKEN_KEYS)
    if not token:
        raise TripoPipelineError(f"No upload token found in Tripo response: {payload}")
    return token, payload


def create_task(
    session: requests.Session,
    base_url: str,
    task_payload: dict[str, Any],
    timeout: float,
) -> tuple[str, dict[str, Any]]:
    payload = api_request(
        session,
        "POST",
        f"{base_url}/task",
        timeout=timeout,
        json=task_payload,
    )
    task_id = find_first_key(payload, TASK_KEYS)
    if not task_id:
        raise TripoPipelineError(f"No task id found in Tripo response: {payload}")
    return task_id, payload


def wait_for_task(
    session: requests.Session,
    base_url: str,
    task_id: str,
    timeout: float,
    poll_seconds: float,
    request_timeout: float,
) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    last_payload: dict[str, Any] = {}
    while time.monotonic() < deadline:
        last_payload = api_request(
            session,
            "GET",
            f"{base_url}/task/{task_id}",
            timeout=request_timeout,
        )
        status = find_status(last_payload)
        print(f"TRIPO_TASK {task_id} status={status}", flush=True)
        if status in SUCCESS_STATES:
            return last_payload
        if status in FAILURE_STATES:
            raise TripoPipelineError(f"Tripo task {task_id} ended with status {status}: {last_payload}")
        time.sleep(poll_seconds)
    raise TripoPipelineError(f"Tripo task {task_id} timed out after {timeout:.0f} seconds")


def download_file(session: requests.Session, url: str, destination: Path, timeout: float) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with session.get(url, timeout=timeout, stream=True) as response:
        response.raise_for_status()
        with destination.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    handle.write(chunk)


def validate_manifest(manifest: dict[str, Any], repo_root: Path) -> dict[str, Any]:
    asset_id = str(manifest.get("asset_id", "")).strip()
    source_value = str(manifest.get("source_image", "")).strip()
    output_name = str(manifest.get("output_name", f"{asset_id}.glb")).strip()
    task = manifest.get("task")
    if not asset_id or not re.fullmatch(r"[a-z0-9_\-]+", asset_id):
        raise TripoPipelineError("asset_id must use lowercase letters, digits, underscores or hyphens")
    if not source_value:
        raise TripoPipelineError("source_image is required")
    source = (repo_root / source_value).resolve()
    try:
        source.relative_to(repo_root)
    except ValueError as exc:
        raise TripoPipelineError("source_image must remain inside the repository") from exc
    if not source.is_file():
        raise TripoPipelineError(f"Source image not found: {source_value}")
    if source.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        raise TripoPipelineError("source_image must be PNG, JPEG or WebP")
    if not isinstance(task, dict) or not isinstance(task.get("payload"), dict):
        raise TripoPipelineError("task.payload must be a JSON object")
    post_tasks = manifest.get("post_tasks", [])
    if not isinstance(post_tasks, list):
        raise TripoPipelineError("post_tasks must be an array")
    quality = manifest.get("quality", {})
    if not isinstance(quality, dict):
        raise TripoPipelineError("quality must be an object")
    max_mb = float(quality.get("max_download_mb", 50.0))
    if max_mb <= 0.0 or max_mb > 500.0:
        raise TripoPipelineError("quality.max_download_mb must be in ]0, 500]")
    return {
        "asset_id": asset_id,
        "source": source,
        "source_relative": source_value,
        "output_name": output_name,
        "task_payload": task["payload"],
        "post_tasks": post_tasks,
        "quality": {"max_download_mb": max_mb},
        "provenance": manifest.get("provenance", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output-root", default=Path("build/tripo-api"), type=Path)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--base-url", default=os.environ.get("TRIPO_API_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--poll-seconds", type=float, default=8.0)
    parser.add_argument("--task-timeout", type=float, default=1800.0)
    parser.add_argument("--request-timeout", type=float, default=90.0)
    args = parser.parse_args()

    repo_root = Path.cwd().resolve()
    manifest_path = args.manifest if args.manifest.is_absolute() else repo_root / args.manifest
    manifest = load_json(manifest_path)
    validated = validate_manifest(manifest, repo_root)
    output_dir = args.output_root / validated["asset_id"]
    output_dir.mkdir(parents=True, exist_ok=True)

    validation_report = {
        "asset_id": validated["asset_id"],
        "source_image": validated["source_relative"],
        "source_sha256": sha256(validated["source"]),
        "source_bytes": validated["source"].stat().st_size,
        "output_name": validated["output_name"],
        "post_task_count": len(validated["post_tasks"]),
        "validated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (output_dir / "validation.json").write_text(
        json.dumps(validation_report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    if args.validate_only:
        print(json.dumps(validation_report, indent=2, ensure_ascii=False))
        return 0

    api_key = os.environ.get("TRIPO_API_KEY", "").strip()
    if not api_key:
        raise TripoPipelineError(
            "TRIPO_API_KEY is missing. Add it as a GitHub Actions repository secret; "
            "the Tripo API cannot create tasks anonymously."
        )

    base_url = args.base_url.rstrip("/")
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
        "User-Agent": "BlackoutProtocol-AssetPipeline/1.0",
    })

    source_type = validated["source"].suffix.lower().lstrip(".").replace("jpeg", "jpg")
    upload_token, upload_response = upload_source(
        session, base_url, validated["source"], args.request_timeout
    )
    variables = {
        "FILE_TOKEN": upload_token,
        "SOURCE_TYPE": source_type,
        "ASSET_ID": validated["asset_id"],
    }
    initial_payload = substitute(validated["task_payload"], variables)
    task_id, create_response = create_task(
        session, base_url, initial_payload, args.request_timeout
    )
    variables["MODEL_TASK_ID"] = task_id
    variables["PREVIOUS_TASK_ID"] = task_id
    final_task_id = task_id
    final_response = wait_for_task(
        session,
        base_url,
        task_id,
        args.task_timeout,
        args.poll_seconds,
        args.request_timeout,
    )

    post_task_reports: list[dict[str, Any]] = []
    for index, post_task in enumerate(validated["post_tasks"]):
        if not isinstance(post_task, dict) or not isinstance(post_task.get("payload"), dict):
            raise TripoPipelineError(f"post_tasks[{index}].payload must be an object")
        post_payload = substitute(post_task["payload"], variables)
        post_id, post_create = create_task(
            session, base_url, post_payload, args.request_timeout
        )
        post_result = wait_for_task(
            session,
            base_url,
            post_id,
            args.task_timeout,
            args.poll_seconds,
            args.request_timeout,
        )
        post_task_reports.append({
            "name": str(post_task.get("name", f"post_{index + 1}")),
            "task_id": post_id,
            "create_response": post_create,
            "result": post_result,
        })
        variables["PREVIOUS_TASK_ID"] = post_id
        final_task_id = post_id
        final_response = post_result

    urls = find_download_urls(final_response)
    if not urls and post_task_reports:
        for report in reversed(post_task_reports):
            urls = find_download_urls(report["result"])
            if urls:
                break
    if not urls:
        urls = find_download_urls(final_response) + find_download_urls(create_response)
    if not urls:
        raise TripoPipelineError(f"No downloadable model URL found for final task {final_task_id}")

    selected_url = urls[0]
    suffix = Path(urlparse(selected_url).path).suffix.lower() or ".glb"
    requested_output = Path(validated["output_name"])
    if requested_output.suffix:
        suffix = requested_output.suffix
    destination = output_dir / f"{requested_output.stem}{suffix}"
    download_file(session, selected_url, destination, max(args.request_timeout, 180.0))
    size_mb = destination.stat().st_size / (1024 * 1024)
    if size_mb > validated["quality"]["max_download_mb"]:
        destination.unlink(missing_ok=True)
        raise TripoPipelineError(
            f"Downloaded model is {size_mb:.2f} MB, above the allowed "
            f"{validated['quality']['max_download_mb']:.2f} MB"
        )

    report = {
        **validation_report,
        "base_url": base_url,
        "upload_response": upload_response,
        "model_task_id": task_id,
        "final_task_id": final_task_id,
        "post_tasks": post_task_reports,
        "download_url": selected_url,
        "download_path": str(destination),
        "download_bytes": destination.stat().st_size,
        "download_sha256": sha256(destination),
        "completed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "provenance": validated["provenance"],
    }
    (output_dir / "generation.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "asset_id": validated["asset_id"],
        "task_id": final_task_id,
        "output": str(destination),
        "size_mb": round(size_mb, 3),
    }, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except TripoPipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
