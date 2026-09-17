# HERO//VAULT — Agent Handoff Guide

> **Purpose:** This file is the portable source of operational context for coding agents working on HERO//VAULT.
>
> **Rule zero:** Do not invent repository facts. Anything marked **VERIFY IN REPO** must be checked before acting on it.

## 1. Read This First

Before changing code, an incoming agent should:

1. Read this entire file.
2. Read the current `README.md`.
3. Inspect the repository tree.
4. Find the actual build/run/test commands and replace any stale placeholders in this file.
5. Read the most relevant design/data files for the requested task.
6. Check `git status` before editing.
7. Preserve unrelated user work.
8. Make the smallest coherent change that solves the task.
9. Run the relevant validation.
10. Update the **Session Handoff** section before stopping.

If documentation conflicts with executable code, **do not silently choose one**. Note the conflict, determine which is actually current, and update the stale source if appropriate.

---

## 2. Project Snapshot

**HERO//VAULT** is a game about watching a roster of highly distinct heroes interact, fight, scale, miss, clutch, and create readable statistical stories.

The viewing experience matters as much as mechanical balance. A good system should create:
- recognizable character identity;
- suspense without requiring direct player execution;
- visible cause-and-effect;
- surprising but legible outcomes;
- interesting statistics and post-match stories;
- enough randomness that outcomes do not feel solved.

### Current design direction

The following rules are current design intent and should be treated as high-priority unless later documentation explicitly supersedes them:

- Heroes should generally have **fewer abilities**, not sprawling kits.
- Prefer one ability with several understandable effects over multiple redundant abilities.
- Do **not** give every hero a bespoke subsystem just because one is possible.
- Mechanical complexity should serve character fantasy, not replace it.
- Many attacks/projectiles may **whiff** based on projectile speed, attack tendency, positioning, or other simulation factors.
- Players are primarily **watching heroes perform**, rather than manually executing every hero ability.
- Randomness is desirable when it produces suspense and remains understandable.
- Hero ultimates use a **long timer/cooldown model**, not a charge meter.
- Heroes currently progress through **13 levels**.
- Items should preferably do at least one of two things:
  1. ask an interesting statistical question; or
  2. create something fun to watch.
- Spectator readability beats invisible mathematical cleverness.
- Avoid mechanics that only become understandable after reading a paragraph of exceptions.

### Roster

Implemented (see `docs/CONTENT.md` and `scripts/catalog.gd`):

- **Objects given life:** Poppet, Crash Test, Kiln
- **Fantasy:** Eleanor, Mexai
- **Circus:** Oddity, Irene
- **Other:** Hazmat, Yellow Colony, Sunday

Crash Test and Sunday follow the user's design sheets (see `docs/CONTENT.md`). Poppet and Kiln are first-pass kits built from their names and categories; the user may replace them.

Concept only: a shark pirate; an anime mascot/toy character who clones herself (hive-mind flavor); a superhero tank-carry (Atlas, **parked** on 2026-09-15; do not re-add without being asked).

---

## 3. Source-of-Truth Order

When sources disagree, use this order unless the user says otherwise:

1. The user's explicit instruction in the current task
2. Current executable behavior and tests
3. Current game-data/config files
4. `AGENTS.md` / current design docs
5. Current issue/roadmap docs
6. Old design notes, chat summaries, archived prototypes

Do not resurrect an older mechanic merely because it exists in an abandoned file.

---

## 4. Repository Facts

Fill these in only after inspecting the actual repository.

