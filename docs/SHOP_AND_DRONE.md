# Remote shop and courier drone

Added 2026-09-17. Replaces the pre-match 18-point item budget and its 14 items. The player doesn't control heroes. Instead, they back their heroes by buying upgrades and having the drone fly them across the map.

## Player flow

1. In a live game tab, select one of your heroes (click the hero, click their lineup row, or press 1–5).
2. The **Remote Shop** panel shows that hero's HP, Power, Speed, level, K/D, inventory (6 slots) and the team's shared credits.
3. Click an item. Credits are deducted immediately and a delivery order is created for that hero. The hero gets nothing yet.
4. The team's courier drone flies from the vault to the hero. The item enters the hero's inventory and its stats apply only when the handoff finishes.
5. The drone flies back to the vault before it takes the next order. Orders bought while it is busy wait in the queue.

Feedback line: `Purchased <item> / Delivering to <hero> / Drone ETA: Ns`, then `Delivered <item> to <hero>`. The left panel shows the drone's state, cargo, target and pending queue at all times. Shopping is disabled in replays and after the game ends.

## Architecture

```text
Shop UI (app_shell.gd -> match_session.purchase)
  -> battle.request_purchase(team, hero_id, item)
  -> ShopManager.request_purchase   validate, TeamEconomy.spend, create order, queue
  -> CourierDrone.update            claim_next -> fly -> handoff -> return
  -> ShopManager.complete           HeroInventory.add_item (stats apply here)
```

| Script | Responsibility |
|---|---|
| `scripts/team_economy.gd` | Shared credits: `can_afford`, `spend`, `add`, bounties, passive income. |
| `scripts/shop_catalog.gd` | Item data (IDs, cost, stats). |
| `scripts/shop_manager.gd` | Catalog access, purchase validation, order creation, FIFO delivery queue, rival auto-buy. |
| `scripts/courier_drone.gd` | State machine, cargo, target, straight-line travel, handoff, return, ETA estimate. |
| `scripts/hero_inventory.gd` | Item slots, adding delivered items, applying/removing stat bonuses. |
| `scripts/battle.gd` | Owns one economy/shop/drone per team, ticks them in `update_logistics`, pays bounties, snapshots `logistics`. |

The UI never touches the drone or hero stats directly.

## Drone state machine

`IDLE_AT_BASE -> DELIVERING -> HANDOFF -> RETURNING -> IDLE_AT_BASE`

- **IDLE_AT_BASE:** takes the first deliverable order and leaves on the same tick.
- **DELIVERING:** flies straight at the target's current position (95 units/s). Within 34 units, it switches to handoff.
- **HANDOFF:** 0.6s while following the target, then the item is delivered.
- **RETURNING:** flies back to the vault. It can't pick up anything until it lands.

It carries one order at a time. The drone is not a battle unit, so it is invulnerable and ignored by combat and AI.

## Orders and queue

An order has `id`, `hero_id`, `hero_name`, `item`, `cost`, `ordered_at`, `sequence`, `status` (`pending`, `in_transit`, `delivered`) and `attempts`.

- Queue order is purchase order (FIFO). Orders stay in `ShopManager.queue` until they are delivered, so an aborted order keeps its place.
- Orders for dead heroes are skipped (not dropped) until those heroes respawn.
- Queued orders reserve inventory slots, so a hero can never be sent more items than they can hold.
- Future manual reordering only needs to move entries within `queue`. The drone always reads the array in order.

## Target death

If the target dies during DELIVERING or HANDOFF, the delivery is aborted and the drone returns to base. The order goes back to `pending`, and the delivery is retried after the hero respawns. Nothing is refunded or lost.

## Economy (prototype numbers)

| Value | Amount |
|---|---:|
| Starting credits | 300 |
| Passive income | 2/s |
| Enemy hero takedown | +75 to the killing side |
| Enemy creep death | +6 to the other side |

## Prototype items

| ID | Name | Cost | Effect |
|---|---|---:|---|
| `power_cell` | Power Cell | 250 | +20 Power (basic and structure damage) |
| `vital_plate` | Vital Plate | 200 | +100 Max HP (also heals 100 when it arrives) |
| `swift_treads` | Swift Treads | 150 | +2 Move Speed |

These values aren't balanced. The items only exist to verify delivery and inventory behavior.

## Rival team

The red team has its own economy, shop and drone. Every 25s, if it has fewer than two orders queued, it buys through the same `request_purchase` path. It rotates through heroes and items without using RNG.

## Mexai

Pilfer and Grand Larceny now steal delivered items. `HeroInventory.refresh` moves the stolen item's stat bonus to Mexai for 8s, then returns it.

## Events (CSV)

`item_purchased`, `drone_departed`, `delivery_aborted` (`detail` = reason), `item_delivered` (`held_seconds` = purchase-to-arrival time). The fight story shows `DELIVERED / <ITEM>`.

## Not implemented yet

Item combining, upgrades, recipes, courier combat or destruction, multiple couriers, drone upgrades, queue reordering, final UI, models and VFX, and pathfinding beyond straight-line flight.
