# Current content reference

This is the authoritative list of implemented heroes and items. Numbers are prototype tuning, not balance claims. Data lives in `scripts/catalog.gd`; hero behavior lives in `scripts/hero_kits.gd`; shared combat rules live in `scripts/battle.gd`; shop items and delivery live in `scripts/shop_catalog.gd`, `scripts/shop_manager.gd`, `scripts/courier_drone.gd` and `scripts/hero_inventory.gd`.

Supersedes the kit and item tables in [REWORK_2026-09-15.md](REWORK_2026-09-15.md). The scaling tank-carry hero (Atlas) was removed on 2026-09-15 and is parked, not cancelled.

## Heroes (10)

| Hero | Category | Basic | Signature | Ultimate (timer) |
|---|---|---|---|---|
| Hazmat | Other | Slow heavy melee with stagger | Red Gas follows him, damages enemies and cuts their healing by 20% | OVERPRESSURE: bigger gas, +Resolve, heals from gas damage (90s) |
| Irene | Circus | Fast knives, 25% lifesteal | Leeching Cut dash; steals 12% max HP for 7s | Blood Rush: attack/move speed, 50% lifesteal, redirects enemy healing (75s) |
| Oddity | Circus | Slow, dodgeable confetti | Teleport; Encore stores a nearby ultimate for a weaker copy (own 105s timer) | INTERMISSION: 3s freeze, seeded enemy rearrangement (120s) |
| Mexai | Fantasy | Quick shiv | Pilfer: borrow a delivered item for 8s | Grand Larceny: dash-steal chain (80s) |
| Eleanor | Fantasy | Slow, broad greatsword arc | Intercede: rush to a wounded ally, shield, knockback | Hold the Line: huge defenses, 35% ally damage interception, slowed (100s) |
| Yellow Colony | Other | Melee swarm; grows every two levels | Area slam | All Together: larger slam and shield (100s) |
| **Poppet** | Objects given life | Fast needles (620 speed) | **Stitch**: binds an enemy hero for 5s; 35% of damage Poppet takes is mirrored to them | **Pincushion**: five-needle fan; each needle can miss (85s) |
| **Crash Test** *(The Human Safety Violation)* | Objects given life | **Impact Test**: slow, clumsy punch with big knockback | **FULL SEND** (14s): catapults 200–650 units at the target's *current* spot, across lanes if needed. Airborne: can't act, can't be hit. Landing: area damage and knockback (both grow with distance), 0.9s stun at the center. Can land on nobody. **SAFETY RATING: ZERO** (16s): 4s of +40 Armor, 85% less knockback, −40% speed; used when surrounded or badly hurt | **CRASH PROGRAM**: for 8s, every knockback, landing or wall hit emits a shockwave (95s) |
| **Kiln** | Objects given life | Slow ember lob (240 speed, easy to dodge) | **Firing**: anchored burning patch under an enemy (max two fires) | **Open the Door**: wide blast plus a large fire (100s). Passive: +50% tower/vault damage |
| **Sunday** *(The Daystar Darling)* | Other | **Sunbeam**: slow (170), long-lived (4s), heavy bolt with a small splash | **Warmth** (12s): 5s healing aura (+15 Resolve); she walks toward a wounded ally to cast it, even into danger. **Flare** (13s): very slow (95) solar orb aimed at a clustered or stuck enemy; bursts where they *were*, or on whoever walks into it: heavy area damage, knockback, brief burn | **BEAUTIFUL DAY**: 7s stationary sun zone (radius 170) on a fight with 3+ heroes. Allies heal 3% max HP/s and gain +25 Resolve; enemies burn and are easier to target; hidden heroes are revealed. Stays even if Sunday falls (110s) |

Crash Test and Sunday follow Lucy's design sheets (2026-09-16). Poppet and Kiln are still first-pass interpretations built from their names and categories.

AI quirks: Poppet focuses her stitched target. Crash Test prefers enemies already fighting allies and low-HP targets, and FULL SEND deliberately prefers far, crowded fights over safe ones. Kiln has 5 Waveclear/Siege and never roams. Sunday fights from 95% of her range, rarely chases, favors enemies engaging her allies, and saves BEAUTIFUL DAY for crowds.

## Stability, knockback and walls

- Every hero has **Stability** (1–10). Knockback distance is multiplied by `1.45 − 0.09 × Stability` (Crash Test 1 → ×1.36; Kiln 9 → ×0.64). SAFETY RATING: ZERO sets it to ×0.15.
- Knockback sources: Crash Test's punch and landing, Sunday's Flare, and Eleanor's Intercede.
- A knockback stopped 18+ units short by the lane edge is a **wall slam**: 3% max HP and a 0.25s stun. Crash Test takes only 1%, is stunned for 0.5s, and staggers enemies within 70.
- Size: Crash Test's token is larger (radius 21 vs 17).
- Airborne heroes are skipped by targeting, projectiles, fields, towers and damage.

## Items (remote shop)

Bought in-match and delivered by the courier drone. Data: `scripts/shop_catalog.gd`. Rules: [SHOP_AND_DRONE.md](SHOP_AND_DRONE.md). Six inventory slots per hero, and queued orders reserve slots.

| ID | Item | Cost | Effect |
|---|---|---:|---|
| `power_cell` | Power Cell | 250 | +20 Power |
| `vital_plate` | Vital Plate | 200 | +100 Max HP |
| `swift_treads` | Swift Treads | 150 | +2 Move Speed |

The 14 pre-match items, the 18-point budget and item evolution were removed on 2026-09-17. Shop CSV events: `item_purchased`, `drone_departed`, `delivery_aborted`, `item_delivered`.

## New CSV event kinds

`stitch`, `stitch_mirror`, `full_send_launch`, `full_send_land` (`detail` = hit/miss, value = heroes hit), `crash_program_shockwave`, `knockback`, `wall_slam`, `flare_burst` (`detail` = hit/miss). Answer "Where is Crash Test now?" with `full_send_*` positions, and "Do Sunday's slow attacks land?" with `projectile_hit`/`projectile_miss` plus `flare_burst`. Existing IDs, including `crown_*` for the Double Damage Idol, are unchanged.

## Match pacing modifier (Development Cycle 001)

The catalog's hero HP and flat HP growth are multiplied by **1.4** when deployed in a match; damage and authored abilities are unchanged. Expanded three-lane travel, creep roles, tower defenses, retreat decisions and the timed Central Power Node are specified in [DESIGN.md](DESIGN.md#development-cycle-001-make-matches-breathe).
