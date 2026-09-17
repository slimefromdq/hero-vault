# Character expressions and portrait uploads

Open **Team Builder → Character expressions**. Choose a hero, then **Upload expression sheet** to select a PNG, JPG or WebP. This imports a local copy into the game's user-data folder; it does not publish personal uploads to GitHub.

## Import and preview

- Sheets can be up to 4096 × 4096 pixels and 32 MB.
- Set Columns and Rows for a regular grid containing at least 12 cells. The first 12 cells are read left to right, then down.
- Bottom crop % removes captions from each cell. Built-in Mexai and Hazmat sheets use their authored crop regions; grid controls apply to uploaded replacements.
- Remove pale background clears only pale pixels connected to cell edges. Enclosed white eyes and other enclosed details remain intact. Transparent padding is trimmed and the result is centered on a square transparent canvas without stretching.
- Faces follow this order: neutral, smug, angry, happy, attack, panic, hurt, dazed, upset, excited, knocked out, special.
- Each row previews the face assigned to that reaction. Use the dropdown to change the assignment, including choosing Neutral to suppress a distinct reaction.
- Save expressions applies to the selected hero across Home, Team Builder, battle tokens, lineup portraits and the focus panel. Cancel preserves saved settings. Switching heroes discards the previous hero's unsaved draft. Restore defaults previews the bundled art and rules; save to apply it.

The bundled sheets remain unchanged in `assets/`. Background cleanup happens once per sheet load, and textures are cached. The original artwork is not repainted. The pale area enclosed inside a portrait's drawn outline is retained.

## Reaction rules

| Reaction | Default face | Default timing |
|---|---|---|
| Idle / preparation | Neutral | While idle |
| Successful theft | Smug | 1.2 seconds |
| Missed attack or dash | Angry | 0.9 seconds |
| Hero takedown / victory | Happy | 1.8 seconds / match result |
| Melee windup or projectile launch | Attack | 0.7 seconds |
| Low health | Panic | Below 25% HP |
| Actual HP damage | Hurt | 0.65 seconds |
| Stunned | Dazed | While stunned |
| Defeat | Upset | Match result |
| Level / ultimate ready / camp clear | Excited | 1.2 seconds |
| Knocked out | Knocked out | While dead |
| Ultimate cast / active special | Special | 1.5 seconds / while charging, Overpressure or Grand Larceny is active |

Each hero has editable face assignments, timed reaction durations (0–10 seconds), and a low-health threshold (1–99%). Timed duration zero disables that timed reaction. Victory and active-special conditions persist while active even if their timed duration is zero.

Priority remains: KO, match result, stun, low health, active ultimate, then timed special, hurt, happy, smug, angry, excited and attack. Duration changes do not reorder priorities. Settings apply immediately to existing games and replay presentation; replay event timestamps remain unchanged. Pauses hold animation time and match speed changes animation speed. These settings do not affect combat rules or RNG.

## Killstreak fire

Three consecutive enemy hero kills while alive trigger orange-and-gold flames for three simulation seconds. Additional hero kills refresh the burst; death clears it and creeps do not count. Battlefield, lineup and focus portraits share the effect. `portrait_streak` and `portrait_fire_until` are cosmetic and independent of the Kill Crown item's power stacks.

## Agent implementation guide

- `scripts/expression_editor.gd`: hero-specific draft, file picker, validation, live previews, face assignments, durations, save/reset controls.
- `scripts/expressions.gd`: built-in regions, runtime image loading, edge-connected background cleanup, square framing, cached textures, profile persistence, reaction resolver, and fire drawing.
- `scripts/battle.gd`: existing event hook calls `Expressions.record`; bounded cue expiry timestamps and cosmetic streak fields are copied into unit snapshots. Never consume RNG for portraits.
- `scripts/app_shell.gd` and `scripts/battle_view.gd`: use the library's instance `resolve()` so saved overrides apply. Preparation portraits use the saved neutral mapping.
- `scripts/loadout_panel.gd`: editor entry point and refreshed preparation portraits.

`user://expressions.json` stores profiles keyed by stable hero ID. Each profile contains `path`, `columns`, `rows`, `trim`, `remove_background`, `low_health`, `mapping`, and `durations`. `mapping` is keyed by reaction names in `NAMES`; values are face names. `durations` is keyed by timed reaction names in `DURATIONS`. `path` is empty for bundled artwork. Imported files are copied as PNGs to `user://expression_sheets/`. Settings are replaced using a temporary file and rename; the running library updates only after persistence succeeds. Previous imported copies are retained, so replacing a sheet does not delete user artwork. Missing files produce a warning and fall back to the hero SVG.

The launcher redirects user data under `.local-data/`, which is ignored by Git. Never commit user profiles, test saves or captures. New bundled sheets can be registered in `SHEETS`; uploads need no code changes. Preserve stable hero IDs, default event durations (used to reconstruct cue start time), and the distinction between timed cues and persistent state. If changing default durations, update both `DURATIONS` and event recording.

## Validation

Run Godot 4.7.2 with isolated APPDATA and LOCALAPPDATA directories:

```powershell
& $GodotPath --headless --path . --script res://tests/expression_test.gd
& $GodotPath --headless --path . --script res://tests/expression_editor_test.gd
& $GodotPath --headless --path . --script res://tests/navigation_test.gd
& $GodotPath --headless --path . --script res://tests/rework_test.gd
```

The expression checks cover all built-in faces, transparency, reactions, timing, replay isolation and streak fire. Editor integration checks cover grid validation, preservation of enclosed white detail, import preview, copy-on-save, restart persistence, custom mapping/duration/threshold, cancellation, default restoration and dialog size. For native visual QA, run `expression_editor_test.gd` without `--headless` and append `-- --capture-editor`; it writes `.local-data/expression-editor.png`. Test fixtures and uploads stay in isolated user data.
