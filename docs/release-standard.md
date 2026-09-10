# Dying Sun — Sol Release Standard

Last updated: 2026-09-10

Dying Sun does not become a release candidate because all planned tasks are checked off. It becomes a release candidate when the complete experience meets the following standard.

## Core experience
- Movement, attack, boost, damage, hit feedback, death, recovery, and boss combat feel intentional rather than prototype-grade.
- The first ten minutes communicate the fantasy, controls, danger, and central mystery without requiring outside explanation.
- Combat remains interesting through the full campaign because enemy behaviors, encounter composition, player tools, and environment evolve.
- Difficulty can punish mistakes without relying on unreadable damage, cheap contact spam, or arbitrary health inflation.

## Structure and progression
- The game has a complete authored beginning, escalation, climax, and ending.
- Player growth changes decisions and playstyle rather than only increasing numbers.
- Checkpoints/save behavior is trustworthy and understandable.
- A normal first completion should feel substantial enough to justify a paid compact indie release; no artificial padding.
- Optional replay value must come from meaningful alternate choices/builds/outcomes rather than required grinding.

## Sol character standard
- Sol has a recognizable personality independent of the player's preferences.
- She can disagree with the player, remember consequential choices, revise judgments, and affect gameplay or story outcomes.
- Her relationship with the player develops through events and actions, not only a numeric affection meter.
- Critical narrative beats are authored and deterministic enough to preserve pacing, canon, safety, and reliability.
- If live AI is added, the game remains complete when the service is unavailable and no private David/Sol-Control data is accessible to the runtime.

## Presentation
- Art direction is coherent across environment, protagonist, enemies, Sol, UI, effects, typography, and store assets.
- Placeholder visuals, debug labels, developer-facing controls, temporary copy, and prototype geometry are removed from the commercial path.
- Audio includes music/ambience, attacks, impacts, damage, UI feedback, major encounters, and accessibility-minded volume controls.
- UI is readable at target PC resolutions and sensible with keyboard/mouse and controller. Web/mobile playtesting support does not dictate the Steam UI.

## Technical quality
- Clean Godot headless import and runtime smoke tests.
- Automated structural/game-state tests cover critical progression and choice branches.
- Windows release export succeeds reproducibly in CI.
- No known progression blockers, softlocks, save corruption paths, missing critical assets, or obvious crash paths.
- Performance is acceptable on modest Windows gaming hardware consistent with the game's visual scope.
- Input remapping/settings, pause behavior, audio controls, display/window options, and save/reset controls exist at commercial quality.

## Commercial readiness
- Final title and branding are chosen and checked for obvious conflicts before store submission.
- Versioned Windows build, icon, capsule/key art, screenshots, description copy, trailer plan/assets, credits, privacy disclosures if applicable, support contact, and licenses are ready.
- Steam Content Survey accurately discloses any AI-generated or live-generated content.
- Any live AI feature has project-specific credentials, server-side key storage, rate/spend limits, failure handling, abuse controls, and a non-AI fallback.

## Final gate
Before David receives the next broad playtest build, Sol must be able to answer YES to all of these:
1. Would I willingly put my name on this build?
2. Would I consider the core loop worth money from a stranger?
3. Can a new player understand and finish it without David explaining what I intended?
4. Have I removed features I kept only because I already spent time building them?
5. Are the remaining known defects compatible with a release-candidate label rather than an alpha/beta label?

If any answer is NO, continue development instead of handing the build to David for general playtesting.