| Fact | Current value |
|---|---|
| Engine / framework | Godot |
| Engine version | 4.7.2 (local executable); project targets 4.7 |
| Primary language(s) | GDScript |
| Default branch | `main` |
| Main game entry point | `project.godot` -> `scenes/main.tscn` |
| Hero data location | `scripts/catalog.gd` (data); `scripts/hero_kits.gd` (per-hero abilities, ultimates, AI quirks) |
| Item data location | `scripts/shop_catalog.gd` (in-match shop items); purchase/queue in `scripts/shop_manager.gd`; delivery in `scripts/courier_drone.gd`; stats in `scripts/hero_inventory.gd`; credits in `scripts/team_economy.gd` (see `docs/SHOP_AND_DRONE.md`) |
| Simulation/combat core | `scripts/battle.gd` |
| UI/spectator layer | `scripts/app_shell.gd`, `scripts/battle_view.gd` |
| Automated tests | `tests/*_test.gd` |
| Formatting/lint tooling | No configured formatter/linter; use git diff --check |
| Asset pipeline | Godot imports bundled SVG/PNG; custom expression sheets load at runtime (docs/EXPRESSIONS.md) |
| Save/data compatibility constraints | `user://squad.json`: retired heroes are swapped one-for-one (`Catalog.migrate_team`), saved pre-match `equipment` is ignored (items are bought in-match since 2026-09-17). CSV event IDs are stable (`crown_*` = Double Damage Idol). |

### Build / run / test commands

Verified locally on 2026-09-17:

```powershell
# Launch (uses -GodotPath, $env:GODOT, or godot on PATH):
./play.ps1
# Run each test with an isolated user-data directory (APPDATA/LOCALAPPDATA on Windows, HOME on Linux):
$godotExe = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = Join-Path $PWD '.local-data\checks\appdata'
$env:LOCALAPPDATA = Join-Path $PWD '.local-data\checks\cache'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
& $godotExe --headless --path . --script res://tests/roster_items_test.gd
# Other headless checks: courier, rework, battle, navigation, map, duel, jungle, handoff, session, expression, expression_editor, pacing.
# display_test.gd needs a real display (xvfb-run works on Linux). No formatter/linter is configured.
# Balance snapshot over random squads:
$env:N=45
& $godotExe --headless --path . --script res://tools/balance_probe.gd
```

An agent must not claim validation succeeded if these commands have not actually been run.

---

## 5. Directory Map

Keep this section synchronized with the repository. Prefer a short map of architecturally important directories rather than dumping every file.

```text
/
|-- project.godot, play.ps1    # game entry and launcher
|-- scenes/                  # main scene
|-- scripts/                 # catalog, simulation, hero kits, shop/drone logistics, navigation and presentation
|-- assets/                  # SVG hero portraits, expression sheets, Godot import settings
|-- tests/                   # GDScript checks
|-- tools/                   # balance probe
|-- docs/                    # CONTENT.md (current content), design and historical notes
|-- index.md, heroes.md, items.md, systems.md, roadmap.md
|-- _config.yml              # GitHub Pages (Jekyll) site served from the root
|-- AGENTS.md, README.md     # agent guide and play instructions
```

### Files an incoming coding agent should locate immediately

- Hero definitions / hero registry
- Ability definitions
- Combat resolution / hit resolution
- Projectile simulation
- AI / behavior tendencies
- Level progression
- Ultimate cooldown/timer logic
- Item definitions
- Match simulation / game loop
- Random-number generation and seeding
- Statistics/event logging
- Spectator UI
- Tests for any of the above

---

## 6. Architecture Guardrails

These are architectural preferences, not permission to refactor blindly.

### Prefer data-driven content

Hero identity should live in data/configuration where practical:
- base stats;
- ability references;
- attack tendency;
- projectile properties;
- cooldowns/timers;
- level scaling;
- tags/categories;
- AI weights;
- VFX/SFX references.

Avoid one enormous switch statement keyed on hero name if the architecture can support clean composition.

### Separate simulation from presentation

Where the existing architecture allows it:
- simulation decides what happened;
- event/stat logging records what happened;
- presentation shows what happened.

This makes deterministic testing, replay/debugging, and spectator readability easier.

### Randomness must be inspectable

If randomness affects outcomes:
- use the project's existing seeded RNG path;
- do not introduce a second hidden RNG source;
- log or expose enough information to debug surprising outcomes;
- make deterministic reproduction possible where feasible.

A projectile missing can be great television. A projectile missing for an unknowable reason is a bug-shaped fog cloud.

