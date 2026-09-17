extends RefCounted
## Hero item slots and item stat effects. Operates on battle unit dictionaries
## (u.items holds item IDs) so snapshots and replays copy inventories for free.
## Only the courier drone's handoff adds items; nothing here spends currency.

const ShopCatalog = preload("res://scripts/shop_catalog.gd")
const MAX_SLOTS := 6

static func empty_bonus() -> Dictionary:
	return {"power": 0.0, "max_hp": 0.0, "speed": 0.0}

static func free_slots(u: Dictionary) -> int:
	return MAX_SLOTS - u.items.size()

## Called when a delivery completes. Returns false if the item cannot be held.
static func add_item(b, u: Dictionary, item: String) -> bool:
	if u.get("creep", true) or not ShopCatalog.ITEMS.has(item) or free_slots(u) <= 0:
		return false
	u.items.append(item)
	refresh(b, u)
	return true

static func bonus_for(items: Array) -> Dictionary:
	var total := empty_bonus()
	for item in items:
		var stats: Dictionary = ShopCatalog.ITEMS.get(item, {}).get("stats", {})
		for stat in stats:
			total[stat] += float(stats[stat])
	return total

## Reconciles applied stat bonuses with the items this hero can currently use
## (Mexai's Pilfer temporarily moves an item's effect to the thief).
static func refresh(b, u: Dictionary) -> void:
	var wanted := bonus_for(b.effective_items(u))
	var applied: Dictionary = u.item_bonus
	var power: float = wanted.power - applied.power
	var health: float = wanted.max_hp - applied.max_hp
	var speed: float = wanted.speed - applied.speed
	if power == 0.0 and health == 0.0 and speed == 0.0:
		return
	u.damage += power
	u.speed += speed
	u.max_hp = maxf(1.0, u.max_hp + health)
	if u.hp > 0:
		# Gaining max HP also grants that HP; losing it only trims overflow.
		u.hp = clampf(u.hp + maxf(0.0, health), 1.0, u.max_hp)
	u.item_bonus = wanted

static func item_names(u: Dictionary) -> Array:
	return u.items.map(func(item): return ShopCatalog.ITEMS[item].name)
