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
			var landing: Dictionary = full_send_target(b, u)
			if not landing.is_empty():
				launch_full_send(b, u, landing)
				u.ability = 14
		"kiln":
			if has_enemy and distance < u.reach+20:
				start_fire(b, u, enemy.pos, 70.0, 6.0, 8.0+u.level*1.1)
				u.ability = 11
		"sunday":
			# Warmth: she walks toward a wounded ally first, even into a bad fight.
			var ally: Dictionary = wounded_ally(b, u, 320)
			if not ally.is_empty():
				if u.pos.distance_to(ally.pos) <= 110:
					start_warmth(b, u)
				else:
					u.dash = {"kind": "walk", "target": ally.id, "time": 6.0}
					u.intent = "Hurry to help " + ally.name
				u.ability = 12
			elif u.hp/u.max_hp < 0.5 and has_enemy:
				start_warmth(b, u)
				u.ability = 12

## Second ability, on its own timer (ability2).
static func signature2(b, u: Dictionary, enemy: Dictionary) -> void:
	match u.portrait:
		"sunday":
			var target: Dictionary = flare_target(b, u)
			if not target.is_empty():
				b.launch_orb(u, target.pos, (70.0+u.level*7.0)*b.crown_multiplier(u))
				u.ability2 = 13
				b.log_event("FLARE", u.name + " lobs a slow solar orb at " + target.name + ". Get out of the way.", "flare", u.id)
		"crash_test":
			var crowd := 0
			for other in b.units:
				if other.team != u.team and not other.creep and other.hp > 0 and other.pos.distance_to(u.pos) < 120:
					crowd += 1
			if crowd >= 3 or (u.hp/u.max_hp < 0.4 and not enemy.is_empty() and u.pos.distance_to(enemy.pos) < 150):
				u.safety = 4.0
				u.ability2 = 16
				b.log_event("SAFETY RATING: ZERO", u.name + " locks every joint. No.", "safety", u.id)

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
		"colony":
			return distance > 150
		"crash_test":
			return count_heroes(b, u.pos, 180, 1-u.team) < 2
		"sunday":
			var best := 0
			for hero in b.units:
				if hero.creep or hero.hp <= 0 or hero.team == u.team or not hero.flight.is_empty() or u.pos.distance_to(hero.pos) > 320:
					continue
				var crowd: int = count_heroes(b, hero.pos, 170, -1)
				if crowd > best:
					best = crowd
					u.sun_center = hero.pos
			return best < 3
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
			u.program = 8.0*u.cast_scale
			u.program_scale = u.cast_scale
			u.program_cd = 0.0
		"kiln":
			var target: Dictionary = b.get_unit(u.charge_target)
			var center: Vector2 = u.pos if target.is_empty() else u.pos.move_toward(target.pos, 90)
			b.area_hit(u, center, 110, damage)
			start_fire(b, u, center, 110.0, 5.0, (10.0+u.level*1.4)*u.cast_scale)
		"sunday":
			var center: Vector2 = u.sun_center if u.sun_center != Vector2.ZERO else u.pos
			b.fields.append({"kind": "sun", "anchored": true, "pos": center, "source": u.id, "team": u.team, "time": 7.0*u.cast_scale,
				"tick": 0.0, "radius": 170.0, "overload": false, "damage": damage})
			u.sun_center = Vector2.ZERO

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
			var bias: float = -40.0*(1.0-enemy.hp/enemy.max_hp)
			if b.fighting_team(enemy, u.team):
				bias -= 80.0
			return bias
		"sunday":
			return -50.0 if b.fighting_team(enemy, u.team) else 0.0
	return 0.0

## Heavy melee commits to its swing instead of circling.
static func holds_ground(_b, u: Dictionary) -> bool:
	return u.portrait in ["hazmat", "eleanor", "crash_test"]

## Fraction of basic-attack range a hero tries to fight from.
static func preferred_range(_b, u: Dictionary) -> float:
	return 0.95 if u.portrait == "sunday" else 0.78

static func siege_multiplier(_b, u: Dictionary) -> float:
	return 1.5 if u.portrait == "kiln" else 1.0

static func on_melee_hit(b, u: Dictionary, target: Dictionary) -> void:
	if u.portrait == "hazmat" and target.hp > 0:
		b.stagger(target, 0.35)
	elif u.portrait == "crash_test" and target.hp > 0:
		b.knockback(target, u.pos, 38.0, u.id)

static func melee_cleaves(_b, u: Dictionary) -> bool:
	return u.portrait == "eleanor"

# --- Ongoing effects -----------------------------------------------------------

