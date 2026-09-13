# Dying Sun — Player-Path QoL / Maturity Audit

Last updated: 2026-09-13

This document separates machine validity from player-facing maturity. A green workflow, successful export, or deployed browser build does not by itself justify a broad human handoff.

## Current classification

- **MACHINE-VALID:** **YES** for the current authored five-act implementation. Clean Godot import/runtime, campaign/combat/Acts I–V regressions, touch and accelerated Web stability smokes, scripted opening playtest, Windows export, and artifact upload all pass together in CI.
- **PLAYTEST-WORTHY:** **NO for broad campaign handoff yet.** All five acts are now authored, but two narrow real-device Web questions remain unresolved from prior human evidence: virtual-stick ownership/release on iOS and an observed browser crash during gameplay. A full end-to-end subjective campaign pass is also still needed for pacing, repetition, encounter fairness, readability, and emotional payoff now that Last Light exists.
- **RELEASE-WORTHY:** **NO.** The game has crossed out of generic campaign-skeleton development, but target-Windows mix/performance, full campaign feel, remaining presentation consistency, save/reset UX, and known real-device playtest-surface risks still need release-candidate judgment.

## Player-path audit

### Opening and direction

**Addressed**
- Authored sector objectives no longer rely on the vague `KEEP MOVING` fallback in the campaign's authored routes.
- The Breaker gate persistently explains the required input across keyboard, controller, and touch.
- Armor and Frame Charge have readable text labels rather than relying only on bars.
- Black Relay, Crown Engine, and Last Light expose live objective progress through player-facing HUD language.
- Last Light now begins with a physical descent and memory-convergence objective rather than an enemy-clear wave.

**Still needed before broad handoff**
- Run the complete first-session/full-campaign path on the current five-act build and judge whether transitions and objective language remain clear without developer explanation.

### Controls, pause, retry, navigation

**Addressed**
- Mobile Web has a dedicated pause affordance rather than depending on keyboard Escape.
- Pause has a direct checkpoint-restart path on touch and controller/keyboard.
- Desktop/controller control hints include Breaker after Act II.
- Automated touch ownership/recovery regressions remain green after the last mobile fixes.

**Blocking broad Web handoff**
- Confirm on a real iOS device that the virtual stick never moves without an active gesture and releases cleanly after direction changes, secondary touches, and combat-button use.
- Confirm the browser remains stable during a short real-device combat session after the previous observed crash.

**Valuable before release candidate**
- Full input remapping rather than fixed key/button bindings.
- More complete display/window options beyond fullscreen.
- Explicit confirmation for destructive save reset/new-game replacement behavior if the final menu flow makes accidental overwrite plausible.

### Combat and encounter readability

**Addressed**
- Authored acts replace the earlier repeated kill/link/reset campaign rhythm with traversal, system interaction, escort/support, evidence extraction, adaptive counters, and finale-route mechanics.
- Route consequences are represented mechanically during play rather than only stored as flags or dialogue.
- Last Light's solar-collapse pressure is visually drawn before contact and has a movement/boost answer.
- STAY turns the finale into a moving Sol-link objective with charge support and pressure relief.
- SEVER turns the finale into three spatial Breaker interactions whose result carries into boss stagger/attack behavior.
- Last Light's final fight changes mechanically with the relational route instead of only changing ending text.

**Subjective gate still needed**
- Confirm on a full human campaign run that the authored variety actually reads as variety, not merely different state labels around the same combat cadence.
- Judge whether hazard tells are early enough at real play speed, whether bosses test learned mechanics fairly, and whether the final collapse pressure is demanding rather than noisy.

### Feedback and audio

**Addressed**
- Breaker charge and impact have distinct procedural cues rather than generic fallback sounds.
- Relay stabilization and defense-grid assistance have dedicated feedback tones.
- Crown testimony recovery and Crown phase/landing responses have distinct cues.
- Last Light adds dedicated memory-echo, Sol-link, authority-lock, and solar-break cues.
- Act V ambience adds a fractured low layer so the finale does not reuse the earlier acts' exact sonic shape.
- Menu/settings/pause navigation now receives lightweight confirmation feedback, and entering an ending receives a distinct final stinger.

**Valuable before release candidate**
- Validate the procedural mix/readability on real speakers and headphones, especially strikes, warnings, boss pressure, dialogue moments, and the Last Light collapse.
- Replace any procedural/fallback cue that still reads as placeholder after listening in context; do not replace procedural audio merely for asset-count optics.
- Validate interruption/background behavior and volume expectations on the target Windows build.

### Saving and recovery

**Current state**
- Act/choice checkpoints persist and death recovery exists.
- Act II's Index Seal has a softlock-recovery guard.
- Pause-driven checkpoint restart is available before death.
- Major authored-route consequences are persisted as campaign flags before boss transitions.
- Last Light persists its echo resolution and route consequence before the final confrontation.

**Valuable before release candidate**
- Clear save-state communication at important checkpoints.
- A deliberate save/reset UX audit, including corrupt/incompatible save behavior and accidental NEW GAME replacement risk.

### Presentation and consistency

**Addressed in the current pass**
- Last Light has its own procedural spatial identity: concentric artificial-sun machinery, radial conduits, drifting motes, echo glyphs, Sol-link visuals, authority locks, collapse rings, and route-sensitive boss treatment.
- The title screen now receives a restrained machine-city silhouette, broken orbital traces, and ash drift around the existing artificial-sun mark rather than relying only on flat menu geometry.
- Endings receive distinct visual motifs for reconciliation, preserving Sol, preserving the city, severing the system, and burning clean.
- A minimal framing layer adds cohesion during play without covering combat or HUD information.

**Still needed before release candidate**
- Review the whole campaign at human play speed for abrupt state changes, temporary-looking labels, repeated geometry, clutter, and hierarchy conflicts that static/code inspection cannot reliably judge.
- Promote or cut individual presentation elements based on how they actually read on the target display rather than adding more effects by default.

### Technical and performance

**Addressed / continuously gated**
- Critical progression, combat, authored Acts I–V, touch input, accelerated Web stability, opening path, runtime, and Windows export regressions run in the same CI job.
- Current Windows release export and artifact upload succeed from CI.

**Needed before release candidate**
- Keep all critical gates green on the release candidate.
- Investigate and clean meaningful Godot exit-time resource leak warnings rather than normalizing them indefinitely if they still reproduce on the release path.
- Validate acceptable performance on modest Windows hardware representative of the intended audience.
- Clear or deliberately scope the two remaining real-device Web issues before relying on the browser build as the primary human playtest surface.

## Deliberate omissions

The following are not maturity gaps for this game's intended compact identity unless future evidence changes the decision:
- open world;
- generic side-quest log;
- rarity-colored loot shower;
- large inventory-management layer;
- procedural campaign used as a substitute for authored acts;
- filler encounters added only to increase playtime.

## Next maturity sequence

1. Clear the short real-device iOS gate: virtual-stick ownership/release and browser stability only; if either fails, isolate the exact observed behavior rather than guessing.
2. Run one complete human campaign pass focused on feel, fairness, pacing, repetition, clarity, route consequence, boss readability, audio balance, and whether Last Light actually lands as a climax.
3. Consolidate that evidence into one fix/polish pass rather than repeated tiny handoffs.
4. Perform the target-Windows maturity pass: modest-hardware performance, audio mix, save/reset UX, controller/keyboard expectations, display behavior, and release presentation.
5. Classify the remaining gaps as NEEDED / VALUABLE / DELIBERATELY OMIT and only then decide whether the build has crossed to `PLAYTEST-WORTHY` broadly and later `RELEASE-WORTHY`.
