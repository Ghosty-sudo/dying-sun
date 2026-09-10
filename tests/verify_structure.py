from pathlib import Path

required = [
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("scenes/main.tscn"),
    Path("scripts/game.gd"),
    Path("scripts/main.gd"),
    Path("scripts/campaign_data.gd"),
    Path("scripts/game_state.gd"),
    Path("scripts/save_manager.gd"),
    Path("scripts/settings_manager.gd"),
    Path("scripts/audio_manager.gd"),
    Path("tests/state_smoke.gd"),
    Path("tests/campaign_flow_smoke.gd"),
    Path("docs/creative-charter.md"),
    Path("docs/release-standard.md"),
    Path("docs/campaign-spine.md"),
    Path("docs/combat-spec.md"),
]

missing = [str(path) for path in required if not path.exists()]
if missing:
    raise SystemExit(f"Missing required files: {', '.join(missing)}")

project = Path("project.godot").read_text(encoding="utf-8")
script = Path("scripts/game.gd").read_text(encoding="utf-8")
content = Path("scripts/campaign_data.gd").read_text(encoding="utf-8")
state = Path("scripts/game_state.gd").read_text(encoding="utf-8")
save = Path("scripts/save_manager.gd").read_text(encoding="utf-8")
settings = Path("scripts/settings_manager.gd").read_text(encoding="utf-8")
audio = Path("scripts/audio_manager.gd").read_text(encoding="utf-8")
scene = Path("scenes/main.tscn").read_text(encoding="utf-8")
exports = Path("export_presets.cfg").read_text(encoding="utf-8")
ci = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")

checks = {
    "main scene configured": 'run/main_scene="res://scenes/main.tscn"' in project,
    "scene loads campaign runtime": 'res://scripts/game.gd' in scene,
    "GameState autoload configured": 'GameState="*res://scripts/game_state.gd"' in project,
    "SaveManager autoload configured": 'SaveManager="*res://scripts/save_manager.gd"' in project,
    "SettingsManager autoload configured": 'SettingsManager="*res://scripts/settings_manager.gd"' in project,
    "AudioManager autoload configured": 'AudioManager="*res://scripts/audio_manager.gd"' in project,
    "five campaign acts present": all(name in content for name in ["ASH INTAKE", "THE MEMORY WORKS", "BLACK RELAY", "THE CROWN ENGINE", "LAST LIGHT"]),
    "five bosses present": all(name in content for name in ["GATE-CUSTODIAN", "THE-ARCHIVIST", "RELAY-SAINT", "CROWN-CUSTODIAN", "LAST-LIGHT"]),
    "Sol dialogue present": 'SOL:' in content,
    "combat present": 'perform_attack' in script,
    "checkpoint restart present": 'restart_from_checkpoint' in script,
    "parry present": 'perform_deflect' in script,
    "stagger system present": 'apply_stagger' in script and 'SYSTEM BREAK' in script,
    "boss runtime present": 'update_boss' in script and 'execute_boss_pattern' in script,
    "projectiles present": 'update_projectiles' in script and 'spawn_projectile' in script,
    "module progression present": 'module_options' in content and 'choose_module' in script and 'add_module' in state,
    "ending resolution present": 'resolve_final_ending' in script and 'ending_lines' in content,
    "title flow present": 'title_options' in script and 'start_new_game' in script and 'continue_game' in script,
    "pause flow present": 'pause_options' in script and 'draw_pause' in script,
    "settings UI present": 'draw_settings' in script and 'settings_entries' in script,
    "touch input present": 'InputEventScreenTouch' in script and 'InputEventScreenDrag' in script,
    "controller input present": 'InputEventJoypadButton' in script and 'InputEventJoypadMotion' in script,
    "relationship evidence model present": all(k in state for k in ['"trust"', '"defiance"', '"mercy"', '"pragmatism"', '"curiosity"']),
    "promise tracking present": 'remember_promise' in state and 'resolve_promise' in state,
    "ending eligibility present": 'available_endings' in state,
    "save snapshot present": 'GameState.snapshot()' in save,
    "load validation present": 'GameState.load_snapshot' in save,
    "settings persistence present": 'save_settings' in settings and 'load_settings' in settings,
    "procedural ambience present": 'build_ambience' in audio and 'LOOP_FORWARD' in audio,
    "procedural SFX present": 'build_sfx' in audio and 'play_sfx' in audio,
    "state smoke wired into CI": 'Campaign state smoke' in ci and 'state_smoke.gd' in ci,
    "full campaign smoke wired into CI": 'Full campaign branch smoke' in ci and 'campaign_flow_smoke.gd' in ci,
    "Windows export present": 'name="Windows Desktop"' in exports,
    "Web export present": 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"Structural checks failed: {', '.join(failed)}")

print("Dying Sun structure verified")
for name in checks:
    print(f"  OK: {name}")
