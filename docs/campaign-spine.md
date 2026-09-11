# Dying Sun — Campaign Spine

Last updated: 2026-09-11
Status: Sol-directed internal design baseline

## Product shape
Dying Sun is a compact dark science-fantasy action RPG intended for a paid Steam release. The campaign should be finishable in roughly 2.5–4 hours on a first clear, with enough alternate relationship/build outcomes to justify replay without padding.

The player is a recovered combat frame carrying a human operator whose identity has been partially erased by the machine-city. The city surrounds a failing artificial sun. Sol is an intelligence bound to the sun's control lattice. She is not a passive narrator: she can grant access, alter systems, withhold information, disagree with the player, and change the final options available based on remembered actions.

## Five-act structure

### I — Ash Intake
Fantasy: wake, learn the frame, survive.
- Enter through the city's abandoned intake foundry.
- Learn movement, strike, boost, damage, recovery, and environmental hazards through play.
- First contact with Sol happens after the player proves basic survival competence.
- First meaningful relationship choice: demand truth or reject authority.
- Authored route moves through intake traversal, layered furnace combat, coolant hazards, inner-gate pressure, and the Gate Custodian.

### II — The Memory Works
Fantasy: discover what powers the city and learn to disrupt it rather than merely kill what guards it.
- Breaker unlocks as a system-interaction verb at the Index Seal, not only as a heavier attack.
- Memory sweeps create moving battlefield pressure; Breaker can temporarily silence the field and create safe windows.
- The player learns that the artificial sun burns recorded human memory as stabilizing fuel and that Sol's own memory has repeatedly been partitioned into the system.
- The archive decision changes the playable objective immediately:
  - **Preserve:** hold the Index Core under pressure long enough to keep the civilian archive coherent. The route is slower and The Archivist reaches the fight at full integrity.
  - **Burn:** cross a moving thermal purge while pursued. The route is faster and the purge damages The Archivist before the boss fight, but the archive is permanently lost.
- Preserve/burn remains a later ending and relationship consequence; the choice must never collapse back into dialogue-only flavor.
- End boss: The Archivist, a machine that weaponizes stored echoes.

### III — Black Relay
Fantasy: choose who gets power, then live inside the physical consequence of that choice.
- The act opens by entering the Routing Spine rather than clearing a generic wave.
- The player must stabilize three relay nodes by holding position inside active rings while enemies create pressure and live black arcs rotate between relay connections.
- Finishing the routing sequence makes the power decision at a moment when the system has been physically understood rather than presenting it as detached dialogue.
- **Civilian route:** divert the remaining output to the civilian vaults. The defense grid goes dark and the player must stay near and escort a moving power current across the relay while hostile reinforcements arrive. Relay Saint reaches the boss fight at full integrity.
- **Defense route:** arm the defense lattice. The player pushes to the uplink while the friendly grid periodically cuts and staggers hostile machines. The same system visibly strips part of Relay Saint's shield before the boss encounter.
- The choice therefore changes objective, support, hazard pressure, encounter rhythm, and boss starting state rather than only dialogue or hidden flags.
- Sol may advocate for civilians and still respect a player who chooses survival through defense; relationship state records mercy/pragmatism without treating obedience as inherently good.
- End boss: Relay Saint, a defense intelligence occupying a failed human-shaped maintenance shell.

### IV — The Crown Engine
Fantasy: learn what Sol did, then survive a machine that has been studying how you survive.
- Enter the Crown audit chamber instead of another generic combat wave.
- Recover three witness records by holding active testimony rings while rotating Crown scans and enemy pressure force movement and timing.
- Relationship state changes how the truth is delivered:
  - sufficiently trusting players hear Sol volunteer specific admissions;
  - defiant players can expose machine records carrying Sol's authority/signature instead of relying on her confession.
- The core reveal is concrete: Sol authorized an evacuation denial, partitioned herself to keep the artificial sun stable, and accepted the city's survival while people were erased.
- The OPEN/FOLLOW decision changes the playable route immediately:
  - **OPEN:** remain in the Crown record system and extract two physical proofs under the rotating scan. The evidence exposes a real break point in Crown Custodian's stagger state.
  - **FOLLOW:** defer the record and accept Sol's frame overdrive. The route becomes a fast crossing through an expanding Crown surge while Frame Charge regenerates aggressively, and the boss encounter begins fully charged.
- Crown Engine observes actual combat behavior during the act and resolves a dominant habit: strike, boost, deflect, Breaker, or balanced.
- Crown Custodian then announces and applies a readable counterprofile rather than receiving only more health:
  - strike-heavy play is answered by telegraphed close-pressure punishment;
  - boost-heavy play receives a predicted landing trace that can be defeated by redirecting the dash;
  - deflect-heavy play receives expanding non-projectile shock pressure that must be moved/boosted through;
  - Breaker-heavy play causes the Custodian to phase away from a committed charge, forcing timing and positioning changes;
  - balanced play keeps the rotating Crown scan as general pressure.
- The adaptive fight is meant to create the realization that the machine has noticed the player's habits while still making every counter legible and learnable.
- End boss: Crown Custodian.

### V — Last Light
Fantasy: decide what survives.
- Descend into the artificial sun's inner control body as containment fails.
- Encounters remix prior enemy families under unstable conditions.
- Final confrontation is both mechanical and relational.
- Ending options are gated by actions across the campaign, not a single final dialogue selector.
- Baseline endings: Preserve Sol / Preserve City / Sever the System / Burn Everything Clean.
- A stronger reconciliation ending may exist, but only if earned through difficult cross-act conditions.
- **Authored-act treatment is still pending.** Existing state-machine content does not yet satisfy this description by itself.

## Combat growth
Player growth should create new decisions rather than linear stat inflation.

Core frame verbs:
- directional movement;
- short invulnerable/armor-shifting boost with resource cost;
- fast melee chain;
- charged breaker strike that can also disrupt compatible world systems;
- deflect window unlocked early;
- one equipped frame module active;
- one passive chassis trait.

Build archetypes should emerge from combinations rather than classes:
- aggressive heat conversion;
- precision deflect/counter;
- mobility/boost chaining;
- heavy breaker/stagger;
- memory-tech abilities that trade stability for power.

## Relationship model
Do not expose a visible affection meter.

Track durable evidence categories instead:
- TRUST: player shares risk/information or follows Sol when doing so has a cost.
- DEFIANCE: player rejects Sol's direction or proves her wrong.
- MERCY: player preserves vulnerable memory/entities when destruction is easier.
- PRAGMATISM: player sacrifices sentiment for survival/resource advantage.
- CURIOSITY: player investigates optional truth at risk/cost.
- PROMISES: explicit commitments Sol can later recall as kept, broken, or unresolved.

Sol's behavior should be derived from remembered events plus current stakes. She may respect defiance. High trust is not automatically the 'good' route.

## Release discipline
- No filler quests.
- No generic rarity loot shower.
- No open world.
- No procedural campaign pretending to be authored content.
- Bosses must test learned mechanics, not just have larger health bars.
- Every act must add either a combat verb, enemy problem, systemic consequence, or major truth.
- A technically complete state machine is not equivalent to an authored campaign.
- Machine-valid, playtest-worthy, and release-worthy are separate maturity gates.
