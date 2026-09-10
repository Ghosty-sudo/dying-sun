# Dying Sun

**Working title.** A compact dark science-fantasy action RPG set inside a machine-city built around a dying artificial sun.

Dying Sun is Sol-owned creative territory: David sets hard real-world boundaries and serves as primary human playtester; Sol owns default creative direction, scope calls, systems design, iteration, and release-readiness decisions.

## Current build — Internal Playable / Authored Campaign Development

The current build is an internal playable, not a release candidate and not automatically ready for broad human handoff merely because CI or exports are green. Development distinguishes **machine-valid**, **playtest-worthy**, and **release-worthy** as separate gates.

Current campaign state:
- **Act I — Ash Intake:** authored traversal, layered combat teaching, furnace/coolant hazards, gate approach, and Gate Custodian;
- **Act II — The Memory Works:** Breaker-gated Index Seal, moving memory pressure, preserve/burn objectives with mechanical consequences, and The Archivist;
- **Act III — Black Relay:** routing-spine stabilization under live arcs, followed by either civilian power escort or defense-lattice assault, with the route changing the Relay Saint encounter;
- **Acts IV–V:** still below the authored-act standard and therefore a known blocker to broad playtest-worthiness.

The combat frame currently supports strike chains, boost, deflect, stagger breaks, and the Act II+ Breaker heavy/system-disruption attack. Relationship, choice, checkpoint, death, module, and ending state persist through the campaign.

See `docs/player-path-audit.md` for the current outside-in QoL and maturity audit.

## Controls

### Keyboard / mouse
- **WASD / arrows** — move
- **Shift** — boost
- **Space** — strike chain
- **F** — deflect
- **Q (hold, Act II+)** — charge and release Breaker
- **E** — interact / advance dialogue
- **1 / 2** — dialogue or module decision
- **Esc** — pause
- **R** — restart from checkpoint while paused; restart after death

### Controller
- **left stick** — move
- **A / south face** — strike chain; choose left option when a decision is open
- **B / east face** — boost; choose right option when a decision is open
- **X / west face** — deflect
- **Y / north face** — interact / advance dialogue; restart checkpoint while paused
- **left shoulder (hold, Act II+)** — charge and release Breaker
- **menu/start** — pause / resume

### Mobile Web
- **left thumb** — virtual movement stick
- **STRIKE** — melee strike chain
- **BOOST** — dash/boost
- **PARRY** — timed defensive counter
- **BRK (Act II+)** — hold to charge and release Breaker
- **II button (top-right)** — pause / resume
- **RESTART CHECKPOINT** — available from pause
- **tap dialogue** — continue
- **left/right choice zones** — choose dialogue or frame module
- **tap after death** — restart from the latest checkpoint

For the mobile validation runtime, landscape orientation is recommended so the 16:9 chamber and touch controls have enough room. Mobile Web remains a convenient validation/device-test target; Steam / Windows PC is the commercial target.

## Player-facing development standard

A successful launch, browser deployment, Windows export, test run, or roadmap completion is not sufficient for handoff. Before broad human testing, the game is audited for player direction, control discoverability, pause/retry, settings, save/recovery, HUD hierarchy, readable hazards and interactables, progression feedback, transitions, audio/game feel, presentation consistency, and target-platform expectations.

David's broad playtests are reserved primarily for questions automation cannot answer well: fun, control feel, difficulty fairness, pacing, choice interest, confusion despite technical correctness, progression satisfaction, repetition, and emotional effect.

## Technical target

- Engine: Godot 4.7.2
- Commercial target: Steam / Windows PC
- Validation/device-test target: Web via GitHub Pages on desktop and mobile browsers
- CI: structural checks + headless import + campaign/state/combat/authored-act/player-path smoke tests + runtime smoke + Windows export
- Pages: Godot Web export deployed through GitHub Actions

## AI character boundary

The current build does **not** call an AI API. Sol is simulated through authored personality, relationship state, promises, remembered choices, and save-state memory.

A later live-AI layer may receive a sanitized Sol persona plus game-world state. It must never receive David's private Sol controller, private conversation history, connected-account context, credentials, or unrelated personal information. API credentials must remain server-side and project-specific.

## Design doctrine

The game must be fun without generative AI. AI should deepen a character and relationship, not conceal weak combat, weak progression, or weak writing.

Compact coherence beats feature volume. No filler quests, generic rarity-loot shower, open-world expansion, or procedural campaign will be added merely to make the game look larger.

The final commercial title is intentionally undecided until the game earns one.
