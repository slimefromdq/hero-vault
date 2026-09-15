# hero//vault

A Godot 4.7.2 MOBA autobattler and spectator simulation. Choose five heroes, assign lanes and spend a shared 18-point item budget. Watch three autonomous battles and win two of three.

## Play

Run `./play.ps1` or import `project.godot` into Godot 4.7.2 and press F5. Use the permanent **Team Builder** tab to choose heroes, items, lanes and strategy, then **Save Team**. Return **Home** and choose **Queue 3 Games**. The starter lineup costs **17/18** points, with two distinct item slots per hero.

F11 toggles fullscreen. Click a hero or press 1–5 to follow; scroll to zoom. Press 0/Escape to restore overview. Each game gets a separate tab. Build your next team while queued games continue; saved edits never change an existing lineup. Close and reopen game tabs from Home without resetting games. Pause/speed controls affect only that queued set. Highlights, saved progression and CSV exports remain available.

## Tabbed navigation

Home, Team Builder and game views are separate pages. Up to three sets (nine local games) may run concurrently. Team drafts survive tab switches; save explicitly before queuing. Completed tabs keep results and replays for the current app session. Running games are local and end when the app closes; saved teams and account progression persist. See [navigation notes](docs/TABBED_UI.md).

## September 15 rework

- Replaced the shop with the nine items from the supplied screenshot. Double Damage Idol is a jungle-spawned world pickup, never a purchasable item.
- Narrowed the physical map by 30% and reduced base hero radii from 28 to 17. Colony still grows through 13 levels.
- Reworked Hazmat, Irene, Oddity, Mexai and Eleanor around the current hero table. Melee attacks now have real range and windup checks; ranged attacks can miss in flight.
- Removed Oddity's Irene-following and protection behavior, including copied protective effects.
- Added temporary inventory theft, maximum-HP theft, red gas, Blood Rush, Intermission, and Eleanor's damage interception.

See [the complete rework notes](docs/REWORK_2026-09-15.md) for every kit, item, timer, numerical tuning choice and validation detail.

Old saves retain roster and progression; retired equipment becomes empty slots. Use **Restore starter squad** in the builder to try the new default equipment. This only changes preparation when you save the squad. The launcher stores saves under `.local-data/`.

## Project structure

- `scripts/catalog.gd`: hero profiles, stats, item descriptions/costs and roster validation.
- `scripts/battle.gd`: seeded fixed-step simulation and structured event export.
- `scripts/map_layout.gd`: shared physical map geometry.
- `scripts/battle_view.gd`: presentation and spectator camera.
- `scripts/main.gd`: scene entry point.
- `scripts/app_shell.gd`: persistent tabs, page navigation, queue, profile and results.
- `scripts/loadout_panel.gd`: standalone Team Builder page and unsaved draft.
- `scripts/match_session.gd`: independent queued simulations, per-game cameras and replays.

All heroes cap at 13. Ultimates use long cooldown timers that continue through death, not charge resources. Temporary effects are reversible and recorded in replay state. `damage` CSV records now report actual HP damage after mitigation/shields, with an `absorbed` field; `heal` records actual restored HP. Item activations include `item` IDs. Historical `crown_*` event names refer to Double Damage Idol, preserving the existing export identifiers.

## Checks

Run your Godot executable with `--headless --path . --script res://tests/NAME_test.gd` for `navigation`, `rework`, `battle`, `ui`, `map`, `duel`, `jungle` and `handoff`. `content` delegates to the rework specification. Run `display` with a real display to test fullscreen switching. Use a separate test user-data directory so UI tests do not overwrite your personal squad save.

The previous handoff is retained as historical source material. The September 15 rework notes take precedence for current content. Online matchmaking, authored animation, advanced AI, generalized Stability and an R dashboard remain future work.
