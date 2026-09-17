extends SceneTree
## Poppet, Crash Test, Kiln, Sunday, and seed-reproducibility with in-match shopping.
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
const TEAM := ["poppet", "crash_test", "kiln", "sunday", "hazmat"] # Units 0-4.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

## Units 0-4 are TEAM; 5-9 are rival 0 (hazmat, irene, eleanor, colony, oddity).
func clean(seed_value: int = 11):
	var b = Battle.new()
	b.setup(seed_value, 0, 0, 0, TEAM)
	for i in range(b.units.size()):
		var u: Dictionary = b.units[i]
		u.items.clear()
		u.armor = 0
		u.resolve = 0
		u.pos = Vector2(-600 + i*140, 900) # Far apart unless a check places them.
		u.lane = 0
	return b

func _init() -> void:
	check(Catalog.validate_definitions() == "", "Definitions, shop items and rival squads validate")
	check(Battle.ShopManager.ITEM_IDS.size() == 3, "Three prototype shop items")
	check(not Catalog.HEROES.has("atlas"), "Tank carry is scrapped for now")
	check(Catalog.migrate_team(["atlas", "irene", "irene", "volt", "kiln"]) == ["hazmat", "irene", "eleanor", "colony", "kiln"], "Retired or duplicate heroes are replaced one-for-one")
	poppet_checks()
	crash_test_checks()
	kiln_checks()
	sunday_checks()
	determinism_checks()
	print("ROSTER/ITEMS PASS" if failures == 0 else "ROSTER/ITEMS FAIL: %d" % failures)
	quit(failures)

func poppet_checks() -> void:
	var b = clean()
	var poppet: Dictionary = b.units[0]
	var enemy: Dictionary = b.units[5]
	poppet.pos = Vector2(0, 0)
	enemy.pos = Vector2(150, 0)
	poppet.ability = 0
	b.use_abilities(poppet, enemy)
	check(enemy.curse == 5.0 and enemy.curse_source == poppet.id, "Stitch binds the enemy hero")
	var hp: float = enemy.hp
	b.apply_damage(poppet, 100, b.units[6].id)
	check(is_equal_approx(hp-enemy.hp, 35.0), "Damage to Poppet is mirrored to the stitched enemy")
	b.update_effects(enemy, 5.1)
	hp = enemy.hp
	b.apply_damage(poppet, 100, b.units[6].id)
	check(enemy.hp == hp, "Stitch expires")
	poppet.cast_effect = "poppet"
	poppet.charge_target = enemy.id
	b.resolve_ultimate(poppet, enemy)
	check(b.shots.size() == 5, "Pincushion throws five dodgeable needles")

