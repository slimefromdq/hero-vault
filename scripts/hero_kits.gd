extends RefCounted
## Hero-specific abilities, ultimates and AI quirks. battle.gd owns shared rules
## (movement, damage, items, objectives) and calls into this file by hero ID.
## Every random choice uses b.rng so matches stay seed-reproducible.

const Catalog = preload("res://scripts/catalog.gd")
const MapLayout = preload("res://scripts/map_layout.gd")

# All functions are static and take the battle.gd instance as `b`, so no
# reference cycle is created between the battle and its kit rules.

# --- Signature abilities -------------------------------------------------------

static func signature(b, u: Dictionary, enemy: Dictionary) -> void:
	var has_enemy := not enemy.is_empty()
	var hero_enemy: bool = has_enemy and not enemy.creep
	var distance: float = u.pos.distance_to(enemy.pos) if has_enemy else INF
	match u.portrait:
		"hazmat":
			if distance < 115:
				start_gas(b, u, false)
				u.ability = 12
		"irene":
			if hero_enemy and distance < 170:
				u.dash = {"kind": "leech", "target": enemy.id, "time": 0.45}
				u.ability = 10
		"oddity":
			if has_enemy:
				var direction: Vector2 = enemy.pos.direction_to(u.pos) if u.hp/u.max_hp < 0.45 or distance < 100 else Vector2.from_angle(b.rng.randf()*TAU)
				u.pos = MapLayout.constrain(u.pos+direction*110, u.lane)
				u.ability = 10
				b.log_event("NOW YOU SEE ME", "Oddity changes the staging. No ally protection order.", "blink", u.id)
		"mexai":
			if hero_enemy and distance < u.reach+enemy.radius:
				steal(b, u, enemy, false)
				u.ability = 10
		"eleanor":
			var ally: Dictionary = b.weakest_ally(u, 240)
			if not ally.is_empty() and ally.hp/ally.max_hp < 0.65:
				u.dash = {"kind": "intercede", "target": ally.id, "time": 0.75}
				u.ability = 12
		"colony":
			if distance < 105:
				b.area_hit(u, u.pos, 80+u.radius, 38+u.level*5)
				u.ability = 10
		"poppet":
			if hero_enemy and distance < 220 and enemy.curse <= 0:
				enemy.curse = 5.0
				enemy.curse_source = u.id
				u.ability = 11
				b.record_event("stitch", u.id, enemy.id, 5.0)
				b.log_event("STITCHED", u.name + " binds " + enemy.name + ". Hurting Poppet now hurts them too.", "curse", u.id)
		"crash_test":
			if hero_enemy and distance > 70 and distance < 230:
				# Aim at where the target is now; the charge does not steer.
				var direction: Vector2 = u.pos.direction_to(enemy.pos)
				u.dash = {"kind": "ram", "target": enemy.id, "dest": MapLayout.constrain(u.pos+direction*(distance+20), u.lane), "time": 0.8}
				u.ability = 11
				b.log_event("IMPACT TEST", u.name + " charges at " + enemy.name + ".", "charge_ram", u.id)
				# Agile duelists may see it coming and step aside (seeded roll).
				var dodge: float = 0.08 + enemy.behavior.dueling*0.05 + maxf(0, enemy.speed-45)*0.006
				if enemy.stun <= 0 and enemy.swing <= 0 and b.rng.randf() < dodge:
					var side: Vector2 = direction.orthogonal()*(1.0 if b.rng.randf() < 0.5 else -1.0)
					enemy.pos = MapLayout.constrain(enemy.pos+side*(u.radius+enemy.radius+14), enemy.lane)
					enemy.intent = "Sidestep the charge"
					b.record_event("ram_dodge", enemy.id, u.id)
		"kiln":
			if has_enemy and distance < u.reach+20:
				start_fire(b, u, enemy.pos, 70.0, 6.0, 8.0+u.level*1.1)
				u.ability = 11
		"sunday":
			var ally: Dictionary = b.weakest_ally(u, 260)
			var patient: Dictionary = {}
			if not ally.is_empty() and ally.hp/ally.max_hp < 0.7:
				patient = ally
			elif u.hp/u.max_hp < 0.5:
				patient = u
			if not patient.is_empty():
				b.heal(u, patient, 55.0+u.level*6.0)
				u.ability = 9
				b.log_event("DAY OF REST", u.name + " restores " + patient.name + ".", "rest", u.id)

