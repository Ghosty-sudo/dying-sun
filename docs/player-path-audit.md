# Dying Sun — Player-Path QoL / Maturity Audit

Last updated: 2026-09-10

This document separates machine validity from player-facing maturity. A green workflow, successful export, or deployed browser build does not by itself justify a human handoff.

## Current classification

- **MACHINE-VALID:** target state after every merged change; requires clean import/runtime, progression regressions, and reproducible exports.
- **PLAYTEST-WORTHY:** **NO** at this stage. Act V still uses the generic campaign skeleton and the authored campaign has not yet received its full end-to-end player-path polish pass.
- **RELEASE-WORTHY:** **NO**. The project remains an internal playable in authored-campaign development.

## Player-path audit

### Opening and direction

**Addressed**
- Authored sector objectives no longer rely on the vague `KEEP MOVING` fallback.
- The Breaker gate persistently explains the required input across keyboard, controller, and touch.
- Armor and Frame Charge have readable text labels rather than relying only on bars.
- Black Relay and Crown Engine expose live objective progress through the same player-facing HUD hierarchy.

**Still needed before broad handoff**
- Finish authored Act V.
- Re-run a full first-ten-minute and full-campaign path audit after the final authored act is integrated.

### Controls, pause, retry, navigation

**Addressed**
- Mobile Web has a dedicated pause affordance rather than depending on keyboard Escape.
- Pause has a direct checkpoint-restart path on touch and controller/keyboard.
- Desktop/controller control hints include Breaker after Act II.

**Valuable before release candidate**
- Full input remapping rather than fixed key/button bindings.
- More complete display/window options beyond fullscreen.
- Explicit confirmation for destructive save reset/new-game replacement behavior if the final menu flow makes accidental overwrite plausible.

### Combat and encounter readability

**Needed — ongoing**
- Hazard tells must visually precede damage and remain distinguishable from enemy projectiles.
- Bosses must test learned mechanics rather than only adding health.
- Route consequences must be visible mechanically during play, not only stored as flags or dialogue.

**Addressed in Act III — Black Relay**
- The act begins with relay stabilization under pressure instead of an enemy-clear wave.
- The civilian choice becomes an escort objective with the defense grid intentionally dark.
- The defense choice becomes a lattice-supported push in which the grid actively damages threats and visibly weakens Relay Saint's starting shield.

**Addressed in Act IV — Crown Engine**
- The act begins with testimony recovery under a rotating Crown scan rather than an enemy-clear wave.
- Relationship history changes whether Sol volunteers responsibility or the machine record exposes it.
- OPEN becomes evidence extraction; the recovered proof exposes a real stagger break point on Crown Custodian.
- FOLLOW becomes a dangerous Frame-Charge overdrive traversal and carries that support into the boss fight.
- Crown Custodian resolves a counterprofile from observed strike, boost, deflect, or Breaker usage instead of pretending to adapt through dialogue alone.
- A boost-heavy player receives a telegraphed predicted landing trace with a readable answer: redirect the dash before impact.
- A Breaker-heavy player can provoke a phase shift during a committed charge; strike and deflect profiles receive their own distinct spatial counters.

### Feedback and audio

**Addressed**
- Breaker charge and impact have distinct procedural cues rather than generic fallback sounds.
- Relay stabilization and defense-grid assistance have dedicated feedback tones.
- Crown testimony recovery and Crown phase/landing responses have distinct cues.

**Valuable before release candidate**
- Replace broad procedural/fallback audio with a more authored sound identity where it materially improves strikes, bosses, warnings, UI confirmation, and act atmosphere.
- Validate mix/readability with real speakers/headphones and interruption behavior on the actual target Windows build.

### Saving and recovery

**Current state**
- Act/choice checkpoints persist and death recovery exists.
- Act II's Index Seal has a softlock-recovery guard.
- Pause-driven checkpoint restart is available before death.
- Major authored-route consequences are persisted as campaign flags before boss transitions.

**Valuable before release candidate**
- Clear save-state communication at important checkpoints.
- A deliberate save/reset UX audit, including corrupt/incompatible save behavior.

### Presentation and consistency

**Still needed before broad handoff**
- Act V needs authored spatial/mechanical identity and a climactic presentation standard above the earlier acts.
- Continue removing prototype-feeling geometry/copy as authored rooms and transitions replace generic arena presentation.
- Review the campaign end-to-end for abrupt state changes, temporary labels, inconsistent visual hierarchy, and repeated visual language after all acts are authored.

### Technical and performance

**Needed before release candidate**
- Keep all critical progression, touch, controller, runtime, authored-act, and export regressions green.
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

1. Validate and merge authored Act IV without promoting the build to playtest-worthy solely because CI is green.
2. Author Act V — Last Light as an unstable-system climax rather than another wave pair.
3. Run an end-to-end player-path polish audit across opening, combat, choices, upgrades, save/retry, pause/settings, transitions, endings, controller, and target Windows presentation.
4. Perform an outside-in maturity comparison against appropriate released compact action games and classify remaining gaps as NEEDED / VALUABLE / DELIBERATELY OMIT.
5. Only then decide whether the build has crossed from machine-valid to playtest-worthy.
