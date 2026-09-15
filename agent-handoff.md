---
layout: default
title: Agent Handoff
---

# Agent Handoff

[Overview](./) · [Heroes](heroes.html) · [Systems](systems.html) · [Items](items.html) · [Roadmap](roadmap.html) · [Agent Handoff](agent-handoff.html)

The full machine-facing handoff lives at [`/AGENTS.md`](../AGENTS.md).

## The short version

Every incoming coding agent should:

1. read `AGENTS.md`;
2. inspect the repo before assuming architecture;
3. preserve unrelated work;
4. make the smallest coherent change;
5. run real validation;
6. update the Session Handoff before stopping.

The handoff file deliberately distinguishes **design canon** from **facts that must be verified in code**.

## Current design canon

- fewer, broader hero abilities;
- no unnecessary bespoke mechanic for every hero;
- controlled randomness is part of the spectacle;
- projectiles may plausibly miss;
- ultimates use long timers/cooldowns;
- hero progression currently targets 13 levels;
- items should create statistical questions or visible fun.