static func tick(b, u: Dictionary, dt: float) -> void:
	for timer in ["safety", "program", "program_cd"]:
		u[timer] = maxf(0, u[timer]-dt)
	if u.warmth > 0:
		u.warmth = maxf(0, u.warmth-dt)
		u.warmth_tick -= dt
		if u.warmth_tick <= 0:
			u.warmth_tick = 0.5
			for ally in b.units:
				if ally.team == u.team and not ally.creep and ally.hp > 0 and ally.pos.distance_to(u.pos) < 130:
					b.heal(u, ally, (10.0+u.level)*0.5)

static func on_damaged(b, target: Dictionary, actual: float, _absorbed: float, _source_id: int) -> void:
	if b.mirroring or actual <= 0:
		return
	b.mirroring = true
	for bound in b.units:
		if bound.curse > 0 and bound.curse_source == target.id and bound.hp > 0 and bound.team != target.team:
			b.apply_damage(bound, actual*0.35, target.id, false, "magic", true)
			b.record_event("stitch_mirror", target.id, bound.id, actual*0.35, {"damage_type": "magic"})
	b.mirroring = false

static func on_death(_b, target: Dictionary) -> void:
	for timer in ["curse", "warmth", "safety", "program"]:
		target[timer] = 0.0
	target.flight.clear()

## Resolve bonus from Sunday's Warmth aura or a friendly BEAUTIFUL DAY.
static func resolve_bonus(b, target: Dictionary) -> float:
	var bonus := 0.0
	for ally in b.units:
		if ally.team == target.team and ally.warmth > 0 and ally.hp > 0 and ally.pos.distance_to(target.pos) < 130:
			bonus = 15.0
			break
	for field in b.fields:
		if field.kind == "sun" and field.team == target.team and target.pos.distance_to(field.pos) < field.radius:
			bonus += 25.0
			break
	return bonus

static func armor_bonus(_b, target: Dictionary) -> float:
	return 40.0 if target.safety > 0 else 0.0

static func speed_scale(_b, u: Dictionary) -> float:
	return 0.6 if u.safety > 0 else 1.0

## Knockback multiplier from Stability (1-10). SAFETY RATING: ZERO makes Crash Test nearly immovable.
static func knockback_scale(_b, u: Dictionary) -> float:
	if u.safety > 0:
		return 0.15
	return 1.45-0.09*u.stability

## Crash Test is built for crashes: smaller wall damage, and nearby enemies get staggered.
static func built_for_crashes(_b, u: Dictionary) -> bool:
	return u.portrait == "crash_test"

## Called whenever a hero is knocked back, lands from FULL SEND, or hits a wall.
static func on_displaced(b, u: Dictionary, amount: float, cause: String) -> void:
	if u.program <= 0 or u.program_cd > 0 or amount < 10 or u.hp <= 0:
		return
	u.program_cd = 0.4
	var data: Dictionary = Catalog.ULTIMATES["crash_test"]
	var damage: float = (data.damage+data.per_level*u.level)*u.program_scale
	b.record_event("crash_program_shockwave", u.id, -1, damage, {"ability": data.id, "detail": cause})
	b.log_event("BOOM", u.name + " turns a " + cause + " into a shockwave.", "shockwave", u.id)
	b.area_hit(u, u.pos, 90, damage)

static func count_heroes(b, position: Vector2, radius: float, team: int) -> int:
	var total := 0
	for hero in b.units:
		if not hero.creep and hero.hp > 0 and hero.flight.is_empty() and (team < 0 or hero.team == team) and hero.pos.distance_to(position) < radius:
			total += 1
	return total

