# hero//vault

A Godot 4.7.2 MOBA autobattler and spectator simulation. Choose five heroes, assign lanes and spend a shared 18-point item budget. Watch three autonomous battles and win two of three.

## Play

Run `./play.ps1` (it uses `-GodotPath`, the `GODOT` environment variable, or `godot` on your PATH), or import `project.godot` into Godot 4.7.2 and press F5. The launcher keeps saves under `.local-data/`.

Use the **Team Builder** tab to choose heroes, items, lanes and strategy, then **Save Team**. Return **Home** and choose **Queue 3 Games**. The starter lineup costs **17/18** points, with two distinct item slots per hero. Hover an item to see what it evolves into.

F11 toggles fullscreen. Click a hero or press 1–5 to follow; scroll to zoom; 0/Escape restores the overview. Each game gets its own tab and keeps running while you build your next team. Pause/speed controls affect only that queued set. See [navigation notes](docs/TABBED_UI.md).

**Team Builder → Character expressions** lets you upload expression sheets and customize reactions. See the [expressions guide](docs/EXPRESSIONS.md).

## Content

Ten heroes: Hazmat, Irene, Oddity, Mexai, Eleanor, Yellow Colony, **Poppet**, **Crash Test**, **Kiln** and **Sunday**. Fourteen items, including **Ambush Shield**, **Invisible Cloak** and three 1-point items (Lane Rations, Scout Pin, Tempered Sole). Six items **evolve** once into a stronger named version at a visible threshold. The Double Damage Idol is a jungle pickup, never a purchasable item.

Full kits, numbers and evolution rules: [docs/CONTENT.md](docs/CONTENT.md). Design direction: [docs/DESIGN.md](docs/DESIGN.md).

Old saves keep their progression. Retired heroes are swapped one-for-one for unused current heroes, and retired equipment becomes empty slots.

## Project structure

- `scripts/catalog.gd`: hero stats, behavior ratings, ultimates, items and evolutions, rival squads, validation and save migration.
- `scripts/battle.gd`: seeded fixed-step simulation (movement, damage, items, objectives) and CSV event export.
- `scripts/hero_kits.gd`: per-hero signature abilities, ultimates and AI quirks.
- `scripts/map_layout.gd`: shared map geometry.
- `scripts/battle_view.gd`: battlefield drawing and spectator camera.
- `scripts/app_shell.gd`: tabs, queue, profile and results. `scripts/main.gd` is the scene entry point.
- `scripts/loadout_panel.gd`: Team Builder page and unsaved draft.
- `scripts/match_session.gd`: queued simulations, per-game cameras and replays.
- `scripts/expressions.gd`, `scripts/expression_editor.gd`: portrait reactions and the sheet editor.
- `tools/balance_probe.gd`: runs random squads and prints per-hero win rate, K/D, damage and healing.

All heroes cap at 13. Ultimates use long cooldown timers that continue through death, not charge resources. `damage` CSV rows report actual HP damage after mitigation and shields, with an `absorbed` field; `heal` rows report actual restored HP. Historical `crown_*` event names refer to the Double Damage Idol.

## Checks

Run each test with a separate user-data directory so UI tests don't overwrite your squad:

```sh
godot --headless --path . --script res://tests/NAME_test.gd
```

Headless tests: `roster_items`, `rework`, `battle`, `navigation`, `map`, `duel`, `jungle`, `handoff`, `session`, `expression`, `expression_editor`. `display` needs a real window. Balance snapshot: `N=45 godot --headless --path . --script res://tools/balance_probe.gd`.

Online matchmaking, authored animation, spectator world objects, advanced AI, generalized Stability and an R dashboard remain future work.
