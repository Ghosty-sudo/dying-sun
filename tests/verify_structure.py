from pathlib import Path

required = [
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("scenes/main.tscn"),
    Path("scripts/game.gd"),
    Path("scripts/input_router.gd"),
    Path("scripts/campaign_data.gd"),
    Path("scripts/game_state.gd"),
    Path("scripts/save_manager.gd"),
    Path("scripts/settings_manager.gd"),
    Path("scripts/audio_manager.gd"),
    Path("scripts/breaker_controller.gd"),
    Path("scripts/sector_director.gd"),
    Path("scripts/act3_director.gd"),
    Path("scripts/act4_director.gd"),
    Path("scripts/act5_director.gd"),
    Path("scripts/crown_boost_counter.gd"),
    Path("scripts/melee_contact_guard.gd"),
    Path("scripts/player_path_polish.gd"),
    Path("scripts/presentation_polish.gd"),
    Path("tests/state_smoke.gd"),
    Path("tests/save_recovery_smoke.gd"),
    Path("tests/campaign_flow_smoke.gd"),
    Path("tests/campaign_flow_smoke.tscn"),
    Path("tests/combat_smoke.gd"),
    Path("tests/combat_smoke.tscn"),
    Path("tests/sector_smoke.gd"),
    Path("tests/sector_smoke.tscn"),
    Path("tests/act2_sector_smoke.gd"),
    Path("tests/act2_sector_smoke.tscn"),
    Path("tests/act3_sector_smoke.gd"),
    Path("tests/act3_sector_smoke.tscn"),
    Path("tests/act4_sector_smoke.gd"),
    Path("tests/act4_sector_smoke.tscn"),
    Path("tests/act5_sector_smoke.gd"),
    Path("tests/act5_sector_smoke.tscn"),
    Path("tests/player_path_polish_smoke.gd"),
    Path("tests/player_path_polish_smoke.tscn"),
    Path("tests/act1_movement_smoke.gd"),
    Path("tests/act1_movement_smoke.tscn"),
    Path("tests/touch_input_smoke.gd"),
    Path("tests/touch_input_smoke.tscn"),
    Path("tests/web_stability_smoke.gd"),
    Path("tests/web_stability_smoke.tscn"),
    Path("tests/opening_playtest.gd"),
    Path("tests/opening_playtest.tscn"),
    Path("docs/creative-charter.md"),
    Path("docs/release-standard.md"),
    Path("docs/campaign-spine.md"),
    Path("docs/combat-spec.md"),
    Path("docs/player-path-audit.md"),
    Path("docs/core-runtime.md"),
]

missing = [str(path) for path in required if not path.exists()]
if missing:
    raise SystemExit(f"Missing required files: {', '.join(missing)}")

retired = [
    Path("scripts/controller_adapter.gd"),
    Path("scripts/touch_input_adapter.gd"),
]
retired_present = [str(path) for path in retired if path.exists()]
if retired_present:
    raise SystemExit(f"Retired competing input adapters still present: {', '.join(retired_present)}")

project = Path("project.godot").read_text(encoding="utf-8")
script = Path("scripts/game.gd").read_text(encoding="utf-8")
input_router = Path("scripts/input_router.gd").read_text(encoding="utf-8")
content = Path("scripts/campaign_data.gd").read_text(encoding="utf-8")
state = Path("scripts/game_state.gd").read_text(encoding="utf-8")
save = Path("scripts/save_manager.gd").read_text(encoding="utf-8")
settings = Path("scripts/settings_manager.gd").read_text(encoding="utf-8")
audio = Path("scripts/audio_manager.gd").read_text(encoding="utf-8")
breaker = Path("scripts/breaker_controller.gd").read_text(encoding="utf-8")
sector = Path("scripts/sector_director.gd").read_text(encoding="utf-8")
act3 = Path("scripts/act3_director.gd").read_text(encoding="utf-8")
act4 = Path("scripts/act4_director.gd").read_text(encoding="utf-8")
act5 = Path("scripts/act5_director.gd").read_text(encoding="utf-8")
crown_boost = Path("scripts/crown_boost_counter.gd").read_text(encoding="utf-8")
melee_guard = Path("scripts/melee_contact_guard.gd").read_text(encoding="utf-8")
polish = Path("scripts/player_path_polish.gd").read_text(encoding="utf-8")
presentation = Path("scripts/presentation_polish.gd").read_text(encoding="utf-8")
scene = Path("scenes/main.tscn").read_text(encoding="utf-8")
exports = Path("export_presets.cfg").read_text(encoding="utf-8")
ci = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
audit = Path("docs/player-path-audit.md").read_text(encoding="utf-8")
core_runtime = Path("docs/core-runtime.md").read_text(encoding="utf-8")

