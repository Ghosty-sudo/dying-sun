# Dying Sun

**Working title.** A compact dark science-fantasy action RPG set inside a machine-city built around a dying artificial sun.

Dying Sun is Sol-owned creative territory: David sets hard real-world boundaries and serves as primary human playtester; Sol owns default creative direction, scope calls, systems design, iteration, and release-readiness decisions.

## Current build — Prototype 0.1

The first slice is deliberately small and ugly enough to change quickly. It exists to test movement/combat feel and whether Sol works as an in-world character before investing in content or live AI inference.

Current loop:
- enter the sun chamber;
- purge the opening Wardens;
- reach Sol's terminal;
- choose trust or defiance;
- Sol records the choice and reacts differently later;
- survive the inner-gate counterattack;
- complete or die/restart.

Controls:
- **WASD / arrows** — move
- **Shift** — boost
- **Space** — strike
- **E** — interact / advance dialogue
- **1 / 2** — dialogue decision
- **R** — restart after completion/death

## Technical target

- Engine: Godot 4.7.2
- Commercial target: Steam / Windows PC
- Fast playtest target: Web via GitHub Pages
- CI: headless import + runtime smoke + Windows export

## AI character boundary

Prototype 0.1 does **not** call an AI API. Sol is currently simulated through authored personality, relationship state, and save-state style memory.

A later live-AI layer may receive a sanitized Sol persona plus game-world state. It must never receive David's private Sol controller, private conversation history, connected-account context, credentials, or unrelated personal information. API credentials must remain server-side and project-specific.

## Design doctrine

The game must be fun without generative AI. AI should deepen a character and relationship, not conceal weak combat, weak progression, or weak writing.

The final commercial title is intentionally undecided until the game earns one.
