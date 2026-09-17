from pathlib import Path

required = [
    "project.godot", "export_presets.cfg", "scenes/main.tscn",
    "scripts/game.gd", "scripts/input_router.gd", "scripts/campaign_data.gd",
    "scripts/game_state.gd", "scripts/save_manager.gd", "scripts/settings_manager.gd",
    "scripts/audio_manager.gd", "scripts/breaker_controller.gd", "scripts/sector_director.gd",
    "scripts/act3_director.gd", "scripts/act4_director.gd", "scripts/act5_director.gd",
    "scripts/crown_boost_counter.gd", "scripts/melee_contact_guard.gd",
    "scripts/player_path_polish.gd", "scripts/presentation_polish.gd",
    "tests/state_smoke.gd", "tests/save_recovery_smoke.gd", "tests/save_recovery_smoke.tscn",
    "tests/desktop_input_smoke.gd", "tests/desktop_input_smoke.tscn",
    "tests/campaign_flow_smoke.tscn", "tests/combat_smoke.tscn", "tests/sector_smoke.tscn",
    "tests/act2_sector_smoke.tscn", "tests/act3_sector_smoke.tscn",
    "tests/act4_sector_smoke.tscn", "tests/act5_sector_smoke.tscn",
    "tests/act1_movement_smoke.tscn", "tests/touch_input_smoke.tscn",
    "tests/web_stability_smoke.tscn", "tests/player_path_polish_smoke.tscn",
    "tests/opening_playtest.tscn", "docs/core-runtime.md", "docs/player-path-audit.md",
]

missing = [path for path in required if not Path(path).exists()]
if missing:
    raise SystemExit("Missing required files: " + ", ".join(missing))

retired = ["scripts/controller_adapter.gd", "scripts/touch_input_adapter.gd"]
retired_present = [path for path in retired if Path(path).exists()]
if retired_present:
    raise SystemExit("Retired competing input adapters still present: " + ", ".join(retired_present))

read = lambda path: Path(path).read_text(encoding="utf-8")
project = read("project.godot")
scene = read("scenes/main.tscn")
game = read("scripts/game.gd")
router = read("scripts/input_router.gd")
breaker = read("scripts/breaker_controller.gd")
polish = read("scripts/player_path_polish.gd")
save = read("scripts/save_manager.gd")
state = read("scripts/game_state.gd")
content = read("scripts/campaign_data.gd")
sector = read("scripts/sector_director.gd")
act3 = read("scripts/act3_director.gd")
act4 = read("scripts/act4_director.gd")
act5 = read("scripts/act5_director.gd")
melee = read("scripts/melee_contact_guard.gd")
audio = read("scripts/audio_manager.gd")
ci = read(".github/workflows/ci.yml")
core_doc = read("docs/core-runtime.md")
audit = read("docs/player-path-audit.md")
exports = read("export_presets.cfg")

