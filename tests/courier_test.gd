extends SceneTree
## Remote shop + courier drone acceptance checks (purchase, travel, handoff,
## return, FIFO queue, target death retry, validation, rival auto-buy).
const Battle = preload("res://scripts/battle.gd")
const Drone = preload("res://scripts/courier_drone.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func tick_until(b, condition: Callable, limit: int = 2000) -> bool:
	for i in range(limit):
		if condition.call():
			return true
		b.update_logistics(Battle.STEP)
	return condition.call()

func _init() -> void:
	delivery_flow()
	validation_checks()
	fifo_checks()
	live_match_checks()
	print("COURIER PASS" if failures == 0 else "COURIER FAIL: %d" % failures)
	quit(failures)

func delivery_flow() -> void:
	var b = Battle.new()
	b.setup(47, 0, 0, 0)
	var economy = b.economies[0]
	var shop = b.shops[0]
	var drone = b.couriers[0]
	var lee: Dictionary = b.units[0]
	var hazmat: Dictionary = b.units[1]
	var enemy: Dictionary = b.units[5]
	lee.pos = Vector2(1200, 300)
	hazmat.pos = Vector2(1000, 500)
	economy.credits = 1000
	var power: float = lee.damage
	var credits: float = economy.credits
	check(drone.state == Drone.State.IDLE_AT_BASE and drone.pos == drone.home, "Drone starts idle at base")
	var result: Dictionary = b.request_purchase(0, lee.id, "power_cell")
	check(result.ok and "Delivering to " + lee.name in result.message and result.eta > 0, "Purchase confirms target and ETA")
	check(economy.credits == credits-250, "Currency is deducted immediately")
	check(lee.items.is_empty() and lee.damage == power, "No item or stats before delivery")
	b.update_logistics(Battle.STEP)
	check(drone.state == Drone.State.DELIVERING and drone.cargo.item == "power_cell" and drone.target_id == lee.id, "Idle drone loads the order and departs")
	check(drone.pos != drone.home, "Drone physically leaves base")
	# Second purchase while busy waits in the queue.
	var second: Dictionary = b.request_purchase(0, hazmat.id, "vital_plate")
	check(second.ok and shop.queue.size() == 2 and shop.queue[1].status == shop.PENDING, "Second order waits while the drone is busy")
	check(second.eta > result.eta, "Queued order ETA includes the current trip")
	var saw_handoff := tick_until(b, func(): return drone.state == Drone.State.HANDOFF)
	check(saw_handoff and lee.items.is_empty(), "Drone reaches the hero and begins handoff before the item applies")
	check(tick_until(b, func(): return drone.state == Drone.State.RETURNING), "Handoff completes")
	check(lee.items == ["power_cell"] and lee.damage == power+20, "Item enters inventory and +20 Power applies on arrival")
	check(b.records.any(func(r): return r.kind == "item_delivered" and r.actor == lee.id), "Delivery is logged")
	check(shop.queue.size() == 1 and shop.queue[0].status == shop.PENDING, "Second order still waits while the drone returns")
	check(tick_until(b, func(): return drone.state == Drone.State.IDLE_AT_BASE) and drone.pos == drone.home, "Drone returns to base")
	b.update_logistics(Battle.STEP)
	check(drone.state == Drone.State.DELIVERING and drone.target_id == hazmat.id, "Drone collects the queued order")
	# Target dies mid-delivery: abort, no refund, retry after respawn.
	var max_hp: float = hazmat.max_hp
	credits = economy.credits
	b.apply_damage(hazmat, 999999, enemy.id)
	check(hazmat.hp <= 0, "Target is dead")
	b.update_logistics(Battle.STEP)
	check(drone.state == Drone.State.RETURNING and drone.cargo.is_empty(), "Delivery aborts and the drone heads home")
	check(shop.queue.size() == 1 and shop.queue[0].status == shop.PENDING and shop.queue[0].item == "vital_plate", "Order stays pending, item not destroyed")
	check(economy.credits >= credits and hazmat.items.is_empty(), "No refund, no item yet")
	check(b.records.any(func(r): return r.kind == "delivery_aborted"), "Abort is logged")
	tick_until(b, func(): return drone.state == Drone.State.IDLE_AT_BASE)
	for i in range(40):
		b.update_logistics(Battle.STEP)
	check(drone.state == Drone.State.IDLE_AT_BASE, "Drone waits at base while the only target is dead")
	check(b.couriers[0].estimate_eta(b, shop, shop.queue[0].id) >= hazmat.respawn, "ETA accounts for respawn")
	hazmat.hp = hazmat.max_hp # Respawned.
	hazmat.pos = Vector2(1300, 200)
	b.update_logistics(Battle.STEP)
	check(drone.state == Drone.State.DELIVERING and drone.target_id == hazmat.id, "Delivery retries once the hero is alive")
	check(tick_until(b, func(): return drone.state == Drone.State.RETURNING), "Retry completes")
	check(hazmat.items == ["vital_plate"] and hazmat.max_hp == max_hp+100 and shop.queue.is_empty(), "Vital Plate delivered: +100 Max HP")
	check(shop.delivered.size() == 2 and drone.deliveries == 2 and drone.aborts == 1, "Delivery history is kept")
	# Speed item.
	var speed: float = lee.speed
	b.request_purchase(0, lee.id, "swift_treads")
	tick_until(b, func(): return lee.items.size() == 2)
	check(lee.speed == speed+2, "Swift Treads adds +2 Move Speed")
	# Snapshots carry logistics as copies, not live references.
	b.snapshot()
	var saved: Dictionary = b.history[-1].logistics
	check(saved.couriers[0].state == drone.state and saved.economy[0].credits == economy.credits, "Snapshot records drone and currency")
	economy.add(1000)
	check(saved.economy[0].credits != economy.credits, "Snapshot logistics are copies")

func validation_checks() -> void:
	var b = Battle.new()
	b.setup(48, 0, 0, 0)
	var economy = b.economies[0]
	var hero: Dictionary = b.units[2]
	economy.credits = 100
	var result: Dictionary = b.request_purchase(0, hero.id, "power_cell")
	check(not result.ok and economy.credits == 100 and b.shops[0].queue.is_empty(), "Unaffordable purchase is rejected without charge")
	economy.credits = 99999
	check(not b.request_purchase(0, b.units[6].id, "power_cell").ok, "Cannot buy for an enemy hero")
	check(not b.request_purchase(0, hero.id, "idol").ok, "Unknown items are rejected")
	for i in range(6):
		check(b.request_purchase(0, hero.id, "swift_treads").ok, "Slots can be filled by queued orders")
	check(not b.request_purchase(0, hero.id, "swift_treads").ok, "Queued orders reserve inventory slots")
	b.winner = 0
	check(not b.request_purchase(0, b.units[3].id, "swift_treads").ok, "No shopping after the match ends")

func fifo_checks() -> void:
	var b = Battle.new()
	b.setup(49, 0, 0, 0)
	b.economies[0].credits = 99999
	var shop = b.shops[0]
	b.request_purchase(0, b.units[0].id, "power_cell")
	b.request_purchase(0, b.units[1].id, "vital_plate")
	b.request_purchase(0, b.units[2].id, "swift_treads")
	check(shop.queue.map(func(o): return o.item) == ["power_cell", "vital_plate", "swift_treads"], "Orders keep purchase order")
	check(shop.queue.map(func(o): return o.sequence) == [1, 2, 3], "Orders record their sequence")
	b.units[0].hp = 0
	var claimed: Dictionary = shop.claim_next(b)
	check(claimed.item == "vital_plate", "Dead target is skipped, not dropped")
	shop.release(b, claimed.id, "test")
	b.units[0].hp = b.units[0].max_hp
	check(shop.claim_next(b).item == "power_cell", "FIFO resumes with the oldest order once its hero lives")

func live_match_checks() -> void:
	var b = Battle.new()
	b.setup(50, 0, 0, 1)
	var result: Dictionary = b.request_purchase(0, b.units[0].id, "vital_plate")
	check(result.ok, "Live purchase accepted")
	var delivered := false
	for i in range(int(240.0/Battle.STEP)):
		b.step()
		if b.units[0].items.has("vital_plate"):
			delivered = true
			break
	check(delivered, "Delivery completes during a running match")
	while b.clock < 30.0 and b.winner == -1:
		b.step()
	check(b.shops[1].delivered.size() + b.shops[1].queue.size() > 0 and b.economies[1].spent > 0, "Rival team buys through its own shop")
	check(b.frame().has("logistics"), "Frames expose logistics for the UI")
