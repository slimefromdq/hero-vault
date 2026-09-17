extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Map = preload("res://scripts/map_layout.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	check(Map.LANE_COUNT == 3 and Map.length(2) > 1400 and Map.length(0) > 2000, "All three lanes have meaningful travel time")
	for lane in range(Map.LANE_COUNT):
		check(not Map.on_lane(Map.POWER_NODE, lane), "Contesting the node requires leaving the lane")
	var b = Battle.new()
	b.setup(817, 0, 0, 0)
	b.spawn_wave()
	check(b.units.filter(func(u): return u.creep_kind == "melee").size() == 12, "Each side sends two durable melee creeps per lane")
	check(b.units.filter(func(u): return u.creep_kind == "ranged").size() == 12, "Each side sends two ranged creeps per lane")
	b.spawn_wave()
	check(not b.units.any(func(u): return u.creep_kind == "siege"), "First two waves have no siege creep")
	b.spawn_wave()
	check(b.units.filter(func(u): return u.creep_kind == "siege").size() == 6, "Every third wave brings siege creeps to every lane")
	var hero: Dictionary = b.units[0]
	var tower: Dictionary = b.towers[3]
	hero.pos = tower.pos + Vector2(10, 0)
	hero.items.clear()
	hero.resolve = 0
	hero.armor = 0
	var creep: Dictionary = b.units[10]
	creep.pos = tower.pos + Vector2(80, 0)
	var hp: float = hero.hp
	b.update_towers(0.05)
	check(hero.hp == hp and creep.hp < creep.max_hp, "Tower always targets an in-range allied wave before the closer hero")
	b.units = [hero]
	tower.cooldown = 0
	b.update_towers(0.05)
	check(hero.hp <= hp-hero.max_hp*0.2, "Unsupported hero takes punishing tower damage")
	check(b.avoid_tower(hero, 0.3) and hero.intent.begins_with("Wait for wave"), "AI backs away from an unsupported dive")
	hero.hp = hero.max_hp*0.45
	hero.behavior.retreat = 5
	hero.decision_cd = 0
	b.update_decision(hero, 0.3)
	check(hero.decision == "retreat", "Cautious personality retreats at 45 percent HP")
	hero.behavior.retreat = 1
	hero.decision = "farm"
	hero.decision_cd = 0
	b.update_decision(hero, 0.3)
	check(hero.decision != "retreat", "Aggressive personality stays at the same HP")
	hero.hp = hero.max_hp*0.1
	hero.decision_cd = 0
	hero.pos = Map.BASES[hero.team]
	b.wave_clock = 10000
	for i in range(240):
		b.step()
	check(hero.hp/hero.max_hp >= 0.8 and hero.decision != "retreat", "Retreat recovery ends rather than leaving heroes stuck at base")
	var objective = Battle.new()
	objective.setup(818, 0, 0, 0)
	var node: Dictionary = objective.camps[-1]
	objective.update_camps(239.9)
	check(node.hp == 0, "Power node cannot be farmed during early laning")
	objective.clock = 240
	objective.update_camps(0.1)
	check(node.hp == node.max_hp, "Power node activates at four minutes")
	var scout: Dictionary = objective.units[4]
	scout.rotate_cd = 0
	objective.consider_rotation(scout)
	check(scout.camp_target == 2 and not scout.rotation.is_empty(), "Roamer voluntarily leaves lane for the node")
	scout.pos = node.pos
	scout.cooldown = 0
	var challenger: Dictionary = objective.units[5]
	challenger.pos = node.pos+Vector2(20, 0)
	objective.farm_camp(scout, 0.05)
	check(scout.intent.begins_with("Fight") and node.hp == node.max_hp, "Enemy contest diverts attacks away from the objective")
	challenger.pos = challenger.spawn
	scout.cooldown = 0
	node.hp = 1
	objective.farm_camp(scout, 0.05)
	check(node.hp == 0 and node.respawn == Battle.NODE_RESPAWN, "Capture schedules a periodic respawn")
	check(objective.empowered_until[0] == 330 and objective.units[0].xp == 12, "Capture rewards the whole team")
	objective.spawn_wave()
	check(objective.units.any(func(u): return u.creep and u.team == 0 and u.empowered), "Winning side receives visibly empowered waves")
	check(not objective.units.any(func(u): return u.creep and u.team == 1 and u.empowered), "Opposing waves remain ordinary")
	objective.clock = 331
	objective.units = objective.units.filter(func(u): return not u.creep)
	objective.spawn_wave()
	check(not objective.units.any(func(u): return u.empowered), "Wave empowerment expires")
	objective.update_camps(Battle.NODE_RESPAWN)
	check(node.hp == node.max_hp, "Node returns for a later contest")
	var waves = Battle.new()
	waves.setup(819, 0, 0, 0)
	waves.units.clear()
	waves.towers.clear()
	waves.wave_clock = 10000
	waves.spawn_wave()
	for i in range(600):
		waves.step()
	check(waves.units.any(func(u): return u.hp < u.max_hp), "Opposing waves actually fight each other")
	check(waves.units.any(func(u): return u.lane == 2 and absf(Map.project(u.pos, 2).progress-Map.length(2)*0.5) < 220), "Colliding waves hold a central front")
	var siege = Battle.new()
	siege.setup(820, 0, 0, 0)
	var cannon: Dictionary = siege.make_unit("Siege creep", 0, "", Map.TOWERS[1][0], 380, 16, 220, 0)
	cannon.creep = true
	cannon.cooldown = 0
	var tower_hp: float = siege.towers[3].hp
	siege.siege(cannon, 0.05)
	var ordinary: float = tower_hp-siege.towers[3].hp
	cannon.creep_kind = "siege"
	cannon.cooldown = 0
	tower_hp = siege.towers[3].hp
	siege.siege(cannon, 0.05)
	check(is_equal_approx(tower_hp-siege.towers[3].hp, ordinary*3.5), "Siege creep damage meaningfully accelerates structure pressure")
	print("PACING PASS" if failures == 0 else "PACING FAIL: %d" % failures)
	quit(1 if failures else 0)
