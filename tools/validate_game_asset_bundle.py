#!/usr/bin/env python3
"""Validate a generated asset bundle before it can be committed or exposed to Godot."""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

VALID_CATEGORIES = {"robot_biped","robot_quadruped","character_humanoid","fps_viewmodel","articulated_machine","prop","wall","door","environment","gui_panel"}
VALID_MODES = {"none", "localized", "detachable", "segmented_wall", "material_advanced"}
VALID_TEXTURE_MODES = {"reference_atlas", "palette_only", "screen_image", "flat"}
VALID_COLLISIONS = {"auto", "box", "capsule", "local_boxes", "segmented_cells", "none"}
FORBIDDEN_VISIBLE_TOKENS = ("-colonly", "_colonly", "previewground", "collisionhidden")


def read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def read_glb_document(payload: bytes) -> dict[str, Any]:
    offset = 12
    while offset + 8 <= len(payload):
        length, chunk_type = struct.unpack_from("<II", payload, offset)
        start = offset + 8
        end = start + length
        if end > len(payload):
            raise ValueError("invalid GLB chunk length")
        if chunk_type == 0x4E4F534A:
            return json.loads(payload[start:end].rstrip(b" \t\r\n\x00").decode("utf-8"))
        offset = end
    raise ValueError("GLB has no JSON chunk")


def validate_glb(path: Path, max_mb: int) -> dict[str, Any]:
    payload = path.read_bytes()
    if len(payload) < 20 or payload[:4] != b"glTF":
        raise ValueError(f"{path} is not a binary glTF file")
    version, total_length = struct.unpack_from("<II", payload, 4)
    if version != 2 or total_length != len(payload):
        raise ValueError(f"{path} has an invalid glTF header")
    if len(payload) > max_mb * 1024 * 1024:
        raise ValueError(f"{path} exceeds {max_mb} MB")
    document = read_glb_document(payload)
    visible_helpers: list[str] = []
    for node in document.get("nodes", []):
        name = str(node.get("name", ""))
        lowered = name.lower().replace(" ", "")
        if "mesh" in node and any(token in lowered for token in FORBIDDEN_VISIBLE_TOKENS):
            visible_helpers.append(name)
    if visible_helpers:
        raise ValueError("visible collision/preview helpers remain in GLB: " + ", ".join(visible_helpers))
    return {"bytes": len(payload), "version": version, "nodes": len(document.get("nodes", [])), "visible_helpers": 0}


def validate_asset(asset: dict[str, Any], slug: str) -> None:
    required = {"schema_version","id","name","category","glb","damage_profile","dimensions_m","rig","animations","audio_profile"}
    missing = sorted(required - asset.keys())
    if missing:
        raise ValueError(f"asset manifest missing: {', '.join(missing)}")
    if asset["schema_version"] != 1 or asset["id"] != slug:
        raise ValueError("asset schema version or id mismatch")
    if asset["category"] not in VALID_CATEGORIES:
        raise ValueError("unsupported asset category")
    dims = asset["dimensions_m"]
    if not isinstance(dims, dict) or any(float(dims.get(axis, 0)) <= 0 for axis in ("width", "height", "depth")):
        raise ValueError("invalid metric dimensions")
    if not isinstance(asset["animations"], list):
        raise ValueError("animations must be an array")
    if asset.get("texture_mode", "palette_only") not in VALID_TEXTURE_MODES:
        raise ValueError("unsupported texture mode")
    if asset.get("collision_mode", "auto") not in VALID_COLLISIONS:
        raise ValueError("unsupported collision mode")
    parts = asset.get("segmentation_parts", [])
    if not isinstance(parts, list) or len(parts) != len(set(map(str, parts))):
        raise ValueError("segmentation parts must be a unique array")


def validate_damage(damage: dict[str, Any], slug: str, category: str) -> None:
    if damage.get("schema_version") != 1 or damage.get("asset_id") != slug:
        raise ValueError("damage schema version or asset id mismatch")
    if damage.get("mode") not in VALID_MODES:
        raise ValueError("unsupported destruction mode")
    zones = damage.get("zones")
    if not isinstance(zones, list):
        raise ValueError("damage zones must be an array")
    ids: set[str] = set()
    for zone in zones:
        if not isinstance(zone, dict):
            raise ValueError("each damage zone must be an object")
        zone_id = str(zone.get("id", ""))
        if not zone_id or zone_id in ids:
            raise ValueError("damage zone ids must be unique and non-empty")
        ids.add(zone_id)
        if float(zone.get("max_health", 0)) <= 0:
            raise ValueError(f"zone {zone_id} has invalid health")
        if not isinstance(zone.get("node_patterns"), list) or not zone.get("node_patterns"):
            raise ValueError(f"zone {zone_id} has no node patterns")
    if category in {"robot_biped","robot_quadruped","character_humanoid","fps_viewmodel","articulated_machine"} and damage.get("mode") != "none" and len(zones) < 3:
        raise ValueError("an articulated destructible asset requires at least three localized zones")
    if category == "wall" and damage.get("mode") in {"segmented_wall", "material_advanced"} and len(zones) < 2:
        raise ValueError("a segmented wall requires multiple cells")
    rules = damage.get("tool_rules")
    if not isinstance(rules, dict) or "flashlight_bash" not in rules or "crowbar" not in rules:
        raise ValueError("tool rules must include flashlight_bash and crowbar")


