#!/usr/bin/env python3
"""Create a safe local TripoSR input folder from a simple GitHub issue form."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ALLOWED_HOSTS = {
    "github.com",
    "user-images.githubusercontent.com",
    "private-user-images.githubusercontent.com",
    "githubusercontent.com",
    "raw.githubusercontent.com",
}
MAX_IMAGE_BYTES = 12 * 1024 * 1024
MAX_IMAGES = 4
SLUG_RE = re.compile(r"[^a-z0-9]+")
URL_RE = re.compile(r"https://[^\s)>\]]+")


class RequestError(RuntimeError):
    pass


def slugify(value: str) -> str:
    slug = SLUG_RE.sub("_", value.strip().lower()).strip("_")
    if not slug:
        raise RequestError("The asset name is empty or invalid")
    return slug[:80]


def section(body: str, title: str) -> str:
    pattern = re.compile(
        rf"^###\s+{re.escape(title)}\s*$\n+(.*?)(?=^###\s+|\Z)",
        re.MULTILINE | re.DOTALL | re.IGNORECASE,
    )
    match = pattern.search(body)
    if not match:
        return ""
    value = match.group(1).strip()
    return "" if value in {"_No response_", "No response"} else value


def parse_float(value: str, default: float) -> float:
    if not value:
        return default
    match = re.search(r"\d+(?:[.,]\d+)?", value)
    if not match:
        raise RequestError(f"Invalid height: {value!r}")
    result = float(match.group(0).replace(",", "."))
    if not 0.05 <= result <= 20.0:
        raise RequestError("Height must be between 0.05 m and 20 m")
    return result


def infer_view_name(text: str, index: int) -> str:
    normalized = text.lower().replace("-", "_").replace(" ", "_")
    if any(token in normalized for token in ("three_quarter", "3_4", "trois_quart", "3quart")):
        return "three_quarter"
    if any(token in normalized for token in ("front", "face", "avant")):
        return "front"
    if any(token in normalized for token in ("right", "side", "profil", "droite")):
        return "right"
    if any(token in normalized for token in ("back", "rear", "arriere", "arrière")):
        return "back"
    return ("three_quarter", "front", "right", "back")[min(index, 3)]


def download_image(url: str, destination: Path, token: str) -> None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise RequestError(f"Image host is not allowed: {parsed.hostname}")
    headers = {
        "User-Agent": "Blackout-Protocol-3D-Generator/2.0",
        "Accept": "image/avif,image/webp,image/png,image/jpeg,*/*;q=0.8",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    destination.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    with urllib.request.urlopen(request, timeout=90) as response, destination.open("wb") as handle:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_IMAGE_BYTES:
                raise RequestError("An uploaded image exceeds the 12 MB limit")
            handle.write(chunk)
    try:
        with Image.open(destination) as image:
            image.verify()
    except Exception as exc:
        destination.unlink(missing_ok=True)
        raise RequestError(f"Downloaded file is not a valid image: {url}") from exc


def copy_existing(source_root: Path, existing: str, destination: Path) -> list[str]:
    source = (source_root / slugify(existing)).resolve()
    try:
        source.relative_to(source_root.resolve())
    except ValueError as exc:
        raise RequestError("Existing asset folder escapes Input image") from exc
    if not source.is_dir():
        raise RequestError(f"Existing asset folder was not found: {existing}")
    destination.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for path in sorted(source.iterdir()):
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
            shutil.copy2(path, destination / path.name)
            copied.append(path.name)
    if not copied:
        raise RequestError(f"No images found in existing asset folder: {existing}")
    return copied


def write_output(path: str, values: dict[str, str]) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        for key, value in values.items():
            handle.write(f"{key}={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--body-file", type=Path, required=True)
    parser.add_argument("--title", default="")
    parser.add_argument("--repository-input", type=Path, default=Path("assets/Input image"))
    parser.add_argument("--request-root", type=Path, default=Path("build/issue-input"))
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    args = parser.parse_args()

    body = args.body_file.read_text(encoding="utf-8")
    asset_name = section(body, "Nom du modèle")
    if not asset_name:
        asset_name = re.sub(r"^\[3D\]\s*", "", args.title, flags=re.IGNORECASE).strip()
    slug = slugify(asset_name)
    existing = section(body, "Images déjà présentes dans le dépôt")
    height = parse_float(section(body, "Hauteur souhaitée en mètres"), 1.0)
    quality_value = section(body, "Qualité")
    standard = "standard" in quality_value.lower()

    destination = (args.request_root / slug).resolve()
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)

    image_section = section(body, "Images du modèle")
    urls: list[str] = []
    for url in URL_RE.findall(image_section):
        clean = url.rstrip(".,;\"")
        if clean not in urls:
            urls.append(clean)
    urls = urls[:MAX_IMAGES]

    image_names: list[str] = []
    if urls:
        token = os.environ.get("GITHUB_TOKEN", "")
        for index, url in enumerate(urls):
            view = infer_view_name(url, index)
            target = destination / f"{view}.png"
            suffix_index = 2
            while target.exists():
                target = destination / f"{view}_{suffix_index}.png"
                suffix_index += 1
            download_image(url, target, token)
            image_names.append(target.name)
    else:
        existing_slug = existing.strip() or slug
        image_names = copy_existing(args.repository_input, existing_slug, destination)

    preferred = next((name for name in image_names if Path(name).stem == "three_quarter"), image_names[0])
    config = {
        "asset_name": asset_name,
        "primary_image": preferred,
        "generation": {
            "foreground_ratio": 0.86,
            "mc_resolution": 192 if standard else 128,
            "texture_resolution": 1024,
            "target_faces": 12000 if standard else 9000,
            "target_height_m": height,
            "bake_texture": False,
            "create_collision": False,
            "device": "cpu",
        },
        "quality": {"max_glb_mb": 30},
    }
    (destination / "asset.json").write_text(
        json.dumps(config, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    write_output(
        args.github_output,
        {
            "asset_slug": slug,
            "asset_name": asset_name,
            "input_root": args.request_root.as_posix(),
            "primary_image": preferred,
        },
    )
    print(json.dumps({"asset": asset_name, "slug": slug, "images": image_names, "config": config}, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RequestError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
