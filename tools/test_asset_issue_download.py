#!/usr/bin/env python3
"""Small regression checks for issue attachment parsing."""
from __future__ import annotations

import parse_game_asset_issue_v2 as parser


def main() -> None:
    assert parser.is_allowed_image_host("github.com")
    assert parser.is_allowed_image_host("objects.githubusercontent.com")
    assert parser.is_allowed_image_host("private-user-images.githubusercontent.com")
    assert parser.is_allowed_image_host("github-production-user-asset-6210df.s3.amazonaws.com")
    assert not parser.is_allowed_image_host("example.com")
    assert parser.detect_image_extension(b"\x89PNG\r\n\x1a\nrest", "application/octet-stream") == ".png"
    assert parser.detect_image_extension(b"\xff\xd8\xffrest", "application/octet-stream") == ".jpg"
    assert parser.detect_image_extension(b"RIFF1234WEBPrest", "application/octet-stream") == ".webp"
    print("asset issue attachment regression checks passed")


if __name__ == "__main__":
    main()