func crash_test_checks() -> void:
	var b = clean()
	var crash: Dictionary = b.units[1]
	var enemy: Dictionary = b.units[5]
	var bystander: Dictionary = b.units[6]
	check(crash.stability == 1 and crash.radius > enemy.radius and crash.max_hp > enemy.max_hp, "Crash Test is huge, durable and unstable")
	# Stability: Crash Test flies much farther than a stable hero.
	crash.pos = Vector2(500, 80)
	enemy.pos = Vector2(600, 80)
	b.knockback(crash, Vector2(460, 80), 40, enemy.id)
	var crash_moved: float = crash.pos.x-500
	b.knockback(enemy, Vector2(560, 80), 40, crash.id)
	var hazmat_moved: float = enemy.pos.x-600
	check(crash_moved > hazmat_moved*1.3, "Low Stability means bigger knockback")
	# FULL SEND picks a far, busy fight, flies without correcting, and lands.
	crash.pos = Vector2(700, 80)
	enemy.pos = Vector2(300, 80)
	bystander.pos = Vector2(310, 90)
	b.units[0].pos = Vector2(320, 80) # Poppet already fighting there.
	b.units[0].last_attacker = enemy.id
	b.units[0].last_hit = b.clock
	crash.ability = 0
	b.use_abilities(crash, {})
	check(not crash.flight.is_empty() and crash.flight.to == Vector2(300, 80), "FULL SEND launches at the distant fight")
	var hp: float = enemy.hp
	b.apply_damage(crash, 50, enemy.id)
	check(crash.hp == crash.max_hp, "Airborne Crash Test cannot be hit")
	b.select_enemy(enemy)
	check(b.select_enemy(enemy).get("id", -1) != crash.id, "Airborne Crash Test is not targeted")
	enemy.pos = Vector2(300, 80)
	for i in range(80):
		if crash.flight.is_empty():
			break
		b.Kits.update_flight(b, crash, 0.05)
	check(crash.flight.is_empty() and enemy.hp < hp, "Landing damages enemies at the impact point")
	check(b.records.any(func(r): return r.kind == "full_send_land" and r.detail == "hit"), "Landing is logged as a hit")
	# A target that moved away leaves Crash Test landing on nobody.
	crash.pos = Vector2(700, 80)
	b.Kits.launch_full_send(b, crash, enemy)
	enemy.pos = Vector2(300, 400)
	bystander.pos = Vector2(250, 400)
	enemy.lane = 1
	for i in range(80):
		if crash.flight.is_empty():
			break
		b.Kits.update_flight(b, crash, 0.05)
	check(b.records.any(func(r): return r.kind == "full_send_land" and r.detail == "miss"), "FULL SEND can miss")
	# Wall slams: Crash Test takes little damage and staggers nearby enemies.
	crash.stun = 0
	crash.hp = crash.max_hp
	crash.pos = Vector2(500, 110)
	enemy.pos = Vector2(520, 110)
	enemy.lane = 0
	enemy.stun = 0
	b.knockback(crash, Vector2(500, 60), 90, enemy.id)
	check(crash.hp < crash.max_hp and crash.max_hp-crash.hp <= crash.max_hp*0.011 and crash.stun > 0, "Crash Test shrugs off a wall slam")
	check(enemy.stun > 0, "Wall slam staggers nearby enemies")
	# SAFETY RATING: ZERO
	crash.stun = 0
	crash.safety = 4.0
	var before: Vector2 = crash.pos
	b.knockback(crash, crash.pos-Vector2(40, 0), 40, enemy.id)
	check(crash.pos.distance_to(before) < 8 and b.movement_speed(crash, crash.pos) == crash.speed*0.6, "Safety Rating makes Crash Test heavy and slow")
	crash.safety = 0
	# CRASH PROGRAM: displacement becomes shockwaves.
	crash.cast_effect = "crash_test"
	b.resolve_ultimate(crash, enemy)
	check(crash.program == 8.0, "CRASH PROGRAM is active")
	crash.pos = Vector2(500, 80)
	enemy.pos = Vector2(560, 80)
	hp = enemy.hp
	b.knockback(crash, Vector2(470, 80), 30, enemy.id)
	check(enemy.hp < hp and b.records.any(func(r): return r.kind == "crash_program_shockwave"), "Knockback during CRASH PROGRAM emits a shockwave")
	# Basic punch knocks back.
	crash.pos = Vector2(500, 80)
	enemy.pos = Vector2(540, 80)
	b.Kits.on_melee_hit(b, crash, enemy)
	check(enemy.pos.x > 540, "Impact Test punch knocks the target back")

func kiln_checks() -> void:
	var b = clean()
	var kiln: Dictionary = b.units[2]
	var enemy: Dictionary = b.units[5]
	kiln.pos = Vector2(0, 0)
	enemy.pos = Vector2(100, 0)
	kiln.ability = 0
	b.use_abilities(kiln, enemy)
	check(b.fields.size() == 1 and b.fields[0].kind == "fire" and b.fields[0].pos == enemy.pos, "Firing lights the ground under the enemy")
	var spot: Vector2 = b.fields[0].pos
	kiln.pos = Vector2(-80, 0)
	var hp: float = enemy.hp
	b.update_fields(0.05)
	check(b.fields[0].pos == spot and enemy.hp < hp, "Fire stays anchored and burns")
	b.units[6].pos = enemy.pos
	b.units[6].hp = 100
	b.heal(b.units[6], b.units[6], 50)
	check(b.units[6].hp == 150, "Kiln fire does not reduce healing (only Hazmat gas does)")
	check(b.Kits.siege_multiplier(b, kiln) == 1.5 and b.Kits.siege_multiplier(b, enemy) == 1.0, "Kiln has bonus structure damage")

