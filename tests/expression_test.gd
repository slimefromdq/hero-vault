extends SceneTree
const Expressions = preload("res://scripts/expressions.gd")
const Battle = preload("res://scripts/battle.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	var library := Expressions.new()
	for hero in Expressions.SHEETS:
		var seen := []
		for name in Expressions.NAMES:
			var texture := library.texture(hero, name)
			check(texture != null, hero + " loads " + name)
			check(texture.get_width() == texture.get_height(), "Square canvas preserves aspect")
			var pixels := texture.get_image()
			check(pixels.get_pixel(0,0).a == 0, "Portrait corners are transparent")
			var fingerprint := hash(pixels.get_data())
			check(not seen.has(fingerprint), "Each expression has unique art")
			seen.append(fingerprint)
	check(library.texture("eleanor") != null, "Other heroes retain SVG art")
	var battle := Battle.new()
	battle.setup(4702, 0, 0, 0)
	var actor: Dictionary = battle.units[0]
	var victim: Dictionary = battle.units[5]
	battle.clock = 10.0
	battle.record_event("melee_windup", actor.id, victim.id)
	check(Expressions.state(actor, 10) == "attack", "Windup triggers a readable attack")
	check(Expressions.state(actor, 11) == "neutral", "Reaction expires")
	battle.record_event("damage", victim.id, actor.id, 10)
	check(Expressions.state(actor, 10) == "hurt", "Damage overrides attack")
	battle.snapshot()
	var replay: Dictionary = battle.history[-1]
	battle.record_event("ultimate_cast", actor.id, victim.id)
	check(Expressions.state(actor, 10) == "special", "Ultimate gets signature face")
	check(Expressions.state(replay.units[0], replay.time) == "hurt", "Replay retains its original cue")
	actor.hp = actor.max_hp*0.2
	check(Expressions.state(actor, 10) == "panic", "Low health overrides action")
	actor.stun = 1.0
	check(Expressions.state(actor, 10) == "dazed", "Stun overrides panic")
	actor.hp = 0.0
	check(Expressions.state(actor, 10, actor.team) == "knocked_out", "KO has highest priority")
	actor.hp = actor.max_hp
	actor.stun = 0.0
	check(Expressions.state(actor, 20, actor.team) == "happy", "Victory reaction")
	check(Expressions.state(actor, 20, 1-actor.team) == "upset", "Defeat reaction")
	actor.erase("portrait_streak")
	victim.hp = 0.0
	for i in range(2):
		Expressions.record("damage", actor, victim, 10, 20)
	check(Expressions.fire_strength(actor, 20.5) == 0, "Two kills do not trigger fire")
	Expressions.record("damage", actor, victim, 10, 21)
	check(Expressions.fire_strength(actor, 21.5) > 0, "Third consecutive hero kill triggers fire")
	check(Expressions.fire_strength(actor, 24.1) == 0, "Fire ends after three seconds")
	var streak_replay: Dictionary = actor.duplicate(true)
	Expressions.record("damage", actor, victim, 10, 24)
	check(Expressions.fire_strength(actor, 24.5) > 0, "Additional takedown refreshes fire")
	check(Expressions.fire_strength(streak_replay, 24.5) == 0, "Replay keeps original fire timing")
	actor.hp = 0.0
	Expressions.record("damage", victim, actor, 10, 25)
	actor.hp = actor.max_hp
	check(actor.portrait_streak == 0 and Expressions.fire_strength(actor, 25.5) == 0, "Death resets fire and streak after respawn")
	victim.creep = true
	Expressions.record("damage", actor, victim, 10, 26)
	check(actor.portrait_streak == 0, "Creep kills do not build streak")
	print("EXPRESSION PASS" if failures == 0 else "EXPRESSION FAIL: %d" % failures)
	quit(failures)