### Preserve stable identifiers

Do not casually rename:
- hero IDs;
- ability IDs;
- item IDs;
- serialized enum values;
- save keys;
- analytics/stat keys.

Human-facing display names may be easier to change than persistent identifiers. **VERIFY IN REPO** before renaming either.

---

## 7. Hero Design Contract

Use this when implementing or revising a hero.

### Identity test

A hero should be describable in one strong sentence:
> “This hero wins by ______.”

If that sentence requires a flowchart, simplify.

### Kit test

For each ability, ask:
- Does it express the hero fantasy?
- Does it do something visibly different from the other abilities?
- Does it create decisions or stories in the simulation?
- Can a spectator understand roughly what happened?
- Could this effect be folded into another ability instead?

### Complexity budget

Default toward:
- a clear basic attack or attack pattern;
- a small number of signature abilities;
- a passive only when it materially changes identity;
- one ultimate governed by a long timer/cooldown.

Do not add a unique resource meter, stance wheel, minigame, transformation tree, and stack system to a hero merely because each is individually interesting.

### Outcome uncertainty

The simulation may use:
- projectile travel time;
- projectile speed;
- aim/attack tendency;
- target movement;
- spacing;
- cooldown timing;
- target selection;
- controlled randomness

to produce misses and varied outcomes.

Randomness should not erase hero identity. A sniper can miss, but should still behave recognizably like a sniper over many observations.

### 13-level progression

Current design target: **13 levels**.

In the code (`battle.grant_xp`, `Catalog.GROWTH`):
- XP needed for the next level = `level × 6`; creep 1, hero takedown 3, jungle camp 6.
- Each level adds that hero's flat HP × 1.4 and basic damage. Starting HP also uses the 1.4 match pacing multiplier.
- Ability numbers scale with level inside `hero_kits.gd`; there are no unlock points. Yellow Colony grows every two levels.
- Level 13 is a hard cap (`Catalog.MAX_LEVEL`). Items do not change progression.

When changing progression, update simulations/tests that assume the cap.

---

## 8. Item Design Contract

Items should usually produce visible, analyzable consequences.

Good directions:
- conditional multipliers;
- tradeoffs;
- transferable objectives;
- effects that create possession history;
- effects that change kill/death patterns;
- effects that create a clear “did this pay off?” statistical question.

Avoid:
- tiny invisible bonuses with no spectator story;
- stacking several nearly identical percentage modifiers;
- mechanics whose main result is UI clutter.

For every implemented item, consider logging:
- pickups;
- drops;
- transfers;
- time held;
- damage/healing generated;
- kills/deaths while held;
- activation count;
- relevant before/after deltas.

---

## 9. Coding Conventions

**VERIFY IN REPO FIRST.** Follow existing conventions over this generic list.

Unless the repository clearly does otherwise:
- Keep functions small enough to name cleanly.
- Prefer explicit names over clever abbreviations.
- Do not duplicate game constants across files.
- Add comments for *why*, not for obvious syntax.
- Avoid drive-by formatting of unrelated files.
- Preserve existing public APIs unless the task requires a breaking change.
- Add or update tests when changing simulation rules.
- Keep content data separate from engine plumbing where the architecture supports it.

### Agent-generated code

An agent should:
- avoid placeholder code that looks production-ready but is nonfunctional;
- mark temporary scaffolding clearly;
- avoid silent fallbacks that hide missing data;
- avoid speculative abstractions for hypothetical future systems;
- avoid replacing a working subsystem wholesale without a concrete reason.

---

## 10. Data Schema Expectations

The exact schema must be read from the repo. Do not fabricate fields.

A hero definition will likely need concepts equivalent to:

```text
Hero
- stable id
- display name
- category/tags
- base stats
- growth/scaling
- attack definition
- abilities
- ultimate
- behavior/AI tendencies
- presentation references
```

An ability will likely need concepts equivalent to:

```text
Ability
- stable id
- cooldown/timer
- targeting rule
- range / geometry
- effect(s)
- projectile data, if applicable
- AI usage conditions/weights
- presentation references
- event/stat hooks
```

These are conceptual checklists, **not mandated field names**.

---

## 11. Testing Strategy

When modifying simulation code, prefer tests that answer player-visible questions.

Examples:
- Can a projectile actually miss under the intended conditions?
- Given a fixed seed, is the result reproducible?
- Does an ultimate become available on the intended timer?
- Can a hero exceed level 13 accidentally?
- Does an item transfer/drop correctly on death?
- Are events logged exactly once?
- Do 1,000 simulated matches reveal an obviously broken distribution?

### Statistical sanity checks

For probabilistic mechanics:
- run enough seeded simulations to detect extreme regressions;
- compare distributions, not one lucky/unlucky match;
- record the seed for failures;
- do not “fix” randomness by forcing every short sample to look average.

---

## 12. Agent Workflow

### Before coding

Record:
- requested task;
- relevant files;
- assumptions;
- validation plan.

### While coding

Keep a small decision trail for non-obvious choices. If a decision changes game design, add it to the Decision Log.

### Before handing off

An agent must leave:

1. A clean summary of what changed.
2. Exact files changed.
3. Validation actually run.
4. Any failures or warnings.
5. Any repo facts discovered that should update this document.
6. One clear next action if work remains.

Never leave the next agent with “continue where I left off” and no coordinates.

---

## 13. Session Handoff

### Current objective
Remote shop + courier drone rework (2026-09-17). Implemented and validated. It replaces the placeholder pre-match item budget. Previous handoff (Development Cycle 001: Make Matches Breathe) is summarized in `docs/DESIGN.md`.

### What changed
- **Removed** the 18-point pre-match budget, all 14 items, item evolution, Team Builder item slots and all item rules (execution, first hit, coin, cloak/invisibility, scout, rations, sole, bodyguard, glass, revenge, kill streak, ambush, last stand, coward) from `battle.gd`, `catalog.gd`, `loadout_panel.gd`, `app_shell.gd` and tests. `Catalog.validate(team)` now takes only the team. `Battle.setup(seed, plan, assignment, rival, team, orders)` and `MatchSession.setup(number, name, team, lanes, plan, assignment)` lost their equipment parameter. Old saves' `equipment` is ignored.
- **Added** `team_economy.gd`, `shop_catalog.gd`, `shop_manager.gd`, `courier_drone.gd`, `hero_inventory.gd`. `battle.gd` owns one economy, shop and drone per team, ticks them in `update_logistics` (before the intermission freeze, so deliveries continue), pays bounties on deaths, and includes `logistics` in frames and snapshots.
- Three prototype items: Power Cell (+20 Power), Vital Plate (+100 Max HP), Swift Treads (+2 Move Speed). HeroInventory applies bonuses as reconciled deltas, so Mexai's Pilfer moves a stolen item's stats to him and back.
- Game page: the bottom panel is now the hero-centric **Remote Shop** (selected hero stats, inventory, credits, three buy buttons, purchase/ETA feedback). The left panel shows persistent **drone status** (state, cargo, target, queue). Drones are drawn on the map as diamonds with a line to their target.
- Red team auto-buys through the same shop.

### Files changed
- New: `scripts/team_economy.gd`, `scripts/shop_catalog.gd`, `scripts/shop_manager.gd`, `scripts/courier_drone.gd`, `scripts/hero_inventory.gd`, `tests/courier_test.gd`, `docs/SHOP_AND_DRONE.md`
- Modified: `scripts/battle.gd`, `scripts/catalog.gd`, `scripts/hero_kits.gd`, `scripts/match_session.gd`, `scripts/app_shell.gd`, `scripts/loadout_panel.gd`, `scripts/battle_view.gd`, `tools/balance_probe.gd`, `tests/roster_items_test.gd`, `tests/rework_test.gd`, `tests/navigation_test.gd`, `tests/session_test.gd`
- Docs: `README.md`, `AGENTS.md`, `items.md`, `systems.md`, `roadmap.md`, `docs/CONTENT.md`, `docs/DESIGN.md`, `docs/TABBED_UI.md`

