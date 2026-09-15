# HERO//VAULT GitHub Pages Starter

This folder contains a lightweight documentation site plus `AGENTS.md`.

## Files

- `AGENTS.md` — coding-agent transfer/handoff contract
- `docs/index.md` — project overview
- `docs/heroes.md`
- `docs/systems.md`
- `docs/items.md`
- `docs/roadmap.md`
- `docs/agent-handoff.md`
- `docs/_config.yml` — GitHub Pages/Jekyll configuration

## Install into your repository

Copy:

```text
AGENTS.md  -> repository root
docs/      -> repository root/docs/
```

Commit and push the files to your default branch.

## Enable GitHub Pages

On GitHub:

1. Open the repository.
2. Go to **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select your default branch (usually `main`).
5. Select the `/docs` folder.
6. Save.

GitHub Pages will use `docs/index.md` as the site entry page.

## First repo-specific cleanup

Before relying on `AGENTS.md`, inspect the actual project and replace the `VERIFY IN REPO` placeholders for:
- engine/version;
- languages;
- directory map;
- hero/item data paths;
- build/run/test/lint commands;
- simulation/RNG architecture;
- implemented roster.

Do not fill these from memory or guesses.