checks = {
    "main scene configured": 'run/main_scene="res://scenes/main.tscn"' in project,
    "scene loads campaign runtime": 'res://scripts/game.gd' in scene,
    "GameState autoload configured": 'GameState="*res://scripts/game_state.gd"' in project,
    "SaveManager autoload configured": 'SaveManager="*res://scripts/save_manager.gd"' in project,
    "SettingsManager autoload configured": 'SettingsManager="*res://scripts/settings_manager.gd"' in project,
    "AudioManager autoload configured": 'AudioManager="*res://scripts/audio_manager.gd"' in project,

    # Core framework: one physical input owner, separate gameplay/action owners.
    "InputRouter mounted": 'res://scripts/input_router.gd' in scene and 'InputRouter' in scene,
    "legacy controller adapter unmounted": 'ControllerAdapter' not in scene and 'controller_adapter.gd' not in scene,
    "legacy touch adapter unmounted": 'TouchInputAdapter' not in scene and 'touch_input_adapter.gd' not in scene,
    "router disables legacy parent callbacks": all(token in input_router for token in ['parent.set_process_input(false)', 'parent.set_process_unhandled_key_input(false)']),
    "router owns screen touch and drag": all(token in input_router for token in ['InputEventScreenTouch', 'InputEventScreenDrag', 'claim_movement_pointer', 'update_movement_vector']),
    "router owns Web mouse fallback": all(token in input_router for token in ['InputEventMouseButton', 'InputEventMouseMotion', 'MOUSE_POINTER_ID', 'screen_stream_recent']),
    "router blocks action fingers from movement recovery": all(token in input_router for token in ['blocked_drag_ids', 'can_recover_drag', 'blocked_drag_ids[pointer_id] = true']),
    "router guards released pointer recovery": all(token in input_router for token in ['last_released_screen_id', 'last_release_ms', 'RELEASE_RECOVERY_GUARD_MS']),
    "router clears focus/transient input": all(token in input_router for token in ['NOTIFICATION_APPLICATION_FOCUS_OUT', 'cancel_transient_input', 'clear_movement_authority']),
    "router owns pause and restart": all(token in input_router for token in ['TOUCH_PAUSE_CENTER', 'TOUCH_RESTART_RECT', 'set_paused', 'restart_checkpoint']),
    "router owns controller actions and navigation": all(token in input_router for token in ['JOY_BUTTON_START', 'JOY_BUTTON_A', 'JOY_BUTTON_B', 'JOY_BUTTON_X', 'JOY_BUTTON_Y', 'JOY_BUTTON_DPAD_UP', 'JOY_BUTTON_DPAD_DOWN']),
    "router owns Breaker physical bindings": 'KEY_Q' in input_router and 'JOY_BUTTON_LEFT_SHOULDER' in input_router and 'TOUCH_BREAKER_CENTER' in input_router,
    "Breaker controller is action-only": 'func begin_charge' in breaker and 'func release_charge' in breaker and 'func perform_breaker' in breaker and 'func _input' not in breaker,
    "PlayerPathPolish is presentation-only": 'func _input' not in polish and 'draw_touch_pause' in polish and 'draw_restart_affordance' in polish,

    # Core state/recovery.
    "save snapshot present": 'GameState.snapshot()' in save,
    "load validation present": 'GameState.load_snapshot' in save,
    "save uses temp promotion": all(token in save for token in ['SAVE_TEMP_PATH', 'rename_absolute', '_remove_if_present(SAVE_PATH)']),
    "save preserves recoverable backup": all(token in save for token in ['SAVE_BACKUP_PATH', 'Recovered Dying Sun campaign from backup', '_load_from_path(SAVE_BACKUP_PATH)']),
    "save recovery avoids corrupt-backup overwrite": '_remove_if_present(SAVE_PATH)' in save and 'if not save_campaign()' in save,
    "relationship evidence model present": all(k in state for k in ['"trust"', '"defiance"', '"mercy"', '"pragmatism"', '"curiosity"']),
    "promise tracking present": 'remember_promise' in state and 'resolve_promise' in state,
    "ending eligibility present": 'available_endings' in state,
    "settings persistence present": 'save_settings' in settings and 'load_settings' in settings,

    # Campaign/core combat remains intact after framework rebuild.
    "five campaign acts present": all(name in content for name in ["ASH INTAKE", "THE MEMORY WORKS", "BLACK RELAY", "THE CROWN ENGINE", "LAST LIGHT"]),
    "five bosses present": all(name in content for name in ["GATE-CUSTODIAN", "THE-ARCHIVIST", "RELAY-SAINT", "CROWN-CUSTODIAN", "LAST-LIGHT"]),
    "Sol dialogue present": 'SOL:' in content,
    "combat present": 'perform_attack' in script and 'perform_boost' in script and 'perform_deflect' in script,
    "checkpoint restart present": 'restart_from_checkpoint' in script,
    "stagger system present": 'apply_stagger' in script and 'SYSTEM BREAK' in script,
    "boss runtime present": 'update_boss' in script and 'execute_boss_pattern' in script,
    "projectiles present": 'update_projectiles' in script and 'spawn_projectile' in script,
    "melee contact guard mounted": 'res://scripts/melee_contact_guard.gd' in scene and 'MeleeContactGuard' in scene and 'CONTACT' in melee_guard,
    "breaker mounted in scene": 'res://scripts/breaker_controller.gd' in scene and 'BreakerController' in scene,
    "breaker unlock gated to Act II": 'current_act) >= 2' in breaker,
    "breaker can disrupt authored systems": 'on_breaker_fired' in breaker and 'SectorDirector' in breaker,
    "module progression present": 'module_options' in content and 'choose_module' in script and 'add_module' in state,
    "ending resolution present": 'resolve_final_ending' in script and 'ending_lines' in content,
    "title flow present": 'title_options' in script and 'start_new_game' in script and 'continue_game' in script,
    "pause flow present": 'pause_options' in script and 'draw_pause' in script,
    "settings UI present": 'draw_settings' in script and 'settings_entries' in script,

    # Authored act framework remains mounted and distinct.
    "Act I-II sector director mounted": 'res://scripts/sector_director.gd' in scene and 'SectorDirector' in scene,
    "Act I sector director outruns parent progression": 'process_priority = -100' in sector,
    "Act I begins with traversal": 'sector_intake_walk' in sector and 'INTAKE_THRESHOLD_X' in sector,
    "Act I includes environmental pressure": all(token in sector for token in ['sector_furnace', 'sector_coolant', 'sector_gate_approach', 'apply_furnace_hazard', 'apply_coolant_hazard', 'apply_gate_hazard']),
    "Act II begins with Breaker traversal": all(token in sector for token in ['sector_memory_entry', 'sector_memory_seal', 'MEMORY-SEAL', 'INDEX SEAL']),
    "Act II has memory-reactive hazard": all(token in sector for token in ['sector_memory_gallery', 'apply_memory_sweep', 'memory_suppression']),
    "Act II choice changes objective": all(token in sector for token in ['sector_archive_hold', 'sector_purge_run', 'ARCHIVE_HOLD_GOAL', 'MEMORY_EXIT_X']),
    "Act III director mounted": 'res://scripts/act3_director.gd' in scene and 'Act3Director' in scene,
    "Act III routes power instead of generic clear": all(token in act3 for token in ['sector_relay_entry', 'sector_relay_sync', 'RELAY_NODES']),
    "Act III route consequence exists": all(token in act3 for token in ['sector_civilian_feed', 'sector_defense_push']),
    "Act IV director mounted": 'res://scripts/act4_director.gd' in scene and 'Act4Director' in scene,
    "Act IV adaptive boost counter mounted": 'res://scripts/crown_boost_counter.gd' in scene and 'CrownBoostCounter' in scene,
    "Act IV choice and adaptation remain authored": all(token in act4 for token in ['sector_record_extraction', 'sector_crown_overdrive', 'dominant_habit', 'crown_counter_profile']),
    "Act IV boost adaptation is telegraphed": all(token in crown_boost for token in ['LANDING TRACE', 'TELEGRAPH_TIME', 'REDIRECT']),
    "Act V director mounted": 'res://scripts/act5_director.gd' in scene and 'Act5Director' in scene,
    "Act V authored finale remains active": all(token in act5 for token in ['LAST LIGHT', 'STAY', 'SEVER']),

    # Presentation/audio exist but are deliberately not the focus of this pass.
    "player-path polish mounted": 'res://scripts/player_path_polish.gd' in scene and 'PlayerPathPolish' in scene,
    "presentation layer mounted": 'res://scripts/presentation_polish.gd' in scene and 'PresentationPolish' in scene and len(presentation) > 100,
    "HUD labels armor and charge": 'ARMOR %d/%d' in polish and 'FRAME %d%%' in polish,
    "desktop hints include Breaker after unlock": 'Q/LB BREAKER' in polish,
    "procedural ambience remains available": 'build_ambience' in audio and 'LOOP_FORWARD' in audio,
    "procedural SFX remains available": 'build_sfx' in audio and 'play_sfx' in audio,
    "maturity audit separates quality gates": all(token in audit for token in ['MACHINE-VALID', 'PLAYTEST-WORTHY', 'RELEASE-WORTHY', 'Act V']),
    "core runtime doc states input ownership": 'InputRouter' in core_runtime and 'one physical input owner' in core_runtime,
    "core runtime doc preserves art/audio scope": 'Art and audio are intentionally not the focus' in core_runtime,

    # Machine gates.
    "state smoke wired into CI": 'Campaign state smoke' in ci and 'state_smoke.gd' in ci,
    "save recovery smoke wired into CI": 'Save recovery smoke' in ci and 'save_recovery_smoke.gd' in ci,
    "full campaign smoke uses project scene": 'Full campaign branch smoke' in ci and 'campaign_flow_smoke.tscn' in ci,
    "combat smoke uses project scene": 'Combat kit smoke' in ci and 'combat_smoke.tscn' in ci,
    "authored Act I smoke wired into CI": 'Authored Act I smoke' in ci and 'sector_smoke.tscn' in ci,
    "authored Act II smoke wired into CI": 'Authored Act II smoke' in ci and 'act2_sector_smoke.tscn' in ci,
    "authored Act III smoke wired into CI": 'Authored Act III smoke' in ci and 'act3_sector_smoke.tscn' in ci,
    "authored Act IV smoke wired into CI": 'Authored Act IV smoke' in ci and 'act4_sector_smoke.tscn' in ci,
    "authored Act V smoke wired into CI": 'Authored Act V smoke' in ci and 'act5_sector_smoke.tscn' in ci,
    "player-path polish smoke wired into CI": 'Player-path polish smoke' in ci and 'player_path_polish_smoke.tscn' in ci,
    "Act I movement regression wired into CI": 'Act I movement regression' in ci and 'act1_movement_smoke.tscn' in ci,
    "mobile touch input smoke wired into CI": 'Mobile touch input smoke' in ci and 'touch_input_smoke.tscn' in ci,
    "Web stability smoke wired into CI": 'Accelerated Web stability smoke' in ci and 'web_stability_smoke.tscn' in ci,
    "Windows export present": 'name="Windows Desktop"' in exports,
    "Web export present": 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"Structural checks failed: {', '.join(failed)}")

print("Dying Sun structure verified")
for name in checks:
    print(f"  OK: {name}")
