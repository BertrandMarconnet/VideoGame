#!/usr/bin/env python3
"""Hardened entry point for parsing image-driven asset issues.

GitHub attachment links can redirect from github.com/user-attachments to a GitHub-owned
`githubusercontent.com` host or to the dedicated `github-production-user-asset-*` S3 bucket.
Those responses may use `application/octet-stream` even though their bytes are a valid PNG/JPEG/WebP.
This wrapper keeps the existing form parser and replaces only its attachment downloader.
"""
from __future__ import annotations

import urllib.parse
import urllib.request
from pathlib import Path

import parse_game_asset_issue as base


def is_allowed_image_host(host: str | None) -> bool:
    if not host:
        return False
    normalized = host.lower().rstrip(".")
    if normalized == "github.com":
        return True
    if normalized == "githubusercontent.com" or normalized.endswith(".githubusercontent.com"):
        return True
    if normalized.startswith("github-production-user-asset-") and normalized.endswith(".amazonaws.com"):
        return True
    return False


def detect_image_extension(data: bytes, content_type: str) -> str:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if data.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    by_mime = {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/webp": ".webp",
    }
    if content_type in by_mime:
        return by_mime[content_type]
    raise ValueError(f"Le fichier téléchargé n'est pas une image PNG/JPEG/WebP valide ({content_type})")


def download_image(url: str, destination: Path) -> Path:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not is_allowed_image_host(parsed.hostname):
        raise ValueError(f"Hôte d'image non autorisé : {parsed.hostname}")

    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "BlackoutProtocolAssetBot/4.0",
            "Accept": "image/avif,image/webp,image/png,image/jpeg,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        final_host = urllib.parse.urlparse(response.geturl()).hostname
        if not is_allowed_image_host(final_host):
            raise ValueError(f"Redirection d'image non autorisée : {final_host}")
        content_type = response.headers.get_content_type().lower()
        data = response.read(base.MAX_IMAGE_BYTES + 1)

    if len(data) > base.MAX_IMAGE_BYTES:
        raise ValueError("Image trop volumineuse")
    extension = detect_image_extension(data, content_type)
    output = destination.with_suffix(extension)
    output.write_bytes(data)
    return output


base.download_image = download_image


if __name__ == "__main__":
    try:
        base.main()
    except Exception as exc:
        print(f"asset request error: {exc}", file=base.sys.stderr)
        raise
