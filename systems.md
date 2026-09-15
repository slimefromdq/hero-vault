---
layout: default
title: Systems
---

# Systems

[Overview](./) · [Heroes](heroes.html) · [Systems](systems.html) · [Items](items.html) · [Roadmap](roadmap.html) · [Agent Handoff](agent-handoff.html)

## Simulation

The simulation should make outcomes variable without making them opaque. Seeded randomness and inspectable event logging are preferred where supported by the codebase.

## Combat readability

Useful questions for any combat rule:
- Can a viewer tell what just happened?
- Can a developer reproduce it?
- Does it create character identity?
- Does it produce interesting long-run statistics?

## Progression

Current target: **13 hero levels**.

The repository remains the source of truth for:
- XP thresholds;
- per-level stat growth;
- unlock timing;
- whether modes/items can modify the cap.

## Ultimates

Current direction: ultimates use **long timers/cooldowns** rather than charge meters.

## Statistics and events

When practical, systems should emit structured events for:
- damage;
- healing;
- kills/deaths;
- ability use;
- item pickup/drop/transfer;
- level-ups;
- ultimate use;
- notable objective interactions.

This supports debugging, replays, spectator UI, and post-match analysis.
