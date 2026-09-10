# Dying Sun — Combat Identity

Last updated: 2026-09-10
Status: Internal implementation target

## Combat promise
The frame should feel dangerous because the player makes committed, readable decisions—not because the screen fills with effects or stats.

The baseline combat loop is **close distance -> read intent -> strike/deflect/boost -> create stagger -> break target -> reposition before retaliation**.

## Player verbs

### Move
Fast analog/digital movement. No stamina cost. Movement should remain useful during pressure rather than becoming a slow walk between dodge cooldowns.

### Strike chain
Three-hit light chain on one input.
- Hit 1: quick, low commitment.
- Hit 2: stronger forward bite.
- Hit 3: wide breaker finish with increased stagger.
- Waiting too long resets the chain.

### Boost
Short directional burst using Frame Charge.
- Can pass through danger during a brief protected interval.
- Costs enough charge that panic-spamming empties the frame.
- Charge regenerates when not boosting.
- Boost should be useful offensively for gap closing, not only escape.

### Deflect
Short timing window introduced in Act I after the player understands strike/boost.
- Successful deflect cancels a readable enemy attack and creates stagger.
- Failure should be punishable but not instantly fatal.
- Not every attack is deflectable; color/shape/audio telegraph must communicate this.

### Breaker
Charged heavy attack introduced in Act II.
- High stagger and armor damage.
- Long enough commitment that using it into an unbroken enemy is risky.
- Strong against stunned/staggered targets and certain defenses.

## Frame Charge
One shared combat resource powers boost and later active modules.
- Maximum baseline: 100.
- Boost target cost: 28–35 depending on tuning.
- Passive regeneration begins immediately but is modest under pressure.
- Deflect success may refund charge to encourage skillful aggression.

The resource exists to produce choices, not downtime. Avoid designs where the optimal play is to run away and wait for a full bar.

## Enemy grammar

### Warden
Melee pressure unit.
- Chases directly.
- Telegraphs a short lunge rather than dealing invisible contact damage.
- Purpose: teach spacing and boost/deflect timing.

### Husk
Ranged memory-shell.
- Tries to maintain medium distance.
- Fires slow readable bolts that pressure stationary play.
- Purpose: force target prioritization and movement.

### Sun-Husk
Aggressive unstable elite.
- Telegraphs a line charge.
- High stagger resistance during normal movement, vulnerable after a missed charge.
- Purpose: punish panic movement and reward baiting.

### Archivist fragments
Later enemy family that repeats recorded attack patterns with timing distortions. Used in Act II.

## Boss doctrine
Every boss tests a learned skill and then complicates it.

### First major boss prototype: Gate Custodian
- Phase A tests melee spacing and telegraphed lunges.
- Phase B adds ranged solar arcs that deny passive circling.
- Stagger windows reward aggressive follow-up.
- The boss must not be a large HP version of a Warden.

## Feedback requirements
Every meaningful hit should communicate through at least two channels when practical:
- motion/knock response;
- flash/effect;
- sound;
- controller haptic on native build;
- clear health/stagger change.

Do not use constant screen shake. Reserve stronger feedback for breaker hits, perfect deflects, boss stagger, and lethal blows.

## Anti-patterns
- no unavoidable contact damage blobs;
- no enemies that differ only by HP/speed;
- no long invulnerability phases without player agency;
- no dodge-roll spam as the entire defense model;
- no damage-number confetti unless later testing proves it adds clarity;
- no loot rarity treadmill as substitute for combat progression.
