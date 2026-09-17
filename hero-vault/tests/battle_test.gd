extends SceneTree

const Battle = preload("res://scripts/battle.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	var a = Battle.new()
	a.setup(47, 0, 0, 0)
	var rally: Dictionary = a.units[0]
	a.apply_damage(rally, 9999, 2)
	check(rally.hp == 0, "Lethal damage kills the hero")
	check(rally.respawn > 0, "Death schedules a respawn")
	rally.respawn = 0.01
	a.step()
	check(rally.hp > 0 and not rally.standing, "Respawn restores life")

	var shield_test = Battle.new()
	shield_test.setup(4, 0, 0, 0)
	var defender: Dictionary = shield_test.units[1]
	defender.items.clear()
	defender.resolve = 0
	defender.shield = 50.0
	var hp: float = defender.hp
	shield_test.apply_damage(defender, 70, 2)
	check(defender.hp == hp - 20 and defender.shield == 0, "Shields absorb before health")

	var intercept = Battle.new()
	intercept.setup(4, 0, 0, 2)
	intercept.units[0].pos = Vector2(200, 250)
	for u in intercept.units:
		u.pos = Vector2(0, 0)
		u.items.clear()
		u.resolve = 0
	intercept.units[0].pos = Vector2(200, 250)
	intercept.units[5].pos = Vector2(500, 250)
	intercept.units[6].pos = Vector2(350, 250)
	var front_hp: float = intercept.units[6].hp
	var back_hp: float = intercept.units[5].hp
	intercept.fire(intercept.units[0], intercept.units[5], 100, true)
	for i in range(20):
		intercept.update_shots(0.05)
	check(intercept.units[6].hp == front_hp - 100, "Front hero intercepts the aimed ultimate")
	check(intercept.units[5].hp == back_hp, "Protected target takes no damage")

	var first = Battle.new()
	var second = Battle.new()
	first.setup(4702, 0, 0, 0)
	second.setup(4702, 0, 0, 0)
	for i in range(1200):
		first.step()
		second.step()
	check(first.frame() == second.frame(), "Fixed seed and plan produce identical state")
	check(first.events == second.events, "Fixed seed produces identical event history")
	check(first.history.size() <= 210, "Replay buffer stays bounded")
	var pressure = Battle.new()
	pressure.setup(4702, 1, 1, 0)
	for i in range(1200):
		pressure.step()
	check(first.frame() != pressure.frame(), "Preparation changes the encounter")

	var clutch_count := 0
	for p in range(3):
		for rival in range(3):
			var battle = Battle.new()
			battle.setup(4793 + rival * 37, p, 0, rival)
			for tick in range(24000):
				battle.step()
				if battle.winner != -1:
					break
			check(battle.winner != -1, "Battle terminates by vault destruction within 20 simulated minutes")
			check(battle.vaults[0] == 0 or battle.vaults[1] == 0, "Victory requires destroyed vault")
			var clutches := 0
			for event in battle.events:
				if event.kind == "clutch":
					clutches += 1
			clutch_count += clutches
			print("MATCH plan=%d rival=%d winner=%d seconds=%.1f kills=%s clutch_events=%d" % [p, rival, battle.winner, battle.clock, str(battle.kills), clutches])
	check(clutch_count > 0, "Standard combat produces a low-health recovery moment")
	print("PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(0 if failures == 0 else 1)
