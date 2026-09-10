# Dying Sun — Player-Path QoL / Maturity Audit

Last updated: 2026-09-10

This document separates machine validity from player-facing maturity. A green workflow, successful export, or deployed browser build does not by itself justify a human handoff.

## Current classification

- **MACHINE-VALID:** target state after every merged change; requires clean import/runtime, progression regressions, and reproducible exports.
- **PLAYTEST-WORTHY:** **NO** at this stage. Acts IV and V still use the generic campaign skeleton, so a broad playtest would spend too much of David's time rediscovering known content-maturity gaps.
- **RELEASE-WORTHY:** **NO**. The project remains an internal playable in authored-campaign development.

## Player-path audit

### Opening and direction

**Needed — addressed in this pass**
- Authored sector objectives must not fall back to the vague `KEEP MOVING` HUD copy.
- The Breaker gate must persistently explain the required input across keyboard, controller, and touch.
- Armor and Frame Charge need readable labels rather than relying on unlabeled bars.

**Still needed before broad handoff**
- Continue authored campaign treatment through Acts IV and V.
- Audit the full first-ten-minute sequence after all opening presentation changes are integrated.

### Controls, pause, retry, navigation

**Needed — addressed in this pass**
- Mobile Web needs a dedicated pause affordance rather than depending on keyboard Escape.
- Pause needs a direct checkpoint-restart path on touch and controller/keyboard.
- Desktop/controller control hints must include Breaker after Act II rather than continuing to advertise an incomplete combat kit.

**Valuable before release candidate**
- Full input remapping rather than fixed key/button bindings.
- More complete display/window options beyond fullscreen.
- Explicit confirmation for destructive save reset/new-game replacement behavior if the final menu flow makes accidental overwrite plausible.

### Combat and encounter readability

**Needed — ongoing**
- Hazard tells must visually precede damage and remain distinguishable from enemy projectiles.
- Bosses must test learned mechanics rather than only adding health.
- Route consequences must be visible mechanically during play, not only stored as flags or dialogue.

**Addressed in Act III**
- Black Relay begins with relay stabilization under pressure instead of an enemy-clear wave.
- The civilian choice becomes an escort objective with the defense grid intentionally dark.
- The defense choice becomes a lattice-supported push in which the grid actively damages threats and visibly weakens Relay Saint's starting shield.

### Feedback and audio

**Needed — addressed in this pass**
- Relay stabilization and defense-grid assistance receive dedicated procedural feedback tones.

**Valuable before release candidate**
- Replace broad procedural/fallback audio with a more authored sound identity where it materially improves strikes, Breaker, bosses, warnings, UI confirmation, and act atmosphere.
- Validate mix/readability with real speakers/headphones and interruption behavior on the actual target Windows build.

### Saving and recovery

**Current state**
- Act/choice checkpoints persist and death recovery exists.
- Act II's Index Seal has a softlock-recovery guard.
- This pass adds pause-driven checkpoint restart paths so recovery is available before death.

**Valuable before release candidate**
- Clear save-state communication at important checkpoints.
- A deliberate save/reset UX audit, including corrupt/incompatible save behavior.

### Presentation and consistency

**Still needed before broad handoff**
- Acts IV–V need authored spatial/mechanical identity.
- Continue removing prototype-feeling geometry/copy as richer rooms and transitions replace generic arena presentation.
- Review the campaign end-to-end for abrupt state changes, temporary labels, and inconsistent visual hierarchy after all acts are authored.

### Technical and performance

**Needed before release candidate**
- Keep all critical progression, touch, controller, runtime, and export regressions green.
- Investigate and clean known Godot exit-time resource leak warnings rather than normalizing them indefinitely.
- Validate acceptable performance on modest Windows hardware representative of the intended audience.

## Deliberate omissions

The following are not maturity gaps for this game's intended compact identity unless future evidence changes the decision:
- open world;
- generic side-quest log;
- rarity-colored loot shower;
- large inventory-management layer;
- procedural campaign used as a substitute for authored acts;
- filler encounters added only to increase playtime.

## Next maturity sequence

1. Finish and validate authored Act III plus this player-path polish layer.
2. Author Act IV — Crown Engine around truth/reveal machinery and a boss that attacks the player's learned habit.
3. Author Act V — Last Light as an unstable-system climax rather than another wave pair.
4. Run an end-to-end player-path polish audit across opening, combat, choices, upgrades, save/retry, pause/settings, transitions, endings, controller, and target Windows presentation.
5. Only then decide whether the build has crossed from machine-valid to playtest-worthy.
