extends SceneTree
## Poppet, Crash Test, Kiln, Sunday; Ambush Shield, Invisible Cloak, the 1-point
## items and burst item evolution.
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/catalog.gd")
const TEAM := ["poppet", "crash_test", "kiln", "sunday", "hazmat"]
const EMPTY := [["none", "none"], ["none", "none"], ["none", "none"], ["none", "none"], ["none", "none"]]
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

## Units 0-4 are TEAM; 5-9 are rival 0 (hazmat, irene, eleanor, colony, oddity).
func clean(seed_value: int = 11):
	var b = Battle.new()
	b.setup(seed_value, 0, 0, 0, TEAM, EMPTY)
	for i in range(b.units.size()):
		var u: Dictionary = b.units[i]
		u.items.clear()
		u.armor = 0
		u.resolve = 0
		u.pos = Vector2(-600 + i*140, 900) # Far apart unless a check places them.
		u.lane = 0
	return b

func _init() -> void:
	check(Catalog.validate_definitions() == "", "Definitions, evolutions and rival squads validate")
	check(Catalog.ITEM_IDS.size() == 15, "Fourteen purchasable items plus Empty")
	check(not Catalog.HEROES.has("atlas"), "Tank carry is scrapped for now")
	check(Catalog.migrate_team(["atlas", "irene", "irene", "volt", "kiln"]) == ["hazmat", "irene", "eleanor", "colony", "kiln"], "Retired or duplicate heroes are replaced one-for-one")
	check("EVOLVES" in Catalog.item_tooltip("coin") and not "EVOLVES" in Catalog.item_tooltip("glass"), "Tooltips explain evolution")
	poppet_checks()
	crash_test_checks()
	kiln_checks()
	sunday_checks()
	item_checks()
	evolution_checks()
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
	crash.pos = Vector2(500, 80)
	enemy.pos = Vector2(620, 80)
	enemy.behavior.dueling = 1
	enemy.speed = 0
	crash.dash = {"kind": "ram", "target": enemy.id, "dest": Vector2(640, 80), "time": 0.8}
	var hp: float = enemy.hp
	for i in range(20):
		if crash.dash.is_empty():
			break
		b.update_dash(crash, 0.05)
	check(enemy.hp < hp and enemy.stun > 0, "Impact Test damages and stuns the first hero in its path")
	enemy.pos = Vector2(620, 120)
	crash.pos = Vector2(500, 80)
	crash.stun = 0
	crash.dash = {"kind": "ram", "target": enemy.id, "dest": Vector2(640, 80), "time": 0.8}
	for i in range(20):
		if crash.dash.is_empty():
			break
		b.update_dash(crash, 0.05)
	check(crash.stun > 0 and b.records.any(func(r): return r.kind == "dash_miss"), "A whiffed charge dazes Crash Test")
	crash.stun = 0
	crash.cast_effect = "crash_test"
	b.resolve_ultimate(crash, enemy)
	check(crash.write_off == 8.0 and crash.shield > 0, "Total Write-Off starts with a shield")
	b.apply_damage(crash, 100, enemy.id)
	check(crash.write_off_stored == 100, "Write-Off stores absorbed damage")
	enemy.pos = crash.pos + Vector2(60, 0)
	hp = enemy.hp
	b.update_effects(crash, 8.1)
	check(crash.write_off == 0 and enemy.hp < hp, "Write-Off explodes when the timer ends")
	crash.write_off = 4.0
	crash.write_off_stored = 0
	hp = enemy.hp
	b.apply_damage(crash, 99999, enemy.id)
	check(enemy.hp < hp, "Write-Off also explodes if Crash Test is destroyed")

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
	sunday.pos = Vector2(0, 0)
	ally.pos = Vector2(100, 0)
	ally.hp = ally.max_hp*0.3
	var hp: float = ally.hp
	sunday.ability = 0
	b.use_abilities(sunday, {})
	check(ally.hp > hp, "Day of Rest heals the most wounded nearby ally")
	sunday.cast_effect = "sunday"
	b.resolve_ultimate(sunday, {})
	check(ally.rest == 5.0 and sunday.rest == 5.0, "Sunday Best covers Sunday and nearby allies")
	check(b.movement_speed(ally, ally.pos+Vector2(10, 0)) == ally.speed*1.2, "Sunday Best adds movement")
	hp = ally.hp
	b.update_effects(ally, 1.0)
	check(is_equal_approx(ally.hp-hp, ally.max_hp*0.05), "Sunday Best heals 5% max HP per second")

