---
layout: default
title: Systems
---

# Systems

[Overview](./) · [Heroes](heroes.html) · [Systems](systems.html) · [Items](items.html) · [Roadmap](roadmap.html) · [Agent Handoff](agent-handoff.html)

## Simulation

A fixed-step (0.05s) simulation with one seeded random-number generator. The same seed and squads always produce the same match. The camera and UI never change combat state.

## Combat readability

Useful questions for any combat rule:
- Can a viewer tell what just happened?
- Can a developer reproduce it?
- Does it create character identity?
- Does it produce interesting long-run statistics?

## Progression

Heroes level from **1 to 13**. Each level needs `level × 6` XP from nearby creep deaths (1), hero takedowns (3) and jungle camps (6). Each level adds hero-specific HP and damage. Some items evolve at levels 9 or 13.

## Ultimates

Ultimates use **long timers** (75–120s) that keep running through death. Each hero has its own conditions for when to spend a ready ultimate, and the CSV records how long it was held.

## Hits and misses

Ranged attacks are real projectiles that can miss moving targets; heroes sidestep visible shots. Melee attacks have a windup and miss if the target leaves range. Crash Test's charge can be sidestepped.

## Stability and collisions

Every hero has a Stability rating (1–10) that scales how far knockbacks push them. A hero pushed into the lane edge takes a wall slam (small damage and a brief stun). Crash Test has Stability 1 and is built for crashes.

## Statistics and events

Every match records structured events (damage, healing, kills, casts, projectile hits and misses, item activations, thefts, evolutions, cloak reveals and gank outcomes, Idol possession) and exports them as CSV for analysis in R.

## Three-lane map

North and south follow equal-length outer routes. Mid runs diagonally between the vaults and is shorter, bringing its waves into contact sooner. Each lane has one tower per team and receives three creeps per team each wave. A destroyed lane tower opens that approach to the opposing vault. Jungle camps flank the mid road, while the Double Damage Idol appears at the central crossing. Roamers choose among all three lanes based on enemy pressure and wounded opponents, collecting available camps during travel. FULL SEND lands on the nearest of the three roads.

Team Builder offers North, South, Jungle / roam and Mid. Saved assignments retain their original meanings (0 north, 1 south, 2 roam); mid uses assignment 3. New squads cover every lane with one jungle roamer.