func sunday_checks() -> void:
	var b = clean()
	var sunday: Dictionary = b.units[3]
	var ally: Dictionary = b.units[4]
	var enemy: Dictionary = b.units[5]
	# Sunbeam: slow, long-lived, splashes.
	sunday.pos = Vector2(700, 80)
	enemy.pos = Vector2(500, 80)
	b.units[7].pos = Vector2(500, 110)
	b.fire(sunday, enemy, sunday.damage, false)
	var shot: Dictionary = b.shots[-1]
	check(shot.speed == 170.0 and shot.life == 4.0 and shot.splash > 0, "Sunbeam is a slow, long-lived splash bolt")
	var splash_hp: float = b.units[7].hp
	for i in range(40):
		b.update_shots(0.05)
	check(enemy.hp < enemy.max_hp and b.units[7].hp < splash_hp, "Sunbeam splashes around the target")
	# Warmth: walk toward a wounded ally, then heal and add Resolve.
	sunday.pos = Vector2(700, 80)
	ally.pos = Vector2(560, 80)
	ally.hp = ally.max_hp*0.3
	sunday.ability = 0
	b.use_abilities(sunday, {})
	check(sunday.dash.get("kind", "") == "walk", "Sunday walks toward a wounded ally")
	for i in range(80):
		if sunday.dash.is_empty():
			break
		b.update_dash(sunday, 0.05)
	check(sunday.warmth > 0, "Warmth starts once she arrives")
	var hp: float = ally.hp
	b.update_effects(sunday, 0.05)
	check(ally.hp > hp and b.Kits.resolve_bonus(b, ally) == 15.0, "Warmth heals and adds Resolve")
	# Flare: slow orb that bursts at the target spot even if they leave.
	var c = clean()
	var sun2: Dictionary = c.units[3]
	var slow: Dictionary = c.units[5]
	sun2.pos = Vector2(700, 80)
	slow.pos = Vector2(500, 80)
	slow.stun = 1.0
	sun2.ability2 = 0
	c.use_abilities(sun2, slow)
	check(c.shots.size() == 1 and c.shots[0].kind == "orb" and c.shots[0].speed < 170.0, "Flare targets a stuck enemy with a very slow orb")
	slow.pos = Vector2(620, 124)
	c.units[6].pos = Vector2(505, 85)
	hp = c.units[6].hp
	for i in range(60):
		c.update_shots(0.05)
	check(c.shots.is_empty() and c.units[6].hp < hp and slow.hp == slow.max_hp, "Flare hits whoever is at the spot, not the target that moved")
	check(c.fields.any(func(f): return f.kind == "fire"), "Flare leaves a brief burn")
	# BEAUTIFUL DAY: needs a crowd, then heals allies and burns enemies in a fixed zone.
	var d = clean()
	var sun3: Dictionary = d.units[3]
	var foe: Dictionary = d.units[5]
	sun3.pos = Vector2(700, 80)
	foe.pos = Vector2(520, 80)
	check(d.Kits.ultimate_held(d, sun3, foe), "BEAUTIFUL DAY waits for a crowd")
	d.units[0].pos = Vector2(540, 80)
	d.units[6].pos = Vector2(500, 80)
	d.units[0].hp = 100
	check(not d.Kits.ultimate_held(d, sun3, foe), "BEAUTIFUL DAY fires on a multi-hero fight")
	sun3.cast_effect = "sunday"
	d.resolve_ultimate(sun3, foe)
	check(d.fields.size() == 1 and d.fields[0].kind == "sun" and d.fields[0].radius == 170.0, "BEAUTIFUL DAY creates a large sun zone")
	hp = foe.hp
	d.update_fields(0.05)
	check(foe.hp < hp and d.units[0].hp > 100, "Sunlight burns enemies and heals allies")
	check(d.in_sunlight(foe, sun3.team) and d.Kits.resolve_bonus(d, d.units[0]) == 25.0, "Enemies are marked and allies gain Resolve")
	sun3.hp = 0
	d.update_fields(0.05)
	check(d.fields.size() == 1, "The zone stays even if Sunday falls")

func determinism_checks() -> void:
	var runs := []
	for attempt in range(2):
		var b = Battle.new()
		b.setup(808, 1, 0, 2, TEAM)
		for i in range(3600):
			if i == 100:
				b.request_purchase(0, b.units[0].id, "power_cell")
				b.request_purchase(0, b.units[3].id, "swift_treads")
			b.step()
		runs.append([b.records.size(), b.kills.duplicate(), b.units.map(func(u): return u.pos), b.units.map(func(u): return u.items)])
	check(runs[0] == runs[1], "New heroes, purchases and deliveries stay seed-reproducible")
