#!/usr/bin/env python3
"""Hardened parser for image/audio driven game-asset issues."""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import parse_game_asset_issue as base

MAX_AUDIO_BYTES = 24 * 1024 * 1024


def is_allowed_attachment_host(host: str | None) -> bool:
    if not host:
        return False
    normalized = host.lower().rstrip(".")
    if normalized == "github.com":
        return True
    if normalized == "githubusercontent.com" or normalized.endswith(".githubusercontent.com"):
        return True
    return normalized.startswith("github-production-user-asset-") and normalized.endswith(".amazonaws.com")


def is_allowed_image_host(host: str | None) -> bool:
    """Backward-compatible alias used by the attachment regression test."""
    return is_allowed_attachment_host(host)


def detect_image_extension(data: bytes, content_type: str) -> str:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if data.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    by_mime = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}
    if content_type in by_mime:
        return by_mime[content_type]
    raise ValueError(f"Le fichier téléchargé n'est pas une image PNG/JPEG/WebP valide ({content_type})")


def detect_audio_extension(data: bytes, content_type: str) -> str:
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        return ".wav"
    if data.startswith(b"OggS"):
        return ".ogg"
    if data.startswith(b"ID3") or (len(data) >= 2 and data[0] == 0xFF and data[1] & 0xE0 == 0xE0):
        return ".mp3"
    by_mime = {"audio/wav": ".wav", "audio/x-wav": ".wav", "audio/ogg": ".ogg", "audio/mpeg": ".mp3"}
    if content_type in by_mime:
        return by_mime[content_type]
    raise ValueError(f"Le fichier téléchargé n'est pas un son WAV/OGG/MP3 valide ({content_type})")


def _checked_local_repository_file(url: str) -> Path | None:
    """Resolve a raw URL from the current checked-out repository.

    Private repositories return HTTP 404 to anonymous raw.githubusercontent.com requests even
    though GitHub Actions already checked the referenced file out. Reuse that trusted local copy
    instead of requiring public repository access.
    """
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "raw.githubusercontent.com":
        return None
    parts = parsed.path.lstrip("/").split("/", 3)
    if len(parts) != 4:
        return None
    owner, repository, _ref, relative = parts
    expected_repository = os.environ.get("GITHUB_REPOSITORY", "")
    if expected_repository and f"{owner}/{repository}" != expected_repository:
        return None
    if not (relative.startswith("asset_jobs/") or relative.startswith("tests/fixtures/")):
        raise ValueError("Chemin de référence interne non autorisé")
    root = Path.cwd().resolve()
    source = (root / relative).resolve()
    try:
        source.relative_to(root)
    except ValueError as exc:
        raise ValueError("Chemin de référence interne hors dépôt") from exc
    if not source.is_file() or source.is_symlink():
        raise FileNotFoundError(f"Référence interne introuvable : {relative}")
    return source


def _copy_local_image(url: str, destination: Path) -> Path | None:
    source = _checked_local_repository_file(url)
    if source is None:
        return None
    data = source.read_bytes()
    if len(data) > base.MAX_IMAGE_BYTES:
        raise ValueError("Image trop volumineuse")
    output = destination.with_suffix(detect_image_extension(data, ""))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    return output


def _download(url: str, destination: Path, maximum: int, detector, accept: str) -> Path:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not is_allowed_attachment_host(parsed.hostname):
        raise ValueError(f"Hôte de pièce jointe non autorisé : {parsed.hostname}")
    request = urllib.request.Request(url, headers={"User-Agent": "BlackoutProtocolAssetBot/5.1", "Accept": accept})
    with urllib.request.urlopen(request, timeout=45) as response:
        final_host = urllib.parse.urlparse(response.geturl()).hostname
        if not is_allowed_attachment_host(final_host):
            raise ValueError(f"Redirection de pièce jointe non autorisée : {final_host}")
        content_type = response.headers.get_content_type().lower()
        data = response.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError("Pièce jointe trop volumineuse")
    output = destination.with_suffix(detector(data, content_type))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    return output


