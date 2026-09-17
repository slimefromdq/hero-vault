# Current design

The game is a five-hero MOBA autobattler / spectator simulation with three differentiated lanes, jungle camps, three simultaneous rival battles, a shared 18-point equipment budget, 13 levels and timer-based ultimates.

The authoritative list of implemented heroes, items and item evolutions is [CONTENT.md](CONTENT.md). [REWORK_2026-09-15.md](REWORK_2026-09-15.md) records the earlier September 15 rework (map sizing, theft, Intermission and the original nine items). Oddity does not protect Irene, and the Double Damage Idol only spawns in the jungle; it is never equipped during preparation.

Hero personalities inform target choice, retreat, roaming and protection. Projectiles and committed melee swings can miss through movement; Crash Test's charge can be sidestepped. All random choices use the match seed. The camera and UI do not alter combat state.

`DEVELOPMENT_HANDOFF.md` preserves an older discussion for context; it is not a specification to revert these changes.
