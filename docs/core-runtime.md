# Dying Sun — Core Runtime Framework

Last reconciled: 2026-09-15

This document defines the current runtime ownership model for controls and core gameplay reliability. It exists to prevent later features from reintroducing competing input/state owners.

## Current priority

This pass is about **controls, state integrity, recovery, and core gameplay behavior**.

Art and audio are intentionally not the focus of this pass. Existing presentation and procedural audio stay in place unless a core-function defect requires a change. Visual/audio expansion comes after the input and campaign runtime have earned real-device trust.

## One physical input owner

`InputRouter` is the **one physical input owner** for the live game scene.

It receives and reconciles:
- keyboard action/navigation events;
- controller buttons and menu navigation;
- screen touch and drag;
- the Web mouse-compatible fallback emitted by some touch/browser paths;
- pause/restart input;
- Breaker press/hold/release input.

Gameplay systems consume commands/state produced by this router; they do not independently compete for the same physical event.

### Movement ownership

The router owns transient touch movement state:
- active pointer ID;
- source (`screen`, `mouse`, or none);
- stick origin;
- normalized movement vector;
- released-pointer recovery guard;
- action/secondary-pointer block list.

The parent `game.gd` fields `touch_move_id`, `touch_origin`, and `touch_move` are compatibility mirrors used by existing gameplay/rendering code. They are not independent authorities.

A real screen pointer outranks the Web mouse-compatible fallback. A secondary/action finger cannot steal the active movement pointer. A released finger cannot be immediately resurrected by a late drag. Focus loss, pause, death, dialogue, module selection, and checkpoint reset clear transient movement ownership.

### Multi-touch actions

Right-side combat actions may fire while a left-side movement finger remains active. An action finger is blocked from later becoming movement until it is released. This prevents a combat-button drag or a second finger from turning into unsolicited movement.

## Action owners

`game.gd` remains the owner of core combat/gameplay consequences such as:
- strike;
- boost;
- deflect;
- player movement integration;
- enemy/projectile simulation;
- dialogue/module/ending flow.

`BreakerController` owns Breaker charge state and Breaker combat consequences, but **not physical input routing**.

Act directors own authored campaign progression and hazards for their acts. They do not own device input.

`PlayerPathPolish` owns objective/HUD/control presentation. It does not own pause/restart input.

## Pause, restart, and focus

Pause is a state boundary, not merely an overlay. Entering pause clears movement and cancels a charging Breaker so no held action leaks through resume.

Checkpoint restart clears transient input before rebuilding campaign runtime state. No pointer or button hold is allowed to survive the reset as live movement/action ownership.

Application/window focus loss clears movement and Breaker transient state. Resuming the app requires fresh input.

## Save/recovery contract

Campaign saves use three paths:
- primary save;
- temporary write;
- previous-valid backup.

A save is first written to the temporary path, the previous primary is preserved as a backup, then the new temporary file is promoted. If the primary cannot be loaded, the runtime attempts the backup and heals the primary from recovered state without overwriting the valid backup with corrupt primary bytes.

Save recovery is machine-tested because campaign progress is a core function, not presentation polish.

## Compatibility strategy

The large `game.gd` still contains older input helper methods while the runtime is being decomposed. `InputRouter` disables the parent physical-input callbacks when the scene boots, so those helpers are dormant compatibility code rather than competing live owners.

Do not add new physical `_input` handlers to gameplay/action/presentation nodes. New device bindings belong in `InputRouter`; new gameplay consequences belong in the system that owns that action.

When the remaining compatibility helpers can be removed without destabilizing the campaign, delete them in a later cleanup pass. Runtime ownership is already centralized now; source-file cleanup is secondary to behavior.

## Machine gates before human testing

At minimum, the core path must keep proving:
- project import/runtime launch;
- campaign state and save recovery;
- full campaign branching;
- combat kit;
- authored Acts I–V;
- movement through the real input router;
- multi-touch ownership/release and Web fallback behavior;
- pause/restart state scrubbing;
- Breaker hold/release routing;
- accelerated Web stability;
- Windows export.

Passing these establishes **MACHINE-VALID** behavior only. Real iOS input/browser evidence and the later subjective five-act pass remain separate human gates.
