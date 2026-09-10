from pathlib import Path

required = [
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("scenes/main.tscn"),
    Path("scripts/main.gd"),
    Path("scripts/game_state.gd"),
    Path("scripts/save_manager.gd"),
    Path("scripts/settings_manager.gd"),
    Path("tests/state_smoke.gd"),
    Path("docs/creative-charter.md"),
    Path("docs/release-standard.md"),
    Path("docs/campaign-spine.md"),
    Path("docs/combat-spec.md"),
]

missing = [str(path) for path in required if not path.exists()]
if missing:
    raise SystemExit(f"Missing required files: {', '.join(missing)}")

project = Path("project.godot").read_text(encoding="utf-8")
script = Path("scripts/main.gd").read_text(encoding="utf-8")
state = Path("scripts/game_state.gd").read_text(encoding="utf-8")
save = Path("scripts/save_manager.gd").read_text(encoding="utf-8")
settings = Path("scripts/settings_manager.gd").read_text(encoding="utf-8")
scene = Path("scenes/main.tscn").read_text(encoding="utf-8")
exports = Path("export_presets.cfg").read_text(encoding="utf-8")
ci = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")

checks = {
    "main scene configured": 'run/main_scene="res://scenes/main.tscn"' in project,
    "scene loads main script": 'res://scripts/main.gd' in scene,
    "GameState autoload configured": 'GameState="*res://scripts/game_state.gd"' in project,
    "SaveManager autoload configured": 'SaveManager="*res://scripts/save_manager.gd"' in project,
    "SettingsManager autoload configured": 'SettingsManager="*res://scripts/settings_manager.gd"' in project,
    "Sol encounter present": 'SOL:' in script,
    "prototype choice memory present": 'remembered_choice' in script,
    "combat present": 'perform_attack' in script,
    "checkpoint restart present": 'restart_from_checkpoint' in script,
    "parry present": 'perform_deflect' in script,
    "stagger system present": 'apply_stagger' in script and 'SYSTEM BREAK' in script,
    "boss present": 'CUSTODIAN' in script and 'spawn_gate_custodian' in script,
    "projectiles present": 'update_projectiles' in script and 'spawn_projectile' in script,
    "touch input present": 'InputEventScreenTouch' in script and 'InputEventScreenDrag' in script,
    "virtual stick present": 'touch_move' in script and 'TOUCH_STICK_RADIUS' in script,
    "touch attack present": 'TOUCH_ATTACK_CENTER' in script,
    "touch boost present": 'TOUCH_BOOST_CENTER' in script,
    "touch dialogue choice present": 'choose_path(1 if pos.x < 320.0 else 2)' in script,
    "relationship evidence model present": all(k in state for k in ['"trust"', '"defiance"', '"mercy"', '"pragmatism"', '"curiosity"']),
    "promise tracking present": 'remember_promise' in state and 'resolve_promise' in state,
    "ending eligibility present": 'available_endings' in state,
    "save snapshot present": 'GameState.snapshot()' in save,
    "load validation present": 'GameState.load_snapshot' in save,
    "settings persistence present": 'save_settings' in settings and 'load_settings' in settings,
    "display settings present": 'toggle_fullscreen' in settings,
    "state smoke wired into CI": 'Campaign state smoke' in ci and 'state_smoke.gd' in ci,
    "Windows export present": 'name="Windows Desktop"' in exports,
    "Web export present": 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"Structural checks failed: {', '.join(failed)}")

print("Dying Sun structure verified")
for name in checks:
    print(f"  OK: {name}")
