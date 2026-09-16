# Visual clarity: combat text, damage breakdown, telegraphs, map

Added 2026-09-16. Everything here is presentation or analytics: none of it touches combat rules, positions or RNG. A four-match seed probe gives identical winners, clocks, kill counts, event sequences and final unit states before and after the change.

## Floating numbers

`battle.popups` holds short-lived entries (`time`, `pos`, `kind`, `amount`, `absorbed`, `crit`, `team`, `lift`), trimmed after `POPUP_SECONDS` (1.3 s) and copied into replay snapshots. `battle_view.draw_popups` draws them rising and fading, and scales the text down as the camera zooms in.

| Popup | Look |
|---|---|
| Basic attack (ranged or melee) | White number |
| Ability, splash | Orange number |
| Magic (gas, fire, sunlight, Stitch mirror) | Purple number |
| Wall slam | Steel-blue number |
| Crit (Lucky Coin) | Large gold number with `!` |
| Shield absorbed | Small green `(N shield)` under the number |
| Heal | Green `+N` |
| Miss (hero projectile expired, melee whiff) | Grey `MISS` |

Only damage to heroes and heals on heroes create popups; minion damage stays quiet. Popups at the same spot within 0.25 s stack upward.

## Damage breakdown

`apply_damage` now records each protection step:

- `raw_damage`: the amount passed in
- `boosted_damage`: after Execution Blade, Hammer, Lucky Coin and similar item bonuses
- `crit`: Lucky Coin tripled the hit
- `intercepted`: the amount Hold the Line moved to a protector (the protector gets its own row labelled `Hold the Line (covering X): …`)
- `defense`, `mitigated`: armor or resolve after modifiers, and the damage it removed (negative when defense is below zero, e.g. Glass Cannon)
- `bodyguard`: the amount Bodyguard Vest removed
- `absorbed`: the amount shields soaked up (existing column)
- `overkill`: damage beyond remaining HP
- `value`: HP actually lost (unchanged)
- `ability`: the source name (`Basic attack`, `Toxic gas`, `FULL SEND landing`, `Tower shot`, `Jungle guardian`, ultimate names, …)
- `transferred`: true for Hold the Line shares and Stitch mirroring

For each hero row: `boosted − mitigated − intercepted − bodyguard − absorbed − overkill = value`.

Callers name an ability by setting `battle.damage_label` just before `apply_damage`, which clears it. `area_hit` takes an optional label. Unlabelled hits fall back to `damage_source_name` (based on the damage kind, the attacker's ultimate, towers and camps).

`battle.damage_ledger` sums these values per hero target, keyed by source unit and ability. All minions share one "Minion" source. `damage_taken(id)` and `damage_dealt(id)` return sorted rows.

**In game:** use the **Damage breakdown** button, or press **D** in a game tab. With no hero followed, it shows a table of all ten heroes: incoming damage, defense, covered (Hold the Line plus Bodyguard), shields, HP lost and biggest source. Follow a hero (1–5 or click) to see a per-source table (hits, crits, each reduction step), a summary line and the damage that hero dealt to other heroes. Totals are cumulative for the live game.

## Readable action

- **Melee windups:** team-coloured wedge showing reach and arc (Eleanor's is wider because she cleaves), with a sweep line that fills as the swing lands. Swings are copied into snapshots (`swings`) with `total` and `reach`.
- **Dashes:** Leeching Cut (red) and Intercede (green) draw a dashed line and a ring on the target.
- **Ultimate windup:** the ultimate's name appears under the charging ring.
- **Projectiles:** fading tail plus a bright head.
- **Hit flash:** red pulse on a hero for 0.18 s after damage (`hurt_at`).
- **Stun:** three orbiting stars.
- **Status pills** above the name, most urgent first (up to four): STUN, STITCH, HIDDEN, SHIELD, HOLD, OVERP, RUSH, SAFE, PROGRAM, WARM, POWER/REGEN (jungle buff), RETREAT. These replace the old DISABLED/STITCHED/CRASH PROGRAM text.

## Map and jungle

Drawing only; `map_layout.gd` is unchanged.

- **Meadow:** grass tufts, flowers and stones, placed deterministically and never on roads or in the jungle.
- **Roads:** curb, worn centre track, cracks and edge stones.
- **Buildings:** stone plazas under both vaults; foundations under towers.
- **Jungle:** ragged canopy edge, undergrowth, dirt footpaths from each lane edge to the centre and on to each camp, a pond, and trees placed away from trails and clearings.
- **Camps:** lair-stone rings. Ember Beast has horns and a glow. Grove Guardian is a mossy stump with leaves. Camps flash when hit, and names and tags are centred.

## Validation

`tests/clarity_test.gd` checks that:

- popups and swings appear during play
- every hero damage row names its source
- ledger rows add up and match the CSV damage
- labels are used once and then cleared
- shield and defense steps are recorded
- replay snapshots keep popups and swings
- the new CSV columns exist
- stun is the first status pill