## Extra per-hero conditions before spending an available ultimate.
static func ultimate_held(b, u: Dictionary, enemy: Dictionary) -> bool:
	var distance: float = u.pos.distance_to(enemy.pos)
	match u.portrait:
		"hazmat":
			return distance > 140
		"irene":
			return u.attacks < 3
		"eleanor":
			return b.weakest_ally(u, 160).is_empty()
		"crash_test", "colony":
			return distance > 150
		"sunday":
			var ally: Dictionary = b.weakest_ally(u, 230)
			return (ally.is_empty() or ally.hp/ally.max_hp > 0.6) and u.hp/u.max_hp > 0.5
	return false

static func resolve(b, u: Dictionary, effect: String, damage: float) -> void:
	match effect:
		"hazmat":
			u.overpressure = 8.0*u.cast_scale
			start_gas(b, u, true)
		"irene":
			u.blood_rush = 9.0*u.cast_scale
		"eleanor":
			u.hold_line = 8.0*u.cast_scale
		"oddity":
			start_intermission(b, u)
		"mexai":
			u.larceny.clear()
			for target in b.units:
				if target.team != u.team and not target.creep and target.hp > 0 and target.pos.distance_to(u.pos) < 210:
					u.larceny.append(target.id)
			u.larceny_time = 2.5*u.cast_scale
		"colony":
			b.area_hit(u, u.pos, 140+u.radius, damage)
			b.grant_shield(u, u, 100*u.cast_scale, 4)
		"poppet":
			var target: Dictionary = b.get_unit(u.charge_target)
			var aim: float = u.facing if target.is_empty() else u.pos.angle_to_point(target.pos)
			for i in range(5):
				b.launch(u, Vector2.from_angle(aim+(i-2)*0.14), damage*b.crown_multiplier(u), 560.0)
		"crash_test":
			u.write_off = 8.0
			u.write_off_scale = u.cast_scale
			u.write_off_stored = 0.0
			b.grant_shield(u, u, (120+u.level*6)*u.cast_scale, 8)
		"kiln":
			var target: Dictionary = b.get_unit(u.charge_target)
			var center: Vector2 = u.pos if target.is_empty() else u.pos.move_toward(target.pos, 90)
			b.area_hit(u, center, 110, damage)
			start_fire(b, u, center, 110.0, 5.0, (10.0+u.level*1.4)*u.cast_scale)
		"sunday":
			for ally in b.units:
				if ally.team == u.team and not ally.creep and ally.hp > 0 and ally.pos.distance_to(u.pos) < 230:
					ally.rest = 5.0*u.cast_scale
					ally.rest_source = u.id

# --- AI quirks -----------------------------------------------------------------

## Lower scores are preferred targets.
static func target_bias(b, u: Dictionary, enemy: Dictionary) -> float:
	if enemy.creep:
		return 0.0
	match u.portrait:
		"irene":
			return -50.0*(1.0-enemy.hp/enemy.max_hp)
		"mexai":
			return -b.item_value(enemy)*14.0
		"eleanor":
			var bias := 0.0
			for ally in b.units:
				if ally.id != u.id and ally.team == u.team and ally.hp > 0 and ally.last_attacker == enemy.id and u.pos.distance_to(ally.pos) < 220:
					bias -= 80.0
			return bias
		"oddity":
			return sin(float(enemy.id)*2.0 + floorf(b.clock/4.0))*35.0
		"poppet":
			return -60.0 if enemy.curse > 0 and enemy.curse_source == u.id else 0.0
		"crash_test":
			return -enemy.max_hp*0.05 # Picks the biggest thing in the lane.
	return 0.0

## Heavy melee commits to its swing instead of circling.
static func holds_ground(_b, u: Dictionary) -> bool:
	return u.portrait in ["hazmat", "eleanor"]

static func siege_multiplier(_b, u: Dictionary) -> float:
	return 1.5 if u.portrait == "kiln" else 1.0

static func on_melee_hit(b, u: Dictionary, target: Dictionary) -> void:
	if u.portrait == "hazmat" and target.hp > 0:
		b.stagger(target, 0.35)

static func melee_cleaves(_b, u: Dictionary) -> bool:
	return u.portrait == "eleanor"

# --- Ongoing effects -----------------------------------------------------------

