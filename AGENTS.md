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

### Known hero/category examples

These names are design references, not a guarantee that each is currently implemented:

- **Objects given life:** Poppet, Crash Test, Kiln
- **Fantasy:** Eleanor, Mexai
- **Circus:** Oddity, Irene
- **Other concepts discussed:** Hazmat, Sunday, a shark pirate, an anime mascot/toy character capable of cloning herself with a hive-mind flavor

**VERIFY IN REPO:** exact implemented roster, current names, stats, abilities, categories, assets, and status.

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
| Hero data location | `scripts/catalog.gd` |
| Item data location | `scripts/catalog.gd` |
| Simulation/combat core | `scripts/battle.gd` |
| UI/spectator layer | `scripts/app_shell.gd`, `scripts/battle_view.gd` |
| Automated tests | `tests/*_test.gd` |
| Formatting/lint tooling | No configured formatter/linter; use git diff --check |
| Asset pipeline | Godot imports bundled SVG/PNG; custom expression sheets load at runtime (docs/EXPRESSIONS.md) |
| Save/data compatibility constraints | **VERIFY IN REPO** |

### Build / run / test commands

Replace placeholders after repo inspection.

```powershell
# Import project.godot into Godot 4.7.2, or launch with an explicit executable:
./play.ps1 -GodotPath 'C:\path\to\godot.exe'
# Run each test with an isolated APPDATA/LOCALAPPDATA directory:
godot --headless --path . --script res://tests/navigation_test.gd
# Other headless checks: rework, battle, ui, map, duel, jungle, handoff, session.
# display_test.gd needs a real display. No formatter/linter is configured.
```

An agent must not claim validation succeeded if these commands have not actually been run.

---

## 5. Directory Map

Keep this section synchronized with the repository. Prefer a short map of architecturally important directories rather than dumping every file.

```text
/
|-- project.godot, play.ps1    # game entry and launcher
|-- scenes/                  # main scene
|-- scripts/                 # catalog, simulation, navigation and presentation
|-- assets/                  # SVG hero art and Godot import settings
|-- tests/                   # GDScript checks
|-- docs/                    # implementation and historical design notes
|-- index.md, heroes.md, items.md, systems.md, roadmap.md
|-- _config.yml              # existing root-level documentation site
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

**VERIFY IN REPO**:
- XP curve;
- stat growth method;
- ability unlock/upgrade points;
- whether level 13 is a hard cap everywhere;
- whether items or modes can modify progression.

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
Character expression uploads, transparent portrait backgrounds, editable reaction rules, and GitHub publication with an agent guide.

### What changed
- Added Team Builder → Character expressions: per-hero imports, grid/caption controls, previews, mappings, durations, low-health threshold, save/cancel and default restoration.
- Removed edge-connected pale backgrounds from Mexai and Hazmat while preserving enclosed white eyes; cached transparent textures preserve proportions.
- Included the earlier combat expressions and three-kill fire burst across battlefield, lineup and focus portraits.
- Added the user and implementation guide in [docs/EXPRESSIONS.md](docs/EXPRESSIONS.md), including persistence schema, extension points and testing instructions.
- GitHub destination: origin/main (slimefromdq/hero-vault). Personal uploads, test fixtures and captures remain under ignored user data.

### Files changed
- `scripts/expressions.gd`, `scripts/expression_editor.gd` and `.uid` files
- `scripts/app_shell.gd`, `scripts/battle.gd`, `scripts/battle_view.gd`, `scripts/loadout_panel.gd`
- `tests/expression_test.gd`, `tests/expression_editor_test.gd` and `.uid` files
- Both expression-sheet PNGs and `.import` files; retained previous Mexai assortment PNG, `.import` and `.tres` source assets
- `docs/EXPRESSIONS.md`, `README.md`, `AGENTS.md`

### Validation run
- Godot 4.7.2 headless editor import passed.
- Expression, expression-editor, UI/navigation, rework, session and battle checks passed. Battle test exercised nine full matches.
- Native editor capture inspected: cleaned portraits and Save/Cancel controls visible; dialog sizing has a regression check.
- `git diff --check` passed. Tests used isolated `.local-data/final-*` and `.local-data/import-*` directories.

### Known problems / warnings
- Godot emits the existing Windows root certificate store warning; checks passed.
- Imports require regular grids; bottom crop handles captions. Pale enclosed areas remain part of the artwork.
- Editor changes apply immediately to current replay presentation. Prior uploads are retained when replaced.
- Pre-existing `project.godot` line-ending-only status was preserved; no project setting change is needed.

### Next recommended action
Open Team Builder → Character expressions to import additional heroes or adjust reaction rules.

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

---

## 15. Known Issues / Open Questions

These are intentionally unresolved until the repo is inspected:

- What engine/framework is currently canonical?
- Where is hero data stored?
- Is the simulation deterministic when given a seed?
- What is the current hit/miss model?
- How are AI attack tendencies represented?
- How are match statistics stored and surfaced?
- How is the 13-level curve implemented?
- Are ultimate timers global, per-hero, or modified by stats/items?
- Which discussed heroes are implemented versus concept-only?
- Which items are implemented versus concept-only?
- Is there already a docs site or GitHub Pages workflow?

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
