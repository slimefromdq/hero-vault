# Documentation site setup

The GitHub Pages site is built from the **repository root** with Jekyll (`_config.yml`). Pages: `index.md`, `heroes.md`, `systems.md`, `items.md`, `roadmap.md` and `agent-handoff.md`. Longer design notes live in `docs/` and are linked from those pages.

## Enable GitHub Pages

1. Open the repository on GitHub.
2. Go to **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select `main` and the `/ (root)` folder.
5. Save.

`_config.yml` excludes the Godot project folders from the site build.

## Keeping it current

When heroes, items or systems change, update `docs/CONTENT.md` first, then the matching site page. `AGENTS.md` describes the full documentation rule for coding agents.
