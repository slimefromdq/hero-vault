# Current design

The game is a five-hero MOBA autobattler / spectator simulation with three lanes (north, south and a shorter diagonal mid), jungle camps, three simultaneous rival battles, an in-match remote shop with courier-drone delivery ([SHOP_AND_DRONE.md](SHOP_AND_DRONE.md)), 13 levels and timer-based ultimates.

The authoritative list of implemented heroes and items is [CONTENT.md](CONTENT.md). [REWORK_2026-09-15.md](REWORK_2026-09-15.md) records the earlier September 15 rework (map sizing, theft, Intermission and the original nine items). Oddity does not protect Irene, and the Double Damage Idol only spawns in the jungle; it is never sold in the shop.

Hero personalities inform target choice, retreat, roaming and protection. Projectiles and committed melee swings can miss through movement; Crash Test's charge can be sidestepped. All random choices use the match seed. The camera and UI do not alter combat state.

`DEVELOPMENT_HANDOFF.md` preserves an older discussion for context; it is not a specification to revert these changes.

## Development Cycle 001: Make Matches Breathe

The three-lane layout is retained by explicit user instruction. Travel distances are 2.5 times the previous map: outer lanes are 2,075 units and mid is approximately 1,491. Movement speeds, attack ranges and ability timers retain their hero-specific values. Heroes start with 40% more HP and receive 40% more HP per level; damage growth is unchanged. Death costs 16–45 seconds plus travel back to the front.

Every 30 seconds, each lane gets two melee creeps (240 HP, 12 damage) and two ranged creeps (130 HP, 19 damage). Every third wave adds a siege creep (380 HP, 16 damage, 3.5× structure damage). Creep HP and damage grow by `1 + match_seconds / 900`. Surviving waves establish the front; heroes follow them between fights.

Towers have 4,200 HP and 300 range. They always prefer creeps in range, dealing 55 damage to them; exposed heroes take 22% of maximum HP per shot before defenses, every 1.2 seconds. Heroes wait outside unsupported tower range, and their unsupported structure damage is reduced to 15%. Vaults have 14,000 HP. Normal structure damage uses a 0.20 multiplier; the existing 12-minute overtime progressively increases it. There is no timer-based victory or invulnerable early vault.

Every 0.3 seconds, heroes reassess health and nearby numbers. Retreat rating changes the base retreat threshold from 27% to 55%; being outnumbered raises it, and squad strategy biases it. Retreat continues until 80% HP, with healing near the home vault. Target selection weighs pursuit, dueling, waveclear and protection. Roamers react to lane pressure; healthy heroes with sufficient roaming affinity can also leave lane for the central objective. Decisions are recorded in the CSV.

The Central Power Node is off the mid road and first activates at four minutes. It has 2,400 HP, retaliates, and regenerates when abandoned. Up to three eligible heroes per team commit while other heroes hold lanes; opponents at the node fight each other. The final hit awards 12 XP to every teammate and 90 seconds of empowered wave spawns (+40% creep HP and +60% structure damage). Existing empowered creeps retain their upgrade until death. The node returns 180 seconds after capture. Existing small camps and the Double Damage Idol remain; no new jungle ecosystem, item redesign or drone system is introduced.

The spectator view labels early game, midgame and overtime, shows node availability and wave-buff timers, and distinguishes melee, ranged, siege and empowered creeps. Target duration is roughly 12–20 minutes, with a ten-minute lower bound checked across the standard seeded match scenarios. This is pacing validation, not a roster balance sign-off.
