# Current design

The game remains a five-hero MOBA autobattler / spectator simulation with two lanes, jungle camps, three simultaneous rival battles, a shared 18-point equipment budget, 13 levels and timer-based ultimates.

The authoritative implemented kit and equipment details for this revision are in [REWORK_2026-09-15.md](REWORK_2026-09-15.md). They replace the earlier kit descriptions and shop. In particular, Oddity does not protect Irene, and Double Damage Idol only initially spawns in the jungle rather than being equipped during preparation.

Hero personalities inform target choice, retreat, roaming and protection. Projectiles and committed melee swings can miss through movement. All random choices use the match seed. The camera and UI do not alter combat state.

`DEVELOPMENT_HANDOFF.md` preserves an older discussion for context; it is not a specification to revert these changes.
