#!/usr/bin/env python3
"""Remove preview/collision helper geometry from a generated GLB without touching gameplay meshes.

Blender's glTF exporter does not interpret ``hide_render`` or viewport ``WIRE`` display as an
instruction to omit a mesh. Earlier bundles therefore contained the black ``Body-colonly`` proxy
that is visible when the GLB is imported in Blender or Godot. This tool clears the mesh reference
from helper nodes while preserving the binary buffers, animation indices and armature hierarchy.
"""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
FORBIDDEN_TOKENS = ("-colonly", "_colonly", "previewground", "collisionhidden")


def _is_helper_name(value: str) -> bool:
    lowered = value.lower().replace(" ", "")
    return any(token in lowered for token in FORBIDDEN_TOKENS)


def _read_chunks(payload: bytes) -> tuple[dict[str, Any], list[tuple[int, bytes]]]:
    if len(payload) < 20 or payload[:4] != b"glTF":
        raise ValueError("Not a binary glTF 2.0 file")
    version, total = struct.unpack_from("<II", payload, 4)
    if version != 2 or total != len(payload):
        raise ValueError("Invalid GLB header")
    offset = 12
    document: dict[str, Any] | None = None
    other: list[tuple[int, bytes]] = []
    while offset + 8 <= len(payload):
        length, chunk_type = struct.unpack_from("<II", payload, offset)
        start = offset + 8
        end = start + length
        if end > len(payload):
            raise ValueError("Invalid GLB chunk length")
        data = payload[start:end]
        if chunk_type == JSON_CHUNK:
            document = json.loads(data.rstrip(b" \t\r\n\x00").decode("utf-8"))
        else:
            other.append((chunk_type, data))
        offset = end
    if document is None:
        raise ValueError("GLB has no JSON chunk")
    return document, other


def _write_glb(path: Path, document: dict[str, Any], chunks: list[tuple[int, bytes]]) -> None:
    json_data = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_data += b" " * ((4 - len(json_data) % 4) % 4)
    body = struct.pack("<II", len(json_data), JSON_CHUNK) + json_data
    for chunk_type, data in chunks:
        padded = data + b"\x00" * ((4 - len(data) % 4) % 4)
        body += struct.pack("<II", len(padded), chunk_type) + padded
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


def sanitize(path: Path, report_path: Path | None = None) -> dict[str, Any]:
    document, chunks = _read_chunks(path.read_bytes())
    materials = document.get("materials", [])
    helper_materials = {
        index
        for index, material in enumerate(materials)
        if _is_helper_name(str(material.get("name", "")))
    }
    helper_meshes: set[int] = set()
    for mesh_index, mesh in enumerate(document.get("meshes", [])):
        if _is_helper_name(str(mesh.get("name", ""))):
            helper_meshes.add(mesh_index)
            continue
        for primitive in mesh.get("primitives", []):
            if primitive.get("material") in helper_materials:
                helper_meshes.add(mesh_index)
                break

    cleared: list[str] = []
    for node in document.get("nodes", []):
        node_name = str(node.get("name", ""))
        mesh_index = node.get("mesh")
        if _is_helper_name(node_name) or mesh_index in helper_meshes:
            if "mesh" in node:
                node.pop("mesh", None)
                cleared.append(node_name or f"mesh_{mesh_index}")
            extras = node.setdefault("extras", {})
            if isinstance(extras, dict):
                extras["blackout_helper_only"] = True

    _write_glb(path, document, chunks)
    report = {
        "schema_version": 1,
        "glb": str(path),
        "cleared_helper_nodes": cleared,
        "helper_mesh_indices": sorted(helper_meshes),
        "helper_material_indices": sorted(helper_materials),
    }
    if report_path is not None:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--glb", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    sanitize(args.glb, args.report)


if __name__ == "__main__":
    main()