static func wounded_ally(b, u: Dictionary, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var ratio := 0.7
	for ally in b.units:
		if ally.id != u.id and ally.team == u.team and not ally.creep and ally.hp > 0 and ally.flight.is_empty() and ally.hp/ally.max_hp < ratio and u.pos.distance_to(ally.pos) <= reach:
			best = ally
			ratio = ally.hp/ally.max_hp
	return best

static func start_warmth(b, u: Dictionary) -> void:
	u.warmth = 5.0
	u.warmth_tick = 0.0
	b.log_event("WARMTH", u.name + " radiates healing light.", "warmth", u.id)

## Flare prefers clustered or slow/stuck enemy heroes.
static func flare_target(b, u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	for enemy in b.units:
		if enemy.team == u.team or enemy.creep or enemy.hp <= 0 or not enemy.flight.is_empty():
			continue
		if u.pos.distance_to(enemy.pos) > u.reach+60:
			continue
		var score: float = count_heroes(b, enemy.pos, 80, -1)-1
		if enemy.stun > 0 or enemy.swing > 0 or enemy.hold_line > 0 or enemy.speed < 42 or enemy.safety > 0:
			score += 1.5
		if score > best_score:
			best_score = score
			best = enemy
	return best

## FULL SEND prefers big, far-away fights where allies are already engaged.
## It deliberately ignores its own safety: intentional target-selection stupidity.
static func full_send_target(b, u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for enemy in b.units:
		if enemy.team == u.team or enemy.creep or enemy.hp <= 0 or not enemy.flight.is_empty():
			continue
		var distance: float = u.pos.distance_to(enemy.pos)
		if distance < 200 or distance > 650:
			continue
		var score: float = distance*0.3 + count_heroes(b, enemy.pos, 130, -1)*90.0
		if b.fighting_team(enemy, u.team):
			score += 120.0
		if score > best_score:
			best_score = score
			best = enemy
	return best

static func launch_full_send(b, u: Dictionary, target: Dictionary) -> void:
	var distance: float = u.pos.distance_to(target.pos)
	# Aimed at where the target is now. No mid-flight correction: physics has the wheel.
	u.flight = {"from": u.pos, "to": target.pos, "time": 0.0, "total": 0.6+distance/300.0, "distance": distance, "target": target.id}
	u.charge = 0.0
	u.rotation.clear()
	u.camp_target = -1
	b.record_event("full_send_launch", u.id, target.id, distance)
	b.log_event("FULL SEND", u.name + " launches toward " + target.name + ". Something is approaching.", "full_send", u.id)

static func update_flight(b, u: Dictionary, dt: float) -> void:
	var flight: Dictionary = u.flight
	flight.time += dt
	var t: float = minf(1.0, flight.time/flight.total)
	u.pos = flight.from.lerp(flight.to, t)
	u.intent = "FULL SEND  -  airborne"
	if t < 1.0:
		return
	# Land in whichever lane is closer; the jungle counts as "somewhere unhelpful".
	u.lane = MapLayout.nearest_lane(flight.to)
	u.pos = MapLayout.constrain(flight.to, u.lane)
	u.flight = {}
	var travel: float = minf(flight.distance, 600.0)
	var damage: float = (40.0+u.level*4.0)*(1.0+travel/400.0)*b.crown_multiplier(u)
	var push: float = 20.0+travel*0.08
	var hits := 0
	for enemy in b.units:
		if enemy.team == u.team or enemy.hp <= 0 or not enemy.flight.is_empty() or enemy.pos.distance_to(u.pos) > 75:
			continue
		if not enemy.creep:
			hits += 1
		var close: bool = enemy.pos.distance_to(u.pos) < 35
		b.apply_damage(enemy, damage, u.id, false, "ability")
		b.knockback(enemy, u.pos, push, u.id)
		if close:
			b.stagger(enemy, 0.9)
	b.record_event("full_send_land", u.id, flight.target, hits, {"detail": "hit" if hits > 0 else "miss"})
	if hits == 0:
		b.log_event("FULL SEND MISSES", u.name + " lands on nobody. Profoundly unhelpful.", "full_send_miss", u.id)
	else:
		b.log_event("TOUCHDOWN", u.name + " lands on %d hero%s." % [hits, "" if hits == 1 else "es"], "full_send_hit", u.id)
	on_displaced(b, u, travel, "landing")

static func update_dash(b, u: Dictionary, dt: float) -> void:
	var action: Dictionary = u.dash
	var target: Dictionary = b.get_unit(action.target)
	if target.is_empty() or target.hp <= 0 or u.stun > 0:
		u.dash.clear()
		return
	u.dash.time -= dt
	if action.kind == "walk":
		# Sunday waddles toward the ally at her normal pace, then casts Warmth.
		u.pos = MapLayout.move_on_lane(u.pos, target.pos, u.lane, b.movement_speed(u, target.pos)*dt)
		u.intent = "Hurry to help " + target.name
		if u.pos.distance_to(target.pos) <= 110:
			start_warmth(b, u)
			u.dash.clear()
		elif u.dash.time <= 0:
			u.dash.clear()
		return
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
					b.knockback(enemy, u.pos, 65.0, u.id)
			b.log_event("INTERCEDE", u.name+" shields "+target.name+" and drives enemies back.", "shield", u.id)
		u.dash.clear()
	elif u.dash.time <= 0:
		b.record_event("dash_miss", u.id, target.id)
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
	b.log_event("GRAND LARCENY" if grand else "PILFER", u.name+" takes "+b.ShopManager.item_name(item)+" from "+enemy.name+" for 8s.", "theft", u.id)
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