static func tick(b, u: Dictionary, dt: float) -> void:
	if u.write_off > 0:
		u.write_off = maxf(0, u.write_off-dt)
		if u.write_off <= 0:
			detonate(b, u)
	if u.rest > 0:
		u.rest = maxf(0, u.rest-dt)
		var source: Dictionary = b.get_unit(u.rest_source)
		b.heal(u if source.is_empty() else source, u, u.max_hp*0.05*dt)

static func on_damaged(b, target: Dictionary, actual: float, absorbed: float, _source_id: int) -> void:
	if target.write_off > 0:
		target.write_off_stored += actual+absorbed
	if b.mirroring or actual <= 0:
		return
	b.mirroring = true
	for bound in b.units:
		if bound.curse > 0 and bound.curse_source == target.id and bound.hp > 0 and bound.team != target.team:
			b.apply_damage(bound, actual*0.35, target.id, false, "magic", true)
			b.record_event("stitch_mirror", target.id, bound.id, actual*0.35, {"damage_type": "magic"})
	b.mirroring = false

static func on_death(b, target: Dictionary) -> void:
	if target.write_off > 0:
		detonate(b, target)
	target.rest = 0.0
	target.curse = 0.0

static func detonate(b, u: Dictionary) -> void:
	var data: Dictionary = Catalog.ULTIMATES["crash_test"]
	var damage: float = (data.damage+data.per_level*u.level+u.write_off_stored*0.5)*u.write_off_scale
	u.write_off = 0.0
	b.record_event("write_off_blast", u.id, -1, damage, {"ability": data.id})
	b.log_event("TOTAL WRITE-OFF", u.name + " explodes for %d after absorbing %d." % [int(damage), int(u.write_off_stored)], "ultimate_release", u.id)
	b.area_hit(u, u.pos, 130, damage)
	u.write_off_stored = 0.0

static func update_dash(b, u: Dictionary, dt: float) -> void:
	var action: Dictionary = u.dash
	var target: Dictionary = b.get_unit(action.target)
	if action.kind == "ram":
		update_ram(b, u, dt)
		return
	if target.is_empty() or target.hp <= 0 or u.stun > 0:
		u.dash.clear()
		return
	u.dash.time -= dt
	u.pos = MapLayout.move_on_lane(u.pos, target.pos, u.lane, 350*dt)
	u.intent = "Leeching Cut" if action.kind == "leech" else "Intercede"
	if u.pos.distance_to(target.pos) < u.radius+target.radius+15:
		if action.kind == "leech":
			b.apply_damage(target, (45+u.level*3)*b.crown_multiplier(u), u.id, false, "ability")
			if target.hp > 0:
				var amount: float = target.max_hp*0.12
				target.max_hp -= amount
				target.hp = minf(target.hp, target.max_hp)
				u.max_hp += amount
				b.heal(u, u, amount)
				b.health_loans.append({"owner": target.id, "thief": u.id, "amount": amount, "until": b.clock+7.0})
				b.record_event("health_stolen", u.id, target.id, amount)
		else:
			b.grant_shield(u, target, 110+u.level*4, 4)
			u.saves += 1
			for enemy in b.units:
				if enemy.team != u.team and enemy.hp > 0 and enemy.pos.distance_to(u.pos) < 95:
					enemy.pos = MapLayout.constrain(enemy.pos+u.pos.direction_to(enemy.pos)*65, enemy.lane)
			b.log_event("INTERCEDE", u.name+" shields "+target.name+" and drives enemies back.", "shield", u.id)
		u.dash.clear()
	elif u.dash.time <= 0:
		b.record_event("dash_miss", u.id, target.id)
		u.dash.clear()

static func update_ram(b, u: Dictionary, dt: float) -> void:
	var action: Dictionary = u.dash
	action.time -= dt
	u.intent = "Impact Test"
	var before: Vector2 = u.pos
	u.pos = MapLayout.constrain(u.pos.move_toward(action.dest, 420*dt), u.lane)
	for enemy in b.units:
		if enemy.team == u.team or enemy.creep or enemy.hp <= 0:
			continue
		var point := Geometry2D.get_closest_point_to_segment(enemy.pos, before, u.pos)
		if point.distance_to(enemy.pos) < u.radius+enemy.radius-2:
			b.apply_damage(enemy, (50+u.level*5)*b.crown_multiplier(u), u.id, false, "ability")
			b.stagger(enemy, 0.8)
			b.log_event("CRASH", u.name + " flattens " + enemy.name + ".", "crash", u.id)
			b.record_event("ram_hit", u.id, enemy.id)
			u.dash.clear()
			return
	if action.time <= 0 or u.pos.distance_to(action.dest) < 2 or u.pos == before:
		u.stun = maxf(u.stun, 0.9)
		b.record_event("dash_miss", u.id, action.target)
		b.log_event("WHIFF", u.name + " misses the charge and sits there dazed.", "ram_miss", u.id)
		u.dash.clear()

