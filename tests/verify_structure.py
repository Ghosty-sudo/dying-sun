from pathlib import Path

required = [
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("scenes/main.tscn"),
    Path("scripts/main.gd"),
]

missing = [str(path) for path in required if not path.exists()]
if missing:
    raise SystemExit(f"Missing required files: {', '.join(missing)}")

project = Path("project.godot").read_text(encoding="utf-8")
script = Path("scripts/main.gd").read_text(encoding="utf-8")
scene = Path("scenes/main.tscn").read_text(encoding="utf-8")
exports = Path("export_presets.cfg").read_text(encoding="utf-8")

checks = {
    "main scene configured": 'run/main_scene="res://scenes/main.tscn"' in project,
    "scene loads main script": 'res://scripts/main.gd' in scene,
    "Sol encounter present": 'SOL:' in script,
    "choice memory present": 'remembered_choice' in script,
    "combat present": 'perform_attack' in script,
    "restart loop present": 'restart_run' in script,
    "Windows export present": 'name="Windows Desktop"' in exports,
    "Web export present": 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"Structural checks failed: {', '.join(failed)}")

print("Dying Sun structure verified")
for name in checks:
    print(f"  OK: {name}")