func item_checks() -> void:
	var b = clean()
	var a: Dictionary = b.units[4]
	var t: Dictionary = b.units[5]
	# Ambush Shield
	a.items = ["ambush"]
	b.apply_damage(a, a.max_hp*0.2, t.id)
	check(a.shield == 0, "Ambush Shield ignores small hits")
	b.apply_damage(a, a.max_hp*0.15, t.id)
	check(a.shield > 0 and a.ambush_cd == 20.0, "Ambush Shield triggers on burst damage")
	# Invisible Cloak
	var c = clean()
	var ganker: Dictionary = c.units[0]
	var victim: Dictionary = c.units[5]
	ganker.items = ["cloak"]
	ganker.pos = Vector2(500, 80)
	victim.pos = Vector2(700, 80)
	check(c.select_enemy(victim).get("id", -1) == ganker.id, "A visible ganker is targeted")
	c.try_cloak(ganker, "approach", victim)
	check(ganker.invisible == 6.0 and ganker.cloak_cd == 30.0, "Cloak triggers when closing on a distant hero")
	check(c.select_enemy(victim).get("id", -1) != ganker.id, "Enemies cannot target a cloaked hero")
	victim.pos = Vector2(540, 80)
	c.update_effects(ganker, 0.05)
	check(ganker.invisible == 0.0, "Proximity reveals the cloaked hero")
	ganker.invisible = 3.0
	c.apply_damage(ganker, 1, victim.id)
	check(ganker.invisible == 0.0, "Damage reveals the cloaked hero")
	ganker.cloak_cd = 0
	ganker.invisible = 0
	victim.pos = Vector2(200, 0)
	c.try_cloak(ganker, "approach", victim)
	c.apply_damage(victim, 99999, ganker.id)
	check(c.records.any(func(r): return r.kind == "cloak_gank_success"), "Cloaked takedowns are logged for gank analysis")
	# Scout Pin
	victim.hp = victim.max_hp
	victim.items = ["scout"]
	ganker.invisible = 6.0
	ganker.pos = Vector2(0, 0)
	victim.pos = Vector2(200, 0)
	c.update_effects(victim, 0.05)
	check(ganker.invisible == 0.0 and victim.scout_cd == 10.0, "Scout Pin reveals nearby hidden heroes")
	# Lane Rations
	a.items = ["rations"]
	a.hp = 100
	b.clock = 50
	a.last_hero_hit = 47
	b.update_effects(a, 1.0)
	check(a.hp == 100, "Rations wait until hero damage stops")
	a.last_hero_hit = 40
	b.update_effects(a, 1.0)
	check(is_equal_approx(a.hp, 100+4.0+0.4*a.level), "Rations heal after six quiet seconds")
	# Tempered Sole
	a.items = ["sole"]
	a.retreating = false
	b.begin_retreat(a)
	check(a.sole_time == 2.5 and b.movement_speed(a, a.pos) == a.speed*1.4, "Tempered Sole boosts the start of a retreat")
	a.sole_time = 0
	a.retreating = true
	a.sole_cd = 0
	b.begin_retreat(a)
	check(a.sole_time == 0, "Sole only triggers when a retreat begins")

func evolution_checks() -> void:
	var b = clean()
	var a: Dictionary = b.units[4]
	var t: Dictionary = b.units[5]
	a.items = ["first_hit"]
	for i in range(5):
		b.clock += 10
		b.apply_damage(t, 1, a.id, false, "basic")
	check("first_hit" in a.evolved, "First Hit Hammer evolves after five procs")
	check(b.events.any(func(e): return e.kind == "evolve" and "Opening Sledge" in e.detail), "Evolution is announced")
	b.clock += 10
	t.stun = 0
	var hp: float = t.hp
	b.apply_damage(t, 1, a.id, false, "basic")
	check(hp-t.hp == 101 and t.stun > 0, "Opening Sledge hits harder and staggers")
	a.items = ["coin"]
	check(b.coin_chance(a) == 0.08, "Coin starts at 8%")
	b.grant_xp(a, 9999)
	check(a.level == 13 and "coin" in a.evolved and b.coin_chance(a) == 0.14, "Coin evolves at level 13")
	# Stolen items never evolve for the thief.
	var thief: Dictionary = b.units[6]
	var owner: Dictionary = b.units[0]
	owner.items = ["execution"]
	b.thefts.append({"owner": owner.id, "thief": thief.id, "slot": 0, "item": "execution", "until": b.clock+8.0})
	for i in range(3):
		b.advance_item(thief, "execution", 1)
		b.advance_item(owner, "execution", 1)
	check("execution" not in thief.evolved and "execution" not in owner.evolved, "Suppressed or stolen items make no evolution progress")
	b.thefts.clear()
	for i in range(3):
		b.advance_item(owner, "execution", 1)
	check("execution" in owner.evolved, "Execution Blade evolves after three kills")
	a.items = ["bodyguard"]
	b.units[3].hp = 1
	b.units[3].pos = a.pos
	for i in range(20):
		b.apply_damage(a, 100, t.id)
		a.hp = a.max_hp
	check("bodyguard" in a.evolved, "Bodyguard Vest evolves after blocking 400 damage")
	hp = a.hp
	b.apply_damage(a, 100, t.id)
	check(is_equal_approx(hp-a.hp, 65.0), "Shield Wall Vest blocks 35%")

func determinism_checks() -> void:
	var gear := [["ambush", "rations"], ["first_hit", "sole"], ["bodyguard", "coin"], ["scout", "execution"], ["cloak", "coward"]]
	var runs := []
	for attempt in range(2):
		var b = Battle.new()
		b.setup(808, 1, 0, 2, TEAM, gear)
		for i in range(3600):
			b.step()
		runs.append([b.records.size(), b.kills.duplicate(), b.units.map(func(u): return u.pos)])
	check(runs[0] == runs[1], "New heroes and items stay seed-reproducible")
