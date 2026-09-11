from pathlib import Path

required = [
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("scenes/main.tscn"),
    Path("scripts/game.gd"),
    Path("scripts/campaign_data.gd"),
    Path("scripts/game_state.gd"),
    Path("scripts/save_manager.gd"),
    Path("scripts/settings_manager.gd"),
    Path("scripts/audio_manager.gd"),
    Path("scripts/breaker_controller.gd"),
    Path("scripts/controller_adapter.gd"),
    Path("scripts/sector_director.gd"),
    Path("scripts/act3_director.gd"),
    Path("scripts/act4_director.gd"),
    Path("scripts/crown_boost_counter.gd"),
    Path("scripts/player_path_polish.gd"),
    Path("scripts/touch_input_adapter.gd"),
    Path("tests/state_smoke.gd"),
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
    Path("tests/player_path_polish_smoke.gd"),
    Path("tests/player_path_polish_smoke.tscn"),
    Path("tests/act1_movement_smoke.gd"),
    Path("tests/act1_movement_smoke.tscn"),
    Path("tests/touch_input_smoke.gd"),
    Path("tests/touch_input_smoke.tscn"),
    Path("docs/creative-charter.md"),
    Path("docs/release-standard.md"),
    Path("docs/campaign-spine.md"),
    Path("docs/combat-spec.md"),
    Path("docs/player-path-audit.md"),
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
breaker = Path("scripts/breaker_controller.gd").read_text(encoding="utf-8")
controller = Path("scripts/controller_adapter.gd").read_text(encoding="utf-8")
sector = Path("scripts/sector_director.gd").read_text(encoding="utf-8")
act3 = Path("scripts/act3_director.gd").read_text(encoding="utf-8")
act4 = Path("scripts/act4_director.gd").read_text(encoding="utf-8")
crown_boost = Path("scripts/crown_boost_counter.gd").read_text(encoding="utf-8")
polish = Path("scripts/player_path_polish.gd").read_text(encoding="utf-8")
touch = Path("scripts/touch_input_adapter.gd").read_text(encoding="utf-8")
scene = Path("scenes/main.tscn").read_text(encoding="utf-8")
exports = Path("export_presets.cfg").read_text(encoding="utf-8")
ci = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
audit = Path("docs/player-path-audit.md").read_text(encoding="utf-8")

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
    "breaker controller present": 'perform_breaker' in breaker and 'BREAKER_COST' in breaker,
    "breaker mounted in scene": 'res://scripts/breaker_controller.gd' in scene and 'BreakerController' in scene,
    "breaker unlock gated to Act II": 'current_act) >= 2' in breaker and 'UNLOCKS ACT II' in breaker,
    "breaker uses standard shoulder mapping": 'JOY_BUTTON_LEFT_SHOULDER' in breaker,
    "breaker can disrupt authored systems": 'on_breaker_fired' in breaker and 'SectorDirector' in breaker,
    "breaker has dedicated feedback audio": all(token in audio for token in ['"breaker_charge"', '"breaker"']),
    "controller adapter mounted": 'res://scripts/controller_adapter.gd' in scene and 'ControllerAdapter' in scene,
    "controller Start and choice routing present": 'JOY_BUTTON_START' in controller and 'JOY_BUTTON_A' in controller and 'JOY_BUTTON_B' in controller,
    "touch recovery adapter mounted": 'res://scripts/touch_input_adapter.gd' in scene and 'TouchInputAdapter' in scene,
    "touch adapter supports screen drag": 'InputEventScreenDrag' in touch and 'claim_pointer' in touch,
    "touch adapter supports Web mouse fallback": 'InputEventMouseMotion' in touch and 'MOUSE_POINTER_ID' in touch,
    "touch adapter recovers lost presses": 'parent.touch_move_id < 0' in touch and 'drag.position - drag.relative' in touch,
    "authored sector director mounted": 'res://scripts/sector_director.gd' in scene and 'SectorDirector' in scene,
    "Act I sector director outruns parent progression": 'process_priority = -100' in sector,
    "Act I begins with traversal": 'sector_intake_walk' in sector and 'INTAKE_THRESHOLD_X' in sector,
    "Act I includes environmental pressure": all(token in sector for token in ['sector_furnace', 'sector_coolant', 'sector_gate_approach', 'apply_furnace_hazard', 'apply_coolant_hazard', 'apply_gate_hazard']),
    "Act I breaks three-kill repetition": 'game.enemies.size() != 2' not in sector and 'begin_gate_pressure' in sector,
    "Act II begins with Breaker traversal": all(token in sector for token in ['sector_memory_entry', 'sector_memory_seal', 'MEMORY-SEAL', 'INDEX SEAL']),
    "Act II has memory-reactive hazard": all(token in sector for token in ['sector_memory_gallery', 'apply_memory_sweep', 'memory_suppression', 'MEMORY FIELD SILENCED']),
    "Act II choice changes objective": all(token in sector for token in ['sector_archive_hold', 'sector_purge_run', 'ARCHIVE_HOLD_GOAL', 'MEMORY_EXIT_X']),
    "Act III director mounted": 'res://scripts/act3_director.gd' in scene and 'Act3Director' in scene,
    "Act III outruns generic progression": 'process_priority = -90' in act3,
    "Act III routes power instead of clearing a wave": all(token in act3 for token in ['sector_relay_entry', 'sector_relay_sync', 'RELAY_NODES', 'RELAY_HOLD_GOAL']),
    "Act III civilian route is an escort": all(token in act3 for token in ['sector_civilian_feed', 'escort_pos', 'CIVILIAN_ESCORT_RADIUS', 'civilian_feed_completed']),
    "Act III defense route actively assists combat": all(token in act3 for token in ['sector_defense_push', 'fire_defense_lattice', 'defense_lattice_powered', 'TARGET CUT']),
    "Act III consequence reaches boss state": 'LATTICE CUTS ITS SHIELD' in act3 and 'RELAY SAINT' in content,
    "Act IV director mounted": 'res://scripts/act4_director.gd' in scene and 'Act4Director' in scene,
    "Act IV adaptive boost counter mounted": 'res://scripts/crown_boost_counter.gd' in scene and 'CrownBoostCounter' in scene,
    "Act IV outruns generic progression": 'process_priority = -80' in act4,
    "Act IV recovers testimony instead of clearing a wave": all(token in act4 for token in ['sector_crown_entry', 'sector_crown_audit', 'TRUTH_NODES', 'TRUTH_HOLD_GOAL']),
    "Act IV relationship changes testimony source": all(token in act4 for token in ['relationship_value("trust")', 'relationship_value("defiance")', 'AUTHORITY: SOL']),
    "Act IV choice changes playable route": all(token in act4 for token in ['sector_record_extraction', 'sector_crown_overdrive', 'crown_record_extracted', 'crown_overdrive_crossed']),
    "Act IV records and counters combat habits": all(token in act4 for token in ['strike_uses', 'boost_uses', 'deflect_uses', 'breaker_uses', 'dominant_habit', 'crown_counter_profile']),
    "Act IV boost adaptation is telegraphed": all(token in crown_boost for token in ['LANDING TRACE', 'TELEGRAPH_TIME', 'trace_pos', 'REDIRECT']),
    "Act IV consequence reaches boss state": all(token in act4 for token in ['PROOF EXPOSED A BREAK POINT', 'SOL OVERDRIVE ONLINE', 'CROWN CUSTODIAN']),
    "Act IV has dedicated feedback audio": all(token in audio for token in ['"crown_truth"', '"crown_phase"']),
    "player-path polish mounted": 'res://scripts/player_path_polish.gd' in scene and 'PlayerPathPolish' in scene,
    "Act I-II authored objectives override vague fallback": all(token in polish for token in ['INNER SEAL', 'BREAKER REQUIRED']),
    "Act III objective source is delegated": 'Act3Director' in polish and 'objective_text' in polish and 'ROUTING SPINE' in act3,
    "Act IV objective source is delegated": 'Act4Director' in polish and 'sector_crown_audit' in polish and 'COUNTERPROFILE' in act4,
    "HUD labels armor and charge": 'ARMOR %d/%d' in polish and 'FRAME %d%%' in polish,
    "touch pause and checkpoint restart present": 'TOUCH_PAUSE_CENTER' in polish and 'TOUCH_RESTART_RECT' in polish and 'restart_checkpoint' in polish,
    "desktop hints include Breaker after unlock": 'Q/LB BREAKER' in polish,
    "maturity audit separates quality gates": all(token in audit for token in ['MACHINE-VALID', 'PLAYTEST-WORTHY', 'RELEASE-WORTHY', 'Act V']),
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
    "full campaign smoke uses project scene": 'Full campaign branch smoke' in ci and 'campaign_flow_smoke.tscn' in ci,
    "combat smoke uses project scene": 'Combat kit smoke' in ci and 'combat_smoke.tscn' in ci,
    "authored Act I smoke wired into CI": 'Authored Act I smoke' in ci and 'sector_smoke.tscn' in ci,
    "authored Act II smoke wired into CI": 'Authored Act II smoke' in ci and 'act2_sector_smoke.tscn' in ci,
    "authored Act III smoke wired into CI": 'Authored Act III smoke' in ci and 'act3_sector_smoke.tscn' in ci,
    "authored Act IV smoke wired into CI": 'Authored Act IV smoke' in ci and 'act4_sector_smoke.tscn' in ci,
    "player-path polish smoke wired into CI": 'Player-path polish smoke' in ci and 'player_path_polish_smoke.tscn' in ci,
    "Act I movement regression wired into CI": 'Act I movement regression' in ci and 'act1_movement_smoke.tscn' in ci,
    "mobile touch input smoke wired into CI": 'Mobile touch input smoke' in ci and 'touch_input_smoke.tscn' in ci,
    "Windows export present": 'name="Windows Desktop"' in exports,
    "Web export present": 'name="Web"' in exports,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit(f"Structural checks failed: {', '.join(failed)}")

print("Dying Sun structure verified")
for name in checks:
    print(f"  OK: {name}")
