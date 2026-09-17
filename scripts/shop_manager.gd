extends RefCounted
## A team's remote shop: the item catalog, purchase validation and the FIFO
## delivery queue. UI calls request_purchase(); the CourierDrone pulls orders
## with claim_next() and reports back with release() or complete().

const ShopCatalog = preload("res://scripts/shop_catalog.gd")
const HeroInventory = preload("res://scripts/hero_inventory.gd")
const ITEM_IDS := ShopCatalog.ITEM_IDS
const ITEMS := ShopCatalog.ITEMS
const PENDING := "pending"
const IN_TRANSIT := "in_transit"
const DELIVERED := "delivered"
const AUTO_BUY_INTERVAL := 25.0
const AUTO_BUY_MAX_QUEUE := 2
const HISTORY_LIMIT := 12

var team := 0
var economy
var auto_buy := false
var auto_clock := AUTO_BUY_INTERVAL
var auto_turn := 0
var next_order_id := 1
# Array order is delivery order. Orders stay here until delivered, so an aborted
# delivery keeps its place. Manual reordering can later move entries in this array.
var queue: Array = []
var delivered: Array = []

func _init(team_index: int, team_economy, automatic: bool = false) -> void:
	team = team_index
	economy = team_economy
	auto_buy = automatic

static func item_name(item: String) -> String:
	return ITEMS[item].name if ITEMS.has(item) else item

static func item_cost(item: String) -> int:
	return int(ITEMS[item].cost) if ITEMS.has(item) else 0

func pending_for(hero_id: int) -> int:
	return queue.filter(func(order): return order.hero_id == hero_id).size()

## Validates, charges immediately and queues a delivery. Never touches the hero's
## inventory: the item only exists in the world as cargo until the drone arrives.
func request_purchase(b, hero_id: int, item: String) -> Dictionary:
	if b.winner != -1:
		return fail("The match is over.")
	if not ITEMS.has(item):
		return fail("Unknown item.")
	var hero: Dictionary = b.get_unit(hero_id)
	if hero.is_empty() or hero.creep or hero.team != team:
		return fail("Select one of your heroes first.")
	if HeroInventory.free_slots(hero) - pending_for(hero_id) <= 0:
		return fail("%s has no free item slots (including items on the way)." % hero.name)
	var cost := item_cost(item)
	if not economy.spend(cost):
		return fail("Not enough credits: %s costs %d, team has %d." % [item_name(item), cost, economy.balance()])
	var order := {"id": next_order_id, "hero_id": hero_id, "hero_name": hero.name, "item": item,
		"cost": cost, "ordered_at": b.clock, "sequence": next_order_id, "status": PENDING, "attempts": 0}
	next_order_id += 1
	queue.append(order)
	b.record_event("item_purchased", hero_id, -1, cost, {"item": item, "detail": "order %d" % order.id})
	var eta: float = b.couriers[team].estimate_eta(b, self, order.id)
	return {"ok": true, "order": order.duplicate(), "eta": eta,
		"message": "Purchased %s / Delivering to %s" % [item_name(item), hero.name]}

func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "order": {}, "eta": -1.0}

## FIFO, skipping orders whose hero is dead. Those keep their place and are
## retried as soon as the hero is back.
func claim_next(b) -> Dictionary:
	for order in queue:
		if order.status != PENDING:
			continue
		var hero: Dictionary = b.get_unit(order.hero_id)
		if hero.is_empty() or hero.hp <= 0:
			continue
		order.status = IN_TRANSIT
		order.attempts += 1
		return order
	return {}

## Delivery aborted (target died). Nothing is refunded or lost.
func release(b, order_id: int, reason: String) -> void:
	var order := find(order_id)
	if order.is_empty():
		return
	order.status = PENDING
	b.record_event("delivery_aborted", order.hero_id, -1, order.cost, {"item": order.item, "detail": reason})

func complete(b, order_id: int) -> bool:
	var order := find(order_id)
	if order.is_empty():
		return false
	var hero: Dictionary = b.get_unit(order.hero_id)
	if hero.is_empty() or hero.hp <= 0 or not HeroInventory.add_item(b, hero, order.item):
		release(b, order_id, "handoff failed")
		return false
	order.status = DELIVERED
	order["delivered_at"] = b.clock
	queue.erase(order)
	delivered.append(order)
	if delivered.size() > HISTORY_LIMIT:
		delivered.pop_front()
	b.record_event("item_delivered", hero.id, -1, order.cost, {"item": order.item, "held_seconds": b.clock-order.ordered_at})
	b.log_event("DELIVERED / " + item_name(order.item).to_upper(), "%s receives %s (%s)." % [hero.name, item_name(order.item), ITEMS[order.item].summary], "delivery", hero.id)
	return true

func find(order_id: int) -> Dictionary:
	for order in queue:
		if order.id == order_id:
			return order
	return {}

## Rival teams shop through the same validation path as the player.
func tick(b, dt: float) -> void:
	if not auto_buy:
		return
	auto_clock -= dt
	if auto_clock > 0:
		return
	auto_clock = AUTO_BUY_INTERVAL
	if queue.size() >= AUTO_BUY_MAX_QUEUE:
		return
	var heroes: Array = b.units.filter(func(u): return u.team == team and not u.creep)
	for attempt in range(heroes.size()):
		var hero: Dictionary = heroes[(auto_turn+attempt) % heroes.size()]
		var item: String = ITEM_IDS[(auto_turn+attempt) % ITEM_IDS.size()]
		if hero.hp > 0 and economy.can_afford(item_cost(item)) and request_purchase(b, hero.id, item).ok:
			auto_turn += attempt+1
			return

func to_dict() -> Dictionary:
	return {"team": team, "queue": queue.duplicate(true), "delivered": delivered.duplicate(true)}
