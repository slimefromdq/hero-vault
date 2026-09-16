# Current content reference

This is the authoritative list of implemented heroes and items. Numbers are prototype tuning, not balance claims. Data lives in `scripts/catalog.gd`; hero behavior lives in `scripts/hero_kits.gd`; shared combat and item rules live in `scripts/battle.gd`.

Supersedes the kit and item tables in [REWORK_2026-09-15.md](REWORK_2026-09-15.md). The scaling tank-carry hero (Atlas) was removed on 2026-09-15 and is parked, not cancelled.

## Heroes (10)

| Hero | Category | Basic | Signature | Ultimate (timer) |
|---|---|---|---|---|
| Hazmat | Other | Slow heavy melee with stagger | Red Gas follows him, damages enemies and cuts their healing by 20% | OVERPRESSURE: bigger gas, +Resolve, heals from gas damage (90s) |
| Irene | Circus | Fast knives, 25% lifesteal | Leeching Cut dash; steals 12% max HP for 7s | Blood Rush: attack/move speed, 50% lifesteal, redirects enemy healing (75s) |
| Oddity | Circus | Slow, dodgeable confetti | Teleport; Encore stores a nearby ultimate for a weaker copy (own 105s timer) | INTERMISSION: 3s freeze, seeded enemy rearrangement (120s) |
| Mexai | Fantasy | Quick shiv | Pilfer: borrow an equipped item for 8s | Grand Larceny: dash-steal chain (80s) |
| Eleanor | Fantasy | Slow, broad greatsword arc | Intercede: rush to a wounded ally, shield, knockback | Hold the Line: huge defenses, 35% ally damage interception, slowed (100s) |
| Yellow Colony | Other | Melee swarm; grows every two levels | Area slam | All Together: larger slam and shield (100s) |
| **Poppet** | Objects given life | Fast needles (620 speed) | **Stitch**: binds an enemy hero for 5s; 35% of damage Poppet takes is mirrored to them | **Pincushion**: five-needle fan; each needle can miss (85s) |
| **Crash Test** | Objects given life | Bumper melee | **Impact Test**: straight-line charge, damage and 0.8s stun on the first hero in its path. Agile targets may sidestep (seeded). A whiff dazes Crash Test for 0.9s | **Total Write-Off**: 8s shield; then explodes for base damage + 50% of everything absorbed. Also explodes if destroyed early (95s) |
| **Kiln** | Objects given life | Slow ember lob (240 speed, easy to dodge) | **Firing**: anchored burning patch under an enemy (max two fires) | **Open the Door**: wide blast plus a large fire (100s). Passive: +50% tower/vault damage |
| **Sunday** | Other | Sunbeam | **Day of Rest**: instant heal on the most wounded nearby ally (or herself) | **Sunday Best**: allies nearby heal 25% max HP over 5s with +20% movement (90s) |

Poppet, Crash Test, Kiln and Sunday are first-pass interpretations built from their names and categories; expect their kits to change once their designs are written down.

AI quirks: Poppet focuses her stitched target; Crash Test picks the biggest enemy; Kiln has 5 Waveclear/Siege and never roams; Sunday has 5 Protection, 1 Pursuit and hangs back.

## Items (14 + Empty)

Shared 18-point team budget; two distinct slots per hero.

| Item | Cost | Effect | Evolves into (condition → upgrade) |
|---|---:|---|---|
| Last Stand Shield | 2 | Below 25% HP: 35%-max-HP shield for 5s, once per life | — |
| Execution Blade | 3 | +60% damage to heroes below 20% HP | **Headsman's Axe** (3 hero kills) → threshold 30% |
| First Hit Hammer | 2 | +60 first basic hit per enemy; refreshes after 8s apart | **Opening Sledge** (5 procs) → +100 and 0.4s stagger |
| Revenge Armor | 2 | +40 Armor/Resolve against your last killer | — |
| Kill Streak Crown | 3 | +8 Power per consecutive kill; resets on death | — |
| Coward's Boots | 1 | +50% move below 30% HP when fleeing | — |
| Bodyguard Vest | 2 | 25% damage reduction beside a lower-HP ally | **Shield Wall Vest** (400 damage prevented) → 35% |
| Glass Cannon | 2 | +25 Power, −25 Armor/Resolve | — |
| Lucky Coin | 1 | 8% triple-damage basic hit (seeded) | **Two-Headed Coin** (level 13) → 14% |
| **Ambush Shield** | 2 | Losing 30% max HP within 2s: 30%-max-HP shield for 3s; 20s cooldown | — |
| **Invisible Cloak** | 3 | On a jungle rotation or when closing on a hero 150+ away: enemies can't see you for 6s. Attacking, taking damage or coming within 60 of an enemy hero reveals you; towers ignore you. 30s cooldown | — |
| **Lane Rations** | 1 | After 6s without hero damage: 4 HP/s (+0.4/level) | **Hearty Rations** (level 9) → starts after 4s, double healing |
| **Scout Pin** | 1 | Reveals hidden enemy heroes within 260; 10s cooldown after a reveal | — |
| **Tempered Sole** | 1 | Starting a retreat: +40% move for 2.5s; 12s cooldown | **Tempered Greaves** (4 boosted retreats) → +55% for 4s |

### Evolution rules

- Evolution is a one-time, announced jump (`ITEM EVOLVED` in the fight story, `item_evolved` in the CSV). The evolved name shows in gold in the match equipment panel.
- Progress belongs to the owner. A stolen copy works at base strength for the thief and makes no progress; a suppressed item makes no progress for its owner either.
- Evolution data sits on each item in `Catalog.ITEMS[id].evolve` (`trigger`: `level`, `procs`, `kills`, `blocked`, `retreats`). `Catalog.validate_definitions()` checks it.

### Statistics these items produce

- `cloak_gank_success`: a takedown within 12s of cloaking. Compare with cloak activations to answer "does the Cloak pay for itself?"
- `cloak_reveal` with `detail` = `attack`, `damaged`, `proximity` or `scout`.
- `item_proc` for `ambush`, `sole`, `scout` and the older triggered items; `item_evolved` with the progress value at evolution.

## New CSV event kinds

`stitch`, `stitch_mirror`, `ram_hit`, `ram_dodge`, `dash_miss` (also for Crash Test), `write_off_blast`, `cloak_reveal`, `cloak_gank_success`, `item_evolved`. Existing IDs, including `crown_*` for the Double Damage Idol, are unchanged.