### Validation run
Run on Linux with Godot 4.7.2 headless, each test with its own HOME, on 2026-09-17:
- New `courier` test passes. It covers all 13 acceptance steps (immediate charge, no stats before arrival, departure, handoff, +20 Power, return, queued second order, pickup after return, death abort without refund, idle wait while target is dead, retry after respawn, +100 Max HP, +2 Speed), plus validation (unaffordable, enemy hero, unknown item, slot reservation, match over), FIFO with dead-target skipping, snapshot copies, a live-match delivery and rival auto-buy.
- `roster_items`, `rework`, `navigation`, `map`, `duel`, `jungle`, `handoff`, `session`, `expression`, `expression_editor`, `pacing` pass.
- **`battle` fails 2 checks.** Of the nine standard seeded matches, one (plan 0 vs rival 1, seed 4830) reaches 20:00 without a destroyed vault. It still stalls with rival auto-buy disabled, so the cause is removing the old items (which shifted the tuned pacing and RNG sequence), not the shop. The other eight end in 12:19–16:59. Blue wins 0/9 because the test never buys for blue. Pacing has not been re-tuned.
- `display` could not be validated here: under Xvfb (no window manager), its fullscreen assertion fails for the untouched baseline too. Run it on Windows. A rendered capture of the game page (shop panel, drone status, drone on map, delivery event) was checked by eye.

### Known problems / warnings
- `.uid` files for the six new scripts/tests were generated by headless Godot 4.7.2 and included.
- `tests/battle_test.gd` duration sweep currently fails on one seed (see above). The likely fix is a pacing re-tune, or starting blue on an auto-buyer in the sweep, once real items exist.
- Economy numbers and item stats are unbalanced placeholders. Removing the old items changes match outcomes and pacing numbers from Development Cycle 001, and they have not been re-tuned.
- ETA is an estimate that assumes heroes stay put. Drones fly in straight lines, even over the jungle.
- Fight story also lists rival deliveries (`DELIVERED / ...`).

### Next recommended action
Play a set and judge whether delivery time creates meaningful decisions. Then tune credits/income and design real items (components/combination) on top of `shop_catalog.gd`.

---
## 14. Decision Log

Add entries only for decisions with future consequences.

| Date | Decision | Reason | Files / systems affected |
|---|---|---|---|
| 2026-09-15 | Ultimates use long timers/cooldowns rather than charge meters. | Current design direction. | Hero/ultimate systems |
| 2026-09-15 | Current hero progression target is 13 levels. | Current design direction. | XP/level scaling |
| 2026-09-15 | Prefer fewer, broader abilities and avoid unnecessary bespoke mechanics. | Preserve readability and hero identity. | Hero design |
| 2026-09-15 | Controlled randomness, including projectile misses, is part of spectator suspense. | Outcomes should remain uncertain and watchable. | Combat/AI/RNG |
| 2026-09-15 | Items should create statistical questions or entertaining visible outcomes. | Supports HERO//VAULT's viewing-first identity. | Items/stats/UI |
| 2026-09-15 | Tank-carry superhero (Atlas) is parked and removed from the game. | User request. | Catalog, battle, assets |
| 2026-09-15 | Items evolve once, at an announced threshold, and only for their owner. *(Superseded 2026-09-17: evolving pre-match items removed.)* | Burst evolution creates spectator events; theft stays temporary. | Catalog `evolve`, battle item rules, UI |
| 2026-09-15 | Hero-specific rules live in `hero_kits.gd` as static functions. | Keeps `battle.gd` generic without a battle↔kit reference cycle. | Simulation architecture |
| 2026-09-16 | Stability (1–10) scales knockback; lane edges cause wall slams. | Crash Test's design ("worst Stability, built for crashes") and general physical comedy. | battle `knockback`/`wall_slam`, catalog |
| 2026-09-17 | Retain three lanes, expand travel by 2.5×, strengthen creep waves/towers, add retreat recovery and a four-minute power node. | Development Cycle 001; user explicitly said to keep three lanes. | Map, battle AI, objective, spectator, pacing tests |
| 2026-09-17 | Add a shorter diagonal mid lane; preserve saved roaming assignment 2 and use 3 for mid. | User requested a third-lane experiment; preserve saves while testing earlier central pressure. | Map, simulation, Team Builder, spectator |
| 2026-09-17 | Replace the pre-match 18-point item budget (14 items, evolutions) with an in-match remote shop and physical courier-drone delivery. Items never apply instantly; stats apply on handoff. | Core identity: the player supports autonomous heroes through purchase logistics. User chose full removal of the old system. | New logistics scripts, battle, catalog, Team Builder, game UI, tests |
| 2026-09-17 | One drone per team, one order per trip, FIFO queue; return to base between trips. Dead targets abort the trip and are retried after respawn, with no refund and no loss. Drone is invulnerable and invisible to combat for now. | User spec; limits come from travel time only. | `courier_drone.gd`, `shop_manager.gd` |
| 2026-09-17 | Rival team shops through the same ShopManager path (deterministic rotation every 25s). | User chose symmetric logistics so the shop is not a one-sided buff. | `shop_manager.gd` |
| 2026-09-16 | Airborne heroes cannot be targeted or damaged. | FULL SEND must commit without mid-flight interaction. | battle, hero_kits flight |