def validate_audio(audio: dict[str, Any], slug: str, bundle: Path) -> None:
    if audio.get("schema_version") != 1 or audio.get("asset_id") != slug:
        raise ValueError("audio schema version or asset id mismatch")
    streams = audio.get("streams", {})
    events = audio.get("events", [])
    if not isinstance(streams, dict) or not isinstance(events, list):
        raise ValueError("audio streams/events have invalid types")
    for name, resource_path in streams.items():
        path = str(resource_path)
        marker = f"res://assets/generated/{slug}/"
        if not path.startswith(marker):
            raise ValueError(f"audio stream {name} escapes the asset bundle")
        local = bundle / path[len(marker):]
        if not local.is_file() or local.stat().st_size == 0:
            raise ValueError(f"missing audio stream file: {local}")
    for event in events:
        if not isinstance(event, dict):
            raise ValueError("audio event must be an object")
        if str(event.get("stream", "")) not in streams.values():
            raise ValueError("audio event references an unknown stream")
        marker = float(event.get("time_normalized", -1.0))
        if not 0.0 <= marker <= 1.0:
            raise ValueError("audio marker must be normalized between 0 and 1")


def validate_rig_and_animations(asset: dict[str, Any], metrics: dict[str, Any]) -> None:
    category = asset["category"]
    bones = int(metrics.get("bones", 0))
    animations = metrics.get("animations", [])
    if not isinstance(animations, list):
        raise ValueError("metrics animations must be an array")
    if category in {"robot_biped", "robot_quadruped", "character_humanoid"}:
        if bones < 10 or len(animations) < 3:
            raise ValueError("biped/quadruped bundle does not contain a usable rig and clips")
    elif category == "fps_viewmodel" and (bones < 4 or len(animations) < 3):
        raise ValueError("FPS viewmodel requires a hand/tool rig and at least three clips")
    elif category == "articulated_machine" and (bones < 5 or len(animations) < 3):
        raise ValueError("articulated machine requires a multi-joint rig and at least three clips")
    elif category == "door" and asset.get("rig") != "none" and (bones < 2 or len(animations) < 2):
        raise ValueError("animated door requires a hinge rig and open/close clips")
    elif category == "prop" and asset.get("rig") == "rigid_segmented" and (bones < 2 or len(animations) < 1):
        raise ValueError("segmented prop requires a rigid-part rig")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--max-mb", type=int, default=24)
    args = parser.parse_args()
    base = args.bundle
    paths = {name: base / f"{args.slug}.{suffix}" for name, suffix in {"glb":"glb","preview":"png","asset":"asset.json","damage":"damage.json","metrics":"metrics.json","audio":"audio.json","sanitize":"sanitize.json"}.items()}
    for name, path in paths.items():
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"missing generated {name}: {path}")
    glb_info = validate_glb(paths["glb"], args.max_mb)
    asset, damage, metrics, audio = read_json(paths["asset"]), read_json(paths["damage"]), read_json(paths["metrics"]), read_json(paths["audio"])
    validate_asset(asset, args.slug)
    validate_damage(damage, args.slug, asset["category"])
    validate_audio(audio, args.slug, base)
    validate_rig_and_animations(asset, metrics)
    triangles = int(metrics.get("triangles", 0))
    if triangles <= 0 or triangles > 60000:
        raise ValueError(f"invalid triangle count: {triangles}")
    if int(metrics.get("mesh_objects", 0)) <= 0:
        raise ValueError("bundle contains no mesh objects")
    report = {"valid":True,"slug":args.slug,"category":asset["category"],"triangles":triangles,"mesh_objects":int(metrics.get("mesh_objects",0)),"bones":int(metrics.get("bones",0)),"animations":metrics.get("animations",[]),"damage_zones":len(damage.get("zones",[])),"audio_streams":len(audio.get("streams",{})),"audio_events":len(audio.get("events",[])),"texture_mode":asset.get("texture_mode","palette_only"),"collision_mode":asset.get("collision_mode","auto"),"reference_images_used":int(metrics.get("reference_images_used",0)),"glb":glb_info}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