checks = {
    "main scene configured": 'run/main_scene="res://scenes/main.tscn"' in project,
    "autoloads configured": all(token in project for token in [
        'GameState="*res://scripts/game_state.gd"',
        'SaveManager="*res://scripts/save_manager.gd"',
        'SettingsManager="*res://scripts/settings_manager.gd"',
        'AudioManager="*res://scripts/audio_manager.gd"',
    ]),
    "InputRouter is mounted": 'res://scripts/input_router.gd' in scene and 'InputRouter' in scene,
    "legacy input adapters are unmounted": all(token not in scene for token in ["ControllerAdapter", "TouchInputAdapter", "controller_adapter.gd", "touch_input_adapter.gd"]),
    "router disables legacy parent callbacks": 'parent.set_process_input(false)' in router and 'parent.set_process_unhandled_key_input(false)' in router,
    "router owns touch movement": all(token in router for token in ["InputEventScreenTouch", "InputEventScreenDrag", "claim_movement_pointer", "update_movement_vector"]),
    "router owns Web fallback": all(token in router for token in ["InputEventMouseButton", "InputEventMouseMotion", "MOUSE_POINTER_ID", "screen_stream_recent"]),
    "router blocks action/secondary finger takeover": all(token in router for token in ["blocked_drag_ids", "can_recover_drag", "RELEASE_RECOVERY_GUARD_MS", "TRANSIENT_RECOVERY_GUARD_MS"]),
    "router clears transient state": all(token in router for token in ["NOTIFICATION_APPLICATION_FOCUS_OUT", "cancel_transient_input", "clear_movement_authority"]),
    "router owns pause/restart": all(token in router for token in ["TOUCH_PAUSE_CENTER", "TOUCH_RESTART_RECT", "set_paused", "restart_checkpoint"]),
    "router owns keyboard/controller/Breaker bindings": all(token in router for token in ["KEY_Q", "JOY_BUTTON_START", "JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y", "JOY_BUTTON_LEFT_SHOULDER"]),
    "BreakerController is action-only": all(token in breaker for token in ["func begin_charge", "func release_charge", "func perform_breaker"]) and "func _input" not in breaker,
    "PlayerPathPolish is presentation-only": "func _input" not in polish and "draw_touch_pause" in polish and "draw_restart_affordance" in polish,
    "save temp/backup recovery exists": all(token in save for token in ["SAVE_TEMP_PATH", "SAVE_BACKUP_PATH", "rename_absolute", "_load_from_path(SAVE_BACKUP_PATH)", "Recovered Dying Sun campaign from backup"]),
    "campaign state remains serializable": "GameState.snapshot()" in save and "GameState.load_snapshot" in save and "available_endings" in state,
    "five acts remain authored": all(token in content for token in ["ASH INTAKE", "THE MEMORY WORKS", "BLACK RELAY", "THE CROWN ENGINE", "LAST LIGHT"]),
    "core combat remains intact": all(token in game for token in ["perform_attack", "perform_boost", "perform_deflect", "apply_stagger", "update_projectiles", "update_boss"]),
    "melee contact guard remains mounted": "MeleeContactGuard" in scene and "CONTACT" in melee,
    "Act I-II director remains mounted": "SectorDirector" in scene and "sector_intake_walk" in sector and "sector_memory_seal" in sector,
    "Act III director remains mounted": "Act3Director" in scene and "sector_relay_sync" in act3,
    "Act IV director remains mounted": "Act4Director" in scene and "crown_counter_profile" in act4,
    "Act V director remains mounted": "Act5Director" in scene and all(token in act5 for token in ["LAST LIGHT", "STAY", "SEVER"]),
    "presentation/audio retained without expansion dependency": "PlayerPathPolish" in scene and "PresentationPolish" in scene and "build_ambience" in audio and "play_sfx" in audio,
    "core runtime ownership documented": "one physical input owner" in core_doc and "Art and audio are intentionally not the focus" in core_doc,
    "quality gates remain separated": all(token in audit for token in ["MACHINE-VALID", "PLAYTEST-WORTHY", "RELEASE-WORTHY"]),
    "save recovery smoke is CI-gated": "Save recovery smoke" in ci and "save_recovery_smoke.tscn" in ci,
    "desktop input smoke is CI-gated": "Desktop input routing smoke" in ci and "desktop_input_smoke.tscn" in ci,
    "touch input regressions are CI-gated": "Act I movement regression" in ci and "Mobile touch input smoke" in ci,
    "campaign and stability gates remain CI-gated": all(token in ci for token in ["Full campaign branch smoke", "Authored Act V smoke", "Accelerated Web stability smoke", "Scripted opening playtest"]),
    "Windows and Web exports remain configured": 'name="Windows Desktop"' in exports and 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("Structural checks failed: " + ", ".join(failed))

print("Dying Sun structure verified")
for name in checks:
    print("  OK: " + name)
