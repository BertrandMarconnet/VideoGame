#!/usr/bin/env python3
"""Create a lightweight animation-synchronised audio bundle for a generated asset.

The generator accepts optional audio files uploaded through the issue form. When none are supplied,
it creates deterministic low-cost WAV placeholders adapted to the asset category. The resulting
``.audio.json`` is consumed by the Godot runtime and keeps animation markers separate from the GLB.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import shutil
import struct
import wave
from pathlib import Path
from typing import Any, Callable

SAMPLE_RATE = 22050


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_") or "sound"


def _write_wav(path: Path, duration: float, sample: Callable[[float], float]) -> None:
    count = max(1, int(SAMPLE_RATE * duration))
    frames = bytearray()
    for index in range(count):
        t = index / SAMPLE_RATE
        value = max(-1.0, min(1.0, sample(t)))
        frames.extend(struct.pack("<h", int(value * 32767)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(bytes(frames))


def _fade(t: float, duration: float, attack: float = 0.02, release: float = 0.08) -> float:
    return min(1.0, t / max(attack, 1e-4), (duration - t) / max(release, 1e-4))


def _servo(path: Path) -> None:
    duration = 1.0
    _write_wav(path, duration, lambda t: 0.18 * math.sin(2 * math.pi * 92 * t) + 0.07 * math.sin(2 * math.pi * 184 * t + 0.4) + 0.025 * math.sin(2 * math.pi * 31 * t))


def _step(path: Path) -> None:
    duration = 0.28
    rng = random.Random(2107)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration) + 1)]
    _write_wav(path, duration, lambda t: _fade(t, duration, 0.004, 0.16) * (0.55 * math.sin(2 * math.pi * (72 - 32 * t) * t) + 0.12 * noise[min(int(t * SAMPLE_RATE), len(noise) - 1)]))


def _impact(path: Path) -> None:
    duration = 0.42
    rng = random.Random(1987)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration) + 1)]
    _write_wav(path, duration, lambda t: math.exp(-11 * t) * (0.75 * math.sin(2 * math.pi * 54 * t) + 0.28 * noise[min(int(t * SAMPLE_RATE), len(noise) - 1)]))


def _hydraulic(path: Path) -> None:
    duration = 0.85
    rng = random.Random(501)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration) + 1)]
    _write_wav(path, duration, lambda t: _fade(t, duration, 0.08, 0.2) * (0.16 * math.sin(2 * math.pi * (38 + 80 * t) * t) + 0.09 * noise[min(int(t * SAMPLE_RATE), len(noise) - 1)]))


def _alarm(path: Path) -> None:
    duration = 1.0
    _write_wav(path, duration, lambda t: 0.22 * math.sin(2 * math.pi * (620 if int(t * 4) % 2 == 0 else 430) * t))


def _electric(path: Path) -> None:
    duration = 0.55
    rng = random.Random(9001)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration) + 1)]
    _write_wav(path, duration, lambda t: math.exp(-5.5 * t) * (0.16 * math.sin(2 * math.pi * 980 * t) + 0.18 * noise[min(int(t * SAMPLE_RATE), len(noise) - 1)]))


def _ambience(path: Path) -> None:
    duration = 1.5
    rng = random.Random(4201)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration) + 1)]
    _write_wav(path, duration, lambda t: 0.025 * noise[min(int(t * SAMPLE_RATE), len(noise) - 1)] + 0.035 * math.sin(2 * math.pi * 46 * t))


GENERATORS: dict[str, Callable[[Path], None]] = {
    "servo": _servo,
    "step": _step,
    "impact": _impact,
    "hydraulic": _hydraulic,
    "alarm": _alarm,
    "electric": _electric,
    "ambience": _ambience,
}

CATEGORY_PRESETS = {
    "robot_biped": ["servo", "step", "impact", "electric"],
    "robot_quadruped": ["servo", "step", "impact", "electric"],
    "character_humanoid": ["step", "impact", "ambience"],
    "fps_viewmodel": ["servo", "impact", "electric"],
    "articulated_machine": ["hydraulic", "servo", "alarm", "impact"],
    "prop": ["impact", "electric"],
    "wall": ["impact"],
    "door": ["hydraulic", "servo", "impact"],
    "environment": ["ambience", "alarm", "electric"],
    "gui_panel": ["electric", "alarm", "servo"],
}


def _default_events(category: str, animations: list[str], streams: dict[str, str]) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for animation in animations:
        lowered = animation.lower()
        if "idle" in lowered and "servo" in streams:
            events.append({"animation": animation, "time_normalized": 0.0, "stream": streams["servo"], "loop": True, "volume_db": -12.0})
        elif "walk" in lowered or "crawl" in lowered:
            sound = streams.get("step") or streams.get("servo")
            if sound:
                events.extend([
                    {"animation": animation, "time_normalized": 0.18, "stream": sound, "loop": False, "volume_db": -5.0},
                    {"animation": animation, "time_normalized": 0.68, "stream": sound, "loop": False, "volume_db": -5.0},
                ])
        elif "run" in lowered:
            sound = streams.get("step") or streams.get("servo")
            if sound:
                events.extend([
                    {"animation": animation, "time_normalized": 0.12, "stream": sound, "loop": False, "volume_db": -3.0},
                    {"animation": animation, "time_normalized": 0.55, "stream": sound, "loop": False, "volume_db": -3.0},
                ])
        elif any(token in lowered for token in ("attack", "bash", "break", "fall")):
            sound = streams.get("impact") or next(iter(streams.values()), "")
            if sound:
                events.append({"animation": animation, "time_normalized": 0.46, "stream": sound, "loop": False, "volume_db": -1.0})
        elif any(token in lowered for token in ("open", "close", "work", "use", "interact")):
            sound = streams.get("hydraulic") or streams.get("servo") or next(iter(streams.values()), "")
            if sound:
                events.append({"animation": animation, "time_normalized": 0.15, "stream": sound, "loop": False, "volume_db": -5.0})
        elif any(token in lowered for token in ("alarm", "shutdown")):
            sound = streams.get("alarm") or streams.get("electric") or next(iter(streams.values()), "")
            if sound:
                events.append({"animation": animation, "time_normalized": 0.35, "stream": sound, "loop": False, "volume_db": -3.0})
        elif "boot" in lowered:
            sound = streams.get("electric") or next(iter(streams.values()), "")
            if sound:
                events.append({"animation": animation, "time_normalized": 0.08, "stream": sound, "loop": False, "volume_db": -6.0})
    if category == "environment" and "ambience" in streams:
        events.append({"animation": "__always__", "time_normalized": 0.0, "stream": streams["ambience"], "loop": True, "volume_db": -18.0})
    return events


def _parse_custom_events(description: str, animations: list[str], stream_lookup: dict[str, str]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    aliases = {slug(Path(path).stem): path for path in stream_lookup.values()}
    aliases.update({slug(key): value for key, value in stream_lookup.items()})
    animation_lookup = {slug(name): name for name in animations}
    for raw in re.split(r"[;\n]+", description):
        raw = raw.strip()
        if not raw or "=" not in raw:
            continue
        animation_raw, event_raw = [part.strip() for part in raw.split("=", 1)]
        pieces = [part.strip() for part in event_raw.split("@")]
        clip_name = slug(pieces[0])
        stream = aliases.get(clip_name)
        if not stream:
            continue
        animation = animation_lookup.get(slug(animation_raw), animation_raw)
        time_value = 0.0
        if len(pieces) > 1:
            try:
                time_value = max(0.0, min(1.0, float(pieces[1].replace(",", "."))))
            except ValueError:
                time_value = 0.0
        loop = len(pieces) > 2 and pieces[2].lower() in {"loop", "boucle", "true", "1"}
        result.append({"animation": animation, "time_normalized": time_value, "stream": stream, "loop": loop, "volume_db": -4.0})
    return result


def build(request_path: Path, bundle: Path) -> dict[str, Any]:
    request = json.loads(request_path.read_text(encoding="utf-8"))
    slug_id = request["slug"]
    asset_path = bundle / f"{slug_id}.asset.json"
    asset = json.loads(asset_path.read_text(encoding="utf-8"))
    animations = [str(value) for value in asset.get("animations", request.get("animations", []))]
    mode = str(request.get("sound_mode", "procedural")).lower()
    audio_dir = bundle / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    streams: dict[str, str] = {}
    uploaded = [Path(value) for value in request.get("audio_files", []) if Path(value).is_file()]
    if mode in {"uploaded", "hybrid"}:
        for index, source in enumerate(uploaded, 1):
            name = f"uploaded_{index:02d}_{slug(source.stem)}{source.suffix.lower()}"
            destination = audio_dir / name
            shutil.copyfile(source, destination)
            streams[slug(source.stem)] = f"res://assets/generated/{slug_id}/audio/{name}"

    presets = [slug(value) for value in request.get("sound_presets", [])]
    if not presets:
        presets = CATEGORY_PRESETS.get(request.get("category", "prop"), ["impact"])
    if mode in {"procedural", "hybrid"} or not streams:
        for preset in presets:
            generator = GENERATORS.get(preset)
            if generator is None:
                continue
            destination = audio_dir / f"{preset}.wav"
            generator(destination)
            streams[preset] = f"res://assets/generated/{slug_id}/audio/{destination.name}"

    custom = _parse_custom_events(str(request.get("sound_sync_description", "")), animations, streams)
    events = custom or _default_events(str(request.get("category", "prop")), animations, streams)
    profile = {
        "schema_version": 1,
        "asset_id": slug_id,
        "mode": mode,
        "spatial": str(request.get("category", "")) != "fps_viewmodel",
        "streams": streams,
        "events": events,
        "notes": str(request.get("sound_sync_description", ""))[:2000],
    }
    profile_path = bundle / f"{slug_id}.audio.json"
    profile_path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    asset["audio_profile"] = f"res://assets/generated/{slug_id}/{slug_id}.audio.json"
    asset["sound_mode"] = mode
    asset_path.write_text(json.dumps(asset, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"asset": slug_id, "audio_events": len(events), "audio_streams": len(streams)}))
    return profile


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    args = parser.parse_args()
    build(args.request, args.bundle)


if __name__ == "__main__":
    main()
