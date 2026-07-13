#!/usr/bin/env python3
"""Build lightweight Act I GLB assets from the validated concept language.

This deterministic fallback runs on a standard GitHub runner. It guarantees that
Blackout Protocol has small, original, Web-safe low-poly assets while the local
TripoSR inbox remains available for higher-detail image-to-3D iterations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix, translation_matrix

PALETTE: dict[str, tuple[int, int, int, int]] = {
    "steel": (48, 56, 58, 255),
    "dark": (19, 27, 30, 255),
    "black": (7, 11, 13, 255),
    "trim": (115, 125, 122, 255),
    "cyan": (16, 145, 158, 255),
    "green": (32, 177, 145, 255),
    "red": (211, 59, 32, 255),
    "amber": (208, 143, 45, 255),
    "brown": (109, 76, 49, 255),
    "glass": (130, 202, 207, 255),
}


def color_mesh(mesh: trimesh.Trimesh, color: str) -> trimesh.Trimesh:
    rgba = np.asarray(PALETTE[color], dtype=np.uint8)
    mesh.visual.face_colors = np.tile(rgba, (len(mesh.faces), 1))
    return mesh


def add_box(
    scene: trimesh.Scene,
    name: str,
    size: tuple[float, float, float],
    position: tuple[float, float, float],
    color: str,
    rotation: tuple[list[float], float] | None = None,
) -> None:
    mesh = color_mesh(trimesh.creation.box(extents=size), color)
    transform = translation_matrix(position)
    if rotation:
        axis, angle = rotation
        transform = transform @ rotation_matrix(angle, axis)
    scene.add_geometry(mesh, node_name=name, geom_name=name, transform=transform)


def add_cylinder(
    scene: trimesh.Scene,
    name: str,
    radius: float,
    height: float,
    position: tuple[float, float, float],
    color: str,
    sections: int = 8,
    axis: str = "z",
) -> None:
    mesh = color_mesh(
        trimesh.creation.cylinder(radius=radius, height=height, sections=sections),
        color,
    )
    transform = translation_matrix(position)
    if axis == "x":
        transform = transform @ rotation_matrix(np.pi / 2.0, [0, 1, 0])
    elif axis == "y":
        transform = transform @ rotation_matrix(np.pi / 2.0, [1, 0, 0])
    scene.add_geometry(mesh, node_name=name, geom_name=name, transform=transform)


def service_access() -> trimesh.Scene:
    scene = trimesh.Scene()
    add_box(scene, "DoorSlab", (2.72, 0.24, 3.30), (0, 0, 1.65), "steel")
    add_box(scene, "DoorInset", (2.20, 0.08, 2.68), (0, -0.16, 1.62), "dark")
    for index, x_value in enumerate((-0.82, -0.28, 0.28, 0.82)):
        add_box(scene, f"Rib{index}", (0.08, 0.10, 2.48), (x_value, -0.23, 1.62), "trim")
    add_box(scene, "CenterSeam", (0.08, 0.10, 2.72), (0, -0.25, 1.64), "black")
    for index, x_value in enumerate(np.linspace(-1.0, 1.0, 6)):
        add_box(
            scene,
            f"Hazard{index}",
            (0.28, 0.04, 0.18),
            (float(x_value), -0.28, 0.18),
            "amber" if index % 2 == 0 else "black",
            ([0, 1, 0], -0.35),
        )
    add_box(scene, "BadgeReader", (0.24, 0.10, 0.54), (1.08, -0.25, 1.62), "dark")
    add_box(scene, "BadgeScreen", (0.12, 0.03, 0.14), (1.08, -0.31, 1.78), "cyan")
    add_cylinder(scene, "BadgeAlarm", 0.035, 0.035, (1.08, -0.32, 1.47), "red", axis="y")
    return scene


def blast_door() -> trimesh.Scene:
    scene = trimesh.Scene()
    add_box(scene, "BlastSlab", (2.72, 0.30, 3.30), (0, 0, 1.65), "dark")
    add_box(scene, "BlastInset", (2.30, 0.10, 2.76), (0, -0.20, 1.65), "steel")
    add_box(scene, "BlastCore", (1.76, 0.08, 2.18), (0, -0.27, 1.66), "steel")
    add_box(scene, "CenterLock", (0.12, 0.11, 2.35), (0, -0.34, 1.66), "black")
    for index, (x_value, z_value) in enumerate(((-1.04, 0.32), (1.04, 0.32), (-1.04, 2.98), (1.04, 2.98))):
        add_cylinder(scene, f"Bolt{index}", 0.09, 0.07, (x_value, -0.34, z_value), "trim", axis="y")
    for index, x_value in enumerate(np.linspace(-1.05, 1.05, 7)):
        add_box(
            scene,
            f"Hazard{index}",
            (0.24, 0.04, 0.17),
            (float(x_value), -0.36, 0.17),
            "amber" if index % 2 == 0 else "black",
            ([0, 1, 0], -0.30),
        )
    add_box(scene, "ControlHousing", (0.27, 0.12, 0.62), (1.08, -0.33, 1.61), "dark")
    add_box(scene, "ControlCRT", (0.15, 0.03, 0.16), (1.08, -0.41, 1.79), "cyan")
    add_cylinder(scene, "ControlAlarm", 0.04, 0.035, (1.08, -0.42, 1.46), "red", axis="y")
    return scene


def sentinel_console() -> trimesh.Scene:
    scene = trimesh.Scene()
    add_box(scene, "ConsoleBase", (2.30, 0.86, 0.75), (0, 0, 0.375), "dark")
    add_box(scene, "ConsoleTop", (2.16, 0.72, 0.16), (0, -0.04, 0.82), "steel", ([1, 0, 0], -0.22))
    for index, x_value in enumerate((-0.72, 0.0, 0.72)):
        add_box(scene, f"CRTFrame{index}", (0.58, 0.12, 0.44), (x_value, -0.35, 1.08), "steel", ([1, 0, 0], -0.18))
        add_box(scene, f"CRTGlow{index}", (0.46, 0.03, 0.32), (x_value, -0.42, 1.08), "green" if index == 1 else "cyan", ([1, 0, 0], -0.18))
    for row, z_value in enumerate((0.72, 0.60, 0.48)):
        for column, x_value in enumerate(np.linspace(-0.82, 0.82, 6)):
            color = "amber" if (row + column) % 7 == 0 else ("red" if row == 0 and column == 5 else "trim")
            add_box(scene, f"Key{row}_{column}", (0.18, 0.12, 0.055), (float(x_value), -0.49, z_value), color, ([1, 0, 0], -0.18))
    add_box(scene, "LowerPanel", (1.70, 0.05, 0.18), (0, -0.44, 0.24), "steel")
    add_cylinder(scene, "EmergencyStop", 0.08, 0.06, (-0.76, -0.49, 0.25), "red", sections=10, axis="y")
    return scene


def fps_flashlight() -> trimesh.Scene:
    scene = trimesh.Scene()
    add_cylinder(scene, "FlashBody", 0.075, 0.42, (0, 0, 0.22), "dark", sections=6)
    add_cylinder(scene, "FlashHead", 0.13, 0.16, (0, 0, 0.51), "steel", sections=6)
    add_cylinder(scene, "Lens", 0.105, 0.025, (0, 0, 0.605), "glass", sections=12)
    for index in range(6):
        angle = 2.0 * np.pi * index / 6.0
        add_box(
            scene,
            f"GripRib{index}",
            (0.025, 0.04, 0.28),
            (0.08 * np.cos(angle), 0.08 * np.sin(angle), 0.20),
            "black",
            ([0, 0, 1], angle),
        )
    add_box(scene, "Switch", (0.08, 0.055, 0.06), (0, -0.085, 0.36), "red")
    add_box(scene, "HandBlock", (0.19, 0.17, 0.24), (0.04, 0.08, 0.02), "brown")
    return scene


def wall_module() -> trimesh.Scene:
    scene = trimesh.Scene()
    add_box(scene, "WallBase", (3.0, 0.22, 3.2), (0, 0, 1.6), "steel")
    for row, z_value in enumerate((0.72, 1.62, 2.52)):
        for column, x_value in enumerate((-1.0, 0.0, 1.0)):
            add_box(scene, f"Panel{row}_{column}", (0.82, 0.08, 0.70), (x_value, -0.16, z_value), "dark")
    add_box(scene, "TopSign", (1.8, 0.08, 0.34), (-0.38, -0.17, 2.94), "black")
    add_box(scene, "SignAmber", (1.48, 0.025, 0.10), (-0.38, -0.225, 3.00), "amber")
    for index, x_value in enumerate((0.96, 1.19)):
        add_cylinder(scene, f"Pipe{index}", 0.055, 2.68, (x_value, -0.24, 1.64), "red" if index == 0 else "cyan")
        add_cylinder(scene, f"PipeCap{index}", 0.085, 0.08, (x_value, -0.24, 0.28), "trim")
    for index, x_value in enumerate(np.linspace(-1.25, 1.25, 7)):
        add_box(
            scene,
            f"WallHazard{index}",
            (0.25, 0.04, 0.16),
            (float(x_value), -0.22, 0.15),
            "amber" if index % 2 == 0 else "black",
            ([0, 1, 0], -0.30),
        )
    return scene


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def export_asset(scene: trimesh.Scene, path: Path, max_faces: int) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(scene.export(file_type="glb"))
    loaded = trimesh.load(path, force="scene")
    if not isinstance(loaded, trimesh.Scene) or not loaded.geometry:
        raise RuntimeError(f"Invalid GLB scene: {path}")
    faces = sum(len(geometry.faces) for geometry in loaded.geometry.values())
    vertices = sum(len(geometry.vertices) for geometry in loaded.geometry.values())
    if faces <= 0 or faces > max_faces:
        raise RuntimeError(f"Face budget failed for {path}: {faces}/{max_faces}")
    if path.stat().st_size > 2 * 1024 * 1024:
        raise RuntimeError(f"Web size budget failed for {path}")
    return {
        "path": path.as_posix(),
        "bytes": path.stat().st_size,
        "faces": faces,
        "vertices": vertices,
        "bounds": np.asarray(loaded.bounds).round(5).tolist(),
        "sha256": sha256(path),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("assets/production"))
    args = parser.parse_args()
    assets = (
        (service_access(), args.root / "act1" / "service_access.glb", 8000),
        (blast_door(), args.root / "act1" / "s01_blast_door.glb", 9000),
        (sentinel_console(), args.root / "act1" / "sentinel_console.glb", 7000),
        (fps_flashlight(), args.root / "act1" / "fps_flashlight.glb", 4000),
        (wall_module(), args.root / "environment" / "industrial_wall_module_a.glb", 6000),
    )
    results = [export_asset(scene, path, budget) for scene, path, budget in assets]
    catalog = args.root / "baseline-catalog.json"
    catalog.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
