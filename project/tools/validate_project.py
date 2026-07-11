from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    checks.append((name, bool(condition), detail))


required = [
    "project.godot",
    "export_presets.cfg",
    "scenes/main.tscn",
    "scripts/main.gd",
    "scripts/player_controller.gd",
    "scripts/factory_generator.gd",
    "scripts/robot_agent.gd",
    "scripts/game_director.gd",
    "scripts/environment_agent.gd",
    "scripts/mobile_controls.gd",
    "scripts/destructible_panel.gd",
    "scripts/grabbable.gd",
]
for relative in required:
    check(f"required:{relative}", (ROOT / relative).is_file())

project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
export_text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
check("Jolt selected", '3d/physics_engine="Jolt Physics"' in project_text)
check("Compatibility renderer", 'renderer/rendering_method="gl_compatibility"' in project_text)
check("Web export preset", 'platform="Web"' in export_text)
check("PWA enabled", "progressive_web_app/enabled=true" in export_text)

all_text = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "scripts").glob("*.gd"))
for token in [
    "GrabbableProp",
    "DestructiblePanel",
    "EnvironmentAgent",
    "GameDirector",
    "RobotAgent",
    "MobileControls",
    "get_path",
    "repair_nearest_breach",
    "fear_profile",
    "_make_procedural_loop",
]:
    check(f"feature:{token}", token in all_text)

refs = set(re.findall(r'(?:load|preload)\("res://([^\"]+)"\)', all_text))
for ref in sorted(refs):
    check(f"resource:{ref}", (ROOT / ref).exists())

try:
    result = subprocess.run(
        ["gdlint", *[str(path) for path in sorted((ROOT / "scripts").glob("*.gd"))]],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    check("GDScript linter", result.returncode == 0, result.stdout + result.stderr)
except FileNotFoundError:
    check("GDScript linter", False, "gdlint is not installed")

passed = sum(1 for _, ok, _ in checks if ok)
print(f"Blackout Protocol validation: {passed}/{len(checks)} checks passed")
for name, ok, detail in checks:
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail.strip()}" if detail.strip() else ""))
if passed != len(checks):
    sys.exit(1)