# --- Shared hero helpers -------------------------------------------------------

static func steal(b, u: Dictionary, enemy: Dictionary, grand: bool) -> void:
	if enemy.hp <= 0 or u.hp <= 0 or u.pos.distance_to(enemy.pos) > u.reach+enemy.radius+15:
		return
	var available: Array = []
	for slot in range(enemy.items.size()):
		if enemy.items[slot] != "none" and not b.slot_stolen(enemy.id, slot):
			available.append(slot)
	if available.is_empty():
		return
	var slot: int = available[b.rng.randi_range(0, available.size()-1)]
	var item: String = enemy.items[slot]
	b.thefts.append({"owner": enemy.id, "thief": u.id, "slot": slot, "item": item, "until": b.clock+8.0})
	b.log_event("GRAND LARCENY" if grand else "PILFER", u.name+" takes "+Catalog.ITEMS[item].name+" from "+enemy.name+" for 8s.", "theft", u.id)
	b.record_event("item_stolen", u.id, enemy.id, 8, {"item": item})

static func update_larceny(b, u: Dictionary, dt: float) -> void:
	u.larceny_time -= dt
	if u.larceny_time <= 0 or u.stun > 0:
		u.larceny.clear()
		return
	var target: Dictionary = b.get_unit(u.larceny[0])
	if target.is_empty() or target.hp <= 0 or target.pos.distance_to(u.pos) > 240 or target.lane != u.lane:
		u.larceny.pop_front()
		return
	u.pos = MapLayout.move_on_lane(u.pos, target.pos, u.lane, 380*dt)
	u.intent = "Grand Larceny / next pocket"
	if target.pos.distance_to(u.pos) < u.reach+target.radius+10:
		steal(b, u, target, true)
		b.apply_damage(target, (45+u.level*4)*u.cast_scale*b.crown_multiplier(u), u.id, false, "ability")
		u.larceny.pop_front()

static func start_gas(b, u: Dictionary, overload: bool) -> void:
	# Opening the rig again replaces its prior cloud instead of stacking it.
	b.fields = b.fields.filter(func(field): return not (field.source == u.id and field.kind == "gas"))
	b.fields.append({"kind": "gas", "anchored": false, "pos": u.pos, "source": u.id, "team": u.team, "time": 8.0 if overload else 5.0,
		"tick": 0.0, "radius": 155.0 if overload else 90.0, "overload": overload,
		"damage": (17.0+u.level*2.5)*u.cast_scale if overload else 9.0+u.level*1.2})
	b.log_event("OVERPRESSURE" if overload else "RED GAS", u.name+" vents a moving cloud of red gas.", "gas", u.id)

static func start_fire(b, u: Dictionary, position: Vector2, radius: float, duration: float, damage: float) -> void:
	# Kiln keeps at most two fires burning.
	var own: Array = b.fields.filter(func(field): return field.source == u.id and field.kind == "fire")
	if own.size() >= 2:
		b.fields.erase(own[0])
	b.fields.append({"kind": "fire", "anchored": true, "pos": position, "source": u.id, "team": u.team, "time": duration,
		"tick": 0.0, "radius": radius, "overload": false, "damage": damage})
	b.log_event("FIRING", u.name + " sets the ground alight.", "fire", u.id)

static func start_intermission(b, u: Dictionary) -> void:
	b.intermission = {"time": 3.0*u.cast_scale, "caster": u.id}
	# No ally rescue selection, no Irene affinity. Enemy staging is seeded.
	var moved := 0
	for target in b.units:
		if target.id == u.id or target.team == u.team or target.creep or target.hp <= 0 or target.pos.distance_to(u.pos) > 220:
			continue
		target.pos = MapLayout.constrain(target.pos+Vector2.from_angle(b.rng.randf()*TAU)*b.rng.randf_range(45, 95), target.lane)
		b.record_event("intermission_move", u.id, target.id)
		moved += 1
		if moved >= 4:
			break
	b.log_event("INTERMISSION", "Combat freezes. Oddity restages nearby opponents; frozen units cannot take damage.", "intermission_start", u.id)
