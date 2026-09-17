# Tabbed app navigation

The app now separates preparation from running games, with a persistent browser-style tab strip.

## Pages

- **Home:** inspect the saved team, queue a best-of-three against local rivals, and reopen current or completed games.
- **Team Builder:** choose the five heroes, two item slots each, lane assignments, squad name, plan and hero assignment. The 18-point budget still applies. Changes are drafts until **Save Team**; switching tabs retains the draft. **Discard edits** reloads the last saved team.
- **Game tabs:** one tab per opponent, containing only the battlefield, queued lineup, combat stats, events, camera controls and game-specific replays. No team-editing controls overlap the game.

Each queue creates three game tabs. Subsequent queues create new sets rather than replacing earlier games. A queued set holds an independent copy of the saved lineup and settings. Editing or saving a team never changes an already queued game.

All sets advance regardless of the selected page. Closing a tab closes only its view; reopen it from Home. Each game remembers its camera and replay selection. Pause and speed apply to the selected three-game set, leaving other sets running. Up to three unfinished sets may run concurrently; paused sets count toward this limit.

Completed games retain their results and available highlights for the current app session. Each finished set grants progression and exports its CSVs exactly once. Saved team, progression and queue numbering persist across app restarts. Running simulations and open game tabs are session-local and are not restored after quitting. This remains local AI queuing, not an online matchmaking service.

## Implementation

- `main.gd`: thin scene entry point.
- `app_shell.gd`: persistent navigation, page visibility, queue management, profile and completion rewards.
- `loadout_panel.gd`: embedded Team Builder page with a separate editable draft.
- `match_session.gd`: independent fixed-step simulations and per-game view/replay state.
- `battle.gd`, `catalog.gd`, `map_layout.gd` and `battle_view.gd`: existing gameplay and map presentation retained.

## Validation

`navigation_test.gd` checks page separation, drafts across tab switches, queued-state isolation, independent queues, background progress, closing/reopening tabs, per-game camera/replay state, targeted pausing, single completion rewards, saved-profile migration and the concurrent-queue cap. `session_test.gd` runs a complete queued set through the extracted session model. Existing combat checks remain applicable. Native Godot screenshots of Home, Team Builder and a game were visually inspected.

Run tests with a separate Godot user-data directory; UI tests deliberately write a fixture profile. Native `display_test.gd` checks F11 and camera shortcuts using a real window.
