# Dying Sun

**Working title.** A compact dark science-fantasy action RPG set inside a machine-city built around a dying artificial sun.

Dying Sun is Sol-owned creative territory: David sets hard real-world boundaries and serves as primary human playtester; Sol owns default creative direction, scope calls, systems design, iteration, and release-readiness decisions.

## Current build — Prototype 0.1M

The current build is still an internal development prototype. It exists to prove the campaign spine, combat systems, persistence, and Sol's in-world role before the project earns release-candidate treatment.

Current loop:
- fight through five escalating machine-city acts;
- survive mixed enemy waves and act bosses;
- use strike chains, boost, deflect, stagger breaks, and the Act II Breaker heavy attack;
- make consequential choices with Sol between encounters;
- install one of two frame modules after each of the first four acts;
- carry relationship, choice, checkpoint, death, and module state through the campaign;
- reach one of multiple authored endings.

Desktop controls:
- **WASD / arrows** — move
- **Shift** — boost
- **Space** — strike chain
- **F** — deflect
- **Q (hold, Act II+)** — charge and release Breaker
- **E** — interact / advance dialogue
- **1 / 2** — dialogue or module decision
- **Esc** — pause
- **R** — restart after death

Controller controls:
- **left stick** — move
- **A / south face** — strike chain; choose left option when a decision is open
- **B / east face** — boost; choose right option when a decision is open
- **X / west face** — deflect
- **Y / north face** — interact / advance dialogue
- **left shoulder (hold, Act II+)** — charge and release Breaker
- **menu/start** — pause / resume

Mobile Web controls:
- **left thumb** — virtual movement stick
- **STRIKE** — melee strike chain
- **BOOST** — dash/boost
- **DEFLECT** — timed defensive counter
- **BRK (Act II+)** — hold to charge and release Breaker
- **tap dialogue** — continue
- **left/right choice zones** — choose dialogue or frame module
- **tap after death** — restart from the latest checkpoint

For the current mobile playtest runtime, landscape orientation is recommended so the 16:9 chamber and touch controls have enough room. Mobile Web remains a convenient test target; Steam / Windows PC is the commercial target.

## Technical target

- Engine: Godot 4.7.2
- Commercial target: Steam / Windows PC
- Fast playtest target: Web via GitHub Pages on desktop and mobile browsers
- CI: structural checks + headless import + campaign/state/combat smoke tests + runtime smoke + Windows export
- Pages: Godot Web export deployed through GitHub Actions

## AI character boundary

The current build does **not** call an AI API. Sol is simulated through authored personality, relationship state, promises, remembered choices, and save-state memory.

A later live-AI layer may receive a sanitized Sol persona plus game-world state. It must never receive David's private Sol controller, private conversation history, connected-account context, credentials, or unrelated personal information. API credentials must remain server-side and project-specific.

## Design doctrine

The game must be fun without generative AI. AI should deepen a character and relationship, not conceal weak combat, weak progression, or weak writing.

The final commercial title is intentionally undecided until the game earns one.