---

## 15. Known Issues / Open Questions

Answered from the code (2026-09-15):

- Engine: Godot 4.7.2, GDScript.
- Hero data: `scripts/catalog.gd`; hero behavior: `scripts/hero_kits.gd`.
- Determinism: yes; one `RandomNumberGenerator` seeded per match (`tests/roster_items_test.gd` and `rework_test.gd` check it).
- Hit/miss: projectiles are simulated and can be dodged; melee has a windup and a range check; Crash Test's charge can be sidestepped.
- AI tendencies: 1–5 ratings in `Catalog.PROFILES`, plus per-hero `target_bias` in `hero_kits.gd`.
- Statistics: `battle.records` rows, exported with `export_csv`.
- Levels: `Catalog.MAX_LEVEL = 13`; XP needed per level = `level × XP_PER_LEVEL`.
- Ultimate timers: per hero (`Catalog.ULTIMATES`); not currently modified by items.
- Items: bought in-match from a per-team remote shop and flown to heroes by a courier drone (`docs/SHOP_AND_DRONE.md`).
- Docs site: Jekyll from the repository root.

Still open:

- Final kits for Poppet and Kiln.
- Spectator world objects beyond the Idol, and object possession history.
- The tank-carry archetype (parked), the shark pirate and the cloning mascot.

---

## 16. Prompt Template for a New Coding Agent

Copy this into a new agent session:

```text
You are working on HERO//VAULT.

First read AGENTS.md in full, then inspect the repository before making changes.
Do not invent repo facts. Resolve every relevant VERIFY IN REPO marker from actual files.
Preserve unrelated work and follow existing conventions.

Task:
[PASTE TASK]

Before editing:
1. identify the relevant files and current architecture;
2. summarize the smallest coherent implementation plan;
3. note any design conflict with AGENTS.md.

While editing:
- keep simulation behavior inspectable;
- preserve seeded randomness/determinism if the repo supports it;
- favor spectator readability and hero identity;
- do not add unnecessary bespoke mechanics.

Before stopping:
- run relevant validation;
- update AGENTS.md Session Handoff;
- list files changed, tests run, unresolved issues, and the next action.
```

---

## 17. Documentation Rule

When a code change materially alters:
- hero behavior;
- item behavior;
- progression;
- randomness;
- combat resolution;
- spectator/stat systems;
- repository architecture;
- build/test commands

update the relevant documentation in the same change.

The goal is simple: the next agent should inherit a **map**, not an archaeological dig.