def download_image(url: str, destination: Path) -> Path:
    local = _copy_local_image(url, destination)
    if local is not None:
        return local
    return _download(url, destination, base.MAX_IMAGE_BYTES, detect_image_extension, "image/avif,image/webp,image/png,image/jpeg,*/*;q=0.8")


def download_audio(url: str, destination: Path) -> Path:
    return _download(url, destination, MAX_AUDIO_BYTES, detect_audio_extension, "audio/wav,audio/ogg,audio/mpeg,*/*;q=0.5")


def _arg_path(flag: str) -> Path:
    if flag not in sys.argv:
        raise RuntimeError(f"Argument manquant : {flag}")
    return Path(sys.argv[sys.argv.index(flag) + 1])


def _checked_values(text: str) -> list[str]:
    result: list[str] = []
    for line in text.splitlines():
        match = re.match(r"^- \[[xX]\]\s*([^—–:]+)", line.strip())
        if match:
            value = match.group(1).strip()
            if value and value not in result:
                result.append(value)
    return result


def _first_any(sections: dict[str, str], *labels: str) -> str:
    return base.first_any(sections, *labels)


def _augment_request() -> None:
    event_path = _arg_path("--event")
    output_path = _arg_path("--output")
    event = json.loads(event_path.read_text(encoding="utf-8"))
    issue = event.get("issue") or {}
    sections = base.parse_sections(str(issue.get("body", "")))
    request = json.loads(output_path.read_text(encoding="utf-8"))

    checked_animations = _checked_values(_first_any(sections, "Animations standard", "Animations à générer"))
    custom_animations = base.parse_animations(_first_any(sections, "Animations supplémentaires"), [])
    if checked_animations or custom_animations:
        request["animations"] = base.parse_animations(",".join(checked_animations + custom_animations), request.get("animations", []))

    selected_parts = _checked_values(_first_any(sections, "Parties séparables / destructibles", "Parties séparables ou destructibles"))
    custom_parts = base.parse_parts(_first_any(sections, "Parties supplémentaires", "Parties supplémentaires à séparer"))
    if selected_parts or custom_parts:
        request["segmentation_parts"] = base.parse_parts(",".join(selected_parts + custom_parts))

    mode_map = {
        "Sons procéduraux adaptés à la catégorie — recommandé": "procedural",
        "Utiliser uniquement mes sons": "uploaded",
        "Mélanger mes sons et les sons procéduraux": "hybrid",
        "Aucun son": "none",
    }
    request["sound_mode"] = mode_map.get(_first_any(sections, "Mode sonore"), "procedural")
    request["sound_presets"] = _checked_values(_first_any(sections, "Familles sonores", "Familles sonores à produire"))
    request["sound_sync_description"] = _first_any(sections, "Synchronisation animation ↔ son", "Synchronisation animation et son")

    audio_section = _first_any(sections, "Sons du modèle", "Sons personnels du modèle")
    audio_urls = base.extract_urls(audio_section)
    audio_dir = output_path.parent / "audio"
    audio_files: list[str] = []
    audio_errors: list[str] = []
    for index, url in enumerate(audio_urls[:8]):
        try:
            audio_files.append(str(download_audio(url, audio_dir / f"audio_{index + 1}")))
        except Exception as exc:
            audio_errors.append(str(exc))
    request["audio_files"] = audio_files
    request["audio_file_errors"] = audio_errors
    output_path.write_text(json.dumps(request, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"audio_files": len(audio_files), "animations": request.get("animations", []), "parts": request.get("segmentation_parts", [])}, ensure_ascii=False))


base.download_image = download_image

if __name__ == "__main__":
    try:
        base.main()
        _augment_request()
    except Exception as exc:
        print(f"asset request error: {exc}", file=base.sys.stderr)
        raise
