extends RefCounted
## A team's courier drone: IDLE_AT_BASE -> DELIVERING -> HANDOFF -> RETURNING -> IDLE_AT_BASE.
## Carries one order at a time and must return home between deliveries. It is not a
## battle unit, so combat and AI never see it (invulnerable for now). Flies straight.

enum State { IDLE_AT_BASE, DELIVERING, HANDOFF, RETURNING }
const STATE_NAMES := ["IDLE_AT_BASE", "DELIVERING", "HANDOFF", "RETURNING"]
const SPEED := 95.0
const HANDOFF_RANGE := 34.0
const HANDOFF_TIME := 0.6

var team := 0
var home := Vector2.ZERO
var pos := Vector2.ZERO
var state: int = State.IDLE_AT_BASE
var cargo: Dictionary = {}
var target_id := -1
var handoff_clock := 0.0
var deliveries := 0
var aborts := 0

func _init(team_index: int, base: Vector2) -> void:
	team = team_index
	home = base
	pos = base

func update(b, shop, dt: float) -> void:
	match state:
		State.IDLE_AT_BASE:
			var order: Dictionary = shop.claim_next(b)
			if not order.is_empty():
				cargo = order
				target_id = order.hero_id
				state = State.DELIVERING
				b.record_event("drone_departed", target_id, -1, order.cost, {"item": order.item})
				update(b, shop, dt)
		State.DELIVERING:
			var target: Dictionary = b.get_unit(target_id)
			if not alive(target):
				abort(b, shop, "target died")
				return
			pos = pos.move_toward(target.pos, SPEED*dt)
			if pos.distance_to(target.pos) <= HANDOFF_RANGE:
				state = State.HANDOFF
				handoff_clock = HANDOFF_TIME
		State.HANDOFF:
			var target: Dictionary = b.get_unit(target_id)
			if not alive(target):
				abort(b, shop, "target died")
				return
			pos = pos.move_toward(target.pos, SPEED*dt)
			handoff_clock -= dt
			if handoff_clock <= 0:
				if shop.complete(b, cargo.id):
					deliveries += 1
				cargo = {}
				target_id = -1
				state = State.RETURNING
		State.RETURNING:
			pos = pos.move_toward(home, SPEED*dt)
			if pos.distance_to(home) < 0.5:
				pos = home
				state = State.IDLE_AT_BASE

func alive(target: Dictionary) -> bool:
	return not target.is_empty() and target.hp > 0

## The order goes back to the queue untouched; the drone flies home first.
func abort(b, shop, reason: String) -> void:
	shop.release(b, cargo.id, reason)
	aborts += 1
	cargo = {}
	target_id = -1
	state = State.RETURNING

func busy() -> bool:
	return state != State.IDLE_AT_BASE

## Rough seconds until order_id is handed over, assuming heroes stay where they are.
## Returns -1 if the order is not queued.
func estimate_eta(b, shop, order_id: int) -> float:
	var time := 0.0
	if state in [State.DELIVERING, State.HANDOFF]:
		var carried: Dictionary = b.get_unit(target_id)
		var outbound: float = pos.distance_to(carried.pos)/SPEED + (handoff_clock if state == State.HANDOFF else HANDOFF_TIME)
		if cargo.get("id", -1) == order_id:
			return outbound
		time = outbound + carried.pos.distance_to(home)/SPEED
	elif state == State.RETURNING:
		time = pos.distance_to(home)/SPEED
	for order in shop.queue:
		if order.status != shop.PENDING:
			continue
		var hero: Dictionary = b.get_unit(order.hero_id)
		if hero.is_empty():
			continue
		var leg: float = home.distance_to(hero.pos)/SPEED
		if hero.hp <= 0:
			# Dead targets are skipped until they respawn at their spawn point.
			leg = home.distance_to(hero.spawn)/SPEED
			if order.id == order_id:
				return maxf(time, hero.respawn) + leg + HANDOFF_TIME
			continue
		if order.id == order_id:
			return time + leg + HANDOFF_TIME
		time += leg*2 + HANDOFF_TIME
	return -1.0

func to_dict() -> Dictionary:
	return {"team": team, "pos": pos, "home": home, "state": state, "state_name": STATE_NAMES[state],
		"cargo": cargo.duplicate(), "target": target_id, "deliveries": deliveries, "aborts": aborts}
